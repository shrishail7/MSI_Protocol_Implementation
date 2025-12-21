

`include "msi_types.vh"


module P2_controller (

input wire clk,
input wire reset,

// ========== Processor Interface ==========
input wire [3:0] proc_req_type,
input wire [15:0] proc_req_addr,
input wire [127:0] proc_write_data,
output reg [127:0] proc_read_data,
output wire [2:0] ctrl_current_state,
output reg proc_resp_valid,
output reg proc_resp_hit,

// ========== L1 Cache Read Interface ==========
output reg [4:0] l1_rd_set_idx,
input wire [6:0] l1_rd_tag_way0,
input wire [6:0] l1_rd_tag_way1,
input wire [127:0] l1_rd_data_way0,
input wire [127:0] l1_rd_data_way1,
input wire l1_rd_valid_way0,
input wire l1_rd_valid_way1,
input wire l1_rd_dirty_way0,
input wire l1_rd_dirty_way1,
input wire l1_rd_lru_bit,
input wire [2:0] l1_rd_msi_way0,
input wire [2:0] l1_rd_msi_way1,

// ========== L1 Cache Write Interface ==========
output reg l1_wr_en,
output reg [4:0] l1_wr_set_idx,
output reg l1_wr_way,
output reg [6:0] l1_wr_tag,
output reg [127:0] l1_wr_data,
output reg l1_wr_valid,
output reg l1_wr_dirty,
output reg [2:0] l1_wr_msi,
output reg l1_wr_lru,

// ========== Bus Interface (Request) ==========
output reg [3:0] bus_req_type,
output reg [15:0] bus_req_addr,
output reg [127:0] bus_req_data,
output reg bus_req_valid,
input wire bus_req_grant,

// ========== Bus Interface (Snoop Response) ==========
input wire [3:0] bus_msg_type,
input wire [15:0] bus_addr,
input wire [127:0] bus_data,
input wire bus_valid,
input wire [1:0] bus_requester_id,

// ========== L2 Response Interface ==========
input wire [127:0] l2_resp_data,
input wire l2_resp_valid,
output wire [2:0] p2_pending_msi_debug

);
// ========== State Machine Parameters ==========
localparam STATE_IDLE = 3'd0;
localparam STATE_READ = 3'd1;
localparam STATE_WRITE = 3'd2;
localparam STATE_BUS_REQ = 3'd3;
localparam STATE_WAIT_L2 = 3'd4;
localparam STATE_TRANSIENT = 3'd5;

// ========== Internal Signals ==========
reg [2:0] current_state;
reg [3:0] pending_req_type;
reg [15:0] pending_addr;
reg [127:0] pending_data;
reg [4:0] pending_set_idx;
reg [6:0] pending_tag;
reg hit_way;
reg hit_valid;
reg [2:0] hit_msi_state;
reg [127:0] hit_data;
reg [127:0] hit_data_stable;
reg pending_wr_way; // ⭐ FIX: Register to store the correct way for S->M upgrades

// ========== Latency Counter ==========
reg [3:0] latency_counter;
reg latency_active;

// ========== Transient State Tracking ==========
reg [2:0] target_msi_state;
reg [127:0] transient_l1_wr_data;

assign p2_pending_msi_debug = 3'b000;

// ========== Main State Machine ==========
always @(posedge clk) begin

if(reset) begin
  current_state <= STATE_IDLE;
  pending_req_type <= `PR_IDLE;
  bus_req_valid <= 1'b0;
  l1_wr_en <= 1'b0;
  proc_resp_valid <= 1'b0;
  latency_active <= 1'b0;
  proc_read_data <= 128'b0;
  target_msi_state <= `MSI_INVALID;
  transient_l1_wr_data <= 128'b0;
  hit_data_stable <= 128'b0;
end

else begin

// ========== Default Assignments ==========
l1_wr_en <= 1'b0;
bus_req_valid <= 1'b0;
proc_resp_valid <= 1'b0;

case (current_state)

STATE_IDLE: begin
  if(proc_req_type != `PR_IDLE) begin
    pending_req_type <= proc_req_type;
    pending_addr <= proc_req_addr;
    pending_data <= proc_write_data;
    pending_set_idx <= proc_req_addr[8:4];
    pending_tag <= proc_req_addr[15:9];
    
    if(proc_req_type == `PR_RD)
      current_state <= STATE_READ;
    else if(proc_req_type == `PR_WR)
      current_state <= STATE_WRITE;
  end
