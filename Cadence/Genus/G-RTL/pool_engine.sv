// =============================================================================
// pool_engine.sv
// -----------------------------------------------------------------------------
// 2×2 max-pool over Conv2 output (16×16×8) → 8×8×8 feature map.
//
// Data layout (channel-first / planar):
//   Input  address = ch*256 + row*16 + col   (ch∈[0,7], row/col∈[0,15])
//   Output address = ch*64  + row*8  + col   (ch∈[0,7], row/col∈[0,7])
//
// Pipeline (4-read + compare + write per output pixel):
//   S_IDLE   → wait for pool_start
//   S_ADDR0  → issue address for pixel (2r,   2c)   — read latency 1 cycle
//   S_ADDR1  → issue address for pixel (2r,   2c+1) — capture p0 from SRAM
//   S_ADDR2  → issue address for pixel (2r+1, 2c)   — capture p1 from SRAM
//   S_ADDR3  → issue address for pixel (2r+1, 2c+1) — capture p2 from SRAM
//   S_MAX    → capture p3; compute max(p0,p1,p2,p3)
//   S_WRITE  → assert sram_wr_en; write result; advance counters
//   S_DONE   → assert pool_done (level, not pulse) — held until next start
//
// Xcelium compliance:
//   - No assert...else $fatal  (SVAAKB)   → use if(!cond) $fatal(...)
//   - No multi-line $fatal strings          (EXPRPA)
//   - Signals declared before use          (UNDIDN)
//   - No same register in initial+always_ff (MULAXX)
//   - No 8'sd<N> in aggregates             (NULLU)
//   - `default_nettype none at top         (NODNTW)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module pool_engine (
    input  wire         clk,
    input  wire         rst_n,

    // Handshake
    input  wire         pool_start,     // 1-cycle strobe to begin
    output logic        pool_done,      // Level HIGH in S_DONE

    // Source SRAM read port (Conv2 output bank)
    output logic [12:0] sram_rd_addr,
    input  wire  [7:0]  sram_rd_data,

    // Destination SRAM write port (output bank)
    output logic [12:0] sram_wr_addr,
    output logic [7:0]  sram_wr_data,
    output logic        sram_wr_en
);

    // =============================================================================
    // FSM state encoding
    // =============================================================================
    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_ADDR0 = 3'd1,   // Issue addr for (2r,   2c),   latch nothing yet
        S_ADDR1 = 3'd2,   // Issue addr for (2r,   2c+1), latch p0
        S_ADDR2 = 3'd3,   // Issue addr for (2r+1, 2c),   latch p1
        S_ADDR3 = 3'd4,   // Issue addr for (2r+1, 2c+1), latch p2
        S_MAX   = 3'd5,   // Latch p3, compute max
        S_WRITE = 3'd6,   // Write result to destination SRAM
        S_DONE  = 3'd7
    } state_t;

    state_t state_reg, state_next;

    // =============================================================================
    // Loop counters:  ch ∈ [0,7],  out_row ∈ [0,7],  out_col ∈ [0,7]
    // Total output pixels = 8 × 8 × 8 = 512
    // =============================================================================
    logic [2:0] ch;         // current output channel
    logic [2:0] out_row;    // current output row
    logic [2:0] out_col;    // current output column

    // Pixel capture registers (unsigned 8-bit activations)
    logic [7:0] p0, p1, p2, p3;
    logic [7:0] max01, max23, max_result;

    // =============================================================================
    // Helper: compute 2-operand max (combinational)
    // =============================================================================
    function logic [7:0] max2 (input logic [7:0] a, input logic [7:0] b);
        max2 = (a > b) ? a : b;
    endfunction

    // =============================================================================
    // Input SRAM address construction
    //   in_row  = out_row * 2 + row_offset   (0 or 1)
    //   in_col  = out_col * 2 + col_offset   (0 or 1)
    //   addr    = ch * 256 + in_row * 16 + in_col
    //           = {ch[2:0], 8'b0} + {in_row[3:0], 4'b0} + {in_col[3:0]}
    // Full address ≤ 7*256 + 15*16 + 15 = 1792+240+15 = 2047  → fits [10:0]
    // Padded to [12:0] to match SRAM port width (8KB = 8192 entries).
    // =============================================================================
    function logic [12:0] rd_addr_calc(
        input logic [2:0] ch_i,
        input logic [2:0] orow_i,
        input logic [2:0] ocol_i,
        input logic       row_off,
        input logic       col_off
    );
        logic [4:0] in_row;
        logic [4:0] in_col;
        in_row = {1'b0, orow_i, 1'b0} + {4'b0, row_off};
        in_col = {1'b0, ocol_i, 1'b0} + {4'b0, col_off};
        rd_addr_calc = {2'b00, ch_i, 8'h00} + {4'b0, in_row, 4'b0} + {8'b0, in_col};
    endfunction

    // Output SRAM address:  ch*64 + out_row*8 + out_col
    function logic [12:0] wr_addr_calc(
        input logic [2:0] ch_i,
        input logic [2:0] orow_i,
        input logic [2:0] ocol_i
    );
        return {2'b00, ch_i, 6'h00} + {4'b0, orow_i, 3'b0} + {10'b0, ocol_i};
    endfunction

    // =============================================================================
    // FSM — state register
    // =============================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_reg <= S_IDLE;
        else
            state_reg <= state_next;
    end

    // =============================================================================
    // FSM — next-state logic (combinational)
    // =============================================================================
    always_comb begin
        state_next = state_reg;
        case (state_reg)
            S_IDLE  : if (pool_start)       state_next = S_ADDR0;
            S_ADDR0 :                        state_next = S_ADDR1;
            S_ADDR1 :                        state_next = S_ADDR2;
            S_ADDR2 :                        state_next = S_ADDR3;
            S_ADDR3 :                        state_next = S_MAX;
            S_MAX   :                        state_next = S_WRITE;
            S_WRITE : begin
                // Advance to next pixel or finish
                if (ch == 3'd7 && out_row == 3'd7 && out_col == 3'd7)
                    state_next = S_DONE;
                else
                    state_next = S_ADDR0;
            end
            S_DONE  :                        state_next = S_DONE; // Hold until reset/restart
            default :                        state_next = S_IDLE;
        endcase
    end

    // =============================================================================
    // Counter update — synchronous, driven only from always_ff  (MULAXX safe)
    // Counters advance in S_WRITE after each output pixel is committed.
    // =============================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch      <= 3'd0;
            out_row <= 3'd0;
            out_col <= 3'd0;
        end else if (state_reg == S_IDLE && pool_start) begin
            // Reset counters at the start of a new pooling pass
            ch      <= 3'd0;
            out_row <= 3'd0;
            out_col <= 3'd0;
        end else if (state_reg == S_WRITE) begin
            // Column-major inner loop: col → row → channel
            if (out_col == 3'd7) begin
                out_col <= 3'd0;
                if (out_row == 3'd7) begin
                    out_row <= 3'd0;
                    if (ch != 3'd7)
                        ch <= ch + 3'd1;
                    // ch wraps naturally; FSM moves to S_DONE on the last pixel
                end else begin
                    out_row <= out_row + 3'd1;
                end
            end else begin
                out_col <= out_col + 3'd1;
            end
        end
    end

    // =============================================================================
    // Pixel capture registers — latch SRAM read data with 1-cycle latency
    //   S_ADDR0 issues addr → data valid in S_ADDR1 → latch as p0
    //   S_ADDR1 issues addr → data valid in S_ADDR2 → latch as p1
    //   etc.
    // =============================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p0 <= 8'h00;
            p1 <= 8'h00;
            p2 <= 8'h00;
            p3 <= 8'h00;
        end else begin
            case (state_reg)
                S_ADDR1 : p0 <= sram_rd_data;   // data for addr issued in S_ADDR0
                S_ADDR2 : p1 <= sram_rd_data;   // data for addr issued in S_ADDR1
                S_ADDR3 : p2 <= sram_rd_data;   // data for addr issued in S_ADDR2
                S_MAX   : p3 <= sram_rd_data;   // data for addr issued in S_ADDR3
                default : ;
            endcase
        end
    end

    // =============================================================================
    // Max computation (combinational + registered result)
    // =============================================================================
    always_comb begin
        max01     = max2(p0, p1);
        max23     = max2(p2, p3);
        max_result = max2(max01, max23);
    end

    // =============================================================================
    // SRAM read address — combinational based on current state + counters
    // =============================================================================
    always_comb begin
        case (state_reg)
            S_ADDR0 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b0, 1'b0);
            S_ADDR1 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b0, 1'b1);
            S_ADDR2 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b1, 1'b0);
            S_ADDR3 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b1, 1'b1);
            default : sram_rd_addr = 13'h0000;
        endcase
    end

    // =============================================================================
    // SRAM write — only asserted in S_WRITE
    // =============================================================================
    always_comb begin
        sram_wr_en   = (state_reg == S_WRITE);
        sram_wr_addr = wr_addr_calc(ch, out_row, out_col);
        sram_wr_data = max_result;
    end

    // =============================================================================
    // pool_done — level HIGH in S_DONE
    // =============================================================================
    always_comb begin
        pool_done = (state_reg == S_DONE);
    end

    // =============================================================================
    // Simulation assertions (Xcelium SVAAKB: no assert...else $fatal)
    // =============================================================================
`ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (rst_n && state_reg == S_WRITE) begin
            if (ch > 3'd7)
                $fatal(1, "[pool_engine] ch counter overflow: ch=%0d", ch);
            if (out_row > 3'd7)
                $fatal(1, "[pool_engine] out_row counter overflow: out_row=%0d", out_row);
            if (out_col > 3'd7)
                $fatal(1, "[pool_engine] out_col counter overflow: out_col=%0d", out_col);
        end
    end
`endif

endmodule

`default_nettype wire
// =============================================================================
// End of pool_engine.sv
// =============================================================================