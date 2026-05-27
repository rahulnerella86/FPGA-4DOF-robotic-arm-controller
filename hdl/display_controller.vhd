-- ============================================================================
-- Display Controller Module
-- File: display_controller.vhd
--
-- Description:
--   Converts 4 servo pulse width values to angle displays on 8 seven-segment
--   displays. Each servo angle (0-180°) is shown on a pair of displays
--   (tens and ones digits).
--
-- Display Layout:
--   HEX7-HEX6: Servo 4 angle (tens, ones)
--   HEX5-HEX4: Servo 3 angle (tens, ones)
--   HEX3-HEX2: Servo 2 angle (tens, ones)
--   HEX1-HEX0: Servo 1 angle (tens, ones)
--
-- Angle Calculation:
--   angle = ((pulse_width - PULSE_MIN) * 180) / (PULSE_MAX - PULSE_MIN)
--   With defaults: angle = ((pw - 50000) * 180) / 50000
--
-- 7-Segment Encoding (active-low, accent on = '0'):
--   Segment order: (6 downto 0) = g, f, e, d, c, b, a
--   0="1000000", 1="1111001", 2="0100100", 3="0110000", 4="0011001"
--   5="0010010", 6="0000010", 7="1111000", 8="0000000", 9="0010000"
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_controller is
    generic (
        CLK_FREQ  : integer := 50_000_000;  -- 50 MHz
        PULSE_MIN : integer := 50_000;       -- 1.0 ms (minimum pulse width)
        PULSE_MAX : integer := 100_000       -- 2.0 ms (maximum pulse width)
    );
    port (
        clk             : in  std_logic;
        rst_n           : in  std_logic;
        servo_1_pulse   : in  std_logic_vector(19 downto 0);
        servo_2_pulse   : in  std_logic_vector(19 downto 0);
        servo_3_pulse   : in  std_logic_vector(19 downto 0);
        servo_4_pulse   : in  std_logic_vector(19 downto 0);
        hex0            : out std_logic_vector(6 downto 0);  -- Servo 1 ones
        hex1            : out std_logic_vector(6 downto 0);  -- Servo 1 tens
        hex2            : out std_logic_vector(6 downto 0);  -- Servo 2 ones
        hex3            : out std_logic_vector(6 downto 0);  -- Servo 2 tens
        hex4            : out std_logic_vector(6 downto 0);  -- Servo 3 ones
        hex5            : out std_logic_vector(6 downto 0);  -- Servo 3 tens
        hex6            : out std_logic_vector(6 downto 0);  -- Servo 4 ones
        hex7            : out std_logic_vector(6 downto 0)   -- Servo 4 tens
    );
end display_controller;

architecture rtl of display_controller is

    -- Pulse range constant
    constant PULSE_RANGE : integer := PULSE_MAX - PULSE_MIN;  -- 50,000

    -- Angle values for each servo (0-180)
    signal angle_1 : integer range 0 to 180;
    signal angle_2 : integer range 0 to 180;
    signal angle_3 : integer range 0 to 180;
    signal angle_4 : integer range 0 to 180;

    -- BCD digits (hundreds, tens, ones) for each servo
    signal s1_hundreds, s1_tens, s1_ones : integer range 0 to 9;
    signal s2_hundreds, s2_tens, s2_ones : integer range 0 to 9;
    signal s3_hundreds, s3_tens, s3_ones : integer range 0 to 9;
    signal s4_hundreds, s4_tens, s4_ones : integer range 0 to 9;

    -- 7-segment lookup function (active-low: '0' = segment ON)
    -- Segment order: g f e d c b a
    function to_7seg(digit : integer range 0 to 9) return std_logic_vector is
    begin
        case digit is
            when 0 => return "1000000";
            when 1 => return "1111001";
            when 2 => return "0100100";
            when 3 => return "0110000";
            when 4 => return "0011001";
            when 5 => return "0010010";
            when 6 => return "0000010";
            when 7 => return "1111000";
            when 8 => return "0000000";
            when 9 => return "0010000";
            when others => return "1111111";  -- Blank
        end case;
    end function;

    -- Binary to BCD conversion procedure (for values 0-180)
    procedure bin_to_bcd(
        signal bin_val   : in  integer range 0 to 180;
        signal hundreds  : out integer range 0 to 9;
        signal tens      : out integer range 0 to 9;
        signal ones      : out integer range 0 to 9
    ) is
        variable temp : integer range 0 to 180;
    begin
        temp := bin_val;
        hundreds <= temp / 100;
        temp := temp mod 100;
        tens <= temp / 10;
        ones <= temp mod 10;
    end procedure;

