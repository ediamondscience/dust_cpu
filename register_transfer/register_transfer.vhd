library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! I/O definitions for reading and writing cpu registers
package register_transfer is
  --! Connection for writing cpu registers
  type t_reg_writer is record
    --! Write enable
    wr_ena : std_logic;
    --! Data line
    data : std_logic_vector(15 downto 0);
  end record t_reg_writer;
  --! Connection for readin register values
  type t_reg_reader is record
    --! readout is active
    rd_active : std_logic;
    --! data line
    data : std_logic_vector(15 downto 0);
  end record t_reg_reader;
end register_transfer;