# SPDX-FileCopyrightText: © 2025 Project Template Contributors
# SPDX-License-Identifier: Apache-2.0

import os
import random
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, Edge, RisingEdge, FallingEdge, ClockCycles
from cocotb.types import LogicArray, Logic, Range
from cocotb_tools.runner import get_runner

sim = os.getenv("SIM", "icarus")
pdk_root = os.getenv("PDK_ROOT", Path("~/.ciel").expanduser())
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_fd_sc_mcu7t5v0")
gl = os.getenv("GL", False)

hdl_toplevel = "chip_top"


async def set_defaults(dut):
    global mem
    mem = {}

    # for i in range(2**24):
    #     mem.append(LogicArray(random.randint(0, 255), Range(7, "downto", 0)))

    lines = ()
    with open("../fib.txt", "r") as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        mem[i] = LogicArray(int(line, base=16), Range(7, "downto", 0))

    print(mem)
    dut.input_PAD.value = 0


async def enable_power(dut):
    dut.VDD.value = 1
    dut.VSS.value = 0


async def start_clock(clock, freq=10):
    """Start the clock @ freq MHz"""
    c = Clock(clock, 1 / freq * 1000, "ns")
    cocotb.start_soon(c.start())


async def reset(reset, active_low=True, time_ns=1000):
    """Reset dut"""
    cocotb.log.info("Reset asserted...")

    reset.value = not active_low
    await Timer(time_ns, "ns")
    reset.value = active_low

    cocotb.log.info("Reset deasserted.")


async def start_up(dut):
    """Startup sequence"""
    await set_defaults(dut)
    if gl:
        await enable_power(dut)
    await start_clock(dut.clk_PAD)
    await reset(dut.rst_n_PAD)

state = "IDLE"
mem = list()
WRITE_CMD = 2
READ_CMD = 3
command_reg = LogicArray(0, Range(7, "downto", 0))
addr_reg = LogicArray(0, Range(23, "downto", 0))
datain_reg = LogicArray(0, Range(7, "downto", 0))
dataout_reg = LogicArray(0, Range(31, "downto", 0))
index = 0
mem_pattern = []
mem_pattern_correct = [
    (160, 2), (161, 0), (162, 0), (163, 0),
    (164, 3), (165, 0), (166, 0), (167, 0),
    (168, 5), (169, 0), (170, 0), (171, 0),
    (172, 8), (173, 0), (174, 0), (175, 0),
    (176, 13), (177, 0), (178, 0), (179, 0),
    (180, 21), (181, 0), (182, 0), (183, 0),
    (184, 34), (185, 0), (186, 0), (187, 0),
    (188, 55), (189, 0), (190, 0), (191, 0),
    (192, 89), (193, 0), (194, 0), (195, 0),
]


def do_spi(dut):
    global state
    global mem
    global WRITE_CMD
    global READ_CMD
    global command_reg
    global addr_reg
    global datain_reg
    global dataout_reg
    global index
    global mem_pattern

    si = dut.bidir_PAD.get()[0]

    if dut.bidir_PAD.get()[2] == 0:
        state = "IDLE"
        index = 7
    else:
        if state == "IDLE":
            state = "RECV_COMMAND"
            index = 7

        elif state == "RECV_COMMAND":
            command_reg[index] = si
            if index == 0:
                index = 23
                state = "RECV_ADDR"
            else:
                index = index - 1

        elif state == "RECV_ADDR":
            addr_reg[index] = si
            if index == 0:
                index = 31
                addr_tmp = addr_reg.integer
                # print("====================================")
                # print(f"Received cmd: {command_reg.integer}")
                # print("====================================")

                if command_reg.integer == READ_CMD:
                    state = "SEND_DATA"
                    addr_tmp = addr_reg.integer
                    # print("====================================")
                    # print(f"Received addr: {addr_tmp}")
                    # print("====================================")
                    dataout_reg[31:24] = mem[addr_tmp]
                    dataout_reg[23:16] = mem[addr_tmp + 1]
                    dataout_reg[15:8] = mem[addr_tmp + 2]
                    dataout_reg[7:0] = mem[addr_tmp + 3]

                    # First SEND_DATA iteration copied here
                    tmp = dut.input_PAD.get()
                    tmp[1] = dataout_reg[index]
                    dut.input_PAD.set(tmp)
                    if index == 0:
                        state = "END"
                    else:
                        index = index - 1

                else:
                    state = "RECV_DATA"
                    index = 7
            else:
                index = index - 1

        elif state == "WAITING":
            state = "SEND_DATA"
            addr_tmp = addr_reg[23:0].integer
            dataout_reg[31:24] = mem[addr_tmp]
            dataout_reg[23:16] = mem[addr_tmp + 1]
            dataout_reg[15:8] = mem[addr_tmp + 2]
            dataout_reg[7:0] = mem[addr_tmp + 3]

        elif state == "RECV_DATA":
            datain_reg[index] = si
            if index == 0:
                mem[addr_reg.integer] = datain_reg
                print("============================")
                print(f"Wrote {datain_reg.integer} to {addr_reg.integer}")
                mem_pattern.append((addr_reg.integer, datain_reg.integer))
                index = 7
                addr_reg = LogicArray(addr_reg.integer + 1, Range(23, "downto", 0))
            else:
                index = index - 1

        elif state == "SEND_DATA":
            tmp = dut.input_PAD.get()
            tmp[1] = dataout_reg[index]
            dut.input_PAD.set(tmp)
            if index == 0:
                state = "END"
            else:
                index = index - 1

        elif state == "END":
            pass


