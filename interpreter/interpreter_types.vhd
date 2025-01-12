-- Instruction definitions and translations for the cpu project.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.decoder_types.all;

package interpreter_types is
  --! width of the reigsters and commands of this cpu
  constant CMD_WIDTH : integer := 16;
  --! Number of registers of 16 bit logic for this cpu's cache
  constant CMD_REGS : integer := 256;
  --! Commands that can be issued to the cpu
  type cpu_cmds is
  (
  -- **** special/system ****
  -- do nothing
  NOOP,
  -- stop execution
  HALT,
  -- make a hardware perepheral call
  HWPC,

  -- **** arithmetic calls ****
  -- add two numbers
  ADDI,
  -- subtract two numbers
  SUBI,
  -- multiply two numbers
  MULI,
  -- divide two numbers
  DIVI,
  -- take the modulo of a number
  MODI,

  -- **** conditional ****
  -- check the value of two registers
  CHKI,

  -- **** memory access ****
  -- load a value from memory into a register
  LDRI,
  -- save a register value into memory
  SVRI,

  -- **** execution flow ****
  -- jump conditional
  JMPC
  );

  --! address of the check register
  constant CHECK_REGISTER : integer := 12;
  -- **** CHECK REGISTER CONSTANTS
  --! arg1 is greater than arg 2 if both are signed
  constant GREATER_THAN_SIGNED_BIT : integer := 0;
  --! arg1 is greater than arg 2 if both are unsigned
  constant GREATER_THAN_UNSIGNED_BIT : integer := 1;
  --! arg1 is less than arg 2 if both are signed
  constant LESS_THAN_SIGNED_BIT : integer := 2;
  --! arg1 is less than arg 2 if both are unsigned
  constant LESS_THAN_UNSIGNED_BIT : integer := 3;
  --! arg1 is equal to arg 2
  constant EQUAL_TO_BIT : integer := 4;
  --! arg1 is not equal to arg 2
  constant NOT_EQUAL_TO_BIT : integer := 5;

  -- **** CPU TYPE DEFINITIONS ****
  --! Register address type for the CPU Registers
  type cpu_regs is array (0 to CMD_REGS - 1) of std_logic_vector(CMD_WIDTH - 1 downto 0);

  --! Shift register for indexing into the CPU regs for results
  type t_wr_shift is array (0 to 1) of integer range -1 to 15;

  --! Port into the cpu_interpreter
  type t_interpreter_port is record
    --! Command to the ALU
    cmd : cpu_cmds;
    --! argument bits
    cmd_bits : std_logic_vector(11 downto 0);
  end record t_interpreter_port;

  --! State machine for the interpreter
  type t_sm_interp is (execute, jmp_halt, halted);

  --! Converts a bitcode nibble into a CPU command
  pure function read_instruction(
  instruction_nibble : in std_logic_vector(3 downto 0)
  ) return cpu_cmds;

  --! Returns a bool indicating whether a check was true or false
  pure function read_check_register(
  command_bits   : std_logic_vector(11 downto 0);
  registers : in cpu_regs
  ) return t_decoder_jmp_port;

  pure function check_inactive return t_decoder_jmp_port;

  --! convert a 4 wide std_logic_vector into an index for the CPU registers
  pure function to_idx(
    check_byte : in std_logic_vector(3 downto 0)
    ) return integer;
end package;

package body interpreter_types is
  --! Converts a bitcode nibble into a CPU command
  pure function read_instruction(
  instruction_nibble : std_logic_vector(3 downto 0)
  ) return cpu_cmds is
  variable command : cpu_cmds;
  begin
    case instruction_nibble is
      when "0000" => -- 0x0
        command := NOOP;
      when "0001" => -- 0x1
        command := HALT;
      when "0010" => -- 0x2
        command := HWPC;
      when "0011" => -- 0x3
        command := ADDI;
      when "0100" => -- 0x4
        command := SUBI;
      when "0101" => -- 0x5
        command := MULI;
      when "0110" => -- 0x6
        command := DIVI;
      when "0111" => -- 0x7
        command := MODI;
      when "1000" => -- 0x8
        command := CHKI;
      when "1001" => -- 0x9
        command := LDRI;
      when "1010" => -- 0xA
        command := SVRI;
      when "1011" => -- 0xB
        command := JMPC;
      when others => -- error handling, do nothing
        command := NOOP;
    end case;
  return command;
  end function;

  --! Returns a bool indicating whether a check was true or false
  pure function read_check_register(
  command_bits   : std_logic_vector(11 downto 0);
  registers : in cpu_regs
  ) return t_decoder_jmp_port is
    variable return_val : t_decoder_jmp_port;
  begin
    if (command_bits(0) = '1' and registers(CHECK_REGISTER)(GREATER_THAN_SIGNED_BIT) = '1') or
       (command_bits(1) = '1' and registers(CHECK_REGISTER)(GREATER_THAN_UNSIGNED_BIT) = '1') or
       (command_bits(2) = '1' and registers(CHECK_REGISTER)(LESS_THAN_SIGNED_BIT) = '1') or 
       (command_bits(3) = '1' and registers(CHECK_REGISTER)(LESS_THAN_UNSIGNED_BIT) = '1') or 
       (command_bits(4) = '1' and registers(CHECK_REGISTER)(EQUAL_TO_BIT) = '1') or
       (command_bits(5) = '1' and registers(CHECK_REGISTER)(NOT_EQUAL_TO_BIT) = '1') then
      return_val.sig_jmp := '1';
      return_val.address := registers(to_idx(command_bits(3 downto 0)));
    else
      return_val.sig_jmp := '0';
      return_val.address := (others => '0');
    end if;
    return return_val;
  end read_check_register;

  pure function check_inactive return t_decoder_jmp_port is
    variable return_value : t_decoder_jmp_port;
  begin
    return_value.sig_jmp := '0';
    return_value.address := (others => '0');
    return return_value;
  end check_inactive;

  --! convert a 4 wide std_logic_vector into an index for the CPU registers
  pure function to_idx(
    check_byte : in std_logic_vector(3 downto 0)
    ) return integer is
    variable index : integer;
    begin
      index := to_integer(unsigned(check_byte));
    return index;
    end function;
end interpreter_types;