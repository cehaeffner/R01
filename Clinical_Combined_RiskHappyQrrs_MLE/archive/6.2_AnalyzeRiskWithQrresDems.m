% Analyze how combined fit data correlates with motivation and state
% questionnaires
% Note: should add multiple corrections
% Result: alpha is not related to anything besides pos emotion (but not
% related to negative emotion...sus), lambda is correlated with depression
% (barely)
clear;clc

% Load risk data and questionnaire data
tmp = load("fitcombinedRiskData_all.mat");
fitcombinedriskdata = tmp.combinedriskdata(cell2mat(tmp.combinedriskdata.pr2_pt) > 0.1, :);
tmp = load("combinedSurveyData_all.mat");
combinedphq9gad7 = tmp.combinedphq9gad7_all;
combinedmasqbami = tmp.combinedmasqbami_all;
combinedstate = tmp.combinedstate_all;

% Filter by r2
idx = cell2mat(fitcombinedriskdata.pr2_pt) > -8;
fitcombinedriskdata = fitcombinedriskdata(idx, :);

% Extract parameters from risk data
fitcombinedriskdata.mu = cellfun(@(x) x(1), fitcombinedriskdata.b_pt);
fitcombinedriskdata.lambda = cellfun(@(x) x(2), fitcombinedriskdata.b_pt);
fitcombinedriskdata.alpha = cellfun(@(x) x(3), fitcombinedriskdata.b_pt);

% Combine dfs
riskphq9gad7 = outerjoin(combinedphq9gad7, fitcombinedriskdata, 'Keys', 'redcapID', 'MergeKeys', true);
riskmasqbami = outerjoin(combinedmasqbami, fitcombinedriskdata, 'Keys', 'redcapID', 'MergeKeys', true);
riskstate = outerjoin(combinedstate, fitcombinedriskdata, 'Keys', 'redcapID', 'MergeKeys', true);

% Create gender-specific dataframe
g0_riskmasqbami = riskmasqbami(riskmasqbami.gender == 0, :);
g0_riskphq9gad7 = riskphq9gad7(riskphq9gad7.gender == 0, :);
g0_riskstate = riskstate(riskstate.gender == 0, :);
g0_fitcombinedriskdata = fitcombinedriskdata(fitcombinedriskdata.gender == 0, :);
g1_riskmasqbami = riskmasqbami(riskmasqbami.gender == 1, :);
g1_riskphq9gad7 = riskphq9gad7(riskphq9gad7.gender == 1, :);
g1_riskstate = riskstate(riskstate.gender == 1, :);
g1_fitcombinedriskdata = fitcombinedriskdata(fitcombinedriskdata.gender == 1, :);

%% Does mean risk preference relate to mean MASQ score (anhedonia)?
[rho, p] = corr(g0_riskmasqbami.mean_masqscore, g0_riskmasqbami.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No
[rho, p] = corr(g1_riskmasqbami.mean_masqscore, g1_riskmasqbami.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean risk preference relate to mean BAMI score (behavioral apathy)?
[rho, p] = corr(g0_riskmasqbami.mean_bamiscore, g0_riskmasqbami.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No
[rho, p] = corr(g1_riskmasqbami.mean_bamiscore, g1_riskmasqbami.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean risk preference relate to mean PHQ9 score (depression)?
[rho, p] = corr(g0_riskphq9gad7.mean_phq9score, g0_riskphq9gad7.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No
[rho, p] = corr(g1_riskphq9gad7.mean_phq9score, g1_riskphq9gad7.alpha, 'Type', 'Spearman', 'Rows', 'complete');

% Does mean risk preference relate to mean GAD7 score (anxiety)?
[rho, p] = corr(g0_riskphq9gad7.mean_gad7score, g0_riskphq9gad7.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No
[rho, p] = corr(g1_riskphq9gad7.mean_gad7score, g1_riskphq9gad7.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean risk preference relate to mean worriedness?
[rho, p] = corr(g0_riskstate.mean_worriedscore, g0_riskstate.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean risk preference relate to mean positive emotion?
[rho, p] = corr(riskstate.mean_posemoscore, riskstate.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No - marginal
% R2 filt at .1: still marginal

% Does mean risk preference relate to mean negative emotion?
[rho, p] = corr(riskstate.mean_negemoscore, riskstate.alpha, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean risk preference relate to phq8 at scid (depression)
[rho, p] = corr(fitcombinedriskdata.phq8_scid, fitcombinedriskdata.alpha,'Type', 'Spearman', 'Rows', 'complete');
% No

%% Does percent gambling relate to mean MASQ score (anhedonia)?
[rho, p] = corr(riskmasqbami.mean_masqscore, riskmasqbami.pGamble, 'Type', 'Spearman', 'Rows', 'complete');
% No - marginal
% R2 filt at .1: still marginal

% Does percent gambling relate to mean BAMI score (behavioral apathy)?
[rho, p] = corr(riskmasqbami.mean_bamiscore, riskmasqbami.pGamble, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does percent gambling relate to mean PHQ9 score (depression)?
[rho, p] = corr(riskphq9gad7.mean_phq9score, riskphq9gad7.pGamble, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does percent gambling relate to mean GAD7 score (anxiety)?
[rho, p] = corr(riskphq9gad7.mean_gad7score, riskphq9gad7.pGamble, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does percent gambling relate to mean worriedness?
[rho, p] = corr(riskstate.mean_worriedscore, riskstate.pGamble, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does percent gambling relate to mean positive emotion?
[rho, p] = corr(riskstate.mean_posemoscore, riskstate.pGamble, 'Type', 'Spearman', 'Rows', 'complete');
% Yes
% R2 filt at .1: NS

% Does percent gambling relate to mean negative emotion?
[rho, p] = corr(riskstate.mean_negemoscore, riskstate.pGamble, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does percent gambling relate to phq8 at scid (depression)
[rho, p] = corr(fitcombinedriskdata.phq8_scid, fitcombinedriskdata.pGamble,'Type', 'Spearman', 'Rows', 'complete');
% No

%% Does mean loss aversion relate to mean MASQ score (anhedonia)?
[rho, p] = corr(riskmasqbami.mean_masqscore, riskmasqbami.lambda, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean loss aversion relate to mean BAMI score (behavioral apathy)?
[rho, p] = corr(riskmasqbami.mean_bamiscore, riskmasqbami.lambda, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean loss aversion relate to mean PHQ9 score (depression)?
[rho, p] = corr(riskphq9gad7.mean_phq9score, riskphq9gad7.lambda, 'Type', 'Spearman', 'Rows', 'complete');
% Yes

% Does mean loss aversion relate to mean GAD7 score (anxiety)?
[rho, p] = corr(riskphq9gad7.mean_gad7score, riskphq9gad7.lambda, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean loss aversion relate to mean worriedness?
[rho, p] = corr(riskstate.mean_worriedscore, riskstate.lambda, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean loss aversion relate to mean positive emotion?
[rho, p] = corr(riskstate.mean_posemoscore, riskstate.lambda, 'Type', 'Spearman', 'Rows', 'complete');
% No - marginal
% R2 filt at .1: NS

% Does mean loss aversion relate to mean negative emotion?
[rho, p] = corr(riskstate.mean_negemoscore, riskstate.lambda, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean loss aversion relate to phq8 at scid (depression)
[rho, p] = corr(fitcombinedriskdata.phq8_scid, fitcombinedriskdata.lambda,'Type', 'Spearman', 'Rows', 'complete');
% No