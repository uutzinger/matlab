function [EEM,Ref]=assembleSPXDX(StartDir, FilePattern, varargin);
% [EEM,Ref]=assembleSPC(StartDir, FilePattern, [xcorr, mcorr])
% StartDir    = e.g. 'P:\Fluoro Log 3-22\data\01162003'
% FilePattern = e.g. 'G1*.SPC'
% xcorr       = 'XCORRECT.SPC' (optional, SPC file needs to be in the StartDir)
% mcorr       = 'MCORRECT.SPC' (optional, SPC file needs to be in the StartDir)
%
% EEM is the standard UU EEM format, horizontal is excitatin, veritcal is emission, wavelengths are on the left and top side
% R is two colum vector with the first one the wavelength
%
% This software needs the eem toolbox and measurements perfromed with the Fluorolog 3 from SPEX with my batch script.
%
% 1) generates files list
% 2) reads all files
% 3) separates out reflectance scan and background scans
% 4) essembles EEM
% 5) subtracts bg interpolated to all excitation wavelegnths (average value for all emssion wavelengths, is not a real bg subtraction
% 6) apply correction factors, both the emission correction factors and the excitation correction factors
%  Excitation correction factors need to be applied since they are generated by measureing a rhodamine excitation scan which calibrates for excitation inhomogeneities, this not intuitive and I am still thinking about it
%
% Currently use at your own risk
% This is feedback ware. If you change this routine you need to email your version to utzinger@email.arizona.edu
% UU, U of A, Spring 2003 - Fall 2003

% Check if correction needs to be perfromed
mcorr=0;
xcorr=0;
if nargin > 2
    xcorr=varargin{1};
    mcorr=varargin{2};
end

