// =============================================================================
// hack_computer: the Hack computer (nand2tetris) on the Basys-2.
//
// CPU + 1K words of program ROM + 2K words of data RAM, running a program
// from a .hack file (see the Makefile: `make PROGRAM=...`).
//
// Board I/O
// ---------
//   BTN0        reset: hold to keep the CPU at address 0, release to (re)start
//   SW3..SW0    RAM address to show on the display (0..15)
//   display     the 16-bit word RAM[SW3..SW0] in hexadecimal
//               (e.g. 5 = 0005, -5 = FFFB)
//   LD7..LD0    the low 8 bits of the program counter
//   SW7         speed: down = 1 million instructions per second,
//               up = 2 instructions per second, slow enough to watch the
//               program counter step on the LEDs
//
// Memory map (as seen by the program)
// -----------------------------------
//   ROM  addresses 0..1023      instructions, read by the CPU via PC
//   RAM  addresses 0..2047      data (the Hack spec has 16K of RAM plus
//                               screen and keyboard; this smaller computer
//                               has neither, and addresses wrap at 2048)
//
// How the CPU is clocked
// ----------------------
// Everything runs from the 50 MHz board clock. The CPU does not get a slower
// clock of its own; instead a counter produces cpu_ce, a pulse that is high
// for one 50 MHz cycle every CPU_DIV cycles, and the CPU only executes an
// instruction on edges where cpu_ce is high:
//
//   mclk     _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
//   cpu_ce   ___|‾‾‾|___________________|‾‾‾|__________________   (CPU_DIV = 6 here)
//                   ^ instruction n done    ^ instruction n+1 done
//
// Between two instructions the ROM and RAM have several clock edges to read
// the new PC and the new A (their reads are synchronous, one edge each), so
// the instruction and inM are ready long before the CPU needs them. That's
// why CPU_DIV must be at least 2.
//
// Parameters
//   CLK_HZ    board clock
//   CPU_HZ    instructions per second with SW7 down (CLK_HZ / CPU_HZ >= 2)
//   SLOW_HZ   instructions per second with SW7 up
//   DIGIT_HZ  display multiplexing rate
//   ROM_FILE  program (.hack), RAM_FILE initial RAM contents
// =============================================================================
`timescale 1ns / 1ps

module hack_computer #(
    parameter CLK_HZ   = 50_000_000,
    parameter CPU_HZ   = 1_000_000,
    parameter SLOW_HZ  = 2,
    parameter DIGIT_HZ = 1_000,
    parameter ROM_FILE = "rom.hack",
    parameter RAM_FILE = "ram.hack"
) (
    input  wire       mclk,   // 50 MHz board clock
    input  wire [3:0] btn,    // push buttons, pressed = 1
    input  wire [7:0] sw,     // slide switches, up = 1
    output wire [7:0] led,    // LEDs, 1 = on
    output wire [3:0] an,     // 7-segment digit enables, active low
    output wire [6:0] seg,    // 7-segment segments g..a, active low
    output wire       dp      // 7-segment decimal point, active low
);
    // ------------------------------------------------------------------
    // Inputs: synchronize buttons and switches to mclk.
    // ------------------------------------------------------------------
    wire [3:0] btn_s;
    wire [7:0] sw_s;

    synchronizer #(.WIDTH(12)) input_sync (
        .clk (mclk),
        .in  ({btn, sw}),
        .out ({btn_s, sw_s})
    );

    wire       reset     = btn_s[0];
    wire       slow_mode = sw_s[7];
    wire [3:0] show_addr = sw_s[3:0];

    // ------------------------------------------------------------------
    // CPU clock enable: one pulse every CPU_DIV (fast) or SLOW_DIV (slow)
    // cycles. Using ">=" instead of "==" makes switching from slow to fast
    // safe: a count that is already past the fast limit wraps right away.
    // ------------------------------------------------------------------
    localparam integer CPU_DIV  = CLK_HZ / CPU_HZ;
    localparam integer SLOW_DIV = CLK_HZ / SLOW_HZ;

    reg  [25:0] ce_count = 26'd0;           // 26 bits: up to 67 million
    wire [25:0] ce_limit = slow_mode ? SLOW_DIV - 1 : CPU_DIV - 1;
    wire        cpu_ce   = (ce_count >= ce_limit);

    always @(posedge mclk)
        ce_count <= cpu_ce ? 26'd0 : ce_count + 26'd1;

    // ------------------------------------------------------------------
    // The CPU.
    // ------------------------------------------------------------------
    wire [15:0] instruction;
    wire [15:0] inM, outM;
    wire        writeM;
    wire [14:0] addressM, pc;

    hack_cpu cpu (
        .clk         (mclk),
        .ce          (cpu_ce),
        .reset       (reset),
        .instruction (instruction),
        .inM         (inM),
        .outM        (outM),
        .writeM      (writeM),
        .addressM    (addressM),
        .pc          (pc)
    );

    // ------------------------------------------------------------------
    // Program ROM: 1024 words, addressed by the low 10 bits of PC.
    // ------------------------------------------------------------------
    hack_rom #(
        .ADDR_WIDTH (10),
        .INIT_FILE  (ROM_FILE)
    ) rom (
        .clk  (mclk),
        .addr (pc[9:0]),
        .data (instruction)
    );

    // ------------------------------------------------------------------
    // Data RAM: 2048 words. Port A belongs to the CPU; it writes only on
    // the clock edge that completes the instruction (cpu_ce) and never
    // during reset. Port B feeds the display.
    // ------------------------------------------------------------------
    wire [15:0] shown_word;

    hack_ram #(
        .ADDR_WIDTH (11),
        .INIT_FILE  (RAM_FILE)
    ) ram (
        .clk    (mclk),
        .we_a   (writeM && cpu_ce && !reset),
        .addr_a (addressM[10:0]),
        .din_a  (outM),
        .dout_a (inM),
        .addr_b ({7'd0, show_addr}),
        .dout_b (shown_word)
    );

    // ------------------------------------------------------------------
    // Outputs: PC on the LEDs, RAM[SW3..SW0] on the display.
    // ------------------------------------------------------------------
    assign led = pc[7:0];

    seven_seg_display #(
        .CLK_HZ   (CLK_HZ),
        .DIGIT_HZ (DIGIT_HZ)
    ) display (
        .clk   (mclk),
        .value (shown_word),
        .dp_on (4'b0000),
        .an    (an),
        .seg   (seg),
        .dp    (dp)
    );
endmodule
