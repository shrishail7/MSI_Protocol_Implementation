`timescale 1ns/1ps
`include "msi_types.vh"

module testcase6_tb();

    // ========== Clock and Reset ==========
    reg clk;
    reg reset;

    // ========== P1 Interface ==========
    reg [3:0] p1_proc_req_type;
    reg [15:0] p1_proc_req_addr;
    reg [127:0] p1_proc_write_data;
    wire [127:0] p1_proc_read_data;
    wire p1_proc_resp_valid;
    wire p1_proc_resp_hit;

    // ========== P2 Interface ==========
    reg [3:0] p2_proc_req_type;
    reg [15:0] p2_proc_req_addr;
    reg [127:0] p2_proc_write_data;
    wire [127:0] p2_proc_read_data;
    wire p2_proc_resp_valid;
    wire p2_proc_resp_hit;

    // ========== Debug Signals ==========
    wire [2:0] p1_l1_state_way0, p1_l1_state_way1;
    wire [2:0] p2_l1_state_way0, p2_l1_state_way1;
    wire [2:0] l2_state_way0, l2_state_way1;
    wire p1_l1_hit, p1_l1_miss;
    wire p2_l1_hit, p2_l1_miss;
    wire l2_hit, l2_miss;
    wire [2:0] p2_current_state_debug;
    wire [2:0] p2_pending_msi_debug;

    // ========== Instantiate Top Module ==========
    msi_cache_hierarchy DUT (
        .clk(clk),
        .reset(reset),

        .p1_proc_req_type(p1_proc_req_type),
        .p1_proc_req_addr(p1_proc_req_addr),
        .p1_proc_write_data(p1_proc_write_data),
        .p1_proc_read_data(p1_proc_read_data),
        .p1_proc_resp_valid(p1_proc_resp_valid),
        .p1_proc_resp_hit(p1_proc_resp_hit),

        .p2_proc_req_type(p2_proc_req_type),
        .p2_proc_req_addr(p2_proc_req_addr),
        .p2_proc_write_data(p2_proc_write_data),
        .p2_proc_read_data(p2_proc_read_data),
        .p2_proc_resp_valid(p2_proc_resp_valid),
        .p2_proc_resp_hit(p2_proc_resp_hit),

        .p1_l1_state_way0(p1_l1_state_way0),
        .p1_l1_state_way1(p1_l1_state_way1),
        .p2_l1_state_way0(p2_l1_state_way0),
        .p2_l1_state_way1(p2_l1_state_way1),
        .l2_state_way0(l2_state_way0),
        .l2_state_way1(l2_state_way1),
        .p1_l1_hit(p1_l1_hit),
        .p1_l1_miss(p1_l1_miss),
        .p2_l1_hit(p2_l1_hit),
        .p2_l1_miss(p2_l1_miss),
        .l2_hit(l2_hit),
        .l2_miss(l2_miss),
        .p2_current_state_debug(p2_current_state_debug),
        .p2_pending_msi_debug(p2_pending_msi_debug)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Timeout counter
    integer cycle_count;
    initial cycle_count = 0;
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 1000) begin
            $display("Timeout at cycle %0d", cycle_count);
            $finish;
        end
    end

    // Main test sequence
    initial begin
        $dumpfile("testcase6.vcd");
        $dumpvars(0, testcase6_tb);

        // Initialize all inputs
        reset = 1;
        p1_proc_req_type = `PR_IDLE;
        p2_proc_req_type = `PR_IDLE;
        p1_proc_req_addr = 0;
        p2_proc_req_addr = 0;
        p1_proc_write_data = 0;
        p2_proc_write_data = 0;

        // Apply reset
        #100;
        reset = 0;
        #20;

        // Phase 1: P1 Write to address 2000
        $display("Cycle %0d: P1 issuing Write to 16'h2000", cycle_count);
        p1_proc_req_type = `PR_WR;
        p1_proc_req_addr = 16'h2000;
        p1_proc_write_data = 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE;
        #10; // Hold request for one cycle
        p1_proc_req_type = `PR_IDLE;

        // Wait for P1 to complete
        wait(p1_proc_resp_valid);
        $display("Cycle %0d: P1 Write complete", cycle_count);
        
        #50; // Wait a bit

        // Phase 2: P2 Read from address 2000
        $display("Cycle %0d: P2 issuing Read from 16'h2000", cycle_count);
        p2_proc_req_type = `PR_RD;
        // p1_l1_state_way0 = `MSI_SHARED;
        p2_proc_req_addr = 16'h2000;
        #10; // Hold request for one cycle
        p2_proc_req_type = `PR_IDLE;

        // Wait for P2 to complete
        wait(p2_proc_resp_valid);
        $display("Cycle %0d: P2 Read complete", cycle_count);

        // Check read data
        if (p2_proc_read_data == 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE) begin
            $display("Test PASSED: P2 read data matches P1 write data.");
        end else begin
            $display("Test FAILED: P2 read data (%h) does not match P1 write data (%h)",
                     p2_proc_read_data, 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE);
        end

        #100; // Wait a final bit before finishing

        $display("Test completed at cycle %0d", cycle_count);
        $finish;
    end

endmodule