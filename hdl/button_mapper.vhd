-- ============================================================================
-- Button Mapper Module
-- File: button_mapper.vhd
--
-- Description:
--   Maps raw debounced button inputs to servo control commands.
--   Implements edge detection for toggle-based CW/CCW direction control.
--   Provides mode selection, emergency stop, and home position commands.
--
-- Button Assignments:
--   Button 0: Servo 1 enable (toggle CW/CCW on each press)
--   Button 1: Servo 2 enable (toggle CW/CCW on each press)
--   Button 2: Servo 3 enable (toggle CW/CCW on each press)
--   Button 3: Servo 4 enable (toggle CW/CCW on each press)
--   Button 4: Mode select (manual/auto toggle)
--   Button 5: Emergency stop
--   Button 6: Home position command
--   Button 7: Reserved (record/playback)
--
-- Port Description:
--   clk             : Input clock (50 MHz)
--   rst_n           : Active-low reset
--   buttons         : 8-bit debounced button inputs (active-low)
--   servo_direction : 4-bit direction output (1=CW, 0=CCW per servo)
--   servo_enable    : 4-bit enable output (1=servo active)
--   mode            : Mode output (0=manual, 1=auto)
--   e_stop          : Emergency stop pulse (active-high, one clock)
--   home_cmd        : Home position command pulse (active-high, one clock)
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_mapper is
    generic (
        CLK_FREQ : integer := 50_000_000  -- 50 MHz
    );
    port (
        clk             : in  std_logic;
        rst_n           : in  std_logic;
        buttons         : in  std_logic_vector(7 downto 0);  -- Active-low
        servo_direction : out std_logic_vector(3 downto 0);   -- 1=CW, 0=CCW
        servo_enable    : out std_logic_vector(3 downto 0);   -- 1=active
        mode            : out std_logic;                       -- 0=manual, 1=auto
        e_stop          : out std_logic;                       -- Emergency stop pulse
        home_cmd        : out std_logic                        -- Home command pulse
    );
end button_mapper;

architecture rtl of button_mapper is

    -- Synchronization flip-flops (2-stage for CDC)
    signal buttons_sync1 : std_logic_vector(7 downto 0);
    signal buttons_sync2 : std_logic_vector(7 downto 0);
    
    -- Previous button state for edge detection
    signal buttons_prev  : std_logic_vector(7 downto 0);
    
    -- Falling edge detection (button press on active-low)
    signal buttons_fall  : std_logic_vector(7 downto 0);
    
    -- Direction toggle registers (1=CW, 0=CCW)
    signal direction_reg : std_logic_vector(3 downto 0);
    
    -- Enable registers
    signal enable_reg    : std_logic_vector(3 downto 0);
    
    -- Mode register
    signal mode_reg      : std_logic;
    
begin

    -- ========================================================================
    -- Input Synchronization (2-stage flip-flop for metastability)
    -- ========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            buttons_sync1 <= (others => '1');  -- Active-low: '1' = not pressed
            buttons_sync2 <= (others => '1');
            buttons_prev  <= (others => '1');
        elsif rising_edge(clk) then
            buttons_sync1 <= buttons;
            buttons_sync2 <= buttons_sync1;
            buttons_prev  <= buttons_sync2;
        end if;
    end process;

    -- ========================================================================
    -- Falling Edge Detection (active-low buttons: press = 1->0 transition)
    -- ========================================================================
    gen_edge: for i in 0 to 7 generate
        buttons_fall(i) <= buttons_prev(i) and (not buttons_sync2(i));
    end generate gen_edge;

    -- ========================================================================
    -- Direction Toggle Logic (Buttons 0-3)
    -- Each press toggles CW <-> CCW for the corresponding servo
    -- ========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            direction_reg <= "1111";  -- Default: CW for all servos
        elsif rising_edge(clk) then
            for i in 0 to 3 loop
                if buttons_fall(i) = '1' then
                    direction_reg(i) <= not direction_reg(i);
                end if;
            end loop;
        end if;
    end process;

    -- ========================================================================
    -- Servo Enable Logic (Buttons 0-3)
    -- Servo is enabled while its corresponding button is held down
    -- ========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            enable_reg <= "0000";
        elsif rising_edge(clk) then
            for i in 0 to 3 loop
                enable_reg(i) <= not buttons_sync2(i);  -- Active when pressed (low)
            end loop;
        end if;
    end process;

    -- ========================================================================
    -- Mode Toggle (Button 4)
    -- Each press toggles between manual and auto mode
    -- ========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            mode_reg <= '0';  -- Default: manual mode
        elsif rising_edge(clk) then
            if buttons_fall(4) = '1' then
                mode_reg <= not mode_reg;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Emergency Stop (Button 5) - Single-cycle pulse on press
    -- ========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            e_stop <= '0';
        elsif rising_edge(clk) then
            if buttons_fall(5) = '1' then
                e_stop <= '1';
            else
                e_stop <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Home Command (Button 6) - Single-cycle pulse on press
    -- ========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            home_cmd <= '0';
        elsif rising_edge(clk) then
            if buttons_fall(6) = '1' then
                home_cmd <= '1';
            else
                home_cmd <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Output Assignments
    -- ========================================================================
    servo_direction <= direction_reg;
    servo_enable    <= enable_reg;
    mode            <= mode_reg;

end architecture rtl;
