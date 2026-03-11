% Analyze how combined fit data correlates with motivation and state
% questionnaires, across datasets and R2 filters
clear; clc; close all;

% Define datasets, filters, parameters, and questionnaires to loop over
datasets   = {'dense', 'all', 'monthly'};
r2_threshs = [-8, 0.1];
params     = {'alpha', 'lambda', 'pGamble', 'mu'};
q_vars     = {'mean_masqscore','mean_bamiscore','mean_phq9score','mean_gad7score',...
              'mean_worriedscore','mean_posemoscore','mean_negemoscore','phq8_scid'};
q_labels   = {'MASQ','BAMI','PHQ9','GAD7','Worry','PosEmo','NegEmo','PHQ8-SCID'};
q_src      = {'masqbami','masqbami','phq9gad7','phq9gad7','state','state','state','phq9gad7'};

% Preallocate results matrices (rows = param x questionnaire, cols = dataset x r2 filter)
n_cond = numel(datasets) * numel(r2_threshs);
n_rows = numel(params) * numel(q_vars);
rho_mat    = nan(n_rows, n_cond);
p_mat      = nan(n_rows, n_cond);
col_labels = {};

% Load risk data
tmp = load("fitcombinedRiskData_dense.mat");
fitcombinedriskdata_dense   = tmp.combinedriskdata;
tmp = load("fitcombinedRiskData_all.mat");
fitcombinedriskdata_all     = tmp.combinedriskdata;
tmp = load("fitcombinedRiskData_monthly.mat");
fitcombinedriskdata_monthly = tmp.combinedriskdata;

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

% Pack into structs for loop access
riskdata_map = struct('dense', fitcombinedriskdata_dense, ...
                      'all',   fitcombinedriskdata_all, ...
                      'monthly', fitcombinedriskdata_monthly);
survey_map = struct( ...
    'dense',   struct('phq9gad7', combinedphq9gad7_dense,   'masqbami', combinedmasqbami_dense,   'state', combinedstate_dense), ...
    'all',     struct('phq9gad7', combinedphq9gad7_all,     'masqbami', combinedmasqbami_all,     'state', combinedstate_all), ...
    'monthly', struct('phq9gad7', combinedphq9gad7_monthly, 'masqbami', combinedmasqbami_monthly, 'state', combinedstate_monthly));

% Loop over datasets and R2 filters, join tables, run correlations
col = 0;
for di = 1:numel(datasets)
    tag = datasets{di};

    % Extract model parameters from risk data
    rd = riskdata_map.(tag);
    rd.mu     = cellfun(@(x) x(1), rd.b_pt);
    rd.lambda = cellfun(@(x) x(2), rd.b_pt);
    rd.alpha  = cellfun(@(x) x(3), rd.b_pt);

    % Get survey tables for this dataset
    T = survey_map.(tag);

    for ri = 1:numel(r2_threshs)
        col = col + 1;
        col_labels{col} = sprintf('%s R2>%g', tag, r2_threshs(ri));

        % Filter by R2 and join risk data with each survey table
        rd_filt = rd(cell2mat(rd.pr2_pt) > r2_threshs(ri), :);
        joined.phq9gad7 = outerjoin(T.phq9gad7, rd_filt, 'Keys','redcapID','MergeKeys',true);
        joined.masqbami = outerjoin(T.masqbami,  rd_filt, 'Keys','redcapID','MergeKeys',true);
        joined.state    = outerjoin(T.state,     rd_filt, 'Keys','redcapID','MergeKeys',true);

        % Run all correlations
        row = 0;
        for pi = 1:numel(params)
            for qi = 1:numel(q_vars)
                row = row + 1;
                tbl = joined.(q_src{qi});
                x = tbl.(q_vars{qi}); y = tbl.(params{pi});
                if iscell(x), x = cell2mat(x); end
                if iscell(y), y = cell2mat(y); end
                ok = ~isnan(x) & ~isnan(y);
                if sum(ok) < 10, continue; end
                [rho_mat(row,col), p_mat(row,col)] = corr(x(ok), y(ok), 'Type','Spearman');
            end
        end
    end
end

