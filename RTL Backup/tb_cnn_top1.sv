// =============================================================================
// tb_cnn_top.sv
//
// Testbench for cnn_top — full top-level integration.
//
// Test plan:
//   1. Reset verification — done=0 after reset
//   2. Run 1 — start pulse → wait for done → verify done=1
//   3. Run 2 — restart from S_DONE → verify FSM re-arms correctly
//
// Watchdog: 3,000,000 ns — sized for Conv1 + Conv2 + Pool worst case
// =============================================================================

`timescale 1ns/1ps

module tb_cnn_top;

    // -------------------------------------------------------------------------
    // DUT port signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;
    logic start;
    logic done;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    cnn_top dut (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start),
        .done (done)
    );

    // -------------------------------------------------------------------------
    // pool_done stub — pulse pool_done for 1 cycle when pool_start fires
    // Remove once pool_engine is instantiated in cnn_top
    // -------------------------------------------------------------------------
    // synthesis translate_off
    always_ff @(posedge clk) begin
        if (dut.pool_start) begin
            $display("[TB STUB] pool_start at %0t ns — pulsing pool_done.", $time);
            force dut.pool_done = 1'b1;
        end else begin
            release dut.pool_done;
        end
    end
    // synthesis translate_on

    // -------------------------------------------------------------------------
    // Clock — 100 MHz, 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Watchdog — $fatal (not $finish) so it is clearly an error, not a pass
    // -------------------------------------------------------------------------
    initial begin
        #3_000_000;
        $fatal(1, "[WATCHDOG] Simulation exceeded 3,000,000 ns. DUT appears stuck.");
    end

    // -------------------------------------------------------------------------
    // Cycle monitor — prints key signals each active clock edge
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_n)
            $display("[%0t ns] start=%0b done=%0b",
                     $time, start, done);
    end

    // =========================================================================
    // Tasks
    // =========================================================================

    // -------------------------------------------------------------------------
    // Task: reset_dut
    // -------------------------------------------------------------------------
    task automatic reset_dut();
        start = 1'b0;
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        #1; rst_n = 1'b1;
        @(posedge clk);

        if (done !== 1'b0)
            $fatal(1, "[FAIL] done=%0b after reset (expected 0)", done);

        $display("[%0t ns] Reset released — quiescence verified.", $time);
    endtask

    // -------------------------------------------------------------------------
    // Task: pulse_start — single cycle start pulse with #1 drive delay
    // -------------------------------------------------------------------------
    task automatic pulse_start();
        @(posedge clk); #1;
        start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0;
        $display("[%0t ns] Start pulse sent.", $time);
    endtask

    // -------------------------------------------------------------------------
    // Task: wait_for_done — blocks until done asserts
    // -------------------------------------------------------------------------
    task automatic wait_for_done();
        @(posedge clk iff (done === 1'b1));
        $display("[%0t ns] done asserted.", $time);
        repeat(2) @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Task: check_done — verifies done is high after a run
    // -------------------------------------------------------------------------
    task automatic check_done(input string test_name);
        if (done !== 1'b1) begin
            $display("  [FAIL] %s — done=%0b (expected 1)", test_name, done);
            $fatal(1, "[FATAL] %s failed.", test_name);
        end
        $display("  [PASS] ✅  %s — done=1", test_name);
    endtask

    // =========================================================================
    // Stimulus
    // =========================================================================
    initial begin
        $display("========================================");
        $display(" Starting tb_cnn_top");
        $display("========================================");

        // -- Reset ------------------------------------------------------------
        reset_dut();

        // =====================================================================
        // Run 1 — full pipeline pass
        // =====================================================================
        $display("\n--- Run 1: Full pipeline ---");
        pulse_start();
        wait_for_done();
        check_done("Run 1");

        // =====================================================================
        // Run 2 — restart from S_DONE
        // =====================================================================
        $display("\n--- Run 2: Restart from S_DONE ---");
        pulse_start();
        wait_for_done();
        check_done("Run 2");

        // =====================================================================
        $display("\n========================================");
        $display("  All tests PASSED ✅");
        $display("========================================\n");
        $finish;
    end

endmodule