`timescale 1ns/1ps
`include "msi_types.vh"

module testcase5_tb();

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

    // ========== Clock Generation ==========
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 10ns clock period
    end

    // ========== Task: Wait for Response ==========
    task wait_for_response(input integer max_cycles);
        integer cycle_count;
        begin
            cycle_count = 0;
            while (!p1_proc_resp_valid && cycle_count < max_cycles) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
            if (cycle_count >= max_cycles) begin
                $display("[ERROR] P1 Response timeout after %0d cycles", max_cycles);
            end
        end
    endtask

    task wait_for_p2_response(input integer max_cycles);
        integer cycle_count;
        begin
            cycle_count = 0;
            while (!p2_proc_resp_valid && cycle_count < max_cycles) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
            if (cycle_count >= max_cycles) begin
                $display("[ERROR] P2 Response timeout after %0d cycles", max_cycles);
            end
        end
    endtask

    // ========== Task: Print Cache State ==========
    task print_cache_state(input string label);
        begin
            $display("\n%s", label);
            $display("  P1 L1 Way0 State: %s (0x%b)", msi_state_name(p1_l1_state_way0), p1_l1_state_way0);
            $display("  P1 L1 Way1 State: %s (0x%b)", msi_state_name(p1_l1_state_way1), p1_l1_state_way1);
            $display("  P2 L1 Way0 State: %s (0x%b)", msi_state_name(p2_l1_state_way0), p2_l1_state_way0);
            $display("  P2 L1 Way1 State: %s (0x%b)", msi_state_name(p2_l1_state_way1), p2_l1_state_way1);
            $display("  L2 Way0 State: %s (0x%b)", msi_state_name(l2_state_way0), l2_state_way0);
            $display("  L2 Way1 State: %s (0x%b)", msi_state_name(l2_state_way1), l2_state_way1);
        end
    endtask

    // ========== Function: MSI State Name ==========
    function string msi_state_name(input [2:0] state);
        case(state)
            `MSI_INVALID: msi_state_name = "Invalid(I)";
            `MSI_SHARED:  msi_state_name = "Shared(S)";
            `MSI_MODIFIED: msi_state_name = "Modified(M)";
            `MSI_ISD:     msi_state_name = "ISD(I->S)";
            `MSI_IMD:     msi_state_name = "IMD(I->M)";
            `MSI_SMD:     msi_state_name = "SMD(S->M)";
            default:      msi_state_name = "UNKNOWN";
        endcase
    endfunction

    // ========== Main Test ==========
    initial begin
        // ========== VCD Dump for Waveform Analysis ==========
        $dumpfile("testcase5.vcd");
        $dumpvars(0, testcase5_tb);

        $display("\n======================================================");
        $display("  TESTCASE 5: M -> I Transition");
        $display("  P1 Write 1080 (M) -> P2 Write 1080 (P1 invalidated)");
        $display("======================================================\n");

        // ========== Reset Phase ==========
        reset = 1'b1;
        p1_proc_req_type = `PR_IDLE;
        p2_proc_req_type = `PR_IDLE;
        p1_proc_write_data = 128'h0;
        p2_proc_write_data = 128'h0;
        @(posedge clk);
        @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        print_cache_state("[INIT] After Reset");

        // ========== Phase 1: P1 Write to address 1080 (L1 Miss -> L2 Miss -> Memory) ==========
        $display("\n[PHASE 1] P1 Write 1080 (GetM Request)");
        $display("  Timestamp: %0t ns", $time);
        p1_proc_req_type = `PR_WR;
        p1_proc_req_addr = 16'h1080; 
        p1_proc_write_data = 128'hAAAA_BBBB_CCCC_DDDD;
        @(posedge clk);
        p1_proc_req_type = `PR_IDLE;
        
        wait_for_response(100);
        @(posedge clk);
        print_cache_state("[P1-DONE] After P1 Write 1080");
        
        $display("\n  Expected: P1 L1 Way contains Addr 1080 in MODIFIED state");
        $display("  P1 L1 Cache State:");
        if (p1_l1_state_way0 == `MSI_MODIFIED) begin
            $display("    ✓ Way0 is MODIFIED");
        end else if (p1_l1_state_way1 == `MSI_MODIFIED) begin
            $display("    ✓ Way1 is MODIFIED");
        end else begin
            $display("    ✗ ERROR: Neither way is MODIFIED!");
        end

        // ========== Stable period for observation ==========
        repeat(5) @(posedge clk);

        // ========== Phase 2: P2 Write to address 1080 (Bus Snoop invalidates P1) ==========
        $display("\n[PHASE 2] P2 Write 1080 (GetM Request - should invalidate P1)");
        $display("  Timestamp: %0t ns", $time);
        p2_proc_req_type = `PR_WR;
        p2_proc_req_addr = 16'h1080;  // Same address 1080
        p2_proc_write_data = 128'hZZZZ_YYYY_XXXX_WWWW;
        @(posedge clk);
        p2_proc_req_type = `PR_IDLE;

        wait_for_p2_response(100);
        @(posedge clk);
        print_cache_state("[P2-DONE] After P2 Write 1080");

        $display("\n  Expected: P1 L1 invalidated (I), P2 L1 modified (M)");
        $display("  P1 L1 Cache State:");
        if (p1_l1_state_way0 == `MSI_INVALID) begin
            $display("    ✓ Way0 is INVALID");
        end else if (p1_l1_state_way1 == `MSI_INVALID) begin
            $display("    ✓ Way1 is INVALID");
        end else begin
            $display("    ✗ ERROR: Expected INVALID state");
        end
        
        $display("  P2 L1 Cache State:");
        if (p2_l1_state_way0 == `MSI_MODIFIED) begin
            $display("    ✓ Way0 is MODIFIED");
        end else if (p2_l1_state_way1 == `MSI_MODIFIED) begin
            $display("    ✓ Way1 is MODIFIED");
        end else begin
            $display("    ✗ ERROR: Expected MODIFIED state");
        end

        // ========== Stable period for verification ==========
        repeat(10) @(posedge clk);

        // ========== Final Summary ==========
        $display("\n======================================================");
        print_cache_state("[FINAL] Test Complete");
        $display("======================================================\n");

        // ========== Verification Logic ==========
        $display("\n[VERIFICATION SUMMARY]");
        if ((p1_l1_state_way0 == `MSI_INVALID || p1_l1_state_way1 == `MSI_INVALID) &&
            (p2_l1_state_way0 == `MSI_MODIFIED || p2_l1_state_way1 == `MSI_MODIFIED)) begin
            $display("  ✓✓✓ TESTCASE 5 PASSED: M->I transition successful");
            $display("      P1 cache line invalidated when P2 issued GetM");
            $display("      P2 now owns the cache line in MODIFIED state");
        end else begin
            $display("  ✗✗✗ TESTCASE 5 FAILED");
            $display("      P1 State: %s (expected I)", msi_state_name(
                (p1_l1_state_way0 == `MSI_INVALID || p1_l1_state_way1 == `MSI_INVALID) ? 
                `MSI_INVALID : p1_l1_state_way0));
            $display("      P2 State: %s (expected M)", msi_state_name(
                (p2_l1_state_way0 == `MSI_MODIFIED || p2_l1_state_way1 == `MSI_MODIFIED) ? 
                `MSI_MODIFIED : p2_l1_state_way0));
        end

        #100;
        $finish;
    end

    // ========== Waveform Monitoring (Optional) ==========
    always @(posedge clk) begin
        if (!reset && (p1_proc_resp_valid || p2_proc_resp_valid)) begin
            $display("[RESP] @ %0t ns: P1_RESP=%b, P2_RESP=%b", 
                     $time, p1_proc_resp_valid, p2_proc_resp_valid);
        end
    end

endmodule
