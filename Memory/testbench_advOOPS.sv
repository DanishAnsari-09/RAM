`timescale 1ns/1ps

// ====================================================
// Transaction Class
// ====================================================

class transaction;

    rand bit       write_en;
    rand bit [3:0] addr;
    rand bit [7:0] data;

    int unsigned uid;
    int unsigned transaction_seed;

    // Address constraint
    constraint c_address {
        addr inside {[0:15]};
    }

    // Data constraint
    constraint c_data {
        data inside {[8'h00:8'hFF]};
    }

    // Weighted distribution of writes and reads
    constraint c_default_mix {
        write_en dist {1'b1 := 6, 1'b0 := 4};
    }

    // Constructor: UID is always supplied as 7
    function new(int unsigned id = 7);
        uid = id;
        transaction_seed = 32'h1ACE_B00C ^ id;
    endfunction

    function void pre_randomize();
        $display(
            "[PRE ] UID=%0d seed=0x%08h: preparing transaction",
            uid, transaction_seed
        );
    endfunction

    function void post_randomize();
        $display(
            "[POST] UID=%0d op=%s addr=0x%0h data=0x%02h",
            uid,
            write_en ? "WRITE" : "READ ",
            addr,
            data
        );
    endfunction

    function void print();
        $display(
            "UID=%0d op=%s addr=0x%0h data=0x%02h seed=0x%08h",
            uid,
            write_en ? "WRITE" : "READ ",
            addr,
            data,
            transaction_seed
        );
    endfunction

endclass


// ====================================================
// Testbench
// ====================================================

module testbench;

    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;
    localparam int DEPTH      = (1 << ADDR_WIDTH);
    localparam int UID        = 7;

    logic clk = 1'b0;
    logic reset;
    logic write_en;

    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] write_data;
    logic [DATA_WIDTH-1:0] read_data;

    // DUT instantiation
    memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk        (clk),
        .reset      (reset),
        .write_en   (write_en),
        .addr       (addr),
        .write_data (write_data),
        .read_data  (read_data)
    );

    // Clock generation: 10 ns period
    always #5 clk = ~clk;

    // Reference memory and scoreboard
    bit [DATA_WIDTH-1:0] reference_mem [0:DEPTH-1];
    bit [DEPTH-1:0] initialized;

    int unsigned checks = 0;
    int unsigned errors = 0;
    int unsigned writes = 0;
    int unsigned reads  = 0;

    int unsigned transaction_count = 0;


    // =================================================
    // Reset Task
    // =================================================

    task automatic apply_reset();

        @(negedge clk);

        reset      = 1'b1;
        write_en   = 1'b0;
        addr       = '0;
        write_data = '0;

        @(posedge clk);
        #1;

        for (int i = 0; i < DEPTH; i++) begin
            reference_mem[i] = '0;
            initialized[i]   = 1'b1;
        end

        if (read_data !== '0) begin
            $error(
                "Reset check failed: read_data=%h expected=00",
                read_data
            );
            errors++;
        end
        else begin
            $display("[CHECK] Reset output is zero: PASS");
        end

        @(negedge clk);
        reset = 1'b0;

    endtask


    // =================================================
    // Execute Transaction and Check Output
    // =================================================

    task automatic execute_transaction(input transaction tr);

        bit [DATA_WIDTH-1:0] expected;

        @(negedge clk);

        write_en   = tr.write_en;
        addr       = tr.addr;
        write_data = tr.data;

        expected = reference_mem[tr.addr];

        @(posedge clk);
        #1;

        if (tr.write_en) begin

            reference_mem[tr.addr] = tr.data;
            initialized[tr.addr]  = 1'b1;

            writes++;

            $display(
                "[MODEL] WRITE mem[%0d] = 0x%02h",
                tr.addr,
                tr.data
            );

        end
        else begin

            reads++;
            checks++;

            if (!initialized[tr.addr]) begin

                $error(
                    "Read from uninitialized address %0d",
                    tr.addr
                );

                errors++;

            end
            else if (read_data !== expected) begin

                $error(
                    "MISMATCH UID=%0d addr=%0d expected=0x%02h actual=0x%02h",
                    tr.uid,
                    tr.addr,
                    expected,
                    read_data
                );

                errors++;

            end
            else begin

                $display(
                    "[CHECK] UID=%0d addr=%0d expected=0x%02h actual=0x%02h PASS",
                    tr.uid,
                    tr.addr,
                    expected,
                    read_data
                );

            end

        end

    endtask


    // =================================================
    // Constrained-Random Transaction
    // =================================================

    task automatic send_random();

        transaction tr;

        tr = new(UID);
        tr.srandom(tr.transaction_seed);

        if (!tr.randomize())
            $fatal(1, "Randomization failed for UID=%0d", tr.uid);

        transaction_count++;

        tr.print();
        execute_transaction(tr);

    endtask


    // =================================================
    // Inline Constraint: Read from Specific Address
    // =================================================

    task automatic send_inline_read(
        input bit [3:0] forced_addr
    );

        transaction tr;

        tr = new(UID);
        tr.srandom(tr.transaction_seed);

        if (!tr.randomize() with {
            write_en == 1'b0;
            addr == forced_addr;
        })
            $fatal(
                1,
                "Inline-constrained randomization failed for UID=%0d",
                tr.uid
            );

        transaction_count++;

        $display(
            "[INLINE] Forced READ at address %0d",
            forced_addr
        );

        tr.print();
        execute_transaction(tr);

    endtask


    // =================================================
    // Directed Write Transaction
    // =================================================

    task automatic send_write(
        input bit [3:0] forced_addr,
        input bit [7:0] forced_data
    );

        transaction tr;

        tr = new(UID);
        tr.srandom(tr.transaction_seed);

        if (!tr.randomize() with {
            write_en == 1'b1;
            addr == forced_addr;
            data == forced_data;
        })
            $fatal(
                1,
                "Directed write randomization failed for UID=%0d",
                tr.uid
            );

        transaction_count++;

        tr.print();
        execute_transaction(tr);

    endtask


    // =================================================
    // Main Test Sequence
    // =================================================

    initial begin : run_test

        transaction control_tr;

        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        reset       = 1'b0;
        write_en    = 1'b0;
        addr        = '0;
        write_data  = '0;
        initialized = '0;

        $display("====================================================");
        $display(" Constrained-Random Memory Verification Testbench");
        $display(" Memory: %0d x %0d bits", DEPTH, DATA_WIDTH);
        $display(" Fixed UID: %0d", UID);
        $display("====================================================");

        apply_reset();


        // ---------------------------------------------
        // Phase 1: Initialize all memory locations
        // ---------------------------------------------

        $display("\n--- Phase 1: Initialize all memory locations ---");

        for (int i = 0; i < DEPTH; i++) begin
            send_write(i[3:0], (8'h30 + i));
        end


        // ---------------------------------------------
        // Phase 2: Randomized transactions
        // ---------------------------------------------

        $display("\n--- Phase 2: Randomized operations ---");

        repeat (12)
            send_random();


        // ---------------------------------------------
        // Phase 3: Inline constraint demonstration
        // ---------------------------------------------

        $display("\n--- Phase 3: Inline constraint demonstration ---");

        send_inline_read(4'd3);


        // ---------------------------------------------
        // Phase 4: constraint_mode() and rand_mode()
        // ---------------------------------------------

        $display("\n--- Phase 4: constraint_mode() and rand_mode() ---");

        control_tr = new(UID);
        control_tr.srandom(control_tr.transaction_seed);

        control_tr.c_default_mix.constraint_mode(0);

        control_tr.write_en.rand_mode(0);
        control_tr.write_en = 1'b0;

        if (!control_tr.randomize())
            $fatal(
                1,
                "Randomization failed with rand_mode disabled"
            );

        transaction_count++;

        $display(
            "[MODE] c_default_mix disabled; write_en fixed to READ"
        );

        control_tr.print();
        execute_transaction(control_tr);

        // Restore randomization modes
        control_tr.write_en.rand_mode(1);
        control_tr.c_default_mix.constraint_mode(1);

        send_random();


        // ---------------------------------------------
        // Phase 5: Write then read the same address
        // ---------------------------------------------

        $display("\n--- Phase 5: Write-then-read scenario ---");

        send_write(4'd5, 8'hA5);
        send_inline_read(4'd5);


        // ---------------------------------------------
        // Phase 6: Boundary address testing
        // ---------------------------------------------

        $display("\n--- Phase 6: Boundary-address scenario ---");

        send_write(4'd0, 8'h11);
        send_inline_read(4'd0);

        send_write(4'd15, 8'hEE);
        send_inline_read(4'd15);


        // ---------------------------------------------
        // Phase 7: Additional randomized traffic
        // ---------------------------------------------

        $display("\n--- Phase 7: Additional randomized traffic ---");

        repeat (20)
            send_random();


        // ---------------------------------------------
        // Final Summary
        // ---------------------------------------------

        $display("\n====================================================");
        $display(" TEST SUMMARY");
        $display(" Fixed UID             : %0d", UID);
        $display(" Transactions generated: %0d", transaction_count);
        $display(" Writes                : %0d", writes);
        $display(" Reads                 : %0d", reads);
        $display(" Read checks           : %0d", checks);
        $display(" Errors                : %0d", errors);

        if (errors == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $display("====================================================");

        if (errors != 0)
            $fatal(1, "Memory verification failed");

        $finish;

    end

endmodule