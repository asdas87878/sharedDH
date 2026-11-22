"""A top-down map of where the props stand (2026-11-18, for the spread trial: PROPS2=1 GREYBOX_OUT=art/map/spread_trial
python tools/map/greybox.py). Floor tiles light, walls dark, every prop a dot in its own colour sized by its reach,
the small dressing as specks, the lands' borders marked.
usage: python tools/map/spread_map.py <folder with parts.json> <out.png> [s_from] [s_to]"""
import collections
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
parts = json.load(open(os.path.join(src, "parts.json")))["parts"]
path = json.load(open(os.path.join(src, "path.json")))
s0, s1 = (float(sys.argv[3]), float(sys.argv[4])) if len(sys.argv) > 4 else (0.0, 3500.0)
rows = [p for p in path["Path"] if s0 - 200 <= p[0] <= s1 + 200]
xs = [p[1] for p in rows]
zs = [p[3] for p in rows]
x_lo, x_hi, z_lo, z_hi = min(xs) - 700, max(xs) + 700, min(zs) - 150, max(zs) + 150
K = 0.55  # pixels a stud
W, H = int((z_hi - z_lo) * K), int((x_hi - x_lo) * K)
im = Image.new("RGB", (W, H + 60), (36, 46, 60))
d = ImageDraw.Draw(im)


def px(x, z):
    return ((z - z_lo) * K, (x_hi - x) * K)


for p in parts:
    if p["k"] not in ("ground", "face", "grass") or not (z_lo < p["p"][2] < z_hi and x_lo < p["p"][0] < x_hi):
        continue
    sx, sz = p["s"][0], p["s"][2]
    cx, cz = px(p["p"][0], p["p"][2])
    hw, hh = max(1, sz * K / 2), max(1, sx * K / 2)
    col = tuple(p["c"]) if p["k"] == "ground" else ((120, 128, 140) if p["k"] == "face" else (90, 150, 90))
    d.rectangle([cx - hw, cz - hh, cx + hw, cz + hh], fill=col)

models = collections.defaultdict(list)
for p in parts:
    if p["k"] == "prop" and z_lo < p["p"][2] < z_hi:
        models[p["n"].rsplit("_", 1)[0]].append(p)
for name, bs in models.items():
    mx = sum(b["p"][0] for b in bs) / len(bs)
    mz = sum(b["p"][2] for b in bs) / len(bs)
    reach = max(math.hypot(b["p"][0] - mx, b["p"][2] - mz) + max(b["s"][0], b["s"][2]) / 2 for b in bs)
    vol = collections.Counter()
    for b in bs:
        vol[tuple(b["c"])] += b["s"][0] * b["s"][1] * b["s"][2]
    col = vol.most_common(1)[0][0]
    cx, cz = px(mx, mz)
    dressing = bs[0].get("g") == "dressing"
    r = max(1.2, reach * K) if not dressing else 1.4
    d.ellipse([cx - r, cz - r, cx + r, cz + r], fill=col, outline=None if dressing else (20, 20, 30))
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 18)
for land in path["Lands"]:
    if s0 <= land["S0"] <= s1:
        row = min(path["Path"], key=lambda p: abs(p[0] - land["S0"]))
        cx, _ = px(row[1], row[3])
        d.line([cx, 0, cx, H], fill=(255, 255, 255), width=2)
        d.text((cx + 6, 6), land.get("Name", ""), font=font, fill=(255, 255, 255))
d.text((10, H + 18), "Top down: floor in its colour, walls grey, grass tops green; each prop a dot in its colour sized by its reach, outlined; small dressing as specks", font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18), fill=(230, 230, 230))
im.save(out)
print(out, im.size)