@cocotb.test()
async def test_counter(dut):
    global mem_pattern
    global mem_pattern_correct
    """Run the counter test"""

    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut)

    logger.info("Running the test...")

    # Wait for a number of clock cycles
    for i in range(30000):
        await ClockCycles(dut.clk_PAD, 1)
        if dut.bidir_PAD.get()[1] == 1:
            do_spi(dut)

    # Check the end result of the counter
    assert mem_pattern == mem_pattern_correct

    logger.info("Done!")


def chip_top_runner():

    proj_path = Path(__file__).resolve().parent

    sources = []
    defines = {}
    includes = []

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        # We use the powered netlist
        sources.append(proj_path / f"../final/pnl/{hdl_toplevel}.pnl.v")

        defines = {"FUNCTIONAL": True, "USE_POWER_PINS": True}
    else:
        sources.append(proj_path / "../rtl/src/constants.sv")
        sources.append(proj_path / "../rtl/src/chip_top.sv")
        sources.append(proj_path / "../rtl/src/chip_core.sv")
        sources.append(proj_path / "../rtl/src/cpu.sv")
        sources.append(proj_path / "../rtl/src/alu.sv")
        sources.append(proj_path / "../rtl/src/lo_gen.v")
        sources.append(proj_path / "../rtl/src/csr.sv")
        sources.append(proj_path / "../rtl/src/memory.sv")
        sources.append(proj_path / "../rtl/src/dsmod.v")
        sources.append(proj_path / "../rtl/src/regs.sv")
        sources.append(proj_path / "../rtl/src/freq_generator.sv")
        sources.append(proj_path / "../rtl/src/spi_master.sv")
        sources.append(proj_path / "../rtl/src/control.sv")
        sources.append(proj_path / "../rtl/src/i2c_master.sv")
        sources.append(proj_path / "../rtl/src/cordic_iterative.v")
        sources.append(proj_path / "../rtl/src/imm_gen.sv")
        sources.append(proj_path / "../rtl/src/uart_tx.v")
        sources.append(proj_path / "../rtl/src/cordic_slice.v")
        sources.append(proj_path / "../rtl/src/instructioncounter.sv")

    sources += [
        # IO pad models
        Path(pdk_root) / pdk / "libs.ref/gf180mcu_fd_io/verilog/gf180mcu_fd_io.v",
        Path(pdk_root) / pdk / "libs.ref/gf180mcu_fd_io/verilog/gf180mcu_ws_io.v",
        
        # SRAM macros
        Path(pdk_root) / pdk / "libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram64x8m8wm1.v",
        
        # Custom IP
        proj_path / "../ip/gf180mcu_ws_ip__id/vh/gf180mcu_ws_ip__id.v",
        proj_path / "../ip/gf180mcu_ws_ip__logo/vh/gf180mcu_ws_ip__logo.v",
    ]

    build_args = []

    if sim == "icarus":
        # For debugging
        # build_args = ["-Winfloop", "-pfileline=1"]
        build_args = ["-DSIM"]
        pass

    if sim == "verilator":
        build_args = ["--timing", "--trace", "--trace-fst", "--trace-structs"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        defines=defines,
        always=True,
        includes=includes,
        build_args=build_args,
        waves=True,
    )

    plusargs = []

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="chip_top_tb,",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    chip_top_runner()
