clear all
close all
clc

MAKE_RESULT = system("cd ..; touch src/CPU_GPU_COMPARE.cu ; make run");
if (MAKE_RESULT ~= 0)
  return
end

% Note: the Skan kernel natively works with channels 'horizontally' and time 'vertically'
% but for visualisation it is easier to work the other way

CPU = csvread("../data/CPU.csv");
GPU = csvread("../data/GPU.csv");
INPUT = csvread("../data/INPUT.csv");

% Rotate them for convenience
CPU = CPU';
GPU = GPU';
INPUT = INPUT';


SKAN_PLOT(CPU)
title('CPU')
SKAN_PLOT(GPU)
title('GPU')


maxError = max(max(abs(CPU-GPU)))


for time = 1:size(CPU,2)
  for channel = 1:size(CPU,1)
    err = abs(CPU(channel,time) - GPU(channel,time));
    if err~=0
      SKAN_PLOT(CPU - GPU)
      title('CPU - GPU')
      channel 
      time  
      return
    end
  end
end  