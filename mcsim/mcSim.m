function [simData,simOptions] = mcSim(scoh,simOptions,varargin)
%MCSIM generate 1D Choice & Reaction time data using Monte Carlo method
%   [simData,simOptions] = mcSim(scoh,simOptions,varargin)
%   where
%       scoh is signed coherence column vector,
%       simOptions is Monte Carlo simulation options generated by
%       MCSIMOPTIONS function,
%       varargin are 'field' & 'value' pairs to update simOptions,
%       and
%       simData is Choice & Reaction Time data generated and sorted by
%       trial. Each row is signed coherence, choice and reaction time.
%
%   See also MCSIMOPTIONS, GETPROFILEFCN.

%   Copyright 2014 Jian Wang

if nargin < 2
    error('Not enough inputs.');
end

if nargin > 2
    simOptions = updateOptions(simOptions,varargin{:}); % Update options.
end

% Set time step size.
dt = simOptions.dt;    
if dt > 1.0E-3 % Unit of second.
    warning('Time step size is too coarse.');
end

tMax = simOptions.tMax; % Unit of second.
t = 0:dt:tMax;

% Set random number generator seed.
if isempty(simOptions.rngSeed) 
    rngSeed = rng;
    simOptions.rngSeed = rngSeed;
else
    rngSeed = simOptions.rngSeed;
end
rng(rngSeed);

% Set number of trials per signed coherence.
trials = simOptions.trials;

% Load theta inputs.
theta = simOptions.theta;

kappa = theta(1);
cohBias = theta(2);
uBias = theta(3);
sigma = theta(4);
bSigma = theta(5);
tndr = theta(6);
tndrsd = theta(7);
tndl = theta(8);
tndlsd = theta(9);

% Calculate up-boundary profile.
upBoundaryProfile = getProfileFcn(simOptions.upBoundaryProfile);
b = simOptions.upBoundaryParameter;
Bup = feval(upBoundaryProfile,b,t);

if isnan(b(1))
    error('Valid up boundary parameter must be provided.');
end

% Stop boundary collapsing when the boundary height become less than 0.1% 
% of initial value.
Bup(Bup <= b(1)*1e-3, 1) = b(1) * 1e-3;

% Calculate lower-boundary profile.
lowerBoundaryProfile = getProfileFcn(simOptions.lowerBoundaryProfile);
b = simOptions.lowerBoundaryParameter;
Blower = feval(lowerBoundaryProfile,b,t);

if isnan(b(1))
    error('Valid up boundary parameter must be provided.');
end

Blower(Blower <= b(1)*1e-3, 1) = b(1) * 1e-3;
Blower = -1.0 * Blower; % Inverse to make defining boundary profile easier.

drift = kappa*(scoh + cohBias) + uBias; % Drift term (mu)
dfu = sqrt(sigma^2 + bSigma * abs(scoh)); % Standard deviation (sd)

% Simulation
nt = length(t);
nd = length(drift);
BupMatrix = repmat(Bup',1,trials);
BlowerMatrix = repmat(Blower',1,trials);
simData = zeros(trials,nd,3); % Matrix of [scoh,lo 0/up 1, ndt]
mu = drift * dt;
sd = dfu * sqrt(dt); % Standard deviance is calculated in this way to make 
                     % sum(variance) = 1 per second.

for n1 = 1:nd
    dftForce = normrnd(mu(n1),sd(n1),nt-1,trials);
    dftSum = [zeros(1,trials); cumsum(dftForce,1)];
    dftBup = dftSum >= BupMatrix;
    dftBlo = dftSum <= BlowerMatrix;
    
    tndrA = normrnd(tndr,tndrsd,1,trials);
    tndlA = normrnd(tndl,tndlsd,1,trials);
    
    for n2 = 1:trials
        iu = find(dftBup(:,n2),1,'first'); % Index of hitting up bound
        il = find(dftBlo(:,n2),1,'first'); % Index of hitting lo bound
        
        if isempty(iu) && isempty(il)
            choice = NaN;
            ndt = NaN;
        elseif ~isempty(iu) && isempty(il)
            choice = 1;
            ndt = (iu-1) * dt + tndrA(1,n2);
        elseif isempty(iu) && ~isempty(il)
            choice = 0;
            ndt = (il-1) * dt + tndlA(1,n2);
        elseif ~isempty(iu) && ~isempty(il)
            if iu <= il
                choice = 1;
                ndt = (iu-1) * dt + tndrA(1,n2);
            else
                choice = 0;
                ndt = (il-1) * dt + tndlA(1,n2);
            end
        end
        
        simData(n2,n1,:) = [scoh(n1),choice,ndt];
    end
end

simData = reshape(simData,[nd*trials,3]);



