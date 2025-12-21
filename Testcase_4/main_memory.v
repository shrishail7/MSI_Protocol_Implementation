

`include "msi_types.vh"

module main_memory #(
    parameter Addr_Width = 16,
    parameter Line_Bytes = 16
) (
    input wire clk,
    input wire reset,

    input wire mem_read,
    input wire mem_write,
    input wire [Addr_Width-1:0] mem_addr,
    input wire [Line_Bytes*8-1:0] mem_wdata,
    output reg [Line_Bytes*8-1:0] mem_rdata,
    output reg mem_ready
);

    // Memory Parameters
    localparam Memory_Size = 2**(Addr_Width);
    localparam Block_Size = Line_Bytes;
    localparam Num_Blocks = Memory_Size / Block_Size;

    // Memory Storage
    reg [Line_Bytes*8-1:0] memory_array [0:Num_Blocks-1];

    // State Machine Signals
    reg [2:0] latency_counter;
    reg access_in_progress;
    reg access_is_write;
    reg [Addr_Width-1:0] access_addr;
    reg [Line_Bytes*8-1:0] access_wdata;

    // Initialization with DISTINCTIVE TEST DATA
    integer i;
    initial begin
        for(i=0; i<Num_Blocks; i=i+1)
            memory_array[i] = 128'b0;
        
  
        memory_array[16'h1010 >> 4] = 128'h55555555666666667777777788888888;
        memory_array[16'h1020 >> 4] = 128'h123456789ABCDEF0123456789ABCDEF0;
        memory_array[16'h1040 >> 4] = 128'hAAAABBBBCCCCDDDDEEEEFFFF11112222;
        memory_array[16'h1060 >> 4] = 128'h11111111222222223333333344444444;
        memory_array[16'h1080 >> 4] = 128'h99999999AAAAAAAABBBBBBBBCCCCCCCC;
        memory_array[16'h2000 >> 4] = 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE;



        latency_counter = 3'b0;
        access_in_progress = 1'b0;
        mem_ready = 1'b1;
        mem_rdata = 128'b0;
    end

    // Memory Read and Write Logic
    always @(posedge clk) begin
        if(reset) begin
            latency_counter <= 3'b0;
            access_in_progress <= 1'b0;
            mem_ready <= 1'b1;
            mem_rdata <= 128'b0;
        end
        else begin
            // No access in progress, new request arrives
            if(!access_in_progress && (mem_read || mem_write)) begin
                access_in_progress <= 1'b1;
                access_is_write <= mem_write;
                access_addr <= mem_addr;
                access_wdata <= mem_wdata;
                latency_counter <= 3'd6;  // 7-cycle latency (6 down to 0)
                mem_ready <= 1'b0;
            end
            // Access in progress - counting down latency
            else if(access_in_progress) begin
                if(latency_counter > 3'd1) begin
                    latency_counter <= latency_counter - 3'd1;
                end
                else begin
                    // Latency expired - perform operation
                    if(access_is_write) begin
                        // Write operation
                        memory_array[access_addr >> 4] <= access_wdata;
                    end
                    else begin
                        // Read operation - return data from memory
                        mem_rdata <= memory_array[access_addr >> 4];
                    end
                    
                    // Clear access state
                    access_in_progress <= 1'b0;
                    latency_counter <= 3'b0;
                    mem_ready <= 1'b1;
                end
            end
            // No access in progress and no new request
            else begin
                mem_ready <= 1'b1;
            end
        end
    end

endmodule