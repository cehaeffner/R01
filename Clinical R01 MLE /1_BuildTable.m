%% Consolidates Game Data and Survey Data into one Table
clear; clc

%% 1. Load and label data
idData      = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;
riskData    = load("../data/raw/database_nimh_depression_reward.mat").T_data;
rlData      = load("../data/raw/database_nimh_depression_fruit.mat").T_data;
surveyData  = load("../data/raw/database_nimh_depression_survey.mat").T_data;
lteqData    = load("../data/raw/lteqdata.mat").lteq;
mriRiskData = load("../data/raw/mri_day_gambling.mat").mri_alldata;

% Add Ids
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};
allKeyCols     = [denseKeyCols, monthlyKeyCols];
longID_all     = buildLongID(idData, allKeyCols);

% Add session type
riskData.SessionType = strings(height(riskData), 1);
riskData.SessionType(ismember(riskData.enrolNumber, [801, 501, 502, 52]))   = "dense";
riskData.SessionType(ismember(riskData.enrolNumber, [601, 602, 61, 62]))    = "monthly";

rlData.SessionType = strings(height(rlData), 1);
rlData.SessionType(ismember(rlData.enrolNumber, [801, 501, 502, 52]))       = "dense";
rlData.SessionType(ismember(rlData.enrolNumber, [601, 602, 61, 62]))        = "monthly";

surveyData.SessionType = strings(height(surveyData), 1);
surveyData.SessionType(ismember(surveyData.enrolNumber, [801, 501, 502, 52])) = "dense";
surveyData.SessionType(ismember(surveyData.enrolNumber, [601, 602, 61, 62]))  = "monthly";

