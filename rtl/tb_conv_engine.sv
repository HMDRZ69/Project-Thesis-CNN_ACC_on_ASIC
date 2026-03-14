// =============================================================================
// Module  : tb_conv_engine.sv
// Project : CNN Accelerator — IHP 130nm ASIC (MSc Project Thesis)
// Purpose : Self-checking testbench for conv_engine.sv
//
// Key change: conv_engine now has a 'pixel_done' input (= addr_gen out_wr_en).
//   out_valid fires ONLY on pixel_done_d1 — once per completed pixel.
//   drive_mac()     : last (or only) tap; fires pixel_done after mac_valid
//   drive_mac_tap() : intermediate tap; NO pixel_done pulse
//
//   Tests: single-tap MAC, saturation, ReLU, boundary, multi-tap (ONE
//          out_valid per pixel), acc_clear, zero, mixed-sign, addr counter,
//          reset behaviour, Run 1 + Run 2 restart.
//
// Xcelium compliance
//   - #1 drive delay after @(posedge clk)
//   - $fatal(1,"...") single-line, no concatenation (EXPRPA)
//   - No 8'sd<N> inside '{...} aggregates → 8'sh<HH> hex form (NULLU/APSNTX)
//   - Watchdog: #3_000_000 ns
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module tb_conv_engine;

    // =========================================================================
    // Parameters — match DUT defaults
    // =========================================================================
    localparam int NUM_LANES  = 4;
    localparam int ACT_WIDTH  = 8;
    localparam int WGT_WIDTH  = 8;
    localparam int ACC_WIDTH  = 32;
    localparam int OUT_WIDTH  = 8;
    localparam int ADDR_WIDTH = 16;

    localparam int CLK_HALF   = 5;   // 10 ns period = 100 MHz

    // =========================================================================
    // DUT port connections
    // =========================================================================
    logic                                     clk;
    logic                                     rst_n;
    logic                                     mac_valid;
    logic                                     acc_clear;
    logic                                     pixel_done;  // NEW: AG_WRITE strobe
    logic [NUM_LANES-1:0][ACT_WIDTH-1:0]     act_data;
    logic [NUM_LANES-1:0][WGT_WIDTH-1:0]     weight_data;
    logic [OUT_WIDTH-1:0]                     out_data;
    logic [ADDR_WIDTH-1:0]                    out_wr_addr;
    logic                                     out_valid;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    conv_engine #(
        .NUM_LANES  (NUM_LANES),
        .ACT_WIDTH  (ACT_WIDTH),
        .WGT_WIDTH  (WGT_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .OUT_WIDTH  (OUT_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .mac_valid  (mac_valid),
        .acc_clear  (acc_clear),
        .pixel_done (pixel_done),
        .act_data   (act_data),
        .weight_data(weight_data),
        .out_data   (out_data),
        .out_wr_addr(out_wr_addr),
        .out_valid  (out_valid)
    );

    // =========================================================================
    // Clock generation
    // =========================================================================
    initial clk = 1'b0;
    always #(CLK_HALF) clk = ~clk;

    // =========================================================================
    // Watchdog
    // =========================================================================
    initial begin
        #3_000_000;
        $fatal(1, "[TB] WATCHDOG TIMEOUT at t=%0t — simulation hung", $time);
    end

    // =========================================================================
    // Automatic tasks
    // =========================================================================

    // --- Reset DUT ---
    task automatic reset_dut();
        rst_n       = 1'b0;
        mac_valid   = 1'b0;
        acc_clear   = 1'b0;
        pixel_done  = 1'b0;
        act_data    = '0;
        weight_data = '0;
        repeat(4) @(posedge clk);
        #1;
        rst_n = 1'b1;
        @(posedge clk); #1;
        $display("[TB] Reset released at t=%0t", $time);
    endtask

    // --- Drive one MAC cycle then pulse pixel_done (mimics AG_WRITE) ---
    // In the real system addr_gen asserts out_wr_en (pixel_done) for 1 cycle
    // in AG_WRITE, which is the cycle AFTER the last mac_valid tap.
    // The unit TB models this as: mac_valid HIGH for 1 cycle, then
    // pixel_done HIGH for 1 cycle on the following cycle.
    task automatic drive_mac(
        input logic                                  acc_clr,
        input logic [NUM_LANES-1:0][ACT_WIDTH-1:0]  act,
        input logic [NUM_LANES-1:0][WGT_WIDTH-1:0]  wgt
    );
        @(posedge clk); #1;
        mac_valid   = 1'b1;
        acc_clear   = acc_clr;
        act_data    = act;
        weight_data = wgt;
        @(posedge clk); #1;
        mac_valid   = 1'b0;
        acc_clear   = 1'b0;
        // Pulse pixel_done for exactly 1 cycle (AG_WRITE equivalent)
        pixel_done  = 1'b1;
        @(posedge clk); #1;
        pixel_done  = 1'b0;
    endtask

    // --- Wait for out_valid and capture result ---
    task automatic wait_out(
        output logic [OUT_WIDTH-1:0]  captured_data,
        output logic [ADDR_WIDTH-1:0] captured_addr
    );
        @(posedge clk iff (out_valid === 1'b1));
        #1;
        captured_data = out_data;
        captured_addr = out_wr_addr;
    endtask

    // --- Drive intermediate tap (NO pixel_done pulse — accumulation continues) ---
    task automatic drive_mac_tap(
        input logic                                  acc_clr,
        input logic [NUM_LANES-1:0][ACT_WIDTH-1:0]  act,
        input logic [NUM_LANES-1:0][WGT_WIDTH-1:0]  wgt
    );
        @(posedge clk); #1;
        mac_valid   = 1'b1;
        acc_clear   = acc_clr;
        act_data    = act;
        weight_data = wgt;
        @(posedge clk); #1;
        mac_valid   = 1'b0;
        acc_clear   = 1'b0;
        // No pixel_done pulse — result is not final yet
    endtask

    // --- Check helper ---
    int pass_count;
    int fail_count;

    task automatic check(
        input string         test_name,
        input logic [7:0]    got,
        input logic [7:0]    expected
    );
        if (got === expected) begin
            $display("[PASS] %-30s got=0x%02X expected=0x%02X  t=%0t",
                     test_name, got, expected, $time);
            pass_count++;
        end else begin
            $display("[FAIL] %-30s got=0x%02X expected=0x%02X  t=%0t",
                     test_name, got, expected, $time);
            fail_count++;
        end
    endtask

    // =========================================================================
    // Helper: compute expected single-tap result
    //   sum = Σ (unsigned act[i] * signed wgt[i]) for i=0..3
    //   relu_sat(sum)
    // =========================================================================
    function automatic logic [7:0] expected_relu_sat(
        input logic [NUM_LANES-1:0][ACT_WIDTH-1:0] act,
        input logic [NUM_LANES-1:0][WGT_WIDTH-1:0] wgt
    );
        logic signed [ACC_WIDTH-1:0] acc;
        logic signed [ACC_WIDTH-1:0] prod;
        acc = '0;
        for (int i = 0; i < NUM_LANES; i++) begin
            prod = $signed(32'(act[i])) * $signed({{24{wgt[i][7]}}, wgt[i]});
            acc  = acc + prod;
        end
        if      (acc < 0)         return 8'h00;
        else if (acc > 32'hFF)    return 8'hFF;
        else                      return acc[7:0];
    endfunction

    // =========================================================================
    // Test variables
    // =========================================================================
    logic [OUT_WIDTH-1:0]  cap_data;
    logic [ADDR_WIDTH-1:0] cap_addr;

    logic [NUM_LANES-1:0][ACT_WIDTH-1:0] test_act;
    logic [NUM_LANES-1:0][WGT_WIDTH-1:0] test_wgt;

    logic signed [ACC_WIDTH-1:0] manual_acc;

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("============================================================");
        $display("[TB] conv_engine testbench starting");
        $display("============================================================");

        // =====================================================================
        // RUN 1
        // =====================================================================
        reset_dut();

        // ------------------------------------------------------------------
        // Test 1: Single-tap, all ones (act=1, wgt=1 → sum=4)
        // ------------------------------------------------------------------
        test_act = '{4{8'h01}};
        test_wgt = '{4{8'h01}};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T1:single_tap_all_ones", cap_data, 8'h04);
        check("T1:addr=0", cap_addr[7:0], 8'h00);

        // ------------------------------------------------------------------
        // Test 2: Single-tap, known values
        //   act={10,20,30,40}, wgt={1,2,3,4}
        //   sum = 10+40+90+160 = 300 → saturate → 255
        // ------------------------------------------------------------------
        test_act = '{8'd40, 8'd30, 8'd20, 8'd10};
        test_wgt = '{8'sh04, 8'sh03, 8'sh02, 8'sh01};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T2:saturation_300->255", cap_data, 8'hFF);
        check("T2:addr=1", cap_addr[7:0], 8'h01);

        // ------------------------------------------------------------------
        // Test 3: ReLU — negative accumulator
        //   act={10,0,0,0}, wgt={-5,0,0,0}
        //   sum = -50 → ReLU → 0
        // ------------------------------------------------------------------
        test_act = '{8'd0,  8'd0, 8'd0, 8'd10};
        test_wgt = '{8'sh00, 8'sh00, 8'sh00, 8'shFB};  // 0, 0, 0, -5 in two's complement
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T3:relu_negative->0", cap_data, 8'h00);

        // ------------------------------------------------------------------
        // Test 4: Exact boundary — act=1, wgt=1 lane0 only → sum=1
        // ------------------------------------------------------------------
        test_act = '{8'd0, 8'd0, 8'd0, 8'd1};
        test_wgt = '{8'sh00, 8'sh00, 8'sh00, 8'sh01};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T4:single_lane_sum1", cap_data, 8'h01);

        // ------------------------------------------------------------------
        // Test 5: Exact boundary — result = 255
        //   act={255,0,0,0}, wgt={1,0,0,0} → sum=255
        // ------------------------------------------------------------------
        test_act = '{8'd0, 8'd0, 8'd0, 8'd255};
        test_wgt = '{8'sh00, 8'sh00, 8'sh00, 8'sh01};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T5:exact_255", cap_data, 8'hFF);

        // ------------------------------------------------------------------
        // Test 6: Multi-tap accumulation (3 taps, one output per pixel)
        //   Models addr_gen AG_TAPS×3 → AG_WRITE sequence:
        //     Tap1 (acc_clear=1): drive_mac_tap  — no pixel_done (intermediate)
        //     Tap2 (acc_clear=0): drive_mac_tap  — no pixel_done (intermediate)
        //     Tap3 (acc_clear=0): drive_mac      — pixel_done fires → out_valid
        //
        //   Expected accumulation:
        //     Tap1: acc = 4*1*1        =  4
        //     Tap2: acc = 4 + 4*2*1   = 12
        //     Tap3: acc = 12 + 4*3*1  = 24  ← only this fires out_valid
        // ------------------------------------------------------------------

        // Tap 1 (clear, intermediate — no pixel_done)
        test_act = '{4{8'd1}};
        test_wgt = '{4{8'sh01}};
        drive_mac_tap(1'b1, test_act, test_wgt);

        // Tap 2 (accumulate, intermediate — no pixel_done)
        test_act = '{4{8'd2}};
        test_wgt = '{4{8'sh01}};
        drive_mac_tap(1'b0, test_act, test_wgt);

        // Tap 3 (accumulate, last tap — pixel_done fires → out_valid)
        test_act = '{4{8'd3}};
        test_wgt = '{4{8'sh01}};
        drive_mac(1'b0, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T6:multitap_final_24", cap_data, 8'd24);  // only ONE output for 3 taps

        // ------------------------------------------------------------------
        // Test 7: acc_clear resets accumulator — new pixel starts fresh
        //   After T6 acc=24; drive new pixel with acc_clear=1
        //   act={5,5,5,5} wgt={1,1,1,1} → sum=20 (old 24 discarded)
        // ------------------------------------------------------------------
        test_act = '{4{8'd5}};
        test_wgt = '{4{8'sh01}};
        drive_mac(1'b1, test_act, test_wgt);   // acc_clear=1 → fresh pixel
        wait_out(cap_data, cap_addr);
        check("T7:acc_clear_resets", cap_data, 8'd20);

        // ------------------------------------------------------------------
        // Test 8: Zero inputs after clear → output must be 0
        // ------------------------------------------------------------------
        test_act = '{4{8'd0}};
        test_wgt = '{4{8'sh00}};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T8:zero_inputs", cap_data, 8'h00);

        // ------------------------------------------------------------------
        // Test 9: Mixed sign weights
        //   act={10,10,10,10} wgt={+3,-1,+2,-4} → sum=10*(3-1+2-4)=10*0=0
        // ------------------------------------------------------------------
        test_act = '{4{8'd10}};
        test_wgt = '{8'shFC, 8'sh02, 8'shFF, 8'sh03};  // -4, +2, -1, +3 in two's complement
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T9:mixed_signs_zero", cap_data, 8'h00);

        // ------------------------------------------------------------------
        // Test 10: Address counter continuity
        //   Outputs so far: T1(0) T2(1) T3(2) T4(3) T5(4)
        //                   T6(5, one output for 3 taps) T7(6) T8(7) T9(8)
        //   T10 will be output #9 → addr=9
        // ------------------------------------------------------------------
        test_act = '{4{8'd1}};
        test_wgt = '{4{8'sh01}};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("T10:addr_counter_check", cap_addr[7:0], 8'd9);

        $display("------------------------------------------------------------");
        $display("[TB] RUN 1 COMPLETE");
        $display("------------------------------------------------------------");

        // =====================================================================
        // RUN 2 — restart (reset DUT, verify clean state, re-run key tests)
        // =====================================================================
        $display("[TB] Starting RUN 2 (restart)");
        reset_dut();

        // After reset: out_wr_addr must be 0
        // Drive one pixel and check addr restarted
        test_act = '{4{8'd2}};
        test_wgt = '{4{8'sh02}};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        // sum = 4*(2*2)=16
        check("R2:T1:basic_mac", cap_data, 8'd16);
        check("R2:T1:addr_reset_to_0", cap_addr[7:0], 8'h00);

        // ReLU again after restart
        test_act = '{8'd0, 8'd0, 8'd0, 8'd5};
        test_wgt = '{8'sh00, 8'sh00, 8'sh00, 8'shFD};  // 0, 0, 0, -3 in two's complement
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        check("R2:T2:relu_after_reset", cap_data, 8'h00);

        // Saturation after restart
        test_act = '{4{8'd128}};
        test_wgt = '{4{8'sh02}};
        drive_mac(1'b1, test_act, test_wgt);
        wait_out(cap_data, cap_addr);
        // sum = 4*128*2 = 1024 → saturate → 255
        check("R2:T3:sat_after_reset", cap_data, 8'hFF);

        $display("------------------------------------------------------------");
        $display("[TB] RUN 2 COMPLETE");
        $display("------------------------------------------------------------");

        // =====================================================================
        // Summary
        // =====================================================================
        $display("============================================================");
        $display("[TB] RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================================");

        if (fail_count > 0)
            $fatal(1, "[TB] SIMULATION FAILED — %0d test(s) failed", fail_count);
        else
            $display("[TB] ALL TESTS PASSED — conv_engine verified OK");

        $finish;
    end

endmodule : tb_conv_engine

`default_nettype wire
// =============================================================================
// End of tb_conv_engine.sv
// =============================================================================
