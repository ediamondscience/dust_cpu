library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.alu_types.all;

--! Handles arithmetic operations on combinations of numbers.
--! Can add, subtract, multiply, divide, and take remainders of division.
entity algorithmic_logic_unit is
  generic (
    g_WIDTH : integer := 16
    );
  port
  (
    --! clock input
    i_clk : in std_logic;
    --! Input argument
    i_cmd : in t_alu_cmd;
    --! Input for arg 1
    i_arg1 : in std_logic_vector(g_WIDTH - 1 downto 0);
    --! Input for arg 2
    i_arg2 : in std_logic_vector(g_WIDTH - 1 downto 0);
    --! error register
    o_error : out std_logic_vector(g_WIDTH - 1 downto 0);
    --! carry register
    o_carry : out std_logic_vector(g_WIDTH - 1 downto 0);
    --! result writer
    o_result : out std_logic_vector(g_WIDTH - 1 downto 0)
  );
end entity algorithmic_logic_unit;

architecture RTL of algorithmic_logic_unit is
  --! Algorithmic operation result wire, split to output and carry
  signal w_full_result : unsigned ((2 * g_WIDTH) - 1 downto 0);
  signal w_arg1        : unsigned ((2 * g_WIDTH) - 1 downto 0);
  signal w_arg2        : unsigned ((2 * g_WIDTH) - 1 downto 0);
begin

  --! Performs the input operation on the input values
  combine_numbers : process (i_clk)
  begin
    if rising_edge(i_clk) then
      case i_cmd is
        when ALU_ADD =>
          w_full_result <= w_arg1 + w_arg2;
          o_error <= (others => '0');
        when ALU_SUB =>
          w_full_result <= w_arg1 - w_arg2;
          o_error <= (others => '0');
        when ALU_MUL =>
          w_full_result <= w_arg1(g_WIDTH - 1 downto 0) * w_arg2(g_WIDTH - 1 downto 0);
          o_error <= (others => '0');
        when ALU_DIV =>
          if w_arg2 = 0 then
            o_error <= (4 => '1', others => '0');
          else
            w_full_result <= w_arg1 / w_arg2;
            o_error <= (others => '0');
          end if;
        when ALU_REM =>
          if w_arg2 = 0 then
            o_error <= (5 => '1', others => '0');
          else
            w_full_result <= w_arg1 mod w_arg2;
          o_error <= (others => '0');
          end if;
        when others =>
            o_error <= (6 => '1', others => '0');
      end case;
    end if;
  end process combine_numbers;

  o_carry  <= std_logic_vector(w_full_result((2 * g_WIDTH) - 1 downto g_WIDTH));
  o_result <= std_logic_vector(w_full_result(g_WIDTH - 1 downto 0));

  w_arg1 <= resize(unsigned(i_arg1), 2*g_WIDTH);
  w_arg2 <= resize(unsigned(i_arg2), 2*g_WIDTH);

end architecture RTL;