% Analyze whether LTEQ (baseline trauma exposure) predicts symptom trajectory
% Timepoints: dense mean = T0, each monthly visit = T1, T2, T3...
% Per-person slope computed via linear regression across these timepoints,
% then correlated with baseline LTEQ score
clear; clc; close all;

% Load LTEQ data (one file)
tmp = load("lteqdata.mat");
lteq = tmp.lteq;
lteq = renamevars(lteq, "ParticipantPublicID", "redcapID");

% Load dense survey data (provides T0 mean)
tmp = load("combinedSurveyData_dense.mat");
combinedphq9gad7_dense = tmp.combinedphq9gad7_dense;
combinedmasqbami_dense = tmp.combinedmasqbami_dense;
combinedstate_dense    = tmp.combinedstate_dense;

% Load monthly survey data (provides T1, T2, T3... as list_ variables)
tmp = load("combinedSurveyData_monthly.mat");
combinedphq9gad7_monthly = tmp.combinedphq9gad7_monthly;
combinedmasqbami_monthly = tmp.combinedmasqbami_monthly;
combinedstate_monthly    = tmp.combinedstate_monthly;

% Define outcome variables: [dense mean var, monthly list var, label, source table]
q_info = {
    'mean_phq9score',        'list_phq9score',        'PHQ9',        'phq9gad7';
    'mean_gad7score',        'list_gad7score',        'GAD7',        'phq9gad7';
    'mean_masqscore',        'list_masqscore',        'MASQ',        'masqbami';
    'mean_bamiscore',        'list_bamiscore',        'BAMI',        'masqbami';
    'mean_mentalhealthscore','list_mentalhealthscore','MentalHealth','state';
    'mean_posemoscore',      'list_posemoscore',      'PosEmo',      'state';
    'mean_negemoscore',      'list_negemoscore',      'NegEmo',      'state';
    'mean_worriedscore',     'list_worriedscore',     'Worry',       'state';
};

% Pack survey tables by source key
dense_map   = struct('phq9gad7', combinedphq9gad7_dense,   'masqbami', combinedmasqbami_dense,   'state', combinedstate_dense);
monthly_map = struct('phq9gad7', combinedphq9gad7_monthly, 'masqbami', combinedmasqbami_monthly, 'state', combinedstate_monthly);

% Preallocate results
n_q = size(q_info, 1);
rho_vec = nan(n_q, 1);
p_vec   = nan(n_q, 1);

% For each questionnaire, build per-person timeseries [T0, T1, T2, ...] and compute slope
for qi = 1:n_q
    mean_var  = q_info{qi,1};
    list_var  = q_info{qi,2};
    src       = q_info{qi,4};

    % Join dense (T0) and monthly (T1+) with LTEQ on redcapID
    dense_lteq   = innerjoin(dense_map.(src),   lteq, 'Keys', 'redcapID');
    monthly_lteq = innerjoin(monthly_map.(src), lteq, 'Keys', 'redcapID');

    % Find participants present in both
    shared_ids = intersect(dense_lteq.redcapID, monthly_lteq.redcapID);

    slopes      = nan(numel(shared_ids), 1);
    lteq_scores = nan(numel(shared_ids), 1);

    for i = 1:numel(shared_ids)
        id = shared_ids(i);

        % Get T0 from dense mean
        d_row = dense_lteq(dense_lteq.redcapID == id, :);
        t0    = d_row.(mean_var);
        if iscell(t0), t0 = cell2mat(t0); end
        if isempty(t0) || isnan(t0), continue; end

        % Get T1+ from monthly list
        m_row     = monthly_lteq(monthly_lteq.redcapID == id, :);
        monthly_vals = m_row.(list_var){1};
        if numel(monthly_vals) < 1, continue; end

        % Build full timeseries: [T0, T1, T2, ...]
        y = [t0; monthly_vals(:)];
        x = (0:numel(y)-1)';

        % Require at least 3 timepoints for a meaningful slope
        if numel(y) < 3, continue; end

        % Fit linear slope
        b = [ones(size(x)), x] \ y;
        slopes(i)      = b(2);
        lteq_scores(i) = m_row.lteq_score;
    end

    % Correlate slope with LTEQ
    ok = ~isnan(slopes) & ~isnan(lteq_scores);
    if sum(ok) < 10, continue; end
    [rho_vec(qi), p_vec(qi)] = corr(slopes(ok), lteq_scores(ok), 'Type','Spearman');
    fprintf('%s: rho=%.3f, p=%.4f, n=%d\n', q_info{qi,3}, rho_vec(qi), p_vec(qi), sum(ok));
end

%% Plot heatmap summarizing significance
% Convert p-values to significance codes: -1=no data, 0=NS, 1=marginal, 2=sig
sig = zeros(n_q, 1);
sig(p_vec < 0.1)  = 1;
sig(p_vec < 0.05) = 2;
sig(isnan(p_vec)) = -1;

figure('Position',[100 100 250 400],'Color','w');
imagesc(sig, [-1 2]);
colormap([0.7 0.7 0.7; 0.93 0.93 0.93; 1 0.85 0.2; 0.2 0.75 0.35]); % gray/NS/marginal/sig

% Overlay rho values (black if sig, gray otherwise)
for r = 1:n_q
    if ~isnan(rho_vec(r))
        clr = [0.4 0.4 0.4];
        if p_vec(r) < 0.05, clr = 'k'; end
        text(1, r, sprintf('%.2f', rho_vec(r)), ...
            'HorizontalAlignment','center','FontSize',9,'Color',clr);
    end
end

set(gca, 'XTick', 1, 'XTickLabel', {'LTEQ'}, 'XAxisLocation','top', ...
         'YTick', 1:n_q, 'YTickLabel', q_info(:,3), 'TickLabelInterpreter','none', ...
         'FontSize', 10);

cb = colorbar; cb.Ticks = [-0.625 0.125 0.875 1.625];
cb.TickLabels = {'No data','NS','Marginal','Sig'};
title('LTEQ predicting symptom slope (dense T0 + monthly T1+)','FontWeight','bold');
saveas(gcf, 'lteqSymptomSlope_heatmap.png');