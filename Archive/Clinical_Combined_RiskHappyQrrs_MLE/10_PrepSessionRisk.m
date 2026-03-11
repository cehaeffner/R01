clear; clc

% Load data
tmp = load("../data/raw/database_nimh_depression_survey.mat");
surveydata = tmp.T_data;
idData = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;

% Define userKey columns by type
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};

% Build each version and tag with sessionType
surveyWithIDs_dense   = innerjoin(surveydata, buildLongID(idData, denseKeyCols),   'Keys', 'userKey');
surveyWithIDs_monthly = innerjoin(surveydata, buildLongID(idData, monthlyKeyCols), 'Keys', 'userKey');

surveyWithIDs_dense.sessionType   = repmat("dense",   height(surveyWithIDs_dense),   1);
surveyWithIDs_monthly.sessionType = repmat("monthly", height(surveyWithIDs_monthly), 1);

% Stack into single table
surveydata_all = vertcat(surveyWithIDs_dense, surveyWithIDs_monthly);

% Move redcapID to first column
surveydata_all = surveydata_all(:, ['redcapID', setdiff(surveydata_all.Properties.VariableNames, {'redcapID'}, 'stable')]);

save('sessionSurveyData.mat', 'surveydata_all');

%% Look at ppt data
dense_only   = surveydata_all(surveydata_all.sessionType == "dense",   :);
monthly_only = surveydata_all(surveydata_all.sessionType == "monthly", :);

n_dense   = numel(unique(dense_only.redcapID));
n_monthly = numel(unique(monthly_only.redcapID));
fprintf('Unique participants - Dense: %d, Monthly: %d\n', n_dense, n_monthly);

dense_sessions   = groupcounts(dense_only,   'redcapID').GroupCount;
monthly_sessions = groupcounts(monthly_only, 'redcapID').GroupCount;

fprintf('\nDense sessions per participant:\n');
fprintf('  Mean: %.1f, Median: %.1f, Min: %d, Max: %d\n', ...
    mean(dense_sessions), median(dense_sessions), min(dense_sessions), max(dense_sessions));

fprintf('Monthly sessions per participant:\n');
fprintf('  Mean: %.1f, Median: %.1f, Min: %d, Max: %d\n', ...
    mean(monthly_sessions), median(monthly_sessions), min(monthly_sessions), max(monthly_sessions));

fprintf('\nDense - distribution of session counts:\n');
tabulate(dense_sessions)
fprintf('Monthly - distribution of session counts:\n');
tabulate(monthly_sessions)

%% Helper function
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

%% Merge with risk

% Load fitted risk data
tmp = load("fitsessionRiskHappyData.mat");
riskdata = tmp.riskdata;


% Make sure both have a date column in the same format
riskdata.date   = dateshift(riskdata.date, 'start', 'day');
surveydata.date = dateshift(datetime(surveydata.date), 'start', 'day');

% Merge on redcapID + date
mergeddata = innerjoin(riskdata, surveydata, 'Keys', {'redcapID', 'date'});

save('mergedRiskSurveyData.mat', 'mergeddata');

fprintf('Risk rows: %d\n', height(riskdata));
fprintf('Survey rows: %d\n', height(surveydata));
fprintf('Merged rows: %d\n', height(mergeddata));