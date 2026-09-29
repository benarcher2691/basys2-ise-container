#!/usr/bin/env python3
"""Turn a text file into the initial contents of the text RAM.

Usage: tools/make_screen.py mem/screen.txt > build/screen.hex

The screen has 40 columns and 30 rows. Each line of the file becomes one
row; shorter lines and missing rows are filled with spaces. The output has
one ASCII code per line, in hex, row by row (1200 lines), for $readmemh.
The hardware shows lowercase letters as uppercase, so they may be used.
"""
import sys

COLS, ROWS = 40, 30
lines = open(sys.argv[1], encoding='ascii').read().split('\n')
if lines and lines[-1] == '':
    lines.pop()
if len(lines) > ROWS:
    sys.exit('%s: %d lines, the screen has %d rows' % (sys.argv[1], len(lines), ROWS))
for n, line in enumerate(lines, 1):
    if len(line) > COLS:
        sys.exit('%s:%d: %d characters, the screen has %d columns' % (sys.argv[1], n, len(line), COLS))

for row in range(ROWS):
    line = lines[row] if row < len(lines) else ''
    for ch in line.ljust(COLS):
        print('%02X' % ord(ch))
