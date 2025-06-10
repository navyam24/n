`timescale 1ns / 1ps

module fp_alu (
    input wire clk,
    input wire rst,
    input wire [9:0] op_funct,
    input wire [data_width-1:0] a,
    input wire [data_width-1:0] b,
    output reg [data_width-1:0] result,
    output reg fp_alu_ack,
    input wire fp_alu_activate
);
    import const_pkg::*; 
    import float_const::*;

    wire fadd_ack, fmul_ack;
    wire [31:0] fadd_out, fmul_out;
    reg fadd_req, fmul_req;
    reg [31:0] fadd_result, fmul_result;
    localparam FADD_OP = 10'b0000000000;
    localparam FMUL_OP = 10'b0001000000;

    float_add_pipeline float_adder (
        .clk(clk),
        .rst(rst),
        .req(fadd_req),
        .a(a),
        .b(b),
        .out(fadd_out),
        .ack(fadd_ack)
    );

    float_mul_pipeline float_multiplier (
        .clk(clk),
        .rst(rst),
        .req(fmul_req),
        .a(a),
        .b(b),
        .out(fmul_out),
        .ack(fmul_ack)
    );

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            fadd_result <= 32'b0;
            fmul_result <= 32'b0;
        end else begin
            if (fadd_ack) fadd_result <= fadd_out;
            if (fmul_ack) fmul_result <= fmul_out;
        end
    end

    always @(*) begin
        if (!fp_alu_activate) begin
            result = 'x;
            fp_alu_ack = 1'b1;
            fadd_req = 1'b0;
            fmul_req = 1'b0;
        end else begin
            fadd_req = 1'b0;
            fmul_req = 1'b0;
        
            case(op_funct)
                FADD_OP: begin
		            // BLANK : TO BE FILLED
		            // NAVYA
                    result = fadd_result;
                    fp_alu_ack = fadd_ack;
                    fadd_req = 1'b1;
                end
                FMUL_OP: begin
                    // BLANK : TO BE FILLED
                    // NAVYA
		            result = fmul_result;
                    fp_alu_ack = fmul_ack;
                    fmul_req = 1'b1;
                end
                default: begin
                    result = 'x;
                    fp_alu_ack = 1'b1;
                    fadd_req = 1'b0;
                    fmul_req = 1'b0;
                end
            endcase
        end
    end

endmodule
