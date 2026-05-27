# Pinout Configuration Reference

## DE2-415 (Altera/Intel Cyclone IV)

### Clock and Reset
| Signal | Pin | Direction | Standard |
|--------|-----|-----------|----------|
| `clk` | PIN_Y2 | Input | 3.3-V LVTTL |
| `rst_n` | PIN_M23 | Input | 3.3-V LVTTL |

### Buttons
| Signal | Pin | Description |
|--------|-----|-------------|
| `button_0` | PIN_M21 | Servo 1 CW/CCW |
| `button_1` | PIN_N21 | Servo 2 CW/CCW |
| `button_2` | PIN_R24 | Servo 3 CW/CCW |
| `button_3` | PIN_P28 | Servo 4 CW/CCW |

### Servo PWM
| Signal | Pin | Description |
|--------|-----|-------------|
| `servo_pwm_1` | PIN_AB22 | Base joint |
| `servo_pwm_2` | PIN_AC15 | Elbow joint |
| `servo_pwm_3` | PIN_AB21 | Wrist joint |
| `servo_pwm_4` | PIN_Y17 | Gripper |

---

## Spartan-6 (Xilinx)

### Clock and Reset
| Signal | Pin | Direction | Standard |
|--------|-----|-----------|----------|
| `clk` | V10 | Input | LVCMOS33 |
| `rst_n` | B8 | Input | LVCMOS33 |

### Buttons
| Signal | Pin | Description |
|--------|-----|-------------|
| `button_0` | A7 | Servo 1 CW/CCW |
| `button_1` | M4 | Servo 2 CW/CCW |
| `button_2` | C11 | Servo 3 CW/CCW |
| `button_3` | G12 | Servo 4 CW/CCW |

### Servo PWM
| Signal | Pin | Description |
|--------|-----|-------------|
| `servo_pwm_1` | T12 | Base joint |
| `servo_pwm_2` | V12 | Elbow joint |
| `servo_pwm_3` | N10 | Wrist joint |
| `servo_pwm_4` | P11 | Gripper |
