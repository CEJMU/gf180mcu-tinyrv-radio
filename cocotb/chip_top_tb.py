# SPDX-FileCopyrightText: © 2025 Project Template Contributors
# SPDX-License-Identifier: Apache-2.0

import os
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, Edge, RisingEdge, FallingEdge, ClockCycles
from cocotb.handle import Immediate
from cocotb.types import LogicArray, Logic, Range
from cocotb_tools.runner import get_runner

sim = os.getenv("SIM", "icarus")
pdk_root = os.getenv("PDK_ROOT", Path("~/.ciel").expanduser())
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_fd_sc_mcu7t5v0")
gl = os.getenv("GL", False)
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "chip_top"

CPU_CLK_FREQ = 20  # MHz

mem = {}
async def set_defaults(dut, program_path):
    global mem
    mem = {}

    lines = ()
    with open(program_path, "r") as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        mem[i] = LogicArray(int(line, base=16), Range(7, "downto", 0))

    dut.input_PAD.value = 2**6  # uart rx set to 1


async def enable_power(dut):
    dut.VDD.value = 1
    dut.VSS.value = 0


async def start_clock(clock, freq=20):
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


async def start_up(dut, program_path):
    global CPU_CLK_FREQ
    """Startup sequence"""
    await set_defaults(dut, program_path)
    if gl:
        await enable_power(dut)
    await start_clock(dut.clk_PAD, CPU_CLK_FREQ)
    await reset(dut.rst_n_PAD)

state = "RECV_COMMAND"
WRITE_CMD = 2
READ_CMD = 3
command_reg = LogicArray(0, Range(7, "downto", 0))
addr_reg = LogicArray(0, Range(23, "downto", 0))
datain_reg = LogicArray(0, Range(7, "downto", 0))
dataout_reg = LogicArray(0, Range(7, "downto", 0))
index = 0
mem_pattern = []
prev_sclk = 0


async def do_spi(dut):
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
    global prev_sclk

    sclk = dut.bidir_PAD.get()[1]
    if sclk == 1 and prev_sclk == 0:
        si = dut.bidir_PAD.get()[0]

        if dut.bidir_PAD.get()[2] == 0:
            state = "RECV_COMMAND"
            index = 7
        else:
            if state == "IDLE":
                state = "RECV_COMMAND"
                index = 7

            elif state == "RECV_COMMAND":
                if dut.bidir_PAD.get()[2] == 1:
                    command_reg[index] = si
                    if index == 0:
                        index = 23
                        state = "RECV_ADDR"
                    else:
                        index = index - 1

            elif state == "RECV_ADDR":
                addr_reg[index] = si
                if index == 0:
                    index = 7

                    if command_reg.to_unsigned() == READ_CMD:
                        state = "SEND_DATA"
                        addr_tmp = addr_reg[22:0].to_unsigned()
                        dataout_reg = mem[addr_tmp]

                        # First SEND_DATA iteration copied here
                        tmp = dut.input_PAD.get()
                        tmp[0] = dataout_reg[index]
                        dut.input_PAD.set(Immediate(tmp))

                        if index == 0:
                            state = "END"
                        else:
                            index = index - 1

                    elif command_reg.to_unsigned() == WRITE_CMD:
                        state = "RECV_DATA"
                        index = 7
                    else:
                        print("GOT UNKNOWN SPI COMMAND!!!!!")
                else:
                    index = index - 1

            elif state == "RECV_DATA":
                datain_reg[index] = si
                if index == 0:
                    mem[addr_reg.to_unsigned()] = LogicArray(datain_reg.to_unsigned(), Range(7, "downto", 0))

                    mem_pattern.append((addr_reg[22:0].to_unsigned(), datain_reg.to_unsigned()))
                    index = 7
                    addr_reg = LogicArray(addr_reg[22:0].to_unsigned() + 1, Range(23, "downto", 0))
                else:
                    index = index - 1

            elif state == "SEND_DATA":
                tmp = dut.input_PAD.get()
                tmp[0] = dataout_reg[index]
                dut.input_PAD.set(Immediate(tmp))

                if index == 0:
                    index = 7
                    addr_reg = LogicArray(addr_reg[22:0].to_unsigned() + 1, Range(23, "downto", 0))
                    addr_tmp = addr_reg.to_unsigned()
                    if addr_tmp in mem:
                        dataout_reg = mem[addr_reg.to_unsigned()]
                    else:
                        dataout_reg = LogicArray("XXXXXXXX", Range(7, "downto", 0))
                else:
                    index = index - 1

            elif state == "END":
                pass

    prev_sclk = sclk


