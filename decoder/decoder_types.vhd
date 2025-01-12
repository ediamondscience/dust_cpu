library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Types for the decoder
package decoder_types is
  --! Connection to the ALU
  type t_decoder_jmp_port is record
    --! signal to jump instruction register
    sig_jmp : std_logic;
    --! register nibble with jump location
    address : std_logic_vector(15 downto 0);
  end record t_decoder_jmp_port;
end package;