%% Consolidates Game Data and Survey Data into one Table
clear; clc

%% 1. Load data
idData      = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;
riskData    = load("../data/raw/database_nimh_depression_reward.mat").T_data;
rlData      = load("../data/raw/database_nimh_depression_fruit.mat").T_data;
surveyData  = load("../data/raw/database_nimh_depression_survey.mat").T_data;
lteqData    = load("../data/raw/lteqdata.mat").lteq;
mriRiskData = load("../data/raw/mri_day_gambling.mat").mri_alldata;

%% 2. Build long ID table
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};
allKeyCols     = [denseKeyCols, monthlyKeyCols];
longID_all     = buildLongID(idData, allKeyCols);

%% 3. Label session types on raw data
riskData.SessionType = strings(height(riskData), 1);
riskData.SessionType(ismember(riskData.enrolNumber, [801, 501, 502, 52]))     = "dense";
riskData.SessionType(ismember(riskData.enrolNumber, [601, 602, 61, 62]))      = "monthly";

rlData.SessionType = strings(height(rlData), 1);
rlData.SessionType(ismember(rlData.enrolNumber, [801, 501, 502, 52]))         = "dense";
rlData.SessionType(ismember(rlData.enrolNumber, [601, 602, 61, 62]))          = "monthly";

surveyData.SessionType = strings(height(surveyData), 1);
surveyData.SessionType(ismember(surveyData.enrolNumber, [801, 501, 502, 52])) = "dense";
surveyData.SessionType(ismember(surveyData.enrolNumber, [601, 602, 61, 62]))  = "monthly";

