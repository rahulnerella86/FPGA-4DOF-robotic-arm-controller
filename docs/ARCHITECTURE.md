# FPGA Robotic Arm - System Architecture

## Overview

The FPGA-based 4DOF robotic arm controller is a real-time embedded system that demonstrates hardware-level control of servo motors using FPGA logic. The system operates synchronously at 50 MHz clock frequency with multiple functional blocks working in parallel.

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        FPGA Logic                               │
│                     (50 MHz Clock)                              │
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────┐     │
│  │ Button   │    │ Debounce     │    │ Button Mapper    │     │
│  │ Inputs   │───▶│ Logic        │───▶│ (State Machine)  │     │
│  │(4-12)    │    │ (20ms)       │    │                  │     │
│  └──────────┘    └──────────────┘    └────────┬─────────┘     │
│                                                │                │
│  ┌──────────┐    ┌──────────────┐    ┌────────▼─────────┐     │
│  │ Servo    │    │ PWM          │    │ Servo Control    │     │
│  │ Feedback │───▶│ Generators   │◀───│ Logic            │     │
│  │(Optional)│    │ (4x 50Hz)    │    │                  │     │
│  └──────────┘    └──────┬───────┘    └──────────────────┘     │
│                         │                                       │
│  ┌──────────┐    ┌──────▼──────┐    ┌──────────────────┐     │
│  │ Display  │    │ Display      │    │ Clock/Reset      │     │
│  │ Outputs  │───▶│ Controller   │    │ Management       │     │
│  │(7-seg)   │    │ (8-digit)    │    │                  │     │
│  └──────────┘    └──────────────┘    └──────────────────┘     │
│                                                                 │
└────────┬──────────┬──────────┬──────────┬──────────────────────┘
         │          │          │          │
    ┌────▼───┐ ┌────▼───┐ ┌────▼───┐ ┌────▼───┐
    │ Servo 1 │ │ Servo 2 │ │ Servo 3 │ │ Servo 4 │  External
    │(PWM)   │ │(PWM)   │ │(PWM)   │ │(PWM)   │  Servo Motors
    └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

## Functional Blocks

### 1. Input Stage: Button Management

**Module**: `button_inputs.vhd`

#### Purpose
- Acquire button states from FPGA board GPIO pins
- Provide hardware-level debouncing
- Generate clean button signals for state machine

#### Debounce Algorithm
```
Input Signal (noisy): ┌─┐                    ┌─┐
                      │ └──┐            ┌────┘ └──
                      
After 20ms Debounce:  ┌────────────┐    ┌─────────
                      │            │    │
                      └─────────────┘    └─────────
```

**Debounce Time**: 20 ms (at 50 MHz = 1,000,000 clock cycles)

#### Specifications
- Number of buttons: 4-12 (configurable)
- Debounce window: 20 ms
- Input voltage: 3.3V (FPGA I/O standard)
- Logic: Active-low (typical button configuration)

### 2. Input Processing: Button Mapper

**Module**: `button_mapper.vhd`

#### Purpose
- Convert debounced button signals to servo commands
- Implement state machine for mode selection
- Generate servo control parameters

#### Control Matrix
```
Button 0: ─┬─ Pulse Up   → Servo 1 increase pulse width
           └─ Pulse Down → Servo 1 decrease pulse width

Button 1: ─┬─ Pulse Up   → Servo 2 increase pulse width
           └─ Pulse Down → Servo 2 decrease pulse width

Button 2: ─┬─ Pulse Up   → Servo 3 increase pulse width
           └─ Pulse Down → Servo 3 decrease pulse width

Button 3: ─┬─ Pulse Up   → Servo 4 increase pulse width
           └─ Pulse Down → Servo 4 decrease pulse width

[Optional Buttons]:
Button 4: Mode Select (Manual/Automatic)
Button 5: Emergency Stop
Button 6: Reset to Home Position
Button 7: Record/Playback
```

#### State Machine
```
States:
  IDLE        → Waiting for button press
  ACTIVE      → Button pressed, servo moving
  DEBOUNCE    → Waiting for debounce window
  HOLD        → Button held for continuous motion
```

