function result = fitmodel_aa(indata)

% RESULT = fitmodel_aa_model(INDATA)
%
% INDATA is a matrix with at least 6 columns (col 3 certain amount, col 4
% win amount, col 5 loss amount, col 6 chose risky is 1, chose safe is 0)

result           = struct;
result.data      = indata;
result.betalabel = {'mu','lambda','alpha', 'betagain', 'betaloss'}; 
result.inx       = [1    2   0.8  0   0];   %initial values for parameters
result.lb        = [0.01 0.5 0.3 -1  -1]; %min values possible for design matrix
result.ub        = [20   5   1.3  1   1];   %max values
result.options   = optimset('Display','off','MaxIter',100000,'TolFun',1e-10,'TolX',1e-10,...
    'DiffMaxChange',1e-2,'DiffMinChange',1e-4,'MaxFunEvals',10000,'LargeScale','off');
warning off;                    %to see outputs use 'Display','iter'

try
    [b, ~, exitflag, output, ~, ~, H] = fmincon(@setup_aa_model,result.inx,[],[],[],[],result.lb,result.ub,[],result.options,result);
    clear temp;
    [loglike, utildiff, logodds, probchoice] = setup_aa_model(b, result);
    result.b          = b;      %parameter estimates
    result.se         = transpose(sqrt(diag(inv(H)))); %SEs for parameters from inverse of the Hessian
    result.modelLL    = -loglike;
    result.exitflag   = exitflag;
    result.output     = output;
    result.utildiff   = utildiff;
    result.logodds    = logodds;
    result.probchoice = probchoice;

    % adding pseudo-R2
    p_null = mean(indata(:,6));
    LL_null = sum(indata(:,6) .* log(p_null) + (1-indata(:,6)) .* log(1-p_null));
    LL_model = result.modelLL;
    result.pseudoR2 = 1 - (LL_model / LL_null); 
catch
    fprintf(1,'model fit failed\n');
end

end


function [loglike, utildiff, logodds, probchoice] = setup_aa_model(x, data)

data.mu         = x(1);
data.lambda     = x(2);
data.alpha      = x(3);
data.betagain   = x(4);
data.betaloss   = x(5);

[loglike, utildiff, logodds, probchoice] = aa_model(data);

end


function [loglike, utildiff, logodds, probchoice] = aa_model(data)

%data.data is a matrix with at least 6 columns (col 3 certain amount, col 4
%win amount, col 5 loss amount, col 6 chose risky is 1, chose safe is 0)
%data.lambda and data.mu are loss aversion and inverse temperature
%parameters. function returns -loglikelihood and vectors for trial-by-trial
%utility difference, logodds, and probability of taking the risky option

utilcertain   = (data.data(:,3)>0).*abs(data.data(:,3)).^data.alpha - ...
                (data.data(:,3)<0).*data.lambda.*abs(data.data(:,3)).^data.alpha;
winutil       = data.data(:,4).^data.alpha;   %utility for potential risky gain
lossutil      = -data.lambda*abs(data.data(:,5)).^data.alpha; %utility for potential risky loss
utilgamble    = 0.5*winutil+0.5*lossutil;         %utility for risky option
utildiff      = utilgamble - utilcertain;         %utility difference between risky and safe options
logodds       = data.mu*utildiff;                 %convert to logodds using noise parameter
probchoice = 1 ./ (1+exp(-logodds));              % Initialize probchoice

% Adjust probchoice for gain trials  
gain_trials = utilcertain > 0;
if data.betagain >= 0
    probchoice(gain_trials) = ((1-data.betagain) ./ (1+exp(-logodds(gain_trials)))) + data.betagain;
else
    probchoice(gain_trials) = ((1+data.betagain) ./ (1+exp(-logodds(gain_trials))));
end

% Adjust probchoice for loss trials  
loss_trials = utilcertain < 0;  
if data.betaloss >= 0
    probchoice(loss_trials) = ((1-data.betaloss) ./ (1+exp(-logodds(loss_trials)))) + data.betaloss;
else
    probchoice(loss_trials) = ((1+data.betaloss) ./ (1+exp(-logodds(loss_trials))));
end

choice        = data.data(:,6);                   %1 chose risky, 0 chose safe

probchoice(probchoice==0) = eps;                  %to prevent fmincon crashing from log zero
probchoice(probchoice==1) = 1-eps;
loglike       = - (transpose(choice(:))*log(probchoice(:)) + transpose(1-choice(:))*log(1-probchoice(:)));
loglike       = sum(loglike);                     %number to minimize

end