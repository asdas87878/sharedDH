"""The hub's scale against the reference's, from above, all at one scale (2026-11-22, the user: "the scale feels
wrong, whether it's in the actual scale of the hub or the texture, or it's just the walk speed"). Three plans:
ours as it stands (read from the place: art/map/hub_study/dump_2026-11-22.csv), the reference's (measured from our
frames: docs/reference/ride-a-dino-map.md, "The hub, measured", good to about 15%), and S, ours at the reference's
own size (236 by 193; theirs is about 230 by 180) with eight pens (50 by 60, sharing fences, in a U), checked: see
check() and tools/map/hub_s.py (the walls). Schematic: walls as a line, pens as boxes.

usage: python tools/map/hub_scale_plan.py [out.png]"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1] if __name__ == "__main__" and len(sys.argv) > 1 else os.path.join(ROOT, "docs", "attachments", "hub-scale-plans.png")
PX = 1.5  # pixels a stud
PANEL_W, PANEL_H = 460 * PX, 410 * PX
FLOOR, WALL, PEN, WATER, STRIP, OPEN, INK = (92, 160, 80), (40, 60, 40), (236, 222, 172), (150, 205, 225), (240, 230, 200), (255, 255, 255), (20, 24, 36)
try:
    FONT = ImageFont.truetype("arialbd.ttf", 16)
    SMALL = ImageFont.truetype("arial.ttf", 13)
except OSError:
    FONT = SMALL = ImageFont.load_default()


def panel(title, lines, hub, pens, strip, spawn, walks, open_box, tanks_tall=False, things=()):
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
    for tx, tz, tw, td, label, colour in things:
        d.rectangle([p(tx - tw / 2, tz + td / 2), p(tx + tw / 2, tz - td / 2)], fill=colour, outline=INK)
        if label:
            d.text((p(tx - tw / 2, tz + td / 2)[0] + 2, p(tx - tw / 2, tz + td / 2)[1] + 1), label, fill=(255, 255, 255), font=SMALL)
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


# ours, as read from the place (2026-11-22); z measured from the hub's front edge (the place's z = 0). Sizes are
# wall to wall: across, and from the strip's inner edge (z -32) to the back wall
RED, PURPLE, BLUE, TEAL, GOLD, GREY, PAD = (220, 70, 70), (160, 90, 220), (60, 100, 210), (40, 160, 170), (220, 160, 40), (90, 90, 110), (230, 90, 90)


def stations(sell, auras, fuse, index, sub, earners):
    return [(sell[0], sell[1], 29, 20, "Sell", RED), (auras[0], auras[1], 29, 20, "Auras", PURPLE),
            (fuse[0], fuse[1], 29, 41, "Fuse", BLUE), (index[0], index[1], 47, 18, "Index", GOLD),
            (sub[0], sub[1], 20, 29, "Sub", TEAL), (earners[0], earners[1], 26, 8, "", GREY)]


def trainers(points):
    return [(x, z, 12, 12, "", PAD) for x, z in points]


ours_tanks = [(-109, -57, -296, -212), (-52, 0, -296, -212), (6, 58, -296, -212), (65, 117, -296, -212),
              (-192, -108, -179, -127), (-192, -108, -115, -63), (108, 192, -188, -136), (108, 192, -125, -73)]
now = panel("Ours now: 400 x 280, tanks 52 x 84 and 34 tall",
            "spawn to the strip 67 | back tank to the strip 180 (6.4 s at 28)",
            (-200, 200, -312, 0), ours_tanks, (-48, 48, -32, 0), (1, -99), [((0, -212), (0, -32), "180")],
            (-108, 108, -212, -32), tanks_tall=True,
            things=stations((-26, -97), (34, -97), (5, -129), (-155, -48), (92, -54), (-92, -36))
            + trainers([(-71, -199), (-13, -199), (45, -199), (104, -199), (-95, -166), (-95, -102), (95, -149), (95, -86)]))
# the reference's: about 230 by 180 (measured, good to 15%); its pens' count and places are drawn, not measured
ref_pens = [(-100, -50, -210, -150), (-50, 0, -210, -150), (0, 50, -210, -150), (50, 100, -210, -150),
            (-115, -55, -150, -100), (55, 115, -150, -100)]
ref = panel("The reference: about 230 x 180, pens 50 x 60, fence 4 high",
            "own pen to the strip 110 (4 s at 28) | stalls 17-25 off the strip | pens drawn, not measured",
            (-115, 115, -210, 0), ref_pens, (-48, 48, -30, 0), (0, -100), [((-75, -150), (-20, -30), "110")],
            None)
GATE, REACH = 12, 8  # a gate's width, and the clear floor wanted in front of it


def check(name, hub, strip, pens, things, gates):
    """what a sketch must keep: nothing overlaps, all of it inside the hub and off the strip, every gate with REACH studs
    of clear floor in front. gates: (x, z, dx, dz) the gate's middle and the way out of the pen. Returns each gate's
    straight line to the strip's inner edge"""
    boxes = [("pen%d" % (i + 1), a, b, c, e) for i, (a, b, c, e) in enumerate(pens)]
    boxes += [("%s@%g,%g" % (t[4] or "pad/board", t[0], t[1]), t[0] - t[2] / 2, t[0] + t[2] / 2, t[1] - t[3] / 2, t[1] + t[3] / 2) for t in things]

    def hit(p_, q):
        return p_[1] < q[2] and q[1] < p_[2] and p_[3] < q[4] and q[3] < p_[4]

    bad = [(p_[0], q[0]) for i, p_ in enumerate(boxes) for q in boxes[i + 1:] if hit(p_, q)]
    sbox = ("strip",) + tuple(strip)
    bad += [(p_[0], "strip") for p_ in boxes if hit(p_, sbox)]
    bad += [(p_[0], "outside") for p_ in boxes if p_[1] < hub[0] or p_[2] > hub[1] or p_[3] < hub[2] or p_[4] > strip[2]]
    walks = []
    for i, (x, z, dx, dz) in enumerate(gates):
        ax, az = x + dx * REACH / 2, z + dz * REACH / 2
        hx, hz = (REACH / 2, GATE / 2) if dx else (GATE / 2, REACH / 2)
        lane = ("gate%d" % (i + 1), ax - hx, ax + hx, az - hz, az + hz)
        bad += [(lane[0], q[0]) for q in boxes if hit(lane, q)]
        walks.append(round(math.hypot(max(abs(x) - strip[1], 0), strip[2] - z)))
    print(name, "gates to the strip", walks, "BAD " + str(bad) if bad else "ok")
    return bad


