library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Types for the decoder
package hw_manager_types is
  --! Commands to the hardware manager
  type hw_cmds is (noop, led, sev_seg, uart_rx, uart_tx, uart_reset);

  pure function read_hw_cmd(
    hw_nibble : in std_logic_vector(3 downto 0)
  ) return hw_cmds;
end package;

package body hw_manager_types is
  pure function read_hw_cmd(
    hw_nibble : in std_logic_vector(3 downto 0)
  ) return hw_cmds is
    variable command : hw_cmds;
  begin
    case hw_nibble is
      when "0000" =>
        command := noop;
      when "0001" =>
        command := led;
      when "0010" =>
        command := sev_seg;
      when "0011" =>
        command := uart_rx;
      when "0100" =>
        command := uart_tx;
      when "0101" =>
        command := uart_reset;
      when others => -- error handling, do nothing
        command := noop;
    end case;
    return command;
  end function;
end hw_manager_types;