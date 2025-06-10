`timescale 1ns / 1ps

module op_lui_handler(
    input wire [31:0] instr,
    input wire [4:0] rd,
    output wire [31:0] result
);
    assign result = {instr[31:12], 12'b0};
endmodule
