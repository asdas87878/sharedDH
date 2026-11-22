"""The hub's scale against the reference's, from above, all at one scale (2026-11-22, the user: "the scale feels
wrong, whether it's in the actual scale of the hub or the texture, or it's just the walk speed"). Three plans:
ours as it stands (read from the place: art/map/hub_study/dump_2026-11-22.csv), the reference's (measured from our
frames: docs/reference/ride-a-dino-map.md, "The hub, measured", good to about 15%), and R, ours at the reference's
size with its pens (50 by 60, sharing fences, in a U). Schematic: walls as a line, pens as boxes.

usage: python tools/map/hub_scale_plan.py [out.png]"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "attachments", "hub-scale-plans.png")
PX = 1.5  # pixels a stud
PANEL_W, PANEL_H = 460 * PX, 410 * PX
FLOOR, WALL, PEN, WATER, STRIP, OPEN, INK = (92, 160, 80), (40, 60, 40), (236, 222, 172), (150, 205, 225), (240, 230, 200), (255, 255, 255), (20, 24, 36)
try:
    FONT = ImageFont.truetype("arialbd.ttf", 16)
    SMALL = ImageFont.truetype("arial.ttf", 13)
except OSError:
    FONT = SMALL = ImageFont.load_default()


def panel(title, lines, hub, pens, strip, spawn, walks, open_box, tanks_tall=False):
    """hub: (x0, x1, z0, z1) with the strip's edge at z1; pens: (x0, x1, z0, z1) boxes; walks: ((x, z), (x, z), label)"""
    im = Image.new("RGB", (int(PANEL_W), int(PANEL_H)), (236, 240, 244))
    d = ImageDraw.Draw(im)
    cx, top = PANEL_W / 2, 60

    def p(x, z):  # the lane (+z) up; z = 0 is the hub's front edge (the strip's far end)
        return cx + x * PX, top + (40 - z) * PX

    x0, x1, z0, z1 = hub
    d.rectangle([p(x0, z1), p(x1, z0)], fill=FLOOR, outline=WALL, width=4)
    if open_box:
        a, b, c, e = open_box
        d.rectangle([p(a, e), p(b, c)], outline=OPEN, width=2)
        d.text((p(a, e)[0] + 4, p(a, e)[1] + 3), f"open floor {b - a:.0f} x {e - c:.0f}", fill=OPEN, font=SMALL)
    for a, b, c, e in pens:
        d.rectangle([p(a, e), p(b, c)], fill=WATER if tanks_tall else PEN, outline=(110, 80, 50), width=2)
    sx0, sx1, sz0, sz1 = strip
    d.rectangle([p(sx0, sz1), p(sx1, sz0)], fill=STRIP, outline=(200, 190, 160))
    d.rectangle([p(-200, 40), p(200, sz1)], fill=(120, 180, 225))
    for (ax, az), (bx, bz), label in walks:
        d.line([p(ax, az), p(bx, bz)], fill=(230, 60, 60), width=3)
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        d.text((p(mx, mz)[0] + 6, p(mx, mz)[1] - 8), label, fill=(170, 30, 30), font=SMALL)
    sx, sz = spawn
    d.ellipse([p(sx, sz)[0] - 5, p(sx, sz)[1] - 5, p(sx, sz)[0] + 5, p(sx, sz)[1] + 5], fill=(255, 255, 255), outline=INK)
    # a 5-stud player and a 50-stud bar, for the eye
    d.rectangle([12, PANEL_H - 22, 12 + 50 * PX, PANEL_H - 16], fill=INK)
    d.text((16 + 50 * PX, PANEL_H - 27), "50 studs", fill=INK, font=SMALL)
    d.text((12, 8), title, fill=INK, font=FONT)
    for i, line in enumerate(lines):
        d.text((12, 30 + i * 0, ), "", fill=INK)
    d.text((12, 30), lines, fill=(60, 64, 80), font=SMALL)
    return im


# ours, as read from the place (2026-11-22); z measured from the hub's front edge (the place's z = 0)
ours_tanks = [(-109, -57, -296, -212), (-52, 0, -296, -212), (6, 58, -296, -212), (65, 117, -296, -212),
              (-192, -108, -179, -127), (-192, -108, -115, -63), (108, 192, -188, -136), (108, 192, -125, -73)]
now = panel("Ours now: 400 x 312, tanks 52 x 84 and 34 tall",
            "spawn to the strip 67 | back tank to the strip 180 (6.4 s at 28)",
            (-200, 200, -312, 0), ours_tanks, (-48, 48, -32, 0), (1, -99), [((0, -212), (0, -32), "180")],
            (-108, 108, -212, -32), tanks_tall=True)
# the reference's, measured: about 230 by 180, pens 50 by 60 in a U sharing fences, the strip 96 wide
ref_pens = [(-100, -50, -180, -120), (-50, 0, -180, -120), (0, 50, -180, -120), (50, 100, -180, -120),
            (-115, -55, -120, -70), (55, 115, -120, -70)]
ref = panel("The reference, measured: about 230 x 180, pens 50 x 60, fence 4 high",
            "own pen to the strip 110 (4 s at 28) | sell and auras 17-25 off the strip",
            (-115, 115, -180, 0), ref_pens, (-48, 48, -30, 0), (0, -100), [((-75, -120), (-20, -30), "110")],
            None)
# R: ours at the reference's size, eight pens of 50 by 60 in a U
r_pens = [(-100, -50, -200, -140), (-50, 0, -200, -140), (0, 50, -200, -140), (50, 100, -200, -140),
          (-122, -62, -140, -90), (-122, -62, -90, -40), (62, 122, -140, -90), (62, 122, -90, -40)]
r = panel("R: ours at the reference's size: 260 x 208, eight pens 50 x 60",
          "back pen to the strip 108 | side pens 10 to 60 | open floor about the reference's",
          (-130, 130, -208, 0), r_pens, (-48, 48, -32, 0), (0, -80), [((0, -140), (0, -32), "108")],
          (-62, 62, -140, -32))
sheet = Image.new("RGB", (int(PANEL_W) * 3 + 20, int(PANEL_H)), (255, 255, 255))
for i, im in enumerate((now, ref, r)):
    sheet.paste(im, (i * (int(PANEL_W) + 10), 0))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT)
print(OUT)
