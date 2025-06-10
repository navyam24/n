`timescale 1ns / 1ps
`default_nettype wire
`include "assert.sv"

import float_const::*;

module float_add_pipeline(
    input                         clk,
    input                         rst,
    input                         req,
    input [float_width - 1:0]     a,
    input [float_width - 1:0]     b,
    output reg [float_width -1:0] out,
    output reg                      ack
);
    reg                             a_sign;
    reg [float_exp_width - 1:0]     a_exp;
    reg [float_mant_width + 2:0]    a_mant; // [sign][overflow][extra one][stored mantissa]

    reg                             b_sign;
    reg [float_exp_width - 1:0]     b_exp;
    reg [float_mant_width + 2:0]    b_mant;

    reg [float_exp_width - 1:0]     new_exp;
    reg [float_mant_width + 2:0]    new_mant;

    reg [float_exp_width - 1:0]     exp_diff;

    reg [float_mant_width + 2:0]    new_mant_lookup[float_mant_width];
    reg [$clog2(float_mant_width) - 1:0]
                                    norm_shift;

    reg                             new_sign;


    reg [float_width -1:0]          n_out;
    reg                             n_ack;

    reg                             n_a_sign;
    reg [float_exp_width - 1:0]     n_a_exp;
    reg [float_mant_width + 2:0]    n_a_mant; // [sign][overflow][extra one][stored mantissa]

    reg                             n_b_sign;
    reg [float_exp_width - 1:0]     n_b_exp;
    reg [float_mant_width + 2:0]    n_b_mant;

    reg [float_exp_width - 1:0]     n_new_exp;
    reg [float_mant_width + 2:0]    n_new_mant;

    reg                             n_new_sign;


    typedef enum bit[1:0] {
        IDLE,
        S1,
        S2
    } e_state;
    reg [1:0] state;
    reg [1:0] n_state;

    always @(state, req) begin
        n_state = state;

        n_a_sign = a_sign;
        n_a_exp = a_exp;
        n_a_mant = a_mant;
        n_b_sign = b_sign;
        n_b_exp = b_exp;
        n_b_mant = b_mant;
        n_new_exp = new_exp;
        n_new_mant = new_mant;
        n_new_sign = new_sign;

        n_out = '0;
        n_ack = 0;

        for(int shift = 0; shift < float_mant_width; shift++) begin
            new_mant_lookup[shift] = 0;
        end

        case(state)
            IDLE: begin
                `assert_known(req);
                if(req) begin
                    `assert_known(a);
                    `assert_known(b);

                    n_a_mant[float_mant_width + 2:float_mant_width] = 3'b001;
                    {n_a_sign, n_a_exp, n_a_mant[float_mant_width - 1:0]} = a;

                    n_b_mant[float_mant_width + 2:float_mant_width] = 3'b001;
                    {n_b_sign, n_b_exp, n_b_mant[float_mant_width - 1:0]} = b;

                    if(n_a_exp > n_b_exp) begin
                        n_new_exp = n_a_exp;
                        exp_diff = n_a_exp - n_b_exp;
                        n_b_mant = n_b_mant >> exp_diff;
                    end else begin
                        n_new_exp = n_b_exp;
                        exp_diff = n_b_exp - n_a_exp;
                        n_a_mant = n_a_mant >> exp_diff;
                    end

                    n_state = S1;
                end
            end
            S1: begin
                `assert_known(n_a_sign);
                `assert_known(n_b_sign);
           	// BLOCK C : Do the aligned addition/subtraction step. There's no normalising/round required here, that is handled in S2
		// START BLOCK
		         // ADD
		         if (n_a_sign == n_b_sign) begin		              		 
		            n_new_mant = n_a_mant + n_b_mant;
		            n_new_sign = n_a_sign;
		         end
		         else begin // SUBTRACT
		            if (n_a_mant > n_b_mant) begin
		                  n_new_mant = n_a_mant - n_b_mant;
		                  n_new_sign = n_a_sign;
		            end
		            else begin
		                  n_new_mant = n_b_mant - n_a_mant;
		                  n_new_sign = n_b_sign;
		            end
		         end
		         n_state = S2;
		
		// END BLOCK
            end
            S2: begin
                `assert_known(n_new_mant);
                if(n_new_mant[float_mant_width + 1] == 1) begin
                    n_new_mant[float_mant_width + 1:0] = n_new_mant[float_mant_width + 1:0] >> 1;
                    n_new_exp = n_new_exp + 1;
                end
                norm_shift = 0;
                `assert_known(n_new_mant);
                
                if(|n_new_mant == 0) begin
                    // if eveyrthing is zero ,then just return zero
                    n_new_exp = '0;
                    n_new_sign = 0;
                end else begin
                    // shift_int needs to be signed, oterhwise the condition shift_int >= 0 doesnt work
                    // but shift needs to have only $clog2(float_mant_width) bits, because that
                    // is the size of the index of new_mant_lookup
                    for(int shift_int = float_mant_width - 1; shift_int >= 0; shift_int--) begin
                        reg [$clog2(float_mant_width) - 1:0] shift;
                        shift = shift_int[$clog2(float_mant_width) - 1:0];
                        `assert_known(n_new_mant);
                        if(n_new_mant[float_mant_width - shift] == 1) begin
                            norm_shift = shift;
                            new_mant_lookup[shift] = n_new_mant << shift;
                        end
                    end
                    n_new_mant = new_mant_lookup[norm_shift];
                    // norm_shift has fewer bits than n_new_exp
                    // - norm_shift is unsigned, so we can fill up the extra bits with zeros
                    // - n_new_exp is of width float_exp_width
                    // - norm_shift is of width $clog2(float_mant_width)
                    n_new_exp = n_new_exp - { {float_exp_width - $clog2(float_mant_width) {1'b0}}, norm_shift };
                end
                n_out = {n_new_sign, n_new_exp, n_new_mant[float_mant_width - 1:0]};
                n_ack = 1;
                n_state = IDLE;
            end
            default: begin
            end
        endcase

    end

    always @(posedge clk, negedge rst) begin
        if(~rst) begin
            state <= IDLE;

            out <= 0;
            ack <= 0;

            a_sign <= 0;
            a_exp <= '0;
            a_mant <= '0;

            b_sign <= 0;
            b_exp <= '0;
            b_mant <= '0;

            new_exp <= '0;
            new_mant <= '0;
            new_sign <= '0;
            
        end else begin
            out <= n_out;
            ack <= n_ack;

            state <= n_state;

            a_sign <= n_a_sign;
            a_exp <= n_a_exp;
            a_mant <= n_a_mant;

            b_sign <= n_b_sign;
            b_exp <= n_b_exp;
            b_mant <= n_b_mant;

            new_exp <= n_new_exp;
            new_mant <= n_new_mant;
            new_sign <= n_new_sign;
        end
    end
endmodule

