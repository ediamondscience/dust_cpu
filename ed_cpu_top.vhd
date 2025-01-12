library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.alu_types.all;
use work.decoder_types.all;
use work.hw_manager_types.all;
use work.interpreter_types.all;
use work.register_transfer.all;

entity cpu_top is
  port
  (
    i_Clk        : in std_logic;
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
end entity cpu_top;

architecture RTL of cpu_top is
  --! hardware command signals
  signal hardware_command : hw_cmds := noop;
  signal hw_reg_in : t_reg_reader;
  signal hw_reg_out : t_reg_writer;
  signal hw_error : t_reg_writer;
  

  --! alu command signals
  signal alu_cmd : t_alu_cmd;
  signal alu_arg1 : t_reg_reader;  
  signal alu_arg2 : t_reg_reader;
  signal alu_result : t_reg_writer;
  signal alu_error : t_reg_writer;
  signal alu_carry : t_reg_writer;

  --! decoder command signals
  signal instruction : std_logic_vector(15 downto 0);
  signal jump_signal : t_decoder_jmp_port;
  signal decoder_interp : t_interpreter_port;
  signal instruction_address : std_logic_vector(15 downto 0);

  --! ram command signals
  signal write_back_ena : std_logic;
  signal ram_reg_reader : t_reg_reader;
  signal ram_addr_sel : t_reg_reader;
  signal ram_reg_writer : t_reg_writer;

begin
  io_manager : entity work.hw_manager
    generic map (
      g_fifo_depth => 16
    )
    port map (
      i_clk        => i_Clk,
      i_hw_cmd     => hardware_command,
      i_register   => hw_reg_in,
      o_register   => hw_reg_out,
      o_hw_error   => hw_error,
      i_UART_RX    => i_UART_RX,   
      o_UART_TX    => o_UART_TX,   
      o_Segment1_A => o_Segment1_A,
      o_Segment1_B => o_Segment1_B,
      o_Segment1_C => o_Segment1_C,
      o_Segment1_D => o_Segment1_D,
      o_Segment1_E => o_Segment1_E,
      o_Segment1_F => o_Segment1_F,
      o_Segment1_G => o_Segment1_G,
      o_Segment2_A => o_Segment2_A,
      o_Segment2_B => o_Segment2_B,
      o_Segment2_C => o_Segment2_C,
      o_Segment2_D => o_Segment2_D,
      o_Segment2_E => o_Segment2_E,
      o_Segment2_F => o_Segment2_F,
      o_Segment2_G => o_Segment2_G,
      o_LED_1      => o_LED_1,     
      o_LED_2      => o_LED_2,     
      o_LED_3      => o_LED_3,     
      o_LED_4      => o_LED_4
    );

  alu : entity work.algorithmic_logic_unit
    port map (
      i_clk => i_Clk,
      i_cmd => alu_cmd,
      i_arg1 => alu_arg1,
      i_arg2 => alu_arg2,
      o_error => alu_error,
      o_carry => alu_carry,
      o_result => alu_result
    );

  decode : entity work.decoder
    port map (
      i_clk => i_Clk,
      i_instr => instruction,
      i_instr_chg => jump_signal,
      o_intr_out => decoder_interp,
      o_intr_cnt => instruction_address
    );

  ram : entity work.ram_module
    generic map(
      g_ADDR_DEPTH => 256
    )
    port map(
      i_clk           => i_Clk,
      i_wb_req        => write_back_ena,
      i_instr_addr    => instruction_address,
      i_data_register => ram_reg_reader,
      i_addr_register => ram_addr_sel,
      o_register      => ram_reg_writer,
      o_instr_data    => instruction
    );
  
  interp : entity work.interpreter
  port map(
      i_clk       => i_Clk,
      i_instr     => decoder_interp,
      o_jmp_out   => jump_signal,
      o_alu_cmd   => alu_cmd,
      o_alu_arg_1 => alu_arg1,
      o_alu_arg_2 => alu_arg2,
      i_alu_ret   => alu_result,
      i_alu_carry => alu_carry,
      i_alu_error => alu_error,
      o_data_reg  => ram_reg_reader,
      o_data_addr => ram_addr_sel,
      i_data_wrb  => ram_reg_writer,
      o_write_ena => write_back_ena,
      o_hw_cmd    => hardware_command,
      o_hwm_reg   => hw_reg_in,
      i_hwm_reg   => hw_reg_out,
      i_hw_error  => hw_error
    );
  
end architecture RTL;