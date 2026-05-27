# Hardware Setup Guide

## System Components

### FPGA Development Board
- **DE2-415** (Altera/Intel) or **Spartan-6** (Xilinx)
- 50 MHz clock input
- GPIO pins for buttons and PWM outputs
- 3.3V I/O voltage

### Servo Motors
- **Quantity**: 4 standard servo motors
- **Specifications**:
  - Control signal: PWM, 50 Hz, 1-2 ms pulse width
  - Power supply: 5V DC (separate from FPGA)
  - Current per servo: ~500-1000 mA max
  - Torque rating: Depends on servo model

### Power Supply
- **FPGA Board**: USB power (typically 500 mA @ 5V)
- **Servo Motors**: External 5V/10A regulated power supply (highly recommended)
- **Voltage Isolation**: Use separate power supplies to prevent noise coupling

### Mechanical Components
- **Robot Arm**: 4DOF assembly with joints at base, elbow, wrist, and gripper
- **Mounting**: Mechanical frame to support servos and arm structure

## Wiring Diagram

```
FPGA Board                          Servo Motors
┌─────────────────┐
│  DE2-415/       │
│ Spartan-6       │
│                 │
│ GPIO Pins:      │                   ┌─ Brown (GND)
│  Button 0 ◄─────┼───────────────────┤─ Red (5V)
│  Button 1 ◄─────┼──────────────     └─ Orange (PWM)
│  Button 2 ◄─────┼──────────────
│  Button 3 ◄─────┼──────────────
│  Button 4 ◄─────┼──────────────     ┌─ Servo 1 (Base)
│  Button 5 ◄─────┼──────────────     ├─ Servo 2 (Elbow)
│  Button 6 ◄─────┼──────────────     ├─ Servo 3 (Wrist)
│  Button 7 ◄─────┼──────────────     ├─ Servo 4 (Gripper)
│                 │                   └─ (Add more buttons as needed)
│ PWM Outputs:    │
│  GPIO 0 ─┐      │
│  GPIO 1  ├──► Servo Control Signals
│  GPIO 2  │
│  GPIO 3 ─┘
│                 │
│ LED Outputs:    │
│  LED 0-9 ───────┼─────► Status Indicators
│                 │
│ 7-Segment:      │
│  HEX 0-7 ───────┼─────► Position Display
│                 │
└─────────────────┘
        ▲
        │ USB (Programming)
        │ 50 MHz Clock
        │ Power
```

## Pin Configuration

### Button Input Pins (Typical for DE2-415)
```
Pin Assignment (Altera DE2-415):
Button 0: PIN_L2     (GPIO_0[0])     - Servo 1 CW/CCW
Button 1: PIN_L1     (GPIO_0[1])     - Servo 2 CW/CCW
Button 2: PIN_M2     (GPIO_0[2])     - Servo 3 CW/CCW
Button 3: PIN_M1     (GPIO_0[3])     - Servo 4 CW/CCW
Button 4: PIN_N2     (GPIO_0[4])     - Mode select
Button 5: PIN_P2     (GPIO_0[5])     - Emergency stop
Button 6: PIN_N1     (GPIO_0[6])     - Home position
Button 7: PIN_P1     (GPIO_0[7])     - Reserved

(Adjust pin numbers based on your specific board and design)
```

### PWM Output Pins (Typical for DE2-415)
```
PWM Output Pins:
Servo 1 PWM: PIN_AA1  (GPIO_1[0])    ─► Servo 1 Control
Servo 2 PWM: PIN_AB1  (GPIO_1[1])    ─► Servo 2 Control
Servo 3 PWM: PIN_AC1  (GPIO_1[2])    ─► Servo 3 Control
Servo 4 PWM: PIN_AD1  (GPIO_1[3])    ─► Servo 4 Control

(Adjust pin numbers based on your specific board and design)
```

### 7-Segment Display Pins (Typical for DE2-415)
```
HEX Display:
HEX[0]: PIN_B5, PIN_A5, PIN_D5, PIN_C5, PIN_E5, PIN_C6, PIN_B6, PIN_A6
HEX[1]: Similar configuration
... (repeat for HEX[2] through HEX[7])

(Specific pin assignments depend on board variant)
```

## Physical Connections

### Button Wiring
```
Mechanical Button
        │
        ├─ Button Terminal 1 ──── FPGA GPIO Pin
        │                         (with internal pull-up)
        ├─ Button Terminal 2 ──── GND (FPGA)
        │
    Debounce Capacitor (optional):
    Add 0.1μF ceramic capacitor across button terminals
    for additional noise filtering
```

### Servo Motor Wiring
```
Standard Servo Connector (3-pin):
┌─────────────────┐
│ Brown  │ Red  │ Orange │
│ (GND)  │(+5V) │ (PWM)  │
└─────────────────┘
   │       │        │
   │       │        └──────► FPGA GPIO Pin (3.3V logic)
   │       │
   │       └──────► +5V External Power Supply (NOT FPGA power!)
   │
   └──────► Ground (common with FPGA ground)
```

