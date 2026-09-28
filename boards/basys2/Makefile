# Board-level helpers for the Basys-2.
#   make factory   write Digilent's factory demo back to the XCF02S flash,
#                  verify it, and reload the FPGA from it (JP3 on ROM)
#
# On 2026-09-28 the flash of Ben's board was verified to hold exactly this
# file (basys2_100userdemoCClk.bit), so this restores the as-delivered state.
# The bitfile is Digilent's and lives in the gitignored data/ folder
# (see docs/data-inventory.md).

ROOT := $(abspath ../..)
ISE  := $(ROOT)/bin/ise
DEMO := $(ROOT)/data/vhdl-zip/vhdl/basys2/src/Basys2UserDemo/Basys2UserDemo/BitFilesBasys2UserDemo/basys2_100userdemoCClk.bit

factory: build/factory_flash.svf
	$(ROOT)/bin/basys2 svf $<
	$(ROOT)/bin/basys2 reload

build/factory_flash.svf: $(DEMO)
	mkdir -p build
	cp "$(DEMO)" build/factory.bit
	printf '%s\n' 'setMode -bs' \
	    'setCable -port svf -file "/work/boards/basys2/build/factory_flash.svf"' \
	    'addDevice -p 1 -part xc3s100e' 'addDevice -p 2 -part xcf02s' \
	    'assignFile -p 2 -file "/work/boards/basys2/build/factory.mcs"' \
	    'program -p 2 -e -v' 'closeCable' 'quit' > build/factory_flash.cmd
	(cd build && $(ISE) bash -euc ' \
	    promgen -w -p mcs -c FF -x xcf02s -o factory.mcs -u 0 factory.bit && \
	    impact -batch factory_flash.cmd') > build/factory_flash.log 2>&1 || \
	    { tail -20 build/factory_flash.log; exit 1; }

clean:
	rm -rf build

.PHONY: factory clean
