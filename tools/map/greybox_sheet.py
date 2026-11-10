"""Lays the grey-box renders (tools/blender/map_greybox_view.py) out as one picture for the vault.
usage: python tools/map/greybox_sheet.py   -> docs/attachments/map-greybox.jpg"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "map", "greybox", "renders")
VIEWS = [("hub", "1. In the hub, looking at the start: the floor is level with the water, the walls close the view"),
         ("aerial", "2. The hub and the start from above (the water drawn thin, so the lane shows)"),
         ("lane_above", "3. The first land from above: walls flush on the lane, in terraces, with open edges"),
         ("ride", "4. Under water in the Shallows, riding height"),
         ("open_edge", "5. Where the left wall stops: the lane's edge is open to the blue"),
         ("border", "6. A land border: a line of flags on a small step down"),
         ("big_slope", "7. The big drop after land 4, as a long steep slope")]


def font(size, bold=True):
    return ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf", size)


w, h, pad, cap, cols = 800, 450, 14, 32, 2
rows = (len(VIEWS) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w + (cols + 1) * pad, 50 + rows * (h + cap + pad)), (254, 248, 241))
d = ImageDraw.Draw(sheet)
d.text((pad, 12), "Map grey-box 1 (2026-11-10): the hub, four lands and the first big slope. Boxes only, rendered in Blender, not in Roblox.", font=font(21), fill=(30, 30, 30))
for k, (name, label) in enumerate(VIEWS):
    x, y = pad + (k % cols) * (w + pad), 50 + (k // cols) * (h + cap + pad)
    sheet.paste(Image.open(os.path.join(SRC, name + ".png")).convert("RGB").resize((w, h), Image.LANCZOS), (x, y))
    d.text((x + 2, y + h + 6), label, font=font(16), fill=(40, 40, 40))
out = os.path.join(ROOT, "docs", "attachments", "map-greybox.jpg")
sheet.save(out, quality=88)
print(out)
