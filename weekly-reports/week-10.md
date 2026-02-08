# Weekly Progress Report – Week 10  
**Date:** February 08, 2026

### Accomplished This Week
- Finalized the project scope and core design assumptions for the Master's thesis:
  - Confirmed focus on ASIC digital design flow validation (RTL → Simulation → Synthesis)
  - Explicitly excluded dataset handling, training, inference accuracy benchmarking, and external memory interfaces
- Reviewed and consolidated CNN fundamentals from first principles to bridge software concepts with hardware mapping:
  - Layers, neurons (as MAC operations), convolution, kernels, stride, padding
  - Activation functions (ReLU) and MaxPooling
- Locked the final CNN network architecture for hardware implementation:
  - Input: 32×32×1 grayscale
  - Conv1: 3×3 kernel, stride=1, padding=1, 4 output channels + ReLU
  - Conv2: 3×3 kernel, stride=1, padding=1, 8 output channels + ReLU
  - MaxPool: 2×2, stride=2
  - Output: 16×16×8 feature map
- Defined fixed-point data formats and numerical precision for the datapath:
  - Activations: 8-bit unsigned
  - Weights: 8-bit signed
  - Accumulator: 32-bit (to prevent overflow during MAC operations)
- Calculated and validated on-chip memory requirements for feature maps:
  - Input: 1 KB
  - Conv1 output: 4 KB
  - Conv2 output: 8 KB (worst case)
  - Pooled output: 2 KB
- Designed a Ping-Pong memory architecture for feature maps:
  - Two 8 KB SRAM banks (A/B) — one for reading current layer, one for writing next layer
  - Automatic bank swapping between layers
- Determined weight storage approach:
  - Total weight size extremely small (Conv1: 36 bytes, Conv2: 288 bytes)
  - Implemented as ROM or hard-coded constants (no external weight loading)
- Defined the top-level hardware architecture and block diagram:
  - Top Controller (FSM + control signals)
  - Address Generation unit
  - Shared Convolution Engine (time-multiplexed for Conv1 & Conv2)
  - Weight ROM
  - Feature SRAM A/B
  - MaxPool Engine
- Adopted a single shared convolution engine strategy:
  - All layers processed sequentially on the same hardware
  - ReLU applied inline after accumulation
- Designed the high-level FSM control flow:
  - States: IDLE → CONV1 → CONV2 → POOL → DONE
- Completed detailed RTL-level design of the Top Controller FSM:
  - Defined states, transitions, and control signal responsibilities
  - Implemented ping-pong buffer selection logic
  - Generated one-cycle start pulses for Conv and Pool engines
  - Ensured strict separation between control logic and datapath

### Results & Outputs
- Complete, consistent, and hardware-oriented CNN accelerator architecture now fully defined
- Top-level block diagram decomposed into clear RTL modules with well-defined interfaces
- Controller FSM implemented and ready for direct integration into RTL simulation
- Project structurally prepared for systematic RTL coding, module-level verification, and incremental integration

### Key Learnings / Insights
- A single shared convolution engine is sufficient and optimal for an MSc-level ASIC project when throughput is not the primary objective
- Strict separation of control (FSM), address generation, and datapath greatly simplifies RTL development and debugging
- Padding logic can be efficiently handled inside address generation without extra memory overhead
- Designing the FSM first provides a stable control backbone that guides incremental RTL implementation

### Challenges & Blocking Points
- Initial difficulty mapping multi-channel convolution to a time-multiplexed MAC-based hardware architecture  
  → **Solution:** Step-by-step decomposition (window generation → accumulation → channel-wise summation) clarified datapath behavior
- Risk of over-engineering the architecture beyond thesis requirements  
  → **Solution:** Explicit scope restriction to flow validation (RTL–synthesis) eliminated unnecessary features/optimizations

### Plan for Next Week
- Design and implement the Address Generation (`addr_gen`) module for convolution layers:
  - Nested loop structure for spatial, channel, and kernel indices
  - SRAM read/write address generation
  - Accumulator control signaling
- Extend address generation logic to support multi-channel convolution (Conv2)
- Begin RTL implementation of behavioral models for feature SRAMs (A/B)
- Start integrating the Top Controller FSM with `addr_gen` in simulation environment
- Prepare the Convolution Engine interface for incremental RTL development