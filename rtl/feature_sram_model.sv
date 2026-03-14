// =============================================================================
// feature_sram_model.sv
//
// Behavioural model of a single-port synchronous SRAM used to store
// intermediate feature maps between pipeline stages.
//
// Properties:
//   - Synchronous read with 1-cycle latency
//   - Synchronous write
//   - Write-before-read priority when rd_addr == wr_addr in the same cycle
//   - rd_data holds 0x00 when rd_en is deasserted (no stale data)
//   - Memory initialised to 0x00 at simulation start
//
// Parameters:
//   DEPTH   : number of addressable bytes (default 8192 = 8 KB)
//   ADDR_W  : address bus width in bits  (must satisfy 2^ADDR_W == DEPTH)
// =============================================================================

`timescale 1ns/1ps

module feature_sram_model #(
    parameter int DEPTH  = 8192,
    parameter int ADDR_W = 13
)(
    input  logic clk,

    input  logic              rd_en,
    input  logic [ADDR_W-1:0] rd_addr,
    output logic [7:0]        rd_data,

    input  logic              wr_en,
    input  logic [ADDR_W-1:0] wr_addr,
    input  logic [7:0]        wr_data
);

    // -------------------------------------------------------------------------
    // Elaboration-time parameter consistency check
    // Using if/$fatal instead of assert...else for Xcelium compatibility
    // -------------------------------------------------------------------------
    `ifndef SYNTHESIS
    initial begin
        if (2**ADDR_W != DEPTH)
            $fatal(1, "feature_sram_model: ADDR_W=%0d implies depth %0d but DEPTH=%0d. Parameters are inconsistent.", ADDR_W, 2**ADDR_W, DEPTH);
    end
    `endif

    // -------------------------------------------------------------------------
    // Memory array — initialised to 0x00
    // -------------------------------------------------------------------------
    logic [7:0] mem [0:DEPTH-1];

    `ifndef SYNTHESIS
    initial begin
        for (int i = 0; i < DEPTH; i++)
            mem[i] = 8'h00;
        // NOTE: rd_data is intentionally NOT initialised here.
        // Initialising it in 'initial' creates a second driver conflict
        // with the always_ff block in Xcelium (MULAXX error).
        // The always_ff block drives rd_data to 8'h00 whenever rd_en=0,
        // so stale values will never propagate after the first clock edge.
    end
    `endif
    
    // -------------------------------------------------------------------------
    // Synchronous read/write — write-before-read priority
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin

        if (wr_en) begin
            // synthesis translate_off
            if (int'(wr_addr) >= DEPTH)
                $fatal(1, "feature_sram_model: wr_addr=0x%0h out of range [0..%0d] at time %0t", wr_addr, DEPTH-1, $time);
            // synthesis translate_on
            mem[wr_addr] <= wr_data;
        end

        if (rd_en) begin
            // synthesis translate_off
            if (int'(rd_addr) >= DEPTH)
                $fatal(1, "feature_sram_model: rd_addr=0x%0h out of range [0..%0d] at time %0t", rd_addr, DEPTH-1, $time);
            // synthesis translate_on
            if (wr_en && (wr_addr == rd_addr))
                rd_data <= wr_data;
            else
                rd_data <= mem[rd_addr];
        end else begin
            rd_data <= 8'h00;
        end

    end

endmodule