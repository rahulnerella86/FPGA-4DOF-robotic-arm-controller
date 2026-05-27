-- ============================================================================
-- PWM Generator Module
-- File: pwm_generator.vhd
-- 
-- Description:
--   Generates a 50 Hz PWM signal with configurable pulse width.
--   Used for controlling servo motors in the robotic arm.
--
-- Specifications:
--   - Frequency: 50 Hz (20 ms period)
--   - Pulse Width Range: 1.0 - 2.0 ms
--   - Input Clock: 50 MHz
--   - Resolution: ~5 μs per count
--
-- Port Description:
--   clk          : Input clock (50 MHz)
--   rst_n        : Active-low reset
--   pulse_width  : Desired pulse width (0-4000 counts, 5μs resolution)
--   pwm_out      : PWM output signal
--
-- Calculation:
--   Period = 20 ms at 50 MHz = 1,000,000 clock cycles
--   1 ms = 50,000 clock cycles
--   0.1 ms = 5,000 clock cycles
--   Resolution = 20 ns / count * 250 = ~5 μs per count
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_generator is
    generic (
        CLK_FREQ    : integer := 50_000_000;  -- 50 MHz
        PWM_FREQ    : integer := 50;           -- 50 Hz (standard servo)
        PULSE_MIN   : integer := 50_000;       -- 1.0 ms (50,000 cycles)
        PULSE_MAX   : integer := 100_000;      -- 2.0 ms (100,000 cycles)
        PERIOD_CNTS : integer := 1_000_000     -- 20 ms (1,000,000 cycles)
    );
    port (
        clk         : in std_logic;
        rst_n       : in std_logic;
        pulse_width : in std_logic_vector(19 downto 0);  -- 20-bit input
        pwm_out     : out std_logic
    );
end pwm_generator;

architecture rtl of pwm_generator is
    signal counter           : integer range 0 to PERIOD_CNTS - 1;
    signal pulse_width_int   : integer range PULSE_MIN to PULSE_MAX;
    signal pulse_width_valid : integer range PULSE_MIN to PULSE_MAX;
    
begin
    
    -- Convert input to integer and clamp to valid range
    process(pulse_width)
        variable temp : integer;
    begin
        temp := to_integer(unsigned(pulse_width));
        
        if temp < PULSE_MIN then
            pulse_width_valid <= PULSE_MIN;
        elsif temp > PULSE_MAX then
            pulse_width_valid <= PULSE_MAX;
        else
            pulse_width_valid <= temp;
        end if;
    end process;
    
    -- Main PWM generation process
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            counter <= 0;
            pulse_width_int <= 75_000;  -- Default to center (1.5 ms)
            pwm_out <= '0';
            
        elsif rising_edge(clk) then
            -- Update the cached pulse width value
            pulse_width_int <= pulse_width_valid;
            
            -- Increment counter for period timing
            if counter = PERIOD_CNTS - 1 then
                counter <= 0;
            else
                counter <= counter + 1;
            end if;
            
            -- Generate PWM: HIGH for pulse_width counts, LOW for remainder
            if counter < pulse_width_int then
                pwm_out <= '1';
            else
                pwm_out <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
