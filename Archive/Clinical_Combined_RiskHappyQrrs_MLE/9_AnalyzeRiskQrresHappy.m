% Analyze how qrre - risk associations change by mood in game
clear; clc; close all;

% Load happiness & Risk data
tmp = load("fitcombinedRiskHappyData_dense.mat");
fitcombinedhappydata_dense   = tmp.combinedriskhappydata;
tmp = load("fitcombinedRiskHappyData_all.mat");
fitcombinedhappydata_all     = tmp.combinedriskhappydata;
tmp = load("fitcombinedRiskHappyData_monthly.mat");
fitcombinedhappydata_monthly = tmp.combinedriskhappydata;

% Load survey data
tmp = load("combinedSurveyData_dense.mat");
combinedphq9gad7_dense = tmp.combinedphq9gad7_dense;
combinedmasqbami_dense = tmp.combinedmasqbami_dense;
combinedstate_dense    = tmp.combinedstate_dense;
tmp = load("combinedSurveyData_all.mat");
combinedphq9gad7_all = tmp.combinedphq9gad7_all;
combinedmasqbami_all = tmp.combinedmasqbami_all;
combinedstate_all    = tmp.combinedstate_all;
tmp = load("combinedSurveyData_monthly.mat");
combinedphq9gad7_monthly = tmp.combinedphq9gad7_monthly;
combinedmasqbami_monthly = tmp.combinedmasqbami_monthly;
combinedstate_monthly    = tmp.combinedstate_monthly;

% Combine happiness/risk with survey data within each session type
% MONTHLY
fitcombinedhappydata_monthly = innerjoin(fitcombinedhappydata_monthly, combinedphq9gad7_monthly, 'Keys', 'redcapID');
fitcombinedhappydata_monthly = innerjoin(fitcombinedhappydata_monthly, combinedmasqbami_monthly, 'Keys', 'redcapID');
fitcombinedhappydata_monthly = innerjoin(fitcombinedhappydata_monthly, combinedstate_monthly,    'Keys', 'redcapID');

% DENSE
fitcombinedhappydata_dense = innerjoin(fitcombinedhappydata_dense, combinedphq9gad7_dense, 'Keys', 'redcapID');
fitcombinedhappydata_dense = innerjoin(fitcombinedhappydata_dense, combinedmasqbami_dense, 'Keys', 'redcapID');
fitcombinedhappydata_dense = innerjoin(fitcombinedhappydata_dense, combinedstate_dense,    'Keys', 'redcapID');

% ALL
fitcombinedhappydata_all = innerjoin(fitcombinedhappydata_all, combinedphq9gad7_all, 'Keys', 'redcapID');
fitcombinedhappydata_all = innerjoin(fitcombinedhappydata_all, combinedmasqbami_all, 'Keys', 'redcapID');
fitcombinedhappydata_all = innerjoin(fitcombinedhappydata_all, combinedstate_all,    'Keys', 'redcapID');