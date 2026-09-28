// Deliberate syntax error: tests/regress.sh checks XST's error path.
module bad (input wire a, output wire y)
    assign y = a
endmodule
