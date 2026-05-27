-------------------------------------------------------------------------------
-- File       : pwm_generator_tb.vhd
-- Project    : 4DOF FPGA Robotic Arm
-- Description: Testbench for the PWM generator module.
--              Uses scaled-down generics for fast simulation:
--                PERIOD_CNTS = 1000, PULSE_MIN = 50, PULSE_MAX = 100,
--                center = 75.  Clock period = 10 ns (100 MHz).
--
-- Test cases:
--   1. Reset test        – pwm_out = '0' while rst_n is asserted low
--   2. Center pulse test – pulse_width = 75, HIGH time ≈ 75 clocks
--   3. Min pulse test    – pulse_width = 50, HIGH time ≈ 50 clocks
--   4. Max pulse test    – pulse_width = 100, HIGH time ≈ 100 clocks
--   5. Clamping test     – out-of-range value clamped to PULSE_MAX
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_generator_tb is
end entity pwm_generator_tb;

architecture sim of pwm_generator_tb is

    ---------------------------------------------------------------------------
    -- Scaled-down constants for fast simulation
    ---------------------------------------------------------------------------
    constant CLK_PERIOD   : time    := 10 ns;   -- 100 MHz sim clock
    constant PERIOD_CNTS  : integer := 1000;
    constant PULSE_MIN    : integer := 50;
    constant PULSE_MAX    : integer := 100;
    constant PULSE_CENTER : integer := 75;

    ---------------------------------------------------------------------------
    -- DUT signals
    ---------------------------------------------------------------------------
    signal clk         : std_logic := '0';
    signal rst_n       : std_logic := '0';
    signal pulse_width : std_logic_vector(19 downto 0) := (others => '0');
    signal pwm_out     : std_logic;

    ---------------------------------------------------------------------------
    -- Simulation control
    ---------------------------------------------------------------------------
    signal sim_done : boolean := false;

    ---------------------------------------------------------------------------
    -- Helper: count the number of clock cycles pwm_out is HIGH during one
    --         full PWM period (PERIOD_CNTS clock cycles).
    ---------------------------------------------------------------------------
    procedure measure_high_time (
        signal   clk_i      : in  std_logic;
        signal   pwm_i      : in  std_logic;
        constant period      : in  integer;
        variable high_count  : out integer
    ) is
    begin
        high_count := 0;
        for i in 0 to period - 1 loop
            wait until rising_edge(clk_i);
            if pwm_i = '1' then
                high_count := high_count + 1;
            end if;
        end loop;
    end procedure measure_high_time;

