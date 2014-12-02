#ifndef SKAN_KERNEL_H
#define SKAN_KERNEL_H

__global__ void GPU_SKAN_KERNEL(float * input,  float  * dendriteValue, int timeLength, int blockSize);
float * GPU_SKAN(int channels, int timeLength, float * h_input);

#endif
