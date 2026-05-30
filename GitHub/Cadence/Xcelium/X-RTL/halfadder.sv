// half_adder.v
// Simple 2-input 2-output half adder module written by HMD

module half_adder(input A, input B, output SUM, output CARRY);

    assign SUM = A ^ B;   //XOR Operation
    assign CARRY = A & B;   //AND Operation

endmodule
