

`include "msi_types.vh"

module moduleName (
    input wire clk ,
    input wire reset ,


    // ========== Processor Interface ==========
    input wire [3:0] proc_req_type,
    input wire [15:0] proc_req_addr,
    input wire [127:0] proc_write_data,
    output reg [127:0] proc_read_data,
    output reg proc_resp_valid,
    output reg proc_resp_hit,

    // ========== L1 cache interface ( read ) { read req from processor to L1A } ==========
    
    output reg [$clog2(32)-1:0] l1_rd_set_idx,
    
    // tag
    input wire [6:0] l1_rd_tag_way0,
    input wire [6:0] l1_rd_tag_way1,
    
    // data
    input wire [127:0] l1_rd_data_way0,
    input wire [127:0] l1_rd_data_way1 ,
    
    // valid
    input wire l1_rd_valid_way0 ,
    input wire l1_rd_valid_way1 ,
    
    //dirty
    input wire l1_rd_dirty_way0 ,
    input wire l1_rd_dirty_way1 ,
    
    //lru 
    input wire l1_rd_lru_bit
    
    // msi bit
    input wire [1:0] l1_rd_msi_way0,
    input wire [1:0] l1_rd_msi_way1,

    // ========== L1 cache interface ( Write ) { Write req from processor to L1A } ==========

    output reg l1_wr_en ,
    output reg [$clog2(32)-1:0] l1_wr_set_idx ,
    output reg l1_wr_way ,
    output reg [6:0] l1_wr_tag ,
    output reg [127:0] l1_wr_data , 
    output reg l1_wr_valid ,
    output reg l1_wr_dirty,
    output reg [1:0] l1_wr_msi ,
    output reg l1_wr_lru ,

    // ========== Bus Interface ==========
    output reg [3:0] bus_req_type,
    output reg [15:0] bus_req_addr,
    output reg [127:0] bus_req_data ,
    output reg bus_req_valid ,
    input wire bus_req_grant ,
    input wire [3:0] bus_msg_type ,
    input wire [15:0] bus_addr ,
    input wire [127:0] bus_data ,
    input wire bus_valid ,
    input wire [1:0] bus_requester_id ,
    
    // ========== L2 Interface ==========
    input wire [127:0] L2_resp_data ,
    input wire L2_resp_valid ,

    // ========== Latency input ==========
    input wire L2_hit_valid ,
    output reg [2:0] response_source 

);


    reg [2:0] current_state , next_state ;
    reg [3:0] pending_req_type;
    reg [15:0] pending_addr;
    reg [127:0] pending_data ;
    reg [4:0] pending_set_idx ;
    reg [6:0] pending_tag ;
    reg hit_way;
    reg hit_valid;
    reg [1:0] hit_msi_state;

    // ==================== Latency counter register ====================
    reg [2:0] latency_counter ; // Counts down latency cycles
    reg [1:0] latency_state ;   // IDLE, ACTIVE, or COMPLETE
    reg [2:0] latency_type;     // Which latency is applied
    reg latency_responce_pending ; // Flag: response waiting for latency
    reg [127:0] pending_read_data; // Data to return after latency



    parameter STATE_IDLE = 3'd0;
    parameter STATE_PROC_READ = 3'd1;
    parameter  STATE_PROC_WRITE = 3'd2;
    parameter STATE_BUS_WAIT = 3'd3;
    parameter STATE_SNOOP = 3'd4;

    always @(posedge clk ) 
        begin
            if(reset)
                begin
                    current_state <= STATE_IDLE;
                    pending_req_type <= `PR_IDLE;
                    pending_addr <= 16'b0;
                    pending_data <= 128'b0;
                    bus_req_valid <= 1'b0;
                    l1_wr_en <= 1'b0;
                    proc_resp_valid <= 1'b0;

                    // ==================== Reset latency ====================
                    latency_counter <= 3'b0;
                    latency_state <= `LATENCY_IDLE ;
                    latency_responce_pending <= 1'b0;
                    pending_read_data <= 128'b0;
                    response_source <= 3'b0;

                end
            else
                begin
                    current_state <= next_state;
                end
        end


    always @(*) 
        begin
            next_state = current_state ;
            bus_req_valid = 1'b0;
            l1_wr_en = 1'b0;
            proc_resp_valid = 1'b0;
            l1_rd_set_idx = pending_set_idx;
            hit_valid = 1'b0;
            hit_way = 1'b0;


            // check for cache hit
            if(l1_rd_valid_way0 && (l1_rd_tag_way0 == pending_tag))
                begin
                    hit_valid = 1'b1;
                    hit_way = 1'b0 ;
                    hit_msi_state = l1_rd_msi_way0;
                end
            else if(l1_rd_valid_way1 && (l1_rd_tag_way1 == pending_tag))
                begin
                    hit_valid = 1'b1;
                    hit_way = 1'b1;
                    hit_msi_state = l1_rd_msi_way1;
                end


            case (current_state)
                
                STATE_IDLE :
                    begin
                        if(proc_req_type != `PR_IDLE)
                            begin
                                pending_req_type <= proc_req_type;
                                pending_addr <= proc_req_addr;
                                pending_data <= proc_write_data;
                                pending_set_idx <= proc_req_addr[8:4];
                                pending_tag <= proc_req_addr[15:9];

                                if(proc_req_type == `PR_RD)
                                    begin
                                        next_state = STATE_PROC_READ;
                                    end
                                else if(proc_req_type == `PR_WR)
                                    begin
                                        next_state = STATE_PROC_WRITE;
                                    end

                            end     
                    end 

                STATE_PROC_READ :
                        begin
                            l1_rd_set_idx = pending_set_idx;

                            // cache hit and latency expired 
                            if(hit_valid && latency_state == `LATENCY_COMPLETE )
                                begin
                                    proc_resp_valid = 1'b1;
                                    proc_resp_hit = 1'b1;
                                    proc_read_data = pending_read_data;
                                    next_state = STATE_IDLE;
                                end  

                            // cache hit but  latecy not completed , just wait do nothing

                            // cache miss , proceed to get from L2 
                            else if(!hit_valid)
                                begin
                                    if(!bus_req_grant)
                                        begin
                                            bus_req_valid = 1'b1;
                                            bus_req_type = `BUS_RD;
                                            bus_req_addr = pending_addr;
                                            bus_req_data = 128'b0;
                                            next_state = STATE_BUS_WAIT;
                                        end
                                end
                            
                        end
                STATE_PROC_WRITE :
                    begin
                        l1_rd_set_idx = pending_set_idx;
                        
                        // Modified state and hit valid
                        if(hit_valid && hit_msi_state==`MSI_MODIFIED)
                            begin
                                l1_wr_en = 1'b1;
                                l1_wr_set_idx = pending_set_idx;
                                l1_wr_way = hit_way;
                                l1_wr_tag = pending_tag;
                                l1_wr_data = pending_data ; 
                                l1_wr_valid = 1'b1;
                                l1_wr_msi = `MSI_MODIFIED ;
                                l1_wr_dirty = 1'b1;
                                l1_wr_lru = l1_rd_lru_bit;
                                proc_resp_valid = 1'b1;
                                proc_resp_hit = 1'b1;
                                next_state = STATE_IDLE;
                            end 
                        // shared state and hit valid
                        else if(hit_valid && hit_msi_state == `MSI_SHARED)
                            begin
                                if(!bus_req_grant)
                                    begin
                                        bus_req_valid = 1'b1;
                                        bus_req_type = `BUS_UPGR;
                                        bus_req_addr = pending_addr;
                                        bus_req_data = 128'b0;
                                        next_state = STATE_BUS_WAIT;
                                    end
                            end
                        // either invalid state or hit not valid
                        else    
                            begin
                                if(!bus_req_grant)
                                    begin
                                        bus_req_valid = 1'b1;
                                        bus_req_type = `BUS_RDX;
                                        bus_req_addr = pending_addr;
                                        bus_req_data = 128'b0;
                                        next_state = STATE_BUS_WAIT;
                                    end
                            end
                    end

                STATE_BUS_WAIT :
                    begin
                        if(L2_resp_valid)
                            begin
                                l1_wr_en = 1'b1;
                                l1_wr_set_idx = pending_set_idx;
                                l1_wr_way = l1_rd_lru_bit ? 1'b1 : 1'b0;
                                l1_wr_tag = pending_tag;
                                l1_wr_data = L2_resp_data;
                                l1_wr_valid = 1'b1;
                                l1_wr_dirty = 1'b0;

                                if(pending_req_type == `PR_RD)
                                    begin
                                        l1_wr_msi = `MSI_SHARED;
                                        l1_wr_dirty = 1'b0;
                                    end
                                else    
                                    begin
                                        l1_wr_msi = `MSI_MODIFIED;
                                        l1_wr_dirty = 1'b1;
                                    end
                                
                                l1_wr_lru = l1_rd_lru_bit;
                                proc_resp_valid = 1'b0; // do not respond immediately
                                proc_resp_hit = 1'b0;
                                next_state = STATE_IDLE;
                            end 
                    end

                    STATE_SNOOP :
                        begin
                            if(bus_valid && bus_addr[15:9] == pending_addr)
                                begin
                                    if(bus_msg_type == `BUS_INV)
                                        begin
                                            if(hit_valid)
                                                begin
                                                    l1_wr_en = 1'b1;
                                                    l1_wr_set_idx = pending_set_idx;
                                                    l1_wr_way = hit_way ;
                                                    l1_wr_msi = `MSI_INVALID;
                                                    l1_wr_valid = 1'b0;
                                                end 
                                        end
                                    next_state = STATE_IDLE;
                                end
                        end
            endcase
        end 

        // ============ Latency Counter FSM  ============
        

endmodule