library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.register_transfer.all;

--! A simple ram module with adjustable width and depth.
--! Has two access lanes: one is read only and is meant 
--! for reading instructions. The read/write lane acts as
--! the sole writer for changing the data held by this module.
entity ram_module is
  generic
  (
    --! The number of register addresses in this module
    g_ADDR_DEPTH : integer := 256
  );
  port
  (
    --! Input clock
    i_clk : in std_logic;
    --! request writeback
    i_wb_req : in std_logic;
    --! Instruction address select to read out from RAM -- this line is read only
    i_instr_addr : in std_logic_vector(15 downto 0);
    --! input from the CPU registers
    i_data_register : in t_reg_reader;
    --! input for the data read/write address
    i_addr_register : in t_reg_reader;
    --! output to the CPU registers
    o_register : out t_reg_writer;
    --! Output instruction data line
    o_instr_data : out std_logic_vector(15 downto 0)
  );
end ram_module;

architecture RTL of ram_module is
  --! Array of std_logic_vector for holding ram information
  type t_ram_type is array (g_ADDR_DEPTH - 1 downto 0) of std_logic_vector (15 downto 0);
  --! Array of memory values
  signal r_memory : t_ram_type := (others => (others => '0'));
begin
  --! handles reading and writing to the RAM
  ram_acess : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_addr_register.rd_active = '1' and i_data_register.rd_active = '1' then
        r_memory(to_integer(unsigned(i_addr_register.data))) <= i_data_register.data;
      end if;
      if i_wb_req = '1' then
        o_register.data <= r_memory(to_integer(unsigned(i_addr_register.data)));
      end if;
      o_instr_data <= r_memory(to_integer(unsigned(i_instr_addr)));
    end if;
  end process;

  o_register.wr_ena <= i_wb_req;
end RTL;