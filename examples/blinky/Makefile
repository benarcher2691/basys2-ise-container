# Blinky on the Basys-2 with the XST reference flow (REPORT.md Phase 3).
#   make        build/top.bit (ISE in the container)
#   make prog   load it into the FPGA over USB (bin/basys2)
#   make clean

ROOT   := ../..
ISE    := $(ROOT)/bin/ise
PART   := xc3s100e-cp132-4
UCF    := $(ROOT)/boards/basys2/basys2.ucf
TOP    := top
SRCS   := rtl/top.v

all: build/$(TOP).bit

# One container run for the whole flow: each tool takes ~1 min just to
# start under Rosetta, so there's no point splitting it into make steps.
build/$(TOP).bit: $(SRCS) $(UCF)
	mkdir -p build
	printf 'verilog work "../%s"\n' $(SRCS) > build/$(TOP).prj
	printf 'run\n-ifn $(TOP).prj\n-ifmt mixed\n-top $(TOP)\n-ofn $(TOP).ngc\n-ofmt NGC\n-p $(PART)\n-opt_mode Speed\n-opt_level 1\n' > build/$(TOP).xst
	cd build && ../$(ISE) bash -euc ' \
	    xst -ifn $(TOP).xst -ofn $(TOP).syr && \
	    ngdbuild -aul -p $(PART) -uc ../$(UCF) $(TOP).ngc $(TOP).ngd && \
	    map -w -p $(PART) -o $(TOP)_map.ncd $(TOP).ngd $(TOP).pcf && \
	    par -w $(TOP)_map.ncd $(TOP).ncd $(TOP).pcf && \
	    trce -v 10 -o $(TOP).twr $(TOP).ncd $(TOP).pcf && \
	    bitgen -w -g StartUpClk:JtagClk $(TOP).ncd $(TOP).bit'

prog: build/$(TOP).bit
	$(ROOT)/bin/basys2 prog $<

clean:
	rm -rf build

.PHONY: all prog clean
