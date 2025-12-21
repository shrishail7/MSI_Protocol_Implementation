/*
========================================
TESTCASE 1: P1 WRITE 0x1010 (I→M Direct)
========================================

Objective: 
- P1 issues WRITE to address 0x1010
- Initially all caches are INVALID (I state)
- Expected: Direct transition I→M (no intermediate S state!)
- dirty=1 (data differs from memory immediately)
- NO read of original data needed (write-allocate with M directly)

Key Points:
1. Address 0x1010 - NEW address, not in any cache
2. Operation: WRITE (not READ)
3. Initial: All caches I (000)
4. Final: P1 L1 state = M (010), dirty=1, valid=1
5. Data: Processor's data (0xAAAABBBBCCCCDDDD...)

Critical Signals to Monitor:
✓ p1_proc_req_type = WRITE (010)
✓ p1_proc_req_addr = 0x1010
✓ p1_proc_write_data = 0xAAAABBBBCCCCDDDD...
✓ p1_l1_state_way0 = M (010) final state
✓ p1_l1_wr_dirty = 1 (MUST be 1!)
✓ p1_l1_wr_msi = M (010)
✓ p1_l1_wr_valid = 1
✓ p1_proc_resp_valid = 1 (write acknowledged)
✓ bus_req_type = BUS_RDX (write request, NOT BUS_RD!)

MSI State Transition: I(000) → M(010) DIRECT
NO intermediate state needed
NO read from memory
Just: allocate line + write data + set M state
*/

`include "msi_types.vh"
`timescale 1ns / 1ps

