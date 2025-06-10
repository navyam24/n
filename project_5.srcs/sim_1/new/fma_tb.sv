
`timescale 1ns / 1ps

import float_const::*;

module fma_tb();

    logic                     clk;
    logic                     rst;
    logic                     req_in;
    logic [float_width - 1:0] mult_a_in;
    logic [float_width - 1:0] mult_b_in;
    logic [float_width - 1:0] add_c_in;
    logic [float_width - 1:0] result_out;
    logic                     ack_out;

    fused_mult_add FMA (
        .clk(clk),
        .rst(rst),
        .req_in(req_in),
        .mult_a_in(mult_a_in),
        .mult_b_in(mult_b_in),
        .add_c_in(add_c_in),
        .result_out(result_out),
        .ack_out(ack_out)
    );
    
    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end
    
    function real to_real(input [float_width - 1:0] fval);
        if(fval == '0) begin
            to_real = '0;
        end else begin
            // given a float in our own representation, convert to opaque verilog real format, and return that
            reg sign;
            reg [float_exp_width - 1:0] exp;
            reg [float_mant_width - 1:0] mant;
            {sign, exp, mant} = fval;
    
            to_real = $itor(mant);
            // $display("mant as real: %0f", to_real);
            // while(exp > 127) begin
                // to_real = to_real 
            // end
            for(int i = 0; i < 23; i++) begin
                to_real = to_real / 2;
            end
            // $display("mant as real: %0f", to_real);
            to_real = 1 + to_real;
            // $display("mant as real: %0f", to_real);
            while(exp > 127) begin
                exp = exp - 1;
                to_real = to_real * 2;
            end
            while(exp < 127) begin
                exp = exp + 1;
                to_real = to_real / 2;
            end
            // $display("mant as real: %0f", to_real);
            if(sign) begin
                to_real = - to_real;
            end
        end
    endfunction  
    
    task fma_op(
        input [float_width - 1:0] mult_a,
        input [float_width - 1:0] mult_b,
        input [float_width - 1:0] add_c
    );
        rst <= 1;
        #10
        rst <= 0;
        #10
        mult_a_in <= mult_a; 
        mult_b_in <= mult_b;   
        add_c_in <=  add_c; 
        rst <= 1;
        #10
        req_in <= 1; 
        #10
        req_in <= 0; 
    
        while (!ack_out) begin
            #10;
        end
        
        $display("FMA Result: %f", to_real(result_out));
        
    endtask
    
    
    
    initial begin
        
        // DEVELOP SMART BARCNHING TO STATES WHERE THE RESULT IS BOUND TO BE 0
        
        fma_op(32'h00000000, 32'h00000000, 32'h00000000); // (0 * 0) + 0 , NO
        fma_op(32'h40e147ae, 32'h41473333, 32'h00000000); // (7.04 * 12.45) + 0 = 87.648, YES
        fma_op(32'h00000000, 32'h40000000, 32'h00000000); // (0 * 2) + 0 , NO       
        fma_op(32'h400ccccd, 32'h404ccccd, 32'h00000000); // (2.2 * 3.2) + 0 = 7.04 , YES
        fma_op(32'h40e147ae, 32'h00000000, 32'h00000000); // (7.04 * 0) + 0 = 0
        
        //fma_op(32'h3f800000, 32'h3f800000, 32'h3f800000); // (1 * 1) + 1 , YES      
        //fma_op(32'h00000000, 32'h3f800000, 32'h3f800000); // (0 * 1) + 1 , YES
        //fma_op(32'h00000000, 32'h40000000, 32'h3f800000); // (0 * 2) + 1 , YES
               
        //fma_op(32'h40066666, 32'h40466666, 32'h40833333); // (2.1 * 3.1) + 4.1 = 10.61 , YES
        //fma_op(32'h400ccccd, 32'h404ccccd, 32'h40866666); // (2.2 * 3.2) + 4.2 = 11.24 , YES
        
        //fma_op(32'h4133d70a, 32'h4129c28f, 32'h4148a3d7); // (11.24 * 10.61) + 12.54 = 131.7964 , YES
        
        //fma_op(32'h3f800000, 32'h3f800000, 32'hbf800000); // (1 * 1) - 1 = 0 , YES
        //fma_op(32'hbf800000, 32'h3f800000, 32'hbf800000); // (-1 * 1) - 1 = -2 , YES
        //fma_op(32'h00000000, 32'hbf800000, 32'hbf800000); // (0 * -1) - 1 = -1 , YES
        
        //fma_op(32'hc0066666, 32'h40466666, 32'hc0833333); // (-2.1 * 3.1) - 4.1 = -10.61 , YES
        //fma_op(32'hc0066666, 32'hc0466666, 32'hc0833333); // (-2.1 * -3.1) - 4.1 = 2.41, YES
        //fma_op(32'hc133d70a, 32'h4129c28f, 32'h4148a3d7); // (-11.24 * 10.61) + 12.54 = -106.7164 , YES
        
        // TEST EXTREM CASES NEXT

        $stop;
    end

endmodule
