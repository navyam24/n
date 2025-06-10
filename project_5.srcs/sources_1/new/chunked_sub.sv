`timescale 1ns / 1ps

import const_pkg::*;

module chunked_sub(
    input [adder_width - 1:0] a,
    input [adder_width - 1:0] b,
    output reg [adder_width - 1:0] out
);
    parameter adder_width = 32;
    parameter half_width = adder_width / 2;

    reg [half_width - 1:0] a1, a0;
    reg [half_width - 1:0] b1, b0;
    reg [half_width - 1:0] out0;
    reg [half_width - 1:0] out10, out11;
    reg [half_width - 1:0] out1;
    reg c0; 

    // Sequential block for assigning a1, a0, b1, b0, and performing subtraction
    always @(*) begin
        // Split inputs into two halves
        a1 = a[adder_width-1 : half_width];
        a0 = a[half_width-1 : 0];
        b1 = b[adder_width-1 : half_width];
        b0 = b[half_width-1 : 0];

        // BLOCK A : Perform the two-block subtraction
	    // Over here, we want to perform a chunked subtraction operation similar to our chunked add operation in the provided file
        
        // START BLOCK
        // Perform addition on the lower half
        {c0, out0} = a0 - b0;
        
        // Compute possible results for the upper half
        out10 = a1 - b1;
        out11 = a1 - b1 - 1;
	    // END BLOCK

        out1 = c0 ? out11 : out10; 

        // Concatenate results
        out = {out1, out0};
    end
endmodule

