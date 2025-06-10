// drive the gpu_die, to test it
module gpu_driver();
    parameter out_size = 2048;

    reg rst;
    reg clk;

    reg [31:0] cycle_count;

    reg [31:0] outmem [out_size];
    reg [out_size-1 : 0] outtype;
    reg [$clog2(out_size) - 1:0] outpos;
    reg outr_ack;

    reg cpu_instr_type;  
    reg [31:0] cpu_in_data;
    wire [31:0] cpu_out_data;
    wire cpu_out_ack;

    // Additional signals for output handling
    reg outen;
    reg outflen;
    reg [data_width - 1:0] out;
    
    gpu_die gpu_die_(
        .rst(rst),
        .clk(clk),

        .cpu_instr_type(cpu_instr_type),
        .cpu_in_data(cpu_in_data),
        .cpu_out_data(cpu_out_data),
        .cpu_out_ack(cpu_out_ack),

        .outen(outen),
        .outflen(outflen),
        .out(out),

        .outr_ack(outr_ack) // Connect outr_ack
    );

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    initial begin
        rst <= 1;
        #10
        rst <= 0;
        #20
        outpos <= 0;
        outr_ack <= 1'b0;
        outen <= 0;
        outflen <= 0;
        cpu_instr_type <= 0;
        cpu_in_data <= 0;
        rst <= 1;
        #10
        
        // Start processing instructions
        process_instructions();
        $display("done reading");
        // Print the Matrix Multiplication Output
        print_outmem();
        $display("done printing");
        $finish();
    end

    task process_instructions();
        integer i;
        integer file;
        integer status;
        string line;

        // TODO: Update path
        file = $fopen("C:/Users/Dell/Desktop/m5/MILESTONE_5/project_5/gpu_instructions_matrix_mul2.txt", "r");
        i=0;
        
        if (file) begin
            while (!$feof(file)) begin
                status = $fgets(line, file);
                i = i+1;
                
                if (status) begin              
                    if (line[0] == "#") begin // Ignore comments
                        continue;
                    end
                    
                    $display("i = %d, line = %s", i, line);
                    // $display($time);
                    if (line[0] == "S") begin // "STATE" instruction
                        cpu_instr_type = 0; // Set for STATE
                        cpu_in_data = parse_data(line, cpu_instr_type); // Get data value for STATE
                        // Wait for acknowledgment before moving on
                        do begin
                            #10;
                        end while(~cpu_out_ack);
                    end else if (line[0] == "D") begin // "DATA" instruction
                        cpu_instr_type = 1; // Set for DATA
                        cpu_in_data = parse_data(line, cpu_instr_type);
                        // Wait for acknowledgment before moving on
                        do begin
                            #10;
                        end while(~cpu_out_ack);
                    end else if (line[0] == "R") begin // "READ_DATA" instruction
                        cpu_instr_type = 1; // Set for READ_DATA for a memory read operation
                        cpu_in_data = 0;
                        // Wait for acknowledgment before moving on
                        do begin
                            #10;
                        end while(~cpu_out_ack);
                    end
                end
            end
            
            $fclose(file);
        end else begin
            $display("Error opening file.");
        end
    endtask

    function [31:0] parse_data(input string line, input reg cpu_instr_type);
        reg [31:0] value, status;
        // Extract hex value from line (assuming format is "DATA 0x...")
        if(cpu_instr_type) begin
            status = $sscanf(line, "DATA %h", value);
            // $display(value);
            // $display(cpu_instr_type);
        end else begin
            status = $sscanf(line, "STATE %h", value);
            // $display(value);
            // $display(cpu_instr_type);
        end        
        return value;
    endfunction
    
    function real to_real(input [float_width - 1:0] fval);
        if(fval == '0) begin
            to_real = '0;
        end else begin
            // given a float in our own representation, convert to opaque verilog real format, and return that
            reg sign;
            reg [float_exp_width - 1:0] exp;
            reg [float_mant_width - 1:0] mant;
            {sign, exp, mant} = fval;
    
            to_real = $itor(mant);
            // $display("mant as real: %0f", to_real);
            // while(exp > 127) begin
                // to_real = to_real 
            // end
            for(int i = 0; i < 23; i++) begin
                to_real = to_real / 2;
            end
            // $display("mant as real: %0f", to_real);
            to_real = 1 + to_real;
            // $display("mant as real: %0f", to_real);
            while(exp > 127) begin
                exp = exp - 1;
                to_real = to_real * 2;
            end
            while(exp < 127) begin
                exp = exp + 1;
                to_real = to_real / 2;
            end
            // $display("mant as real: %0f", to_real);
            if(sign) begin
                to_real = - to_real;
            end
        end
    endfunction
    
    task print_outmem();
        integer j;

        $display("Filled outmem entries:");
        
        for (j = 0; j < outpos; j = j + 1) begin           
            $display("outmem[%0d] = %h, Float: %f", j, outmem[j], to_real(outmem[j]));
        end
    endtask

    always @(posedge clk) begin
        if ((outen | outflen) && (outpos < out_size - 1) && !outr_ack) begin
            outmem[outpos] <= out;     // Store output in outmem based on conditions.
            outtype[outpos] <= outflen; 
            outpos <= outpos + 1;      // Increment position in output memory.
            outr_ack <= 1'b1;          // Signal acknowledgment.
        end else begin
            outr_ack <= 1'b0;          // Reset acknowledgment signal.
        end
    end

endmodule
