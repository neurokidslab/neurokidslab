% -------------------------------------------------------------------------
% Function that performs an artefact rejection algorithm based on the 
% variace of the signal across electrodes: if at a given sample the 
% amplitud for a given electrode is too far away from the median of all electrodes it is rejected
% 
% INPUTS
% EEG   EEG structure
%
% OPTIONAL INPUTS
%   - thresh        number of interquartil range above or bellow from the meadian (default 2)
%   - refdata       referenced average the data before (1) or not (0) (default 0)
%   - refbaddata    how to teat bad data when reference average ('replacebynan' / 'none' / 'zero', default 'none')
%   - dozscore      z-score the data per electrodes before (1) or not (0) (default 0)
%   - mask          time to mask bad segments (default 0)
%
% OUTPUTS
%   EEG     output data
%   BCT     bad data 
%   T       threshold
%
% -------------------------------------------------------------------------

function [ EEG, BCT, T ] = eega_tRejAmpElecVar( EEG, varargin )

fprintf('### Rejecting based on the variance across electrodes ###\n' )

%% ------------------------------------------------------------------------
%% Parameters
P.thresh = 2;
P.refdata = 0;
P.refbaddata = 'none'; % 'replacebynan' / 'none' / 'zero'
P.dozscore = 0;
P.mask = 0;

[P, OK, extrainput] = eega_getoptions(P, varargin);
if ~OK
    error('eega_tDefBTBC: Non recognized inputs')
end

% Check the inputs
if length(P.thresh)~=1
    error('eega_tRejAmpElecVar: The threshold has to be a number')
end

fprintf('- referenced data: %d\n',P.refdata)
fprintf('- z-score data: %d\n',P.dozscore)
fprintf('\n')

%% ------------------------------------------------------------------------
%% Get data
nEl = size(EEG.data,1);
nS = size(EEG.data,2);
nEp = size(EEG.data,3);

if ~isfield(EEG, 'artifacts') || ~isfield(EEG.artifacts, 'BCT')
    EEG.artifacts.BCT = false(nEl,nS,nEp);
end
if ~isfield(EEG, 'artifacts') || ~isfield(EEG.artifacts, 'BT')
    EEG.artifacts.BT = false(1,nS,nEp);
end

%% ------------------------------------------------------------------------
%% Reference data
if P.refdata
    [ EEG, reference ] = eega_refavg( EEG ,'BadData',P.refbaddata,'SaveRef',0);
end

%% ------------------------------------------------------------------------
%% Z-score
if P.dozscore
    [EEG, mu, sd] = eega_ZscoreForArt(EEG);
end

%% ------------------------------------------------------------------------
%% Find the thresholds
%take the data
D = EEG.data;
%do not consider bad data
D(EEG.artifacts.BCT) = nan;
%do not consider bad times and times were majority of the electrodes are bad
bt = EEG.artifacts.BT | sum(EEG.artifacts.BCT,1)/nEl>0.5;
D(repmat(bt,[nEl 1 1])) = nan;
%reshape
D = reshape(D,[nEl nS*nEp]);
%normalize such that the distribution of values across electrodes has equal mean and standard deviation
Dmean = nanmean(D,1);
Dstd = nanstd(D,[],1);
D = (D - Dmean) ./  Dstd;
%obtain the threshold    
perc = prctile(D(:), [25 50 75]);
IQ = perc(3) - perc(1); 
t_u = perc(3) + P.thresh*IQ;
t_l = perc(1) - P.thresh*IQ;
T = [t_l t_u];

%% ------------------------------------------------------------------------
%% Reject 
%take the data
D = EEG.data;
%reshape
D = reshape(D,[nEl nS*nEp]);
bt = reshape(bt,[1 nS*nEp]);
%normalize such that the distribution of values across electrodes has equal mean and standard deviation
Dmeanbad = nanmean(D,1);
Dstdbad = nanstd(D,[],1);
Dmean(bt) = Dmeanbad(bt);
Dstd(bt) = Dstdbad(bt);
D = (D - Dmean) ./ Dstd;
%reject
BCT = (D > t_u) | (D < t_l);
BCT = reshape(BCT, [nEl nS nEp]);

%% ------------------------------------------------------------------------
%% Update the rejection matrix
EEG.artifacts.BCT = EEG.artifacts.BCT | BCT;
EEG.artifacts.summary = eega_summaryartifacts(EEG);

%% ------------------------------------------------------------------------
%% Data back
if P.dozscore
    EEG.data = EEG.data.*repmat( sd, [1 nS nEp]) + repmat( mu, [1 nS nEp]);
end
if P.refdata
    EEG.data = EEG.data + repmat(reference,[size(EEG.data,1) 1 1]);
end

%% ------------------------------------------------------------------------
%% Mask around 
if ~isempty(P.mask) && P.mask~=0
    [ EEG, bctmask ] = eega_tMask( EEG, 'tmask', P.mask);
    BCT = BCT | bctmask;
    clear bctmask
end

%% ------------------------------------------------------------------------
%% Display rejected data
n = nEl*nS*nEp;
fprintf('Total data rejected %3.2f %%\n', sum(BCT(:))/n*100 )
fprintf('\n' )


end

