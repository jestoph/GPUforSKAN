clear all
close all
clc

MAKE_RESULT = system("cd ..; touch src/CPU_GPU_COMPARE.cu ; make run");
if (MAKE_RESULT ~= 0)
  return
end

% Note: the Skan kernel natively works with channels 'horizontally' and time 'vertically'
% but for visualisation it is easier to work the other way

%CPU = csvread("../data/CPU.csv");
GPU = csvread("../data/OUTPUT.csv");
%INPUT = csvread("../data/INPUT.csv");

% Rotate them for convenience
%CPU = CPU';
GPU = GPU';
%INPUT = INPUT';

SKAN_PLOT(GPU)
title('GPU')
%SKAN_PLOT(INPUT)
%title('INPUT')