uart_rx_bytes = list()  # List of bytes sent by the CPU to the tb
UART_RX_BAUD = 115200
# UART_RX_WAIT_CYCLES = (1e9 * (1.0 / UART_RX_BAUD)) / (1e3 * (1.0 / CPU_CLK_FREQ))
UART_RX_WAIT_CYCLES = 104
uart_rx_clk_counter = 0
uart_rx_bit_counter = 0
uart_rx_state = "IDLE"  # IDLE, WAIITNG, RECV
uart_rx_current_data = 0


async def do_uart_rx(dut):
    global uart_rx_bytes
    global UART_RX_WAIT_CYCLES
    global uart_rx_clk_counter
    global uart_rx_bit_counter
    global uart_rx_state
    global uart_rx_current_data

    cpu_tx = dut.bidir_PAD.get()[3]

    if uart_rx_state == "IDLE":
        if cpu_tx == 1:
            # No start condition. Doing nothing
            return

        uart_rx_state = "RECV"
        uart_rx_clk_counter = 1.5 * UART_RX_WAIT_CYCLES
        uart_rx_bit_counter = 0
        uart_rx_current_data = LogicArray(0, Range(7, "downto", 0))

    elif uart_rx_state == "RECV":
        uart_rx_clk_counter -= 1

        if uart_rx_clk_counter != 0:
            return

        uart_rx_clk_counter = UART_RX_WAIT_CYCLES
        if uart_rx_bit_counter <= 7:
            uart_rx_current_data[uart_rx_bit_counter] = cpu_tx
            uart_rx_bit_counter += 1
        else:
            if cpu_tx == 0:
                print("Expected to see UART stop condition on rx!")
            else:
                uart_rx_state = "IDLE"
                uart_rx_bytes.append(chr(uart_rx_current_data.to_unsigned()))


UART_TX_BAUD = 115200
# UART_TX_WAIT_CYCLES = (1e9 * (1.0 / UART_RX_BAUD)) / (1e3 * (1.0 / CPU_CLK_FREQ))
UART_TX_WAIT_CYCLES = 104
uart_tx_clk_counter = 0
uart_tx_bit_counter = 0
uart_tx_state = "IDLE"  # IDLE, TX, END
uart_tx_current_data = 0
uart_tx_enable = 0


async def do_uart_tx(dut):
    global UART_TX_WAIT_CYCLES
    global uart_tx_clk_counter
    global uart_tx_bit_counter
    global uart_tx_state
    global uart_tx_current_data
    global uart_tx_enable

    if uart_tx_enable == 0:
        return

    cpu_rx_in = 1

    if uart_tx_state == "IDLE":
        cpu_rx_in = 0

        uart_tx_state = "TX"
        uart_tx_clk_counter = 1 * UART_TX_WAIT_CYCLES
        uart_tx_bit_counter = 0

    elif uart_tx_state == "TX":
        uart_tx_clk_counter -= 1

        if uart_tx_clk_counter != 0:
            return

        uart_tx_clk_counter = UART_TX_WAIT_CYCLES
        if uart_tx_bit_counter <= 7:
            cpu_rx_in = uart_tx_current_data[uart_tx_bit_counter]
            uart_tx_bit_counter += 1
        else:
            uart_tx_state = "IDLE"
            cpu_rx_in = 1
            uart_tx_enable = 0

    # Set CPU rx input to the computed value
    tmp = dut.input_PAD.get()
    tmp[6] = cpu_rx_in
    dut.input_PAD.set(Immediate(tmp))


