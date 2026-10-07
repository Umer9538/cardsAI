#!/usr/bin/env python3
"""Draws the Carbs AI wordmark.

The mark used to be a hand-made PNG with no way to regenerate it, which is how
it ended up reading "Carbsai" — one word — long after the brand was written
"Carbs AI" everywhere else. A raster nobody can rebuild is a raster that drifts
from the thing it is supposed to say.

It is set in the app's own Space Grotesk Bold so the mark and the UI are the
same typeface, with "AI" in the brand orange, exactly as the first one was.

    python3 tool/make_wordmark.py

Writes assets/images/splash/logo_carbsai.png. The filename is deliberately
unchanged: it is referenced from Dart and from the splash's layout numbers, and
renaming the file buys nothing. The *picture* is the brand, not the path.

The canvas is 486x162 because `DesignImage` takes exported pixels / 3, and the
splash places it at 162x54 on the artboard. Keep that ratio or the splash
layout numbers stop matching the art.
"""

import pathlib

from PIL import Image, ImageDraw, ImageFont

OUT = pathlib.Path("assets/images/splash/logo_carbsai.png")
FONT = pathlib.Path("assets/fonts/SpaceGrotesk-Bold.ttf")

# AppColors.white and AppColors.primary.
WHITE = (255, 255, 255, 255)
ORANGE = (255, 90, 22, 255)

WIDTH, HEIGHT = 486, 162
SIZE = 108  # Tuned so "Carbs AI" fills the width the way "Carbsai" did.


def main() -> None:
    if not FONT.exists():
        raise SystemExit(f"missing {FONT}")

    font = ImageFont.truetype(str(FONT), SIZE)

    # Measured, not guessed: the two runs are drawn separately so "AI" can take
    # the brand orange, which means the second run's x depends on the first
    # run's advance rather than on its ink bounds.
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    left = "Carbs "
    right = "AI"
    left_w = probe.textlength(left, font=font)
    right_w = probe.textlength(right, font=font)
    total = left_w + right_w

    canvas = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    x = (WIDTH - total) / 2
    # Vertical centring off the cap box rather than the full ascent: Space
    # Grotesk's ascent includes diacritic room this string never uses, so
    # centring on it leaves the mark visibly high.
    top, bottom = font.getbbox("CarbsAI")[1], font.getbbox("CarbsAI")[3]
    y = (HEIGHT - (bottom - top)) / 2 - top

    draw.text((x, y), left, font=font, fill=WHITE)
    draw.text((x + left_w, y), right, font=font, fill=ORANGE)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT)
    print(f"wrote {OUT}  {canvas.size}  mode={canvas.mode}")


if __name__ == "__main__":
    main()
