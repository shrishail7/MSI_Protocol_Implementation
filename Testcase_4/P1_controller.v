`include "msi_types.vh"

module P1_controller (

input wire clk,
input wire reset,

// ========== Processor Interface ==========
input wire [3:0] proc_req_type,
input wire [15:0] proc_req_addr,
input wire [127:0] proc_write_data,
output reg [127:0] proc_read_data,
output reg proc_resp_valid,
output reg proc_resp_hit,

// ========== L1 Cache Read Interface ==========
output reg [$clog2(32)-1:0] l1_rd_set_idx,
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
output reg [$clog2(32)-1:0] l1_wr_set_idx,
output reg l1_wr_way,
output reg [6:0] l1_wr_tag,
output reg [127:0] l1_wr_data,
output reg l1_wr_valid,
output reg l1_wr_dirty,
output reg [2:0] l1_wr_msi,
output reg l1_wr_lru,

// ========== Bus Interface ==========
output reg [3:0] bus_req_type,
output reg [15:0] bus_req_addr,
output reg [127:0] bus_req_data,
output reg bus_req_valid,
input wire bus_req_grant,

// ========== Bus Response ==========
input wire [3:0] bus_msg_type,
input wire [15:0] bus_addr,
input wire [127:0] bus_data,
input wire bus_valid,
input wire [1:0] bus_requester_id,

// ========== L2 Interface ==========
input wire [127:0] l2_resp_data,
input wire l2_resp_valid,
input wire l2_hit_valid,

// ========== Memory Write Interface (WRITE-THROUGH) ==========
output reg mem_wr_req_valid,
output reg [15:0] mem_wr_addr,
output reg [127:0] mem_wr_data

);

// ========== State Machine Parameters ==========
parameter STATE_IDLE = 3'd0;
parameter STATE_READ = 3'd1;
parameter STATE_WRITE = 3'd2;
parameter STATE_BUS_REQ = 3'd3;
parameter STATE_WAIT_L2 = 3'd4;
parameter STATE_TRANSIENT = 3'd5;
parameter STATE_WRITE_MEM = 3'd6; 
// ========== Internal Signals ==========
reg [2:0] current_state;
reg [3:0] pending_req_type;
reg [15:0] pending_addr;
reg [127:0] pending_data;
reg [4:0] pending_set_idx;
reg [6:0] pending_tag;
reg hit_valid;
reg hit_way;
reg [2:0] hit_msi_state;
reg [127:0] hit_data;
reg [127:0] hit_data_stable;
reg pending_wr_way;
reg [2:0] target_msi_state;
reg [127:0] transient_l1_wr_data;

// ========== Latency Signals ==========
reg latency_active;
reg [3:0] latency_counter;

reg write_through_pending;
reg [15:0] wt_addr;
reg [127:0] wt_data;

// ========== Main Sequential Logic ==========
always @(posedge clk) begin
if(reset) begin
    current_state <= STATE_IDLE;
    pending_req_type <= `PR_IDLE;
    pending_addr <= 16'b0;
    pending_data <= 128'b0;
    bus_req_valid <= 1'b0;
    l1_wr_en <= 1'b0;
    proc_resp_valid <= 1'b0;
    latency_active <= 1'b0;
    latency_counter <= 4'b0;
    target_msi_state <= `MSI_INVALID;
    transient_l1_wr_data <= 128'b0;
    hit_data_stable <= 128'h0;
    l1_rd_set_idx <= 5'd0;
    mem_wr_req_valid <= 1'b0;
    mem_wr_addr <= 16'b0;
    mem_wr_data <= 128'b0;
    write_through_pending <= 1'b0;  
    wt_addr <= 16'b0;               
    wt_data <= 128'b0;              
end
else begin
    // ========== Default Assignments ==========
    l1_wr_en <= 1'b0;
    bus_req_valid <= 1'b0;
    proc_resp_valid <= 1'b0;
    
    if (write_through_pending) begin
        mem_wr_req_valid <= 1'b1;
        mem_wr_addr <= wt_addr;
        mem_wr_data <= wt_data;
        write_through_pending <= 1'b0;  // Clear after one cycle
    end else begin
        mem_wr_req_valid <= 1'b0;  // Default to 0
    end

    case (current_state)
    STATE_IDLE: begin
        if(proc_req_type != `PR_IDLE) begin
            pending_req_type <= proc_req_type;
            pending_addr <= proc_req_addr;
            pending_data <= proc_write_data;
            pending_set_idx <= proc_req_addr[8:4];
            pending_tag <= proc_req_addr[15:9];
            l1_rd_set_idx <= proc_req_addr[8:4];
            
            if(proc_req_type == `PR_RD)
                current_state <= STATE_READ;
            else if(proc_req_type == `PR_WR)
                current_state <= STATE_WRITE;
        end
    end

    STATE_READ: begin
        l1_rd_set_idx <= pending_set_idx;
        
        if((l1_rd_valid_way0 && (l1_rd_tag_way0 == pending_tag)) ||
           (l1_rd_valid_way1 && (l1_rd_tag_way1 == pending_tag))) begin
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
            
            latency_active <= 1'b1;
            latency_counter <= 4'd2;
            proc_resp_hit <= 1'b1;
            current_state <= STATE_IDLE;
        end
        else begin
            pending_wr_way <= l1_rd_lru_bit;
            bus_req_valid <= 1'b1;
            bus_req_type <= `BUS_RD;
            bus_req_addr <= pending_addr;
            bus_req_data <= 128'b0;
            current_state <= STATE_BUS_REQ;
        end
    end

    STATE_WRITE: begin
        l1_rd_set_idx <= pending_set_idx;
        
        if((l1_rd_valid_way0 && (l1_rd_tag_way0 == pending_tag)) ||
           (l1_rd_valid_way1 && (l1_rd_tag_way1 == pending_tag))) begin
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

            if(hit_msi_state == `MSI_MODIFIED) begin
                l1_wr_en <= 1'b1;
                l1_wr_set_idx <= pending_set_idx;
                l1_wr_way <= hit_way;
                l1_wr_tag <= pending_tag;
                l1_wr_data <= pending_data;
                l1_wr_valid <= 1'b1;
                l1_wr_msi <= `MSI_MODIFIED;
                l1_wr_dirty <= 1'b1;
                l1_wr_lru <= ~l1_rd_lru_bit;
                
                write_through_pending <= 1'b1;
                wt_addr <= pending_addr;
                wt_data <= pending_data;
                
                latency_active <= 1'b1;
                latency_counter <= 4'd2;
                proc_resp_hit <= 1'b1;
                current_state <= STATE_IDLE;
            end
            else if(hit_msi_state == `MSI_SHARED) begin
                pending_wr_way <= hit_way;
                bus_req_valid <= 1'b1;
                bus_req_type <= `BUS_UPGR;
                bus_req_addr <= pending_addr;
                bus_req_data <= 128'b0;
                current_state <= STATE_BUS_REQ;
            end
        end
        else begin
            pending_wr_way <= l1_rd_lru_bit;
            bus_req_valid <= 1'b1;
            bus_req_type <= `BUS_RDX;
            bus_req_addr <= pending_addr;
            bus_req_data <= 128'b0;
            current_state <= STATE_BUS_REQ;
        end
    end

    STATE_BUS_REQ: begin
        l1_rd_set_idx <= pending_set_idx;
        
        if(bus_req_grant) begin
            bus_req_valid <= 1'b0;
            current_state <= STATE_WAIT_L2;
        end
    end

    STATE_WAIT_L2: begin
        l1_rd_set_idx <= pending_set_idx;
        
        if(l2_resp_valid) begin
            l1_wr_en <= 1'b1;
            l1_wr_set_idx <= pending_set_idx;
            l1_wr_way <= pending_wr_way;
            l1_wr_tag <= pending_tag;
            l1_wr_data <= l2_resp_data;
            l1_wr_valid <= 1'b1;
            hit_data_stable <= l2_resp_data;
            transient_l1_wr_data <= l2_resp_data;
            
            if(pending_req_type == `PR_RD) begin
                l1_wr_msi <= `MSI_ISD;
                l1_wr_dirty <= 1'b0;
                target_msi_state <= `MSI_SHARED;
            end
            else begin
                l1_wr_msi <= `MSI_IMD;
                l1_wr_dirty <= 1'b1;
                target_msi_state <= `MSI_MODIFIED;
            end
            
            l1_wr_lru <= ~l1_rd_lru_bit;
            proc_resp_hit <= 1'b0;
            current_state <= STATE_TRANSIENT;
        end
    end

    STATE_TRANSIENT: begin
        l1_rd_set_idx <= pending_set_idx;
        
        l1_wr_en <= 1'b1;
        l1_wr_set_idx <= pending_set_idx;
        l1_wr_way <= pending_wr_way;
        l1_wr_tag <= pending_tag;
        
        if(pending_req_type == `PR_WR) begin
            l1_wr_data <= pending_data;
        end else begin
            l1_wr_data <= transient_l1_wr_data;
        end
        
        l1_wr_valid <= 1'b1;
        l1_wr_msi <= target_msi_state;
        l1_wr_lru <= ~l1_rd_lru_bit;
        
        if(target_msi_state == `MSI_MODIFIED)
            l1_wr_dirty <= 1'b1;
        else
            l1_wr_dirty <= 1'b0;
        
        if(pending_req_type == `PR_WR) begin
            write_through_pending <= 1'b1;
            wt_addr <= pending_addr;
            wt_data <= pending_data;
        end
        
        latency_active <= 1'b1;
        latency_counter <= 4'd4;
        proc_resp_hit <= 1'b0;
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

endmodule