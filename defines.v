// ============================================================
//  defines.v - Global Parameters
// ============================================================

`define NUM_SETS        4
`define NUM_WAYS        2
`define BLOCK_SIZE      8
`define ADDR_WIDTH      8
`define INDEX_BITS      2
`define TAG_BITS        4
`define OFFSET_BITS     2
`define NUM_MSHR        4
`define MEM_LATENCY     6

// MSHR States
`define MSHR_INVALID    2'b00
`define MSHR_ALLOCATED  2'b01
`define MSHR_WAITING    2'b10
`define MSHR_FILLING    2'b11
