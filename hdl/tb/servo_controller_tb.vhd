-------------------------------------------------------------------------------
-- File       : servo_controller_tb.vhd
-- Project    : 4DOF FPGA Robotic Arm
-- Description: System-level testbench for the servo_controller module.
--              Uses scaled-down generics for fast simulation:
--                SERVO_STEP = 25, SERVO_MIN = 500, SERVO_MAX = 1000,
--                SERVO_CENTER = 750, CLK_FREQ = 1000.
--              Clock period = 10 ns.
--              Buttons are active-low: '1' = released, '0' = pressed.
--
-- Button mapping (active-low):
--   buttons(0) – Servo 1 CW  (increase pulse)
--   buttons(1) – Servo 1 CCW (decrease pulse)
--   buttons(2) – Servo 2 CW
--   buttons(3) – Servo 2 CCW
--   buttons(4) – Servo 3 CW
--   buttons(5) – Emergency Stop
--   buttons(6) – Home (return all servos to centre)
--   buttons(7) – Servo 4 CW (or other function)
--
-- Test cases:
--   1. Reset test      – all servo pulses = SERVO_CENTER (750)
--   2. Button 0 press  – servo_1_pulse increases by SERVO_STEP
--   3. Home button (6) – all servos return to centre
--   4. Emergency stop (5) – servo_active = "0000"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity servo_controller_tb is
end entity servo_controller_tb;

architecture sim of servo_controller_tb is

    ---------------------------------------------------------------------------
    -- Scaled-down constants for fast simulation
    ---------------------------------------------------------------------------
    constant CLK_PERIOD   : time    := 10 ns;
    constant CLK_FREQ     : integer := 1000;
    constant SERVO_STEP   : integer := 25;
    constant SERVO_MIN    : integer := 500;
    constant SERVO_MAX    : integer := 1000;
    constant SERVO_CENTER : integer := 750;

    ---------------------------------------------------------------------------
    -- DUT signals
    ---------------------------------------------------------------------------
    signal clk           : std_logic := '0';
    signal rst_n         : std_logic := '0';
    signal buttons       : std_logic_vector(7 downto 0) := (others => '1'); -- all released
    signal servo_1_pulse : std_logic_vector(19 downto 0);
    signal servo_2_pulse : std_logic_vector(19 downto 0);
    signal servo_3_pulse : std_logic_vector(19 downto 0);
    signal servo_4_pulse : std_logic_vector(19 downto 0);
    signal servo_active  : std_logic_vector(3 downto 0);

    ---------------------------------------------------------------------------
    -- Simulation control
    ---------------------------------------------------------------------------
    signal sim_done : boolean := false;

    ---------------------------------------------------------------------------
    -- Helper: press a button (active-low) for a given number of clock cycles
    ---------------------------------------------------------------------------
    procedure press_button (
        signal   btn_vec : inout std_logic_vector(7 downto 0);
        constant idx     : in    integer;
        constant cycles  : in    integer;
        signal   clk_i   : in    std_logic
    ) is
    begin
        btn_vec(idx) <= '0';                          -- press
        for i in 0 to cycles - 1 loop
            wait until rising_edge(clk_i);
        end loop;
        btn_vec(idx) <= '1';                          -- release
        -- Small settling time after release
        for i in 0 to 9 loop
            wait until rising_edge(clk_i);
        end loop;
    end procedure press_button;

