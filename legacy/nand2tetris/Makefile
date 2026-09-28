# nand2tetris "Hack" computer (2013-2015): CPU + 1K ROM + 2K RAM on the Basys-2.
# The ROM holds test001.asm (all jump instructions); after reset (BTN0) the
# 7-segment display shows RAM[SW3..SW0]: expect 5, -5, 1, 1, 1, 1, 1, 1, 1
# in RAM[0..8]. Sources, UCF and the CORE Generator netlists (cores/*.ngc,
# which carry the ROM/RAM contents) are copied unchanged from
# data/vhdl-zip/vhdl/projects/nand2tetris/src/nand2tetris.
TOP   := b_computer
SRCS  := $(wildcard src/*.vhd)
UCF   := pins.ucf
CORES := cores
include ../../mk/ise.mk
