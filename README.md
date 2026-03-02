# MSHR-Based Non-Blocking Cache

A synthesizable, parameterized non-blocking cache implemented in Verilog, verified with a self-checking testbench. Built to demonstrate design verification methodologies relevant to IC development flows.

---

## Architecture Overview
```
CPU Request
     │
     ▼
┌─────────────┐     hit     ┌──────────────────┐
│  Tag Lookup  │───────────▶│  Cache Data Array │
│ (2-way LRU)  │            │  (2-way, 4 sets)  │
└─────────────┘             └──────────────────┘
     │ miss
     ▼
┌─────────────────────────┐
│     MSHR File (x4)       │
│  INVALID → ALLOCATED     │
│  → WAITING → FILLING     │
│  + Request Coalescing    │
└─────────────────────────┘
     │
     ▼
┌─────────────┐
│  Mem Model   │  (latency-accurate backing memory)
│  256 x 8b    │
└─────────────┘
```

---

## Features

- **2-way set-associative** with pseudo-LRU replacement policy
- **4-entry MSHR file** — tracks up to 4 simultaneous outstanding misses
- **Per-entry FSM** — each MSHR transitions through `INVALID → ALLOCATED → WAITING → FILLING`
- **Request coalescing** — a second miss to an in-flight address merges into the existing MSHR instead of allocating a new one
- **Latency-accurate memory model** — configurable cycle latency, address-seeded initial data for easy verification
- **Non-blocking** — cache continues to accept hits while misses are pending

---

## File Structure
```
├── defines.v       # Global parameters (sets, ways, MSHR count, latency)
├── cache.v         # Top-level cache with MSHR FSM and LRU logic
├── mem_model.v     # Backing memory — stores real data, models latency
└── testbench.v     # Self-checking testbench with pass/fail reporting
```

---

## Parameters (`defines.v`)

| Parameter | Default | Description |
|---|---|---|
| `NUM_SETS` | 4 | Number of cache sets |
| `NUM_WAYS` | 2 | Associativity |
| `NUM_MSHR` | 4 | Outstanding miss capacity |
| `MEM_LATENCY` | 6 | Memory response latency (cycles) |
| `ADDR_WIDTH` | 8 | Address width (bits) |
| `BLOCK_SIZE` | 8 | Data width (bits) |

---

## Test Coverage

| Test | Scenario | Result |
|---|---|---|
| T1 | Write → wait for fill → read back | PASS |
| T2 | Cold read miss → fill from memory → hit | PASS |
| T3 | Saturate all 4 MSHRs → verify `mshr_full` signal | PASS |
| T4 | Two misses to same address → coalesced into one MSHR | PASS |
| T5 | LRU eviction — both ways filled, verify correct evict | PASS |

All 6 assertions passed. 0 failures.

---

## How to Run (Vivado)

1. Create a new RTL project in Vivado (Verilog)
2. Add `defines.v`, `cache.v`, `mem_model.v` as design sources
3. Add `testbench.v` as simulation source
4. Set `testbench` as simulation top
5. Run Behavioral Simulation → check console for `PASS/FAIL` output
6. Add signals to waveform: `hit`, `miss`, `mshr_full`, `ready`, `rdata`, `mem_req_valid`, `mem_resp_valid`

---

## Key Waveforms to Observe

- **MSHR fill handshake**: `mem_req_valid` goes high when MSHR transitions `ALLOCATED → WAITING`, `mem_resp_valid` comes back after latency
- **Coalescing**: Two back-to-back misses to `0x20` — only one `mem_req_valid` pulse observed
- **MSHR full**: `mshr_full` asserts on 5th simultaneous miss when all 4 entries occupied

> <img width="1914" height="1022" alt="image" src="https://github.com/user-attachments/assets/da85620b-0793-4d58-af50-b804a9e8e59d" />


---

## Concepts Demonstrated

- Non-blocking cache design and memory-level parallelism
- MSHR allocation, tracking, and coalescing
- Finite state machine design in synthesizable Verilog
- Set-associative cache indexing and LRU replacement
- Latency modeling and memory interface handshaking
- Self-checking testbench methodology
