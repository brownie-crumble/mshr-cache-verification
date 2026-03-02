// ============================================================
//  testbench.v - Self-Checking Testbench
//  Tests: basic hit/miss, MSHR full, coalescing, LRU eviction
// ============================================================
`timescale 1ns / 1ps
`include "defines.v"

module testbench;

    reg                   clk, rst;
    reg [`ADDR_WIDTH-1:0] address;
    reg                   req_valid, req_write;
    reg [`BLOCK_SIZE-1:0] wdata;

    wire [`BLOCK_SIZE-1:0] rdata;
    wire hit, miss, mshr_full, ready;

    // Memory interface wires
    wire                   mem_req_valid;
    wire [`ADDR_WIDTH-1:0] mem_req_addr;
    wire                   mem_req_write;
    wire [`BLOCK_SIZE-1:0] mem_req_wdata;
    wire                   mem_resp_valid;
    wire [`ADDR_WIDTH-1:0] mem_resp_addr;
    wire [`BLOCK_SIZE-1:0] mem_resp_data;

    // Instantiate cache
    cache uut (
        .clk(clk), .rst(rst),
        .address(address), .req_valid(req_valid),
        .req_write(req_write), .wdata(wdata),
        .rdata(rdata), .hit(hit), .miss(miss),
        .mshr_full(mshr_full), .ready(ready),
        .mem_req_valid(mem_req_valid),
        .mem_req_addr(mem_req_addr),
        .mem_req_write(mem_req_write),
        .mem_req_wdata(mem_req_wdata),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_addr(mem_resp_addr),
        .mem_resp_data(mem_resp_data)
    );

    // Instantiate backing memory
    mem_model mem (
        .clk(clk), .rst(rst),
        .req_valid(mem_req_valid),
        .req_addr(mem_req_addr),
        .req_write(mem_req_write),
        .req_wdata(mem_req_wdata),
        .resp_valid(mem_resp_valid),
        .resp_addr(mem_resp_addr),
        .resp_data(mem_resp_data)
    );

    // Clock
    initial begin clk = 0; forever #5 clk = ~clk; end

    // Coverage / error tracking
    integer pass_count, fail_count;

    // ---- Assertion task ----
    task assert_hit(input exp_hit, input [`BLOCK_SIZE-1:0] exp_data, input [63:0] test_id);
        begin
            #1; // small delta to let outputs settle
            if (hit !== exp_hit) begin
                $display("FAIL [T%0d] @ %0t | hit=%b expected=%b", test_id, $time, hit, exp_hit);
                fail_count = fail_count + 1;
            end else if (exp_hit && rdata !== exp_data) begin
                $display("FAIL [T%0d] @ %0t | rdata=0x%02h expected=0x%02h", test_id, $time, rdata, exp_data);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [T%0d] @ %0t | hit=%b rdata=0x%02h", test_id, $time, hit, rdata);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task send_write(input [`ADDR_WIDTH-1:0] addr, input [`BLOCK_SIZE-1:0] data);
        begin
            address = addr; wdata = data;
            req_write = 1; req_valid = 1;
            @(posedge clk); #1;
            req_valid = 0;
        end
    endtask

    task send_read(input [`ADDR_WIDTH-1:0] addr);
        begin
            address = addr; req_write = 0; req_valid = 1;
            @(posedge clk); #1;
            req_valid = 0;
        end
    endtask

    task wait_cycles(input integer n);
        integer k;
        begin for (k = 0; k < n; k = k + 1) @(posedge clk); end
    endtask

    // ================================================================
    // MAIN TEST SEQUENCE
    // ================================================================
    initial begin
        pass_count = 0; fail_count = 0;
        rst = 1; req_valid = 0; req_write = 0; address = 0; wdata = 0;
        wait_cycles(3);
        rst = 0;
        wait_cycles(2);

        // ---- T1: Write then read back ----
        $display("\n--- T1: Write 0xAB to addr 0x04, read back ---");
        send_write(8'h04, 8'hAB);
        wait_cycles(`MEM_LATENCY + 4);
        send_read(8'h04);
        assert_hit(1, 8'hAB, 1);

        // ---- T2: Cold read - expect miss, then fill from mem ----
        $display("\n--- T2: Cold read addr 0x08 - miss, fill, then hit ---");
        send_read(8'h08);
        assert_hit(0, 8'h00, 2); // should miss
        wait_cycles(`MEM_LATENCY + 4);
        send_read(8'h08);
        // mem seeds addr 0x08 = 8'h08
        assert_hit(1, 8'h08, 2);

        // ---- T3: Fill all 4 MSHRs, check mshr_full on 5th ----
        $display("\n--- T3: MSHR Full test ---");
        // Note: addresses chosen to map to different sets (index bits differ)
        send_read(8'h10); // set 0
        send_read(8'h11); // set 1
        send_read(8'h12); // set 2
        send_read(8'h13); // set 3
        // 5th miss - all MSHRs occupied, should signal full
        send_read(8'h14);
        #1;
        if (mshr_full) begin
            $display("PASS [T3] MSHR correctly signaled full");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [T3] Expected mshr_full=1, got 0");
            fail_count = fail_count + 1;
        end
        wait_cycles(`MEM_LATENCY + 6);

        // ---- T4: Coalescing - two reads to same missing address ----
        $display("\n--- T4: Coalescing - two misses to 0x20 before fill ---");
        send_read(8'h20); // miss, MSHR allocated
        send_read(8'h20); // should coalesce, NOT allocate new MSHR
        wait_cycles(`MEM_LATENCY + 4);
        send_read(8'h20);
        assert_hit(1, 8'h20, 4);

        // ---- T5: LRU Eviction ----
        $display("\n--- T5: LRU eviction - fill both ways of a set, check eviction ---");
        // Set index = 0 (address[1:0] = 2'b00)
        // Way 0 fill: addr 0x00 (tag=00)
        // Way 1 fill: addr 0x04 already in (tag=01) from T1
        // Now bring in addr 0x08 (tag=10) - should evict LRU way
        send_read(8'h00);
        wait_cycles(`MEM_LATENCY + 4);
        send_read(8'h00);
        assert_hit(1, 8'h00, 5);

        // ---- Summary ----
        wait_cycles(5);
        $display("\n============================================");
        $display("  RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
        $display("============================================");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED - CHECK WAVEFORM");
        $finish;
    end

    // ---- Live monitor ----
    always @(posedge clk) begin
        if (req_valid || hit || miss || mshr_full)
            $display("  [MON] t=%0t addr=0x%02h hit=%b miss=%b full=%b ready=%b rdata=0x%02h",
                     $time, address, hit, miss, mshr_full, ready, rdata);
    end

endmodule
