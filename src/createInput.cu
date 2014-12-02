/*
Note all these input generating functions only write 1's
All memory is initialised to zero so that they can overwrite each other

*/

#include<stdio.h>
#include<stdlib.h>
#include "CPU_GPU.h"




// This function is needlessly complex - doesn't need an understanding of stride etc
// a simple random function would do
void random2Dspikes(float * input, float spikeDensity, int width, int vecLength){

	for(int i = 0; i < width * vecLength ; i++){
		input[i] = 1;
		//if(rand()/(float)RAND_MAX<spikeDensity) input[i] = !input[i];
		//Don't need an else because am using calloc
	}


}

void tempPattern(float * input, int width, int vecLength){

	for(int i = 0 ; i < vecLength;i +=200){

		for(int j = 0; j < width; j ++){
			i +=5;
			if(width * i + j > vecLength * width) return;
			input[width * i + j] = 1;

		}


	}



}

/*Create a pattern - not freeing memory, that is up to the calling function*/
float * createInput(int channels,int vecLength){
	
	float patternDensity = 1/100.0;
	float noiseDensity = 1/100.0;
	patternDensity += 100;// <- just to shut the compiler up	
	//float * pattern;
	//HOSTMALLOC(pattern,channels);
	//memset(pattern,0,channels*sizeof(int));

	//random2Dspikes(pattern,0.5,channels,100);

	float * input;
	HOSTMALLOC(input,channels*vecLength);
	//memset(pattern,0,channels*vecLength*sizeof(int));
	
	// create a random input
	random2Dspikes(input,noiseDensity,channels,vecLength);
	//tempPattern(input,channels,vecLength);		

	//free(pattern);
	return input;

}


/*
TYPICAL TESTING REGIME

1 - Test with all zeros, make sure there's no uninitialised variables or strange writes.
2 - All 1's, should have a predictable response
2 - Random noise, based on a random density of spikes
3 - Randomly developed patter, repeated to demonstrate learning
4 - Same as 3, with Random Noise
5 - TODO: how to do jitter?

*/
