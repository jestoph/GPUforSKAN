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

// Some Helper device Functions
#include "deviceFunctions.h"

// SKAN_kernel 
#include "SKAN_KERNEL.h"
#include "multiNeuron.h"

// CPU SKAN
#include "SKAN_CPU.h"

// CSV read/write operations
#include "CSV_IO.h"

// Function to create a random input
#include "createInput.h"


