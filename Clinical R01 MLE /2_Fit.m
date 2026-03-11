% Fit prospect theory (single alpha) model to risk data
clear;clc

% Load risk data and extract data from structure to table format
data = load("data_cleaned.mat").data_cleaned;
%data = load("fitdata_cleaned.mat").data;

%% Fit prospect theory (single alpha) model to risk data
% Overall fit - dense, monthly, and mri
for s = 1:height(data)
    if isempty(data.riskDataStacked{s})
        % True for 2 people
        data.result_pt{s} = [];
        data.b_pt{s}      = [];
        data.pr2_pt(s)     = NaN;
        data.pGamble(s)    = NaN;
        data.pGamGain(s)   = NaN;
        data.pGamMix(s)    = NaN;
        continue
    end
    t = data.riskDataStacked{s};
    result_pt = fitmodel_PT1alpha(t);
    data.result_pt{s} = result_pt;
    data.b_pt{s}      = result_pt.b;
    data.pr2_pt(s)     = result_pt.pseudoR2;
    data.pGamble(s)    = mean(t(:,6));
    data.pGamGain(s)   = mean(t(t(:,3)>0, 6));
    data.pGamMix(s)    = mean(t(t(:,3)==0, 6));
end

%% Fit per-session
for s = 1:height(data)
    if isempty(data.riskMatrices{s})
        data.result_pt_ses{s} = {};
        data.b_pt_ses{s}      = {};
        data.pr2_pt_ses{s}    = [];
        data.pGamble_ses{s}   = [];
        data.pGamGain_ses{s}  = [];
        data.pGamMix_ses{s}   = [];
        continue
    end

    nSes = numel(data.riskMatrices{s});
    data.result_pt_ses{s} = cell(1, nSes);
    data.b_pt_ses{s}      = cell(1, nSes);
    data.pr2_pt_ses{s}    = NaN(1, nSes);
    data.pGamble_ses{s}   = NaN(1, nSes);
    data.pGamGain_ses{s}  = NaN(1, nSes);
    data.pGamMix_ses{s}   = NaN(1, nSes);

    for k = 1:nSes
        tk = data.riskMatrices{s}{k};
        if isempty(tk) || size(tk, 2) < 6
            data.result_pt_ses{s}{k} = [];
            data.b_pt_ses{s}{k}      = [];
            continue
        end
        try
            res = fitmodel_PT1alpha(tk);
            data.result_pt_ses{s}{k} = res;
            data.b_pt_ses{s}{k}      = res.b;
            data.pr2_pt_ses{s}(k)    = res.pseudoR2;
        catch
            data.result_pt_ses{s}{k} = [];
            data.b_pt_ses{s}{k}      = [];
        end
        data.pGamble_ses{s}(k)  = mean(tk(:,6));
        data.pGamGain_ses{s}(k) = mean(tk(tk(:,3)>0, 6));
        data.pGamMix_ses{s}(k)  = mean(tk(tk(:,3)==0, 6));
    end
end

%% Fit MRI data

% Fit
for s = 1:height(data)
    if isempty(data.mriRisk_data{s})
        data.result_pt_mri{s} = [];
        data.b_pt_mri{s}      = [];
        data.pr2_pt_mri(s)    = NaN;
        data.pGamble_mri(s)   = NaN;
        data.pGamGain_mri(s)  = NaN;
        data.pGamMix_mri(s)   = NaN;
        continue
    end
    t = data.mriRisk_data{s};
    t = t(~isnan(t(:,6)), :);  % remove trials with NaN choices
    try
        result_pt_mri = fitmodel_PT1alpha(t);
        data.result_pt_mri{s} = result_pt_mri;
        data.b_pt_mri{s}      = result_pt_mri.b;
        data.pr2_pt_mri(s)    = result_pt_mri.pseudoR2;
    catch
        fprintf('MRI fit failed: redcapID %s\n', string(data.redcapID(s)));
        data.result_pt_mri{s} = [];
        data.b_pt_mri{s}      = [];
        data.pr2_pt_mri(s)    = NaN;
    end
    data.pGamble_mri(s)  = mean(t(:,6));
    data.pGamGain_mri(s) = mean(t(t(:,3)>0, 6));
    data.pGamMix_mri(s)  = mean(t(t(:,3)==0, 6));
end

%% Save Risk fit
save("fit_data_cleaned.mat", "data")