### 3. Core Control: Servo Controller

**Module**: `servo_controller.vhd`

#### Purpose
- Maintain servo position/pulse width values
- Implement rate limiting for smooth motion
- Coordinate multi-axis operation

#### Servo Parameters (per axis)
```vhdl
type servo_record is record
    current_pulse_width : integer range 1000 to 2000;
    target_pulse_width  : integer range 1000 to 2000;
    velocity            : integer range 0 to 100;    -- Steps per 20ms
    enabled             : std_logic;
    error_state         : std_logic;
end record;
```

#### Pulse Width Mapping
```
Pulse Width (ms)    →    Servo Angle
1.0 ms              →    -90° (or minimum)
1.5 ms              →     0° (center)
2.0 ms              →    +90° (or maximum)

Hardware Resolution:
20-bit counter at 50MHz = 1 count = 20ns
For 20ms period: 20ms / 20ns = 1,000,000 counts
```

#### Rate Limiting
```vhdl
-- Smooth motion profile
-- Maximum step change: velocity_limit per update period
process(clk)
begin
    if rising_edge(clk) then
        if current_pulse_width < target_pulse_width then
            current_pulse_width <= current_pulse_width + velocity;
        elsif current_pulse_width > target_pulse_width then
            current_pulse_width <= current_pulse_width - velocity;
        end if;
    end if;
end process;
```

### 4. Output Generation: PWM Generators

**Module**: `pwm_generator.vhd` (instantiated 4x)

#### Purpose
- Generate 50 Hz PWM signals for servo control
- Provide configurable pulse width (1-2 ms)
- Maintain deterministic timing

#### PWM Generation Algorithm
```
Period = 20 ms (50 Hz)
Clock = 50 MHz
Counts per period = 1,000,000

Pulse Width = (desired_ms * 50,000) counts

Example: 1.5 ms pulse
1.5 * 50,000 = 75,000 counts at HIGH
Remaining = 1,000,000 - 75,000 = 925,000 counts at LOW
```

#### Timing Diagram
```
20 ms Period (50 Hz):
┌─────────────────────────────────────────────┐
│ HIGH: 1-2 ms     │         LOW: 18-19 ms    │
└─────────────────────────────────────────────┘
↑                   ↑
0ns                1.5ms (example)
```

#### Specifications
- Frequency: 50 Hz (20 ms period)
- Pulse Width Range: 1.0 - 2.0 ms
- Resolution: ~5 μs per count (at 50 MHz)
- Accuracy: ±1 clock cycle (20 ns)
- Jitter: <50 ns typical

### 5. Display Output: Display Controller

**Module**: `display_controller.vhd`

#### Purpose
- Drive 7-segment LED displays
- Show servo positions, status, error codes
- Provide visual feedback to operator

#### Display Update Scheme
```
Display 0-1: Servo 1 position (0-180°)
Display 2-3: Servo 2 position (0-180°)
Display 4-5: Servo 3 position (0-180°)
Display 6-7: Servo 4 position (0-180°)

Refresh Rate: 1 kHz (multiplexed display)
```

#### 7-Segment Control
```vhdl
-- Common anode/cathode configuration
-- Refresh rate: 1 display per 100 μs
-- Typical multiplexing: 8 displays × 100 μs = 800 μs cycle

HEX 0 ─────┐
           ├─► Multiplexer ──► 7-Segment Driver
HEX 1 ─────┤
           └─► Select Line (3 bits for 8 displays)
```

### 6. System Integration: Top Module

**Module**: `top.vhd`

