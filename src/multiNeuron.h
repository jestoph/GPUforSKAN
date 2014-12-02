#ifndef MULTINEURON_H
#define MULTINEURON_H


__global__ void multiNeuron(float * input,  float  * dendriteValue, int timeLength, int numberofWarps);


float * multiNeuron_hostFn(int timeLength, float * h_input, int reps, int numberofWarps);



#endif
