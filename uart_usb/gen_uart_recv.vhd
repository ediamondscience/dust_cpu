-- This entity is a uart reciever with configurable baud, stop bits, data bits. 
-- This does not allow for configurable flow control or parity bits.
-- Writen while studying vhdl on the nandland go board. 
-- I had a look at Russel Merrick's code for this and took the idea of the state machine being a defined type. 
-- E.D. 1/24
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_recvr is
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
    -- clock input
    i_clk : in std_logic;
    -- recieve line
    i_recv : in std_logic;
    -- data output is an integer
    o_data : out std_logic_vector(g_bits - 1 downto 0);
    -- new data available
    o_new : out std_logic);
end entity uart_recvr;

architecture RTL of uart_recvr is

  -- set up constants for the number of clocks between the bits and a half a bit
  constant c_bit_width  : integer := g_clk/g_baud;
  constant c_half_width : integer := g_clk/(2 * g_baud);

  -- Defining a new type for the state machine. UART goes through a few different states:
  -- - Idle: the uart is waiting to recieve the start bit
  -- - Start bit: the start bit has been recieved. This is not a data bit, but does start the timing critical section
  -- - Data bits: the data bits are running at the specified timing, the rx is reading them out
  -- - Stop bit:  the stop bit is being transmitted, this is a good opportunity for the rx module to clean up
  type rx_SM is (idle, start_bit, data_bits, stop_bits);

  -- set up the state machine to start in idle
  signal state : rx_SM := idle;
  -- vector holds the data bit values
  signal r_data : std_logic_vector (g_bits - 1 downto 0) := (others => '0');
  -- data bit counter
  signal r_cnt : integer range 0 to g_bits - 1 := 0;
  -- clock to baud converter
  signal r_baud : integer range 0 to c_bit_width := 0;

begin
  sig_interp : process (i_Clk) is
  begin
    if rising_edge(i_Clk) then
      case state is
          -- hanging around in idle
        when idle =>
          if i_recv = '0' then
            state  <= start_bit; -- the start bit has been sent
            r_cnt  <= 0;
            r_baud <= 0;
            o_new  <= '0';
          end if;
          -- the start bit routine
        when start_bit =>
          if r_baud = c_bit_width then
            state  <= data_bits; -- the start bit has finished, go to data bit state
            r_baud <= 0;
          else
            r_baud <= r_baud + 1;
          end if;
          -- reading out the data bits, order is big endian
        when data_bits =>
          if r_baud = c_bit_width then
            if r_cnt = g_bits then
              state  <= stop_bits; -- the data bits have finished and we've waited until the stop bits begin
              r_cnt  <= 0;
              o_data <= r_data;
            end if;
            r_baud <= 0;
          elsif r_baud = c_half_width then
            r_data(r_cnt) <= i_recv;
            r_cnt         <= r_cnt + 1;
            r_baud        <= r_baud + 1;
          else
            r_baud <= r_baud + 1;
          end if;
          -- delaying for the correct number of stop bits, maybe unecessary
        when stop_bits =>
          if r_baud = c_bit_width then
            state  <= idle;
            r_baud <= 0;
            o_new  <= '1';
            o_data <= r_data;
          else
            r_baud <= r_baud + 1;
          end if;
      end case;
    end if;
  end process sig_interp;

end architecture;