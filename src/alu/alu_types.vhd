library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Instruction and port definitions for the cpu project.
package alu_types is
  --! Different operational commands to the algorithmic logic unit.
  type t_alu_cmd is (
    --! ALU NOOP
    ALU_NOP,
    --! add two numbers
    ALU_ADD,
    --! subtract two numbers
    ALU_SUB,
    --! multiply two numbers
    ALU_MUL,
    --! divide two numbers
    ALU_DIV,
    --! take the remainder of a number divided by another
    ALU_REM
  );
end package;