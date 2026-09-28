#!/usr/bin/env python3
"""Play an SVF file on the Basys-2's JTAG chain (local addition, see UPSTREAM.md)."""

import argparse
import sys
import time

import usb1
from adepttool.device import get_devices
from adepttool.svf import Player, SvfError

parser = argparse.ArgumentParser(description='Play an SVF file over the Basys-2 USB.')
parser.add_argument('--device', type=int, help='Device index', default=0)
parser.add_argument('svf', help='The SVF file')
args = parser.parse_args()

with open(args.svf) as f:
    text = f.read()

with usb1.USBContext() as ctx:
    devs = get_devices(ctx)
    if args.device >= len(devs):
        print('No device {} found.'.format(args.device))
        sys.exit(1)
    dev = devs[args.device]
    dev.start()
    port = dev.djtg_ports[0]
    port.enable()
    player = Player(port, log=print)
    start = time.monotonic()
    try:
        n = player.play(text)
    except SvfError as e:
        print('SVF FAILED: {}'.format(e))
        sys.exit(1)
    finally:
        port.disable()
    print('SVF OK: {} statements, {} TDO checks passed, {:.1f} s'.format(
        n, player.checks, time.monotonic() - start))
