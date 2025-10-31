
/*

Header file for MSI protocol variables

*/


`ifndef MSI_TYPES_VH
`define MSI_TYPES_VH


// ========== MSI States ==========
`define MSI_INVALID    2'b00
`define MSI_SHARED     2'b01
`define MSI_MODIFIED   2'b11


// ========== MSI Bus message types ==========
`define BUS_IDLE  4'b0000
`define BUS_RD    4'b0001
`define BUS_RDX   4'b0010
`define BUS_WB    4'b0011
`define BUS_UPGR  4'b0100 // upgrade S-> M Optimization
`define BUS_INVALIDATE  4'b0011 // invalidate cammand
`define BUS_DATA  4'b0110    // data responce state

// ========== Processor Request ==========
`define PR_IDLE  3'b000      // No request
`define PR_RD    3'b001      // read request
`define PR_WR    3'b010      //processor write req
`define PR_EVICT 3'b011      // Eviction

// ========== BUS Width ==========
`define BUS_ADDR_WIDTH 16
`define BUS_DATA_WIDTH 128
`define BUS_MSG_TYPE_WIDTH 4 
`define MSI_STATE_WIDTH 2


// ========== Address decomposition 
// tag-7 , set_index-5 , byte_offset-4 , filler 16

`define GET_TAG(addr)       ((addr)>>9)
`define GET_SET_IDX(addr)   (((addr)>>4) & 5'b11111)
`define  GET_BYTE_OFF(addr) ((addr) & 4'hf)

// ===== LATENCY CYCLE DEFINITIONS =====
`define LATENCY_L1_HIT        3'd3    // L1 cache hit: 3 cycles
`define LATENCY_L2_HIT        3'd5    // L1 miss, L2 hit: 5 cycles
`define LATENCY_MEMORY_HIT    3'd7    // L1 & L2 miss, memory: 7 cycles

// ===== LATENCY STATE MACHINE =====
`define LATENCY_IDLE          2'b00   // No latency in progress
`define LATENCY_ACTIVE        2'b01   // Latency counter running
`define LATENCY_COMPLETE      2'b10   // Latency expired, ready to respond

// ===== LATENCY SOURCE IDENTIFICATION =====
`define LATENCY_SOURCE_L1     3'd0    // Hit from L1
`define LATENCY_SOURCE_L2     3'd1    // Hit from L2
`define LATENCY_SOURCE_MEM    3'd2    // Hit from Memory

`endif