#!/usr/bin/env python3
"""
cross_check.py — Cross-check between Python golden reference and RTL sim log.

Usage:
    python cross_check.py <simulation_log_file>

Example:
    python cross_check.py cnn_sim.log
    python cross_check.py gls_sim.log
"""

import re
import subprocess
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent

GR_SCRIPTS = {
    0: SCRIPT_DIR / "gr0_relu_clip.py",
    1: SCRIPT_DIR / "gr1_addressing.py",
    2: SCRIPT_DIR / "gr2_pixel_exact.py",
}

# Matches lines like:
#   [PASS] R1:GR0 oc=0,y=1,x=1  (...)  got=8'd  0 (0x00) ...
#   [FAIL] R1:GR1 oc=1,y=0,x=1  (...)  got=8'd  1 (0x01) ...
LOG_LINE_RE = re.compile(
    r"\[(PASS|FAIL)\]\s+R1:GR(\d).*?got=8'd\s*(\d+)",
    re.IGNORECASE,
)

# --------------------------------------------------------------------------
# Step 1: Run each Python GR script and extract its computed output value
# --------------------------------------------------------------------------

def run_python_gr(gr_index):
    """Runs gr{N}*.py and returns the integer 'Computed ReLU output' value."""
    script = GR_SCRIPTS[gr_index]
    print(f"  Running {script.name} ...", end=" ")

    if not script.exists():
        print(f"NOT FOUND")
        return None

    result = subprocess.run(
        [sys.executable, str(script)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    m = re.search(r"Computed ReLU output\s*:\s*(\d+)", result.stdout)
    if m:
        val = int(m.group(1))
        print(f"output = {val}")
        return val
    else:
        print("COULD NOT PARSE OUTPUT")
        print(f"    stdout: {result.stdout.strip()}")
        print(f"    stderr: {result.stderr.strip()}")
        return None


# --------------------------------------------------------------------------
# Step 2: Parse the simulation log for GR0/GR1/GR2 'got=' values
# --------------------------------------------------------------------------

def parse_log(log_path):
    """Returns dict {gr_index: got_value} from the simulation log."""
    results = {}
    lines_scanned = 0

    try:
        # Try UTF-8 first (Linux logs), fall back to latin-1 (Windows safe)
        for enc in ("utf-8", "latin-1", "cp1252"):
            try:
                with open(log_path, "r", encoding=enc, errors="replace") as f:
                    for line in f:
                        lines_scanned += 1
                        m = LOG_LINE_RE.search(line)
                        if m:
                            gr_index = int(m.group(2))
                            got_value = int(m.group(3))
                            results[gr_index] = got_value
                break  # successfully read the file
            except UnicodeDecodeError:
                continue

    except FileNotFoundError:
        print(f"ERROR: Log file not found: {log_path}")
        sys.exit(1)

    print(f"  Scanned {lines_scanned:,} lines, found {len(results)} GR result(s)")
    return results


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main():
    print()
    print("=" * 65)
    print("  CNN Accelerator — Golden Reference Cross-Check")
    print("=" * 65)

    if len(sys.argv) != 2:
        print()
        print(f"  Usage: python cross_check.py <simulation_log_file>")
        print(f"  Example: python cross_check.py cnn_sim.log")
        print()
        input("Press Enter to exit...")
        sys.exit(2)

    log_path = Path(sys.argv[1])
    print(f"  Log file : {log_path.resolve()}")
    print(f"  Log exists: {log_path.exists()}")
    print()

    if not log_path.exists():
        print(f"ERROR: Cannot find log file '{log_path}'")
        print(f"       Current directory: {Path.cwd()}")
        print()
        input("Press Enter to exit...")
        sys.exit(1)

    # Step 1 — Python golden reference
    print("Step 1: Running Python golden-reference scripts")
    print("-" * 45)
    python_results = {}
    for idx in (0, 1, 2):
        val = run_python_gr(idx)
        if val is not None:
            python_results[idx] = val
    print()

    # Step 2 — Parse simulation log
    print("Step 2: Parsing simulation log")
    print("-" * 45)
    log_results = parse_log(log_path)
    print()

    # Step 3 — Compare
    print("Step 3: Cross-check results")
    print("-" * 45)
    print(f"  {'Check':<10} {'Python':>8} {'RTL log':>10} {'Match?':>10}")
    print(f"  {'-'*10} {'-'*8} {'-'*10} {'-'*10}")

    all_ok = True
    for idx in (0, 1, 2):
        py  = python_results.get(idx)
        rtl = log_results.get(idx)

        py_str  = str(py)  if py  is not None else "?"
        rtl_str = str(rtl) if rtl is not None else "missing"

        if py is None or rtl is None:
            status = "MISSING"
            all_ok = False
        elif py == rtl:
            status = "MATCH"
        else:
            status = "MISMATCH"
            all_ok = False

        print(f"  GR{idx:<7} {py_str:>8} {rtl_str:>10} {status:>10}")

    print()
    if all_ok:
        print("  RESULT: [PASS] Python model matches RTL simulation output.")
    else:
        print("  RESULT: [FAIL] One or more values do not match.")
        print()
        if not log_results:
            print("  HINT: No GR lines were found in the log.")
            print("        Make sure you are using the correct log file")
            print("        (cnn_sim.log or gls_sim.log from the server).")

    print()
    input("Press Enter to exit...")
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\nUNEXPECTED ERROR: {e}")
        import traceback
        traceback.print_exc()
        input("Press Enter to exit...")
        sys.exit(1)
