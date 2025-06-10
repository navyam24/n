`timescale 1ns / 1ps
`default_nettype wire

module float_mul_pipeline #(
    parameter float_width = 32
) (
    input wire clk,
    input wire rst,
    input wire req,
    output reg ack,
    input wire [float_width-1:0] a,
    input wire [float_width-1:0] b,
    output reg [float_width-1:0] out
);

    // Constants for IEEE 754 single-precision
    localparam EXPONENT_WIDTH = 8;
    localparam MANTISSA_WIDTH = 23;
    localparam BIAS = 127;

    // State machine
    reg [2:0] state;
    localparam IDLE = 3'b000, UNPACK = 3'b001, MULTIPLY = 3'b010, NORMALIZE = 3'b011, SET_EXP = 3'b100, PACK = 3'b101;

    // MY VARS
    reg sign_a, sign_b;
    reg [47:0] temp_mantissa_product;

    // Registers and wires
    reg sign;
    reg [EXPONENT_WIDTH-1:0] exponent_a, exponent_b;
    reg [MANTISSA_WIDTH:0] mantissa_a, mantissa_b;
    reg [EXPONENT_WIDTH:0] exponent_sum;
    wire [47:0] mantissa_product;
    reg [MANTISSA_WIDTH-1:0] normalized_mantissa;
    reg [EXPONENT_WIDTH-1:0] final_exponent;

    // Mantissa multiplier signals
    reg start_mul;
    reg set_ack;
    wire mul_ack;

    // Instantiate the mantissa multiplier
    mul_pipeline_cycle_24bit_2bpc mantissa_mul (
        .clk(clk),
        .rst(rst),
        .start(start_mul),
        .set_ack(set_ack),
        .a(mantissa_a),
        .b(mantissa_b),
        .product(mantissa_product),
        .ack(mul_ack)
    );

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            state <= IDLE;
            ack <= 1'b0;
            out <= {float_width{1'b0}};
            start_mul <= 1'b0;
            set_ack <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    ack <= 1'b0;
                    if (req) begin
                        state <= UNPACK;                      
                        set_ack <= 1'b1;
                    end
                end

                UNPACK: begin
                    // BLOCK D : The UNPACK stage : Set up the multiplier for the "MULTPLY" stage
		    // START BLOCK
		          // Extract bits for input A
		          mantissa_a[MANTISSA_WIDTH] <= 1'b1; // Implicit 1
		          {sign_a, exponent_a, mantissa_a[MANTISSA_WIDTH - 1: 0]} = a;
		      
		          // Extract bits for input B
		          mantissa_b[MANTISSA_WIDTH] <= 1'b1; // Implicit 1
		          {sign_b, exponent_b, mantissa_b[MANTISSA_WIDTH - 1: 0]} = b;
		          
		          // Compute output sign
		          sign = (sign_a ^ sign_b);
		          
		          // Start multiplication operation in other module
		          start_mul <= 1'b1;
		          
		          // Deassert the set_ack signal so the multiplication instantiated module
		          // can move onto the next case (setting up the temp register variables (a_reg, b_reg
		          // partial_product, bit_counter))
		          set_ack <= 1'b0;
		          
		          // Transition to next state
		          state <= MULTIPLY;
		          
		    // END BLOCK
                end

                MULTIPLY: begin
                    start_mul <= 1'b0;
                    if (mul_ack) begin
                        exponent_sum <= $signed({1'b0, exponent_a}) + $signed({1'b0, exponent_b}) - BIAS;
                        state <= NORMALIZE;
                    end
                end

                NORMALIZE: begin
                    // BLOCK E : Get the normalised mantissa from the mantissa product outputted from the mantissa multiplier
		    // START BLOCK
		    
		            // Assign top 23 bits from mantissa_product to normalized_mantissa
		            // Use blocking because we need the top 23 bits from mantissa_product 
		            // in the same clock cycle in order to perform the shifting and final 
		            // assignment (to normalized_mantissa) all in the same clock cyle.
		            // Use reg temp variable since "mantissa_product" is wire type		            	                          
	                temp_mantissa_product = mantissa_product;
	                // Overflow	
		            if (mantissa_product[47] == 1'b1) begin
		                  // Use blocking assignment so the shifted result is immediately shifted and can
		                  // be captured by normalized_mantissa within the current clock cycle (no delay). 
		                  temp_mantissa_product = (temp_mantissa_product >> 1);
		                  exponent_sum <= exponent_sum + 1;
		            end
		            
		            // Assign the normalized temp_mantissa_product to normalized_mantissa
		            normalized_mantissa = temp_mantissa_product[46: 46- MANTISSA_WIDTH];
	            
		            // Transition to the next state
		            state <= SET_EXP;
		            
		    // END BLOCK
                end
                
                SET_EXP: begin
                
                    // (the condition was originally just "==", I chaged it to "<=") so that it can
                    // handel zero cases as well
                    if ($signed(exponent_sum) <= 0) begin
                        final_exponent <= {EXPONENT_WIDTH{1'b0}};
                    end else if (exponent_sum[EXPONENT_WIDTH]) begin
                        final_exponent <= {EXPONENT_WIDTH{1'b1}};
                    end else begin
                        final_exponent <= exponent_sum[EXPONENT_WIDTH-1:0];
                    end
                    state <= PACK;
                end
                
                PACK: begin
                    out <= {sign, final_exponent[EXPONENT_WIDTH-1:0], normalized_mantissa[MANTISSA_WIDTH-1:0]};
                    ack <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

