`timescale 1ns / 1ps

import const_pkg::*;

module core_and_mem(
    input clk, rst,
    input contr_mem_wr_en, // Enable the proccess to write the instruction from the tb 
                           // in the instruction memory array in the "global_mem_controller"
                           // instantiated module
    input [addr_width - 1:0] contr_mem_addr, // Address bits to store the instruction in the
                                             // instruction memory
    input [data_width - 1:0] contr_mem_wr_data, // THIS IS THE INSTRUCTION MEM FROM TB

    output [data_width - 1:0] out,
    output outen,
    output outflen,

    input contr_core1_ena,
    input contr_core1_clr,
    input contr_core1_set_pc_req,
    input [data_width - 1:0] contr_core1_set_pc_addr,
    output contr_core1_halt,
    input outr_ack
);

    wire core1_mem_rd_req;
    wire core1_mem_wr_req;
    wire [addr_width - 1:0] core1_mem_addr;
    wire [data_width - 1:0] core1_mem_rd_data;
    wire [data_width - 1:0] core1_mem_wr_data;
    wire core1_mem_busy;
    wire core1_mem_ack;

    // Remove unused signals
    // reg contr_mem_rd_en;
    // reg [addr_width - 1:0] contr_mem_rd_addr;
    // reg [data_width - 1:0] contr_mem_rd_data;
    // reg contr_mem_rd_ack;

    // This module contains the data memory 2D array for STORE and LOAD instructions. This
    // data memory array is accessed through the "corel_xxxx" ports.
    
    // This module contains the instruction memory 1D array for STORE and LOAD instructions. This
    // data memory array is accessed through the "contr_xxxx" ports.  
    global_mem_controller global_mem_controller_(
        .clk(clk),
        .rst(rst),
    
        .core1_rd_req(core1_mem_rd_req), // Input: Request sig to read the instruction we just stored (from teh HEX file) 
        .core1_wr_req(core1_mem_wr_req),
        .core1_addr(core1_mem_addr),
        .core1_rd_data(core1_mem_rd_data),
        .core1_wr_data(core1_mem_wr_data),
        .core1_busy(core1_mem_busy),
        .core1_ack(core1_mem_ack), // Ouput: If sig goes high while in C0 state, main core FSM transitions to C1 state 
    
        // These ports are to only store/write the instruction in the instruction memory 
        .contr_wr_en(contr_mem_wr_en), // Enable the proccess to write the instruction from the tb 
                                       // in the instruction memory array in the "global_mem_controller"
                                       // instantiated module
        .contr_rd_en(1'b0),            // READING FROM MEM IS DISABLED FOR contr
        .contr_addr(contr_mem_addr),   // Address bits to store the instruction from the tb in the
                                       // instruction memory array
        .contr_wr_data(contr_mem_wr_data), // THIS IS THE INSTRUCTION MEM data (the HEX bits)
                                           // FROM TB
        .contr_rd_data(),                  // CANT READ FROM MEM FOR contr
        .contr_ack() // Acknwledge sig is not used
    );

    core core1(
        .rst(rst),
        .clk(clk),
        .clr(contr_core1_clr),
        .ena(contr_core1_ena),
        .set_pc_req(contr_core1_set_pc_req),
        .set_pc_addr(contr_core1_set_pc_addr),

        .outflen(outflen),
        .out(out),
        .outen(outen),

        .halt(contr_core1_halt),

        .mem_addr(core1_mem_addr),
        .mem_rd_data(core1_mem_rd_data),// Input: THIS IS THE INSTRUCTION MEM FROM TB
        .mem_wr_data(core1_mem_wr_data),
        .mem_ack(core1_mem_ack),// Input: If sig goes high while in C0 state, main core FSM transitions to C1 state
        .mem_busy(core1_mem_busy),
        .mem_rd_req(core1_mem_rd_req),// Output: Request sig to read the instruction we just stored (from teh HEX file) 
        .mem_wr_req(core1_mem_wr_req),
        .outr_ack(rt90)
    );
endmodule