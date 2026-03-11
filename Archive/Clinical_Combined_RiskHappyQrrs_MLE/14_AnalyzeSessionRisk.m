% Analyze behavior split by session
clear;clc;
tmp = load("fitsessionRiskHappyData.mat");
riskdata = tmp.riskdata;

%% Extract parameters from b_pt cell array
riskdata.mu      = cellfun(@(x) x(1), riskdata.b_pt);
riskdata.lambda  = cellfun(@(x) x(2), riskdata.b_pt);
riskdata.alpha   = cellfun(@(x) x(3), riskdata.b_pt);
riskdata.logmu   = log(riskdata.mu);
riskdata.cert    = cellfun(@(x) x(1), riskdata.b_evrpe);
riskdata.logcert = log(riskdata.cert);
riskdata.ev      = cellfun(@(x) x(2), riskdata.b_evrpe);
riskdata.logev   = log(riskdata.ev);
riskdata.rpe     = cellfun(@(x) x(3), riskdata.b_evrpe);
riskdata.logrpe  = log(riskdata.rpe);
riskdata.tau     = cellfun(@(x) x(4), riskdata.b_evrpe);
riskdata.logtau  = log(riskdata.tau);
riskdata.const   = cellfun(@(x) x(5), riskdata.b_evrpe);
riskdata.logconst = log(riskdata.const);


% Assign session number per participant FIRST
ids = unique(riskdata.redcapID);
riskdata.sessionNum = zeros(height(riskdata), 1);
for i = 1:numel(ids)
    idx = riskdata.redcapID == ids(i);
    n   = sum(idx);
    riskdata.sessionNum(idx) = (1:n)';
end

% THEN filter
riskdata = riskdata(riskdata.sessionNum <= 14, :);
ids = unique(riskdata.redcapID);

%% Plot parameters over time by participant
params = {'mu', 'logmu', 'lambda', 'alpha', 'pr2_pt', 'pGamble', 'pGamGain', 'pGamMix'...
    'cert', 'logcert', 'ev', 'logev', 'rpe', 'logrpe', 'tau', 'logtau', 'const', 'logconst'};
cmap    = lines(numel(ids));
maxSess = max(riskdata.sessionNum);

for p = 1:length(params)
    figure; hold on;

    for i = 1:numel(ids)
        idx   = riskdata.redcapID == ids(i);
        sess  = riskdata.sessionNum(idx);
        vals  = riskdata.(params{p})(idx);
        [sess, order] = sort(sess);
        vals = vals(order);
        plot(sess, vals, '-o', 'Color', [cmap(i,:) 0.4], 'MarkerSize', 4, 'MarkerFaceColor', cmap(i,:));
    end

    % Mean line binned by session number
    sessNums = unique(riskdata.sessionNum);
    meanVals = arrayfun(@(s) mean(riskdata.(params{p})(riskdata.sessionNum == s & isfinite(riskdata.(params{p}))), 'omitnan'), sessNums);
    nPerSess = arrayfun(@(s) sum(~isnan(riskdata.(params{p})(riskdata.sessionNum == s))), sessNums);

    enough = nPerSess >= 5;
    plot(sessNums(enough), meanVals(enough), 'k-o', 'LineWidth', 2.5, ...
        'MarkerFaceColor', 'k', 'MarkerSize', 6);

    xlim([0.5 maxSess+0.5]);
    xlabel('Session number (per person)');
    ylabel(params{p});
    title(['Parameter over time: ' params{p}]);
    xticks(1:maxSess);
    hold off;
end

%% Change over time with median split (sessions 1-5, 6-10, 11-14 — roughly equal)
riskdata.third = zeros(height(riskdata), 1);
riskdata.third(riskdata.sessionNum <= 5)  = 1;
riskdata.third(riskdata.sessionNum >= 6  & riskdata.sessionNum <= 10) = 2;
riskdata.third(riskdata.sessionNum >= 11) = 3;