# S: about the reference's own size, 236 by 193 from the strip's inner edge (z -32) to the back wall (z -225): theirs is
# 230 by 180, good to 15%. At 230 by 180 exactly the pens run into the round corners of the walls the generator builds
# (tools/map/hub_s.py checks that). Four pens on the back; two down each side, 50 into the hub and 60 along the wall,
# which leaves 15 studs of each back corner pen's front open: its gate is there
SZ = -10.0
s_pens = [(-100, -50, -212 + SZ, -152 + SZ), (-50, 0, -212 + SZ, -152 + SZ), (0, 50, -212 + SZ, -152 + SZ), (50, 100, -212 + SZ, -152 + SZ),
          (-115, -65, -152 + SZ, -92 + SZ), (-115, -65, -92 + SZ, -32 + SZ), (65, 115, -152 + SZ, -92 + SZ), (65, 115, -92 + SZ, -32 + SZ)]
s_gates = [(x, z + SZ, dx, dz) for x, z, dx, dz in
           [(-57.5, -152, 0, 1), (-25, -152, 0, 1), (25, -152, 0, 1), (57.5, -152, 0, 1),
            (-65, -122, 1, 0), (-65, -72, 1, 0), (65, -122, -1, 0), (65, -72, -1, 0)]]
# what stands on the floor is at the reference's size too (2026-11-23, the user: "the hub size still aint matched up"):
# theirs measured from run 6.0 s, 21 s and 39 s (ground.py): a stall 8.5 by 6.3 (posts) and about 9 high, its ring 11.5,
# the fuse machine 19 wide, a trainer's pad 5. Ours were 20 by 11 by 12.6, 16, 28.6 and 12. FIT scales a station in its
# own axes; the lighthouse and the earners board have nothing to measure against (theirs is a button and a wall board)
FIT = {"Sell": (0.64, 0.7, 0.5), "Auras": (0.64, 0.7, 0.5), "Sub": (0.5, 0.7, 0.64), "Fuse": (0.66, 0.66, 0.66),
       "Index": (0.5, 0.5, 0.5), "Earners": (0.6, 0.6, 0.6)}
PAD_SIZE, RING = 6, 11.5
s_things = [(-18, -54, 19, 12, "Sell", RED), (18, -54, 19, 12, "Auras", PURPLE), (16, -112, 19, 27, "Fuse", BLUE),
            (-20, -112, 24, 9, "Index", GOLD), (54, -48, 12, 19, "Sub", TEAL), (-55, -40, 16, 5, "", GREY)]
s_things += [(x, z + SZ, PAD_SIZE, PAD_SIZE, "", PAD) for x, z in
             [(-45, -147), (-12, -147), (12, -147), (45, -147), (-60, -106), (-60, -84), (60, -106), (60, -84)]]
S_TRY = {"HUB_HALF": 118, "HUB_BACK": -225, "CORNER": 12, "FRONT_TURN": 8, "GATE_TURN": 17}
assert not check("S", (-118, 118, -225, 0), (-48, 48, -32, 0), s_pens, s_things, s_gates)
r = panel("S (a sketch): 236 x 193, eight pens 50 x 60",
          "back gates to the strip 130 (4.6 s) | side gates 101 and 53 | clears the built walls",
          (-118, 118, -225, 0), s_pens, (-48, 48, -32, 0), (0, -88), [((-25, -162), (-25, -32), "130")],
          (-65, 65, -162, -32), things=s_things)
sheet = Image.new("RGB", (int(PANEL_W) * 3 + 20, int(PANEL_H)), (255, 255, 255))
for i, im in enumerate((now, ref, r)):
    sheet.paste(im, (i * (int(PANEL_W) + 10), 0))
if __name__ == "__main__":
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    sheet.save(OUT)
    print(OUT)
