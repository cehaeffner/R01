% Analyze lteq and risk-taking
% fitcombinedRiskData.mat made in clinical_combined_riskhappyqrrs_mle
clear; clc

% Load data
tmp = load("lteqdata.mat");
lteq = tmp.lteq;
tmp = load("fitcombinedRiskData_monthly.mat");
combinedriskdata = tmp.combinedriskdata;

% Rename public ID to redcapID for merging
lteq = renamevars(lteq, "ParticipantPublicID", "redcapID");

% Merge
lteqrisk = innerjoin(combinedriskdata, lteq, 'Keys', 'redcapID');

% Filter risk and happiness by r2
idx = cell2mat(lteqrisk.pr2_pt) > -8;
lteqrisk = lteqrisk(idx, :);

% Correlate trauma with percent gambling
[rho,pval] = corr(lteqrisk.lteq_score, lteqrisk.pGamble);

% Correlate trauma with alpha
alpha = cellfun(@(x) x(3), lteqrisk.b_pt);
[rho,pval] = corr(lteqrisk.lteq_score, alpha);

% Correlate trauma with lambda
lambda = cellfun(@(x) x(2), lteqrisk.b_pt);
[rho,pval] = corr(lteqrisk.lteq_score, lambda);

% Correlate trauma with lambda
mu = cellfun(@(x) x(1), lteqrisk.b_pt);
[rho,pval] = corr(lteqrisk.lteq_score, mu);


% All: none
% Dense: none



