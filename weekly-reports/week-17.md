# Weekly Progress Report – Week 17

**Date:** May 15, 2026

---

### Accomplished This Week

- Applied three surgical fixes to `pool_engine.sv` to resolve the architectural restart bug identified in Week 16:

  * **Fix 1 — S_DONE exit transition:** Added `if (pool_start) state_next = S_ADDR0` in the `S_DONE` branch of the next-state logic. Without this, `pool_engine` had no path out of `S_DONE`, making it permanently done after the first run. The FSM can now re-arm for any subsequent run.
  * **Fix 2 — Counter reset on restart from S_DONE:** Extended the counter-reset condition from `(state_reg == S_IDLE && pool_start)` to `((state_reg == S_IDLE || state_reg == S_DONE) && pool_start)`. This is required because at the end of a pool run the channel counter is left at `ch=7` (not `ch=0`), so without an explicit reset on restart the counters would be wrong for RUN 2 and beyond.
  * **Fix 3 — pool_done combinational de-assertion on pool_start:** Modified `pool_done` to de-assert when `pool_start` is HIGH: `pool_done = (state_reg == S_DONE) && !pool_start`. This ensures that when `controller_fsm` pulses `pool_start`, it sees `pool_done = 0` on the same cycle, giving `pool_engine` one clock cycle to transition out of `S_DONE` before the FSM re-checks the signal.

- Updated `tb_cnn_top.sv` with three improvements:

  * **Fix 1 — Removed `tb_pool_engine.sv` from integration compile:** Separated the unit test and integration test compile commands. `tb_pool_engine.sv` now has its own dedicated compile invocation. The integration testbench is compiled and simulated alone, preventing Xcelium from selecting the wrong simulation top.
  * **Fix 2 — Added pool pixel count assertion:** Added `POOL_PIXELS = 8 * 16 * 16` (2048) localparam, a `pool_pixel_count` counter driven by `u_dut.u_sram_b.wr_en` gated by an `in_pool_phase` flag, and a `check_int("Pool pixel count", ...)` assertion in `run_cnn()`. Total testbench check count increased from 15 to 17 per run (3 post-reset + 7 per run × 2 runs).
  * **Fix 3 — Corrected `tb_conv_out_v` inversion:** The `~u_dut.conv_out_valid` inversion is now wrapped in a `` `ifdef SYNTHESIS `` guard. In RTL simulation, `conv_out_valid` is active-HIGH and must not be inverted. The inversion is only applied in GLS (`` `define SYNTHESIS ``), where Genus mapped `conv_out_valid` to the `Q_N` output of `sg13g2_dfrbp_2`. Without this fix the pixel counters were counting idle cycles (~20,487) instead of valid output cycles (4,096).

- Re-ran the `pool_engine` unit test suite to confirm the fixes introduced no regressions:
  * Compile: `xrun -sv RTL/pool_engine.sv RTL/tb_pool_engine.sv`
  * Result: **22/22 PASSED, 0 FAILED** ✅

- Re-ran the full RTL integration simulation with the updated `tb_cnn_top.sv`:
  * Compile command excludes `tb_pool_engine.sv` — `tb_cnn_top` is the only simulation top
  * Result: **20/20 PASSED, 0 FAILED** ✅ (includes new pool pixel count assertion for both runs)

---

### RTL / Testbench Files Modified

- `RTL/pool_engine.sv` — 3 fixes (S_DONE exit, counter reset, pool_done de-assertion)
- `Xcelium/tb_cnn_top.sv` — 3 fixes (compile separation, pool assertion, conv_out_v guard)

---

### Results & Outputs

**RTL integration simulation results (post-fix):**

- Simulation runtime: ~11 seconds (2 full Conv1→Conv2→Pool runs)
- Total tests: 20 PASSED, 0 FAILED

| Metric                      | RUN 1   | RUN 2   | Match |
| --------------------------- | ------- | ------- | ----- |
| Conv1 pixel count           | 4,096   | 4,096   | ✅     |
| Conv2 pixel count           | 8,192   | 8,192   | ✅     |
| Pool pixel count            | 2,048   | 2,048   | ✅     |
| Cycles to done              | 135,178 | 135,178 | ✅     |
| GR0: ReLU clips negative    | 0       | 0       | ✅     |
| GR1: SRAM read latency      | 1       | 1       | ✅     |
| GR2: Full 9-tap MAC result  | 33      | 33      | ✅     |
| `done` level stable         | ✅       | ✅       | ✅     |
| Ping-pong src/dst no-X      | ✅       | ✅       | ✅     |
| Pipeline restarts correctly  | —       | ✅       | ✅     |

> **Note on cycle count:** RUN 2 is now 135,178 cycles, matching RUN 1 exactly. The previous Week 15 value of 122,889 cycles for RUN 2 was wrong because pool never ran — those cycles were Conv1 + Conv2 only. The correct total is Conv1 (24,576) + Conv2 (98,304) + Pool (~12,298) + overhead.

---

### Current Architecture Status (End of Week 17)

| Module           | Status                             | Notes                                          |
| ---------------- | ---------------------------------- | ---------------------------------------------- |
| `controller_fsm` | ✅ RTL verified                     | No changes; FSM correctly drives pool_start    |
| `addr_gen`       | ✅ RTL verified                     | All 4 lanes active and correct                 |
| `feature_sram`   | ✅ RTL verified                     | Real SRAM macro wrapper — no changes needed    |
| `weight_rom`     | ✅ RTL verified                     | 4 instances verified in integration sim        |
| `conv_engine`    | ✅ RTL verified                     | 4-lane MAC output verified (GR0, GR1, GR2)    |
| `pool_engine`    | ✅ Bug fixed & re-verified          | 22/22 unit + 2×2048 pool pixels in integration |
| `cnn_top`        | ✅ RTL integration verified (20/20) | End-to-end pipeline confirmed for 2 full runs  |

**ASIC flow status: RTL fully re-verified post pool_engine fix. All 20 integration checks pass. Ready for Genus re-synthesis.**

---

### Challenges & Blocking Points

**Challenge 1 — Three-way interaction between pool_done, pool_start, and the FSM**
> Simply adding the S_DONE exit transition (Fix 1) was not sufficient on its own. Without Fix 3 (combinational de-assertion of pool_done on pool_start), the FSM sees pool_done=1 for one cycle after asserting pool_start before pool_engine has had a chance to leave S_DONE. The three fixes must be applied together to create a well-defined LOW→HIGH completion handshake.

**Challenge 2 — conv_out_v inversion broke RTL pixel counters**
> The inversion that was introduced in Week 15 for GLS polarity correction was applied unconditionally, meaning RTL simulation was also counting inverted valid pulses. With valid logically inverted, idle cycles (~20,487 per run) were counted instead of active output cycles (4,096). This masked itself because the testbench was not actually reaching pool phase due to the `tb_pool_engine` compile conflict.

---

### Plan for Next Week (Week 18)

- Re-run Genus synthesis with the corrected `pool_engine.sv`:
  * Verify all 4 SRAM macro instances still present in the netlist
  * Confirm WNS is consistent with the Week 15 result (~−45 ns)
  * Generate updated area, timing, power, and QoR reports
- Re-run Gate-Level Simulation with the new netlist and updated `tb_cnn_top.sv`:
  * Expected: all checks pass with the `SYNTHESIS` flag active (pool pixel count now included)
  * Document any new Q_N polarity or internal net probe issues
- If GLS passes: proceed to Innovus Place & Route setup
