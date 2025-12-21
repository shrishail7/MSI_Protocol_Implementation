
## 📋 Project Overview

This project implements a **multi-level cache hierarchy** with **MSI (Modified-Shared-Invalid) cache coherence protocol** and **write-through** support. The system includes two processors (P1 and P2) with private L1 caches, a shared L2 cache, main memory, and a bus-based coherence mechanism.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CACHE HIERARCHY                          │
├─────────────────────────────────────────────────────────────┤
│                                                            │
│    P1 Processor       P2 Processor                         │
│        │                  │                                 │
│    P1 L1 Cache       P2 L1 Cache                           │
│    (1KB, 2-way)      (1KB, 2-way)                          │
│        │                  │                                 │
│        └───────┬──────┬───┘                                 │
│                │      │                                     │
│            Bus Arbiter & Snooping                          │
│                    │                                        │
│                L2 Memory Controller                        │
│                    │                                        │
│                L2 Cache (8KB, 2-way)                       │
│                    │                                        │
│                Main Memory (64KB)                          │
│                                                            │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
msi_cache_project/testcase_1/
├── 📄 msi_top.v                  # Top-level module
├── 📄 P1_controller.v           # P1 Cache Controller (with write-through)
├── 📄 P2_controller.v           # P2 Cache Controller
├── 📄 L1_cache.v               # L1 Cache Storage
├── 📄 L2_cache.v               # L2 Cache Storage
├── 📄 L2_memory_controller.v   # L2 & Memory Controller
├── 📄 bus_arbiter.v            # Bus Arbitration & Snooping
├── 📄 main_memory.v            # Main Memory Module
├── 📄 msi_types.vh             # Type Definitions & Parameters
├── 📄 Testbench_1.v            # Testcase 1: P1 Write I→M Direct
├── 📄 functionality_1.txt      # Testcase 1 Expected Behavior
├── 📄 Testbench.v              # Alternate Testbench
└── 📄 README.md               # This file
```

## 🔧 Key Features

### 1. **MSI Cache Coherence Protocol**
- **Modified (M)**: Exclusive ownership, data differs from memory
- **Shared (S)**: Read-only, data consistent with memory
- **Invalid (I)**: Invalid/empty cache line
- **Transient States**: ISD, IMD, SMD for state transitions

### 2. **Write-Through Support (P1)**
- P1 implements **write-through** cache policy
- Write hits: Update L1 cache AND write to memory immediately
- Write misses: Allocate line in M state AND write to memory
- Ensures memory consistency

### 3. **Bus-Based Coherence**
- Shared bus for inter-cache communication
- Bus messages: `BUS_RD`, `BUS_RDX`, `BUS_UPGR`, `BUS_DATA`
- Snooping protocol for coherence maintenance
- Bus arbitration with priority-based scheduling

### 4. **Two-Level Cache Hierarchy**
- **L1 Caches**: 1KB each, 2-way set associative, 32 sets
- **L2 Cache**: 8KB, 2-way set associative, 256 sets
- **Main Memory**: 64KB with 7-cycle access latency

## 📊 Cache Parameters

### L1 Cache (Per Processor)
- **Size**: 1KB (1024 bytes)
- **Associativity**: 2-way set associative
- **Line Size**: 16 bytes (128 bits)
- **Number of Sets**: 32
- **Tag Bits**: 7 bits
- **Index Bits**: 5 bits
- **Offset Bits**: 4 bits

### L2 Cache
- **Size**: 8KB (8192 bytes)
- **Associativity**: 2-way set associative
- **Line Size**: 16 bytes (128 bits)
- **Number of Sets**: 256
- **Tag Bits**: 4 bits
- **Index Bits**: 8 bits
- **Offset Bits**: 4 bits

## 🚀 Testcase 1: P1 Write I→M Direct

### Objective
Test write miss handling with write-through protocol:
- P1 issues WRITE to address 0x1010
- Initially all caches are INVALID (I state)
- Expected: Direct transition I→M (no intermediate S state)
- dirty=1 (data differs from memory immediately)
- NO read of original data needed

### Expected Signal Sequence
1. **Step 1**: P1 issues write request
   - `p1_proc_req_type = WRITE (010)`
   - `p1_proc_req_addr = 0x1010`
   - `p1_proc_write_data = 0xAAAABBBBCCCCDDDD...`

2. **Step 2**: L1 cache miss detection
   - `rd_valid_way0 = 0`, `rd_valid_way1 = 0`
   - `rd_dirty = 0`

3. **Step 3**: Bus request for exclusive ownership
   - `bus_msg_type = BUS_RDX (0010)`
   - `bus_req_valid = 1`
   - `bus_valid = 1`

4. **Step 4**: Memory write (write-through)
   - `mem_write = 1`
   - `mem_wdata = processor's write data`

