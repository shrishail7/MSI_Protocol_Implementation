
`include "msi_types.vh"

module L2_cache #(

    parameter No_Sets = 256,
    parameter No_Ways = 2,
    parameter Line_Bytes = 16,
    parameter Tag_Bits = 4

)(

    input wire clk,
    input wire reset ,

    // ========== Read Operation ports ==========
    input wire [$clog2(No_Sets)-1:0] rd_set_index,
    input wire rd_en ,

    //tag
    output wire [Tag_Bits-1:0] rd_tag_way0,
    output wire [Tag_Bits-1:0] rd_tag_way1,

    //data
    output wire [Line_Bytes*8-1:0] rd_data_way0,
    output wire [Line_Bytes*8-1:0] rd_data_way1,

    //valid
    output wire rd_valid_way0,
    output wire rd_valid_way1 , 

    // dirty
    output wire rd_dirty_way0,
    output wire rd_dirty_way1,

    // lru
    output wire rd_lru_bit,

    // ========== MSI States ==========
    output wire [1:0] rd_msi_way0,
    output wire [1:0] rd_msi_way1,

    // ========== Write Operation ports ==========
    input wire wr_en,
    input wire [$clog(No_Sets)-1:0] wr_set_idx,
    input wire wr_way,
    input wire [Tag_Bits-1:0] wr_tag,
    input wire [Line_Bytes*8-1:0] wr_data,
    input wire wr_valid,
    input wire wr_dirty ,
    input wire wr_lru , 
    input wire [1:0] wr_msi

);
endmodule