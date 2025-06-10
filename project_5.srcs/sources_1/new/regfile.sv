`timescale 1ns / 1ps
import const_pkg::*;

module regfile(
    input wire clk,
    input wire rst,
    
    // Read port 1
    input wire [addr_width-1:0] rs1_addr,
    output reg [data_width-1:0] rs1_data,
    
    // Read port 2
    input wire [addr_width-1:0] rs2_addr,
    output reg [data_width-1:0] rs2_data,
    
    // Read port 3
    input wire [addr_width-1:0] rs3_addr,
    output reg [data_width-1:0] rs3_data,
    
    // Write port
    input wire we,
    input wire [addr_width-1:0] rd_addr,
    input wire [data_width-1:0] rd_data,
    
    // Write acknowledgment
    output reg wr_ack
);

    // Register file
    reg [data_width-1:0] registers [0:num_regs-1];

    // Read operations (combinational)
    always @(*) begin
        // x0 is hardwired to 0
        rs1_data = (rs1_addr == 0) ? 0 : registers[rs1_addr];
        rs2_data = (rs2_addr == 0) ? 0 : registers[rs2_addr];
        rs3_data = (rs3_addr == 0) ? 0 : registers[rs3_addr];
    end

    // Write operation (sequential)
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            // Reset all registers to 0
            integer i;
            for (i = 0; i < num_regs; i = i + 1) begin
                registers[i] <= 0;
            end
            wr_ack <= 1'b0;
        end else begin
            if (we && rd_addr != 0) begin
                // Write data to register (x0 is read-only)
                registers[rd_addr] <= rd_data;
                wr_ack <= 1'b1;
            end else begin
                wr_ack <= 1'b0;
            end
        end
    end

endmodule
