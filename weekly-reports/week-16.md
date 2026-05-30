# Weekly Progress Report – Week 16

**Date:** May 8, 2026

---

### Accomplished This Week

- Conducted a full end-to-end review of the entire design flow to consolidate understanding before proceeding to Innovus Place & Route:
  * Re-read all 7 RTL modules (`controller_fsm`, `addr_gen`, `feature_sram`, `weight_rom`, `conv_engine`, `pool_engine`, `cnn_top`) in sequence
  * Traced all inter-module signal handshakes: `conv_start`/`conv_done`, `pool_start`/`pool_done`, `ag_enable`, ping-pong `src`/`dst` select lines
  * Cross-checked the Genus synthesis log, timing reports, and GLS log to confirm understanding of every documented known issue

- During this review, identified a **critical architectural bug in `pool_engine.sv`**:
  * **Root cause:** After completing its first run, `pool_engine` transitions to `S_DONE` and stays there permanently — the FSM has no exit from `S_DONE` back to `S_ADDR0`. Since `pool_done` is driven combinationally as `(state_reg == S_DONE)`, it stays HIGH indefinitely after RUN 1.
  * **Failure mode:** When `controller_fsm` re-enters `S_POOL` for RUN 2, it pulses `pool_start` and immediately samples `pool_done = 1` (still HIGH from RUN 1). The FSM therefore exits `S_POOL → S_DONE` in a single cycle — pool never executes for RUN 2 or any subsequent run.
  * **Evidence:** In the existing integration simulation log, RUN 2 duration was 122,889 cycles. Conv1 + Conv2 alone account for 24,576 + 98,304 = 122,880 cycles — the entire RUN 2 budget with zero cycles remaining for pool. Pool pixel count for RUN 2 = 0, which the testbench did not catch because no pool pixel assertion existed.
  * **Scope:** This is not a synthesis artefact — it is present in the RTL. The GLS passing result from Week 15 masked this bug because (1) the testbench had no pool pixel count assertion, and (2) the `tb_pool_engine.sv` unit test was being compiled alongside `tb_cnn_top.sv`, causing Xcelium to simulate the pool unit test only and exit before `tb_cnn_top` could complete.

- Identified two secondary issues discovered during the same review:
  * **TB compile conflict:** `tb_pool_engine.sv` and `tb_cnn_top.sv` were both included in the integration compile command. Xcelium chose `tb_pool_engine` as the simulation top, which calls `$finish` at ~862 ns — killing the simulation before `tb_cnn_top` could run. All 22 "PASS" results reported in Week 15 were `tb_pool_engine` unit tests, not integration tests.
  * **Missing pool pixel assertion:** `tb_cnn_top.sv` checked Conv1 and Conv2 pixel counts but had no corresponding check for pool output pixel count, allowing pool to produce zero pixels without triggering any failure.

---

### Current Architecture Status (End of Week 16)

| Module           | Status                             | Notes                                                    |
| ---------------- | ---------------------------------- | -------------------------------------------------------- |
| `controller_fsm` | ✅ Verified                       | FSM logic correct; bug is entirely in `pool_engine`      |
| `addr_gen`       | ✅ Verified                       | Address generation correct for all 4 lanes               |
| `feature_sram`   | ✅ Verified                       | Bank-select, read-latency alignment, BIST tie-offs clean |
| `weight_rom`     | ✅ Verified                       | 4 instances, one per MAC lane                            |
| `conv_engine`    | ✅ Verified                       | 4-lane MAC datapath structurally correct                 |
| `pool_engine`    | ❌ Architecture bug identified    | `S_DONE` has no exit; pool silently skipped from RUN 2+  |
| `cnn_top`        | ⚠️ Pending pool_engine fix        | Top-level integration pending re-verification            |

**ASIC flow status: Architecture review complete. Critical pool_engine bug identified. Redesign and re-verification planned for Week 17.**

---

### Challenges & Blocking Points

**Challenge 1 — Pool silently skipped for all runs after the first**
> The lack of a pool pixel count assertion in the testbench meant this bug was not caught during integration simulation. The design appeared to pass because Conv1 and Conv2 counts were correct and the `done` signal asserted at the right time.

**Challenge 2 — Integration testbench never actually executed**
> Because `tb_pool_engine.sv` was included in the same compile invocation as `tb_cnn_top.sv`, Xcelium selected `tb_pool_engine` as the simulation top. The integration test (`tb_cnn_top`) was never simulated. The Week 15 "18/18 PASS" result was the pool unit test, not a full system integration result.

---

### Plan for Next Week (Week 17)

- Fix `pool_engine.sv`:
  * Add `S_DONE → S_ADDR0` transition gated on `pool_start`
  * Reset all counters when restarting from `S_DONE`
  * De-assert `pool_done` combinationally when `pool_start` is HIGH
- Update `tb_cnn_top.sv`:
  * Remove `tb_pool_engine.sv` from the integration compile command
  * Add `pool_pixel_count` assertion (expected: 2048 per run)
  * Fix `tb_conv_out_v` inversion conditional (`SYNTHESIS` vs RTL)
- Re-run full unit test suite for `pool_engine` (target: 22/22)
- Re-run full RTL integration simulation (target: all checks passing, including new pool assertion)
