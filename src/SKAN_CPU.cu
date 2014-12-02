 #include "includes.h"


/**************************************************************************************************************
			CPU_SKAN

	Running the code on the CPU both for a comparison and for basic accuracy checks

	SINGLE SKAN KERNEL, NOT IMPLEMENTING LAYER FUNCTIONALITY

**************************************************************************************************************/
float * CPU_SKAN(int channels, int timeLength, float * input, int reps){

/*****************This Fuckn Shit**************************************/

int chs = channels;
int T=400; // T = number of timesteps between presentations?
int C=4; // ratio between dr_max/dr_min
//    %%% Synapse-Dendrite Paramters

int rampMax = 10000;  //% maximum value r can have aka synaptic weight (w) in paper

int dRampSlope = 1; //%(ddr) in paper
float rampSlope_min=2*(2*C)/(float)(2*C-1)*rampMax/(float)T;
float rampSlope_max=C*rampSlope_min; //% del_r_max in paper

//    %%% Soma Parameters
float threshIncrease =.004*rampMax*chs; //% INCREASE in thresh during firing should be about half threshDecay
float postFiringThreshDecay = .01*rampMax*chs;//% threshIncrease*2; % 'forgetting' parameter
float noFiringThreshDecay =.01*rampMax*chs;
float threshold_initial = .5*rampMax*chs;

//    %%% Layer parameters
float inhibitionMax=rampMax;
float inhibitionDecay=2*inhibitionMax/T;



/**********************************************************************/

	/* Stride to keep track of where in the array you are in.*/
	int stride = channels + reps; 
	
	float edgecase = 0; // this is to handle if the value goes below zero
	float somaOutput = 0;

	int logicOffset = 1; // in order to map -1 to 0
	int CHANGESTATE[3];


	// output will be held and saved in this array, including the sum
	float * dendriteValue;
	HOSTMALLOC(dendriteValue, (channels + reps)* timeLength);


	/* Arrays to hold local info for dendrites*/
	// Rampslope is to hold the next value - MUST FREE
	float * rampSlope;
	HOSTMALLOC(rampSlope,channels);

	//float * rampMax;
	//HOSTMALLOC(rampMax,channels);
	// Set up the state machine	

	int * CURRENTSTATE;
	HOSTMALLOC(CURRENTSTATE,channels);

/* LOOP OVER THE NEURONS */
for(int rep = 0 ; rep < reps ; rep ++){

	// Set rampslope and dendrite value to initial value
	for(int i = 0 ; i < channels ; i++){
		dendriteValue[i] = 0.0;
		rampSlope[i] = 0; // Will get clamped to rampslope_min
		CURRENTSTATE[i] = NOTHING;
	}

	// Initialise the first value of the return vector
	dendriteValue[channels + rep] = 0;
//	printf("\treps %d rep %d channels %d\n",reps,rep,channels);

	
	
	/*Global Flags*/
	int JUSTSTOPPED = 0;
	int SPIKING = 0;
	int NOFIREEVENT = 0;
	
	/*Initialise first timestep before enter loop*/
	float somaSum = 0.0; // <- avoid cast
	float somaSumPrev = 0.0;
	somaOutput = 0;

	int inhibition = 0;
	int inhibitionPrev=0;
	float threshold = threshold_initial;
	/**********************************************
	* RUN THE SIMULATION
	**********************************************/
	for(int time = 1 ; time < timeLength ; time++){
	
		somaSum = 0;
		// Take Max
		inhibition = ( (inhibition - inhibitionDecay)) >0 ?(inhibition - inhibitionDecay):0;


		for (int ch = 0 ; ch < channels ; ch ++){	

			/*
			Update Global flag-dependant variables
			*/
			

	
			if(JUSTSTOPPED){
			//	rampMax[ch] += WOUTPUTAFTERINPUT_RISE * wInputFlag - WOUTPUTWITHOUTINPUT_FALL * (~wInputFlag);
			//	wInputFlag = 0;
			}
			else if(SPIKING){
				rampSlope[ch] += CURRENTSTATE[ch]*dRampSlope;
			}
			else if(NOFIREEVENT){
			//	rampMax[ch] -= WINPUTWITHOUTOUTPUT_FALL * wInputFlag;
			//	wInputFlag = 0;
			}

			//rampMax[ch] = HOSTCLAMP(rampMax[ch], RAMPMAX_MAX,RAMPMAX_MIN);
			rampSlope[ch] = HOSTCLAMP(rampSlope[ch], rampSlope_max, rampSlope_min);	


			// Move from nothing if there is an input - no need to check state, that is done later
			CHANGESTATE[NOTHING + logicOffset] = NEXTSTATE(NOTHING,GOINGUP, (input[channels*time + ch]));
			// Move from ramping up to ramping down if you have exceeded rampMax
			CHANGESTATE[GOINGUP + logicOffset] = NEXTSTATE(GOINGUP,GOINGDOWN, (dendriteValue[stride*(time -1) + ch]>rampMax));
			// Move from ramping down to nothing if you go below zero or are zero
			CHANGESTATE[GOINGDOWN + logicOffset] = NEXTSTATE(GOINGDOWN,NOTHING, (dendriteValue[stride*(time - 1) + ch]<=0 ));


			// Handles if the output goes below zero, in order for it to come back up
			edgecase = dendriteValue[stride*(time - 1) + ch] < 0;
			
			// Update the state machine - this is where all the madness starts to make sense
			CURRENTSTATE[ch] = CHANGESTATE[CURRENTSTATE[ch] + logicOffset];

			// Now can use the state (which is actually 1 or 0 or -1) to multiply the dendrit
			// I want to do this : dendriteValue[ch*time] = dendriteValue[ch*time-1] + CURRENTSTATE * rampSlope[ch]; // ideal version
			// WHY WONT THIS WORK
			dendriteValue[stride*time + ch] = (1 - edgecase) * dendriteValue[stride*(time - 1) + ch] + CURRENTSTATE[ch] * rampSlope[ch];
			
			// calculate the sum of the dendrites
			
			somaSum += dendriteValue[stride*time + ch] ;
		} // Channels	

		/*UPDATE THE GLOBAL STATE*/

		// Set to zero so can use if--elseif--elseif to avoid extra evaluation
		SPIKING = 0;
		JUSTSTOPPED = 0;
		NOFIREEVENT = 0;

		/* FIRING */
            	if ((inhibitionPrev == 0 ||  somaOutput == 1) && somaSum>=threshold){
			SPIKING = 1;
			somaOutput = 1;
			threshold += threshIncrease; 
			inhibition = inhibitionMax;
		}
		/* JUST STOPPED */
		else if(somaOutput == 1 && somaSum < threshold){
			JUSTSTOPPED = 1;
			somaOutput = 0;	
			threshold -= postFiringThreshDecay;
		}
		/* THERE WAS A NO FIRING EVENT */
            	else if( somaSumPrev > 0 && somaSum <= 0 && inhibitionPrev == 0){ // if  rsum just hit zero.(\_) this spike series event is over
			NOFIREEVENT = 1;
			somaSum = 0; // <- incase it went below zero
			somaOutput = 0;
			threshold -= noFiringThreshDecay;
		}
		// This is incase there was a no-firing event
		somaSumPrev = somaSum;
		inhibitionPrev = inhibition;
		/* Store all the data*/
		// store the somaSum back into the array
		dendriteValue[stride*time + channels + rep ] = SPIKING;//threshold;//somaSum;//SPIKING;//somaSum;



	} // END OF TIME

} // END OF NEURONS

	/************************************************
	* END OF SIMULATION
	************************************************/

	free(rampSlope);
	free(CURRENTSTATE);

	return dendriteValue;
}




