# Digital Design of a Basic CNN Accelerator on an ASIC in IHP 130nm Technology

**Project / Master's Project Thesis**  
**Student:** Hamed Ramezan Zadeh  
**Supervisor:** Prof. Dr. Florian Ashauer  
**Start Date:** November 2025

### Project Overview
Design and implementation of a lightweight, digital hardware accelerator for a basic Convolutional Neural Network (CNN) using **IHP SG13S 130nm** CMOS technology.  
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
- `rtl/` → Verilog/SystemVerilog source code (controller, addr_gen, SRAM models, integration, stubs)  
- `simulation/` → testbenches, Xcelium scripts, waveform screenshots  
- `docs/` → notes, datasheets, PDK references (to be expanded)

### Weekly Progress

| Week | Date           | Main Topic / Milestone                                      | Report Link                                      |
|------|----------------|-------------------------------------------------------------|--------------------------------------------------|
| 01   | 2025-11-07    | ASIC flow introduction & Cadence tool access                | [week-01.md](weekly-reports/week-01.md)          |
| 02   | 2025-11-14    | Verilog basics & Half-Adder RTL + simulation                | [week-02.md](weekly-reports/week-02.md)          |
| 03   | 2025-11-21    | AND gate, Half-Adder verification, server workflow          | [week-03.md](weekly-reports/week-03.md)          |
| 04   | 2025-11-28    | Full-Adder RTL, simulation & IHP rules review               | [week-04.md](weekly-reports/week-04.md)          |
| 05   | 2025-12-05    | GitHub repo structure, README & documentation cleanup       | [week-05.md](weekly-reports/week-05.md)          |
| 06   | 2025-12-12    | SG13G2 PDK verification & local extraction attempts         | [week-06.md](weekly-reports/week-06.md)          |
| 07   | 2025-12-18    | PDK environment scripts, workspace & OA library setup       | [week-07.md](weekly-reports/week-07.md)          |
| 08   | 2025-12-25    | Cadence launch debugging & VM disk space resolution         | [week-08.md](weekly-reports/week-08.md)          |
| 09   | 2026-01-18    | PDK library linkage fixes → Cadence Library Manager ready   | [week-09.md](weekly-reports/week-09.md)          |
| 10   | 2026-02-08    | Final CNN architecture, top-level FSM RTL & simulation      | [week-10.md](weekly-reports/week-10.md)          |
| 11   | 2026-02-22    | Address Generation (`addr_gen`) RTL & full verification     | [week-11.md](weekly-reports/week-11.md)          |
| 12   | 2026-03-??    | Top-level integration (`cnn_top`), conv_engine interface & stub | [week-12.md](weekly-reports/week-12.md)          |

*Last updated: March 2026*  
*Current status:* Control flow, address generation and memory ping-pong fully integrated and verified. Datapath represented by behavioral stub. Ready for real convolution engine RTL implementation.

Feel free to open a GitHub Issue or contact me via email for questions, feedback or discussion.