end

STATE_READ: begin
  l1_rd_set_idx <= pending_set_idx;
  // Check L1 hit
  if((l1_rd_valid_way0 && (l1_rd_tag_way0 == pending_tag)) ||
     (l1_rd_valid_way1 && (l1_rd_tag_way1 == pending_tag))) begin
    
    // Determine hit way
    if(l1_rd_valid_way0 && (l1_rd_tag_way0 == pending_tag)) begin
      hit_valid <= 1'b1;
      hit_way <= 1'b0;
      hit_msi_state <= l1_rd_msi_way0;
      hit_data <= l1_rd_data_way0;
      hit_data_stable <= l1_rd_data_way0;
    end
    else begin
      hit_valid <= 1'b1;
      hit_way <= 1'b1;
      hit_msi_state <= l1_rd_msi_way1;
      hit_data <= l1_rd_data_way1;
      hit_data_stable <= l1_rd_data_way1;
    end
    
    // L1 Hit - start latency
    latency_active <= 1'b1;
    latency_counter <= 4'd2;
    proc_resp_hit <= 1'b1;
    current_state <= STATE_IDLE;
  end
  else begin
    // L1 Miss - request from bus
    pending_wr_way <= l1_rd_lru_bit; // Store victim way
    bus_req_valid <= 1'b1;
    bus_req_type <= `BUS_RD;
    bus_req_addr <= pending_addr;
    bus_req_data <= 128'b0;
    current_state <= STATE_BUS_REQ;
  end
end

STATE_WRITE: begin
  l1_rd_set_idx <= pending_set_idx;
  // Check L1 hit
  if((l1_rd_valid_way0 && (l1_rd_tag_way0 == pending_tag)) ||
     (l1_rd_valid_way1 && (l1_rd_tag_way1 == pending_tag))) begin
    
    // Get hit info
    if(l1_rd_valid_way0 && (l1_rd_tag_way0 == pending_tag)) begin
      hit_valid <= 1'b1;
      hit_way <= 1'b0;
      hit_msi_state <= l1_rd_msi_way0;
      hit_data <= l1_rd_data_way0;
    end
    else begin
      hit_valid <= 1'b1;
      hit_way <= 1'b1;
      hit_msi_state <= l1_rd_msi_way1;
      hit_data <= l1_rd_data_way1;
    end
    
    // Write hit in M state - direct write
    if(hit_msi_state == `MSI_MODIFIED) begin
      l1_wr_en <= 1'b1;
      l1_wr_set_idx <= pending_set_idx;
      l1_wr_way <= hit_way;
      l1_wr_tag <= pending_tag;
      l1_wr_data <= pending_data;
      l1_wr_valid <= 1'b1;
      l1_wr_msi <= `MSI_MODIFIED;
      l1_wr_dirty <= 1'b1;
      l1_wr_lru <= ~l1_rd_lru_bit; // ⭐ LRU FIX
      
      latency_active <= 1'b1;
      latency_counter <= 4'd2;
      proc_resp_hit <= 1'b1;
      current_state <= STATE_IDLE;
    end
    
    // Write hit in S state - need upgrade
    else if(hit_msi_state == `MSI_SHARED) begin
      pending_wr_way <= hit_way; // ⭐ S->M FIX
      bus_req_valid <= 1'b1;
      bus_req_type <= `BUS_UPGR;
      bus_req_addr <= pending_addr;
      bus_req_data <= 128'b0;
      current_state <= STATE_BUS_REQ;
    end
  end
  
  else begin
    // L1 Miss - need GetM
    pending_wr_way <= l1_rd_lru_bit; // ⭐ S->M FIX
    bus_req_valid <= 1'b1;
    bus_req_type <= `BUS_RDX;
    bus_req_addr <= pending_addr;
    bus_req_data <= 128'b0;
    current_state <= STATE_BUS_REQ;
  end
end

STATE_BUS_REQ: begin
  if(bus_req_grant) begin
    bus_req_valid <= 1'b0;
    current_state <= STATE_WAIT_L2;
  end
