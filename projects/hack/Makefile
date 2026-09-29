# The Hack computer (nand2tetris) on the Basys-2, in Verilog.
#   make sim                      simulate: ALU test + test001 on the whole computer
#   make                          build/hack_computer.bit with ISE (~4 min)
#   make prog / make flash        load it into the FPGA / write it to the flash
#   make PROGRAM=programs/x.hack  build with another program in the ROM
#                                 (assembled from programs/x.asm if needed)
TOP  := hack_computer
SRCS := rtl/hack_computer.v rtl/hack_cpu.v rtl/hack_alu.v \
        rtl/hack_rom.v rtl/hack_ram.v \
        ../common/rtl/synchronizer.v \
        ../common/rtl/seven_seg_decoder.v \
        ../common/rtl/seven_seg_display.v
TB   := tb/hack_alu_tb.v tb/hack_computer_tb.v

# ROM and RAM contents, read with $readmemb("rom.hack") and ("ram.hack")
# in the build directory.
PROGRAM  ?= programs/test001.hack
RAM_INIT ?= mem/ram_init.hack
EXTRA_DEPS = $(B)/rom.hack $(B)/ram.hack

include ../../mk/ise.mk

# Copy only when the content differs, so switching PROGRAM rebuilds and an
# unchanged program doesn't.
$(B)/rom.hack: $(PROGRAM) FORCE | $(B)
	@cmp -s $(PROGRAM) $@ || cp $(PROGRAM) $@
$(B)/ram.hack: FORCE | $(B)
	@cmp -s $(RAM_INIT) $@ || cp $(RAM_INIT) $@

# Assemble .asm into .hack with Ben's assembler, e.g. for PROGRAM=programs/x.hack
# when programs/x.asm exists.
programs/%.hack: programs/%.asm tools/assembler.py
	python3 tools/assembler.py $<

FORCE:
.PHONY: FORCE
