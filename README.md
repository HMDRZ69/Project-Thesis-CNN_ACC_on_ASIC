# Digital Design of a Basic CNN Accelerator on ASIC in IHP 130nm Technology

**Master's Project**  
**Student:** Hamed Ramezanzadeh  
**Supervisor:** Prof. Dr.-Ing Florian Aschauer  
**Start Date:** November 2025

---

## Project Status

| Metric | Result |
|---|---|
| RTL Simulation | ✅ 20/20 PASS |
| Gate-Level Simulation | ✅ 19/19 PASS |
| DRC Violations | ✅ 0 |
| Post-route WNS @ 100 MHz | −0.030 ns (effectively timing-met) |
| Leaf cells (Genus) | 4,906 + 4 IHP SRAM macros |
| Cell area (Genus) | 660,659 µm² |
| Post-route area (Innovus) | 630,304 µm² | 
| Total power | 23.74 mW |

**The full ASIC flow is complete:**  
RTL Design → Functional Simulation → Synthesis → Gate-Level Simulation → Place & Route → GDSII  
Primary deliverable: `Cadence/Innovus/innovus_out/gds/cnn_top_final.gds`

---

## Project Overview

Design and implementation of a lightweight digital hardware accelerator for a basic Convolutional Neural Network (CNN) using **IHP SG13G2 130nm** CMOS technology on an ASIC.

The project validates the complete ASIC digital design flow using the Cadence toolchain (Xcelium → Genus → Innovus).

### CNN Architecture

- **Input:** 32×32×1 grayscale
- **Conv1:** 3×3, stride=1, pad=1, 4 channels + ReLU
- **Conv2:** 3×3, stride=1, pad=1, 8 channels + ReLU
- **MaxPool:** 2×2, stride=2
- **Output:** 16×16×8 feature map

**Fixed-point format:**  
Activations: 8-bit unsigned | Weights: 8-bit signed | Accumulator: 32-bit

### RTL Modules

| Module | Description |
|---|---|
| `controller_fsm` | Top-level FSM controlling the full inference pipeline |
| `addr_gen` | Address generation for SRAM read/write sequencing |
| `feature_sram` | Ping-pong dual-bank SRAM for feature maps |
| `weight_rom` | Weight storage ROM |
| `conv_engine` | 3×3 MAC-based convolution engine |
| `pool_engine` | 2×2 max-pooling engine |
| `cnn_top` | Top-level integration of all modules |

---

## Repository Structure

```
├── weekly-reports/         # One Markdown progress report per week
├── Cadence/
│   ├── Xcelium/            # RTL source files, testbenches, simulation scripts & logs
│   ├── Genus/              # Synthesis scripts (run_genus.tcl), netlists, SDC, QoR reports
│   └── Innovus/            # P&R scripts (mmmc.tcl, run_innovus.tcl), GDSII, post-route reports
└── simulation/             # Early-stage waveforms and simulation outlines (Weeks 1–9)
```

---

## Getting Started

### Prerequisites

| Requirement | Details |
|---|---|
| Cadence Xcelium | 23.09 (used for RTL & GLS) |
| Cadence Genus | 23.11 (used for synthesis) |
| Cadence Innovus | 23.31 (used for P&R) |
| IHP SG13G2 PDK | Open-source: [IHP-Open-PDK/ihp-sg13g2](https://github.com/IHP-Open-PDK/ihp-sg13g2) |
| Liberty file | `sg13g2_stdcell_tt_1p20V_25C.lib` (included in PDK) |

> **Server access (OTH Regensburg):** The Cadence tools are available on the university EDA server. Contact Prof. Aschauer for access credentials.

### 1. RTL Simulation (Xcelium)

```bash
cd Cadence/Xcelium
xrun -sv <source_files> <testbench_file> -log sim.log
```

Refer to the scripts in `Cadence/Xcelium/` for the exact file list and simulation commands used in this project.

### 2. Synthesis (Genus)

```bash
cd Cadence/Genus
genus -legacy_ui -f run_genus.tcl
```

Output netlists and reports are written to `Cadence/Genus/genus_out/`.

### 3. Place & Route (Innovus)

```bash
cd Cadence/Innovus
innovus -init run_innovus.tcl
```

Final GDSII and post-route reports are written to `Cadence/Innovus/innovus_out/`.

---

## Weekly Progress

| Week | Date | Main Topic / Milestone | Report |
|---|---|---|---|
| 01 | 2025-11-07 | ASIC flow introduction & Cadence tool access | [week-01.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-01.md) |
| 02 | 2025-11-14 | Verilog basics & Half-Adder RTL + simulation | [week-02.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-02.md) |
| 03 | 2025-11-21 | AND gate, Half-Adder verification, server workflow | [week-03.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-03.md) |
| 04 | 2025-11-28 | Full-Adder RTL, simulation & IHP rules review | [week-04.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-04.md) |
| 05 | 2025-12-05 | GitHub repo structure, README & documentation cleanup | [week-05.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-05.md) |
| 06 | 2025-12-12 | SG13G2 PDK verification & local extraction attempts | [week-06.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-06.md) |
| 07 | 2025-12-18 | PDK environment scripts, workspace & OA library setup | [week-07.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-07.md) |
| 08 | 2025-12-25 | Cadence launch debugging & VM disk space resolution | [week-08.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-08.md) |
| 09 | 2026-01-18 | PDK library linkage fixes → Cadence Library Manager ready | [week-09.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-09.md) |
| 10 | 2026-02-08 | Final CNN architecture, top-level FSM RTL & simulation | [week-10.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-10.md) |
| 11 | 2026-02-15 | Address Generation (`addr_gen`) RTL & full verification | [week-11.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-11.md) |
| 12 | 2026-02-22 | Top-level integration (`cnn_top`), conv_engine interface & stub | [week-12.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-12.md) |
| 13 | 2026-03-14 | RTL finalization, full CNN datapath integration & simulation verification | [week-13.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-13.md) |
| 14 | 2026-04-24 | First ASIC synthesis (Cadence Genus), QoR analysis & optimisation issues identified | [week-14.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-14.md) |
| 15 | 2026-05-01 | Second ASIC synthesis with real SRAM macros + Gate-Level Simulation (GLS) | [week-15.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-15.md) |
| 16 | 2026-05-08 | Full design-flow review; critical `pool_engine` architectural bug identified | [week-16.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-16.md) |
| 17 | 2026-05-15 | `pool_engine` redesign + testbench fixes; RTL re-verified 20/20 PASS | [week-17.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-17.md) |
| 18 | 2026-05-22 | Re-synthesis (Genus) + GLS with corrected RTL; 19/19 PASS | [week-18.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-18.md) |
| 19 | 2026-05-28 | Innovus Place & Route → DRC-clean GDSII; WNS = −0.030 ns @ 100 MHz | [week-19.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-19.md) |

---

## Known Limitations

- **WNS at synthesis level (−52.6 ns):** Expected for a non-pipelined MAC architecture. The critical path runs through the full accumulator chain without register pipeline stages. This is a documented architectural choice, not a sign-off blocker given the project scope.
- **Weights in `weight_rom.sv` are placeholder values.** Real inference weights were not the objective of this project.

---

## Contact

For questions or feedback, open a [GitHub Issue](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/issues) or contact via email.
