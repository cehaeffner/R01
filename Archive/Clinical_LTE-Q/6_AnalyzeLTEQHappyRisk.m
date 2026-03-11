% Analyze LTEQ and happiness in risk
% fitcombinedRiskHappyData.mat made in clinical_combined_riskhappyqrrs_mle

clear; clc

% Load data
tmp = load("lteqdata.mat");
lteq = tmp.lteq;
tmp = load("fitcombinedRiskHappyData_all.mat");
fitcombinedriskhappydata = tmp.combinedriskhappydata;

% Filter risk and happiness by r2
idx = cell2mat(fitcombinedriskhappydata.r2_evrpe) > 0;
fitcombinedriskhappydata = fitcombinedriskhappydata(idx, :);

% Rename public ID to redcapID for merging
lteq = renamevars(lteq, "ParticipantPublicID", "redcapID");

% Merge
lteqriskhappy = innerjoin(fitcombinedriskhappydata, lteq, 'Keys', 'redcapID');

% Extract parameters
lteqriskhappy.cert = cellfun(@(x) x(1), lteqriskhappy.b_evrpe);
lteqriskhappy.ev = cellfun(@(x) x(2), lteqriskhappy.b_evrpe);
lteqriskhappy.rpe = cellfun(@(x) x(3), lteqriskhappy.b_evrpe);
lteqriskhappy.tau = cellfun(@(x) x(4), lteqriskhappy.b_evrpe);
lteqriskhappy.const = cellfun(@(x) x(5), lteqriskhappy.b_evrpe);

% Correlate trauma with cert
[rho,pval] = corr(lteqriskhappy.lteq_score, lteqriskhappy.cert);
% No

% Correlate trauma with ev
[rho,pval] = corr(lteqriskhappy.lteq_score, lteqriskhappy.ev);
% No
% monthly sig

% Correlate trauma with rpe
[rho,pval] = corr(lteqriskhappy.lteq_score, lteqriskhappy.rpe);
% No

% Correlate trauma with tau
[rho,pval] = corr(lteqriskhappy.lteq_score, lteqriskhappy.tau);
% No

% Correlate trauma with const
[rho,pval] = corr(lteqriskhappy.lteq_score, lteqriskhappy.const);
% No
