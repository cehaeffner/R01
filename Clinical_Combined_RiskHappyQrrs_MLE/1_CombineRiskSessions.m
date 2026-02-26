% Combines data from different sessions in R01 to fit together 
% (for better stochasticity parameter fits)
clear;clc

% Load data
idData  = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;
rawData = load("../data/raw/database_nimh_depression_reward.mat").T_data;

% Define userKey columns by type
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};
allKeyCols     = [denseKeyCols, monthlyKeyCols];

% Helper function to build long ID table from a set of key columns
function longID = buildLongID(idData, keyCols)
    longID = table();
    for i = 1:numel(keyCols)
        col = keyCols{i};
        if ismember(col, idData.Properties.VariableNames)
            tmp          = idData(:, {'redcapID', 'age_denseSampling', 'gender', 'phq8_scid'});
            tmp.userKey  = idData.(col);
            tmp          = tmp(tmp.userKey ~= "", :);
            longID       = [longID; tmp];
        end
    end
end

% Helper function to stack and build final table from joined data
function out = buildCombinedTable(riskWithIDs)
    % Extract date and sort chronologically
    riskWithIDs.dateOnly = dateshift(datetime(riskWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss'), 'start', 'day');
    riskWithIDs = sortrows(riskWithIDs, 'dateOnly', 'ascend');

    [G, redcapID]   = findgroups(riskWithIDs.redcapID);
    numSessions     = splitapply(@numel, riskWithIDs.enrolNumber, G);
    userKeys        = splitapply(@(x) {unique(x)}, riskWithIDs.userKey, G);
    gameDataStacked = splitapply(@(x) {vertcat(x{:})}, {riskWithIDs.gameData.data}', G);
    enrolNumList    = splitapply(@(x) {x'}, riskWithIDs.enrolNumber, G);
    dateList        = splitapply(@(x) {x'}, riskWithIDs.dateOnly, G);
    age_dense       = splitapply(@(x) x(1), riskWithIDs.age_denseSampling, G);
    gender          = splitapply(@(x) x(1), riskWithIDs.gender, G);
    phq8_scid       = splitapply(@(x) x(1), riskWithIDs.phq8_scid, G);
    out = table(redcapID, userKeys, numSessions, gameDataStacked, enrolNumList, ...
        dateList, age_dense, gender, phq8_scid);
end

% Build and save each version
riskWithIDs_dense   = innerjoin(rawData, buildLongID(idData, denseKeyCols),   'Keys', 'userKey');
riskWithIDs_monthly = innerjoin(rawData, buildLongID(idData, monthlyKeyCols), 'Keys', 'userKey');
riskWithIDs_all     = innerjoin(rawData, buildLongID(idData, allKeyCols),     'Keys', 'userKey');

combinedriskdata_dense   = buildCombinedTable(riskWithIDs_dense);
combinedriskdata_monthly = buildCombinedTable(riskWithIDs_monthly);
combinedriskdata_all     = buildCombinedTable(riskWithIDs_all);

save('combinedRiskData_dense.mat',   'combinedriskdata_dense');
save('combinedRiskData_monthly.mat', 'combinedriskdata_monthly');
save('combinedRiskData_all.mat',     'combinedriskdata_all');