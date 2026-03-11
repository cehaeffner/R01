%% Consolidates Game Data and Survey Data into one Master Table
clear; clc

% 1. Load All Data
idData     = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;
rawData    = load("../data/raw/database_nimh_depression_reward.mat").T_data;
surveyData = load("../data/raw/database_nimh_depression_survey.mat").T_data;

% 2. Build ID Mapping (All versions)
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};
allKeyCols     = [denseKeyCols, monthlyKeyCols];
longID_all     = buildLongID(idData, allKeyCols);

%% 3. Process Game Data (Risk Data)
riskWithIDs = innerjoin(rawData, longID_all, 'Keys', 'userKey');
riskWithIDs.dt = datetime(riskWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
riskWithIDs = sortrows(riskWithIDs, {'redcapID', 'dt'}, 'ascend');

[G_risk, redcapIDs_risk] = findgroups(riskWithIDs.redcapID);

riskTable = table(redcapIDs_risk, ...
    splitapply(@(x) x(1), riskWithIDs.gender, G_risk), ...
    splitapply(@(x) x(1), riskWithIDs.age_denseSampling, G_risk), ...
    splitapply(@(x) {vertcat(x{:})}, {riskWithIDs.gameData.data}', G_risk), ...
    splitapply(@(x) {{x'}}, {riskWithIDs.gameData.data}', G_risk), ...
    splitapply(@(x) {{x'}}, riskWithIDs.dt, G_risk), ...
    'VariableNames', {'redcapID', 'gender', 'age', 'gameDataStacked', 'gameMatrices', 'gameDates'});

%% 4. Process Survey Data (Using your specific scoring logic)
% Filter by config
phq9gad7data = surveyData(surveyData.configFileName == "config_clinical_survey_1_PHQ9_GAD7", :);
statedata    = surveyData(surveyData.configFileName == "config_clinical_survey_4_state", :);
masqbamidata = surveyData(surveyData.configFileName == "config_clinical_survey_2_MASQanhedonia_BAMI", :);

% Clean incomplete
phq9gad7data = phq9gad7data(cellfun(@(x) isequal(size(x), [18, 5]), {phq9gad7data.surveyData.data}'), :);
statedata    = statedata(cellfun(@(x) isequal(size(x), [11, 5]), {statedata.surveyData.data}'), :);

% Your Scoring Logic
phq9gad7data.phq9score = cellfun(@(x) sum(cell2mat(x(1:9, 5)) - 1),   {phq9gad7data.surveyData.data}');
phq9gad7data.gad7score = cellfun(@(x) sum(cell2mat(x(11:18, 5)) - 1), {phq9gad7data.surveyData.data}'); 
masqbamidata.masqscore = cellfun(@(x) sum(6 - cell2mat(x(1:10, 5))),  {masqbamidata.surveyData.data}');
masqbamidata.bamiscore = cellfun(@(x) mean(cell2mat(x(11:16, 5)) - 1), {masqbamidata.surveyData.data}');

% State scores logic
statedata.mentalhealthscore = cellfun(@(x) x{8, 5}, {statedata.surveyData.data}');
statedata.posemoscore       = cellfun(@(x) x{9, 5}, {statedata.surveyData.data}');
statedata.negemoscore       = cellfun(@(x) x{10, 5}, {statedata.surveyData.data}');

% Join surveys with IDs to get redcapID
phq9gad7_ID = innerjoin(phq9gad7data, longID_all, 'Keys', 'userKey');
masqbami_ID = innerjoin(masqbamidata, longID_all, 'Keys', 'userKey');
state_ID    = innerjoin(statedata,    longID_all, 'Keys', 'userKey');

% Helper function to aggregate specific survey types
% (Using the bulletproof vertcat fix for consistent lists)
function surveyTable = aggregateSurvey(data, scoreVarName)
    data.dt = datetime(data.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    data = sortrows(data, {'redcapID', 'dt'}, 'ascend');
    [G, rID] = findgroups(data.redcapID);
    
    scoreList = splitapply(@(x) {{x'}}, data.(scoreVarName), G);
    dateList  = splitapply(@(x) {{x'}}, data.dt, G);
    
    surveyTable = table(rID, vertcat(scoreList{:}), vertcat(dateList{:}), ...
        'VariableNames', {'redcapID', strcat('list_', scoreVarName), strcat('dates_', scoreVarName)});
end

% Create individual survey aggregation tables
phqAgg   = aggregateSurvey(phq9gad7_ID, 'phq9score');
gadAgg   = aggregateSurvey(phq9gad7_ID, 'gad7score');
masqAgg  = aggregateSurvey(masqbami_ID, 'masqscore');
bamiAgg  = aggregateSurvey(masqbami_ID, 'bamiscore');
stateAgg = aggregateSurvey(state_ID,    'mentalhealthscore');

%% 5. Final Master Join
% Sequentially join everything by redcapID
riskDataMaster = riskTable;
riskDataMaster = outerjoin(riskDataMaster, phqAgg,   'Keys', 'redcapID', 'MergeKeys', true);
riskDataMaster = outerjoin(riskDataMaster, gadAgg,   'Keys', 'redcapID', 'MergeKeys', true);
riskDataMaster = outerjoin(riskDataMaster, masqAgg,  'Keys', 'redcapID', 'MergeKeys', true);
riskDataMaster = outerjoin(riskDataMaster, bamiAgg,  'Keys', 'redcapID', 'MergeKeys', true);
riskDataMaster = outerjoin(riskDataMaster, stateAgg, 'Keys', 'redcapID', 'MergeKeys', true);

% 6. Save
save('riskData_Master_Full.mat', 'riskDataMaster');
fprintf('Master Risk Data saved with %d participants.\n', height(riskDataMaster));

%% BuildLongID Helper
function longID = buildLongID(idData, keyCols)
    longID = table();
    for i = 1:numel(keyCols)
        col = keyCols{i};
        if ismember(col, idData.Properties.VariableNames)
            tmp = idData(:, {'redcapID', 'age_denseSampling', 'gender', 'phq8_scid'});
            tmp.userKey = idData.(col);
            tmp = tmp(tmp.userKey ~= "", :);
            longID = [longID; tmp];
        end
    end
end