function varargout = readRigolbin(filename, varargin)
%     clear all; close all
%Reads a binary waveform (.bin) file stored by a Rigol oscilloscope.
% uses file fomart as listed in DHO800 User Guide, Aug. 2023
%tested on DHO804 oscillocsope .bin files
%Version 1.0; January 23, 2024
%Uses ~same format as readRigolWaveform funcuton (2009) by Paul Wagenaars
%to read Rigol .wfm files
%
% readRigolbin(filename) Displays information about the recorded
% signal(s) in the waveform file and plots the signal(s).
%
% filename - filename of Rigol binary waveform *.bin
%
% [y, nfo, t] = readRigolWaveform(filename) Reads the signal(s) and information
% in the specified file.
%
% y        - column array with data. If n_waveforms were recorded it
%            contains n colums.
% nfo      - structure with time axis and other information
%            nfo.x_start: time corresponding to first sample (memo ry save)
%            nfo.dx: sample time (= 1 / sample_frequency)
%            nfo.channel_names: cell array with list of recorded channel names
%            nfo.y_units: cell array with units of each channel
%            nfo.model: Rigol oscilloscope model and serial number
%            nfo.notes: text field other oscilloscope settings
% t        - time axis for waveforms in seconds, can be created from nfo
%
% for 'memory' save:   t= x_start +dx*(0:n_pts-1)
% for 'screen' save:   t= -x_start +dx*(0:n_pts-1)
% for 'screen' save; n_pts=1000

if nargout == 0
    fprintf('---\nFilename: %s\n', filename);
end

%% Open the file and check the header
if ~exist(filename, 'file')
    error('Specified file (%s) doesn''t exist.', filename);
end

fid = fopen(filename, 'r');
if fid == -1
    error('Unable to open %s for reading.', filename);
end
%%%File Header
% Check first two bytes
cookie = fread(fid, 2,   'uint8=>char')';
if (cookie~='RG')
    error('Incorrect first two bytes. This files does not seem to be a Rigol waveform file.');
end
version=fread(fid, 2,  'uint8=>char')';
if (version(2)~='3')
    fprintf('Version: %s, Function tested on file version 3, may be incorrect.\n',version);
end

file_size=fread(fid, 1, '*uint64')';
n_waveforms=fread(fid, 1, 'uint32=>double');

%waveform header
header_size=fread(fid, 1, '*uint32');
waveform_type=fread(fid, 1, '*uint32');
n_buffers=fread(fid, 1, '*uint32');
n_pts=fread(fid, 1, 'uint32=>double');
count=fread(fid, 1, '*uint32');
x_range=fread(fid, 1, 'single');
x_display_origin=fread(fid, 1, 'double');
x_increment=fread(fid, 1, 'double');
x_origin=fread(fid, 1, 'double');
x_units=fread(fid,  1, '*uint32'); %fixed at 2 ==Time(s)
y_units=fread(fid,  1, '*uint32');
f_date=deblank(fread(fid, 16,'uint8=>char')');
f_time=deblank(fread(fid, 16,'uint8=>char')');
model=deblank(fread(fid, 24, 'uint8=>char')');
%channel_name=fread(fid, 16,'uint8=>char')';
%channel_name= channel_name(1:(find(channel_name==0,1)-1));


%waveform data header--- dont' need it
   fseek(fid, 156, -1);
   wfm_header_size=fread(fid,  1, '*uint32');
   buffer_type=fread(fid,  1, '*uint16');
    bytes_per_point=fread(fid, 1, '*uint16');
   buffer_size=fread(fid, 1, '*uint64')';

%%%%%%
unit_types={'Unknown','Volts (V)','Seconds (s)','Constant','Amps (A)','Decibel (dB)',' Hertz (Hz)'};
channel_names=cell(1,n_waveforms);
y_units=cell(1,n_waveforms);
Y=zeros(n_waveforms,n_pts);

%read in data for each channel
for i=1:n_waveforms
  fseek(fid, 68+(140+16+buffer_size)*(i-1) , -1);
 y_units{i}=unit_types{fread(fid,  1, '*uint32')+1};
fseek(fid, 128+(140+16+buffer_size)*(i-1) , -1);
channel_names{i}=deblank(fread(fid, 16,'uint8=>char')');
   fseek(fid, 16*(i+1)+ 140*i+ buffer_size*(i-1), -1);
y=fread(fid,n_pts,'*single');
if length(y)<n_pts
    error('Error: incomplete file');
end

Y(i,:)=y;
end
clear y
if nargout == 0
      fprintf('File date: %s\n', f_date);
      fprintf('File time: %s\n', f_time);
  if n_pts >=1e6
     fprintf('Record length: %dMeg\n', n_pts / 1e6);
   else
    fprintf('Record length: %dk\n', n_pts / 1000);
    end
 if x_increment <=1e-6
     fprintf('Time/pt: %3.1f nanoseconds\n', x_increment / 1e-9);
   elseif x_increment <=1e-3
    fprintf('Time/pt: %3.1f microseconds\n', x_increment / 1e-6);
   elseif x_increment <=1
    fprintf('Time/pt: %3.1f milliseconds\n', x_increment / 1e-3);
   else
    fprintf('Time/pt: %3.1f seconds\n', x_increment / 1e-3);
    end
     fprintf('Number of waveforms: %i\n', n_waveforms);
     for i=1:n_waveforms
        fprintf('  - %s  : %s\n', channel_names{i}, y_units{i});
        end
 end

%% Close file
fclose(fid);


%% Plot signals
if nargout == 0
 f=figure('Name',filename,'Position',[100 100 500 n_waveforms*250]);
t= -x_origin +x_increment*double([1:n_pts]-1);
  for i=1:n_waveforms
    subplot(n_waveforms,1,i)
 plot(t,Y(i,:),'.-')
   xlim tight
  title(channel_names(i))
     grid on;

end
 xlabel('Time (s)');
end

if nargout >= 1
    varargout{1} = Y;
end

%% Assign output arguments
if nargout >= 2

nfo.f_date=f_date;
nfo.f_time=f_time;
nfo.file_size=file_size;
nfo.n_waveforms=n_waveforms;
nfo.n_pts=n_pts; %number of points per waveform
nfo.model=model;
nfo.x_start = -x_origin;
nfo.dx = x_increment;nfo.channel_names=channel_names;
   nfo.y_units=y_units;
    varargout{2} = nfo;

end

   if nargout == 3
      %time axis
      varargout{3} = -x_origin +x_increment*double([1:n_pts]-1);
end

%%%%%%% end of main function
end


