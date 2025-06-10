`timescale 1ns / 1ps

module instruction_complete(
    input wire clk,
    input wire rst,
    input wire [6:0] c2_op,
    input wire [9:0] c2_op_funct,
    input wire [4:0] c2_rd_sel,
    input wire [31:0] c2_instr, // FULL 32-BIT INSTRUCTION, WHAT DO I DO WITH THIS?
    input wire [31:0] pc,
    input wire mem_ack, // Signal goes high when the data loaded from or stored in memory is complete
    input wire div_wr_reg_req,
    input wire [31:0] mem_rd_data, // THIS IS THE INSTRUCTION ?????? 32-BIT, NOT USED YET
    input wire [4:0] div_wr_reg_sel,
    input wire [31:0] div_wr_reg_data,
    input wire [4:0] decoder_wr_reg_sel,
    input wire decoder_wr_reg_req, // Used to send a write request to the regfile. This request comes 
                                   // comes from teh decoder module
    input wire [31:0] decoder_wr_reg_data,
    output reg [4:0] wr_reg_sel,
    output reg [31:0] wr_reg_data,
    output reg wr_reg_req, // Used to send a write request to the regfile.
    output reg div_wr_reg_ack,
    output reg [31:0] next_pc,
    output reg [4:0] next_state,
    input wire [31:0] alu_result,
    input wire [31:0] fp_alu_result,
    input wire [31:0] fma_result,
    input wire [31:0] decoder_next_pc,
    input wire reg_wr_ack
);
    import op_const_pkg::*;

    // Internal registers
    reg [4:0] wr_reg_sel_next;
    reg [31:0] wr_reg_data_next;
    reg wr_reg_req_next;
    reg div_wr_reg_ack_next;
    reg [31:0] pc_next;
    reg [4:0] state_next;

    // Combinational logic
    always @(*) begin
        pc_next = decoder_next_pc; // the instruction decoder sets how we should handle the pc adjustment
        state_next = C0; // by default, always go to C0. only branch and jump will change this
        
        case (c2_op)
            LOAD: begin
		// BLANK : TO BE FILLED
		// RUDY: NEEDS MORE STUFF !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		          wr_reg_sel_next = decoder_wr_reg_sel;
		          wr_reg_req_next = decoder_wr_reg_req;
		          wr_reg_data_next = mem_rd_data;
            end
            STORE: begin
		// BLANK : TO BE FILLED
		// RUDY: NEEDS MORE STUFF !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		          wr_reg_sel_next = decoder_wr_reg_sel;
		          wr_reg_req_next = decoder_wr_reg_req;
		          wr_reg_data_next = mem_rd_data;
            end
            OPFP: begin
		        // Navya
		        wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = fp_alu_result;
                wr_reg_req_next = 1'b1;
                
                if (~reg_wr_ack) begin
                    state_next = C2;
                end
            end
            OP: begin
                wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = alu_result;
                wr_reg_req_next = 1'b1;
            end
            MADD: begin
                wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = fma_result;
                wr_reg_req_next = 1'b1;
            end
            OPIMM: begin
            // BLANK : TO BE FILLED
            // RUDY: DONE
                wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = decoder_wr_reg_data;
                wr_reg_req_next = decoder_wr_reg_req;
            end
            LUI: begin
                // Use values from the decoder for LUI instructions
                wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = decoder_wr_reg_data;
                wr_reg_req_next = decoder_wr_reg_req;
            end
            JAL: begin
                wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = decoder_wr_reg_data;
                wr_reg_req_next = decoder_wr_reg_req;
            end
            JALR: begin
                wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = decoder_wr_reg_data;
                wr_reg_req_next = decoder_wr_reg_req;
            end
            BRANCH: begin
                wr_reg_sel_next = decoder_wr_reg_sel;
                wr_reg_data_next = decoder_wr_reg_data;
                wr_reg_req_next = 1'b0;
            end
            default : begin
                wr_reg_sel_next = 0;
                wr_reg_data_next = 0;
                wr_reg_req_next = 0;
                pc_next = pc + 4; // if unknown instruction, just increment 4. this won't matter as decoder will halt the core.
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            wr_reg_sel <= 5'b0;
            wr_reg_data <= 32'b0;
            wr_reg_req <= 1'b0;
            div_wr_reg_ack <= 1'b0;
            next_pc <= 32'b0;
            next_state <= 5'b0;
        end else begin
            wr_reg_sel <= wr_reg_sel_next;
            wr_reg_data <= wr_reg_data_next;
            wr_reg_req <= wr_reg_req_next;
            div_wr_reg_ack <= div_wr_reg_ack_next;
            next_pc <= pc_next;
            next_state <= state_next;
        end
    end

endmodule
