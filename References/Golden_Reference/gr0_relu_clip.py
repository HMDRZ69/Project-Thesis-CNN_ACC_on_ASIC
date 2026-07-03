#!/usr/bin/env python3
"""
gr0_relu_clip.py — Golden reference for GR0 (oc=0, y=1, x=1).

Purpose: verifies ReLU clipping behaviour. All nine kernel taps for this
output pixel are in-bounds (no padding), and the accumulated MAC sum is
negative, so the expected output after ReLU must be exactly 0.

Pixel under test: output channel oc=0, output row y=1, output col x=1.
This pixel was deliberately chosen because (y=1, x=1) with pad=1 means all
3x3 taps fall within the valid 32x32 image (in_y, in_x range 0..2), so no
padding/zero-substitution occurs and ReLU clipping is the only correctness
property under test.

Conv1: Cin=1 (single input channel), so the 9 taps map directly to 3 MAC
groups of 4 lanes each (group 2's last lane is padded/unused since 9 % 4 != 0,
but only lane 0 of each group matters for this check, per the SRAM-latency
model in gr_common.py).

Expected result (from tb_cnn_top.sv / GLS verification log):
    ReLU(MAC) = 0  ->  GR_EXP_0 = 8'd0

NOTE on the MAC intermediate value: tb_cnn_top.sv only asserts the final
8-bit output (gr_captured[0] == GR_EXP_0); it does not assert the exact
intermediate 32-bit MAC accumulation. The project report (Section 4.1)
quotes "MAC=-66" as an explanatory comment, while applying the same
group/latency model used for GR1/GR2 in this golden-reference script gives
-33. Both values clip to 0 after ReLU, so this discrepancy does not affect
correctness of the verified RTL behaviour -- but it IS a real inconsistency
between the report text and a strict re-derivation, and should be corrected
in the report (the report's "-66" appears to assume two non-zero
contributing groups rather than one; this script computes only one
non-zero group under the verified 1-cycle SRAM-latency model, as confirmed
for GR1/GR2 by GLS). Only the final clipped output is therefore asserted
below, matching exactly what the RTL testbench checks.
"""

import sys
from gr_common import (
    group_data_with_latency,
    weight_rom_slice,
    relu_sat8,
)

# Output pixel under test
OUT_Y, OUT_X = 1, 1
OC = 0
N_GROUPS = 3  # Conv1: 9 taps / 4 lanes, rounded up to 3 groups

# Only the final RTL-verified output is asserted (see NOTE above for why
# the intermediate MAC value is reported but not strictly checked).
EXPECTED_OUT = 0


def compute_gr0():
    # SRAM data seen by MAC lane 0 at each group, accounting for the
    # 1-cycle registered SRAM read latency (see gr_common.py docstring).
    data_seen = group_data_with_latency(OUT_Y, OUT_X, N_GROUPS, ic=0)

    # Only the weight at the lane-0 tap of the *previous* group's address is
    # the one actually multiplied against the captured data at each cycle,
    # following the same one-cycle-shifted pipeline as the RTL. For this
    # pixel and architecture, only group 2's captured data is non-zero
    # (groups 0 and 1 always see zero/stale data — see gr_common.py).
    # The corresponding weight index for oc=0 is idx=8 (k=8, the 9th tap).
    weights = weight_rom_slice([8])
    w = weights[8]

    # MAC accumulation: only group 2 contributes (groups 0,1 contribute 0
    # because data_seen[0] = 0 and data_seen[1] = 0 under the latency model).
    mac = sum(data_seen[g] * (w if g == 2 else 0) for g in range(N_GROUPS))

    out = relu_sat8(mac)
    return mac, out, data_seen


def main():
    mac, out, data_seen = compute_gr0()

    print(f"GR0: oc={OC}, y={OUT_Y}, x={OUT_X}")
    print(f"  SRAM data seen per group (with 1-cycle latency): {data_seen}")
    print(f"  Computed MAC accumulation (informational): {mac}")
    print(f"  Computed ReLU output      : {out}")
    print(f"  Expected ReLU output      : {EXPECTED_OUT}")

    ok = True
    if out != EXPECTED_OUT:
        print(f"  [FAIL] Output mismatch: got {out}, expected {EXPECTED_OUT}")
        ok = False

    if ok:
        print("  [PASS] GR0 golden reference matches RTL/GLS result.")
        print("  (Note: intermediate MAC value is informational only -- the")
        print("   RTL testbench does not assert it; see module docstring.)")
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
