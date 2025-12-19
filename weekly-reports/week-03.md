# Weekly Progress Report - Week 03
**Date:** 21.11.2025

## What have done this week:
    1. Learning Verilog structure and its operators
    2. Implemented some basic operators and adders (AND Gate, Half-adder provided) + tesetbenches as a warm-up for digital design flow
    3. Comprehension of the Verilog coding

### Results & Outputs
Successful simulation results

![Half-Adder Simulation Waveform](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/half_adder_waveform.png)

*Waveform captured from Cadence Xcelium SimVision. Inputs: a, b; Outputs: sum, carry.*

![Half-Adder Simulation Waveform](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/half_adder_Outline.png)

## Code Script
**AND Gate RTL (rtl/and_gate.v):**
// Full Code in rtl

module and_gate(
    input a,
    input b,
    output y
);
    // Behavioral continuous assignment
    assign y = a & b;
endmodule

**Half-Adder RTL (rtl/halfadder.v):**
// Full Code in rtl

module half_adder(input A, input B, output SUM, output CARRY);

    assign SUM = A ^ B;   //XOR Operation
    assign CARRY = A & B;   //AND Operation

endmodule

**Testbench (simulation/and_tb.v):**
// Full Code in rtl

initial begin
    a = 0; b = 0; #10;
    a = 0; b = 1; #10;
    a = 1; b = 0; #10;
    a = 1; b = 1; #10;

    //End Simulation
 end

**Testbench excerpt (simulation/tb_half_adder.v):**
// Full Code in rtl

initial begin
    a = 0; b = 0;
    #10 a = 0; b = 1;
    #10 a = 1; b = 0;
    #10 a = 1; b = 1;

    #10 $stop;  // Stop simulation
end

## Challenge & Blocking points
    - Code written and operated via VS Code running on Windows, but the execution could not takes place remotely on the University Server
        Write the code directly via VS Code running on the University Server (Linux)
    - Mistakes involving naming and structural format
        The observed errors were primarily due to improperly written names and incorrect structural definitions - Solved

## Plan for the Next Week:
    1. Implement Full-Adder and it's testbench
    2. Comprehension of the design flow
    3. Start studying CNN Accelerator