"""The ten lands' looks on one sheet (docs/design/map-feel.md): for each land its floor (and wall tops), its wall face, its
two cliff layers going off into the haze, the water colour proposed for it, and what lights it. The first four columns
are what the map is built with now (tools/map/greybox.py); the water and the lights are proposals, not built.
usage: python tools/map/zone_looks.py        writes docs/attachments/map-zone-looks.jpg"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HAZE = (120, 175, 195)
GROUND = [(242, 214, 128), (244, 148, 152), (120, 172, 92), (160, 148, 124), (90, 124, 176),
          (104, 96, 170), (62, 66, 120), (120, 72, 64), (150, 150, 168), (110, 44, 60)]
# name, the water's colour there, how far you see (studs), what lights it, a glow colour
LANDS = [
    ("1 Shallows", (64, 200, 205), 1000, "full daylight; light rippling on the floor", None),
    ("2 Coral Reef", (40, 170, 200), 900, "daylight, softer; the corals are the colour", None),
    ("3 Kelp Forest", (50, 140, 110), 550, "green light in shafts between the kelp", (255, 230, 107)),
    ("4 Shipwrecks", (35, 105, 120), 500, "dim teal; lanterns on the wrecks", (255, 196, 110)),
    ("5 Open Blue", (20, 85, 170), 750, "one deep blue; you see far, with little to see", None),
    ("6 Twilight", (20, 30, 95), 420, "the sun is gone; glowing things begin", (95, 240, 224)),
    ("7 Midnight", (10, 14, 48), 300, "dark; lit ledges, lures, the herd's own glow", (95, 240, 224)),
    ("8 Vents", (38, 14, 16), 280, "orange from below: the vents light the walls", (255, 140, 60)),
    ("9 Bone Graveyard", (22, 30, 40), 300, "pale green glow on the bones", (170, 255, 190)),
    ("10 The Underworld", (28, 4, 8), 250, "red cracks in the floor and the walls", (255, 58, 42)),
]


def face_of(ground, pale=0.0):
    near = [0.4 * g + 0.6 * 158 for g in ground]
    return tuple(int(n + (h - n) * 0.6 * pale) for n, h in zip(near, HAZE))


def hazed(colour, share):
    return tuple(int(c + (h - c) * share) for c, h in zip(colour, HAZE))


font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 20)
small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
W, ROW = 1500, 74
im = Image.new("RGB", (W, 110 + ROW * len(LANDS)), (255, 248, 240))
d = ImageDraw.Draw(im)
d.text((14, 12), "The ten lands: what they are built in now, and the water and light proposed for each", font=big, fill=(30, 30, 30))
heads = [(190, "floor and tops"), (330, "wall face"), (470, "first cliff"), (610, "second cliff"), (770, "water (proposed)"), (960, "what lights it (proposed)")]
for x, text in heads:
    d.text((x, 62), text, font=font, fill=(60, 60, 60))
for k, ((name, water, far, light, glow), ground) in enumerate(zip(LANDS, GROUND)):
    y = 100 + k * ROW
    d.text((14, y + 20), name, font=font, fill=(30, 30, 30))
    chips = [ground, face_of(ground), face_of(ground, 0.35), face_of(ground, 0.7)]
    for i, c in enumerate(chips):
        d.rectangle([190 + i * 140, y + 6, 190 + i * 140 + 120, y + ROW - 10], fill=c, outline=(40, 40, 40))
    d.rectangle([770, y + 6, 890, y + ROW - 10], fill=water, outline=(40, 40, 40))
    d.text((900, y + 4), f"{far}", font=small, fill=(90, 90, 90))
    if glow:
        d.ellipse([904, y + 30, 934, y + 60], fill=glow, outline=(40, 40, 40))
    d.text((960, y + 20), light, font=small, fill=(30, 30, 30))
im.save(os.path.join(ROOT, "docs", "attachments", "map-zone-looks.jpg"), quality=90)
print("written")
