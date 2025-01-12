library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fifo_types.all;
use work.interpreter_types.all;
use work.hw_manager_types.all;
use work.register_transfer.all;

--! A module for controlling hardware aspects of the go board
entity hw_manager is
  generic
  (
    g_fifo_depth : integer := 4 -- depth of the fifos
  );
  port
  (
    i_clk        : in std_logic;
    i_hw_cmd     : in hw_cmds;
    i_register   : in t_reg_reader;
    o_register   : out t_reg_writer;
    o_hw_error   : out t_reg_writer;
    i_UART_RX    : in std_logic;
    o_UART_TX    : out std_logic;
    o_Segment1_A : out std_logic;
    o_Segment1_B : out std_logic;
    o_Segment1_C : out std_logic;
    o_Segment1_D : out std_logic;
    o_Segment1_E : out std_logic;
    o_Segment1_F : out std_logic;
    o_Segment1_G : out std_logic;
    o_Segment2_A : out std_logic;
    o_Segment2_B : out std_logic;
    o_Segment2_C : out std_logic;
    o_Segment2_D : out std_logic;
    o_Segment2_E : out std_logic;
    o_Segment2_F : out std_logic;
    o_Segment2_G : out std_logic;
    o_LED_1      : out std_logic;
    o_LED_2      : out std_logic;
    o_LED_3      : out std_logic;
    o_LED_4      : out std_logic
  );
end hw_manager;

architecture RTL of hw_manager is
  -- constants for uart setup
  constant c_Clk  : integer := 25000000;
  constant c_Baud : integer := 115200;
  constant c_Bits : integer := 8;
  constant c_Stop : integer := 1;

  -- fifo signals
  signal w_tx_fifo_in, w_rx_fifo_in   : t_fifo_in;
  signal w_tx_fifo_out, w_rx_fifo_out : t_fifo_out;

  signal r_led_states : std_logic_vector(3 downto 0);

  -- holds the first four bits of vec_out, sends to one 7 segment display
  signal msb_out : integer range 0 to 15 := 0;
  -- holds the last four bits of vec_out, sends to other 7 segment
  signal lsb_out : integer range 0 to 15 := 0;
  -- signal the fifos to reset
  signal reset : std_logic := '0';
  -- output register line
  signal w_out_register : t_reg_writer;

begin
  -- seven segment display in the MSB position
  sev_seg_msb : entity work.sev_seg_disp
    port map
    (
      i_Clk      => i_clk,
      i_disp_num => msb_out,
      o_a        => o_Segment1_A,
      o_b        => o_Segment1_B,
      o_c        => o_Segment1_C,
      o_d        => o_Segment1_D,
      o_e        => o_Segment1_E,
      o_f        => o_Segment1_F,
      o_g        => o_Segment1_G
    );

  -- seven segment display in the LSB position
  sev_seg_lsb : entity work.sev_seg_disp
    port
    map
    (
    i_Clk      => i_clk,
    i_disp_num => lsb_out,
    o_a        => o_Segment2_A,
    o_b        => o_Segment2_B,
    o_c        => o_Segment2_C,
    o_d        => o_Segment2_D,
    o_e        => o_Segment2_E,
    o_f        => o_Segment2_F,
    o_g        => o_Segment2_G
    );

  -- fifo components
  uart_rx_buffer : entity work.fifo
    generic map (
    g_depth => g_fifo_depth
    )
    port map (
    i_fifo_in  => w_rx_fifo_in,
    o_fifo_out => w_rx_fifo_out
    );

  uart_tx_buffer : entity work.fifo
    generic map (
    g_depth => g_fifo_depth
    )
    port map (
    i_fifo_in  => w_tx_fifo_in,
    o_fifo_out => w_tx_fifo_out
    );

  -- UART Definitions
  uart_recv_inst : entity work.uart_recvr
    generic map (
    g_baud => c_Baud,
    g_bits => c_Bits,
    g_stop => c_Stop,
    g_clk  => c_Clk
    )
    port map (
    i_clk  => i_clk,
    i_recv => i_UART_RX,
    o_data => w_rx_fifo_in.data,
    o_new  => w_rx_fifo_in.enq
    );

  uart_tx_inst : entity work.uart_tx
    generic map (
    g_baud => c_Baud,
    g_bits => c_Bits,
    g_stop => c_Stop,
    g_clk  => c_Clk
    )
    port map (
    i_clk  => i_clk,
    i_data => w_tx_fifo_out.data,
    i_ena  => not(w_tx_fifo_out.empty),
    o_line => o_UART_TX,
    o_fin  => w_tx_fifo_in.deq
    );

  --! handles reading and writing to the RAM
  hw_mgmt : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_register.rd_active = '1' then
        case i_hw_cmd is
          when sev_seg =>
              msb_out <= to_idx(i_register.data(7 downto 4));
              lsb_out <= to_idx(i_register.data(3 downto 0));
          when led =>
              r_led_states <= i_register.data(3 downto 0);
          when uart_tx =>
              w_tx_fifo_in.data <= i_register.data(7 downto 0);
          when uart_rx =>
            w_out_register.data(7 downto 0) <= w_rx_fifo_in.data;
            w_out_register.data(15 downto 8) <= (others => '0');
            w_out_register.wr_ena <= '1';
          when others =>
            null;
        end case;

        if w_rx_fifo_out.full = '1' then
          o_hw_error.data(12) <= '1';
        else
          o_hw_error.data(12) <= '0';
        end if;

        if w_tx_fifo_out.full = '1' then
          o_hw_error.data(13) <= '1';
        else
          o_hw_error.data(13) <= '0';
        end if;

        if (w_rx_fifo_out.full = '1' or w_tx_fifo_out.full = '1') then
          o_hw_error.wr_ena <= '0';
        else
          o_hw_error.wr_ena <= '0';
        end if;
      end if;
      if (i_register.rd_active = '1' or w_out_register.wr_ena = '1') then
        case i_hw_cmd is
          when uart_tx =>
            w_rx_fifo_in.deq <= '0';
            w_tx_fifo_in.enq <= '1';
          when others =>
            w_rx_fifo_in.deq <= '0';
            w_tx_fifo_in.enq <= '0';
        end case;
      end if;
      if i_register.rd_active = '1' then
        case i_hw_cmd is
          when uart_rx =>
            w_rx_fifo_in.deq <= '1';
            w_tx_fifo_in.enq <= '0';
          when others =>
            
        end case;
      end if;
      case i_hw_cmd is
        when uart_reset =>
          reset <= '1';
        when others =>
          reset <= '0';
      end case;
    end if;
  end process;
  o_LED_1 <= r_led_states(0);
  o_LED_2 <= r_led_states(1);
  o_LED_3 <= r_led_states(2);
  o_LED_4 <= r_led_states(3);
  with i_hw_cmd select reset <=
  '1' when uart_reset,
  '0' when others;

  w_rx_fifo_in.clk   <= i_clk;
  w_tx_fifo_in.clk   <= i_clk;
  w_rx_fifo_in.reset <= reset;
  w_tx_fifo_in.reset <= reset;

  o_register <= w_out_register;
end RTL;