%% 4. Process risk data — join, sort, compute hours & nums, then aggregate
riskWithIDs = innerjoin(riskData, longID_all, 'Keys', 'userKey');
riskWithIDs.dt = datetime(riskWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
riskWithIDs = sortrows(riskWithIDs, {'redcapID', 'dt'}, 'ascend');

% Compute hours since first dense/monthly per participant (before grouping)
riskWithIDs.hoursSinceDense1  = NaN(height(riskWithIDs), 1);
riskWithIDs.hoursSinceMonthly1 = NaN(height(riskWithIDs), 1);
riskWithIDs.denseNum   = NaN(height(riskWithIDs), 1);
riskWithIDs.monthlyNum = NaN(height(riskWithIDs), 1);

ids = unique(riskWithIDs.redcapID);
for i = 1:numel(ids)
    idx = riskWithIDs.redcapID == ids(i);
    rows = find(idx);
    types = riskWithIDs.SessionType(rows);
    dates = riskWithIDs.dt(rows);

    denseRows = rows(types == "dense");
    if ~isempty(denseRows)
        hrs = hours(dates(types == "dense") - dates(types == "dense"));
        hrs = hours(riskWithIDs.dt(denseRows) - riskWithIDs.dt(denseRows(1)));
        riskWithIDs.hoursSinceDense1(denseRows) = hrs;
        riskWithIDs.denseNum(denseRows) = round(hrs / 24) + 1;
    end

    monthlyRows = rows(types == "monthly");
    if ~isempty(monthlyRows)
        hrs = hours(riskWithIDs.dt(monthlyRows) - riskWithIDs.dt(monthlyRows(1)));
        riskWithIDs.hoursSinceMonthly1(monthlyRows) = hrs;
        riskWithIDs.monthlyNum(monthlyRows) = round(hrs / (30*24)) + 1;
    end
end

% Aggregate into per-participant table
[G_risk, redcapIDs_risk] = findgroups(riskWithIDs.redcapID);

riskTable = table(redcapIDs_risk, ...
    splitapply(@(x) {x'}, riskWithIDs.SessionType, G_risk), ...
    splitapply(@(x) x(1), riskWithIDs.gender, G_risk), ...
    splitapply(@(x) x(1), riskWithIDs.age_denseSampling, G_risk), ...
    splitapply(@(x) {vertcat(x.data)}, riskWithIDs.gameData, G_risk), ...
    splitapply(@(x) {x'}, {riskWithIDs.gameData.data}', G_risk), ...
    splitapply(@(x) {x'}, riskWithIDs.dt, G_risk), ...
    splitapply(@(x) {x(~isnan(x))'}, riskWithIDs.hoursSinceDense1, G_risk), ...
    splitapply(@(x) {x(~isnan(x))'}, riskWithIDs.hoursSinceMonthly1, G_risk), ...
    splitapply(@(x) {x(~isnan(x))'}, riskWithIDs.denseNum, G_risk), ...
    splitapply(@(x) {x(~isnan(x))'}, riskWithIDs.monthlyNum, G_risk), ...
    'VariableNames', {'redcapID', 'riskSessionType', 'gender', 'age', ...
        'riskDataStacked', 'riskMatrices', 'riskDates', ...
        'riskHoursSinceDense1', 'riskHoursSinceMonthly1', 'riskDenseNum', 'riskMonthlyNum'});

%% 5. Process RL data — same approach as risk
rlWithIDs = innerjoin(rlData, longID_all, 'Keys', 'userKey');
rlWithIDs.dt = datetime(rlWithIDs.startDateTimeLocal, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
rlWithIDs = sortrows(rlWithIDs, {'redcapID', 'dt'}, 'ascend');

% Compute hours since first dense/monthly per participant
rlWithIDs.hoursSinceDense1   = NaN(height(rlWithIDs), 1);
rlWithIDs.hoursSinceMonthly1 = NaN(height(rlWithIDs), 1);
rlWithIDs.denseNum   = NaN(height(rlWithIDs), 1);
rlWithIDs.monthlyNum = NaN(height(rlWithIDs), 1);

ids = unique(rlWithIDs.redcapID);
for i = 1:numel(ids)
    idx = rlWithIDs.redcapID == ids(i);
    rows = find(idx);
    types = rlWithIDs.SessionType(rows);

    denseRows = rows(types == "dense");
    if ~isempty(denseRows)
        hrs = hours(rlWithIDs.dt(denseRows) - rlWithIDs.dt(denseRows(1)));
        rlWithIDs.hoursSinceDense1(denseRows) = hrs;
        rlWithIDs.denseNum(denseRows) = round(hrs / 24) + 1;
    end

    monthlyRows = rows(types == "monthly");
    if ~isempty(monthlyRows)
        hrs = hours(rlWithIDs.dt(monthlyRows) - rlWithIDs.dt(monthlyRows(1)));
        rlWithIDs.hoursSinceMonthly1(monthlyRows) = hrs;
        rlWithIDs.monthlyNum(monthlyRows) = round(hrs / (30*24)) + 1;
    end
end

% Aggregate
[G_rl, redcapIDs_rl] = findgroups(rlWithIDs.redcapID);

rlTable = table(redcapIDs_rl, ...
    splitapply(@(x) {x'}, rlWithIDs.SessionType, G_rl), ...
    splitapply(@(x) {vertcat(x.data)}, rlWithIDs.gameData, G_rl), ...
    splitapply(@(x) {x'}, {rlWithIDs.gameData.data}', G_rl), ...
    splitapply(@(x) {x'}, rlWithIDs.dt, G_rl), ...
    splitapply(@(x) {x(~isnan(x))'}, rlWithIDs.hoursSinceDense1, G_rl), ...
    splitapply(@(x) {x(~isnan(x))'}, rlWithIDs.hoursSinceMonthly1, G_rl), ...
    splitapply(@(x) {x(~isnan(x))'}, rlWithIDs.denseNum, G_rl), ...
    splitapply(@(x) {x(~isnan(x))'}, rlWithIDs.monthlyNum, G_rl), ...
    'VariableNames', {'redcapID', 'rlSessionType', 'rlDataStacked', 'rlMatrices', 'rlDates', ...
        'rlHoursSinceDense1', 'rlHoursSinceMonthly1', 'rlDenseNum', 'rlMonthlyNum'});

%% 6. Process survey data
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

% Un-scored state items
statedata.eatenToday      = cellfun(@(x) x{1, 5}, {statedata.surveyData.data}');
statedata.caffeineToday   = cellfun(@(x) x{2, 5}, {statedata.surveyData.data}');
statedata.smokeToday      = cellfun(@(x) x{3, 5}, {statedata.surveyData.data}');
statedata.alcoholPast24   = cellfun(@(x) x{4, 5}, {statedata.surveyData.data}');
statedata.sleepHours      = cellfun(@(x) x{5, 5}, {statedata.surveyData.data}');
statedata.exerciseMinutes = cellfun(@(x) x{6, 5}, {statedata.surveyData.data}');
statedata.yogaMinutes     = cellfun(@(x) x{7, 5}, {statedata.surveyData.data}');

% Join with IDs
phq9gad7_ID = innerjoin(phq9gad7data, longID_all, 'Keys', 'userKey');
masqbami_ID = innerjoin(masqbamidata, longID_all, 'Keys', 'userKey');
state_ID    = innerjoin(statedata,    longID_all, 'Keys', 'userKey');

% Aggregate surveys (includes dates & session types)
phqAgg   = aggregateSurvey(phq9gad7_ID, {'phq9scores'});
gadAgg   = aggregateSurvey(phq9gad7_ID, {'gad7scores'});
masqAgg  = aggregateSurvey(masqbami_ID, {'masqscores'});
bamiAgg  = aggregateSurvey(masqbami_ID, {'bamiscores'});
stateAgg = aggregateSurvey(state_ID, {'mentalhealthscores', 'posemoscores', 'negemoscores', ...
             'eatenToday', 'caffeineToday', 'smokeToday', ...
             'alcoholPast24', 'sleepHours', 'exerciseMinutes', 'yogaMinutes'});

% Rename to unique names per survey
phqAgg   = renamevars(phqAgg,   {'surveyDates','sessionTypes'}, {'phqDates','phqSessionTypes'});
gadAgg   = renamevars(gadAgg,   {'surveyDates','sessionTypes'}, {'gadDates','gadSessionTypes'});
masqAgg  = renamevars(masqAgg,  {'surveyDates','sessionTypes'}, {'masqDates','masqSessionTypes'});
bamiAgg  = renamevars(bamiAgg,  {'surveyDates','sessionTypes'}, {'bamiDates','bamiSessionTypes'});
stateAgg = renamevars(stateAgg, {'surveyDates','sessionTypes'}, {'stateDates','stateSessionTypes'});

% Participant means
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

% Participant SDs
phqAgg.phqSD     = cellfun(@(x) std(x, 'omitnan'), phqAgg.phq9scores);
gadAgg.gadSD     = cellfun(@(x) std(x, 'omitnan'), gadAgg.gad7scores);
bamiAgg.bamiSD   = cellfun(@(x) std(x, 'omitnan'), bamiAgg.bamiscores);
masqAgg.masqSD   = cellfun(@(x) std(x, 'omitnan'), masqAgg.masqscores);
stateAgg.mhSD    = cellfun(@(x) std(x, 'omitnan'), stateAgg.mentalhealthscores);
stateAgg.peSD    = cellfun(@(x) std(x, 'omitnan'), stateAgg.posemoscores);
stateAgg.neSD    = cellfun(@(x) std(x, 'omitnan'), stateAgg.negemoscores);
stateAgg.eatSD   = cellfun(@(x) std(x, 'omitnan'), stateAgg.eatenToday);
stateAgg.cafSD   = cellfun(@(x) std(x, 'omitnan'), stateAgg.caffeineToday);
stateAgg.smokeSD = cellfun(@(x) std(x, 'omitnan'), stateAgg.smokeToday);
stateAgg.alcSD   = cellfun(@(x) std(x, 'omitnan'), stateAgg.alcoholPast24);
stateAgg.sleepSD = cellfun(@(x) std(x, 'omitnan'), stateAgg.sleepHours);
stateAgg.exercSD = cellfun(@(x) std(x, 'omitnan'), stateAgg.exerciseMinutes);
stateAgg.yogaSD  = cellfun(@(x) std(x, 'omitnan'), stateAgg.yogaMinutes);

%% 7. Join all tables
data = riskTable;
data = outerjoin(data, rlTable,  'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, phqAgg,   'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, gadAgg,   'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, masqAgg,  'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, bamiAgg,  'Keys', 'redcapID', 'MergeKeys', true);
data = outerjoin(data, stateAgg, 'Keys', 'redcapID', 'MergeKeys', true);

%% Add additional data
% Add MRI risk data
mriRiskData = renamevars(struct2table(mriRiskData), {'id', 'data'}, {'redcapID', 'mriRisk_data'});
data = outerjoin(data, mriRiskData, 'Keys', 'redcapID', 'Type', 'left', 'MergeKeys', true);

% For mri data, columns are different order
% Swap columns 6 and 7 in MRI data, then append to stacked risk data
for s = 1:height(data)
    if ~isempty(data.mriRisk_data{s})
        t = data.mriRisk_data{s};
        t(:,6)  = t(:,7);      % col 7 -> col 6 (choice)
        t(:,7)  = t(:,9);      % col 9 -> col 7 (choice RT)
        t(:,9)  = t(:,10)/100; % col 10 -> col 9, scaled by 100 (happy)
        t(:,10) = t(:,11);     % col 11 -> col 10 (happy RT)
        t(:,11:end) = [];      % remove cols 11-15 (outcome in 14, not needed)
        t(isnan(t(:,6)), :) = [];  % remove NaN choice trials
        data.mriRisk_data{s} = t;
    end
end

% Stack
for s = 1:height(data)
    if ~isempty(data.mriRisk_data{s})
        data.riskDataStacked{s} = [data.riskDataStacked{s}; data.mriRisk_data{s}];
    end
end

% Add LTEQ
lteqData = renamevars(lteqData, 'ParticipantPublicID', 'redcapID');
lteqData(:, 2) = [];
data = outerjoin(data, lteqData, 'Keys', 'redcapID', 'Type', 'left', 'MergeKeys', true);

%% 8. Save raw data
save('data.mat', 'data');
fprintf('Data saved with %d participants.\n', height(data));

%% 9. Same-day dedup — keep first session per day
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

%% 10. Recompute hours & session nums after dedup (risk & RL)
for s = 1:height(data)
    % Risk
    if isempty(data.riskDates{s}) || isempty(data.riskSessionType{s})
        data.riskHoursSinceDense1{s} = []; data.riskHoursSinceMonthly1{s} = [];
        data.riskDenseNum{s} = []; data.riskMonthlyNum{s} = [];
    else
        dates = data.riskDates{s}; types = data.riskSessionType{s};
        dI = find(types == "dense"); mI = find(types == "monthly");
        if ~isempty(dI)
            data.riskHoursSinceDense1{s} = hours(dates(dI) - dates(dI(1)));
            data.riskDenseNum{s} = round(data.riskHoursSinceDense1{s} / 24) + 1;
        else
            data.riskHoursSinceDense1{s} = []; data.riskDenseNum{s} = [];
        end
        if ~isempty(mI)
            data.riskHoursSinceMonthly1{s} = hours(dates(mI) - dates(mI(1)));
            data.riskMonthlyNum{s} = round(data.riskHoursSinceMonthly1{s} / (30*24)) + 1;
        else
            data.riskHoursSinceMonthly1{s} = []; data.riskMonthlyNum{s} = [];
        end
    end

    % RL
    if isempty(data.rlDates{s}) || isempty(data.rlSessionType{s})
        data.rlHoursSinceDense1{s} = []; data.rlHoursSinceMonthly1{s} = [];
        data.rlDenseNum{s} = []; data.rlMonthlyNum{s} = [];
    else
        dates = data.rlDates{s}; types = data.rlSessionType{s};
        dI = find(types == "dense"); mI = find(types == "monthly");
        if ~isempty(dI)
            data.rlHoursSinceDense1{s} = hours(dates(dI) - dates(dI(1)));
            data.rlDenseNum{s} = round(data.rlHoursSinceDense1{s} / 24) + 1;
        else
            data.rlHoursSinceDense1{s} = []; data.rlDenseNum{s} = [];
        end
        if ~isempty(mI)
            data.rlHoursSinceMonthly1{s} = hours(dates(mI) - dates(mI(1)));
            data.rlMonthlyNum{s} = round(data.rlHoursSinceMonthly1{s} / (30*24)) + 1;
        else
            data.rlHoursSinceMonthly1{s} = []; data.rlMonthlyNum{s} = [];
        end
    end
end

%% 11. Remove duplicate session nums — keep closest to expected timing
for s = 1:height(data)
    % Risk dense
    if ~isempty(data.riskDenseNum{s})
        [data] = removeDupeNums(data, s, 'risk', 'dense', 24);
    end
    % Risk monthly
    if ~isempty(data.riskMonthlyNum{s})
        [data] = removeDupeNums(data, s, 'risk', 'monthly', 30*24);
    end
    % RL dense
    if ~isempty(data.rlDenseNum{s})
        [data] = removeDupeNums(data, s, 'rl', 'dense', 24);
    end
    % RL monthly
    if ~isempty(data.rlMonthlyNum{s})
        [data] = removeDupeNums(data, s, 'rl', 'monthly', 30*24);
    end
end

%% 12. Remove sessions beyond limits (risk: dense>14, monthly>6; RL same)
for s = 1:height(data)
    % Risk
    data = removeOverLimit(data, s, 'risk', 'dense', 14);
    data = removeOverLimit(data, s, 'risk', 'monthly', 6);
    % RL
    data = removeOverLimit(data, s, 'rl', 'dense', 14);
    data = removeOverLimit(data, s, 'rl', 'monthly', 6);
end

%% 12.5 Rebuild stacked with MRI data included
for s = 1:height(data)
    % Restack from cleaned matrices
    if ~isempty(data.riskMatrices{s})
        data.riskDataStacked{s} = vertcat(data.riskMatrices{s}{:});
    end
    % Append MRI data
    if ~isempty(data.mriRisk_data{s})
        data.riskDataStacked{s} = [data.riskDataStacked{s}; data.mriRisk_data{s}];
    end
end

%% 13. Recalculate survey means & SDs after dedup
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

data.phqSD   = cellfun(@(x) std(x, 'omitnan'), data.phq9scores);
data.gadSD   = cellfun(@(x) std(x, 'omitnan'), data.gad7scores);
data.bamiSD  = cellfun(@(x) std(x, 'omitnan'), data.bamiscores);
data.masqSD  = cellfun(@(x) std(x, 'omitnan'), data.masqscores);
data.mhSD    = cellfun(@(x) std(x, 'omitnan'), data.mentalhealthscores);
data.peSD    = cellfun(@(x) std(x, 'omitnan'), data.posemoscores);
data.neSD    = cellfun(@(x) std(x, 'omitnan'), data.negemoscores);
data.eatSD   = cellfun(@(x) std(x, 'omitnan'), data.eatenToday);
data.cafSD   = cellfun(@(x) std(x, 'omitnan'), data.caffeineToday);
data.smokeSD = cellfun(@(x) std(x, 'omitnan'), data.smokeToday);
data.alcSD   = cellfun(@(x) std(x, 'omitnan'), data.alcoholPast24);
data.sleepSD = cellfun(@(x) std(x, 'omitnan'), data.sleepHours);
data.exercSD = cellfun(@(x) std(x, 'omitnan'), data.exerciseMinutes);
data.yogaSD  = cellfun(@(x) std(x, 'omitnan'), data.yogaMinutes);

%% 14. Save cleaned data
data_cleaned = data;
save('data_cleaned.mat', 'data_cleaned');
fprintf('Cleaned data saved with %d participants.\n', height(data_cleaned));

%% Helper functions

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

% Remove duplicate session numbers — keep the one closest to expected timing
function data = removeDupeNums(data, s, task, sessionType, hoursPerUnit)
    if strcmp(task, 'risk')
        numsField = 'riskDenseNum'; hrsField = 'riskHoursSinceDense1'; typeField = 'riskSessionType';
        matField = 'riskMatrices'; dateField = 'riskDates'; stackField = 'riskDataStacked';
        if strcmp(sessionType, 'monthly')
            numsField = 'riskMonthlyNum'; hrsField = 'riskHoursSinceMonthly1';
        end
    else
        numsField = 'rlDenseNum'; hrsField = 'rlHoursSinceDense1'; typeField = 'rlSessionType';
        matField = 'rlMatrices'; dateField = 'rlDates'; stackField = 'rlDataStacked';
        if strcmp(sessionType, 'monthly')
            numsField = 'rlMonthlyNum'; hrsField = 'rlHoursSinceMonthly1';
        end
    end

    hrs = data.(hrsField){s};
    nums = data.(numsField){s};
    uniqueNums = unique(nums);
    keepIdx = true(1, numel(nums));

    for n = 1:numel(uniqueNums)
        dupeIdx = find(nums == uniqueNums(n));
        if numel(dupeIdx) > 1
            expectedHours = (uniqueNums(n) - 1) * hoursPerUnit;
            [~, bestIdx] = min(abs(hrs(dupeIdx) - expectedHours));
            remove = dupeIdx; remove(bestIdx) = [];
            keepIdx(remove) = false;
        end
    end

    if ~all(keepIdx)
        fullIdx = find(data.(typeField){s} == sessionType);
        removeFromFull = fullIdx(~keepIdx);
        keepFull = true(1, numel(data.(typeField){s}));
        keepFull(removeFromFull) = false;

        data.(matField){s}  = data.(matField){s}(keepFull);
        data.(dateField){s} = data.(dateField){s}(keepFull);
        data.(typeField){s} = data.(typeField){s}(keepFull);
        if ~isempty(data.(matField){s})
            data.(stackField){s} = vertcat(data.(matField){s}{:});
        end
        data.(hrsField){s}  = hrs(keepIdx);
        data.(numsField){s} = nums(keepIdx);
    end
end

% Remove sessions beyond a limit
function data = removeOverLimit(data, s, task, sessionType, limit)
    if strcmp(task, 'risk')
        numsField = 'riskDenseNum'; hrsField = 'riskHoursSinceDense1'; typeField = 'riskSessionType';
        matField = 'riskMatrices'; dateField = 'riskDates'; stackField = 'riskDataStacked';
        if strcmp(sessionType, 'monthly')
            numsField = 'riskMonthlyNum'; hrsField = 'riskHoursSinceMonthly1';
        end
    else
        numsField = 'rlDenseNum'; hrsField = 'rlHoursSinceDense1'; typeField = 'rlSessionType';
        matField = 'rlMatrices'; dateField = 'rlDates'; stackField = 'rlDataStacked';
        if strcmp(sessionType, 'monthly')
            numsField = 'rlMonthlyNum'; hrsField = 'rlHoursSinceMonthly1';
        end
    end

    if isempty(data.(numsField){s}), return; end

    over = data.(numsField){s} > limit;
    if ~any(over), return; end

    fullIdx = find(data.(typeField){s} == sessionType);
    removeFromFull = fullIdx(over);
    keepFull = true(1, numel(data.(typeField){s}));
    keepFull(removeFromFull) = false;

    data.(matField){s}  = data.(matField){s}(keepFull);
    data.(dateField){s} = data.(dateField){s}(keepFull);
    data.(typeField){s} = data.(typeField){s}(keepFull);
    if ~isempty(data.(matField){s})
        data.(stackField){s} = vertcat(data.(matField){s}{:});
    end
    data.(hrsField){s}  = data.(hrsField){s}(~over);
    data.(numsField){s} = data.(numsField){s}(~over);
end