5. **Step 6**: L1 state transition
   - `p1_l1_state_way0: IMD (100) → M (010)`

### Verification Points
- ✅ Final MSI State: M (010)
- ✅ Valid Bit: 1
- ✅ L1 Miss Detected
- ✅ Response Valid: 1
- ✅ Dirty Bit: 1 (data differs from memory)

## 🧪 Running Simulation

### Prerequisites
- Verilog simulator (Icarus Verilog, ModelSim, etc.)
- VCD viewer (GTKWave)

### Simulation Steps
```bash
# Compile with Icarus Verilog
iverilog -o testcase1 \
    msi_types.vh \
    L1_cache.v \
    L2_cache.v \
    main_memory.v \
    bus_arbiter.v \
    L2_memory_controller.v \
    P1_controller.v \
    P2_controller.v \
    msi_top.v \
    Testbench_1.v

# Run simulation
vvp testcase1

# View waveform (optional)
gtkwave testcase1_waveform.vcd
```

### Expected Output
The testbench will display detailed verification steps:
1. Reset and initialization
2. Write request issuance
3. Cache state verification
4. Bus request validation
5. Memory write confirmation
6. Final state verification

## 🔍 Debug Signals

### Top-Level Debug Ports
```verilog
output wire [2:0] p1_l1_state_way0, p1_l1_state_way1;
output wire [2:0] p2_l1_state_way0, p2_l1_state_way1;
output wire [2:0] l2_state_way0, l2_state_way1;
output wire p1_l1_hit, p1_l1_miss;
output wire p2_l1_hit, p2_l1_miss;
output wire l2_hit, l2_miss;
```

### MSI State Encoding
| State | Binary | Description |
|-------|--------|-------------|
| I     | 000    | Invalid     |
| S     | 001    | Shared      |
| M     | 010    | Modified    |
| ISD   | 011    | I→S transient |
| IMD   | 100    | I→M transient |
| SMD   | 101    | S→M transient |

### Bus Message Types
| Message | Binary | Description |
|---------|--------|-------------|
| BUS_IDLE | 0000 | No operation |
| BUS_RD   | 0001 | Read request (GetS) |
| BUS_RDX  | 0010 | Read exclusive (GetM) |
| BUS_WB   | 0011 | Write-back (PutM) |
| BUS_UPGR | 0100 | Upgrade (S→M) |
| BUS_DATA | 0110 | Data response |

## ⚠️ Known Issues & Limitations

### Current Issues
1. **Write-Through Timing**: Memory write requests may not be held long enough for 7-cycle memory latency
2. **Bus Arbitration**: Priority logic may need refinement for concurrent requests
3. **Snooping Logic**: P2's snooping response may need enhancement

### Limitations
- Simplified memory model with fixed 7-cycle latency
- No cache eviction/write-back handling in testcases
- Limited error handling and edge case coverage

## 🛠️ Future Enhancements

### Planned Improvements
1. **Write-Back Support**: Add write-back policy option
2. **Cache Replacement**: Implement LRU replacement policy
3. **Performance Counters**: Add hit/miss counters
4. **Multi-Processor Support**: Extend beyond 2 processors
5. **Adaptive Protocols**: MOESI or MESI protocol support

### Testing Expansion
1. **Testcase 2**: P2 read after P1 write (coherence test)
2. **Testcase 3**: Concurrent read/write operations
3. **Testcase 4**: Cache line eviction scenarios
4. **Testcase 5**: Memory consistency verification

## 📚 References

### Cache Coherence Protocols
- MSI (Modified-Shared-Invalid) Protocol
- Write-through vs Write-back Policies
- Snooping-based Coherence
- Directory-based Coherence (future)

### Related Standards
- Memory Consistency Models
- Cache Hierarchy Design Principles
- Bus Arbitration Protocols

## 👥 Contributors

- **Project Lead**: Shrishail Dolle
- **Verilog Implementation**: Shrishail Dolle
- **Testing & Validation**: Shrishail Dolle

## 📄 License

This project is for educational and research purposes. All rights reserved.

---

*Last Updated: December 2024*  
*Project Status: Functional Implementation*  
*Test Coverage: Basic write-through scenario verified*
