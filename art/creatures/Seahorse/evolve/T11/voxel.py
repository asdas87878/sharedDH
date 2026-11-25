"""Seahorse rocker, level 11 "Starfire" (docs/style/13-seahorse-evolution.md): a three-headed hydra. A near-black trunk with a
furnace in its chest; a middle neck that rises and leads, roaring; two side necks spread out low and forward, one biting, one
turned out; four wings of dark boards whose ragged lower edges burn; two clawed forelimbs; seven cyan crystals rooted in the
back; two curled tails, each ending in a four-pointed star. The seahorse's marks: rings on the necks and the tails, a crest on
every head and down every neck, cheek fins, the curl. Four values keep the shapes apart: "body" (near black), "armour" (mid
purple plate), "edge" (light violet lips and rings), "ivory"; the lit colours are "lava" and "hot" (orange) and "ice" (cyan)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 11
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
PALETTE.update({"edge": "#9470DC", "lava": "#FF6A2A", "hot": "#FFB050", "ice": "#56E8FF", "armour": "#55378A", "deep": "#2C9CC8"})
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW = dict(c.glow_of(LEVEL), lava=0.75, hot=0.9, ice=0.75)
LIGHTS = []
FLOATING = ["Coil"]
SWING = 6
SEAT = (4, 59.6, 5)

TS, BS = [(6, 2), (3, 2), (1, 3)], [(5, 2), (2, 3)]
# the trunk: (from, to, cubes out, bottom, top, its top steps, its bottom steps)
TRUNK = ((-20, -14, 12, 30, 53, [(3, 2), (1, 2)], [(3, 2), (1, 2)]),
         (-14, 0, 16, 28, 58, TS, BS),
         (0, 11, 15, 28, 54, [(5, 2), (2, 2)], BS),
         (11, 18, 14, 29, 57, TS, [(4, 2), (2, 2)]),
         (18, 23, 11, 31, 53, [(4, 2), (2, 2)], [(3, 2), (1, 2)]))
# the necks: points, sizes, the way to their backs, then the head: where, yaw (out), pitch (nose up), roll, the jaw's angle
NECKS = {
    "": dict(points=((-11.5, 0, 48), (-18, 0, 65), (-22.5, 0, 77), (-25, 0, 88)), sizes=(15, 13.4, 11.8), back=(0.8, 0, 0.6),
             head=(-26, 0, 90), yaw=0, pitch=3, roll=0, jaw=36),
    "R": dict(points=((-7, 8, 45.5), (-17, 18, 44.5), (-26, 25, 47.5), (-33, 28, 55)), sizes=(14.6, 13, 11.4), back=(0.3, 0, 1),
              head=(-35, 28, 57.5), yaw=5, pitch=-4, roll=0, jaw=18),
    "L": dict(points=((-7, -8, 46), (-12, -20, 44), (-15.5, -28.5, 43.5), (-18.5, -34, 44.5)), sizes=(14.6, 13.4, 10.8), back=(0.3, 0, 1),
              head=(-19, -34.3, 45.5), yaw=-20, pitch=-6, roll=0, jaw=27),
}
TAIL_SIZE = (13, 11.7, 10.4, 9.1, 7.9, 6.7, 5.5, 4.3)
TAIL_LONG = (11.5, 9.5, 9, 8.5, 8, 7.5, 7, 6)
TAIL_TURN = (-50, -41, -22, 10, 50, 92, 134, 172)
TAIL_OUT = 32


# ---------------------------------------------------------------- small geometry
def add(a, b, k=1.0):
    return tuple(i + k * j for i, j in zip(a, b))


def sub(a, b):
    return tuple(i - j for i, j in zip(a, b))


def neg(a):
    return tuple(-i for i in a)


def dot(a, b):
    return sum(i * j for i, j in zip(a, b))


def unit(a):
    n = math.sqrt(dot(a, a))
    return tuple(i / n for i in a)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def mix(a, b, t):
    return tuple(i + (j - i) * t for i, j in zip(a, b))


def axes(a, b, ref):
    """along a to b, across, and the way nearest `ref`"""
    d = unit(sub(b, a))
    thin = unit(add(ref, d, -dot(ref, d)))
    return d, cross(thin, d), thin


def bar(p, a, b, wide, thick, colour, ref=(0, 1, 0), mirror=False):
    """a whole box from a to b, `thick` along ref, `wide` across"""
    d, w, t = axes(a, b, ref)
    p._oriented(mix(a, b, 0.5), d, w, t, (math.dist(a, b), wide, thick), colour, mirror)


def point(p, a, b, wide, thick, colour, ref=(0, 1, 0), mirror=False):
    """a pyramid from a base at a (`wide` across, `thick` along ref) to its apex b"""
    d, w, t = axes(a, b, ref)
    base = [add(add(a, w, i * wide / 2), t, j * thick / 2) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    p.spike(base, b, colour, mirror)


class Frame:
    """a place and an angle: `a` runs forward along the nose, `w` out to +y, `h` up"""

    def __init__(self, o, yaw=0.0, pitch=0.0, roll=0.0):
        q, e, r = (math.radians(v) for v in (yaw, pitch, roll))
        self.o = o
        self.d = (-math.cos(q) * math.cos(e), math.sin(q) * math.cos(e), math.sin(e))
        n = (math.cos(q) * math.sin(e), -math.sin(q) * math.sin(e), math.cos(e))
        w = (math.sin(q), math.cos(q), 0.0)
        self.n = add(tuple(v * math.cos(r) for v in n), w, math.sin(r))
        self.w = add(tuple(v * math.cos(r) for v in w), n, -math.sin(r))

    def at(self, a, w, h):
        return add(add(add(self.o, self.d, a), self.w, w), self.n, h)

    def way(self, a, w, h):
        return add(add(tuple(v * a for v in self.d), self.w, w), self.n, h)

    def tipped(self, a, h, angle):
        """the same frame moved to (a, 0, h) and tipped nose up by `angle`"""
        f = Frame.__new__(Frame)
        e = math.radians(angle)
        f.o, f.w = self.at(a, 0, h), self.w
        f.d, f.n = self.way(math.cos(e), 0, math.sin(e)), self.way(-math.sin(e), 0, math.cos(e))
        return f

    def box(self, p, a, w, h, colour, tip=0.0, turn=0.0):
        """a whole box: a, w, h = (from, to); tipped nose up and turned out about its own middle. If w does not straddle the
        middle it is made on both sides"""
        mid = [(v[0] + v[1]) / 2 for v in (a, w, h)]
        size = (a[1] - a[0], w[1] - w[0], h[1] - h[0])
        e, q = math.radians(tip), math.radians(turn)
        for s in ((1, -1) if abs(mid[1]) > 1e-6 else (1,)):
            d = (math.cos(e) * math.cos(q), s * math.sin(q), math.sin(e) * math.cos(q))
            n = (-math.sin(e), 0.0, math.cos(e))
            across = cross(n, d)
            p._oriented(self.at(mid[0], s * mid[1], mid[2]), self.way(*d), self.way(*across), self.way(*n), size, colour, False)

    def pairs(self, a, b, ref):
        for s in ((1, -1) if abs(a[1]) + abs(b[1]) > 1e-6 else (1,)):
            m = (1, s, 1)
            yield (self.at(*(i * j for i, j in zip(a, m))), self.at(*(i * j for i, j in zip(b, m))),
                   self.way(*(i * j for i, j in zip(ref, m))))

    def bar(self, p, a, b, wide, thick, colour, ref=(0, 0, 1)):
        for a1, b1, r1 in self.pairs(a, b, ref):
            bar(p, a1, b1, wide, thick, colour, r1)

    def point(self, p, a, b, wide, thick, colour, ref=(0, 0, 1)):
        for a1, b1, r1 in self.pairs(a, b, ref):
            point(p, a1, b1, wide, thick, colour, r1)

    def tooth(self, p, a, w, h, size, length, colour="ivory", lean=0.3):
        """a pyramid tooth: its base flat at height h, its point `length` up (negative: down), leaning forward; both sides"""
        for s in ((1, -1) if abs(w) > 1e-6 else (1,)):
            k = size / 2
            base = [self.at(a + i * k, s * w + j * 0.6, h) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            p.spike(base, self.at(a + lean, s * w, h + length), colour)


# ---------------------------------------------------------------- a head, at a place and an angle
def horn(f, p, base, steps, colours):
    """a horn of boxes, each thinner and bending on, and a point: steps of (way, length, thickness)"""
    at, last = base, None
    for k, (way, length, thick) in enumerate(steps):
        way = unit(way)
        start = at if last is None else add(at, way, -0.35 * last)
        end = add(at, way, length)
        if k < len(steps) - 1:
            f.bar(p, start, end, thick, thick, colours[k], (0.2, 0, 1))
        else:
            f.point(p, start, end, thick, thick, colours[k], (0.2, 0, 1))
        at, last = end, thick


def head(m, tag, spec):
    f = Frame(spec["head"], spec["yaw"], spec["pitch"], spec["roll"])
    p = m.part("Head" + tag, spec["points"][-1], "Neck" + tag)
    gape = spec["jaw"]
    # the skull, its jowls, the snout in two turned blocks and a beak
    f.box(p, (-5, 10.4), (-6.6, 6.6), (-3.2, 5.9), "armour")
    f.box(p, (-4.2, 7.6), (-4.7, 4.7), (5.3, 7.3), "armour")
    f.box(p, (-2.5, 7.4), (4.6, 7.9), (-6.6, 1.2), "body", turn=-5)
    f.box(p, (8.2, 19.0), (-5.2, 5.2), (-2.6, 3.9), "armour", tip=-8)
    f.box(p, (17.2, 24.2), (-4.2, 4.2), (-3.2, 1.6), "armour", tip=-5)
    f.box(p, (21.2, 25.0), (-3.1, 3.1), (-3.0, 0.8), "armour+", tip=-12)
    f.box(p, (24.25, 25.65), (1.2, 2.7), (-0.75, -0.05), "body", tip=-12)  # the nostrils, and the lip under the nose
    f.box(p, (22.4, 23.9), (-3.3, 3.3), (-4.2, -2.4), "body")
    f.box(p, (8.9, 18.6), (-1.7, 1.7), (2.9, 4.7), "edge", tip=-8)  # the ridge down the snout, and the nose's horn
    f.point(p, (21.0, 0, 0.6), (21.6, 0, 6.2), 3.4, 2.6, "edge", (0, 1, 0))
    # the lips: a dark edge the teeth stand in; the lit palate between them
    f.box(p, (5.0, 18.6), (3.5, 5.0), (-4.2, -2.1), "body")
    f.box(p, (17.4, 23.6), (2.6, 4.0), (-4.45, -2.3), "body")
    f.box(p, (3.0, 18.5), (-3.6, 3.6), (-3.8, -2.2), "lava")
    f.box(p, (17.6, 22.8), (-2.7, 2.7), (-4.0, -2.3), "lava")
    for a, w, size, length in ((7.9, 4.25, 2.2, 2.8), (10.4, 4.25, 2.6, 4.4), (13.4, 4.25, 2.4, 3.0), (16.4, 4.25, 2.8, 4.8),
                               (19.4, 3.3, 2.2, 3.0), (22.1, 3.3, 2.6, 5.6)):
        f.tooth(p, a, w, -3.9, size, -length)
    # the eye: a cyan slit in a dark socket under a heavy brow
    f.box(p, (4.4, 11.0), (4.9, 7.2), (0.7, 5.1), "body", turn=-22)
    f.box(p, (5.4, 11.3), (5.7, 7.5), (1.6, 3.7), "ice", tip=-14, turn=-22)
    f.box(p, (2.6, 13.2), (4.2, 8.3), (3.9, 6.3), "edge", tip=-15, turn=-14)
    # the horns, the crest and the cheek fins
    horn(f, p, (1.8, 3.7, 3.4), (((-0.5, 0.45, 0.75), 8.0, 4.6), ((-0.9, 0.35, 0.45), 6.4, 3.5), ((-1, 0.1, 0.3), 7.4, 2.7)),
         ("edge", "ivory", "ivory"))
    horn(f, p, (4.0, 0, 6.0), (((-0.35, 0, 1), 5.2, 4.2), ((-0.8, 0, 0.6), 4.8, 3.2), ((-1, 0, 0.3), 6.4, 2.4)),
         ("edge", "ivory", "ivory"))
    for way, length, wide, thick in (((-0.75, 0.66, 0.1), 10.5, 5.0, 1.6),):
        way, root = unit(way), (0.5, 6.4, -1.8)
        f.bar(p, root, add(root, way, length), wide, thick, "fin", (0.6, 0.8, 0))
        f.bar(p, add(root, way, length - 3.2), add(root, way, length + 1.6), wide - 0.9, thick - 0.4, "edge", (0.6, 0.8, 0))
    # the throat, lit, and the sinew at the mouth's corner
    hinge = (4.2, -4.0)
    t = f.tipped(hinge[0], hinge[1], -gape / 2)
    gap = 2 * math.tan(math.radians(gape / 2))
    t.box(p, (-1.0, 5.0), (-4.05, 4.05), (-gap * 2.6 - 0.6, gap * 2.6 + 0.6), "hot")
    t.box(p, (-0.9, 4.2), (4.5, 5.35), (-gap * 2.2 - 0.9, gap * 2.2 + 0.9), "body")

    # the jaw, on its own joint at the mouth's corner
    j = f.tipped(hinge[0], hinge[1], -gape)
    jaw = m.part("Jaw" + tag, f.at(hinge[0], 0, hinge[1]), "Head" + tag)
    j.box(jaw, (-3.4, 6.0), (-5.6, 5.6), (-4.4, 0.6), "body")
    j.box(jaw, (3.0, 15.2), (-5.0, 5.0), (-4.0, -0.7), "armour")
    j.box(jaw, (12.8, 20.4), (-4.1, 4.1), (-3.5, 0.0), "armour", tip=6)
    j.box(jaw, (17.4, 21.4), (-3.0, 3.0), (-2.7, -0.2), "armour+", tip=14)
    j.box(jaw, (5.4, 15.0), (3.3, 4.8), (-1.8, 0.0), "body")
    j.box(jaw, (14.0, 19.6), (2.5, 3.9), (-1.3, 0.75), "body", tip=6)
    j.box(jaw, (4.0, 15.2), (-3.4, 3.4), (-1.4, -0.3), "lava")
    j.box(jaw, (14.4, 18.8), (-2.6, 2.6), (-1.4, 0.3), "lava", tip=6)
    for a, w, size, length in ((7.4, 4.05, 2.2, 2.6), (10.2, 4.05, 2.4, 3.8), (13.2, 4.05, 2.2, 2.8)):
        j.tooth(jaw, a, w, -0.3, size, length)
    for a, size, length in ((15.9, 2.2, 3.6), (18.4, 2.0, 4.8)):
        j.tooth(jaw, a, 3.2, 0.1, size, length)
    j.point(jaw, (13.0, 0, -2.6), (9.0, 0, -9.4), 4.0, 2.2, "edge", (0, 1, 0))  # the beard


def neck(m, tag, spec):
    """three blocks, a ring over each joint, plates down the back with a crest on them, a lit stripe down the front"""
    pts, sizes, back = spec["points"], spec["sizes"], spec["back"]
    p = m.part("Neck" + tag, add(pts[0], unit(sub(pts[1], pts[0])), 8), "Body")
    for k, size in enumerate(sizes):
        a, b = pts[k], pts[k + 1]
        d, w, t = axes(a, b, back)
        end = add(b, d, 0.4 * sizes[k + 1] if k < 2 else 1.5)
        start = a if k == 0 else add(a, d, -0.3 * size)
        bar(p, start, end, size, size, "body", back)
        ring = size + 1.3
        if k < 2:
            bar(p, add(end, d, -2.2), add(end, d, 0.35), ring, ring, "edge", back)
        if k == 0 and not tag:  # a heavy collar where it leaves the trunk
            mid = add(a, d, 11.0)
            bar(p, add(mid, d, -1.8), add(mid, d, 1.2), ring + 1.0, ring + 1.0, "armour", back)
        # the plates down the back: a wide one, lower, and a narrower one over it
        lo, hi = (0.62, 0.95) if k == 0 else (0.0, 0.98)
        for n, (u0, u1) in enumerate(((lo, hi),) if tag else ((lo, lo + (hi - lo) * 0.56), (lo + (hi - lo) * 0.46, hi))):
            q0, q1 = mix(a, b, u0), mix(a, b, u1)
            wide = size - 2.2 - 0.5 * n - 0.15 * k
            lift = size / 2 + 0.6 * n + (0.2 if k == 1 else 0)
            bar(p, add(q0, t, lift), add(q1, t, lift), wide, 2.0, "armour" if n == 0 else "armour+", back)
        # the crest: a finned blade on the plates
        if k > 0:
            q = add(mix(a, b, 0.5 if k else 0.8), t, size / 2)
            way = unit(add(t, d, 0.55))
            bar(p, q, add(q, way, 5.2 - 0.4 * k), 4.4 - 0.4 * k, 1.8 - 0.2 * k, "armour", w)
            far = add(q, way, 5.2 - 0.4 * k)
            way2 = unit(add(t, d, 0.15))
            point(p, add(far, way2, -1.6), add(far, way2, 3.8), 3.4 - 0.4 * k, 1.3 - 0.2 * k, "edge", w)
        # the stripe: one lit run standing in dark sides: down the middle neck's throat, along the front of a side neck
        face = t if not tag else w if w[0] > 0 else neg(w)
        front = size / 2 - 0.1
        q0 = add(a, d, 9.6) if k == 0 else add(a, d, 0.3)
        q1 = add(b, d, 0.6)
        bar(p, add(q0, face, -front), add(q1, face, -front), 5.0 - 0.4 * k, 1.8 if tag and k == 1 else 2.2, "lava", face)
    return p


# ---------------------------------------------------------------- the trunk and what stands on it
def trunk(body):
    for x0, x1, n, bot, top, ts, bs in TRUNK:
        body.hull(x0, x1, n, bot, top, "body", ts, bs)
        body.paint_sym(x0, x1, n, bot, bot + 4, "belly")
    # the furnace: a lit hole in the chest, in a plated rim, with bars
    body.carve(-20, -18, -8, 9, 33, 50)
    body.paint(-18, -17, -8, 9, 33, 50, "lava")
    body.paint(-18, -17, -5, 6, 34, 45, "hot")
    rim = (8.7, 10.9, 32.2, 50.6)
    body.block(-21.6, rim, -19.3, rim, "armour", mirror=True)
    for z0, z1 in ((50.2, 52.6), (30.2, 32.8)):
        body.block(-21.9, (-9.3, 9.3, z0, z1), -19.5, (-9.3, 9.3, z0, z1), "edge")
    body.block(-20.7, (3.2, 4.8, 31.6, 50.6), -19.1, (3.2, 4.8, 31.6, 50.6), "body", mirror=True)
    body.block(-21.1, (-9.0, 9.0, 40.2, 41.8), -19.5, (-9.0, 9.0, 40.2, 41.8), "body")
    # the armour: pauldrons over the shoulders, a shell over each flank, a crupper over the haunch
    body.beam((-5.5, 6.4, 59.4), (-5.5, 17.6, 51.8), 12.0, 3.4, "armour", flat="z", mirror=True)
    body.beam((-5.5, 15.0, 52.6), (-5.5, 18.9, 43.0), 9.6, 2.2, "armour+", flat="y", mirror=True)
    body.beam((-5.5, 18.2, 44.6), (-5.5, 18.8, 42.2), 10.2, 2.9, "edge", flat="y", mirror=True)
    body.beam((-5.5, 6.0, 59.8), (-5.5, 8.0, 58.45), 12.5, 4.2, "edge", flat="z", mirror=True)
    for (x0, x1, n, bot, top, ts, bs), b0, b1 in ((TRUNK[2], 8.2, 10.6), (TRUNK[3], 11.6, 14.2)):
        body.band(b0, b1, n, bot, top, "armour", ts, bs, proud=0.5, stop=34)
    for x in (1, 5):  # vents in the flanks, lit from the furnace
        body.dent(x, x + 2, 15, 34, 42, "lava", depth=0.6)
    body.beam((14.6, 10.0, 56.4), (15.4, 17.0, 44.2), 7.0, 3.4, "armour", flat="y", mirror=True)
    body.beam((15.3, 16.1, 45.8), (15.5, 17.2, 42.8), 7.6, 4.0, "edge", flat="y", mirror=True)


def tack(body):
    body.block(0.5, (-7.4, 7.4, 52.8, 55.6), 10.4, (-7.4, 7.4, 52.8, 55.6), "wing")  # the blanket: dark, an orange hem, a crystal
    body.beam((5.4, 6.6, 54.2), (5.4, 16.9, 49.2), 9.0, 2.4, "wing", flat="z", mirror=True)
    body.beam((5.4, 15.9, 50.4), (5.4, 16.5, 44.4), 9.4, 2.4, "wing", flat="y", mirror=True)
    body.beam((5.4, 16.2, 46.8), (5.4, 16.6, 44.0), 9.9, 3.2, "ring", flat="y", mirror=True)
    for wide, thick, y, colour in ((4.4, 2.4, 17.2, "armour"), (2.9, 2.7, 17.75, "ice")):
        body._oriented((4.6, y, 49.0), (0.7071, 0, 0.7071), (0.7071, 0, -0.7071), (0, 1, 0), (wide, wide, thick), colour, True)
    body.block(1.2, (-6.0, 6.0, 54.2, 57.2), 8.6, (-6.0, 6.0, 54.2, 57.2), "armour")
    body.block(1.6, (-5.2, 5.2, 56.6, 59.6), 8.2, (-5.2, 5.2, 56.6, 59.6), "saddle+")
    body.beam((1.6, 0, 57.8), (-0.6, 0, 62.0), 2.4, 7.0, "armour")
    body.beam((-0.2, 0, 61.0), (-0.8, 0, 62.5), 3.0, 7.6, "edge")
    body.beam((8.0, 0, 57.4), (10.0, 0, 64.0), 2.4, 10.0, "armour")
    body.beam((9.6, 0, 62.8), (10.2, 0, 65.0), 3.0, 10.7, "edge")


def crystals(body):
    """seven, each rooted in a socket; the middle one short so the rider is seen over it"""
    for base, tip, size, mirror in (((-10.5, 9.5, 54.5), (-13.5, 14.0, 68.5), 4.2, True), ((15.8, 6.6, 54.5), (22.5, 9.0, 72.0), 4.8, True),
                                    ((19.6, 5.6, 50.5), (28.0, 6.8, 63.0), 4.0, True), ((20.6, 0, 50.5), (27.5, 0, 57.5), 3.4, False)):
        d = unit(sub(tip, base))
        long = math.dist(base, tip)
        ref = (0, 1, 0)
        bar(body, add(base, d, 0.8), add(base, d, 3.6), size + 1.8, size + 1.8, "armour", ref, mirror)
        bar(body, add(base, d, 1.4), add(base, d, long * 0.6), size, size, "deep", ref, mirror)
        point(body, add(base, d, long * 0.5), tip, size - 0.5, size - 0.5, "ice", ref, mirror)


# ---------------------------------------------------------------- wings, limbs, tails
# a wing: the shoulder (x, y, z), then the elbow the outer wing hangs from, its plane's sweep and lean; the rest is drawn in the
# front view (y, z) on that plane: the wrist, then the tips its trailing edge runs through (the last one is in the trunk)
WING = dict(shoulder=(8.5, 10.5, 47), elbow=(11, 17.5, 66), sweep=0.68, lean=0.05, wrist=(21, 84), arm=(7.0, 5.8), bone=2.3, edge=2.6,
            claw=8.0, tips=((34.5, 93.5), (43.0, 77), (38.5, 56), (25, 44.5), (12.5, 41.5)), deep=(15.5, 25.5, 16.5, 10.5),
            thick=(1.6, 2.2, 1.6, 2.1))
WING2 = dict(shoulder=(16.5, 8.5, 44), elbow=(21, 15.5, 52), sweep=0.65, lean=0.05, wrist=(20.5, 61), arm=(5.6, 5.0), bone=1.9, edge=2.2,
             claw=5.6, tips=((33.0, 62.5), (33.0, 48), (23.5, 35.5), (9.5, 36)), deep=(12.0, 14.0, 9.0), thick=(1.4, 1.9, 1.3))


def wing(m, name, s, W):
    """a wing: an upper arm out of the trunk, a forearm up to the wrist, long fingers down to the trailing edge, a whole turned
    panel between two fingers, along each panel's end one lit beam, and a knuckle with an ivory claw where two beams meet"""
    normal = unit((-1.0, W["sweep"], W["lean"]))  # out of the outer wing's front
    ref = (normal[0], s * normal[1], normal[2])
    ex, ey, ez = W["elbow"]

    def at(yz):
        y, z = yz
        return (ex + W["sweep"] * (y - ey) + W["lean"] * (z - ez), s * y, z)

    S = (W["shoulder"][0], s * W["shoulder"][1], W["shoulder"][2])
    E, T = (ex, s * ey, ez), at(W["wrist"])
    p = m.part(name, S, "Body")
    a1, a2 = W["arm"]
    tips = [at(t) for t in W["tips"]]
    for k, (deep, thick) in enumerate(zip(W["deep"], W["thick"])):
        e = unit(sub(tips[k + 1], tips[k]))
        n = cross(ref, e)
        n = n if dot(n, sub(T, tips[k])) > 0 else neg(n)
        up = 1.6 if k else -0.6  # into the panel before it
        mid, wide = add(mix(tips[k], tips[k + 1], 0.5), e, -up / 2), math.dist(tips[k], tips[k + 1]) + up
        bar(p, add(mid, n, 0.3 + 0.5 * (k % 2)), add(mid, n, deep), wide, thick, "wing", ref)
        bar(p, tips[k], add(tips[k + 1], e, 0.7 if k + 2 == len(tips) else 0), W["edge"], 2.9 - 0.4 * (k % 2), "lava", ref)
    last = len(tips) - 2
    for k, b in enumerate(tips[:-1]):  # the last finger hangs from the elbow, the others from the wrist
        a, t = E if k == last else T, W["bone"]
        through = 3.5 + 0.35 * ((last - k) % 3)
        d = unit(sub(b, a))
        bar(p, a, b, t, through, "edge", ref)
        knob = W["edge"] + 1.9
        bar(p, add(b, d, -2.4), add(b, d, 2.0), knob, through + 1.2, "edge", ref)
        hook = unit(add(d, (0, 0, -1), 0.9 if k else 0.3))
        point(p, add(b, d, 0.3), add(add(b, d, 1.0), hook, W["claw"] * 0.75), t + 0.6, through - 0.4, "ivory", ref)
    d, d2 = unit(sub(E, S)), unit(sub(T, E))
    bar(p, S, E, a1, a1, "armour", ref)
    bar(p, add(E, d2, -a1 * 0.45), T, a2, a2, "armour", ref)
    bar(p, add(E, d, -2.4), add(E, d, 2.2), a1 + 1.2, a1 + 1.2, "edge", ref)
    bar(p, add(T, d2, -2.0), add(T, d2, 1.4), a2 + 1.1, a2 + 1.1, "edge", ref)
    up = unit(add(d2, (0, 0, 1), 1.2))
    point(p, add(T, up, 0.4), add(T, up, W["claw"]), a2 * 0.62, a2 * 0.62, "ivory", ref)


