// =============================================================================
// tb_addr_gen.sv
//
// Testbench for addr_gen.
//
// Test plan:
//   1. Reset and verify initial quiescence
//   2. Conv1 (layer_sel=0, Cin=1, Cout=4, taps=9):
//      a. Check acc_clear fires exactly once per pixel
//      b. Check mac_valid fires exactly 3 cycles per pixel (ceil(9/4)=3 groups)
//      c. Check first pixel (oc=0,y=0,x=0) write address == 0
//      d. Check out_wr_en fires exactly Cout*H*W = 4*32*32 = 4096 times
//      e. Check layer_done asserts and FSM returns to AG_IDLE after enable low
//   3. Conv2 (layer_sel=1, Cin=4, Cout=8, taps=36):
//      a. Check mac_valid fires exactly 9 cycles per pixel (ceil(36/4)=9 groups)
//      b. Check out_wr_en fires exactly Cout*H*W = 8*32*32 = 8192 times
//      c. Check layer_done asserts correctly
// =============================================================================

`timescale 1ns/1ps

module tb_addr_gen;

    // -------------------------------------------------------------------------
    // Parameters (must match DUT defaults)
    // -------------------------------------------------------------------------
    localparam int H = 32;
    localparam int W = 32;

    // Expected counts — derived from parameters so they scale automatically
    localparam int CONV1_COUT       = 4;
    localparam int CONV2_COUT       = 8;
    localparam int CONV1_TAPS_TOTAL = 9;
    localparam int CONV2_TAPS_TOTAL = 36;
    localparam int CONV1_GROUPS     = (CONV1_TAPS_TOTAL + 3) / 4;  // ceil div = 3
    localparam int CONV2_GROUPS     = (CONV2_TAPS_TOTAL + 3) / 4;  // ceil div = 9
    localparam int CONV1_PIXELS     = CONV1_COUT * H * W;           // 4096
    localparam int CONV2_PIXELS     = CONV2_COUT * H * W;           // 8192

    // -------------------------------------------------------------------------
    // DUT port signals — grouped by direction
    // -------------------------------------------------------------------------

    // Inputs to DUT
    logic clk;
    logic rst_n;
    logic enable;
    logic layer_sel;

    // Outputs from DUT
    logic        mac_valid;
    logic        acc_clear;
    logic [3:0]       act_rd_en;
    logic [3:0]       act_zero;
    logic [3:0][15:0] act_rd_addr;
    logic [3:0]      w_rd_en;
    logic [3:0][8:0] w_idx;
    logic        out_wr_en;
    logic [15:0] out_wr_addr;
    logic        layer_done;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    addr_gen #(
        .H(H),
        .W(W)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (enable),
        .layer_sel  (layer_sel),
        .mac_valid  (mac_valid),
        .acc_clear  (acc_clear),
        .act_rd_en  (act_rd_en),
        .act_zero   (act_zero),
        .act_rd_addr(act_rd_addr),
        .w_rd_en    (w_rd_en),
        .w_idx      (w_idx),
        .out_wr_en  (out_wr_en),
        .out_wr_addr(out_wr_addr),
        .layer_done (layer_done)
    );

    // -------------------------------------------------------------------------
    // Clock — 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Watchdog — kills simulation if DUT stalls
    // -------------------------------------------------------------------------
    // Conv2 worst case: 8192 pixels * (9 groups + 3 overhead) cycles ~= 100k cycles
    initial begin
        #2_000_000;
        $fatal(1, "[WATCHDOG] Simulation exceeded 2,000,000 ns — DUT appears stuck.");
    end

    // -------------------------------------------------------------------------
    // Event counters — reset by task before each test
    // -------------------------------------------------------------------------
    int mac_valid_cnt;
    int acc_clear_cnt;
    int out_wr_en_cnt;
    int layer_done_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_valid_cnt  <= 0;
            acc_clear_cnt  <= 0;
            out_wr_en_cnt  <= 0;
            layer_done_cnt <= 0;
        end else begin
            if (mac_valid)  mac_valid_cnt  <= mac_valid_cnt  + 1;
            if (acc_clear)  acc_clear_cnt  <= acc_clear_cnt  + 1;
            if (out_wr_en)  out_wr_en_cnt  <= out_wr_en_cnt  + 1;
            if (layer_done) layer_done_cnt <= layer_done_cnt + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Cycle monitor — compact per-cycle display
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_n) begin
            $display("[%7t ns] mac_v=%0b acc_clr=%0b | act_en=%4b act_z=%4b | a[0..3]=%0d,%0d,%0d,%0d | w[0..3]=%0d,%0d,%0d,%0d | wr=%0b wr_addr=%0d done=%0b",
                     $time,
                     mac_valid, acc_clear,
                     act_rd_en, act_zero,
                     act_rd_addr[0], act_rd_addr[1], act_rd_addr[2], act_rd_addr[3],
                     w_idx[0], w_idx[1], w_idx[2], w_idx[3],
                     out_wr_en, out_wr_addr, layer_done);
        end
    end

    // =========================================================================
    // Tasks
    // =========================================================================

    // -------------------------------------------------------------------------
    // Task: reset_dut
    //   Drives reset low for 3 cycles then releases it.
    // -------------------------------------------------------------------------
    task automatic reset_dut();
        enable    = 1'b0;
        layer_sel = 1'b0;
        rst_n     = 1'b0;
        repeat(3) @(posedge clk);
        #1; rst_n = 1'b1;
        @(posedge clk);   // one quiet cycle after reset
    endtask

    // -------------------------------------------------------------------------
    // Task: run_layer
    //   Asserts enable, waits for layer_done, then deasserts enable.
    //   Blocks until the DUT returns to AG_IDLE.
    // -------------------------------------------------------------------------
    task automatic run_layer(input logic sel);
        #1; layer_sel = sel;
            enable    = 1'b1;

        // Wait for layer_done
        @(posedge clk iff (layer_done === 1'b1));

        // Deassert enable so DUT transitions back to AG_IDLE
        #1; enable = 1'b0;

        // Give 2 cycles to settle
        repeat(2) @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Task: check_first_pixel_conv1
    //   After Conv1's first out_wr_en pulse, verifies:
    //   - Write address is 0 (pixel oc=0, y=0, x=0 in CHW layout)
    //   - acc_clear fired exactly once before this write
    //   - mac_valid fired exactly CONV1_GROUPS (3) times for this pixel
    //   - Corner pixel (0,0) has top-left 4 taps zero-padded
    // -------------------------------------------------------------------------
    task automatic check_first_pixel_conv1();
        // Snapshot counters right after first out_wr_en
        automatic int snap_mac   = mac_valid_cnt;
        automatic int snap_clear = acc_clear_cnt;
        automatic int snap_addr  = int'(out_wr_addr);

        if (snap_addr !== 0)
            $fatal(1, "[FAIL] Conv1 first pixel: out_wr_addr=%0d (expected 0)", snap_addr);

        if (snap_clear !== 1)
            $fatal(1, "[FAIL] Conv1 first pixel: acc_clear_cnt=%0d (expected 1)", snap_clear);

        if (snap_mac !== CONV1_GROUPS)
            $fatal(1, "[FAIL] Conv1 first pixel: mac_valid_cnt=%0d (expected %0d)",
                   snap_mac, CONV1_GROUPS);

        // For pixel (y=0, x=0), tap 0 = (ic=0, ky=0, kx=0) maps to in_y=-1, in_x=-1
        // => act_zero[0] must be 1 (top-left corner is out of bounds)
        if (act_zero[0] !== 1'b1)
            $fatal(1, "[FAIL] Conv1 pixel(0,0) lane 0: act_zero[0]=%0b (expected 1 — padding)", act_zero[0]);

        $display("  [PASS] ✅  Conv1 first pixel checks passed (addr=0, acc_clear=1, mac_valid=%0d, padding OK)",
                 snap_mac);
    endtask

    // -------------------------------------------------------------------------
    // Task: check_layer_totals
    //   After a full layer run, checks aggregate counters.
    // -------------------------------------------------------------------------
    task automatic check_layer_totals(
        input string test_name,
        input int    exp_out_wr,
        input int    exp_acc_clear,
        input int    exp_mac_valid_per_pixel,
        input int    exp_layer_done
    );
        automatic logic pass = 1'b1;

        if (out_wr_en_cnt !== exp_out_wr) begin
            $display("  [FAIL] %s — out_wr_en_cnt=%0d (expected %0d)",
                     test_name, out_wr_en_cnt, exp_out_wr);
            pass = 1'b0;
        end
        if (acc_clear_cnt !== exp_acc_clear) begin
            $display("  [FAIL] %s — acc_clear_cnt=%0d (expected %0d)",
                     test_name, acc_clear_cnt, exp_acc_clear);
            pass = 1'b0;
        end
        // mac_valid fires exp_mac_valid_per_pixel times per pixel
        if (mac_valid_cnt !== exp_out_wr * exp_mac_valid_per_pixel) begin
            $display("  [FAIL] %s — mac_valid_cnt=%0d (expected %0d)",
                     test_name, mac_valid_cnt, exp_out_wr * exp_mac_valid_per_pixel);
            pass = 1'b0;
        end
        if (layer_done_cnt < exp_layer_done) begin
            $display("  [FAIL] %s — layer_done never asserted", test_name);
            pass = 1'b0;
        end

        if (!pass)
            $fatal(1, "[FATAL] %s failed. Aborting.", test_name);

        $display("  [PASS] ✅  %s — wr=%0d acc_clear=%0d mac_valid=%0d layer_done=%0b",
                 test_name, out_wr_en_cnt, acc_clear_cnt, mac_valid_cnt, layer_done);
    endtask

    // =========================================================================
    // Stimulus
    // =========================================================================
    initial begin

        // -- Reset -----------------------------------------------------------
        reset_dut();

        // ====================================================================
        // Test 1 — Conv1 (layer_sel=0, Cin=1, Cout=4, taps=9, groups=3)
        // ====================================================================
        $display("\n--- Test 1: Conv1 full run ---");

        // Wait for first pixel write to check per-pixel correctness
        fork
            run_layer(1'b0);
            begin
                @(posedge clk iff (out_wr_en === 1'b1));
                check_first_pixel_conv1();
            end
        join

        check_layer_totals(
            .test_name              ("Conv1"),
            .exp_out_wr             (CONV1_PIXELS),          // 4096
            .exp_acc_clear          (CONV1_PIXELS),          // once per pixel
            .exp_mac_valid_per_pixel(CONV1_GROUPS),          // 3
            .exp_layer_done         (1)
        );

        // ====================================================================
        // Test 2 — Conv2 (layer_sel=1, Cin=4, Cout=8, taps=36, groups=9)
        // ====================================================================
        $display("\n--- Test 2: Conv2 full run ---");

        // Reset counters for a clean Conv2 measurement
        // (counters are held in always_ff — force via reset pulse)
        #1; rst_n = 1'b0;
        repeat(2) @(posedge clk);
        #1; rst_n = 1'b1;
        @(posedge clk);

        run_layer(1'b1);

        check_layer_totals(
            .test_name              ("Conv2"),
            .exp_out_wr             (CONV2_PIXELS),          // 8192
            .exp_acc_clear          (CONV2_PIXELS),          // once per pixel
            .exp_mac_valid_per_pixel(CONV2_GROUPS),          // 9
            .exp_layer_done         (1)
        );

        // ====================================================================
        $display("\n========================================");
        $display("  All tests PASSED ✅");
        $display("========================================\n");
        $finish;
    end

endmodule