%% 2. Process Game Data
% Risk
riskWithIDs = innerjoin(riskData, longID_all, 'Keys', 'userKey');
riskWithIDs.dt = datetime(riskWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
riskWithIDs = sortrows(riskWithIDs, {'redcapID', 'dt'}, 'ascend');

[G_risk, redcapIDs_risk] = findgroups(riskWithIDs.redcapID);

riskTable = table(redcapIDs_risk, ...
    splitapply(@(x) {x'}, riskWithIDs.SessionType, G_risk), ...
    splitapply(@(x) x(1), riskWithIDs.gender, G_risk), ...
    splitapply(@(x) x(1), riskWithIDs.age_denseSampling, G_risk), ...
    splitapply(@(x) {vertcat(x.data)}, riskWithIDs.gameData, G_risk), ...
    splitapply(@(x) {x'}, {riskWithIDs.gameData.data}', G_risk), ...
    splitapply(@(x) {x'}, riskWithIDs.dt, G_risk), ...
    'VariableNames', {'redcapID', 'riskSessionType', 'gender', 'age', 'riskDataStacked', 'riskMatrices', 'riskDates'});

% RL
rlWithIDs = innerjoin(rlData, longID_all, 'Keys', 'userKey');
rlWithIDs.dt = datetime(rlWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
rlWithIDs = sortrows(rlWithIDs, {'redcapID', 'dt'}, 'ascend');

[G_rl, redcapIDs_rl] = findgroups(rlWithIDs.redcapID);

rlTable = table(redcapIDs_rl, ...
    splitapply(@(x) {x'}, rlWithIDs.SessionType, G_rl), ...
    splitapply(@(x) {vertcat(x.data)}, rlWithIDs.gameData, G_rl), ...
    splitapply(@(x) {x'}, {rlWithIDs.gameData.data}', G_rl), ...
    splitapply(@(x) {x'}, rlWithIDs.dt, G_rl), ...
    'VariableNames', {'redcapID', 'rlSessionType', 'rlDataStacked', 'rlMatrices', 'rlDates'});

%% 3. Process Survey Data
% Filter by config
phq9gad7data = surveyData(surveyData.configFileName == "config_clinical_survey_1_PHQ9_GAD7", :);
statedata    = surveyData(surveyData.configFileName == "config_clinical_survey_4_state", :);
masqbamidata = surveyData(surveyData.configFileName == "config_clinical_survey_2_MASQanhedonia_BAMI", :);

% Clean incomplete
phq9gad7data = phq9gad7data(cellfun(@(x) isequal(size(x), [18, 5]), {phq9gad7data.surveyData.data}'), :);
statedata    = statedata(cellfun(@(x) isequal(size(x), [11, 5]), {statedata.surveyData.data}'), :);

% Score
phq9gad7data.phq9scores = cellfun(@(x) sum(cell2mat(x(1:9, 5)) - 1),   {phq9gad7data.surveyData.data}');
phq9gad7data.gad7scores = cellfun(@(x) sum(cell2mat(x(11:18, 5)) - 1), {phq9gad7data.surveyData.data}');
masqbamidata.masqscores = cellfun(@(x) sum(6 - cell2mat(x(1:10, 5))),  {masqbamidata.surveyData.data}');
masqbamidata.bamiscores = cellfun(@(x) mean(cell2mat(x(11:16, 5)) - 1), {masqbamidata.surveyData.data}');
statedata.mentalhealthscores = cellfun(@(x) x{8, 5}, {statedata.surveyData.data}');
statedata.posemoscores       = cellfun(@(x) x{9, 5}, {statedata.surveyData.data}');
statedata.negemoscores       = cellfun(@(x) x{10, 5}, {statedata.surveyData.data}');

% Add un-scored state items
statedata.eatenToday      = cellfun(@(x) x{1, 5}, {statedata.surveyData.data}');
statedata.caffeineToday   = cellfun(@(x) x{2, 5}, {statedata.surveyData.data}');
statedata.smokeToday      = cellfun(@(x) x{3, 5}, {statedata.surveyData.data}');
statedata.alcoholPast24   = cellfun(@(x) x{4, 5}, {statedata.surveyData.data}');
statedata.sleepHours      = cellfun(@(x) x{5, 5}, {statedata.surveyData.data}');
statedata.exerciseMinutes = cellfun(@(x) x{6, 5}, {statedata.surveyData.data}');
statedata.yogaMinutes     = cellfun(@(x) x{7, 5}, {statedata.surveyData.data}');

% Join surveys with IDs to get redcapID
phq9gad7_ID = innerjoin(phq9gad7data, longID_all, 'Keys', 'userKey');
masqbami_ID = innerjoin(masqbamidata, longID_all, 'Keys', 'userKey');
state_ID    = innerjoin(statedata,    longID_all, 'Keys', 'userKey');

% Aggregate survey data
phqAgg   = aggregateSurvey(phq9gad7_ID, {'phq9scores'});
gadAgg   = aggregateSurvey(phq9gad7_ID, {'gad7scores'});
masqAgg  = aggregateSurvey(masqbami_ID, {'masqscores'});
bamiAgg  = aggregateSurvey(masqbami_ID, {'bamiscores'});
stateAgg = aggregateSurvey(state_ID, {'mentalhealthscores', 'posemoscores', 'negemoscores', ...
             'eatenToday', 'caffeineToday', 'smokeToday', ...
             'alcoholPast24', 'sleepHours', 'exerciseMinutes', 'yogaMinutes'});

% Rename dates & session types to unique names per survey
phqAgg   = renamevars(phqAgg,   {'surveyDates','sessionTypes'}, {'phqDates','phqSessionTypes'});
gadAgg   = renamevars(gadAgg,   {'surveyDates','sessionTypes'}, {'gadDates','gadSessionTypes'});
masqAgg  = renamevars(masqAgg,  {'surveyDates','sessionTypes'}, {'masqDates','masqSessionTypes'});
bamiAgg  = renamevars(bamiAgg,  {'surveyDates','sessionTypes'}, {'bamiDates','bamiSessionTypes'});
stateAgg = renamevars(stateAgg, {'surveyDates','sessionTypes'}, {'stateDates','stateSessionTypes'});

% Add participant means
phqAgg.phqMean     = cellfun(@(x) mean(x, 'omitnan'), phqAgg.phq9scores);
gadAgg.gadMean     = cellfun(@(x) mean(x, 'omitnan'), gadAgg.gad7scores);
bamiAgg.bamiMean   = cellfun(@(x) mean(x, 'omitnan'), bamiAgg.bamiscores);
masqAgg.masqMean   = cellfun(@(x) mean(x, 'omitnan'), masqAgg.masqscores);
stateAgg.mhMean    = cellfun(@(x) mean(x, 'omitnan'), stateAgg.mentalhealthscores);
stateAgg.peMean    = cellfun(@(x) mean(x, 'omitnan'), stateAgg.posemoscores);
stateAgg.neMean    = cellfun(@(x) mean(x, 'omitnan'), stateAgg.negemoscores);
stateAgg.eatMean   = cellfun(@(x) mean(x, 'omitnan'), stateAgg.eatenToday);
stateAgg.cafMean   = cellfun(@(x) mean(x, 'omitnan'), stateAgg.caffeineToday);
stateAgg.smokeMean = cellfun(@(x) mean(x, 'omitnan'), stateAgg.smokeToday);
stateAgg.alcMean   = cellfun(@(x) mean(x, 'omitnan'), stateAgg.alcoholPast24);
stateAgg.sleepMean = cellfun(@(x) mean(x, 'omitnan'), stateAgg.sleepHours);
stateAgg.exercMean = cellfun(@(x) mean(x, 'omitnan'), stateAgg.exerciseMinutes);
stateAgg.yogaMean  = cellfun(@(x) mean(x, 'omitnan'), stateAgg.yogaMinutes);

%% 4. Join Tables
data = riskTable;
data = outerjoin(data, rlTable,  'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, phqAgg,   'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, gadAgg,   'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, masqAgg,  'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, bamiAgg,  'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, stateAgg, 'Keys', 'redcapID', 'MergeKeys', true);

%% 5. Add MRI day gambling
mriRiskData = renamevars(struct2table(mriRiskData), {'id', 'data'}, {'redcapID', 'mriRisk_data'});
data = outerjoin(data, mriRiskData, 'Keys', 'redcapID', 'Type', 'left', 'MergeKeys', true);

%% 6. Add LTEQ
lteqData = renamevars(lteqData, 'ParticipantPublicID', 'redcapID');
lteqData(:, 2) = [];
data = outerjoin(data, lteqData, 'Keys', 'redcapID', 'Type', 'left', 'MergeKeys', true);

%% 6. Save
save('data.mat', 'data');
fprintf('Data saved with %d participants.\n', height(data));

%% 7. Remove same-day duplicates (keep first per day)
for s = 1:height(data)
    % Risk
    if iscell(data.riskDates) && ~isempty(data.riskDates{s})
        dates = dateshift(data.riskDates{s}, 'start', 'day');
        [~, idx] = unique(dates, 'first');
        data.riskMatrices{s}    = data.riskMatrices{s}(idx);
        data.riskDates{s}       = data.riskDates{s}(idx);
        data.riskSessionType{s} = data.riskSessionType{s}(idx);
        data.riskDataStacked{s} = vertcat(data.riskMatrices{s}{:});
    end

    % RL
    if iscell(data.rlDates) && ~isempty(data.rlDates{s})
        dates = dateshift(data.rlDates{s}, 'start', 'day');
        [~, idx] = unique(dates, 'first');
        data.rlMatrices{s}     = data.rlMatrices{s}(idx);
        data.rlDates{s}        = data.rlDates{s}(idx);
        data.rlSessionType{s}  = data.rlSessionType{s}(idx);
        data.rlDataStacked{s}  = vertcat(data.rlMatrices{s}{:});
    end

    % PHQ
    if iscell(data.phqDates) && ~isempty(data.phqDates{s})
        dates = dateshift(data.phqDates{s}, 'start', 'day');
        [~, idx] = unique(dates, 'first');
        data.phqDates{s}        = data.phqDates{s}(idx);
        data.phqSessionTypes{s} = data.phqSessionTypes{s}(idx);
        data.phq9scores{s}      = data.phq9scores{s}(idx);
    end

    % GAD
    if iscell(data.gadDates) && ~isempty(data.gadDates{s})
        dates = dateshift(data.gadDates{s}, 'start', 'day');
        [~, idx] = unique(dates, 'first');
        data.gadDates{s}        = data.gadDates{s}(idx);
        data.gadSessionTypes{s} = data.gadSessionTypes{s}(idx);
        data.gad7scores{s}      = data.gad7scores{s}(idx);
    end

    % MASQ
    if iscell(data.masqDates) && ~isempty(data.masqDates{s})
        dates = dateshift(data.masqDates{s}, 'start', 'day');
        [~, idx] = unique(dates, 'first');
        data.masqDates{s}        = data.masqDates{s}(idx);
        data.masqSessionTypes{s} = data.masqSessionTypes{s}(idx);
        data.masqscores{s}       = data.masqscores{s}(idx);
    end

    % BAMI
    if iscell(data.bamiDates) && ~isempty(data.bamiDates{s})
        dates = dateshift(data.bamiDates{s}, 'start', 'day');
        [~, idx] = unique(dates, 'first');
        data.bamiDates{s}        = data.bamiDates{s}(idx);
        data.bamiSessionTypes{s} = data.bamiSessionTypes{s}(idx);
        data.bamiscores{s}       = data.bamiscores{s}(idx);
    end

    % State
    if iscell(data.stateDates) && ~isempty(data.stateDates{s})
        dates = dateshift(data.stateDates{s}, 'start', 'day');
        [~, idx] = unique(dates, 'first');
        data.stateDates{s}        = data.stateDates{s}(idx);
        data.stateSessionTypes{s} = data.stateSessionTypes{s}(idx);
        stateVars = {'mentalhealthscores','posemoscores','negemoscores',...
            'eatenToday','caffeineToday','smokeToday','alcoholPast24',...
            'sleepHours','exerciseMinutes','yogaMinutes'};
        for v = 1:numel(stateVars)
            data.(stateVars{v}){s} = data.(stateVars{v}){s}(idx);
        end
    end
end

% Recalculate means after dedup
data.phqMean   = cellfun(@(x) mean(x, 'omitnan'), data.phq9scores);
data.gadMean   = cellfun(@(x) mean(x, 'omitnan'), data.gad7scores);
data.masqMean  = cellfun(@(x) mean(x, 'omitnan'), data.masqscores);
data.bamiMean  = cellfun(@(x) mean(x, 'omitnan'), data.bamiscores);
data.mhMean    = cellfun(@(x) mean(x, 'omitnan'), data.mentalhealthscores);
data.peMean    = cellfun(@(x) mean(x, 'omitnan'), data.posemoscores);
data.neMean    = cellfun(@(x) mean(x, 'omitnan'), data.negemoscores);
data.eatMean   = cellfun(@(x) mean(x, 'omitnan'), data.eatenToday);
data.cafMean   = cellfun(@(x) mean(x, 'omitnan'), data.caffeineToday);
data.smokeMean = cellfun(@(x) mean(x, 'omitnan'), data.smokeToday);
data.alcMean   = cellfun(@(x) mean(x, 'omitnan'), data.alcoholPast24);
data.sleepMean = cellfun(@(x) mean(x, 'omitnan'), data.sleepHours);
data.exercMean = cellfun(@(x) mean(x, 'omitnan'), data.exerciseMinutes);
data.yogaMean  = cellfun(@(x) mean(x, 'omitnan'), data.yogaMinutes);

%% 8. Save deduplicated
data_deduped = data;
save('data_deduped.mat', 'data_deduped');
fprintf('Deduplicated data saved with %d participants.\n', height(data));

%% Helper Functions
function surveyTable = aggregateSurvey(data, varNames)
    data.dt = datetime(data.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    data = sortrows(data, {'redcapID', 'dt'}, 'ascend');

    [G, rID] = findgroups(data.redcapID);

    surveyTable = table(rID, 'VariableNames', {'redcapID'});

    for i = 1:length(varNames)
        colName = varNames{i};
        surveyTable.(colName) = splitapply(@(x) {x'}, data.(colName), G);
    end

    surveyTable.surveyDates  = splitapply(@(x) {x'}, data.dt, G);
    surveyTable.sessionTypes = splitapply(@(x) {x'}, data.SessionType, G);
end

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