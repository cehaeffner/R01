% Fit prospect theory (single alpha) model to risk data
clear;clc

% Load risk data and extract data from structure to table format
tmp = load("combinedRiskData_all.mat"); % change
combinedriskdata = tmp.combinedriskdata_all; % change

% Remove 2 people with no game data
combinedriskdata(cellfun(@isempty, combinedriskdata.gameDataStacked), :) = [];

% Fit PT model
for s = 1:height(combinedriskdata)
    t = combinedriskdata.gameDataStacked{s};
    result_pt = fitmodel_PT1alpha(t);
    combinedriskdata.result_pt{s} = result_pt;
    combinedriskdata.b_pt{s} = result_pt.b;
    combinedriskdata.pr2_pt{s} = result_pt.pseudoR2;
end

% Add model-free data
combinedriskdata.pGamble = cellfun(@(x) mean(x(:,6)), combinedriskdata.gameDataStacked);

% Save as .mat
save('fitcombinedRiskData_all.mat', "combinedriskdata") % change

%% Sanity check: alpha v pGam
B = cell2mat(combinedriskdata.b_pt);
figure;
scatter(B(:,3), combinedriskdata.pGamble, 20, 'filled');
xlabel('alpha'); ylabel('pGamble');
[r,p] = corr(B(:,3), combinedriskdata.pGamble);
title(sprintf('r=%.2f, p=%.3f', r, p));
box off; axis square;

%% Sanity check: Parameter distributions
B = cell2mat(combinedriskdata.b_pt);
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

