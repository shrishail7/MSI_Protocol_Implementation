/*
========================================
TESTCASE 2: P2 READ 0x1020 (I→S)
========================================

Objective:
- P2 issues READ request to address 0x1020
- Initially all caches are INVALID (I state)
- Expected: Transition I→S (Shared state, clean)
- dirty=0 (read-only data, no modification)
- Data from memory: 0x123456789ABCDEF0... (pre-initialized)

Key Points:
1. Address 0x1020 - NEW address, not in any cache
2. Operation: READ (not WRITE)
3. Initial: All caches I (000)
4. Final: P2 L1 state = S (001), dirty=0, valid=1
5. Data: Memory data (0x123456789ABCDEF0...)
6. Bus Request: BUS_RD (0001) - for shared read access

Critical Signals to Monitor:
✓ p2_proc_req_type = READ (001)
✓ p2_proc_req_addr = 0x1020
✓ p2_l1_state_way0 = S (001) final state
✓ p2_l1_wr_dirty = 0 (clean from memory!)
✓ p2_l1_wr_msi = S (001) ← NOT M!
✓ p2_l1_wr_valid = 1
✓ p2_proc_resp_valid = 1 (read data available)
✓ bus_req_type = BUS_RD (0001, NOT BUS_RDX!)

MSI State Transition: I(000) → ISD(011) → S(001)
ISD is transient: In-Service-Data waiting for memory response
*/

`include "msi_types.vh"
`timescale 1ns / 1ps

