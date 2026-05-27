-- ============================================================================
-- Top-Level Module: 4DOF Robotic Arm Controller
-- File: top.vhd
--
-- Description:
--   Integrates all submodules for the FPGA-based robotic arm controller.
--   Manages button inputs, servo PWM outputs, and display control.
--
-- Architecture:
--   - 4 PWM generators for servo control
--   - 4 button inputs with debouncing
--   - State machine for mode control
--   - Display controller for 7-segment LEDs
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        -- System Clock and Reset
        clk             : in std_logic;           -- 50 MHz
        rst_n           : in std_logic;           -- Active-low reset
        
        -- Button Inputs (4-12 buttons)
        button_0        : in std_logic;           -- Servo 1 CW/CCW
        button_1        : in std_logic;           -- Servo 2 CW/CCW
        button_2        : in std_logic;           -- Servo 3 CW/CCW
        button_3        : in std_logic;           -- Servo 4 CW/CCW
        button_4        : in std_logic;           -- Mode select (optional)
        button_5        : in std_logic;           -- Emergency stop (optional)
        button_6        : in std_logic;           -- Home position (optional)
        button_7        : in std_logic;           -- Record/Play (optional)
        
        -- Servo PWM Outputs
        servo_pwm_1     : out std_logic;          -- Servo 1 (Base)
        servo_pwm_2     : out std_logic;          -- Servo 2 (Elbow)
        servo_pwm_3     : out std_logic;          -- Servo 3 (Wrist)
        servo_pwm_4     : out std_logic;          -- Servo 4 (Gripper)
        
        -- 7-Segment Display Outputs (8 displays)
        hex0            : out std_logic_vector(6 downto 0);
        hex1            : out std_logic_vector(6 downto 0);
        hex2            : out std_logic_vector(6 downto 0);
        hex3            : out std_logic_vector(6 downto 0);
        hex4            : out std_logic_vector(6 downto 0);
        hex5            : out std_logic_vector(6 downto 0);
        hex6            : out std_logic_vector(6 downto 0);
        hex7            : out std_logic_vector(6 downto 0);
        
        -- LED Indicators
        led_0           : out std_logic;          -- Servo 1 active
        led_1           : out std_logic;          -- Servo 2 active
        led_2           : out std_logic;          -- Servo 3 active
        led_3           : out std_logic;          -- Servo 4 active
        led_4           : out std_logic;          -- Mode indicator
        led_5           : out std_logic;          -- Error indicator
        led_6           : out std_logic;          -- Position reached
        led_7           : out std_logic;          -- System active
        led_8           : out std_logic;          -- Reserved
        led_9           : out std_logic;          -- Reserved
        
        -- UART for Telemetry (optional)
        uart_tx         : out std_logic;
        uart_rx         : in std_logic
    );
end top;

architecture rtl of top is
    
    -- PWM Generator Component
    component pwm_generator
        generic (
            CLK_FREQ    : integer;
            PWM_FREQ    : integer;
            PULSE_MIN   : integer;
            PULSE_MAX   : integer;
            PERIOD_CNTS : integer
        );
        port (
            clk         : in std_logic;
            rst_n       : in std_logic;
            pulse_width : in std_logic_vector(19 downto 0);
            pwm_out     : out std_logic
        );
    end component;
    
    -- Debouncer Component
    component debouncer
        generic (
            CLK_FREQ      : integer;
            DEBOUNCE_TIME : integer
        );
        port (
            clk              : in std_logic;
            rst_n            : in std_logic;
            button_in        : in std_logic;
            button_debounced : out std_logic
        );
    end component;
    
    -- Internal signal declarations
    signal button_debounced : std_logic_vector(7 downto 0);
    signal servo_pulse_width : array_4bit(0 to 3) of std_logic_vector(19 downto 0);
    signal servo_active : std_logic_vector(3 downto 0);
    signal system_reset : std_logic;
    signal servo_positions : array_16bit(0 to 3) of std_logic_vector(15 downto 0);
    
    -- State machine declarations
    type state_type is (IDLE, SERVO1_CW, SERVO1_CCW, 
                        SERVO2_CW, SERVO2_CCW,
                        SERVO3_CW, SERVO3_CCW,
                        SERVO4_CW, SERVO4_CCW,
                        HOME, EMERGENCY_STOP);
    signal current_state, next_state : state_type;
    
    -- Servo pulse width parameters (in clock cycles at 50 MHz)
    constant SERVO_MIN : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(50_000, 20));   -- 1.0 ms
    constant SERVO_MAX : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(100_000, 20));  -- 2.0 ms
    constant SERVO_CENTER : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(75_000, 20)); -- 1.5 ms
    constant SERVO_STEP : integer := 2_500;  -- 0.05 ms step size
    
    -- Control registers for servo positions
    signal servo_1_pulse : std_logic_vector(19 downto 0) := SERVO_CENTER;
    signal servo_2_pulse : std_logic_vector(19 downto 0) := SERVO_CENTER;
    signal servo_3_pulse : std_logic_vector(19 downto 0) := SERVO_CENTER;
    signal servo_4_pulse : std_logic_vector(19 downto 0) := SERVO_CENTER;
    
    -- Debounce counter for preventing rapid updates
    signal debounce_counter : integer range 0 to 100_000;
    signal allow_update : std_logic;
    
