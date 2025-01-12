-- Code to interface with 1 seven segment display using a 16b unsigned integer.
-- Coded while going through the tutorials from https://nandland.com/
-- This is likely pretty similar to Russell Merrick's solution, but was 
-- coded without looking at it for additional challenge.
-- I think that Merrick's solution probably had a different
-- input method, but I know that there is another implementation he wrote for project 7.
-- E.D. 1/24
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sev_seg_disp is
  port
  (
    i_Clk      : in std_logic;
    i_disp_num : in integer;
    o_a        : out std_logic;
    o_b        : out std_logic;
    o_c        : out std_logic;
    o_d        : out std_logic;
    o_e        : out std_logic;
    o_f        : out std_logic;
    o_g        : out std_logic
  );
end entity sev_seg_disp;

architecture RTL of sev_seg_disp is

  -- assumed architecture of 7 segment display is as follows:
  -- 
  --  -- 0 --
  --  |     |
  --  5     1
  --  |- 6 -|
  --  4     2
  --  |     |
  --  -- 3 --
  --
  -- init both values to zero
  signal disp_int : integer range 0 to 15 := 0;

  -- handling this with a vector for compactness, first time using one of these
  signal out_vec : std_logic_vector (6 downto 0) := (6 => '0', others => '1'); -- disp 0

begin
  p_disp_num : process (i_Clk) is
  begin
    if rising_edge(i_Clk) then
      disp_int <= i_disp_num;

      -- handling display cases, note that '0' turns segment on
      case disp_int is
        when 0                 =>
          out_vec <= (6 => '1', others => '0');
        when 1                 =>
          out_vec <= (1 | 2 => '0', others => '1');
        when 2                 =>
          out_vec <= (5 | 2 => '1', others => '0');
        when 3                 =>
          out_vec <= (5 | 4 => '1', others => '0');
        when 4                 =>
          out_vec <= (0 | 3 | 4 => '1', others => '0');
        when 5                 =>
          out_vec <= (1 | 4 => '1', others => '0');
        when 6                 =>
          out_vec <= (1 => '1', others => '0');
        when 7                 =>
          out_vec <= (0 | 1 | 2 => '0', others => '1');
        when 8                 =>
          out_vec <= (6 downto 0 => '0');
        when 9                 =>
          out_vec <= (3 | 4 => '1', others => '0');
        when 10                => -- a
          out_vec <= (3 => '1', others => '0');
        when 11                => -- b
          out_vec <= (0 | 1 => '1', others => '0');
        when 12                => -- c
          out_vec <= (1 | 2 | 6 => '1', others => '0');
        when 13                => -- d
          out_vec <= (0 | 5 => '1', others => '0');
        when 14                => -- e
          out_vec <= (1 | 2 => '1', others => '0');
        when 15                => -- f
          out_vec <= (1 | 2 | 3 => '1', others => '0');
      end case;
    end if;
  end process p_disp_num;

  o_a <= out_vec(0);
  o_b <= out_vec(1);
  o_c <= out_vec(2);
  o_d <= out_vec(3);
  o_e <= out_vec(4);
  o_f <= out_vec(5);
  o_g <= out_vec(6);

end architecture RTL;