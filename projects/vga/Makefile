# Colour bars on a VGA monitor, 640 x 480 at 60 Hz (see rtl/vga_colorbars.v).
#   make sim     simulate (tb/vga_colorbars_tb.v checks timing and picture)
#   make         build/vga_colorbars.bit with ISE    make prog / make flash
TOP  := vga_colorbars
SRCS := rtl/vga_colorbars.v rtl/vga_timing.v
TB   := tb/vga_colorbars_tb.v
include ../../mk/ise.mk
