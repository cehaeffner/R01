% Fit prospect theory (single alpha) model to risk data per session
clear;clc
% Load risk data and extract data from structure to table format
tmp = load("sessionRiskData_filt.mat");
riskdata = tmp.sessiondata_filt;

% 18 empty arrays
riskdata = riskdata(arrayfun(@(x) ~isempty(x.data), riskdata.gameData), :);

% Fit PT model
for s = 1:height(riskdata)
    t = riskdata.gameData(s).data;
    result_pt = fitmodel_PT1alpha(t);
    riskdata.result_pt(s) = result_pt;
    riskdata.b_pt{s}      = result_pt.b;
    riskdata.pr2_pt(s)    = result_pt.pseudoR2;
end

% Add model-free data
riskdata.pGamble  = arrayfun(@(x) mean(x.data(:,6)),                    riskdata.gameData);
riskdata.pGamGain = arrayfun(@(x) mean(x.data(x.data(:,3)>0,  6)),      riskdata.gameData);
riskdata.pGamMix  = arrayfun(@(x) mean(x.data(x.data(:,3)==0, 6)),      riskdata.gameData);

% Save as .mat
save('fitsessionRiskData.mat', 'riskdata');

%% Sanity check: alpha v pGam
B = cell2mat(riskdata.b_pt);
figure;
scatter(B(:,3), riskdata.pGamble, 20, 'filled');
xlabel('alpha'); ylabel('pGamble');
[r,p] = corr(B(:,3), riskdata.pGamble);
title(sprintf('r=%.2f, p=%.3f', r, p));
box off; axis square;

figure;
scatter(B(:,3), riskdata.pGamGain, 20, 'filled');
xlabel('alpha'); ylabel('pGambleGain');
[r,p] = corr(B(:,3), riskdata.pGamGain);
title(sprintf('r=%.2f, p=%.3f', r, p));
box off; axis square;

figure;
scatter(B(:,3), riskdata.pGamMix, 20, 'filled');
xlabel('alpha'); ylabel('pGambleMix');
[r,p] = corr(B(:,3), riskdata.pGamMix);
title(sprintf('r=%.2f, p=%.3f', r, p));
box off; axis square;

mean(riskdata.pGamble); % 60%
mean(riskdata.pGamGain); % 78%
mean(riskdata.pGamMix); % 40%

%% Sanity check: lambda v pGamLoss
figure;
scatter(B(:,2), riskdata.pGamMix, 20, 'filled');
xlabel('lambda'); ylabel('pGambleMix');
[r,p] = corr(B(:,2), riskdata.pGamMix);
title(sprintf('r=%.2f, p=%.3f', r, p));
box off; axis square;

%% Sanity check: Parameter distributions
B = cell2mat(riskdata.b_pt);
params = {'mu','lambda','alpha'};
figure;
for p = 1:3
    subplot(1,3,p);
    histogram(B(:,p));
    xline(mean(B(:,p),   'omitnan'), 'r--', 'LineWidth', 1.5, 'Label', 'Mean');
    xline(median(B(:,p), 'omitnan'), 'b--', 'LineWidth', 1.5, 'Label', 'Median');
    title(params{p}); box off; axis square;
end
sgtitle('PT Model: Parameter distributions');