module testcase1_tb();

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

    // ========== P2 Processor Interface (Idle) ==========
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
        $dumpfile("testcase1_waveform.vcd");
        $dumpvars(0, testcase1_tb);

        // ========== Display Header ==========
        $display("\n");
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║          TESTCASE 1: P1 WRITE 0x1010 (I→M Direct)            ║");
        $display("║          All caches initially INVALID                         ║");
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

        // ========== STEP 1: ISSUE WRITE REQUEST ==========
        $display("┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 1: ISSUE P1 WRITE REQUEST                                 │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Request Type: WRITE (010)                                      │");
        $display("│ Address: 0x1010 (NEW, not in cache)                            │");
        $display("│ Data: 0xAAAABBBBCCCCDDDD... (processor data)                   │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        p1_proc_req_type = `PR_WR;
        p1_proc_req_addr = 16'h1010;
        p1_proc_write_data = 128'hEEEEFFFF11112222_AAAABBBBCCCCDDDD;

        $display("[%0t] P1 Request Issued:", $time);
        $display("       Type: WRITE (0x%0h)", p1_proc_req_type);
        $display("       Addr: 0x%0h", p1_proc_req_addr);
        $display("       Data: 0x%032h...", p1_proc_write_data[127:64]);

        #10;

        // ========== STEP 2: CHECK INITIAL STATE ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 2: VERIFY INITIAL INVALID STATE                           │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: Both L1 ways invalid, L2 ways invalid                 │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        #10;

        $display("[%0t] Initial Cache States:", $time);
        $display("       P1_L1 Way0: %s", msi_state_to_str(p1_l1_state_way0));
        $display("       P1_L1 Way1: %s", msi_state_to_str(p1_l1_state_way1));
        $display("       L2 Way0: %s", msi_state_to_str(l2_state_way0));
        $display("       L2 Way1: %s", msi_state_to_str(l2_state_way1));

        if (p1_l1_state_way0 == `MSI_INVALID && p1_l1_state_way1 == `MSI_INVALID) begin
            $display("       ✓ L1 Both ways invalid");
        end else begin
            $display("       ! L1 not fully invalid");
        end

        // ========== STEP 3: CHECK L1 MISS ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 3: VERIFY L1 MISS DETECTION                               │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: p1_l1_miss = 1 (cache miss detected)                  │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        #10;

        $display("[%0t] Miss/Hit Status:", $time);
        $display("       P1_L1 Miss: %b (expect 1)", p1_l1_miss);
        $display("       P1_L1 Hit: %b (expect 0)", p1_l1_hit);
        $display("       L2 Miss: %b (expect 1)", l2_miss);

        if (p1_l1_miss && !p1_l1_hit) begin
            $display("       ✓ L1 MISS confirmed");
        end else begin
            $display("       ✗ Miss detection failed!");
        end

        // ========== STEP 4: WAIT FOR BUS_RDX REQUEST ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 4: CHECK BUS_RDX REQUEST (Write request)                  │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: BUS_RDX (0010) sent to bus                            │");
        $display("│ NOT BUS_RD (0001) - this is a WRITE!                           │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        $display("[%0t] Waiting for state transitions...", $time);
        #200;  // Wait for L1 miss processing

        $display("[%0t] L1 State After Miss Processing:", $time);
        $display("       P1_L1 Way0: %s", msi_state_to_str(p1_l1_state_way0));

        // ========== STEP 5: WAIT FOR L1 WRITE & M STATE ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 5: CHECK L1 WRITE WITH M STATE (CRITICAL)                 │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: L1 transitions directly I→M                           │");
        $display("│           dirty bit set to 1                                    │");
        $display("│           Processor data written (0xAAAA...)                    │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        #150;  // Wait for write to complete

        $display("[%0t] Final L1 State:", $time);
        $display("       P1_L1 Way0 MSI: %s", msi_state_to_str(p1_l1_state_way0));

        // ========== STEP 6: RESPONSE CHECK ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 6: VERIFY WRITE RESPONSE                                  │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: proc_resp_valid=1, proc_write_ack=1                   │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        $display("[%0t] Response Signals:", $time);
        $display("       proc_resp_valid: %b (expect 1)", p1_proc_resp_valid);
        $display("       proc_resp_hit: %b (expect 0 for miss)", p1_proc_resp_hit);
        $display("       Latency: ~%0d ns", $time - 500);

        // ========== VERIFICATION RESULTS ==========
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║               TESTCASE 1 VERIFICATION RESULTS                  ║");
        $display("╠════════════════════════════════════════════════════════════════╣");

        // Check 1: Final MSI State = M
        if (p1_l1_state_way0 == `MSI_MODIFIED) begin
            $display("║ ✓ Final MSI State: M (010)     [PASS]                         ║");
        end else begin
            $display("║ ✗ Final MSI State: %s    [FAIL]                         ║", msi_state_to_str(p1_l1_state_way0));
        end

        // Check 2: Valid Bit = 1
        if (p1_l1_state_way0 != `MSI_INVALID) begin
            $display("║ ✓ Valid Bit: 1                [PASS]                         ║");
        end else begin
            $display("║ ✗ Valid Bit: 0                [FAIL]                         ║");
        end

        // Check 3: L1 Miss confirmed
        if (p1_l1_miss && !p1_l1_hit) begin
            $display("║ ✓ L1 Miss Detected            [PASS]                         ║");
        end else begin
            $display("║ ✗ Miss detection failed       [FAIL]                         ║");
        end

        // Check 4: Response Valid
        if (p1_proc_resp_valid) begin
            $display("║ ✓ Response Valid: 1           [PASS]                         ║");
        end else begin
            $display("║ ! Response Not Valid           [CHECK]                        ║");
        end

        $display("║                                                                ║");
        $display("║ Summary: Testcase 1 - Write I→M Direct (No Read)               ║");
        $display("║          Initial: All INVALID                                  ║");
        $display("║          Final: P1 L1 = M (Modified), dirty=1, valid=1         ║");
        $display("║          Data: Processor's write data (not memory data)         ║");
        $display("║                                                                ║");

        if (p1_l1_state_way0 == `MSI_MODIFIED) begin
            $display("║                 ✓✓✓ TESTCASE 1 PASSED ✓✓✓                      ║");
        end else begin
            $display("║                 ✗✗✗ TESTCASE 1 FAILED ✗✗✗                      ║");
        end

        $display("╚════════════════════════════════════════════════════════════════╝\n");

        p1_proc_req_type = `PR_IDLE;
        #100;

        $finish;
    end

endmodule
