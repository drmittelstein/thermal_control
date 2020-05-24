# Thermal Control

This repository includes scripts that allow the user to conduct thermal ultrasound experiments with closed loop control using a PID with anti-windup control system.  Scripts enable the users to align and calibrate ultrasound transducers and to control the insonation of these transducers on targets in 24 well plate platforms.

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

After aligning the transducer to the hydrophone as described above, use the following script to get the pressure waveforms for various ultrasound waveforms sent through the transducer:

```
ThermalGUI.m
```


## Contributing

Currently contributing is not suppported, please see future versions at https://github.com/drmittelstein/ultrasound_hardware_control to determine whether this changes.

## Versioning
Please see available versions at https://github.com/drmittelstein/ultrasound_hardware_control

## Authors

* **David Reza Mittelstein** - "Modifying ultrasound waveform parameters to control, influence, or disrupt cells" *Caltech Doctorate Thesis in Medical Engineering*

## Acknowledgments

* Acknowledgements to my colleagues in Gharib, Shapiro, and Colonius lab at Caltech who helped answer questions involved in the development of these scripts.
