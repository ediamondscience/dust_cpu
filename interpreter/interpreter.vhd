library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.alu_types.all;
use work.decoder_types.all;
use work.interpreter_types.all;
use work.hw_manager_types.all;
use work.register_transfer.all;

--! CPU Interpreter. This module sends commands out to executor modules.
--! This takes decoded 4 bit command specifications with 12 bit arguments 
--! in each command word. Most arguments must be loaded into registers
--! in the CPU that shuttle arguments to the relevant components. 
entity interpreter is
  port (
    --! Input clock
    i_clk : in std_logic;
    --! Command input from fetcher
    i_instr : in t_interpreter_port;
    --! Jump command to the decoder
    o_jmp_out : out t_decoder_jmp_port;

    -- ALU ARGS IN/OUT
    --! Output for ALU command
    o_alu_cmd : out t_alu_cmd;
    --! ALU Arg 1 
    o_alu_arg_1 : out t_reg_reader;
    --! ALU Arg 2 
    o_alu_arg_2 : out t_reg_reader;
    --! ALU Return
    i_alu_ret : in t_reg_writer;
    --! ALU Carry
    i_alu_carry : in t_reg_writer;
    --! ALU Error
    i_alu_error : in t_reg_writer;

    -- RAM IN/OUT
    --! input to the RAM module
    o_data_reg : out t_reg_reader;
    --! Address input to the RAM module
    o_data_addr : out t_reg_reader;
    --! Writeback from the RAM module
    i_data_wrb : in t_reg_writer;
    --! request writeback from RAM module
    o_write_ena : out std_logic;

    -- HW IN/OUT
    o_hw_cmd : out hw_cmds;
    --! Input to the HW manager
    o_hwm_reg : out t_reg_reader;
    --! Write back from the HW manager
    i_hwm_reg : in t_reg_writer;
    --! HW error
    i_hw_error : in t_reg_writer
  );
end interpreter;

architecture RTL of interpreter is
  -- **** CONSTANTS ****
  constant ERROR_REGISTER : integer := 14;
  constant CARRY_REGISTER : integer := 15;
  
  -- **** Wires ****
  --! The current state of the interpreter
  signal state         : t_sm_interp := execute;
  signal registers     : cpu_regs    := (others => (others => '0'));
  signal arg1          : std_logic_vector(15 downto 0);
  signal arg2          : std_logic_vector(15 downto 0);
  signal arg3          : integer range 0 to 15;
  signal write_back_sr : t_wr_shift;
  signal w_jump_port   : t_decoder_jmp_port;

