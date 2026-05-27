-- ============================================================================
-- Servo Controller Module
-- File: servo_controller.vhd
--
-- Description:
--   Standalone servo control entity that manages 4 servo motors via a
--   finite state machine.  Accepts 8 debounced button inputs and produces
--   4 × 20-bit pulse-width outputs plus a 4-bit servo_active indicator.
--
-- State Machine:
--   IDLE          – No movement; wait for button input
--   SERVO1_CW     – Increment Servo 1 pulse width (clockwise)
--   SERVO1_CCW    – Decrement Servo 1 pulse width (counter-clockwise)
--   SERVO2_CW/CCW – Same for Servo 2
--   SERVO3_CW/CCW – Same for Servo 3
--   SERVO4_CW/CCW – Same for Servo 4
--   HOME          – Return all servos to center position
--   EMERGENCY_STOP – Freeze all servos; clear active flags
--
-- Button Mapping (active-low buttons, active after debounce):
--   button(0) – Servo 1 toggle CW / CCW
--   button(1) – Servo 2 toggle CW / CCW
--   button(2) – Servo 3 toggle CW / CCW
--   button(3) – Servo 4 toggle CW / CCW
--   button(4) – (reserved / mode)
--   button(5) – Emergency stop
--   button(6) – Home position
--   button(7) – (reserved)
--
-- Rate Limiting:
--   An internal divider (UPDATE_DIVIDER) gates servo position updates
--   so that only one SERVO_STEP increment/decrement occurs every
--   UPDATE_DIVIDER clock cycles (~2 ms at default 100,000 counts).
--
-- Generics:
--   CLK_FREQ     – System clock frequency in Hz (default 50 MHz)
--   SERVO_STEP   – Pulse-width increment per update (default 2,500)
--   SERVO_MIN    – Minimum pulse width in clk cycles  (default 50,000)
--   SERVO_MAX    – Maximum pulse width in clk cycles  (default 100,000)
--   SERVO_CENTER – Center (home) pulse width           (default 75,000)
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity servo_controller is
    generic (
        CLK_FREQ      : integer := 50_000_000;  -- 50 MHz
        SERVO_STEP    : integer := 2_500;        -- 0.05 ms step
        SERVO_MIN     : integer := 50_000;       -- 1.0 ms minimum
        SERVO_MAX     : integer := 100_000;      -- 2.0 ms maximum
        SERVO_CENTER  : integer := 75_000;       -- 1.5 ms center
        UPDATE_DIVIDER: integer := 100_000       -- Rate-limit divider
    );
    port (
        clk           : in  std_logic;                          -- 50 MHz
        rst_n         : in  std_logic;                          -- Active-low reset
        buttons       : in  std_logic_vector(7 downto 0);       -- Debounced, active-low
        servo1_pulse  : out std_logic_vector(19 downto 0);      -- Servo 1 pulse width
        servo2_pulse  : out std_logic_vector(19 downto 0);      -- Servo 2 pulse width
        servo3_pulse  : out std_logic_vector(19 downto 0);      -- Servo 3 pulse width
        servo4_pulse  : out std_logic_vector(19 downto 0);      -- Servo 4 pulse width
        servo_active  : out std_logic_vector(3 downto 0)        -- Active indicators
    );
end servo_controller;

