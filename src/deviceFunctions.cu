#include "deviceFunctions.h"
#include <stdio.h>

#ifndef DEVICEFUNCTIONS_CU
#define DEVICEFUNCTIONS_CU

/****************************************************************************
*	My clamp function
*	USAGE clamp(value, max,min)
*
*	Avoids branching by using intrinsic max/min functions
******************************************************************************/
__device__ float clamp(float value,float max, float min){
	// is it intrinsic? http://llvm.org/docs/LangRef.html#fcmp-instruction and http://llvm.org/docs/LangRef.html#select-instruction
	// select is like cond?a:b 'without IR-level branching.' meaning intermediate representation
	// could do: float maxRes[2] = {a,b}
	//		result = maxRes[a>b]; select <cond> <trueval> <falseval> nobranch!
	/*
	*	look for
	*
	*/
	// fcmp
	return(fminf(fmaxf(value,min),max));
}

/***************************************************************************
*
*	A Warp-divergent Clamp function
*	Just to demonstrate the inefficiency
*
***************************************************************************/
__device__ float clamp_branch(float value,float max,float min){

	if(value>max) value = max;
	else if(value<min) value = min;

	return value;
}

/******************************************************************************
*	My Reduction Function
*	Works for any number of inputs
*
*	This function will actually be inlined after compilation
********************************************************************************/
__device__ float reduce( float * sReduce, int blockSize, int nextPowerof2){

	/************************************************************************
	 *	Take the sum of the dendrites, store in the channels + 1 column
	 *	DO NOT MESS WITH THIS LOGIC - IT WORKS!!!!
	 ************************************************************************/

	int difference = blockSize - nextPowerof2;
	
	//Ensure previous load is completed
	__syncthreads();

	// handle the non-power of two bits
	if(difference && threadIdx.x < difference){
		sReduce[threadIdx.x] += sReduce[threadIdx.x + nextPowerof2];
	}

	// Make sure load is completed
	__syncthreads();

	// This is the normal, naive reduction for 2^N threads
	for(int n = nextPowerof2>>1; n>=1; n>>=1){
	
		if(threadIdx.x < n)
			sReduce[threadIdx.x] += sReduce[threadIdx.x + n];
	
		__syncthreads();
	}
	// result will be stored in dendriteValue[time*stride + blockSize]
		
	return( sReduce[threadIdx.x] );


}

__device__ float betterReduce( float * sReduce, int blockSize, int nextPowerof2){

	/************************************************************************
	 *	Take the sum of the dendrites, store in the channels + 1 column
	 *	DO NOT MESS WITH THIS LOGIC - IT WORKS!!!!
	 ************************************************************************/

	int difference = blockSize - nextPowerof2;
	int tid = threadIdx.x;
	//Ensure previous load is completed
	__syncthreads();

	// handle the non-power of two bits
	if(difference && threadIdx.x < difference){
		sReduce[threadIdx.x] += sReduce[threadIdx.x + nextPowerof2];
		//__syncthreads; // This is not necessary because there is no collision 
	}

	
	// Conditionally reduce for different blocksizes
	if (blockSize >= 512) {if (tid < 256) { sReduce[tid] += sReduce[tid + 256]; } __syncthreads(); }
	if (blockSize >= 256) {if (tid < 128) { sReduce[tid] += sReduce[tid + 128]; } __syncthreads(); }
	if (blockSize >= 128) {if (tid < 64) { sReduce[tid] += sReduce[tid + 64]; } __syncthreads(); }

	// We are at the final warp, no longer need to sync threads.
	// these 'if blocksize' should be evaluated at compile time, so shouldn't be slow.
	if (tid < 32){
		if (blockSize >= 64) sReduce[tid] += sReduce[tid + 32];
		if (blockSize >= 32) sReduce[tid] += sReduce[tid + 16];
		if (blockSize >= 16) sReduce[tid] += sReduce[tid + 8];
		if (blockSize >= 8) sReduce[tid] += sReduce[tid + 4];
		if (blockSize >= 4) sReduce[tid] += sReduce[tid + 2];
		if (blockSize >= 2) sReduce[tid] += sReduce[tid + 1];
	}		

	return( sReduce[0] );


}

/****************************************************************
*
*	Warp Reduce - works for 32 Warps of 32 Threads ONLY
*	__syncthreads not necessary as it calculates within warps which execute in parallel
*	INTERESTING RESULT: SYNCTHREADS() STILL NECESSARY EVEN WITHIN WARP! IS THIS BECAUSE OF SHARED MEMORY LATENCY?:w
*	http://forums.udacity.com/questions/100037602/why-__syncthreads-needed-even-within-the-warp
*
*	Fixed this by using a volatile float. Note this may break in future.
*	
****************************************************************/
__device__ float warpReduce(volatile float * sReduce, int thisWarp){


//	TODO: don't need the ifs here, can just toss away useless results in non-thisWarp threads


	if(threadIdx.x < blockDim.x - 16){
		sReduce[threadIdx.x] += sReduce[threadIdx.x + 16];
		//__syncthreads(); // not sure if this is necessary
		 sReduce[threadIdx.x] += sReduce[threadIdx.x + 8];
		//__syncthreads(); // not sure if this is necessary
		 sReduce[threadIdx.x] += sReduce[threadIdx.x + 4];
		//__syncthreads(); // not sure if this is necessary
		 sReduce[threadIdx.x] += sReduce[threadIdx.x + 2];
		//__syncthreads(); // not sure if this is necessary
		sReduce[threadIdx.x] += sReduce[threadIdx.x + 1];
		//__syncthreads(); // not sure if this is necessary
	}

	// Result is now in sReduce[thisWarp]

	return (sReduce[thisWarp]);
	



}

#endif
