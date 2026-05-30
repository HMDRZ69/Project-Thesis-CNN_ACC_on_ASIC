// =============================================================================
// tb_pool_engine.sv
// =============================================================================
// Self-checking testbench for pool_engine.sv (updated for 32x32→16x16 pooling)
// Tests: basic 2×2 max-pool correctness, address mapping, done behaviour,
//        all-same values, all-zero inputs, max-value saturation.
//
// Xcelium compliance: SVAAKB, EXPRPA, MULAXX, UNDIDN, NODNTW.
// =============================================================================

`default_nettype none
`timescale 1ns/1ps

module tb_pool_engine;

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic        clk;
    logic        rst_n;
    logic        pool_start;
    logic        pool_done;
    logic [12:0] sram_rd_addr;
    logic [7:0]  sram_rd_data;
    logic [12:0] sram_wr_addr;
    logic [7:0]  sram_wr_data;
    logic        sram_wr_en;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    pool_engine dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .pool_start   (pool_start),
        .pool_done    (pool_done),
        .sram_rd_addr (sram_rd_addr),
        .sram_rd_data (sram_rd_data),
        .sram_wr_addr (sram_wr_addr),
        .sram_wr_data (sram_wr_data),
        .sram_wr_en   (sram_wr_en)
    );

    // =========================================================================
    // Clock: 10ns period (100 MHz)
    // =========================================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================================
    // Behavioural SRAM model — 8KB, 1-cycle read latency
    // =========================================================================
    logic [7:0] src_mem [0:8191];   // Conv2 output (source) - 32x32x8
    logic [7:0] dst_mem [0:8191];   // Pool output  (destination) - 16x16x8

    // Registered read (1 cycle latency)
    always_ff @(posedge clk)
        sram_rd_data <= src_mem[sram_rd_addr];

    // Capture writes
    always_ff @(posedge clk)
        if (sram_wr_en)
            dst_mem[sram_wr_addr] <= sram_wr_data;

    // =========================================================================
    // Test infrastructure
    // =========================================================================
    int pass_count;
    int fail_count;

    task automatic check(
        input string  test_name,
        input logic   cond,
        input string  msg
    );
        if (cond) begin
            $display("[PASS] %s — %s", test_name, msg);
            pass_count++;
        end else begin
            $display("[FAIL] %s — %s", test_name, msg);
            fail_count++;
        end
    endtask

    // Wait for pool_done with timeout
    task automatic wait_done(input int timeout_cycles);
        int i;
        for (i = 0; i < timeout_cycles; i++) begin
            @(posedge clk);
            if (pool_done) return;
        end
        $display("[TB] ERROR: pool_done did not assert within %0d cycles", timeout_cycles);
        fail_count++;
    endtask

    // Reference model: compute expected max-pool output for current src_mem
    // Input layout : ch*1024 + row*32 + col   (32x32 per channel)
    // Output layout: ch*256  + row*16 + col   (16x16 per channel)
    function automatic logic [7:0] ref_pool(
        input int ch_i, input int or_i, input int oc_i
    );
        logic [7:0] p0, p1, p2, p3;
        int base_in;
        base_in = ch_i * 1024;
        p0 = src_mem[base_in + (or_i*2  )*32 + (oc_i*2  )];
        p1 = src_mem[base_in + (or_i*2  )*32 + (oc_i*2+1)];
        p2 = src_mem[base_in + (or_i*2+1)*32 + (oc_i*2  )];
        p3 = src_mem[base_in + (or_i*2+1)*32 + (oc_i*2+1)];
        ref_pool = (p0 > p1) ? p0 : p1;
        ref_pool = (ref_pool > p2) ? ref_pool : p2;
        ref_pool = (ref_pool > p3) ? ref_pool : p3;
    endfunction

    // Run one full pooling pass and verify all 2048 output pixels
    task automatic run_and_verify(input string test_name);
        int ch_i, or_i, oc_i;
        logic [7:0] expected;
        logic [7:0] actual;
        int mismatch;
        int pixel_fail;

        // Clear dst_mem before each run
        for (int i = 0; i < 8192; i++) dst_mem[i] = 8'h00;

        // Return FSM to S_IDLE
        @(posedge clk); #1;
        rst_n = 1'b0;
        @(posedge clk); #1;
        rst_n = 1'b1;
        @(posedge clk); #1;

        // Pulse pool_start
        @(posedge clk); #1;
        pool_start = 1'b1;
        @(posedge clk); #1;
        pool_start = 1'b0;

        // Wait for done (2048 pixels × ~7 cycles + margin)
        wait_done(20000);

        check(test_name, pool_done, "pool_done asserted");

        // Verify all 2048 output pixels against reference model
        mismatch = 0;
        for (ch_i = 0; ch_i < 8; ch_i++) begin
            for (or_i = 0; or_i < 16; or_i++) begin
                for (oc_i = 0; oc_i < 16; oc_i++) begin
                    expected = ref_pool(ch_i, or_i, oc_i);
                    actual   = dst_mem[ch_i*256 + or_i*16 + oc_i];
                    if (actual !== expected) begin
                        if (mismatch < 4) // Limit noise
                            $display("[FAIL] %s ch=%0d r=%0d c=%0d: expected=%02x got=%02x",
                                     test_name, ch_i, or_i, oc_i, expected, actual);
                        mismatch++;
                    end
                end
            end
        end
        pixel_fail = (mismatch > 0);
        check(test_name, !pixel_fail,
              $sformatf("all 2048 output pixels correct (%0d mismatches)", mismatch));

        // Check done remains HIGH
        repeat(10) @(posedge clk);
        check(test_name, pool_done, "pool_done stays HIGH (S_DONE is a level)");
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================

    // T1: Gradient pattern — unique value per pixel
    task automatic t1_gradient();
        int addr;
        for (int i = 0; i < 8192; i++) src_mem[i] = 8'h00;
        for (int ch_i = 0; ch_i < 8; ch_i++)
            for (int r = 0; r < 32; r++)
                for (int c = 0; c < 32; c++) begin
                    addr = ch_i*1024 + r*32 + c;
                    src_mem[addr] = {r[4:0], c[4:0]};  // 5-bit row + 5-bit col
                end
        run_and_verify("T1_Gradient");
    endtask

    // T2: All zeros
    task automatic t2_all_zero();
        for (int i = 0; i < 8192; i++) src_mem[i] = 8'h00;
        run_and_verify("T2_AllZero");
    endtask

    // T3: All max (0xFF)
    task automatic t3_all_max();
        for (int i = 0; i < 8192; i++) src_mem[i] = 8'hFF;
        run_and_verify("T3_AllMax");
    endtask

    // T4: Max in bottom-right of each 2×2 window
    task automatic t4_peak_at_br();
        for (int i = 0; i < 8192; i++) src_mem[i] = 8'h10;
        for (int ch_i = 0; ch_i < 8; ch_i++)
            for (int or_i = 0; or_i < 16; or_i++)
                for (int oc_i = 0; oc_i < 16; oc_i++)
                    src_mem[ch_i*1024 + (or_i*2+1)*32 + (oc_i*2+1)] = 8'hAA;
        run_and_verify("T4_PeakAtBR");
    endtask

    // T5: Max in top-left of each 2×2 window
    task automatic t5_peak_at_tl();
        for (int i = 0; i < 8192; i++) src_mem[i] = 8'h05;
        for (int ch_i = 0; ch_i < 8; ch_i++)
            for (int or_i = 0; or_i < 16; or_i++)
                for (int oc_i = 0; oc_i < 16; oc_i++)
                    src_mem[ch_i*1024 + (or_i*2)*32 + (oc_i*2)] = 8'hBB;
        run_and_verify("T5_PeakAtTL");
    endtask

    // T6: Channel isolation
    task automatic t6_channel_isolation();
        for (int ch_i = 0; ch_i < 8; ch_i++)
            for (int r = 0; r < 32; r++)
                for (int c = 0; c < 32; c++)
                    src_mem[ch_i*1024 + r*32 + c] = 8'(ch_i * 8'd32 + 8'd1);
        run_and_verify("T6_ChannelIsolation");
    endtask

    // T7: Reset mid-run
    task automatic t7_reset_recovery();
        // Start a run, then abort with reset
        @(posedge clk); #1;
        pool_start = 1'b1;
        @(posedge clk); #1;
        pool_start = 1'b0;
        repeat(50) @(posedge clk);   // Let it run partway (increased for larger design)
        rst_n = 1'b0;
        @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check("T7_Reset", !pool_done, "pool_done de-asserted after reset");

        // Clean run
        for (int i = 0; i < 8192; i++) src_mem[i] = 8'h00;
        for (int ch_i = 0; ch_i < 8; ch_i++)
            for (int r = 0; r < 32; r++)
                for (int c = 0; c < 32; c++)
                    src_mem[ch_i*1024 + r*32 + c] = 8'(r + c);
        run_and_verify("T7_Reset_Recovery");
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        pool_start = 1'b0;
        rst_n      = 1'b0;
        for (int i = 0; i < 8192; i++) begin
            src_mem[i] = 8'h00;
            dst_mem[i] = 8'h00;
        end

        // Release reset
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        // Run all tests
        t1_gradient();
        t2_all_zero();
        t3_all_max();
        t4_peak_at_br();
        t5_peak_at_tl();
        t6_channel_isolation();
        t7_reset_recovery();

        // Final report
        $display("");
        $display("[TB] =========================================");
        $display("[TB] RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("[TB] ALL TESTS PASSED — pool_engine verified OK");
        else
            $display("[TB] FAILURES DETECTED — review log above");
        $display("[TB] =========================================");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #1000000;  // Increased timeout for larger design
        $display("[TB] TIMEOUT — simulation exceeded 1ms");
        $finish;
    end

endmodule

`default_nettype wire
// =============================================================================
// End of tb_pool_engine.sv
// =============================================================================