% Fit hyperbolic discounting model to itc data
clear; clc;

% Load risk data and extract data from structure to table format
tmp = load("itcData.mat");
itcdata = tmp.itcdata;

% Fit model
for s = 1:height(itcdata)
    t = itcdata.gameData{s};
    result_itc_hd = fitmodel_itc_hypdisc(t);
    itcdata.result_itc_hd{s} = result_itc_hd;
    itcdata.b_itc_hd{s} = result_itc_hd.b;
    itcdata.pr2_itc_hd{s} = result_itc_hd.pseudoR2;
end

% Add model-free data
itcdata.pLater = cellfun(@(x) mean(x(:,6)), itcdata.gameData);

% Save as .mat
save('fitItcData.mat', "itcdata")

%% Sanity check: correlation between kappa and percent delay choice
% Should be inversely correlated

kappa = cellfun(@(x) x.b(2), itcdata.result_itc_hd);
scatter(log(kappa), itcdata.pLater)
xlabel('Log Kappa')
ylabel('Proportion Later Choices')