def arms(m):
    z = (0, 0, 1)
    for tag, s in (("R", 1), ("L", -1)):
        S, E, H = ((-11, 13.0 * s, 37), (-17.5, 22.5 * s, 29.0), (-30.0, 20.5 * s, 22.5))
        p = m.part("Arm" + tag, (-11, 14 * s, 36), "Body")
        d, d2 = unit(sub(E, S)), unit(sub(H, E))
        bar(p, S, add(E, d, 2.0), 10.0, 9.6, "armour", z)
        bar(p, add(E, d, -1.8), add(E, d, 2.6), 11.9, 11.5, "edge", z)
        bar(p, add(E, d2, -2.0), H, 8.4, 8.0, "body", z)
        bar(p, add(H, d2, -1.5), add(H, d2, 0.5), 9.4, 9.0, "edge", z)
        point(p, add(E, (0.7, 0.6 * s, -0.35), 1.0), add(E, (0.7, 0.6 * s, -0.35), 12.5), 4.8, 4.6, "ivory", z)  # the elbow's spur
        palm = add(H, unit((-1, 0, -0.35)), 3.4)
        bar(p, add(H, d2, -1.6), palm, 9.8, 6.4, "armour", z)
        for k, (dy, way, long) in enumerate(((-3.1, (-0.85, -0.38, -0.45), 6.2), (0.0, (-0.95, 0, -0.4), 7.4), (3.1, (-0.85, 0.38, -0.45), 6.2))):
            way = unit(way)
            q = add(palm, (0, dy, 0))
            knuckle = add(q, way, long * 0.62)
            bar(p, add(q, way, -2.2), knuckle, 2.9 - 0.1 * k, 3.0 + 0.13 * k, "body", z)
            hook = unit((way[0] * 0.6, way[1] * 0.7, -0.75))
            point(p, add(knuckle, way, -0.7), add(knuckle, hook, 7.0), 2.5, 2.6, "ivory", z)


