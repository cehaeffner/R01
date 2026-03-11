function result = fitmodel_happy_evrpe(data)

%function result = fit_happytask_evrpe(data)
%
%data is a matrix where columns 3-5 are certain/gamblegain/gambleloss,
%column 6 is 1 if they gambled, column 8 is trial outcome, column 9 is the
%raw happiness rating (0-1)
%
%Robb Rutledge, October 2020

happyind          = find(~isnan(data(:,9)));    %trials with ratings after them
rawhappy          = data(happyind,9);           %all of the ratings
certainmtx        = zeros(length(rawhappy),size(data,1)); %history certain rewards
rewardmtx         = zeros(length(rawhappy),size(data,1)); %history gamble rewards
evmtx = certainmtx; rpemtx = certainmtx;

for m = 1:length(happyind)                       %to first rating
    t             = data(1:happyind(m),:);       %clip out all trials up to rating
    tempcertain   = t(:,8) .* (t(:,6)==0);       %trial outcomes for certain reward
    tempreward    = t(:,8) .* (t(:,6)==1);       %trial outcomes for gamble reward
    tempev        = mean(t(:,4:5),2) .* (t(:,6)==1); %0 if no gamble or error, ev if gambled
    temprpe       = t(:,8) .* (t(:,6)==1) - tempev;  %0 if no gamble or error, rpe if gambled
    certainmtx(m,1:length(tempcertain)) = fliplr(transpose(tempcertain))/100; %per 100 points
    rewardmtx(m,1:length(tempreward))   = fliplr(transpose(tempreward))/100; %per 100 points
    evmtx(m,1:length(tempev))           = fliplr(transpose(tempev)) / 100;
    rpemtx(m,1:length(temprpe))         = fliplr(transpose(temprpe)) / 100;
end

result.rawhappy   = rawhappy;
result.certainmtx = certainmtx;
result.rewardmtx  = rewardmtx;
result.evmtx      = evmtx;
result.rpemtx     = rpemtx;
result.options    = optimset('Display','off','MaxIter',1000,'TolFun',1e-5,'TolX',1e-5,...
    'DiffMaxChange',1e-2,'DiffMinChange',1e-4,'MaxFunEvals',1000,'LargeScale','off');
warning off; %display,iter to see outputs
result.inx        = [0    0    0    0.5 0.5]; %reward, tau, const
result.lb         = [-100 -100 -100 0   0];
result.ub         = [100  100  100  1   1];
result.blabel     = {'certain','ev','rpe','tau','const'};

b = fmincon(@happymodel,result.inx,[],[],[],[],result.lb,result.ub,[],result.options,result);

result.b          = b;
[sse, happypred, r2] = happymodel(b, result);
result.happypred  = happypred;
result.r2         = r2;
result.sse        = sse;


function [sse, happypred, r2] =  happymodel(x, data)

cert      = x(1); %certain
ev        = x(2); %ev
rpe       = x(3); %rpe
tau       = x(4); %decay constant
const     = x(5); %baseline happiness parameter

decayvec  = tau.^(0:size(data.rewardmtx,2)-1); decayvec = decayvec(:);
happypred = cert*data.certainmtx*decayvec + ev*data.evmtx*decayvec + ...
    rpe*data.rpemtx*decayvec + const;
sse       = sum((data.rawhappy-happypred).^2); %sum least-squares error
re        = sum((data.rawhappy-mean(data.rawhappy)).^2); r2 = 1-sse/re;
