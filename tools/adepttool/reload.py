#!/usr/bin/env python3
"""Make the FPGA reload its configuration (local addition, see UPSTREAM.md).

JPROGRAM clears the FPGA. With JP3 on ROM (Master Serial mode) it then
configures itself from the XCF02S flash, like after a power cycle.
"""

import sys
import time

import usb1
from adepttool.device import get_devices
from adepttool.jtag import Chain, Spartan3

with usb1.USBContext() as ctx:
    devs = get_devices(ctx)
    if not devs:
        print('No devices found.')
        sys.exit(1)
    dev = devs[0]
    dev.start()
    chain = Chain(dev.djtg_ports[0])
    chain.init()
    fpga = next(d for d in chain.devices if isinstance(d, Spartan3))
    fpga.jprogram()
    # get_status() re-shifts the current instruction: switch to BYPASS so
    # polling doesn't keep re-issuing JPROGRAM (and resetting the FPGA).
    fpga.prep_cmd(0x3f)
    deadline = time.monotonic() + 5
    while not fpga.get_status() & 0x20:
        if time.monotonic() > deadline:
            print('DONE did not go high: is JP3 on ROM and the flash programmed?')
            chain.close()
            sys.exit(1)
        time.sleep(0.05)
    print('FPGA reloaded from flash: DONE')
    chain.close()
