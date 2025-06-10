`timescale 1ns / 1ps

module op_jal_handler(
    input wire [31:0] instr,
    input wire [4:0] rd_sel,
    input wire [31:0] pc,
    output wire [31:0] result,
    output wire [31:0] next_pc
);
    wire [20:0] imm_j;
    assign imm_j = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    assign result = pc + 4;
    assign next_pc = pc + {{11{imm_j[20]}}, imm_j};
endmodule
