"""The ten lands' looks on one sheet (docs/design/map-feel.md, docs/design/water.md): for each land its floor (and
wall tops), its wall face, how those look seen through that land's water near and far, the water's colour, how far you
see, and what lights it. The map's colours are what is built (tools/map/greybox.py); the water is tools/map/water_zones.py.
usage: python tools/map/zone_looks.py        writes docs/attachments/map-zone-looks.jpg"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from water_zones import GROUND, ZONES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def face_of(ground):
    return tuple(int(0.4 * g + 0.6 * 158) for g in ground)


def through(colour, zone, far):
    """a colour seen through this land's water: washed by its tint, then faded toward the water by distance"""
    washed = [c * t / 255.0 for c, t in zip(colour, zone["tint"])]
    return tuple(int(w + (f - w) * far) for w, f in zip(washed, zone["water"]))


font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 20)
small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
W, ROW = 1660, 78
im = Image.new("RGB", (W, 112 + ROW * len(ZONES)), (255, 248, 240))
d = ImageDraw.Draw(im)
d.text((14, 12), "The ten lands under water: bright, and each its own colour. The water is a proposal to play, not final.", font=big, fill=(30, 30, 30))
for x, text in [(200, "the water"), (350, "floor: near, middle, far"), (700, "wall: near, middle, far"), (1042, "view"), (1120, "lamps"), (1190, "what lights it")]:
    d.text((x, 64), text, font=font, fill=(60, 60, 60))
for k, (zone, ground) in enumerate(zip(ZONES, GROUND)):
    y = 102 + k * ROW
    d.text((14, y + 22), f"{k + 1} {zone['name']}", font=font, fill=(30, 30, 30))
    d.rectangle([200, y + 6, 330, y + ROW - 10], fill=zone["water"], outline=(40, 40, 40))
    for j, far in enumerate((0.0, zone["thick"] * 0.5, zone["thick"])):  # near, half way to "see", at "see"
        d.rectangle([350 + j * 110, y + 6, 350 + j * 110 + 104, y + ROW - 10], fill=through(ground, zone, far), outline=(40, 40, 40))
        d.rectangle([700 + j * 110, y + 6, 700 + j * 110 + 104, y + ROW - 10], fill=through(face_of(ground), zone, far), outline=(40, 40, 40))
    d.text((1042, y + 22), "wall" if zone["thick"] >= 1 else "veil", font=small, fill=(60, 60, 60))
    if zone["glow"]:
        d.ellipse([1126, y + 16, 1166, y + 56], fill=zone["glow"], outline=(40, 40, 40))
    d.text((1190, y + 22), zone["light"], font=small, fill=(30, 30, 30))
im.save(os.path.join(ROOT, "docs", "attachments", "map-zone-looks.jpg"), quality=90)
print("written")
