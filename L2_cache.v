
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

    // ========== cache storage arrays ==========
    reg [Tag_Bits-1:0]     tag_array  [0:No_Sets-1][0:No_Ways-1];
    reg [Line_Bytes*8-1:0] data_array [0:No_Sets-1][0:No_Ways-1];
    reg                    valid_array [0:No_Sets-1][0:No_Ways-1];
    reg                    dirty_array [0:No_Sets-1][0:No_Ways-1];
    reg                    lru_array [ 0:No_Sets-1];

    // ========== MSI State Array ==========
    reg [1:0] msi_state_array [0:No_Sets-1][0:No_Ways-1];

    // ========== initialisation ==========
    integer i,j;
    initial 
        begin
            for(i=0;i<No_Sets;i=i+1)
            begin
                for(j=0;j<No_Ways;j=j+1)
                begin
                    tag_array[i][j]=0;
                    data_array[i][j]=0;
                    valid_array[i][j]=0;
                    dirty_array[i][j]=0;
                    msi_state_array[i][j]=`MSI_INVALID;
                end 
                lru_array[i]=0;
            end
        end

    // ========== reset logic ==========
    always @(posedge clk ) begin
        if(reset)
            begin
                for(i=0;i<No_Sets;i=i+1)
                begin
                    for(j=0;j<No_Ways;j=j+1)
                    begin
                        tag_array[i][j]<=0;
                        data_array[i][j]<=0;
                        valid_array[i][j]<=0;
                        dirty_array[i][j]<=0;
                        msi_state_array[i][j]<=`MSI_INVALID;
                    end 
                    lru_array[i]<=0;
                end
            end
    end

    // ========== Write Logic  ==========
    always @(posedge clk ) begin
        if(!reset && wr_en)
            begin
                tag_array[wr_set_idx][wr_way] <= wr_tag;
                data_array[wr_set_idx][wr_way] <= wr_data;
                valid_array[wr_set_idx][wr_way] <= wr_valid;
                dirty_array[wr_set_idx][wr_way] <= wr_dirty;
                msi_state_array[wr_set_idx][wr_way] <= wr_msi;
                lru_array[wr_set_idx] <= wr_lru;
            end
    end

    // ========== Read Logic ==========
    //tag
    assign rd_tag_way0 = tag_array[rd_set_idx][0];
    assign rd_tag_way1 = tag_array[rd_set_idx][1];

    //data
    assign rd_data_way0 = data_array[rd_set_idx][0];
    assign rd_data_way1 = data_array[rd_set_idx][1];

    // dirty
    assign rd_dirty_way0 = dirty_array[rd_set_idx][0];
    assign rd_dirty_way1 = dirty_array[rd_set_idx][1];

    //valid
    assign rd_valid_way0 = valid_array[rd_set_idx][0];
    assign rd_valid_way1 = valid_array[rd_set_idx][1];

    //lru
    assign rd_lru_bit = lru_array[rd_set_idx];

    // ========== MSI State ==========
    assign rd_msi_way0 = msi_state_array[rd_set_idx][0];
    assign rd_msi_way1 = msi_state_array[rd_set_idx][1];


endmodule