% Analyze how combined fit data correlates with motivation and state
% questionnaires
% Result: stochasticity is not related to anything besides GAD7
clear;clc

% Load risk data and questionnaire data
tmp = load("fitcombinedRiskData_monthly.mat");
fitcombinedriskdata = tmp.combinedriskdata(cell2mat(tmp.combinedriskdata.pr2_pt) > 0.1, :);
tmp = load("combinedSurveyData_monthly.mat");
combinedphq9gad7 = tmp.combinedphq9gad7_monthly;
combinedmasqbami = tmp.combinedmasqbami_monthly;
combinedstate = tmp.combinedstate_monthly;

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

% Does mean stochasticity relate to mean MASQ score (anhedonia)?
[rho, p] = corr(riskmasqbami.mean_masqscore, riskmasqbami.mu, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean stochasticity relate to mean bAMI score (apathy)?
[rho, p] = corr(riskmasqbami.mean_bamiscore, riskmasqbami.mu, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean stochasticity relate to PHQ9 (depression)?
[rho, p] = corr(riskphq9gad7.mean_phq9score, riskphq9gad7.mu, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean stochasticity relate to GAD7 (anxiety)?
[rho, p] = corr(riskphq9gad7.mean_gad7score, riskphq9gad7.mu, 'Type', 'Spearman', 'Rows', 'complete');
% All: Yes: p = 0.0148, rho = -0.1343 (same with r2 > 0.1)
% Dense: Marginal: p = 0.0817, rho = -0.0984 (same with r2 > 0.1)
% Monthly: NS p = 0.2032, rho = -0.0811

% Does mean stochasticity relate to being worried?
[rho, p] = corr(riskstate.mean_worriedscore, riskstate.mu, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean stochasticity relate to recent eating?
[rho, p] = corr(riskstate.mean_eatcategory, riskstate.mu, 'Type', 'Spearman', 'Rows', 'complete');
% No for all and dense(diff direction)
% Monthly: p = 2.7901e-5, rho = 0.2622

% Does mean stochasticity relate to sleep?
[rho, p] = corr(riskstate.mean_sleepcategory, riskstate.mu, 'Type', 'Spearman', 'Rows', 'complete');
% No for all and dense (same direction)
% Monthly: p = 0.0056, rho = 0.1750

% Does mean stochasticity relate to coffee?
[rho, p] = corr(riskstate.mean_coffeecategory, riskstate.mu, 'Type', 'Spearman', 'Rows', 'complete');
% No

% Does mean stochasticity relate to phq8 at scid (depression)
[rho, p] = corr(fitcombinedriskdata.phq8_scid, fitcombinedriskdata.mu,'Type', 'Spearman', 'Rows', 'complete');
% No