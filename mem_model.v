// ============================================================
//  mem_model.v - Backing Memory with Real Latency
//  Stores actual data. Returns addr-seeded values on first read.
// ============================================================
`timescale 1ns / 1ps
`include "defines.v"

module mem_model (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   req_valid,
    input  wire [`ADDR_WIDTH-1:0] req_addr,
    input  wire                   req_write,
    input  wire [`BLOCK_SIZE-1:0] req_wdata,
    output reg                    resp_valid,
    output reg  [`ADDR_WIDTH-1:0] resp_addr,
    output reg  [`BLOCK_SIZE-1:0] resp_data
);
    reg [`BLOCK_SIZE-1:0] mem [0:255];

    reg                     pending;
    reg [`ADDR_WIDTH-1:0]   pending_addr;
    reg                     pending_write;
    reg [`BLOCK_SIZE-1:0]   pending_wdata;
    reg [3:0]               latency_cnt;
    integer j;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            resp_valid  <= 0;
            pending     <= 0;
            latency_cnt <= 0;
            // Seed memory: mem[addr] = addr, easy to verify in testbench
            for (j = 0; j < 256; j = j + 1)
                mem[j] <= j[7:0];
        end else begin
            resp_valid <= 0;

            if (!pending && req_valid) begin
                pending       <= 1;
                pending_addr  <= req_addr;
                pending_write <= req_write;
                pending_wdata <= req_wdata;
                latency_cnt   <= `MEM_LATENCY - 1;
            end

            if (pending) begin
                if (latency_cnt > 0) begin
                    latency_cnt <= latency_cnt - 1;
                end else begin
                    if (pending_write)
                        mem[pending_addr] <= pending_wdata;
                    resp_valid <= 1;
                    resp_addr  <= pending_addr;
                    resp_data  <= pending_write ? pending_wdata : mem[pending_addr];
                    pending    <= 0;
                end
            end
        end
    end
endmodule
