# Stopwatch on the Basys-2, in Verilog (see rtl/kronometer.v).
#   make sim     simulate (tb/kronometer_tb.v, Icarus Verilog)
#   make         build/kronometer.bit with ISE    make prog / make flash
TOP  := kronometer
SRCS := rtl/kronometer.v rtl/bcd_counter.v \
        ../common/rtl/synchronizer.v \
        ../common/rtl/seven_seg_decoder.v \
        ../common/rtl/seven_seg_display.v
TB   := tb/kronometer_tb.v
include ../../mk/ise.mk
