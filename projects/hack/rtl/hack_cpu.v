// =============================================================================
// hack_cpu: the central processing unit of the Hack computer (nand2tetris).
//
// A single-cycle CPU: every enabled clock edge completes one whole
// instruction. There is no pipeline and no multi-step sequencing, which makes
// it the simplest possible stored-program computer to understand.
//
// Registers
// ---------
//   A   16 bits  address register: holds constants, and the memory address
//                the current instruction reads and writes (M = RAM[A])
//   D   16 bits  data register: the ALU's x input
//   PC  15 bits  program counter: address of the current instruction in ROM
//
// Instructions (16 bits) come in two kinds, told apart by the top bit:
//
//   A-instruction  0vvv vvvv vvvv vvvv   "@value": load the 15-bit constant
//                                        into A.
//
//   C-instruction  111a cccc ccdd djjj   "dest = comp ; jump":
//        a      ALU y input: 0 = A, 1 = M (the RAM word at address A)
//        cccccc ALU control bits zx nx zy ny f no (see hack_alu.v)
//        ddd    where to store the ALU result: bit 5 = A, bit 4 = D,
//               bit 3 = M (RAM[A])
//        jjj    when to jump to the address in A, based on the ALU result:
//               bit 2 = if < 0, bit 1 = if = 0, bit 0 = if > 0
//               (000 = never, 111 = always; any combination is allowed)
//
// Data path (what happens during one instruction)
// -----------------------------------------------
//
//   instruction ──> decoder ──> control signals (load A, load D, a bit, ...)
//        │
//        │ the constant (A-instruction)
//        v
//    ┌───────┐
//    │  mux  │<──────────────────────────────── ALU out (C-instruction)
//    └───┬───┘                                     ^
//        v                                         │
//   A register ──┬──> addressM (RAM address)       │
//        │       └──> jump target for PC           │
//        v                                         │
//    ┌───────┐                                     │
//    │  mux  │<── inM (RAM[A])                     │
//    └───┬───┘   selected by the a bit             │
//        v y                                       │
//   ┌─────────┐                                    │
//   │   ALU   │── out ──┬──────────────────────────┘
//   └─────────┘         ├──> D register
//     ^ x    │ zr, ng   └──> outM (RAM data, written if dest has M)
//     │      v
//   D register    jump logic ──> PC = A if jumping, else PC + 1
//
// All three registers change at the same clock edge, at the END of the
// instruction. So during an instruction, addressM and the jump target are
// the value A had BEFORE the instruction, exactly as the Hack spec requires
// (for "AM=M+1", M is read and written at the old A).
//
// Clock enable
// ------------
// The registers only change on clock edges where ce = 1. The surrounding
// computer uses this to run the CPU slower than the 50 MHz board clock
// without creating a second clock (see hack_computer.v).
//
// Reset
// -----
// While reset = 1, PC is held at 0 and A and D keep their values. When reset
// goes back to 0, execution starts at ROM address 0.
// =============================================================================
`timescale 1ns / 1ps

module hack_cpu (
    input  wire        clk,
    input  wire        ce,            // clock enable: execute one instruction
    input  wire        reset,         // hold PC at 0
    input  wire [15:0] instruction,   // ROM[pc]
    input  wire [15:0] inM,           // RAM[addressM]
    output wire [15:0] outM,          // value to write to RAM[addressM]
    output wire        writeM,        // 1 = write outM to RAM[addressM]
    output wire [14:0] addressM,      // RAM address (= A)
    output wire [14:0] pc             // ROM address of the current instruction
);
    // ------------------------------------------------------------------
    // Registers (the complete state of the CPU).
    // ------------------------------------------------------------------
    reg [15:0] a_reg  = 16'h0000;
    reg [15:0] d_reg  = 16'h0000;
    reg [14:0] pc_reg = 15'h0000;

    // ------------------------------------------------------------------
    // Instruction decoding: give the instruction fields names.
    // ------------------------------------------------------------------
    wire       is_c_instr = instruction[15];     // 1 = C-instruction
    wire       use_m      = instruction[12];     // ALU y: 0 = A, 1 = M
    wire [5:0] comp       = instruction[11:6];   // zx nx zy ny f no
    wire       dest_a     = instruction[5];
    wire       dest_d     = instruction[4];
    wire       dest_m     = instruction[3];
    wire       jump_lt    = instruction[2];      // jump if out < 0
    wire       jump_eq    = instruction[1];      // jump if out = 0
    wire       jump_gt    = instruction[0];      // jump if out > 0

    // ------------------------------------------------------------------
    // ALU: x is always D; y is A or M, chosen by the a bit.
    // ------------------------------------------------------------------
    wire [15:0] alu_y = use_m ? inM : a_reg;
    wire [15:0] alu_out;
    wire        zr, ng;

    hack_alu alu (
        .x   (d_reg),
        .y   (alu_y),
        .zx  (comp[5]), .nx (comp[4]),
        .zy  (comp[3]), .ny (comp[2]),
        .f   (comp[1]), .no (comp[0]),
        .out (alu_out),
        .zr  (zr),
        .ng  (ng)
    );

    // ------------------------------------------------------------------
    // Control signals. The dest and jump bits only mean something in a
    // C-instruction, so each one is qualified with is_c_instr.
    // ------------------------------------------------------------------
    // A is loaded by every A-instruction (with the constant) and by
    // C-instructions whose dest includes A (with the ALU result).
    wire        load_a = !is_c_instr || dest_a;
    wire [15:0] a_next = is_c_instr ? alu_out : instruction;   // bit 15 is 0

    wire        load_d = is_c_instr && dest_d;

    // "Positive" means neither zero nor negative.
    wire        positive = !zr && !ng;
    wire        jump     = is_c_instr && ((jump_lt && ng) ||
                                          (jump_eq && zr) ||
                                          (jump_gt && positive));

    // ------------------------------------------------------------------
    // Register updates: one instruction per enabled clock edge.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            pc_reg <= 15'h0000;
        end else if (ce) begin
            if (load_a) a_reg <= a_next;
            if (load_d) d_reg <= alu_out;
            pc_reg <= jump ? a_reg[14:0] : pc_reg + 15'h0001;
        end
    end

    // ------------------------------------------------------------------
    // Outputs to memory.
    // ------------------------------------------------------------------
    assign outM     = alu_out;
    assign writeM   = is_c_instr && dest_m;
    assign addressM = a_reg[14:0];
    assign pc       = pc_reg;
endmodule
