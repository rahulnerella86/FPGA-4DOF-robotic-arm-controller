-------------------------------------------------------------------------------
-- File       : debouncer_tb.vhd
-- Project    : 4DOF FPGA Robotic Arm
-- Description: Testbench for the button debouncer module.
--              Uses DEBOUNCE_TIME = 100 clock cycles for fast simulation.
--              Clock period = 10 ns (100 MHz equivalent).
--              Buttons are active-low: '1' = released, '0' = pressed.
--
-- Test cases:
--   1. Reset test   – button_debounced = '1' (released) during reset
--   2. Clean press  – button held low, output goes low after debounce time
--   3. Bouncy press – button bounces within window, output stays high
--                     until input is stable for the full debounce time
--   4. Clean release– button goes high, output returns high after debounce
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer_tb is
end entity debouncer_tb;

architecture sim of debouncer_tb is

    ---------------------------------------------------------------------------
    -- Constants
    ---------------------------------------------------------------------------
    constant CLK_PERIOD    : time    := 10 ns;
    constant CLK_FREQ      : integer := 50_000_000;
    constant DEBOUNCE_TIME : integer := 100;  -- 100 clock cycles for fast sim

    ---------------------------------------------------------------------------
    -- DUT signals
    ---------------------------------------------------------------------------
    signal clk              : std_logic := '0';
    signal rst_n            : std_logic := '0';
    signal button_in        : std_logic := '1';   -- idle = released (high)
    signal button_debounced : std_logic;

    ---------------------------------------------------------------------------
    -- Simulation control
    ---------------------------------------------------------------------------
    signal sim_done : boolean := false;

begin

    ---------------------------------------------------------------------------
    -- Clock generation
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

    ---------------------------------------------------------------------------
    -- DUT instantiation
    ---------------------------------------------------------------------------
    uut : entity work.debouncer
        generic map (
            CLK_FREQ      => CLK_FREQ,
            DEBOUNCE_TIME => DEBOUNCE_TIME
        )
        port map (
            clk              => clk,
            rst_n            => rst_n,
            button_in        => button_in,
            button_debounced => button_debounced
        );

    ---------------------------------------------------------------------------
    -- Stimulus process
    ---------------------------------------------------------------------------
    stim_proc : process
    begin
        -----------------------------------------------------------------------
        -- TEST 1 : Reset test
        -----------------------------------------------------------------------
        report "TEST 1: Reset test – button_debounced should be '1' during reset";
        rst_n     <= '0';
        button_in <= '1';       -- released
        wait for CLK_PERIOD * 5;

        assert button_debounced = '1'
            report "FAIL: button_debounced is not '1' during reset"
            severity error;

        report "TEST 1 PASSED";

        -- Release reset
        wait until rising_edge(clk);
        rst_n <= '1';
        wait until rising_edge(clk);

        -----------------------------------------------------------------------
        -- TEST 2 : Clean press
        --   Button goes low and stays low.  After DEBOUNCE_TIME cycles the
        --   debounced output should transition low.
        -----------------------------------------------------------------------
        report "TEST 2: Clean press – button held low for > debounce time";
        button_in <= '0';   -- press

        -- Wait half the debounce time – output should still be '1'
        for i in 0 to (DEBOUNCE_TIME / 2) - 1 loop
            wait until rising_edge(clk);
        end loop;

        assert button_debounced = '1'
            report "FAIL: button_debounced went low too early (clean press)"
            severity error;

        -- Wait for the remainder of debounce time plus margin
        for i in 0 to (DEBOUNCE_TIME / 2) + 10 loop
            wait until rising_edge(clk);
        end loop;

        assert button_debounced = '0'
            report "FAIL: button_debounced did not go low after debounce time"
            severity error;

        report "TEST 2 PASSED";

        -----------------------------------------------------------------------
        -- TEST 3 : Bouncy press
        --   Button bounces several times within the debounce window.
        --   Debounced output must remain '1' until the button is stable low
        --   for the full debounce period.
        -----------------------------------------------------------------------
        report "TEST 3: Bouncy press – multiple bounces within debounce window";

        -- Start from released state
        button_in <= '1';
        for i in 0 to DEBOUNCE_TIME + 20 loop
            wait until rising_edge(clk);
        end loop;

        -- Simulate bounce sequence: low-high-low-high-low  (each < debounce)
        -- Bounce 1
        button_in <= '0';
        wait for CLK_PERIOD * 10;
        button_in <= '1';
        wait for CLK_PERIOD * 5;

        -- Bounce 2
        button_in <= '0';
        wait for CLK_PERIOD * 8;
        button_in <= '1';
        wait for CLK_PERIOD * 3;

        -- Bounce 3
        button_in <= '0';
        wait for CLK_PERIOD * 12;
        button_in <= '1';
        wait for CLK_PERIOD * 4;

        -- During all bounces, output should still be high (released)
        assert button_debounced = '1'
            report "FAIL: button_debounced went low during bouncing"
            severity error;

        -- Now settle low for full debounce period
        button_in <= '0';
        for i in 0 to DEBOUNCE_TIME + 10 loop
            wait until rising_edge(clk);
        end loop;

        assert button_debounced = '0'
            report "FAIL: button_debounced did not go low after bouncy press settled"
            severity error;

        report "TEST 3 PASSED";

        -----------------------------------------------------------------------
        -- TEST 4 : Clean release
        --   Button goes high and stays high. After debounce time the
        --   debounced output should return high.
        -----------------------------------------------------------------------
        report "TEST 4: Clean release – button released, output returns high";

        -- Make sure we start in the pressed state
        button_in <= '0';
        for i in 0 to DEBOUNCE_TIME + 10 loop
            wait until rising_edge(clk);
        end loop;

        -- Verify pressed state
        assert button_debounced = '0'
            report "FAIL: button_debounced not low before release test"
            severity error;

        -- Release button
        button_in <= '1';

        -- Wait half the debounce time – output should still be '0'
        for i in 0 to (DEBOUNCE_TIME / 2) - 1 loop
            wait until rising_edge(clk);
        end loop;

        assert button_debounced = '0'
            report "FAIL: button_debounced went high too early (clean release)"
            severity error;

        -- Wait for the full debounce time plus margin
        for i in 0 to (DEBOUNCE_TIME / 2) + 10 loop
            wait until rising_edge(clk);
        end loop;

        assert button_debounced = '1'
            report "FAIL: button_debounced did not return high after release"
            severity error;

        report "TEST 4 PASSED";

        -----------------------------------------------------------------------
        -- All tests complete
        -----------------------------------------------------------------------
        report "============================================";
        report "ALL DEBOUNCER TESTS PASSED";
        report "============================================";

        sim_done <= true;
        wait;
    end process stim_proc;

end architecture sim;
