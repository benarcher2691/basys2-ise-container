# Board-level helpers for the Basys-2 (JP3 on ROM).
#   make factory          write Digilent's factory demo back to the XCF02S
#                         flash, verify it, and reload the FPGA from it
#   make verify-factory   check, read-only, that the flash holds exactly the
#                         factory demo (~7 s; fails on any other contents)
#
# On 2026-09-28 the flash of Ben's board was verified to hold exactly this
# file (basys2_100userdemoCClk.bit), so `factory` restores the as-delivered
# state. The bitfile is Digilent's and lives in the gitignored data/ folder
# (see docs/data-inventory.md).

ROOT := $(abspath ../..)
ISE  := $(ROOT)/bin/ise
DEMO := $(ROOT)/data/vhdl-zip/vhdl/basys2/src/Basys2UserDemo/Basys2UserDemo/BitFilesBasys2UserDemo/basys2_100userdemoCClk.bit

factory: build/factory_program.svf
	$(ROOT)/bin/basys2 svf $<
	$(ROOT)/bin/basys2 reload

verify-factory: build/factory_verify.svf
	$(ROOT)/bin/basys2 svf $<

# XCF02S image of the demo.
build/factory.mcs: $(DEMO)
	mkdir -p build
	cp "$(DEMO)" build/factory.bit
	(cd build && $(ISE) promgen -w -p mcs -c FF -x xcf02s -o factory.mcs -u 0 factory.bit) \
	    > build/factory_mcs.log 2>&1 || { tail -20 build/factory_mcs.log; exit 1; }

# iMPACT SVF for the flash (position 2 in the chain TDI → xc3s100e → xcf02s):
# $(1) = name, $(2) = iMPACT operation.
define impact_svf
build/factory_$(1).svf: build/factory.mcs
	printf '%s\n' 'setMode -bs' \
	    'setCable -port svf -file "/work/boards/basys2/build/factory_$(1).svf"' \
	    'addDevice -p 1 -part xc3s100e' 'addDevice -p 2 -part xcf02s' \
	    'assignFile -p 2 -file "/work/boards/basys2/build/factory.mcs"' \
	    '$(2)' 'closeCable' 'quit' > build/factory_$(1).cmd
	(cd build && $(ISE) impact -batch factory_$(1).cmd) > build/factory_$(1).log 2>&1 || \
	    { tail -20 build/factory_$(1).log; exit 1; }
endef
$(eval $(call impact_svf,program,program -p 2 -e -v))
$(eval $(call impact_svf,verify,verify -p 2))

clean:
	rm -rf build

.PHONY: factory verify-factory clean
