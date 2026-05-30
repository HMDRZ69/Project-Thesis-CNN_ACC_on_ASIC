// =============================================================================
// pool_engine.sv
// -----------------------------------------------------------------------------
// 2x2 max-pool over Conv2 output (32x32x8) -> 16x16x8 feature map.
//
// Data layout (channel-first / planar):
//   Input  address = ch*1024 + row*32 + col   (ch in [0,7], row/col in [0,31])
//   Output address = ch*256  + row*16 + col   (ch in [0,7], row/col in [0,15])
//
// Total output pixels = 8 x 16 x 16 = 2048
// Total cycles approx 2048 x 7 = 14,336
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module pool_engine (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         pool_start,
    output logic        pool_done,
    output logic [12:0] sram_rd_addr,
    input  wire  [7:0]  sram_rd_data,
    output logic [12:0] sram_wr_addr,
    output logic [7:0]  sram_wr_data,
    output logic        sram_wr_en
);

    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_ADDR0 = 3'd1,
        S_ADDR1 = 3'd2,
        S_ADDR2 = 3'd3,
        S_ADDR3 = 3'd4,
        S_MAX   = 3'd5,
        S_WRITE = 3'd6,
        S_DONE  = 3'd7
    } state_t;

    state_t state_reg, state_next;

    logic [2:0] ch;
    logic [3:0] out_row;
    logic [3:0] out_col;

    logic [7:0] p0, p1, p2, p3;
    logic [7:0] max01, max23, max_result;

    function logic [7:0] max2 (input logic [7:0] a, input logic [7:0] b);
        max2 = (a > b) ? a : b;
    endfunction

    // ==================== FIXED ADDRESS CALCULATIONS ====================
    // Input : ch*1024 + row*32 + col
    function logic [12:0] rd_addr_calc(
        input logic [2:0] ch_i,
        input logic [3:0] orow_i,
        input logic [3:0] ocol_i,
        input logic       row_off,
        input logic       col_off
    );
        logic [4:0] in_row;
        logic [4:0] in_col;
        in_row = {orow_i, row_off};           // 0..31
        in_col = {ocol_i, col_off};           // 0..31
        rd_addr_calc = {ch_i, 10'b0} + ({in_row, 5'b0}) + {8'b0, in_col};
    endfunction

    // Output: ch*256 + out_row*16 + out_col
    function logic [12:0] wr_addr_calc(
        input logic [2:0] ch_i,
        input logic [3:0] orow_i,
        input logic [3:0] ocol_i
    );
        wr_addr_calc = {ch_i, 8'b0} + {orow_i, 4'b0} + ocol_i;  // ch*256 + row*16 + col
    endfunction

    // FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state_reg <= S_IDLE;
        else        state_reg <= state_next;
    end

    always_comb begin
        state_next = state_reg;
        case (state_reg)
            S_IDLE  : if (pool_start) state_next = S_ADDR0;
            S_ADDR0 : state_next = S_ADDR1;
            S_ADDR1 : state_next = S_ADDR2;
            S_ADDR2 : state_next = S_ADDR3;
            S_ADDR3 : state_next = S_MAX;
            S_MAX   : state_next = S_WRITE;
            S_WRITE : begin
                if (ch == 3'd7 && out_row == 4'd15 && out_col == 4'd15)
                    state_next = S_DONE;
                else
                    state_next = S_ADDR0;
            end
            S_DONE  : if (pool_start) state_next = S_ADDR0;  // re-arm for next run
                      else            state_next = S_DONE;
            default : state_next = S_IDLE;
        endcase
    end

    // Counters
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch      <= 3'd0;
            out_row <= 4'd0;
            out_col <= 4'd0;
        end else if ((state_reg == S_IDLE || state_reg == S_DONE) && pool_start) begin
            ch      <= 3'd0;
            out_row <= 4'd0;
            out_col <= 4'd0;
        end else if (state_reg == S_WRITE) begin
            if (out_col == 4'd15) begin
                out_col <= 4'd0;
                if (out_row == 4'd15) begin
                    out_row <= 4'd0;
                    if (ch != 3'd7) 
                        ch <= ch + 3'd1;
                end else begin
                    out_row <= out_row + 4'd1;
                end
            end else begin
                out_col <= out_col + 4'd1;
            end
        end
    end

    // Pixel capture
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p0 <= 8'h00; p1 <= 8'h00; p2 <= 8'h00; p3 <= 8'h00;
        end else begin
            case (state_reg)
                S_ADDR1 : p0 <= sram_rd_data;
                S_ADDR2 : p1 <= sram_rd_data;
                S_ADDR3 : p2 <= sram_rd_data;
                S_MAX   : p3 <= sram_rd_data;
                default : ;
            endcase
        end
    end

    // Max computation
    always_comb begin
        max01      = max2(p0, p1);
        max23      = max2(p2, p3);
        max_result = max2(max01, max23);
    end

    // Read address
    always_comb begin
        case (state_reg)
            S_ADDR0 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b0, 1'b0);
            S_ADDR1 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b0, 1'b1);
            S_ADDR2 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b1, 1'b0);
            S_ADDR3 : sram_rd_addr = rd_addr_calc(ch, out_row, out_col, 1'b1, 1'b1);
            default : sram_rd_addr = 13'h0000;
        endcase
    end

    // Write
    always_comb begin
        sram_wr_en   = (state_reg == S_WRITE);
        sram_wr_addr = wr_addr_calc(ch, out_row, out_col);
        sram_wr_data = max_result;
    end

    always_comb begin
        pool_done = (state_reg == S_DONE) && !pool_start;
    end

endmodule

`default_nettype wire