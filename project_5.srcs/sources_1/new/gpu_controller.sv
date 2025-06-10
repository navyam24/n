`timescale 1ns / 1ps

import op_const_pkg::*;
import const_pkg::*;

module gpu_controller (
    input wire clk,
    input wire rst,
    input wire cpu_instr_type, // This is 0 for state changes and 1 for when data is sent (doesnt touch mem controller or core)
    input wire [31:0] cpu_in_data, // Does not touch mem controller or core, comes from tb
    input wire mem_ack, // If the instruction from the tb has been stored in mem then send acknowledge signal
    input wire outr_ack, // Comes from tb, NOT USED YET?
    output reg mem_rd_en,
    output reg mem_wr_en,
    output reg [addr_width - 1:0] mem_addr,
    output reg [data_width - 1:0] mem_data,
    output reg contr_core1_ena,
    output reg contr_core1_set_pc_req,
    output reg [data_width - 1:0] contr_core1_set_pc_addr,
    input wire contr_core1_halt, // comes from core module
    output reg cpu_instr_handled,
    output reg outflen, ////////////////////////////////////////////////////////////////////// NOT USED YET?
    output reg [2:0] contr_state, // DONE
    output reg [2:0] contr_prev_state // DONE
);
    
    // States
    localparam NOP = 0, COPY_TO_GPU = 1, COPY_FROM_GPU = 2, KERNEL_LAUNCH = 3;

    reg [2:0] state;
    reg [2:0] prev_state;
    reg [31:0] offset;
    reg [31:0] byte_count;
    reg [31:0] bytes_read_or_written; // Track bytes read/written
    reg [2:0] cycle_number; // Tracks the cycle number at which we are in the current state
    reg ctr; // This keeps track of cpu_instr_handled output to ensure that it's only "1" for 1 cycle once we get the mem_ack
    
    // my vars
    reg kernel_count;
    reg write_count;
    reg read_count;
    reg out_enable_count;

    assign contr_state = state;
    assign contr_prev_state = prev_state;
    
    // Rudy
    assign mem_data = cpu_in_data;
    //assign mem_addr = offset + bytes_read_or_written; // offset is set from cpu in "cpu_in_data" during cycle 1. And "bytes_read_or_written"
                                                                // is where in memory we have already explored so we dont want to go there again. 
                                                                // cpu_in_data holds the offset when cycle_number is 1.

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            state <= NOP; 
            prev_state <= NOP;
            cpu_instr_handled <= 0; 
            offset <= 0;
            byte_count <= 0;
            bytes_read_or_written <= 0;
            contr_core1_ena <= 0;
            cycle_number <= 0;
            ctr <= 0;
            outflen <= 0;
            
            // ADDED 
            mem_wr_en <= 1'b0; 
            mem_rd_en <= 1'b0;
            mem_addr <= 32'b0;
            mem_data <= 32'b0;
            contr_core1_set_pc_req <= 1'b0;
            contr_core1_set_pc_addr <= 32'b0;
            
            // my vars
            kernel_count <= 0;
            write_count <= 0;
            read_count <= 1'b0;
            out_enable_count <= 1'b0;
            
        end else begin
            // TODO
            //BLANK : Fill in entire GPU Controller functionality
            
            cpu_instr_handled <= 0; // Keep resetting back to zero            
            mem_wr_en <= 1'b0; 
            mem_rd_en <= 1'b0;
            
            case (state)
                NOP: begin
                    cycle_number <= 3'b0; // Reset the cycle while in NOP state
                    kernel_count <= 0; // reset  kernel count
                    
                    if (cpu_instr_type == 1'b0) begin // instruction type is 0 when we want to transition states
                        case (cpu_in_data) // If instruction type is 0, then the cpu data will contain which state we want to transition to
                            NOP: begin
                                state <= NOP;
                            end
                            COPY_TO_GPU: begin
                                state <= COPY_TO_GPU;                           
                            end
                            COPY_FROM_GPU: begin
                                state <= COPY_FROM_GPU;
                            end
                            KERNEL_LAUNCH: begin
                                state <= KERNEL_LAUNCH;                                                             
                            end
                            default: begin
                                state <= NOP;                            
                            end                                                                              
                        endcase
                        //prev_state <= state; // Keep track of pervious state. We only update this variable when the CPU wants to change the state
                        bytes_read_or_written <= 0; // Reset the bytes read or written when we change state (meaning new command from CPU)
                        cpu_instr_handled <= 1; // Set command complete flag
                        write_count <= 1'b0;
                        read_count <= 1'b0;
                        out_enable_count <= 1'b0;
                    end        
                end
                
                COPY_TO_GPU: begin // Write CPU instructions to the GPU memory 
                    if (cpu_instr_type == 1) begin // instruction type = 1 indicates data related instruction 
                        case (cycle_number) // cpu_in_data will hold different values depending on which cycle we are on
                            0: begin offset <= cpu_in_data; end // In cycle 0, cpu_in_data holds the offset                           
                            
                            1: begin // In cycle 1, cpu_in_data holds the byte_count 
                                    byte_count <= cpu_in_data;
                                    prev_state <= state;               
                                    state <= NOP;
                               end                          
                            default: begin offset <= cpu_in_data; state <= NOP; end
                        endcase                        
                        cycle_number <= cycle_number + 1; // Incremnet the cycle so we know what the "cpu_in_data" holds at a given time                        
                        cpu_instr_handled <= 1; // Set command complete flag
                    end
                end
    
                COPY_FROM_GPU: begin // Read the data from the GPU memory and send it to the CPU for processing
                    if (cpu_instr_type == 1) begin // instruction type = 1 indicates data related instruction 
                        case (cycle_number) // cpu_in_data will hold different values depending on which cycle we are on
                            0: begin offset <= cpu_in_data; end // In cycle 0, cpu_in_data holds the offset
                            
                            1: begin // In cycle 1, cpu_in_data holds the byte_count 
                                    byte_count <= cpu_in_data;
                                    prev_state <= state;                                    
                                    state <= NOP;                   
                               end
                               
                            default: begin offset <= cpu_in_data; state <= NOP; end
                        endcase
                        cycle_number <= cycle_number + 1; // Incremnet the cycle so we know what the "cpu_in_data" holds at a given time
                        cpu_instr_handled <= 1; // Set command complete flag
                    end
                end
                
                KERNEL_LAUNCH: begin // Launch the GPU to perform instructions
                    
                    if (cpu_instr_type == 1) begin // instruction type = 1 indicates data related instruction 
                      
                      if (outr_ack || contr_core1_halt) begin
                        cpu_instr_handled <= 1; // Set command complete flag 
                        state <= NOP;
                        contr_core1_ena <= 0; // Enable the GPU to run
                      end                                                                 
                        
                        case (kernel_count)
                            0: begin
                                contr_core1_set_pc_addr <= cpu_in_data; // The CPU sets the PC address for the GPU
                                contr_core1_set_pc_req <= 1; // CPU request to set the PC value
                                kernel_count <= kernel_count + 1;
                                contr_core1_ena <= 0; // Enable the GPU to run
                               end
                            
                            1: begin
                                contr_core1_set_pc_req <= 0; // Deassert the PC set request
                                contr_core1_ena <= 1; // Enable the GPU to run
                               end
                    
                        endcase                                                                  
                    end                                
                end        
            
                default: begin
                
                end
            endcase
            
            // Disable read and write capabilities when not in NOP state
            if (state != NOP) begin
                mem_wr_en <= 1'b0; 
                mem_rd_en <= 1'b0;
            end
            
            
//            if (state == NOP && prev_state == COPY_TO_GPU) begin               
                
//                if (bytes_read_or_written < byte_count) begin
                
                    
//                    mem_wr_en <= 1'b1;                  
                    
//                    if (mem_ack) begin
//                        bytes_read_or_written <= bytes_read_or_written + 4;
//                        cpu_instr_handled <= 1'b1;
//                    end
//                    else begin
//                        cpu_instr_handled <= 1'b0;
//                    end                
                
//                end
//                else begin
//                    cpu_instr_handled <= 1'b1;                
//                end
                
//            end
            
            
            // WRITE
            if (state == NOP && prev_state == COPY_TO_GPU) begin               
                
                if (bytes_read_or_written < byte_count) begin
                    case(write_count)
                        0: begin
                                mem_wr_en <= 1'b1;  
                                bytes_read_or_written <= bytes_read_or_written + 4;
                                mem_addr <= offset + bytes_read_or_written;                             
                                write_count <= 1'b1;
                           end
                           
                        1: begin
                                mem_wr_en <= 1'b0;
                                if (mem_ack) begin
                                    cpu_instr_handled <= 1'b1;
                                    write_count <= 1'b0;
                                end
                           end                      
                    endcase
                end
                else if (bytes_read_or_written >= byte_count) begin
                    cpu_instr_handled <= 1'b1;
                end
            end
            
            // READ
            if (state == NOP && prev_state == COPY_FROM_GPU) begin                          
                
                if (bytes_read_or_written <= byte_count) begin
                    case(read_count)
                        0: begin
                                mem_rd_en <= 1'b1;  
                                if (bytes_read_or_written < byte_count) begin
                                    bytes_read_or_written <= bytes_read_or_written + 4;
                                    mem_addr <= offset + bytes_read_or_written;   
                                end
                                outflen <= 1'b0;                          
                                read_count <= 1'b1;
                           end
                           
                        1: begin
                                mem_rd_en <= 1'b0;
                                if (mem_ack) begin
                                    cpu_instr_handled <= 1'b1;
                                    outflen <= 1'b1;
                                    read_count <= 1'b0;
                                end
                           end                      
                    endcase
                end
//                else begin
//                    cpu_instr_handled <= 1'b0;
//                    case(out_enable_count) 
//                        0: begin
//                                outflen <= 1'b0;
//                                out_enable_count <= 1'b1;
//                           end
                           
//                        1: begin
//                                outflen <= 1'b1;
//                                out_enable_count <= 1'b1;
//                           end
                    
//                    endcase
//                end
                
//                else if (bytes_read_or_written == byte_count) begin
//                    cpu_instr_handled <= 1'b1;
//                    outflen <= 1'b0;
//                    mem_rd_en <= 1'b0;
//                end
//                else begin
//                    cpu_instr_handled <= 1'b0;
//                    outflen <= 1'b1;
//                    mem_rd_en <= 1'b0;
//                end
            end
            
            
            
        
            // WRITE
            // We will only enter this state once during a single clock cycle when we transition from COPY_TO_GPU to NOP.
            // During this time, cycle_number will have gone through 0-2 and the variables "offset", "byte_count", and "state"
            // will have been set with their correct values passed by the input port from the CPU "cpu_in_data".   
            // bytes_read_or_written < byte_count is another condition to enter. bytes_read_or_written is the space in memory that we have 
            // already been too. byte_count is to make sure we dont access the same piece of memory whne we read or write to teh GPU memory.  
//            if (state == NOP && prev_state == COPY_TO_GPU && bytes_read_or_written < byte_count) begin
//                mem_wr_en <= 1'b1; 
//                mem_rd_en <= 1'b0;                
//                mem_data <= cpu_in_data; // cpu_in_data holds the mem_data when cycle_number is 2.
                
//                // Wait to get an ack signal from the GPU memory before we increment the address and bytes written
//                if (mem_ack) begin
                
//                    bytes_read_or_written <= bytes_read_or_written + 4; // 4 bytes is 32 bits. We read/write 4 bytes at a time
//                    //mem_addr <= offset + bytes_read_or_written; // offset is set from cpu in "cpu_in_data" during cycle 1. And "bytes_read_or_written"
//                                                                // is where in memory we have already explored so we dont want to go there again. 
//                                                                // cpu_in_data holds the offset when cycle_number is 1.
                                                                
//                    cpu_instr_handled <= 1; // Only set when last byte is confirmed written
//                    if (bytes_read_or_written + 4 >= byte_count) begin
//                        //cpu_instr_handled <= 1; // Only set when last byte is confirmed written
//                    end                                                                
//                end
//            end
            
            // READ
            // We will only enter this state once during a single clock cycle when we transition from COPY_FROM_GPU to NOP.
            // During this time, cycle_number will have gone through 0-2 and the variables "offset", "byte_count", and "state"
            // will have been set with their correct values passed by the input port from the CPU "cpu_in_data".
            // bytes_read_or_written < byte_count is another condition to enter. bytes_read_or_written is the space in memory that we have 
            // already been too. byte_count is to make sure we dont access the same piece of memory whne we read or write to teh instruction memory.
//            if (state == NOP && prev_state == COPY_FROM_GPU) begin
            
//                if (outr_ack) begin
//                    cpu_instr_handled <= 1; // Only set when we get the confirmation that the tb has registered the output value
//                end
               
//                if (bytes_read_or_written < byte_count) begin
//                    mem_wr_en <= 1'b0; 
//                    mem_rd_en <= 1'b1;
                              
                
//                    // Wait to get an ack signal from the GPU memory before we increment the address and bytes read
//                    if (mem_ack) begin
//                        bytes_read_or_written <= bytes_read_or_written + 4; // 4 bytes is 32 bits. We read/write 4 bytes at a time
//                        //mem_addr <= offset + bytes_read_or_written; // offset is set from cpu in "cpu_in_data" during cycle 1. And "bytes_read_or_written"
//                                                                    // is where in memory we have already explored so we dont want to go there again. 
//                                                                    // cpu_in_data holds the offset when cycle_number is 1.
                                                                                       
//                        if (bytes_read_or_written + 4 >= byte_count) begin
//                            //cpu_instr_handled <= 1; // Only set when last byte is confirmed written
//                            outflen <= 1'b1;
//                        end
//                    end
//                end
                                              
//            end       
    
            // Enter if we receieve a halt command from the GPU core module
            if (state == KERNEL_LAUNCH && contr_core1_halt) begin               
                contr_core1_ena <= 0; // disable the core module from progressing
                //cpu_instr_handled <= 1; // Set command complete flag                            
            end    
        end              
    end

endmodule

