# Verification

Verified on October 15, 2026. The preview comes from the simulation waveform; physical-board testing of this revision is pending.

## RTL regression

Run `python scripts/test.py` with Python 3.10+ and Icarus Verilog. The local run used Icarus 13.0 and finished with:

```text
PASS: 54568 checks, 57 complete frames, all 10 repeat counts
```

The testbench checks the actual RTL against a separate expected-pattern array. It drives buttons and switches through the public ports; hierarchical signals are observed for cycle-level checks, never forced.

- All repeat selections from 1 through 10: 55 complete sequences.
- A further two sequences after reset and restart.
- Every LED pattern and its exact duration, including both long holds.
- Exact startup delay and countdown changes at sequence boundaries.
- All four bank-mask combinations and the eight unused switches.
- Seven-segment encodings from 0 through A.
- Synchronizer latency, busy-time presses, and held-start behavior.
- Asynchronous reset in startup and playback, with countdown retention.

Timing parameters are reduced to 7 startup ticks, 5 long-step ticks, and 3 short-step ticks. This validates the counter boundaries quickly; it does not simulate billions of cycles at the default board delays. The source defaults and 50 MHz SDC define those hardware delays.

[GitHub Actions](../.github/workflows/verify.yml) runs the same regression and saves the VCD as a workflow artifact. A failing assertion or watchdog exits with an error.

## Quartus build

Built with Quartus Prime Lite 25.1std.0, targeting `10M50DAF484C6GES`. The checked-in project uses a 20.000 ns clock period.

- Compilation: successful, 0 errors.
- Logic elements: 183 / 49,760, about 0.37%.
- Registers: 52. Memory bits, multipliers, and PLLs: 0.
- Minimum setup slack across the three reported corners: **+13.935 ns**.
- Minimum hold slack: **+0.152 ns**.
- Minimum pulse-width slack: **+9.329 ns**.

The [fitter summary](verification/quartus-fit.txt) and [timing summary](verification/quartus-timing.txt) are copied from this build. [Source hashes](verification/source-hashes.json) identify the RTL, project settings, constraints, and testbench used.

These are internal synchronous-path results. The SDC excludes asynchronous button/switch inputs and LED/display outputs, which have no external capture clock. Reset recovery/removal is excluded; synchronized reset release is not implemented. The device uses preliminary timing models, so these results are not production sign-off.

The build reports 21 warnings, including unused switches, the permanently off decimal point, missing drive-strength settings, preliminary device timing, a device I/O advisory, and tool configuration/license notices. None are hidden or counted as failures by the simulation workflow. All 31 active design ports have explicit pin locations.

## Rebuild the preview

Install Pillow, run the regression, then render the VCD:

```bash
python -m pip install Pillow
python scripts/render_demo.py
```

The renderer reads the first complete unmasked LED sequence from the VCD and restores the intended 0.1 s / 1.0 s display durations. It does not independently simulate the controller. The GIF loops for viewing; the real design stops after its selected repeat count.