end

STATE_WAIT_L2: begin
  if(l2_resp_valid) begin
    // FIRST WRITE: ISD/IMD state with L2 data
    l1_wr_en <= 1'b1;
    l1_wr_set_idx <= pending_set_idx;
    l1_wr_way <= pending_wr_way; // ⭐ S->M FIX
    l1_wr_tag <= pending_tag;
    l1_wr_data <= l2_resp_data;
    l1_wr_valid <= 1'b1;

    hit_data_stable <= l2_resp_data;
    transient_l1_wr_data <= l2_resp_data;

    if(pending_req_type == `PR_RD) begin
      l1_wr_msi <= `MSI_ISD; // 3'd3
      l1_wr_dirty <= 1'b0;
      target_msi_state <= `MSI_SHARED;
    end
    else begin
      l1_wr_msi <= `MSI_IMD; // 3'd4
      l1_wr_dirty <= 1'b0;
      target_msi_state <= `MSI_MODIFIED;
    end
    
    l1_wr_lru <= ~l1_rd_lru_bit; // ⭐ LRU FIX
    proc_resp_hit <= 1'b0;
    
    current_state <= STATE_TRANSIENT;
  end
end

STATE_TRANSIENT: begin
  // SECOND WRITE: Final MSI state
  l1_wr_en <= 1'b1;
  l1_wr_set_idx <= pending_set_idx;
  l1_wr_way <= pending_wr_way; // ⭐ S->M FIX
  l1_wr_tag <= pending_tag;
  
  if(pending_req_type == `PR_WR) begin
      l1_wr_data <= pending_data; 
  end else begin
      l1_wr_data <= transient_l1_wr_data;
  end

  l1_wr_valid <= 1'b1;
  l1_wr_msi <= target_msi_state;
  l1_wr_lru <= ~l1_rd_lru_bit; // ⭐ LRU FIX

  if(target_msi_state == `MSI_MODIFIED)
    l1_wr_dirty <= 1'b1;
  else
    l1_wr_dirty <= 1'b0;
  
  // Start latency for response
  latency_active <= 1'b1;
  latency_counter <= 4'd4;
  proc_resp_hit <= 1'b0;
  
  // Return to IDLE
  current_state <= STATE_IDLE;
end

endcase

// ========== Latency Counter Logic ==========
if(latency_active) begin
  if(latency_counter > 4'd0)
    latency_counter <= latency_counter - 4'd1;
  else begin
    latency_active <= 1'b0;
    proc_resp_valid <= 1'b1;
    proc_read_data <= hit_data_stable;
  end
end
else begin
  proc_resp_valid <= 1'b0;
end

end

end

// ========== Snooping Logic ==========
always @(posedge clk) begin

if(!reset && bus_valid) begin
  // Check if snoop targets our L1 cache
  // This logic is simple and assumes tags/sets don't match
  // a pending request, which is fine for this simulation.
  if((bus_addr[15:9] == pending_tag) && (bus_addr[8:4] == pending_set_idx)) begin
    
    if(bus_msg_type == `BUS_RDX && bus_requester_id != 2'b10) begin
      // Other processor's GetM - invalidate our copy
      if((l1_rd_valid_way0 && (l1_rd_tag_way0 == bus_addr[15:9])) ||
         (l1_rd_valid_way1 && (l1_rd_tag_way1 == bus_addr[15:9]))) begin
        
        if(l1_rd_valid_way0 && (l1_rd_tag_way0 == bus_addr[15:9])) begin
          l1_wr_en <= 1'b1;
          l1_wr_set_idx <= bus_addr[8:4];
          l1_wr_way <= 1'b0;
          l1_wr_valid <= 1'b0;
          l1_wr_msi <= `MSI_INVALID;
        end
        else begin
          l1_wr_en <= 1'b1;
          l1_wr_set_idx <= bus_addr[8:4];
          l1_wr_way <= 1'b1;
          l1_wr_valid <= 1'b0;
          // ⭐ TYPO FIX: Was l1__msi, now corrected
          l1_wr_msi <= `MSI_INVALID; 
        end
      end
    end
  end
end

end

assign ctrl_current_state = current_state;
endmodule