architecture rtl of servo_controller is

    -- ====================================================================
    -- State Machine Type
    -- ====================================================================
    type state_type is (
        IDLE,
        SERVO1_CW, SERVO1_CCW,
        SERVO2_CW, SERVO2_CCW,
        SERVO3_CW, SERVO3_CCW,
        SERVO4_CW, SERVO4_CCW,
        HOME,
        EMERGENCY_STOP
    );
    signal current_state, next_state : state_type;

    -- ====================================================================
    -- Servo Pulse-Width Registers
    -- ====================================================================
    signal s1_pulse : unsigned(19 downto 0);
    signal s2_pulse : unsigned(19 downto 0);
    signal s3_pulse : unsigned(19 downto 0);
    signal s4_pulse : unsigned(19 downto 0);

    -- ====================================================================
    -- Rate-Limit Counter
    -- ====================================================================
    signal update_counter : integer range 0 to UPDATE_DIVIDER;
    signal allow_update   : std_logic;

    -- ====================================================================
    -- Edge Detection for CW/CCW Toggle
    -- ====================================================================
    -- Previous button samples (active-low, so falling edge = press)
    signal btn_prev : std_logic_vector(3 downto 0);
    -- Toggle registers: '0' = CW mode, '1' = CCW mode
    signal dir_toggle : std_logic_vector(3 downto 0);

    -- ====================================================================
    -- Active Indicator Register
    -- ====================================================================
    signal active_reg : std_logic_vector(3 downto 0);

