
#include "CSV_IO.h"
#include <stdio.h>
#include <stdlib.h>
#include "CPU_GPU.h"
#include <errno.h>

void csvWrite(char * name,  int stride, int length, float * vector){

	FILE * fp = fopen(name,"w");
	if(fp == NULL){ printf("couldn't open file\n");exit(-1);}

	for(int i = 0 ; i < length; i ++){

		for(int j = 0 ; j < stride-1 ; j ++){
			
			fprintf(fp,"%f,",vector[stride*i + j]);
		}

		fprintf(fp,"%f\n",vector[stride*i + stride - 1]); // last record in a line has no comma

	}

	fclose(fp);

}


//Assumes that the file is non-empty. Will crash if it is.
// Assumes CSV, could change to accept any record seperator
// also assumes that every line is the same number of fields, or will either miss them or crash.
float * csvRead(char * name, int * width, int * height){

	float * data;
printf("here\n");
	FILE * fp = fopen(name,"r");	
		
printf("here\n");
	if(fp == NULL){printf("fail\n");perror("fail\n"); exit(-1);}

	*width = 1; 
	*height = 1;

printf("here\n");

	int ch;
	char fieldSeperator = ',';
	char recordSeperator = '\n';

printf("here\n");
	// Find out how much space is needed to allocate
	while ((ch = fgetc(fp)) != recordSeperator) {if (ch == fieldSeperator ) (*width) ++;}
	while ((ch = fgetc(fp)) != EOF){ if(ch == recordSeperator) (*height) ++;} 

	// Allocate the space, error checking handled in macro	
	// Needs to be freed by caller.	
	HOSTMALLOC(data,(*width) * (*height));	

printf("here\n");
	// Go back to the beginning, Write the data in
	rewind(fp);

	//put the data into buffer
	for(int j = 0; j < *height ; j ++){

		for(int i = 0 ; i < *width-1 ; i ++){
			fscanf(fp,"%f,",&data[j * (*width) + i]);
		}
		fscanf(fp,"%f",&data[j*(*width) + (*width) - 1]); //Last record in line has no terminator

	}	

	fclose(fp);
	
	return(data);

}



