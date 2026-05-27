-- ============================================================================
-- Button Debouncer Testbench
-- File: button_test.vhd
--
-- Description:
--   Focused testbench for the debouncer module, verifying that electrical
--   noise from mechanical buttons is correctly filtered.  Instantiates 8
--   debouncer instances with a very small DEBOUNCE_TIME (50 clocks) so that
--   simulation completes quickly.
--
-- Test Plan:
--   1. Default state    – all 8 outputs idle at '1' (active-low, unpressed)
--   2. Single press     – each button 0-7 pressed then released individually
--   3. Simultaneous     – buttons 0 and 1 pressed at the same time
--   4. Rapid bounce     – fast toggling on button 0 (simulated contact bounce)
--   5. Sustained hold   – button 0 held low for an extended period
--
-- Clock:       10 ns period (100 MHz sim clock; irrelevant to debounce count)
-- Reset:       Active-low, asserted for 100 ns at start
-- Pass/Fail:   Report statements at each checkpoint
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_test is
    -- Testbench – no ports
end button_test;

architecture tb of button_test is

    -- -----------------------------------------------------------------------
    -- Constants
    -- -----------------------------------------------------------------------
    constant CLK_PERIOD    : time    := 10 ns;
    constant DEBOUNCE_TIME : integer := 50;   -- very short for fast sim
    constant CLK_FREQ      : integer := 50_000_000;

    -- -----------------------------------------------------------------------
    -- DUT component declaration
    -- -----------------------------------------------------------------------
    component debouncer is
        generic (
            CLK_FREQ      : integer;
            DEBOUNCE_TIME : integer
        );
        port (
            clk              : in  std_logic;
            rst_n            : in  std_logic;
            button_in        : in  std_logic;
            button_debounced : out std_logic
        );
    end component;

    -- -----------------------------------------------------------------------
    -- Testbench signals
    -- -----------------------------------------------------------------------
    signal clk   : std_logic := '0';
    signal rst_n : std_logic := '0';

    signal raw_buttons       : std_logic_vector(7 downto 0) := (others => '1');
    signal debounced_buttons : std_logic_vector(7 downto 0);

    signal sim_done : boolean := false;  -- stops the clock

