// full_adder.v
// Simple Full Adder with 3 inputs and 2 outputs written by HMD

module full_adder(input A, input B, input Cin, output SUM, output Cout);

    assign SUM = A ^ B ^ Cin;
    assign Cout = (A & B) | (Cin & (A ^ B));

endmodule