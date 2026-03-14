// =============================================================================
// addr_gen.sv
//
// Address generator for a two-layer Conv accelerator (4-lane MAC datapath).
//
// For each output pixel (oc, y, x) the module iterates over all input taps
// (ic, ky, kx) in groups of 4, driving:
//   - act_rd_addr[0..3]  : activation SRAM read addresses (CHW layout)
//   - w_idx[0..3]        : weight ROM indices
//   - act_zero[0..3]     : lane uses zero (zero-padding or out-of-bounds)
//   - mac_valid          : tap group is valid for the MAC
//   - acc_clear          : clear accumulator at the first tap of each pixel
//   - out_wr_en/addr     : write result after all taps for a pixel are done
//   - layer_done         : all output pixels have been written
//
// Supported layers:
//   Conv1  layer_sel=0  Cin=1, Cout=4,  taps_total=9
//   Conv2  layer_sel=1  Cin=4, Cout=8,  taps_total=36
//
// Feature map dimensions are H x W (default 32x32). Zero-padding of 1 is
// assumed (same-padding for 3x3 kernels).
// =============================================================================

module addr_gen #(
    parameter int H = 32,
    parameter int W = 32
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        enable,      // 1 => run address generation
    input  logic        layer_sel,   // 0: Conv1 (Cin=1,Cout=4)  1: Conv2 (Cin=4,Cout=8)

    // MAC datapath controls
    output logic        mac_valid,   // asserted while a tap group drives valid data
    output logic        acc_clear,   // pulse on the first tap group of each output pixel

    // 4-lane activation read port
    output logic [3:0]       act_rd_en,
    output logic [3:0]       act_zero,        // 1 => substitute zero (padding)
    output logic [3:0][15:0] act_rd_addr,     // CHW linear address

    // 4-lane weight read port (ROM)
    output logic [3:0]      w_rd_en,
    output logic [3:0][8:0] w_idx,            // max index = 7*4*9+8 = 260 < 512

    // Output write port (one cycle per completed pixel)
    output logic        out_wr_en,
    output logic [15:0] out_wr_addr,          // CHW linear address

    output logic        layer_done
);

    // =========================================================================
    // Parameter sanity checks (elaboration time)
    // =========================================================================
    initial begin
        assert (H <= 32 && W <= 32)
            else $fatal(1, "addr_gen: H and W must be <= 32 (got H=%0d W=%0d)", H, W);
        // Max activation address for Conv2: (Cin-1)*H*W + (H-1)*W + (W-1)
        // = 3*32*32 + 31*32 + 31 = 4126, fits in 13 bits — safe for 16-bit addr.
        // Max weight index for Conv2: (Cout-1)*Cin*9 + (Cin-1)*9 + 8
        // = 7*4*9 + 3*9 + 8 = 252+27+8 = 287, fits in 9 bits.
    end

    // =========================================================================
    // Layer-dependent parameters
    // =========================================================================
    logic [3:0] cout_p;       // number of output channels
    logic [3:0] cin_p;        // number of input  channels
    logic [5:0] taps_total;   // cin * 9 kernel taps

    always_comb begin
        if (!layer_sel) begin
            cin_p      = 3'd1;
            cout_p     = 4'd4;
            taps_total = 6'd9;
        end else begin
            cin_p      = 3'd4;
            cout_p     = 4'd8;
            taps_total = 6'd36;
        end
    end

    // =========================================================================
    // State machine
    // =========================================================================
    typedef enum logic [2:0] {
        AG_IDLE   = 3'd0,
        AG_NEWPIX = 3'd1,
        AG_TAPS   = 3'd2,
        AG_WRITE  = 3'd3,
        AG_NEXT   = 3'd4,
        AG_DONE   = 3'd5
    } ag_state_t;

    ag_state_t state_r, state_n;

    // =========================================================================
    // Pixel / tap counters
    // =========================================================================
    logic [2:0] oc;        // output channel index
    logic [4:0] y, x;      // output spatial position
    logic [5:0] tap_base;  // index of first tap in the current 4-lane group

    // Combinationally detect when AG_NEXT should advance to AG_DONE instead
    // of AG_NEWPIX. This avoids the dual-driver conflict in the original design
    // where the sequential block wrote st <= AG_DONE directly.
    logic last_pixel;
    always_comb begin
        last_pixel = (x == 5'd31) && (y == 5'd31) && (oc == (cout_p - 4'd1));
    end

    // Flag: this is the final 4-lane group for the current pixel
    logic last_tap_group;
    always_comb begin
        last_tap_group = ((tap_base + 6'd4) >= taps_total);
    end

    // =========================================================================
    // Padding helper: parameterised on H and W, not hardcoded to 32
    // =========================================================================
    function automatic logic in_bounds(input int v, input int limit);
        return (v >= 0 && v < limit);
    endfunction

    // =========================================================================
    // Combinational output and next-state logic
    // =========================================================================
    always_comb begin
        // ---- Safe defaults -------------------------------------------------
        state_n     = state_r;

        mac_valid   = 1'b0;
        acc_clear   = 1'b0;

        act_rd_en   = 4'b0000;
        act_zero    = 4'b1111;   // all lanes pad-zero by default
        act_rd_addr = '{default: 16'd0};

        w_rd_en     = 4'b0000;
        w_idx       = '{default: 9'd0};

        out_wr_en   = 1'b0;
        out_wr_addr = 16'd0;

        layer_done  = 1'b0;

        case (state_r)

            // -- Wait for enable ---------------------------------------------
            AG_IDLE: begin
                if (enable) state_n = AG_NEWPIX;
            end

            // -- Start of a new output pixel: reset tap group ----------------
            AG_NEWPIX: begin
                state_n = AG_TAPS;
            end

            // -- Drive one 4-lane tap group to the MAC -----------------------
            AG_TAPS: begin
                mac_valid = 1'b1;

                // Clear accumulator only on the very first group of this pixel
                if (tap_base == 6'd0) acc_clear = 1'b1;

                // Compute addresses for up to 4 concurrent taps
                for (int lane = 0; lane < 4; lane++) begin : gen_lanes
                    automatic int tap  = int'(tap_base) + lane;
                    automatic int ic   = tap / 9;
                    automatic int k    = tap % 9;
                    automatic int ky   = k  / 3;
                    automatic int kx   = k  % 3;
                    automatic int in_y = int'(y) + ky - 1;
                    automatic int in_x = int'(x) + kx - 1;

                    if (tap < int'(taps_total)) begin
                        // ---- Weight index: (oc * Cin + ic) * 9 + k --------
                        w_rd_en[lane] = 1'b1;
                        w_idx[lane]   = 9'((int'(oc) * int'(cin_p) + ic) * 9 + k);

                        // ---- Activation: check same-padding boundary -------
                        if (in_bounds(in_y, H) && in_bounds(in_x, W)) begin
                            act_rd_en[lane]   = 1'b1;
                            act_zero[lane]    = 1'b0;
                            // CHW layout: (ic * H * W) + (in_y * W) + in_x
                            act_rd_addr[lane] = 16'((ic * H * W) + (in_y * W) + in_x);
                        end else begin
                            // Out-of-bounds tap: substitute zero (implicit padding)
                            act_rd_en[lane]   = 1'b0;
                            act_zero[lane]    = 1'b1;
                            act_rd_addr[lane] = 16'd0;
                        end
                    end
                    // Lanes beyond taps_total stay at their safe defaults (zeros)
                end

                state_n = last_tap_group ? AG_WRITE : AG_TAPS;
            end

            // -- Write completed pixel to output SRAM ------------------------
            AG_WRITE: begin
                out_wr_en   = 1'b1;
                // CHW layout: (oc * H * W) + (y * W) + x
                out_wr_addr = 16'((int'(oc) * H * W) + (int'(y) * W) + int'(x));
                state_n     = AG_NEXT;
            end

            // -- Advance output pixel counters --------------------------------
            // Counter updates happen in the sequential block.
            // Transition target depends on last_pixel (computed combinationally
            // from current counter values, before they are incremented).
            AG_NEXT: begin
                state_n = last_pixel ? AG_DONE : AG_NEWPIX;
            end

            // -- All pixels written: assert done and wait for enable low -----
            AG_DONE: begin
                layer_done = 1'b1;
                if (!enable) state_n = AG_IDLE;
            end

            default: state_n = AG_IDLE;

        endcase
    end

    // =========================================================================
    // Sequential: state register + counter updates
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r  <= AG_IDLE;
            oc       <= 3'd0;
            y        <= 5'd0;
            x        <= 5'd0;
            tap_base <= 6'd0;
        end else begin
            state_r <= state_n;

            case (state_r)

                AG_IDLE: begin
                    if (enable) begin
                        oc       <= 3'd0;
                        y        <= 5'd0;
                        x        <= 5'd0;
                        tap_base <= 6'd0;
                    end
                end

                AG_NEWPIX: begin
                    tap_base <= 6'd0;
                end

                AG_TAPS: begin
                    // Advance tap group unless this is already the last group
                    // (tap_base holds its value naturally; no explicit self-assign needed)
                    if (!last_tap_group)
                        tap_base <= tap_base + 6'd4;
                end

                AG_NEXT: begin
                    // Counter rollover: x → y → oc (row-major CHW order)
                    tap_base <= 6'd0;

                    if (x == 5'd31) begin
                        x <= 5'd0;
                        if (y == 5'd31) begin
                            y <= 5'd0;
                            // oc rolls over when transitioning to AG_DONE,
                            // so reset it here for the next run
                            if (oc == (cout_p - 4'd1))
                                oc <= 3'd0;
                            else
                                oc <= oc + 3'd1;
                        end else begin
                            y <= y + 5'd1;
                        end
                    end else begin
                        x <= x + 5'd1;
                    end
                end

                // AG_WRITE, AG_DONE: no counter updates needed
                default: ;

            endcase
        end
    end

endmodule