begin

    -- -----------------------------------------------------------------------
    -- Clock generation (stops when sim_done = true)
    -- -----------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- -----------------------------------------------------------------------
    -- DUT instantiation – 8 debouncers
    -- -----------------------------------------------------------------------
    gen_debouncers : for i in 0 to 7 generate
        deb_inst : debouncer
            generic map (
                CLK_FREQ      => CLK_FREQ,
                DEBOUNCE_TIME => DEBOUNCE_TIME
            )
            port map (
                clk              => clk,
                rst_n            => rst_n,
                button_in        => raw_buttons(i),
                button_debounced => debounced_buttons(i)
            );
    end generate;

    -- -----------------------------------------------------------------------
    -- Stimulus process
    -- -----------------------------------------------------------------------
    stim : process

        -- Helper: wait N clock cycles
        procedure wait_clks(n : in integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- Helper: press (drive low) a single button for a given number of clks
        procedure press_button(btn : in integer; hold_clks : in integer) is
        begin
            raw_buttons(btn) <= '0';
            wait_clks(hold_clks);
            raw_buttons(btn) <= '1';
        end procedure;

        variable pass_count : integer := 0;
        variable fail_count : integer := 0;

    begin
        -- ==================================================================
        -- Reset phase
        -- ==================================================================
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait_clks(5);

        -- ==================================================================
        -- TEST 1 – Default state: all buttons unpressed ('1')
        -- ==================================================================
        report "TEST 1: Default state check" severity note;
        if debounced_buttons = "11111111" then
            report "  PASS – all debounced outputs are '1'" severity note;
            pass_count := pass_count + 1;
        else
            report "  FAIL – expected 11111111, got " &
                   std_logic'image(debounced_buttons(7)) &
                   std_logic'image(debounced_buttons(6)) &
                   std_logic'image(debounced_buttons(5)) &
                   std_logic'image(debounced_buttons(4)) &
                   std_logic'image(debounced_buttons(3)) &
                   std_logic'image(debounced_buttons(2)) &
                   std_logic'image(debounced_buttons(1)) &
                   std_logic'image(debounced_buttons(0))
                   severity error;
            fail_count := fail_count + 1;
        end if;

        -- ==================================================================
        -- TEST 2 – Single button press/release for each button 0-7
        -- ==================================================================
        report "TEST 2: Individual button press/release" severity note;
        for btn in 0 to 7 loop
            -- Press button (hold longer than DEBOUNCE_TIME so it registers)
            raw_buttons(btn) <= '0';
            wait_clks(DEBOUNCE_TIME + 20);

            -- Check that debounced output went low
            if debounced_buttons(btn) = '0' then
                report "  PASS – button " & integer'image(btn) &
                       " debounced to '0'" severity note;
                pass_count := pass_count + 1;
            else
                report "  FAIL – button " & integer'image(btn) &
                       " did not debounce to '0'" severity error;
                fail_count := fail_count + 1;
            end if;

            -- Release button
            raw_buttons(btn) <= '1';
            wait_clks(DEBOUNCE_TIME + 20);

            -- Check that debounced output returned to '1'
            if debounced_buttons(btn) = '1' then
                report "  PASS – button " & integer'image(btn) &
                       " released to '1'" severity note;
                pass_count := pass_count + 1;
            else
                report "  FAIL – button " & integer'image(btn) &
                       " did not release to '1'" severity error;
                fail_count := fail_count + 1;
            end if;
        end loop;

        -- ==================================================================
        -- TEST 3 – Simultaneous press of buttons 0 and 1
        -- ==================================================================
        report "TEST 3: Simultaneous button press (0 and 1)" severity note;
        raw_buttons(0) <= '0';
        raw_buttons(1) <= '0';
        wait_clks(DEBOUNCE_TIME + 20);

        if debounced_buttons(0) = '0' and debounced_buttons(1) = '0' then
            report "  PASS – both buttons debounced to '0'" severity note;
            pass_count := pass_count + 1;
        else
            report "  FAIL – simultaneous press not detected" severity error;
            fail_count := fail_count + 1;
        end if;

        -- Verify other buttons remain unpressed
        if debounced_buttons(7 downto 2) = "111111" then
            report "  PASS – remaining buttons stayed '1'" severity note;
            pass_count := pass_count + 1;
        else
            report "  FAIL – spurious press on other buttons" severity error;
            fail_count := fail_count + 1;
        end if;

        -- Release both
        raw_buttons(0) <= '1';
        raw_buttons(1) <= '1';
        wait_clks(DEBOUNCE_TIME + 20);

        -- ==================================================================
        -- TEST 4 – Rapid press/release (bounce simulation) on button 0
        --   Toggle the raw input faster than the debounce window; the
        --   debounced output should remain stable at '1' (or at least not
        --   follow every glitch).
        -- ==================================================================
        report "TEST 4: Rapid bounce simulation on button 0" severity note;
        for i in 1 to 10 loop
            raw_buttons(0) <= '0';
            wait_clks(3);  -- much shorter than DEBOUNCE_TIME
            raw_buttons(0) <= '1';
            wait_clks(3);
        end loop;
        wait_clks(5);

        -- After bouncing, output should still be '1' (bounce rejected)
        if debounced_buttons(0) = '1' then
            report "  PASS – bounce was filtered, output remained '1'"
                   severity note;
            pass_count := pass_count + 1;
        else
            report "  FAIL – bounce was NOT filtered, output is '0'"
                   severity error;
            fail_count := fail_count + 1;
        end if;

        -- ==================================================================
        -- TEST 5 – Button held for extended period
        --   Press button 0 and hold it low for 5x the debounce window.
        --   Verify it stays '0' throughout and returns to '1' after release.
        -- ==================================================================
        report "TEST 5: Extended button hold on button 0" severity note;
        raw_buttons(0) <= '0';
        wait_clks(DEBOUNCE_TIME * 5);

        if debounced_buttons(0) = '0' then
            report "  PASS – button held low, debounced is '0'" severity note;
            pass_count := pass_count + 1;
        else
            report "  FAIL – button held low but debounced is '1'"
                   severity error;
            fail_count := fail_count + 1;
        end if;

        -- Release and verify recovery
        raw_buttons(0) <= '1';
        wait_clks(DEBOUNCE_TIME + 20);

        if debounced_buttons(0) = '1' then
            report "  PASS – button released, debounced returned to '1'"
                   severity note;
            pass_count := pass_count + 1;
        else
            report "  FAIL – button released but debounced still '0'"
                   severity error;
            fail_count := fail_count + 1;
        end if;

        -- ==================================================================
        -- Summary
        -- ==================================================================
        report "========================================" severity note;
        report "BUTTON TEST COMPLETE" severity note;
        report "  Passed: " & integer'image(pass_count) severity note;
        report "  Failed: " & integer'image(fail_count) severity note;
        report "========================================" severity note;

        if fail_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "SOME TESTS FAILED" severity error;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture tb;
