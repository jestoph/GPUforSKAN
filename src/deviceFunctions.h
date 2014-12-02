
#ifndef DEVICEFUNCTIONS_H
#define DEVICEFUNCTIONS_H


__device__ float clamp(float value,float max, float min);

__device__ float clamp_branch(float value,float max,float min);

__device__ float reduce( float * sReduce, int blockSize, int nextPowerof2);

__device__ float betterReduce( float * sReduce, int blockSize, int nextPowerof2);

__device__ float warpReduce(volatile float * sReduce, int thisWarp);



#endif
