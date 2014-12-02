
#
#
# 	Makefile for src/CPU_GPU_COMPAREsrc/CPU_GPU_COMPARE
#
#	Getting used to the NVCC environment
#

# Choose nvcc as compiler
GCC ?= g++
CUDA_PATH ?= /usr/local/cuda-6.5
NVCC := $(CUDA_PATH)/bin/nvcc -ccbin $(GCC)
EXEC ?= 
INCLUDES  := -I../../common/inc -Ibin
DEBUG := -D DEBUG
# The --relocatable-device-code true means that you can have device code else where
FLAGS := --relocatable-device-code true 
################################################################################
#


# taken from samples

# Target rules
all: build

build: bin/CPU_GPU_COMPARE

bin/CPU_GPU_COMPARE: bin/CPU_GPU_COMPARE.o bin/CSV_IO.o bin/createInput.o bin/deviceFunctions.o bin/SKAN_KERNEL.o bin/multiNeuron.o bin/SKAN_CPU.o
	$(EXEC) $(NVCC) $(FLAGS) -o $@ $+ 

bin/CPU_GPU_COMPARE.o: src/CPU_GPU_COMPARE.cu 
	$(EXEC) $(NVCC) $(INCLUDES) $(FLAGS)  -o $@ -c $< 	

bin/SKAN_KERNEL.o: src/SKAN_KERNEL.cu 
	$(EXEC) $(NVCC) $(INCLUDES) $(FLAGS)  -o $@ -c $< 	

bin/SKAN_CPU.o: src/SKAN_CPU.cu
	$(EXEC) $(NVCC) $(INCLUDES) $(FLAGS)  -o $@ -c $< 

bin/CSV_IO.o: src/CSV_IO.cu
	$(EXEC) $(NVCC) $(INCLUDES)  $(FLAGS)  -o $@ -c $<

bin/createInput.o: src/createInput.cu
	$(EXEC) $(NVCC) $(INCLUDES)  $(FLAGS)  -o $@ -c $<

bin/deviceFunctions.o: src/deviceFunctions.cu
	$(EXEC) $(NVCC) $(INCLUDES)  $(FLAGS)  -o $@ -c $<

bin/multiNeuron.o: src/multiNeuron.cu bin/deviceFunctions.o
	$(EXEC) $(NVCC) $(INCLUDES)  $(FLAGS)  -o $@ -c $<
	
run: build
	$(EXEC) ./bin/CPU_GPU_COMPARE

clean:
	rm -f bin/CPU_GPU_COMPARE bin/CPU_GPU_COMPARE.o

#because I AAAALWAYS type clear instead of clean
clear: clean

###############################################################################
# various debugging options

#profiler option
p: profile
profile: FLAGS+= -pg
profile: run
profile: 
	nvprof bin/CPU_GPU_COMPARE --log-file data/profiledata.txt

#for extra info
d: debug
debug: FLAGS += -D DEBUG
debug: build
	
g: gdb
gdb: FLAGS += -g
gdb: build
gdb:
	gdb bin/CPU_GPU_COMPARE

s: save
save: FLAGS += --save-temps
save: build