def tail(m, tag, s):
    q = math.radians(TAIL_OUT)
    side = (-math.sin(q) * s, math.cos(q), 0.0)
    pt, pts, ways = (16.5, 6.0 * s, 43.0), [], []
    for turn, long in zip(TAIL_TURN, TAIL_LONG):
        e = math.radians(turn)
        way = (math.cos(e) * math.cos(q), s * math.cos(e) * math.sin(q), math.sin(e))
        pts.append(pt)
        ways.append((way, (math.sin(e) * math.cos(q), s * math.sin(e) * math.sin(q), -math.cos(e))))  # along, and the curl's outside
        pt = add(pt, way, long)
    pts.append(pt)
    part = None
    for k, size in enumerate(TAIL_SIZE):
        a, b, (d, outer) = pts[k], pts[k + 1], ways[k]
        if k % 2 == 0:
            part = m.part(f"T{tag}{k // 2 + 1}", a, f"T{tag}{k // 2}" if k else "Body")
        end = add(b, d, 0.4 * TAIL_SIZE[k + 1]) if k < 7 else b
        bar(part, add(a, d, -0.2 * size), end, size, size, "body", side)
        if k < 7:
            bar(part, add(end, d, -1.7), add(end, d, 0.35), size + 1.1, size + 1.1, "edge", side)
        if k > 4:
            continue
        lift = size / 2 - 0.5
        bar(part, add(add(a, outer, lift), d, 1.2 if k else 5.0), add(add(end, outer, lift), d, -2.4), size - 2.6, 1.9, "belly", outer)
        inner = neg(outer)
        bar(part, add(add(a, inner, lift + 0.4), d, 2.0 if k else 7.0), add(add(end, inner, lift + 0.4), d, -1.2), size - 3.4, 2.1, "armour", outer)
    # the star: a lit core and blades up, down and on
    d = ways[-1][0]
    up = ways[-1][1]
    core = add(pts[-1], d, 1.4)
    bar(part, add(core, d, -2.8), add(core, d, 2.6), 5.4, 4.0, "ice", side)
    for way, long in ((d, 12.5), (up, 11.0), (neg(up), 11.0)):
        point(part, add(core, way, 1.0), add(core, way, long), 5.0, 2.6, "ivory", side)


