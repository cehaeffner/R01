% Prep data to be fit at individual level
clear;clc

% Load data
idData  = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;
rawData = load("../data/raw/database_nimh_depression_reward.mat").T_data;

% Define userKey columns by type
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};

% Helper function to build long ID table from a set of key columns
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

% Helper function to build session-level table (one row per session)
function out = buildSessionTable(riskWithIDs)
    riskWithIDs.date = dateshift(datetime(riskWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss'), 'start', 'day');
riskWithIDs.time = timeofday(datetime(riskWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss'));
    riskWithIDs = sortrows(riskWithIDs, {'redcapID', 'date'}, {'ascend', 'ascend'});

    [G, ~] = findgroups(riskWithIDs.redcapID);
    riskWithIDs.sessionNum = zeros(height(riskWithIDs), 1);
    for g = 1:max(G)
        idx = G == g;
        riskWithIDs.sessionNum(idx) = (1:sum(idx))';
    end

    out = table( ...
        riskWithIDs.redcapID, ...
        riskWithIDs.userKey, ...
        riskWithIDs.enrolNumber, ...
        riskWithIDs.date, ...
        riskWithIDs.time, ...
        riskWithIDs.sessionNum, ...
        riskWithIDs.age_denseSampling, ...
        riskWithIDs.gender, ...
        riskWithIDs.phq8_scid, ...
        riskWithIDs.gameData, ...
        'VariableNames', {'redcapID', 'userKey', 'enrolNumber', 'date', 'time' ...
                          'sessionNum', 'age_dense', 'gender', 'phq8_scid', 'gameData'});
end

% Build each version and tag with sessionType
riskWithIDs_dense   = innerjoin(rawData, buildLongID(idData, denseKeyCols),   'Keys', 'userKey');
riskWithIDs_monthly = innerjoin(rawData, buildLongID(idData, monthlyKeyCols), 'Keys', 'userKey');

sessiondata_dense   = buildSessionTable(riskWithIDs_dense);
sessiondata_monthly = buildSessionTable(riskWithIDs_monthly);

sessiondata_dense.sessionType   = repmat("dense",   height(sessiondata_dense),   1);
sessiondata_monthly.sessionType = repmat("monthly", height(sessiondata_monthly), 1);

% Stack into single table
sessiondata_all = vertcat(sessiondata_dense, sessiondata_monthly);

save('sessionRiskData.mat', 'sessiondata_all');

%% Look at ppt data
% Summary of unique participants and sessions per type
dense_only   = sessiondata_all(sessiondata_all.sessionType == "dense",   :);
monthly_only = sessiondata_all(sessiondata_all.sessionType == "monthly", :);

% Unique participants
n_dense   = numel(unique(dense_only.redcapID));
n_monthly = numel(unique(monthly_only.redcapID));
fprintf('Unique participants - Dense: %d, Monthly: %d\n', n_dense, n_monthly);

% Sessions per participant
dense_sessions   = groupcounts(dense_only,   'redcapID').GroupCount;
monthly_sessions = groupcounts(monthly_only, 'redcapID').GroupCount;

fprintf('\nDense sessions per participant:\n');
fprintf('  Mean: %.1f, Median: %.1f, Min: %d, Max: %d\n', ...
    mean(dense_sessions), median(dense_sessions), min(dense_sessions), max(dense_sessions));

fprintf('Monthly sessions per participant:\n');
fprintf('  Mean: %.1f, Median: %.1f, Min: %d, Max: %d\n', ...
    mean(monthly_sessions), median(monthly_sessions), min(monthly_sessions), max(monthly_sessions));

% Distribution of session counts
fprintf('\nDense - distribution of session counts:\n');
tabulate(dense_sessions)
fprintf('Monthly - distribution of session counts:\n');
tabulate(monthly_sessions)

% I'm not that concerned with the few people that have extra 

%% Remove multiple plays on same day
[~, firstIdx] = unique(sessiondata_all(:, {'redcapID', 'date'}), 'rows', 'first');
sessiondata_filt = sessiondata_all(firstIdx, :);
% Got rid of 488 extra plays

save('sessionRiskData_filt.mat', 'sessiondata_filt');

%% Look at ppt data filtered
% Summary of unique participants and sessions per type
dense_only   = sessiondata_filt(sessiondata_filt.sessionType == "dense",   :);
monthly_only = sessiondata_filt(sessiondata_filt.sessionType == "monthly", :);

% Unique participants
n_dense   = numel(unique(dense_only.redcapID));
n_monthly = numel(unique(monthly_only.redcapID));
fprintf('Unique participants - Dense: %d, Monthly: %d\n', n_dense, n_monthly);

% Sessions per participant
dense_sessions   = groupcounts(dense_only,   'redcapID').GroupCount;
monthly_sessions = groupcounts(monthly_only, 'redcapID').GroupCount;

fprintf('\nDense sessions per participant:\n');
fprintf('  Mean: %.1f, Median: %.1f, Min: %d, Max: %d\n', ...
    mean(dense_sessions), median(dense_sessions), min(dense_sessions), max(dense_sessions));

fprintf('Monthly sessions per participant:\n');
fprintf('  Mean: %.1f, Median: %.1f, Min: %d, Max: %d\n', ...
    mean(monthly_sessions), median(monthly_sessions), min(monthly_sessions), max(monthly_sessions));

% Distribution of session counts
fprintf('\nDense - distribution of session counts:\n');
tabulate(dense_sessions)
fprintf('Monthly - distribution of session counts:\n');
tabulate(monthly_sessions)
