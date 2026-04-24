// =============================================================================
// controller_fsm.md
//
// Top-level FSM for a two-layer Conv + Pooling accelerator.
//
// Pipeline:
//   IDLE -> CONV1 -> CONV2 -> POOL -> DONE
//
// Ping-pong buffering:
//   - SRAM A is the initial source, SRAM B the initial destination.
//   - src/dst swap on every state transition so each stage reads
//     the output written by the previous stage.
//
// Pulse outputs:
//   - conv_start / pool_start are registered 1-cycle pulses,
//     asserted in the cycle AFTER the triggering transition.
//
// done output:
//   - Registered to avoid combinational glitches.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module controller_fsm (
    input  logic clk,
    input  logic rst_n,

    // Handshake inputs
    input  logic start,       // Single-cycle pulse to begin processing
    input  logic conv_done,   // Asserted for one cycle when Conv engine finishes
    input  logic pool_done,   // Asserted for one cycle when Pool engine finishes

    // Engine trigger outputs (registered 1-cycle pulses)
    output logic conv_start,
    output logic pool_start,

    // Datapath selects
    output logic layer_sel,   // 0: Conv1 weights,  1: Conv2 weights
    output logic mode_sel,    // 0: Convolution,    1: Pooling

    // Ping-pong SRAM selects
    output logic src_sel,     // 0: read from SRAM A,  1: read from SRAM B
    output logic dst_sel,     // 0: write to SRAM A,   1: write to SRAM B

    // Completion flag (registered)
    output logic done
);

    // -------------------------------------------------------------------------
    // State encoding
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_CONV1 = 3'd1,
        S_CONV2 = 3'd2,
        S_POOL  = 3'd3,
        S_DONE  = 3'd4
    } state_t;

    state_t state_r, state_n;

    // -------------------------------------------------------------------------
    // Internal next-state signals
    // -------------------------------------------------------------------------
    logic src_sel_n, dst_sel_n;
    logic conv_start_n, pool_start_n;
    logic done_n;

    // -------------------------------------------------------------------------
    // Combinational next-state and output logic
    // -------------------------------------------------------------------------
    always_comb begin
        // ---- Safe defaults (hold current state, no pulses, not done) --------
        state_n      = state_r;
        src_sel_n    = src_sel;
        dst_sel_n    = dst_sel;
        conv_start_n = 1'b0;
        pool_start_n = 1'b0;
        done_n       = 1'b0;

        // Datapath selects default to Conv1 / Conv mode
        layer_sel    = 1'b0;
        mode_sel     = 1'b0;

        // ---- State transitions ----------------------------------------------
        case (state_r)

            // -- Wait for start pulse -----------------------------------------
            S_IDLE: begin
                if (start) begin
                    src_sel_n    = 1'b0;   // SRAM A -> initial source
                    dst_sel_n    = 1'b1;   // SRAM B -> initial destination
                    conv_start_n = 1'b1;
                    state_n      = S_CONV1;
                end
            end

            // -- First convolution layer (Conv1) ------------------------------
            S_CONV1: begin
                layer_sel = 1'b0;   // Conv1 weights
                mode_sel  = 1'b0;   // Convolution

                if (conv_done) begin
                    // Swap ping-pong buffers: previous dst becomes new src
                    src_sel_n    = dst_sel;
                    dst_sel_n    = src_sel;
                    conv_start_n = 1'b1;
                    state_n      = S_CONV2;
                end
            end

            // -- Second convolution layer (Conv2) -----------------------------
            S_CONV2: begin
                layer_sel = 1'b1;   // Conv2 weights
                mode_sel  = 1'b0;   // Convolution

                if (conv_done) begin
                    // Swap ping-pong buffers before pooling
                    src_sel_n    = dst_sel;
                    dst_sel_n    = src_sel;
                    pool_start_n = 1'b1;
                    state_n      = S_POOL;
                end
            end

            // -- Max/Avg Pooling ----------------------------------------------
            S_POOL: begin
                layer_sel = 1'b1;   // Retain Conv2 context
                mode_sel  = 1'b1;   // Pooling

                if (pool_done) begin
                    done_n  = 1'b1;
                    state_n = S_DONE;
                end
            end

            // -- Processing complete, assert done and wait --------------------
            S_DONE: begin
                done_n = 1'b1;   // Hold done until start re-triggers

                if (start) begin
                    // Re-arm for a new inference pass
                    src_sel_n    = 1'b0;
                    dst_sel_n    = 1'b1;
                    conv_start_n = 1'b1;
                    done_n       = 1'b0;   // Clear done on restart
                    state_n      = S_CONV1;
                end
            end

            // -- Unreachable: safe recovery ----------------------------------
            default: begin
                state_n = S_IDLE;
            end

        endcase
    end

    // -------------------------------------------------------------------------
    // Sequential state and output registers
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r    <= S_IDLE;
            src_sel    <= 1'b0;
            dst_sel    <= 1'b1;
            conv_start <= 1'b0;
            pool_start <= 1'b0;
            done       <= 1'b0;
        end else begin
            state_r    <= state_n;
            src_sel    <= src_sel_n;
            dst_sel    <= dst_sel_n;
            conv_start <= conv_start_n;
            pool_start <= pool_start_n;
            done       <= done_n;
        end
    end

endmodule : controller_fsm

`default_nettype wire
// =============================================================================
// End of controller_fsm.sv
// =============================================================================