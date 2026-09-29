#!/usr/bin/env python3
"""Make yosys EDIF acceptable to ISE's ngdbuild for 9-bit-wide block RAMs.

Usage: tools/yosys-edif-fix.py design.edf   (rewrites the file in place)

Why
---
Spartan-3E block RAMs in 9-bit-wide configurations (RAMB16_S9, RAMB16_S9_S9,
RAMB16_S9_S18, ...) have one parity bit per port: DIP/DOP, DIPA/DOPA, ... ISE's
library declares these as 1-bit *buses* (e.g. DOPA[0:0]), but yosys'
write_edif writes every 1-bit port as a plain scalar. ngdbuild then sees a
different pin list and rejects the cell ("Symbol 'RAMB16_S9_S9' is not
supported in target 'spartan3e'").

What
----
For every cell definition named RAMB16_*, each scalar parity port
(DIP, DOP, DIPA, DOPA, DIPB, DOPB) becomes a 1-bit array, and every
connection to that port on an instance of that cell becomes a reference to
bit 0 of the array:

    (port DOPA (direction OUTPUT))
 -> (port (array (rename DOPA "DOPA[0:0]") 1) (direction OUTPUT))

    (portRef DOPA (instanceRef id00850))
 -> (portRef (member DOPA 0) (instanceRef id00850))

It relies on the layout yosys writes (one port or instance header per line).
Wider parity buses (e.g. the 2-bit DOP of RAMB16_S18) are already arrays and
are left alone. Running it twice is harmless.
"""

import re
import sys

PARITY_PORT = re.compile(r'D[IO]P[AB]?')

path = sys.argv[1]
lines = open(path).read().split('\n')

# Pass 1: cell definitions. Find scalar parity ports of RAMB16_* cells and
# rewrite them as 1-bit arrays; remember which (cell, port) pairs changed.
converted = {}          # cell name -> set of port names
cell = None
for i, line in enumerate(lines):
    m = re.match(r'\s*\(cell (\S+)$', line)
    if m:
        cell = m.group(1)
        continue
    if cell and cell.startswith('RAMB16'):
        m = re.match(r'(\s*)\(port (\w+) (\(direction \w+\)\))$', line)
        if m and PARITY_PORT.fullmatch(m.group(2)):
            indent, port, rest = m.groups()
            lines[i] = '%s(port (array (rename %s "%s[0:0]") 1) %s' % (indent, port, port, rest)
            converted.setdefault(cell, set()).add(port)

# Pass 2: instances. Map each instance name to its cell. yosys writes
# "(instance NAME" or "(instance (rename NAME "original"))" and the cellRef on
# the same or the following line.
instance_cell = {}
pending = None
for line in lines:
    m = re.match(r'\s*\(instance (?:\(rename )?(\S+)', line)
    if m:
        pending = m.group(1)
    if pending:
        c = re.search(r'\(cellRef (\S+?)[ )]', line)
        if c:
            instance_cell[pending] = c.group(1)
            pending = None

# Pass 3: connections to converted ports.
fixed = 0
for i, line in enumerate(lines):
    m = re.match(r'(\s*)\(portRef (\w+) \(instanceRef (\S+?)\)\)$', line)
    if m:
        indent, port, inst = m.groups()
        if port in converted.get(instance_cell.get(inst), ()):
            lines[i] = '%s(portRef (member %s 0) (instanceRef %s))' % (indent, port, inst)
            fixed += 1

open(path, 'w').write('\n'.join(lines))
ports = sum(len(p) for p in converted.values())
if ports:
    print('yosys-edif-fix: %d parity ports on %s made 1-bit buses, %d connections updated'
          % (ports, ', '.join(sorted(converted)), fixed))