begin

    -- ========================================================================
    -- Pulse Width to Angle Conversion
    -- angle = ((pulse_width - PULSE_MIN) * 180) / PULSE_RANGE
    -- ========================================================================
    process(clk, rst_n)
        variable pw1, pw2, pw3, pw4 : integer;
        variable offset : integer;
    begin
        if rst_n = '0' then
            angle_1 <= 90;  -- Center position
            angle_2 <= 90;
            angle_3 <= 90;
            angle_4 <= 90;
        elsif rising_edge(clk) then
            -- Servo 1
            pw1 := to_integer(unsigned(servo_1_pulse));
            if pw1 < PULSE_MIN then
                pw1 := PULSE_MIN;
            elsif pw1 > PULSE_MAX then
                pw1 := PULSE_MAX;
            end if;
            offset := pw1 - PULSE_MIN;
            angle_1 <= (offset * 180) / PULSE_RANGE;

            -- Servo 2
            pw2 := to_integer(unsigned(servo_2_pulse));
            if pw2 < PULSE_MIN then
                pw2 := PULSE_MIN;
            elsif pw2 > PULSE_MAX then
                pw2 := PULSE_MAX;
            end if;
            offset := pw2 - PULSE_MIN;
            angle_2 <= (offset * 180) / PULSE_RANGE;

            -- Servo 3
            pw3 := to_integer(unsigned(servo_3_pulse));
            if pw3 < PULSE_MIN then
                pw3 := PULSE_MIN;
            elsif pw3 > PULSE_MAX then
                pw3 := PULSE_MAX;
            end if;
            offset := pw3 - PULSE_MIN;
            angle_3 <= (offset * 180) / PULSE_RANGE;

            -- Servo 4
            pw4 := to_integer(unsigned(servo_4_pulse));
            if pw4 < PULSE_MIN then
                pw4 := PULSE_MIN;
            elsif pw4 > PULSE_MAX then
                pw4 := PULSE_MAX;
            end if;
            offset := pw4 - PULSE_MIN;
            angle_4 <= (offset * 180) / PULSE_RANGE;
        end if;
    end process;

    -- ========================================================================
    -- Binary to BCD Conversion
    -- ========================================================================
    process(clk, rst_n)
        variable temp : integer range 0 to 180;
    begin
        if rst_n = '0' then
            s1_hundreds <= 0; s1_tens <= 9; s1_ones <= 0;  -- "090"
            s2_hundreds <= 0; s2_tens <= 9; s2_ones <= 0;
            s3_hundreds <= 0; s3_tens <= 9; s3_ones <= 0;
            s4_hundreds <= 0; s4_tens <= 9; s4_ones <= 0;
        elsif rising_edge(clk) then
            -- Servo 1 BCD
            temp := angle_1;
            s1_hundreds <= temp / 100;
            temp := angle_1 mod 100;
            s1_tens <= temp / 10;
            s1_ones <= temp mod 10;

            -- Servo 2 BCD
            temp := angle_2;
            s2_hundreds <= temp / 100;
            temp := angle_2 mod 100;
            s2_tens <= temp / 10;
            s2_ones <= temp mod 10;

            -- Servo 3 BCD
            temp := angle_3;
            s3_hundreds <= temp / 100;
            temp := angle_3 mod 100;
            s3_tens <= temp / 10;
            s3_ones <= temp mod 10;

            -- Servo 4 BCD
            temp := angle_4;
            s4_hundreds <= temp / 100;
            temp := angle_4 mod 100;
            s4_tens <= temp / 10;
            s4_ones <= temp mod 10;
        end if;
    end process;

    -- ========================================================================
    -- 7-Segment Display Output (showing tens and ones per servo pair)
    -- For 3-digit angles (e.g., 180), the hundreds digit is combined with
    -- the tens digit on the upper display: display shows "18" and "0"
    -- ========================================================================
    hex0 <= to_7seg(s1_ones);                              -- Servo 1 ones
    hex1 <= to_7seg((s1_hundreds * 10 + s1_tens) mod 100); -- Servo 1 tens (with hundreds overflow)
    hex2 <= to_7seg(s2_ones);                              -- Servo 2 ones
    hex3 <= to_7seg((s2_hundreds * 10 + s2_tens) mod 100); -- Servo 2 tens
    hex4 <= to_7seg(s3_ones);                              -- Servo 3 ones
    hex5 <= to_7seg((s3_hundreds * 10 + s3_tens) mod 100); -- Servo 3 tens
    hex6 <= to_7seg(s4_ones);                              -- Servo 4 ones
    hex7 <= to_7seg((s4_hundreds * 10 + s4_tens) mod 100); -- Servo 4 tens

end architecture rtl;