%% Plot heatmap summarizing significance across all conditions
% Convert p-values to significance codes: -1=no data, 0=NS, 1=marginal, 2=sig
sig = zeros(size(p_mat));
sig(p_mat < 0.1)  = 1;
sig(p_mat < 0.05) = 2;
sig(isnan(p_mat)) = -1;

% Build row labels
row_labels = {};
for pi = 1:numel(params)
    for qi = 1:numel(q_vars)
        row_labels{end+1} = sprintf('%s x %s', params{pi}, q_labels{qi});
    end
end

figure('Position',[100 100 900 600],'Color','w');
imagesc(sig, [-1 2]);
colormap([0.7 0.7 0.7; 0.93 0.93 0.93; 1 0.85 0.2; 0.2 0.75 0.35]); % gray/NS/marginal/sig

% Overlay rho values (black if sig, gray otherwise)
for r = 1:n_rows
    for c = 1:n_cond
        if ~isnan(rho_mat(r,c))
            clr = [0.4 0.4 0.4];
            if p_mat(r,c) < 0.05, clr = 'k'; end
            text(c, r, sprintf('%.2f', rho_mat(r,c)), ...
                'HorizontalAlignment','center','FontSize',7,'Color',clr);
        end
    end
end

% Dividing lines between parameter groups and datasets
hold on;
for pi = 1:numel(params)-1
    yline(pi*numel(q_vars)+0.5, 'k-', 'LineWidth', 1.5);
end
for di = 1:numel(datasets)-1
    xline(di*numel(r2_threshs)+0.5, 'k-', 'LineWidth', 1.5);
end

set(gca, 'XTick',1:n_cond, 'XTickLabel',col_labels, 'XAxisLocation','top', ...
         'YTick',1:n_rows,  'YTickLabel',row_labels,  'TickLabelInterpreter','none', ...
         'FontSize',8);
xtickangle(30);

cb = colorbar; cb.Ticks = [-0.625 0.125 0.875 1.625];
cb.TickLabels = {'No data','NS','Marginal','Sig'};
title('Spearman correlations: risk params x questionnaires','FontWeight','bold');
saveas(gcf, 'riskCorrelations_heatmap.png');

%% Median split symptom levels prep
fitcombinedriskdata_all.mu = cellfun(@(x) x(1), fitcombinedriskdata_all.b_pt);
fitcombinedriskdata_all.lambda = cellfun(@(x) x(2), fitcombinedriskdata_all.b_pt);
fitcombinedriskdata_all.alpha = cellfun(@(x) x(3), fitcombinedriskdata_all.b_pt);

masqbamirisk = innerjoin(fitcombinedriskdata_all, combinedmasqbami_all, 'Keys', 'redcapID');
phq9gad7risk = innerjoin(fitcombinedriskdata_all, combinedphq9gad7_all, 'Keys', 'redcapID');
staterisk = innerjoin(fitcombinedriskdata_all, combinedstate_all, 'Keys', 'redcapID');

masqMedian = median(masqbamirisk.mean_masqscore);
bamiMedian = median(masqbamirisk.mean_bamiscore);
phq9Median = median(phq9gad7risk.mean_phq9score);
gad7Median = median(phq9gad7risk.mean_gad7score);
worriedMedian = median(staterisk.mean_worriedscore);
mentalhealthMedian = median(staterisk.mean_mentalhealthscore);
posemoMedian = median(staterisk.mean_posemoscore);
negemoMedian = median(staterisk.mean_negemoscore);

masqbamirisk.masqGroup = categorical(masqbamirisk.mean_masqscore > masqMedian, [0 1], {'low', 'high'});
masqbamirisk.bamiGroup = categorical(masqbamirisk.mean_bamiscore > bamiMedian, [0 1], {'low', 'high'});
phq9gad7risk.phq9Group = categorical(phq9gad7risk.mean_phq9score > phq9Median, [0 1], {'low', 'high'});
phq9gad7risk.gad7Group = categorical(phq9gad7risk.mean_gad7score > gad7Median, [0 1], {'low', 'high'});
staterisk.mentalhealthGroup = categorical(staterisk.mean_mentalhealthscore > worriedMedian, [0 1], {'low', 'high'});
staterisk.worriedGroup = categorical(staterisk.mean_worriedscore > worriedMedian, [0 1], {'low', 'high'});
staterisk.posemoGroup = categorical(staterisk.mean_posemoscore > posemoMedian, [0 1], {'low', 'high'});
staterisk.negemoGroup = categorical(staterisk.mean_negemoscore > negemoMedian, [0 1], {'low', 'high'});

