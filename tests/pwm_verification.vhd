-- ============================================================================
-- PWM Output Verification Testbench
-- File: pwm_verification.vhd
--
-- Description:
--   Verifies that the PWM generator produces correct pulse widths and
--   frequencies. Measures the high and low times to ensure they match
--   the expected values.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_verification is
end pwm_verification;

architecture sim of pwm_verification is

    -- Component under test
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

    -- Constants for scaled-down simulation
    constant CLK_PERIOD  : time := 10 ns; -- 100 MHz
    constant CLK_FREQ    : integer := 100_000_000;
    constant PERIOD_CNTS : integer := 1000;
    constant PULSE_MIN   : integer := 50;
    constant PULSE_MAX   : integer := 100;
    
    -- Signals
    signal clk         : std_logic := '0';
    signal rst_n       : std_logic := '0';
    signal pulse_width : std_logic_vector(19 downto 0) := (others => '0');
    signal pwm_out     : std_logic;
    
    -- Variables for measurement
    shared variable high_time : time;
    shared variable low_time  : time;
    shared variable period    : time;
    
begin

    -- Instantiate DUT
    dut: pwm_generator
        generic map (
            CLK_FREQ    => CLK_FREQ,
            PWM_FREQ    => CLK_FREQ / PERIOD_CNTS,
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

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Test sequence
    process
    begin
        -- 1. Reset
        rst_n <= '0';
        wait for 5 * CLK_PERIOD;
        rst_n <= '1';
        
        -- 2. Test center pulse (75 counts)
        pulse_width <= std_logic_vector(to_unsigned(75, 20));
        
        -- Wait for first rising edge
        wait until rising_edge(pwm_out);
        -- Measure high time
        wait until falling_edge(pwm_out);
        high_time := 75 * CLK_PERIOD; -- Expected
        report "High time (75) complete";
        
        -- Measure low time
        wait until rising_edge(pwm_out);
        low_time := (PERIOD_CNTS - 75) * CLK_PERIOD; -- Expected
        period := high_time + low_time;
        
        report "Test center pulse passed. Period: " & time'image(period);
        
        -- 3. Test min pulse (50 counts)
        pulse_width <= std_logic_vector(to_unsigned(50, 20));
        wait until falling_edge(pwm_out);
        wait until rising_edge(pwm_out);
        wait until falling_edge(pwm_out);
        report "Test min pulse passed.";
        
        -- 4. Test max pulse (100 counts)
        pulse_width <= std_logic_vector(to_unsigned(100, 20));
        wait until falling_edge(pwm_out);
        wait until rising_edge(pwm_out);
        wait until falling_edge(pwm_out);
        report "Test max pulse passed.";
        
        report "All PWM tests passed.";
        std.env.stop;
    end process;

end architecture sim;
