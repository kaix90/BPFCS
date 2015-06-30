% % % % % % % % % % % % % % % % % % % % % % % % % % %
% Test sparsity vs time vs M
% Pre-processing data through DWT
% % % % % % % % % % % % % % % % % % % % % % % % % % %

clear
clc

mdivision = 20;

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% Prepare raw data
% % % % % % % % % % % % % % % % % % % % % % % % % % %

RawInpLoad = load('15814m_ltdbECG_1h.mat');
RawInpLoad = RawInpLoad.val;
n_dl = 128;
m_dl = 51;
epochs = floor(length(RawInpLoad) / n_dl);    % 4517
RawInpLoad = RawInpLoad(1:n_dl * epochs);

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% Prepare training and testing data
% % % % % % % % % % % % % % % % % % % % % % % % % % %

RawInp = RawInpLoad(1:n_dl*epochs);
RawInp = reshape(RawInp , n_dl, epochs);
crossValidFactor = 0.7;

TrainInp = RawInp(:, 1:floor(epochs*crossValidFactor));
TestInp = RawInp(:, (size(TrainInp,2)+1):epochs);


n = 128;
XI = eye(n);
W = [];
for i = 1 : n
    W(:,i) = wavedec(XI(:,i),7,'db4');
end
mesh(W)




load sumsin; s = sumsin; 
% Perform decomposition at level 3 of s using db1. 
[c,l] = wavedec(s,3,'db1');
% Using some plotting commands,
% the following figure is generated.




wt = haarmtx(n_dl);
TrainInpDWT = wt * TrainInp;
% figure
% subplot(2,1,1)
% plot(TrainInp(:,1));
% subplot(2,1,2)
% plot(TrainInpDWT(:,1));
spar = 1- length(find(abs(TrainInpDWT)>15) ) / size(TrainInpDWT,1) / size(TrainInpDWT,2);
disp(sprintf('Sparsity after wavelet transformation is : %0.2f', spar));

TrainInpDWT = TrainInpDWT - repmat(mean(TrainInpDWT),[size(TrainInpDWT,1),1]);
TrainInpDWT = TrainInpDWT ./ repmat(sqrt(sum(TrainInpDWT.^2)),[size(TrainInpDWT,1),1]);

TestInp = TestInp - repmat(mean(TestInp),[size(TestInp,1),1]);
TestInp = TestInp ./ repmat(sqrt(sum(TestInp.^2)),[size(TestInp,1),1]);

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% Compressive sensing
% % % % % % % % % % % % % % % % % % % % % % % % % % %

samplesTrainDWT = size(TrainInpDWT,2);
samplesTest  = size(TestInp,2);

rsnr_dl = zeros(mdivision,length(1:floor(samplesTrainDWT / 50)));
res_dl = zeros(mdivision,length(1:floor(samplesTrainDWT / 50)));
sparsity_dl = zeros(mdivision,length(1:floor(samplesTrainDWT / 50)));
basis = cell(mdivision,length(1:floor(samplesTrainDWT / 50)));

%%

% parpool('local',20);
% poolobj = gcp('nocreate'); % If no pool, do not create new one.
% if isempty(poolobj)
%     poolsize = 0;
% else
%     poolsize = poolobj.NumWorkers;
% end

%%

 for i = 1:mdivision 
    m_dl = floor(i * n_dl / mdivision);
    phi_dl = randn(m_dl,n_dl);
        
    for j = 10 : floor(samplesTrainDWT / 50)      % adjust iter
        param = struct;
        param.iter = j;
        param.batchsize = 50;
        param.K = 512;
        param.lambda = 0.15;
        param.numThreads = -1; 
        param.verbose = false;
        
        res = 0;
        x2 = 0;
        spar = 0;
        prd = 0;
        xs_dl = [];
        x0_dl = [];
        xhat_dl = [];
        D = [];
        
        epochesD = floor(j * param.batchsize);
        D = mexTrainDL(TrainInpDWT(:,1:epochesD),param);

        basis(i, j) = {D};

        psi_dl = D;
        A_dl = phi_dl * wt' * psi_dl;

        for ep = 1:samplesTest
            y_dl = phi_dl * TestInp(:,ep);
            x0_dl = pinv(A_dl) * y_dl; 
            xs_dl = l1eq_pd(x0_dl, A_dl, [], y_dl, 1e-6); 
            xres_dl = wt' * psi_dl * xs_dl;
            
            res = res + sum(norm(TestInp(:,ep) - xres_dl).^2);
            x2 = x2 + sum(TestInp(:,ep).^2);
            spar = spar + length(find(abs(xs_dl)>0.001) ); 
        end
        rsnr_dl(i,j) = 20 * log10(sqrt(x2 / res));
        cr_dl = n_dl / m_dl;
        sparsity_dl(i,j) = 1 - spar / samplesTest / length(xs_dl);
        prd_dl(i,j) = sqrt(res / x2);
    end
