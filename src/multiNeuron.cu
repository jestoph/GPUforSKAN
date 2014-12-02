
#include<cuda_runtime.h>
#include "CPU_GPU.h"
#include <stdio.h>
#include <stdlib.h>
#include "deviceFunctions.h"


#define GLOBALINHIBITION

/**********************************************************************************************************************************
*  GPU KERNEL
*
*  Mostly taken from example code
*
*`	TODO: do something about the cruft at the top of the function.
*
*
*
*
************************************************************************************************************************************/


// what does const mean in this context? is it putting into global memory?
__global__ void multiNeuron(float * input,  float  * dendriteValue, int timeLength, int numberofWarps){

	// Memory for reduction
	// This has been declared volatile for warp synchronisation
	// Will be deprecated for devices over compute 2.3
	volatile extern  __shared__ float sReduce[];

	// Some local variables for atomic operations
	__shared__ int globalInhibition;
	globalInhibition = 0;

	// A lock that determines if this thread is allowed to edit inhibition
	volatile __shared__ int inhibitionLock;
	inhibitionLock = -1; // set to an invalid threadId to start with 


	// find the thread and memory offset for global memory
	int warpMemoryOffset = threadIdx.x/warpSize;

	// Each warp is identified by its lowest thread ie threadIdx.x = 0,32,64,96,128...
	int thisWarp = warpSize * warpMemoryOffset; 

	int inputStride = warpSize;
	int outputStride = warpSize + numberofWarps;


/*****REMOVE ALL THIS SHIT*****/
int chs = warpSize;
int T=400; // T = number of timesteps between presentations?
int C=4; // ratio between dr_max/dr_min
//    %%% Synapse-Dendrite Paramters

int rampMax = 10000;  //% maximum value r can have aka synaptic weight (w) in paper
int dRampSlope = 1; //%(ddr) in paper
float rampSlope_min=2*(2*C)/(float)(2*C-1)*rampMax/(float)T;
//printf("rampslopemin = %f\n",rampSlope_min);
float rampSlope_max=C*rampSlope_min; //% del_r_max in paper
   
//    %%% Soma Parameters
float threshIncrease =.004*rampMax*chs; //% INCREASE in thresh during firing should be about half threshDecay
float postFiringThreshDecay = .01*rampMax*chs;//% threshIncrease*2; % 'forgetting' parameter
float noFiringThreshDecay =.01*rampMax*chs;
float threshold=.5*rampMax*chs;

//    %%% Layer parameters
float inhibitionMax=rampMax;
float inhibitionDecay=2*inhibitionMax/T;
/******************************/

	int edgecase = 0; // this is to handle if the value goes below zero
	int somaOutput = 0;

	int logicOffset = 1; // in order to map -1 to 0
	int CHANGESTATE[3];

	float rampSlope = 0;// doesn't matter if 0 will be clamped anyway.
	//float rampmax = 10000;

	// Set up the state machine - states defined in preprocesser	
	int CURRENTSTATE = NOTHING;

	/* Global Parameters*/
	/*TODO: 	think about using preprocessor to get rid of some of these values? 
			How many variables can the kernel hold without having to store them in cache? - ans: about 32*/
	float somaSum = 0;
	float somaSumPrev = 0; // <- AAARGH IT WAS THIS BASTARD!

	/* Global Flags - Dont need some of these because of the K=0 thing*/
	//int JUSTSTOPPED = 0;
	int SPIKING = 0;
	//int NOFIREEVENT = 0;	

	int localInhibition = 0;//INHIBITION_INITIAL;
	int inhibitionPrev=0;



	/* Run the Simulation*/

	// Initial Conditions
	if(threadIdx.x < warpSize){
		dendriteValue[threadIdx.x] = 0;// 0;//threadIdx.x;
		dendriteValue[warpSize + threadIdx.x] = 0;//threshold;//0;
	}
	float temp = 0; /*temp to avoid global memory access*/	

//	if(threadIdx.x == thisWarp) printf("I am %3d, I own warp %3d and my final result is %2.2f\n",threadIdx.x, warpMemoryOffset,sReduce[thisWarp]);
	for(int time = 1 ; time < timeLength; time ++){


/***********************************copied code*****************************************/

		/* Taken word for word from the SKAN_KERNEL.cu implementation*/
		// Does my warp own the inhibtion lock? If so, decay. If it hits zero, give up the lock
		if(inhibitionLock == threadIdx.x){
			globalInhibition = fmaxf(globalInhibition - inhibitionDecay,0);
			if(globalInhibition == 0) inhibitionLock = -1;
		}
		

		if(SPIKING){
			rampSlope += CURRENTSTATE*dRampSlope;
		}

		rampSlope = clamp(rampSlope,rampSlope_max,rampSlope_min);

		/* LOCAL, DENDRITIC DATA */

		// Move from nothing if there is an input - no need to check state, that is done later
		CHANGESTATE[NOTHING + logicOffset] = NEXTSTATE(NOTHING,GOINGUP, (input[time * inputStride + threadIdx.x - thisWarp]) );
		// Move from ramping up to ramping down if you have exceeded rampMax
		CHANGESTATE[GOINGUP + logicOffset] = NEXTSTATE(GOINGUP,GOINGDOWN, (temp > rampMax));
		// Move from ramping down to nothing if you go below zero or are zero
		CHANGESTATE[GOINGDOWN + logicOffset] = NEXTSTATE(GOINGDOWN,NOTHING, (temp<=0 ));

		// Handles if the output goes below zero, in order for it to come back up
		edgecase = temp < 0;

		// Update the state machine - this is where all the madness starts to make sense
		CURRENTSTATE = CHANGESTATE[CURRENTSTATE + logicOffset];


		// Now can use the state (which is actually 1 or 0 or -1) to multiply the dendrite
		temp = (1 - edgecase) * temp + CURRENTSTATE * rampSlope;

		sReduce[ threadIdx.x] =	temp;
		
		// Use this placeholder variable so we don't need lots of memory access
		somaSum = warpReduce( sReduce, thisWarp);  // DIFFERENT FROM KERNEL CODE
		somaSum = sReduce[thisWarp]; // DIFFERENT FROM KERNEL CODE


		/*UPDATE THE GLOBAL STATE*/

		// Set to zero so can use if--elseif--elseif to avoid extra evaluation
		SPIKING = 0;
		/* FIRING */
		// This has been moved around so that the atomicCAS isn't called unless it needs to be.
            	if ((inhibitionPrev == 0 || somaOutput == 1) && somaSum>=threshold){ // DIFFERENT FROM KERNEL CODE

			// First thread that gets here gets the lock!
			// Lazy evaluation means it will only do atomic swap once per firing.
			if(somaOutput == 1 || atomicCAS((int *)&globalInhibition,0,1)==0) {inhibitionLock = thisWarp;}
			if(inhibitionLock == thisWarp){
				SPIKING = 1;
				somaOutput = 1;
				threshold += threshIncrease;// THRESHINCREASE; 
				globalInhibition = inhibitionMax;// INHIBITION_MAX;
			}
		}
		/* JUST STOPPED */
		else if(somaOutput == 1 && somaSum < threshold){
			// Set the global inhibition signal back to zero
			somaOutput = 0;
			threshold -= postFiringThreshDecay;//  THRESHDECAY_POSTFIRE;
		}
		/* THERE WAS A NO FIRING EVENT */
            	else if( somaSumPrev > 0 && somaSum <= 0 && inhibitionPrev == 0){ // if  rsum just hit zero.(\_) this spike series event is over
			somaSum = 0; // <- incase it went below zero
			somaOutput = 0;
			threshold -=  noFiringThreshDecay;// THRESHDECAY_NOFIRE;
		}
		// This is incase there was a no-firing event
		somaSumPrev = somaSum;

		__syncthreads(); // <-- THIS IS CRUCIAL
		inhibitionPrev = globalInhibition;//localInhibition;



/***************************end copied code******************************************/

		// Just store the first warp's results
		if(threadIdx.x < warpSize) dendriteValue[ time * outputStride + threadIdx.x] = temp;// sReduce has already been changed
		if(threadIdx.x == thisWarp ){
			// Store the Soma Sum
			dendriteValue[time*outputStride + warpSize + warpMemoryOffset] = somaOutput;//lobalInhibition;//somaOutput;//SPIKING;//threshold;//somaSum;//SPIKING ;//somaSum;
			//dendriteValue[time*outputStride + 31] = threshold;
			//dendriteValue[time*outputStride + 30] = somaSum;
			// Store the Soma Output
			
		}

	}

}

