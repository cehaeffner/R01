% Analyze lteq and ITC
clear; clc

% Load data
tmp = load("lteqdata.mat");
lteq = tmp.lteq;
tmp = load("fitItcData.mat");
itc = tmp.itcdata;

% Merge
lteqitc = join(itc, lteq, 'Keys','ParticipantPublicID');

% Filter risk and happiness by r2
%idx = cell2mat(lteqitc.pr2_itc_hd) > 0.1;
%lteqitc = lteqitc(idx, :);

% Correlate trauma with model-free discounting
[rho,pval] = corr(lteqitc.lteq_score, lteqitc.pLater);

% Correlate trauma with model-based discounting
kappa = cellfun(@(x) x(2), lteqitc.b_itc_hd);
[rho,pval] = corr(lteqitc.lteq_score, kappa);

% Correlate trauma with stochasticity
mu = cellfun(@(x) x(1), lteqitc.b_itc_hd);
[rho,pval] = corr(lteqitc.lteq_score, mu);



