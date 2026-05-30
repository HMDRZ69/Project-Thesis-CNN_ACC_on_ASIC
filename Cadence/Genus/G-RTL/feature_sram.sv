`default_nettype none
// =============================================================================
//  feature_sram.sv — Single-port 8192×8 SRAM wrapper
//  Wraps two IHP SG13G2 RM_IHPSG13_1P_4096x8_c3_bm_bist macros.
//
//  Memory map:
//    addr[12]  = 0  → lower macro (rows    0–4095)
//    addr[12]  = 1  → upper macro (rows 4096–8191)
//
//  Port interface is identical to the behavioural feature_sram.sv —
//  cnn_top.sv requires NO changes.
//
//  Parameters
//    DEPTH  : total word count  (must be 8192)
//    ADDR_W : address bus width (must be 13)
//    DATA_W : data bus width    (must be 8)
// =============================================================================

module feature_sram #(
    parameter int DEPTH  = 8192,
    parameter int ADDR_W = 13,
    parameter int DATA_W = 8
)(
    input  wire               clk,
    input  wire               wr_en,
    input  wire [ADDR_W-1:0]  addr,
    input  wire [DATA_W-1:0]  wdata,
    output wire [DATA_W-1:0]  rdata
);

`ifndef SYNTHESIS
    initial begin
        if (DEPTH != 8192 || ADDR_W != 13 || DATA_W != 8)
            $fatal(1, "feature_sram: only DEPTH=8192 ADDR_W=13 DATA_W=8 supported with macro");
    end
`endif

    // -------------------------------------------------------------------------
    //  Internal signals
    // -------------------------------------------------------------------------

    // addr[12] selects upper (1) or lower (0) macro
    wire        bank_sel  = addr[ADDR_W-1];          // bit 12
    wire [11:0] mac_addr  = addr[ADDR_W-2:0];        // bits [11:0] → 4096 rows

    // Read-enable and write-enable per macro
    // A_MEN = memory enable (active high), A_REN = read enable, A_WEN = write enable
    // Only the selected bank gets active enables
    wire lower_men = ~bank_sel;          // lower macro enabled when bank_sel=0
    wire upper_men =  bank_sel;          // upper macro enabled when bank_sel=1

    wire lower_wen = lower_men & wr_en;
    wire upper_wen = upper_men & wr_en;

    wire lower_ren = lower_men & ~wr_en;
    wire upper_ren = upper_men & ~wr_en;

    // Macro read outputs
    wire [DATA_W-1:0] lower_dout;
    wire [DATA_W-1:0] upper_dout;

    // -------------------------------------------------------------------------
    //  Output mux — registered bank_sel to align with macro read latency
    //  IHP macro has 1-cycle read latency (clocked SRAM)
    // -------------------------------------------------------------------------
    reg bank_sel_d1;
    always_ff @(posedge clk)
        bank_sel_d1 <= bank_sel;

    assign rdata = bank_sel_d1 ? upper_dout : lower_dout;

    // -------------------------------------------------------------------------
    //  BIST ports — tied off (not used in this design)
    //  A_BIST_EN = 0 disables BIST; all other BIST inputs held at safe values
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    //  Lower macro: addresses 0–4095
    // -------------------------------------------------------------------------
    RM_IHPSG13_1P_4096x8_c3_bm_bist u_lower (
        .A_CLK      (clk),
        .A_MEN      (lower_men),
        .A_WEN      (lower_wen),
        .A_REN      (lower_ren),
        .A_ADDR     (mac_addr),
        .A_DIN      (wdata),
        .A_DLY      (1'b0),
        .A_DOUT     (lower_dout),
        .A_BM       (8'hFF),        // all bits unmasked (write all)
        // BIST — disabled
        .A_BIST_CLK (1'b0),
        .A_BIST_EN  (1'b0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_ADDR(12'b0),
        .A_BIST_DIN (8'b0),
        .A_BIST_BM  (8'b0)
    );

    // -------------------------------------------------------------------------
    //  Upper macro: addresses 4096–8191
    // -------------------------------------------------------------------------
    RM_IHPSG13_1P_4096x8_c3_bm_bist u_upper (
        .A_CLK      (clk),
        .A_MEN      (upper_men),
        .A_WEN      (upper_wen),
        .A_REN      (upper_ren),
        .A_ADDR     (mac_addr),
        .A_DIN      (wdata),
        .A_DLY      (1'b0),
        .A_DOUT     (upper_dout),
        .A_BM       (8'hFF),
        // BIST — disabled
        .A_BIST_CLK (1'b0),
        .A_BIST_EN  (1'b0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_ADDR(12'b0),
        .A_BIST_DIN (8'b0),
        .A_BIST_BM  (8'b0)
    );

endmodule
`default_nettype wire