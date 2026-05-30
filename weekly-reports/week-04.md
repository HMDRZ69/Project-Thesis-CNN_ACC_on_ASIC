# Weekly Progress Report – Week 04  
**Date:** November 28, 2025

### Accomplished This Week
- Designed and implemented a 1-bit **Full Adder** in Verilog:
  - Used continuous assignments for sum (3-input XOR) and carry-out logic
  - Implemented carry-out using majority function: (A&B) | (Cin&(A^B))
- Developed a testbench for the Full Adder:
  - Applied selected stimulus patterns covering different carry propagation cases
  - Used timed delays to observe signal transitions
- Performed functional simulation using Cadence Xcelium:
  - Successfully ran simulation and visualized waveforms in SimVision
  - Verified correct sum and carry-out behavior for tested input combinations
- Captured simulation results:
  - Waveform screenshot → `simulation/full_adder_waveform.png`
  - Block diagram / outline → `simulation/full_adder_outline.png`
- Reviewed the IHP SG13G2 design rules (basic overview of relevant sections for digital standard-cell design)

### Results & Outputs
Successful functional simulation with correct logical behavior observed.

![Full-Adder Simulation Waveform](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/full_adder_waveform.png)  
*Waveform captured from Cadence Xcelium SimVision. Inputs: A, B, Cin; Outputs: SUM, Cout.*

![Full-Adder Simulation Outline](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/full_adder_outline.png)  
*High-level block diagram of the Full Adder.*

### Code Snippets
**Full-Adder RTL (rtl/fulladder.v):**
```verilog
module full_adder(
    input A, input B, input Cin,
    output SUM, output Cout
);
    assign SUM  = A ^ B ^ Cin;
    assign Cout = (A & B) | (Cin & (A ^ B));
endmodule
Testbench excerpt (simulation/tb_full_adder.v):
veriloginitial begin
    A = 0; B = 0; Cin = 0;
    #10 A = 0; B = 1; Cin = 0;
    #10 A = 1; B = 0; Cin = 1;
    #10 A = 1; B = 1; Cin = 1;
    #10 $stop;
end
```
### Key Learnings / Insights

- Full-Adder logic can be concisely expressed using continuous assignments, making it easy to read and synthesize.
- Waveform visibility in SimVision depends heavily on proper signal probing and access rights during simulation setup.

### Challenges & Blocking Points

- SimVision opened correctly after simulation, but no signals were visible in the waveform viewer
→ Solution: Re-ran the simulation with correct read access permissions for signal values, which resolved the visibility issue

### Plan for Next Week

- Set up a clear GitHub repository structure optimized for weekly progress reporting
(folders for rtl/, simulation/, weekly-reports/, docs/, etc.; update README with progress table)