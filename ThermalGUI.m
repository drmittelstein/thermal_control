% Author: David Reza Mittelstein (drmittelstein@gmail.com)
% Medical Engineering, California Institute of Technology, 2020

% SUBROUTINE
% Activate Thermal Control GUI
% Customizable PIDaw controls and schema parameters in ThermalGUI_OpeningFcn

function varargout = ThermalGUI(varargin)
% THERMALGUI MATLAB code for ThermalGUI.fig
%      THERMALGUI, by itself, creates a new THERMALGUI or raises the existing
%      singleton*.
%
%      H = THERMALGUI returns the handle to a new THERMALGUI or the handle to
%      the existing singleton*.
%
%      THERMALGUI('CALLBA/CK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in THERMALGUI.M with the given input arguments.
%
%      THERMALGUI('Property','Value',...) creates a new THERMALGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ThermalGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ThermalGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ThermalGUI

% Last Modified by GUIDE v2.5 21-May-2018 06:18:50

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ThermalGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @ThermalGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before ThermalGUI is made visible.
function ThermalGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ThermalGUI (see VARARGIN)

% Choose default command line output for ThermalGUI
disp('Loading... please wait')
handles.output = hObject;

delete(timerfind);

handles.PID.TA = 46; % Reference temperature (Celsius) for Scheme A
handles.PID.TB = 37; % Reference temperature (Celsius) for Scheme B

% Default PID with anti-windup constants
handles.PID.Kp = 0.1;  % Proportional control
handles.PID.Ki = 0.1;  % Integral control
handles.PID.Kd = 0;    % Derivative control
handles.PID.Kt = 0.25; % Anti-windup control

handles.MaxVppTransducer = 50;
% This specifies the maximum Vpp output that the control system will use
% Safety settings are also on, make sure that the value set here will agree
% with the limits set in safety (sub_AllSettings)
% For example, when the PID controller is using a control value of 1, it
% will use the MaxVppTransducer value specified above

handles.data.schemeprd = 5; % Time (minutes) between scheme switch

handles.data.scheme = 0;
handles.data.schemetoggle = 0;


UpdateGUI(hObject, handles);

handles.PID.t = [];
handles.PID.y = [];
handles.PID.r = [];
handles.PID.u = [];
handles.PID.v = [];

handles.timer = timer;
handles.timer.TimerFcn = {@TimerTick, hObject};
handles.timer.Period = 0.25;
handles.timer.StartDelay = 0.25;
handles.timer.ExecutionMode = 'fixedSpacing';

handles.params = sub_AllSettings('Thermal Control');
sub_Close_All_Connections;

disp('- Connecting to Neoptix Reflex Fiber Optic Temp Sensor')
delete(instrfind('status', 'closed'));
% First try to connect to the Neoptix without disconnecting anything
port = 2;
connected = 0;
while port < 20 && ~connected
    try
    port = port + 1;
    handles.sobj = serial(sprintf('COM%d',port), 'Terminator', 'CR', 'Timeout', 1);   
    fopen(handles.sobj);
    disp(sprintf('   > Found device on open port COM%d', port));
    if contains(query(handles.sobj, 'i'), 'ReFlex')
        disp(sprintf('   > Confirmed connection to Neoptix Reflex on COM%d', port))
        fclose(handles.sobj);
        fopen(handles.sobj);
        connected = 1;
    else
        disp('   > But it is not Neoptix')
        fclose(handles.sobj);
        delete(instrfind('Name', sprintf('Serial-COM%1.0f',port)));
    end
    
    catch
    end
end

if ~connected
disp('   > Could not find Neoptix on unused ports, now looking through used ports')
disp('     this may cause other devices to disconnect');

port = 2;
connected = 0;
while port < 100 && ~connected
    try
    port = port + 1;
    dvcs = instrfind('Name', sprintf('Serial-COM%1.0f',port));

    if numel(dvcs) > 0
        disp(sprintf('   > Disconnected device on COM%1.0f', port));
        delete(dvcs);
    end
    handles.sobj = serial(sprintf('COM%d',port), 'Terminator', 'CR', 'Timeout', 1);   
    fopen(handles.sobj);
    disp(sprintf('   > Found device on open port COM%d', port));
    if contains(query(handles.sobj, 'i'), 'ReFlex')
        disp(sprintf('   > Connected connection to Neoptix Reflex on COM%d', port))
        connected = 1;
    else
        disp('   > But it is not Neoptix')
    end
    
    catch
    end
end   

    
end
delete(instrfind('status', 'closed'));
if ~connected
    error('Could not find Neoptix on any COM port')
end

handles.params.SG.Waveform.ch = 1;
handles.params.SG.Waveform.frequency = 6.7E+05; % Hz
handles.params.SG.Waveform.voltage = 5 * 10^(-handles.params.Amplifier.GainDB/20); 
handles.params.SG.Waveform.period = 1e-3;

handles.params = sub_SG_Initialize(handles.params);
handles.params = sub_SG_ApplySettings(handles.params);
cmdUS_Callback(hObject, struct, handles);

handles.tic = tic;
start(handles.timer);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ThermalGUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


function TimerTick(obj, event, hObject)
handles = guidata(hObject);

timenow = toc(handles.tic);
set(handles.lblTime, 'String', sprintf('%02.0f:%02.0f', floor(timenow/60), mod(timenow,60)))

toggles = floor(timenow/(60 * handles.data.schemeprd));

if toggles ~= handles.data.schemetoggle
    handles.data.schemetoggle = toggles;
    handles.data.scheme = ~handles.data.scheme;
end

% Read out temperature from Neoptix
neoptix_readout = strtrim(query(handles.sobj, 't'));
while handles.sobj.BytesAvailable
    fscanf(handles.sobj, '%s', handles.sobj.BytesAvailable);
end
tempnow = str2double(neoptix_readout);

% Confirm if it is a good read, default is no
% Bad reads are not counted in the PID control system
goodread = 0;

Min_Temp = 20; % Deg C, we will assume any read below this are errors

if ~isnan(tempnow)
    if tempnow > Min_Temp;
        goodread = 1;
    end
end

if goodread
% Only update PID data if good read
handles.PID.t(end+1) = timenow;
handles.PID.y(end+1) = tempnow;
handles.PID.r(end+1) = 0;
handles.PID.u(end+1) = 0;
handles.PID.v(end+1) = 0;
end

dB = handles.params.Amplifier.GainDB;
handles.params.SG.Waveform.voltage = 30 * 10^(-dB/20);

if get(handles.cmdUS, 'Value')
    if ~handles.data.scheme 
        set(handles.SA, 'BackgroundColor', [1 .5 .5]) 
        set(handles.SB, 'BackgroundColor', [1 1 1])
        handles.PID.r(end) = handles.PID.TA;
    else
        set(handles.SB, 'BackgroundColor', [1 .5 .5]) 
        set(handles.SA, 'BackgroundColor', [1 1 1])
        handles.PID.r(end) = handles.PID.TB;
    end
    
    if numel(handles.PID.t) <= 1
        err_P = (handles.PID.r(end) - handles.PID.y(end));
        err_D = 0;
        err_I = 0;
        err_T = 0;
        intg_indices = 1;
    else 
        err_P = (handles.PID.r(end) - handles.PID.y(end));
        err_D = -(handles.PID.y(end) - handles.PID.y(end-1)) / (handles.PID.t(end) - handles.PID.t(end-1));
        
        intg_indices = find(handles.PID.t >= handles.PID.t(end) - mod(handles.PID.t(end), 60 * handles.data.schemeprd));
        intg_Iintegrand = (handles.PID.r - handles.PID.y);
        intg_Tintegrand = (handles.PID.u - handles.PID.v);
        
        if numel(intg_indices) > 2
            err_I = trapz(handles.PID.t(intg_indices), intg_Iintegrand(intg_indices));
            err_T = trapz(handles.PID.t(intg_indices), intg_Tintegrand(intg_indices));
        else
            err_I = 0;
            err_T = 0;
        end
    end
    
    PID_P = err_P * handles.PID.Kp;
    PID_D = err_D * handles.PID.Kd;
    PID_I = err_I * handles.PID.Ki;    
    PID_T = err_T * handles.PID.Kt;   

    handles.PID.v(end) = PID_P + PID_I + PID_D + PID_T;
    handles.PID.u(end) = max(0, min(1, handles.PID.v(end)));
       
    % Granularity of 20 steps to prevent excessive SG switching
    factor = floor(handles.PID.u(end)*20)/20;
    handles.params.SG.Waveform.voltage = handles.MaxVppTransducer * 10^(-handles.params.Amplifier.GainDB/20) * factor;

    if ~isequal(handles.params.SG.Waveform, handles.params.SG.WaveformSent)
        if factor <= 0
            % Turn off US
            handles.params.SG.Waveform.voltage = 0.002;
            handles.params = sub_SG_ApplySettings_POnly(handles.params);
            handles.params.SG.WaveformSent = handles.params.SG.Waveform;
        else
            % US signal defined
            handles.params = sub_SG_ApplySettings_POnly(handles.params);
            handles.params.SG.WaveformSent = handles.params.SG.Waveform;
        end
    end
    
    if goodread
    set(handles.PIDStatus, 'String', ...
        sprintf(' T = %1.1f deg C \n R = %1.1f deg C \n \n For %1.1f < t < %1.1f sec \n Error P = %1.2f \n Error D = %1.2f \n Error I = %1.2f \n Error T = %1.2f \n\n Ideal = %1.2f \n Control = %1.2f', ...
        handles.PID.y(end), handles.PID.r(end), handles.PID.t(intg_indices(1)), handles.PID.t(intg_indices(end)), err_P, err_D, err_I, err_T, handles.PID.v(end), handles.PID.u(end)));
    end
        
else
    set(handles.SA, 'BackgroundColor', [1 .5 .5]) 
    set(handles.SB, 'BackgroundColor', [1 1 1])
    
    handles.params.SG.Waveform.voltage = 0.002;
    if ~isequal(handles.params.SG.Waveform, handles.params.SG.WaveformSent)
        handles.params = sub_SG_ApplySettings_POnly(handles.params);
        handles.params.SG.WaveformSent = handles.params.SG.Waveform;
    end
    
    if goodread
    set(handles.PIDStatus, 'String', sprintf(' PID offline \n t=%1.1f sec\n T=%1.1f deg C', handles.PID.t(end), handles.PID.y(end)));
    end
    
end

if ~goodread
    set(handles.PIDStatus, 'String', sprintf(' Neoptix Readout Invalid \n Check Sensor! \n \n READOUT: \n %s \n \n Current Time \n %s', neoptix_readout, datestr(now)));
end

plot(handles.axes1, handles.PID.t, handles.PID.y, 'ko', handles.PID.t, handles.PID.r, 'b-');
xlabel(handles.axes1, 'Time (s)');
ylabel(handles.axes1, 'Temperature (deg C)');
drawnow
plot(handles.axes2, handles.PID.t, handles.PID.u, 'ro');
xlabel(handles.axes2, 'Time (s)');
ylabel(handles.axes2, 'PID Control');
ylim(handles.axes2, [0 1]);

guidata(hObject, handles);


function UpdateGUI(hObject, handles)

set(handles.TA, 'String', handles.PID.TA);
set(handles.TB, 'String', handles.PID.TB);

set(handles.Kp, 'String', handles.PID.Kp);
set(handles.Ki, 'String', handles.PID.Ki);
set(handles.Kd, 'String', handles.PID.Kd);
set(handles.Kt, 'String', handles.PID.Kt);

set(handles.Prd, 'String', handles.data.schemeprd);

if ~handles.data.scheme
    set(handles.rbB, 'Value', 0);
    set(handles.rbA, 'Value', 1);
else
    set(handles.rbA, 'Value', 0);
    set(handles.rbB, 'Value', 1);
end

drawnow;



function ManageGUI(hObject, handles)
errflag = 0;
if all([...
            isempty(str2double(get(handles.TA, 'String')));
            isempty(str2double(get(handles.TB, 'String')));
            isempty(str2double(get(handles.Kp, 'String')));
            isempty(str2double(get(handles.Ki, 'String')));
            isempty(str2double(get(handles.Kd, 'String')));
            isempty(str2double(get(handles.Kt, 'String')));
            ])
        
    errflag = 1; 
       
elseif ~all([...
        str2double(get(handles.Prd, 'String')) > 0;
        ])
    
    errflag = 1;
    
end

if ~errflag
    handles.PID.TA = str2double(get(handles.TA, 'String'));
    handles.PID.TB = str2double(get(handles.TB, 'String'));
    handles.PID.Kp = str2double(get(handles.Kp, 'String'));
    handles.PID.Ki = str2double(get(handles.Ki, 'String'));
    handles.PID.Kd = str2double(get(handles.Kd, 'String'));
    handles.PID.Kt = str2double(get(handles.Kt, 'String'));
    
    handles.data.schemeprd = str2double(get(handles.Prd, 'String'));
    
    guidata(hObject, handles);
    
else
    msgbox('Control values out of bounds')
end
    
UpdateGUI(hObject, handles);

    
     

% --- Outputs from this function are returned to the command line.
function varargout = ThermalGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in cmdClear.
function cmdClear_Callback(hObject, eventdata, handles)
% hObject    handle to cmdClear (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.PID.t = [];
handles.PID.y = [];
handles.PID.r = [];
handles.PID.u = [];
handles.PID.v = [];
handles.tic = tic;
guidata(hObject, handles);


% --- Executes on button press in cmdSave.
function cmdSave_Callback(hObject, eventdata, handles)
% hObject    handle to cmdSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
fn = sprintf('thermaldata_%s.txt', datestr(now, 'YYYY-MM-DD-hh-mm-ss'));
[f,p] = uiputfile(fn);
filename = [p f];
fileID = fopen(filename, 'w');
fprintf(fileID, '%s\t%s', 'Time (s)', 'Temperature (deg C)');
fprintf(fileID, '\r\n');
for i = 1:numel(handles.PID.t)
fprintf(fileID, '%1.2f\t%1.2f\r\n', handles.PID.t(i), handles.PID.y(i));
end
fclose(fileID);


% --- Executes on button press in cmdUS.
function cmdUS_Callback(hObject, eventdata, handles)
% hObject    handle to cmdUS (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cmdUS

if get(handles.cmdUS, 'Value')
    set(handles.cmdUS, 'String', sprintf('US HEATING: ON'))
    set(handles.cmdUS, 'BackgroundColor', [1 .3 .3]);
    cmdClear_Callback(hObject, eventdata, handles);
else
    set(handles.cmdUS, 'String', sprintf('US HEATING: OFF'))
    set(handles.cmdUS, 'BackgroundColor', [1 1 1]);
end



function edit5_Callback(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit6_Callback(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit4_Callback(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit4 as text
%        str2double(get(hObject,'String')) returns contents of edit4 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function T1_Callback(hObject, eventdata, handles)
% hObject    handle to T1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of T1 as text
%        str2double(get(hObject,'String')) returns contents of T1 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function T1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to T1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D1_Callback(hObject, eventdata, handles)
% hObject    handle to D1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D1 as text
%        str2double(get(hObject,'String')) returns contents of D1 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D4_Callback(hObject, eventdata, handles)
% hObject    handle to D4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D4 as text
%        str2double(get(hObject,'String')) returns contents of D4 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V4_Callback(hObject, eventdata, handles)
% hObject    handle to V4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V4 as text
%        str2double(get(hObject,'String')) returns contents of V4 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function T3_Callback(hObject, eventdata, handles)
% hObject    handle to T3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of T3 as text
%        str2double(get(hObject,'String')) returns contents of T3 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function T3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to T3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D3_Callback(hObject, eventdata, handles)
% hObject    handle to D3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D3 as text
%        str2double(get(hObject,'String')) returns contents of D3 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V3_Callback(hObject, eventdata, handles)
% hObject    handle to V3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V3 as text
%        str2double(get(hObject,'String')) returns contents of V3 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit8_Callback(hObject, eventdata, handles)
% hObject    handle to edit8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit8 as text
%        str2double(get(hObject,'String')) returns contents of edit8 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function edit8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit9_Callback(hObject, eventdata, handles)
% hObject    handle to edit9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit9 as text
%        str2double(get(hObject,'String')) returns contents of edit9 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function edit9_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit10_Callback(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit10 as text
%        str2double(get(hObject,'String')) returns contents of edit10 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function edit10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V1_Callback(hObject, eventdata, handles)
% hObject    handle to V1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V1 as text
%        str2double(get(hObject,'String')) returns contents of V1 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function T2_Callback(hObject, eventdata, handles)
% hObject    handle to T2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of T2 as text
%        str2double(get(hObject,'String')) returns contents of T2 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function T2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to T2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D2_Callback(hObject, eventdata, handles)
% hObject    handle to D2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D2 as text
%        str2double(get(hObject,'String')) returns contents of D2 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V2_Callback(hObject, eventdata, handles)
% hObject    handle to V2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V2 as text
%        str2double(get(hObject,'String')) returns contents of V2 as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in rbA.
function rbA_Callback(hObject, eventdata, handles)
% hObject    handle to rbA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rbA
ManageGUI(hObject, handles)

% --- Executes on button press in rbB.
function rbB_Callback(hObject, eventdata, handles)
% hObject    handle to rbB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rbB
ManageGUI(hObject, handles)


function Prd_Callback(hObject, eventdata, handles)
% hObject    handle to Prd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Prd as text
%        str2double(get(hObject,'String')) returns contents of Prd as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function Prd_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Prd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V4B_Callback(hObject, eventdata, handles)
% hObject    handle to V4B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V4B as text
%        str2double(get(hObject,'String')) returns contents of V4B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V4B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V4B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D4B_Callback(hObject, eventdata, handles)
% hObject    handle to D4B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D4B as text
%        str2double(get(hObject,'String')) returns contents of D4B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D4B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D4B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V3B_Callback(hObject, eventdata, handles)
% hObject    handle to V3B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V3B as text
%        str2double(get(hObject,'String')) returns contents of V3B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V3B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V3B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D3B_Callback(hObject, eventdata, handles)
% hObject    handle to D3B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D3B as text
%        str2double(get(hObject,'String')) returns contents of D3B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D3B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D3B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function T3B_Callback(hObject, eventdata, handles)
% hObject    handle to T3B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of T3B as text
%        str2double(get(hObject,'String')) returns contents of T3B as a double


% --- Executes during object creation, after setting all properties.
function T3B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to T3B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V2B_Callback(hObject, eventdata, handles)
% hObject    handle to V2B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V2B as text
%        str2double(get(hObject,'String')) returns contents of V2B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V2B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V2B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D2B_Callback(hObject, eventdata, handles)
% hObject    handle to D2B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D2B as text
%        str2double(get(hObject,'String')) returns contents of D2B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D2B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D2B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function T2B_Callback(hObject, eventdata, handles)
% hObject    handle to T2B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of T2B as text
%        str2double(get(hObject,'String')) returns contents of T2B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function T2B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to T2B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function D1B_Callback(hObject, eventdata, handles)
% hObject    handle to D1B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of D1B as text
%        str2double(get(hObject,'String')) returns contents of D1B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function D1B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to D1B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function T1B_Callback(hObject, eventdata, handles)
% hObject    handle to T1B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of T1B as text
%        str2double(get(hObject,'String')) returns contents of T1B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function T1B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to T1B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function V1B_Callback(hObject, eventdata, handles)
% hObject    handle to V1B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of V1B as text
%        str2double(get(hObject,'String')) returns contents of V1B as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function V1B_CreateFcn(hObject, eventdata, handles)
% hObject    handle to V1B (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit31_Callback(hObject, eventdata, handles)
% hObject    handle to edit31 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit31 as text
%        str2double(get(hObject,'String')) returns contents of edit31 as a double


% --- Executes during object creation, after setting all properties.
function edit31_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit31 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit32_Callback(hObject, eventdata, handles)
% hObject    handle to edit32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit32 as text
%        str2double(get(hObject,'String')) returns contents of edit32 as a double


% --- Executes during object creation, after setting all properties.
function edit32_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit33_Callback(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit33 as text
%        str2double(get(hObject,'String')) returns contents of edit33 as a double


% --- Executes during object creation, after setting all properties.
function edit33_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Kp_Callback(hObject, eventdata, handles)
% hObject    handle to Kp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Kp as text
%        str2double(get(hObject,'String')) returns contents of Kp as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function Kp_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Kp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Ki_Callback(hObject, eventdata, handles)
% hObject    handle to Ki (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Ki as text
%        str2double(get(hObject,'String')) returns contents of Ki as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function Ki_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Ki (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Kd_Callback(hObject, eventdata, handles)
% hObject    handle to Kd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Kd as text
%        str2double(get(hObject,'String')) returns contents of Kd as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function Kd_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Kd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Kt_Callback(hObject, eventdata, handles)
% hObject    handle to Kt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Kt as text
%        str2double(get(hObject,'String')) returns contents of Kt as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function Kt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Kt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function TA_Callback(hObject, eventdata, handles)
% hObject    handle to TA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of TA as text
%        str2double(get(hObject,'String')) returns contents of TA as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function TA_CreateFcn(hObject, eventdata, handles)
% hObject    handle to TA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function TB_Callback(hObject, eventdata, handles)
% hObject    handle to TB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of TB as text
%        str2double(get(hObject,'String')) returns contents of TB as a double
ManageGUI(hObject, handles)

% --- Executes during object creation, after setting all properties.
function TB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to TB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
