% Analyze LTEQ and other psychopathology questionnaires across survey datasets
% questionnaire data cleaned & scored in clinical_combined_riskhappyqrrs_mle
clear; clc; close all;

% Load LTEQ data (one file)
tmp = load("lteqdata.mat");
lteq = tmp.lteq;
lteq = renamevars(lteq, "ParticipantPublicID", "redcapID");

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

% Pack into struct for loop access
survey_map = struct( ...
    'dense',   struct('phq9gad7', combinedphq9gad7_dense,   'masqbami', combinedmasqbami_dense,   'state', combinedstate_dense), ...
    'all',     struct('phq9gad7', combinedphq9gad7_all,     'masqbami', combinedmasqbami_all,     'state', combinedstate_all), ...
    'monthly', struct('phq9gad7', combinedphq9gad7_monthly, 'masqbami', combinedmasqbami_monthly, 'state', combinedstate_monthly));

% Define datasets, questionnaire variables and their source tables
datasets  = {'dense', 'all', 'monthly'};
q_vars    = {'mean_gad7score','mean_phq9score','mean_masqscore','mean_bamiscore',...
             'mean_mentalhealthscore','mean_posemoscore','mean_negemoscore','mean_worriedscore'};
q_labels  = {'GAD7','PHQ9','MASQ','BAMI','MentalHealth','PosEmo','NegEmo','Worry'};
q_src     = {'phq9gad7','phq9gad7','masqbami','masqbami','state','state','state','state'};

% Preallocate results matrices (rows = questionnaires, cols = datasets)
n_cond = numel(datasets);
n_rows = numel(q_vars);
rho_mat = nan(n_rows, n_cond);
p_mat   = nan(n_rows, n_cond);

% Loop over datasets, join with LTEQ, run correlations
for di = 1:numel(datasets)
    tag = datasets{di};
    T   = survey_map.(tag);

    % Join each survey table with LTEQ
    joined.phq9gad7 = innerjoin(T.phq9gad7, lteq, 'Keys', 'redcapID');
    joined.masqbami = innerjoin(T.masqbami,  lteq, 'Keys', 'redcapID');
    joined.state    = innerjoin(T.state,     lteq, 'Keys', 'redcapID');

    % Run all correlations against LTEQ score
    for qi = 1:numel(q_vars)
        tbl = joined.(q_src{qi});
        x = tbl.(q_vars{qi}); y = tbl.lteq_score;
        if iscell(x), x = cell2mat(x); end
        ok = ~isnan(x) & ~isnan(y);
        if sum(ok) < 10, continue; end
        [rho_mat(qi,di), p_mat(qi,di)] = corr(x(ok), y(ok), 'Type','Spearman');
    end
end

%% Plot heatmap summarizing significance across all conditions
% Convert p-values to significance codes: -1=no data, 0=NS, 1=marginal, 2=sig
sig = zeros(size(p_mat));
sig(p_mat < 0.1)  = 1;
sig(p_mat < 0.05) = 2;
sig(isnan(p_mat)) = -1;

figure('Position',[100 100 500 400],'Color','w');
imagesc(sig, [-1 2]);
colormap([0.7 0.7 0.7; 0.93 0.93 0.93; 1 0.85 0.2; 0.2 0.75 0.35]); % gray/NS/marginal/sig

% Overlay rho values (black if sig, gray otherwise)
for r = 1:n_rows
    for c = 1:n_cond
        if ~isnan(rho_mat(r,c))
            clr = [0.4 0.4 0.4];
            if p_mat(r,c) < 0.05, clr = 'k'; end
            text(c, r, sprintf('%.2f', rho_mat(r,c)), ...
                'HorizontalAlignment','center','FontSize',8,'Color',clr);
        end
    end
end

set(gca, 'XTick',1:n_cond, 'XTickLabel',datasets, 'XAxisLocation','top', ...
         'YTick',1:n_rows,  'YTickLabel',q_labels,  'TickLabelInterpreter','none', ...
         'FontSize',9);
xtickangle(30);

cb = colorbar; cb.Ticks = [-0.625 0.125 0.875 1.625];
cb.TickLabels = {'No data','NS','Marginal','Sig'};
title('Spearman correlations: questionnaires x LTEQ','FontWeight','bold');
saveas(gcf, 'lteqQuestCorrelations_heatmap.png');

%% View PHQ9 scores over time per participant
figure; hold on;
colors = lines(height(combinedphq9gad7_dense));
for i = 1:height(combinedphq9gad7_dense)
    y = combinedphq9gad7_dense.list_phq9score{i};
    x = 1:numel(y);
    plot(x, y, '-o', 'Color', colors(i,:), 'DisplayName', char(combinedphq9gad7_dense.redcapID(i)));
end
xlabel('Timepoint'); ylabel('PHQ9 Score');
legend('show', 'Location', 'bestoutside');
hold off;