%% Sanity check: pR2 distribution
figure('Color', 'w');
pr2_numeric = cell2mat(combinedriskdata.pr2_pt);
histogram(pr2_numeric, 80, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'w');
xlim([0,1])
xline(0, 'black', 'Chance', 'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
xline(mean(pr2_numeric, 'omitnan'), '-b', sprintf('Mean (%.2f)', mean(pr2_numeric, 'omitnan')), 'LineWidth', 2);
xline(median(pr2_numeric, 'omitnan'), '-r', sprintf('Median (%.2f)', median(pr2_numeric, 'omitnan')), 'LineWidth', 2);
title('Model Fit (pR^2)'); xlabel('Predictive Pseudo-R^2'); ylabel('Count'); axis square;

n_below_0 = sum(pr2_numeric < 0);
n_below_01 = sum(pr2_numeric < 0.1);

%% Sanity check: Percent choice by SV difference bins
figure;
for s = 1:height(combinedriskdata)
    t = combinedriskdata.gameDataStacked{s};
    % SV difference: gain SV - loss SV (columns 3=safe, 4=gain, 5=loss, 6=choice)
    sv_safe = t(:,3);
    sv_lott = t(:,4)*.5 + t(:,5)*.5;
    sv_diff = sv_lott - sv_safe; 
    choice  = t(:,6);
    combinedriskdata.sv_diff{s} = sv_diff;
    combinedriskdata.choice{s}  = choice;
end

all_sv   = cell2mat(combinedriskdata.sv_diff);
all_ch   = cell2mat(combinedriskdata.choice);

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
B       = cell2mat(combinedriskdata.b_pt);
alphas  = B(:, 3);
edges_a = quantile(alphas, [0 1/3 2/3 1]);
alphaGroup = discretize(alphas, edges_a, 'IncludedEdge', 'right');

groupLabels = {sprintf('Low alpha (<%.2f)',     edges_a(2)), ...
               sprintf('Mid alpha (%.2f-%.2f)', edges_a(2), edges_a(3)), ...
               sprintf('High alpha (>%.2f)',    edges_a(3))};
colors      = {[0.8 0.2 0.2], [0.2 0.6 0.2], [0.2 0.2 0.8]};

getType    = @(t) (t(:,5) == 0) .* 1 + ...
                  (t(:,4) ~= 0 & t(:,5) ~= 0) .* 2;
typeLabels = {'Gain only', 'Mixed'};

figure('Position', [100 100 800 450]);

for tt = 1:2        % <-- was 1:3
    subplot(1, 2, tt); hold on;

    for g = 1:3     % <-- was 1:2
        idx    = find(alphaGroup == g);
        all_ev = []; all_ch = [];

        for s = 1:numel(idx)
            t     = combinedriskdata.gameDataStacked{idx(s)};
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

%% Single subject: raw choices by safe value and lottery EV
s = 300; % change subject index

t      = combinedriskdata.gameDataStacked{s};
B      = combinedriskdata.b_pt{s};
alpha  = B(3);
lambda = B(2);
r2 = combinedriskdata.pr2_pt{s};

gainRows  = t(:,5) == 0;
mixRows   = t(:,4) ~= 0 & t(:,5) ~= 0;

gain_safe   = t(gainRows, 3);
gain_ev     = t(gainRows, 4) * 0.5;
gain_choice = t(gainRows, 6);
safe_levels = unique(gain_safe);

mix_ev     = t(mixRows, 4)*0.5 + t(mixRows, 5)*0.5;
mix_choice = t(mixRows, 6);

nSafe = numel(safe_levels);
figure('Position', [100 100 300*(nSafe+1) 400]);
tiledlayout(1, nSafe+1, 'TileSpacing', 'compact');

% One subplot per safe value for gain trials
for sl = 1:nSafe
    nexttile; hold on;
    idx = gain_safe == safe_levels(sl);
    [ev_sorted, order] = sort(gain_ev(idx));
    ch_sorted = gain_choice(idx); ch_sorted = ch_sorted(order);
    plot(ev_sorted, ch_sorted, 'ko-', 'LineWidth', 1.5, 'MarkerFaceColor', 'k');
    yline(0.5, 'k--');
    xline(safe_levels(sl), 'b--', 'LineWidth', 1.5);
    xlabel('Lottery EV'); ylabel('Choice (0=safe, 1=gamble)');
    title(sprintf('Gain Safe=%g', safe_levels(sl)));
    ylim([-0.1 1.1]); yticks([0 1]); box off;
end

% Single subplot for mixed trials
nexttile; hold on;
[ev_sorted, order] = sort(mix_ev);
ch_sorted = mix_choice(order);
plot(ev_sorted, ch_sorted, 'ro-', 'LineWidth', 1.5, 'MarkerFaceColor', 'r');
yline(0.5, 'k--');
xline(0, 'b--', 'LineWidth', 1.5); 
xlabel('Lottery EV'); ylabel('Choice (0=safe, 1=gamble)');
title('Mixed');
ylim([-0.1 1.1]); yticks([0 1]); box off;

sgtitle(sprintf('Subject %d | alpha=%.2f, lambda=%.2f, R²=%.2f', s, alpha, lambda, r2));

%% Approach avoidance
% Something must be wrong here
% Alpha is not correlated with pgam at all


% Fit prospect theory (single alpha) model to risk data
clear;clc

% Load risk data
tmp = load("combinedRiskData_all.mat");
combinedriskdata = tmp.combinedriskdata_all;

% Remove people with no game data
combinedriskdata(cellfun(@isempty, combinedriskdata.gameDataStacked), :) = [];

% Fit AA model
for s = 1:height(combinedriskdata)
    t = combinedriskdata.gameDataStacked{s};
    result_aa = fitmodel_aa(t);
    combinedriskdata.result_aa{s} = result_aa;
    combinedriskdata.b_aa{s}      = result_aa.b;
    combinedriskdata.pr2_aa{s}    = result_aa.pseudoR2;
end

% Add model-free data
combinedriskdata.pGamble = cellfun(@(x) mean(x(:,6)), combinedriskdata.gameDataStacked);

% Save
save('fitcombinedRiskData_all.mat', 'combinedriskdata');

%% Sanity check: Parameter distributions
B      = cell2mat(combinedriskdata.b_aa);
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
pr2_numeric = cell2mat(combinedriskdata.pr2_aa);

figure('Color', 'w');
histogram(pr2_numeric, 80, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'w');
xlim([0 1]);
xline(0,                             'k',  'Chance',                                           'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
xline(mean(pr2_numeric,   'omitnan'), '-b', sprintf('Mean (%.2f)',   mean(pr2_numeric,   'omitnan')), 'LineWidth', 2);
xline(median(pr2_numeric, 'omitnan'), '-r', sprintf('Median (%.2f)', median(pr2_numeric, 'omitnan')), 'LineWidth', 2);
title('AA Model Fit (pR²)'); xlabel('Pseudo-R²'); ylabel('Count'); axis square;

%% Sanity check: alpha vs pGamble
figure;
scatter(B(:,3), combinedriskdata.pGamble, 20, 'filled');
xlabel('alpha'); ylabel('pGamble');
[r, p] = corr(B(:,3), combinedriskdata.pGamble, 'rows', 'pairwise');
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
            t     = combinedriskdata.gameDataStacked{idx(s)};
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

%% Sanity check: Single subject raw choices
s = 1; % change subject index

t      = combinedriskdata.gameDataStacked{s};
B_s    = combinedriskdata.b_aa{s};
alpha  = B_s(3);
lambda = B_s(2);
r2     = combinedriskdata.pr2_aa{s};

gainRows    = t(:,5) == 0;
mixRows     = t(:,4) ~= 0 & t(:,5) ~= 0;
gain_safe   = t(gainRows, 3);
gain_ev     = t(gainRows, 4) * 0.5;
gain_choice = t(gainRows, 6);
safe_levels = unique(gain_safe);
mix_ev      = t(mixRows, 4)*0.5 + t(mixRows, 5)*0.5;
mix_choice  = t(mixRows, 6);

nSafe = numel(safe_levels);
figure('Position', [100 100 300*(nSafe+1) 400]);
tiledlayout(1, nSafe+1, 'TileSpacing', 'compact');

for sl = 1:nSafe
    nexttile; hold on;
    idx = gain_safe == safe_levels(sl);
    [ev_sorted, order] = sort(gain_ev(idx));
    ch_sorted = gain_choice(idx); ch_sorted = ch_sorted(order);
    plot(ev_sorted, ch_sorted, 'ko-', 'LineWidth', 1.5, 'MarkerFaceColor', 'k');
    yline(0.5, 'k--');
    xline(safe_levels(sl), 'b--', 'LineWidth', 1.5);
    xlabel('Lottery EV'); ylabel('Choice (0=safe, 1=gamble)');
    title(sprintf('Gain | Safe=%g', safe_levels(sl)));
    ylim([-0.1 1.1]); yticks([0 1]); box off;
end

nexttile; hold on;
[ev_sorted, order] = sort(mix_ev);
ch_sorted = mix_choice(order);
plot(ev_sorted, ch_sorted, 'ro-', 'LineWidth', 1.5, 'MarkerFaceColor', 'r');
yline(0.5, 'k--');
xlabel('Lottery EV'); ylabel('Choice (0=safe, 1=gamble)');
title('Mixed'); ylim([-0.1 1.1]); yticks([0 1]); box off;

sgtitle(sprintf('Subject %d | alpha=%.2f, lambda=%.2f, R²=%.2f', s, alpha, lambda, r2));