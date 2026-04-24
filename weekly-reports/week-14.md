# Weekly Progress Report – Week 14
**Date:** April 24, 2026

### Accomplished This Week

  - Prepared the CNN accelerator RTL for initial ASIC synthesis using Cadence Genus:
    - Reviewed synthesizability of the RTL modules
    - Cleaned simulation-only constructs
    - Fixed synthesis-incompatible coding styles
    - Prepared a dedicated Genus synthesis script (`run_genus.tcl`)

  - Set up the synthesis environment for IHP SG13G2 130 nm technology:
    - Used the SG13G2 standard-cell Liberty file from the OpenFPGA/IHP library set (provided by Professor Aschauer)
    - Target library: `sg13g2_stdcell_typ_1p20V_25C.lib`
    - Target corner: typical, 1.20 V, 25 °C
    - Target clock: 100 MHz (`10 ns` period)

  - Created the synthesis script flow:
    - Read RTL files in dependency order
    - Elaborated the top module `cnn_top`
    - Applied basic timing constraints using SDC
    - Ran the Genus synthesis stages:
      - `syn_generic`
      - `syn_map`
      - `syn_opt`

  - Generated synthesis outputs:
    - Gate-level netlist
    - SDC constraint file
    - Genus database
    - Area report
    - Timing reports
    - Power report
    - QoR report

### RTL / Synthesis Files

  - [rtl/run_genus.tcl](../rtl/run_genus.tcl)
  - [rtl/cnn_top_netlist.v](../rtl/cnn_top_netlist.v)
  - [rtl/cnn_top.sdc](../rtl/cnn_top.sdc)
  - [rtl/cnn_top_genus.db](../rtl/cnn_top_genus.db)
  - [rtl/area.rpt](../rtl/area.rpt)
  - [rtl/timing_setup.rpt](../rtl/timing_setup.rpt)
  - [rtl/timing_hold.rpt](../rtl/timing_hold.rpt)
  - [rtl/power.rpt](../rtl/power.rpt)
  - [rtl/qor.rpt](../rtl/qor.rpt)

### Results & Outputs

  - Initial synthesis completed successfully in Cadence Genus.
  - No setup timing violations were reported.
  - Worst reported setup slack: approximately `7571 ps`
  - Target clock period: `10 ns`
  - Total negative slack (TNS): `0`
  - Number of violating paths: `0`

  - Reported synthesis area:
    - Cell area: `3519.596 µm²`
    - Net area: `1792.091 µm²`
    - Total area: `5311.687 µm²`

  - Reported instance statistics:
    - Leaf instance count: `208`
    - Sequential instance count: `40`
    - Combinational instance count: `168`
    - Hierarchical instance count: `3`

  - Reported power:
    - Total estimated power: `2.37881e µW`
    - Register power dominates the estimate
    - Logic and clock switching power were also reported

### Current Architecture Status (End of Week 14)

| Module             | Status                              | Notes                                           |
|--------------------|-------------------------------------|-------------------------------------------------|
| controller_fsm     | Synthesized                         | Included in the final netlist                   |
| addr_gen           | Synthesized                         | Included in the final netlist                   |
| feature_sram       | Optimized away Behavioral SRAM      | Was not preserved in the final netlist          |
| weight_rom         | Optimized away ROM logic            | Was not preserved in the final netlist          |
| conv_engine        | Optimized away Convolution datapath | Was not preserved in the final netlist          |
| pool_engine        | Synthesized                         | Included in the final netlist (2×2 max-pooling) |
| cnn_top            | Synthesized                         | Top-level module generated                      |

**ASIC synthesis flow Partially validated Genus flow works, but full datapath synthesis still needs correction**


### Challenges & Blocking Points

  - Several RTL constructs were not directly synthesis-friendly.
→ **Solution:** Reviewed and cleaned problematic RTL sections before running Genus again.

  - The first successful synthesis did not preserve all intended accelerator modules.
→ Issue: `conv_engine`, `feature_sram`, and `weight_rom` were optimized away because their outputs were not functionally required at the top-level output, due to the behavioral SRAM.

  - The current top-level output is mainly `done`, so Genus removed large internal datapath logic that did not affect observable outputs.
→ **Solution:** The next RTL revision should preserve internal datapath activity by connecting meaningful outputs, debug signals, or synthesis-preserved logic.

  - The reported timing, area, and power values are currently too optimistic.
→ Reason: They only represent the remaining synthesized logic, not the complete CNN accelerator datapath.

  - Real SRAM integration is still unresolved.
→ Current status: Behavioral SRAM was used for initial synthesis, but SRAM macro replacement should be investigated for the next ASIC flow stages.

### Plan for Next Week (Week 15)

  - Replace behavioral SRAM with an SG13G2 SRAM macro
  - Fix top-level RTL so that the complete datapath is preserved during synthesis
  - Ensure `conv_engine`, `feature_sram`, and `weight_rom` are not optimized away
  - Re-run Genus synthesis with the corrected RTL
  - Compare the new synthesis reports with the current baseline
  - Prepare the design for the next ASIC flow stage:
    - post-synthesis simulation
    - more realistic area/timing analysis
    - preparation for physical design / Innovus