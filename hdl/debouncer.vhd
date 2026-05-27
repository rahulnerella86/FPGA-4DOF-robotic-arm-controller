-- ============================================================================
-- Button Debouncer Module
-- File: debouncer.vhd
--
-- Description:
--   Removes electrical noise from button inputs using a 20 ms debounce window.
--   Typical switch bounce duration: 5-20 ms
--   This module samples the button state at 50 MHz and holds stable output
--   only after stable reading for DEBOUNCE_TIME cycles.
--
-- Specifications:
--   - Debounce time: 20 ms (default)
--   - Clock frequency: 50 MHz
--   - Input voltage: 3.3V (FPGA I/O standard)
--   - Logic: Active-low (typical button configuration)
--
-- Port Description:
--   clk              : Input clock (50 MHz)
--   rst_n            : Active-low reset
--   button_in        : Raw button input (active-low)
--   button_debounced : Stable button output (active-low)
--
-- Timing:
--   - Input change → Maximum 20 ms delay until output changes
--   - Bounce rejection: Any glitch <20 ms is filtered out
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer is
    generic (
        CLK_FREQ       : integer := 50_000_000;  -- 50 MHz
        DEBOUNCE_TIME  : integer := 1_000_000    -- 20 ms debounce
    );
    port (
        clk              : in std_logic;
        rst_n            : in std_logic;
        button_in        : in std_logic;
        button_debounced : out std_logic
    );
end debouncer;

architecture rtl of debouncer is
    signal ff1              : std_logic;  -- First flip-flop (CDC)
    signal ff2              : std_logic;  -- Second flip-flop (CDC)
    signal debounce_counter : integer range 0 to DEBOUNCE_TIME - 1;
    signal output_reg       : std_logic;
    signal stable_counter   : integer range 0 to DEBOUNCE_TIME - 1;
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            ff1 <= '1';  -- Assuming active-low logic, '1' = not pressed
            ff2 <= '1';
            output_reg <= '1';
            debounce_counter <= 0;
            stable_counter <= 0;
            button_debounced <= '1';
            
        elsif rising_edge(clk) then
            -- Clock domain crossing (CDC) - synchronize asynchronous input
            ff1 <= button_in;
            ff2 <= ff1;
            
            -- Check if the button input is stable
            if ff2 /= output_reg then
                -- Input has changed, start debounce timer
                stable_counter <= 0;
                
                if stable_counter = DEBOUNCE_TIME - 1 then
                    -- Debounce time has elapsed with stable input
                    output_reg <= ff2;
                    button_debounced <= ff2;
                else
                    stable_counter <= stable_counter + 1;
                end if;
                
            else
                -- Input is stable
                stable_counter <= 0;
            end if;
        end if;
    end process;

end architecture rtl;
