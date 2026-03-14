# Weekly Progress Report – Week 13  
**Date:** March 14, 2026

### Accomplished This Week
- Replaced the temporary `conv_engine_stub` with the full RTL implementation of the **Convolution Engine** (`conv_engine.sv`):
  - 4-lane parallel MAC datapath
  - Multiplier units for activation–weight products
  - Adder tree for partial sum accumulation
  - 32-bit accumulator with clear-on-first-tap behavior
  - Inline ReLU activation
  - 8-bit output quantization and saturation
- Connected the real `conv_engine` output to the SRAM write path:
  - Removed stub-driven write logic
  - `conv_out_valid` now drives SRAM write enable
  - Convolution output written directly into destination feature map bank
- Updated activation read interface:
  - 4-lane support implemented (lane 0 active; lanes 1–3 structurally ready)
- Integrated the **MaxPool Engine** (`pool_engine.sv`) into the pipeline:
  - Implemented 2×2 max-pooling on Conv2 output
  - Removed testbench `force/release` stub for `pool_done`
- Performed unit-level verification:
  - `tb_conv_engine`: validated MAC, accumulation, ReLU, saturation
  - `tb_pool_engine`: verified max-selection logic (fixed initial comparator issues)
  - All unit tests passed successfully
- Executed full-system integration simulation (`tb_cnn_top`):
  - Verified complete pipeline: Conv1 → Conv2 → Pool → DONE
  - Confirmed correct sequencing, pixel counts (Conv1: 4096, Conv2: 8192), restart behavior

### RTL Code Snippets
- [rtl/conv_engine.sv](../rtl/conv_engine.sv)
- [rtl/pool_engine.sv](../rtl/pool_engine.sv)
- [rtl/cnn_top.sv](../rtl/cnn_top.sv)
- [rtl/controller_fsm.sv](../rtl/controller_fsm.sv)
- [rtl/addr_gen.sv](../rtl/addr_gen.sv)
- [rtl/weight_rom.sv](../rtl/weight_rom.sv)
- [rtl/tb_conv_engine.sv](../rtl/tb_conv_engine.sv)
- [rtl/tb_cnn_top.sv](../rtl/tb_cnn_top.sv)
- [rtl/tb_pool_engine.sv](../rtl/tb_pool_engine.sv)

### Results & Outputs
- conv_engine fully implemented with real MAC datapath
- pool_engine implemented and integrated into the accelerator pipeline
- All datapath modules verified through unit-level testbenches
- Full accelerator integration verified through system-level simulation
- Convolution layers produce expected output pixel counts
- Control flow and datapath operation confirmed across multiple accelerator runs
- [simulation/cnn_top_integration_verified.png](../simulation/cnn_top_integration_verified.png)
- [simulation/full_system_integration.png](../simulation/full_system_integration.png)
- [rtl/cnn_top_integration.sim.log](../rtl/cnn_top_integration.sim.log)
- [rtl/full_system_integration.sim.log](../rtl/full_system_integration.sim.log)
- [rtl/pool_engine.sim.log](../rtl/pool_engine.sim.log)

### Current Architecture Status (End of Week 13)

| Module                    | Status                  | Notes                                      |
|---------------------------|-------------------------|--------------------------------------------|
| controller_fsm            | Verified                | Layer sequencing                           |
| addr_gen                  | Verified                | Address & control generation               |
| feature_sram (behavioral) | Implemented             | Ping-pong A/B banks                        |
| weight_rom                | Implemented             | Hard-coded weights                         |
| conv_engine               | Implemented & verified  | 4-lane MAC + ReLU + saturation             |
| pool_engine               | Implemented & verified  | 2×2 max-pooling                            |
| cnn_top (integration)     | Fully integrated        | Control + memory + real datapath           |
| tb_cnn_top                | Verified                | System-level simulation passed             |
| System datapath           | Integrated & simulated  | Conv → Conv → Pool pipeline verified       |
| Accelerator control flow  | Verified                | Full sequencing & restart confirmed        |

### Key Learnings / Insights
- Implementing real datapath after interface/stub validation greatly reduces integration complexity
- Strict separation between control/addressing and compute logic remains key to modularity
- Unit-level testbenches are critical for catching arithmetic issues before full-system runs
- Incremental debugging of datapath modules simplifies root-cause analysis

### Challenges & Blocking Points
- Initial mismatches in pooling unit testbench due to incorrect max-selection comparator logic  
  → **Solution:** Fixing the max-selection comparison logic and validating it with multiple test patterns in tb_pool_engine. 
- Incorrect write address progression in the convolution engine caused unit test failures 
  → **Solution:** Correcting the out_wr_addr update logic so that the write address increments only when conv_out_valid is asserted.
- Early system-level simulations produced incorrect output counts due to improper output-enable timing 
  → **Solution:** Modifying addr_gen so that out_enable is asserted only for the final MAC group of each output pixel.
- Integration instability during early datapath replacement (stub → real RTL) risked breaking the top-level pipeline 
  → **Solution:** Performing incremental verification with unit testbenches before running full-system simulations.

### Plan for Next Week (Week 14)
- Perform RTL cleanup and synthesis preparation
- Guard/remove all simulation-only constructs
- Prepare clean synthesizable RTL file set
- Begin initial logic synthesis using Cadence Genus
- Analyze synthesis results: 
    - area 
    - timing 
    - resource utilization
- Prepare design for next ASIC flow stages (place & route, timing closure)