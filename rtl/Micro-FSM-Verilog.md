module conv_fsm #(
    parameter H        = 32,
    parameter W        = 32,
    parameter CIN_MAX  = 4,
    parameter COUT_MAX = 8
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire         start,       // شروع لایه
    input  wire [7:0]   Cin,         // تعداد کانال ورودی واقعی
    input  wire [7:0]   Cout,        // تعداد کانال خروجی واقعی

    // اینترفیس ورودی
    output reg          in_req,
    output reg  [15:0]  in_addr,
    input  wire [15:0]  in_data,     // a

    // اینترفیس وزن
    output reg          w_req,
    output reg  [15:0]  w_addr,
    input  wire [15:0]  w_data,      // w

    // اینترفیس خروجی
    output reg          out_we,
    output reg  [15:0]  out_addr,
    output reg  [15:0]  out_data,

    // MAC
    output reg          mac_valid,
    output reg  [15:0]  mac_a,
    output reg  [15:0]  mac_w,
    input  wire [31:0]  mac_out,

    output reg          done
);

    // -------------------------
    // شمارنده‌ها
    // -------------------------
    reg [7:0] fout_cnt;
    reg [7:0] cin_cnt;
    reg [5:0] y_cnt;   // 0..31
    reg [5:0] x_cnt;   // 0..31
    reg [1:0] ky_cnt;  // 0..2
    reg [1:0] kx_cnt;  // 0..2

    reg [31:0] acc;

    // -------------------------
    // حالت‌ها
    // -------------------------
    typedef enum logic [3:0] {
        S_IDLE       = 4'd0,
        S_INIT_FOUT  = 4'd1,
        S_INIT_Y     = 4'd2,
        S_INIT_X     = 4'd3,
        S_INIT_CIN   = 4'd4,
        S_INIT_KY    = 4'd5,
        S_INIT_KX    = 4'd6,
        S_READ       = 4'd7,
        S_MAC        = 4'd8,
        S_NEXT_K     = 4'd9,
        S_QUANT_RELU = 4'd10,
        S_WRITE      = 4'd11,
        S_NEXT_XYF   = 4'd12,
        S_DONE       = 4'd13
    } state_t;

    state_t state, next_state;

    // -------------------------
    // رجیستر حالت
    // -------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // -------------------------
    // منطق حالت بعدی
    // -------------------------
    always @* begin
        next_state = state;
        case (state)
            S_IDLE:       next_state = start ? S_INIT_FOUT : S_IDLE;

            S_INIT_FOUT:  next_state = S_INIT_Y;
            S_INIT_Y:     next_state = S_INIT_X;
            S_INIT_X:     next_state = S_INIT_CIN;
            S_INIT_CIN:   next_state = S_INIT_KY;
            S_INIT_KY:    next_state = S_INIT_KX;
            S_INIT_KX:    next_state = S_READ;

            S_READ:       next_state = S_MAC;
            S_MAC:        next_state = S_NEXT_K;

            S_NEXT_K: begin
                if (kx_cnt < 2)
                    next_state = S_INIT_KX;
                else if (ky_cnt < 2)
                    next_state = S_INIT_KY;
                else if (cin_cnt < Cin-1)
                    next_state = S_INIT_CIN;
                else
                    next_state = S_QUANT_RELU;
            end

            S_QUANT_RELU: next_state = S_WRITE;
            S_WRITE:      next_state = S_NEXT_XYF;

            S_NEXT_XYF: begin
                if (x_cnt < W-1)
                    next_state = S_INIT_X;
                else if (y_cnt < H-1)
                    next_state = S_INIT_Y;
                else if (fout_cnt < Cout-1)
                    next_state = S_INIT_FOUT;
                else
                    next_state = S_DONE;
            end

            S_DONE:       next_state = S_IDLE;
            default:      next_state = S_IDLE;
        endcase
    end

    // -------------------------
    // منطق ترتیبی و شمارنده‌ها
    // -------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fout_cnt <= 0;
            cin_cnt  <= 0;
            y_cnt    <= 0;
            x_cnt    <= 0;
            ky_cnt   <= 0;
            kx_cnt   <= 0;
            acc      <= 0;
            done     <= 0;

            in_req   <= 0;
            w_req    <= 0;
            out_we   <= 0;
            mac_valid<= 0;
        end else begin
            // پیش‌فرض‌ها
            in_req    <= 0;
            w_req     <= 0;
            out_we    <= 0;
            mac_valid <= 0;
            done      <= 0;

            case (state)
                S_INIT_FOUT: begin
                    fout_cnt <= 0;
                    y_cnt    <= 0;
                    x_cnt    <= 0;
                end

                S_INIT_Y: begin
                    y_cnt <= (state == S_INIT_FOUT) ? 0 : y_cnt;
                    x_cnt <= 0;
                end

                S_INIT_X: begin
                    x_cnt <= 0;
                    acc   <= 0;
                end

                S_INIT_CIN: begin
                    cin_cnt <= 0;
                end

                S_INIT_KY: begin
                    ky_cnt <= 0;
                end

                S_INIT_KX: begin
                    kx_cnt <= 0;
                end

                S_READ: begin
                    // آدرس‌دهی ورودی و وزن (ساده و نمادین)
                    in_req  <= 1'b1;
                    w_req   <= 1'b1;
                    // اینجا باید آدرس واقعی را بر اساس layout خودت بسازی
                    in_addr <= /* addr_in(cin_cnt, y_cnt+ky_cnt-1, x_cnt+kx_cnt-1) */ 16'd0;
                    w_addr  <= /* addr_w(fout_cnt, cin_cnt, ky_cnt, kx_cnt) */       16'd0;

                    mac_a   <= in_data;
                    mac_w   <= w_data;
                    mac_valid <= 1'b1;
                end

                S_MAC: begin
                    acc <= acc + mac_out;
                end

                S_NEXT_K: begin
                    if (kx_cnt < 2)
                        kx_cnt <= kx_cnt + 1;
                    else begin
                        kx_cnt <= 0;
                        if (ky_cnt < 2)
                            ky_cnt <= ky_cnt + 1;
                        else begin
                            ky_cnt <= 0;
                            if (cin_cnt < Cin-1)
                                cin_cnt <= cin_cnt + 1;
                        end
                    end
                end

                S_QUANT_RELU: begin
                    // quantize + sat + ReLU (نمادین)
                    // فرض: mac_out در acc است
                    // اینجا می‌تونی تابع واقعی‌ات را جایگزین کنی
                    if ($signed(acc[31:24]) < 0)
                        out_data <= 16'd0;
                    else
                        out_data <= acc[23:8]; // مثال: بریدن به 16 بیت
                end

                S_WRITE: begin
                    out_we   <= 1'b1;
                    out_addr <= /* addr_out(fout_cnt, y_cnt, x_cnt) */ 16'd0;
                end

                S_NEXT_XYF: begin
                    if (x_cnt < W-1)
                        x_cnt <= x_cnt + 1;
                    else begin
                        x_cnt <= 0;
                        if (y_cnt < H-1)
                            y_cnt <= y_cnt + 1;
                        else begin
                            y_cnt <= 0;
                            if (fout_cnt < Cout-1)
                                fout_cnt <= fout_cnt + 1;
                        end
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
