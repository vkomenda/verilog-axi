import itertools
import logging
import os
import random

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiLiteRam


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.m_count = len(dut.axil_simd_inst.m_axil_awvalid)

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.clk, dut.rst)
        self.axil_ram = [
            AxiLiteRam(AxiLiteBus.from_prefix(dut, f"m{k:02d}_axil"), dut.clk, dut.rst, size=2**16) for k in range(self.m_count)
        ]

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())
            for k in range(self.m_count):
                self.axil_ram[k].write_if.b_channel.set_pause_generator(generator())
                self.axil_ram[k].read_if.r_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())
            for k in range(self.m_count):
                self.axil_ram[k].write_if.aw_channel.set_pause_generator(generator())
                self.axil_ram[k].write_if.w_channel.set_pause_generator(generator())
                self.axil_ram[k].read_if.ar_channel.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test_write(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)
    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes*2):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset
            test_data = bytearray([x % 256 for x in range(length)])

            for k in range(tb.m_count):
                tb.axil_ram[k].write(addr, b'\xaa'*length)

            await tb.axil_master.write(addr, test_data)

            # tb.log.debug("%s", tb.axil_ram[0].hexdump_str((addr & ~0xf), (((addr & 0xf)+length-1) & ~0xf)+64))

            for k in range(tb.m_count):
                assert tb.axil_ram[k].read(addr, length) == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_read(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)
    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes*2):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset
            test_data = bytearray([x % 256 for x in range(length)])

            for k in range(tb.m_count):
                tb.axil_ram[k].write(addr, test_data)

            data = await tb.axil_master.read(addr, length)

            assert data.data == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    async def worker(master, offset, aperture, count=16):
        for k in range(count):
            length = random.randint(1, min(32, aperture))
            addr = offset+random.randint(0, aperture-length)
            tb.log.info("worker offset 0x%x, aperture 0x%x, length %d, addr 0x%x", offset, aperture, length, addr)
            test_data = bytearray([x % 256 for x in range(length)])

            await Timer(random.randint(1, 100), 'ns')

            await master.write(addr, test_data)

            await Timer(random.randint(1, 100), 'ns')

            data = await master.read(addr, length)
            assert data.data == test_data

    addr_width = tb.axil_master.write_if.address_width

    assert addr_width >= 4
    min_offset_width = min(12, addr_width - 4)
    extra_offset_width = max(1, addr_width - min_offset_width - 8)

    assert addr_width >= min_offset_width + extra_offset_width

    addr_bits = 1 << addr_width
    min_offset = 1 << min_offset_width
    workers = []

    for k in range(extra_offset_width):
        offset = min_offset * (2 ^ k)  # CAVEAT: << inside the loop leads to superfluous test failures
        aperture = min(min_offset, addr_bits - offset)
        workers.append(cocotb.start_soon(worker(tb.axil_master, offset, aperture, count=16)))

    while workers:
        await workers.pop(0).join()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    for test in [run_test_write, run_test_read]:

        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.generate_tests()

    factory = TestFactory(run_stress_test)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
cur_dir = os.path.abspath('.')

@pytest.mark.parametrize("m_count", [8])
@pytest.mark.parametrize("addr_width", [5, 16, 32])
@pytest.mark.parametrize("data_width", [8, 16, 32])
def test_axil_simd(request, m_count, addr_width, data_width):
    dut = "axil_simd"
    module = os.path.splitext(os.path.basename(__file__))[0]
    wrapper = f"{dut}_wrap_{m_count}"
    toplevel = wrapper

    print(f"wrapper {wrapper}")

    verilog_sources = [
        os.path.join(cur_dir, f"{wrapper}.v"),
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, f"{dut}_rd.v"),
        os.path.join(rtl_dir, f"{dut}_wr.v")
    ]

    print(f"verilog_sources {verilog_sources}")

    parameters = {}

    parameters['M_COUNT'] = m_count
    parameters['ADDR_WIDTH'] = addr_width
    parameters['DATA_WIDTH'] = data_width
    parameters['STRB_WIDTH'] = parameters['DATA_WIDTH'] // 8

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
