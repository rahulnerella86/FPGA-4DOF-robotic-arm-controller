# FPGA-Based 4DOF Robotic Arm Controller

A real-time, hardware-based control system for a 4-degree-of-freedom (4DOF) robotic arm using FPGA technology. This project demonstrates pulse-width modulation (PWM) control of servo motors via direct button input on an FPGA development board.

## 📋 Project Overview

This project implements a complete robotic arm control system on an FPGA platform, allowing intuitive manual control of all four joint axes using onboard pushbuttons. The system features:

- **Real-time PWM generation** for servo motor control
- **Direct button interface** with hardware debouncing
- **4-axis independent control** with simultaneous operation
- **Visual feedback** through 7-segment displays and LEDs
- **Modular VHDL architecture** for easy customization and extension

## 🎯 Hardware Components

### FPGA Development Boards
- **Primary**: DE2-415 FPGA Board (Altera/Intel)
- **Alternative**: Spartan-6 FPGA Development Board (Xilinx)

### Robotic Arm Specifications
- **DOF**: 4 degrees of freedom
- **Actuators**: Servo motors (one per joint)
- **Control**: Servo PWM signals (50 Hz base frequency, 1-2 ms pulse width)
- **Power**: External power supply for servo motors

### Control Interface
- **Input**: 4-12 pushbuttons (depending on configuration)
- **Feedback**: 7-segment display, LED indicators, UART output
- **Additional**: Temperature sensor, ADC inputs for extensibility

## 🏗️ Architecture

### System Block Diagram

```
┌─────────────────┐
│  Pushbuttons    │
│  (on FPGA Bd)   │
└────────┬────────┘
         │
    ┌────▼─────────────────────────────┐
    │  FPGA Logic                       │
    │  ├─ Button Debouncer             │
    │  ├─ PWM Generator (4x)           │
    │  ├─ Control State Machine        │
    │  └─ Display Controller           │
    └────┬──────────────────────────────┘
         │
         ├──────────┬──────────┬──────────┐
         │          │          │          │
    ┌────▼───┐ ┌────▼───┐ ┌────▼───┐ ┌────▼───┐
    │ Servo 1 │ │ Servo 2 │ │ Servo 3 │ │ Servo 4 │
    │ (Base)  │ │(Elbow)  │ │(Wrist)  │ │(Gripper)│
    └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

### VHDL Modules

1. **pwm_generator.vhd** - PWM signal generation with configurable frequency and duty cycle
2. **debouncer.vhd** - Button input debouncing (20-50ms window)
3. **servo_controller.vhd** - Main servo control logic with multi-axis support
4. **button_mapper.vhd** - Maps button inputs to servo commands
5. **display_controller.vhd** - 7-segment display and LED management
6. **top.vhd** - Top-level module integrating all components

## 🔌 Pin Configuration

### Input Pins (Buttons)
```
Button 0: Servo 1 CW / CCW
Button 1: Servo 2 CW / CCW
Button 2: Servo 3 CW / CCW
Button 3: Servo 4 CW / CCW
[Additional buttons for mode selection, emergency stop, etc.]
```

### Output Pins (Servo PWM)
```
PWM 0: Servo 1 (Base Joint)
PWM 1: Servo 2 (Elbow Joint)
PWM 2: Servo 3 (Wrist Joint)
PWM 3: Servo 4 (Gripper)
```

### Display Outputs
```
7-Segment Display: Position feedback / Status display
LED Bank: Mode indicator, activity, error states
UART TX: Telemetry and debug information
```

## ⚡ Technical Specifications

| Parameter | Value |
|-----------|-------|
| FPGA Clock Frequency | 50 MHz |
| PWM Frequency | 50 Hz |
| PWM Resolution | 20 bits |
| Pulse Width Range | 1.0 - 2.0 ms |
| Button Debounce Time | 20 ms |
| Update Rate | 50 Hz |
| Max Servo Speed | Configurable per servo |

## 🚀 Getting Started

### Prerequisites
- Altera Quartus II (for DE2-415) or Xilinx ISE (for Spartan-6)
- VHDL compiler/simulator (ModelSim recommended)
- DE2-415 or Spartan-6 FPGA board
- 4-channel servo motors with control electronics
- Power supply suitable for servo motors


## 📁 Repository Structure

```
fpga-robotic-arm/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── docs/
│   ├── ARCHITECTURE.md                # Detailed system architecture
│   ├── CONTROL_LOGIC.md               # Control algorithm explanation
│   ├── HARDWARE_SETUP.md              # Hardware connection guide
│   ├── PINOUT.md                      # Pin configuration reference
│   └── TIMING_DIAGRAMS.md             # PWM and timing details
├── hdl/
│   ├── top.vhd                        # Top-level module
│   ├── pwm_generator.vhd              # PWM generation logic
│   ├── debouncer.vhd                  # Button debouncer
│   ├── servo_controller.vhd           # Main servo control
│   ├── button_mapper.vhd              # Input mapping logic
│   ├── display_controller.vhd         # 7-segment display control
│   └── tb/
│       ├── pwm_generator_tb.vhd       # PWM testbench
│       ├── debouncer_tb.vhd           # Debouncer testbench
│       └── servo_controller_tb.vhd    # System testbench
├── constraints/
│   ├── de2415_pins.ucf                # Quartus pin constraints
│   └── spartan6_pins.ucf              # ISE pin constraints
├── sim/
│   ├── run_simulation.do              # ModelSim simulation script
│   └── waveform_configs/              # Waveform configuration files
├── software/
│   ├── python/
│   │   ├── arm_controller.py          # Python control interface
│   │   ├── servo_calibration.py       # Servo calibration utility
│   │   └── monitor.py                 # Real-time monitoring
│   └── embedded_c/
│       └── uart_monitor.c             # UART telemetry receiver
├── media/
│   ├── demo_video.mp4                 # System demonstration video
│   ├── schematic.pdf                  # Wiring diagram
│   ├── photos/
│   │   ├── board_overview.jpg         # FPGA board photo
│   │   ├── arm_assembly.jpg           # Robotic arm photo
│   │   └── connections.jpg            # Connection details
│   └── diagrams/
│       ├── block_diagram.svg          # System architecture
│       └── pwm_timing.svg             # PWM timing diagram
└── tests/
    ├── button_test.vhd                # Button functionality test
    ├── pwm_verification.vhd           # PWM output verification
    └── integration_test.vhd           # Full system integration test
```



---

**Last Updated**: May 2026  
**Status**: Active Development  
**Version**: 1.0.0
