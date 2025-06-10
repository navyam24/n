`timescale 1ns / 1ps

module instruction_decoder(
    // RUDY:
    // NEED ALU_RESULT FOR MEM_ADDR FOR LOAD INSTR
    //input wire [data_width - 1:0] alu_result,
    ////////////////////////////////////////////////////////////////    
    input wire clk,
    input wire rst,
    input wire [31:0] instr,
    input wire [31:0] pc,
    input wire [31:0] rs1_data,
    input wire [31:0] rs2_data,
    input wire mem_ack,
    input wire div_wr_reg_req,
    
    output reg [4:0] next_state, // to choose the next state
    output reg [31:0] next_pc, // to choose the next PC, important for branch instructions
    output reg [4:0] wr_reg_sel, // to select the destination register rd
    output reg [31:0] wr_reg_data, // data to write into the regfile, instructions that use this
                                   // signal dont use the ALU
                                   
    output reg wr_reg_req, // Uses to send a request to teh regfile that we want to write to it
    output reg [31:0] mem_addr, // Address to read/write from/to the data memory (not the regfile)
                                // Used for STORE and LOAD instructions
    output reg mem_rd_req, // Used to send a read request to the data memory
    output reg mem_wr_req, // Used to send a write request to the data memory
    output reg [31:0] mem_wr_data, // This is the data that we want to store in the data memory
    
    //////////////////////////////////////////////////////////////////////////////////////////////
    // I believe we set these bits any time our instruction uses the ALU. 
    // The register to register (OP) instructions use the ALU.
    // funct7 and funct3 make a 10-bit value that determins what arithmatic or logical
    // operation we will perform, like DIV. 
    // The "core" module already extracts the operation with the line:
    //      assign alu_op_funct = {instr[31:25], instr[14:12]};
    // So I believe we dont need to do anything with the:
    //      assign funct7 = instr[31:25];
    //      and 
    //      assign funct3 = instr[14:12];
    // lines in this module. 
    // I believe we just need to set these bits when there is a possibility that the
    // instruction, is an R-type instruction (OP)
    output reg n_div_req, // I HAVE NO IDEA HOW/WHEN TO USE THIS
    output reg [4:0] n_div_r_quot_sel,// I HAVE NO IDEA HOW/WHEN TO USE THIS
    output reg [4:0] n_div_r_mod_sel,// I HAVE NO IDEA HOW/WHEN TO USE THIS
    output reg [31:0] n_div_rs1_data,// I HAVE NO IDEA HOW/WHEN TO USE THIS
    output reg [31:0] n_div_rs2_data,// I HAVE NO IDEA HOW/WHEN TO USE THIS
    //////////////////////////////////////////////////////////////////////////////////////////////
    
    output reg halt, // I HAVE NO IDEA HOW/WHEN TO USE THIS. Only the 7'b1111011 and default opcode 
                     // cases set this bit high. Perhaps this signal is used to stop the proccesor from
                     // proceeding when it recieves a faulty opcode, or a specific opcode like 7'b1111011?
    output reg n_out_req, // I think only the custom opcodes uses this
    output reg [31:0] n_out_data, // I think only the custom opcodes uses this
    output reg n_out_float, // I think only the custom opcodes uses this
   
    input wire alu_ack, // Used to keep the proccessor in the C1 state while the ALU is in use.
                        // Once the ALU calulation is done, the ALU sends this bit high which prompts
                        // this module to transition to the C2 state.
    output reg alu_activate, // Used to activate the ALU for an operation
    input wire fp_alu_ack,// Used to keep the proccessor in the C1 state while the FP ALU is in use.
                          // Once the FP ALU calulation is done, the FP ALU sends this bit high which prompts
                          // this module to transition to the C2 state.
    output reg fp_alu_activate, // Used to activate the FP ALU for an operation
    
    // FMA signals
    input wire fma_ack,         // keeps processor in C1 state when FMA module is active
    output reg fma_activate     // used to activate the FMA module
);
    import op_const_pkg::*;
    import const_pkg::*;

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rd, rs1, rs2, rs3;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    

    assign opcode = instr[6:0];
    assign rd = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign funct7 = instr[31:25];
    assign rs3 = instr[31:27];      // relevant for FMA
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // RUDY:
    // SINCE THERE IS NO ALU_RESULT INPUT PORT, WE MUST PERFORM imm[11:0] + rs1 ourselves 
    // for load instructions 
    wire [31:0] load_data_at_mem_addr;
    assign load_data_at_mem_addr = imm_i + rs1_data;
    
    // SINCE THERE IS NO ALU_RESULT INPUT PORT, WE MUST PERFORM imm[11:5] + imm[4:0] + rs1 ourselves 
    // for store instructions
    wire [31:0] store_data_at_mem_addr;
    assign store_data_at_mem_addr = imm_s + rs1_data;
    /////////////////////////////////////////////////////////////////////////////////////////////////

    // Immediate value generation
    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u = {instr[31:12], 12'b0};
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Instruction handler instantiations
    wire [4:0] op_imm_wr_reg_sel;
    wire [31:0] op_imm_wr_reg_data;
    wire op_imm_wr_reg_req;
    wire [31:0] op_imm_next_pc;

    op_imm_handler op_imm_inst(
        .funct3(funct3),
        .rd(rd),
        .rs1(rs1),
        .rs1_data(rs1_data),
        .i_imm(imm_i),
        .wr_reg_sel(op_imm_wr_reg_sel),
        .wr_reg_data(op_imm_wr_reg_data),
        .wr_reg_req(op_imm_wr_reg_req)
    );
    
    wire [31:0] branch_next_pc;
    wire branch_taken;
    op_branch_handler op_branch_inst(
        .opcode(opcode), // RUDY: Port added
        .funct3(funct3),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .pc(pc),
        .branch_offset(imm_b),
        .next_pc(branch_next_pc),
        .branch_taken(branch_taken)
    );

    wire [31:0] lui_result;
    op_lui_handler op_lui_inst(
        .instr(instr),
        .rd(rd),
        .result(lui_result)
    );

    wire [31:0] auipc_result;
    op_auipc_handler op_auipc_inst(
        .instr(instr),
        .rd(rd),
        .pc(pc),
        .result(auipc_result)
    );

    wire [31:0] jal_result, jal_next_pc;
    op_jal_handler op_jal_inst(
        .instr(instr),
        .rd_sel(rd),
        .pc(pc),
        .result(jal_result),
        .next_pc(jal_next_pc)
    );

    wire [31:0] jalr_result, jalr_next_pc;
    op_jalr_handler op_jalr_inst(
        .instr(instr),
        .rd_sel(rd),
        .rs1_data(rs1_data),
        .pc(pc),
        .result(jalr_result),
        .next_pc(jalr_next_pc)
    );

    // Combinational logic
    always @(*) begin
        // default values
        mem_rd_req <= 1'b0; // only goes high in LOAD
        mem_wr_req <= 1'b0; // only goes high in STORE
        n_out_req <= 1'b0; // only goes high with custom out and outr opcodes
        fp_alu_activate <= 1'b0; // only goes high when fp alu is needed
        alu_activate <= 1'b0; // only goes high when alu is needed
        wr_reg_req <= 1'b0; // only goes high when we write to a register
        wr_reg_data <= 32'b0; // only changes when we have data to write to a register 
        wr_reg_sel <= 5'b0; // used to select the specific register we write to
        halt <= 1'b0; // only goes high if opcode is unrecognized or halt instr
        next_pc <= pc + 4; // next_pc gets pc + 4 by default. only changes in jump and branch
        n_out_float <= 1'b0; // only goes high when we want to output a float
        next_state <= C2; // by default, the next state is C2. certain ops will adjust this
        mem_addr <= 32'b0; // only changes when we want to write to a specific address
        fma_activate <= 1'b0;

        case (opcode)
            OPIMM: begin
		// BLANK : TO BE FILLED
		// RUDY: DONE
                wr_reg_req <= op_imm_wr_reg_req; // Yes we want to store/write the imm result in the destination reg in the regfile. This occurs in state C2
                wr_reg_data <= op_imm_wr_reg_data;
                wr_reg_sel <= op_imm_wr_reg_sel;
            end
            LOAD: begin
		// BLANK : TO BE FILLED
                wr_reg_sel <= rd;// Yes we want to store the value at address imm + rs1 in the destination reg "rd" in the regfile. This occurs in state C2
		        // wr_reg_data <= ; // This is the data that is stored at address imm + rs1 in memory
		        // normmaly we would do:  wr_reg_data <= mem_rd_data;, however, there is no mem_rd_data on the input ports.
		        // mem_rd_data does exist as an input port in the instruction_complete module so I will do it there.		        		        		        
		        mem_addr <= load_data_at_mem_addr;		        
		        wr_reg_req <= 1'b1; // Yes we want to store the value at address imm + rs1 in the destination reg "rd" in the regfile. This occurs in state C2
		        // we only want to write to teh regfile while in C2
		        
		        // there is no mem_rd_req in the instruction complete module so I must do it here.
		        mem_rd_req <= 1'b1; // Yes, we want to read something from memory (a load instruction)
		        if (~mem_ack) begin
		          next_state <= C1;
		        end
            end
            STORE: begin
                // BLANK : TO BE FILLED
		        mem_wr_req <= 1'b1; // Yes, we want to store rs2 at address location imm_s + rs1
		        mem_addr <= store_data_at_mem_addr; // Yes, we want to store rs2 at address location imm_s + rs1
		        mem_wr_data <= rs2_data; // Yes, we want to store rs2 at address location imm_s + rs1
		        if (!mem_ack) begin
		          next_state <= C1;
		        end
            end
            BRANCH: begin
                wr_reg_sel <= rd;
                next_pc <= branch_taken ? branch_next_pc : (pc + 4);
                next_state <= C2;
            end
            OPFP: begin
		        // Navya
                fp_alu_activate <= 1'b1;
                if (!fp_alu_ack) begin
                    next_state <= C1;
                end
                wr_reg_sel <= rd;
                wr_reg_req <= 1'b1;
            end
            OP: begin
                alu_activate <= 1'b1;
                if (!alu_ack) begin
                    next_state <= C1;
                end
                wr_reg_sel <= rd;
                wr_reg_req <= 1'b1;
            end
            MADD: begin
                $display("MADD");
                fma_activate <= 1'b1;
                if(!fma_ack) begin
                    next_state <= C1;
                end
                wr_reg_sel <= rd;
                wr_reg_req <= 1'b1;
            end
            LUI: begin
                wr_reg_sel <= rd;
                wr_reg_data <= lui_result;
                wr_reg_req <= 1'b1;
            end
            AUIPC: begin
                wr_reg_sel <= rd;
                wr_reg_data <= auipc_result;
                wr_reg_req <= 1'b1;
            end
            JAL: begin
                // BLANK : TO BE FILLED
                // JAROD - DONE
                next_pc <= jal_next_pc;
                wr_reg_req <= 1'b1;
                wr_reg_data <= jal_result;
                wr_reg_sel <= rd;
            end
            JALR: begin
                // BLANK : TO BE FILLED
                // JAROD - DONE
                next_pc <= jalr_next_pc;
                wr_reg_req <= 1'b1;
                wr_reg_data <= jalr_result;
                wr_reg_sel <= rd;
            end

            7'b0101011: begin // outr (custom opcode)
                n_out_req <= 1'b1;
                n_out_data <= rs1_data;
            end
            7'b1011011: begin // outr.s (custom opcode)
                n_out_req <= 1'b1;
                n_out_data <= rs1_data;
                n_out_float <= 1'b1;
            end
            7'b1111011: begin
                halt <= 1'b1;
                next_state <= C1;
            end
            default: begin
                $display("unhandled opcode");
                halt <= 1'b1;
                next_state <= C1;
                //next_state <= C0;
            end
        endcase
    end

    // Sequential logic with reset
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            fma_activate <= 1'b0;
            fp_alu_activate <= 1'b0;
            alu_activate <= 1'b0;
            next_state <= C1;
            next_pc <= 32'b0;
            wr_reg_sel <= 5'b0;
            wr_reg_data <= 32'b0;
            wr_reg_req <= 1'b0;
            mem_addr <= 32'b0;
            mem_rd_req <= 1'b0;
            mem_wr_req <= 1'b0;
            mem_wr_data <= 32'b0;
            n_div_req <= 1'b0;
            n_div_r_quot_sel <= 5'b0;
            n_div_r_mod_sel <= 5'b0;
            n_div_rs1_data <= 32'b0;
            n_div_rs2_data <= 32'b0;
            halt <= 1'b0;
        end
    end

endmodule
