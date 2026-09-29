# 40 x 30 characters of text on a VGA monitor (see rtl/vga_text.v).
#   make sim     simulate: checks every pixel of two frames, writes build/frame.ppm
#   make         build/vga_text.bit with ISE    make prog / make flash
# The text comes from mem/screen.txt: edit it and rebuild.
TOP  := vga_text
SRCS := rtl/vga_text.v rtl/text_ram.v rtl/char_rom.v ../vga/rtl/vga_timing.v
TB   := tb/vga_text_tb.v

EXTRA_DEPS = $(B)/font.hex $(B)/screen.hex

include ../../mk/ise.mk

$(B)/font.hex: mem/font.hex | $(B)
	cp $< $@
$(B)/screen.hex: mem/screen.txt tools/make_screen.py | $(B)
	python3 tools/make_screen.py $< > $@

# The character map is generated from the font source and committed
# (font.txt is the same with pictures, for reading).
mem/font.hex: fonts/font8x8_basic.h tools/make_font.py
	python3 tools/make_font.py $< > $@
	python3 tools/make_font.py --pictures $< > mem/font.txt
