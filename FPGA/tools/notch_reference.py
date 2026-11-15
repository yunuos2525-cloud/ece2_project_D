#!/usr/bin/env python3
"""Generate Q2.14 notch coefficients and quantized linear-response evidence."""
from __future__ import annotations
import argparse, csv, cmath, math
from pathlib import Path

FS = 16_000.0
TARGETS = (930, 1370, 1830, 2460)
RADIUS = 0.95

def q214(value: float) -> int:
    scaled = value * (1 << 14)
    return int(scaled + 0.5) if scaled >= 0 else int(scaled - 0.5)

def coefficients(freq: float) -> tuple[int, int, int, int, int]:
    w = 2.0 * math.pi * freq / FS
    gain = (1.0 - 2.0 * RADIUS * math.cos(w) + RADIUS**2) / (2.0 - 2.0 * math.cos(w))
    return (q214(gain), q214(-2.0 * gain * math.cos(w)), q214(gain),
            q214(-2.0 * RADIUS * math.cos(w)), q214(RADIUS**2))

def response_db(coeff: tuple[int, ...], freq: float) -> float:
    b0, b1, b2, a1, a2 = (v / (1 << 14) for v in coeff)
    z1 = cmath.exp(-1j * 2.0 * math.pi * freq / FS)
    h = (b0 + b1*z1 + b2*z1*z1) / (1.0 + a1*z1 + a2*z1*z1)
    return 20.0 * math.log10(max(abs(h), 1e-15))

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("target_hz", "b0_q214", "b1_q214", "b2_q214", "a1_q214", "a2_q214",
                         "model_target_db", "model_500hz_db", "pole_radius"))
        for target in TARGETS:
            coeff = coefficients(target)
            writer.writerow((target, *coeff, f"{response_db(coeff,target):.6f}",
                             f"{response_db(coeff,500):.6f}", RADIUS))
            print(f"MODEL target={target} coeff={coeff} target_db={response_db(coeff,target):.3f} "
                  f"pass500_db={response_db(coeff,500):.3f}")

if __name__ == "__main__":
    main()
