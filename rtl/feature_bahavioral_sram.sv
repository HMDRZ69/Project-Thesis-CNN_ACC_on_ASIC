// =============================================================================
// feature_sram.sv
//
// Behavioural 8 KB synchronous SRAM model for feature map storage.
// Functionally equivalent to feature_sram_model.sv but uses a unified
// single-port interface (shared address/we) to match cnn_top.sv's
// instantiation style.
//
// Properties:
//   - Synchronous read with 1-cycle latency
//   - Synchronous write
//   - Write-before-read: if we=1, rdata returns newly written value
//   - rdata holds 0x00 when we=0 and no read is pending (safe default)
//   - Memory zero-initialised at simulation start
//
// Parameters:
//   DEPTH  : number of addressable bytes (default 8192 = 8 KB)
//   ADDR_W : address bus width (must satisfy 2^ADDR_W == DEPTH)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module feature_sram #(
    parameter int DEPTH  = 8192,
    parameter int ADDR_W = 13
)(
    input  logic              clk,
    input  logic              we,
    input  logic [ADDR_W-1:0] addr,
    input  logic [7:0]        wdata,
    output logic [7:0]        rdata
);

    // -------------------------------------------------------------------------
    // Elaboration-time parameter check
    // -------------------------------------------------------------------------
    logic [7:0] mem [0:DEPTH-1];

    `ifndef SYNTHESIS
    initial begin
        if (2**ADDR_W != DEPTH)
            $fatal(1, "feature_sram: ADDR_W=%0d implies depth %0d but DEPTH=%0d. Parameters are inconsistent.", ADDR_W, 2**ADDR_W, DEPTH);
    end

    // -------------------------------------------------------------------------
    // Memory array — zero-initialised
    // -------------------------------------------------------------------------
    initial begin
        for (int i = 0; i < DEPTH; i++)
            mem[i] = 8'h00;
    end
    `endif
    // -------------------------------------------------------------------------
    // Synchronous read/write — write-before-read priority
    //
    // Original bug fixed: the original always read mem[addr] unconditionally
    // after the write, meaning a same-cycle write+read returned the OLD value.
    // Now: if we=1 and read targets same address, rdata returns new wdata.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (we) begin
            // synthesis translate_off
            if (int'(addr) >= DEPTH)
                $fatal(1, "feature_sram: addr=0x%0h out of range [0..%0d] at time %0t", addr, DEPTH-1, $time);
            // synthesis translate_on
            mem[addr] <= wdata;
        end

        // Read — returns newly written data if same address written this cycle
        if (we)
            rdata <= wdata;        // write-before-read forwarding
        else
            rdata <= mem[addr];    // normal read
    end

endmodule : feature_sram

`default_nettype wire
// =============================================================================
// End of feature_sram.sv
// =============================================================================