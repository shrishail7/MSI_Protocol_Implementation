`include "msi_types.vh"

module L2_memory_controller (
    input wire clk,
    input wire reset,

    // Bus Interface (from L1 controllers)
    input wire [3:0] bus_msg_type,
    input wire [15:0] bus_req_addr,
    input wire [127:0] bus_req_data,
    input wire bus_req_valid,
    output reg bus_req_ack,

    // Response on Bus
    output reg [127:0] bus_resp_data,
    output reg bus_resp_valid,
    output reg [3:0] bus_resp_type,

    // L2 Cache Interface (Read)
    output reg [7:0] l2_rd_set_idx,
    output reg l2_rd_en,
    input wire [3:0] l2_rd_tag_way0,
    input wire [3:0] l2_rd_tag_way1,
    input wire [127:0] l2_rd_data_way0,
    input wire [127:0] l2_rd_data_way1,
    input wire l2_rd_valid_way0,
    input wire l2_rd_valid_way1,
    input wire l2_rd_dirty_way0,
    input wire l2_rd_dirty_way1,
    input wire l2_rd_lru_bit,
    input wire [2:0] l2_rd_msi_way0,
    input wire [2:0] l2_rd_msi_way1,

    // L2 Cache Interface (Write)
    output reg l2_wr_en,
    output reg [7:0] l2_wr_set_idx,
    output reg l2_wr_way,
    output reg [3:0] l2_wr_tag,
    output reg [127:0] l2_wr_data,
    output reg l2_wr_valid,
    output reg l2_wr_dirty,
    output reg [2:0] l2_wr_msi,
    output reg l2_wr_lru,

    // Main Memory Interface
    output reg mem_req_valid,
    output reg mem_req_read,      
    output reg mem_req_write,     
    output reg [15:0] mem_req_addr,
    output reg [127:0] mem_req_data,
    input wire mem_ready,
    input wire [127:0] mem_resp_data,
    
    input wire p1_mem_wr_req_valid,
    input wire [15:0] p1_mem_wr_addr,
    input wire [127:0] p1_mem_wr_data

);

    // ========== State Machine Parameters ==========
    parameter STATE_IDLE = 3'd0;
    parameter STATE_L2_LOOKUP = 3'd1;
    parameter STATE_L2_HIT = 3'd2;
    parameter STATE_L2_MISS = 3'd3;
    parameter STATE_MEM_READ = 3'd4;
    parameter STATE_MEM_WAIT = 3'd5;
    parameter STATE_MEM_WRITE = 3'd6; 
    parameter STATE_RESP = 3'd7;

    reg [2:0] current_state, next_state;
    reg [3:0] pending_msg_type;
    reg [15:0] pending_addr;
    reg [127:0] pending_data;
    reg [7:0] pending_l2_set;
    reg [3:0] pending_l2_tag;
    reg hit_way;
    reg [127:0] hit_data;

    reg wt_pending;
    reg [15:0] wt_addr;
    reg [127:0] wt_data;

    // ========== Sequential Logic ==========
    always @(posedge clk) begin
        if(reset) begin
            current_state <= STATE_IDLE;
            pending_msg_type <= 4'b0;
            pending_addr <= 16'b0;
            pending_data <= 128'b0;
            bus_req_ack <= 1'b0;
            bus_resp_valid <= 1'b0;
            l2_rd_en <= 1'b0;
            l2_wr_en <= 1'b0;
            mem_req_valid <= 1'b0;
            mem_req_read <= 1'b0;
            mem_req_write <= 1'b0;  
            wt_pending <= 1'b0;     
            wt_addr <= 16'b0;       
            wt_data <= 128'b0;      
        end
        else begin
            // ========== Default Assignments ==========
            bus_req_ack <= 1'b0;
            bus_resp_valid <= 1'b0;
            l2_rd_en <= 1'b0;
            l2_wr_en <= 1'b0;
            mem_req_valid <= 1'b0;
            mem_req_read <= 1'b0;
            mem_req_write <= 1'b0;  

            if(p1_mem_wr_req_valid && !wt_pending) begin
                wt_pending <= 1'b1;
                wt_addr <= p1_mem_wr_addr;
                wt_data <= p1_mem_wr_data;
                current_state <= STATE_MEM_WRITE;
            end
            else if(wt_pending) begin
                // Process pending write-through
                case(current_state)
                    STATE_MEM_WRITE: begin
                        mem_req_valid <= 1'b1;
                        mem_req_write <= 1'b1;      
                        mem_req_read <= 1'b0;
                        mem_req_addr <= wt_addr;
                        mem_req_data <= wt_data;
                        
                        if(mem_ready) begin
                            wt_pending <= 1'b0;
                            current_state <= STATE_IDLE;
                            $display("[L2_MEM_CTRL] Write-through completed: Addr=0x%h, Data=0x%032x", wt_addr, wt_data);
                        end
                    end
                    
                    default: begin
                        current_state <= STATE_MEM_WRITE;
                    end
                endcase
            end
            else begin
                // Handle bus requests normally
                case(current_state)

                STATE_IDLE: begin
                    if(bus_req_valid) begin
                        pending_msg_type <= bus_msg_type;
                        pending_addr <= bus_req_addr;
                        pending_data <= bus_req_data;
                        pending_l2_set <= bus_req_addr[11:4];
                        pending_l2_tag <= bus_req_addr[15:12];
                        bus_req_ack <= 1'b1;
                        current_state <= STATE_L2_LOOKUP;
                    end
                end

                STATE_L2_LOOKUP: begin
                    l2_rd_en <= 1'b1;
                    l2_rd_set_idx <= pending_l2_set;
                    current_state <= STATE_L2_HIT;
                end

                STATE_L2_HIT: begin
                    // Check if hit in L2
                    if((l2_rd_valid_way0 && (l2_rd_tag_way0 == pending_l2_tag)) ||
                       (l2_rd_valid_way1 && (l2_rd_tag_way1 == pending_l2_tag))) begin
                        
                        // L2 HIT
                        if(l2_rd_valid_way0 && (l2_rd_tag_way0 == pending_l2_tag)) begin
                            hit_way <= 1'b0;
                            hit_data <= l2_rd_data_way0;
                        end
                        else begin
                            hit_way <= 1'b1;
                            hit_data <= l2_rd_data_way1;
                        end
                        
                        // Update L2 state based on message type
                        l2_wr_en <= 1'b1;
                        l2_wr_set_idx <= pending_l2_set;
                        l2_wr_way <= hit_way;
                        l2_wr_tag <= pending_l2_tag;
                        
                        if(pending_msg_type == `BUS_RD) begin
                            l2_wr_msi <= `MSI_SHARED;
                            l2_wr_dirty <= 1'b0;
                        end
                        else if(pending_msg_type == `BUS_RDX) begin
                            l2_wr_msi <= `MSI_MODIFIED;
                            l2_wr_dirty <= 1'b1;
                        end
                        
                        l2_wr_data <= hit_data;
                        l2_wr_valid <= 1'b1;
                        l2_wr_lru <= ~l2_rd_lru_bit;
                        
                        // Send response on bus
                        bus_resp_valid <= 1'b1;
                        bus_resp_type <= `BUS_DATA;
                        bus_resp_data <= hit_data;
                        
                        current_state <= STATE_IDLE;
                    end
                    else begin
                        // L2 MISS - need to read from main memory
                        current_state <= STATE_L2_MISS;
                    end
                end

                STATE_L2_MISS: begin
                    // Request data from main memory
                    mem_req_valid <= 1'b1;
                    mem_req_read <= 1'b1;
                    mem_req_write <= 1'b0;  
                    mem_req_addr <= pending_addr;
                    mem_req_data <= 128'b0;
                    current_state <= STATE_MEM_READ;
                end

                STATE_MEM_READ: begin
                    mem_req_valid <= 1'b1;
                    mem_req_read <= 1'b1;
                    mem_req_write <= 1'b0;  
                    mem_req_addr <= pending_addr;
                    current_state <= STATE_MEM_WAIT;
                end

                STATE_MEM_WAIT: begin
                    if(mem_ready) begin
                        // Data received from memory
                        hit_data <= mem_resp_data;
                        
                        // Write to L2 cache
                        l2_wr_en <= 1'b1;
                        l2_wr_set_idx <= pending_l2_set;
                        l2_wr_way <= l2_rd_lru_bit;
                        l2_wr_tag <= pending_l2_tag;
                        l2_wr_data <= mem_resp_data;
                        l2_wr_valid <= 1'b1;
                        l2_wr_lru <= ~l2_rd_lru_bit;
                        
                        if(pending_msg_type == `BUS_RD) begin
                            l2_wr_msi <= `MSI_SHARED;
                            l2_wr_dirty <= 1'b0;
                        end
                        else if(pending_msg_type == `BUS_RDX) begin
                            l2_wr_msi <= `MSI_MODIFIED;
                            l2_wr_dirty <= 1'b1;
                        end
                        
                        // Send response on bus
                        bus_resp_valid <= 1'b1;
                        bus_resp_type <= `BUS_DATA;
                        bus_resp_data <= mem_resp_data;
                        
                        current_state <= STATE_IDLE;
                    end
                    else begin
                        mem_req_valid <= 1'b1;
                        mem_req_read <= 1'b1;
                        mem_req_write <= 1'b0;  
                    end
                end

                endcase
            end
        end
    end

endmodule