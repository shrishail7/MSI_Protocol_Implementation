

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
    
endmodule