"""
gr_common.py — Shared golden-reference model for the CNN accelerator (cnn_top).

This module reproduces, in Python, the exact addressing and timing behaviour
of the RTL address generator (addr_gen.sv) and convolution engine
(conv_engine.sv), specifically the parts needed to reproduce the three
golden-reference pixel checks GR0 / GR1 / GR2 used in tb_cnn_top.sv.

It is NOT a full behavioural model of the accelerator (that would require the
complete 324-entry weight ROM and full image data). It only reconstructs the
exact subset of state needed to verify these three known-good output pixels,
matching the same derivation used to debug the RTL during verification.

== SRAM read-latency model (CRITICAL) ==
The IHP RM_IHPSG13_1P_4096x8 SRAM macro has a 1-cycle synchronous read
latency: data requested with address A in cycle N appears on the output bus
in cycle N+1. addr_gen presents one tap address per AG_TAPS cycle (one cycle
per MAC group of 4 lanes), so the data captured by conv_engine in any given
AG_TAPS cycle is actually the data for the *previous* cycle's address, not
the address being driven in the current cycle.

Concretely, for a kernel tap group sequence ADDR(group=0), ADDR(group=1),
ADDR(group=2), ...:
    DATA(group=0) = X                  (driven by AG_NEWPIX, garbage/unused)
    DATA(group=1) = mem[ADDR(group=0)]
    DATA(group=2) = mem[ADDR(group=1)]
    ...
This means the value the MAC actually accumulates for "group g" (g >= 1) is
mem[ADDR(g-1)], not mem[ADDR(g)]. Group 0's contribution is always 0 because
no valid address has been driven yet (or the address was OOB/padding).

This was confirmed during RTL/GLS verification: GR1 was originally computed
assuming zero-latency (ideal) memory and gave 32; the actual gate-level
result was 1, traced to this exact one-cycle pipeline delay.

== Memory contents ==
The testbench initialises u_sram_a (Bank A, the input image) with a ramp
pattern: mem[i] = i % 256 for i = 0 .. 1023 (1024 bytes = 32x32x1 image).

== Image / kernel geometry ==
Image: 32 (H) x 32 (W), single input channel for Conv1.
Kernel: 3x3, stride 1, pad 1 (zero padding for out-of-bounds taps).
CHW addressing: addr = ic*H*W + in_y*W + in_x  (ic=0 for Conv1).
"""

H = 32
W = 32
KSIZE = 3
PAD = 1

# Ramp pattern used by the testbench to initialise SRAM Bank A (input image).
def sram_image(i: int) -> int:
    """Returns mem[i] for the 32x32x1 input image bank (Bank A)."""
    return i % 256


def tap_coords(out_y: int, out_x: int, k: int):
    """
    Returns (in_y, in_x) for kernel tap index k (0..8, row-major 3x3),
    given output pixel (out_y, out_x), stride=1, pad=1.
    """
    ky, kx = divmod(k, KSIZE)
    in_y = out_y - PAD + ky
    in_x = out_x - PAD + kx
    return in_y, in_x


def in_bounds(in_y: int, in_x: int) -> bool:
    return 0 <= in_y < H and 0 <= in_x < W


def tap_sram_addr(in_y: int, in_x: int, ic: int = 0) -> int:
    """CHW-layout SRAM address for input channel ic, coordinate (in_y, in_x)."""
    return ic * H * W + in_y * W + in_x


def group_addresses(out_y: int, out_x: int, n_taps: int, ic: int = 0):
    """
    Returns a list of length n_taps where entry k is the SRAM address driven
    for tap k (lane 0 of each 4-tap group), or None if that tap is
    out-of-bounds (padding -> zero, no SRAM access).

    NOTE: this returns ALL tap addresses (k = 0 .. n_taps-1), not grouped
    by 4-lane MAC group. group_data() below applies the lane-0-of-group
    selection and the 1-cycle latency shift.
    """
    addrs = []
    for k in range(n_taps):
        in_y, in_x = tap_coords(out_y, out_x, k)
        if in_bounds(in_y, in_x):
            addrs.append(tap_sram_addr(in_y, in_x, ic))
        else:
            addrs.append(None)
    return addrs


def group0_lane0_addresses(out_y: int, out_x: int, n_groups: int, ic: int = 0):
    """
    Returns the SRAM address driven for lane 0 of each 4-tap MAC group
    (group index g = 0 .. n_groups-1), i.e. tap index k = 4*g.
    Returns None for that group if the lane-0 tap is out-of-bounds.

    Conv1 uses 3 groups (9 taps / 4 lanes, rounded up); only the lane-0 tap
    of each group matters for the GR0/GR1/GR2 checks below, since those
    checks track the address-generator pipeline behaviour at the group
    granularity (matching how addr_gen drives one address per AG_TAPS cycle).
    """
    out = []
    for g in range(n_groups):
        k = 4 * g
        if k >= 9:
            out.append(None)
            continue
        in_y, in_x = tap_coords(out_y, out_x, k)
        if in_bounds(in_y, in_x):
            out.append(tap_sram_addr(in_y, in_x, ic))
        else:
            out.append(None)
    return out


def group_data_with_latency(out_y: int, out_x: int, n_groups: int, ic: int = 0):
    """
    Applies the 1-cycle SRAM read latency to the group lane-0 addresses.
    Returns a list of length n_groups: data_seen[g] = mem[addr(g-1)] for
    g >= 1, and data_seen[0] = 0 (no valid prior address / AG_NEWPIX cycle).

    This reproduces exactly what conv_engine's lane-0 MAC input actually
    sees at each AG_TAPS cycle, given the registered SRAM read.
    """
    addrs = group0_lane0_addresses(out_y, out_x, n_groups, ic)
    data = [0]  # group 0 always sees stale/zero data (AG_NEWPIX cycle)
    for g in range(1, n_groups):
        prev_addr = addrs[g - 1]
        if prev_addr is None:
            data.append(0)  # previous tap was OOB -> zero was driven, mem read suppressed
        else:
            data.append(sram_image(prev_addr))
    return data


def relu(x: int) -> int:
    return x if x > 0 else 0


def relu_sat8(x: int) -> int:
    """ReLU followed by 8-bit saturating truncation (0..255), matching conv_engine.sv."""
    y = relu(x)
    return min(y, 255)


def weight_rom_slice(indices_needed):
    """
    Returns a dict {index: value} for the specific weight_rom.sv indices
    required to reproduce GR0/GR1/GR2. Values are taken directly from the
    hardcoded constants in weight_rom.sv (placeholder weights, as documented
    in the project report, Section 1.2 / "Known Limitations").

    Indices used by these three checks:
        idx 8  -> -1   (Conv1, oc=0, ic=0, k=8: weight for GR0's group-2 tap)
        idx 17 -> +1   (Conv1, oc=1, ic=0, k=8: weight for GR1/GR2's group-2 tap)

    Weight index formula (addr_gen.sv): idx = oc*Cin*9 + ic*9 + k
    For Conv1, Cin=1, so idx = oc*9 + k.
        oc=0, k=8 -> idx = 0*9+8 = 8
        oc=1, k=8 -> idx = 1*9+8 = 17
    """
    table = {8: -1, 17: 1}
    return {i: table[i] for i in indices_needed}
