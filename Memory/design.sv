module memory #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter DEPTH = 1 << ADDR_WIDTH
)(
    input logic clk,
    input logic reset,
    input logic write_en,

    input logic [ADDR_WIDTH-1:0] write_addr,
    input logic [DATA_WIDTH-1:0] write_data,

    input logic [ADDR_WIDTH-1:0] read_addr,
    output logic [DATA_WIDTH-1:0] read_data
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Synchronous reset and write
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < DEPTH; i++)
                mem[i] <= '0;
        end
        else if (write_en) begin
            mem[write_addr] <= write_data;
        end
    end

    // Asynchronous read
    always_comb begin
        read_data = mem[read_addr];
    end

endmodule