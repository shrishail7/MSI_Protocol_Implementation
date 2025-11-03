

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


endmodule