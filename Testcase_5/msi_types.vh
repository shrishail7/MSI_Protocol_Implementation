`ifndef MSI_TYPES_VH
`define MSI_TYPES_VH

// ========== MSI States (3-bit: stable + transient states) ==========
`define MSI_INVALID    3'b000  // I state
`define MSI_SHARED     3'b001  // S state
`define MSI_MODIFIED   3'b010  // M state
`define MSI_ISD        3'b011  // Intermediate: I->S (GetS data waiting)
`define MSI_IMD        3'b100  // Intermediate: I->M or M->I (PutM/GetM data waiting)
`define MSI_SMD        3'b101  // Intermediate: S->M (GetM data waiting)

// ========== MSI Bus message types ==========
`define BUS_IDLE       4'b0000
`define BUS_RD         4'b0001  // GetS request
`define BUS_RDX        4'b0010  // GetM request
`define BUS_WB         4'b0011  // PutM (Write-back)
`define BUS_UPGR       4'b0100  // S->M upgrade
`define BUS_DATA       4'b0110  // Data response

// ========== Processor Request Types ==========
`define PR_IDLE        3'b000   // No request
`define PR_RD          3'b001   // Read request
`define PR_WR          3'b010   // Write request
`define PR_EVICT       3'b011   // Cache eviction

// ========== BUS Width Parameters ==========
`define BUS_ADDR_WIDTH 16
`define BUS_DATA_WIDTH 128
`define BUS_MSG_TYPE_WIDTH 4
`define MSI_STATE_WIDTH 3

// ========== Address decomposition (L1: 1KB, 2-way)
`define GET_TAG(addr)       ((addr)>>9)
`define GET_SET_IDX(addr)   (((addr)>>4) & 5'b11111)
`define GET_BYTE_OFF(addr)  ((addr) & 4'hf)

// ========== Address decomposition (L2: 8KB, 2-way)
`define GET_L2_TAG(addr)    ((addr)>>12)
`define GET_L2_SET(addr)    (((addr)>>4) & 8'hff)

// ========== Latency Cycle Definitions ==========
`define LATENCY_L1_HIT        3'd3    // L1 cache hit: 3 cycles
`define LATENCY_L2_HIT        3'd5    // L1 miss, L2 hit: 5 cycles
`define LATENCY_MEMORY_HIT    3'd7    // L1 & L2 miss, memory: 7 cycles

`endif
