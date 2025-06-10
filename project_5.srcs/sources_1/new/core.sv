`timescale 1ns / 1ps

module core(
    input wire clk,
    input wire rst,
    input wire clr,
    input wire ena,
    input wire set_pc_req,
    input wire [addr_width - 1:0] set_pc_addr,

    output reg [data_width - 1:0] out,
    output reg outen,
    output reg outflen,

    output reg halt,

    // Memory interface
    output reg [addr_width - 1:0] mem_addr,
    input wire [data_width - 1:0] mem_rd_data, // THIS IS THE 32-BIT INSTRUCTION FROM THE TB
    output reg [data_width - 1:0] mem_wr_data,
    output reg mem_wr_req,
    output reg mem_rd_req,
    input wire mem_ack,
    input wire mem_busy,
    input wire outr_ack
);
    import op_const_pkg::*;
    import const_pkg::*;  
    

    // Internal registers
    reg [addr_width - 1:0] pc;
    reg [4:0] state;
    reg [instr_width - 1:0] instr; // THIS IS NOT ASSIGNED TO THE INCOMING INSTRUCTION. WE MUST ASSIGN IT???
    reg [instr_width - 1:0] c2_instr; // THIS IS NOT ASSIGNED TO THE INCOMING INSTRUCTION. WE MUST ASSIGN IT???
    reg instruction_executed;
    reg output_done;
    reg mem_ack_received;      // Tracks whether mem_ack has been received for a load instruction

    // Decoder outputs
    wire [4:0] decoder_next_state;
    wire [31:0] decoder_next_pc;
    wire [4:0] decoder_wr_reg_sel;
    wire [31:0] decoder_wr_reg_data;
    wire decoder_wr_reg_req;
    wire [31:0] decoder_mem_addr;
    wire decoder_mem_rd_req;
    wire decoder_mem_wr_req;
    wire [31:0] decoder_mem_wr_data;
    wire decoder_n_div_req;
    wire [4:0] decoder_n_div_r_quot_sel;
    wire [4:0] decoder_n_div_r_mod_sel;
    wire [31:0] decoder_n_div_rs1_data;
    wire [31:0] decoder_n_div_rs2_data;
    wire decoder_halt;
    wire decoder_n_out_req;
    wire [31:0] decoder_n_out_data;
    wire decoder_n_out_float;

    // Regfile signals
    wire [data_width-1:0] rs1_data, rs2_data, rs3_data;
    wire [addr_width-1:0] rs1_addr, rs2_addr, rs3_addr, rd_addr;
    wire reg_we;
    wire [data_width-1:0] rd_data;
    wire reg_wr_ack;

    // ALU signals
    wire [9:0] alu_op_funct;
    wire [data_width-1:0] alu_result;
    wire alu_ack;
    wire div_busy;
    wire [reg_sel_width-1:0] div_wr_reg_sel;
    wire [data_width-1:0] div_wr_reg_data;
    wire div_wr_reg_req;
    reg div_wr_reg_ack;
    wire alu_activate;
    wire decoder_alu_activate;
    
    //FP ALU Signals
    wire [31:0] fp_alu_result;
    wire fp_alu_ack;
    wire fp_alu_activate;
    wire decoder_fp_alu_activate;
    
    // Instruction complete signals
    wire [4:0] ic_wr_reg_sel;
    wire [31:0] ic_wr_reg_data;
    wire ic_wr_reg_req;
    wire ic_div_wr_reg_ack;
    wire [31:0] ic_next_pc;
    wire [4:0] ic_next_state;

    // Instantiate regfile
    regfile regfile_inst (
        .clk(clk),
        .rst(rst),
        .rs1_addr(rs1_addr),
        .rs1_data(rs1_data),
        .rs2_addr(rs2_addr),
        .rs2_data(rs2_data),
        .rs3_data(rs3_data),
        .rs3_addr(rs3_addr),
        .we(reg_we),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .wr_ack(reg_wr_ack)
    );

    // Instantiate ALU
    alu alu_inst (
        .clk(clk),
        .rst(rst),
        .op_funct(alu_op_funct),
        .a(rs1_data),
        .b(rs2_data),
        .result(alu_result),
        .alu_ack(alu_ack),
        .div_req(decoder_n_div_req),
        .div_r_quot_sel(decoder_n_div_r_quot_sel),
        .div_r_mod_sel(decoder_n_div_r_mod_sel),
        .div_busy(div_busy),
        .div_wr_reg_sel(div_wr_reg_sel),
        .div_wr_reg_data(div_wr_reg_data),
        .div_wr_reg_req(div_wr_reg_req),// OUTPUT
        .div_wr_reg_ack(div_wr_reg_ack),
        .alu_activate(alu_activate)
    );

    fp_alu fp_alu_inst (
        .clk(clk),
        .rst(rst),
        .op_funct(alu_op_funct),
        .a(rs1_data),
        .b(rs2_data),
        .result(fp_alu_result),
        .fp_alu_ack(fp_alu_ack),
        .fp_alu_activate(fp_alu_activate)
    );
    
    // FMA signals
    wire fmadd_ack;
    wire [data_width-1:0] fmadd_out;
    wire fmadd_req;
    reg [data_width-1:0] fmadd_result;
    wire [data_width-1:0] fmadd_a, fmadd_b, fmadd_c;
    wire decoder_fmadd_activate;
    
    assign fmadd_req = (state == C0) ? 1'b0 : decoder_fmadd_activate;
    
    // instantiate FMA module
    fused_mult_add FMA (
        .clk(clk),
        .rst(rst),
        .req_in(fmadd_req),
        .mult_a_in(rs1_data),
        .mult_b_in(rs2_data),
        .add_c_in(rs3_data),
        .result_out(fmadd_out),
        .ack_out(fmadd_ack)
    );
    
    // Instantiate instruction decoder
    instruction_decoder decoder(
        .clk(clk),
        .rst(rst),
        .instr(instr),
        .pc(pc),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .mem_ack(mem_ack),
        .div_wr_reg_req(div_wr_reg_req), // INPUT
        .next_state(decoder_next_state),
        .next_pc(decoder_next_pc),
        .wr_reg_sel(decoder_wr_reg_sel),
        .wr_reg_data(decoder_wr_reg_data),
        .wr_reg_req(decoder_wr_reg_req),
        .mem_addr(decoder_mem_addr),
        .mem_rd_req(decoder_mem_rd_req),
        .mem_wr_req(decoder_mem_wr_req),
        .mem_wr_data(decoder_mem_wr_data),
        .n_div_req(decoder_n_div_req),
        .n_div_r_quot_sel(decoder_n_div_r_quot_sel),
        .n_div_r_mod_sel(decoder_n_div_r_mod_sel),
        .n_div_rs1_data(decoder_n_div_rs1_data),
        .n_div_rs2_data(decoder_n_div_rs2_data),
        .halt(decoder_halt),
        .n_out_req(decoder_n_out_req),
        .n_out_data(decoder_n_out_data),
        .n_out_float(decoder_n_out_float),
        .alu_ack(alu_ack),
        .alu_activate(decoder_alu_activate),
        .fp_alu_ack(fp_alu_ack),
        .fp_alu_activate(decoder_fp_alu_activate),
        .fma_ack(fmadd_ack),
        .fma_activate(decoder_fmadd_activate)
    );

    // Instantiate instruction_complete
    instruction_complete ic_inst (
        .clk(clk),
        .rst(rst),
        .c2_op(c2_instr[6:0]),
        .c2_op_funct(c2_instr[31:25]),
        .c2_rd_sel(c2_instr[11:7]),
        .c2_instr(c2_instr),
        .pc(pc),
        .mem_ack(mem_ack),
        .div_wr_reg_req(div_wr_reg_req), // INPUT
        .mem_rd_data(mem_rd_data), // THIS IS THE INSTRUCTION ?????? 32-BIT
        .div_wr_reg_sel(div_wr_reg_sel),
        .div_wr_reg_data(div_wr_reg_data),
        .decoder_wr_reg_sel(decoder_wr_reg_sel),
        .decoder_wr_reg_req(decoder_wr_reg_req),
        .decoder_wr_reg_data(decoder_wr_reg_data),
        .wr_reg_sel(ic_wr_reg_sel),
        .wr_reg_data(ic_wr_reg_data),
        .wr_reg_req(ic_wr_reg_req),
        .div_wr_reg_ack(ic_div_wr_reg_ack),
        .next_pc(ic_next_pc), // OUTPUT, DOESNT GO ANYWHERE YET, perhaps we dont use
                              // this signal since the tb is providing the next
                              // PC value to read through the lines in the HEX file.
        .next_state(ic_next_state),
        .alu_result(alu_result),
        .fp_alu_result(fp_alu_result),
        .fma_result(fmadd_out),
        .decoder_next_pc(decoder_next_pc), // INPUT, COMES FROM DECODER
        .reg_wr_ack(reg_wr_ack)
    );

    // Instruction fetch mechanism
    reg fetch_req;
    reg [addr_width-1:0] fetch_addr;

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            fetch_req <= 1'b0;
            fetch_addr <= 'b0;
        end else if (clr) begin
            fetch_req <= 1'b0;
            fetch_addr <= 'b0;
        end else if (ena) begin
            if (state == C0) begin
                fetch_addr <= pc;
  //              if (fetch_addr == pc) begin
                if(~mem_ack) begin
                    fetch_req <= 1'b1;
                end else begin
                    fetch_req <= 1'b0;
                end
            end else begin
                fetch_req <= 1'b0;
            end
        end
    end

    // RUDY:
    // TEST VARS
    reg set_instr_vars_flag;

    // Main control logic
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            pc <= 'b0;
            state <= C0;
            instr <= 'b1;
            c2_instr <= 'b0;
            halt <= 1'b0;
            instruction_executed <= 1'b0;
            mem_ack_received <= 1'b0;
            
            // RUDY: ///////////////////////////////////////////////////////////////////////////
            // MY VARS
            set_instr_vars_flag <= 1'b0;
            ///////////////////////////////////////////////////////////////////////////////
            
        end else if (clr) begin
            pc <= 'b0;
            state <= C0;
            instr <= 'b0;
            c2_instr <= 'b0;
            halt <= 1'b0;
            instruction_executed <= 1'b0;
            mem_ack_received <= 1'b0;
            
            // RUDY: ///////////////////////////////////////////////////////////////////////////
            // MY VARS
            set_instr_vars_flag <= 1'b0;
            ///////////////////////////////////////////////////////////////////////////////
        end else if (~ena) begin       
            if (set_pc_req) begin
                pc <= set_pc_addr;
                state <= C0;
                instruction_executed <= 1'b0;
            end 
        end
        else begin
        
            mem_ack_received <= mem_ack;
            
            case (state)
                // RUDY: DONE
                C0: begin // Instruction fetch
                    // BLANK : TO BE FILLED
                    if (mem_ack) begin
                        instr <= mem_rd_data;
                        c2_instr <= mem_rd_data;
                        set_instr_vars_flag <= 1'b1;
                        state <= C1;
                    end
                end
                // RUDY: DONE
                C1: begin // Instruction Decode and Execute 
                    // BLANK : TO BE FILLED
                    instruction_executed <= 1; // RUDY: To set "halt" high if we recieve "decoder_halt" signal, see line 308
                    if (decoder_next_state == C2) begin
                        state <= C2;
                        output_done <= 1'b0; // JAROD                       
                    end
                    else if (decoder_next_state == C0) begin
                        state <= C0;
                    end
                end
                // RUDY: DONE
                C2: begin // Instruction Complete
                    // BLANK : TO BE FILLED
                    if (ic_next_state == C0) begin 
                        state <= C0;
                        pc <= ic_next_pc; // JAROD
                    end
                    else if (ic_next_state == C1) begin
                        state <= C1;
                    end
                end
                default: state <= C0;
            endcase
        if (instruction_executed && decoder_halt) begin /////////////////////////// instruction_executed never gets set
            halt <= 1'b1;
        end
        end
    end
    
    wire [6:0] opcode;
    assign opcode = instr[6:0];
    
    
    // RUDY
    //////////////////////////////////////////////////////////////////////////////////////////////////
    reg [4:0] funct5_float;
    reg is_float_mult_instr;
    reg is_int_mult_instr;
    
    assign funct5_float = instr[31:27]; 
    assign is_float_mult_instr = (opcode == OPFP) && (funct5_float == FMUL);
    assign is_int_mult_instr = (opcode == OP) && (alu_op_funct == MUL);
    //////////////////////////////////////////////////////////////////////////////////////////////////

    // Memory interface
    always @(*) begin
        // default values
        mem_addr = 'b0;
        mem_rd_req = 1'b0;
        mem_wr_req = 1'b0;
        mem_wr_data = 'b0;
        
        // Enter this case if we want to fetch the instruction that originated from the tb.
        // This case is were we start sending the signals to the "global_mem_controller" to
        // fetch the instruction from its 2D mem array that it got from the tb (HEX file).
        if (fetch_req) begin
            mem_addr = fetch_addr;
            mem_rd_req = 1'b1;
        // Enter this case if the instruction is STORE or LOAD
        end else begin
            mem_addr = decoder_mem_addr;
            if (state == C1) begin
                mem_rd_req = decoder_mem_rd_req && !mem_ack;
                mem_wr_req = decoder_mem_wr_req;
                mem_wr_data = decoder_mem_wr_data;
            end
        end
    end

    // Register file control
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rs3_addr = c2_instr[6:0] == MADD ? instr[31:27] : 'b0;
    assign rd_addr = ic_wr_reg_sel;
    assign reg_we = (state == C2) && (
        (ic_wr_reg_req && c2_instr[6:0] != LOAD) || // For non-load instructions
        (ic_wr_reg_req && c2_instr[6:0] == LOAD && mem_ack_received) // For load word (lw) instruction
    );

    assign rd_data = ic_wr_reg_data;

    // ALU control
    assign alu_op_funct = {instr[31:25], instr[14:12]};
    assign alu_activate = (state == C0) ? 1'b0 : decoder_alu_activate;
    assign fp_alu_activate = (state == C0) ? 1'b0 : decoder_fp_alu_activate;

    // Output control
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            out <= 0;
            outen <= 0;
            outflen <= 0;
        end
        if (ena && decoder_n_out_req && state == C2 && !output_done) begin
            out <= decoder_n_out_data;
            //outen <= decoder_n_out_req;
            outen <= 1'b1;
            outflen <= decoder_n_out_float;
        end
        else begin
            out <= 0;
            outen <= 0;
            outflen <= 0;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            output_done <= 1'b1;
        end else if (clr) begin
            output_done <= 1'b0;
        end else if (ena && state == C2 && !output_done) begin
            if (decoder_n_out_req && !output_done) begin
                output_done <= 1'b1;
            end else if (!decoder_n_out_req) begin
                output_done <= 1'b0;
            end
        end
    end



endmodule
