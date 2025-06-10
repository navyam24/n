`timescale 1ns / 1ps

import const_pkg::*;

module alu (
    input clk,
    input rst,
    
    input [9:0] op_funct,
    input [data_width - 1:0] a,
    input [data_width - 1:0] b,
    output reg [data_width - 1:0] result,
    output reg alu_ack,
    input alu_activate,

    // Division
    input div_req,
    input [reg_sel_width - 1:0] div_r_quot_sel,
    input [reg_sel_width - 1:0] div_r_mod_sel,
    output div_busy,
    output [reg_sel_width - 1:0] div_wr_reg_sel,
    output [data_width - 1:0] div_wr_reg_data,
    output div_wr_reg_req,
    input div_wr_reg_ack
);
    import op_const_pkg::*;

    // Instantiate chunked_add module
    wire [data_width - 1:0] add_result;
    chunked_add #(
        .adder_width(data_width)
    ) chunked_add_inst (
        .a(a),
        .b(b),
        .out(add_result)
    );

    // Instantiate chunked_sub module
    wire [data_width - 1:0] sub_result;
    chunked_sub #(
        .adder_width(data_width)
    ) chunked_sub_inst (
        .a(a),
        .b(b),
        .out(sub_result)
    );

    wire mul_req;
    wire mul_ack;
    wire [data_width - 1:0] mul_out;
    
    // Instantiate existing modules
    assign mul_req = (op_funct == MUL);
    mul_pipeline_32bit mul_pipeline_32bit_(
        .clk(clk),
        .rst(rst),
        .req(mul_req),
        .a(a),
        .b(b),
        .out(mul_out),
        .ack(mul_ack)
    );

    wire div_ack;
    int_div_regfile int_div_regfile_(
        .clk(clk),
        .rst(rst),
        .req(div_req),
        .busy(div_busy),
        .r_quot_sel(div_r_quot_sel),
        .r_mod_sel(div_r_mod_sel),
        .a(a),
        .b(b),
        .rf_wr_sel(div_wr_reg_sel),
        .rf_wr_data(div_wr_reg_data),
        .rf_wr_req(div_wr_reg_req),
        .rf_wr_ack(div_wr_reg_ack)
    );

    // ALU operations
    always @(*) begin
        if (!alu_activate) begin
            result = 'x;
            alu_ack = 1'b0;
        end else begin           
            case(op_funct)
                ADD: result = add_result;
                SUB: result = sub_result;
                MUL: result = mul_out;
                DIV: result = div_wr_reg_data;
                SLT: result = $signed(a) < $signed(b) ? 1 : 0;
                SLTU: result = a < b ? 1 : 0;
                AND: result = a & b;
                OR: result = a | b;
                XOR: result = a ^ b;
                SLL: result = a << b[4:0];
                SRL: result = a >> b[4:0];
                SRA: result = $signed(a) >>> b[4:0];
                default: result = 'x;
            endcase

            case(op_funct)
                MUL: alu_ack = mul_ack;
                DIV: alu_ack = div_wr_reg_req;
                default: alu_ack = 1'b1;
            endcase
        end
    end

endmodule

