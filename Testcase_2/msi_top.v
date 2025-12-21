/*
TOP MODULE - MSI Cache Hierarchy with Write-Through Support
FIXED: Corrected L2_memory_controller port connections
*/

`include "msi_types.vh"

module msi_cache_hierarchy (
    input wire clk,
    input wire reset,

    // ========== Processor 1 Interface ==========
    input wire [3:0] p1_proc_req_type,
    input wire [15:0] p1_proc_req_addr,
    input wire [127:0] p1_proc_write_data,
    output wire [127:0] p1_proc_read_data,
    output wire p1_proc_resp_valid,
    output wire p1_proc_resp_hit,

    // ========== Processor 2 Interface ==========
    input wire [3:0] p2_proc_req_type,
    input wire [15:0] p2_proc_req_addr,
    input wire [127:0] p2_proc_write_data,
    output wire [127:0] p2_proc_read_data,
    output wire p2_proc_resp_valid,
    output wire p2_proc_resp_hit,

    // ========== Debug Signals ==========
    output wire [2:0] p1_l1_state_way0,
    output wire [2:0] p1_l1_state_way1,
    output wire [2:0] p2_l1_state_way0,
    output wire [2:0] p2_l1_state_way1,
    output wire [2:0] l2_state_way0,
    output wire [2:0] l2_state_way1,
    output wire p1_l1_hit,
    output wire p1_l1_miss,
    output wire p2_l1_hit,
    output wire p2_l1_miss,
    output wire l2_hit,
    output wire l2_miss,
    output wire [2:0] p2_current_state_debug,
    output wire [2:0] p2_pending_msi_debug,
    
    // ========== Memory Debug ==========
    output wire mem_read,
    output wire mem_write,
    output wire [15:0] mem_addr,
    output wire [127:0] mem_wdata,
    output wire [127:0] mem_rdata,
    output wire mem_ready

);

    // ========== Internal Bus Signals ==========
    wire [3:0] bus_msg_type;
    wire [15:0] bus_addr;
    wire [127:0] bus_data;
    wire bus_valid;
    wire [1:0] bus_requester_id;

    // ========== P1 L1 Cache Signals ==========
    wire [4:0] p1_l1_rd_set_idx, p1_l1_wr_set_idx;
    wire [6:0] p1_l1_rd_tag_way0, p1_l1_rd_tag_way1;
    wire [127:0] p1_l1_rd_data_way0, p1_l1_rd_data_way1;
    wire p1_l1_rd_valid_way0, p1_l1_rd_valid_way1;
    wire p1_l1_rd_dirty_way0, p1_l1_rd_dirty_way1;
    wire p1_l1_rd_lru_bit;
    wire [2:0] p1_l1_rd_msi_way0, p1_l1_rd_msi_way1;
    wire p1_l1_wr_en, p1_l1_wr_way;
    wire [6:0] p1_l1_wr_tag;
    wire [127:0] p1_l1_wr_data;
    wire p1_l1_wr_valid, p1_l1_wr_dirty;
    wire [2:0] p1_l1_wr_msi;
    wire p1_l1_wr_lru;

    // ========== P2 L1 Cache Signals ==========
    wire [4:0] p2_l1_rd_set_idx, p2_l1_wr_set_idx;
    wire [6:0] p2_l1_rd_tag_way0, p2_l1_rd_tag_way1;
    wire [127:0] p2_l1_rd_data_way0, p2_l1_rd_data_way1;
    wire p2_l1_rd_valid_way0, p2_l1_rd_valid_way1;
    wire p2_l1_rd_dirty_way0, p2_l1_rd_dirty_way1;
    wire p2_l1_rd_lru_bit;
    wire [2:0] p2_l1_rd_msi_way0, p2_l1_rd_msi_way1;
    wire p2_l1_wr_en, p2_l1_wr_way;
    wire [6:0] p2_l1_wr_tag;
    wire [127:0] p2_l1_wr_data;
    wire p2_l1_wr_valid, p2_l1_wr_dirty;
    wire [2:0] p2_l1_wr_msi;
    wire p2_l1_wr_lru;

    // ========== L2 Cache Signals ==========
    wire [7:0] l2_rd_set_idx, l2_wr_set_idx;
    wire [3:0] l2_rd_tag_way0, l2_rd_tag_way1;
    wire [127:0] l2_rd_data_way0, l2_rd_data_way1;
    wire l2_rd_valid_way0, l2_rd_valid_way1;
    wire l2_rd_dirty_way0, l2_rd_dirty_way1;
    wire l2_rd_lru_bit;
    wire [2:0] l2_rd_msi_way0, l2_rd_msi_way1;
    wire l2_hit_valid;
    wire l2_wr_en, l2_wr_way;
    wire [3:0] l2_wr_tag;
    wire [127:0] l2_wr_data;
    wire l2_wr_valid, l2_wr_dirty;
    wire [2:0] l2_wr_msi;
    wire l2_wr_lru;

    // ⭐ NEW: Write-Through Signals from P1 to L2 Memory Controller
    wire p1_mem_wr_req_valid;
    wire [15:0] p1_mem_wr_addr;
    wire [127:0] p1_mem_wr_data;

    // ========== L2 Memory Controller Signals ==========
    wire [3:0] l2m_bus_msg_type;
    wire [15:0] l2m_bus_req_addr;
    wire [127:0] l2m_bus_req_data;
    wire l2m_bus_req_valid;
    wire l2m_bus_req_ack;
    wire [127:0] l2m_bus_resp_data;
    wire l2m_bus_resp_valid;
    wire [3:0] l2m_bus_resp_type;

    // ========== Bus Arbiter Signals ==========
    wire [3:0] p1_bus_req_type, p2_bus_req_type;
    wire [15:0] p1_bus_req_addr, p2_bus_req_addr;
    wire [127:0] p1_bus_req_data, p2_bus_req_data;
    wire p1_bus_req_valid, p2_bus_req_valid;
    wire p1_bus_req_grant, p2_bus_req_grant;

    // ========== Debug Assignments ==========
    assign p1_l1_hit = p1_proc_resp_hit;
    assign p1_l1_miss = !p1_proc_resp_hit;
    assign p2_l1_hit = p2_proc_resp_hit;
    assign p2_l1_miss = !p2_proc_resp_hit;
    assign l2_hit = l2_hit_valid;
    assign l2_miss = !l2_hit_valid;

    assign p1_l1_state_way0 = p1_l1_rd_msi_way0;
    assign p1_l1_state_way1 = p1_l1_rd_msi_way1;
    assign p2_l1_state_way0 = p2_l1_rd_msi_way0;
    assign p2_l1_state_way1 = p2_l1_rd_msi_way1;
    assign l2_state_way0 = l2_rd_msi_way0;
    assign l2_state_way1 = l2_rd_msi_way1;

    // ⭐ NEW: Connect P1 write-through signals from P1_controller
    assign p1_mem_wr_req_valid = P1_CTRL.mem_wr_req_valid;
    assign p1_mem_wr_addr = P1_CTRL.mem_wr_addr;
    assign p1_mem_wr_data = P1_CTRL.mem_wr_data;

    // ========== Instantiate P1 Controller ==========
    P1_controller P1_CTRL (
        .clk(clk), .reset(reset),
        .proc_req_type(p1_proc_req_type), .proc_req_addr(p1_proc_req_addr),
        .proc_write_data(p1_proc_write_data), 
        .proc_resp_valid(p1_proc_resp_valid), .proc_resp_hit(p1_proc_resp_hit),
        .proc_read_data(p1_proc_read_data),
        
        .l1_rd_set_idx(p1_l1_rd_set_idx), .l1_rd_tag_way0(p1_l1_rd_tag_way0),
        .l1_rd_tag_way1(p1_l1_rd_tag_way1), .l1_rd_data_way0(p1_l1_rd_data_way0),
        .l1_rd_data_way1(p1_l1_rd_data_way1), .l1_rd_valid_way0(p1_l1_rd_valid_way0),
        .l1_rd_valid_way1(p1_l1_rd_valid_way1), .l1_rd_dirty_way0(p1_l1_rd_dirty_way0),
        .l1_rd_dirty_way1(p1_l1_rd_dirty_way1), .l1_rd_lru_bit(p1_l1_rd_lru_bit),
        .l1_rd_msi_way0(p1_l1_rd_msi_way0), .l1_rd_msi_way1(p1_l1_rd_msi_way1),
        
        .l1_wr_en(p1_l1_wr_en), .l1_wr_set_idx(p1_l1_wr_set_idx),
        .l1_wr_way(p1_l1_wr_way), .l1_wr_tag(p1_l1_wr_tag),
        .l1_wr_data(p1_l1_wr_data), .l1_wr_valid(p1_l1_wr_valid),
        .l1_wr_dirty(p1_l1_wr_dirty), .l1_wr_msi(p1_l1_wr_msi),
        .l1_wr_lru(p1_l1_wr_lru),
        
        .bus_req_type(p1_bus_req_type), .bus_req_addr(p1_bus_req_addr),
        .bus_req_data(p1_bus_req_data), .bus_req_valid(p1_bus_req_valid),
        .bus_req_grant(p1_bus_req_grant),
        
        .bus_msg_type(bus_msg_type), .bus_addr(bus_addr),
        .bus_data(bus_data), .bus_valid(bus_valid),
        .bus_requester_id(bus_requester_id),
        
        .l2_resp_data(l2m_bus_resp_data), .l2_resp_valid(l2m_bus_resp_valid),
        .l2_hit_valid(l2_hit_valid),
        
        .mem_wr_req_valid(p1_mem_wr_req_valid),
        .mem_wr_addr(p1_mem_wr_addr),
        .mem_wr_data(p1_mem_wr_data)
    );

    // ========== Instantiate P2 Controller ==========
    P2_controller P2_CTRL (
        .clk(clk), .reset(reset),
        .proc_req_type(p2_proc_req_type), .proc_req_addr(p2_proc_req_addr),
        .proc_write_data(p2_proc_write_data), 
        .proc_resp_valid(p2_proc_resp_valid), .proc_resp_hit(p2_proc_resp_hit),
        .proc_read_data(p2_proc_read_data),
        
        .l1_rd_set_idx(p2_l1_rd_set_idx), .l1_rd_tag_way0(p2_l1_rd_tag_way0),
        .l1_rd_tag_way1(p2_l1_rd_tag_way1), .l1_rd_data_way0(p2_l1_rd_data_way0),
        .l1_rd_data_way1(p2_l1_rd_data_way1), .l1_rd_valid_way0(p2_l1_rd_valid_way0),
        .l1_rd_valid_way1(p2_l1_rd_valid_way1), .l1_rd_dirty_way0(p2_l1_rd_dirty_way0),
        .l1_rd_dirty_way1(p2_l1_rd_dirty_way1), .l1_rd_lru_bit(p2_l1_rd_lru_bit),
        .l1_rd_msi_way0(p2_l1_rd_msi_way0), .l1_rd_msi_way1(p2_l1_rd_msi_way1),
        
        .l1_wr_en(p2_l1_wr_en), .l1_wr_set_idx(p2_l1_wr_set_idx),
        .l1_wr_way(p2_l1_wr_way), .l1_wr_tag(p2_l1_wr_tag),
        .l1_wr_data(p2_l1_wr_data), .l1_wr_valid(p2_l1_wr_valid),
        .l1_wr_dirty(p2_l1_wr_dirty), .l1_wr_msi(p2_l1_wr_msi),
        .l1_wr_lru(p2_l1_wr_lru),
        
        .bus_req_type(p2_bus_req_type), .bus_req_addr(p2_bus_req_addr),
        .bus_req_data(p2_bus_req_data), .bus_req_valid(p2_bus_req_valid),
        .bus_req_grant(p2_bus_req_grant),
        
        .bus_msg_type(bus_msg_type), .bus_addr(bus_addr),
        .bus_data(bus_data), .bus_valid(bus_valid),
        .bus_requester_id(bus_requester_id),
        .ctrl_current_state(p2_current_state_debug),
        .p2_pending_msi_debug(p2_pending_msi_debug),

        .l2_resp_data(l2m_bus_resp_data), .l2_resp_valid(l2m_bus_resp_valid)
    );

    // ========== Instantiate Bus Arbiter ==========
    bus_arbiter BUS_ARB (
        .clk(clk), .reset(reset),
        .p1_req_type(p1_bus_req_type), .p1_req_addr(p1_bus_req_addr),
        .p1_req_data(p1_bus_req_data), .p1_req_valid(p1_bus_req_valid),
        .p1_req_grant(p1_bus_req_grant),
        .p2_req_type(p2_bus_req_type), .p2_req_addr(p2_bus_req_addr),
        .p2_req_data(p2_bus_req_data), .p2_req_valid(p2_bus_req_valid),
        .p2_req_grant(p2_bus_req_grant),
        .bus_msg_type(bus_msg_type), .bus_addr(bus_addr),
        .bus_data(bus_data), .bus_valid(bus_valid),
        .bus_requester_id(bus_requester_id),
        .l2m_resp_data(l2m_bus_resp_data), .l2m_resp_valid(l2m_bus_resp_valid),
        .l2m_resp_type(l2m_bus_resp_type)
    );

    // ⭐ FIXED: L2 Memory Controller instantiation with CORRECT ports
    L2_memory_controller L2_MEM_CTRL (
        .clk(clk), .reset(reset),
        .bus_msg_type(bus_msg_type), .bus_req_addr(bus_addr),
        .bus_req_data(bus_data), .bus_req_valid(bus_valid),
        .bus_req_ack(l2m_bus_req_ack),
        .bus_resp_data(l2m_bus_resp_data), .bus_resp_valid(l2m_bus_resp_valid),
        .bus_resp_type(l2m_bus_resp_type),
        .l2_rd_set_idx(l2_rd_set_idx), .l2_rd_en(),
        .l2_rd_tag_way0(l2_rd_tag_way0), .l2_rd_tag_way1(l2_rd_tag_way1),
        .l2_rd_data_way0(l2_rd_data_way0), .l2_rd_data_way1(l2_rd_data_way1),
        .l2_rd_valid_way0(l2_rd_valid_way0), .l2_rd_valid_way1(l2_rd_valid_way1),
        .l2_rd_dirty_way0(l2_rd_dirty_way0), .l2_rd_dirty_way1(l2_rd_dirty_way1),
        .l2_rd_lru_bit(l2_rd_lru_bit), .l2_rd_msi_way0(l2_rd_msi_way0),
        .l2_rd_msi_way1(l2_rd_msi_way1),
        .l2_wr_en(l2_wr_en), .l2_wr_set_idx(l2_wr_set_idx),
        .l2_wr_way(l2_wr_way), .l2_wr_tag(l2_wr_tag),
        .l2_wr_data(l2_wr_data), .l2_wr_valid(l2_wr_valid),
        .l2_wr_dirty(l2_wr_dirty), .l2_wr_msi(l2_wr_msi),
        .l2_wr_lru(l2_wr_lru),
        // ⭐ FIXED: Correct memory ports (removed mem_resp_valid)
        .mem_req_valid(mem_read), 
        .mem_req_read(), 
        .mem_req_write(mem_write),
        .mem_req_addr(mem_addr),
        .mem_req_data(mem_wdata), 
        .mem_resp_data(mem_rdata),
        .mem_ready(mem_ready),
        // ⭐ NEW: Write-Through connections
        .p1_mem_wr_req_valid(p1_mem_wr_req_valid),
        .p1_mem_wr_addr(p1_mem_wr_addr),
        .p1_mem_wr_data(p1_mem_wr_data)
    );

    // ========== Instantiate L1 Caches ==========
    // ⭐ VERIFIED: L1 cache instantiation - rd_en is properly set to 1'b1
    L1_cache #(.No_Sets(32), .No_Ways(2), .Line_Bytes(16), .Tag_Bits(7)) P1_L1 (
        .clk(clk), .reset(reset),
        .rd_set_idx(p1_l1_rd_set_idx), .rd_en(1'b1),  // ✅ CORRECT: Always enabled for read
        .rd_tag_way0(p1_l1_rd_tag_way0), .rd_tag_way1(p1_l1_rd_tag_way1),
        .rd_data_way0(p1_l1_rd_data_way0), .rd_data_way1(p1_l1_rd_data_way1),
        .rd_valid_way0(p1_l1_rd_valid_way0), .rd_valid_way1(p1_l1_rd_valid_way1),
        .rd_dirty_way0(p1_l1_rd_dirty_way0), .rd_dirty_way1(p1_l1_rd_dirty_way1),
        .rd_lru_bit(p1_l1_rd_lru_bit), .rd_msi_way0(p1_l1_rd_msi_way0),
        .rd_msi_way1(p1_l1_rd_msi_way1),
        .wr_en(p1_l1_wr_en), .wr_set_idx(p1_l1_wr_set_idx),
        .wr_way(p1_l1_wr_way), .wr_tag(p1_l1_wr_tag),
        .wr_data(p1_l1_wr_data), .wr_valid(p1_l1_wr_valid),
        .wr_dirty(p1_l1_wr_dirty), .wr_msi(p1_l1_wr_msi),
        .wr_lru(p1_l1_wr_lru)
    );

    // ⭐ VERIFIED: P2 L1 cache instantiation - rd_en is properly set to 1'b1
    L1_cache #(.No_Sets(32), .No_Ways(2), .Line_Bytes(16), .Tag_Bits(7)) P2_L1 (
        .clk(clk), .reset(reset),
        .rd_set_idx(p2_l1_rd_set_idx), .rd_en(1'b1),  // ✅ CORRECT: Always enabled for read
        .rd_tag_way0(p2_l1_rd_tag_way0), .rd_tag_way1(p2_l1_rd_tag_way1),
        .rd_data_way0(p2_l1_rd_data_way0), .rd_data_way1(p2_l1_rd_data_way1),
        .rd_valid_way0(p2_l1_rd_valid_way0), .rd_valid_way1(p2_l1_rd_valid_way1),
        .rd_dirty_way0(p2_l1_rd_dirty_way0), .rd_dirty_way1(p2_l1_rd_dirty_way1),
        .rd_lru_bit(p2_l1_rd_lru_bit), .rd_msi_way0(p2_l1_rd_msi_way0),
        .rd_msi_way1(p2_l1_rd_msi_way1),
        .wr_en(p2_l1_wr_en), .wr_set_idx(p2_l1_wr_set_idx),
        .wr_way(p2_l1_wr_way), .wr_tag(p2_l1_wr_tag),
        .wr_data(p2_l1_wr_data), .wr_valid(p2_l1_wr_valid),
        .wr_dirty(p2_l1_wr_dirty), .wr_msi(p2_l1_wr_msi),
        .wr_lru(p2_l1_wr_lru)
    );

    // ========== Instantiate L2 Cache ==========
    L2_cache #(.No_Sets(256), .No_Ways(2), .Line_Bytes(16), .Tag_Bits(4)) L2 (
        .clk(clk), .reset(reset),
        .rd_set_index(l2_rd_set_idx), .rd_en(1'b1),  // ✅ CORRECT: Always enabled for read
        .rd_tag_way0(l2_rd_tag_way0), .rd_tag_way1(l2_rd_tag_way1),
        .rd_data_way0(l2_rd_data_way0), .rd_data_way1(l2_rd_data_way1),
        .rd_valid_way0(l2_rd_valid_way0), .rd_valid_way1(l2_rd_valid_way1),
        .rd_dirty_way0(l2_rd_dirty_way0), .rd_dirty_way1(l2_rd_dirty_way1),
        .rd_lru_bit(l2_rd_lru_bit), .rd_msi_way0(l2_rd_msi_way0),
        .rd_msi_way1(l2_rd_msi_way1), .l2_hit_valid(l2_hit_valid),
        .wr_en(l2_wr_en), .wr_set_idx(l2_wr_set_idx),
        .wr_way(l2_wr_way), .wr_tag(l2_wr_tag),
        .wr_data(l2_wr_data), .wr_valid(l2_wr_valid),
        .wr_dirty(l2_wr_dirty), .wr_msi(l2_wr_msi),
        .wr_lru(l2_wr_lru)
    );

    // ========== Instantiate Main Memory ==========
    main_memory #(.Addr_Width(16), .Line_Bytes(16)) MEMORY (
        .clk(clk), .reset(reset),
        .mem_read(mem_read), .mem_write(mem_write),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata), .mem_ready(mem_ready)
    );

endmodule