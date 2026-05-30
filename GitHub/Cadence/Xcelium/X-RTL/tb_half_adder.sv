// tb_half_adder.v
// Simple testbench for 2-input 2-output half adder written by HMD

module tb_half_adder;

// input/output determination
    reg A;
    reg B;
    wire SUM;
    wire CARRY;

// instantiate main module
half_adder uut (.A(A), .B(B), .SUM(SUM), .CARRY(CARRY));

// test_vectors
initial begin
    a = 0; b = 0;
    #10 a = 0; b = 1;
    #10 a = 1; b = 0;
    #10 a = 1; b = 1;

    #10 $stop;  // Stop simulation
end

// outputs display
initial begin
    $monitor("time=%0t | A=%b B=%b | SUM=%b CARRY=%b", $time, A, B, SUM, CARRY);
end

endmodule