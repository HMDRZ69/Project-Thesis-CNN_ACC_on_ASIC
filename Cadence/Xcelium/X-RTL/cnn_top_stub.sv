// =============================================================================
// cnn_top.sv
//
// Top-level integration of the CNN accelerator pipeline.
// Replaces cnn_top_integ.sv as the single definitive top module.
//
// Adds over cnn_top_integ:
//   - weight_rom instantiation
//   - Explicit ping-pong bank routing via read_bank_sel / write_bank_sel
//   - Unified feature_sram interface (single we/addr port)
//
// Integration status:
//   [x] controller_fsm       — fully connected
//   [x] addr_gen             — fully connected (lane 0 read only)
//   [x] feature_sram A/B     — fully connected
//   [x] weight_rom           — fully connected
//   [ ] conv_engine          — not yet instantiated (debug hooks ready)
//   [ ] pool_engine          — not yet instantiated (pool_done stub active)
//   [ ] Lanes 1-3 SRAM reads — not yet connected
//   [ ] SRAM write from MAC  — dummy_wdata placeholder active
// =============================================================================

`timescale 1ns/1ps

module cnn_top (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done
);

    // =========================================================================
    // Layer encoding
    // =========================================================================
    localparam logic [1:0] LAYER_CONV1 = 2'd0;
    localparam logic [1:0] LAYER_CONV2 = 2'd1;
    localparam logic [1:0] LAYER_POOL  = 2'd2;

    // =========================================================================
    // Controller FSM signals
    // =========================================================================
    logic conv_start;
    logic pool_start;
    logic layer_sel;      // 1-bit: 0=Conv1, 1=Conv2 (matches verified FSM)
    logic mode_sel;       // 0=Conv, 1=Pool
    logic src_sel;        // ping-pong read  bank: 0=SRAM A, 1=SRAM B
    logic dst_sel;        // ping-pong write bank: 0=SRAM A, 1=SRAM B
    logic conv_done;
    logic pool_done;

    assign pool_done = 1'b0;   // stub — pool engine not yet instantiated

    // =========================================================================
    // addr_gen signals
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
    // ag_enable SR-register with edge detection
    // (ported from verified cnn_top_integ.sv)
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

    // declare pulse FIRST
    assign layer_done_pulse = layer_done & ~layer_done_d1;
    // Then assign conv_done - layer_done_pulse now exists
    assign conv_done = layer_done_pulse;   // pulse only — prevents FSM skipping Conv2

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
    //
    // Uses src_sel/dst_sel from controller_fsm (already manages ping-pong).
    // read_bank_sel  = src_sel  (0=read SRAM A, 1=read SRAM B)
    // write_bank_sel = dst_sel  (0=write SRAM A, 1=write SRAM B)
    // =========================================================================
    logic read_bank_sel;
    logic write_bank_sel;

    assign read_bank_sel  = src_sel;
    assign write_bank_sel = dst_sel;

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
            $display("[WARN] cnn_top: pool_start at %0t ns — pool_done must be driven by testbench stub.", $time);
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
    // [O] conv_engine_stub localparams and signals
    // =========================================================================
    localparam int CE_LANES  = 4;
    localparam int CE_ACT_W  = 8;
    localparam int CE_WGT_W  = 8;
    localparam int CE_ACC_W  = 32;
    localparam int CE_ADDR_W = 16;

    logic                                      conv_mac_valid;
    logic                                      conv_acc_clear;
    logic                                      conv_out_enable;
    logic                                      conv_relu_enable;
    logic [CE_LANES-1:0][CE_ACT_W-1:0]        conv_act_data;
    logic [CE_LANES-1:0]                       conv_act_zero_mask;
    logic signed [CE_LANES-1:0][CE_WGT_W-1:0] conv_weight_data;
    logic                                      conv_out_valid;
    logic [CE_ACT_W-1:0]                       conv_out_data;
    logic [CE_ADDR_W-1:0]                      conv_out_wr_addr;
    logic signed [CE_ACC_W-1:0]                conv_acc_debug;

    // =========================================================================
    // SRAM routing
    //
    // Lane 0 only connected for reads (lanes 1-3 TODO).
    // Dummy write data active (TODO: replace with conv/pool engine output).
    // Write-before-read priority maintained within feature_sram itself.
    // =========================================================================
    localparam int AW = 13;

    logic          sram_a_we,   sram_b_we;
    logic [AW-1:0] sram_a_addr, sram_b_addr;
    logic [7:0]    sram_a_wdata, sram_b_wdata;
    logic [7:0]    sram_a_rdata, sram_b_rdata;

    // Lane 0 read address (valid only when not zero-padded)
    logic          lane0_rd_en;
    logic [AW-1:0] lane0_rd_addr;

    assign lane0_rd_en   = act_rd_en[0] & ~act_zero[0];
    assign lane0_rd_addr = act_rd_addr[0][AW-1:0];


    // SRAM A — active when it is the read OR write target
    assign sram_a_we    = (write_bank_sel == 1'b0) ? out_wr_en   : 1'b0;
    assign sram_a_addr = (write_bank_sel == 1'b0) ? conv_out_wr_addr[AW-1:0] :
                          (read_bank_sel  == 1'b0) ? lane0_rd_addr        :
                                                     {AW{1'b0}};
    assign sram_a_wdata = conv_out_data;

    // SRAM B — active when it is the read OR write target
    assign sram_b_we    = (write_bank_sel == 1'b1) ? out_wr_en   : 1'b0;
    assign sram_b_addr = (write_bank_sel == 1'b1) ? conv_out_wr_addr[AW-1:0] :
                          (read_bank_sel  == 1'b1) ? lane0_rd_addr        :
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
    // Read data selection — active read bank feeds the datapath
    // =========================================================================
    logic [7:0] act_data_selected;
    assign act_data_selected = (read_bank_sel == 1'b0) ? sram_a_rdata
                                                       : sram_b_rdata;

    // =========================================================================
    // Weight ROM instantiation
    // w_idx[0] feeds lane 0 (lanes 1-3 TODO)
    // =========================================================================
    logic signed [7:0] weight_data;

    weight_rom #(
        .ADDR_W(9)
    ) u_weight_rom (
        .index (w_idx[0]),
        .weight(weight_data)
    );

    // =========================================================================
    // [P] conv_engine_stub control wiring
    // =========================================================================
    assign conv_mac_valid        = mac_valid;
    assign conv_acc_clear        = acc_clear;
    assign conv_out_enable       = out_wr_en;
    assign conv_relu_enable      = 1'b1;

    // Lane 0 — connected to verified addr_gen + weight_rom outputs
    assign conv_act_data[0]      = act_data_selected;
    assign conv_act_zero_mask[0] = act_zero[0];
    assign conv_weight_data[0]   = weight_data;

    // Lanes 1-3 — tied off until 4-lane reads are connected (TODO)
    generate
        genvar gi;
        for (gi = 1; gi < CE_LANES; gi++) begin : g_lane_tieoff
            assign conv_act_data[gi]      = '0;
            assign conv_act_zero_mask[gi] = 1'b1;
            assign conv_weight_data[gi]   = '0;
        end
    endgenerate

    // =========================================================================
    // [Q] conv_engine_stub instantiation
    // =========================================================================
    conv_engine_stub #(
        .ACT_W (CE_ACT_W),
        .WGT_W (CE_WGT_W),
        .ACC_W (CE_ACC_W),
        .LANES (CE_LANES),
        .ADDR_W(CE_ADDR_W)
    ) u_conv_engine (
        .clk          (clk),
        .rst_n        (rst_n),
        .mac_valid    (conv_mac_valid),
        .acc_clear    (conv_acc_clear),
        .out_enable   (conv_out_enable),
        .relu_enable  (conv_relu_enable),
        .wr_addr_in   (out_wr_addr),
        .act_data     (conv_act_data),
        .act_zero_mask(conv_act_zero_mask),
        .weight_data  (conv_weight_data),
        .out_valid    (conv_out_valid),
        .out_data     (conv_out_data),
        .out_wr_addr  (conv_out_wr_addr),
        .acc_debug    (conv_acc_debug)
    );

    // =========================================================================
    // Pool done stub — testbench forces pool_done via hierarchical force
    // Remove this block once pool_engine is instantiated
    // =========================================================================

    // =========================================================================
    // Debug hooks — connect to conv_engine in next step
    //
    // TODO:
    //   act_data_selected → conv_engine activation input
    //   weight_data       → conv_engine weight input
    //   mac_valid         → conv_engine mac_valid
    //   acc_clear         → conv_engine acc_clear
    //   act_zero[0]       → conv_engine pad_zero
    // =========================================================================
    // synthesis translate_off
    always_ff @(posedge clk) begin
        if (rst_n && mac_valid)
            $display("[%0t ns] mac_valid=1 layer=%0b acc_clear=%0b act=0x%02h weight=0x%02h wr=%0b wr_addr=%0d",
                     $time, layer_sel, acc_clear,
                     act_data_selected, weight_data,
                     out_wr_en, out_wr_addr);
    end
    // synthesis translate_on

endmodule