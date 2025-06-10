`timescale 1ns / 1ps

module mul_pipeline_cycle_24bit_2bpc(
    input wire clk,
    input wire rst,
    input wire start,
    input wire set_ack,
    input wire [23:0] a,
    input wire [23:0] b,
    output reg [47:0] product,
    output reg ack
);
    reg [23:0] a_reg, b_reg;
    reg [47:0] partial_product;
    reg [4:0] bit_counter;

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            a_reg <= 24'b0;
            b_reg <= 24'b0;
            partial_product <= 48'b0;
            bit_counter <= 5'b0;
            product <= 48'b0;
            ack <= 1'b0;
        end else if (set_ack) begin
            ack <= 1'b0;
        end else if (start) begin
            a_reg <= a;
            b_reg <= b;
            partial_product <= 48'b0;
            bit_counter <= 5'b0;
        end else if (!ack) begin
            // BLOCK F : Calculate the mantissa product and give an ack when the product is ready
	    // START BLOCK
	       if (bit_counter <= 22) begin
                partial_product <= partial_product + 
                                                    ({24'b0, (b_reg[bit_counter] ? a_reg : 24'b0)} << bit_counter) + 
                                                    ({24'b0, (b_reg[bit_counter + 1] ? a_reg : 24'b0)} << (bit_counter + 1));
                
                bit_counter <= bit_counter + 2;
           end
	       else begin
	           product <= partial_product;
	           ack <= 1'b1;
	       end
	    // END BLOCK
        end
    end
endmodule

