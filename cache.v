// ============================================================
//  cache.v - 2-Way Set Associative, Non-Blocking Cache
//  4-entry MSHRs with per-entry state machines + coalescing
// ============================================================
`timescale 1ns / 1ps
`include "defines.v"

module cache (
    input  wire                   clk,
    input  wire                   rst,
    input  wire [`ADDR_WIDTH-1:0] address,
    input  wire                   req_valid,
    input  wire                   req_write,
    input  wire [`BLOCK_SIZE-1:0] wdata,
    output reg  [`BLOCK_SIZE-1:0] rdata,
    output reg                    hit,
    output reg                    miss,
    output reg                    mshr_full,
    output reg                    ready,

    // Memory interface
    output reg                    mem_req_valid,
    output reg  [`ADDR_WIDTH-1:0] mem_req_addr,
    output reg                    mem_req_write,
    output reg  [`BLOCK_SIZE-1:0] mem_req_wdata,
    input  wire                   mem_resp_valid,
    input  wire [`ADDR_WIDTH-1:0] mem_resp_addr,
    input  wire [`BLOCK_SIZE-1:0] mem_resp_data
);
    // ---- Cache Arrays (2-way) ----
    reg [`BLOCK_SIZE-1:0] cache_data  [0:`NUM_SETS-1][0:`NUM_WAYS-1];
    reg [`TAG_BITS-1:0]   cache_tags  [0:`NUM_SETS-1][0:`NUM_WAYS-1];
    reg                   cache_valid [0:`NUM_SETS-1][0:`NUM_WAYS-1];
    reg                   lru         [0:`NUM_SETS-1]; // 0=way0 LRU, 1=way1 LRU

    // ---- MSHR Entries ----
    reg [1:0]             mshr_state  [0:`NUM_MSHR-1];
    reg [`ADDR_WIDTH-1:0] mshr_addr   [0:`NUM_MSHR-1];
    reg [`BLOCK_SIZE-1:0] mshr_wdata  [0:`NUM_MSHR-1];
    reg                   mshr_write  [0:`NUM_MSHR-1];
    // Coalescing: store up to 2 merged requests per MSHR
    reg                   mshr_coal_valid [0:`NUM_MSHR-1];
    reg [`BLOCK_SIZE-1:0] mshr_coal_wdata [0:`NUM_MSHR-1];

    // Address breakdown
    wire [`INDEX_BITS-1:0] index = address[`INDEX_BITS-1:0];
    wire [`TAG_BITS-1:0]   tag   = address[`ADDR_WIDTH-1:`INDEX_BITS];

    integer i;
    reg hit_way;
    reg found_hit;
    reg allocated;
    reg coalesced;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hit       <= 0; miss <= 0; mshr_full <= 0; ready <= 1;
            rdata     <= 0;
            mem_req_valid <= 0;
            for (i = 0; i < `NUM_SETS; i = i + 1) begin
                cache_valid[i][0] <= 0;
                cache_valid[i][1] <= 0;
                lru[i] <= 0;
            end
            for (i = 0; i < `NUM_MSHR; i = i + 1) begin
                mshr_state[i]      <= `MSHR_INVALID;
                mshr_coal_valid[i] <= 0;
            end
        end else begin
            // ---- Defaults ----
            hit       <= 0;
            miss      <= 0;
            mshr_full <= 0;
            ready     <= 1;
            mem_req_valid <= 0;

            // ================================================================
            // 1. HANDLE INCOMING REQUEST
            // ================================================================
            if (req_valid) begin
                found_hit = 0;
                hit_way   = 0;

                // Check way 0
                if (cache_valid[index][0] && cache_tags[index][0] == tag) begin
                    found_hit = 1; hit_way = 0;
                end
                // Check way 1
                if (cache_valid[index][1] && cache_tags[index][1] == tag) begin
                    found_hit = 1; hit_way = 1;
                end

                if (found_hit) begin
                    hit   <= 1;
                    ready <= 1;
                    if (req_write)
                        cache_data[index][hit_way] <= wdata;
                    else
                        rdata <= cache_data[index][hit_way];
                    // Update LRU: mark hit_way as recently used
                    lru[index] <= ~hit_way;
                end else begin
                    // MISS - check for coalescing first
                    miss      <= 1;
                    allocated  = 0;
                    coalesced  = 0;

                    // Can we coalesce into an existing MSHR for same address?
                    for (i = 0; i < `NUM_MSHR; i = i + 1) begin
                        if ((mshr_state[i] == `MSHR_ALLOCATED ||
                             mshr_state[i] == `MSHR_WAITING) &&
                             mshr_addr[i] == address && !coalesced) begin
                            // Merge this request
                            mshr_coal_valid[i] <= 1;
                            mshr_coal_wdata[i] <= wdata;
                            coalesced = 1;
                            ready <= 0;
                        end
                    end

                    // If not coalesced, try to allocate a fresh MSHR
                    if (!coalesced) begin
                        for (i = 0; i < `NUM_MSHR; i = i + 1) begin
                            if (mshr_state[i] == `MSHR_INVALID && !allocated) begin
                                mshr_state[i]      <= `MSHR_ALLOCATED;
                                mshr_addr[i]       <= address;
                                mshr_wdata[i]      <= wdata;
                                mshr_write[i]      <= req_write;
                                mshr_coal_valid[i] <= 0;
                                allocated = 1;
                                ready <= 0;
                            end
                        end
                        if (!allocated) begin
                            mshr_full <= 1;
                            ready     <= 0;
                        end
                    end
                end
            end

            // ================================================================
            // 2. ISSUE MEMORY REQUESTS FOR ALLOCATED MSHRs
            // ================================================================
            for (i = 0; i < `NUM_MSHR; i = i + 1) begin
                if (mshr_state[i] == `MSHR_ALLOCATED) begin
                    mem_req_valid <= 1;
                    mem_req_addr  <= mshr_addr[i];
                    mem_req_write <= mshr_write[i];
                    mem_req_wdata <= mshr_wdata[i];
                    mshr_state[i] <= `MSHR_WAITING;
                end
            end

            // ================================================================
            // 3. HANDLE MEMORY FILL RESPONSE
            // ================================================================
            if (mem_resp_valid) begin
                for (i = 0; i < `NUM_MSHR; i = i + 1) begin
                    if (mshr_state[i] == `MSHR_WAITING &&
                        mshr_addr[i]  == mem_resp_addr) begin

                        // Fill cache - evict LRU way
                        cache_data [mem_resp_addr[`INDEX_BITS-1:0]][lru[mem_resp_addr[`INDEX_BITS-1:0]]] <= mem_resp_data;
                        cache_tags [mem_resp_addr[`INDEX_BITS-1:0]][lru[mem_resp_addr[`INDEX_BITS-1:0]]] <= mem_resp_addr[`ADDR_WIDTH-1:`INDEX_BITS];
                        cache_valid[mem_resp_addr[`INDEX_BITS-1:0]][lru[mem_resp_addr[`INDEX_BITS-1:0]]] <= 1;
                        // Flip LRU
                        lru[mem_resp_addr[`INDEX_BITS-1:0]] <= ~lru[mem_resp_addr[`INDEX_BITS-1:0]];

                        mshr_state[i] <= `MSHR_INVALID;
                    end
                end
            end

        end
    end
endmodule
