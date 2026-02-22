`timescale 1ns/1ps

module tb_controller_fsm;

  logic clk;
  logic rst_n;

  logic start;
  logic conv_done;
  logic pool_done;

  logic conv_start;
  logic pool_start;

  logic layer_sel;
  logic mode_sel;
  logic src_sel;
  logic dst_sel;
  logic done;

  // DUT
  controller_fsm dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .conv_done(conv_done),
    .pool_done(pool_done),
    .conv_start(conv_start),
    .pool_start(pool_start),
    .layer_sel(layer_sel),
    .mode_sel(mode_sel),
    .src_sel(src_sel),
    .dst_sel(dst_sel),
    .done(done)
  );

  // clock: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // counters for quick validation
  int conv_start_cnt;
  int pool_start_cnt;

  // count pulses
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      conv_start_cnt <= 0;
      pool_start_cnt <= 0;
    end else begin
      if (conv_start) conv_start_cnt <= conv_start_cnt + 1;
      if (pool_start) pool_start_cnt <= pool_start_cnt + 1;
    end
  end

  // simple monitor (prints key signals each cycle)
  always_ff @(posedge clk) begin
    if (rst_n) begin
      $display("[%0t] st=%0d start=%0b conv_start=%0b conv_done=%0b pool_start=%0b pool_done=%0b | layer_sel=%0b mode_sel=%0b src=%0b dst=%0b done=%0b",
               $time, dut.state, start, conv_start, conv_done, pool_start, pool_done,
               layer_sel, mode_sel, src_sel, dst_sel, done);
    end
  end

  // stimulus
  initial begin
    // init
    start     = 0;
    conv_done = 0;
    pool_done = 0;

    // reset
    rst_n = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;

    // start pulse
    @(posedge clk);
    start <= 1;
    @(posedge clk);
    start <= 0;

    // wait some cycles then finish conv1
    repeat(6) @(posedge clk);
    conv_done <= 1;
    @(posedge clk);
    conv_done <= 0;

    // wait some cycles then finish conv2
    repeat(8) @(posedge clk);
    conv_done <= 1;
    @(posedge clk);
    conv_done <= 0;

    // wait some cycles then finish pool
    repeat(5) @(posedge clk);
    pool_done <= 1;
    @(posedge clk);
    pool_done <= 0;

    // give 2 cycles to settle
    repeat(2) @(posedge clk);

    // checks
    if (conv_start_cnt !== 2) begin
      $display("ERROR: conv_start_cnt=%0d (expected 2)", conv_start_cnt);
      $fatal;
    end
    if (pool_start_cnt !== 1) begin
      $display("ERROR: pool_start_cnt=%0d (expected 1)", pool_start_cnt);
      $fatal;
    end
    if (done !== 1'b1) begin
      $display("ERROR: done=%0b (expected 1)", done);
      $fatal;
    end

    $display("PASS ✅  conv_start_cnt=2, pool_start_cnt=1, done=1");
    $finish;
  end

endmodule