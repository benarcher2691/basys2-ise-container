// =============================================================================
// synchronizer: bring asynchronous inputs (buttons, switches) into a clock
// domain safely.
//
// Why this is needed
// ------------------
// A push button or slide switch can change at any moment, completely
// unrelated to the FPGA clock. If a flip-flop samples a signal exactly while
// it changes, the flip-flop can become "metastable": its output hovers
// between 0 and 1 for a while before settling. Logic that reads such an
// output directly may see different values in different places.
//
// The standard cure is a chain of two flip-flops. The first may go
// metastable, but it has a whole clock period (20 ns at 50 MHz) to settle
// before the second one samples it. The output of the second flip-flop is
// clean for all practical purposes.
//
// What this does NOT do
// ---------------------
// It does not debounce. A mechanical button "bounces" for a few milliseconds
// when pressed or released, so the synchronized signal may toggle several
// times. For level-sensitive uses (hold a button to reset, press to start)
// that does no harm. To count button presses, add a debouncer after this.
//
// Parameters
//   WIDTH  number of independent 1-bit signals synchronized in parallel
// =============================================================================
`timescale 1ns / 1ps

module synchronizer #(
    parameter WIDTH = 1
) (
    input  wire             clk,
    input  wire [WIDTH-1:0] in,    // asynchronous inputs
    output wire [WIDTH-1:0] out    // the same signals, 2 clock cycles later
);
    // Both stages start at 0 after configuration (FPGA registers have a
    // defined power-up value, set here with an initializer).
    reg [WIDTH-1:0] stage1 = {WIDTH{1'b0}};
    reg [WIDTH-1:0] stage2 = {WIDTH{1'b0}};

    always @(posedge clk) begin
        stage1 <= in;       // may go metastable
        stage2 <= stage1;   // has a full clock period to let stage1 settle
    end

    assign out = stage2;
endmodule