% 208 people per group for masq/phq9/gad7/bami
% 211/200 per group for pos emo (low/high)
% 206/205 per group for neg emo (low/high)
% 209/202 per group for worried (low/high)
% 165/246 per group for mental health (low/high)

scales = {
    masqbamirisk, 'masqGroup',         'MASQ';
    masqbamirisk, 'bamiGroup',         'BAMI';
    phq9gad7risk, 'phq9Group',         'PHQ9';
    phq9gad7risk, 'gad7Group',         'GAD7';
    staterisk,    'worriedGroup',      'Worry';
    staterisk,    'posemoGroup',       'PosEmo';
    staterisk,    'negemoGroup',       'NegEmo';
    staterisk,    'mentalhealthGroup', 'MentalHealth'
};

%% Median split symptom levels 

for p = 1:length(params)
    figure;
    allMeans = zeros(2, size(scales,1));
    allSEMs  = zeros(2, size(scales,1));
    
    for s = 1:size(scales,1)
        tbl = scales{s,1};
        grp = scales{s,2};
        stats = grpstats(tbl(:, {params{p}, grp}), grp, {'mean','sem'});
        allMeans(:,s) = stats.(['mean_' params{p}]);
        allSEMs(:,s)  = stats.(['sem_' params{p}]);
        % t-test
        lowData  = tbl.(params{p})(tbl.(grp) == 'low');
        highData = tbl.(params{p})(tbl.(grp) == 'high');
        [~, pval, ~, tstat] = ttest2(lowData, highData);
        fprintf('%s | %s: t(%.0f) = %.3f, p = %.3f\n', params{p}, scales{s,3}, tstat.df, tstat.tstat, pval);
    end
    
    bar(allMeans');
    hold on;
    % error bars
    nGroups = size(allMeans,2);
    groupWidth = min(0.8, 2/(2+1.5));
    for g = 1:2
        x = (1:nGroups) - groupWidth/2 + (2*g-1)*groupWidth/4;
        errorbar(x, allMeans(g,:), allSEMs(g,:), 'k', 'LineStyle','none');
    end
    
    xticklabels(scales(:,3));
    xtickangle(45);
    legend({'low','high'});
    title(params{p});
    ylabel('Parameter Value');
    hold off;
end

%figure;
%stats = grpstats(masqbamirisk(:, {'lambda', 'masqGroup'}), 'masqGroup', {'mean', 'sem'});
%bar(stats.mean_lambda);
%hold on;
%errorbar(1:2, stats.mean_mu, stats.sem_mu, 'k', 'LineStyle', 'none');
%xticklabels(stats.masqGroup);
%ylabel('Mean ± SEM');
%title('lambda by MASQ group');
%hold off;

%% Median split symptom levels prep - MONTHLY
fitcombinedriskdata_monthly.mu = cellfun(@(x) x(1), fitcombinedriskdata_monthly.b_pt);
fitcombinedriskdata_monthly.lambda = cellfun(@(x) x(2), fitcombinedriskdata_monthly.b_pt);
fitcombinedriskdata_monthly.alpha = cellfun(@(x) x(3), fitcombinedriskdata_monthly.b_pt);
masqbamirisk_monthly = innerjoin(fitcombinedriskdata_monthly, combinedmasqbami_all, 'Keys', 'redcapID');
phq9gad7risk_monthly = innerjoin(fitcombinedriskdata_monthly, combinedphq9gad7_all, 'Keys', 'redcapID');
staterisk_monthly    = innerjoin(fitcombinedriskdata_monthly, combinedstate_all, 'Keys', 'redcapID');

masqMedian_monthly         = median(masqbamirisk_monthly.mean_masqscore);
bamiMedian_monthly         = median(masqbamirisk_monthly.mean_bamiscore);
phq9Median_monthly         = median(phq9gad7risk_monthly.mean_phq9score);
gad7Median_monthly         = median(phq9gad7risk_monthly.mean_gad7score);
worriedMedian_monthly      = median(staterisk_monthly.mean_worriedscore);
mentalhealthMedian_monthly = median(staterisk_monthly.mean_mentalhealthscore);
posemoMedian_monthly       = median(staterisk_monthly.mean_posemoscore);
negemoMedian_monthly       = median(staterisk_monthly.mean_negemoscore);

masqbamirisk_monthly.masqGroup         = categorical(masqbamirisk_monthly.mean_masqscore > masqMedian_monthly, [0 1], {'low', 'high'});
masqbamirisk_monthly.bamiGroup         = categorical(masqbamirisk_monthly.mean_bamiscore > bamiMedian_monthly, [0 1], {'low', 'high'});
phq9gad7risk_monthly.phq9Group         = categorical(phq9gad7risk_monthly.mean_phq9score > phq9Median_monthly, [0 1], {'low', 'high'});
phq9gad7risk_monthly.gad7Group         = categorical(phq9gad7risk_monthly.mean_gad7score > gad7Median_monthly, [0 1], {'low', 'high'});
staterisk_monthly.mentalhealthGroup    = categorical(staterisk_monthly.mean_mentalhealthscore > mentalhealthMedian_monthly, [0 1], {'low', 'high'});
staterisk_monthly.worriedGroup         = categorical(staterisk_monthly.mean_worriedscore > worriedMedian_monthly, [0 1], {'low', 'high'});
staterisk_monthly.posemoGroup          = categorical(staterisk_monthly.mean_posemoscore > posemoMedian_monthly, [0 1], {'low', 'high'});
staterisk_monthly.negemoGroup          = categorical(staterisk_monthly.mean_negemoscore > negemoMedian_monthly, [0 1], {'low', 'high'});

scales_monthly = {
    masqbamirisk_monthly, 'masqGroup',         'MASQ';
    masqbamirisk_monthly, 'bamiGroup',         'BAMI';
    phq9gad7risk_monthly, 'phq9Group',         'PHQ9';
    phq9gad7risk_monthly, 'gad7Group',         'GAD7';
    staterisk_monthly,    'worriedGroup',      'Worry';
    staterisk_monthly,    'posemoGroup',       'PosEmo';
    staterisk_monthly,    'negemoGroup',       'NegEmo';
    staterisk_monthly,    'mentalhealthGroup', 'MentalHealth'
};

%% Median split symptom levels - MONTHLY
for p = 1:length(params)
    figure;
    allMeans = zeros(2, size(scales_monthly,1));
    allSEMs  = zeros(2, size(scales_monthly,1));

    for s = 1:size(scales_monthly,1)
        tbl = scales_monthly{s,1};
        grp = scales_monthly{s,2};
        stats = grpstats(tbl(:, {params{p}, grp}), grp, {'mean','sem'});
        allMeans(:,s) = stats.(['mean_' params{p}]);
        allSEMs(:,s)  = stats.(['sem_' params{p}]);

        lowData  = tbl.(params{p})(tbl.(grp) == 'low');
        highData = tbl.(params{p})(tbl.(grp) == 'high');
        [~, pval, ~, tstat] = ttest2(lowData, highData);
        fprintf('[MONTHLY] %s | %s: t(%.0f) = %.3f, p = %.3f\n', params{p}, scales_monthly{s,3}, tstat.df, tstat.tstat, pval);
    end

    bar(allMeans');
    hold on;
    nGroups = size(allMeans,2);
    groupWidth = min(0.8, 2/(2+1.5));
    for g = 1:2
        x = (1:nGroups) - groupWidth/2 + (2*g-1)*groupWidth/4;
        errorbar(x, allMeans(g,:), allSEMs(g,:), 'k', 'LineStyle','none');
    end
    xticklabels(scales_monthly(:,3));
    xtickangle(45);
    legend({'low','high'});
    title(['[Monthly] ' params{p}]);
    ylabel('Parameter Value');
    hold off;
end


%% Median split symptom levels prep - DENSE
fitcombinedriskdata_dense.mu = cellfun(@(x) x(1), fitcombinedriskdata_dense.b_pt);
fitcombinedriskdata_dense.lambda = cellfun(@(x) x(2), fitcombinedriskdata_dense.b_pt);
fitcombinedriskdata_dense.alpha = cellfun(@(x) x(3), fitcombinedriskdata_dense.b_pt);

masqbamirisk_dense = innerjoin(fitcombinedriskdata_dense, combinedmasqbami_all, 'Keys', 'redcapID');
phq9gad7risk_dense = innerjoin(fitcombinedriskdata_dense, combinedphq9gad7_all, 'Keys', 'redcapID');
staterisk_dense    = innerjoin(fitcombinedriskdata_dense, combinedstate_all, 'Keys', 'redcapID');

masqMedian_dense         = median(masqbamirisk_dense.mean_masqscore);
bamiMedian_dense         = median(masqbamirisk_dense.mean_bamiscore);
phq9Median_dense         = median(phq9gad7risk_dense.mean_phq9score);
gad7Median_dense         = median(phq9gad7risk_dense.mean_gad7score);
worriedMedian_dense      = median(staterisk_dense.mean_worriedscore);
mentalhealthMedian_dense = median(staterisk_dense.mean_mentalhealthscore);
posemoMedian_dense       = median(staterisk_dense.mean_posemoscore);
negemoMedian_dense       = median(staterisk_dense.mean_negemoscore);

masqbamirisk_dense.masqGroup         = categorical(masqbamirisk_dense.mean_masqscore > masqMedian_dense, [0 1], {'low', 'high'});
masqbamirisk_dense.bamiGroup         = categorical(masqbamirisk_dense.mean_bamiscore > bamiMedian_dense, [0 1], {'low', 'high'});
phq9gad7risk_dense.phq9Group         = categorical(phq9gad7risk_dense.mean_phq9score > phq9Median_dense, [0 1], {'low', 'high'});
phq9gad7risk_dense.gad7Group         = categorical(phq9gad7risk_dense.mean_gad7score > gad7Median_dense, [0 1], {'low', 'high'});
staterisk_dense.mentalhealthGroup    = categorical(staterisk_dense.mean_mentalhealthscore > mentalhealthMedian_dense, [0 1], {'low', 'high'});
staterisk_dense.worriedGroup         = categorical(staterisk_dense.mean_worriedscore > worriedMedian_dense, [0 1], {'low', 'high'});
staterisk_dense.posemoGroup          = categorical(staterisk_dense.mean_posemoscore > posemoMedian_dense, [0 1], {'low', 'high'});
staterisk_dense.negemoGroup          = categorical(staterisk_dense.mean_negemoscore > negemoMedian_dense, [0 1], {'low', 'high'});

scales_dense = {
    masqbamirisk_dense, 'masqGroup',         'MASQ';
    masqbamirisk_dense, 'bamiGroup',         'BAMI';
    phq9gad7risk_dense, 'phq9Group',         'PHQ9';
    phq9gad7risk_dense, 'gad7Group',         'GAD7';
    staterisk_dense,    'worriedGroup',      'Worry';
    staterisk_dense,    'posemoGroup',       'PosEmo';
    staterisk_dense,    'negemoGroup',       'NegEmo';
    staterisk_dense,    'mentalhealthGroup', 'MentalHealth'
};

%% Median split symptom levels - DENSE
for p = 1:length(params)
    figure;
    allMeans = zeros(2, size(scales_dense,1));
    allSEMs  = zeros(2, size(scales_dense,1));

    for s = 1:size(scales_dense,1)
        tbl = scales_dense{s,1};
        grp = scales_dense{s,2};
        stats = grpstats(tbl(:, {params{p}, grp}), grp, {'mean','sem'});
        allMeans(:,s) = stats.(['mean_' params{p}]);
        allSEMs(:,s)  = stats.(['sem_' params{p}]);

        lowData  = tbl.(params{p})(tbl.(grp) == 'low');
        highData = tbl.(params{p})(tbl.(grp) == 'high');
        [~, pval, ~, tstat] = ttest2(lowData, highData);
        fprintf('[DENSE] %s | %s: t(%.0f) = %.3f, p = %.3f\n', params{p}, scales_dense{s,3}, tstat.df, tstat.tstat, pval);
    end

    bar(allMeans');
    hold on;
    nGroups = size(allMeans,2);
    groupWidth = min(0.8, 2/(2+1.5));
    for g = 1:2
        x = (1:nGroups) - groupWidth/2 + (2*g-1)*groupWidth/4;
        errorbar(x, allMeans(g,:), allSEMs(g,:), 'k', 'LineStyle','none');
    end
    xticklabels(scales_dense(:,3));
    xtickangle(45);
    legend({'low','high'});
    title(['[Dense] ' params{p}]);
    ylabel('Parameter Value');
    hold off;
end

%% Kathy - age and phq9 and pGamMix
phq9risk_all = innerjoin(combinedphq9gad7_all, fitcombinedriskdata_all, 'Keys','redcapID');

% Mixed effects model: pGamMix ~ phq9 * age + (1|redcapID)
tbl = table(phq9risk_all.redcapID, phq9risk_all.mean_phq9score, phq9risk_all.age_dense, phq9risk_all.pGamMix, ...
    'VariableNames', {'ID', 'phq9', 'age', 'y'});
tbl = tbl(~any(ismissing(tbl), 2), :);

lme = fitlme(tbl, 'y ~ phq9 * age + (1|ID)');
disp(lme);

%% Kathy - Filter out remote-only
riskdata_mri_only = phq9risk_all(~ismissing(phq9risk_all.phq8_scid), :);

% Mixed effects model: pGamMix ~ phq9 * age + (1|redcapID)
tbl = table(riskdata_mri_only.redcapID, riskdata_mri_only.mean_phq9score, riskdata_mri_only.age_dense, riskdata_mri_only.pGamMix, ...
    'VariableNames', {'ID', 'phq9', 'age', 'y'});
tbl = tbl(~any(ismissing(tbl), 2), :);

lme = fitlme(tbl, 'y ~ phq9 * age + (1|ID)');
disp(lme);

%% Looking at my analyses but in the subset
riskdata_mri_only.mu = cellfun(@(x) x(1), riskdata_mri_only.b_pt);
riskdata_mri_only.lambda = cellfun(@(x) x(2), riskdata_mri_only.b_pt);
riskdata_mri_only.alpha = cellfun(@(x) x(3), riskdata_mri_only.b_pt);


[rho,p] = corr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.mu); %NS
[rho,p] = corr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.lambda); %NS
[rho,p] = corr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.alpha); %NS
[rho,p] = corr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.pGamMix); %NS


