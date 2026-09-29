# Shared ISE 14.7 flow for the Basys-2 (XST → ngdbuild → map → par → trce →
# bitgen), run in the container through bin/ise. A project Makefile sets:
#
#   TOP     top-level entity/module
#   SRCS    sources (.v, .vhd), relative to the project directory
#   UCF     constraints file (default: boards/basys2/basys2.ucf)
#   CORES   optional directories with CORE Generator netlists (.ngc)
#   TB      optional testbench(es) for `make sim` (Icarus Verilog)
#   EXTRA_DEPS  optional files the build needs in the build directory, e.g.
#           memory images read with $readmemb("name"); the project Makefile
#           adds a rule that puts them there
#
# and then does `include <path>/mk/ise.mk`. Targets:
#
#   make          build/$(TOP).bit, StartUpClk:JtagClk, for loading over JTAG
#                 (SYNTH=yosys: build-yosys/$(TOP).bit, yosys instead of XST)
#   make sim      compile SRCS + TB with iverilog and run it in the build dir
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
TB    ?=
EXTRA_DEPS ?=

# SYNTH=xst (default) or SYNTH=yosys. yosys (Spartan-3E support is
# EXPERIMENTAL) runs natively and writes EDIF; its outputs go to build-yosys/.
SYNTH ?= xst
ifeq ($(SYNTH),yosys)
B          := build-yosys
NETLIST    := $(TOP).edf
SYNTH_DEPS  = $(B)/$(TOP).edf
SYNTH_CMD  :=
else
B          := build
NETLIST    := $(TOP).ngc
SYNTH_DEPS  = $(B)/$(TOP).prj $(B)/$(TOP).xst
SYNTH_CMD  := xst -ifn $(TOP).xst -ofn $(TOP).syr &&
endif

XST_OPTS    ?= -opt_mode Speed -opt_level 1
BITGEN_OPTS ?=

# Paths as the container sees them: the repo is mounted at /work.
ctr = $(patsubst $(ROOT)/%,/work/%,$(abspath $(1)))

all: $(B)/$(TOP).bit

# yosys: native synthesis to EDIF (Verilog only), ISE from ngdbuild on.
# Runs in the build dir, like the ISE tools, so $readmemb finds EXTRA_DEPS.
# -flatten: ISE's edif2ngd wants one flat netlist. Flattening leaves
# $scopeinfo marker cells behind, which write_edif would emit as references
# to an undefined cell, so they're deleted before writing
# (write_edif -pvector bra is what synth_xilinx -edif would run).
$(B)/$(TOP).edf: $(SRCS) $(EXTRA_DEPS) | $(B)
	cd $(B) && yosys -q -l yosys.log -p 'read_verilog $(abspath $(SRCS)); synth_xilinx -family xc3se -top $(TOP) -flatten -ise; delete t:$$scopeinfo; write_edif -pvector bra $(TOP).edf'
	@grep -A30 'Printing statistics' $(B)/yosys.log | grep -E 'cells|FD|LUT|MUXCY|XORCY|BUF|RAM' | head -12 || true

# Simulation with Icarus Verilog, run in the build dir (same file lookup as
# synthesis). The testbench decides pass/fail and says so.
# Each testbench in TB is compiled and run on its own.
sim: $(SRCS) $(TB) $(EXTRA_DEPS) | $(B)
	@set -e; for tb in $(TB); do \
	    name=$$(basename $$tb .v); \
	    echo "== $$name"; \
	    iverilog -g2005 -Wall -s $$name -o $(B)/$$name.vvp $(abspath $(SRCS)) $$(cd $$(dirname $$tb) && pwd)/$$(basename $$tb); \
	    (cd $(B) && vvp -n $$name.vvp); \
	done

$(B)/$(TOP).prj: $(SRCS) | $(B)
	@for s in $(foreach s,$(SRCS),$(call ctr,$(s))); do \
	    case $$s in *.vhd|*.vhdl) l=vhdl ;; *) l=verilog ;; esac; \
	    echo "$$l work \"$$s\""; \
	done > $@

$(B)/$(TOP).xst: | $(B)
	@printf 'run\n-ifn $(TOP).prj\n-ifmt mixed\n-top $(TOP)\n-ofn $(TOP).ngc\n-ofmt NGC\n-p $(PART)\n%s\n' \
	    "$$(echo '$(XST_OPTS)' | tr ' ' '\n' | paste -d' ' - -)" > $@

$(B)/$(TOP).bit: $(SYNTH_DEPS) $(SRCS) $(UCF) $(EXTRA_DEPS)
	cd $(B) && $(ISE) bash -euc ' \
	    $(SYNTH_CMD) \
	    ngdbuild -aul -p $(PART) $(foreach c,$(CORES),-sd $(call ctr,$(c))) \
	        -uc $(call ctr,$(UCF)) $(NETLIST) $(TOP).ngd && \
	    map -w -p $(PART) -o $(TOP)_map.ncd $(TOP).ngd $(TOP).pcf && \
	    par -w $(TOP)_map.ncd $(TOP).ncd $(TOP).pcf && \
	    trce -v 10 -o $(TOP).twr $(TOP).ncd $(TOP).pcf && \
	    bitgen -w -g StartUpClk:JtagClk $(BITGEN_OPTS) $(TOP).ncd $(TOP).bit'
	@grep -hE 'Timing errors|All constraints were met|constraints? (was|were) not met' $(B)/$(TOP).twr $(B)/$(TOP).par 2>/dev/null | sort -u || true

prog: $(B)/$(TOP).bit
	$(ROOT)/bin/basys2 prog $<

# Flash: a CClk bitstream (the FPGA clocks itself from the PROM), turned into
# an XCF02S image by promgen, and an erase/program/verify SVF from iMPACT,
# played over USB by bin/basys2. Chain: TDI → xc3s100e (1) → xcf02s (2) → TDO.
$(B)/$(TOP)_flash.svf: $(B)/$(TOP).bit
	printf '%s\n' 'setMode -bs' \
	    'setCable -port svf -file "$(call ctr,$(B)/$(TOP)_flash.svf)"' \
	    'addDevice -p 1 -part xc3s100e' 'addDevice -p 2 -part xcf02s' \
	    'assignFile -p 2 -file "$(call ctr,$(B)/$(TOP).mcs)"' \
	    'program -p 2 -e -v' 'closeCable' 'quit' > $(B)/$(TOP)_flash.cmd
	(cd $(B) && $(ISE) bash -euc ' \
	    bitgen -w -g StartUpClk:CClk $(BITGEN_OPTS) $(TOP).ncd $(TOP)_prom.bit && \
	    promgen -w -p mcs -c FF -x xcf02s -o $(TOP).mcs -u 0 $(TOP)_prom.bit && \
	    impact -batch $(TOP)_flash.cmd') > $(B)/$(TOP)_flash.log 2>&1 || \
	    { tail -20 $(B)/$(TOP)_flash.log; exit 1; }
	@grep -E "Programming completed|Verification completed|ERROR" $(B)/$(TOP)_flash.log || true

flash: $(B)/$(TOP)_flash.svf
	$(ROOT)/bin/basys2 svf $<
	$(ROOT)/bin/basys2 reload

$(B):
	mkdir -p $@

clean:
	rm -rf build build-yosys

.PHONY: all sim prog flash clean
