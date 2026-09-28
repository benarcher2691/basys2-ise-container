#!/bin/bash
# Put the ISE tools on PATH, then run the given command.
# Pass the install dir explicitly: settings64.sh takes its first argument as
# the install location, and a sourced script sees our "$@" otherwise.
. /opt/Xilinx/14.7/ISE_DS/settings64.sh /opt/Xilinx/14.7/ISE_DS >/dev/null

# Call the real binaries in unwrapped/ first. The bin/lin64/<tool> wrappers
# only prepend their install dir to PATH, LD_LIBRARY_PATH and XILINX (which
# settings64.sh has already done), but each costs ~35 s of start-up under
# Rosetta. Tested 2026-09-28; see docs/ise-container.md.
PATH=$XILINX/bin/lin64/unwrapped:$PATH
export PATH

exec "$@"
