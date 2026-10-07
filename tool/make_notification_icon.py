#!/usr/bin/env python3
"""Generates the Android status-bar icon for meal reminders.

    python3 tool/make_notification_icon.py

Android draws a notification's small icon from its **alpha channel only**,
tinted with the notification's colour — every opaque pixel becomes one flat
colour. So the launcher icon cannot be used: it is opaque edge to edge, and
Android renders it as a solid white square. That is what this app shipped.

The mascot cannot be used either. A silhouette of it at 24dp merges the leaf,
the thumb and the gloves into the body and reads as a blob; the face, which is
the only part anyone recognises, is interior detail that an alpha silhouette
throws away.

So the mark is the mascot reduced to the one shape that survives 24 square
pixels: the avocado half, with the pit knocked out. It is drawn here rather
than exported so that the pit stays a real hole at every density — scaling a
24px master up would make the hole ragged, and scaling a 96px master down would
close it.

Written at 4x and downsampled, which is what keeps the curve clean at mdpi.
"""

import math
import pathlib
from PIL import Image, ImageDraw

# Android's status-bar icon is 24dp. Anything drawn to the edge is clipped by
# the system's own padding on some launchers, so the shape sits inside a
# margin rather than filling the canvas.
DENSITIES = {
    "mdpi": 24,
    "hdpi": 36,
    "xhdpi": 48,
    "xxhdpi": 72,
    "xxxhdpi": 96,
}
# Geometry, as fractions of the canvas. The avocado is the union of two
# circles and the tangent band between them — a neck and a body — which is an
# exact construction rather than a curve fitted by eye, and stays smooth at
# every density. Drawing it from a width function produced a bell: the ends
# fatten faster than the middle narrows.
NECK_Y, NECK_R = 0.335, 0.180
BODY_Y, BODY_R = 0.660, 0.310
PIT_R = 0.132
SUPERSAMPLE = 16


def avocado(size: int) -> Image.Image:
    """A filled avocado half, pit knocked out, as an alpha mask."""
    n = size * SUPERSAMPLE
    mask = Image.new("L", (n, n), 0)
    draw = ImageDraw.Draw(mask)

    cx = n / 2
    y1, r1 = NECK_Y * n, NECK_R * n
    y2, r2 = BODY_Y * n, BODY_R * n

    def circle(cy, r):
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    circle(y1, r1)
    circle(y2, r2)

    # The external tangents. Their contact points close the waist between the
    # two circles without the notch a plain union leaves.
    beta = math.asin((r2 - r1) / (y2 - y1))
    dx, dy = math.cos(beta), math.sin(beta)
    draw.polygon(
        [
            (cx + r1 * dx, y1 - r1 * dy),
            (cx + r2 * dx, y2 - r2 * dy),
            (cx - r2 * dx, y2 - r2 * dy),
            (cx - r1 * dx, y1 - r1 * dy),
        ],
        fill=255,
    )

    # The stem: a short stub off the top, the one piece of the mascot besides
    # the outline that still reads once everything else is gone.
    stem_w = n * 0.060
    stem_top = n * 0.055
    draw.rounded_rectangle(
        [cx - stem_w / 2, stem_top, cx + stem_w / 2, y1 - r1 * 0.2],
        radius=stem_w / 2,
        fill=255,
    )

    # The pit, as a hole. A filled pit would vanish — every opaque pixel is the
    # same colour — so the only way to show it is to take it away.
    pit_r = PIT_R * n
    draw.ellipse([cx - pit_r, y2 - pit_r, cx + pit_r, y2 + pit_r], fill=0)

    return mask.resize((size, size), Image.LANCZOS)


def main() -> None:
    root = pathlib.Path("android/app/src/main/res")
    written = []
    for density, size in DENSITIES.items():
        out = root / f"drawable-{density}"
        out.mkdir(parents=True, exist_ok=True)

        icon = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        icon.putalpha(avocado(size))
        # White so the file is legible on its own; only the alpha is used.
        icon.paste((255, 255, 255), (0, 0, size, size), icon.split()[3])

        path = out / "ic_stat_meal.png"
        icon.save(path)
        written.append(f"  {path}  {size}x{size}")

    # A large preview, so the shape can be checked without a device.
    preview = Image.new("RGBA", (256, 256), (18, 18, 18, 255))
    mark = Image.new("RGBA", (256, 256), (255, 255, 255, 0))
    mark.putalpha(avocado(256))
    mark.paste((255, 255, 255), (0, 0, 256, 256), mark.split()[3])
    preview.alpha_composite(mark)
    preview.save("build/notification_icon_preview.png")

    print("wrote:")
    print("\n".join(written))
    print("  build/notification_icon_preview.png  (preview only)")


if __name__ == "__main__":
    main()
