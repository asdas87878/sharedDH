"""A measured plan of the hub from above, drawn from what is in the place (2026-11-20, the hub study: the dive-in
strip, the walls round it, the space behind the back tanks; docs/design/hub-layout.md).

Input: art/map/hub_study/dump.csv, one row per part in the hub's box, read from Studio (x, z, size x, size z, turn,
top, bottom, colour, path). Parts are drawn lowest first in their own colour, shaded by height, so terraces and walls
read as steps; the lane (+Z) is at the top.

usage: python tools/map/hub_plan.py [dump.csv] [out.png] [--grid]"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
X0, X1, Z0, Z1 = 2740.0, 3260.0, -420.0, 120.0
PX = 2.4  # pixels a stud


def load(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        f = line.strip().split(",")
        if len(f) < 9:
            continue
        x, z, sx, sz, ry, top, bot = (float(v) for v in f[:7])
        rows.append({"x": x, "z": z, "sx": sx, "sz": sz, "ry": ry, "top": top, "bot": bot, "c": f[7], "path": f[8]})
    return rows


def to_px(x, z):
    return (x - X0) * PX, (Z1 - z) * PX


def corners(r):
    a = math.radians(r["ry"])
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = dx * r["sx"] / 2, dz * r["sz"] / 2
        # Roblox: a turn about +Y by a maps local (x, z) to (x cos a + z sin a, -x sin a + z cos a)
        out.append(to_px(r["x"] + lx * ca + lz * sa, r["z"] - lx * sa + lz * ca))
    return out


def shade(hexc, top):
    c = [int(hexc[i:i + 2], 16) for i in (0, 2, 4)]
    k = 0.72 + 0.28 * max(0.0, min(1.0, (top + 2) / 90))  # higher is lighter
    return tuple(min(255, int(v * k)) for v in c)


def draw(rows, out, notes=(), title=""):
    W, H = int((X1 - X0) * PX), int((Z1 - Z0) * PX)
    im = Image.new("RGB", (W, H + 60), (40, 44, 52))
    d = ImageDraw.Draw(im)
    for r in sorted(rows, key=lambda r: r["top"]):
        d.polygon(corners(r), fill=shade(r["c"], r["top"]), outline=(30, 30, 30) if r["top"] > 30 else None)
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15)
    small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 12)
    for gx in range(int(X0 // 40 * 40), int(X1), 40):
        d.line([to_px(gx, Z1), to_px(gx, Z1 - 4)], fill=(255, 255, 255))
    for n in notes:
        kind = n[0]
        if kind == "line":
            _, a, b, colour, text = n
            d.line([to_px(*a), to_px(*b)], fill=colour, width=3)
            for p in (a, b):
                x, y = to_px(*p)
                d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=colour)
            mx, my = to_px((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            d.text((mx + 6, my - 8), text, font=font, fill=colour, stroke_width=3, stroke_fill=(0, 0, 0))
        elif kind == "label":
            _, p, colour, text = n
            x, y = to_px(*p)
            d.text((x, y), text, font=small, fill=colour, stroke_width=2, stroke_fill=(0, 0, 0))
        elif kind == "box":
            _, a, b, colour = n
            d.rectangle([to_px(a[0], b[1]), to_px(b[0], a[1])], outline=colour, width=3)
    d.text((10, H + 10), title, font=font, fill=(240, 240, 240))
    d.text((10, H + 34), "lane (+Z) at the top; a tick every 40 studs; lighter = higher", font=small, fill=(200, 200, 200))
    im.save(out, quality=92)
    return im


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    src = args[0] if args else os.path.join(ROOT, "art", "map", "hub_study", "dump.csv")
    out = args[1] if len(args) > 1 else os.path.join(ROOT, "art", "map", "hub_study", "plan_now.png")
    draw(load(src), out, title="The hub as it is in the place (2026-11-20)")
    print(out)