% Oddly high alphas... mean 1.3... not dirven by just low r2 people
%% Sanity check: pR2 distribution
figure('Color', 'w');
histogram(riskdata.pr2_pt, 80, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'w');
xlim([0,1])
xline(0, 'black', 'Chance', 'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
xline(mean(riskdata.pr2_pt, 'omitnan'), '-b', sprintf('Mean (%.2f)', mean(riskdata.pr2_pt, 'omitnan')), 'LineWidth', 2);
xline(median(riskdata.pr2_pt, 'omitnan'), '-r', sprintf('Median (%.2f)', median(riskdata.pr2_pt, 'omitnan')), 'LineWidth', 2);
title('Model Fit (pR^2)'); xlabel('Predictive Pseudo-R^2'); ylabel('Count'); axis square;

n_below_0 = sum(riskdata.pr2_pt < 0);
n_below_01 = sum(riskdata.pr2_pt < 0.1);

%% Sanity check: Percent choice by SV difference bins
figure;
for s = 1:height(riskdata)
    t = riskdata.gameData{s};
    % SV difference: gain SV - loss SV (columns 3=safe, 4=gain, 5=loss, 6=choice)
    sv_safe = t(:,3);
    sv_lott = t(:,4)*.5 + t(:,5)*.5;
    sv_diff = sv_lott - sv_safe; 
    choice  = t(:,6);
    riskdata.sv_diff{s} = sv_diff;
    riskdata.choice{s}  = choice;
end

all_sv   = cell2mat(riskdata.sv_diff);
all_ch   = cell2mat(riskdata.choice);

% Bin by SV difference
edges    = quantile(all_sv, linspace(0, 1, 11));
binIdx   = discretize(all_sv, edges);
pChoice  = arrayfun(@(b) mean(all_ch(binIdx == b)), 1:10);
binCents = arrayfun(@(b) mean(all_sv(binIdx == b)), 1:10);

plot(binCents, pChoice, 'ko-', 'LineWidth', 2, 'MarkerFaceColor', 'k');
yline(0.5, 'k--'); ylim([0,1])
xlabel('SV difference (gain - loss)'); ylabel('P(gamble)'); title('Choice by SV difference (10 bins)');
axis square;

%% Sanity check: P(gamble) by lottery EV, split by trial type and alpha group
%% Sanity check: Percent choice by SV difference bins
figure;
for s = 1:height(riskdata)
    t = riskdata.gameData(s).data;
    sv_safe = t(:,3);
    sv_lott = t(:,4)*.5 + t(:,5)*.5;
    sv_diff = sv_lott - sv_safe;
    choice  = t(:,6);
    riskdata.sv_diff{s} = sv_diff;
    riskdata.choice{s}  = choice;
end
all_sv   = cell2mat(riskdata.sv_diff);
all_ch   = cell2mat(riskdata.choice);
edges    = quantile(all_sv, linspace(0, 1, 11));
binIdx   = discretize(all_sv, edges);
pChoice  = arrayfun(@(b) mean(all_ch(binIdx == b)), 1:10);
binCents = arrayfun(@(b) mean(all_sv(binIdx == b)), 1:10);
plot(binCents, pChoice, 'ko-', 'LineWidth', 2, 'MarkerFaceColor', 'k');
yline(0.5, 'k--'); ylim([0,1])
xlabel('SV difference (gain - loss)'); ylabel('P(gamble)'); title('Choice by SV difference (10 bins)');
axis square;

%% Sanity check: P(gamble) by lottery EV, split by trial type and alpha group
getType = @(t) (t(:,3) > 0) .* 1 + (t(:,3) == 0) .* 2;
typeLabels = {'Gain only', 'Mixed'};
figure;
for tt = 1:2
    subplot(1,2,tt);
    all_evdiff = []; all_ch = [];
    for s = 1:height(riskdata)
        t = riskdata.gameData(s).data;
        rows = getType(t) == tt;
        ev      = t(rows,4)*0.5 + t(rows,5)*0.5;
        ev_diff = ev - t(rows,3);
        all_evdiff = [all_evdiff; ev_diff];
        all_ch     = [all_ch;     t(rows,6)];
    end
    edges  = quantile(all_evdiff, linspace(0,1,9));
    binIdx = discretize(all_evdiff, edges);
    pCh  = arrayfun(@(b) mean(all_ch(binIdx==b)), 1:8);
    binC = arrayfun(@(b) mean(all_evdiff(binIdx==b)), 1:8);
    plot(binC, pCh, 'o-');
    xline(0, 'k--');
    xlabel('EV difference'); ylabel('P(gamble)'); title(typeLabels{tt});
end

% Gamble by ratio in mixed
all_ratio = []; all_ch = [];
for s = 1:height(riskdata)
    t = riskdata.gameData(s).data;
    rows = t(:,5) ~= 0;
    ratio = t(rows,4) ./ abs(t(rows,5));
    all_ratio = [all_ratio; ratio];
    all_ch    = [all_ch;    t(rows,6)];
end
edges  = quantile(all_ratio, linspace(0,1,9));
binIdx = discretize(all_ratio, edges);
pCh  = arrayfun(@(b) mean(all_ch(binIdx==b)), 1:8);
binC = arrayfun(@(b) mean(all_ratio(binIdx==b)), 1:8);
figure;
plot(binC, pCh, 'o-');
xline(1, 'k--');
xlabel('Gain / |Loss|'); ylabel('P(gamble)'); title('Mixed trials');

figure;
for g = 1:2
    gain_val = [50 80];
    subplot(1,2,g);
    all_ratio = []; all_ch = [];
    for s = 1:height(riskdata)
        t = riskdata.gameData(s).data;
        rows = t(:,4) == gain_val(g);
        ratio = t(rows,4) ./ abs(t(rows,5));
        all_ratio = [all_ratio; ratio];
        all_ch    = [all_ch;    t(rows,6)];
    end
    edges  = quantile(all_ratio, linspace(0,1,9));
    binIdx = discretize(all_ratio, edges);
    pCh  = arrayfun(@(b) mean(all_ch(binIdx==b)), 1:8);
    binC = arrayfun(@(b) mean(all_ratio(binIdx==b)), 1:8);
    plot(binC, pCh, 'o-');
    xline(1, 'k--');
    xlabel('Gain / |Loss|'); ylabel('P(gamble)'); title(sprintf('Gain = %d', gain_val(g)));
end

%% Approach avoidance
% Something must be wrong here
% Alpha is not correlated with pgam at all


% Fit prospect theory (single alpha) model to risk data
clear;clc

% Load risk data
tmp = load("sessionRiskData_all.mat");
riskdata = tmp.riskdata_all;

% Remove people with no game data
riskdata(cellfun(@isempty, riskdata.gameData), :) = [];

% Fit AA model
for s = 1:height(riskdata)
    t = riskdata.gameData{s};
    result_aa = fitmodel_aa(t);
    riskdata.result_aa{s} = result_aa;
    riskdata.b_aa{s}      = result_aa.b;
    riskdata.pr2_aa{s}    = result_aa.pseudoR2;
end

% Add model-free data
riskdata.pGamble = cellfun(@(x) mean(x(:,6)), riskdata.gameData);

% Save
save('fitsessionRiskData_all.mat', 'riskdata');

%% Sanity check: Parameter distributions
B      = cell2mat(riskdata.b_aa);
params = {'mu', 'lambda', 'alpha', 'betagain', 'betaloss'};

figure;
for p = 1:5
    subplot(2,3,p);
    histogram(B(:,p));
    xline(mean(B(:,p),   'omitnan'), 'r--', 'LineWidth', 1.5, 'Label', 'Mean');
    xline(median(B(:,p), 'omitnan'), 'b--', 'LineWidth', 1.5, 'Label', 'Median');
    title(params{p}); box off; axis square;
end
sgtitle('AA Model: Parameter distributions');

%% Sanity check: pR2 distribution
pr2_numeric = cell2mat(riskdata.pr2_aa);

figure('Color', 'w');
histogram(pr2_numeric, 80, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'w');
xlim([0 1]);
xline(0,                             'k',  'Chance',                                           'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
xline(mean(pr2_numeric,   'omitnan'), '-b', sprintf('Mean (%.2f)',   mean(pr2_numeric,   'omitnan')), 'LineWidth', 2);
xline(median(pr2_numeric, 'omitnan'), '-r', sprintf('Median (%.2f)', median(pr2_numeric, 'omitnan')), 'LineWidth', 2);
title('AA Model Fit (pR²)'); xlabel('Pseudo-R²'); ylabel('Count'); axis square;

%% Sanity check: alpha vs pGamble
figure;
scatter(B(:,3), riskdata.pGamble, 20, 'filled');
xlabel('alpha'); ylabel('pGamble');
[r, p] = corr(B(:,3), riskdata.pGamble, 'rows', 'pairwise');
title(sprintf('r=%.2f, p=%.3f', r, p));
box off; axis square;

%% Sanity check: P(gamble) by lottery EV, split by trial type and alpha group
alphas     = B(:, 3);
edges_a    = quantile(alphas, [0 1/3 2/3 1]);
alphaGroup = discretize(alphas, edges_a, 'IncludedEdge', 'right');

groupLabels = {sprintf('Low alpha (<%.2f)',     edges_a(2)), ...
               sprintf('Mid alpha (%.2f-%.2f)', edges_a(2), edges_a(3)), ...
               sprintf('High alpha (>%.2f)',    edges_a(3))};
colors      = {[0.8 0.2 0.2], [0.2 0.6 0.2], [0.2 0.2 0.8]};

getType    = @(t) (t(:,5) == 0) .* 1 + ...
                  (t(:,4) ~= 0 & t(:,5) ~= 0) .* 2;
typeLabels = {'Gain only', 'Mixed'};

figure('Position', [100 100 800 450]);
for tt = 1:2
    subplot(1,2,tt); hold on;
    for g = 1:3
        idx = find(alphaGroup == g);
        all_ev = []; all_ch = [];
        for s = 1:numel(idx)
            t     = riskdata.gameData{idx(s)};
            types = getType(t);
            rows  = types == tt;
            if sum(rows) == 0, continue; end
            all_ev = [all_ev; t(rows,4)*0.5 + t(rows,5)*0.5];
            all_ch = [all_ch; t(rows,6)];
        end
        if isempty(all_ev), continue; end
        edges  = quantile(all_ev, linspace(0,1,9));
        binIdx = discretize(all_ev, edges);
        pCh    = arrayfun(@(b) mean(all_ch(binIdx==b)), 1:8);
        binC   = arrayfun(@(b) mean(all_ev(binIdx==b)), 1:8);
        plot(binC, pCh, 'o-', 'Color', colors{g}, 'LineWidth', 2, ...
             'MarkerFaceColor', colors{g}, 'DisplayName', groupLabels{g});
    end
    yline(0.5, 'k--'); xlabel('Lottery EV'); ylabel('P(gamble)');
    title(typeLabels{tt}); legend('Location', 'best');
    ylim([0 1]); box off; axis square;
end
sgtitle('P(gamble) by lottery EV and alpha group');