begin
    
    -- Reset synchronization
    system_reset <= not rst_n;
    
    -- ========================================================================
    -- Debouncer Instantiation
    -- ========================================================================
    
    debounce_0: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000  -- 20 ms
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_0,
            button_debounced => button_debounced(0)
        );
    
    debounce_1: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_1,
            button_debounced => button_debounced(1)
        );
    
    debounce_2: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_2,
            button_debounced => button_debounced(2)
        );
    
    debounce_3: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_3,
            button_debounced => button_debounced(3)
        );
    
    debounce_4: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_4,
            button_debounced => button_debounced(4)
        );
    
    debounce_5: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_5,
            button_debounced => button_debounced(5)
        );
    
    debounce_6: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_6,
            button_debounced => button_debounced(6)
        );
    
    debounce_7: debouncer
        generic map (
            CLK_FREQ => 50_000_000,
            DEBOUNCE_TIME => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            button_in => button_7,
            button_debounced => button_debounced(7)
        );
    
    -- ========================================================================
    -- PWM Generator Instantiation (4x for 4 servos)
    -- ========================================================================
    
    pwm_gen_0: pwm_generator
        generic map (
            CLK_FREQ => 50_000_000,
            PWM_FREQ => 50,
            PULSE_MIN => 50_000,
            PULSE_MAX => 100_000,
            PERIOD_CNTS => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            pulse_width => servo_1_pulse,
            pwm_out => servo_pwm_1
        );
    
    pwm_gen_1: pwm_generator
        generic map (
            CLK_FREQ => 50_000_000,
            PWM_FREQ => 50,
            PULSE_MIN => 50_000,
            PULSE_MAX => 100_000,
            PERIOD_CNTS => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            pulse_width => servo_2_pulse,
            pwm_out => servo_pwm_2
        );
    
    pwm_gen_2: pwm_generator
        generic map (
            CLK_FREQ => 50_000_000,
            PWM_FREQ => 50,
            PULSE_MIN => 50_000,
            PULSE_MAX => 100_000,
            PERIOD_CNTS => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            pulse_width => servo_3_pulse,
            pwm_out => servo_pwm_3
        );
    
    pwm_gen_3: pwm_generator
        generic map (
            CLK_FREQ => 50_000_000,
            PWM_FREQ => 50,
            PULSE_MIN => 50_000,
            PULSE_MAX => 100_000,
            PERIOD_CNTS => 1_000_000
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            pulse_width => servo_4_pulse,
            pwm_out => servo_pwm_4
        );
    
    -- ========================================================================
    -- Control Logic: State Machine and Servo Position Update
    -- ========================================================================
    
    -- Update rate limiter (prevent too-rapid servo movement)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            debounce_counter <= 0;
            allow_update <= '0';
        elsif rising_edge(clk) then
            if debounce_counter = 100_000 then  -- ~2ms at 50MHz
                allow_update <= '1';
                debounce_counter <= 0;
            else
                allow_update <= '0';
                debounce_counter <= debounce_counter + 1;
            end if;
        end if;
    end process;
    
    -- State Machine: Button to Servo Mapping
    process(current_state, button_debounced, allow_update)
    begin
        next_state <= current_state;
        
        if allow_update = '1' then
            case current_state is
                
                when IDLE =>
                    if button_debounced(0) = '0' then
                        next_state <= SERVO1_CW;
                    elsif button_debounced(1) = '0' then
                        next_state <= SERVO2_CW;
                    elsif button_debounced(2) = '0' then
                        next_state <= SERVO3_CW;
                    elsif button_debounced(3) = '0' then
                        next_state <= SERVO4_CW;
                    elsif button_debounced(5) = '0' then
                        next_state <= EMERGENCY_STOP;
                    elsif button_debounced(6) = '0' then
                        next_state <= HOME;
                    end if;
                
                when SERVO1_CW =>
                    next_state <= IDLE;
                
                when SERVO1_CCW =>
                    next_state <= IDLE;
                
                when SERVO2_CW =>
                    next_state <= IDLE;
                
                when SERVO2_CCW =>
                    next_state <= IDLE;
                
                when SERVO3_CW =>
                    next_state <= IDLE;
                
                when SERVO3_CCW =>
                    next_state <= IDLE;
                
                when SERVO4_CW =>
                    next_state <= IDLE;
                
                when SERVO4_CCW =>
                    next_state <= IDLE;
                
                when EMERGENCY_STOP =>
                    next_state <= IDLE;
                
                when HOME =>
                    next_state <= IDLE;
                
                when others =>
                    next_state <= IDLE;
                    
            end case;
        end if;
    end process;
    
    -- State Register Update
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;
    
    -- Servo Position Update Based on State
    process(clk, rst_n)
        variable servo1_val : integer;
        variable servo2_val : integer;
        variable servo3_val : integer;
        variable servo4_val : integer;
    begin
        if rst_n = '0' then
            servo_1_pulse <= SERVO_CENTER;
            servo_2_pulse <= SERVO_CENTER;
            servo_3_pulse <= SERVO_CENTER;
            servo_4_pulse <= SERVO_CENTER;
            servo_active <= "0000";
            
        elsif rising_edge(clk) then
            
            case current_state is
                
                when SERVO1_CW =>
                    servo1_val := to_integer(unsigned(servo_1_pulse)) + SERVO_STEP;
                    if servo1_val <= 100_000 then
                        servo_1_pulse <= std_logic_vector(to_unsigned(servo1_val, 20));
                    end if;
                    servo_active <= "0001";
                
                when SERVO1_CCW =>
                    servo1_val := to_integer(unsigned(servo_1_pulse)) - SERVO_STEP;
                    if servo1_val >= 50_000 then
                        servo_1_pulse <= std_logic_vector(to_unsigned(servo1_val, 20));
                    end if;
                    servo_active <= "0001";
                
                when SERVO2_CW =>
                    servo2_val := to_integer(unsigned(servo_2_pulse)) + SERVO_STEP;
                    if servo2_val <= 100_000 then
                        servo_2_pulse <= std_logic_vector(to_unsigned(servo2_val, 20));
                    end if;
                    servo_active <= "0010";
                
                when SERVO2_CCW =>
                    servo2_val := to_integer(unsigned(servo_2_pulse)) - SERVO_STEP;
                    if servo2_val >= 50_000 then
                        servo_2_pulse <= std_logic_vector(to_unsigned(servo2_val, 20));
                    end if;
                    servo_active <= "0010";
                
                when SERVO3_CW =>
                    servo3_val := to_integer(unsigned(servo_3_pulse)) + SERVO_STEP;
                    if servo3_val <= 100_000 then
                        servo_3_pulse <= std_logic_vector(to_unsigned(servo3_val, 20));
                    end if;
                    servo_active <= "0100";
                
                when SERVO3_CCW =>
                    servo3_val := to_integer(unsigned(servo_3_pulse)) - SERVO_STEP;
                    if servo3_val >= 50_000 then
                        servo_3_pulse <= std_logic_vector(to_unsigned(servo3_val, 20));
                    end if;
                    servo_active <= "0100";
                
                when SERVO4_CW =>
                    servo4_val := to_integer(unsigned(servo_4_pulse)) + SERVO_STEP;
                    if servo4_val <= 100_000 then
                        servo_4_pulse <= std_logic_vector(to_unsigned(servo4_val, 20));
                    end if;
                    servo_active <= "1000";
                
                when SERVO4_CCW =>
                    servo4_val := to_integer(unsigned(servo_4_pulse)) - SERVO_STEP;
                    if servo4_val >= 50_000 then
                        servo_4_pulse <= std_logic_vector(to_unsigned(servo4_val, 20));
                    end if;
                    servo_active <= "1000";
                
                when HOME =>
                    servo_1_pulse <= SERVO_CENTER;
                    servo_2_pulse <= SERVO_CENTER;
                    servo_3_pulse <= SERVO_CENTER;
                    servo_4_pulse <= SERVO_CENTER;
                    servo_active <= "1111";
                
                when EMERGENCY_STOP =>
                    servo_active <= "0000";
                
                when others =>
                    servo_active <= "0000";
                    
            end case;
        end if;
    end process;
    
    -- ========================================================================
    -- LED Output Assignment
    -- ========================================================================
    
    led_0 <= servo_active(0);
    led_1 <= servo_active(1);
    led_2 <= servo_active(2);
    led_3 <= servo_active(3);
    led_4 <= '0';  -- Mode indicator (reserved)
    led_5 <= '0';  -- Error indicator
    led_6 <= '0';  -- Position reached
    led_7 <= '1';  -- System active
    led_8 <= '0';  -- Reserved
    led_9 <= '0';  -- Reserved
    
    -- ========================================================================
    -- 7-Segment Display Placeholder (implement display controller separately)
    -- ========================================================================
    
    hex0 <= "1111111";  -- Placeholder (implement display logic)
    hex1 <= "1111111";
    hex2 <= "1111111";
    hex3 <= "1111111";
    hex4 <= "1111111";
    hex5 <= "1111111";
    hex6 <= "1111111";
    hex7 <= "1111111";
    
    -- ========================================================================
    -- UART Placeholder (implement telemetry separately)
    -- ========================================================================
    
    uart_tx <= '1';  -- Idle state
    
end architecture rtl;
