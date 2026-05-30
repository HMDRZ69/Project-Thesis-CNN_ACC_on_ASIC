// and_gate.v
// Simple 2-input AND gate - Written by HMD


module and_gate(
    input a,
    input b,
    output y
);
    // Behavioral continuous assignment
    assign y = a & b;
endmodule