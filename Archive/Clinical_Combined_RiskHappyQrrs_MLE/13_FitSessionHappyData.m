% Fit EVRPE happiness model
clear;clc
% Load risk data and extract data from structure to table format
tmp = load("fitsessionRiskData.mat");
riskdata = tmp.riskdata;

% Fit Happiness model
for s = 1:height(riskdata)
    t = riskdata.gameData(s).data;
    result_evrpe = fitmodel_happy_evrpe(t);
    riskdata.result_evrpe{s} = result_evrpe;
    riskdata.b_evrpe{s} = result_evrpe.b;
    riskdata.r2_evrpe{s} = result_evrpe.r2;
end

% Add model-free happiness
riskdata.meanRawHappy = cellfun(@(r) mean(r.rawhappy), riskdata.result_evrpe, 'UniformOutput', false);

% Save as .mat file
save('fitsessionRiskHappyData.mat', "riskdata") %change

%% Sanity check: Plot raw vs predicted happiness for first 30 participants
figure;
n = min(30, height(riskdata));
cols = 6; rows = ceil(n/cols);

for s = 1:n
    subplot(rows, cols, s);
    r = riskdata.result_evrpe{s};
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
n = height(riskdata);
B = cell2mat(riskdata.b_evrpe);

for p = 1:5
    subplot(1,5,p);
    histogram(B(:,p));
    title(params{p}); box off;
    axis square;
end
sgtitle('Parameter distributions');

%% Sanity check: R2 distribution
figure('Color', 'w');
r2_numeric = cell2mat(riskdata.r2_evrpe);
histogram(r2_numeric, 80, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'w');
xlim([0,1]);
xline(0, 'black', 'Chance', 'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
xline(mean(r2_numeric, 'omitnan'), '-b', sprintf('Mean (%.2f)', mean(r2_numeric, 'omitnan')), 'LineWidth', 2);
xline(median(r2_numeric, 'omitnan'), '-r', sprintf('Median (%.2f)', median(r2_numeric, 'omitnan')), 'LineWidth', 2);
title('Model Fit (R^2)'); xlabel('R^2'); ylabel('Count'); axis square;

n_below_0 = sum(r2_numeric < 0); % 1
n_below_01 = sum(r2_numeric < 0.1); % 107c