begin

    ---------------------------------------------------------------------------
    -- Clock generation
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

    ---------------------------------------------------------------------------
    -- DUT instantiation
    ---------------------------------------------------------------------------
    uut : entity work.servo_controller
        generic map (
            CLK_FREQ     => CLK_FREQ,
            SERVO_STEP   => SERVO_STEP,
            SERVO_MIN    => SERVO_MIN,
            SERVO_MAX    => SERVO_MAX,
            SERVO_CENTER => SERVO_CENTER
        )
        port map (
            clk           => clk,
            rst_n         => rst_n,
            buttons       => buttons,
            servo_1_pulse => servo_1_pulse,
            servo_2_pulse => servo_2_pulse,
            servo_3_pulse => servo_3_pulse,
            servo_4_pulse => servo_4_pulse,
            servo_active  => servo_active
        );

    ---------------------------------------------------------------------------
    -- Stimulus process
    ---------------------------------------------------------------------------
    stim_proc : process
        variable pulse_val : integer;
    begin
        -----------------------------------------------------------------------
        -- TEST 1 : Reset test – all servos at SERVO_CENTER
        -----------------------------------------------------------------------
        report "TEST 1: Reset test – all servo pulses should be SERVO_CENTER";
        rst_n   <= '0';
        buttons <= (others => '1');   -- all released
        wait for CLK_PERIOD * 10;

        assert unsigned(servo_1_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_1_pulse not at center after reset, got " &
                   integer'image(to_integer(unsigned(servo_1_pulse)))
            severity error;

        assert unsigned(servo_2_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_2_pulse not at center after reset"
            severity error;

        assert unsigned(servo_3_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_3_pulse not at center after reset"
            severity error;

        assert unsigned(servo_4_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_4_pulse not at center after reset"
            severity error;

        report "TEST 1 PASSED";

        -- Release reset
        wait until rising_edge(clk);
        rst_n <= '1';
        -- Allow a few clocks for the controller to initialize
        for i in 0 to 9 loop
            wait until rising_edge(clk);
        end loop;

        -----------------------------------------------------------------------
        -- TEST 2 : Button 0 press – servo 1 pulse increases
        -----------------------------------------------------------------------
        report "TEST 2: Button 0 press – servo_1_pulse should increase";

        -- Record current pulse value
        pulse_val := to_integer(unsigned(servo_1_pulse));
        report "  servo_1_pulse before press = " & integer'image(pulse_val);

        -- Press button 0 (active-low) for enough cycles
        press_button(buttons, 0, 50, clk);

        -- Allow time for the controller state machine to process
        for i in 0 to 20 loop
            wait until rising_edge(clk);
        end loop;

        report "  servo_1_pulse after press  = " &
               integer'image(to_integer(unsigned(servo_1_pulse)));

        assert to_integer(unsigned(servo_1_pulse)) > pulse_val
            report "FAIL: servo_1_pulse did not increase after button 0 press"
            severity error;

        report "TEST 2 PASSED";

        -----------------------------------------------------------------------
        -- TEST 3 : Home button (button 6) – all servos return to centre
        -----------------------------------------------------------------------
        report "TEST 3: Home button – all servos return to SERVO_CENTER";

        -- Press home button
        press_button(buttons, 6, 50, clk);

        -- Allow time for the controller to move all servos home
        for i in 0 to 50 loop
            wait until rising_edge(clk);
        end loop;

        assert unsigned(servo_1_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_1_pulse not at center after HOME, got " &
                   integer'image(to_integer(unsigned(servo_1_pulse)))
            severity error;

        assert unsigned(servo_2_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_2_pulse not at center after HOME"
            severity error;

        assert unsigned(servo_3_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_3_pulse not at center after HOME"
            severity error;

        assert unsigned(servo_4_pulse) = to_unsigned(SERVO_CENTER, 20)
            report "FAIL: servo_4_pulse not at center after HOME"
            severity error;

        report "TEST 3 PASSED";

        -----------------------------------------------------------------------
        -- TEST 4 : Emergency stop (button 5) – servo_active = "0000"
        -----------------------------------------------------------------------
        report "TEST 4: Emergency stop – servo_active should go to 0000";

        -- Press emergency stop button
        press_button(buttons, 5, 50, clk);

        -- Allow processing time
        for i in 0 to 20 loop
            wait until rising_edge(clk);
        end loop;

        assert servo_active = "0000"
            report "FAIL: servo_active is not 0000 after emergency stop, got " &
                   integer'image(to_integer(unsigned(servo_active)))
            severity error;

        report "TEST 4 PASSED";

        -----------------------------------------------------------------------
        -- All tests complete
        -----------------------------------------------------------------------
        report "============================================";
        report "ALL SERVO_CONTROLLER TESTS PASSED";
        report "============================================";

        sim_done <= true;
        wait;
    end process stim_proc;

end architecture sim;
