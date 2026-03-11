clear; clc

% Load data
tmp = load("../data/raw/database_nimh_depression_survey.mat");
surveydata = tmp.T_data;
idData = load("../data/raw/subjectInfo_nimh_depression.mat").T_subjectInfo;

% Define userKey columns
denseKeyCols   = {'userKey_denseSampling', 'userKey_denseSampling_2'};
monthlyKeyCols = {'userKey_monthlyFollowup', 'userKey_monthlyFollowup_2', 'userKey_monthlyFollowup_3'};
allKeyCols     = [denseKeyCols, monthlyKeyCols];

% Build long ID lookup table
longID = buildLongID(idData, denseKeyCols, monthlyKeyCols);
[~, uIdx] = unique(longID.userKey);
longID = longID(uIdx, :);

% Join to survey data on userKey
surveydata = outerjoin(longID, surveydata, 'Keys', 'userKey', 'MergeKeys', true, 'Type', 'right');

% Move redcapID to first column
surveydata = surveydata(:, ['redcapID', setdiff(surveydata.Properties.VariableNames, {'redcapID'}, 'stable')]);

% Helper function to add redCapID
function longID = buildLongID(idData, denseKeyCols, monthlyKeyCols)
    longID = table();
    allKeyCols = [denseKeyCols, monthlyKeyCols];
    for i = 1:numel(allKeyCols)
        col = allKeyCols{i};
        if ismember(col, idData.Properties.VariableNames)
            tmp         = idData(:, {'redcapID', 'age_denseSampling', 'gender', 'phq8_scid'});
            tmp.userKey = idData.(col);
            tmp         = tmp(tmp.userKey ~= "", :);
            if ismember(col, denseKeyCols)
                tmp.surveyType = repmat("dense", height(tmp), 1);
            else
                tmp.surveyType = repmat("monthly", height(tmp), 1);
            end
            longID = [longID; tmp];
        end
    end
end