# MSHR-Based Non-Blocking Cache Verification

This project simulates and verifies a non-blocking, direct-mapped cache implemented in Verilog with dual Miss Status Handling Registers (MSHRs). The design supports read and write operations, handles concurrent cache misses via MSHRs, and includes assertion-based checks and waveform-based debugging.

## 🔧 Features

- **Dual-MSHR support** for concurrent miss tracking
- **Read/Write request support** with cache fill handling
- **Corner case testing**: hits, misses, MSHR full scenarios
- **Assertions** to check timing and MSHR correctness
- **Waveform debugging** using EPWave/GTKWave
- **Fully automated testbench** with task-based interface

## File Overview

| File            | Description                                 |
|-----------------|---------------------------------------------|
| `design.sv`     | Cache module with MSHR logic and assertions |
| `testbench.sv`  | SystemVerilog testbench with all testcases  |
| `waveform.png`  | Waveform snapshot (optional)                |
| `dump.vcd`      | VCD generated during simulation              |

## Run Instructions

You can run this using Icarus Verilog and GTKWave
