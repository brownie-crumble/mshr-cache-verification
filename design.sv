`timescale 1ns / 1ps

module cache (
    input clk,
    input rst,
    input [7:0] address,
    input req_valid,
    input req_write,
    input [7:0] wdata,
    output reg [7:0] rdata,
    output reg hit,
    output reg ready
);

    reg [7:0] cache_data [0:3];
    reg [3:0] cache_valid;
    reg [1:0] cache_tags [0:3];

    reg mshr_valid [0:1];
    reg mshr_write [0:1];
    reg [7:0] mshr_addr [0:1];
    reg [7:0] mshr_data [0:1];
    reg [2:0] mshr_timer [0:1];

    integer i;
    reg allocated;

    wire [1:0] index = address[1:0];
    wire [1:0] tag   = address[3:2];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cache_valid <= 0;
            hit <= 0;
            ready <= 1;
            rdata <= 0;
            for (i = 0; i < 2; i = i + 1) begin
                mshr_valid[i] <= 0;
                mshr_timer[i] <= 0;
            end
        end else begin
            hit <= 0;
            ready <= 1;

            if (req_valid) begin
                if (cache_valid[index] && cache_tags[index] == tag) begin
                    hit <= 1;
                    if (req_write)
                        cache_data[index] <= wdata;
                    else
                        rdata <= cache_data[index];
                end else begin
                    hit <= 0;
                    allocated = 0;
                    for (i = 0; i < 2; i = i + 1) begin
                        if (!mshr_valid[i] && !allocated) begin
                            mshr_valid[i] <= 1;
                            mshr_addr[i] <= address;
                            mshr_data[i] <= wdata;
                            mshr_write[i] <= req_write;
                            mshr_timer[i] <= 4;
                            ready <= 0;
                            allocated = 1;
                        end
                    end
                end
            end

            for (i = 0; i < 2; i = i + 1) begin
                if (mshr_valid[i]) begin
                    if (mshr_timer[i] > 0)
                        mshr_timer[i] <= mshr_timer[i] - 1;
                    else begin
                        cache_tags[mshr_addr[i][1:0]] <= mshr_addr[i][3:2];
                        cache_valid[mshr_addr[i][1:0]] <= 1;
                        cache_data[mshr_addr[i][1:0]] <= mshr_write[i] ? mshr_data[i] : 8'hAA;
                        mshr_valid[i] <= 0;
                    end
                end
            end
        end
    end

endmodule
