module RAM8x8(
    input [2:0] w_addr,
    input [2:0] r_addr,
    input [7:0] data_in,
    input we, clk, rst,
    output reg [7:0] data_out
    );

    // creating internal memory array
    reg [7:0] mem [0:7];

    //write logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset memory to zero
            mem[0] <= 8'b0;
            mem[1] <= 8'b0;
            mem[2] <= 8'b0;
            mem[3] <= 8'b0;
            mem[4] <= 8'b0;
            mem[5] <= 8'b0;
            mem[6] <= 8'b0;
            mem[7] <= 8'b0;
        end else if (we) begin
            // Write data to memory at the specified address
            mem[w_addr] <= data_in;
        end else if (!we) begin
            // Read data from memory at the specified address
            data_out <= mem[r_addr];
        end
    end

endmodule