i2c_state = "IDLE"
prev_scl = 1
prev_sda = 1
i2c_addr = 0
i2c_cmd = 0
i2c_counter = 0
i2c_index = 3
i2c_recv = []
i2c_current_recv = LogicArray(0, Range(7, "downto", 0))
async def do_i2c_slave(dut):
    global i2c_state
    global prev_scl
    global i2c_addr
    global i2c_cmd
    global i2c_counter
    global i2c_index
    global i2c_recv
    global i2c_current_recv
    global prev_sda

    # Some random values
    i2c_send = [
        LogicArray(37, Range(7, "downto", 0)),
        LogicArray(29, Range(7, "downto", 0)),
        LogicArray(204, Range(7, "downto", 0)),
        LogicArray(103, Range(7, "downto", 0))
    ]

    sda_in = dut.bidir_PAD.get()[9]
    scl = dut.bidir_PAD.get()[8]

    # if scl == 1 and prev_scl == 1 and sda_in == 1 and prev_sda == 0:
    if scl == 1 and prev_scl == 1 and sda_in != prev_sda:
        i2c_state = "IDLE"

    elif i2c_state == "IDLE":
        # I2C start condition
        if sda_in == 0:
            i2c_state = "START"
            i2c_index = 3

    elif i2c_state == "START":
        if sda_in == 0 and scl == 0 and prev_scl == 1:
            i2c_state = "R_ADDR"
            i2c_addr = LogicArray(0, Range(6, "downto", 0))
            i2c_counter = 6

    elif prev_scl == 0 and scl == 1:
        if i2c_state == "R_ADDR":
            # Posedge of scl
            i2c_addr[i2c_counter] = sda_in

        elif i2c_state == "R_CMD":
            i2c_cmd = sda_in

        elif i2c_state == "WRITE":
            i2c_current_recv[i2c_counter] = sda_in

    elif prev_scl == 1 and scl == 0:
        if i2c_state == "R_ADDR":
            if i2c_counter > 0:
                i2c_counter -= 1
            else:
                i2c_state = "R_CMD"

        elif i2c_state == "R_CMD":
            i2c_counter = 0
            i2c_state = "T_ACK"

        elif i2c_state == "T_ACK":
            i2c_counter = 7
            i2c_index = 3
            if i2c_cmd == 1:
                i2c_state = "READ"
            else:
                i2c_state = "WRITE"

        elif i2c_state == "WRITE":
            if i2c_counter > 0:
                i2c_counter -= 1
            else:
                i2c_recv.append(i2c_current_recv.to_unsigned())
                i2c_index -= 1
                i2c_counter = 7
                i2c_state = "WRITE_ACK"

        elif i2c_state == "WRITE_ACK":
            i2c_state = "WRITE"

        elif i2c_state == "READ":
            if i2c_counter > 0:
                i2c_counter -= 1
            else:
                i2c_index -= 1

                if i2c_index < 0:
                    i2c_index = 0

                i2c_counter = 7
                i2c_state = "READ_ACK"

        elif i2c_state == "READ_ACK":
            i2c_state = "READ"

    prev_scl = scl
    prev_sda = sda_in

    tmp = dut.bidir_PAD.get()
    for i in range(len(tmp)):
        tmp[i] = Logic("Z")

    if i2c_state in ["T_ACK", "WRITE_ACK"]:
        tmp[9] = Logic(1)
    elif i2c_state == "READ":
        tmp[9] = i2c_send[3-i2c_index][i2c_counter]

    dut.bidir_PAD.set(Immediate(tmp))


@cocotb.test()
async def test_fibonacci(dut):
    global mem_pattern
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

    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut, "../fib.txt")
    logger.info("Testing basic fibonacci program")

    # Wait for a number of clock cycles
    for i in range(10000):
        await ClockCycles(dut.clk_PAD, 1)

        await do_spi(dut)

    # Check the end result of the counter
    print(mem_pattern)
    assert mem_pattern == mem_pattern_correct
    logger.info("Done!")


@cocotb.test()
async def test_uart_tx(dut):
    global uart_rx_bytes

    uart_rx_bytes = list()  # List of bytes sent by the CPU to the tb

    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut, "../uart_tx_test.txt")
    logger.info("Testing UART transmission")

    # Wait for a number of clock cycles
    # for i in range(150000):
    for i in range(50000):
        await ClockCycles(dut.clk_PAD, 1)

        await do_spi(dut)
        await do_uart_rx(dut)

    # Check the end result of the counter
    print(uart_rx_bytes)
    assert uart_rx_bytes == ["H", "a", "l", "l", "o", "!"]
    # assert mem_pattern == mem_pattern_correct

    logger.info("Done!")


