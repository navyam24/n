`timescale 1ns / 1ps

module op_auipc_handler(
    input wire [31:0] instr,
    input wire [4:0] rd,
    input wire [31:0] pc,
    output wire [31:0] result
);
    wire [31:0] imm_u;
    assign imm_u = {instr[31:12], 12'b0};
    assign result = imm_u + pc;
endmodule