% Save current directory location and move to new one
OldDir=pwd;
eval(['cd ' '''' StartDir '''' ]);

% Generate a file list, this works only on machines with DOS command prompt
if nargin>1
 dos(['dir "' StartDir '\' FilePattern '" /O:N /B   > "' StartDir '\efile.tmplst"']);
end

% how many files?
all_ms=[];
fidlst = fopen('efile.tmplst');
if fidlst==-1
  error('File not found or permission denied');
  end
while 1
  fline = fgetl(fidlst);
  if ~isstr(fline), break, end
  dum    = max(findstr(fline,'\'));
  dum2   = max(findstr(fline,'.'));
  if isempty(dum)
   fpath='.';
   dum=0;
  else
   fpath=fline(1,1:dum-1);
  end;
  file   = fline(1,dum+1:dum2-1);
  name   = file(1:end-3);
  fnr    = str2num(file(end-2:end-1));
  ms     = max(size(file));
  all_ms = [all_ms;fnr];
end %while
fclose(fidlst);
all_ms=unique(sort(all_ms));
k=size(all_ms,1);

% Initilaize variables
% Reserve space for an eem that would have measurements x 1000 values
EEM=-1*ones(k,1000);
EEM_R=-1*ones(k,1000);
% will need to store average darkcurrent/bg
bg=[];
% loop counter
i=1; 
while i<=k,  
    % Generate the two file names
    S_name=[fpath, '\', name, sprintf('%02i',all_ms(i,:)), 'A.SPC'];
    R_name=[fpath, '\', name, sprintf('%02i',all_ms(i,:)), 'B.SPC'];
    % Read data file
    [w,S,spcdate,comment,labels, logtext]=readSPC(S_name);
    % Take log text appart
    tmp=findstr(logtext, 'Type='); Type=sscanf(logtext(tmp(1)+5:tmp(1)+7),'%f'); % will indicate if reflectance mode = synchrounous scan
    tmp=findstr(logtext, 'shutter_mode='); bg_t=sscanf(logtext(tmp(1)+13:tmp(1)+14),'%f'); % will indicate if darkcurren/bg measurement
    tmp=findstr(logtext, 'Start='); Start=sscanf(logtext(tmp(1)+6:tmp(1)+12),'%f'); % Not used but could use to check SPC
    tmp=findstr(logtext, 'End=');   End=sscanf(logtext(tmp(1)+4:tmp(1)+12),'%f'); % Not used but could use to check SPC
    tmp=findstr(logtext, 'Scan Em1='); E1=sscanf(logtext(tmp(1)+9:tmp(1)+10),'%f'); % Find Excitation wavelength
    tmp=findstr(logtext, 'Scan Em2='); E2=sscanf(logtext(tmp(1)+9:tmp(1)+10),'%f'); % Find Excitation wavelegnth in case we run EEM as esciation scans, not used yet
    if E1==1
            tmp=findstr(logtext, 'Position1='); ex=sscanf(logtext(tmp(1)+10:tmp(1)+19),'%f'); % Excitation postion, is usually this one
    else
            tmp=findstr(logtext, 'Position2='); ex=sscanf(logtext(tmp(1)+10:tmp(1)+19),'%f'); % Excitatinb position, maybe in the future
    end
    % Read lamp power measurement file
    [w,R,spcdate,comment,labels, logtext]=readSPC(R_name);
    if bg_t==0   % was is a background measurement
        if End-Start > 100
            % Room light measurement
            room=[w,S];
        else
            % Normal darkcurrent measurement
            bg=[bg; [ex, mean(S)]]; % save average bg and excitation wavel.
        end
    else if Type==2 % was it a reflectance measurement
           Ref=[w,(S./R)]; % create reflectance, this is preliminary since we do not yet have correction and reference measurements
       else % it was a fluroescence emission scan
           EEM(i,round(w))=(S)'; % fill up the EEM device signal by lamp power
           EEM(i,1)=ex;
           EEM_R(i,round(w))=(R)'; % fill up the EEM device signal by lamp power
           EEM_R(i,1)=ex;
       end
    end
    i=i+1;
end

% Fix up eem, remove unused locations in matrix
EEM=EEM((EEM(:,1)~=-1),:);
[i,j]=find(EEM~=-1);
j=unique(j);
EEM=[j,EEM(:,j)'];
[t,i]=sort(EEM(1,:));
EEM=EEM(:,i);

EEM_R=EEM_R((EEM_R(:,1)~=-1),:);
[i,j]=find(EEM_R~=-1);
j=unique(j);
EEM_R=[j,EEM_R(:,j)'];
[t,i]=sort(EEM_R(1,:));
EEM_R=EEM_R(:,i);

EEM(EEM(:,:)==-1)=0;

% Fix room light
room(:,2)=room(:,2)-bg(end,2); % remove darkcurrent
room((room(:,2)<0),2)=0; % clip a zero

% Remove bg, we have only a few measurements, interpolate others (we should qua;lity check because bg should not change to much)
% cannot interpolate sometimes
[mbg,bgi]=max(bg(:,1));
[mex,exi]=max(EEM(1,2:end));
if mbg < mex ; bg(bgi,1)=mex; end;
% interpolate
b=interp1(bg(:,1),bg(:,2),EEM(1,2:end));
b=ones(size(EEM,1)-1,1)*b;
EEM(2:end,2:end)=EEM(2:end,2:end)-b;
% Remove negative numbers (out of measurement range), can be negative because bg is subtracted everywhere
EEM(EEM<0)=0;

% Remove room lights
% generate an EEM with room lights at wavelegnths that were measured
mask=double(EEM(2:end,2:end)>-1);
wl=EEM(2:end,1);
me=size(mask,2);
for mi=1:me,
 r = interp1(room(:,1),room(:,2),wl(mask(:,mi)==1));
 tt=isnan(r); r(tt)=0; if sum(tt)>0; warning('room light range problem'); end
 mask(logical(mask(:,mi)==1),mi)=r;
end
% subtract room lights
EEM(2:end,2:end)=EEM(2:end,2:end)-mask;
EEM(EEM(:,:)<0)=0;

% Correct by lamp intensity fluctuations
EEM=eemdiv(EEM,EEM_R);


% Generate and apply the correction factors if they were provided
if isstr(mcorr) & isstr(xcorr)
    [wm,m,spcdate,comment,labels, logtext]=readSPC(mcorr);
    [wx,x,spcdate,comment,labels, logtext]=readSPC(xcorr);
    c=[[0;wx]' ; [wm,m*x']];
    EEM=eemmult(EEM,c);
elseif (max(size(mcorr))>1 & max(size(xcorr))>1)
    wm=mcorr(:,1); m=mcorr(:,2);
    wx=xcorr(:,1); x=xcorr(:,2);
    c=[[0;wx]' ; [wm,m*x']];
    EEM=eemmult(EEM,c);
else
    warning('No correction factors applied');
end


%clean up
eval(['cd ' '''' OldDir '''' ]);