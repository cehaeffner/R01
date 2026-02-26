% Combines data from different sessions in R01 to fit together 
% (for better stochasticity parameter fits)
% Combines data from different sessions in R01 to fit together 
clear;clc

% Load survey data
tmp = load("../data/raw/database_nimh_depression_survey.mat");
surveydata = tmp.T_data;

% Load subject info
idData = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;

% Define userKey columns by type
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};
allKeyCols     = [denseKeyCols, monthlyKeyCols];

% Helper to build long ID table from a set of key columns
function longID = buildLongID(idData, keyCols)
    longID = table();
    for i = 1:numel(keyCols)
        col = keyCols{i};
        if ismember(col, idData.Properties.VariableNames)
            tmp         = idData(:, {'redcapID', 'age_denseSampling', 'gender', 'phq8_scid'});
            tmp.userKey = idData.(col);
            tmp         = tmp(tmp.userKey ~= "", :);
            longID      = [longID; tmp];
        end
    end
end

% Helper to score, join, and summarize a survey dataset
function out = buildSurveyTable(surveySubset, longID, scoreVarNames)
    joined = innerjoin(surveySubset, longID(longID.userKey ~= "", :), 'Keys', 'userKey');
    joined = sortrows(joined, 'dateOnly', 'ascend');
    
    [G, redcapID] = findgroups(joined.redcapID);
    
    % Always include these
    userKeys     = splitapply(@(x) {unique(x)},  joined.userKey,  G);
    enrolNumList = splitapply(@(x) {x'},          joined.enrolNumber, G);
    dateList     = splitapply(@(x) {x'},          joined.dateOnly, G);
    
    % Dynamically compute mean and list for each score variable
    out = table(redcapID, userKeys, enrolNumList, dateList);
    for i = 1:numel(scoreVarNames)
        varName = scoreVarNames{i};
        meanVal = splitapply(@nanmean,     joined.(varName), G);
        listVal = splitapply(@(x) {x'}, joined.(varName), G);
        out.(strcat('mean_', varName)) = meanVal;
        out.(strcat('list_', varName)) = listVal;
    end
end

% View count per questionnaire
tabulate(surveydata.configFileName)

% Create questionnaire-specific surveys
phq9gad7data = surveydata(surveydata.configFileName == "config_clinical_survey_1_PHQ9_GAD7", :);
statedata    = surveydata(surveydata.configFileName == "config_clinical_survey_4_state", :);
masqbamidata = surveydata(surveydata.configFileName == "config_clinical_survey_2_MASQanhedonia_BAMI", :);

% Remove incomplete surveys
phq9gad7data = phq9gad7data(cellfun(@(x) isequal(size(x), [18, 5]), {phq9gad7data.surveyData.data}'), :);
statedata    = statedata(cellfun(@(x) isequal(size(x), [11, 5]), {statedata.surveyData.data}'), :);

% Score surveys
% Subtract phq9, gad7, and bami by 1 because raw data is scored wrong
% Subtract masq from 6 to reverse score
phq9gad7data.phq9score = cellfun(@(x) sum(cell2mat(x(1:9, 5)) - 1),   {phq9gad7data.surveyData.data}');
phq9gad7data.gad7score = cellfun(@(x) sum(cell2mat(x(11:18, 5)) - 1), {phq9gad7data.surveyData.data}'); 
masqbamidata.masqscore = cellfun(@(x) sum(6 - cell2mat(x(1:10, 5))),  {masqbamidata.surveyData.data}');
masqbamidata.bamiscore = cellfun(@(x) mean(cell2mat(x(11:16, 5)) - 1), {masqbamidata.surveyData.data}');
statedata.eatcategory          = cellfun(@(x) x{1, 5},  {statedata.surveyData.data}');
statedata.coffeecategory       = cellfun(@(x) x{2, 5},  {statedata.surveyData.data}');
statedata.smokecategory        = cellfun(@(x) x{3, 5},  {statedata.surveyData.data}');
statedata.drinkcategory        = cellfun(@(x) x{4, 5},  {statedata.surveyData.data}');
statedata.sleepcategory        = cellfun(@(x) x{5, 5},  {statedata.surveyData.data}');
statedata.physactcategory      = cellfun(@(x) x{6, 5},  {statedata.surveyData.data}');
statedata.exercisedurcategory  = cellfun(@(x) x{7, 5},  {statedata.surveyData.data}');
statedata.mentalhealthscore    = cellfun(@(x) x{8, 5},  {statedata.surveyData.data}');
statedata.posemoscore          = cellfun(@(x) x{9, 5},  {statedata.surveyData.data}');
statedata.negemoscore          = cellfun(@(x) x{10, 5}, {statedata.surveyData.data}');
statedata.worriedscore         = cellfun(@(x) x{11, 5}, {statedata.surveyData.data}');

% Convert to datetime if not already, then extract date only
phq9gad7data.dateOnly = dateshift(datetime(phq9gad7data.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss'), 'start', 'day');
masqbamidata.dateOnly = dateshift(datetime(masqbamidata.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss'), 'start', 'day');
statedata.dateOnly    = dateshift(datetime(statedata.startDateTimeLocal,    'InputFormat', 'dd-MMM-yyyy HH:mm:ss'), 'start', 'day');

% Keep only first instance per userKey + date
% some people have duplicates
[~, idx] = unique([phq9gad7data.userKey, string(phq9gad7data.dateOnly)], 'rows', 'first');
phq9gad7data = phq9gad7data(idx, :);

[~, idx] = unique([masqbamidata.userKey, string(masqbamidata.dateOnly)], 'rows', 'first');
masqbamidata = masqbamidata(idx, :);

[~, idx] = unique([statedata.userKey, string(statedata.dateOnly)], 'rows', 'first');
statedata = statedata(idx, :);

% Build long ID tables for each version
longID_dense   = buildLongID(idData, denseKeyCols);
longID_monthly = buildLongID(idData, monthlyKeyCols);
longID_all     = buildLongID(idData, allKeyCols);

% PHQ9/GAD7 aggregation variables
phqAggrVars = {'phq9score', 'gad7score', 'enrolNumber', 'dateOnly', 'userKey'; 
               'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber'};

% MASQ/BAMI aggregation variables
masqAggrVars = {'masqscore', 'bamiscore', 'enrolNumber', 'dateOnly', 'userKey'; 
                'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber'};

% State aggregation variables
stateAggrVars = {'mentalhealthscore', 'posemoscore', 'negemoscore', 'worriedscore', ...
                 'eatcategory', 'coffeecategory', 'smokecategory', 'drinkcategory', ...
                 'sleepcategory', 'physactcategory', 'exercisedurcategory', 'enrolNumber', 'dateOnly', 'userKey'; ...
                 'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber', ...
                 'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber', ...
                 'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber', 'enrolNumber'};

% Build all versions
combinedphq9gad7_dense   = buildSurveyTable(phq9gad7data, longID_dense,   {'phq9score', 'gad7score'});
combinedphq9gad7_monthly = buildSurveyTable(phq9gad7data, longID_monthly, {'phq9score', 'gad7score'});
combinedphq9gad7_all     = buildSurveyTable(phq9gad7data, longID_all,     {'phq9score', 'gad7score'});

combinedmasqbami_dense   = buildSurveyTable(masqbamidata, longID_dense,   {'masqscore', 'bamiscore'});
combinedmasqbami_monthly = buildSurveyTable(masqbamidata, longID_monthly, {'masqscore', 'bamiscore'});
combinedmasqbami_all     = buildSurveyTable(masqbamidata, longID_all,     {'masqscore', 'bamiscore'});

stateVars = {'mentalhealthscore', 'posemoscore', 'negemoscore', 'worriedscore', ...
             'eatcategory', 'coffeecategory', 'smokecategory', 'drinkcategory', ...
             'sleepcategory', 'physactcategory', 'exercisedurcategory'};
combinedstate_dense   = buildSurveyTable(statedata, longID_dense,   stateVars);
combinedstate_monthly = buildSurveyTable(statedata, longID_monthly, stateVars);
combinedstate_all     = buildSurveyTable(statedata, longID_all,     stateVars);

%% Sanity check: View distributions of surveys
vars = {'mean_phq9score', 'mean_gad7score', 'mean_masqscore', 'mean_bamiscore'};
tables = {combinedphq9gad7_all, combinedphq9gad7_all, combinedmasqbami_all, combinedmasqbami_all};

figure;
for i = 1:4
    subplot(2,2,i)
    d = tables{i}.(vars{i});
    histogram(d)
    xline(mean(d, 'omitnan'), 'r--', 'LineWidth', 1.5, 'Label', 'Mean')
    xline(median(d, 'omitnan'), 'b--', 'LineWidth', 1.5, 'Label', 'Median')
    title(vars{i})
    xlabel('Score'); ylabel('Count')
end

stateVarNames = {'mentalhealthscore', 'posemoscore', 'negemoscore', 'worriedscore', ...
                 'eatcategory', 'coffeecategory', 'smokecategory', 'drinkcategory', ...
                 'sleepcategory', 'physactcategory', 'exercisedurcategory'};

figure;
n = numel(stateVarNames);
ncols = 4;
nrows = ceil(n / ncols);

for i = 1:n
    subplot(nrows, ncols, i)
    d = combinedstate_all.(strcat('mean_', stateVarNames{i}));
    
    if contains(stateVarNames{i}, 'category')
        % categorical-style: bar chart of counts per value
        vals = rmmissing(d);
        bar(histcounts(vals, min(vals):max(vals)+1))
        xlabel('Category'); ylabel('Count')
    else
        histogram(d)
        xline(mean(d, 'omitnan'), 'r--', 'LineWidth', 1.5, 'Label', 'Mean')
        xline(median(d, 'omitnan'), 'b--', 'LineWidth', 1.5, 'Label', 'Median')
        xlabel('Score'); ylabel('Count')
    end
    title(stateVarNames{i}, 'Interpreter', 'none')
end

%% Correlations between questionnaires heatmaps
meanTable = innerjoin(combinedphq9gad7_all(:, {'redcapID', 'mean_phq9score', 'mean_gad7score'}), ...
                      combinedmasqbami_all(:,  {'redcapID', 'mean_masqscore', 'mean_bamiscore'}), ...
                      'Keys', 'redcapID');

labels  = {'PHQ-9', 'GAD-7', 'MASQ', 'BAMI'};
M       = table2array(meanTable(:, {'mean_phq9score','mean_gad7score','mean_masqscore','mean_bamiscore'}));
[R, P]  = corr(M, 'rows', 'pairwise', 'type', 'spearman');

n = numel(labels);
figure; hold on;

for i = 1:n
    for j = 1:n
        if i == j
            clr = [0.85 0.85 0.85];
        elseif P(i,j) < 0.05
            clr = [0.20 0.65 0.25];
        elseif P(i,j) < 0.1
            clr = [0.95 0.80 0.10];
        else
            clr = [0.85 0.85 0.85];
        end
        rectangle('Position', [j-0.5, n-i+0.5, 1, 1], 'FaceColor', clr, 'EdgeColor', 'w', 'LineWidth', 2);
        text(j, n-i+1, sprintf('%.2f', R(i,j)), 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
end

set(gca, 'XTick', 1:n, 'XTickLabel', labels, 'XAxisLocation', 'top', ...
         'YTick', 1:n, 'YTickLabel', fliplr(labels), 'TickLength', [0 0], 'FontSize', 11);
xlim([0.5 n+0.5]); ylim([0.5 n+0.5]); axis square;
title('Spearman correlations: questionnaire means');

%% Within-Person Stability Analysis (Lag-1 and ICC)%% Within-Person Stability Analysis (Full Integrated Loop)
targetVars = {'phq9score', 'gad7score', 'masqscore', 'bamiscore', ...
              'mentalhealthscore', 'posemoscore', 'negemoscore', 'worriedscore'};

varMapping = containers.Map(...
    targetVars, ...
    {'combinedphq9gad7_all', 'combinedphq9gad7_all', 'combinedmasqbami_all', 'combinedmasqbami_all', ...
     'combinedstate_all', 'combinedstate_all', 'combinedstate_all', 'combinedstate_all'});

results = table();

for v = 1:numel(targetVars)
    varName     = targetVars{v};
    sourceTable = eval(varMapping(varName));
    listCol     = strcat('list_', varName);

    all_t = []; all_t_plus_1 = [];
    longFormID = []; longFormScore = [];

    for i = 1:height(sourceTable)
        scores = sourceTable.(listCol){i};
        dates  = sourceTable.dateList{i};

        validIdx = ~isnan(scores);
        scores   = scores(validIdx);
        dates    = dates(validIdx);

        if numel(scores) > 1
            % Lag-1 (only adjacent timepoints within 3 days)
            for t = 1:(numel(scores)-1)
                dayDiff = days(dates(t+1) - dates(t));
                if dayDiff > 0 && dayDiff <= 3
                    all_t       = [all_t;       scores(t)];
                    all_t_plus_1 = [all_t_plus_1; scores(t+1)];
                end
            end

            % ICC long format
            longFormScore = [longFormScore; scores'];
            longFormID    = [longFormID;    repmat(sourceTable.redcapID(i), numel(scores), 1)];
        end
    end

    % Lag-1 Spearman
    if numel(all_t) >= 3
        [r_lag, p_lag] = corr(all_t, all_t_plus_1, 'rows', 'complete', 'type', 'Spearman');
    else
        r_lag = NaN; p_lag = NaN;
    end

    % ICC via LME
    tmpTbl      = table(longFormID, longFormScore, 'VariableNames', {'ID', 'Score'});
    lme         = fitlme(tmpTbl, 'Score ~ 1 + (1|ID)');
    [psi, ~]    = covarianceParameters(lme);
    var_between = psi{1};
    var_within  = lme.MSE;
    icc_val     = var_between / (var_between + var_within);

    if icc_val > 0.6
        class = "Trait-like (Stable)";
    elseif icc_val > 0.4
        class = "Mixed";
    else
        class = "State-like (Fluctuating)";
    end

    results(v, :) = table({varName}, r_lag, p_lag, icc_val, {class}, ...
        'VariableNames', {'Variable', 'Lag1_R', 'Lag1_P', 'ICC', 'Type'});
end

disp(results);

%% Visualization: Trait vs State Scatter
figure('Position', [100 100 700 500]);
scatter(results.ICC, results.Lag1_R, 100, 'filled', 'MarkerFaceAlpha', 0.6);
hold on;

cellfun(@(x, xi, yi) text(xi, yi, x, 'FontSize', 10), results.Variable, ...
    num2cell(results.ICC + 0.01), num2cell(results.Lag1_R + 0.01));

xline(0.5, 'r--', 'Threshold'); ; yline(0.5, 'r--', 'Threshold');

xlabel('ICC (High = Stable Person Traits)');
ylabel('Lag-1 Correlation (High = Day-to-Day Carryover)');
title('Survey Stability Profile: Trait vs. State');

%% Save
save('combinedSurveyData_dense.mat',   'combinedphq9gad7_dense',   'combinedmasqbami_dense',   'combinedstate_dense');
save('combinedSurveyData_monthly.mat', 'combinedphq9gad7_monthly', 'combinedmasqbami_monthly', 'combinedstate_monthly');
save('combinedSurveyData_all.mat',     'combinedphq9gad7_all',     'combinedmasqbami_all',     'combinedstate_all');