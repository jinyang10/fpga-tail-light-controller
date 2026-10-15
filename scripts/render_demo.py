#!/usr/bin/env python3
"""Render the first simulated LED sequence from the regression VCD."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]

def read_pattern(path):
    scope, names, values, steps = [], {}, {}, {}
    signals = {
        "leds": "tail_light_tb.leds", "sw": "tail_light_tb.sw",
        "state": "tail_light_tb.dut.state", "step": "tail_light_tb.dut.step",
    }

    def sample():
        if values.get("state") == 2 and values.get("sw") == 0:
            step, leds = values.get("step"), values.get("leds")
            if step is not None and leds is not None:
                steps.setdefault(step, leds)

    with path.open() as stream:
        for line in stream:
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "$scope":
                scope.append(parts[2])
            elif parts[0] == "$upscope":
                scope.pop()
            elif parts[0] == "$var":
                full_name = ".".join([*scope, parts[4]])
                for name, signal in signals.items():
                    if signal == full_name:
                        names[parts[3]] = name
            elif line.startswith("#"):
                sample()
                if len(steps) == 44:
                    break
            elif line[0] in "bB":
                bits, code = parts[0][1:], parts[1]
                if code in names:
                    values[names[code]] = int(bits, 2) if set(bits) <= {"0", "1"} else None
    sample()
    if len(steps) != 44:
        raise ValueError(f"Expected 44 unmasked steps, found {len(steps)}")
    return [steps[i] for i in range(44)]

def font(size, bold=False):
    candidates = [
        Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf"),
        Path("/usr/share/fonts/truetype/dejavu") / ("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()

def render(pattern):
    frames = []
    for step, bits in enumerate(pattern):
        image = Image.new("RGB", (1100, 440), "#0c1422")
        draw = ImageDraw.Draw(image)
        draw.text((48, 29), "FPGA / DIGITAL DESIGN", font=font(16, True), fill="#58d8c0")
        draw.text((46, 60), "Tail Light Controller", font=font(42, True), fill="#f4f7fc")
        draw.text((48, 119), "Verilog  |  DE10-Lite  |  50 MHz", font=font(19), fill="#b2c0d4")
        draw.rounded_rectangle((42, 170, 1058, 332), radius=22, fill="#152237", outline="#31465f", width=2)
        for index in range(10):
            x = 104 + index * 99
            on = bool(bits & (1 << (9 - index)))
            if on:
                draw.ellipse((x-29, 222, x+29, 280), fill="#662b3d")
            draw.ellipse((x-20, 231, x+20, 271), fill="#ff4e64" if on else "#27354a")
            draw.text((x-12, 291), str(9-index), font=font(14), fill="#b2c0d4")
        draw.text((67, 186), "LEFT BANK", font=font(13, True), fill="#9bacc4")
        draw.text((917, 186), "RIGHT BANK", font=font(13, True), fill="#9bacc4")
        draw.text((48, 357), f"STEP {step+1:02d} / 44", font=font(19, True), fill="#f4f7fc")
        draw.text((271, 357), "1.0 s hold" if step in (11,31) else "0.1 s step", font=font(19), fill="#b2c0d4")
        draw.text((684, 357), "RTL simulation / one sequence", font=font(17), fill="#9bacc4")
        draw.rounded_rectangle((48, 404, 1052, 409), radius=2, fill="#27354a")
        draw.rounded_rectangle((48, 404, 48 + int(1004*(step+1)/44), 409), radius=2, fill="#58d8c0")
        frames.append(image)
    return frames

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcd", type=Path, default=ROOT / "build/iverilog/tail_light.vcd")
    args = parser.parse_args()
    frames = render(read_pattern(args.vcd))
    output = ROOT / "docs/assets"
    output.mkdir(parents=True, exist_ok=True)
    frames[0].save(output / "preview.png")
    frames[0].save(output / "demo.gif", save_all=True, append_images=frames[1:],
                   duration=[1000 if i in (11, 31) else 100 for i in range(44)], loop=0, optimize=False)
    print(output / "demo.gif")

if __name__ == "__main__":
    main()
