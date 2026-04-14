# Testing Environment Setup: GHDL + cocotb

This document describes how to set up a simulation and testing environment for this CPU using GHDL as the simulator and cocotb as the Python-based testbench framework.

---

## A Note on GHDL + cocotb

GHDL support in cocotb is **experimental**. Despite being a VHDL simulator, GHDL implements the VPI interface rather than VHPI, which means some VHDL-specific constructs are not accessible from the Python side — most notably 9-value signal resolution. For this project that is fine: we are driving std_logic ports and reading results, which works correctly. GHDL 2.0 or newer is required. GHDL 3.x or later is recommended.

---

## Prerequisites

### System packages

On a Debian/Ubuntu system:

```bash
sudo apt update
sudo apt install \
    ghdl \
    gtkwave \
    python3 \
    python3-pip \
    python3-venv \
    make \
    gcc
```

On Arch:

```bash
sudo pacman -S ghdl gtkwave python python-pip make gcc
```

On macOS with Homebrew:

```bash
brew install ghdl gtkwave python make
```

Verify GHDL is at least version 2.0:

```bash
ghdl --version
```

### Python environment

Use a virtual environment to keep cocotb isolated:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install cocotb
```

Verify the install:

```bash
cocotb-config --version
```

---

## Repository Test Structure

Tests live in a `tests/` directory alongside the RTL. Each module under test gets its own subdirectory with a `Makefile` and one or more Python test files.

```
.
├── rtl/
│   ├── alu.vhd
│   ├── regfile.vhd
│   ├── control.vhd
│   ├── bram.vhd
│   ├── uart.vhd
│   └── cpu.vhd
└── tests/
    ├── alu/
    │   ├── Makefile
    │   └── test_alu.py
    ├── regfile/
    │   ├── Makefile
    │   └── test_regfile.py
    ├── control/
    │   ├── Makefile
    │   └── test_control.py
    └── cpu/
        ├── Makefile
        ├── programs/
        │   └── fibonacci.hex
        └── test_cpu.py
```

---

## Makefile Template

Every test directory needs a Makefile. The pattern is the same for each module — just change the sources, toplevel, and module name.

```makefile
# Simulator and language
SIM              = ghdl
TOPLEVEL_LANG    = vhdl

# VHDL standard — use 2008 throughout
COMPILE_ARGS     = --std=08

# RTL sources — list dependencies first, toplevel last
VHDL_SOURCES  = $(PWD)/../../rtl/alu.vhd

# Entity name (must match the VHDL entity declaration exactly)
COCOTB_TOPLEVEL  = alu

# Python test module (filename without .py)
COCOTB_TEST_MODULES = test_alu

# Waveform output — comment out if you don't want a VCD
SIM_ARGS        += --vcd=waves.vcd

# cocotb's makefile does the rest
include $(shell cocotb-config --makefiles)/Makefile.sim
```

For modules that depend on others (e.g. `cpu.vhd` depends on everything), list all sources in dependency order:

```makefile
VHDL_SOURCES  = $(PWD)/../../rtl/regfile.vhd
VHDL_SOURCES += $(PWD)/../../rtl/alu.vhd
VHDL_SOURCES += $(PWD)/../../rtl/control.vhd
VHDL_SOURCES += $(PWD)/../../rtl/bram.vhd
VHDL_SOURCES += $(PWD)/../../rtl/uart.vhd
VHDL_SOURCES += $(PWD)/../../rtl/cpu.vhd
```

GHDL determines compilation order automatically, but listing sources in logical dependency order avoids confusion.

---

## Running Tests

From within a test subdirectory:

```bash
cd tests/alu
source ../../.venv/bin/activate
make
```

To run with waveform output explicitly set on the command line:

```bash
make SIM_ARGS="--vcd=waves.vcd"
```

To clean build artifacts:

```bash
make clean
```

To run all tests from the repo root, add a top-level Makefile target:

```makefile
# Root Makefile
.PHONY: test test-alu test-regfile test-control test-cpu

test: test-alu test-regfile test-control test-cpu

test-alu:
	$(MAKE) -C tests/alu

test-regfile:
	$(MAKE) -C tests/regfile

test-control:
	$(MAKE) -C tests/control

test-cpu:
	$(MAKE) -C tests/cpu
```

---

## Writing a Test

cocotb tests are async Python functions decorated with `@cocotb.test()`. The `dut` argument gives you access to every port on the top-level entity.

### Minimal example — ALU add operation

```python
# tests/alu/test_alu.py
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_add(dut):
    """ADD: result should be sum of inputs, carry in REXT"""

    # Drive inputs
    dut.op.value    = 0x6   # ADD opcode
    dut.a.value     = 0x0010
    dut.b.value     = 0x0005

    # Combinational block — just wait a delta cycle for signals to settle
    await Timer(1, units="ns")

    assert dut.result.value == 0x0015, \
        f"Expected 0x0015, got {hex(dut.result.value)}"
    assert dut.rext.value == 0x0000, \
        f"Expected no carry, got {hex(dut.rext.value)}"


