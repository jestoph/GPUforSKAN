

#include "includes.h"

#include "deviceFunctions.h"

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
__global__ void GPU_SKAN_KERNEL(float * input,  float  * dendriteValue, int timeLength, int nextPowerof2, int numberOfBlocks){
/*****REMOVE ALL THIS SHIT*****/
int chs = blockDim.x;
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
	int blockSize = blockDim.x;
	int stride = blockDim.x + numberOfBlocks;

	// allocate shared memory
	extern __shared__ float sReduce[];
	int offset  = threadIdx.x;

	/* Dendritic parameters and logic structures */
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

	int inhibition = 0;//INHIBITION_INITIAL;
	int inhibitionPrev=0;



	/* Run the Simulation*/

	dendriteValue[threadIdx.x] = 0;// 0;//threadIdx.x;
	dendriteValue[blockSize + blockIdx.x] = 0;//threshold;//0;
	float temp = 0; /*temp to avoid global memory access*/	

	for(int time = 1 ; time < timeLength ; time++){

		/*
		* GLOBAL DATA
		* Update Rampmax, Rampslope and wInputFlag depending on the global flags
		* Using boolean flags for arithmetic to avoid branching.
		*/

		inhibition = fmaxf(inhibition - inhibitionDecay,0);

		// All this shit here can get fucked.
		//if(JUSTSTOPPED){
		//	rampMax += wOutputAfterInputRise * wInputFlag - wOutputWithoutInputFall * (~wInputFlag);
		//	wInputFlag = 0;
		//}
		//else
		if(SPIKING){
			rampSlope += CURRENTSTATE*dRampSlope;
		}
		//else if(NOFIREEVENT){
		//	rampMax -= winputwithoutoutputfall * wInputFlag;
		//	wInputFlag = 0;
		//}


		/* Clamp values to ensure stability*/
		/* TODO: these can be put in the appropriate 'if' statement to avoid evaluating them when nothing's happening*/
		//rampMax = clamp_branch(rampMax, wUpperBound,wLowerBound);
		rampSlope = clamp(rampSlope,rampSlope_max,rampSlope_min);


		/*
		* LOCAL, DENDRITIC DATA
		* Change the dendritic state
		* Take the sum and store back to the array
		*/


		// Move from nothing if there is an input - no need to check state, that is done later
		CHANGESTATE[NOTHING + logicOffset] = NEXTSTATE(NOTHING,GOINGUP, (input[time * blockSize + offset]));
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
		somaSum = reduce( sReduce,  blockSize,  nextPowerof2);
		somaSum = sReduce[0]; // <- WITHOUT THIS LINE EVERYTHING BREAKS


		/*UPDATE THE GLOBAL STATE*/

		// Set to zero so can use if--elseif--elseif to avoid extra evaluation
		SPIKING = 0;
		//JUSTSTOPPED = 0;
		//NOFIREEVENT = 0;

		/* FIRING */
            	if ((inhibitionPrev == 0 ||  somaOutput == 1) && somaSum>=threshold){
			SPIKING = 1;
			somaOutput = 1;
			threshold += threshIncrease;// THRESHINCREASE; 
			inhibition = inhibitionMax;// INHIBITION_MAX;
		}
		/* JUST STOPPED */
		else if(somaOutput == 1 && somaSum < threshold){
			//JUSTSTOPPED = 1;
			somaOutput = 0;
			threshold -= postFiringThreshDecay;//  THRESHDECAY_POSTFIRE;
		}
		/* THERE WAS A NO FIRING EVENT */
            	else if( somaSumPrev > 0 && somaSum <= 0 && inhibitionPrev == 0){ // if  rsum just hit zero.(\_) this spike series event is over
			//NOFIREEVENT = 1;
			somaSum = 0; // <- incase it went below zero
			somaOutput = 0;
			threshold -=  noFiringThreshDecay;// THRESHDECAY_NOFIRE;
		}
		// This is incase there was a no-firing event
		somaSumPrev = somaSum;
		inhibitionPrev = inhibition;

		/*
		* Store the Results
		* Get thread 0 to do this so there is no concurrency problem
		* This WILL diverge the warp, but it's necessary.
		*/
		dendriteValue[time*stride + threadIdx.x] = temp;// sReduce has already been changed
		if(threadIdx.x == 0 ){
			// Store the Soma Sum
			dendriteValue[time*stride + blockSize + blockIdx.x] = SPIKING;//inhibition;//threshold;//somaSum;//SPIKING ;//somaSum;
			// Store the Soma Output
			
		}
	}


}

/************************************************************************************************************************
		GPU SKAN

	Host-side code to manage memory allocation and transfer and call the kernel

CURRENTLY ONLY ABLE TO BE SINGLE NEURON, MAINLY JUST WANT TO CHECK FUNCTIONALITY

************************************************************************************************************************/

float * GPU_SKAN(int channels, int timeLength, float * h_input, int reps){

	// Allocate space for input and output on the device, copy data over
	float * d_input, * d_dendriteValues;
	CUDAMALLOC(d_input, channels * timeLength);
	CUDAMALLOC(d_dendriteValues, (channels + reps) * timeLength);
	CUDAMEMCPY_H2D(h_input,d_input, channels * timeLength);

	// find the next lowest power of two
	int nextPowerof2 = 1;
	int temp = channels;
	while((temp>>=1)){
		nextPowerof2<<=1;
	}


	//GPU_SKAN_KERNEL<<<numberOfBlocks, threadsPerBlock, sharedmemory>>>(params);
	//GPU_SKAN_KERNEL_old<<<reps, channels, channels*sizeof(float)>>>(d_input,d_dendriteValues,timeLength,nextPowerof2);	

	GPU_SKAN_KERNEL<<<reps, channels, channels*sizeof(float)>>>(d_input,d_dendriteValues,timeLength,nextPowerof2,reps);	
	
	//cudaDeviceSynchronize(); // block until the device finishes previous call

	// Allocate space for the output on the host
	float * h_dendriteValues;
	HOSTMALLOC(h_dendriteValues, (channels + reps) * timeLength);

	// Copy result back to host
	CUDAMEMCPY_D2H(d_dendriteValues, h_dendriteValues, (channels + reps) * timeLength);

/*	
	// Free device memory
	CUDAFREE(d_input);
	CUDAFREE(d_dendriteValues);

	// Now it is polite to reset the device
	CUDACLEANUP();
*/
	return h_dendriteValues;
}



