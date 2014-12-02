/*



*/


// Standard Libraries
#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#include<sys/time.h> /*gettimeofday*/

// Includes the cuda runtime routines
#include<cuda_runtime.h>


//TODO: These should happily be .h files, but this fails for some reason....

// My preprocessor functions
#include "CPU_GPU.h"

// SKAN_kernel 
#include "SKAN_KERNEL.h"
#include "multiNeuron.h"

// Some Helper device Functions
#include "deviceFunctions.h"

// CPU SKAN
#include "SKAN_CPU.h"

// CSV read/write operations
#include "CSV_IO.h"

// Function to create a random input
#include "createInput.h"




#define TEST 1
#define VIEWRESULT 1

/*
*
* Function Prototypes
*
*/

/*GPU SKAN Functions*/
//__global__ void GPU_SKAN_KERNEL(float * input,  float  * dendriteValue, int timeLength);
float * GPU_SKAN(int channels, int timeLength, float * h_input, int reps);

/*CPU Skan Functions*/
float * CPU_SKAN(int channels, int timeLength, float * input, int reps);

/*CSV I/O Functions*/
//void csvWrite(char * name,  int height, int length, float * vector);
//float * csvRead(char * name);

/* Function to make a random input */
float * createInput(int channels,int vecLength);

/**************************************************************************************************************
		MAIN
	
	Handle input, send out to the cpu and gpu functions 
	So it can easily be viewed by profiler
**************************************************************************************************************/
int main(int argc, char * argv[]){

	DEBUG_MSG;

	// Create Context so that this doesn't get measured
	// Otherwise this will add around 30 - 50 mS of execution time to the 
	// Initial API call
	cudaFree(0);
	srand(time(NULL) ); // Seed the RNG for the input generation
	/*LOAD UP ARRAY LENGTH*/

	int reps = 1;
	int vecLength = 1000000;//VECLENGTH;
	int channels = 32;//CHANNELS;
	int numberofWarps = 32;

	/*ALL GOOD, LETS GET ON WITH IT*/ 
	printf("\tRunning %d repetitions with %d channels and %d timesteps\n",reps, channels,vecLength);

	// Create an input - NEED TO FREE
	//printf("\tCreate input\n");
	float * input = createInput(channels,vecLength);
	float multiNeuron_cpu_time;
	float * output;
	CPU_TIMER(output = multiNeuron_hostFn(vecLength,input,reps, numberofWarps),multiNeuron_cpu_time);
	printf("\tMultineuron took %f\n",(double)multiNeuron_cpu_time/(double)CLOCKS_PER_SEC);

	char writeOut[] = "data/OUTPUT.csv";
	//measure the time taken to write out the output
	float writeouttime;
	CPU_TIMER(csvWrite(writeOut,channels + numberofWarps,vecLength,output),writeouttime);
	printf("output took %f seconds to write out and is %d bytes not including commas and newlines\n",(double)writeouttime/(double)CLOCKS_PER_SEC, (channels + numberofWarps) * vecLength *sizeof(float));

	char csv_input[] = "data/INPUT.csv";
	CPU_TIMER(csvWrite(csv_input,channels, vecLength,input),writeouttime);
	printf("input took %f seconds to write out and is %d bytes not including commas and newlines\n",(double)writeouttime/(double)CLOCKS_PER_SEC, (channels) * vecLength *sizeof(float));

	free(input);
	free(output);



	return 0;

	/****************************************
	* WE NOW HAVE VALID INPUT, APPLY KERNNELS
	*****************************************/

	//for(int reps = 1 ; reps < 1000 ; reps ++){
	// Is a float, returns the whole array so need to be sure to free the memory	
	//printf("\tApplying GPU Kernel to input\n");	

	/**************************************
	* DO PROCESSING, TIME THE PROCESS
	***************************************/	
	//float CPU_clock_time,GPU_clock_time,
	float CPU_cpu_time, GPU_cpu_time;
	float * result_GPU, * result_CPU;


	printf("\tCPU...");
	CPU_TIMER(result_CPU = CPU_SKAN(channels, vecLength, input, reps), CPU_cpu_time);
	printf("Done.\n\tGPU...");
	CPU_TIMER(result_GPU = GPU_SKAN(channels, vecLength, input, reps), GPU_cpu_time);
	printf("Done.\n");

	/*Run on GPU, time with CPU timer*/
	//CLOCK_TIMER_uSEC(result_GPU = GPU_SKAN(channels, vecLength, input, reps), GPU_clock_time);

	/*Run on CPU, time wirh CPU timer*/
	//CLOCK_TIMER_uSEC(result_CPU = CPU_SKAN(channels, vecLength, input, reps), CPU_clock_time);

	printf("\tCPU_cpu %lf, GPU_cpu %lf\n",(double)CPU_cpu_time/(double)CLOCKS_PER_SEC,(double)GPU_cpu_time/(double)CLOCKS_PER_SEC);



	//printf("\tCPU_clock %lf GPU_clock %lf\n",CPU_clock_time,GPU_clock_time),;

	//printf("\tDifference_clock %lf Difference_cputime %lf\n",CPU_clock_time - GPU_clock_time,(double)(CPU_cpu_time-GPU_cpu_time)/(double)CLOCKS_PER_SEC);

	/*
	*
	*
	*
	*
	*
	*
	*
	*
	*/

	/****************************************
	* PROCESSING DONE, CHECK RESULT
	****************************************/

	float FLOATERR = 0.000001;
	float maxError = FLOATERR, temp;
	int maxErrorTimestep = 0, maxErrorHeight =0;

	for(int i = 0 ; i < (channels + reps)*vecLength; i++){ 

		temp = abs(result_CPU[i] - result_GPU[i]);
		if (temp > maxError){
			//printf("\t!error: result_CPU[%d] = %f, result_GPU[%d] = %f\n",i,result_CPU[i],i,result_GPU[i]);
			maxErrorTimestep = i%vecLength; //mod returns the remainder
			maxErrorHeight = i/vecLength; // integer arithmetic returns discards remainder
			maxError = temp;
		}
	}

	if(maxError>FLOATERR)printf("\tMaxerror = %f at height %d and timestep %d\n",maxError,maxErrorHeight,maxErrorTimestep);
	else printf("\tThe two outputs are identical\n");

#if 1 
	if(VIEWRESULT){	
		printf("\tWriting the Input, and the CPU and GPU outputs to .csv files\n");
		char csv_input[] = "data/INPUT.csv";
		char csv_CPU[] = "data/CPU.csv";
		char csv_GPU[] = "data/GPU.csv";

		csvWrite(csv_input,channels, vecLength,input);
		csvWrite(csv_CPU,channels + reps, vecLength,result_CPU);
		csvWrite(csv_GPU,channels + reps,vecLength,result_GPU);
	}
	
	free(result_CPU);
	free(result_GPU);
	free(input);
#endif

	
	return 0;
	
}
