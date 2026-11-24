"""Breakable props, second draft (2026-11-18, the user: "something close to B more like. Just study them better and
watch how they fall apart too, they get simplified"). From the reference, frame by frame (the 5-minute run, 146.0 to
148.9 s): a standing pine is tiers of many small studded cubes; when a herd hits it, the whole pine is gone in one
frame and in its place about eight big plain chunks fly, one to a tier or so, in the pine's two greens, a few with
studs on one face, some flat plates. They tumble, land at angles, lie, then fade.

So here: the standing prop is option B (bricks a third of a fish, tiers of blocks); the broken prop is its GROUPS (a
tier, a branch, the trunk) each turned into one chunk of about the group's bulk and main colour. Three frames per
prop: standing, the chunks in the air, the chunks lying.

usage: python tools/map/prop_drafts2.py                 writes art/map/prop_drafts/drafts2.json
       DRAFTS=drafts2 blender --background --python tools/blender/prop_drafts_view.py
       python tools/map/prop_drafts2.py --sheet          docs/attachments/map-prop-drafts-2.jpg"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop_drafts as d1  # noqa: E402
import props  # noqa: E402
from prop_drafts import PALETTES, tone  # noqa: E402

ROOT, OUT = d1.ROOT, d1.OUT


class Kit(d1.Kit):
    """bricks carry the group they break with: (name, centre, size, colour, axes, studs, group)"""

    def __init__(self):
        super().__init__()
        self.group = "base"

    def box(self, *a, **k):
        super().box(*a, **k)
        self.b[-1] = self.b[-1] + (self.group,)

    def beam(self, *a, **k):
        tip = super().beam(*a, **k)
        self.b[-1] = self.b[-1] + (self.group,)
        return tip


def staghorn(k, r, pal):
    k.group = "foot"
    for x, z in ((-4, -4), (4, -4), (-4, 4), (4, 4)):
        k.box(x * 1.1, 0, z * 1.1, 7.5, 5, 7.5, tone(pal, "Main", 0), yaw=r.uniform(-12, 12))
    k.box(0, 0, 0, 13, 2.5, 13, pal["Cap"], yaw=20)
    k.group = "trunk"
    tip = (0, 5, 0)
    for i in range(3):
        tip = k.beam(tip, 9 - i, 7, 9 - i, tone(pal, "Main", 0), roll=2)
    for j, (pitch, roll) in enumerate(((0, 62), (0, -60), (60, 4), (-58, -6), (40, 44), (-40, -44), (42, -40), (-40, 42))):
        k.group = f"branch{j}"
        mid = d1.chain(k, (tip[0], tip[1] - 2, tip[2]), 6.5, 3, 7.5, pitch, roll, 0, [tone(pal, "Main", 1)], bend=-14)
        end = d1.chain(k, mid, 5, 2, 6.5, pitch * 0.2, roll * 0.2, 0, [tone(pal, "Main", 2)], bend=-4)
        k.box(end[0], end[1] - 1, end[2], 5.5, 2.5, 5.5, pal["Pop"])


def rock_stack(k, r, pal):
    y = 0.0
    for i, (n_side, size, h) in enumerate(((4, 8, 9), (3, 8, 9), (2, 8, 9), (2, 6, 8), (1, 7, 7))):
        off = (n_side - 1) * size / 2
        for a in range(n_side):
            for b in range(n_side):
                if n_side > 2 and r.random() < 0.15:
                    continue
                k.group = f"tier{i}" + ("" if n_side < 3 else ("L" if a < n_side / 2 else "R"))  # a wide tier breaks in two
                hh = h * r.uniform(0.8, 1.15)
                k.box(a * size - off + r.uniform(-1, 1), y, b * size - off + r.uniform(-1, 1), size * r.uniform(0.92, 1.02), hh, size * r.uniform(0.92, 1.02),
                      tone(pal, "Stone", 0 if i < 2 else 1), yaw=r.uniform(-9, 9))
                if r.random() < 0.35 or i == 4:
                    k.box(a * size - off, y + hh, b * size - off, size * 0.8, 2, size * 0.8, pal["Cap"], yaw=r.uniform(-9, 9))
        y += h


def pagoda(k, r, pal):
    """the reference's pine, read for the sea: a stem of segments and five tiers of small studded blocks, each tier
    smaller, offset and turned; the bigger tiers hang a fringe of blocks at their edges (the leafy tree's droop)"""
    k.group = "stem"
    tip = (0, 0, 0)
    for i in range(5):  # up through the tiers, so none floats
        tip = k.beam(tip, 6.5 - i * 0.6, 9, 6.5 - i * 0.6, tone(pal, "Main", 0), studs=False)
    y = 10.0
    for i, (n_side, size, h) in enumerate(((3, 8, 5), (3, 7, 5), (2, 7, 5), (2, 6, 5), (1, 6, 6))):  # (4x4 tiers made 68 bricks: lighter, 2026-11-19)
        k.group = f"tier{i}"
        yaw = r.uniform(-15, 15)
        dx, dz = r.uniform(-1.5, 1.5), r.uniform(-1.5, 1.5)
        off = (n_side - 1) * size / 2
        for a in range(n_side):
            for b in range(n_side):
                p = props.turn((a * size - off, 0, b * size - off), yaw=yaw)
                k.box(p[0] + dx, y, p[2] + dz, size, h * r.uniform(0.9, 1.1), size, tone(pal, "Main" if "Soft" not in pal or i == 4 or (a + b + i) % 2 else "Soft", 2 if i == 4 else 1), yaw=yaw)
                edge = a in (0, n_side - 1) or b in (0, n_side - 1)
                if n_side >= 3 and edge and (a + b) % 2 == 0:  # the fringe
                    k.box(p[0] * 1.08 + dx, y - h * 0.7, p[2] * 1.08 + dz, size * 0.8, h * 0.8, size * 0.8, tone(pal, "Main", 1), yaw=yaw)
        y += h + 2.5
    k.box(dx, y - 2.5, dz, 3, 3, 3, pal["Pop"])


PROPS = [("staghorn coral", staghorn, "Reef orange"), ("pagoda coral", pagoda, "Reef pink"), ("rock stack", rock_stack, "Reef teal")]


def chunks(bs):
    """each group of bricks as one simplified chunk: its bulk as a cube (or a plate for a flat group), its main
    colour, at its middle"""
    groups = {}
    for n, p, s, c, ax, st, g in bs:
        e = groups.setdefault(g, {"v": 0.0, "m": [0.0, 0.0, 0.0], "col": {}, "lo": 1e9, "hi": -1e9})
        v = s[0] * s[1] * s[2]
        e["v"] += v
        for i in range(3):
            e["m"][i] += p[i] * v
        e["col"][c] = e["col"].get(c, 0) + v
        e["lo"], e["hi"] = min(e["lo"], p[1] - s[1] / 2), max(e["hi"], p[1] + s[1] / 2)
    out = []
    for g, e in groups.items():
        mid = [m / e["v"] for m in e["m"]]
        col = max(e["col"], key=e["col"].get)
        side = (e["v"] * 0.55) ** (1 / 3)
        flat = (e["hi"] - e["lo"]) < side * 0.8
        size = (side * 1.3, side * 0.45, side * 1.3) if flat else (side, side * 0.92, side * 1.04)
        out.append((g, mid, size, col))
    return out


def frames(bs, seed):
    """the chunks thrown along +x and outward and turning; then the same chunks lying on the floor further on"""
    r = random.Random(seed)
    air, lying = [], []
    for g, mid, size, col in chunks(bs):
        studs = r.random() < 0.5  # the reference's chunks: some studded, some plain
        side = r.uniform(-1, 1)
        q = (mid[0] + r.uniform(10, 26), mid[1] * 0.8 + r.uniform(4, 14), mid[2] + side * r.uniform(6, 16))
        ang = (r.uniform(-60, 60), r.uniform(-60, 60), r.uniform(-60, 60))
        air.append(("Chunk", q, size, col, tuple(props.turn(a, *ang) for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1))), studs))
        q = (mid[0] + r.uniform(26, 50), size[1] * 0.42, mid[2] + side * r.uniform(12, 26))
        tilt = (r.uniform(-14, 14), r.uniform(0, 90), r.uniform(-14, 14))
        lying.append(("Chunk", q, size, col, tuple(props.turn(a, *tilt) for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1))), studs))
    return air, lying


