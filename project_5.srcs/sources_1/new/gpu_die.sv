`timescale 1ns / 1ps
`default_nettype wire

module gpu_die(
    input clk,
    input rst,

    // Communication with mainboard CPU
    input cpu_instr_type,  
    input [31:0] cpu_in_data,
    input wire outr_ack,
    output reg [31:0] cpu_out_data, // Goes nowhere (fine)
    output reg cpu_out_ack, // Comes from GPU controller

    output reg outflen,
    output reg outen,
    output reg [data_width - 1:0] out
);
    
    // GPU Controller States
    localparam NOP = 0, COPY_TO_GPU = 1, COPY_FROM_GPU = 2, KERNEL_LAUNCH = 3;
    
    wire core1_mem_rd_req;
    wire core1_mem_wr_req;

    wire [addr_width - 1:0] core1_mem_addr;
    wire [data_width - 1:0] core1_mem_rd_data;
    wire [data_width - 1:0] core1_mem_wr_data;

    wire core1_mem_busy;
    wire core1_mem_ack;
    wire core1_outflen;
    wire core1_outen;
    wire [data_width - 1:0] core1_out;

    wire contr_mem_wr_en;
    wire contr_mem_rd_en;
    wire [addr_width - 1:0] contr_mem_addr;
    wire [data_width - 1:0] contr_mem_wr_data;
    wire [data_width - 1:0] contr_mem_rd_data;
    wire contr_mem_ack;
    wire contr_outflen;
    wire [data_width - 1:0] contr_out;

    wire contr_core1_ena;
    wire contr_core1_clr;
    wire contr_core1_set_pc_req;
    wire [data_width - 1:0] contr_core1_set_pc_addr;
    wire contr_core1_halt;
    wire [2:0] contr_state;
    wire [2:0] contr_prev_state;
    
    reg core1_halt;

    // Instantiate global memory controller
    global_mem_controller global_mem_controller_(
        .clk(clk),
        .rst(rst),

        // Memory requests from core
        .core1_addr(core1_mem_addr),
        .core1_wr_req(core1_mem_wr_req),
        .core1_rd_req(core1_mem_rd_req),
        .core1_rd_data(core1_mem_rd_data),
        .core1_wr_data(core1_mem_wr_data),
        .core1_busy(core1_mem_busy),
        .core1_ack(core1_mem_ack),

        // Memory requests from GPU controller
        .contr_wr_en(contr_mem_wr_en),
        .contr_rd_en(contr_mem_rd_en),
        .contr_addr(contr_mem_addr),
        .contr_wr_data(contr_mem_wr_data),
        .contr_rd_data(contr_mem_rd_data),
        .contr_ack(contr_mem_ack) // OUTPUT: If the instruction from the tb has been stored in mem
                                  //         then send acknowledge signal
    );

    // Instantiate core
    core core1(
        .rst(rst),
        .clk(clk),
        .clr(contr_core1_clr),
        .ena(contr_core1_ena),
        .set_pc_req(contr_core1_set_pc_req),
        .set_pc_addr(contr_core1_set_pc_addr),

        .outflen(core1_outflen),
        .out(core1_out),
        .outen(core1_outen),

        .halt(contr_core1_halt),// Output

        // Memory interface to global memory controller
        .mem_addr(core1_mem_addr),
        .mem_rd_data(core1_mem_rd_data), // Receive data from memory
        .mem_wr_data(core1_mem_wr_data), // Data to write to memory
        .mem_ack(core1_mem_ack),          // Acknowledge signal from memory
        .mem_busy(core1_mem_busy),        // Busy signal from memory
        .mem_rd_req(core1_mem_rd_req),   // Read request signal
        .mem_wr_req(core1_mem_wr_req),    // Write request signal,
        .outr_ack(outr_ack)
    );

    // Instantiate GPU controller with correct signals
    gpu_controller gpu_controller_(
        .clk(clk),
        .rst(rst),

        // CPU communication signals
        .cpu_instr_type(cpu_instr_type),
        .cpu_in_data(cpu_in_data),

        .mem_ack(contr_mem_ack), // Input: If the instruction from the tb has been stored in mem
                                       // then send acknowledge signal
        .outr_ack(outr_ack),

        // Memory control signals for global memory controller initiated by GPU controller
        .mem_wr_en(contr_mem_wr_en),       // Write enable for memory operations initiated by GPU controller
        .mem_rd_en(contr_mem_rd_en),       // Read enable for memory operations initiated by GPU controller
        .mem_addr(contr_mem_addr),      // Address for write operations initiated by GPU controller
        .mem_data(contr_mem_wr_data),      // Data for write operations initiated by GPU controller

        // Control signals for core operation
        .contr_core1_ena(contr_core1_ena),       // Enable signal for core operation
        .contr_core1_set_pc_req(contr_core1_set_pc_req), 
        .contr_core1_set_pc_addr(contr_core1_set_pc_addr),

        // Input signal to check if the core is halted
        .contr_core1_halt(contr_core1_halt),

         // Signal to indicate if the instruction was handled by the GPU controller
         .cpu_instr_handled(cpu_out_ack),
         .outflen(contr_outflen),
         .contr_state(contr_state),
         .contr_prev_state(contr_prev_state)
     );
     
    assign outflen = (((contr_state == KERNEL_LAUNCH) && core1_outflen) || ((contr_prev_state == COPY_FROM_GPU) && (contr_state == NOP) && contr_outflen));
    assign outen = (contr_state == KERNEL_LAUNCH) && core1_outen;
     
    always @(*) begin
        if(contr_state == KERNEL_LAUNCH) begin
            out = core1_out;
        end else if ((contr_prev_state == COPY_FROM_GPU) && (contr_state == NOP)) begin
            out = contr_mem_rd_data;
        end else begin
            out = 0;
        end
    end

endmodule
