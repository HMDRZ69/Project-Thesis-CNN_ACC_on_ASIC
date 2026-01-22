# Weekly Progress Report – Week 03  
**Date:** November 21, 2025

### Accomplished This Week
- Studied Verilog language structure, syntax, and basic operators (continuous assignments, bitwise/logical operations)
- Implemented simple combinational building blocks as warm-up for the digital design flow:
  - Basic AND gate using continuous assignment
  - Half-Adder (provided structure, verified and slightly refined)
- Developed corresponding testbenches for both designs:
  - AND gate testbench with 4 input combinations
  - Half-Adder testbench with exhaustive stimulus for all 4 input vectors
- Performed functional simulation using Cadence Xcelium on the university server:
  - Captured and verified waveforms in SimVision for both designs
  - Confirmed correct logical behavior (AND output, Half-Adder sum & carry)
- Added design artifacts to the repository:
  - RTL: `rtl/and_gate.v`, `rtl/halfadder.v`
  - Testbenches: `simulation/and_tb.v`, `simulation/tb_half_adder.v`
  - Waveform screenshot: `simulation/half_adder_waveform.png`
  - Outline/block diagram: `simulation/half_adder_Outline.png`

### Results & Outputs
Successful functional simulations with no mismatches.

![Half-Adder Simulation Waveform](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/half_adder_waveform.png)  
*Waveform captured from Cadence Xcelium SimVision. Inputs: a, b; Outputs: sum, carry.*

![Half-Adder Simulation Outline](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/half_adder_Outline.png)  
*High-level block diagram of the Half-Adder.*

### Code Snippets
**AND Gate RTL (rtl/and_gate.v):**
```verilog
module and_gate(
    input a,
    input b,
    output y
);
    assign y = a & b;  // Behavioral continuous assignment
endmodule
Half-Adder RTL (rtl/halfadder.v):
verilogmodule half_adder(
    input A,
    input B,
    output SUM,
    output CARRY
);
    assign SUM   = A ^ B;   // XOR operation
    assign CARRY = A & B;   // AND operation
endmodule
Testbench excerpt – AND gate (simulation/and_tb.v):
veriloginitial begin
    a = 0; b = 0; #10;
    a = 0; b = 1; #10;
    a = 1; b = 0; #10;
    a = 1; b = 1; #10;
    // End of simulation
end
Testbench excerpt – Half-Adder (simulation/tb_half_adder.v):
veriloginitial begin
    a = 0; b = 0;
    #10 a = 0; b = 1;
    #10 a = 1; b = 0;
    #10 a = 1; b = 1;
    #10 $stop;  // Stop simulation
end
### Key Learnings / Insights

Verilog syntax for modules, ports, and continuous assignments is straightforward but requires precise naming and structure
Running simulations remotely on Linux server (via VS Code) is more reliable than local Windows execution for Cadence tools
Small naming/structure errors cause compilation failures — careful consistency is critical

### Challenges & Blocking Points

Code written in VS Code on Windows could not be executed remotely on the university server
→ Solution: Shifted to writing and running code directly via VS Code connected to the university Linux server
Frequent mistakes in file naming and module/structure definitions
→ Solution: Corrected naming conventions and structural format; double-checked port lists and syntax

### Plan for Next Week

Implement a 1-bit Full-Adder (with carry-in) in Verilog and develop its testbench
Perform exhaustive simulation and waveform analysis for the Full-Adder
Review the IHP SG13G2 design rules (focus on standard cell compatibility and basic layout constraints)