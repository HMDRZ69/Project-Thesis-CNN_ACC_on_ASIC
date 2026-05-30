// =============================================================================
// cnn_top_integ.sv
//
// Top-level integration of the CNN accelerator pipeline.
//
// Current integration status (phased bring-up):
//   [x] controller_fsm   — fully connected
//   [x] addr_gen         — fully connected (all 4 lanes generated)
//   [x] feature_sram_model A/B — read port connected (lane 0 only)
//   [ ] MAC / accumulator       — not yet instantiated
//   [ ] Pooling engine          — not yet instantiated (pool_done tied low)
//   [ ] SRAM write ports        — not yet connected (tied to zero)
//   [ ] Lanes 1–3 SRAM reads    — not yet connected (tied to zero)
//
// Known limitations:
//   - pool_done is permanently 0; FSM will never leave S_POOL.
//     An assertion fires if pool_start is ever asserted.
//   - Only activation lane 0 reads SRAM A/B; lanes 1–3 are ignored.
// =============================================================================

`timescale 1ns/1ps

module cnn_top_integ (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done
);

    // =========================================================================
    // Controller FSM signals
    // =========================================================================
    logic conv_start;
    logic pool_start;
    logic layer_sel;
    logic mode_sel;
    logic src_sel;
    logic dst_sel;
    logic conv_done;
    logic pool_done;

    assign pool_done = 1'b0;

    // =========================================================================
    // addr_gen signals — declared before ag_enable to avoid forward references
    // =========================================================================
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

    // =========================================================================
    // Controller FSM
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

    // synthesis translate_off
    always_ff @(posedge clk) begin
        if (rst_n && pool_start)
            $display("[WARN] cnn_top_integ: pool_start at %0t ns — pool_done must be driven by testbench stub.", $time);
    end
    // synthesis translate_on

    // =========================================================================
    // ag_enable SR-register with edge detection
    //
    // layer_done is a LEVEL held high while addr_gen is in AG_DONE.
    // Using it directly to clear ag_enable causes a deadlock.
    // Using only its rising edge (layer_done_pulse) breaks the deadlock:
    //   - ag_enable clears for exactly 1 cycle
    //   - addr_gen sees enable=0, exits AG_DONE, layer_done goes low
    //   - conv_start_d1 then sets ag_enable for the next layer
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

    // layer_done_pulse: single-cycle rising edge — used for BOTH:
    //   1. clearing ag_enable
    //   2. signalling conv_done to the FSM
    assign layer_done_pulse = layer_done & ~layer_done_d1;

    // conv_done must be a pulse — if it's a level, FSM skips Conv2
    // because layer_done is still high when FSM enters S_CONV2
    assign conv_done = layer_done_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ag_enable <= 1'b0;
        else if (layer_done_pulse)
            ag_enable <= 1'b0;
        else if (conv_start_d1)
            ag_enable <= 1'b1;
    end

    // =========================================================================
    // addr_gen
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
    // Feature SRAM A/B (8 KB each)
    // =========================================================================
    localparam int DEPTH = 8192;
    localparam int AW    = 13;

    logic          sramA_rd_en,   sramB_rd_en;
    logic [AW-1:0] sramA_rd_addr, sramB_rd_addr;
    logic [7:0]    sramA_rd_data, sramB_rd_data;

    logic          sramA_wr_en,   sramB_wr_en;
    logic [AW-1:0] sramA_wr_addr, sramB_wr_addr;
    logic [7:0]    sramA_wr_data, sramB_wr_data;

    assign sramA_wr_en   = 1'b0;
    assign sramA_wr_addr = '0;
    assign sramA_wr_data = '0;
    assign sramB_wr_en   = 1'b0;
    assign sramB_wr_addr = '0;
    assign sramB_wr_data = '0;

    logic          lane0_rd_en;
    logic [AW-1:0] lane0_rd_addr;

    assign lane0_rd_en   = act_rd_en[0] & ~act_zero[0];
    assign lane0_rd_addr = act_rd_addr[0][AW-1:0];

    assign sramA_rd_en   = (src_sel == 1'b0) ? lane0_rd_en   : 1'b0;
    assign sramA_rd_addr = (src_sel == 1'b0) ? lane0_rd_addr : '0;
    assign sramB_rd_en   = (src_sel == 1'b1) ? lane0_rd_en   : 1'b0;
    assign sramB_rd_addr = (src_sel == 1'b1) ? lane0_rd_addr : '0;

    feature_sram_model #(.DEPTH(DEPTH), .ADDR_W(AW)) u_sramA (
        .clk    (clk),
        .rd_en  (sramA_rd_en),
        .rd_addr(sramA_rd_addr),
        .rd_data(sramA_rd_data),
        .wr_en  (sramA_wr_en),
        .wr_addr(sramA_wr_addr),
        .wr_data(sramA_wr_data)
    );

    feature_sram_model #(.DEPTH(DEPTH), .ADDR_W(AW)) u_sramB (
        .clk    (clk),
        .rd_en  (sramB_rd_en),
        .rd_addr(sramB_rd_addr),
        .rd_data(sramB_rd_data),
        .wr_en  (sramB_wr_en),
        .wr_addr(sramB_wr_addr),
        .wr_data(sramB_wr_data)
    );

endmodule