[rho,p] = corr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.mu); %NS
[rho,p] = corr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.lambda); %NS
[rho,p] = corr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.alpha); %NS
[rho,p] = corr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.pGamMix); %NS

% Partial corr
% PHQ-9
[rho, p] = partialcorr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.mu,      riskdata_mri_only.gender); %NS
[rho, p] = partialcorr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.lambda,   riskdata_mri_only.gender); %NS
[rho, p] = partialcorr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.alpha,    riskdata_mri_only.gender); %NS
[rho, p] = partialcorr(riskdata_mri_only.mean_phq9score, riskdata_mri_only.pGamMix,  riskdata_mri_only.gender); %NS

% GAD-7
[rho, p] = partialcorr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.mu,      riskdata_mri_only.gender); %NS
[rho, p] = partialcorr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.lambda,   riskdata_mri_only.gender); %NS
[rho, p] = partialcorr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.alpha,    riskdata_mri_only.gender); %NS
[rho, p] = partialcorr(riskdata_mri_only.mean_gad7score, riskdata_mri_only.pGamMix,  riskdata_mri_only.gender); %NS

%% SD

% PHQ-9 SD
riskdata_mri_only.phq9_sd = NaN(height(riskdata_mri_only), 1);
for i = 1:height(riskdata_mri_only)
    scores = riskdata_mri_only.list_phq9score{i};
    if numel(scores) >= 3
        riskdata_mri_only.phq9_sd(i) = std(scores);
    end
