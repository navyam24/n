
`timescale 1ns / 1ps
`default_nettype wire
`include "assert.sv"

import float_const::*;

module fused_mult_add(
    input logic                      clk,
    input logic                      rst,
    input logic                      req_in,
    input logic  [float_width - 1:0] mult_a_in,
    input logic  [float_width - 1:0] mult_b_in,
    input logic  [float_width - 1:0] add_c_in,
    output logic [float_width - 1:0] result_out,
    output logic                     ack_out
);


    // Constants for IEEE 754 single-precision
    localparam EXPONENT_WIDTH = 8;
    localparam MANTISSA_WIDTH = 23;
    localparam DOUBLE_MANTISSA_WIDTH = 46;
    localparam BIAS = 127;
    localparam EXTENDED_MANTISSA_WIDTH = 50;
    localparam MULT_PRODUCT_WIDTH = 48;

    // State encoding
    typedef enum logic [2:0] {IDLE, UNPACK_MULT, MULTIPLY, NORMALIZE_MULT, UNPACK_ADD, ADDITION, NORMALIZE_ADD, PACK} state_t;
    state_t state; // Present state variables
    
    
    // Sign bits
    logic mult_a_sign, mult_b_sign, add_c_sign;
    logic mult_result_sign, final_sign; // "final_sign" is obtained by comparing "mult_result_sign" and "add_c_sign"


    // Exponent bits
    logic [EXPONENT_WIDTH - 1:0] mult_a_exponent, mult_b_exponent, a_exponent, b_exponent;
    logic [EXPONENT_WIDTH : 0] mult_result_exponent; // Contains an extra bit of percision
    logic [EXPONENT_WIDTH - 1 : 0] add_c_exponent, normalized_mult_result_exponent;
    logic [EXPONENT_WIDTH : 0] exponent_diff, final_exponent; // "final_exponent" is obtained by comparing "mult_result_exponent" and "add_c_exponent"
    logic [$clog2(EXTENDED_MANTISSA_WIDTH) - 1:0] shift_exponent_right_normalize;
    logic [$clog2(EXTENDED_MANTISSA_WIDTH) - 1:0] bit_at_index;
    logic bit_at_index_val;
    logic [EXPONENT_WIDTH - 1:0] exponent_out;

    // Mantissa bits for multiplication
    logic [MANTISSA_WIDTH : 0] mult_a_mantissa, mult_b_mantissa; // [extra one][stored mantissa]
    logic [MULT_PRODUCT_WIDTH - 1 : 0] mult_result_mantissa; 
    logic [MULT_PRODUCT_WIDTH - 1 : 0] temp_mantissa_product;
    logic [MANTISSA_WIDTH - 1: 0] mantissa_out;
    logic [1:0] implicit_one_bit;
    logic [MANTISSA_WIDTH - 1 : 0] normalized_mult_result_mantissa; // 47 bits
    
    
    // Mantissa bits for addition 50 bit
    logic [MANTISSA_WIDTH - 1 : 0] add_c_mantissa;
    logic [MANTISSA_WIDTH + 2 : 0] extended_normalized_mult_result_mantissa, extended_c_mantissa; // [sign][overflow][extra one][stored mantissa]
    logic [MANTISSA_WIDTH + 2 : 0] final_mantissa;

    // Mantissa multiplier signals
    logic start_mul;
    logic set_ack;
    logic mul_ack;
    

        // Instantiate the mantissa multiplier
    mul_pipeline_cycle_24bit_2bpc mantissa_mul (
        .clk(clk),
        .rst(rst),
        .start(start_mul),
        .set_ack(set_ack),
        .a(mult_a_mantissa),
        .b(mult_b_mantissa),
        .product(mult_result_mantissa),
        .ack(mul_ack)
    );
    
    
    
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            state <= IDLE;
            ack_out <= 1'b0;
            result_out <= {float_width{1'b0}};
            start_mul <= 1'b0;
            set_ack <= 1'b0;
            
            mult_a_sign <= 1'b0;
            mult_b_sign <= 1'b0;
            add_c_sign <= 1'b0;
            mult_result_sign <= 1'b0;
            final_sign <= 1'b0;
            mult_a_exponent <= 0;
            mult_b_exponent <= 0;
            add_c_exponent <= 0;
            mult_result_exponent <= 0;
            final_exponent <= 0;
            final_mantissa <= 0;
            mult_a_mantissa <= 0;
            mult_b_mantissa <= 0;
            extended_normalized_mult_result_mantissa <= 0;
            extended_c_mantissa <= 0;
            exponent_diff <= 0;
            shift_exponent_right_normalize <= 0;
            bit_at_index <= EXTENDED_MANTISSA_WIDTH - 3; // start at index 47, or final_mantissa[47]
            bit_at_index_val <= 0;
            mantissa_out <= 0;
            exponent_out <= 0;
            temp_mantissa_product <= 0;
            implicit_one_bit <= 0;
            normalized_mult_result_mantissa <= 0;
            add_c_mantissa <= 0;

        end 
        else begin
        
            case(state) 
                IDLE: 
                    begin
                    
                        ack_out = 1'b0;
                        if (req_in) begin
                            set_ack <= 1'b1;
                            state <= UNPACK_MULT;                      
                        
                        end
                        
                    end
               
                UNPACK_MULT: 
                    begin
                     
                        // Extract bits for input A
                        {mult_a_sign, mult_a_exponent, mult_a_mantissa[MANTISSA_WIDTH - 1: 0]} = mult_a_in;
                            
                        // Set implicit 1 for mantissa A (IEEE 754) if exponent is not 0 else dont set implicit 1
                        if (mult_a_exponent != 0) begin
                            mult_a_mantissa[MANTISSA_WIDTH] = 1'b1;
                            //mult_a_exponent = a_exponent;
                        end
                        else begin
                            mult_a_mantissa[MANTISSA_WIDTH] = 1'b0;
                            //mult_a_exponent = -126;
                        end                                       
                                       
                        // Extract bits for input B
                        {mult_b_sign, mult_b_exponent, mult_b_mantissa[MANTISSA_WIDTH - 1: 0]} = mult_b_in;                                             
                                       
                        // Set implicit 1 for mantissa B (IEEE 754) if exponent is not 0 else dont set implicit 1
                        if (mult_b_exponent != 0) begin
                            mult_b_mantissa[MANTISSA_WIDTH] = 1'b1;
                            //mult_b_exponent = b_exponent;
                        end
                        else begin
                            mult_b_mantissa[MANTISSA_WIDTH] = 1'b0;
                            //mult_b_exponent = -126;
                        end
                                                    
                        // Compute sign for multiplication result
                        mult_result_sign = mult_a_sign ^ mult_b_sign;
                    
                        // Sign bit for C variable 
                        add_c_sign = add_c_in[31];
                            
                        // 8-bit exponent for C
                        add_c_exponent = add_c_in[30:23];
                            
                        // 23-bit mantissa for C
                        add_c_mantissa = add_c_in[22:0];
                        
                        // Add [sign][overflow][extra one] [stored mantissa], 26-bit
                        extended_c_mantissa = {3'b001, add_c_mantissa};
                    
                        // If the product of A x B is zero, then just pass C to the output 
                        if (((|mult_a_mantissa[MANTISSA_WIDTH - 1: 0] == 0) && (mult_a_exponent == 0)) || ((|mult_b_mantissa[MANTISSA_WIDTH - 1: 0] == 0) && (mult_b_exponent == 0))) begin
                            final_sign = add_c_sign;
                            final_exponent = add_c_exponent;
                            final_mantissa = add_c_mantissa;
                            state <= PACK;
                        end 
                        // If input A is 1, then just skip mult states and add B + C       
                        else if ((|mult_a_mantissa[MANTISSA_WIDTH - 1: 0] == 0) && (mult_a_exponent == 8'b01111111)) begin
                            normalized_mult_result_mantissa = mult_b_mantissa[MANTISSA_WIDTH - 1: 0];
                            normalized_mult_result_exponent = mult_b_exponent;
                            mult_result_sign = mult_result_sign;
                            state <= UNPACK_ADD;
                        end
                        // If input B is 1, then just skip mult states and add A + C       
                        else if ((|mult_b_mantissa[MANTISSA_WIDTH - 1: 0] == 0) && (mult_b_exponent == 8'b01111111)) begin
                            normalized_mult_result_mantissa = mult_a_mantissa[MANTISSA_WIDTH - 1: 0];
                            normalized_mult_result_exponent = mult_a_exponent;
                            mult_result_sign = mult_result_sign;
                            state <= UNPACK_ADD;
                        end
                        else begin                                                           
                                                    
                            // Initalize multiplication variables 
                            start_mul <= 1'b1;
                                      
                            // Initalize ack signal from mutiplication instatiated module to zero
                            set_ack <= 1'b0;
                                              
                            // Transition to next state
                            state <= MULTIPLY;
                        end
                    end
                    
                MULTIPLY: 
                    begin
                    
                        // Execute multi-cycle multiplication operation
                        start_mul <= 1'b0;                       
                        
                        if (mult_a_exponent == 0 || mult_b_exponent == 0) begin
                            mult_result_exponent = 0; // Force smallest possible exponent
                        end 
                        else begin
                            mult_result_exponent = $signed({1'b0, mult_a_exponent}) + $signed({1'b0, mult_b_exponent}) - BIAS;
                        end 
                            
                        // CLAMP THE EXPONENT IF OVERFLOW OR UNDERFLOW OCCURS
                            
                        // Handles overflow to infinity exponent
                        if (mult_result_exponent >= 255) begin
                            mult_result_exponent <= 255; // Infinity
                        end                            
                        // Handles underflows to zero or subnormal representation.
                        else if (mult_result_exponent <= 0) begin
                            mult_result_exponent <= 0; // Subnormal or Zero
                        end
                        
                        
                        
                        // When multi-cycle multiplication is done, enter to change the state
                        if (mul_ack) begin
                            
                            temp_mantissa_product <= mult_result_mantissa;
                                                     
                            state <= NORMALIZE_MULT;
                        end
                        
                    end
                    
                NORMALIZE_MULT:
                    begin          
                        
                        // Overflow 
                        if ((temp_mantissa_product[47] == 1'b1) && (mult_result_exponent < 255)) begin
                            temp_mantissa_product <= temp_mantissa_product >> 1;
                            mult_result_exponent <= mult_result_exponent + 1;
                        end
                        // index 46 is the implicit 1 spot, bit 46 must be 1 to be normalized
                        else if (temp_mantissa_product[46] == 1'b0 && (temp_mantissa_product[45:0] != 46'b0) && (mult_result_exponent != 0)) begin
                            temp_mantissa_product <= temp_mantissa_product << 1;
                            mult_result_exponent <= mult_result_exponent - 1;
                        end
                        else begin
                            normalized_mult_result_mantissa <= temp_mantissa_product[45: 23];
                            normalized_mult_result_exponent <= mult_result_exponent[EXPONENT_WIDTH - 1 : 0];
                            state <= UNPACK_ADD;
                        end
                        
                    end
                    
                UNPACK_ADD: 
                    begin
                        
                        // Skip addition if C variable is zero and return the product
                        if (add_c_exponent == 0 && add_c_mantissa == 0) begin
                            final_exponent = normalized_mult_result_exponent;
                            final_mantissa = normalized_mult_result_mantissa;
                            final_sign = mult_result_sign;
                            state <= PACK;
                        end
                        // If the mult product is zero then just skip addition and return C variable 
                        else if (normalized_mult_result_mantissa == 0 && normalized_mult_result_exponent == 0) begin
                            final_sign = add_c_sign;
                            final_exponent = add_c_exponent;
                            final_mantissa = add_c_mantissa;
                            state <= PACK;
                        end
                        else begin
                            // Continue normal execution
                            
                            
                            if (normalized_mult_result_exponent < 255) begin
                            // 26-bit mantissa, [sign][overflow][extra one][stored mantissa (mantissa product)]
                                extended_normalized_mult_result_mantissa = {3'b001, normalized_mult_result_mantissa};
                            end 
                            else begin
                                extended_normalized_mult_result_mantissa = {3'b000, normalized_mult_result_mantissa};
                            end
                            
                            
                            if (add_c_exponent > normalized_mult_result_exponent) begin
                                final_exponent = add_c_exponent;
                                exponent_diff = add_c_exponent - normalized_mult_result_exponent;                               
                                
                                if (exponent_diff < MANTISSA_WIDTH) begin
                                    extended_normalized_mult_result_mantissa <= extended_normalized_mult_result_mantissa >> exponent_diff;
                                end
                                else begin
                                    extended_normalized_mult_result_mantissa <= extended_normalized_mult_result_mantissa;
                                end
                            end
                            else begin
                                final_exponent = normalized_mult_result_exponent;
                                exponent_diff = normalized_mult_result_exponent - add_c_exponent;
                                
                                if (exponent_diff < MANTISSA_WIDTH) begin 
                                    extended_c_mantissa <= extended_c_mantissa >> exponent_diff;         
                                end
                                else begin
                                    extended_c_mantissa <= extended_c_mantissa;
                                end               
                            end
                            
                            state <= ADDITION;
                        end
                    end
                
                ADDITION: 
                    begin
                        // ADD POSITIVE C               
                        if (add_c_sign == mult_result_sign) begin		              		 
                            final_mantissa = extended_c_mantissa + extended_normalized_mult_result_mantissa;
                            final_sign = add_c_sign;
                         end
                         else begin // ADD NEGATIVE C
                            if (extended_c_mantissa > extended_normalized_mult_result_mantissa) begin
                                  final_mantissa = extended_c_mantissa - extended_normalized_mult_result_mantissa;
                                  final_sign = add_c_sign;
                            end
                            else begin
                                  final_mantissa = extended_normalized_mult_result_mantissa - extended_c_mantissa;
                                  final_sign = mult_result_sign;
                            end
                         end 
                         
                         state <= NORMALIZE_ADD;
                         
                    end
                    
                NORMALIZE_ADD: 
                    begin  
                        
                        // Overflow 
                        if (final_mantissa[24] == 1'b1) begin
                            final_mantissa <= final_mantissa >> 1;
                            final_exponent <= final_exponent + 1;
                        end
                        // index 23 is the implicit 1 spot, bit 23 must be 1 to be normalized
                        else if ((final_mantissa[23] == 1'b0) && (final_mantissa[22:0] != 0)) begin
                            final_mantissa <= final_mantissa << 1;
                            final_exponent <= final_exponent - 1;
                        end
                        else begin
                            final_mantissa <= final_mantissa[MANTISSA_WIDTH: 0];
                            //state <= PACK;
                        end
                        
                        if ((|final_mantissa) == 0) begin
                            // If everything is zero, return zero
                            final_exponent = 0;
                            final_sign = 0;
                            //state <= PACK;
                        end 
                        
                        state <= PACK;           
                    end 

                PACK: 
                    begin
                        // Need special handling for NaNs 
                        if (final_exponent == 255 && final_mantissa != 0) begin
                            result_out = {1'b0, 8'hFF, 23'h1}; // NaN
                        end 
                        // Need handling for Infinity 
                        else if (final_exponent == 255) begin
                            result_out = {final_sign, 8'hFF, 23'h0}; // Infinity
                        end else begin
                        
                            mantissa_out = final_mantissa[MANTISSA_WIDTH - 1 : 0];
                            
                            exponent_out = final_exponent[EXPONENT_WIDTH - 1 : 0];
                        
                            result_out = {final_sign, exponent_out, mantissa_out};
                        end
                        
                        ack_out = 1;
                        state <= IDLE;
                    end
    
            endcase
        end
    end
   

endmodule