`timescale 1ns / 1ps

module op_imm_handler(
    input [2:0] funct3,
    input [4:0] rd,
    input [4:0] rs1,
    input [31:0] rs1_data,
    input [31:0] i_imm,
    output reg [4:0] wr_reg_sel,
    output reg [31:0] wr_reg_data,
    output reg wr_reg_req
);
    import op_const_pkg::*;

    always_comb begin
        wr_reg_sel = rd;
        wr_reg_req = 1;

        case(funct3)
            ADDI: wr_reg_data = rs1_data + i_imm;
            SLTI: wr_reg_data = $signed(rs1_data) < $signed(i_imm) ? 32'd1 : 32'd0;
            SLTIU: wr_reg_data = rs1_data < i_imm ? 32'd1 : 32'd0;
            XORI: wr_reg_data = rs1_data ^ i_imm;
            ORI: wr_reg_data = rs1_data | i_imm;
            ANDI: wr_reg_data = rs1_data & i_imm;
            SLLI: wr_reg_data = rs1_data << i_imm[4:0];
            SRLI: wr_reg_data = rs1_data >> i_imm[4:0];
            default: begin
                wr_reg_req = 0;
                $display("op_imm unhandled funct3 %0d", funct3);
            end
        endcase
    end
endmodule
