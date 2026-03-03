% Analyze behavior split by session
clear;clc;
tmp = load("fitsessionRiskData.mat");
riskdata = tmp.riskdata;

%% Extract parameters from b_pt cell array
riskdata.mu     = cellfun(@(x) x(1), riskdata.b_pt);
riskdata.lambda = cellfun(@(x) x(2), riskdata.b_pt);
riskdata.alpha  = cellfun(@(x) x(3), riskdata.b_pt);
riskdata.mu     = log(riskdata.mu);

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
params = {'mu', 'lambda', 'alpha', 'pr2_pt', 'pGamble', 'pGamGain', 'pGamMix'};
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
    meanVals = arrayfun(@(s) mean(riskdata.(params{p})(riskdata.sessionNum == s), 'omitnan'), sessNums);
    nPerSess = arrayfun(@(s) sum(riskdata.sessionNum == s), sessNums);

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