@cocotb.test()
async def test_uart_rx(dut):
    global uart_tx_enable
    global uart_tx_current_data
    global uart_rx_bytes

    uart_rx_bytes = list()  # List of bytes sent by the CPU to the tb
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut, "../uart_rx_test.txt")
    logger.info("Testing UART receiving")

    to_send = ["L", "i", "n", "z"]
    counter = -1  # HACK
    next_i = 8000
    increment = 40000

    # Wait for a number of clock cycles
    for i in range(180000):
        await ClockCycles(dut.clk_PAD, 1)

        if i >= next_i:
            if uart_tx_enable == 0 and counter < len(to_send) - 1:
                counter += 1
                uart_tx_enable = 1
                uart_tx_current_data = LogicArray(ord(to_send[counter]), Range(7, "downto", 0))
                next_i = i + increment

        await do_spi(dut)
        await do_uart_rx(dut)
        await do_uart_tx(dut)

    # Check the end result of the counter
    print(uart_rx_bytes)
    assert uart_rx_bytes == to_send
    logger.info("Done!")


@cocotb.test()
async def test_i2c_rw(dut):
    global uart_tx_enable
    global uart_tx_current_data
    global uart_rx_bytes
    global i2c_recv

    uart_rx_bytes = list()  # List of bytes sent by the CPU to the tb
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut, "../i2c_rw_test.txt")
    logger.info("Testing I2C")

    # Wait for a number of clock cycles
    for i in range(50000):
        await ClockCycles(dut.clk_PAD, 1)

        await do_spi(dut)
        await do_uart_rx(dut)
        await do_uart_tx(dut)
        await do_i2c_slave(dut)

    # Check the end result of the counter
    print(i2c_recv)
    assert i2c_recv == [0x78, 37, 37, 37, 29, 37, 29, 37, 29, 204, 103]
    logger.info("Done!")


@cocotb.test()
async def test_gpio(dut):
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut, "../gpio_test.txt")
    logger.info("Testing GPIO")

    # Test 0111 + 1 = 1000
    tmp = dut.input_PAD.get()
    tmp[4] = 0
    tmp[3] = 1
    tmp[2] = 1
    tmp[1] = 1
    dut.input_PAD.set(Immediate(tmp))
    # Wait for a number of clock cycles

    assert dut.bidir_PAD.get()[7:4] == 0b0000
    for i in range(5000):
        await ClockCycles(dut.clk_PAD, 1)
        await do_spi(dut)

    # Check the end result of the counter
    assert dut.bidir_PAD.get()[7:4] == 0b1000

    # Test 1010 + 1 = 1011
    tmp = dut.input_PAD.get()
    tmp[4] = 1
    tmp[3] = 0
    tmp[2] = 1
    tmp[1] = 0
    dut.input_PAD.set(Immediate(tmp))
    # Wait for a number of clock cycles

    for i in range(5000):
        await ClockCycles(dut.clk_PAD, 1)
        await do_spi(dut)

    # Check the end result of the counter
    assert dut.bidir_PAD.get()[7:4] == 0b1011
    logger.info("Done!")


@cocotb.test()
async def test_wspr(dut):
    # Create a logger for this testbench
    logger = logging.getLogger("my_testbench")

    logger.info("Startup sequence...")

    # Start up
    await start_up(dut, "../wspr_test.txt")
    logger.info("Testing WSPR")

    for i in range(600000):
        await ClockCycles(dut.clk_PAD, 1)
        await do_spi(dut)

        if i == 12000:
            tmp = dut.input_PAD.get()
            tmp[1] = 1
            dut.input_PAD.set(Immediate(tmp))

    print("WSPR TEST DONE. CHECK WAVEFORM!")
    logger.info("Done!")


def chip_top_runner():

    proj_path = Path(__file__).resolve().parent

    sources = []
    defines = {f"SLOT_{slot.upper()}": True}
    includes = [proj_path / "../src/"]

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        # We use the powered netlist
        sources.append(proj_path / f"../final/pnl/{hdl_toplevel}.pnl.v")

        defines = {"FUNCTIONAL": True, "USE_POWER_PINS": True}
    else:
        sources.append(proj_path / "../rtl/constants.sv")
        sources.append(proj_path / "../rtl/src/slot_defines.svh")
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
        sources.append(proj_path / "../rtl/src/uart_rx.v")
        sources.append(proj_path / "../rtl/src/cordic_slice.v")
        sources.append(proj_path / "../rtl/src/instructioncounter.sv")

    sources += [
        # IO pad models
        Path(pdk_root) / pdk / "libs.ref/gf180mcu_fd_io/verilog/gf180mcu_fd_io.v",
        Path(pdk_root) / pdk / "libs.ref/gf180mcu_fd_io/verilog/gf180mcu_ws_io.v",

        # SRAM macros
        # Path(pdk_root) / pdk / "libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram64x8m8wm1.v",

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
