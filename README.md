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
| Core area (Innovus) | 453,727 µm² |
| Total power | 23.74 mW |

**The full ASIC flow is complete:**
RTL Design → Functional Simulation → Synthesis → Gate-Level Simulation → Place & Route → GDSII
Primary deliverable: `Cadence/Innovus/innovus_out/gds/cnn_top_final.gds`

---

## Project Overview

Design and implementation of a lightweight digital hardware accelerator for a basic Convolutional Neural Network (CNN) using **IHP SG13G2 130nm** CMOS technology on an ASIC.

The project validates the complete ASIC digital design flow using the Cadence toolchain (Xcelium → Genus → Innovus).

### CNN Architecture

- **Input:** 32×32×1 grayscale format ramp pattern
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
├── weekly-reports/              # One Markdown progress report per week
├── Cadence/
│   ├── Xcelium/                 # RTL source files, testbenches, simulation scripts & logs
│   ├── Genus/                   # Synthesis scripts (run_genus.tcl), netlists, SDC, reports
│   └── Innovus/                 # P&R scripts (mmmc.tcl, run_innovus.tcl), GDSII, reports
├── References/
│   ├── gr_common.py             # Shared golden-reference model (SRAM latency, addressing)
│   ├── gr0_relu_clip.py         # GR0: ReLU clipping check  (oc=0, y=1, x=1 → expected 0)
│   ├── gr1_addressing.py        # GR1: SRAM latency + padding (oc=1, y=0, x=1 → expected 1)
│   ├── gr2_pixel_exact.py       # GR2: Full MAC check         (oc=1, y=1, x=1 → expected 33)
│   └── cross_check.py           # Automated cross-check: Python model vs. Xcelium log
└── simulation/                  # Early-stage waveforms and simulation outlines (Weeks 1–9)
```

---

## Prerequisites

| Requirement | Version / Details |
|---|---|
| Cadence Xcelium | **24.03** (RTL sim + GLS) |
| Cadence Genus | **23.11** (logic synthesis) |
| Cadence Innovus | **23.31** (place & route) |
| IHP SG13G2 PDK | Open-source — see [IHP-Open-PDK/ihp-sg13g2](https://github.com/IHP-GmbH/IHP-Open-PDK) |
| SRAM macro | `RM_IHPSG13_1P_4096x8_c3_bm_bist` — source at [baruaeee/DD_Lab_exercise](https://github.com/baruaeee/DD_Lab_exercise) |
| Liberty file | `sg13g2_stdcell_typ_1p20V_25C.lib` (included in PDK) |
| Python | ≥ 3.8 (for golden-reference scripts, no extra packages needed) |

> **Server access (OTH Regensburg):** The Cadence tools are available on the university EDA server `ei-vm-018.othr.de`. Contact Prof. Aschauer for access credentials.

---

## Step-by-Step Execution Guide

All commands are run from the server at `/home/<user>/asic_project/`.

### 1. RTL Simulation (Xcelium)

```bash
cd /home/rah47472/asic_project

xrun -sv \
  -timescale 1ns/1ps \
  -notimingchecks \
  libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_core_behavioral_bm_bist.v \
  libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_4096x8_c3_bm_bist.v \
  Xcelium/controller_fsm.sv \
  Xcelium/addr_gen.sv \
  Xcelium/feature_sram.sv \
  Xcelium/weight_rom.sv \
  Xcelium/conv_engine.sv \
  Xcelium/pool_engine.sv \
  Xcelium/cnn_top.sv \
  Xcelium/tb_cnn_top.sv \
  -l cnn_sim.log 2>&1 | tee cnn_run.log
```

**Expected result:** `[TB] RESULTS: 19 PASSED, 0 FAILED`

### 2. Waveform Viewing (SimVision)

To dump and view waveforms, add the following to `tb_cnn_top.sv` inside the `initial` block (or enable via a `+define` flag), then open SimVision after the run:

```bash
# Option A — open SimVision interactively after simulation
xrun -sv -timescale 1ns/1ps -notimingchecks \
  <same file list as above> \
  -gui -input waves.tcl

# Option B — dump to VCD file for offline viewing
# Add to testbench: $dumpfile("cnn_top.vcd"); $dumpvars(0, tb_cnn_top);
# Then open with:
simvision cnn_top.vcd &

# Option C — open SimVision on the existing run database
simvision xcelium.d/tb_cnn_top.shm &
```

Key signals to probe in SimVision:
```
tb_cnn_top/clk
tb_cnn_top/done
tb_cnn_top/u_dut/u_fsm/state
tb_cnn_top/u_dut/conv_out_valid
tb_cnn_top/u_dut/u_sram_a/rdata
```

### 3. Synthesis (Genus)

```bash
cd /home/rah47472/asic_project

