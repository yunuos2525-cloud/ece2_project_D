import math

FS = 16000.0
N = 4096
COEFF = (15834, -29257, 15834, -28760, 14787)


def tone_amplitude(values, frequency, start, stop):
    count = stop - start
    c = 0.0
    s = 0.0
    for n in range(start, stop):
        phase = 2.0 * math.pi * frequency * n / FS
        c += values[n] * math.cos(phase)
        s += values[n] * math.sin(phase)
    return 2.0 * math.hypot(c, s) / count


def simulate(a500, a1000):
    b0, b1, b2, a1, a2 = COEFF
    x1 = x2 = y1 = y2 = 0
    inputs = []
    outputs = []
    saturation_count = 0
    max_abs_acc = 0
    for n in range(N):
        value = (
            128.0
            + a500 * math.sin(2.0 * math.pi * 500.0 * n / FS)
            + a1000 * math.sin(2.0 * math.pi * 1000.0 * n / FS)
        )
        sample = math.floor(value + 0.5)
        x0 = sample - 128
        acc = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        scaled = acc >> 14
        max_abs_acc = max(max_abs_acc, abs(acc))
        if scaled > 127:
            y0 = 127
            saturation_count += 1
        elif scaled < -128:
            y0 = -128
            saturation_count += 1
        else:
            y0 = scaled
        x2, x1 = x1, x0
        y2, y1 = y1, y0
        inputs.append(x0)
        outputs.append(y0)
    return inputs, outputs, saturation_count, max_abs_acc


def db(ratio):
    return 20.0 * math.log10(ratio)


def report_case(name, a500, a1000):
    x, y, saturations, max_abs_acc = simulate(a500, a1000)
    print(f"CASE {name}: nominal A500={a500:.1f} A1000={a1000:.1f}")
    print(
        f"  ranges input=[{min(x)},{max(x)}] output=[{min(y)},{max(y)}] "
        f"output_saturation_count={saturations} max_abs_acc={max_abs_acc}"
    )
    for label, start, stop in (
        ("transient_0_511", 0, 512),
        ("official_512_4095", 512, 4096),
        ("late_2048_4095", 2048, 4096),
    ):
        in500 = tone_amplitude(x, 500.0, start, stop)
        out500 = tone_amplitude(y, 500.0, start, stop)
        in1000 = tone_amplitude(x, 1000.0, start, stop)
        out1000 = tone_amplitude(y, 1000.0, start, stop)
        gain500 = db(out500 / in500) if in500 > 1e-12 else float("nan")
        gain1000 = db(out1000 / in1000) if in1000 > 1e-12 and out1000 > 0 else float("-inf")
        print(
            f"  {label}: in500={in500:.6f} out500={out500:.6f} gain500={gain500:.6f}dB "
            f"in1000={in1000:.6f} out1000={out1000:.6f} gain1000={gain1000:.6f}dB"
        )


def theoretical_gain(frequency):
    b0, b1, b2, a1, a2 = [v / 16384.0 for v in COEFF]
    w = 2.0 * math.pi * frequency / FS
    z1 = complex(math.cos(w), -math.sin(w))
    z2 = z1 * z1
    h = (b0 + b1 * z1 + b2 * z2) / (1.0 + a1 * z1 + a2 * z2)
    return abs(h), db(abs(h))


print("RTL-exact integer diagnostic; no RTL or original test artifact modified")
mag, gain = theoretical_gain(500.0)
print(f"Quantized-coefficient linear H(500Hz): magnitude={mag:.9f} gain={gain:.6f}dB")
report_case("pure500_A40", 40.0, 0.0)
report_case("pure500_A35", 35.0, 0.0)
report_case("mixed_A35_A35", 35.0, 35.0)