begin

    ---------------------------------------------------------------------------
    -- Clock generation – stops when sim_done is asserted
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

    ---------------------------------------------------------------------------
    -- DUT instantiation
    ---------------------------------------------------------------------------
    uut : entity work.pwm_generator
        generic map (
            CLK_FREQ    => 100_000_000,   -- not directly used in PWM counter
            PWM_FREQ    => 50,            -- not directly used when PERIOD_CNTS overrides
            PULSE_MIN   => PULSE_MIN,
            PULSE_MAX   => PULSE_MAX,
            PERIOD_CNTS => PERIOD_CNTS
        )
        port map (
            clk         => clk,
            rst_n       => rst_n,
            pulse_width => pulse_width,
            pwm_out     => pwm_out
        );

    ---------------------------------------------------------------------------
    -- Stimulus process
    ---------------------------------------------------------------------------
    stim_proc : process
        variable high_cnt : integer := 0;
        variable tolerance : integer := 2;   -- allow ±2 clocks for pipeline delay
    begin
        -----------------------------------------------------------------------
        -- TEST 1 : Reset test
        -----------------------------------------------------------------------
        report "TEST 1: Reset test – pwm_out should be '0' during reset";
        rst_n <= '0';
        pulse_width <= std_logic_vector(to_unsigned(PULSE_CENTER, 20));
        wait for CLK_PERIOD * 10;

        assert pwm_out = '0'
            report "FAIL: pwm_out is not '0' during reset"
            severity error;

        report "TEST 1 PASSED";

        -- Release reset
        wait until rising_edge(clk);
        rst_n <= '1';
        wait until rising_edge(clk);

        -----------------------------------------------------------------------
        -- TEST 2 : Center pulse test (pulse_width = 75)
        -----------------------------------------------------------------------
        report "TEST 2: Center pulse test – pulse_width = 75";
        pulse_width <= std_logic_vector(to_unsigned(PULSE_CENTER, 20));

        -- Skip one period to let the counter synchronise after reset
        for i in 0 to PERIOD_CNTS - 1 loop
            wait until rising_edge(clk);
        end loop;

        -- Measure over the next full period
        measure_high_time(clk, pwm_out, PERIOD_CNTS, high_cnt);

        report "  Measured HIGH cycles = " & integer'image(high_cnt)
             & ", expected ≈ " & integer'image(PULSE_CENTER);

        assert (high_cnt >= PULSE_CENTER - tolerance) and
               (high_cnt <= PULSE_CENTER + tolerance)
            report "FAIL: Center pulse HIGH time out of tolerance"
            severity error;

        report "TEST 2 PASSED";

        -----------------------------------------------------------------------
        -- TEST 3 : Min pulse test (pulse_width = 50)
        -----------------------------------------------------------------------
        report "TEST 3: Min pulse test – pulse_width = 50";
        pulse_width <= std_logic_vector(to_unsigned(PULSE_MIN, 20));

        -- Wait one full period for the new value to take effect
        for i in 0 to PERIOD_CNTS - 1 loop
            wait until rising_edge(clk);
        end loop;

        measure_high_time(clk, pwm_out, PERIOD_CNTS, high_cnt);

        report "  Measured HIGH cycles = " & integer'image(high_cnt)
             & ", expected ≈ " & integer'image(PULSE_MIN);

        assert (high_cnt >= PULSE_MIN - tolerance) and
               (high_cnt <= PULSE_MIN + tolerance)
            report "FAIL: Min pulse HIGH time out of tolerance"
            severity error;

        report "TEST 3 PASSED";

        -----------------------------------------------------------------------
        -- TEST 4 : Max pulse test (pulse_width = 100)
        -----------------------------------------------------------------------
        report "TEST 4: Max pulse test – pulse_width = 100";
        pulse_width <= std_logic_vector(to_unsigned(PULSE_MAX, 20));

        for i in 0 to PERIOD_CNTS - 1 loop
            wait until rising_edge(clk);
        end loop;

        measure_high_time(clk, pwm_out, PERIOD_CNTS, high_cnt);

        report "  Measured HIGH cycles = " & integer'image(high_cnt)
             & ", expected ≈ " & integer'image(PULSE_MAX);

        assert (high_cnt >= PULSE_MAX - tolerance) and
               (high_cnt <= PULSE_MAX + tolerance)
            report "FAIL: Max pulse HIGH time out of tolerance"
            severity error;

        report "TEST 4 PASSED";

        -----------------------------------------------------------------------
        -- TEST 5 : Clamping test – value above PULSE_MAX
        -----------------------------------------------------------------------
        report "TEST 5: Clamping test – pulse_width = 200 (should clamp to 100)";
        pulse_width <= std_logic_vector(to_unsigned(200, 20));

        for i in 0 to PERIOD_CNTS - 1 loop
            wait until rising_edge(clk);
        end loop;

        measure_high_time(clk, pwm_out, PERIOD_CNTS, high_cnt);

        report "  Measured HIGH cycles = " & integer'image(high_cnt)
             & ", expected ≈ " & integer'image(PULSE_MAX) & " (clamped)";

        assert (high_cnt >= PULSE_MAX - tolerance) and
               (high_cnt <= PULSE_MAX + tolerance)
            report "FAIL: Clamped pulse HIGH time out of tolerance"
            severity error;

        report "TEST 5 PASSED";

        -----------------------------------------------------------------------
        -- All tests complete
        -----------------------------------------------------------------------
        report "============================================";
        report "ALL PWM_GENERATOR TESTS PASSED";
        report "============================================";

        sim_done <= true;
        wait;
    end process stim_proc;

end architecture sim;
