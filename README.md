# MSHR-Based Non-Blocking Cache Verification

This project implements and verifies a **non-blocking cache** with **dual MSHRs (Miss Status Holding Registers)** using SystemVerilog. The testbench is designed to explore cache hit/miss conditions, simultaneous miss handling, and edge cases like MSHR full.

---

## Concept Overview

Traditional blocking caches stall on a miss. This design allows up to **two outstanding misses** to proceed concurrently using two MSHRs. Requests are queued and serviced independently, simulating realistic memory delays.

Each MSHR holds the metadata for a pending miss, ensuring the cache doesn't block subsequent requests.  
This approach improves performance in pipelined systems and mimics real-world out-of-order memory behavior.

---

##  Design Highlights

- **Direct-Mapped Cache**
- **2-entry MSHR** for parallel miss handling
- **Tag-based hit detection**
- Read/Write support
- Simulated memory latency

---

##  Verification Features

- SystemVerilog assertions for functional correctness
- Testbench generates:
  - Write + Read (RAW)
  - Consecutive read misses (with MSHRs)
  - MSHR full: third request is dropped
- **Waveform-based debugging** with EPWave
- Complete signal observation using `.vcd`

---

## Waveform Snapshot

> Read-after-write hit  
> Two parallel misses allocated  
>  Third miss rejected due to MSHR full  
>  Later hits succeed

![Waveform](waveforms_screenshot.png)

---

##  Repository Structure

| File               | Description                              |
|--------------------|------------------------------------------|
| `design.sv`        | Cache + MSHR RTL design                  |
| `testbench.sv`     | Testbench with corner case coverage      |
| `dump.vcd`         | Waveform file (generated after run)      |
| `waveforms_screenshot.png` | Visual snapshot of signal behavior |

---


