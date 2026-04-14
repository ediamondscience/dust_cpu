SIM ?= ghdl
TOPLEVEL_LANG = vhdl

VHDL_SOURCES = \
    $(abspath ../../src/alu/alu_types.vhd) \
    $(abspath ../../src/alu/algorithmic_logic_unit.vhd)

TOPLEVEL = algorithmic_logic_unit
COCOTB_TEST_MODULES = test_alu

GHDL_ARGS = --std=08

include $(shell cocotb-config --makefiles)/Makefile.sim