end
sub_phq = riskdata_mri_only(~isnan(riskdata_mri_only.phq9_sd), :);

[rho, p] = corr(sub_phq.phq9_sd, sub_phq.mu); %rho=0.1 p = 0.09
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.lambda); %ns
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.alpha); %rho=-0.13
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.pGamMix); %ns
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.pGamGain); %rho=-0.1563,p=0.0248

% GAD-7 SD
riskdata_mri_only.gad7_sd = NaN(height(riskdata_mri_only), 1);
for i = 1:height(riskdata_mri_only)
    scores = riskdata_mri_only.list_gad7score{i};
    if numel(scores) >= 3
        riskdata_mri_only.gad7_sd(i) = std(scores);
    end
end
sub_gad = riskdata_mri_only(~isnan(riskdata_mri_only.gad7_sd), :);

[rho, p] = corr(sub_gad.gad7_sd, sub_gad.mu); %ns
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.lambda); %ns
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.alpha); %ns
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.pGamMix); %ns
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.pGamGain); %rho=-0.1367, p=0.0501

% More qrres
riskdata_mri_only_allqrres = innerjoin()

%%
% PHQ-9 SD
phq9risk_all.mu = cellfun(@(x) x(1), phq9risk_all.b_pt);
phq9risk_all.lambda = cellfun(@(x) x(2), phq9risk_all.b_pt);
phq9risk_all.alpha = cellfun(@(x) x(3), phq9risk_all.b_pt);