def js(bs):
    return [{"n": b[0], "p": [round(v, 2) for v in b[1]], "s": [round(v, 2) for v in b[2]], "c": list(b[3]), "ax": [[round(v, 4) for v in a] for a in b[4]], "studs": b[5]} for b in bs]


def write():
    shots, rows = [], []
    for i, (label, fn, palette) in enumerate(PROPS):
        k = Kit()
        fn(k, random.Random(5 + i), PALETTES[palette])
        bs = k.b
        air, lying = frames(bs, 21 + i)
        rows.append({"label": label, "bricks": len(bs), "chunks": len(air)})
        shots.append({"name": f"v2_{i}", "layout": [[js(bs), [-115, 0, 0]], [js(air), [-20, 0, 0]], [js(lying), [62, 0, 0]]],
                      "eye": [-30, 62, 470], "target": [-30, 24, 0], "fov": 40, "res": [1800, 620], "figure": [-175, 0, 18]})
    data = {"floor": d1.FLOOR, "shots": shots, "rows": rows}
    json.dump(data, open(os.path.join(OUT, "drafts2.json"), "w"))
    for r in rows:
        print(r)


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    data = json.load(open(os.path.join(OUT, "drafts2.json")))
    bold, plain = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 24), ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 19)
    w, h, pad = 1800, 620, 14
    out = Image.new("RGB", (w + 2 * pad, 64 + len(data["rows"]) * (h + 40 + pad)), (254, 248, 241))
    dr = ImageDraw.Draw(out)
    dr.text((pad, 16), "Breakable props, second draft: standing (B), the chunks in the air, the chunks lying: a hit swaps the prop for a few simple chunks", font=bold, fill=(30, 30, 30))
    y = 60
    for i, r in enumerate(data["rows"]):
        dr.text((pad, y), f"{r['label']}: {r['bricks']} bricks standing  ->  {r['chunks']} chunks when it breaks", font=plain, fill=(50, 50, 50))
        out.paste(Image.open(os.path.join(OUT, "renders", f"v2_{i}.png")).convert("RGB"), (pad, y + 32))
        y += h + 40 + pad
    path = os.path.join(ROOT, "docs", "attachments", "map-prop-drafts-2.jpg")
    out.save(path, quality=88)
    print(path)


if __name__ == "__main__":
    sheet() if "--sheet" in sys.argv else write()
