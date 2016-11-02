function dogDescriptor(inputimage,outputfile,siz,sig1,sig2,ROI,rt)
%GENDESCTIPTOR returns difference of gaussian Descriptors 
% 
% [OUTPUTARGS] = DOGDESCTIPTOR(INPUTARGS) 
%   dog = gauss1(sig1)-gauss2(sig1) : difference kernel
%   out = input*dog : convolution
%   out > max(out)/rt : only keep signal > ratio threshold
%   out : [x-y-z-I] : spatial location and intensity at that location
% 
% Inputs: 
%   inputimage: input file can be tif or h5
%   siz: gaussian kernel width
%   sig1: scale of first gaussian
%   sig2: scale of secong gaussian
%   ROI: reject anything outside of BoundingBox
%   rt: threshold ratio
% 
% Outputs: 
%   outputfile: text file that has x-y-z-I values as row vectors
% 
% Examples: 
%   dogDescriptor('/nobackup2/mouselight/cluster/2016-09-25/classifier_output/2016-10-02/00/00314/00314-prob.0.h5',...
%   '/groups/mousebrainmicro/mousebrainmicro/cluster/Stitching/2016-09-25/Descriptors/13844-prob.0.txt',...
%   '[11 11 11]','[3.405500 3.405500 3.405500]','[4.049845 4.049845 4.049845]','[5 1019 5 1531 10 250]','4')
% 
% See also: zmatch.m

% $Author: base $	$Date: 2016/09/20 14:30:14 $	$Revision: 0.1 $
% Copyright: HHMI 2016
tload=tic;
[~,~,fileext] = fileparts(inputimage);
if strcmp(fileext,'.h5')
    It = permute(squeeze(h5read(inputimage,'/exported_data')),[2 1 3]);
else
    It = deployedtiffread(inputimage);
