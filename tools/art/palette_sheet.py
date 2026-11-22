"""The colour study's comparison chart (docs/design/colour.md): for each of our lands, the reference land it copies
(measured, research/ride-a-dino/colour/summary.csv), ours as built, and the proposal (art/map/palettes/proposal.json),
each colour with its L* lightness, and the floor-to-wall lightness gap.
usage: python tools/art/palette_sheet.py [palette.json] [out.jpg]"""
import csv
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "map"))
import water_zones as wz  # noqa: E402

pal_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "art", "map", "palettes", "proposal.json")
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs", "attachments", "colour-palette-compare.jpg")
P = json.load(open(pal_path))["lands"]
ref = {}
summ = os.path.join(ROOT, "research", "ride-a-dino", "colour", "summary.csv")
if os.path.exists(summ):
    for r in csv.DictReader(open(summ)):
        ref[(r["land"], r["role"])] = r["hex"]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def lstar(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
    return 116 * y ** (1 / 3) - 16 if y > 0.008856 else 903.3 * y


REF_OF = {"Shallows": "Desert", "Coral Reef": "Jungle", "Kelp Forest": "Forest", "Shipwrecks": "Extinction", "Open Blue": "Abyss Ocean",
          "Twilight": "Snow", "Midnight": "Snow", "Vents": "Volcano", "Bone Graveyard": "Extinction", "The Underworld": "Cosmic"}
SW, SH = 92, 54
f = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 12)
fb = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15)
cols = [("reference", ["floor", "wall_face", "haze", "prop_main", "prop_accent"]), ("ours now", ["floor", "face", "water"]),
        ("proposed", ["floor", "face", "fog", "prop 1", "prop 2", "accent"])]
W = 170 + sum(len(c) * (SW + 4) + 70 for _, c in cols)
im = Image.new("RGB", (W, 80 + len(P) * (SH + 30)), (250, 246, 240))
d = ImageDraw.Draw(im)
d.text((10, 10), "Each land: the reference land it copies (measured), ours as built, and the proposal. Under each colour its L* lightness; 'gap' is floor to wall", font=fb, fill=(20, 20, 20))
x = 170
for title, roles in cols:
    d.text((x, 38), title, font=fb, fill=(40, 40, 40))
    for j, r in enumerate(roles):
        d.text((x + j * (SW + 4), 58), r.replace("_", " "), font=f, fill=(90, 90, 90))
    x += len(roles) * (SW + 4) + 70
for i, (land, z, g) in enumerate(zip(P, wz.ZONES, wz.GROUND)):
    y = 78 + i * (SH + 30)
    d.text((10, y + 8), land["name"], font=fb, fill=(20, 20, 20))
    d.text((10, y + 28), "copies " + REF_OF[land["name"]], font=f, fill=(90, 90, 90))
    now_face = tuple(int(0.4 * v + 0.6 * 158) for v in g)
    groups = [[ref.get((REF_OF[land["name"]], r)) for r in cols[0][1]],
              ["#%02x%02x%02x" % g, "#%02x%02x%02x" % now_face, "#%02x%02x%02x" % tuple(z["water"])],
              [land["floor"], land["face"], land["fog"]] + land["props"]]
    x = 170
    for gi, hexes in enumerate(groups):
        for j, h in enumerate(hexes):
            if h:
                c = rgb(h)
                d.rectangle([x + j * (SW + 4), y, x + j * (SW + 4) + SW, y + SH - 14], fill=c)
                d.text((x + j * (SW + 4) + 2, y + SH - 12), "L%d %s" % (lstar(c), h), font=f, fill=(40, 40, 40))
        if hexes[0] and hexes[1]:
            gap = abs(lstar(rgb(hexes[0])) - lstar(rgb(hexes[1])))
            d.text((x + len(hexes) * (SW + 4) + 4, y + 14), "gap %d" % gap, font=fb, fill=(160, 40, 40) if gap < 12 else (40, 120, 60))
        x += len(cols[gi][1]) * (SW + 4) + 70
im.save(out, quality=90)
print(out, im.size)
