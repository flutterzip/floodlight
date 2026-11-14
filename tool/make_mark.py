"""Draws Floodlight's app icon and logo from code.

The mark is a bank of six lamps on a mast. `FloodlightMark` in
lib/widgets/floodlight_mark.dart paints the same geometry (see
`MarkGeometry` there); keep the two in step.

    python3 tool/make_mark.py && python3 tool/make_icons.py

The colours are read from Palette.light in lib/config/palette.dart, so the
icon follows the app's palette. Requires Pillow.
"""
import math
import re

from PIL import Image, ImageDraw, ImageFilter


def palette(mode="light"):
    src = open("lib/config/palette.dart").read()
    block = src[src.index(f"static const {mode} = Palette("):]
    block = block[: block.index(");\n")]
    out = {}
    for name, hexa in re.findall(r"(\w+): Color\(0x([0-9A-Fa-f]{8})\)", block):
        out[name] = tuple(int(hexa[i:i + 2], 16) for i in (2, 4, 6))
    return out


P = palette()
SS = 4

# The mark on a unit square. Shared with MarkGeometry.
PANEL_C = (0.5, 0.37)
PANEL_W, PANEL_H, PANEL_R = 0.7, 0.44, 0.09
TILT = -8
LAMP_R, GAP_X, GAP_Y = 0.068, 0.2, 0.19
MAST_TOP, MAST_FOOT, MAST_W, FOOT_W = 0.58, 0.93, 0.07, 0.3


def mark(size, body, lamp, glow=True):
    """The mark alone, on a transparent square."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    foot = s * MAST_FOOT
    d.rounded_rectangle([s * (.5 - MAST_W / 2), s * MAST_TOP, s * (.5 + MAST_W / 2), foot],
                        radius=s * .02, fill=body)
    d.rounded_rectangle([s * (.5 - FOOT_W / 2), foot - s * .03, s * (.5 + FOOT_W / 2), foot + s * .03],
                        radius=s * .03, fill=body)

    # The panel is drawn flat on its own layer, then tilted into place.
    panel = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pd = ImageDraw.Draw(panel)
    cx, cy = s / 2, s / 2
    pd.rounded_rectangle([cx - s * PANEL_W / 2, cy - s * PANEL_H / 2,
                          cx + s * PANEL_W / 2, cy + s * PANEL_H / 2],
                         radius=s * PANEL_R, fill=body)
    lamps = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lamps)
    for row in range(2):
        for col in range(3):
            x, y = cx + (col - 1) * GAP_X * s, cy + (row - .5) * GAP_Y * s
            r = LAMP_R * s
            ld.ellipse([x - r, y - r, x + r, y + r], fill=lamp)
    if glow:
        halo = lamps.filter(ImageFilter.GaussianBlur(s * .035))
        halo.putalpha(halo.getchannel("A").point(lambda a: int(a * .55)))
        panel = Image.alpha_composite(panel, halo)
    panel = Image.alpha_composite(panel, lamps)
    panel = panel.rotate(-TILT, resample=Image.BICUBIC, center=(cx, cy))
    shift = (int(s * PANEL_C[0] - cx), int(s * PANEL_C[1] - cy))
    moved = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    moved.paste(panel, shift, panel)
    img = Image.alpha_composite(img, moved)
    return img.resize((size, size), Image.LANCZOS)


def icon(size):
    """The mark on the night of the scoreboard, with a wash of light."""
    s = size
    board = P["board"]
    img = Image.new("RGBA", (s, s), board + (255,))
    # Light pooling behind the lamps.
    pool = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pool)
    r = s * .46
    cx, cy = s * .5, s * .4
    pd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=P["accent"] + (70,))
    pool = pool.filter(ImageFilter.GaussianBlur(s * .14))
    img = Image.alpha_composite(img, pool)
    inner = int(s * .7)
    m = mark(inner, P["onBoard"], P["accent"])
    img.paste(m, ((s - inner) // 2, int(s * .15)), m)
    return img


if __name__ == "__main__":
    icon(1024).convert("RGB").save("assets/brand/icon_1024.png")
    mark(1024, P["ink"], P["accent"]).save("assets/brand/mark.png")
    print("assets/brand/icon_1024.png, assets/brand/mark.png")
