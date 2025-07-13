`timescale 1ns / 1ps

module testbench;

    reg clk;
    reg rst;
    reg [7:0] address;
    reg req_valid;
    reg req_write;
    reg [7:0] wdata;
    wire [7:0] rdata;
    wire hit;
    wire ready;

    cache uut (
        .clk(clk),
        .rst(rst),
        .address(address),
        .req_valid(req_valid),
        .req_write(req_write),
        .wdata(wdata),
        .rdata(rdata),
        .hit(hit),
        .ready(ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Main test sequence
    initial begin
        $display("Time\tAddr\tHit\tReady\tRData");

        rst = 1; address = 0; req_valid = 0; req_write = 0; wdata = 0;
        #10 rst = 0;

        // Write to 0x01 with 0xDE
        #10 send_write(8'h01, 8'hDE);

        // Wait for MSHR to complete
        #50;

        // Read from 0x01 — should HIT and return 0xDE
        send_read(8'h01);

        #50;

        // ---- MSHR Full Test ----
        $display("\n--- Testing MSHR Full Condition ---");

        #10 send_read(8'h10); // MSHR #0
        #10 send_read(8'h20); // MSHR #1
        #10 send_read(8'h30); // Should NOT allocate — no MSHRs left

        #50 send_read(8'h20); // Should hit after MSHR #1 fills
        #10 send_read(8'h10); // Should hit after MSHR #0 fills

        #50;

        // ---- Corner Case: Back-to-back Write-Read before Fill ----
        $display("\n--- Back-to-Back Write-Then-Read (Before Fill) ---");

        #10 send_write(8'h02, 8'hBE); // MSHR gets triggered

        #10 send_read(8'h02);         // Should MISS

        #50 send_read(8'h02);         // Should HIT and return BE

        #50 $finish;
    end

    // Tasks
    task send_write(input [7:0] addr, input [7:0] data);
        begin
            address = addr;
            wdata = data;
            req_write = 1;
            req_valid = 1;
            #10;
            req_valid = 0;
        end
    endtask

    task send_read(input [7:0] addr);
        begin
            address = addr;
            req_write = 0;
            req_valid = 1;
            #10;
            req_valid = 0;
        end
    endtask

    // Monitoring
    always @(posedge clk) begin
        $display("%4t\t%2h\t%b\t%b\t%2h", $time, address, hit, ready, rdata);
    end

    // Dump waveform
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);
    end

endmodule
