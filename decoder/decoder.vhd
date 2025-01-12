library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.interpreter_types.all;
use work.decoder_types.all;

--! Fetches and decodes instructions for the cpu
entity decoder is
  port
  (
    --! input clock
    i_clk           : in std_logic;
    --! instruction reading port
    i_instr         : in std_logic_vector(CMD_WIDTH - 1 downto 0);
    --! instruction change port
    i_instr_chg     : in t_decoder_jmp_port;
    --! instruction out signal to the interpreter
    o_intr_out      : out t_interpreter_port;
    --! instruction counter out
    o_intr_cnt      : out std_logic_vector(15 downto 0)
  );
end decoder;

architecture RTL of decoder is
  -- **** CONSTANTS ****
  --! portion of instruction that comprises the command
  constant CMD_BITS : integer := 4;
  --! reading 16 bit commands
  constant CMD_WIDTH : integer := 16;
  
  -- **** SIGNALS ****
  --! instruction counter
  signal r_instruction_cntr : unsigned(CMD_WIDTH - 1 downto 0) := (others => '0');
begin
  fetch: process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_instr_chg.sig_jmp = '1' then
        r_instruction_cntr <= unsigned(i_instr_chg.address);
      else
        r_instruction_cntr <= r_instruction_cntr + 1;
        o_intr_out.cmd <= read_instruction(i_instr(CMD_WIDTH - 1 downto CMD_WIDTH - CMD_BITS));
        o_intr_out.cmd_bits <= i_instr(CMD_WIDTH - CMD_BITS - 1 downto 0);
      end if;
    end if;
  end process fetch;
  o_intr_cnt <= std_logic_vector(r_instruction_cntr);
end architecture RTL;