for p = 1:length(params)
    fprintf('\n--- %s ---\n', params{p});
    means = arrayfun(@(t) mean(riskdata.(params{p})(riskdata.third == t), 'omitnan'), 1:3);
    fprintf('  Third 1 (1-5): %.3f | Third 2 (6-10): %.3f | Third 3 (11-14): %.3f\n', means(1), means(2), means(3));
    
    g1 = riskdata.(params{p})(riskdata.third == 1);
    g2 = riskdata.(params{p})(riskdata.third == 2);
    g3 = riskdata.(params{p})(riskdata.third == 3);
    g1 = g1(~isnan(g1)); g2 = g2(~isnan(g2)); g3 = g3(~isnan(g3));
    
    [~, p12] = ttest2(g1, g2); 
    [~, p23] = ttest2(g2, g3);
    [~, p13] = ttest2(g1, g3);
    fprintf('  t-test 1v2: p=%.3f | 2v3: p=%.3f | 1v3: p=%.3f\n', p12, p23, p13);
end

% Bar plots 
thirdLabels = {'Sessions 1-5', 'Sessions 6-10', 'Sessions 11-14'};

for p = 1:length(params)
    figure; hold on;

    means = arrayfun(@(t) mean(riskdata.(params{p})(riskdata.third == t), 'omitnan'), 1:3);
    sems  = arrayfun(@(t) std(riskdata.(params{p})(riskdata.third == t), 'omitnan') / ...
                sqrt(sum(~isnan(riskdata.(params{p})(riskdata.third == t)))), 1:3);

    bar(1:3, means, 'FaceColor', [0.6 0.6 0.6], 'EdgeColor', 'k');
    errorbar(1:3, means, sems, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);

    xticks(1:3);
    xticklabels(thirdLabels);
    ylabel(params{p});
    title(['Parameter by session third: ' params{p}]);
    hold off;
end

%% Change over time with median split (dense)
riskdata.densesplit = zeros(height(riskdata), 1);
riskdata.densesplit(ismember(riskdata.sessionNum, [1 2])) = 1;
riskdata.densesplit(ismember(riskdata.sessionNum, [3 4])) = 2;
riskdata.densesplit(ismember(riskdata.sessionNum, [5 6])) = 3;
riskdata.densesplit(ismember(riskdata.sessionNum, [7 8])) = 4;

for p = 1:length(params)
    fprintf('\n--- %s ---\n', params{p});
    means = arrayfun(@(t) mean(riskdata.(params{p})(riskdata.densesplit == t), 'omitnan'), 1:4);
    fprintf('  Bin 1 (1-2): %.3f | Bin 2 (3-4): %.3f | Bin 3 (5-6): %.3f | Bin 4 (7-8): %.3f\n', means(1), means(2), means(3), means(4));
    g1 = riskdata.(params{p})(riskdata.densesplit == 1);
    g2 = riskdata.(params{p})(riskdata.densesplit == 2);
    g3 = riskdata.(params{p})(riskdata.densesplit == 3);
    g4 = riskdata.(params{p})(riskdata.densesplit == 4);
    g1 = g1(~isnan(g1)); g2 = g2(~isnan(g2)); g3 = g3(~isnan(g3)); g4 = g4(~isnan(g4));
    [~, p12] = ttest2(g1, g2);
    [~, p23] = ttest2(g2, g3);
    [~, p34] = ttest2(g3, g4);
    [~, p14] = ttest2(g1, g4);
    fprintf('  t-test 1v2: p=%.3f | 2v3: p=%.3f | 3v4: p=%.3f | 1v4: p=%.3f\n', p12, p23, p34, p14);
end

