# Control Logic Documentation

## Overview

The control logic implements a straightforward mapping from button inputs to servo PWM adjustments. The system uses a finite state machine to process user input and update servo positions.

## Button-to-Servo Mapping

### Default Configuration

```
Button 0 (GPIO Input) ──► Servo 1 (Base Joint)
Button 1 (GPIO Input) ──► Servo 2 (Elbow Joint)
Button 2 (GPIO Input) ──► Servo 3 (Wrist Joint)
Button 3 (GPIO Input) ──► Servo 4 (Gripper)
Button 4 (GPIO Input) ──► Mode Select
Button 5 (GPIO Input) ──► Emergency Stop
Button 6 (GPIO Input) ──► Home Position
Button 7 (GPIO Input) ──► Record/Playback (Reserved)
```

## State Machine

### States

```
IDLE
  └─ Waiting for button press
  └─ System at rest, servos hold position
  
SERVO1_CW / SERVO1_CCW
  └─ Servo 1 moving clockwise or counter-clockwise
  └─ Pulse width incrementing/decrementing
  
SERVO2_CW / SERVO2_CCW
  └─ Servo 2 moving clockwise or counter-clockwise
  
SERVO3_CW / SERVO3_CCW
  └─ Servo 3 moving clockwise or counter-clockwise
  
SERVO4_CW / SERVO4_CCW
  └─ Servo 4 moving clockwise or counter-clockwise
  
HOME
  └─ All servos moving to center position (1.5 ms)
  └─ Robot arm returns to resting state
  
EMERGENCY_STOP
  └─ All servo motion halts immediately
  └─ Servos hold last known position
  └─ Prevents dangerous arm movement
```

### State Transitions

```
┌─────────┐ Button Press (0-3) ┌──────────────┐
│  IDLE   │─────────────────────►  SERVO_* CW  │
│         │                       │ (in motion) │
│         │◄──────────────────────┤            │
└─────────┘     Update Complete   └──────────────┘
    ▲
    │ Button 6 (Home)
    │
┌─────────────────────┐
│ HOME (All to Center)│
└─────────────────────┘
    │
    └─► IDLE

Button 5 (Emergency Stop):
    Transitions to EMERGENCY_STOP from any state
    └─► IDLE
```

## Servo Pulse Width Control

### Pulse Width Range

```
Minimum: 1.0 ms  (50,000 clock cycles at 50 MHz)
         └─► Servo at extreme position (min angle)

Center:  1.5 ms  (75,000 clock cycles)
         └─► Servo at middle position (neutral angle)

Maximum: 2.0 ms  (100,000 clock cycles)
         └─► Servo at extreme position (max angle)
```

### Pulse Width Adjustment

```vhdl
-- Step size per update
SERVO_STEP : integer := 2_500;  -- ~0.05 ms per 20 ms update

-- This gives ~20 steps from min to max
-- Total movement time: ~20 steps × 20 ms = 400 ms per full range
```

### Rate Limiting

To ensure smooth servo motion and prevent jitter:

```
Update Rate: 50 Hz (20 ms per update)
Max Step:    SERVO_STEP = 2,500 counts (0.05 ms)
Max Velocity: 2,500 / 20ms = 125 counts/ms = 25°/second (typical)
```

## Control Algorithm

### Main Control Loop (20 ms Period)

```
1. Sample debounced button inputs
   └─ Button 0: Servo 1 command
   └─ Button 1: Servo 2 command
   └─ Button 2: Servo 3 command
   └─ Button 3: Servo 4 command
   └─ Button 5: Emergency stop
   └─ Button 6: Home position

2. Update state machine
   └─ Determine next state based on button inputs
   └─ Check for conflicts (emergency stop overrides all)

3. Update servo positions
   └─ For each active servo:
      └─ Adjust pulse width by ±SERVO_STEP
      └─ Clamp to [SERVO_MIN, SERVO_MAX]
      └─ Load into PWM generator

4. Update display and LEDs
   └─ Show current servo positions
   └─ Indicate active servos
   └─ Show system status

5. Next cycle at next 20 ms boundary
```

### Pseudo-Code Example

```
process(clk, button_inputs)
  if rising_edge(clk) then
    -- Sample buttons
    button_deb <= debounce(button_inputs);
    
    -- Update state machine
    case current_state is
      when IDLE =>
        if button_deb(0) = '1' then
          next_state <= SERVO1_CW;
        elsif button_deb(5) = '1' then
          next_state <= EMERGENCY_STOP;
        elsif button_deb(6) = '1' then
          next_state <= HOME;
        end if;
      
      when SERVO1_CW =>
        servo1_pulse <= servo1_pulse + SERVO_STEP;
        if servo1_pulse >= SERVO_MAX then
          next_state <= IDLE;
        end if;
      
      -- ... (similar for other servos)
      
      when EMERGENCY_STOP =>
        -- Hold all servos at current position
        next_state <= IDLE;
    end case;
    
    -- Update state register
    current_state <= next_state;
    
    -- Drive PWM generators
    pwm_gen_1.pulse_width <= servo1_pulse;
    pwm_gen_2.pulse_width <= servo2_pulse;
    pwm_gen_3.pulse_width <= servo3_pulse;
    pwm_gen_4.pulse_width <= servo4_pulse;
  end if;
end process;
```

