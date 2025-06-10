`timescale 1ns / 1ps

module op_branch_handler(
    input [6:0] opcode, 
    input [2:0] funct3,
    input [31:0] rs1_data,
    input [31:0] rs2_data,
    input [31:0] pc,
    input [31:0] branch_offset,
    output reg [31:0] next_pc,
    output reg branch_taken
);
    import op_const_pkg::*;
    import const_pkg::*;

    always @(*) begin
        branch_taken = 0;
        next_pc = pc + 4;

        case(funct3)
            BEQ: branch_taken = (rs1_data == rs2_data);
            BNE: branch_taken = (rs1_data != rs2_data);
            BGE: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
            BLT: branch_taken = ($signed(rs1_data) < $signed(rs2_data));
            BGEU: branch_taken = (rs1_data >= rs2_data);
            BLTU: branch_taken = (rs1_data < rs2_data);
            default: begin
                        // RUDY: We only want to display an error message if the opcode is indeed a BRANCH instruction
                        //       and funct3 is none of the above in the case statemnet.
                        if (opcode == BRANCH) begin
                            $display("op_branch unhandled funct3 %0d", funct3);
                        end
                        else begin
                            // Do nothing
                        end            
                     end                                  
        endcase

        if (branch_taken) begin
            next_pc = pc + branch_offset;
        end
    end
endmodule
