// tb_full_adder.v
// Simple testbench for a 3-input 2-output full adder written by HMD

module tb_full_adder;
    
    //inputs
    reg a;
    reg b;
    reg Cin;
    
    //outputs
    wire SUM; 
    wire Cout;

// instantiate main module
full_adder uut (.A(a), .B(b), .Cin(Cin), .SUM(SUM), .Cout(Cout));

// test_vectors
initial begin
    a = 0; b = 0;
    #10 a = 0; b = 1;
    #10 a = 1; b = 0;
    #10 a = 1; b = 1;

    #10 $stop; // Stop simulation
end

// Display outputs
initial begin
    $monitor("Time=%0t | A=%b B=%b | SUM=%b Cout=%b" , $time, A, B, SUM, Cout)
end

endmodule