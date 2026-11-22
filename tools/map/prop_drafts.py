"""Drafts for better breakable props (2026-11-18, the user: "draft up a few ways to make these collidable models
better ... studs, different colourways ... how many objects in one asset and how they're stacked"). Not the game's
props: tools/map/props.py stays as it is. This writes art/map/prop_drafts/drafts.json for
tools/blender/prop_drafts_view.py, which renders each option whole and in the middle of a hit, then
`python tools/map/prop_drafts.py --sheet` lays them out as docs/attachments/map-prop-drafts.jpg.

The options, on the same two props (a staghorn coral tree and a rock stack):
  now   the props as built: big boxes, one flat colour, no studs
  A     the same bricks, dressed: studs on coral and rock (not on trunks), tones by height, a land-colour cap
  B     rebuilt at fish scale: every brick about a third of a breaking fish's length (6 to 8 studs), tiers of
        blocks, segmented branches; a hit crumbles a tunnel and what stood on it falls
  C     a crumble band and a crown: small bricks only where fish swim (the floor to 40 studs up), the crown above
        in a few big pieces that tip over whole when the band under them goes (as the reference's pine does)
A brick is (name, centre, size, colour, axes, studs); colours come from a palette's slots so a colourway is a swap."""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "map", "prop_drafts")

# A land's palette for its props: slots, not colours, so one build takes any colourway. Main is the prop's own
# colour in three tones (dark at the foot, light at the tips, as the reference lightens its tops), Stone the neutral,
# Cap the land's ground colour on tops (the reference's desert rocks wear the land's olive), Pop a small accent.
PALETTES = {
    "Reef orange": {"Main": [(214, 104, 60), (246, 140, 82), (255, 188, 120)], "Stone": [(128, 132, 150), (160, 164, 180)], "Cap": (130, 214, 190), "Pop": (255, 236, 120)},
    "Reef pink": {"Main": [(200, 84, 120), (240, 122, 150), (255, 172, 190)], "Stone": [(128, 132, 150), (160, 164, 180)], "Cap": (130, 214, 190), "Pop": (255, 236, 120)},
    "Reef teal": {"Main": [(36, 140, 150), (62, 186, 186), (140, 230, 214)], "Stone": [(128, 132, 150), (160, 164, 180)], "Cap": (248, 222, 192), "Pop": (255, 150, 90)},
    "Twilight ice": {"Main": [(96, 90, 200), (150, 150, 240), (214, 226, 255)], "Stone": [(64, 60, 110), (92, 88, 148)], "Cap": (226, 236, 255), "Pop": (120, 255, 240)},
}
FLOOR = (244, 196, 170)


def tone(pal, slot, k):
    v = pal[slot]
    return v[max(0, min(len(v) - 1, k))] if isinstance(v, list) else v


class Kit(props.Kit):
    """props.Kit with a stud flag on each brick"""

    def box(self, x, y0, z, w, h, d, c, yaw=0.0, n="Brick", studs=True):
        super().box(x, y0, z, w, h, d, c, yaw, n)
        self.b[-1] = self.b[-1] + (studs,)

    def beam(self, foot, w, length, d, c, pitch=0.0, roll=0.0, yaw=0.0, n="Brick", studs=True):
        tip = super().beam(foot, w, length, d, c, pitch, roll, yaw, n)
        self.b[-1] = self.b[-1] + (studs,)
        return tip


# ---------------------------------------------------------------- the coral tree
def tree_now(k, r, pal):
    flat = tone(pal, "Main", 1)
    tip = k.beam((0, 0, 0), 11, 20, 11, props.darken(flat, 0.85), roll=3, studs=False)
    for pitch, roll in ((0, 36), (0, -34), (32, 4), (-30, -6)):
        t2 = k.beam((tip[0], tip[1] - 3, tip[2]), 7.5, 23, 7.5, flat, pitch=pitch, roll=roll, studs=False)
        for extra in (-24, 22):
            t3 = k.beam((t2[0], t2[1] - 2, t2[2]), 5, 14, 5, props.lighten(flat), pitch=pitch * 0.5 + (extra if pitch else 0), roll=roll * 0.5 + (0 if pitch else extra), studs=False)
            k.box(t3[0], t3[1] - 1, t3[2], 6, 3, 6, props.lighten(flat, 1.2, 30), studs=False)


