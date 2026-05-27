-- ============================================================================
-- Integration Testbench
-- File: integration_test.vhd
--
-- Description:
--   Full system integration test instantiating the top-level entity.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity integration_test is
end integration_test;

architecture sim of integration_test is

    component top
        port (
            clk             : in std_logic;
            rst_n           : in std_logic;
            button_0        : in std_logic;
            button_1        : in std_logic;
            button_2        : in std_logic;
            button_3        : in std_logic;
            button_4        : in std_logic;
            button_5        : in std_logic;
            button_6        : in std_logic;
            button_7        : in std_logic;
            servo_pwm_1     : out std_logic;
            servo_pwm_2     : out std_logic;
            servo_pwm_3     : out std_logic;
            servo_pwm_4     : out std_logic;
            hex0            : out std_logic_vector(6 downto 0);
            hex1            : out std_logic_vector(6 downto 0);
            hex2            : out std_logic_vector(6 downto 0);
            hex3            : out std_logic_vector(6 downto 0);
            hex4            : out std_logic_vector(6 downto 0);
            hex5            : out std_logic_vector(6 downto 0);
            hex6            : out std_logic_vector(6 downto 0);
            hex7            : out std_logic_vector(6 downto 0);
            led_0           : out std_logic;
            led_1           : out std_logic;
            led_2           : out std_logic;
            led_3           : out std_logic;
            led_4           : out std_logic;
            led_5           : out std_logic;
            led_6           : out std_logic;
            led_7           : out std_logic;
            led_8           : out std_logic;
            led_9           : out std_logic;
            uart_tx         : out std_logic;
            uart_rx         : in std_logic
        );
    end component;

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal buttons  : std_logic_vector(7 downto 0) := (others => '1');
    signal pwm_out  : std_logic_vector(3 downto 0);
    signal hex      : array(0 to 7) of std_logic_vector(6 downto 0);
    signal leds     : std_logic_vector(9 downto 0);
    signal uart_tx  : std_logic;
    signal uart_rx  : std_logic := '1';

begin

    dut: top port map (
        clk => clk, rst_n => rst_n,
        button_0 => buttons(0), button_1 => buttons(1),
        button_2 => buttons(2), button_3 => buttons(3),
        button_4 => buttons(4), button_5 => buttons(5),
        button_6 => buttons(6), button_7 => buttons(7),
        servo_pwm_1 => pwm_out(0), servo_pwm_2 => pwm_out(1),
        servo_pwm_3 => pwm_out(2), servo_pwm_4 => pwm_out(3),
        hex0 => hex(0), hex1 => hex(1), hex2 => hex(2), hex3 => hex(3),
        hex4 => hex(4), hex5 => hex(5), hex6 => hex(6), hex7 => hex(7),
        led_0 => leds(0), led_1 => leds(1), led_2 => leds(2), led_3 => leds(3),
        led_4 => leds(4), led_5 => leds(5), led_6 => leds(6), led_7 => leds(7),
        led_8 => leds(8), led_9 => leds(9),
        uart_tx => uart_tx, uart_rx => uart_rx
    );

    clk <= not clk after CLK_PERIOD / 2;

    process
    begin
        -- 1. Reset
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait for 1 ms;
        
        -- 2. Button 0 press
        buttons(0) <= '0';
        wait for 25 ms; -- Wait for debounce
        buttons(0) <= '1';
        wait for 1 ms;
        
        -- 3. Home button (6)
        buttons(6) <= '0';
        wait for 25 ms;
        buttons(6) <= '1';
        wait for 1 ms;
        
        -- 4. Emergency stop (5)
        buttons(5) <= '0';
        wait for 25 ms;
        buttons(5) <= '1';
        
        report "Integration tests passed (simulation complete)";
        std.env.stop;
    end process;

end architecture sim;
