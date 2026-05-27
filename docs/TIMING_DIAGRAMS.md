# Timing Diagrams

## PWM Signal Timing

The PWM generator creates a 50 Hz signal (20ms period) with a variable high time (pulse width) from 1.0ms to 2.0ms.

```text
20ms Period
|<--------------------------------------------------->|
|                                                     |
|<- 1.5ms ->|                                         |
+-----------+                                         +--
|           |                                         |
|           +-----------------------------------------+
0           1.5ms                                    20ms
```

## Button Debounce

Buttons are sampled and must remain stable for 20ms before the debounced output changes.

```text
Raw Button: 1 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
                  |<--------- 20ms -------->|
Debounced:  1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0
```

## State Machine Transition

Transitions happen synchronously on the rising edge of the clock.

```text
clk:        ^   ^   ^   ^   ^   ^
button_deb: 1   0   0   0   1   1
state:    IDLE  CW  CW  CW IDLE IDLE
```
