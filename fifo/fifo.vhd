library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fifo_types.all;

entity fifo is
  generic
  (
    g_depth : integer := 4
  );
  port
  (
    i_fifo_in  : in t_fifo_in;
    o_fifo_out : out t_fifo_out
  );
end fifo;

architecture RTL of fifo is
  type fifo_memory is array (0 to g_depth - 1) of std_logic_vector(7 downto 0);
  signal r_memory : fifo_memory;
  signal r_head   : integer range 0 to g_depth - 1 := 0;
  signal r_tail   : integer range 0 to g_depth - 1 := 0;
  signal r_count  : integer range 0 to g_depth     := 0;
begin

  process (i_fifo_in.clk, i_fifo_in.reset)
  begin
    if i_fifo_in.reset = '1' then
      r_head  <= 0;
      r_tail  <= 0;
      r_count <= 0;
      o_fifo_out.full <= '0';
      o_fifo_out.empty <= '1';
    elsif rising_edge(i_fifo_in.clk) then
      if i_fifo_in.enq = '1' and r_count /= g_depth then
        r_memory(r_head) <= i_fifo_in.data;
        if r_head /= g_depth - 1 then
          r_head <= r_head + 1;
        else
          r_head <= 0;
        end if;
        r_count <= r_count + 1;
      end if;

      if i_fifo_in.deq = '1' and r_count /= 0 then
        o_fifo_out.data <= r_memory(r_tail);
        if r_head /= g_depth - 1 then
          r_tail <= r_tail + 1;
        else
          r_tail <= 0;
        end if;
        r_count <= r_count - 1;
      end if;
    end if;
  end process;

  o_fifo_out.full <= '1' when r_count = g_depth else
  '0';
  o_fifo_out.empty <= '1' when r_count = 0 else
  '0';

end RTL;