"""The coins and Oxygen rows, before and after, cut from two captures of the game and laid side by side.
    python tools/ui/rows_before_after.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "docs" / "attachments"
BOX = (0, 610, 440, 801)  # the lower left corner of an 801-high capture
ZOOM = 2

font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 22)
parts = [
    ("Before: a gold plate, and a glass box cut by the corner", "ui10-catch-banner.jpg"),
    ("After: two rows at the reference's place and size", "ui11-stat-rows.jpg"),
]
crops = []
for label, name in parts:
    im = Image.open(SHOTS / name).convert("RGB").crop(BOX)
    crops.append((label, im.resize((im.width * ZOOM, im.height * ZOOM), Image.LANCZOS)))
pad = 16
w = sum(c.width for _, c in crops) + pad * (len(crops) + 1)
h = crops[0][1].height + 44 + pad * 2
sheet = Image.new("RGB", (w, h), (24, 28, 38))
d = ImageDraw.Draw(sheet)
x = pad
for label, im in crops:
    d.text((x, pad), label, font=font, fill=(255, 226, 120))
    sheet.paste(im, (x, pad + 44))
    x += im.width + pad
out = SHOTS / "ui11-rows-before-after.jpg"
sheet.save(out, quality=92)
print(out, sheet.size)
