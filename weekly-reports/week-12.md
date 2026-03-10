# Weekly Progress Report – Week 12  
**Date:** February 22, 2026

### Accomplished This Week
- Advanced from individually verified modules to a **stable top-level integration** of the CNN accelerator in `cnn_top`:
  - Integrated previously verified modules:
    - `controller_fsm` (layer sequencing and control)
    - `addr_gen` (address generation and traversal)
    - Behavioral models for two `feature_sram` banks (A/B ping-pong buffering)
    - `weight_rom` (hard-coded weights)
  - Implemented top-level routing logic for memory access and bank selection
- Enforced the **ping-pong feature map architecture** with dynamic bank selection:
  - Conv1: read from SRAM A, write to SRAM B
  - Conv2: read from SRAM B, write to SRAM A
  - MaxPool: read from SRAM A, write to SRAM B
  - Replaced hardcoded mapping with controller-generated source/destination bank select signals
- Defined a clean, RTL-ready **interface contract** for the future `conv_engine` module:
  - Control signals: `mac_valid`, `acc_clear`, `out_enable`
  - Packed 4-lane activation and weight buses
  - Padding mask support
  - Output data and validity signaling
  - Designed as a pure compute block — all traversal/addressing logic remains in `addr_gen`
- Introduced a temporary **`conv_engine_stub`** behavioral model to validate interface connectivity:
  - Accepts full interface signals
  - Generates fixed pattern output (`0xA5`) when `out_enable` asserted
  - Produces aligned `out_valid` signal
  - Increments internal accumulator for activity observation
- Replaced dummy write path with stub-driven output:
  - Removed previous `dummy_wdata` tie-offs
  - SRAM write data now sourced from `conv_engine_stub`
  - SRAM write enable driven by `conv_out_valid`
- Executed **system-level simulation** using `tb_cnn_top` on Cadence Xcelium (university Linux server):
  - Verified reset behavior, start triggering, full pipeline progression, `done` assertion, and restart capability
  - Confirmed no deadlocks or control flow disruptions after stub integration
  - Simulation completed successfully with message: **All tests PASSED**
### RTL Code Snippets
- [rtl/cnn_top.md](../rtl/cnn_top.md)
- [rtl/tb_cnn_top.md](../rtl/tb_cnn_top.md)
- [rtl/weight_rom.md](../rtl/weight_rom.md)
- [rtl/conv_engine_interface.md](../rtl/conv_engine_interface.md)
- [rtl/conv_engine_stub.md](../rtl/conv_engine_stub.md)
### Results & Outputs
- Top-level module `cnn_top` fully integrated and structurally stable
- Control flow and interface connectivity between controller, address generation, memory, and stub datapath verified
- Ping-pong bank selection and write path now correctly driven by real interface signals (not dummies)
- System-level simulation confirms correct sequencing through all layers (Conv1 → Conv2 → POOL stub → DONE)
- Current architecture provides a robust foundation for real datapath implementation  
[cnn_top.png](../simulation/cnn_top.png)    
[conv_engine_stub.png](../simulation/conv_engine_stub.png)

### Current Architecture Status (End of Week 12)

| Module                    | Status                  | Notes                                      |
|---------------------------|-------------------------|--------------------------------------------|
| controller_fsm            | Verified                | Full FSM sequencing                        |
| addr_gen                  | Verified                | Address & control signal generation        |
| feature_sram (behavioral) | Implemented             | Ping-pong banks A/B                        |
| weight_rom                | Implemented             | Hard-coded weights                         |
| cnn_top (integration)     | Completed & simulated   | Control + address + memory + stub datapath |
| tb_cnn_top                | Implemented & passed    | System-level verification                  |
| conv_engine interface     | Defined & connected     | Ready for real implementation              |
| conv_engine               | Stub integrated         | Behavioral placeholder                     |
| MaxPool engine            | Stubbed in testbench    | force/release until real module            |
| System control flow       | Verified                | Full pipeline progression confirmed        |

**Important limitation:** Current verification covers **control flow, interface connectivity, and memory interaction** only — convolution arithmetic correctness is not yet validated (stub datapath in use).

### Key Learnings / Insights
- Defining a strict interface contract early between control/addressing and datapath blocks greatly reduces integration risk
- Replacing dummy tie-offs with a behavioral stub provides meaningful connectivity checks without waiting for full compute logic
- Dynamic bank selection signals from the controller improve architectural clarity and prevent future control/data path mismatches
- Incremental integration with stubs allows validation of higher-level structure before lower-level datapath details are complete
- System-level testbenches with watchdog timers and restart checks are essential for catching deadlocks early

### Challenges & Blocking Points
- None significant this week — integration progressed smoothly thanks to prior module-level verification and clear interface definition

### Plan for Next Week (Week 13)
- The next stage of the project will focus on implementing the RTL of the **conv_engine module**, replacing the temporary stub with a real datapath implementation:
  - 4-lane parallel MAC array
  - Multiplier units for activation–weight products
  - Adder tree for partial sum accumulation
  - 32-bit accumulator register with clear-on-first-tap
  - Inline ReLU activation
  - 8-bit output quantization and saturation
- Connect real `conv_engine` output write port to SRAM A/B write ports (replace stub)
- Connect all 4 activation read lanes to SRAM read ports (remove lane tie-offs)
- Replace testbench `force/release` pool stub with real MaxPool engine preparation
- Begin full datapath simulation and verification (Conv1 & Conv2 arithmetic correctness)
- Prepare RTL for initial synthesis flow (Genus / Design Compiler)