end
fprintf('Read %s in %f sec\n',inputimage,toc(tload))
dims = size(It);
sig1 = eval(sig1);
sig2 = eval(sig2);
siz = eval(siz);
if nargin<6
    ROI = ['''',num2str([1 dims(2) 1 dims(1) 1 dims(3)]),''''];
    rt='4';
elseif nargin<7
    rt='4';
end
ROI = eval(ROI);
rt = eval(rt);
%%
sig = sig1;
[x,y,z] = ndgrid(-siz(1):siz(1),-siz(2):siz(2),-siz(3):siz(3));
h = exp(-(x.*x/2/sig(1)^2 + y.*y/2/sig(2)^2 + z.*z/2/sig(3)^2));
gauss1 = h/sum(h(:));

% sig2 = 3.4055002;
% sig = sig2*ones(1,3);
sig = sig2;
[x,y,z] = ndgrid(-siz(1):siz(1),-siz(2):siz(2),-siz(3):siz(3));
h = exp(-(x.*x/2/sig(1)^2 + y.*y/2/sig(2)^2 + z.*z/2/sig(3)^2));
gauss2 = h/sum(h(:));
dog = gauss1 - gauss2;

outsiz = size(It)+size(dog);%2.^nextpow2(size(It)+size(dog));
tcon = tic;
It = fftn(It,outsiz);
fftdog = fftn(dog,outsiz);
It = ifftn(It.*fftdog);
It = real(It);
fprintf('Convolution of %s in %f sec\n',inputimage,toc(tcon))

st = (size(dog)+1)/2+1; 
ed = st+dims-1;
It = It(st(1):ed(1),st(2):ed(2),st(3):ed(3)); % crop
It(It<max(It(:))/rt)=0;

%%
tloc = tic;
if 0
    It = imregionalmax(It,26);
    [yy,xx,zz] = ind2sub(size(It),find(It));
else
    s  = regionprops(It>0, 'BoundingBox');
    clear submax
    for ii=1:length(s)
        bb = s(ii).BoundingBox;
        st = bb([2 1 3])+.5;
        en = st+bb([5 4 6])-1;
        It_ = It(st(1):en(1),st(2):en(2),st(3):en(3));
        %     figure, imshow3D(It_)
        immax = imregionalmax(It_.*double(It_>0));
        idxmax = find(immax);
        [iy,ix,iz] = ind2sub(size(immax),idxmax);
        submax{ii} = ones(length(iy),1)*st+[iy(:),ix(:),iz(:)]-1;
    end
    localmax = cat(1,submax{:});
    xx = localmax(:,2);
    yy = localmax(:,1);
    zz = localmax(:,3);
end
fprintf('Local maxima of %s in %f sec\n',inputimage,toc(tloc))
%%
validinds = xx>=ROI(1)&xx<=ROI(2)&yy>=ROI(3)&yy<=ROI(4)&zz>=ROI(5)&zz<=ROI(6);
des = [xx(:),yy(:),zz(:)];
des = des(validinds,:);
vals = (It(sub2ind(size(It),des(:,2),des(:,1),des(:,3))));
des = [des vals]';
%% return uniform sampling over spatial domain


%%
fid = fopen(outputfile,'w');
fprintf(fid,'%d %d %d %f\n',des);
fclose(fid);
end

function [Iout] = deployedtiffread(fileName,slices)
%DEPLOYEDTIFFREAD Summary of this function goes here
% 
% [OUTPUTARGS] = DEPLOYEDTIFFREAD(INPUTARGS) Explain usage here
% 
% Examples: 
% 
% Provide sample usage code here
% 
% See also: List related files here

% $Author: base $	$Date: 2015/08/21 12:26:16 $	$Revision: 0.1 $
% Copyright: HHMI 2015
warning off
info = imfinfo(fileName, 'tif');
if nargin<2
    slices = 1:length(info);
end
wIm=info(1).Width;
hIm=info(1).Height;
numIm = numel(slices);
Iout  = zeros(hIm, wIm, numIm,'uint16');

for i=1:numIm
    Iout(:,:,i) = imread(fileName,'Index',slices(i),'Info',info);
end

end

function deployment()
%%
% mcc -m -R -nojvm -v pointMatch.m -d /groups/mousebrainmicro/home/base/CODE/MATLAB/stitching/compiledfunctions/pointMatch  -a ./common -a ./thirdparty
% mcc -m -v -R -singleCompThread /groups/mousebrainmicro/home/base/CODE/MATLAB/stitching/functions/dogDescriptor.m -d /groups/mousebrainmicro/home/base/CODE/MATLAB/stitching/compiledfunctions/dogDescriptor
% totest from matlab window:
% sigma1 = 3.4055002;
% sigma2 = 4.0498447;
% 
% dogDescriptor('/nobackup2/mouselight/cluster/2016-07-18/classifier_output/2016-07-24/01/01063/01063-ngc.0-Probability-2.h5',...
%     '/groups/mousebrainmicro/mousebrainmicro/cluster/Stitching/160404vs3/Descriptors/00001-ngc.0-Probabilitytxt',...
%     '[11 11 11]',...
%     sprintf('[%f %f %f]',[3.405500 3.405500 3.405500]),...
%     sprintf('[%f %f %f]',[4.049845 4.049845 4.049845]),...
%     '[50 974 50 1486 10 241]',...
%         '4');
dogDescriptor('/nobackup2/mouselight/cluster/2016-09-25/classifier_output/2016-10-02/00/00314/00314-prob.0.h5',...
'/groups/mousebrainmicro/mousebrainmicro/cluster/Stitching/2016-09-25/Descriptors/13844-prob.0.txt',...
'[11 11 11]','[3.405500 3.405500 3.405500]','[4.049845 4.049845 4.049845]','[5 1019 5 1531 10 250]','4')
%%
 
addpath(genpath('./common'))
brain = '2016-09-25';
if 1
    args.level = 3;
    args.ext = 'h5';
    opt.inputfolder = sprintf('/nobackup2/mouselight/cluster/%s/classifier_output',brain);
    opt.seqtemp = fullfile(opt.inputfolder,'filelist.txt')
    if exist(opt.seqtemp, 'file') == 2
        % load file directly
    else
        args.fid = fopen(opt.seqtemp,'w');
        recdir(opt.inputfolder,args)
    end
end
% dogDescriptor(inputimage,outputfile,siz,sig1,sig2,ROI,rt)
outputfold = sprintf('/groups/mousebrainmicro/mousebrainmicro/cluster/Stitching/%s/Descriptors/',brain)
mkdir(outputfold)
fid=fopen(sprintf('/nobackup2/mouselight/cluster/%s/classifier_output/filelist.txt',brain),'r');
inputfiles = textscan(fid,'%s');
inputfiles = inputfiles{1};
fclose(fid);
%%
if 0
    validx = missinigFiles(brain,size(inputfiles,1))
end
%%

numcores = 3;
pre = 'prob'
rt = 4;
myfile = sprintf('dogdescriptorrun_%s_run3.sh',brain);
compiledfunc = '/groups/mousebrainmicro/home/base/CODE/MATLAB/stitching/compiledfunctions/dogDescriptor/dogDescriptor'

%find number of random characters to choose from
s = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
numRands = length(s); 
%specify length of random string to generate
sLength = 10;
ROI = [5 1024-5 5 1536-5 10 251-1];
%-o /dev/null
fid = fopen(myfile,'w');
esttime = 6*60;

%%
for ii=find(~validx)%1:size(inputfiles,1)%
    %%
    %generate random string
    randString = s( ceil(rand(1,sLength)*numRands) );
    name = sprintf('dog_%05d-%s',ii,randString);
    outfile = fullfile(outputfold,sprintf('%05d-%s.%d.txt',floor((ii-1)/2)+1,pre,rem(ii+1,2)));
    args = sprintf('''%s %s %s "[%d %d %d]" "[%f %f %f]" "[%f %f %f]" "[%d %d %d %d %d %d]" %d> output.log''',compiledfunc,inputfiles{ii},outfile,...
        11*ones(1,3),3.4055002*ones(1,3),4.0498447*ones(1,3),ROI,rt);
    mysub = sprintf('qsub -pe batch %d -l d_rt=%d -N %s -j y -o ~/logs -b y -cwd -V %s\n',numcores,esttime,name,args);
    fwrite(fid,mysub);
end
unix(sprintf('chmod +x %s',myfile));
end
function validx = missinigFiles(brain,totnum)
%%
outputfold = sprintf('/groups/mousebrainmicro/mousebrainmicro/cluster/Stitching/%s/Descriptors/',brain)
mkdir(outputfold)
fid=fopen(sprintf('/nobackup2/mouselight/cluster/%s/classifier_output/filelist.txt',brain),'r');
inputfiles = textscan(fid,'%s');
inputfiles = inputfiles{1};
fclose(fid);
totnum = size(inputfiles,1);
tmpfiles = dir([sprintf('/groups/mousebrainmicro/mousebrainmicro/cluster/Stitching/%s/Descriptors/',brain),'*.txt']);
validx = zeros(1,size(inputfiles,1));
for ii=1:length(tmpfiles)
    % check if file exists
    tmpfil = tmpfiles(ii).name;
    idx = (str2double(tmpfil(1:5))-1)*2 + str2double(tmpfil(12))+1;
    validx(idx)=1;
end
find(~validx)

end












