% extract signal in each voxel averaging over several TRs following trial
% events, save values for input to further analysis

clear

sublist = [7];
% find my root directory - up a few dirs from where i am now
mypath = pwd;
filesepinds = find(mypath==filesep);
nDirsUp = 2;
exp_path = mypath(1:filesepinds(end-nDirsUp+1));

%% params here
trDur = .8; % actual duration of the TR, for plotting, in seconds...
nTRs = 583-16;

ROI_names = {'V1','V2','V3','V3AB','hV4','IPS0','IPS1','IPS2','IPS3','LO1','LO2',...
    'S1','M1','Premotor'...
    'IFS', 'AI-FO', 'iPCS', 'sPCS','sIPS','ACC-preSMA','M1-S1 all'};

nROIs = length(ROI_names);
hemi_names={'lh','rh'};

% which TRs am i averaging over? From the target onset time.
avgTRs_targ = [10,16];
% also averaging over data after the response probe onset - get a response
% related HRF in motor areas.
avgTRs_resp = [4,10];

% how many TRs to use for TR-by-TR analyses?
nTRs2concat = 30;
% nRuns = 20;
nTrialsPerRun=20;
    
%% load data    
for ss = sublist

    mainSig = struct();

    substr = sprintf('S%02d',ss);
   
    fn2load = fullfile(exp_path,'Samples',sprintf('SampleFile_%s.mat',substr));
    load(fn2load, 'samplesMain','ROIs','all_vox_concat');
    
    %% load the timing file (made in GetEventTiming.m)
    
    fn = fullfile(exp_path,'Samples',sprintf('TimingFile_%s.mat',substr));
    if ~exist(fn, 'file')
        error('need to make timing file first, run GetEventTiming.m')
    end
    fprintf('Loading event timing file\n')
    load(fn)
    
    fn2save = fullfile(exp_path,'Samples',sprintf('MainTaskSignalByTrial_SepHemis_%s.mat',substr));    
   
    %%
    for vv = 1:nROIs % for all visual areas I want to look at
        
        for hh  =1:length(hemi_names)
            %% pull out the data from each ROI
            % want both hemispheres
            [rowind1,colind1] = find(strcmp(reshape({ROIs.name},2,nROIs-1),sprintf('%s_%s',hemi_names{hh},ROI_names{vv})));
            
            col_inds = [colind1]; % column is the region
            row_inds = [rowind1];   % row is the hemisphere
            
            if strcmp(ROI_names{vv},'M1-S1 all')
                inds=[12:14];
                row_inds=[];col_inds=[];
                for ii = inds

                    [r1,c1] = find(reshape(contains({ROIs.name}, sprintf('%s_%s',hemi_names{hh},ROI_names{ii})),2,[]));
                   
                    if isempty(r1) 
                        fprintf('no voxels in %s for %s\n',ROI_names{ii}, substr);
                    end
                    row_inds=[row_inds; r1];
                    col_inds=[col_inds; c1];
                end
            end
            mainDat=[]; 
            eccVals = [];
            for ii=1:length(col_inds)
                name = ROIs(row_inds(ii),col_inds(ii)).name;
                if ~isempty(ROIs(row_inds(ii),col_inds(ii)).voxel_inds)
                    % jj gives indices into the all_vox_concat array
                    [~,jj]=intersect(all_vox_concat, ROIs(row_inds(ii),col_inds(ii)).voxel_inds);
                    mainDat = [mainDat, samplesMain(:,jj)];
                end
            end
            nVox = size(mainDat,2);

            if nVox==0
                fprintf('no voxels in %s area %s!\n',hemi_names{hh},ROI_names{vv});
                continue
            end

            fprintf('processing %s area %s, %d voxels\n',hemi_names{hh}, ROI_names{vv}, nVox);

            %% now zscore the data from each run to normalize...

            nRuns = size(mainDat,1)/nTRs; % hopefully 5 runs per session
            if mod(nRuns,1)~=0
                error('something bad happened here with mainDat run length')
            end
            for ii=1:nRuns
                mainDat(ii*nTRs-nTRs+1:ii*nTRs,:) = zscore(mainDat(ii*nTRs-nTRs+1:ii*nTRs, :),1);
            end

            assert(numel(unique(main.RunLabels))==nRuns);
            %% label the data
            % event labels are as follows:
            % pre-targ cue, targ, delay1, cue, bound-preview, delay2,
            % bound-actual, start ITI
            % Event_type = [Event_type, [0.2, 1, 0, 0.3, 2, 0, 3, 0]];
            event_labels_reshaped = reshape(main.EventLabels,nTRs,length(main.EventLabels)/nTRs);

            % now find the actual onset of each trial - switch from 0.2 to 1
            % (or 0 to 1)
            trial_onset_bool = event_labels_reshaped==1;
            trial_onset_bool = trial_onset_bool(:);
            trial_onset_num = find(trial_onset_bool);

            resp_onset_bool = [zeros(1, size(event_labels_reshaped,2)); diff(event_labels_reshaped)==3];
            resp_onset_bool = resp_onset_bool(:);
            resp_onset_num = find(resp_onset_bool);

            nTrials = nRuns*nTrialsPerRun;
            assert(numel(trial_onset_num)==nTrials);

            %% save out a bunch of descriptors for the trials

            mainSig(vv,hh).runLabs = main.RunLabels(trial_onset_num);
            mainSig(vv,hh).trialLabs = main.TrialLabels(trial_onset_num);
            mainSig(vv,hh).condLabs = main.CondLabels(trial_onset_num);

            targPos = main.TargPos(trial_onset_num);
            mainSig(vv,hh).targPos = targPos;

            boundPos = main.BoundPos(trial_onset_num);
            mainSig(vv,hh).boundPos = boundPos;

            randBoundPos=main.RandBoundPos(trial_onset_num);
            mainSig(vv,hh).randBoundPos = randBoundPos;
            
            mainSig(vv,hh).RespActual = main.RespActual(trial_onset_num);
            mainSig(vv,hh).CorrectResp = main.CorrectResp(trial_onset_num);
            mainSig(vv,hh).RTLabs = main.RTLabels(trial_onset_num);

            mainSig(vv,hh).condLabStrs = {'Predictable','Random'};

            %% compute the signed distance to the boundary for each trial
            % first for real boundary (the one shown at end of trial
            quad1 = mod(boundPos,180)<90;   
            quad2 = mod(boundPos,180)>90;
            mb = mod(boundPos,180);
            mt = mod(targPos,180);
            is_cw1 = quad1 & ( targPos<mb | (targPos>(mb+90) & targPos<(mb+180)) | targPos>mb+270 );
            is_cw2 = quad2 & ( (targPos>(mb-90) & targPos<mb) | (targPos>(mb+90) & targPos<(mb+180)) );
           
            dir_to_real_bound = zeros(size(targPos));   % 1 for CW, 2 for CCW
            dir_to_real_bound(is_cw1 | is_cw2) = 1;
            dir_to_real_bound(dir_to_real_bound==0) = 2;

            dist_to_real_bound = min([abs(mb-mt), 180-abs(mb-mt)],[],2);
            
            % second for fake boundary (for random trials, the first one shown)
            quad1 = mod(randBoundPos,180)<90;   
            quad2 = mod(randBoundPos,180)>90;
            mb = mod(randBoundPos,180);
            mt = mod(targPos,180);
            is_cw1 = quad1 & ( targPos<mb | (targPos>(mb+90) & targPos<(mb+180)) | targPos>mb+270 );
            is_cw2 = quad2 & ( (targPos>(mb-90) & targPos<mb) | (targPos>(mb+90) & targPos<(mb+180)) );
           
            dir_to_rand_bound = zeros(size(targPos));   % 1 for CW, 2 for CCW
            dir_to_rand_bound(is_cw1 | is_cw2) = 1;
            dir_to_rand_bound(dir_to_rand_bound==0) = 2;

            dist_to_rand_bound = min([abs(mb-mt), 180-abs(mb-mt)],[],2);

            dir_to_rand_bound(isnan(randBoundPos)) = nan;
            dist_to_rand_bound(isnan(randBoundPos)) = nan;

            mainSig(vv,hh).dist_to_real_bound = dist_to_real_bound;
            mainSig(vv,hh).dir_to_real_bound = dir_to_real_bound;
            mainSig(vv,hh).dist_to_rand_bound = dist_to_rand_bound;
            mainSig(vv,hh).dir_to_rand_bound = dir_to_rand_bound;
            mainSig(vv,hh).dirToBoundLabs={'CW (-)','CCW (+)'};
            %% some extra plotting code to check the calculations i did above.
            % can comment out usually
    %         close all
    %         xc = cosd([0:10:360]);
    %         yc = sind([0:10:360]);
    %         dirlabs={'CW (-)','CCW (+)'};
    %         for xx=[10:15];
    %             figure;hold all;
    % 
    %             plot(0,0,'.');
    %             scatter(cosd(targPos(xx)),sind(targPos(xx)),'k');
    %             if dir_to_real_bound(xx)==1
    %                 scatter(cosd(targPos(xx)-5),sind(targPos(xx)-5),'r');
    %             else
    %                 scatter(cosd(targPos(xx)+5),sind(targPos(xx)+5),'r');
    %             end
    %             plot([0,cosd(boundPos(xx))],[0,sind(boundPos(xx))],'-');
    %             plot([0,cosd(180+boundPos(xx))],[0,sind(180+boundPos(xx))],'-');
    %             plot(xc,yc,'-');
    %             title(sprintf('targ=%.1f deg, bound=%.1f deg\ndistance = %.1f, %s',targPos(xx),boundPos(xx),dist_to_real_bound(xx),dirlabs{dir_to_real_bound(xx)}));
    %             xlim([-1.2, 1.2]);
    %             ylim([-1.2, 1.2]);
    %             axis square
    %         end
            %
            %% avg the data across each trial
            % single value for each trial, averaged over multiple TRs
            dat_avg_targ = nan(nTrials, nVox); 
            dat_avg_resp = nan(nTrials, nVox);
            % TR-by-TR data        
            dat_by_TR = nan(nTrials, nTRs2concat, nVox);

            triCnt = 0; % counter across "good" trials where the entire desired avg window is available.

            for rr=1:nRuns

                runInd = rr*nTRs-nTRs+1:rr*nTRs;
                assert(all(find(main.RunLabels==rr)==runInd'))
                curDat = mainDat(runInd,:);      % data from current run

                % get numeric indices for each event in this run
                these_targ_onsets = find(trial_onset_bool(runInd));                   
                these_resp_onsets = find(resp_onset_bool(runInd));

                assert(numel(these_targ_onsets)==numel(these_resp_onsets))
                assert(numel(these_targ_onsets)==nTrialsPerRun);

                for tt=1:numel(these_targ_onsets)
                    % check to make sure we don't go past the end of the run.
                    if these_targ_onsets(tt)+nTRs2concat<=nTRs && these_resp_onsets(tt)+avgTRs_resp(2)<=nTRs

                        triCnt = triCnt + 1;  % increment counter over good trials

                        % sum the data over desired interval.
                        dat_avg_targ(triCnt,:) = mean(curDat(these_targ_onsets(tt)+avgTRs_targ(1):these_targ_onsets(tt)+avgTRs_targ(2),:));
                        dat_avg_resp(triCnt,:) = mean(curDat(these_resp_onsets(tt)+avgTRs_resp(1):these_resp_onsets(tt)+avgTRs_resp(2),:));

                    end

                    % also collecting data at each timept
                    for tr = 1:nTRs2concat
                        if these_targ_onsets(tt)+tr-1<=nTRs 
                            dat_by_TR(triCnt,tr,:) = curDat(these_targ_onsets(tt)+tr-1,:);
                        else
                            error('TR %d is past the end of your run!!', tr)
                        end
                    end
                end
            end

            assert(triCnt==nTrials)
            assert(~sum(isnan(dat_avg_targ(:))) && ~sum(isnan(dat_by_TR(:))))
            assert(~sum(isnan(dat_avg_resp(:))))

            mainSig(vv,hh).dat_avg = dat_avg_targ;
            mainSig(vv,hh).dat_avg_resp = dat_avg_resp;

            % this matrix is [nTrials x nTRs x nVox]
            mainSig(vv,hh).dat_by_TR = dat_by_TR;
        end
    end

    fprintf('saving to %s\n',fn2save);
    save(fn2save,'mainSig','ROI_names');

end