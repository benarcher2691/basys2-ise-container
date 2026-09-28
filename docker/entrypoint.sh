#!/bin/bash
# Put the ISE tools on PATH, then run the given command.
. /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null
exec "$@"
