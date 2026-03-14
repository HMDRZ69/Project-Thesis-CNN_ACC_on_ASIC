// =============================================================================
// Module  : conv_engine.sv
// Project : CNN Accelerator — IHP 130nm ASIC (MSc Project Thesis)
// Purpose : 4-lane parallel MAC engine with 32-bit signed accumulator,
//           inline ReLU, 8-bit saturation, and write-address tracking.
//
// Fixed-point convention
//   act_data    : 8-bit UNSIGNED  — feature map activations
//   weight_data : 8-bit SIGNED   — conv weights
//   accumulator : 32-bit SIGNED  — full-precision MAC result
//   out_data    : 8-bit UNSIGNED — ReLU + saturate to [0, 255]
//
// Timing (pipeline latency = 2 cycles from mac_valid to out_valid)
//
//   Cycle N  : mac_valid=1, last tap of pixel N
//              acc_next = acc_reg + lane_sum  (final accumulation)
//   Cycle N+1: addr_gen enters AG_WRITE: out_wr_en=1 → pixel_done=1
//              acc_reg = final accumulated value (registered from N)
//              addr_cnt increments (pre-increment: 0xFFFF→0x0000 first pixel)
//   Cycle N+2: pixel_done_d1=1 → out_valid=1
//              out_data = relu_sat(acc_reg)  ← final value ✓
//              out_wr_addr = addr_cnt        ← stable, correct ✓
//
// pixel_done input:
//   Connected to addr_gen's out_wr_en output (HIGH for exactly 1 cycle
//   per completed output pixel, in AG_WRITE state, one cycle after the
//   last mac_valid tap group). This is the authoritative "pixel complete"
//   signal — it fires exactly once per output pixel regardless of kernel
//   size or number of tap groups.
//
// Write-address tracking
//   addr_cnt initialised to 0xFFFF so first pixel_done wraps it to 0x0000,
//   which is the correct address when out_valid fires one cycle later.
//   Width 16 bits supports 65536 locations (>>16×16×8=2048 needed).
//
// Lint / Xcelium compliance
//   - Signals declared before first use (UNDIDN)
//   - No multi-line $fatal (EXPRPA)
//   - No assert...else $fatal (SVAAKB)
//   - No initial block sharing register with always_ff (MULAXX)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module conv_engine #(
    parameter int NUM_LANES   = 4,
    parameter int ACT_WIDTH   = 8,
    parameter int WGT_WIDTH   = 8,
    parameter int ACC_WIDTH   = 32,
    parameter int OUT_WIDTH   = 8,
    parameter int ADDR_WIDTH  = 16
) (
    input  wire                                  clk,
    input  wire                                  rst_n,

    // Control inputs from addr_gen (via cnn_top)
    input  wire                                  mac_valid,   // tap group valid
    input  wire                                  acc_clear,   // first tap of pixel
    input  wire                                  pixel_done,  // AG_WRITE: pixel complete

    // Data inputs
    input  wire [NUM_LANES-1:0][ACT_WIDTH-1:0]  act_data,
    input  wire [NUM_LANES-1:0][WGT_WIDTH-1:0]  weight_data,

    // Outputs
    output logic [OUT_WIDTH-1:0]                 out_data,
    output logic [ADDR_WIDTH-1:0]                out_wr_addr,
    output logic                                 out_valid
);

    // =========================================================================
    // Internal signal declarations (all before first use — UNDIDN)
    // =========================================================================
    logic signed [ACC_WIDTH-1:0] lane_product [NUM_LANES];
    logic signed [ACC_WIDTH-1:0] acc_reg;
    logic signed [ACC_WIDTH-1:0] acc_next;
    logic signed [ACC_WIDTH-1:0] lane_sum;
    logic                         mac_valid_d1;
    logic                         pixel_done_d1;   // 1-cycle delay of pixel_done
    logic [OUT_WIDTH-1:0]         relu_sat;
    logic [ADDR_WIDTH-1:0]        addr_cnt;

    // =========================================================================
    // Lane products (combinational) — zero-extend act, sign-extend weight
    // =========================================================================
    genvar g;
    generate
        for (g = 0; g < NUM_LANES; g++) begin : gen_mac_lanes
            assign lane_product[g] =
                $signed({{(ACC_WIDTH-ACT_WIDTH){1'b0}}, act_data[g]})
                * $signed({{(ACC_WIDTH-WGT_WIDTH){weight_data[g][WGT_WIDTH-1]}},
                            weight_data[g]});
        end
    endgenerate

    // =========================================================================
    // Lane summation tree (combinational)
    // =========================================================================
    always_comb begin : comb_lane_sum
        lane_sum = '0;
        for (int i = 0; i < NUM_LANES; i++)
            lane_sum = lane_sum + lane_product[i];
    end

    // =========================================================================
    // Accumulator next-value (combinational)
    // =========================================================================
    always_comb begin : comb_acc_next
        if (mac_valid)
            acc_next = acc_clear ? lane_sum : (acc_reg + lane_sum);
        else
            acc_next = acc_reg;
    end

    // =========================================================================
    // Accumulator register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin : ff_accumulator
        if (!rst_n) acc_reg <= '0;
        else        acc_reg <= acc_next;
    end

    // =========================================================================
    // Pipeline delay — 1 cycle to align control with acc_reg
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin : ff_ctrl_pipe
        if (!rst_n) begin
            mac_valid_d1  <= 1'b0;
            pixel_done_d1 <= 1'b0;
        end else begin
            mac_valid_d1  <= mac_valid;
            pixel_done_d1 <= pixel_done;
        end
    end

    // =========================================================================
    // ReLU + 8-bit saturation (combinational from acc_reg)
    // acc_reg holds the final accumulated value when pixel_done_d1 fires
    // =========================================================================
    always_comb begin : comb_relu_sat
        if      (acc_reg < 0)
            relu_sat = {OUT_WIDTH{1'b0}};
        else if (acc_reg > {{(ACC_WIDTH-OUT_WIDTH){1'b0}}, {OUT_WIDTH{1'b1}}})
            relu_sat = {OUT_WIDTH{1'b1}};
        else
            relu_sat = acc_reg[OUT_WIDTH-1:0];
    end

    // =========================================================================
    // Output register
    // out_valid fires on pixel_done_d1 (once per completed pixel)
    // out_data  captures relu_sat when out_valid is asserted
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin : ff_out_data
        if (!rst_n) begin
            out_data  <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= pixel_done_d1;       // ONE pulse per pixel ← key fix
            if (pixel_done_d1)
                out_data <= relu_sat;
        end
    end

    // =========================================================================
    // Write-address counter
    //
    // addr_cnt increments on pixel_done (cycle N+1), one cycle BEFORE
    // out_valid (cycle N+2). The combinational assign presents the
    // pre-increment value as the write address while out_valid is high.
    //
    // Initialised to 0xFFFF: first pixel_done wraps to 0x0000, which is
    // the correct address presented at cycle N+2 when out_valid fires.
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin : ff_wr_addr
        if (!rst_n)
            addr_cnt <= {ADDR_WIDTH{1'b1}};   // -1: first pixel_done wraps to 0
        else if (pixel_done)
            addr_cnt <= addr_cnt + 1'b1;
    end

    assign out_wr_addr = addr_cnt;

    // =========================================================================
    // Simulation-only checks
    // =========================================================================
    `ifdef SIMULATION
    always_ff @(posedge clk) begin : sim_checks
        if (rst_n && pixel_done_d1) begin
            if (acc_reg > 32'sh0000_00FF)
                $display("[CONV_ENGINE] INFO t=%0t acc=%0d saturated to 255", $time, acc_reg);
            if (acc_reg < 32'sh0000_0000)
                $display("[CONV_ENGINE] INFO t=%0t acc=%0d ReLU clamped to 0", $time, acc_reg);
        end
        if (rst_n && out_valid && (&addr_cnt))
            $display("[CONV_ENGINE] WARN t=%0t addr_cnt wrapping!", $time);
    end
    `endif

endmodule : conv_engine

`default_nettype wire
// =============================================================================
// End of conv_engine.sv
// =============================================================================