def tree_a(k, r, pal):
    """the same bricks; tones by height (dark foot, light tips), studs on the coral, the land's colour at the foot"""
    k.box(0, 0, 0, 16, 3, 16, pal["Cap"], yaw=20)  # a patch of the land's colour it stands in
    tip = k.beam((0, 2.5, 0), 11, 20, 11, tone(pal, "Main", 0), roll=3)
    for pitch, roll in ((0, 36), (0, -34), (32, 4), (-30, -6)):
        t2 = k.beam((tip[0], tip[1] - 3, tip[2]), 7.5, 23, 7.5, tone(pal, "Main", 1), pitch=pitch, roll=roll)
        for extra in (-24, 22):
            t3 = k.beam((t2[0], t2[1] - 2, t2[2]), 5, 14, 5, tone(pal, "Main", 2), pitch=pitch * 0.5 + (extra if pitch else 0), roll=roll * 0.5 + (0 if pitch else extra))
            k.box(t3[0], t3[1] - 1, t3[2], 6, 3, 6, pal["Pop"])


def chain(k, foot, size, n, step, pitch, roll, yaw, colours, bend=0.0):
    """a branch as a row of separate segments, each a cube-ish block, bending a little each step"""
    for i in range(n):
        s = size * (1 - 0.09 * i)
        foot = k.beam(foot, s, step * (1 - 0.06 * i), s, colours[min(i * len(colours) // n, len(colours) - 1)], pitch=pitch + bend * i * (1 if pitch >= 0 else -1),
                      roll=roll + bend * i * (1 if roll >= 0 else -1), yaw=yaw)
    return foot


def tree_b(k, r, pal):
    """at fish scale: a stump of four blocks, a trunk of three segments, eight branches of segments, tips lit"""
    for x, z in ((-4, -4), (4, -4), (-4, 4), (4, 4)):  # the foot: four blocks splayed like roots
        k.box(x * 1.1, 0, z * 1.1, 7.5, 5, 7.5, tone(pal, "Main", 0), yaw=r.uniform(-12, 12))
    k.box(0, 0, 0, 13, 2.5, 13, pal["Cap"], yaw=20)
    tip = (0, 5, 0)
    for i in range(3):
        tip = k.beam(tip, 9 - i, 7, 9 - i, tone(pal, "Main", 0), roll=2)
    for pitch, roll in ((0, 62), (0, -60), (60, 4), (-58, -6), (40, 44), (-40, -44), (42, -40), (-40, 42)):
        mid = chain(k, (tip[0], tip[1] - 2, tip[2]), 6.5, 3, 7.5, pitch, roll, 0, [tone(pal, "Main", 1)], bend=-14)
        end = chain(k, mid, 5, 2, 6.5, pitch * 0.2, roll * 0.2, 0, [tone(pal, "Main", 2)], bend=-4)
        k.box(end[0], end[1] - 1, end[2], 5.5, 2.5, 5.5, pal["Pop"])


def tree_c(k, r, pal):
    """the band (floor to 40) in small blocks, the crown in three big pieces that tip over whole"""
    for x, z in ((-4, -4), (4, -4), (-4, 4), (4, 4)):
        k.box(x * 1.1, 0, z * 1.1, 7.5, 5, 7.5, tone(pal, "Main", 0), yaw=r.uniform(-12, 12))
    k.box(0, 0, 0, 13, 2.5, 13, pal["Cap"], yaw=20)
    tip = (0, 5, 0)
    for i in range(4):
        tip = k.beam(tip, 9 - i * 0.6, 7, 9 - i * 0.6, tone(pal, "Main", 0), roll=2)
    for pitch, roll in ((0, 40), (0, -38), (38, 4), (-36, -4)):  # low branches: in the band, segments
        chain(k, (tip[0], tip[1] - 6, tip[2]), 5.5, 3, 6.5, pitch, roll, 0, [tone(pal, "Main", 1), tone(pal, "Main", 2)], bend=-6)
    for pitch, roll, n in ((10, 16, "Crown"), (-12, -18, "Crown"), (0, 0, "Crown")):  # the crown: three big pieces
        t = k.beam((tip[0], tip[1] - 1, tip[2]), 9, 22, 9, tone(pal, "Main", 1), pitch=pitch, roll=roll, n=n)
        k.box(t[0], t[1] - 2, t[2], 15, 6, 15, tone(pal, "Main", 2), yaw=r.uniform(0, 40), n=n)
        k.box(t[0], t[1] + 4, t[2], 8, 3, 8, pal["Pop"], yaw=r.uniform(0, 40), n=n)


# ---------------------------------------------------------------- the rock stack
def rock_now(k, r, pal):
    y, yaw = 0.0, 20
    for i, (w, h, d) in enumerate(((30, 18, 26), (25, 16, 21), (19, 15, 17), (13, 12, 12))):
        k.box(r.uniform(-1.5, 1.5), y, r.uniform(-1.5, 1.5), w, h, d, tone(pal, "Stone", i % 2), yaw=yaw + r.uniform(-14, 14), studs=False)
        y += h
    k.box(0, y, 0, 15, 3.5, 14, pal["Cap"], yaw=yaw, studs=False)


def rock_a(k, r, pal):
    y, yaw = 0.0, 20
    for i, (w, h, d) in enumerate(((30, 18, 26), (25, 16, 21), (19, 15, 17), (13, 12, 12))):
        k.box(r.uniform(-1.5, 1.5), y, r.uniform(-1.5, 1.5), w, h, d, tone(pal, "Stone", 0 if i < 2 else 1), yaw=yaw + r.uniform(-14, 14))
        if i in (0, 2):  # a lip of the land's colour on some tiers, as the walls wear it
            k.box(r.uniform(-2, 2), y + h, r.uniform(-2, 2), w * 0.7, 2.5, d * 0.6, pal["Cap"], yaw=yaw + r.uniform(-14, 14))
        y += h
    k.box(0, y, 0, 15, 3.5, 14, pal["Cap"], yaw=yaw)


def rock_tiers(k, r, pal, tiers, y=0.0):
    for i, (n_side, size, h) in enumerate(tiers):
        off = (n_side - 1) * size / 2
        for a in range(n_side):
            for b in range(n_side):
                if n_side > 2 and r.random() < 0.15:
                    continue  # a gap: the stack is not a cube
                hh = h * r.uniform(0.8, 1.15)
                k.box(a * size - off + r.uniform(-1, 1), y, b * size - off + r.uniform(-1, 1), size * r.uniform(0.92, 1.02), hh, size * r.uniform(0.92, 1.02),
                      tone(pal, "Stone", 0 if i < len(tiers) - 1 else 1), yaw=r.uniform(-9, 9))
                if r.random() < 0.35 or i == len(tiers) - 1:
                    k.box(a * size - off, y + hh, b * size - off, size * 0.8, 2, size * 0.8, pal["Cap"], yaw=r.uniform(-9, 9))
        y += h
    return y


def rock_b(k, r, pal):
    """tiers of blocks a third of a fish across: 4x4, 3x3, 2x2, 1"""
    rock_tiers(k, r, pal, ((4, 8, 9), (3, 8, 9), (2, 8, 9), (2, 6, 8), (1, 7, 7)))


def rock_c(k, r, pal):
    """two tiers of small blocks in the band, then the top as two big blocks that tip over together"""
    y = rock_tiers(k, r, pal, ((4, 8, 9), (3, 8, 9), (3, 7, 9), (2, 8, 8)))
    k.box(0, y, 0, 18, 14, 16, tone(pal, "Stone", 1), yaw=12, n="Crown")
    k.box(1, y + 14, -1, 12, 10, 11, tone(pal, "Stone", 1), yaw=30, n="Crown")
    k.box(1, y + 24, -1, 13, 3, 12, pal["Cap"], yaw=30, n="Crown")


BUILD = {"now": (tree_now, rock_now), "A": (tree_a, rock_a), "B": (tree_b, rock_b), "C": (tree_c, rock_c)}
LABEL = {"now": "Now: big boxes, one flat colour, no studs", "A": "A. Dressed: the same bricks, studs, tones, a cap",
         "B": "B. Rebuilt at fish scale: bricks a third of a fish", "C": "C. Crumble band + a crown that tips over"}


def build(fn, seed, pal):
    k = Kit()
    fn(k, random.Random(seed), pal)
    return k.b


def hit(bs, seed, crown_tips=True):
    """the bricks after a breaking fish (20 long, 7 wide) swam through along +x, 12 studs up, plus Reach 5: what it
    touched is thrown, what stood on it falls; crown pieces tip over as one. Returns (whole, flying) brick lists."""
    r = random.Random(seed)
    band_lo, band_hi, half = 12 - 3.5 - 5, 12 + 3.5 + 5, 3.5 + 5
    out = set()
    for i, (n, p, s, c, ax, st) in enumerate(bs):
        ry = sum(abs(ax[j][1]) * s[j] / 2 for j in range(3))
        rz = sum(abs(ax[j][2]) * s[j] / 2 for j in range(3))
        if p[1] - ry < band_hi and p[1] + ry > band_lo and abs(p[2]) - rz < half and n != "Crown":
            out.add(i)
    # what rested on a thrown brick (above it, within its footprint) falls too, as the server's Topple rule
    for i, (n, p, s, c, ax, st) in enumerate(bs):
        if i in out or n == "Crown":
            continue
        for j in sorted(out):
            q = bs[j][1]
            if p[1] > q[1] and math.hypot(p[0] - q[0], p[2] - q[2]) < 8:
                out.add(i)
                break
    whole, flying = [], []
    crown = [b for b in bs if b[0] == "Crown"]
    crown_falls = crown_tips and bool(out)
    for i, b in enumerate(bs):
        n, p, s, c, ax, st = b
        if i in out:
            if r.random() < 0.45:  # some already lie on the floor beyond the prop
                q = (p[0] + r.uniform(14, 34), max(s[1], s[0]) * 0.35, p[2] + r.uniform(-12, 12))
                ang = (r.uniform(-10, 10), r.uniform(0, 90), r.uniform(-10, 10)) if r.random() < 0.6 else (90, r.uniform(0, 90), 0)
            else:  # the rest in the water, thrown along the fish's way and outward, turning
                q = (p[0] + r.uniform(8, 26), p[1] + r.uniform(2, 12), p[2] + r.uniform(-14, 14))
                ang = (r.uniform(-70, 70), r.uniform(-70, 70), r.uniform(-70, 70))
            flying.append((n, q, s, c, tuple(props.turn(a, *ang) for a in ax), st))
        elif n == "Crown" and crown_falls:
            pivot = (8, 0, 0)  # tips over whole, away from the fish, its foot dropped into the gap
            ang = 58
            rel = (p[0] - pivot[0], p[1] - 14, p[2])
            q = props.turn(rel, roll=-ang)
            flying.append((n, (pivot[0] + q[0] + 6, q[1] + 14, q[2]), s, c, tuple(props.turn(a, roll=-ang) for a in ax), st))
        else:
            whole.append(b)
    return whole, flying


def write():
    cells = []
    for col, key in enumerate(("now", "A", "B", "C")):
        for row, fn in enumerate(BUILD[key]):
            pal = PALETTES["Reef orange"] if row == 0 else PALETTES["Reef teal"]
            bs = build(fn, 3 + row, pal)
            whole, flying = hit(bs, 11 + row)
            cells.append({"key": key, "row": row, "count": len(bs), "out": len(flying), "intact": bs, "hit": whole + flying})
    # colourways: B's tree in the three reef palettes and a later land's
    ways = []
    for name in ("Reef orange", "Reef pink", "Reef teal", "Twilight ice"):
        ways.append({"name": name, "bricks": build(tree_b, 3, PALETTES[name])})

    def js(bs):
        return [{"n": n, "p": [round(v, 2) for v in p], "s": [round(v, 2) for v in s], "c": list(c), "ax": [[round(v, 4) for v in a] for a in ax], "studs": st} for n, p, s, c, ax, st in bs]

    os.makedirs(OUT, exist_ok=True)
    data = {"floor": FLOOR, "cells": [{**c, "intact": js(c["intact"]), "hit": js(c["hit"])} for c in cells],
            "ways": [{"name": w["name"], "bricks": js(w["bricks"])} for w in ways]}
    json.dump(data, open(os.path.join(OUT, "drafts.json"), "w"))
    for c in cells:
        print(c["key"], "tree" if c["row"] == 0 else "rock", c["count"], "bricks,", c["out"], "thrown or fallen in the hit")


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    data = json.load(open(os.path.join(OUT, "drafts.json")))
    R = os.path.join(OUT, "renders")
    bold, plain = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22), ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 17)
    w, h, pad = 800, 450, 12
    cols = ("now", "A", "B", "C")
    out = Image.new("RGB", (pad + 2 * (w + pad), 60 + len(cols) * (h + 34 + pad) + 40 + int(560 * (2 * w + pad) / 1800) + 20), (254, 248, 241))
    d = ImageDraw.Draw(out)
    d.text((pad, 14), "Breakable props, three ways (drafts, Blender): left whole, right just after a breaking fish swam through at 12 studs up", font=bold, fill=(30, 30, 30))
    y = 56
    for key in cols:
        cs = [c for c in data["cells"] if c["key"] == key]
        d.text((pad, y), LABEL[key] + f"   (tree {cs[0]['count']} bricks, {cs[0]['out']} out;  rock {cs[1]['count']} bricks, {cs[1]['out']} out)", font=bold, fill=(40, 40, 40))
        for i, c in enumerate(cs):
            im = Image.open(os.path.join(R, f"{key}_{c['row']}.png")).convert("RGB").resize((w, h))
            out.paste(im, (pad + i * (w + pad), y + 30))
        y += h + 34 + pad
    d.text((pad, y), "Colourways: option B's tree in three reef palettes and a later land's (Twilight ice): the same build, the palette's slots swapped", font=bold, fill=(40, 40, 40))
    im = Image.open(os.path.join(R, "ways.png")).convert("RGB")
    im = im.resize((2 * w + pad, int(im.height * (2 * w + pad) / im.width)))
    out.paste(im, (pad, y + 30))
    path = os.path.join(ROOT, "docs", "attachments", "map-prop-drafts.jpg")
    out.save(path, quality=88)
    print(path)


if __name__ == "__main__":
    sheet() if "--sheet" in sys.argv else write()