#### Port Mapping
```vhdl
entity top is
    port (
        -- Clock and Reset
        clk        : in std_logic;        -- 50 MHz
        rst_n      : in std_logic;        -- Active low
        
        -- Button Inputs (4 minimum, 12 maximum)
        buttons    : in std_logic_vector(11 downto 0);
        
        -- Servo PWM Outputs
        servo_pwm  : out std_logic_vector(3 downto 0);
        
        -- Display Outputs
        hex0, hex1, hex2, hex3 : out std_logic_vector(6 downto 0);
        hex4, hex5, hex6, hex7 : out std_logic_vector(6 downto 0);
        
        -- LED Status Indicators
        leds       : out std_logic_vector(9 downto 0);
        
        -- UART for Telemetry (optional)
        uart_tx    : out std_logic;
        uart_rx    : in std_logic
    );
end top;
```

## Data Flow

### Button Press to Servo Movement

```
1. Button Press (t=0)
   └─► Raw GPIO → Debouncer
   
2. Debounce Window (t=0 to t=20ms)
   └─► Sample button state multiple times
   
3. Debounce Complete (t=20ms)
   └─► Stable signal → Button Mapper
   
4. Servo Update (t=20-30ms)
   └─► New pulse width → PWM Generator
   
5. PWM Output (next 20ms cycle)
   └─► Servo motor responds
   
6. Visual Feedback (simultaneous)
   └─► Display Controller → 7-Segment Display
```

### Timing Characteristics
- Button debounce: 20 ms
- System update: 20 ms (50 Hz)
- Display refresh: ~1 ms (multiplexed)
- Total latency: ~20-40 ms end-to-end

## Clock Domains

```
Primary Clock Domain: 50 MHz
├─ Button debounce counters
├─ PWM period counters
├─ Display multiplexer
└─ State machines

No multi-clock domain crossings
(Single synchronous design)
```

## Power and Reset Strategy

### Power Sequence
```
1. Power supply on → FPGA power stabilizes
2. External reset button → PLL initialization
3. Internal reset counter → Propagate reset to all modules
4. System ready → Normal operation
```

### Reset Distribution
```
Global Reset (rst_n)
        ↓
    ┌───────────────────────────────────┐
    │                                   │
    ▼           ▼           ▼           ▼
Debouncer   PWM Gen    Servo Ctrl   Display Ctrl
    │           │           │           │
    └───────────────────────────────────┘
```

## Resource Utilization (Estimated)

### FPGA Resources
- **Logic Elements**: ~2,000-3,000 (20-30% of typical FPGA)
- **Block RAM**: Minimal (display buffers only)
- **Multipliers**: None required
- **I/O Blocks**: ~20-25

### Timing Performance
- **Maximum Clock Frequency**: >100 MHz
- **Target Clock**: 50 MHz
- **Setup Time Margin**: >50%
- **Hold Time Margin**: >50%

## Design Patterns

### 1. Finite State Machine (FSM)
Used in button mapper for mode control
```vhdl
type state_type is (IDLE, ACTIVE, DEBOUNCE, HOLD);
signal current_state, next_state : state_type;
```

### 2. Counter-based Timing
Debounce and PWM use timing counters
```vhdl
if counter = DEBOUNCE_TIME then
    debounced <= '1';
    counter <= 0;
else
    counter <= counter + 1;
end if;
```

### 3. Parallel Processing
All 4 servo channels operate in parallel
- No serialization → True 50 Hz update rate
- Independent velocity profiles per servo
- Simultaneous button monitoring

## Extensibility

### Adding Features

#### Analog Joystick Input
- Add ADC module
- Map analog values to pulse widths
- Override button-based control

#### UART Remote Control
- Add serial receiver module
- Map UART packets to servo commands
- Enable PC-based control

#### Encoder Feedback
- Add encoder reading module
- Close-loop position control
- Enable precise positioning

#### Recording/Playback
- Add dual-port BRAM
- Record servo sequences
- Automatic replay mode

## Testing Strategy

### Unit Testing
- Each module tested independently
- Testbenches verify timing and functionality
- Compare against expected waveforms

### Integration Testing
- Full system testbench
- Simulate button presses and servo responses
- Verify display updates

### Hardware Testing
- Program FPGA with bitstream
- Physical button press testing
- Oscilloscope verification of PWM signals
- Servo motor response verification

---

**Document Version**: 1.0  
**Last Updated**: May 2026
