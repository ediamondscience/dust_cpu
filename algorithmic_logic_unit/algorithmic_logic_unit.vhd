library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.alu_types.all;
use work.register_transfer.all;

--! Handles arithmetic operations on combinations of numbers.
--! Can add, subtract, multiply, divide, and take remainders of division.
entity algorithmic_logic_unit is
  port
  (
    --! clock input
    i_clk : in std_logic;
    --! Input argument
    i_cmd : in t_alu_cmd;
    --! Input for arg 1
    i_arg1 : in t_reg_reader;
    --! Input for arg 2
    i_arg2 : in t_reg_reader;
    --! error register
    o_error : out t_reg_writer;
    --! carry register
    o_carry : out t_reg_writer;
    --! result writer
    o_result : out t_reg_writer
  );
end entity algorithmic_logic_unit;

architecture RTL of algorithmic_logic_unit is
  --! Algorithmic operation result wire, split to output and carry
  signal w_full_result : unsigned(31 downto 0);
  signal w_arg1        : unsigned (31 downto 0);
  signal w_arg2        : unsigned (31 downto 0);
begin

  --! Performs the input operation on the input values
  combine_numbers : process (i_clk)
  begin
    if rising_edge(i_clk) then
      case i_cmd is
        when ALU_ADD =>
          w_full_result <= w_arg1 + w_arg2;
          o_result.wr_ena <= '1';
          o_carry.wr_ena  <= '1';
          o_error.data   <= x"0000";
          o_error.wr_ena <= '0';
        when ALU_SUB =>
          w_full_result <= w_arg1 - w_arg2;
          o_result.wr_ena <= '1';
          o_carry.wr_ena  <= '1';
          o_error.data   <= x"0000";
          o_error.wr_ena <= '0';
        when ALU_MUL =>
          w_full_result <= w_arg1(15 downto 0) * w_arg2(15 downto 0);
          o_result.wr_ena <= '1';
          o_carry.wr_ena  <= '1';
          o_error.data   <= x"0000";
          o_error.wr_ena <= '0';
        when ALU_DIV =>
          if w_arg2 = 0 then
            o_error.data   <= x"0010";
            o_error.wr_ena <= '1';
            o_result.wr_ena <= '0';
            o_carry.wr_ena  <= '0';
          else
            w_full_result <= w_arg1 / w_arg2;
            o_result.wr_ena <= '1';
            o_carry.wr_ena  <= '1';
            o_error.data   <= x"0000";
            o_error.wr_ena <= '0';
          end if;
        when ALU_REM =>
          if w_arg2 = 0 then
            o_error.data   <= x"0020";
            o_error.wr_ena <= '1';
            o_result.wr_ena <= '0';
            o_carry.wr_ena  <= '0';
          else
            w_full_result <= w_arg1 mod w_arg2;
            o_result.wr_ena <= '1';
            o_carry.wr_ena  <= '1';
            o_error.data   <= x"0000";
            o_error.wr_ena <= '0';
          end if;
        when others =>
          o_result.wr_ena <= '0';
          o_carry.wr_ena  <= '0';
      end case;
    end if;
  end process combine_numbers;

  o_carry.data  <= std_logic_vector(w_full_result(31 downto 16));
  o_result.data <= std_logic_vector(w_full_result(15 downto 0));

  with i_arg1.rd_active select w_arg1(15 downto 0) <=
  unsigned(i_arg1.data) when '1',
  x"0000" when others;

  with i_arg2.rd_active select w_arg2(15 downto 0) <=
  unsigned(i_arg2.data) when '1',
  x"0000" when others;

  w_arg1(31 downto 16) <= x"0000";
  w_arg2(31 downto 16) <= x"0000";

end architecture RTL;