// =============================================================================
// conv_engine_stub.sv
//
// Stub implementation of conv_engine for Week 12 connectivity verification.
//
// Purpose:
//   - Verify conv_engine connects correctly to cnn_top
//   - Verify out_enable reaches the write path at the right time
//   - Remove dummy_wdata from cnn_top and replace with real write path
//   - Confirm datapath placeholder → SRAM write works end-to-end
//
// Behaviour:
//   - acc_value increments by 1 each mac_valid cycle (not a real MAC)
//   - acc_value resets to 0 on acc_clear (clear takes priority over MAC)
//   - out_data outputs 0xA5 (visible debug pattern) when out_enable=1
//   - out_valid pulses for 1 cycle when out_enable=1
//   - out_wr_addr registers wr_addr_in when out_enable=1
//
// Replace with real conv_engine.sv once MAC datapath is implemented.
// =============================================================================

module conv_engine_stub #(
    parameter int ACT_W  = 8,
    parameter int WGT_W  = 8,
    parameter int ACC_W  = 32,
    parameter int LANES  = 4,
    parameter int ADDR_W = 16
)(
    input  logic                               clk,
    input  logic                               rst_n,

    // Control
    input  logic                               mac_valid,
    input  logic                               acc_clear,
    input  logic                               out_enable,
    input  logic                               relu_enable,   // reserved for real engine

    // Write address passthrough
    input  logic [ADDR_W-1:0]                  wr_addr_in,

    // 4-lane activation inputs (packed array — matches addr_gen style)
    input  logic [LANES-1:0][ACT_W-1:0]        act_data,
    input  logic [LANES-1:0]                   act_zero_mask,

    // 4-lane weight inputs
    input  logic signed [LANES-1:0][WGT_W-1:0] weight_data,

    // Outputs
    output logic                               out_valid,
    output logic [ACT_W-1:0]                   out_data,
    output logic [ADDR_W-1:0]                  out_wr_addr,

    // Debug
    output logic signed [ACC_W-1:0]            acc_debug
);

    // =========================================================================
    // Accumulator — acc_clear takes priority over mac_valid
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            acc_debug <= '0;
        else if (acc_clear)
            acc_debug <= '0;           // clear wins — must come before mac check
        else if (mac_valid)
            acc_debug <= acc_debug + 1; // stub: increment instead of real MAC
    end

    // =========================================================================
    // Output register — latch result and write address when out_enable fires
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid   <= 1'b0;
            out_data    <= '0;
            out_wr_addr <= '0;
        end else begin
            out_valid <= 1'b0;           // default: deassert every cycle
            if (out_enable) begin
                out_valid   <= 1'b1;
                out_data    <= 8'hA5;    // visible debug pattern — easy to spot in waveform
                out_wr_addr <= wr_addr_in;
            end
        end
    end

endmodule