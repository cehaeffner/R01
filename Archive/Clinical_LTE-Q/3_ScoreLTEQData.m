% Format LTE-Q data
clear; clc;

lteq_raw = readtable("lteqdata_vall.csv");

% Remove row with value in response that is not a score
lteq_raw = lteq_raw(~strcmp(lteq_raw.QuestionKey, 'END QUESTIONNAIRE'), :);

% Compute and extract scores
lteq = groupsummary(lteq_raw, 'ParticipantPublicID', 'sum', 'Response');

% Rename sum_Response col
lteq = renamevars(lteq, "sum_Response", "lteq_score");

% Save
save("lteqdata.mat", "lteq")