phq9risk_all.phq9_sd = NaN(height(phq9risk_all), 1);
for i = 1:height(phq9risk_all)
    scores = phq9risk_all.list_phq9score{i};
    if numel(scores) >= 3
        phq9risk_all.phq9_sd(i) = std(scores);
    end
end
sub_phq = phq9risk_all(~isnan(phq9risk_all.phq9_sd), :);

[rho, p] = corr(sub_phq.phq9_sd, sub_phq.mu); %ns
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.lambda); %ns
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.alpha); %rho=-0.12,p=0.0316
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.pGamMix); %ns
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.pGamGain); %rho=-0.1288,p=0.0214
[rho, p] = corr(sub_phq.phq9_sd, sub_phq.pGamble); %ns


% GAD-7 SD
phq9risk_all.gad7_sd = NaN(height(phq9risk_all), 1);
for i = 1:height(phq9risk_all)
    scores = phq9risk_all.list_gad7score{i};
    if numel(scores) >= 3
        phq9risk_all.gad7_sd(i) = std(scores);
    end
end
sub_gad = phq9risk_all(~isnan(phq9risk_all.gad7_sd), :);

[rho, p] = corr(sub_gad.gad7_sd, sub_gad.mu); %ns
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.lambda); %ns
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.alpha); %marginal
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.pGamMix); %ns
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.pGamGain); %rho=-0.12, p=0.0382
[rho, p] = corr(sub_gad.gad7_sd, sub_gad.pGamble); %ns

