# Shared ISE 14.7 flow for the Basys-2 (XST → ngdbuild → map → par → trce →
# bitgen), run in the container through bin/ise. A project Makefile sets:
#
#   TOP     top-level entity/module
#   SRCS    sources (.v, .vhd), relative to the project directory
#   UCF     constraints file (default: boards/basys2/basys2.ucf)
#   CORES   optional directories with CORE Generator netlists (.ngc)
#
# and then does `include <path>/mk/ise.mk`. Targets:
#
#   make          build/$(TOP).bit, StartUpClk:JtagClk, for loading over JTAG
#   make prog     load it into the FPGA (bin/basys2 prog, lost at power-off)
#   make flash    write it to the XCF02S flash so it survives power-off, then
#                 reload the FPGA from there (needs JP3 on ROM)
#   make clean
#
# All tools run in one container call: each takes ~35 s just to start under
# Rosetta, so splitting the flow into make steps would only add overhead.

ROOT  := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
ISE   := $(ROOT)/bin/ise
PART  ?= xc3s100e-cp132-4
UCF   ?= $(ROOT)/boards/basys2/basys2.ucf
CORES ?=

XST_OPTS    ?= -opt_mode Speed -opt_level 1
BITGEN_OPTS ?=

# Paths as the container sees them: the repo is mounted at /work.
ctr = $(patsubst $(ROOT)/%,/work/%,$(abspath $(1)))

all: build/$(TOP).bit

build/$(TOP).prj: $(SRCS) | build
	@for s in $(foreach s,$(SRCS),$(call ctr,$(s))); do \
	    case $$s in *.vhd|*.vhdl) l=vhdl ;; *) l=verilog ;; esac; \
	    echo "$$l work \"$$s\""; \
	done > $@

build/$(TOP).xst: | build
	@printf 'run\n-ifn $(TOP).prj\n-ifmt mixed\n-top $(TOP)\n-ofn $(TOP).ngc\n-ofmt NGC\n-p $(PART)\n%s\n' \
	    "$$(echo '$(XST_OPTS)' | tr ' ' '\n' | paste -d' ' - -)" > $@

build/$(TOP).bit: build/$(TOP).prj build/$(TOP).xst $(SRCS) $(UCF)
	cd build && $(ISE) bash -euc ' \
	    xst -ifn $(TOP).xst -ofn $(TOP).syr && \
	    ngdbuild -aul -p $(PART) $(foreach c,$(CORES),-sd $(call ctr,$(c))) \
	        -uc $(call ctr,$(UCF)) $(TOP).ngc $(TOP).ngd && \
	    map -w -p $(PART) -o $(TOP)_map.ncd $(TOP).ngd $(TOP).pcf && \
	    par -w $(TOP)_map.ncd $(TOP).ncd $(TOP).pcf && \
	    trce -v 10 -o $(TOP).twr $(TOP).ncd $(TOP).pcf && \
	    bitgen -w -g StartUpClk:JtagClk $(BITGEN_OPTS) $(TOP).ncd $(TOP).bit'
	@grep -hE 'Timing errors|All constraints were met|constraints? (was|were) not met' build/$(TOP).twr build/$(TOP).par 2>/dev/null | sort -u || true

prog: build/$(TOP).bit
	$(ROOT)/bin/basys2 prog $<

# Flash: a CClk bitstream (the FPGA clocks itself from the PROM), turned into
# an XCF02S image by promgen, and an erase/program/verify SVF from iMPACT,
# played over USB by bin/basys2. Chain: TDI → xc3s100e (1) → xcf02s (2) → TDO.
build/$(TOP)_flash.svf: build/$(TOP).bit
	printf '%s\n' 'setMode -bs' \
	    'setCable -port svf -file "$(call ctr,build/$(TOP)_flash.svf)"' \
	    'addDevice -p 1 -part xc3s100e' 'addDevice -p 2 -part xcf02s' \
	    'assignFile -p 2 -file "$(call ctr,build/$(TOP).mcs)"' \
	    'program -p 2 -e -v' 'closeCable' 'quit' > build/$(TOP)_flash.cmd
	(cd build && $(ISE) bash -euc ' \
	    bitgen -w -g StartUpClk:CClk $(BITGEN_OPTS) $(TOP).ncd $(TOP)_prom.bit && \
	    promgen -w -p mcs -c FF -x xcf02s -o $(TOP).mcs -u 0 $(TOP)_prom.bit && \
	    impact -batch $(TOP)_flash.cmd') > build/$(TOP)_flash.log 2>&1 || \
	    { tail -20 build/$(TOP)_flash.log; exit 1; }
	@grep -E "Programming completed|Verification completed|ERROR" build/$(TOP)_flash.log || true

flash: build/$(TOP)_flash.svf
	$(ROOT)/bin/basys2 svf $<
	$(ROOT)/bin/basys2 reload

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all prog flash clean