begin
  --! Main process for cpu processing
  run_interp : process (i_clk)
  begin
    if rising_edge(i_clk) then
      write_back_sr(1) <= write_back_sr(0);
      case state is
        when execute =>
          --! Use the translated instruction to execute
          with i_instr.cmd select o_alu_cmd <=
          ALU_ADD when ADDI,
          ALU_SUB when SUBI,
          ALU_MUL when MULI,
          ALU_DIV when DIVI,
          ALU_REM when MODI,
          ALU_NOP when others;

          -- set up arguments for the ALU calls
          with i_instr.cmd select o_alu_arg_1.rd_active <=
          '1' when ADDI | SUBI | MULI | DIVI | MODI,
          '0' when others;

          with i_instr.cmd select o_alu_arg_2.rd_active <=
          '1' when ADDI | SUBI | MULI | DIVI | MODI,
          '0' when others;

          with i_instr.cmd select o_alu_arg_1.data <=
          arg1 when ADDI | SUBI | MULI | DIVI | MODI,
          (others => '0') when others;

          with i_instr.cmd select o_alu_arg_2.data <=
          arg2 when ADDI | SUBI | MULI | DIVI | MODI,
          (others => '0') when others;

          if i_alu_ret.wr_ena = '1' and write_back_sr(1) /= - 1 then
            registers(write_back_sr(1)) <= i_alu_ret.data;
          end if;

          with i_instr.cmd select o_write_ena <=
          '1' when LDRI,
          '0' when others;

          -- set up the hardware command arguments
          with i_instr.cmd select o_hw_cmd <=
          read_hw_cmd(i_instr.cmd_bits(11 downto 8)) when HWPC,
          noop when others;

          with i_instr.cmd select o_hwm_reg.rd_active <=
          '1' when HWPC,
          '0' when others;

          if i_alu_carry.wr_ena = '1' then
            registers(CARRY_REGISTER) <= i_alu_carry.data;
          end if;

          with i_instr.cmd select o_hwm_reg.data <=
          arg2 when HWPC,
          (others => '0') when others;

          if i_hwm_reg.wr_ena = '1' and write_back_sr(1) /= - 1 then
            registers(write_back_sr(1)) <= i_hwm_reg.data;
          end if;

          -- error handling
          if (i_alu_error.wr_ena = '1' and i_hw_error.wr_ena = '1') then
            registers(ERROR_REGISTER) <= (registers(ERROR_REGISTER) and i_alu_error.data and i_hw_error.data);
          elsif i_alu_error.wr_ena = '1' then
            registers(ERROR_REGISTER) <= registers(ERROR_REGISTER) and i_alu_error.data;
          elsif i_hw_error.wr_ena = '1' then
            registers(ERROR_REGISTER) <= registers(ERROR_REGISTER) and i_hw_error.data;
          end if;

          -- set up ram access commands
          with i_instr.cmd select o_data_addr.rd_active <=
          '1' when SVRI | LDRI,
          '0' when others;

          with i_instr.cmd select o_data_addr.data <=
          arg1 when SVRI | LDRI,
          (others => '0') when others;

          with i_instr.cmd select o_data_reg.rd_active <=
          '1' when SVRI,
          '0' when others;

          with i_instr.cmd select o_data_reg.data <=
          arg1 when SVRI,
          (others => '0') when others;

          if i_hwm_reg.wr_ena = '1' and write_back_sr(1) /= - 1 then
            registers(write_back_sr(1)) <= i_data_wrb.data;
          end if;

          -- set up write back
          with i_instr.cmd select write_back_sr(0) <=
          arg3 when ADDI | SUBI | MULI | DIVI | MODI | CHKI | HWPC | LDRI | SVRI,
          - 1 when others;

          -- checking behavior
          if i_instr.cmd = CHKI then
            if signed(arg1) > signed(arg2) then
              registers(CHECK_REGISTER)(GREATER_THAN_SIGNED_BIT) <= '1';
            end if;
            if arg1 > arg2 then
              registers(CHECK_REGISTER)(GREATER_THAN_UNSIGNED_BIT) <= '1';
            end if;
            if signed(arg1) < signed(arg2) then
              registers(CHECK_REGISTER)(LESS_THAN_SIGNED_BIT) <= '1';
            end if;
            if arg1 < arg2 then
              registers(CHECK_REGISTER)(LESS_THAN_UNSIGNED_BIT) <= '1';
            end if;
            if arg1 = arg2 then
              registers(CHECK_REGISTER)(EQUAL_TO_BIT) <= '1';
            end if;
            if arg1 /= arg2 then
              registers(CHECK_REGISTER)(NOT_EQUAL_TO_BIT) <= '1';
            end if;
          end if;

          -- jumping behavior
          w_jump_port <= read_check_register(i_instr.cmd_bits, registers);

          with w_jump_port.sig_jmp select state <= 
          jmp_halt when '1',
          execute when others;

        when jmp_halt =>
          state <= execute;
        --! execution has been halted, do nothing
        when halted => -- @suppress "Dead state 'halted': state does not have outgoing transitions"
          null;
      end case;
    end if;
  end process run_interp;

  arg1 <= registers(to_idx(i_instr.cmd_bits(11 downto 8)));
  arg2 <= registers(to_idx(i_instr.cmd_bits(7 downto 4)));
  arg3 <= to_idx(i_instr.cmd_bits(3 downto 0));
  o_jmp_out <= w_jump_port;
end architecture RTL;