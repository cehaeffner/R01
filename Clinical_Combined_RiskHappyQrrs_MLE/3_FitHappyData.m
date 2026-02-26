% Fit EVRPE happiness model
clear;clc

% Load risk data and extract data from structure to table format
tmp = load("fitcombinedRiskData_all.mat"); %change
combinedriskhappydata = tmp.combinedriskdata;

% Remove 2 people with no game data
combinedriskhappydata(cellfun(@isempty, combinedriskhappydata.gameDataStacked), :) = [];

% Fit Happiness model
for s = 1:height(combinedriskhappydata)
    t = combinedriskhappydata.gameDataStacked{s};
    result_evrpe = fitmodel_happy_evrpe(t);
    combinedriskhappydata.result_evrpe{s} = result_evrpe;
    combinedriskhappydata.b_evrpe{s} = result_evrpe.b;
    combinedriskhappydata.r2_evrpe{s} = result_evrpe.r2;
end

% Save as .mat file
save('fitcombinedRiskHappyData_all.mat', "combinedriskhappydata") %change

%% Sanity check: Plot raw vs predicted happiness for first 30 participants
figure;
n = min(30, height(combinedriskhappydata));
cols = 6; rows = ceil(n/cols);

for s = 1:n
    subplot(rows, cols, s);
    r = combinedriskhappydata.result_evrpe{s};
    plot(r.rawhappy, 'k'); hold on;
    plot(r.happypred, 'r');
    title(sprintf('r²=%.2f', r.r2), 'FontSize', 7);
    axis tight; box off;
    if s == 1; legend('raw','pred','FontSize',6); end
end
sgtitle('Raw vs Predicted Happiness');

%% Sanity check: Parameter distributions
figure;
params = {'certain','ev','rpe','tau','const'};
n = height(combinedriskhappydata);
B = cell2mat(combinedriskhappydata.b_evrpe);

for p = 1:5
    subplot(1,5,p);
    histogram(B(:,p));
    title(params{p}); box off;
    axis square;
end
sgtitle('Parameter distributions');

%% Sanity check: R2 distribution
figure('Color', 'w');
r2_numeric = cell2mat(combinedriskhappydata.r2_evrpe);
histogram(r2_numeric, 80, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'w');
xlim([0,1]);
xline(0, 'black', 'Chance', 'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
xline(mean(r2_numeric, 'omitnan'), '-b', sprintf('Mean (%.2f)', mean(r2_numeric, 'omitnan')), 'LineWidth', 2);
xline(median(r2_numeric, 'omitnan'), '-r', sprintf('Median (%.2f)', median(r2_numeric, 'omitnan')), 'LineWidth', 2);
title('Model Fit (R^2)'); xlabel('R^2'); ylabel('Count'); axis square;

n_below_0 = sum(r2_numeric < 0); % 1
n_below_01 = sum(r2_numeric < 0.1); % 107c