/************************************************************************************************************************
		GPU SKAN

	Host-side code to manage memory allocation and transfer and call the kernel

CURRENTLY ONLY ABLE TO BE SINGLE NEURON, MAINLY JUST WANT TO CHECK FUNCTIONALITY

************************************************************************************************************************/

float * multiNeuron_hostFn(int timeLength, float * h_input, int reps, int numberofWarps){

	// Allocate space for input and output on the device, copy data over
	float * d_input, * d_dendriteValues; 
	int channels = 32;

	CUDAMALLOC(d_input, channels * timeLength);
	CUDAMALLOC(d_dendriteValues, (numberofWarps + channels)* timeLength);
	CUDAMEMCPY_H2D(h_input,d_input, channels * timeLength);


	multiNeuron<<<reps, 32*numberofWarps, 32*numberofWarps*sizeof(float)>>>(d_input, d_dendriteValues, timeLength,numberofWarps);	

	cudaDeviceSynchronize(); // block until the device finishes previous call

	// Allocate space for the output on the host
	float * h_dendriteValues;
	HOSTMALLOC(h_dendriteValues, 2*channels* timeLength);

	// Copy result back to host
	CUDAMEMCPY_D2H(d_dendriteValues, h_dendriteValues, (numberofWarps + channels) * timeLength);

	// Free device memory
	//CUDAFREE(d_input);
	//CUDAFREE(d_dendriteValues);

	// Now it is polite to reset the device
	//CUDACLEANUP();

	return h_dendriteValues;

}


