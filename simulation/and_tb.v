// and_tb.v
// Testbench for and_gate

`timescale 1ns/1ps

module and_tb;
    reg a;
    reg b;
    wire y;

    //Instantiate the DUT(Device Under Test)
    and_gate dut (
        .a(a),
        .b(b),
        .y(y)
    );

 initial begin
    //display header
    $display("Time | a b | y")
    $monitor("%4t | %b %b | %b", $time, a, b, y);
    // Apply test vectors
    a = 0; b = 0; #10;
    a = 0; b = 1; #10;
    a = 1; b = 0; #10;
    a = 1; b = 1; #10;

    //End Simulation
 end
 
 endmodule