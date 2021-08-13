% Author: David Reza Mittelstein (drmittelstein@gmail.com)
% Medical Engineering, California Institute of Technology, 2020

% SUBROUTINE
% This subroutine is called in the beginning of each script to generate the params structure
% This includes experiment specific values that should be adjusted before each experiment including:
% * Transducer center frequency
% * Amplifier gain
% * Safety paramters - that prevent the signal generator from sending a signal that could damage equipment or samples
% * Hardware default parameters
% * Reference parameters

function params = sub_AllSettings(name)

params = struct; params.Name = name; params.Time = datestr(now);

%% UPDATE BEFORE EACH EXPERIMENT

params.Transducer_Fc = 6.7E+05; % Center frequency of transducer (Hz)

% Amplifier Gain
params.Amplifier.ReadMe = 'Gain from Vpp on signal generator GUI to Vpp output of amplifier measured by oscilloscope (C2 1 Mohm, C4 50 ohm)';
params.Amplifier.SetupNotes = 'Using AR 100A250B at 100% gain and set BKP to have 50 ohm output load';
params.Amplifier.Tested = '04-Sep-2018 17:59:18';
params.Amplifier.GainDB = 55.0640;
% Gain must be accurately updated above.
% Calculate gain as 20*log10(voltage OUT / voltage IN)

% Amplifier Settings
params.Amplifier.MaxInstVppIn = 0.5;
params.Amplifier.MaxInstVppOut = 150; 
% Vpp = Peak-to-peak voltage.
% MaxInstVppIn: Maximum instantaneous Vpp that the amplifier can tolerate 
% as an input
% MaxInstVppOut: Maximum instantaneous Vpp that the transducer can tolerate
% as an output from the amplifier

params.Amplifier.MaxVrmsOut = 80;
% Vrms = root-mean-squared voltage
% Maximum Vrms that the transducer can tolerate as an output from the
% amplifier
% Use equation: Pavg = Vrms^2 / R

% Safety parameters for the 670 kHz transducer from Precision Acoustics
% 20 W OK for extended duration, which is 31.6 Vrms

params.Amplifier.MaxDutyCycle = inf; % Maximum fraction of time that signal can be on
params.Amplifier.MaxPulseDuration = inf; % Maximum time in seconds that pulse duration can be

%% General Settings
params.Debug = 0;

%% Prepare User Interface
s = [params.Name '_' datestr(now, 'yyyy-mm-dd_HH-MM-SS')];
t = s; t(t ~= '=') = '='; clc; disp(s); disp(t); 
params.NameFull = s; clear s t;

%% Stage Parameters
% Update step size and motor numbers given specific motor stage and setup

% Default speed
params.Stages.Speed = 2000;

% Translation Distance Per Motor Step (6.35 microns / motor step)
params.Stages.step_distance = 0.0254/10/400; 

% Assignment of Motor numbers to axes (as per the definition image)
params.Stages.x_motor = 2;
params.Stages.y_motor = 3;
params.Stages.z_motor = 1;

%% SG Parameters

% Define some basic introductory waveform parameters
params.SG.Waveform.ch = 1;
params.SG.Waveform.cycles = 30;
params.SG.Waveform.period = 1e-3;
params.SG.Waveform.frequency = params.Transducer_Fc;
params.SG.Waveform.voltage = 0.05;
params.SG.Waveform.repeats = -1;

params.SG.WaveformSent = [];

%% Acoustic Values
params.Acoustic.MediumDensity = 1e3; % kg/m3
params.Acoustic.MediumAcousticSpeed = 1.481e3; % m/s
params.Acoustic.Z = params.Acoustic.MediumAcousticSpeed * params.Acoustic.MediumDensity; 

%% Turn off warnings
warning('off','all');

end