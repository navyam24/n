// represents GPU global memory
// we add in simulated delay

 `timescale 1ns/10ps
`define MEM_16MB

`ifdef LARGE_MEM
    `include "memory_modules/mem_large.sv"
`elsif SMALL_MEM
    `include "memory_modules/mem_small.sv"
`elsif MEM_16MB
    `include "memory_modules/mem_16mb.sv"
`endif

import const_pkg::*;

module global_mem_controller (
    input clk,
    input rst,

    input core1_rd_req,
    input core1_wr_req,
    input [addr_width - 1:0] core1_addr,
    output reg [data_width - 1:0] core1_rd_data,
    input [data_width - 1:0] core1_wr_data,
    output reg core1_busy,
    output reg core1_ack,

    input contr_wr_en,
    input contr_rd_en,
    input [addr_width - 1:0] contr_addr,
    input [data_width - 1:0] contr_wr_data,
    output reg [data_width - 1:0] contr_rd_data,
    output reg contr_ack
);
    

    reg [data_width - 1:0] mem[memory_size];

    reg [addr_width - 1:0] received_addr;
    reg [data_width - 1:0] received_data;
    reg received_rd_req;
    reg received_wr_req;
    reg operation_complete;
    
    
    // RUDY
    reg [addr_width - 1:0] contr_true_addr;
    assign contr_true_addr = {2'b0, contr_addr[31:2]};
    

    // Combinational logic for busy signal
    always @(*) begin
        core1_busy = (received_rd_req || received_wr_req);
    end

    // Sequential logic
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            received_addr <= '0;
            received_data <= '0;
            received_rd_req <= 1'b0;
            received_wr_req <= 1'b0;
            core1_rd_data <= '0;
            core1_ack <= 1'b0;
            operation_complete <= 1'b0;
            contr_ack <= 1'b0;
            contr_rd_data <= '0;
        end else begin
            // Handle controller read/write
            
            // Instruction memory gets written to and stored in the 2D "mem" array variable 
            /////////////////////////////////////////////////////////
            if (contr_wr_en) begin // enable signal
                mem[{2'b0, contr_addr[31:2]}] = contr_wr_data; // write instruction and store in mem
                if(mem[{2'b0, contr_addr[31:2]}] == contr_wr_data) begin // verify that the instruction has
                                                                         // been stored in mem 
                    contr_ack <= 1'b1; // If the instruction from the tb has been stored in mem
                                       // then send acknowledge signal
                end
            
            end else if (contr_rd_en) begin
                contr_rd_data = mem[{2'b0, contr_addr[31:2]}];
                contr_ack <= 1'b1;
            // Enter when contr_wr_en is low
            //////////////////////////////////////////////////////////
            end else begin
                contr_ack <= 1'b0;
            end

            // Handle core1 read/write
            if (received_rd_req || received_wr_req) begin
                if (!operation_complete) begin
                    if (received_rd_req) begin
                        core1_rd_data <= mem[{2'b0, received_addr[31:2]}];
                        operation_complete <= 1'b1;
                        core1_ack <= 1'b1;
                    end else if (received_wr_req) begin
                        mem[{2'b0, received_addr[31:2]}] <= received_data;
                        if (mem[{2'b0, received_addr[31:2]}] == received_data) begin
                            operation_complete <= 1'b1;
                            core1_ack <= 1'b1;
                        end
                    end
                end else begin
                    received_rd_req <= 1'b0;
                    received_wr_req <= 1'b0;
                    operation_complete <= 1'b0;
                    core1_ack <= 1'b0;
                end
            end else if (core1_rd_req) begin
                received_rd_req <= 1'b1;
                received_addr <= core1_addr;
            end else if (core1_wr_req) begin
                received_wr_req <= 1'b1;
                received_addr <= core1_addr;
                received_data <= core1_wr_data;
            end
        end
    end
endmodule


