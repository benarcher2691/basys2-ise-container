#!/bin/bash
# Put the ISE tools on PATH, then run the given command.
# Pass the install dir explicitly: settings64.sh takes its first argument as
# the install location, and a sourced script sees our "$@" otherwise.
. /opt/Xilinx/14.7/ISE_DS/settings64.sh /opt/Xilinx/14.7/ISE_DS >/dev/null
exec "$@"
