`timescale 1ns / 1ps

module chunked_add #(
    parameter adder_width = 32
)(
    input [adder_width - 1:0] a,
    input [adder_width - 1:0] b,
    output reg [adder_width - 1:0] out
);
    // Derived parameters
    localparam half_width = adder_width / 2;

    // Intermediate signals
    reg [half_width - 1:0] a1, a0;
    reg [half_width - 1:0] b1, b0;
    reg [half_width - 1:0] out0;
    reg [half_width - 1:0] out10, out11;
    reg [half_width - 1:0] out1;
    reg c0;

    always @(*) begin
        // Split inputs into two halves
        {a1, a0} = a;
        {b1, b0} = b;

        // Perform addition on the lower half
        {c0, out0} = a0 + b0;

        // Compute possible results for the upper half
        out10 = a1 + b1;
        out11 = a1 + b1 + 1;

        // Select upper half result based on carry from lower half
        out1 = c0 ? out11 : out10;

        // Concatenate upper and lower halves for the final output
        out = {out1, out0};
    end
endmodule