## Debounce Integration

### Debouncing Pipeline

```
Raw Button Input
      │
      ▼
  Debouncer (20 ms window)
      │
      ├─ Sample input every clock cycle
      ├─ Wait for 20 ms of stable input
      ├─ Output changes only when stable
      │
      ▼
Debounced Button Signal (clean, no bounces)
      │
      ▼
State Machine (processes stable signal)
      │
      ▼
Servo Position Update
```

### Debounce Timing

```
Input Signal:  ───┐  ┌──────┐
               ││  │││      │││
               ││  │││      │││
Debounce:      ├──┤  └──────┤
                  ▲          ▲
                  │          │
              20ms delay    Output updates
```

## Position Feedback (Future Enhancement)

For closed-loop control, add position feedback:

```
Target Position (button input)
      │
      ▼
Servo Controller
      │
      ├─► PWM Generator ─► Servo Motor
      │
      └◄─ Encoder/Potentiometer Feedback
          
          Compare: Target vs Actual
          └─► Adjust PWM if error detected
```

## Safety Features

### Emergency Stop Logic

```vhdl
-- Emergency stop overrides all other commands
if button_debounced(5) = '0' then  -- Button 5 pressed
    servo_active <= "0000";        -- Stop all servos
    servo_1_pulse <= SERVO_CENTER; -- (optional) center all
    servo_2_pulse <= SERVO_CENTER;
    servo_3_pulse <= SERVO_CENTER;
    servo_4_pulse <= SERVO_CENTER;
end if;
```

### Boundary Checking

```vhdl
-- Prevent pulse width from exceeding servo limits
if servo1_pulse < SERVO_MIN then
    servo1_pulse <= SERVO_MIN;
elsif servo1_pulse > SERVO_MAX then
    servo1_pulse <= SERVO_MAX;
end if;
```

## Velocity Profiles

### Constant Velocity (Current Implementation)

```
Pulse Width
    │       ┌─────────────
    │      /│
    │     / │ Constant slope
    │    /  │ (SERVO_STEP per update)
    │───    │
    │       │
    └───────┴─────► Time
    
Movement is linear in pulse width (approximately linear in angle)
```

### Alternative: S-Curve Acceleration (Future)

```
Pulse Width
    │         ╔═════════════╗
    │       ╱   │           │   ╲
    │      ╱    │  Constant │    ╲
    │     ╱     │  Velocity │     ╲
    │────      │           │       ────
    │          └───────────┘
    │
    └─────────────────────────────► Time

Benefits: Smoother movement, reduced mechanical stress
```

## Customization Guide

### Adjusting Servo Speed

Edit `top.vhd`:
```vhdl
constant SERVO_STEP : integer := 2_500;  -- Current: ~0.05 ms
-- Faster:  SERVO_STEP := 5_000;    -- ~0.1 ms per update
-- Slower:  SERVO_STEP := 1_000;    -- ~0.02 ms per update
```

### Changing Servo Range

Edit `top.vhd`:
```vhdl
constant SERVO_MIN    : std_logic_vector(19 downto 0) := ...(40_000, 20);   -- 0.8 ms
constant SERVO_MAX    : std_logic_vector(19 downto 0) := ...(110_000, 20);  -- 2.2 ms
constant SERVO_CENTER : std_logic_vector(19 downto 0) := ...(75_000, 20);   -- 1.5 ms
```

### Adding Velocity Scaling

```vhdl
-- Map button hold duration to velocity
signal button_hold_time : integer;

process(clk)
begin
    if button_debounced(0) = '0' then
        button_hold_time <= button_hold_time + 1;
    else
        button_hold_time <= 0;
    end if;
end process;

-- Velocity increases with button hold time
adjusted_step <= SERVO_STEP * (1 + button_hold_time / 10);
```

## Testing Control Logic

### Simulation Test Cases

1. **Single Servo Motion**
   - Button press → Servo moves toward max
   - Button release → Servo stops
   - Verify pulse width changes by SERVO_STEP

2. **Multiple Servos**
   - Press multiple buttons simultaneously
   - All servos should move independently

3. **Emergency Stop**
   - Any state + Button 5 → All servos stop
   - Verify immediate halt (no multi-cycle delay)

4. **Home Position**
   - Any state + Button 6 → All servos to center
   - Verify smooth movement to 1.5 ms

5. **Boundary Conditions**
   - Hold button at min/max → Servo stops at boundary
   - Verify clamping to [SERVO_MIN, SERVO_MAX]

### Hardware Validation

1. Connect oscilloscope to PWM outputs
2. Press button and observe pulse width change
3. Verify frequency remains 50 Hz
4. Check for glitches or jitter

## Performance Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Button response | ~20 ms | Debounce window |
| Servo update rate | 50 Hz | 20 ms period |
| Max servo speed | ~25°/sec | At SERVO_STEP=2500 |
| Full range time | ~400 ms | Min to max position |
| State transition latency | <1 ms | Pure combinational logic |

---

*Last Updated: May 2026*
