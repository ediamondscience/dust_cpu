library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Types for the decoder
package fifo_types is
  --! Incoming connection to a fifo
  type t_fifo_in is record
    clk   : std_logic;
    reset : std_logic;
    enq   : std_logic;
    deq   : std_logic;
    data  : std_logic_vector(7 downto 0);
  end record t_fifo_in;
  type t_fifo_out is record
    data  : std_logic_vector(7 downto 0);
    full  : std_logic;
    empty : std_logic;
  end record t_fifo_out;
end package;