# Thermal Control

This repository includes scripts that allow the user to conduct thermal ultrasound experiments with closed loop control using a PID with anti-windup control system.

![Demo photo](/images/PID_control.png)

### Software Prerequisites

This system requires MATLAB with the Instrument Control Toolbox Support Package that is relevant for the hardware that you will be using.  For example, the code as currently written uses the "Instrument Control Toolbox Support Package for Keysight IO Libraries and VISA Interface"

### Hardware Required

This system is designed to function with the following instruments:

```
BK Precision 4050 Function / Arbitrary Waveform Generator
Velmex VMX-3 Stepping Motor Controller
Neoptix Fiber Optic Rectal Thermometer
```

If a different waveform generator, motor controller, or fiber optic thermometer is used, the subroutines used in this code must be modified to the programming syntax of these new pieces of hardware as described in their programming manual.

The ultrasound signal generated needs to be amplified using an RF amplifier that can boost the signal voltage to be sufficient to drive an ultrasound transducer at the target pressure values.

## Setup

### Matlab computer

These scripts must all be in the same directory in order to function.  The results of any scans or acquisitions made by these scripts will be in this directory, so place this directory in a drive with sufficient available space.

### Hardware VISA addresses

Before running the scripts, the VISA address of the signal generator and oscilloscope  must be appended to the list of VISA addresses within the following files:

```
sub_SG_Initialize.m (for the signal generator)
```

Consult the programming manual of the signal generator and oscilloscope to determine how to find the specific instrument's VISA address.  The program should be able to find the connected Velmex motor stage and Neoptic thermometer system automatically. 

### Hardware USB connections

The signal generator, oscilloscope, and thermometer must be connected to the Matlab computer via USB cables.  Using unpowered USB ports may lead to unstable connections that can cause the programs to crash.  Use powered USB hubs if possible.

### Hardware Configuration

The cables for this system must be connected as such

```
SG Ch 1 <--> Amplifier In
Amplifier out <--> US Tx
```

## How to Use

Prior to any experiment, update the transducer, amplifier, and safety values within:

```
sub_AllSettings.m
```

### Transducer Alignment

Position both the transducer and hydrophone in a water bath, with the transducer mounted to the motor stage system.  Define a low intensity pulsed ultrasound test signal that can be run safely continuously during alignment using:

```
SetTestingParameter.m
```

Edit the testing parameters within that file first, then execute the file to apply those changes to the signal generator.  That script will throw an error if any value violates the prior defined safety limits.

Manually position the transsducer such that a signal appears on the oscilloscope.  If using a GUI would be useful in this manual course adjustment of the transducer, then run:

```
stage_GUI.m
```


### Thermal Control

After aligning the transducer to the hydrophone as described above, use the following script to activate the thermal control system:
```
ThermalGUI.m
```
Before running the script, open the script file to set in the configuration file the following key parameters seen under teh ThermalGUI_OpeningFcn function:
```
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
```

When tuning the parameters, take note of the control system architecture for this PID with anti-windup controller:

![Architecture](/images/PID_parameters.png)

## Contributing

Currently contributing is not suppported, please see future versions at https://github.com/drmittelstein/thermal_control to determine whether this changes.

## Versioning
Please see available versions at https://github.com/drmittelstein/thermal_control

## Authors

* **David Reza Mittelstein** - "Modifying ultrasound waveform parameters to control, influence, or disrupt cells" *Caltech Doctorate Thesis in Medical Engineering*

## Acknowledgments

* Acknowledgements to my colleagues in Gharib, Shapiro, and Colonius lab at Caltech who helped answer questions involved in the development of these scripts.