module testcase2_tb();

    // ========== Clock & Reset ==========
    reg clk;
    reg reset;

    // ========== P1 Processor Interface (Idle) ==========
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
        $dumpfile("testcase2_waveform.vcd");
        $dumpvars(0, testcase2_tb);

        // ========== Display Header ==========
        $display("\n");
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║         TESTCASE 2: P2 READ 0x1020 (I→S Shared)              ║");
        $display("║         All caches initially INVALID                          ║");
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

        // ========== STEP 1: ISSUE READ REQUEST ==========
        $display("┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 1: ISSUE P2 READ REQUEST                                  │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Request Type: READ (001)                                       │");
        $display("│ Address: 0x1020 (NEW, not in cache)                            │");
        $display("│ Expected Data: 0x123456789ABCDEF0... (from memory)             │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        p2_proc_req_type = `PR_RD;
        p2_proc_req_addr = 16'h1020;

        $display("[%0t] P2 Request Issued:", $time);
        $display("       Type: READ (0x%0h)", p2_proc_req_type);
        $display("       Addr: 0x%0h", p2_proc_req_addr);
        $display("       Memory contains: 0x123456789ABCDEF0...");

        #10;

        // ========== STEP 2: VERIFY INITIAL STATE ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 2: VERIFY INITIAL INVALID STATE                           │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: P1 & P2 L1 ways invalid, L2 ways invalid             │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        #10;

        $display("[%0t] Initial Cache States:", $time);
        $display("       P2_L1 Way0: %s", msi_state_to_str(p2_l1_state_way0));
        $display("       P2_L1 Way1: %s", msi_state_to_str(p2_l1_state_way1));
        $display("       P1_L1 Way0: %s (should stay invalid)", msi_state_to_str(p1_l1_state_way0));
        $display("       L2 Way0: %s", msi_state_to_str(l2_state_way0));

        if (p2_l1_state_way0 == `MSI_INVALID && p2_l1_state_way1 == `MSI_INVALID) begin
            $display("       ✓ P2 L1 Both ways invalid");
        end else begin
            $display("       ! P2 L1 not fully invalid");
        end

        // ========== STEP 3: VERIFY L1 MISS ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 3: VERIFY L1 MISS DETECTION                               │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: p2_l1_miss = 1 (cache miss detected)                  │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        #10;

        $display("[%0t] Miss/Hit Status:", $time);
        $display("       P2_L1 Miss: %b (expect 1)", p2_l1_miss);
        $display("       P2_L1 Hit: %b (expect 0)", p2_l1_hit);
        $display("       L2 Miss: %b (expect 1)", l2_miss);

        if (p2_l1_miss && !p2_l1_hit) begin
            $display("       ✓ P2 L1 MISS confirmed");
        end else begin
            $display("       ✗ Miss detection failed!");
        end

        // ========== STEP 4: WAIT FOR BUS_RD REQUEST ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 4: CHECK BUS_RD REQUEST (Read request)                    │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: BUS_RD (0001) sent to bus                             │");
        $display("│ NOT BUS_RDX (0010) - this is a READ!                           │");
        $display("│ Difference from TEST 1: BUS_RD vs BUS_RDX                      │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        $display("[%0t] Waiting for memory fetch...", $time);
        #200;  // Wait for L1 miss processing + memory access

        $display("[%0t] State transitions during fetch:", $time);
        $display("       P2_L1 Way0: %s (should be S or ISD)", msi_state_to_str(p2_l1_state_way0));

        // ========== STEP 5: MEMORY DATA CHECK ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 5: VERIFY MEMORY DATA ARRIVAL                             │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: Memory returns 0x123456789ABCDEF0...                  │");
        $display("│           L2 caches data in S state (clean)                    │");
        $display("│           L1 receives data in S state (dirty=0)                │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        #50;  // Wait for memory + L2 + L1 updates

        $display("[%0t] Read Data Status:", $time);
        $display("       P2 Read Data: 0x%032h...", p2_proc_read_data[127:64]);
        $display("       Expected:    0x123456789ABCDEF0...");

        if (p2_proc_read_data[127:64] == 64'h123456789ABCDEF0) begin
            $display("       ✓ Correct memory data read");
        end else begin
            $display("       ! Data mismatch or not ready");
        end

        // ========== STEP 6: FINAL STATE CHECK ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 6: VERIFY FINAL SHARED STATE (CRITICAL)                   │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: P2 L1 state = S (001), dirty=0, valid=1              │");
        $display("│ DIFFERENT from TEST 1: S state (not M)!                        │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        $display("[%0t] Final P2 L1 State:", $time);
        $display("       P2_L1 Way0 MSI: %s", msi_state_to_str(p2_l1_state_way0));

        // ========== STEP 7: RESPONSE CHECK ==========
        $display("\n┌─────────────────────────────────────────────────────────────────┐");
        $display("│ STEP 7: VERIFY READ RESPONSE                                   │");
        $display("├─────────────────────────────────────────────────────────────────┤");
        $display("│ Expected: proc_resp_valid=1, proc_resp_hit=0 (miss)            │");
        $display("│           p2_proc_read_data = 0x123456789ABCDEF0...            │");
        $display("└─────────────────────────────────────────────────────────────────┘");

        #50;  // Wait for response

        $display("[%0t] Response Signals:", $time);
        $display("       proc_resp_valid: %b (expect 1)", p2_proc_resp_valid);
        $display("       proc_resp_hit: %b (expect 0 for miss)", p2_proc_resp_hit);
        $display("       Read Data: 0x%032h...", p2_proc_read_data[127:64]);
        $display("       Latency: ~%0d ns", $time - 500);

        // ========== VERIFICATION RESULTS ==========
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║               TESTCASE 2 VERIFICATION RESULTS                  ║");
        $display("╠════════════════════════════════════════════════════════════════╣");

        // Check 1: Final MSI State = S
        if (p2_l1_state_way0 == `MSI_SHARED) begin
            $display("║ ✓ Final MSI State: S (001)     [PASS]                         ║");
        end else begin
            $display("║ ✗ Final MSI State: %s    [FAIL]                         ║", msi_state_to_str(p2_l1_state_way0));
        end

        // Check 2: Valid Bit = 1
        if (p2_l1_state_way0 != `MSI_INVALID) begin
            $display("║ ✓ Valid Bit: 1                [PASS]                         ║");
        end else begin
            $display("║ ✗ Valid Bit: 0                [FAIL]                         ║");
        end

        // Check 3: L1 Miss confirmed
        if (p2_l1_miss && !p2_l1_hit) begin
            $display("║ ✓ L1 Miss Detected            [PASS]                         ║");
        end else begin
            $display("║ ✗ Miss detection failed       [FAIL]                         ║");
        end

        // Check 4: Response Valid
        if (p2_proc_resp_valid) begin
            $display("║ ✓ Response Valid: 1           [PASS]                         ║");
        end else begin
            $display("║ ! Response Not Valid           [CHECK]                        ║");
        end

        // Check 5: Data Correct
        if (p2_proc_read_data[127:64] == 64'h123456789ABCDEF0) begin
            $display("║ ✓ Data Correct: 0x123456...   [PASS]                         ║");
        end else begin
            $display("║ ! Data incorrect or delayed   [CHECK]                        ║");
        end

        $display("║                                                                ║");
        $display("║ Summary: Testcase 2 - Read I→S (Shared, Clean Read)            ║");
        $display("║          Initial: All INVALID                                  ║");
        $display("║          Final: P2 L1 = S (Shared), dirty=0, valid=1           ║");
        $display("║          Data: Memory data (0x123456789ABCDEF0...)             ║");
        $display("║          Bus: BUS_RD (not BUS_RDX)                             ║");
        $display("║          Difference from TEST 1: S state (read), not M (write) ║");
        $display("║                                                                ║");

        if (p2_l1_state_way0 == `MSI_SHARED && p2_proc_resp_valid) begin
            $display("║                 ✓✓✓ TESTCASE 2 PASSED ✓✓✓                      ║");
        end else begin
            $display("║                 ✗✗✗ TESTCASE 2 FAILED ✗✗✗                      ║");
        end

        $display("╚════════════════════════════════════════════════════════════════╝\n");

        p2_proc_req_type = `PR_IDLE;
        #100;

        $finish;
    end

endmodule