**IMPORTANT**: Use an external 5V power supply for servo motors. FPGA power supplies typically cannot provide sufficient current for multiple servos.

## Step-by-Step Connection Guide

### 1. Power Preparation
- [ ] Ensure FPGA board and servo power supply are unpowered
- [ ] Verify external power supply output: 5V ±0.5V
- [ ] Check current rating: minimum 5A recommended for 4 servos

### 2. Ground Connection
- [ ] Connect GND from FPGA board to external power supply GND
- [ ] Use thick wire (AWG 16 or thicker) for ground returns
- [ ] Create star connection point for servo ground wires

### 3. Button Wiring
- [ ] Connect each button to designated GPIO input pin
- [ ] Connect button other terminal to FPGA GND
- [ ] Verify button polarity (active-low recommended)
- [ ] Optional: Solder debounce capacitor (0.1μF) across button terminals

### 4. Servo PWM Connections
- [ ] Identify PWM output pins on FPGA board
- [ ] Connect PWM pin to servo orange (signal) wire
- [ ] Use shielded or twisted-pair cable if PWM run >1m

### 5. Servo Power Connections
- [ ] Connect all servo brown (GND) wires to external power supply GND
- [ ] Connect all servo red (+5V) wires to external power supply +5V
- [ ] Verify no loose connections or poor contacts
- [ ] Use crimp connectors or solder joints (no twist connections)

### 6. Verification
- [ ] Visually inspect all connections for correctness
- [ ] Use multimeter to verify:
  - Continuity between GND points
  - 5V on servo power pins (motors unpowered)
  - 3.3V logic levels on FPGA outputs
- [ ] Check for shorts between adjacent pins

## LED and Display Connections (Optional)

### LED Status Indicators
```
Common Anode Configuration:
┌─ LED Cathode Leg (short) ─── FPGA GPIO Pin (through 220Ω resistor)
│
LED
│
└─ LED Anode Leg (long) ─────── 3.3V or 5V supply

Resistor Value: 220-330Ω (limits current to ~10-15mA per LED)
```

### 7-Segment Display
Refer to FPGA board documentation for specific pin assignments.
Typical configuration: Common anode or common cathode
Segment labeling:
```
    a
   ___
  |f |b|
  |g |
  |e |c|
   ___
    d
```

## Troubleshooting Connections

| Issue | Cause | Solution |
|-------|-------|----------|
| Servo doesn't respond | No PWM signal | Check FPGA programming; verify GPIO pin assignment |
| Weak servo movement | Insufficient power | Use external 5V supply; check servo power connection |
| Noisy servo movement | EMI/noise coupling | Add ferrite core on servo power cable; shield PWM lines |
| Button unresponsive | Floating input | Verify pull-up resistor; check button connection |
| LEDs not lighting | Wrong polarity | Check LED orientation (long leg = anode) |
| Display not working | Pin mismatch | Verify all segment pins in constraint file |

## Cable Management

- **Button cables**: ~1-2 meters from FPGA to buttons
- **PWM cables**: Keep short (<1m) to avoid noise pickup
  - Use shielded twisted-pair for PWM signals
  - Shield connected to GND at FPGA end only
- **Power cables**: Use appropriate gauge (AWG 16 or larger for servo power)
- **Separation**: Keep PWM lines away from high-current servo power lines

## Testing Connections Without FPGA

### Servo Motor Test
1. Connect servo to 5V external power supply (no FPGA)
2. Apply 1.5 ms pulse at 50 Hz to servo signal pin
3. Servo should move to center position
4. Adjust pulse width (1.0-2.0 ms) and verify full range

### Button Test (with FPGA running)
1. Program "blink" design into FPGA
2. Press each button and observe LED response
3. Verify no ghosting or multiple triggers

## Safety Considerations

- **Servo Torque**: The arm can exert significant force. Keep hands away during operation.
- **Power Supply Isolation**: Use separate power supplies to prevent ground loops.
- **Voltage Levels**: Ensure all logic signals are 3.3V (FPGA standard), not 5V.
- **Current Limiting**: Add inline fuses (1-2A) on servo power supply for protection.
- **Emergency Stop**: Button 5 should immediately stop all servo motion.

## Advanced Customization

### Adding Analog Inputs (ADC)
If your FPGA board has an ADC:
- Connect joystick X-axis to ADC_0
- Connect joystick Y-axis to ADC_1
- Map ADC values (0-4095) to servo pulse widths (50,000-100,000)

### Adding Encoder Feedback
For closed-loop position control:
- Connect encoder output to GPIO inputs
- Implement quadrature decoder in VHDL
- Compare encoder position to target position

### Wireless Control
Add wireless module (Bluetooth, WiFi):
- Connect wireless RX to UART_RX pin
- Receive servo commands via wireless protocol
- Override button-based control when wireless active

---

**Last Updated**: May 2026
