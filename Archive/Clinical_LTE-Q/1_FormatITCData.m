% Format raw Gorilla ITC data into model-ready structure
% Output table has one row per participant with:
%   - publicID: participant public ID
%   - gameData: struct with .data matrix (trials x 10)
%       col 1: trial number
%       col 2: sooner/immediate amount
%       col 3: delay length for sooner/immediate amount (days)
%       col 4: later/delayed amount
%       col 5: delay length for later/delay amount (days)
%       col 6: chose delayed (1) or immediate (0)
%       col 7: choice RT (ms)
%       col 8: happiness rating (NaN if no rating on that trial)
%       col 9: happiness RT (ms, NaN if no rating)

clear; clc;

% Load raw data
raw_itc = readtable('itcdata_vall.csv'); 

% Filter out instructions
raw_itc = raw_itc(ismember(string(raw_itc.ZoneType), ["response_slider_endValue", "response_keyboard_single"]), :);

% Create happiness column
raw_itc.happyrating = NaN(height(raw_itc), 1);
idx = strcmp(raw_itc.ZoneType, 'response_slider_endValue');
raw_itc.happyrating(idx) = cellfun(@str2double, raw_itc.Response(idx));

% Create happiness RT column
raw_itc.happyratingRT = NaN(height(raw_itc), 1);
idx = strcmp(raw_itc.ZoneType, 'response_slider_endValue');
raw_itc.happyratingRT(idx) = raw_itc.ReactionTime(idx);

% Shift happiness ratings up by 1
happyidx = find(idx);
happyidx = happyidx(happyidx > 1);
samePpt = raw_itc.ParticipantPublicID(happyidx - 1) == raw_itc.ParticipantPublicID(happyidx);
happyidx = happyidx(samePpt);
raw_itc.happyrating(happyidx - 1) = raw_itc.happyrating(happyidx);
raw_itc.happyrating(happyidx) = NaN;

% Shift happiness RT up by 1
raw_itc.happyratingRT(happyidx - 1) = raw_itc.happyratingRT(happyidx);
raw_itc.happyratingRT(happyidx) = NaN;

% Remove happiness RT from original column for first instance per person
% (otherwise is duplicate)
firstRows = arrayfun(@(p) find(raw_itc.ParticipantPublicID == p, 1), unique(raw_itc.ParticipantPublicID));
raw_itc.ReactionTime(firstRows) = NaN;

% Create choice column
raw_itc.choice = double(strcmp(raw_itc.Response, 'Delay')); % 1 if delay

% Make choice NaN for happiness-only rating
raw_itc.choice(firstRows) = NaN;

% Create table row per participant
[~, idx] = unique(raw_itc.ParticipantPublicID);
itcdata = raw_itc(idx, {'ParticipantPublicID', 'ParticipantPrivateID', 'LocalDateAndTime',...
    'ExperimentID', 'ExperimentVersion', 'TaskVersion'});

% Create task data with happiness matrix
for p = 1:height(itcdata)
    pid = itcdata.ParticipantPublicID(p);
    pdata = raw_itc(raw_itc.ParticipantPublicID == pid, {'TrialNumber', 'moneyA', 'delayA', 'moneyB', ...
        'delayB', 'choice', 'ReactionTime', 'happyrating', 'happyratingRT'});
    itcdata.gameDataHappy{p} = table2array(pdata);
end

% Create task data without happiness matrix
raw_itc = raw_itc(~isnan(raw_itc.moneyA), :); % Remove happiness rows
raw_itc = raw_itc(~isnan(raw_itc.choice), :); % Remove rows with NaNs for choice
for p = 1:height(itcdata)
    pid = itcdata.ParticipantPublicID(p);
    pdata = raw_itc(raw_itc.ParticipantPublicID == pid, {'TrialNumber', 'moneyA', 'delayA', 'moneyB', ...
        'delayB', 'choice', 'ReactionTime'});
    itcdata.gameData{p} = table2array(pdata);
end

% Save
save('itcData.mat', 'itcdata')