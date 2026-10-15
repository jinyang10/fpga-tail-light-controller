#!/usr/bin/env python3
"""Run the RTL regression with Icarus Verilog or Questa."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def run(args, cwd=ROOT):
    print("+ " + " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=cwd, check=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim", choices=["iverilog", "questa"], default="iverilog")
    parser.add_argument("--bin", type=Path, help="Directory containing simulator executables")
    args = parser.parse_args()
    build = ROOT / "build" / args.sim
    build.mkdir(parents=True, exist_ok=True)

    def exe(name):
        found = shutil.which(name, path=str(args.bin) if args.bin else None)
        if not found:
            parser.error(f"{name} not found. Install the simulator or pass --bin PATH.")
        return found

    sources = [ROOT / "rtl/tail_light_controller.v", ROOT / "tests/tail_light_tb.sv"]
    if args.sim == "iverilog":
        target = build / "test.vvp"
        run([exe("iverilog"), "-g2012", "-Wall", "-s", "tail_light_tb", "-o", target, *sources])
        run([exe("vvp"), target], cwd=build)
    else:
        if not (build / "work").exists():
            run([exe("vlib"), "work"], cwd=build)
        run([exe("vlog"), "-sv", *sources], cwd=build)
        run([exe("vsim"), "-c", "work.tail_light_tb", "-do",
             "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], cwd=build)

if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
