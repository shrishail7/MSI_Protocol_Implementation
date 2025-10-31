
`include "msi_types.vh"

module bus_arbiter (
    input wire clk,
    input wire reset,

    // ========== Request from L1 controller ==========
    input wire [3:0] p1_req_type,
    input wire [15:0] p1_req_addr,
    input wire [127:0] p1_req_data,
    input wire p1_req_valid,
    output wire p1_req_grant,

    input wire [3:0] p2_req_type,
    input wire [15:0] p2_req_addr ,
    input wire [127:0] p2_req_data,
    input wire  p2_req_valid ,
    output reg p2_req_grant

    // ========== Request from L1 controller ==========
    output reg [3:0] bus_msg_type,
    output reg [15:0] bus_addr ,
    output reg [127:0] bus_data,
    output reg bus_valid,
    output reg [1:0] bus_requester_id,

    // ========== Memory / L2 responce ==========
    input wire [127:0] mem_data,
    input wire mem_ready

);
    

    reg msg_in_progress;

    always @(posedge clk) 
    begin
        if(reset)
            begin
                p1_req_grant<=0;
                p2_req_grant <=0;
                bus_valid <=0;
                msg_in_progress <=0;
            end
        else
            begin
                if(!msg_in_progress || (mem_ready && msg_in_progress))
                begin
                    msg_in_progress<=0;
                    if(p1_req_valid)
                    begin
                        p1_req_grant <=1;
                        p2_req_grant <=0;
                        bus_msg_type <= p1_req_type;
                        bus_addr <= p1_req_addr;
                        bus_data <= p1_req_data;
                        bus_requester_id <= 2'b01;
                        bus_valid<=1;
                        msg_in_progress<=1;
                    end
                    else if(p2_req_valid)
                    begin
                        p1_req_grant<=0;
                        p2_req_grant<=1;
                        bus_msg_type<= p2_req_type;
                        bus_addr<= p2_req_addr;
                        bus_data <= p2_req_data;
                        bus_requester_id <= 2'b10;
                        bus_valid <= 1;
                        msg_in_progress <= 1;
                    end
                    else
                    begin
                        p1_req_grant <=0;
                        p2_req_grant<=0;
                        bus_valid<=0;
                        bus_msg_type<= `BUS_IDLE;
                    end
                end
            end
    end



endmodule