%% MASQ BAMI and SD
masqbamirisk_all = innerjoin(combinedmasqbami_all, fitcombinedriskdata_all, 'Keys','redcapID');
% Extract params
masqbamirisk_all.mu     = cellfun(@(x) x(1), masqbamirisk_all.b_pt);
masqbamirisk_all.lambda = cellfun(@(x) x(2), masqbamirisk_all.b_pt);
masqbamirisk_all.alpha  = cellfun(@(x) x(3), masqbamirisk_all.b_pt);

% MASQ SD
masqbamirisk_all.masq_sd = NaN(height(masqbamirisk_all), 1);
for i = 1:height(masqbamirisk_all)
    scores = masqbamirisk_all.list_masqscore{i};
    if numel(scores) >= 3
        masqbamirisk_all.masq_sd(i) = std(scores);
    end
end
sub_masq = masqbamirisk_all(~isnan(masqbamirisk_all.masq_sd), :);

[rho, p] = corr(sub_masq.masq_sd, sub_masq.mu); %ns
[rho, p] = corr(sub_masq.masq_sd, sub_masq.lambda); %ns
[rho, p] = corr(sub_masq.masq_sd, sub_masq.alpha); %rho=-0.13 p=0.016
[rho, p] = corr(sub_masq.masq_sd, sub_masq.pGamMix); %ns
[rho, p] = corr(sub_masq.masq_sd, sub_masq.pGamGain); %rho=-0.11, p=0.054
[rho, p] = corr(sub_masq.masq_sd, sub_masq.pGamble); %ns

