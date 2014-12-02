clc
        
        NORMALIZE_SYNAPTIC_WEIGHTS = 1;

inputValues = csvread("../data/INPUT.csv");
        
%% FUNDAMENTAL PARAMETERS        
    %global level information  
    inputLength = 1;%size(inputValues,1) 
    chs=size(inputValues,2) % number of channels
    numberOfNeurons=1  % Number of neurons

        
    %Parameters
    %%% Input parameters
    T=400 % T = number of timesteps between presentations?
    C=4 % ratio between dr_max/dr_min % arbitrary
    K=2
    
    %%% Synapse-Dendrite Paramters
    maxRampWeight = 10000  % maximum value r can have aka synaptic weight (w) in paper
    synapticNormalizationFactor=maxRampWeight*chs
    
%% DERIVED PARAMETERS    

    wInputWithoutOutputFall=K*.01*maxRampWeight %.004*wMax;
    wOutputWithoutInputFall=K*.004*maxRampWeight  % A channel has to be consistently silent for a really long time for this to take.
    wOutputAfterInputRise=K*.00405*maxRampWeight  %1000 patternpresentations is enough for fall=.004 rise=.00405
    wUpperBound=10*maxRampWeight
    wLowerBound=1 %.25*wMax;
    ddr0 = 1 %(ddr) in paper
    rampSlope_min=2*(2*C)/(2*C-1)*maxRampWeight/T
    rampSlope_max=C*rampSlope_min % del_r_max in paper
    wMax0 = maxRampWeight
    
    %%% Soma Parameters
    threshIncrease =.004*maxRampWeight*chs % INCREASE in thresh during firing should be about half threshDecay
    postFiringThreshDecay = .01*maxRampWeight*chs % threshIncrease*2; % 'forgetting' parameter
    noFiringThreshDecay =.01*maxRampWeight*chs
    threshold0=.5*maxRampWeight*chs

    %%% Layer parameters
    inhibitionMax=maxRampWeight
    inhibitionDecay=2*inhibitionMax/T

    %%%%% Initialize Kernel/Dentritic  Variables %%%%%%%%%
    rampMax_initial = wMax0  % the highest value the ramps can reach aka synaptic weights (w for in the paper)
    drampSlope_initial = ddr0   % change in dr (ddr in paper)
 %   rampSlope_initial = rampSlopeInitial % %initial step size dr(t=0) in paper. Actually only the first entries are important the rest will get written over in time Randomizing the inital step size is the key

    %%%%% Initialize Soma Variables %%%%%%%%%%%%%%%%%%%%
    threshold_initial = threshold0     % Neuron's membrane threshold (theta) in paper.



