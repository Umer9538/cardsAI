#!/usr/bin/env python3
"""Builds the Google Play feature graphic, 1024x500.

    python3 tool/make_feature_graphic.py

Composited from the brand masters rather than drawn by hand or generated, so
the mascot and the wordmark are pixel-identical to the ones in the app and a
change to either propagates by re-running this.

The ground is #121212, the app's own, and not the orange of the icon. Two
reasons, both measured: the wordmark is white with an orange "ai", so on an
orange field half of it disappears; and the mascot scores 15:1 contrast on
#121212 against 2.5:1 on #FF5A16, which is the difference between "excellent"
and "below the minimum" on the contrast scale Play's own design guidance uses.

Play's rules this file is built to (each one a rejection or a crop):
  - exactly 1024x500, JPEG or 24-bit PNG, and NO alpha channel
  - critical content inside the middle 80%; the background bleeds to the edges
  - nothing important in the bottom-right 200x80, where a promo video puts its
    play button
  - no star ratings, install counts, store badges or price claims anywhere,
    which is why there is no room here to add any
"""

import pathlib
from PIL import Image, ImageDraw, ImageFont

W, H = 1024, 500
INK = (18, 18, 18)          # AppColors.background
ORANGE = (255, 90, 22)      # AppColors.primary
WHITE = (255, 255, 255)
MUTED = (201, 195, 186)   # 10.7:1 on the ink — "excellent" band

TAGLINE = "Count calories by taking a photo"


def glow(size, centre, radius, colour, peak=0.42):
    """A soft radial wash. Drawn at an eighth scale and blown back up, which
    is cheaper than per-pixel and leaves no banding."""
    w, h = size
    sw, sh = w // 8, h // 8
    layer = Image.new("L", (sw, sh), 0)
    d = ImageDraw.Draw(layer)
    cx, cy = centre[0] / 8, centre[1] / 8
    steps = 48
    for i in range(steps, 0, -1):
        r = radius / 8 * i / steps
        a = int(255 * peak * (1 - i / steps) ** 2)
        d.ellipse([cx - r, cy - r * 0.85, cx + r, cy + r * 0.85], fill=a)
    layer = layer.resize((w, h), Image.LANCZOS)
    wash = Image.new("RGBA", (w, h), colour + (0,))
    wash.putalpha(layer)
    return wash


def sparkle(draw, x, y, r, colour):
    """A four-point star: the app's own sparkle, as a diamond with concave
    sides approximated by two crossed lens shapes."""
    draw.polygon(
        [(x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y),
         (x + r * 0.28, y + r * 0.28), (x, y + r),
         (x - r * 0.28, y + r * 0.28), (x - r, y),
         (x - r * 0.28, y - r * 0.28)],
        fill=colour,
    )


def main():
    canvas = Image.new("RGB", (W, H), INK)

    # Warm glow behind the mascot, so the right side has depth without the
    # background stopping being flat where the text sits.
    canvas.paste(
        Image.alpha_composite(
            canvas.convert("RGBA"), glow((W, H), (782, 250), 540, ORANGE, peak=0.5)
        ).convert("RGB"),
        (0, 0),
    )

    d = ImageDraw.Draw(canvas, "RGBA")
    # Sparkles, sparse and only in the dark half so they never crowd the type.
    for x, y, r, a in [(168, 92, 9, 90), (612, 84, 13, 120), (566, 404, 8, 70),
                       (122, 400, 7, 60), (676, 196, 6, 70)]:
        sparkle(d, x, y, r, ORANGE + (a,))

    # The mascot, on the right. Sized so its lowest point clears the bottom
    # edge and it stays out of the play-button corner.
    mascot = Image.open("assets/images/brand/mascot.png").convert("RGBA")
    mh = 396
    mw = round(mascot.width * mh / mascot.height)
    mascot = mascot.resize((mw, mh), Image.LANCZOS)
    canvas.paste(mascot, (W - mw - 58, (H - mh) // 2 - 6), mascot)

    # The wordmark, left, trimmed to its ink so the margin is the one set here
    # rather than whatever padding the source file happens to carry.
    mark = Image.open("assets/images/splash/logo_carbsai.png").convert("RGBA")
    mark = mark.crop(mark.getbbox())
    lw = 340
    lh = round(mark.height * lw / mark.width)
    mark = mark.resize((lw, lh), Image.LANCZOS)
    left, top = 104, 174
    canvas.paste(mark, (left, top), mark)

    # One line, well inside the 5-7 words Play's own guidance asks for, set in
    # the app's own face so the banner and the app agree.
    font = ImageFont.truetype("assets/fonts/SpaceGrotesk-Medium.ttf", 27)
    ImageDraw.Draw(canvas).text((left + 3, top + lh + 26), TAGLINE,
                                font=font, fill=MUTED)

    out = pathlib.Path("build/feature_graphic_1024x500.png")
    out.parent.mkdir(exist_ok=True)
    # RGB, so the PNG carries no alpha channel. A transparent feature graphic
    # is rejected.
    canvas.save(out)
    print(f"wrote {out}  {canvas.size}  mode={canvas.mode}")


if __name__ == "__main__":
    main()