% Bar plots
denseLabels = {'Sessions 1-2', 'Sessions 3-4', 'Sessions 5-6', 'Sessions 7-8'};
for p = 1:length(params)
    figure; hold on;
    means = arrayfun(@(t) mean(riskdata.(params{p})(riskdata.densesplit == t), 'omitnan'), 1:4);
    sems  = arrayfun(@(t) std(riskdata.(params{p})(riskdata.densesplit == t), 'omitnan') / ...
                sqrt(sum(~isnan(riskdata.(params{p})(riskdata.densesplit == t)))), 1:4);
    bar(1:4, means, 'FaceColor', [0.6 0.6 0.6], 'EdgeColor', 'k');
    errorbar(1:4, means, sems, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);
    xticks(1:4);
    xticklabels(denseLabels);
    ylabel(params{p});
    title(['Parameter by session bin: ' params{p}]);
    hold off;
end


%% Change over time with median split (monthly)
riskdata.latesplit = zeros(height(riskdata), 1);
riskdata.latesplit(ismember(riskdata.sessionNum, [9 10])) = 1;
riskdata.latesplit(ismember(riskdata.sessionNum, [11 12])) = 2;
riskdata.latesplit(ismember(riskdata.sessionNum, [13 14])) = 3;

for p = 1:length(params)
    fprintf('\n--- %s ---\n', params{p});
    means = arrayfun(@(t) mean(riskdata.(params{p})(riskdata.latesplit == t), 'omitnan'), 1:3);
    fprintf('  Bin 1 (9-10): %.3f | Bin 2 (11-12): %.3f | Bin 3 (13-14): %.3f\n', means(1), means(2), means(3));
    g1 = riskdata.(params{p})(riskdata.latesplit == 1);
    g2 = riskdata.(params{p})(riskdata.latesplit == 2);
    g3 = riskdata.(params{p})(riskdata.latesplit == 3);
    g1 = g1(~isnan(g1)); g2 = g2(~isnan(g2)); g3 = g3(~isnan(g3));
    [~, p12] = ttest2(g1, g2);
    [~, p23] = ttest2(g2, g3);
    [~, p13] = ttest2(g1, g3);
    fprintf('  t-test 1v2: p=%.3f | 2v3: p=%.3f | 1v3: p=%.3f\n', p12, p23, p13);
end

% Bar plots
lateLabels = {'Sessions 9-10', 'Sessions 11-12', 'Sessions 13-14'};
for p = 1:length(params)
    figure; hold on;
    means = arrayfun(@(t) mean(riskdata.(params{p})(riskdata.latesplit == t), 'omitnan'), 1:3);
    sems  = arrayfun(@(t) std(riskdata.(params{p})(riskdata.latesplit == t), 'omitnan') / ...
                sqrt(sum(~isnan(riskdata.(params{p})(riskdata.latesplit == t)))), 1:3);
    bar(1:3, means, 'FaceColor', [0.6 0.6 0.6], 'EdgeColor', 'k');
    errorbar(1:3, means, sems, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);
    xticks(1:3);
    xticklabels(lateLabels);
    ylabel(params{p});
    title(['Parameter by late session bin: ' params{p}]);
    hold off;
end

% Results
% None strongly significant
% Alpha is lower in 3 than 1.

%% Linear mixed effects model
% Tests if session number predicts each parameter, accounting for repeated measures
for p = 1:length(params)
    tbl = table(riskdata.redcapID, riskdata.sessionNum, riskdata.(params{p}), ...
        'VariableNames', {'ID', 'session', 'y'});
    tbl = tbl(~isnan(tbl.y), :);
    lme = fitlme(tbl, 'y ~ session + (1|ID)');
    [~, ~, stats] = fixedEffects(lme);
    fprintf('%s: session beta = %.4f, p = %.3f\n', params{p}, stats.Estimate(2), stats.pValue(2));
end

% Significant (small effect sizes) for all besides pGam
%logmu: session beta = 0.0471, p = 0.000
%lambda: session beta = 0.0679, p = 0.000
%alpha: session beta = -0.0027, p = 0.022
%pr2_pt: session beta = 0.0122, p = 0.000
%pGamble: session beta = -0.0062, p = 0.000
%pGamGain: session beta = -0.0001, p = 0.856
%pGamMix: session beta = -0.0122, p = 0.000