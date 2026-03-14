// =============================================================================
// conv_engine.sv — Interface Definition
//
// 4-lane parallel MAC engine for Conv1 and Conv2 layers.
//
// Operation per clock cycle (when mac_valid=1):
//   For each lane i:
//     if act_zero_mask[i] == 0:
//       acc += act_data[i] * weight_data[i]   (signed × unsigned MAC)
//     else:
//       lane i contributes 0 (zero-padding)
//
// Accumulator control:
//   acc_clear=1 : accumulator resets to 0 on this cycle BEFORE accumulating
//                 (first tap group of each output pixel)
//   mac_valid=1 : accumulation is active this cycle
//   mac_valid=0 : accumulator holds its value (no accumulation)
//
// Output:
//   When out_enable=1 (asserted by addr_gen out_wr_en, pipelined 1 cycle):
//     - Apply ReLU if relu_enable=1: out_data = max(0, acc[ACT_W-1:0])
//     - Saturate: if acc > 2^ACT_W-1, out_data = 8'hFF
//                 if acc < 0,          out_data = 8'h00
//     - Assert out_valid for 1 cycle
//     - out_wr_addr holds the registered write address for SRAM
//
// Saturation policy:
//   ACC_W must satisfy: ACC_W >= ACT_W + WGT_W + ceil(log2(LANES * 9))
//   For defaults: 32 >= 8 + 8 + ceil(log2(36)) = 22 — safe with 10 bits margin
//
// Pipeline latency: 1 cycle (registered output)
//
// Parameters:
//   ACT_W   : activation width in bits (default 8, unsigned)
//   WGT_W   : weight width in bits     (default 8, signed)
//   ACC_W   : accumulator width        (default 32, signed)
//   LANES   : number of parallel MAC lanes (default 4)
//   ADDR_W  : write address width      (default 16, matches out_wr_addr)
// =============================================================================

module conv_engine #(
    parameter int ACT_W  = 8,
    parameter int WGT_W  = 8,
    parameter int ACC_W  = 32,
    parameter int LANES  = 4,
    parameter int ADDR_W = 16     // must match addr_gen out_wr_addr width
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // -------------------------------------------------------------------------
    // Control signals (driven by addr_gen / cnn_top)
    // -------------------------------------------------------------------------
    input  logic                        mac_valid,    // accumulate this cycle
    input  logic                        acc_clear,    // reset acc before MAC
                                                      // (first tap of each pixel)
    input  logic                        out_enable,   // latch and output result
                                                      // (registered out_wr_en)
    input  logic                        relu_enable,  // 1=apply ReLU, 0=linear

    // -------------------------------------------------------------------------
    // Write address — passed through from addr_gen out_wr_addr
    // Registered internally so out_wr_addr is stable when out_valid=1
    // -------------------------------------------------------------------------
    input  logic [ADDR_W-1:0]           wr_addr_in,   // connect to out_wr_addr

    // -------------------------------------------------------------------------
    // 4-lane activation inputs (packed array — matches addr_gen port style)
    // act_zero_mask[i]=1 means lane i is zero-padded: treat as 0, skip SRAM read
    // -------------------------------------------------------------------------
    input  logic [LANES-1:0][ACT_W-1:0] act_data,     // unsigned activations
    input  logic [LANES-1:0]            act_zero_mask, // 1=pad zero this lane

    // -------------------------------------------------------------------------
    // 4-lane weight inputs (signed, packed array)
    // -------------------------------------------------------------------------
    input  logic signed [LANES-1:0][WGT_W-1:0] weight_data,

    // -------------------------------------------------------------------------
    // Output — registered, 1-cycle latency after out_enable
    // -------------------------------------------------------------------------
    output logic                        out_valid,    // result ready this cycle
    output logic [ACT_W-1:0]            out_data,     // saturated+ReLU result
    output logic [ADDR_W-1:0]           out_wr_addr,  // write address for SRAM

    // -------------------------------------------------------------------------
    // Debug output — accumulator value before saturation/ReLU
    // Useful for waveform inspection; tie off in synthesis if not needed
    // synthesis translate_off
    // (acc_debug is present in synthesis but undriven externally —
    //  simulator will show the internal accumulator value)
    // synthesis translate_on
    // -------------------------------------------------------------------------
    output logic signed [ACC_W-1:0]     acc_debug
);

    // =========================================================================
    // Elaboration-time parameter validation
    // =========================================================================
    initial begin
        if (ACC_W < ACT_W + WGT_W + $clog2(LANES * 9))
            $fatal(1,
                "conv_engine: ACC_W=%0d is too narrow. Need at least %0d bits "
                "to avoid overflow (ACT_W=%0d + WGT_W=%0d + log2(LANES*9)=%0d).",
                ACC_W, ACT_W + WGT_W + $clog2(LANES*9),
                ACT_W, WGT_W, $clog2(LANES*9));
        if (LANES < 1 || LANES > 16)
            $fatal(1, "conv_engine: LANES=%0d out of supported range [1..16].", LANES);
    end

endmodule