% BAMI SD
masqbamirisk_all.bami_sd = NaN(height(masqbamirisk_all), 1);
for i = 1:height(masqbamirisk_all)
    scores = masqbamirisk_all.list_bamiscore{i};
    if numel(scores) >= 3
        masqbamirisk_all.bami_sd(i) = std(scores);
    end
end
sub_bami = masqbamirisk_all(~isnan(masqbamirisk_all.bami_sd), :);

[rho, p] = corr(sub_bami.bami_sd, sub_bami.mu); %ns
[rho, p] = corr(sub_bami.bami_sd, sub_bami.lambda); %ns
[rho, p] = corr(sub_bami.bami_sd, sub_bami.alpha); %ns
[rho, p] = corr(sub_bami.bami_sd, sub_bami.pGamMix); %ns
[rho, p] = corr(sub_bami.bami_sd, sub_bami.pGamGain); %ns
[rho, p] = corr(sub_bami.bami_sd, sub_bami.pGamble); %ns

%% State and SD
staterisk_all = innerjoin(combinedstate_all, fitcombinedriskdata_all, 'Keys','redcapID');
% Extract params
staterisk_all.mu     = cellfun(@(x) x(1), staterisk_all.b_pt);
staterisk_all.lambda = cellfun(@(x) x(2), staterisk_all.b_pt);
staterisk_all.alpha  = cellfun(@(x) x(3), staterisk_all.b_pt);

% mean mental health SD
staterisk_all.mh_sd = NaN(height(staterisk_all), 1);
for i = 1:height(staterisk_all)
    scores = staterisk_all.list_mentalhealthscore{i};
    if numel(scores) >= 3
        staterisk_all.mh_sd(i) = std(scores);
    end
end
sub_masq = staterisk_all(~isnan(staterisk_all.mh_sd), :);

[rho, p] = corr(sub_masq.mh_sd, sub_masq.mu); %ns
[rho, p] = corr(sub_masq.mh_sd, sub_masq.lambda); %ns
[rho, p] = corr(sub_masq.mh_sd, sub_masq.alpha); %ns
[rho, p] = corr(sub_masq.mh_sd, sub_masq.pGamMix); %rho=.1 p=.03
[rho, p] = corr(sub_masq.mh_sd, sub_masq.pGamGain); %ns
[rho, p] = corr(sub_masq.mh_sd, sub_masq.pGamble); %rho=.09 p=.077

% Pos emo SD
staterisk_all.pe_sd = NaN(height(staterisk_all), 1);
for i = 1:height(staterisk_all)
    scores = staterisk_all.list_posemoscore{i};
    if numel(scores) >= 3
        staterisk_all.pe_sd(i) = std(scores);
    end
end
sub_bami = staterisk_all(~isnan(staterisk_all.pe_sd), :);

[rho, p] = corr(sub_bami.pe_sd, sub_bami.mu); %ns
[rho, p] = corr(sub_bami.pe_sd, sub_bami.lambda); %ns
[rho, p] = corr(sub_bami.pe_sd, sub_bami.alpha); %ns
[rho, p] = corr(sub_bami.pe_sd, sub_bami.pGamMix); %ns
[rho, p] = corr(sub_bami.pe_sd, sub_bami.pGamGain); %ns
[rho, p] = corr(sub_bami.pe_sd, sub_bami.pGamble); %ns

% neg emo SD
staterisk_all.ne_sd = NaN(height(staterisk_all), 1);
for i = 1:height(staterisk_all)
    scores = staterisk_all.list_negemoscore{i};
    if numel(scores) >= 3
        staterisk_all.ne_sd(i) = std(scores);
    end
end
sub_bami = staterisk_all(~isnan(staterisk_all.ne_sd), :);

[rho, p] = corr(sub_bami.ne_sd, sub_bami.mu); %ns
[rho, p] = corr(sub_bami.ne_sd, sub_bami.lambda); %ns
[rho, p] = corr(sub_bami.ne_sd, sub_bami.alpha); %ns
[rho, p] = corr(sub_bami.ne_sd, sub_bami.pGamMix); %ns
[rho, p] = corr(sub_bami.ne_sd, sub_bami.pGamGain); %ns
[rho, p] = corr(sub_bami.ne_sd, sub_bami.pGamble); %ns
