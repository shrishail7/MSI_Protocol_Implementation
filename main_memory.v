

`include "msi_types.vh"

module moduleName #(
    parameter Addr_Width = 16,
    parameter Line_Bytes = 16
 ) (
    input wire clk,
    input wire reset,

    input wire mem_read ,
    input wire mem_write ,
    input wire [Addr_Width-1:0] mem_addr ,
    input wire [Line_Bytes*8-1:0] mem_wdata,
    output reg [Line_Bytes*8-1:0] mem_rdata,
    output reg mem_ready
);
    
endmodule