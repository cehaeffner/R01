% Analyze how risk parameters correlate with happiness parameters
% across datasets and R2 filters
clear; clc; close all;

% Load risk-happiness data
tmp = load("fitcombinedRiskHappyData_dense.mat");
fitcombinedriskhappydata_dense   = tmp.combinedriskhappydata;
tmp = load("fitcombinedRiskHappyData_all.mat");
fitcombinedriskhappydata_all     = tmp.combinedriskhappydata;
tmp = load("fitcombinedRiskHappyData_monthly.mat");
fitcombinedriskhappydata_monthly = tmp.combinedriskhappydata;

% Pack into struct for loop access
riskdata_map = struct('dense',   fitcombinedriskhappydata_dense, ...
                      'all',     fitcombinedriskhappydata_all, ...
                      'monthly', fitcombinedriskhappydata_monthly);

% Define datasets, R2 filters, and parameters
datasets     = {'dense', 'all', 'monthly'};
r2_threshs   = [-8, 0.1];
risk_params  = {'alpha', 'pGamble','lambda', 'mu'};
happy_params = {'cert', 'ev', 'rpe', 'tau', 'const'};

% Preallocate results matrices (rows = risk x happy params, cols = dataset x r2 filter)
n_cond = numel(datasets) * numel(r2_threshs);
n_rows = numel(risk_params) * numel(happy_params);
rho_mat    = nan(n_rows, n_cond);
p_mat      = nan(n_rows, n_cond);
col_labels = {};

% Loop over datasets and R2 filters, extract parameters, run correlations
col = 0;
for di = 1:numel(datasets)
    tag = datasets{di};

    for ri = 1:numel(r2_threshs)
        col = col + 1;
        col_labels{col} = sprintf('%s R2>%g', tag, r2_threshs(ri));

        % Filter by R2 for both risk and happiness models, extract parameters
        d = riskdata_map.(tag);
        idx = cell2mat(d.pr2_pt) > r2_threshs(ri) & cell2mat(d.r2_evrpe) > r2_threshs(ri);
        d = d(idx, :);
        d.mu     = cellfun(@(x) x(1), d.b_pt);
        d.lambda = cellfun(@(x) x(2), d.b_pt);
        d.alpha  = cellfun(@(x) x(3), d.b_pt);
        d.cert   = cellfun(@(x) x(1), d.b_evrpe);
        d.ev     = cellfun(@(x) x(2), d.b_evrpe);
        d.rpe    = cellfun(@(x) x(3), d.b_evrpe);
        d.tau    = cellfun(@(x) x(4), d.b_evrpe);
        d.const  = cellfun(@(x) x(5), d.b_evrpe);

        % Run all correlations
        row = 0;
        for pi = 1:numel(risk_params)
            for qi = 1:numel(happy_params)
                row = row + 1;
                x = d.(risk_params{pi}); y = d.(happy_params{qi});
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
for pi = 1:numel(risk_params)
    for qi = 1:numel(happy_params)
        row_labels{end+1} = sprintf('%s x %s', risk_params{pi}, happy_params{qi});
    end
end

figure('Position',[100 100 900 450],'Color','w');
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

% Dividing lines between risk parameter groups and datasets
hold on;
for pi = 1:numel(risk_params)-1
    yline(pi*numel(happy_params)+0.5, 'k-', 'LineWidth', 1.5);
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
title('Spearman correlations: risk params x happiness params','FontWeight','bold');
saveas(gcf, 'riskHappy.png');