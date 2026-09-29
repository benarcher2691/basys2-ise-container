# MyVGA (2010-09-13): three colour bars, 640 x 480 at 60 Hz, in VHDL.
# Sources and UCF copied unchanged from data/vhdl-zip/vhdl/Xilinx/vga/MyVGA.
# Note: the UCF takes the clock from pin M6, the IC6 oscillator socket,
# which is empty on the current board, so this build gets no clock there.
# The Verilog rewrite in projects/vga uses the 50 MHz clock on B8.
TOP  := MyVGA
SRCS := src/OwnVGA.vhd
UCF  := pins.ucf
include ../../mk/ise.mk