genus -f run_genus.tcl -log genus_sram.log
```

Output files are written to `genus_out/`:
- `genus_out/netlist/cnn_top_netlist.v` — gate-level netlist
- `genus_out/sdc/cnn_top.sdc` — timing constraints
- `genus_out/reports/` — area, timing, power reports

**Expected result:** 4,906 leaf instances + 4 SRAM macros, WNS = −52.6 ns (wire-load model; resolves after P&R placement)

### 4. Gate-Level Simulation (GLS)

```bash
cd /home/rah47472/asic_project

xrun -sv \
  -define FUNCTIONAL \
  -define SYNTHESIS \
  -timescale 1ns/1ps \
  -notimingchecks \
  libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v \
  libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_core_behavioral_bm_bist.v \
  libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_4096x8_c3_bm_bist.v \
  genus_out/netlist/cnn_top_netlist.v \
  Xcelium/tb_cnn_top.sv \
  -l gls_sim.log 2>&1 | tee gls_run.log
```

**Expected result:** `[TB] RESULTS: 19 PASSED, 0 FAILED`

### 5. Golden Reference Cross-Check (Python)

Run the three independent golden-reference scripts to verify the expected values embedded in the testbench, then run the automated cross-check against the simulation log.

```bash
# Run from any machine with Python >= 3.8 (no extra packages needed)
cd References/

python3 gr0_relu_clip.py     # Expected: [PASS] output = 0
python3 gr1_addressing.py    # Expected: [PASS] output = 1
python3 gr2_pixel_exact.py   # Expected: [PASS] output = 33

# Automated cross-check: compare Python model against Xcelium log
python3 cross_check.py /path/to/cnn_sim.log
# or for GLS:
python3 cross_check.py /path/to/gls_sim.log
```

**Expected cross-check output:**
```
GR Check   Python    RTL (log)   Result
------------------------------------------
GR0         0         0           MATCH
GR1         1         1           MATCH
GR2         33        33          MATCH

[PASS] All Python golden-reference values match the RTL/GLS log.
```

> **What these scripts do:** Each script independently re-derives the expected pixel output from first principles (CHW address generation, 1-cycle SRAM read latency, INT8 MAC, ReLU), without referencing the RTL. The computed values were embedded as `localparam` constants in `tb_cnn_top.sv`. `cross_check.py` then parses the Xcelium log and confirms that RTL-simulated values match the Python model — closing the verification loop automatically.

### 6. Place & Route (Innovus)

```bash
cd /home/rah47472/asic_project

innovus -files run_innovus.tcl -log innovus_run.log
```

Output files are written to `innovus_out/`:
- `innovus_out/gds/cnn_top_final.gds` — final GDSII layout (3.1 MB, DRC-clean)
- `innovus_out/netlist/cnn_top_final.v` — post-route netlist
- `innovus_out/sdc/cnn_top_final.sdc` — post-CTS timing constraints
- `innovus_out/reports/drc.rpt` — DRC report (0 violations)
- `innovus_out/reports/area_postroute.rpt` — area breakdown
- `innovus_out/checkpoints/` — placed, CTS, and routed design snapshots

**Expected result:** DRC = 0 violations, post-route WNS = −0.030 ns @ 100 MHz

> The script opens the Innovus GUI at the end (`win; suspend`) so the layout can be inspected before exiting. Type `resume` in the terminal to continue.

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
| 17 | 2026-05-15 | `pool_engine` redesign + testbench fixes; RTL re-verified 19/19 PASS | [week-17.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-17.md) |
| 18 | 2026-05-22 | Re-synthesis (Genus) + GLS with corrected RTL; 19/19 PASS | [week-18.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-18.md) |
| 19 | 2026-05-28 | Innovus Place & Route → DRC-clean GDSII; WNS = −0.030 ns @ 100 MHz | [week-19.md](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/blob/main/weekly-reports/week-19.md) |

---

## Known Limitations

- **Timing at synthesis (WNS = −52.6 ns):** The critical path runs through the fully combinational MAC datapath (weight fetch → CSA tree → 32-bit accumulator) without pipeline registers, giving a maximum operating frequency of ~16 MHz. Closing timing at 100 MHz would require approximately 7 pipeline stages. This is a documented architectural trade-off, not a sign-off blocker given the project scope.
- **Post-route WNS = −0.030 ns:** One path misses by 30 ps under estimated RC parasitics (no QRC extraction tech file available in the lab). With a full foundry QRC deck this path would likely close cleanly.
- **Weights in `weight_rom.sv` are placeholder values.** Real inference weights and accuracy measurement were explicitly out of scope.
- **No I/O pad ring.** This is a core-only implementation. Adding a pad ring and sealring is the natural next step toward a full tapeout.

---

## Contact

For questions or feedback, open a [GitHub Issue](https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC/issues) or contact via email.