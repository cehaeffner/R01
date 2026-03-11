% Analyze how happiness model parameters correlate with motivation and state
% questionnaires, across datasets and R2 filters
% Note: should add multiple corrections
clear; clc; close all;

% Load happiness data
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

% Pack into structs for loop access
happydata_map = struct('dense', fitcombinedhappydata_dense, ...
                       'all',   fitcombinedhappydata_all, ...
                       'monthly', fitcombinedhappydata_monthly);
survey_map = struct( ...
    'dense',   struct('phq9gad7', combinedphq9gad7_dense,   'masqbami', combinedmasqbami_dense,   'state', combinedstate_dense), ...
    'all',     struct('phq9gad7', combinedphq9gad7_all,     'masqbami', combinedmasqbami_all,     'state', combinedstate_all), ...
    'monthly', struct('phq9gad7', combinedphq9gad7_monthly, 'masqbami', combinedmasqbami_monthly, 'state', combinedstate_monthly));

% Define datasets, R2 filters, parameters, and questionnaires
datasets   = {'dense', 'all', 'monthly'};
r2_threshs = [-8, 0.1];
happy_params = {'cert', 'ev', 'rpe', 'tau', 'const'};
q_vars    = {'mean_masqscore','mean_bamiscore','mean_phq9score','mean_gad7score',...
             'mean_worriedscore','mean_posemoscore','mean_negemoscore','phq8_scid'};
q_labels  = {'MASQ','BAMI','PHQ9','GAD7','Worry','PosEmo','NegEmo','PHQ8-SCID'};
q_src     = {'masqbami','masqbami','phq9gad7','phq9gad7','state','state','state','direct'};

% Preallocate results matrices (rows = happy param x questionnaire, cols = dataset x r2 filter)
n_cond = numel(datasets) * numel(r2_threshs);
n_rows = numel(happy_params) * numel(q_vars);
rho_mat    = nan(n_rows, n_cond);
p_mat      = nan(n_rows, n_cond);
col_labels = {};

% Loop over datasets and R2 filters, join tables, run correlations
col = 0;
for di = 1:numel(datasets)
    tag = datasets{di};
    T   = survey_map.(tag);

    for ri = 1:numel(r2_threshs)
        col = col + 1;
        col_labels{col} = sprintf('%s|R2>%g', tag, r2_threshs(ri));

        % Filter by happiness model R2 and extract parameters
        d = happydata_map.(tag);
        d = d(cell2mat(d.r2_evrpe) > r2_threshs(ri), :);
        d.cert  = cellfun(@(x) x(1), d.b_evrpe);
        d.ev    = cellfun(@(x) x(2), d.b_evrpe);
        d.rpe   = cellfun(@(x) x(3), d.b_evrpe);
        d.tau   = cellfun(@(x) x(4), d.b_evrpe);
        d.const = cellfun(@(x) x(5), d.b_evrpe);

        % Join happiness data with each survey table
        joined.phq9gad7 = outerjoin(T.phq9gad7, d, 'Keys', 'redcapID', 'MergeKeys', true);
        joined.masqbami = outerjoin(T.masqbami,  d, 'Keys', 'redcapID', 'MergeKeys', true);
        joined.state    = outerjoin(T.state,     d, 'Keys', 'redcapID', 'MergeKeys', true);

        % Run all correlations
        row = 0;
        for pi = 1:numel(happy_params)
            for qi = 1:numel(q_vars)
                row = row + 1;
                % phq8_scid lives directly in the happiness data table
                if strcmp(q_src{qi}, 'direct')
                    x = d.phq8_scid; y = d.(happy_params{pi});
                else
                    tbl = joined.(q_src{qi});
                    x = tbl.(q_vars{qi}); y = tbl.(happy_params{pi});
                end
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
for pi = 1:numel(happy_params)
    for qi = 1:numel(q_vars)
        row_labels{end+1} = sprintf('%s x %s', happy_params{pi}, q_labels{qi});
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

% Dividing lines between happy parameter groups and datasets
hold on;
for pi = 1:numel(happy_params)-1
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
title('Spearman correlations: happiness params x questionnaires','FontWeight','bold');
saveas(gcf, 'happyQuestCorrelations_heatmap.png');