begin

    -- ====================================================================
    -- Rate-Limit Divider
    -- Generates a single-cycle allow_update pulse every UPDATE_DIVIDER
    -- clock cycles (~2 ms at 50 MHz with divider = 100,000).
    -- ====================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            update_counter <= 0;
            allow_update   <= '0';
        elsif rising_edge(clk) then
            if update_counter = UPDATE_DIVIDER then
                allow_update   <= '1';
                update_counter <= 0;
            else
                allow_update   <= '0';
                update_counter <= update_counter + 1;
            end if;
        end if;
    end process;

    -- ====================================================================
    -- Button Edge Detection & Direction Toggle
    -- On each falling edge of buttons(0..3) (active-low press), the
    -- corresponding direction toggle flips between CW ('0') and CCW ('1').
    -- ====================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            btn_prev   <= (others => '1');   -- unpressed default
            dir_toggle <= (others => '0');   -- start in CW mode
        elsif rising_edge(clk) then
            btn_prev <= buttons(3 downto 0);

            for i in 0 to 3 loop
                -- Falling edge detection: was '1' (released), now '0' (pressed)
                if btn_prev(i) = '1' and buttons(i) = '0' then
                    dir_toggle(i) <= not dir_toggle(i);
                end if;
            end loop;
        end if;
    end process;

    -- ====================================================================
    -- Next-State Logic (combinational)
    -- ====================================================================
    process(current_state, buttons, allow_update, dir_toggle)
    begin
        next_state <= current_state;  -- default hold

        if allow_update = '1' then
            case current_state is

                when IDLE =>
                    -- Emergency stop has highest priority
                    if buttons(5) = '0' then
                        next_state <= EMERGENCY_STOP;
                    elsif buttons(6) = '0' then
                        next_state <= HOME;
                    elsif buttons(0) = '0' then
                        if dir_toggle(0) = '0' then
                            next_state <= SERVO1_CW;
                        else
                            next_state <= SERVO1_CCW;
                        end if;
                    elsif buttons(1) = '0' then
                        if dir_toggle(1) = '0' then
                            next_state <= SERVO2_CW;
                        else
                            next_state <= SERVO2_CCW;
                        end if;
                    elsif buttons(2) = '0' then
                        if dir_toggle(2) = '0' then
                            next_state <= SERVO3_CW;
                        else
                            next_state <= SERVO3_CCW;
                        end if;
                    elsif buttons(3) = '0' then
                        if dir_toggle(3) = '0' then
                            next_state <= SERVO4_CW;
                        else
                            next_state <= SERVO4_CCW;
                        end if;
                    end if;

                -- All action states return to IDLE after one update tick
                when SERVO1_CW  => next_state <= IDLE;
                when SERVO1_CCW => next_state <= IDLE;
                when SERVO2_CW  => next_state <= IDLE;
                when SERVO2_CCW => next_state <= IDLE;
                when SERVO3_CW  => next_state <= IDLE;
                when SERVO3_CCW => next_state <= IDLE;
                when SERVO4_CW  => next_state <= IDLE;
                when SERVO4_CCW => next_state <= IDLE;
                when HOME           => next_state <= IDLE;
                when EMERGENCY_STOP => next_state <= IDLE;

                when others =>
                    next_state <= IDLE;

            end case;
        end if;
    end process;

    -- ====================================================================
    -- State Register
    -- ====================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- ====================================================================
    -- Servo Position Update (registered output)
    -- Increments / decrements pulse widths by SERVO_STEP, clamped to
    -- [SERVO_MIN .. SERVO_MAX].
    -- ====================================================================
    process(clk, rst_n)
        variable tmp : integer;
    begin
        if rst_n = '0' then
            s1_pulse   <= to_unsigned(SERVO_CENTER, 20);
            s2_pulse   <= to_unsigned(SERVO_CENTER, 20);
            s3_pulse   <= to_unsigned(SERVO_CENTER, 20);
            s4_pulse   <= to_unsigned(SERVO_CENTER, 20);
            active_reg <= "0000";

        elsif rising_edge(clk) then

            case current_state is

                -- Servo 1 CW -------------------------------------------------
                when SERVO1_CW =>
                    tmp := to_integer(s1_pulse) + SERVO_STEP;
                    if tmp <= SERVO_MAX then
                        s1_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "0001";

                -- Servo 1 CCW ------------------------------------------------
                when SERVO1_CCW =>
                    tmp := to_integer(s1_pulse) - SERVO_STEP;
                    if tmp >= SERVO_MIN then
                        s1_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "0001";

                -- Servo 2 CW -------------------------------------------------
                when SERVO2_CW =>
                    tmp := to_integer(s2_pulse) + SERVO_STEP;
                    if tmp <= SERVO_MAX then
                        s2_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "0010";

                -- Servo 2 CCW ------------------------------------------------
                when SERVO2_CCW =>
                    tmp := to_integer(s2_pulse) - SERVO_STEP;
                    if tmp >= SERVO_MIN then
                        s2_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "0010";

                -- Servo 3 CW -------------------------------------------------
                when SERVO3_CW =>
                    tmp := to_integer(s3_pulse) + SERVO_STEP;
                    if tmp <= SERVO_MAX then
                        s3_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "0100";

                -- Servo 3 CCW ------------------------------------------------
                when SERVO3_CCW =>
                    tmp := to_integer(s3_pulse) - SERVO_STEP;
                    if tmp >= SERVO_MIN then
                        s3_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "0100";

                -- Servo 4 CW -------------------------------------------------
                when SERVO4_CW =>
                    tmp := to_integer(s4_pulse) + SERVO_STEP;
                    if tmp <= SERVO_MAX then
                        s4_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "1000";

                -- Servo 4 CCW ------------------------------------------------
                when SERVO4_CCW =>
                    tmp := to_integer(s4_pulse) - SERVO_STEP;
                    if tmp >= SERVO_MIN then
                        s4_pulse <= to_unsigned(tmp, 20);
                    end if;
                    active_reg <= "1000";

                -- Home --------------------------------------------------------
                when HOME =>
                    s1_pulse   <= to_unsigned(SERVO_CENTER, 20);
                    s2_pulse   <= to_unsigned(SERVO_CENTER, 20);
                    s3_pulse   <= to_unsigned(SERVO_CENTER, 20);
                    s4_pulse   <= to_unsigned(SERVO_CENTER, 20);
                    active_reg <= "1111";

                -- Emergency Stop ----------------------------------------------
                when EMERGENCY_STOP =>
                    active_reg <= "0000";

                -- IDLE / others -----------------------------------------------
                when others =>
                    active_reg <= "0000";

            end case;
        end if;
    end process;

    -- ====================================================================
    -- Output Assignments
    -- ====================================================================
    servo1_pulse <= std_logic_vector(s1_pulse);
    servo2_pulse <= std_logic_vector(s2_pulse);
    servo3_pulse <= std_logic_vector(s3_pulse);
    servo4_pulse <= std_logic_vector(s4_pulse);
    servo_active <= active_reg;

end architecture rtl;