def pose(parts, phase):
    """the heads sway and the jaws work, each in its own time; the wings beat; the tails follow"""
    r, s = math.radians, math.sin
    for tag, lag, gape in (("", 0.0, 4.0), ("R", 1.6, 5.0), ("L", 3.1, 4.0)):
        parts["Neck" + tag].rotation_euler.y = r(1.2) * s(phase - lag)
        parts["Neck" + tag].rotation_euler.z = r(1.4) * s(phase - lag - 0.8)
        parts["Head" + tag].rotation_euler.y = r(2.6) * s(phase - lag - 1.0)
        parts["Jaw" + tag].rotation_euler.y = -r(gape) * (0.5 + 0.5 * s(2 * phase - lag))
    for tag, side in (("R", 1), ("L", -1)):
        parts["Wing" + tag].rotation_euler.x = side * r(5.0) * s(phase)
        parts["Wing" + tag].rotation_euler.z = side * r(2.5) * s(phase - 0.6)
        parts["Wing2" + tag].rotation_euler.x = side * r(6.0) * s(phase - 0.9)
        parts["Arm" + tag].rotation_euler.y = r(3.0) * s(phase + (0.0 if side > 0 else 2.2))
        for k in range(4):
            parts[f"T{tag}{k + 1}"].rotation_euler.y = r(0.8 + 0.5 * k) * s(phase - 0.5 * k)
            parts[f"T{tag}{k + 1}"].rotation_euler.z = side * r(0.6 + 0.6 * k) * s(phase - 0.5 * k - 0.9)


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 38), "Stand")
    trunk(body)
    tack(body)
    crystals(body)
    for tag, spec in NECKS.items():
        neck(m, tag, spec)
        head(m, tag, spec)
    for tag, s in (("R", 1), ("L", -1)):
        wing(m, "Wing" + tag, s, WING)
        wing(m, "Wing2" + tag, s, WING2)
        tail(m, tag, s)
    arms(m)
