`include "msi_types.vh"
`timescale 1ns/1ps

/*
================================================================================
TESTCASE 3 TESTBENCH - S -> M TRANSITION
================================================================================
... (comments ommitted for brevity) ...
================================================================================
*/

module testcase_3_tb ();

  reg clk;
  reg reset;

  // ========== P1 Processor Interface ==========
  reg [3:0] p1_proc_req_type;
  reg [15:0] p1_proc_req_addr;
  reg [127:0] p1_proc_write_data;
  wire [127:0] p1_proc_read_data;
  wire p1_proc_resp_valid;
  wire p1_proc_resp_hit;

  // ========== P2 Processor Interface (tied low) ==========
  reg [3:0] p2_proc_req_type;
  reg [15:0] p2_proc_req_addr;
  reg [127:0] p2_proc_write_data;
  wire [127:0] p2_proc_read_data;
  wire p2_proc_resp_valid;
  wire p2_proc_resp_hit;

  // ========== Debug Signals ==========
  wire [2:0] p1_l1_state_way0;
  wire [2:0] p1_l1_state_way1;
  wire [2:0] p2_l1_state_way0;
  wire [2:0] p2_l1_state_way1;
  wire [2:0] l2_state_way0;
  wire [2:0] l2_state_way1;
  wire p1_l1_hit;
  wire p1_l1_miss;
  wire p2_l1_hit;
  wire p2_l1_miss;
  wire l2_hit;
  wire l2_miss;

  // ========== ⭐ SYNTAX FIX: Declarations for monitoring block ==========
  reg [2:0] prev_state;
  wire [2:0] current_state;
  assign current_state = (p1_l1_state_way0 != 3'b0) ? p1_l1_state_way0 : p1_l1_state_way1;

  // ========== Top Module Instantiation ==========
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
    
    // P2 Interface (unused)
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

  // ========== Test Sequence ==========
  initial begin
    // Display header
    $display("\n");
    $display("================================================================================");
    $display("TESTCASE 3: S -> M TRANSITION (Read then Write)");
    $display("================================================================================");
    $display("Address: 0x1040");
    $display("Read Data (from Memory): 128'hAAAABBBBCCCCDDDDEEEEFFFF11112222");
    $display("Write Data (from Processor): 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE");
    $display("================================================================================\n");

    // Initialize
    reset = 1'b1;
    p1_proc_req_type = `PR_IDLE;
    p1_proc_req_addr = 16'b0;
    p1_proc_write_data = 128'b0;
    p2_proc_req_type = `PR_IDLE;
    p2_proc_req_addr = 16'b0;
    p2_proc_write_data = 128'b0;

    #10 reset = 1'b0;
    #10;

    // ===== STEP 1: P1 READS ADDRESS 0x1040 (L1 MISS) =====
    $display("[%0t] ========== STEP 1: P1 READ REQUEST ==========", $time);
    p1_proc_req_type = `PR_RD;
    p1_proc_req_addr = 16'h1040;
    #10;

    // Wait for response
    $display("[%0t] Waiting for read response...", $time);
    wait(p1_proc_resp_valid);
    $display("[%0t] ✓ READ RESPONSE VALID", $time);
    $display("[%0t]   Hit: %b, Read Data: 0x%032x", $time, p1_proc_resp_hit, p1_proc_read_data);
    $display("[%0t]   P1 L1 Way0 State: %d (000=I, 001=S, 010=M)", $time, p1_l1_state_way0);

    // ===== VERIFY READ RESPONSE =====
    if(p1_proc_read_data == 128'hAAAABBBBCCCCDDDDEEEEFFFF11112222) begin
      $display("[%0t] ✓ READ DATA CORRECT (memory data loaded)", $time);
    end else begin
      $display("[%0t] ✗ ERROR: Read data mismatch!", $time);
      $display("[%0t]   Expected: 128'hAAAABBBBCCCCDDDDEEEEFFFF11112222", $time);
      $display("[%0t]   Got:      0x%032x", $time, p1_proc_read_data);
    end

    // ===== VERIFY L1 STATE AFTER READ (Should be S) =====
    #10;
    p1_proc_req_type = `PR_IDLE;
    #20;

    if(p1_l1_state_way0 == 3'd1 || p1_l1_state_way1 == 3'd1) begin
      $display("[%0t] ✓ L1 STATE CORRECT: Shared (001)", $time);
    end else begin
      $display("[%0t] ✗ ERROR: Expected L1 state Shared(001), got %d", $time, 
               (p1_l1_state_way0 == 3'b0 ? p1_l1_state_way1 : p1_l1_state_way0));
    end

    // ===== STEP 2: P1 WRITES TO SAME ADDRESS 0x1040 =====
    $display("\n[%0t] ========== STEP 2: P1 WRITE REQUEST (S->M) ==========", $time);
    
    p1_proc_req_type = `PR_WR;
    p1_proc_req_addr = 16'h1040;
    p1_proc_write_data = 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE;
    #10;

    // Wait for response
    $display("[%0t] Waiting for write response...", $time);
    wait(p1_proc_resp_valid);
    $display("[%0t] ✓ WRITE RESPONSE VALID", $time);
    $display("[%0t]   Hit: %b", $time, p1_proc_resp_hit);

    // ===== VERIFY L1 STATE AFTER WRITE (Should be M) =====
    #30;
    p1_proc_req_type = `PR_IDLE;
    #30;

    if(p1_l1_state_way0 == 3'd2 || p1_l1_state_way1 == 3'd2) begin
      $display("[%0t] ✓ L1 STATE CORRECT: Modified (010)", $time);
    end else begin
      $display("[%0t] ✗ ERROR: Expected L1 state Modified(010), got %d", $time,
               (p1_l1_state_way0 == 3'b0 ? p1_l1_state_way1 : p1_l1_state_way0));
    end

    // ===== STEP 3: VERIFY DATA IN L1 CACHE (Read back to confirm) =====
    $display("\n[%0t] ========== STEP 3: VERIFY L1 DATA ==========", $time);
    p1_proc_req_type = `PR_RD;
    p1_proc_req_addr = 16'h1040;
    #10;

    wait(p1_proc_resp_valid);
    $display("[%0t] ✓ VERIFY READ RESPONSE VALID", $time);
    $display("[%0t]   Hit: %b", $time, p1_proc_resp_hit);

    // ===== VERIFY VERIFICATION READ RETURNS WRITE DATA =====
    if(p1_proc_read_data == 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE) begin
      $display("[%0t] ✓ VERIFICATION READ DATA CORRECT (write data present in L1)", $time);
    end else begin
      $display("[%0t] ✗ ERROR: Verification read data mismatch!", $time);
      $display("[%0t]   Expected: 128'hDEADBEEFCAFEBABEDEADBEEFCAFEBABE", $time);
      $display("[%0t]   Got:      0x%032x", $time, p1_proc_read_data);
    end

    // ===== TEST SUMMARY =====
    #20;
    p1_proc_req_type = `PR_IDLE;
    #20;

    $display("\n");
    $display("================================================================================");
    $display("TESTCASE 3 COMPLETE");
    $display("================================================================================");
    $display("State Transitions:");
    $display("  1. Initial:  I (000)");
    $display("  2. After Read: S (001) - Read hit from memory");
    $display("  3. After Write: M (010) - Upgrade from S to M");
    $display("================================================================================\n");

    $finish;
  end

  // ===== CONTINUOUS MONITORING =====
  // ⭐ SYNTAX FIX: 'prev_state' initialized in its own initial block
  initial begin
    prev_state = 3'b0;
  end

  // ⭐ SYNTAX FIX: Removed 'static' and internal 'reg' declarations
  always @(posedge clk) begin
    if (reset) begin
        prev_state <= 3'b0;
    end else begin
        // Monitor L1 cache state changes
        if(current_state != prev_state && current_state != 3'b0) begin
          $display("[%0t] L1 STATE CHANGE: %d -> %d", $time, prev_state, current_state);
          prev_state <= current_state; // Use non-blocking assignment
        end
    end
  end

  // ===== WAVEFORM GENERATION =====
  initial begin
    $dumpfile("testcase_3.vcd");
    $dumpvars(0, testcase_3_tb);
  end

endmodule