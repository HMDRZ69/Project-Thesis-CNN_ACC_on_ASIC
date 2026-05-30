// =============================================================================
// tb_controller_fsm.sv
//
// Testbench for controller_fsm.
//
// Test plan:
//   1. Reset and verify initial state
//   2. Run 1 — full pipeline: IDLE → CONV1 → CONV2 → POOL → DONE
//      - Verify conv_start_cnt == 2, pool_start_cnt == 1, done == 1
//   3. Run 2 — immediate restart from S_DONE
//      - Verify FSM re-arms correctly and completes a second pass
//   4. Watchdog timer kills simulation if DUT stalls
// =============================================================================

`timescale 1ns/1ps

module tb_controller_fsm;

    // -------------------------------------------------------------------------
    // DUT port signals
    // -------------------------------------------------------------------------

    // Inputs to DUT
    logic clk;
    logic rst_n;
    logic start;
    logic conv_done;
    logic pool_done;

    // Outputs from DUT
    logic conv_start;
    logic pool_start;
    logic layer_sel;
    logic mode_sel;
    logic src_sel;
    logic dst_sel;
    logic done;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    controller_fsm dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .conv_done (conv_done),
        .pool_done (pool_done),
        .conv_start(conv_start),
        .pool_start(pool_start),
        .layer_sel (layer_sel),
        .mode_sel  (mode_sel),
        .src_sel   (src_sel),
        .dst_sel   (dst_sel),
        .done      (done)
    );

    // -------------------------------------------------------------------------
    // Clock generation — 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Pulse counters
    // -------------------------------------------------------------------------
    int conv_start_cnt;
    int pool_start_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            conv_start_cnt <= 0;
            pool_start_cnt <= 0;
        end else begin
            if (conv_start) conv_start_cnt <= conv_start_cnt + 1;
            if (pool_start) pool_start_cnt <= pool_start_cnt + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Cycle monitor — prints key signals every active clock edge
    // Note: references dut.state_r for white-box visibility of FSM state.
    //       If the FSM internal name changes, update here accordingly.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_n) begin
            $display("[%6t ns] state=%0d | start=%0b conv_done=%0b pool_done=%0b | conv_start=%0b pool_start=%0b | layer=%0b mode=%0b src=%0b dst=%0b | done=%0b",
                     $time,
                     dut.state_r,
                     start, conv_done, pool_done,
                     conv_start, pool_start,
                     layer_sel, mode_sel, src_sel, dst_sel,
                     done);
        end
    end

    // -------------------------------------------------------------------------
    // Watchdog — aborts simulation if it runs too long (prevents infinite hang)
    // -------------------------------------------------------------------------
    initial begin
        #10_000;
        $fatal(1, "[WATCHDOG] Simulation exceeded 10000 ns — DUT appears to be stuck.");
    end

    // -------------------------------------------------------------------------
    // Helper task: drive one full inference pass through the pipeline
    //
    // Arguments allow variable latency per stage so the same task can be
    // reused for both Run 1 and Run 2 with different timing.
    // -------------------------------------------------------------------------
    task automatic run_inference (
        input int conv1_latency_cycles,
        input int conv2_latency_cycles,
        input int pool_latency_cycles
    );
        // Assert start for exactly one cycle
        // Drive inputs after the clock edge (#1) to avoid setup race conditions
        @(posedge clk); #1;
        start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0;

        // Simulate Conv1 completing
        repeat(conv1_latency_cycles) @(posedge clk);
        #1; conv_done = 1'b1;
        @(posedge clk); #1;
        conv_done = 1'b0;

        // Simulate Conv2 completing
        repeat(conv2_latency_cycles) @(posedge clk);
        #1; conv_done = 1'b1;
        @(posedge clk); #1;
        conv_done = 1'b0;

        // Simulate Pooling completing
        repeat(pool_latency_cycles) @(posedge clk);
        #1; pool_done = 1'b1;
        @(posedge clk); #1;
        pool_done = 1'b0;

        // Allow 2 cycles for registered outputs to settle
        repeat(2) @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Helper task: check expected values and report pass/fail
    // -------------------------------------------------------------------------
    task automatic check_outputs (
        input int  exp_conv_start_cnt,
        input int  exp_pool_start_cnt,
        input logic exp_done,
        input string test_name
    );
        logic pass;
        pass = 1'b1;

        if (conv_start_cnt !== exp_conv_start_cnt) begin
            $display("  [FAIL] %s — conv_start_cnt=%0d (expected %0d)",
                     test_name, conv_start_cnt, exp_conv_start_cnt);
            pass = 1'b0;
        end
        if (pool_start_cnt !== exp_pool_start_cnt) begin
            $display("  [FAIL] %s — pool_start_cnt=%0d (expected %0d)",
                     test_name, pool_start_cnt, exp_pool_start_cnt);
            pass = 1'b0;
        end
        if (done !== exp_done) begin
            $display("  [FAIL] %s — done=%0b (expected %0b)",
                     test_name, done, exp_done);
            pass = 1'b0;
        end

        if (pass)
            $display("  [PASS] ✅  %s — conv_start_cnt=%0d, pool_start_cnt=%0d, done=%0b",
                     test_name, conv_start_cnt, pool_start_cnt, done);
        else
            $fatal(1, "[FATAL] %s failed. Aborting simulation.", test_name);
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // -- Initialise all inputs -------------------------------------------
        start     = 1'b0;
        conv_done = 1'b0;
        pool_done = 1'b0;

        // -- Reset sequence --------------------------------------------------
        rst_n = 1'b0;
        repeat(3) @(posedge clk);
        #1; rst_n = 1'b1;
        @(posedge clk);   // one idle cycle after reset

        // ====================================================================
        // Run 1 — normal pipeline pass
        // ====================================================================
        $display("\n--- Run 1: Full pipeline ---");
        run_inference(
            .conv1_latency_cycles(6),
            .conv2_latency_cycles(8),
            .pool_latency_cycles (5)
        );
        check_outputs(
            .exp_conv_start_cnt(2),
            .exp_pool_start_cnt(1),
            .exp_done(1'b1),
            .test_name("Run 1")
        );

        // ====================================================================
        // Run 2 — restart from S_DONE (exercises the re-arm path)
        // ====================================================================
        $display("\n--- Run 2: Restart from S_DONE ---");
        run_inference(
            .conv1_latency_cycles(4),
            .conv2_latency_cycles(4),
            .pool_latency_cycles (3)
        );
        check_outputs(
            .exp_conv_start_cnt(4),   // 2 more pulses on top of Run 1
            .exp_pool_start_cnt(2),   // 1 more pulse on top of Run 1
            .exp_done(1'b1),
            .test_name("Run 2")
        );

        // ====================================================================
        $display("\n========================================");
        $display("  All tests PASSED ✅");
        $display("========================================\n");
        $finish;
    end

endmodule