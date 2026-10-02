`timescale 1ns/1ps

// Transaction Class
class transaction;

    bit write_en;
    logic [3:0] addr;
    logic [7:0] data;

    // Constructor
    function new();
        write_en = 0;
        addr = 0;
        data = 0;
    endfunction

    // Initialize transaction
    function void initialize(
        input bit wr,
        input logic [3:0] a,
        input logic [7:0] d
    );
        write_en = wr;
        addr = a;
        data = d;
    endfunction

    // Display method declared inside class
    extern function void display();

    // Create an independent copy
    function transaction copy();
        transaction temp;
        temp = new();

        temp.write_en = this.write_en;
        temp.addr = this.addr;
        temp.data = this.data;

        return temp;
    endfunction

endclass


// Method defined outside class using scope resolution
function void transaction::display();

    $display("Operation: %s | Address: %0d | Data: %0h",
             write_en ? "WRITE" : "READ",
             addr, data);

endfunction


// Additional class for testbench organization
class memory_environment;

    transaction current;
    int write_count;
    int read_count;

    function new();
        current = new();
        write_count = 0;
        read_count = 0;
    endfunction

    function void update(transaction tr);

        current = tr.copy();

        if (tr.write_en)
            write_count++;
        else
            read_count++;

    endfunction

    function void report();

        $display("\n---------- TEST SUMMARY ----------");
        $display("Total Writes = %0d", write_count);
        $display("Total Reads  = %0d", read_count);
        $display("----------------------------------");

    endfunction

endclass


// Main Testbench
module tb;

    logic clk;
    logic reset;
    logic write_en;

    logic [3:0] write_addr;
    logic [7:0] write_data;

    logic [3:0] read_addr;
    logic [7:0] read_data;

    logic [7:0] expected_mem [0:15];
  
  	// Clock generation
	initial clk = 0;
	always #5 clk = ~clk;

	// VCD waveform dump
	initial begin
    	$dumpfile("dump.vcd");
    	$dumpvars(0, tb);
	end

    transaction tr;
    transaction handle1;
    transaction handle2;
    transaction copied;

    memory_environment env;

    // DUT Instantiation
    memory dut (
        .clk(clk),
        .reset(reset),
        .write_en(write_en),
        .write_addr(write_addr),
        .write_data(write_data),
        .read_addr(read_addr),
        .read_data(read_data)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;


    // Apply transaction to DUT
    task automatic execute_transaction(transaction t);

        @(negedge clk);

        write_en = t.write_en;
        write_addr = t.addr;
        write_data = t.data;
        read_addr = t.addr;

        t.display();

        if (t.write_en) begin

            @(posedge clk);
            expected_mem[t.addr] = t.data;

            $display("WRITE SUCCESS: Address=%0d Data=%0h",
                     t.addr, t.data);

        end
        else begin

            #1;

            if (read_data === expected_mem[t.addr])
                $display("READ PASS: Address=%0d Expected=%0h Actual=%0h",
                         t.addr, expected_mem[t.addr], read_data);

            else
                $display("READ FAIL: Address=%0d Expected=%0h Actual=%0h",
                         t.addr, expected_mem[t.addr], read_data);

        end

        env.update(t);

    endtask


    initial begin

        reset = 1;
        write_en = 0;
        write_addr = 0;
        write_data = 0;
        read_addr = 0;

        env = new();

        // Initialize reference model
        for (int i = 0; i < 16; i++)
            expected_mem[i] = 0;

        repeat (2) @(posedge clk);
        #1 reset = 0;

        $display("\n===== OBJECT HANDLE DEMONSTRATION =====");

        // Dynamic object creation
        handle1 = new();
        handle1.initialize(1, 3, 8'hAA);

        // Handle assignment (both refer to same object)
        handle2 = handle1;

        handle2.addr = 5;

        $display("After handle assignment:");
        $display("Handle1 Address = %0d", handle1.addr);
        $display("Handle2 Address = %0d", handle2.addr);

        // Independent object copy
        copied = handle1.copy();

        copied.addr = 7;

        $display("\nAfter independent copy:");
        $display("Original Address = %0d", handle1.addr);
        $display("Copied Address   = %0d", copied.addr);

        // Object deallocation
        handle1 = null;
        handle2 = null;
        copied = null;

        $display("\nObject handles assigned null.");


        $display("\n===== MEMORY VERIFICATION =====");

        // WRITE TRANSACTIONS
        tr = new();
        tr.initialize(1, 0, 8'hA5);
        execute_transaction(tr);

        tr = new();
        tr.initialize(1, 1, 8'h3C);
        execute_transaction(tr);

        tr = new();
        tr.initialize(1, 2, 8'hF0);
        execute_transaction(tr);

        tr = new();
        tr.initialize(1, 3, 8'h55);
        execute_transaction(tr);


        // READ TRANSACTIONS
        tr = new();
        tr.initialize(0, 0, 0);
        execute_transaction(tr);

        tr = new();
        tr.initialize(0, 1, 0);
        execute_transaction(tr);

        tr = new();
        tr.initialize(0, 2, 0);
        execute_transaction(tr);

        tr = new();
        tr.initialize(0, 3, 0);
        execute_transaction(tr);


        // Additional overwrite test
        tr = new();
        tr.initialize(1, 1, 8'hFF);
        execute_transaction(tr);

        tr = new();
        tr.initialize(0, 1, 0);
        execute_transaction(tr);


        env.report();

        $display("\n===== SIMULATION COMPLETED =====");

        $finish;

    end

endmodule