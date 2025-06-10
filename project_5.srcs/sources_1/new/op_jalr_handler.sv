`timescale 1ns / 1ps

module op_jalr_handler(
    input wire [31:0] instr,
    input wire [4:0] rd_sel,
    input wire [31:0] rs1_data,
    input wire [31:0] pc,
    output wire [31:0] result,
    output wire [31:0] next_pc
);
    wire [11:0] imm_i;
    assign imm_i = instr[31:20];
    assign result = pc + 4;
    assign next_pc = (rs1_data + {{20{imm_i[11]}}, imm_i}) & 32'hFFFFFFFE;
endmodule