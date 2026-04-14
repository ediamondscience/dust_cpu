# A 16-bit Pipelined CPU in VHDL

A small, clean, Harvard-architecture CPU targeting Lattice FPGAs with the open-source toolchain. Fits in a modest slice budget, speaks UART, and is programmable enough to do something interesting.

## What it is

- 16-bit data path, 16-bit fixed-width instructions
- 16 registers (7 reserved, 9 general-purpose)
- 16 opcodes: arithmetic, logic, load/store, compare, jump, and UART I/O
- 4-stage pipeline (IF → ID → EX → WB) with stall-based hazard handling
- Harvard architecture — instruction and data memory are separate BRAMs
- Iterative 16-cycle divider for DIV and REM
- UART TX and RX with a programmer-visible status register
- BRAM initialized at synthesis time from a plain hex file — no bootloader needed

## What it is not

- There is no stack and no CALL/RET instruction
- There are no interrupts — all I/O is polled
- LDI is 8-bit immediate only; use LDI + LDIH for full 16-bit constants
- There is no assembler yet

## Toolchain

Built for the open-source Lattice flow:

```
yosys      — synthesis
nextpnr    — place and route
ecppack    — bitstream packing (ECP5) or equivalent for your device
```

Should work with any Lattice family supported by nextpnr.

## Repository Structure

```
.
├── rtl/
│   ├── top.vhd          -- board top-level (clock, reset, UART pins)
│   ├── cpu.vhd          -- CPU top, wires pipeline stages together
│   ├── regfile.vhd      -- 16×16 register file with reserved reg enforcement
│   ├── alu.vhd          -- ALU and iterative divider
│   ├── control.vhd      -- pipeline control, hazard detection, stall/flush
│   ├── bram.vhd         -- IMEM and DMEM, textio init function
│   └── uart.vhd         -- UART TX and RX
├── programs/
│   └── fibonacci.hex    -- example program: Fibonacci sequence over UART
├── SPEC.md              -- full architecture and ISA specification
└── README.md
```

## Memory Model

Instruction memory and data memory are separate BRAMs. Both are word-addressed — each address points to a 16-bit word. The data memory size is a VHDL generic.

Programs are loaded by baking a `.hex` file into the IMEM BRAM at synthesis time using a VHDL `impure function` and `std.textio`. The hex file path is a generic. To change the program, change the file and re-synthesize.

Hex file format — one 16-bit word per line, no prefix:

```
0000
27CD
37AB
...
```

## ISA Quick Reference

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| `0x0` | `AND Ra, Rb, Rd` | `Rd ← Ra & Rb` |
| `0x1` | `HLT` | Halt |
| `0x2` | `LDI Rd, imm8` | `Rd ← 0x00 \|\| imm8` |
| `0x3` | `LDIH Rd, imm8` | `Rd[15:8] ← imm8`, low byte unchanged |
| `0x4` | `LDM Ra, Rd` | `Rd ← DMEM[Ra]` |
| `0x5` | `STM Ra, Rb` | `DMEM[Ra] ← Rb` |
| `0x6` | `ADD Ra, Rb, Rd` | `Rd ← Ra + Rb`, `REXT ← carry` |
| `0x7` | `SUB Ra, Rb, Rd` | `Rd ← Ra − Rb`, `REXT ← borrow` |
| `0x8` | `MUL Ra, Rb, Rd` | `Rd ← (Ra × Rb)[15:0]`, `REXT ← (Ra × Rb)[31:16]` |
| `0x9` | `DIV Ra, Rb, Rd` | `Rd ← Ra ÷ Rb` (16 cycles) |
| `0xA` | `CMP Ra, Rb, mode` | `RCMP ← result` (0 = true, 1 = false) |
| `0xB` | `JIZ Ra, Rb` | `if Rb == 0: PC ← Ra` |
| `0xC` | `REM Ra, Rb, Rd` | `Rd ← Ra mod Rb` (16 cycles) |
| `0xD` | `UTX Ra` | Transmit `Ra[7:0]` over UART |
| `0xE` | `URX Rd` | `Rd ← UART RX buffer` |
| `0xF` | *(reserved)* | Treated as HLT |

`0x0000` is the canonical NOP (AND R0, R0 → R0). CMP mode `0x0` = equality, `0x1` = greater-than.

Full encoding, pipeline behaviour, hazard handling, and reserved register definitions are in [SPEC.md](SPEC.md).

## Reserved Registers

| Reg | Name | Description |
|-----|------|-------------|
| R0 | `ZERO` | Always 0. Writes discarded. |
| R1 | `ERR` | Hardware error codes. `0x0001` = division by zero. |
| R2 | `USTAT` | UART status. Bit 0 = TX busy, bit 1 = RX ready, bit 2 = RX overrun. |
| R3 | `PC` | Program counter. Readable as a source operand. |
| R4 | `PSTART` | Program start address. Hardwired `0x0000`. |
| R5 | `RCMP` | Compare result. Written by CMP. 0 = true, 1 = false. |
| R6 | `REXT` | ALU extension. MUL high word; ADD/SUB carry or borrow in bit 0. |

General-purpose registers are R7–R15.

## Unconditional vs Conditional Jumps

There is one jump instruction: `JIZ Ra, Rb` — jump to address in Ra if Rb is zero.

- **Unconditional:** `JIZ Ra, R0` — R0 is always zero, so always taken.
- **Conditional:** `CMP ..., RCMP` then `JIZ Ra, RCMP` — taken if the comparison was true.
- **Jump if NOT:** use a skip pattern — `JIZ skip, RCMP` / `JIZ target, R0` / `skip:`.

## Example — Fibonacci over UART

The canonical demo program runs the Fibonacci sequence and transmits each value as two bytes (high then low) over UART at 115200 baud. It loops indefinitely. Connect a terminal to watch it count.

## Contributing

This is a hobby project. The most useful additions would be an assembler, a testbench, and possibly a `NOT` or `OR` instruction if a future revision finds a spare opcode slot.