end

% delete(poolobj)

filename = sprintf('./Results/PreDWT_m%d_batchsize%d.mat', mdivision, 50);
save(filename)

subplot(211)
plot(TestInp(:,ep));
subplot(212)
plot(xres_dl);

%% % % % % % % % % % % % % % % % % % % % % % % % % % %
% Plot results
% % % % % % % % % % % % % % % % % % % % % % % % % % %

load ./Results/DWT40.mat
cc = jet(20);
str = cell(1,mdivision-1);

%% figure
j = 1 : floor(samplesTrainDWT / 50) 
subplot(3,1,1)
for i = 1 : mdivision-1
    plot(floor(j * 50),rsnr_dl(i,:),'Color',cc(i,:) ) ;
    str{i}=['m=',num2str(floor(i * n_dl / mdivision))];
    hold on
end
legend(str)
xlabel('Iterations');
ylabel('RSNR(dB)');

subplot(3,1,2)
for i = 1 : mdivision-1
    plot(floor(j * 50),res_dl(i,:),'Color',cc(i,:) );
    str{i}=['m=',num2str(floor(i * n_dl / mdivision))];
    hold on
end
% legend(str)
xlabel('Iterations');
ylabel('MSE');

subplot(3,1,3)
for i = 1 : mdivision-1
    plot(floor(j * 50),sparsity_dl(i,:),'Color',cc(i,:) );
    str{i}=['m=',num2str(floor(i * n_dl / mdivision))];
    hold on
end
% legend(str)
xlabel('Iterations');
ylabel('Sparsity');


%%

% load ./Results/Pre_m20_batchsize50.mat
% load ./Results/DWT40.mat

figure
epV = 50 * (1 : floor(samplesTrainDWT / 50)); 
mV = floor(n_dl/mdivision: n_dl/mdivision: n_dl);

[M,I] = min(abs(rsnr_dl(1:19,:)'-20) );
obj = {M',I'};
obj{1,2}(:,2) = obj{:,1};
i = [19, 17, 11, 10, 9, 7, 6, 5];
plot(epV(I(i)),mV(i),'Color',cc(1,:));
hold on

[M,I] = min(abs(rsnr_dl(1:19,:)'-23) );
obj = {M',I'};
obj{1,2}(:,2) = obj{:,1};
i = [19, 14, 12, 11, 10, 9, 8, 7];
plot(epV(I(i)),mV(i),'Color',cc(3,:));
hold on

[M,I] = min(abs(rsnr_dl(1:19,:)'-25) );
obj = {M',I'};
obj{1,2}(:,2) = obj{:,1};
i = [19, 16, 15, 13, 12, 10];
plot(epV(I(i)),mV(i),'Color',cc(5,:));
hold on

[M,I] = min(abs(rsnr_dl(1:19,:)'-27) );
obj = {M',I'};
obj{1,2}(:,2) = obj{:,1};
i = [18, 16, 15, 14, 13, 12];
plot(epV(I(i)),mV(i),'Color',cc(7,:));
hold on


%%

[M,I] = min(abs(rsnr_dl_dwt - 20) );
plot([200,3200], [m_dl_dwt(I),m_dl_dwt(I)],'Color',cc(11,:));
hold on

[M,I] = min(abs(rsnr_dl_dwt - 23) );
plot([200,3200], [m_dl_dwt(I),m_dl_dwt(I)],'Color',cc(13,:));
hold on

[M,I] = min(abs(rsnr_dl_dwt - 25) );
plot([200,3200], [m_dl_dwt(I),m_dl_dwt(I)],'Color',cc(15,:));
hold on

[M,I] = min(abs(rsnr_dl_dwt - 27) );
plot([200,3200], [m_dl_dwt(I),m_dl_dwt(I)],'Color',cc(17,:));
hold on

str = {'RSNR\_DL = 20dB','RSNR\_DL = 23dB','RSNR\_DL = 25dB', 'RSNR\_DL = 27dB', ...
       'RSNR\_DWT = 20dB','RSNR\_DWT = 23dB','RSNR\_DWT = 25dB', 'RSNR\_DWT = 27dB'};

legend(str);
xlabel('Iterations');
ylabel('m');
axis([0 3300 0 130])

%%