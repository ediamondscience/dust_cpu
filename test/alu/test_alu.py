"""Cocotb tests for algorithmic_logic_unit.

Ports (g_WIDTH=16 default):
  i_clk, i_cmd (t_alu_cmd enum), i_arg1/i_arg2 (16-bit slv)
  o_result (lower 16 bits of full result), o_carry (upper 16 bits), o_error

t_alu_cmd enum positions as seen via GHDL VPI:
  ALU_NOP=0, ALU_ADD=1, ALU_SUB=2, ALU_MUL=3, ALU_DIV=4, ALU_REM=5

Error codes (bit positions in o_error):
  bit 4 (0x0010) -> divide by zero
  bit 5 (0x0020) -> remainder by zero
  bit 6 (0x0040) -> unknown command
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

ALU_NOP = 0
ALU_ADD = 1
ALU_SUB = 2
ALU_MUL = 3
ALU_DIV = 4
ALU_REM = 5

WIDTH = 16


async def init(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    dut.i_cmd.value = ALU_NOP
    dut.i_arg1.value = 0
    dut.i_arg2.value = 0
    await RisingEdge(dut.i_clk)


async def run_op(dut, cmd, arg1, arg2):
    """Drive an operation, clock it through, return (result, carry, error)."""
    dut.i_cmd.value = cmd
    dut.i_arg1.value = arg1
    dut.i_arg2.value = arg2
    await RisingEdge(dut.i_clk)
    await Timer(1, unit="ps")
    return (
        int(dut.o_result.value),
        int(dut.o_carry.value),
        int(dut.o_error.value),
    )


@cocotb.test()
async def test_add(dut):
    """ALU_ADD: carry:result holds the full 32-bit sum."""
    await init(dut)

    cases = [
        (0,      0,      0),
        (1,      1,      2),
        (100,    200,    300),
        (0xFFFF, 1,      0x10000),
        (0xFFFF, 0xFFFF, 0x1FFFE),
    ]
    for arg1, arg2, expected in cases:
        result, carry, error = await run_op(dut, ALU_ADD, arg1, arg2)
        assert error == 0, f"ADD {arg1} + {arg2}: unexpected error {error:#06x}"
        full = (carry << WIDTH) | result
        assert full == expected, f"ADD {arg1} + {arg2}: expected {expected}, got {full}"


@cocotb.test()
async def test_sub(dut):
    """ALU_SUB: 16-bit unsigned subtraction."""
    await init(dut)

    cases = [
        (10,     3,      7),
        (0,      0,      0),
        (0xFFFF, 0xFFFF, 0),
    ]
    for arg1, arg2, expected in cases:
        result, carry, error = await run_op(dut, ALU_SUB, arg1, arg2)
        assert error == 0, f"SUB {arg1} - {arg2}: unexpected error {error:#06x}"
        full = (carry << WIDTH) | result
        assert full == expected, f"SUB {arg1} - {arg2}: expected {expected}, got {full}"


@cocotb.test()
async def test_mul(dut):
    """ALU_MUL: 16x16 multiply, result split across carry (upper) and result (lower)."""
    await init(dut)

    cases = [
        (0,      0,      0),
        (1,      1,      1),
        (3,      4,      12),
        (0x100,  0x100,  0x10000),
        (0xFFFF, 0xFFFF, 0xFFFE0001),
    ]
    for arg1, arg2, expected in cases:
        result, carry, error = await run_op(dut, ALU_MUL, arg1, arg2)
        assert error == 0, f"MUL {arg1} * {arg2}: unexpected error {error:#06x}"
        full = (carry << WIDTH) | result
        assert full == expected, f"MUL {arg1} * {arg2}: expected {expected:#010x}, got {full:#010x}"


@cocotb.test()
async def test_div(dut):
    """ALU_DIV: integer division."""
    await init(dut)

    cases = [
        (10,     2,  5),
        (100,    4,  25),
        (7,      3,  2),
        (0xFFFF, 1,  0xFFFF),
    ]
    for arg1, arg2, expected in cases:
        result, carry, error = await run_op(dut, ALU_DIV, arg1, arg2)
        assert error == 0, f"DIV {arg1} / {arg2}: unexpected error {error:#06x}"
        full = (carry << WIDTH) | result
        assert full == expected, f"DIV {arg1} / {arg2}: expected {expected}, got {full}"


@cocotb.test()
async def test_rem(dut):
    """ALU_REM: modulo."""
    await init(dut)

    cases = [
        (10,     3,       1),
        (100,    7,       2),
        (8,      4,       0),
        (0xFFFF, 0x1000,  0xFFFF % 0x1000),
    ]
    for arg1, arg2, expected in cases:
        result, carry, error = await run_op(dut, ALU_REM, arg1, arg2)
        assert error == 0, f"REM {arg1} mod {arg2}: unexpected error {error:#06x}"
        full = (carry << WIDTH) | result
        assert full == expected, f"REM {arg1} mod {arg2}: expected {expected}, got {full}"


@cocotb.test()
async def test_div_by_zero(dut):
    """ALU_DIV with arg2=0 raises error bit 4 (0x0010)."""
    await init(dut)
    _, _, error = await run_op(dut, ALU_DIV, 42, 0)
    assert error == 0x0010, f"Expected error 0x0010, got {error:#06x}"


@cocotb.test()
async def test_rem_by_zero(dut):
    """ALU_REM with arg2=0 raises error bit 5 (0x0020)."""
    await init(dut)
    _, _, error = await run_op(dut, ALU_REM, 42, 0)
    assert error == 0x0020, f"Expected error 0x0020, got {error:#06x}"


@cocotb.test()
async def test_nop_unknown_cmd(dut):
    """Any unrecognised command raises error bit 6 (0x0040)."""
    await init(dut)
    _, _, error = await run_op(dut, ALU_NOP, 0, 0)
    assert error == 0x0040, f"Expected error 0x0040 on NOP/unknown, got {error:#06x}"