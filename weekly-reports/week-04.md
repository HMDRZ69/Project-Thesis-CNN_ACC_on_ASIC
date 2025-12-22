# Weekly Progress Report - Week 04
**Date:** 28.11.2025

## What have done this week:
    1. Implemented a Full-Adder along with its associated testbench
    2. Reviewed the IHP design rules

### Results & Outputs
Successful simulation results

![Half-Adder Simulation Waveform](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/half_adder_waveform.png)

*Waveform captured from Cadence Xcelium SimVision. Inputs: a, b; Outputs: sum, carry.*

![Half-Adder Simulation Outline](https://raw.githubusercontent.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/main/simulation/half_adder_Outline.png)

## Code Script
**Full-Adder RTL (rtl/fulladder.v):**
    // Full Code in rtl

   module full_adder(
        input A, input B, input Cin, output SUM, output Cout);

        assign SUM = A ^ B ^ Cin;
        assign Cout = (A & B) | (Cin & (A ^ B));

    endmodule

**Testbench (simulation/tb_half_adder.v):**
    // Full Code in rtl

    initial begin
            A = 0; B = 0; Cin = 0;
        #10 A = 0; B = 1; Cin = 0;
        #10 A = 1; B = 0; Cin = 1;
        #10 A = 1; B = 1; Cin = 1;

        #10 $stop;
    end


## Challenge & Blocking points
    - SimVision opened correctly, but no signals were visible despite a successful simulation run.
    - The problem was related to missing read access for signal values.
    SOLUTION: Re-running the simulation with proper access permissions resolved the issue and enabled waveform visualization.

## Plan for the Next Week:
    1. Ensure proper access to the SG13G2 PDK on the university server.
    2. Locate and verify the exact directory path of the SG13G2 PDK on the university server.
    3. Define and configure the required Cadence environment variables.
    4. Add the necessary configurations to the .bashrc and .cdsinit files.
    5. Prepare the Cadence Virtuoso environment to initiate the actual design phase.