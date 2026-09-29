// =============================================================================
// kronometer: a stopwatch on the Basys-2.
//
// The display shows  M.SS.t  (minutes, seconds, tenths of a second) and runs
// from 0.00.0 to 9.59.9, then wraps around to 0.00.0.
//
//   BTN3  start (or continue after a pause)
//   BTN2  stop  (pause; the time stays on the display)
//   BTN0  reset to 0.00.0 and stop
//   BTN1  not used
//
// If several buttons are held at once, reset wins over start, and start wins
// over stop.
//
// Structure
// ---------
//
//   btn ──> synchronizer ──> control state machine ──running──┐
//                                                             v
//   mclk 50 MHz ──────────────────────────────────> 10 Hz tick generator
//                                                             │ tick
//                                                             v
//              [tenths] ─carry─> [seconds] ─carry─> [tens] ─carry─> [minutes]
//                                                             │ 4 BCD digits
//                                                             v
//                                                   seven_seg_display ──> an, seg, dp
//
// Everything is clocked by mclk. The 10 Hz "tick" is not a clock but a
// one-cycle enable pulse, so the whole design is a single clock domain.
//
// Parameters (the defaults are for the board; the testbench uses much smaller
// values so a simulated tenth of a second takes a few cycles, not millions)
//   CLK_HZ    frequency of mclk
//   TICK_HZ   how often the stopwatch advances (10 = tenths of a second)
//   DIGIT_HZ  display multiplexing rate, see seven_seg_display
// =============================================================================
`timescale 1ns / 1ps

module kronometer #(
    parameter CLK_HZ   = 50_000_000,
    parameter TICK_HZ  = 10,
    parameter DIGIT_HZ = 1_000
) (
    input  wire       mclk,   // 50 MHz board clock (pin B8)
    input  wire [3:0] btn,    // push buttons, pressed = 1
    output wire [3:0] an,     // 7-segment digit enables, active low
    output wire [6:0] seg,    // 7-segment segments g..a, active low
    output wire       dp      // 7-segment decimal point, active low
);
    // ------------------------------------------------------------------
    // Buttons: synchronize to mclk and give them names.
    // ------------------------------------------------------------------
    wire [3:0] btn_s;

    synchronizer #(.WIDTH(4)) btn_sync (
        .clk (mclk),
        .in  (btn),
        .out (btn_s)
    );

    wire reset_btn = btn_s[0];
    wire stop_btn  = btn_s[2];
    wire start_btn = btn_s[3];

    // ------------------------------------------------------------------
    // Control: a single flip-flop "running" is the whole state machine.
    //   running = 0: stopped (either reset or paused, the counters tell)
    //   running = 1: counting
    // Reset also clears the time; stop only freezes it.
    // ------------------------------------------------------------------
    reg running = 1'b0;

    always @(posedge mclk) begin
        if (reset_btn)
            running <= 1'b0;
        else if (start_btn)
            running <= 1'b1;
        else if (stop_btn)
            running <= 1'b0;
    end

    // ------------------------------------------------------------------
    // Tick generator: count mclk cycles while running and emit a one-cycle
    // pulse every CLK_HZ / TICK_HZ cycles (5,000,000 cycles = 0.1 s).
    //
    // The counter only runs while the stopwatch runs, so a pause keeps the
    // fraction of the current tenth: after "continue" the next tick comes
    // exactly when it would have come without the pause.
    // ------------------------------------------------------------------
    localparam integer TICK_DIV = CLK_HZ / TICK_HZ;

    reg  [23:0] tick_count = 24'd0;   // 24 bits: up to 16.7 million
    wire        tick = running && (tick_count == TICK_DIV - 1);

    always @(posedge mclk) begin
        if (reset_btn)
            tick_count <= 24'd0;
        else if (running)
            tick_count <= tick ? 24'd0 : tick_count + 24'd1;
    end

    // ------------------------------------------------------------------
    // Time: four chained decimal digits.
    // ------------------------------------------------------------------
    wire [3:0] tenths, seconds, tens, minutes;
    wire       carry_tenths, carry_seconds, carry_tens;

    bcd_counter #(.MAX(4'd9)) tenths_digit (
        .clk (mclk), .clear (reset_btn), .enable (tick),
        .value (tenths), .carry (carry_tenths)
    );

    bcd_counter #(.MAX(4'd9)) seconds_digit (
        .clk (mclk), .clear (reset_btn), .enable (carry_tenths),
        .value (seconds), .carry (carry_seconds)
    );

    bcd_counter #(.MAX(4'd5)) tens_digit (      // tens of seconds: 0..5
        .clk (mclk), .clear (reset_btn), .enable (carry_seconds),
        .value (tens), .carry (carry_tens)
    );

    bcd_counter #(.MAX(4'd9)) minutes_digit (   // 9.59.9 wraps to 0.00.0
        .clk (mclk), .clear (reset_btn), .enable (carry_tens),
        .value (minutes), .carry ()             // nothing after minutes
    );

    // ------------------------------------------------------------------
    // Display: M.SS.t -> decimal points after the minutes digit (leftmost,
    // digit 3) and after the seconds digit (digit 1).
    // ------------------------------------------------------------------
    seven_seg_display #(
        .CLK_HZ   (CLK_HZ),
        .DIGIT_HZ (DIGIT_HZ)
    ) display (
        .clk   (mclk),
        .value ({minutes, tens, seconds, tenths}),
        .dp_on (4'b1010),
        .an    (an),
        .seg   (seg),
        .dp    (dp)
    );
endmodule
