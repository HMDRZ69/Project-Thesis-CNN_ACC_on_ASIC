# Digital Design of a Basic CNN Accelerator on ASIC in IHP 130nm Technology

**Master's Project Thesis**  
**Student:** Hamed Ramezanzadeh  
**Supervisor:** Prof. Dr. Florian Aschauer  
**Start Date:** November 2025

### Project Overview

Design and implementation of a lightweight, digital hardware accelerator for a basic Convolutional Neural Network (CNN) using **IHP SG13S 130nm** CMOS technology on an ASIC.  
The project validates the complete ASIC digital design flow:  
RTL design → functional simulation → synthesis preparation → place & route → post-layout verification

**Current network architecture (locked since Week 10):**

- Input: 32×32×1 grayscale
- Conv1: 3×3, stride=1, pad=1, 4 channels + ReLU
- Conv2: 3×3, stride=1, pad=1, 8 channels + ReLU
- MaxPool: 2×2, stride=2
- Output: 16×16×8 feature map

Fixed-point format:  
Activations: 8-bit unsigned | Weights: 8-bit signed | Accumulator: 32-bit

### Repository Structure

- `weekly-reports/` → one Markdown file per week
- `Cadence/Xcelium/` → Xcelium scripts (testbenches, Verilog/SystemVerilog source code), simulation logs
- `Cadence/Genus/` → Genus synthesis scripts (run_genus.tcl, Verilog/SystemVerilog source code), genus_out reports (netlist, reports, SDC)
- `Cadence/Innovus` →  Innovus P&R scripts (mmmc.tcl, run_innovus.tcl), innovus_out deliverables (GDSII, post-route netlist, SDC, DRC report)
- `simulation` → Basic simulation waveforms and outlines from starting weeks.  

### Weekly Progress

| Week | Date       | Main Topic / Milestone                                                              | Report Link                                                                               |
| ---- | ---------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 01   | 2025-11-07 | ASIC flow introduction & Cadence tool access                                        | [week-01.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-01.md) |
| 02   | 2025-11-14 | Verilog basics & Half-Adder RTL + simulation                                        | [week-02.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-02.md) |
| 03   | 2025-11-21 | AND gate, Half-Adder verification, server workflow                                  | [week-03.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-03.md) |
| 04   | 2025-11-28 | Full-Adder RTL, simulation & IHP rules review                                       | [week-04.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-04.md) |
| 05   | 2025-12-05 | GitHub repo structure, README & documentation cleanup                               | [week-05.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-05.md) |
| 06   | 2025-12-12 | SG13G2 PDK verification & local extraction attempts                                 | [week-06.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-06.md) |
| 07   | 2025-12-18 | PDK environment scripts, workspace & OA library setup                               | [week-07.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-07.md) |
| 08   | 2025-12-25 | Cadence launch debugging & VM disk space resolution                                 | [week-08.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-08.md) |
| 09   | 2026-01-18 | PDK library linkage fixes → Cadence Library Manager ready                           | [week-09.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-09.md) |
| 10   | 2026-02-08 | Final CNN architecture, top-level FSM RTL & simulation                              | [week-10.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-10.md) |
| 11   | 2026-02-15 | Address Generation (`addr_gen`) RTL & full verification                             | [week-11.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-11.md) |
| 12   | 2026-02-22 | Top-level integration (`cnn_top`), conv_engine interface & stub                     | [week-12.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-12.md) |
| 13   | 2026-03-14 | RTL finalization, full CNN datapath integration & simulation verification           | [week-13.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-13.md) |
| 14   | 2026-04-24 | First ASIC synthesis (Cadence Genus), QoR analysis & optimisation issues identified | [week-14.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-14.md) |
| 15   | 2026-05-01 | Second ASIC synthesis with real SRAM macros + Gate-Level Simulation (GLS)          | [week-15.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-15.md) |
| 16   | 2026-05-08 | Full design-flow review; critical `pool_engine` architectural bug identified        | [week-16.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-16.md) |
| 17   | 2026-05-15 | `pool_engine` redesign + testbench fixes; RTL re-verified 20/20 PASS               | [week-17.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-17.md) |
| 18   | 2026-05-22 | Re-synthesis (Genus) + GLS with corrected RTL; 19/19 PASS                          | [week-18.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-18.md) |
| 19   | 2026-05-28 | Innovus Place & Route → DRC-clean GDSII; WNS = −0.030 ns @ 100 MHz                | [week-19.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-19.md) |


*Last updated: May 2026*  
*Current status:*

- **The full Xcelium → Genus → Innovus ASIC flow is complete.** A DRC-clean GDSII of the CNN accelerator has been produced on IHP SG13G2 130nm using the full Cadence toolchain.
- All 7 RTL modules (`controller_fsm`, `addr_gen`, `feature_sram`, `weight_rom`, `conv_engine`, `pool_engine`, `cnn_top`) are implemented, functionally verified, and carried through to physical layout.
- RTL integration simulation: **20/20 PASS** | Gate-Level Simulation: **19/19 PASS**
- Synthesis (Genus 23.11): 4,906 leaf cells + 4 real IHP SRAM macros | Cell area: 660,659 µm² | Total power: 23.74 mW | WNS: −52.6 ns (non-pipelined MAC — documented architectural limitation)
- Place & Route (Innovus 23.31): Post-route area 630,304 µm² | DRC: **0 violations** | Post-route WNS: **−0.030 ns @ 100 MHz** (within geometric RC extraction uncertainty — effectively timing-met)
- Primary thesis project course deliverable achieved: `innovus_out/gds/cnn_top_final.gds`


Feel free to open a GitHub Issue or contact me via email for questions, feedback or discussion.
