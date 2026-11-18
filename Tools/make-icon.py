#!/usr/bin/env python3
"""Builds the AMS Seedboard app icon: a flat calm teal tile with the white hand-drawn "seed with branches"
(AMS-Icons AppMark.seedSprout). One 1.9 stroke on the 24-point grid, round ends, symbol ~62 % of the tile.
iPhone picture: RGB, no transparency, square corners. Mac pictures: rounded tile with a little room around it.

Writes App/Resources/Assets.xcassets/AppIcon.appiconset (icon-1024.png + Mac sizes + Contents.json).
Run:  python3 Tools/make-icon.py        (needs Pillow)
"""
import json, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILE_COLOUR = (0x1F, 0x8A, 0x8A)
WHITE = (255, 255, 255)
STROKE = 1.9
SHARE = 0.62


def bez(p0, c1, c2, p1, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u**3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p1[0],
                    u**3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p1[1]))
    return pts


def ellipse(cx, cy, rx, ry, n=64):
    import math
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]


# AMS-Icons seedSprout (24 grid): seed, three branches, three end dots
LINES = [
    ellipse(7.4, 12, 2.8, 4),
    [(10.2, 12), (15.5, 12)],
    bez((9.9, 10.6), (11.9, 8), (13.1, 6.5), (15.9, 6.5)),
    bez((9.9, 13.4), (11.9, 16), (13.1, 17.5), (15.9, 17.5)),
    ellipse(17.7, 6.5, 1.7, 1.7),
    ellipse(17.3, 12, 1.7, 1.7),
    ellipse(17.7, 17.5, 1.7, 1.7),
]


def draw_glyph(d, size, share, stroke):
    k = size * share / 24.0
    o = size / 2 - 12 * k
    w = max(1, round(stroke * k))
    for pts in LINES:
        xy = [(o + x * k, o + y * k) for x, y in pts]
        d.line(xy, fill=WHITE, width=w, joint="curve")
        for x, y in xy:   # round ends and joins
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=WHITE)


def phone_icon(ss=4):
    s = 1024 * ss
    img = Image.new("RGB", (s, s), TILE_COLOUR)
    draw_glyph(ImageDraw.Draw(img), s, SHARE, STROKE)
    return img.resize((1024, 1024), Image.LANCZOS)


def mac_icon(px, ss=4):
    stroke = STROKE if px > 64 else 2.5
    s = 1024 * ss
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = 100 * ss
    d.rounded_rectangle([m, m, s - m, s - m], radius=185 * ss, fill=TILE_COLOUR + (255,))
    draw_glyph(d, s, 0.80 * SHARE * 1.12, stroke)
    return img.resize((px, px), Image.LANCZOS)


if __name__ == "__main__":
    folder = os.path.join(ROOT, "App", "Resources", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(folder, exist_ok=True)
    phone_icon().save(os.path.join(folder, "icon-1024.png"))
    images = [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f"mac-{base}.png" if scale == 1 else f"mac-{base}@2x.png"
            mac_icon(base * scale).save(os.path.join(folder, name))
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{base}x{base}"})
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=1)
    print("icon written; iPhone picture mode:", Image.open(os.path.join(folder, "icon-1024.png")).mode)
