"""Put the user's drawn lines back onto our renders. The user draws over a screenshot of the face comparison sheet
(docs/attachments/workout2-face-compare.jpg, laid out 3 cells of 460x420 across, concept row on top, kit row below); this
finds the sheet's scale in the screenshot from its cream cells, maps every red pixel in the kit row's front and side cells back
to render pixels (through the crop and scale the sheet used), and draws them on the renders they were drawn over and on the
current ones, side by side.

usage: python tools/art/lines_overlay.py <drawn screenshot> <renders drawn on> <current renders> <out.jpg>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

drawn, old_dir, new_dir, out = sys.argv[1:5]
BG = (254, 248, 241)
CELL = (460, 420)
CELLS = {"front": ((10, 500), None, (90, 60, 470, 470)), "side": ((480, 500), 0.42, (0, 0, 470, 560))}  # sheet xy, crop, view

u = np.asarray(Image.open(drawn).convert("RGB")).astype(int)
cream = (abs(u[..., 0] - 254) <= 2) & (abs(u[..., 1] - 248) <= 3) & (abs(u[..., 2] - 241) <= 3)


def runs(counts, threshold):
    out, start = [], None
    for i, v in enumerate(list(counts) + [0]):
        if v > threshold and start is None:
            start = i
        elif v <= threshold and start is not None:
            out.append((start, i - 1))
            start = None
    return out


rows = [r for r in runs(cream.sum(axis=1), 40) if r[1] - r[0] > 50]
cols = [c for c in runs(cream.sum(axis=0), 40) if c[1] - c[0] > 20]
k = (rows[1][1] - rows[1][0] + 1) / CELL[1]  # the kit row is the second
oy = rows[1][0] - 500 * k
ox = cols[0][0] - 10 * k
print(f"sheet scale {k:.4f}, offset ({ox:.1f}, {oy:.1f})")
red = (u[..., 0] > 170) & (u[..., 1] < 90) & (u[..., 2] < 90)
vs, us = np.nonzero(red)
X, Y = (us - ox) / k, (vs - oy) / k


def flatten(path):
    im = Image.open(path).convert("RGBA")
    base = Image.new("RGBA", im.size, BG + (255,))
    base.alpha_composite(im)
    return base.convert("RGB")


font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 20)
panels = []
for name, ((cx, cy), frac, view) in CELLS.items():
    im = Image.open(os.path.join(old_dir, f"{name}.png")).convert("RGBA")
    x0, y0, x1, y1 = im.getbbox()
    w, h = x1 - x0, y1 - y0
    if frac:
        w = int(w * frac)
    s = min(CELL[0] / w, CELL[1] / h)
    pad = ((CELL[0] - int(w * s)) // 2, (CELL[1] - int(h * s)) // 2)
    inside = (X >= cx) & (X < cx + CELL[0]) & (Y >= cy) & (Y < cy + CELL[1])
    px = x0 + (X[inside] - cx - pad[0]) / s
    py = y0 + (Y[inside] - cy - pad[1]) / s
    print(name, int(inside.sum()), "line pixels")
    pair = []
    for label, folder in (("drawn on", old_dir), ("now", new_dir)):
        shot = flatten(os.path.join(folder, f"{name}.png"))
        d = ImageDraw.Draw(shot)
        for x, y in zip(px, py):
            d.point((float(x), float(y)), fill=(230, 20, 20))
        shot = shot.crop(view)
        shot = shot.resize((shot.width * 2, shot.height * 2), Image.LANCZOS)
        ImageDraw.Draw(shot).text((10, 8), f"{name}, {label} (red: your lines)", font=font, fill=(40, 40, 40))
        pair.append(shot)
    row = Image.new("RGB", (pair[0].width + pair[1].width + 10, max(p.height for p in pair)), (255, 255, 255))
    row.paste(pair[0], (0, 0))
    row.paste(pair[1], (pair[0].width + 10, 0))
    panels.append(row)
sheet = Image.new("RGB", (max(p.width for p in panels), sum(p.height for p in panels) + 10), (255, 255, 255))
y = 0
for p in panels:
    sheet.paste(p, (0, y))
    y += p.height + 10
sheet = sheet.resize((sheet.width * 2 // 3, sheet.height * 2 // 3), Image.LANCZOS)
sheet.save(out, quality=88)
print("saved", out, sheet.size)
