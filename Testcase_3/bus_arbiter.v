/*
BUS ARBITER MODULE - Arbitration and Snooping
*/

`include "msi_types.vh"

module bus_arbiter (
    input wire clk,
    input wire reset,

    input wire [3:0] p1_req_type,
    input wire [15:0] p1_req_addr,
    input wire [127:0] p1_req_data,
    input wire p1_req_valid,
    output reg p1_req_grant,

    input wire [3:0] p2_req_type,
    input wire [15:0] p2_req_addr,
    input wire [127:0] p2_req_data,
    input wire p2_req_valid,
    output reg p2_req_grant,

    output reg [3:0] bus_msg_type,
    output reg [15:0] bus_addr,
    output reg [127:0] bus_data,
    output reg bus_valid,
    output reg [1:0] bus_requester_id,

    input wire [127:0] l2m_resp_data,
    input wire l2m_resp_valid,
    input wire [3:0] l2m_resp_type
);

    reg msg_in_progress;

    always @(posedge clk) begin
        if(reset) begin
            p1_req_grant <= 0;
            p2_req_grant <= 0;
            bus_valid <= 0;
            msg_in_progress <= 0;
            bus_msg_type <= `BUS_IDLE;
            bus_requester_id <= 0;
        end
        else begin
            if(!msg_in_progress || l2m_resp_valid) begin
                msg_in_progress <= 0;
                
                if(p1_req_valid) begin
                    p1_req_grant <= 1;
                    p2_req_grant <= 0;
                    bus_msg_type <= p1_req_type;
                    bus_addr <= p1_req_addr;
                    bus_data <= p1_req_data;
                    bus_requester_id <= 2'b01;
                    bus_valid <= 1;
                    msg_in_progress <= 1;
                end
                else if(p2_req_valid) begin
                    p1_req_grant <= 0;
                    p2_req_grant <= 1;
                    bus_msg_type <= p2_req_type;
                    bus_addr <= p2_req_addr;
                    bus_data <= p2_req_data;
                    bus_requester_id <= 2'b10;
                    bus_valid <= 1;
                    msg_in_progress <= 1;
                end
                else begin
                    p1_req_grant <= 0;
                    p2_req_grant <= 0;
                    bus_valid <= 0;
                    bus_msg_type <= `BUS_IDLE;
                end
            end
            else if(l2m_resp_valid && !p1_req_valid && !p2_req_valid) begin
                bus_valid <= 1;
                bus_msg_type <= l2m_resp_type;
                bus_data <= l2m_resp_data;
                bus_requester_id <= 2'b11;
            end
        end
    end

endmodule
