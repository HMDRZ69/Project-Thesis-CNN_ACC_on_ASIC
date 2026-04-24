// =============================================================================
// cnn_top.sv
//
// Top-level integration of the CNN accelerator pipeline.
// Replaces cnn_top_integ.sv as the single definitive top module.
//
// Integration status:
//   [x] controller_fsm       — fully connected
//   [x] addr_gen             — fully connected, all 4 lane addresses driven
//   [x] feature_sram A/B     — fully connected (lane 0 read; lanes 1-3 TODO)
//   [x] weight_rom           — 4 instances, one per MAC lane
//   [x] conv_engine          — real MAC engine, replaces conv_engine_stub
//   [ ] pool_engine          — not yet instantiated (pool_done stub active)
//   [ ] Lanes 1-3 SRAM reads — single-port SRAM; multi-port banking TODO
//
// Key timing notes:
//   conv_engine has 1-cycle MAC latency:
//     mac_valid → acc_reg updated on next posedge → out_valid pulses 1 later
//   SRAM writes are gated by conv_out_valid (conv_engine output), NOT by
//   out_wr_en from addr_gen, to guarantee data and write-enable are aligned.
//
// Ping-pong SRAM:
//   src_sel / read_bank_sel  → which bank to READ activations from
//   dst_sel / write_bank_sel → which bank to WRITE conv results to
//   controller_fsm manages swap between Conv1 and Conv2.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module cnn_top (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done
);

    // =========================================================================
    // Layer encoding (for future use / debug display)
    // =========================================================================
    localparam logic [1:0] LAYER_CONV1 = 2'd0;
    localparam logic [1:0] LAYER_CONV2 = 2'd1;
    localparam logic [1:0] LAYER_POOL  = 2'd2;

    // =========================================================================
    // Controller FSM signals
    // =========================================================================
    logic conv_start;
    logic pool_start;
    logic layer_sel;      // 0=Conv1, 1=Conv2 (1-bit matches controller_fsm)
    logic mode_sel;       // 0=Conv, 1=Pool
    logic src_sel;        // ping-pong read  bank: 0=SRAM A, 1=SRAM B
    logic dst_sel;        // ping-pong write bank: 0=SRAM A, 1=SRAM B
    logic conv_done;
    logic pool_done;

    assign pool_done = 1'b0;   // stub — pool_engine not yet instantiated

    // =========================================================================
    // addr_gen signals
    // =========================================================================
    logic             mac_valid;
    logic             acc_clear;
    logic [3:0]       act_rd_en;
    logic [3:0]       act_zero;
    logic [3:0][15:0] act_rd_addr;
    logic [3:0][8:0]  w_idx;
    logic [3:0]       w_rd_en;
    logic             out_wr_en;      // addr_gen write strobe (1 cycle per pixel)
    logic [15:0]      out_wr_addr;    // addr_gen write address (CHW)
    logic             layer_done;

    // =========================================================================
    // ag_enable SR-register with edge detection
    //
    // layer_done is a LEVEL held high while addr_gen is in AG_DONE state.
    // Using only its rising edge (layer_done_pulse) prevents the deadlock
    // where ag_enable can never re-assert for Conv2.
    // conv_start is delayed 1 cycle (conv_start_d1) so set and clear
    // never compete in the same clock cycle.
    // =========================================================================
    logic layer_done_d1;
    logic layer_done_pulse;
    logic conv_start_d1;
    logic ag_enable;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            layer_done_d1 <= 1'b0;
            conv_start_d1 <= 1'b0;
        end else begin
            layer_done_d1 <= layer_done;
            conv_start_d1 <= conv_start;
        end
    end

    assign layer_done_pulse = layer_done & ~layer_done_d1;
    assign conv_done        = layer_done_pulse;  // pulse only — prevents FSM skipping Conv2

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ag_enable <= 1'b0;
        else if (layer_done_pulse)
            ag_enable <= 1'b0;
        else if (conv_start_d1)
            ag_enable <= 1'b1;
    end

    // =========================================================================
    // Ping-pong bank selection
    // =========================================================================
    logic read_bank_sel;
    logic write_bank_sel;

    assign read_bank_sel  = src_sel;
    assign write_bank_sel = dst_sel;

    // =========================================================================
    // SRAM parameters
    // =========================================================================
    localparam int AW = 13;   // 8 KB → 8192 locations → 13-bit address

    // =========================================================================
    // Controller FSM instantiation
    // =========================================================================
    controller_fsm u_ctrl (
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

    // Pool start warning — stub active
    // synthesis translate_off
    always_ff @(posedge clk) begin
        if (rst_n && pool_start)
            $display("[WARN] cnn_top t=%0t: pool_start asserted — pool_done must be driven by testbench stub.", $time);
    end
    // synthesis translate_on

    // =========================================================================
    // addr_gen instantiation
    // =========================================================================
    addr_gen u_ag (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (ag_enable),
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

    // =========================================================================
    // Weight ROM — 4 instances, one per MAC lane
    //
    // Each instance is a simple combinational ROM (no clock).
    // w_idx[lane] from addr_gen indexes into the shared weight table;
    // the ROM itself is replicated 4× to provide 4 simultaneous reads.
    // =========================================================================
    logic signed [7:0] weight_data [4];   // weight_data[lane]

    generate
        genvar gi;
        for (gi = 0; gi < 4; gi++) begin : g_weight_rom
            weight_rom #(
                .ADDR_W(9)
            ) u_weight_rom (
                .index (w_idx[gi]),
                .weight(weight_data[gi])
            );
        end
    endgenerate

    // =========================================================================
    // SRAM read routing
    //
    // Single-port SRAM: only lane 0 reads are connected to the real SRAM.
    // Lanes 1-3 are tied to zero until a multi-port banking scheme is added.
    //
    // TODO: To fully utilise the 4-lane MAC, either:
    //   (a) instantiate 4 independent single-port SRAMs (banked by channel), or
    //   (b) use a multi-port SRAM model, or
    //   (c) serialise reads over 4 cycles and buffer results.
    // =========================================================================
    logic          lane0_rd_en;
    logic [AW-1:0] lane0_rd_addr;

    assign lane0_rd_en   = act_rd_en[0] & ~act_zero[0];
    assign lane0_rd_addr = act_rd_addr[0][AW-1:0];

    // =========================================================================
    // SRAM write routing
    //
    // conv_engine outputs are registered — conv_out_valid / conv_out_data /
    // conv_out_wr_addr are already 1-cycle delayed relative to mac_valid.
    // SRAM write-enable is gated by conv_out_valid (NOT out_wr_en from
    // addr_gen) to guarantee data and write-enable arrive in the same cycle.
    // =========================================================================
    logic [7:0]    conv_out_data;
    logic [15:0]   conv_out_wr_addr;
    logic          conv_out_valid;

    logic          sram_a_we,    sram_b_we;
    logic [AW-1:0] sram_a_addr,  sram_b_addr;
    logic [7:0]    sram_a_wdata, sram_b_wdata;
    logic [7:0]    sram_a_rdata, sram_b_rdata;

    // SRAM A — active when it is the read OR write target
    assign sram_a_we    = (write_bank_sel == 1'b0) ? conv_out_valid : 1'b0;
    assign sram_a_addr  = (write_bank_sel == 1'b0) ? conv_out_wr_addr[AW-1:0] :
                          (read_bank_sel  == 1'b0) ? lane0_rd_addr             :
                                                     {AW{1'b0}};
    assign sram_a_wdata = conv_out_data;

    // SRAM B — active when it is the read OR write target
    assign sram_b_we    = (write_bank_sel == 1'b1) ? conv_out_valid : 1'b0;
    assign sram_b_addr  = (write_bank_sel == 1'b1) ? conv_out_wr_addr[AW-1:0] :
                          (read_bank_sel  == 1'b1) ? lane0_rd_addr             :
                                                     {AW{1'b0}};
    assign sram_b_wdata = conv_out_data;

    // =========================================================================
    // Feature SRAM A instantiation
    // =========================================================================
    feature_sram #(
        .DEPTH (8192),
        .ADDR_W(AW)
    ) u_sram_a (
        .clk  (clk),
        .we   (sram_a_we),
        .addr (sram_a_addr),
        .wdata(sram_a_wdata),
        .rdata(sram_a_rdata)
    );

    // =========================================================================
    // Feature SRAM B instantiation
    // =========================================================================
    feature_sram #(
        .DEPTH (8192),
        .ADDR_W(AW)
    ) u_sram_b (
        .clk  (clk),
        .we   (sram_b_we),
        .addr (sram_b_addr),
        .wdata(sram_b_wdata),
        .rdata(sram_b_rdata)
    );

    // =========================================================================
    // Activation read-data selection — active read bank feeds the datapath
    // Lane 0 only; lanes 1-3 zero until multi-port SRAM is implemented.
    // =========================================================================
    logic [3:0][7:0] act_data;   // packed 4-lane activation bus to conv_engine

    assign act_data[0] = (read_bank_sel == 1'b0) ? sram_a_rdata : sram_b_rdata;
    assign act_data[1] = 8'h00;  // TODO: lane 1 SRAM read
    assign act_data[2] = 8'h00;  // TODO: lane 2 SRAM read
    assign act_data[3] = 8'h00;  // TODO: lane 3 SRAM read

    // =========================================================================
    // conv_engine instantiation — real 4-lane MAC, replaces conv_engine_stub
    //
    // Port mapping:
    //   mac_valid    ← addr_gen: HIGH in AG_TAPS (every tap group)
    //   acc_clear    ← addr_gen: HIGH on first tap group of each pixel
    //   pixel_done   ← addr_gen: out_wr_en HIGH once per completed pixel
    //                  (AG_WRITE state, 1 cycle after last mac_valid tap)
    //   act_data     ← SRAM read-data (lane 0 real, lanes 1-3 zero TODO)
    //   weight_data  ← weight_rom[0..3] combinational outputs
    //   out_data     → conv_out_data    → sram_*_wdata
    //   out_wr_addr  → conv_out_wr_addr → sram_*_addr (write path)
    //   out_valid    → conv_out_valid   → sram_*_we (1 pulse per pixel)
    // =========================================================================
    logic signed [3:0][7:0] ce_weight_data;

    // Pack weight_data array into packed type expected by conv_engine
    generate
        genvar gj;
        for (gj = 0; gj < 4; gj++) begin : g_weight_pack
            assign ce_weight_data[gj] = weight_data[gj];
        end
    endgenerate

    conv_engine #(
        .NUM_LANES  (4),
        .ACT_WIDTH  (8),
        .WGT_WIDTH  (8),
        .ACC_WIDTH  (32),
        .OUT_WIDTH  (8),
        .ADDR_WIDTH (16)
    ) u_conv_engine (
        .clk        (clk),
        .rst_n      (rst_n),
        .mac_valid  (mac_valid),
        .acc_clear  (acc_clear),
        .pixel_done (out_wr_en),    // AG_WRITE strobe: 1 cycle per completed pixel
        .act_data   (act_data),
        .weight_data(ce_weight_data),
        .out_data   (conv_out_data),
        .out_wr_addr(conv_out_wr_addr),
        .out_valid  (conv_out_valid)
    );

    // =========================================================================
    // Pool done stub
    // Testbench must use force/release to pulse pool_done when pool_start fires.
    // Remove once pool_engine.sv is instantiated.
    // =========================================================================

    // =========================================================================
    // Debug monitor — compile with +define+VERBOSE to enable per-cycle output
    // WARNING: produces ~86 000 lines per full run — off by default
    // synthesis translate_off
    // =========================================================================
    `ifdef VERBOSE
    always_ff @(posedge clk) begin
        if (rst_n && mac_valid)
            $display("[%0t ns] mac_valid layer=%0b acc_clear=%0b act[0]=0x%02h wgt[0]=0x%02h",
                     $time, layer_sel, acc_clear, act_data[0], weight_data[0]);
        if (rst_n && conv_out_valid)
            $display("[%0t ns] conv_out_valid out_data=0x%02h wr_addr=%0d",
                     $time, conv_out_data, conv_out_wr_addr);
    end
    `endif // VERBOSE
    // synthesis translate_on

endmodule : cnn_top

`default_nettype wire
// =============================================================================
// End of cnn_top.sv
// =============================================================================