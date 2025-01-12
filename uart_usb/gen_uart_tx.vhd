-- This entity is a UART Transmitter.
-- It will take an 8bit integer as an input 
-- and send the coresponding byte once over the line
-- Writen while studying vhdl on the nandland go board. 
-- E.D. 1/24
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
  generic
  (
    -- sets the baud in bps
    g_baud : integer;
    -- the number of data bits
    g_bits : integer;
    -- the number of stop bits
    g_stop : integer;
    -- clock speed in Hz
    g_clk : integer);
  port
  (
    -- the input clock
    i_clk : in std_logic;
    -- the input integer, must be 8 bit
    i_data : in std_logic_vector(g_bits - 1 downto 0);
    -- enable line for tx
    i_ena : in std_logic;
    -- the output line to send over
    o_line : out std_logic;
    -- output finished line
    o_fin : out std_logic);
end entity uart_tx;

architecture RTL of uart_tx is
  -- width in cycles that each bit needs to be held.
  constant c_bit_width : integer := g_clk/g_baud;

  -- state machine type for this entity
  type sm_Tx is (idle, start, data, stop_bits, reset);
  -- state holder for this entity, defaults to idle
  signal state : sm_Tx := idle;
  -- vector that the input is placed into
  signal r_data : std_logic_vector (g_bits - 1 downto 0) := (others => '0');
  -- counter for each bit as the messages are sent
  signal r_cnt : integer range 0 to g_bits - 1 := 0;
  -- counter for the baud width
  signal r_baud : integer range 0 to c_bit_width := 0;

begin

  sig_interp : process (i_clk) is
  begin
    if rising_edge(i_clk) then

      case state is
          -- the idle state: output is held high and finish register is enabled.
        when idle =>
          o_line <= '1';
          o_fin  <= '1';
          if i_ena = '1' then
            state  <= start;
            r_data <= i_data;
            o_line <= '0';
          end if;

          -- start bit state: output is held low for 1 baud cycle, finish register is disabled
        when start =>
          o_line <= '0';
          o_fin  <= '0';
          if r_baud = c_bit_width then
            r_baud <= 0;
            r_cnt  <= 0;
            state  <= data;
          else
            r_baud <= r_baud + 1;
          end if;

          -- data bit state: the output is held at each bit of the input data for one baud cycle
        when data =>
          o_line <= r_data(r_cnt);
          o_fin  <= '0';
          if r_baud = c_bit_width then
            if r_cnt = g_bits - 1 then
              r_cnt  <= 0;
              o_line <= '1';
              state  <= stop_bits;
            else
              r_baud <= 0;
              r_cnt  <= r_cnt + 1;
            end if;
          else
            r_baud <= r_baud + 1;
          end if;

          -- stop bit state: the output is held high for the number of stop bits then shifts to the reset state
        when stop_bits =>
          o_line <= '1';
          o_fin  <= '0';
          if r_baud = c_bit_width then
            if r_cnt = g_stop - 1 then
              r_cnt  <= 0;
              r_baud <= 0;
              state  <= reset;
            else
              r_cnt  <= r_cnt + 1;
              r_baud <= 0;
            end if;
          else
            r_baud <= r_baud + 1;
          end if;

          -- the reset state: the state machine waits for the enable register to go low
          -- this is here so that the enable register doesn't get set and left high, resulting in the tx entity constantly sending bytes
        when reset =>
          o_line <= '1';
          o_fin  <= '0';
          if i_ena = '0' then
            state <= idle;
          end if;
      end case;
    end if;
  end process sig_interp;

end architecture RTL;