// =============================================================================
// Module  : tb_cnn_top.sv
// Project : CNN Accelerator — IHP 130nm ASIC (MSc Project Thesis)
// Purpose : Full-system integration testbench for cnn_top.sv
//
// Bugs fixed vs ALL previous versions:
//   1. FSM auto-loop: old fork/join stub re-armed on every pool_start.
//      Fixed: pool_stub_fired is a pure always_ff signal (never touched by
//      task). Task only drives pool_stub_armed. Fired flag prevents re-fire.
//   2. Pixel counter reset race (MULAXX): int variables shared between
//      always_ff and task blocking assignments are non-deterministic.
//      Fixed: counters are logic[31:0]; reset only via cnt_reset strobe
//      driven by task for exactly 1 cycle; always_ff owns the register.
//   3. done de-assert check was wrong: FSM holds done=1 as a LEVEL in
//      S_DONE. Removed erroneous "de-asserts after 1 cycle" check.
//      Replaced with: verify done=1 at completion, stays=1 in S_DONE.
//   4. MULAXX on pool_stub_fired: was assigned both in task (blocking)
//      and always_ff (non-blocking). Fixed: only always_ff drives it;
//      task resets it via pool_stub_armed de-assertion + cnt_reset cycle.
//
// Cycle budget (10 ns clock):
//   Conv1: 4096 pixels x  6 cycles  =  24 576 cycles ~  245 760 ns
//   Conv2: 8192 pixels x 12 cycles  =  98 304 cycles ~  983 040 ns
//   FSM + pool overhead              ~      60 cycles
//   Total per run                    ~ 123 000 cycles ~ 1 230 000 ns
//   Watchdog (4x margin, 2 runs)     =  10 000 000 ns
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module tb_cnn_top;

    // =========================================================================
    // DUT connections
    // =========================================================================
    logic clk;
    logic rst_n;
    logic start;
    logic done;

    cnn_top u_dut (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start),
        .done (done)
    );

    // =========================================================================
    // Clock — 100 MHz (10 ns period)
    // =========================================================================
    localparam int CLK_HALF = 5;
    initial clk = 1'b0;
    always #(CLK_HALF) clk = ~clk;

    // =========================================================================
    // Watchdog — 10 000 000 ns (4x margin for 2 runs)
    // =========================================================================
    initial begin
        #10_000_000;
        $fatal(1, "[TB] WATCHDOG TIMEOUT at t=%0t ns", $time);
    end

    // =========================================================================
    // Hierarchical signal aliases (READ-ONLY — never driven from TB)
    // =========================================================================
    wire        tb_conv_start = u_dut.conv_start;
    wire        tb_pool_start = u_dut.pool_start;
    wire        tb_layer_sel  = u_dut.layer_sel;
    wire        tb_ag_enable  = u_dut.ag_enable;
    wire        tb_layer_done = u_dut.layer_done;
    wire        tb_mac_valid  = u_dut.mac_valid;
    wire        tb_conv_out_v = u_dut.conv_out_valid;
    wire [7:0]  tb_conv_out_d = u_dut.conv_out_data;
    wire        tb_src_sel    = u_dut.src_sel;
    wire        tb_dst_sel    = u_dut.dst_sel;

    // =========================================================================
    // Expected pixel counts
    // =========================================================================
    localparam int CONV1_PIXELS = 4 * 32 * 32;   // 4096
    localparam int CONV2_PIXELS = 8 * 32 * 32;   // 8192

    // =========================================================================
    // Pixel counters
    // Rule: ONLY always_ff drives conv1/conv2_pixel_count (no task writes)
    // Task drives cnt_reset HIGH for 1 cycle to synchronously clear counters.
    // =========================================================================
    logic        cnt_reset;          // 1-cycle strobe from task
    logic [31:0] conv1_pixel_count;
    logic [31:0] conv2_pixel_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || cnt_reset) begin
            conv1_pixel_count <= 32'd0;
            conv2_pixel_count <= 32'd0;
        end else if (tb_conv_out_v) begin
            if (!tb_layer_sel)
                conv1_pixel_count <= conv1_pixel_count + 1;
            else
                conv2_pixel_count <= conv2_pixel_count + 1;
        end
    end

    // =========================================================================
    // pool_done one-shot stub
    //
    // pool_stub_armed: task drives this HIGH before run, LOW after done asserts
    // pool_stub_fired: ONLY driven by always_ff (no task writes — avoids MULAXX)
    //
    // Sequence:
    //   1. Task sets pool_stub_armed=1 before pulsing start
    //   2. FSM reaches S_POOL, pool_start goes HIGH
    //   3. always_ff sees armed & !fired & pool_start → forces pool_done=1,
    //      sets pool_stub_fired=1
    //   4. Next cycle: always_ff releases pool_done (pool_done returns to 0
    //      via the DUT's internal assign pool_done=1'b0)
    //   5. FSM sees pool_done=1, transitions to S_DONE, done=1
    //   6. Task sees done=1, sets pool_stub_armed=0
    //   7. pool_stub_fired resets on next cnt_reset or rst_n
    //
    // The one-shot (fired flag) prevents re-firing if pool_start pulses again.
    // =========================================================================
    logic pool_stub_armed;   // driven by task only
    logic pool_stub_fired;   // driven by always_ff only (MULAXX prevention)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pool_stub_fired <= 1'b0;
        end else if (cnt_reset) begin
            pool_stub_fired <= 1'b0;   // reset stub state with counters
        end else if (pool_stub_armed && !pool_stub_fired && tb_pool_start) begin
            force u_dut.pool_done = 1'b1;
            pool_stub_fired <= 1'b1;
            $display("[TB] pool_done forced HIGH at t=%0t ns", $time);
        end else if (pool_stub_fired) begin
            release u_dut.pool_done;
        end
    end

    // =========================================================================
    // Check helpers
    // =========================================================================
    int pass_count;
    int fail_count;

    task automatic check_int(input string lbl, input int got, input int exp);
        if (got === exp) begin
            $display("[PASS] %-44s got=%0d expected=%0d t=%0t ns",
                     lbl, got, exp, $time);
            pass_count++;
        end else begin
            $display("[FAIL] %-44s got=%0d expected=%0d t=%0t ns",
                     lbl, got, exp, $time);
            fail_count++;
        end
    endtask

    task automatic check_bit(input string lbl, input logic got, input logic exp);
        if (got === exp) begin
            $display("[PASS] %-44s got=%0b expected=%0b t=%0t ns",
                     lbl, got, exp, $time);
            pass_count++;
        end else begin
            $display("[FAIL] %-44s got=%0b expected=%0b t=%0t ns",
                     lbl, got, exp, $time);
            fail_count++;
        end
    endtask

    // =========================================================================
    // Primitive tasks
    // =========================================================================

    task automatic reset_dut();
        // Drive all TB outputs to safe defaults before releasing reset
        rst_n           = 1'b0;
        start           = 1'b0;
        cnt_reset       = 1'b0;
        pool_stub_armed = 1'b0;
        repeat(8) @(posedge clk); #1;
        rst_n = 1'b1;
        @(posedge clk); #1;
        $display("[TB] Reset released at t=%0t ns", $time);
    endtask

    // Clear pixel counters and pool stub state synchronously
    task automatic clear_state();
        @(posedge clk); #1;
        cnt_reset = 1'b1;        // triggers counter reset + pool_stub_fired=0
        @(posedge clk); #1;
        cnt_reset = 1'b0;
        @(posedge clk); #1;      // one idle cycle before any activity
    endtask

    task automatic pulse_start();
        @(posedge clk); #1;
        start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0;
        $display("[TB] start pulsed at t=%0t ns", $time);
    endtask

    task automatic wait_for_done(input int timeout_cycles);
        int cyc;
        cyc = 0;
        while (done !== 1'b1) begin
            @(posedge clk); #1;
            cyc++;
            if (cyc >= timeout_cycles)
                $fatal(1, "[TB] wait_for_done: timeout after %0d cycles t=%0t ns",
                       timeout_cycles, $time);
        end
        $display("[TB] done asserted at t=%0t ns (after %0d cycles)", $time, cyc);
    endtask

    // =========================================================================
    // run_cnn — one complete Conv1 -> Conv2 -> Pool -> Done sequence
    // =========================================================================
    task automatic run_cnn(input int run_id);
        $display("============================================================");
        $display("[TB] RUN %0d starting at t=%0t ns", run_id, $time);
        $display("============================================================");

        // Step 1: clear counters and pool stub state (synchronous via cnt_reset)
        clear_state();

        // Step 2: arm pool stub BEFORE pulsing start so it is ready when
        //         pool_start fires deep inside the run
        @(posedge clk); #1;
        pool_stub_armed = 1'b1;

        // Step 3: pulse start — FSM exits S_IDLE (Run1) or S_DONE (Run2)
        pulse_start();

        // Step 4: wait for done — both conv layers + pool must complete
        // 200 000 cycles >> 123 000 expected; watchdog provides hard ceiling
        wait_for_done(200_000);

        // Step 5: pixel count checks
        $display("[TB] RUN %0d done. conv1=%0d (exp=%0d) conv2=%0d (exp=%0d)",
                 run_id,
                 conv1_pixel_count, CONV1_PIXELS,
                 conv2_pixel_count, CONV2_PIXELS);
        check_int($sformatf("R%0d: Conv1 pixel count", run_id),
                  int'(conv1_pixel_count), CONV1_PIXELS);
        check_int($sformatf("R%0d: Conv2 pixel count", run_id),
                  int'(conv2_pixel_count), CONV2_PIXELS);

        // Step 6: done must be HIGH right now (FSM in S_DONE, done=1 as level)
        check_bit($sformatf("R%0d: done HIGH at completion", run_id),
                  done, 1'b1);

        // Step 7: done stays HIGH in S_DONE (no start pulsed yet)
        // Verify it holds for 10 more cycles — FSM should not self-exit S_DONE
        repeat(10) @(posedge clk); #1;
        check_bit($sformatf("R%0d: done stays HIGH in S_DONE (10 cyc)", run_id),
                  done, 1'b1);

        // Step 8: ping-pong sanity — neither src_sel nor dst_sel must be X
        if (tb_src_sel === 1'bx || tb_dst_sel === 1'bx) begin
            $display("[FAIL] R%0d: ping-pong X  src=%b dst=%b  t=%0t ns",
                     run_id, tb_src_sel, tb_dst_sel, $time);
            fail_count++;
        end else begin
            $display("[PASS] R%0d: ping-pong src=%0b dst=%0b (no X)  t=%0t ns",
                     run_id, tb_src_sel, tb_dst_sel, $time);
            pass_count++;
        end

        // Step 9: disarm pool stub
        @(posedge clk); #1;
        pool_stub_armed = 1'b0;

        $display("[TB] RUN %0d COMPLETE at t=%0t ns", run_id, $time);
        $display("------------------------------------------------------------");
    endtask

    // =========================================================================
    // Progress ticker — 1 line per 1000 conv_out_valid pulses (not per-cycle)
    // =========================================================================
    int total_out_valid_count;
    initial total_out_valid_count = 0;

    always @(posedge clk) begin
        if (u_dut.conv_out_valid) begin
            total_out_valid_count++;
            if ((total_out_valid_count % 1000) == 0)
                $display("[TB] Progress: %0d conv_out_valid total  layer=%0b  t=%0t ns",
                         total_out_valid_count, tb_layer_sel, $time);
        end
    end

    // =========================================================================
    // X/Z data monitor — warn if conv_out_data contains X when out_valid=1
    // =========================================================================
    always @(posedge clk) begin
        if (rst_n && u_dut.conv_out_valid && (^tb_conv_out_d === 1'bx))
            $display("[WARN] conv_out_data=X (0x%02h) when out_valid=1  t=%0t ns",
                     tb_conv_out_d, $time);
    end

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("============================================================");
        $display("[TB] tb_cnn_top — full-system integration testbench");
        $display("[TB] Conv1=%0d pixels | Conv2=%0d pixels | 100 MHz",
                 CONV1_PIXELS, CONV2_PIXELS);
        $display("============================================================");

        // ---------------------------------------------------------------
        // Hard reset
        // ---------------------------------------------------------------
        reset_dut();

        // Post-reset signal checks
        @(posedge clk); #1;
        check_bit("POST_RESET: done=0",           done,         1'b0);
        check_bit("POST_RESET: conv_start=0",     tb_conv_start,1'b0);
        check_bit("POST_RESET: ag_enable=0",      tb_ag_enable, 1'b0);
        check_bit("POST_RESET: mac_valid=0",      tb_mac_valid, 1'b0);
        check_bit("POST_RESET: conv_out_valid=0", tb_conv_out_v,1'b0);
        check_bit("POST_RESET: layer_done=0",     tb_layer_done,1'b0);

        // ---------------------------------------------------------------
        // RUN 1
        // ---------------------------------------------------------------
        run_cnn(1);

        // Brief idle — verify done stays HIGH in S_DONE without a new start
        repeat(20) @(posedge clk); #1;
        check_bit("INTER_RUN: done HIGH in S_DONE (20 cyc idle)", done, 1'b1);

        // ---------------------------------------------------------------
        // RUN 2 — restart from S_DONE, no rst_n
        // FSM exits S_DONE when start is pulsed inside run_cnn
        // ---------------------------------------------------------------
        run_cnn(2);

        // Post-run idle
        repeat(10) @(posedge clk); #1;
        check_bit("POST_RUN2: done HIGH in S_DONE (no restart)", done, 1'b1);

        // ---------------------------------------------------------------
        // Final summary
        // ---------------------------------------------------------------
        $display("============================================================");
        $display("[TB] RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================================");

        if (fail_count > 0)
            $fatal(1, "[TB] SIMULATION FAILED — %0d test(s) failed", fail_count);
        else
            $display("[TB] ALL TESTS PASSED — cnn_top integration verified OK");

        $finish;
    end

endmodule : tb_cnn_top

`default_nettype wire
// =============================================================================
// End of tb_cnn_top.sv
// =============================================================================
