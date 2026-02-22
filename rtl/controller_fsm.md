module controller_fsm (
    input  logic clk,
    input  logic rst_n,

    input  logic start,       // pulse or level (we treat as pulse)
    input  logic conv_done,
    input  logic pool_done,

    output logic conv_start,   // 1-cycle pulse
    output logic pool_start,   // 1-cycle pulse

    output logic layer_sel,    // 0: Conv1, 1: Conv2
    output logic mode_sel,     // 0: Conv,  1: Pool

    output logic src_sel,      // 0: SRAM A, 1: SRAM B
    output logic dst_sel,      // 0: SRAM A, 1: SRAM B

    output logic done
);

    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_CONV1 = 3'd1,
        S_CONV2 = 3'd2,
        S_POOL  = 3'd3,
        S_DONE  = 3'd4
    } state_t;

    state_t state, state_n;

    // Ping-pong registers
    logic src_sel_r, dst_sel_r;
    logic src_sel_n, dst_sel_n;

    // Start pulse generation (one-cycle) when entering a state
    logic conv_start_n, pool_start_n;

    // combinational defaults
    always_comb begin
        state_n      = state;

        // keep current ping-pong by default
        src_sel_n    = src_sel_r;
        dst_sel_n    = dst_sel_r;

        // defaults for outputs
        conv_start_n = 1'b0;
        pool_start_n = 1'b0;

        // defaults for selectors
        layer_sel    = 1'b0;   // conv1
        mode_sel     = 1'b0;   // conv

        done         = 1'b0;

        unique case (state)
            S_IDLE: begin
                // initial ping-pong mapping at start of a run
                // A -> B
                if (start) begin
                    src_sel_n    = 1'b0;  // A
                    dst_sel_n    = 1'b1;  // B

                    state_n      = S_CONV1;
                    conv_start_n = 1'b1;  // trigger conv engine
                end
            end

            S_CONV1: begin
                layer_sel = 1'b0; // Conv1
                mode_sel  = 1'b0; // Conv
                if (conv_done) begin
                    // swap buffers for next layer
                    src_sel_n = dst_sel_r;
                    dst_sel_n = src_sel_r;

                    state_n      = S_CONV2;
                    conv_start_n = 1'b1; // trigger conv engine for Conv2
                end
            end

            S_CONV2: begin
                layer_sel = 1'b1; // Conv2
                mode_sel  = 1'b0; // Conv
                if (conv_done) begin
                    // swap buffers for pooling
                    src_sel_n = dst_sel_r;
                    dst_sel_n = src_sel_r;

                    state_n      = S_POOL;
                    pool_start_n = 1'b1; // trigger pool engine
                end
            end

            S_POOL: begin
                mode_sel = 1'b1; // Pool
                if (pool_done) begin
                    state_n = S_DONE;
                end
            end

            S_DONE: begin
                done = 1'b1;
                // optional: wait for start to go low then high again
                if (start) begin
                    // restart immediately if user asserts start again
                    src_sel_n    = 1'b0; // A
                    dst_sel_n    = 1'b1; // B
                    state_n      = S_CONV1;
                    conv_start_n = 1'b1;
                    done         = 1'b0;
                end
            end

            default: begin
                state_n = S_IDLE;
            end
        endcase
    end

    // sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            src_sel_r  <= 1'b0;
            dst_sel_r  <= 1'b1;
            conv_start <= 1'b0;
            pool_start <= 1'b0;
        end else begin
            state      <= state_n;
            src_sel_r  <= src_sel_n;
            dst_sel_r  <= dst_sel_n;

            // generate 1-cycle pulses
            conv_start <= conv_start_n;
            pool_start <= pool_start_n;
        end
    end

    // drive outputs from regs
    always_comb begin
        src_sel = src_sel_r;
        dst_sel = dst_sel_r;
    end

endmodule