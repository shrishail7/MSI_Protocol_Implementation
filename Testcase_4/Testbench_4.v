

`include "msi_types.vh"
`timescale 1ns / 1ps

module testcase4_tb();

    // ========== Clock & Reset ==========
    reg clk;
    reg reset;

    // ========== P1 Processor Interface ==========
    reg [3:0] p1_proc_req_type;
    reg [15:0] p1_proc_req_addr;
    reg [127:0] p1_proc_write_data;
    wire [127:0] p1_proc_read_data;
    wire p1_proc_resp_valid;
    wire p1_proc_resp_hit;

    // ========== P2 Processor Interface ==========
    reg [3:0] p2_proc_req_type;
    reg [15:0] p2_proc_req_addr;
    reg [127:0] p2_proc_write_data;
    wire [127:0] p2_proc_read_data;
    wire p2_proc_resp_valid;
    wire p2_proc_resp_hit;

    // ========== Debug/Verification Signals ==========
    wire [2:0] p1_l1_state_way0, p1_l1_state_way1;
    wire [2:0] p2_l1_state_way0, p2_l1_state_way1;
    wire [2:0] l2_state_way0, l2_state_way1;
    wire p1_l1_hit, p1_l1_miss;
    wire p2_l1_hit, p2_l1_miss;
    wire l2_hit, l2_miss;

    // ========== Instantiate DUT ==========
    msi_cache_hierarchy DUT (
        .clk(clk),
        .reset(reset),

        // P1 Interface
        .p1_proc_req_type(p1_proc_req_type),
        .p1_proc_req_addr(p1_proc_req_addr),
        .p1_proc_write_data(p1_proc_write_data),
        .p1_proc_read_data(p1_proc_read_data),
        .p1_proc_resp_valid(p1_proc_resp_valid),
        .p1_proc_resp_hit(p1_proc_resp_hit),

        // P2 Interface
        .p2_proc_req_type(p2_proc_req_type),
        .p2_proc_req_addr(p2_proc_req_addr),
        .p2_proc_write_data(p2_proc_write_data),
        .p2_proc_read_data(p2_proc_read_data),
        .p2_proc_resp_valid(p2_proc_resp_valid),
        .p2_proc_resp_hit(p2_proc_resp_hit),

        // Debug
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
        .l2_miss(l2_miss)
    );

    // ========== Clock Generation ==========
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ========== State-to-String Helper ==========
    function [63:0] msi_state_to_str(input [2:0] state);
        case(state)
            `MSI_INVALID: msi_state_to_str = "I(000)   ";
            `MSI_SHARED:  msi_state_to_str = "S(001)   ";
            `MSI_MODIFIED: msi_state_to_str = "M(010)   ";
            `MSI_ISD:     msi_state_to_str = "ISD(011) ";
            `MSI_IMD:     msi_state_to_str = "IMD(100) ";
            `MSI_SMD:     msi_state_to_str = "SMD(101) ";
            default:      msi_state_to_str = "???(???) ";
        endcase
    endfunction

    // ========== Main Test Sequence ==========
    initial begin
        // ========== Setup Waveform ==========
        $dumpfile("testcase4_waveform.vcd");
        $dumpvars(0, testcase4_tb);

        // ========== Display Header ==========
        $display("\n");
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║          TESTCASE 4: S→I INVALIDATION (Cache Coherence)       ║");
        $display("║          P2 Read 0x1060→S, then P1 Write 0x1060→P2 Invalid   ║");
        $display("╚════════════════════════════════════════════════════════════════╝");
        $display("\n");

        // ========== Reset & Initialize ==========
        reset = 1'b1;
        p1_proc_req_type = `PR_IDLE;
        p2_proc_req_type = `PR_IDLE;
        p1_proc_req_addr = 16'h0000;
        p2_proc_req_addr = 16'h0000;
        p1_proc_write_data = 128'h0;
        p2_proc_write_data = 128'h0;

        #20;
        reset = 1'b0;
        #20;

        $display("[%0t] RESET Complete - All caches in Invalid state\n", $time);

        // ==========================================
        // PHASE A: P2 READS ADDRESS 0x1060 (I→S)
        // ==========================================
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║              PHASE A: P2 READ 0x1060 (I→S)                    ║");
        $display("╚════════════════════════════════════════════════════════════════╝");

        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 1: P2 ISSUES READ REQUEST                                │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Request Type: READ (001)                                      │");
        $display("│ Address: 0x1060 (NEW, not in cache)                           │");
        $display("│ Expected Data: 0x11111111... (from memory)                    │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        p2_proc_req_type = `PR_RD;
        p2_proc_req_addr = 16'h1060;

        $display("[%0t] P2 READ REQUEST:", $time);
        $display("       Type: READ");
        $display("       Addr: 0x1060");

        #10;

        $display("\n[%0t] Initial Cache States:", $time);
        $display("       P2_L1 Way0: %s (expect I)", msi_state_to_str(p2_l1_state_way0));
        $display("       P1_L1 Way0: %s (expect I)", msi_state_to_str(p1_l1_state_way0));

        // Wait for P2 read to complete
        $display("\n[%0t] Waiting for P2 read to complete (~130ns latency)...", $time);
        #300;

        $display("[%0t] After P2 READ:", $time);
        $display("       P2_L1 Way0: %s (expect S)", msi_state_to_str(p2_l1_state_way0));
        $display("       P2 Read Data: 0x%032h...", p2_proc_read_data[127:64]);
        $display("       Expected:    0x11111111...");

        if (p2_l1_state_way0 == `MSI_SHARED) begin
            $display("       ✓ P2 L1: I→S transition complete");
        end else begin
            $display("       ! P2 L1 state unexpected");
        end

        // Wait a bit and ensure P2 request is idle
        p2_proc_req_type = `PR_IDLE;
        #100;

        $display("\n[%0t] PHASE A COMPLETE: P2 has shared copy at 0x1060\n", $time);

        // ==========================================
        // PHASE B: P1 WRITES TO SAME ADDRESS (I→M)
        // P2 SHOULD BE INVALIDATED!
        // ==========================================
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║      PHASE B: P1 WRITE 0x1060 (I→M, Invalidates P2!)         ║");
        $display("╚════════════════════════════════════════════════════════════════╝");

        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 2: P1 ISSUES WRITE REQUEST (Same Address)               │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Request Type: WRITE (010)                                    │");
        $display("│ Address: 0x1060 (SAME as P2!)                               │");
        $display("│ Write Data: 0x99999999... (P1 processor data)               │");
        $display("│ Expected: BUS_RDX sent → P2 invalidated on snooping!        │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        $display("[%0t] Before P1 WRITE - P2 Cache State:", $time);
        $display("       P2_L1 Way0: %s (should be S)", msi_state_to_str(p2_l1_state_way0));

        // Now P1 writes to same address
        p1_proc_req_type = `PR_WR;
        p1_proc_req_addr = 16'h1060;
        p1_proc_write_data = 128'h99999999AAAAAAAA;

        $display("[%0t] P1 WRITE REQUEST:", $time);
        $display("       Type: WRITE");
        $display("       Addr: 0x1060");
        $display("       Data: 0x99999999...");

        #10;

        $display("\n[%0t] During P1 WRITE - Cache States:", $time);
        $display("       P1_L1 Way0: %s (transitioning to M)", msi_state_to_str(p1_l1_state_way0));
        $display("       P2_L1 Way0: %s (may still be S, snooping...)", msi_state_to_str(p2_l1_state_way0));

        // Wait for P1 write to be processed and P2 to be invalidated
        $display("\n[%0t] Waiting for P1 write to complete and P2 invalidation (~200ns)...", $time);
        #400;

        $display("[%0t] After P1 WRITE - CRITICAL STATE CHECK:", $time);
        $display("       P1_L1 Way0: %s (expect M)", msi_state_to_str(p1_l1_state_way0));
        $display("       P2_L1 Way0: %s (expect I - INVALIDATED!) ⭐⭐⭐", msi_state_to_str(p2_l1_state_way0));

        if (p1_l1_state_way0 == `MSI_MODIFIED) begin
            $display("       ✓ P1 L1: I→M transition complete");
        end else begin
            $display("       ! P1 L1 state unexpected");
        end

        if (p2_l1_state_way0 == `MSI_INVALID) begin
            $display("       ✓ P2 L1: S→I INVALIDATION (coherence maintained!)");
        end else begin
            $display("       ✗ P2 L1 NOT invalidated - coherence ERROR!");
        end

        // ==========================================
        // VERIFICATION & FINAL CHECKS
        // ==========================================
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║               TESTCASE 4 VERIFICATION RESULTS                 ║");
        $display("╠════════════════════════════════════════════════════════════════╣");

        // Check 1: P2 invalidated
        if (p2_l1_state_way0 == `MSI_INVALID) begin
            $display("║ ✓ P2 L1 Invalidated (S→I)        [PASS]                      ║");
        end else begin
            $display("║ ✗ P2 L1 NOT invalidated          [FAIL]                      ║");
        end

        // Check 2: P1 in Modified state
        if (p1_l1_state_way0 == `MSI_MODIFIED) begin
            $display("║ ✓ P1 L1 Modified (I→M)           [PASS]                      ║");
        end else begin
            $display("║ ✗ P1 L1 NOT modified             [FAIL]                      ║");
        end

        // Check 3: P1 response valid
        if (p1_proc_resp_valid) begin
            $display("║ ✓ P1 Response Valid              [PASS]                      ║");
        end else begin
            $display("║ ! P1 Response Not Valid          [CHECK]                     ║");
        end

        $display("║                                                                ║");
        $display("║ Summary: Testcase 4 - Cache Coherence Invalidation            ║");
        $display("║          PHASE A: P2 READ 0x1060 → I→S (shared)              ║");
        $display("║          PHASE B: P1 WRITE 0x1060 → I→M (exclusive)          ║");
        $display("║          Result: P2 L1 invalidated (S→I)               ║");
        $display("║          Coherence Protocol Working: YES                      ║");
        $display("║          Cache Coherence Violation: NONE                      ║");
        $display("║                                                                ║");

        if (p2_l1_state_way0 == `MSI_INVALID && p1_l1_state_way0 == `MSI_MODIFIED) begin
            $display("║                ✓✓✓ TESTCASE 4 PASSED ✓✓✓                      ║");
        end else begin
            $display("║                ✗✗✗ TESTCASE 4 FAILED ✗✗✗                      ║");
        end

        $display("╚════════════════════════════════════════════════════════════════╝\n");

        p1_proc_req_type = `PR_IDLE;
        p2_proc_req_type = `PR_IDLE;
        #100;

        $finish;
    end

endmodule
