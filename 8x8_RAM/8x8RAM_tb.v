module 8x8RAM_tb;

    // Inputs
    reg [2:0] w_addr;
    reg [2:0] r_addr;
    reg [7:0] data_in;
    reg we;
    reg clk;
    reg rst;

    // Outputs
    wire [7:0] data_out;

    // Instantiate the RAM8x8 module
    RAM8x8 uut (
        .w_addr(w_addr),
        .r_addr(r_addr),
        .data_in(data_in),
        .we(we),
        .clk(clk),
        .rst(rst),
        .data_out(data_out)
    );

    // Clock generation
    initial begin
    {clk, rst, we, w_addr, r_addr, data_in} = 0;
    end

    always #5 clk = ~clk; // Toggle clock every 5 time units

    // Test sequence
    initial begin
        // Initialize inputs
        rst = 1; we = 0; w_addr = 3'b000; r_addr = 3'b000; data_in = 8'b00000000;
        
        // Apply reset
        #10 rst = 0;

        // Write data to memory
        #10 we = 1; w_addr = 3'b001; data_in = 8'b10101010; // Write to address 1
        #10 we = 1; w_addr = 3'b010; data_in = 8'b11001100; // Write to address 2
        
        // Read data from memory
        #10 we = 0; r_addr = 3'b001; // Read from address 1
        #10 r_addr = 3'b010; // Read from address 2
        
        // Finish simulation
        #20 $finish;
    end
endmodule;