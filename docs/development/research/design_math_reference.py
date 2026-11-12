"""Independent reference arithmetic for the adjacent design research note.

No vendor imports or application dependencies. Run directly with Python 3.
The checks concern mathematical contracts, not browser or plugin execution.
"""

import json
import math


def progress(value, lower, upper):
    if not all(math.isfinite(v) for v in (value, lower, upper)) or upper <= lower:
        raise ValueError("Finite ordered viewport bounds are required")
    return max(0.0, min(1.0, (value - lower) / (upper - lower)))


def interpolate(value, lower, upper, start, end):
    return start + progress(value, lower, upper) * (end - start)


def luminance(rgb):
    def linear(channel):
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    return sum(weight * linear(channel) for weight, channel in zip((0.2126, 0.7152, 0.0722), rgb))


def contrast(a, b):
    first, second = sorted((luminance(a), luminance(b)))
    return (second + 0.05) / (first + 0.05)


def run():
    checks = 0

    def close(actual, expected):
        nonlocal checks
        if not math.isclose(actual, expected, rel_tol=1e-10, abs_tol=1e-10):
            raise AssertionError(f"{actual} != {expected}")
        checks += 1

    for start, end in ((16, 18), (40, 64), (48, 16)):
        for width, expected in ((320, start), (480, start), (840, (start + end) / 2),
                                (1200, end), (1920, end)):
            close(interpolate(width, 480, 1200, start, end), expected)
            slope = (end - start) / (1200 - 480)
            intercept = start - slope * 480
            close(max(min(start, end), min(slope * width + intercept, max(start, end))), expected)
            trig = max(0, min(1, math.tan(math.atan2(width - 480, 1200 - 480))))
            close(trig, progress(width, 480, 1200))

    for lower, upper in ((480, 480), (1200, 480), (0, float("inf"))):
        try:
            progress(840, lower, upper)
        except ValueError:
            checks += 1
        else:
            raise AssertionError("Invalid viewport span was accepted")

    comparison = []
    for width in (320, 480, 660, 840, 1020, 1200, 1920):
        p = progress(width, 480, 1200)
        endpoint = interpolate(width, 480, 1200, 16 * 1.2 ** 3, 18 * 1.333 ** 3)
        ratio_first = (16 + p * 2) * (1.2 + p * (1.333 - 1.2)) ** 3
        comparison.append({"viewport_px": width, "endpoint_first_px": endpoint,
                           "interpolated_ratio_px": ratio_first})
        if width <= 480 or width >= 1200:
            close(endpoint, ratio_first)
    if math.isclose(comparison[3]["endpoint_first_px"], comparison[3]["interpolated_ratio_px"]):
        raise AssertionError("Distinct type-scale curves were incorrectly treated as equivalent")
    checks += 1

    for step in range(-2, 5):
        for width, expected in ((480, 16 * 1.2 ** step), (1200, 18 * 1.333 ** step)):
            close(interpolate(width, 480, 1200, 16 * 1.2 ** step, 18 * 1.333 ** step), expected)

    for columns in range(1, 5):
        minimum, gap = 240, 24
        threshold = columns * minimum + (columns - 1) * gap
        close((threshold - (columns - 1) * gap) / columns, minimum)
        if (threshold - 1 - (columns - 1) * gap) / columns >= minimum:
            raise AssertionError("Grid threshold failed to distinguish insufficient space")
        checks += 1
        for count in range(1, 2 * columns + 2):
            remainder = count % columns or columns
            start_line = columns - remainder + 1
            width = 1280
            track = (width - (2 * columns - 1) * gap) / (2 * columns)
            card = 2 * track + gap
            left = (start_line - 1) * (track + gap)
            occupied = remainder * card + (remainder - 1) * gap
            close(left, width - left - occupied)

    black, white = (0, 0, 0), (1, 1, 1)
    close(luminance(black), 0)
    close(luminance(white), 1)
    close(contrast(black, white), 21)
    close(contrast(white, white), 1)
    close(contrast(black, white), contrast(white, black))

    print(json.dumps({"checks_passed": checks, "scope": "independent arithmetic only",
                      "comparison_step": 3, "comparison": comparison}, indent=2))


if __name__ == "__main__":
    run()
