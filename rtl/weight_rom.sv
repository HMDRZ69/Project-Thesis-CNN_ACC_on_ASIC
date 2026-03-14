// =============================================================================
// weight_rom.sv
//
// Combinational weight ROM for the CNN accelerator.
// Stores all convolution weights for Conv1 and Conv2 as 8-bit signed values.
//
// Weight layout (flat index):
//   Conv1: 1 input channel, 4 output channels, 3x3 kernel = 36 weights
//          index 0..35   → oc=0..3, ic=0, k=0..8
//   Conv2: 4 input channels, 8 output channels, 3x3 kernel = 288 weights
//          index 36..323 → oc=0..7, ic=0..3, k=0..8
//
//   Formula: index = (oc * Cin * 9) + (ic * 9) + k
//
// All unassigned indices return 8'sd0 (safe default).
//
// NOTE: Current values are test/placeholder weights only.
//       Replace with trained weights before functional verification.
//
// Parameters:
//   ADDR_W : index bus width (default 9 — supports 0..511, covers max 324)
// =============================================================================

module weight_rom #(
    parameter int ADDR_W = 9    // 9 bits covers max index 323 (Conv2 last weight)
)(
    input  logic [ADDR_W-1:0]      index,
    output logic signed [7:0]      weight
);

    // -------------------------------------------------------------------------
    // Elaboration-time check: index width must cover Conv1 + Conv2 weight count
    // Conv1: 4*1*9 = 36, Conv2: 8*4*9 = 288, total = 324 → needs ceil(log2(324))=9
    // -------------------------------------------------------------------------
    `ifndef SYNTHESIS
    initial begin
        if (ADDR_W < 9)
            $fatal(1, "weight_rom: ADDR_W=%0d is too narrow. Need at least 9 bits to address 324 weights.", ADDR_W);
    end
    `endif
    
    // -------------------------------------------------------------------------
    // Combinational ROM — pure lookup, no clock needed
    // -------------------------------------------------------------------------
    always_comb begin
        case (index)
            // -----------------------------------------------------------------
            // Conv1 weights (index 0..8): oc=0, ic=0, k=0..8
            // 3x3 kernel — simple edge-detect placeholder
            // -----------------------------------------------------------------
            9'd0 : weight =  8'sd1;
            9'd1 : weight = -8'sd1;
            9'd2 : weight =  8'sd2;
            9'd3 : weight = -8'sd2;
            9'd4 : weight =  8'sd3;
            9'd5 : weight = -8'sd3;
            9'd6 : weight =  8'sd1;
            9'd7 : weight =  8'sd0;
            9'd8 : weight = -8'sd1;

            // -----------------------------------------------------------------
            // Conv1 weights (index 9..35): oc=1..3, ic=0, k=0..8
            // Placeholder: alternating +1/-1 pattern
            // -----------------------------------------------------------------
            9'd9  : weight =  8'sd1;  9'd10 : weight = -8'sd1;  9'd11 : weight =  8'sd1;
            9'd12 : weight = -8'sd1;  9'd13 : weight =  8'sd1;  9'd14 : weight = -8'sd1;
            9'd15 : weight =  8'sd1;  9'd16 : weight = -8'sd1;  9'd17 : weight =  8'sd1;
            9'd18 : weight = -8'sd1;  9'd19 : weight =  8'sd1;  9'd20 : weight = -8'sd1;
            9'd21 : weight =  8'sd1;  9'd22 : weight = -8'sd1;  9'd23 : weight =  8'sd1;
            9'd24 : weight = -8'sd1;  9'd25 : weight =  8'sd1;  9'd26 : weight = -8'sd1;
            9'd27 : weight =  8'sd1;  9'd28 : weight = -8'sd1;  9'd29 : weight =  8'sd1;
            9'd30 : weight = -8'sd1;  9'd31 : weight =  8'sd1;  9'd32 : weight = -8'sd1;
            9'd33 : weight =  8'sd1;  9'd34 : weight = -8'sd1;  9'd35 : weight =  8'sd1;

            // -----------------------------------------------------------------
            // Conv2 weights (index 36..323): oc=0..7, ic=0..3, k=0..8
            // Placeholder: identity-like (+2 on center tap k=4, 0 elsewhere)
            // -----------------------------------------------------------------
            9'd40 : weight =  8'sd2;   // oc=0,ic=0,k=4 (center)
            9'd49 : weight =  8'sd2;   // oc=0,ic=1,k=4
            9'd58 : weight =  8'sd2;   // oc=0,ic=2,k=4
            9'd67 : weight =  8'sd2;   // oc=0,ic=3,k=4
            9'd76 : weight =  8'sd2;   // oc=1,ic=0,k=4
            9'd85 : weight =  8'sd2;   // oc=1,ic=1,k=4
            9'd94 : weight =  8'sd2;   // oc=1,ic=2,k=4
            9'd103: weight =  8'sd2;   // oc=1,ic=3,k=4

            // All remaining Conv2 weights default to 0 (see default below)

            // -----------------------------------------------------------------
            // Safe default — all unassigned indices return 0
            // -----------------------------------------------------------------
            default: weight = 8'sd0;
        endcase
    end

endmodule