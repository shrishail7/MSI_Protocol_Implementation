

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

    // ===== MEMORY PARAMETERS =====
    localparam Memory_Size = 2**(Addr_Width) ;
    localparam Block_Size = Line_Bytes;
    localparam Num_Blocks = Memory_Size / Block_Size;

    // ===== MEMORY STORAGE =====
    reg [Line_Bytes*8-1:0] memory_array [0:Num_Blocks-1];
  
    // ===== STATE MACHINE SIGNALS =====
    reg [2:0] latency_counter;
    reg access_in_progress;
    reg access_is_write;
    reg [Addr_Width-1:0] access_addr;
    reg [Line_Bytes*8-1:0 ] access_wdata;

    // ========== Initialisation ==========
    integer i ;
    initial
        begin
            for(i=0;i<Num_Blocks;i=i+1)
                memory_array[i]=125'b0;
            latency_counter = 3'b0;
            access_in_progress=1'b0;
            mem_ready=1'b1;
            mem_rdata = 128'b0;
        end

    // ========== memory read and write logic ==========

    always @(posedge clk ) begin
        // Reset 
        if(reset)
            begin
                for(i=0;i<Num_Blocks;i=i+1)
                    memory_array[i]<=128'b0;
                latency_counter <= 3'b0;
                access_in_progress <= 1'b0;
                mem_ready <=1'b1;
                mem_rdata <=128'b0;
            end
        else    
            begin
            // Case 1: No access in progress, new request arrives

                if(!access_in_progress && (mem_read || mem_write))
                begin
                    access_in_progress<=1'b1;
                    access_is_write<=mem_write;
                    access_addr<=mem_addr;
                    access_wdata<=mem_wdata;
                    latency_counter<=3'd6;
                    mem_ready<=1'b0;
                end
            // Case 2: Access in progress, counting down latency
                else if(access_in_progress)
                begin
                    // still waiting for latency to expired
                    if(latency_counter>3'd1)
                        begin
                            latency_counter<=latency_counter-3'd1;
                        end
                    else
                    // Latency is expired
                        begin
                        // write operation
                            if(access_is_write)
                                begin
                                    memory_array[access_addr>>4] <= access_wdata;
                                end 
                            else
                        // read operation
                                begin
                                    mem_rdata <= memory_array[access_addr>>4];
                                end
                        // clear access state
                            access_in_progress <= 1'b0;
                            latency_counter <=3'b0;
                        // Signal transaction complete
                            mem_ready <= 1'b1; 
                        end
                end
                else 
            // Case 3: No access in progress and no new request
                    begin
                        mem_ready <= 1'b1;
                    end
            end
    end


endmodule