@cocotb.test()
async def test_add_carry(dut):
    """ADD: carry out should appear in REXT bit 0"""

    dut.op.value = 0x6
    dut.a.value  = 0xFFFF
    dut.b.value  = 0x0001

    await Timer(1, units="ns")

    assert dut.result.value == 0x0000
    assert dut.rext.value   == 0x0001, "Expected carry in REXT[0]"


@cocotb.test()
async def test_div_by_zero(dut):
    """DIV by zero should set err output, not write result"""

    dut.op.value = 0x9   # DIV opcode
    dut.a.value  = 0x0042
    dut.b.value  = 0x0000

    await Timer(1, units="ns")

    assert dut.err.value == 1, "Expected err signal asserted on div/0"
```

### Clocked example — register file

For sequential logic, drive a clock and synchronize on edges:

```python
# tests/regfile/test_regfile.py
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_write_and_read(dut):
    """Write to a GP register and read it back"""

    # Start a 10ns clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst.value    = 1
    dut.wr_en.value  = 0
    await RisingEdge(dut.clk)
    dut.rst.value    = 0

    # Write 0xABCD to R7
    dut.wr_en.value  = 1
    dut.rd_idx.value = 7
    dut.wr_data.value = 0xABCD
    await RisingEdge(dut.clk)
    dut.wr_en.value  = 0

    # Read it back via ra_idx
    dut.ra_idx.value = 7
    await RisingEdge(dut.clk)

    assert dut.ra_val.value == 0xABCD, \
        f"Expected 0xABCD, got {hex(dut.ra_val.value)}"


@cocotb.test()
async def test_r0_always_zero(dut):
    """Writes to R0 must be discarded"""

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value     = 1
    await RisingEdge(dut.clk)
    dut.rst.value     = 0

    # Attempt to write to R0
    dut.wr_en.value   = 1
    dut.rd_idx.value  = 0
    dut.wr_data.value = 0xDEAD
    await RisingEdge(dut.clk)
    dut.wr_en.value   = 0

    dut.ra_idx.value  = 0
    await RisingEdge(dut.clk)

    assert dut.ra_val.value == 0x0000, \
        f"R0 should always be 0, got {hex(dut.ra_val.value)}"
```

---

## Viewing Waveforms

If `SIM_ARGS += --vcd=waves.vcd` is set, GHDL writes a VCD file after each run. Open it with GTKWave:

```bash
gtkwave waves.vcd
```

In GTKWave, expand the signal tree on the left, drag signals into the waveform view, and use the zoom controls to inspect timing. For the pipeline tests, adding all four pipeline register `valid` bits alongside the `PC` and `opcode` signals makes stall and flush behaviour easy to see.

For `.ghw` format (GHDL's native format, more detailed than VCD):

```makefile
SIM_ARGS += --wave=waves.ghw
```

```bash
gtkwave waves.ghw
```

---

## Known Limitations with GHDL + cocotb

**VPI not VHPI** — GHDL uses VPI to communicate with cocotb. This means you cannot read VHDL `std_ulogic` 9-value states (U, X, W, etc.) from Python — you will see them resolved to 0 or 1. For this project that is not a problem in practice.

**VHDL generics** — Accessing VHDL generics from cocotb Python code via GHDL is unreliable and may not work correctly. For testability, design your entities so that the interesting parameters can be observed through output ports rather than relying on Python-side generic reads. If you need to test multiple generic configurations (e.g. different DMEM sizes), use separate Makefile targets with `COMPILE_ARGS += -gDMEM_SIZE=256`.

**No force/release** — VPI force/release of signals is not supported by GHDL. Drive everything through normal port assignments.

**Simulation time** — GHDL defaults to a `1 ns` time resolution. All `Timer` calls in tests should use `"ns"` units unless you change the resolution in the VHDL entity's time specification.

---

## Suggested Test Plan

Work bottom-up — get the leaves passing before testing the full CPU.

| Module | What to test |
|--------|-------------|
| `alu.vhd` | All 16 opcodes. Carry/borrow in REXT. DIV/REM correctness and 16-cycle timing. Div-by-zero err signal. MUL high word in REXT. |
| `regfile.vhd` | Write and read all GP registers. Confirm R0–R6 reject programmer writes. Confirm R1/R5/R6 accept hardware writes on their dedicated paths. |
| `uart.vhd` | TX: drive a byte in, verify the correct serial bit sequence comes out. RX: drive a serial bit sequence in, verify the correct byte and RX_RDY appear. Overrun: send two bytes without reading, verify RX_OVR. |
| `control.vhd` | RAW hazard detection: back-to-back dependent instructions should produce the correct stall count. DIV stall: 16-cycle hold. Jump flush: two bubbles after a taken JIZ. |
| `cpu.vhd` | Load a small hex program (e.g. `fibonacci.hex`) into IMEM. Run for N cycles. Capture UTX calls and verify the byte sequence matches expected Fibonacci values. |
