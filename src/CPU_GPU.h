/*

A whole lot of preprocessor directives and functions to form a basic GPU library.

*/

#ifndef CPU_GPU_H
#define CPU_GPU_H

#ifdef DEBUG
#define DEBUG_MSG do{printf("\n\t\tRUNNING IN DEBUG MODE\n\n");}while(0)
#else
#define DEBUG_MSG
#endif

//#define DEFAULTHEIGHT 500
#define VECLENGTH 1000
#define CHANNELS 8


/*Saeed's Initial Values - need to work out where these come from*/

#define RAMPSLOPE_INITIAL 1
//Set by Saeed
#define RAMPMAX_INITIAL 10000
#define RAMPMAX_MAX 10000
#define RAMPMAX_MIN 1
#define RAMPSLOPE_MAX 228//.57 //these are actually dependant on the number of dendrites I think
#define RAMPSLOPE_MIN 57//.143
#define DRAMPSLOPE 1

#define THRESHOLD_INITIAL 10000
#define THRESHINCREASE 80
#define THRESHDECAY_POSTFIRE 200 
#define THRESHDECAY_NOFIRE 200

#define WOUTPUTAFTERINPUT_RISE 81
#define WOUTPUTWITHOUTINPUT_FALL 80
#define WINPUTWITHOUTOUTPUT_FALL 200

#define INHIBITION_MAX 10000
#define INHIBITION_DECAY 50


//SET UP LOCAL STATE MACHINE VALUES
#define GOINGUP  1
#define GOINGDOWN  -1
#define NOTHING  0


// Preprocessor function so I can write die(check condition, variable)
#define die(bool_result, error_variable) if(bool_result) printf("ERROR on line %d variable " #error_variable " is %d\n",__LINE__,error_variable); exit(-1);
#define HERE() do{printf("\t-got to here line %d\n",__LINE__);}while(0) 

/*******************************************************************************************************************************
			GPU KERNEL PREPROCESSOR FUNCTIONS
			
	Just to take the burden off the writer from having to write repetitive code
*******************************************************************************************************************************/

#define CUDAMALLOC(variable,size)	do{	variable = NULL;								\
						cudaError_t err = cudaMalloc((void **)&variable,size*sizeof(typeof(*variable)));\
						if( err  != cudaSuccess ){							\
							printf("Error allocating device vector " #variable "\n");		\
							printf(" error code %s  line: %d",cudaGetErrorString(err),__LINE__);	\
							exit(-1);								\
						}										\
					}while(0)


#define CUDAMEMCPY_H2D(host,device,size)	do{	cudaError_t err = cudaMemcpy(device,host,size*sizeof(typeof(*host)), cudaMemcpyHostToDevice);	\
							if(err != cudaSuccess){							\
								printf("Couldn't copy vector " #host " line %d\n",__LINE__);	\
								printf("error code %s\n", cudaGetErrorString(err));		\
								exit(-1);							\
							}									\
						}while(0)

#define CUDAMEMCPY_D2H(device,host,size)	do{	cudaError_t err = cudaMemcpy(host,device,size*sizeof(typeof(*device)), cudaMemcpyDeviceToHost);	\
							if(err != cudaSuccess){							\
								printf("Couldn't copy vector " #device " line %d\n",__LINE__);	\
								printf("error code %s\n", cudaGetErrorString(err));		\
								exit(-1);							\
							}									\
						}while(0)

#define CUDAFREE(variable)	do{	cudaError_t err = cudaFree(variable);					\
					if(err != cudaSuccess){							\
						printf("couldn't free " #variable " line %d", __LINE__);	\
						printf("error code %s\n", cudaGetErrorString(err));		\
						exit(-1);							\
					}									\
				}while(0)


#define CUDACLEANUP()	do{	cudaError_t err = cudaDeviceReset();				\
				if(err !=cudaSuccess){						\
					printf("error resetting %d\n",__LINE__);		\
					printf("error code %s\n", cudaGetErrorString(err));	\
					exit(-1);						\
				}								\
			}while(0)


/********************************************************************************************************
*	CPU Preprocessor Functions
*********************************************************************************************************/
// Lazy function to allocate float memory on the host
#define HOSTMALLOC(variable, size) 	do{	variable = (typeof(*variable) *)calloc(size,sizeof(typeof(*variable)));			\
						if(variable == NULL){						\
							printf("Could not allocate space on host");		\
							exit(-1);						\
						}								\
					} while(0)

#define HOSTCLAMP(variable, max, min) variable = (min>variable)?min:((max<variable)?max:variable)	
					

// Easy way to update the state given a condition because states are just numbers
#define NEXTSTATE(curr,next,condition) curr + (next - curr)*(condition)


/****************************************************************************************************
*	Timing functions
****************************************************************************************************/
#define CPU_TIMER(operation,time) do{	clock_t start, stop;			\
					start = clock();			\
					operation;				\
					stop = clock();				\
					time = stop - start;			\
				}while(	0)


#define CLOCK_TIMER_uSEC(operation, uSecs) do{ 	struct timeval tv1;			\
						struct timeval tv2;			\
						gettimeofday(&tv1,NULL);		\
						operation;				\
						gettimeofday(&tv2,NULL);		\
						uSecs = tv2.tv_usec - tv1.tv_usec;	\
					}while(0)



#endif
