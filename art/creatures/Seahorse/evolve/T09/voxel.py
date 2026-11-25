"""Seahorse rocker, level 9 "Golden" (docs/style/13-seahorse-evolution.md): a winged sea drake, the first of the four huge
monsters. Yellow gold all over (VARIANT gold) in three clear tones: pale membranes, rings and scutes, a mid body, deep
undersides and bones; violet is the accent (the pearl, the halo of the eyes, the lines on the neck's rings, the saddle cloth).
The family marks: the curled tail, the armour rings, the crest (now antlers), the fan behind the seat.
- The wings are one flat sheet each, raised: swept back 35 degrees and its top leaned back, so it stands broad to the front,
  the side, the top and the 3/4 views. It stands behind the saddle, so nothing hides the rider.
- The head is a drake's: a jaw open on ivory teeth, a heavy brow over a halo eye turned half forward, antlers, whiskers, a
  beard of three blades. Two arms hold a violet pearl under it."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 9
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
globals().update(c.VARIANTS.get(LEVEL, {}))
# "deep" is the darkest gold of the ramp, so the body lands on the middle one; the kept colours are the violets of the cloth
# and the mouth
PALETTE.update({"deep": "#B07F10", "cloth": "#6A2FBE", "maw": "#3A1466", "tongue": "#A95CE0"})
KEEP += ["cloth", "maw", "tongue"]
GLOW = {"gem": 0.9, "halo": 0.9, "ribbon": 0.7, **c.glow_of(LEVEL)}
LIGHTS = [("Arms", (-38.0, 0, 41.0), "#B25CFF", 40, 1.5)]
FLOATING = ["Coil"]
FRAME, ORTHO = 5.0, 60.0
SWING = 8
SEAT = (5.0, 53.6, 4.6)

TS, BS = [(3, 2), (1, 2)], [(3, 2), (1, 2)]
TS1, BS1 = [(2, 2), (1, 2)], [(2, 2), (1, 2)]
# the trunk: from, to, cubes out, bottom, top
SLICES = ((-17, -15, 7, 32, 46, TS1, BS1), (-15, -12, 9, 29, 48, TS1, BS1), (-12, -9, 10, 27, 49, TS, BS), (-9, 10, 11, 26, 50, TS, BS),
          (10, 13, 10, 27, 49, TS, BS), (13, 16, 8, 29, 47, TS1, BS1))
BARREL = SLICES[3]
NECK = ((-8.0, 0, 41.0), (-15.0, 0, 46.6), (-19.2, 0, 53.4), (-17.8, 0, 63.4), (-22.4, 0, 72.6))
NECK_SIZE = (13.6, 12.5, 11.4, 10.2)
TAIL = ((10.0, 0, 38.0), (20.5, 0, 39.6), (30.0, 0, 37.0), (35.6, 0, 30.6), (36.5, 0, 22.6), (34.2, 0, 15.9), (29.6, 0, 12.4), (25.2, 0, 12.0),
        (21.6, 0, 13.8), (20.0, 0, 16.8))
TAIL_SIZE = (12.6, 11.6, 10.2, 8.9, 7.7, 6.5, 5.3, 4.2, 3.2)


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


class Frame:
    """a frame of its own in the side view: a along it (forward), h out of its top, y across"""

    def __init__(self, origin, down):
        r = math.radians(down)
        self.o, self.d, self.n = origin, (-math.cos(r), 0.0, -math.sin(r)), (-math.sin(r), 0.0, math.cos(r))

    def p(self, a, h, y=0.0):
        return tuple(o + a * d + h * n for o, d, n in zip((self.o[0], y, self.o[2]), self.d, self.n))

    def v(self, a, h, y=0.0):
        return unit(tuple(a * d + h * n + w for d, n, w in zip(self.d, self.n, (0.0, y, 0.0))))

    def box(self, part, a0, a1, h0, h1, wide, colour):
        part._oriented(self.p((a0 + a1) / 2, (h0 + h1) / 2), self.d, (0.0, 1.0, 0.0), self.n, (a1 - a0, wide, h1 - h0), colour, False)

    def pair(self, part, a0, a1, h0, h1, y0, y1, colour):
        part._oriented(self.p((a0 + a1) / 2, (h0 + h1) / 2, (y0 + y1) / 2), self.d, (0.0, 1.0, 0.0), self.n,
                       (a1 - a0, y1 - y0, h1 - h0), colour, True)

    def tooth(self, part, a, h, y, size, apex, colour="ivory", mirror=True):
        """a pointed tooth: its square base on (a, h, y), its point `apex` = (a, h, y) from there"""
        s = size / 2
        base = [self.p(a + i * s, h, y + j * s) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        part.spike(base, self.p(a + apex[0], h + apex[1], y + apex[2]), colour, mirror)


HEAD = Frame((-21.0, 0, 73.5), 8)
JAW_AT = HEAD.p(5.0, -4.6)
JAW = Frame(JAW_AT, 31)


def pose(parts, phase):
    """the head nods, the jaw opens a little, the wings beat, the tail follows"""
    parts["Neck"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.2 + math.pi)
    parts["Jaw"].rotation_euler.y = math.radians(-4) * (1 - math.cos(phase))
    for s, tag in ((1, "R"), (-1, "L")):
        parts["Wing" + tag].rotation_euler.x = s * math.radians(9) * math.sin(phase + 0.5)
        parts["Whisk" + tag].rotation_euler.x = s * math.radians(5) * math.sin(phase - 1.5)
        parts["Whisk" + tag].rotation_euler.y = math.radians(6) * math.sin(phase - 1.8)
    parts["Arms"].rotation_euler.y = math.radians(3) * math.sin(phase + 1.0)
    parts["Fan"].rotation_euler.x = math.radians(5) * math.sin(2 * phase)
    for k in range(9):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians((1, 1, 1, 2, 2, 3, 3, 4, 5)[k]) * math.sin(phase - 0.45 * (k + 1))


def blade(part, base, d1, d2, length, wide, thick, colour="ring", tip="tip"):
    """a finned blade in the side view: a broad box and a narrower, thinner one that bends on from it"""
    d1, d2 = unit(d1), unit(d2)
    mid = at(base, d1, length * 0.6)
    part.beam(base, mid, wide, thick, colour)
    part.beam(at(mid, d2, -wide * 0.42), at(mid, d2, length * 0.5), wide * 0.68, thick - 0.35, tip)


def trunk(body):
    for x0, x1, n, bot, top, ts, bs in SLICES:
        body.hull(x0, x1, n, bot, top, "body", ts, bs)
        body.paint_sym(x0, x1, n, 26, 33, "deep")
    for (a, b), k in (((-11.6, -9.6), 2), ((-5.4, -3.0), 3), ((10.6, 12.4), 4)):  # the armour rings
        n, bot, top, ts, bs = SLICES[k][2:]
        body.band(a, b, n, bot, top, "armour", ts, bs, proud=0.5)
    for z, w in ((33.0, 9.0), (37.0, 11.4), (41.0, 11.4)):  # the chest's pale scutes
        body.block(-18.1, (-w / 2 + 0.6, w / 2 - 0.6, z + 0.3, z + 3.3), -16.4, (-w / 2, w / 2, z, z + 3.6), "belly")
    # the wings' shoulders
    body.beam((12.6, 3.6, 40.6), (13.2, 10.6, 46.2), 8.6, 9.0, "body", mirror=True)
    body.beam((12.8, 6.4, 42.9), (13.3, 11.9, 47.3), 6.8, 7.2, "armour", mirror=True)


def tack(body):
    x0, x1, n, bot, top, ts, bs = BARREL
    body.band(-0.4, 9.6, n, bot, top, "tip", ts, bs, proud=0.35, stop=36.3)  # the cloth: a pale hem, violet on it
    body.band(0.5, 8.7, n, bot, top, "cloth", ts, bs, proud=0.75, stop=37.6)
    body.block(1.0, (-4.4, 4.4, 49.4, 53.5), 9.15, (-4.4, 4.4, 49.4, 53.5), "saddle")
    body.beam((4.6, 3.4, 51.6), (4.6, 9.6, 49.6), 6.4, 1.6, "saddle", mirror=True)  # the skirts
    body.beam((4.6, 10.5, 45.3), (4.6, 13.0, 40.4), 5.6, 1.5, "deep", mirror=True)
    body.beam((2.7, 0, 51.8), (0.9, 0, 55.6), 2.6, 6.4, "saddle")  # the pommel and its knob
    body.beam((1.3, 0, 54.6), (0.4, 0, 56.8), 3.4, 7.2, "tip")
    body.beam((8.0, 0, 51.0), (10.2, 0, 57.0), 2.2, 10.0, "saddle")  # the cantle
    body.beam((9.75, 0, 56.0), (10.4, 0, 57.8), 3.0, 10.8, "tip")
    body.block(3.6, (12.6, 13.6, 35.6, 41.8), 5.6, (12.6, 13.6, 35.6, 41.8), "armour", mirror=True)  # the stirrups
    body.block(2.6, (12.2, 14.4, 34.0, 36.0), 6.6, (12.2, 14.4, 34.0, 36.0), "tip", mirror=True)


def neck(m):
    nk = m.part("Neck", (-10.0, 0, 45), "Body")
    for k in range(4):
        a, b, size = NECK[k], NECK[k + 1], NECK_SIZE[k]
        d = unit(sub(b, a))
        front = (-d[2], 0.0, d[0])
        nk.beam(a if k == 0 else at(a, d, -size * 0.36), at(b, d, 0.8), size, size, "body")
        for s0, s1 in ((), ((2.6, 6.4),), ((0.6, 4.4), (5.0, 8.2)), ((0.8, 4.6), (5.2, 9.4)))[k]:  # the throat's scutes
            nk.beam(at(at(a, d, s0), front, size / 2 - 0.2), at(at(a, d, s1), front, size / 2 - 0.2), 1.7, size - 4.4, "belly")
        if k < 3:  # the ring over the block's end: a deep collar, a pale one on it, a lit violet line
            nk.beam(at(b, d, -1.4), at(b, d, 2.6), size + 0.8, size + 0.8, "deep")
            nk.beam(at(b, d, -0.7), at(b, d, 2.0), size + 1.7, size + 1.7, "armour")
            nk.beam(at(b, d, 0.3), at(b, d, 1.3), size + 2.4, size + 2.4, "ribbon")
    # the back line rises: three blades on the neck, the fourth on the nape of the head
    blade(nk, (-14.8, 0, 50.6), (0.6, 0, 0.8), (0.8, 0, 0.6), 10.0, 5.0, 2.6)
    blade(nk, (-16.0, 0, 57.0), (0.85, 0, 0.53), (0.92, 0, 0.4), 10.0, 5.4, 1.9)
    blade(nk, (-18.0, 0, 64.6), (0.82, 0, 0.57), (0.95, 0, 0.3), 11.0, 5.6, 2.6)


def head(m):
    hd = m.part("Head", (-21.5, 0, 71.5), "Neck")
    H = HEAD
    H.box(hd, -5.0, 8.6, -6.0, 6.0, 14.2, "body")  # the skull
    hd.beam(H.p(6.0, 1.4), H.p(19.6, 0.8), 9.7, 7.0, "body", flat="z")  # the snout, two blocks
    hd.beam(H.p(17.4, 0.8), H.p(24.0, 0.2), 8.2, 5.9, "body", flat="z")
    H.box(hd, -4.2, 6.2, 5.2, 7.3, 8.4, "armour")  # the crown's plate and the nose's
    hd.beam(H.p(5.0, 6.2), H.p(18.2, 4.3), 5.6, 2.2, "armour", flat="z")
    H.pair(hd, 19.8, 23.2, 2.4, 4.5, 1.2, 4.4, "armour")  # the nostrils
    H.pair(hd, 22.6, 23.6, 3.0, 4.0, 1.9, 3.3, "deep-")
    # the mouth: the roof, the lip
    H.box(hd, 4.0, 9.8, -5.6, -1.0, 9.0, "maw")
    H.box(hd, 8.0, 22.6, -3.0, -1.2, 7.8, "maw")
    H.pair(hd, 8.4, 20.0, -3.5, -0.9, 3.4, 5.5, "deep")
    H.pair(hd, 18.6, 24.5, -3.3, -1.1, 3.6, 5.1, "deep")
    H.box(hd, 22.6, 24.8, -3.0, -0.8, 6.6, "deep")
    for a, y, size, length in ((10.8, 4.5, 1.8, 3.2), (13.6, 4.5, 2.0, 3.8), (16.6, 4.5, 1.9, 3.4)):
        H.tooth(hd, a, -3.2, y, size, (0.3, -length, 0.0))
    H.tooth(hd, 21.4, -2.8, 3.8, 2.1, (0.6, -5.2, 0.1))
    H.tooth(hd, 23.6, -2.7, 1.4, 1.7, (0.3, -3.0, 0.0))
    # the jowls, the cheekbones
    H.pair(hd, -2.4, 6.8, -7.8, -1.4, 4.6, 7.6, "deep")
    H.pair(hd, 2.0, 11.4, -3.2, -1.2, 4.4, 8.0, "armour")
    # the eye: turned half forward
    turn = math.radians(42)
    en = tuple(math.sin(turn) * d + y for d, y in zip(H.d, (0.0, math.cos(turn), 0.0)))
    et = tuple(math.cos(turn) * d - y for d, y in zip(H.d, (0.0, math.sin(turn), 0.0)))
    eye = H.p(7.3, 1.5, 6.6)
    for t, h, out, size, colour in ((0.0, 0.0, 0.0, (6.4, 5.6, 3.0), "halo"), (0.1, -0.3, 0.25, (3.6, 4.2, 3.1), "black"),
                                    (0.9, 0.8, 0.5, (1.2, 1.2, 3.1), "ivory")):
        p = at(at(at(eye, et, t), H.n, h), en, out)
        hd._oriented(p, et, en, H.n, (size[0], size[2], size[1]), colour, True)
    hd.beam(H.p(-3.0, 9.0, 7.6), H.p(12.6, 2.7, 2.3), 4.6, 2.8, "deep", flat="z", mirror=True)  # the brow
    hd.beam(H.p(-4.2, 10.3, 7.8), H.p(8.2, 4.4, 2.6), 3.2, 1.9, "armour", flat="z", mirror=True)
    # the frill: three blades a side, swept back from the cheek
    for a, h, v, length, wide, thick in ((-1.0, 2.4, (-0.8, 0.3, 0.62), 12.0, 4.6, 2.2), (-0.4, -1.6, (-0.82, 0.0, 0.66), 11.0, 4.2, 1.6),
                                         (0.0, -5.2, (-0.8, -0.34, 0.6), 9.0, 3.6, 1.0)):
        p, v = H.p(a, h, 4.2), H.v(*v)
        hd.beam(p, at(p, v, length), wide, thick, "fin", mirror=True)
        hd.beam(at(p, v, 0.6), at(p, v, length * 0.6), wide * 0.6, thick + 0.8, "deep", mirror=True)
    # the antlers: four boxes each
    r0, r1, r2 = H.p(-1.0, 4.6, 3.6), H.p(-5.6, 12.4, 9.4), H.p(-9.0, 20.2, 12.8)
    d0, d1 = unit(sub(r1, r0)), unit(sub(r2, r1))
    hd.beam(r0, at(r1, d0, 0.8), 5.4, 5.4, "deep", mirror=True)
    hd.beam(at(r1, d1, -2.2), at(r2, d1, -1.6), 4.1, 4.1, "deep", mirror=True)
    hd.beam(at(r2, d1, -4.0), at(r2, d1, 1.0), 2.9, 2.9, "tip", mirror=True)
    for b0, v, length, size in ((at(r0, d0, 6.6), H.v(0.78, 0.6, 0.45), 9.8, 3.3), (at(r1, d1, 1.6), H.v(-0.15, 0.55, 0.85), 8.4, 3.0)):
        hd.beam(b0, at(b0, v, length * 0.72), size, size, "deep", mirror=True)
        hd.beam(at(b0, v, length * 0.5), at(b0, v, length), size - 0.8, size - 0.8, "tip", mirror=True)
    blade(hd, H.p(-4.0, 2.0), H.v(-0.8, 0.6), H.v(-0.95, 0.3), 9.0, 6.0, 2.2)

    jaw = m.part("Jaw", JAW_AT, "Head")
    J = JAW
    J.box(jaw, -2.4, 12.6, -3.8, 0.0, 10.6, "body")
    J.box(jaw, 11.0, 18.6, -3.3, 0.5, 8.8, "body")
    J.box(jaw, 0.4, 16.4, -1.0, 0.75, 7.2, "maw")
    J.box(jaw, 2.0, 13.0, 0.0, 1.5, 3.6, "tongue")
    J.pair(jaw, 0.6, 13.4, -1.4, 1.1, 3.5, 5.75, "deep")
    J.pair(jaw, 12.4, 18.9, -1.2, 0.95, 3.7, 4.8, "deep")
    J.box(jaw, 16.6, 19.2, -2.6, 1.6, 5.8, "deep")
    J.box(jaw, 3.0, 17.0, -4.6, -2.8, 6.4, "belly")
    for a, y, size, length in ((4.4, 4.6, 1.7, 2.8), (7.6, 4.6, 1.9, 3.4), (10.8, 4.6, 1.8, 3.0)):
        J.tooth(jaw, a, 0.8, y, size, (0.2, length, 0.0))
    J.tooth(jaw, 15.4, 0.4, 3.7, 2.1, (0.5, 4.6, 0.1))
    J.tooth(jaw, 17.8, 1.2, 1.4, 1.6, (0.2, 3.0, 0.0))
    # the beard
    for y, length, wide, thick in ((0.0, 9.5, 3.8, 2.6), (2.6, 7.4, 3.2, 1.9)):
        p = J.p(13.4, -2.4, y)
        v = J.v(-0.15, -1.0, 0.22 * (y > 0))
        mid = at(p, v, length * 0.62)
        jaw.beam(p, mid, wide, thick, "ring", mirror=y > 0)
        jaw.beam(at(mid, v, -1.2), at(mid, J.v(-0.6, -0.9, 0.22 * (y > 0)), length * 0.5), wide * 0.66, thick - 0.4, "tip", mirror=y > 0)
    for s, tag in ((1, "R"), (-1, "L")):  # the whiskers
        pts = [H.p(20.6, 1.2, 3.2), H.p(23.6, 3.4, 6.4), H.p(25.6, 6.6, 9.6), H.p(26.4, 10.8, 11.8), H.p(26.0, 14.4, 14.6),
               H.p(25.6, 15.4, 18.6)]
        pts = [(x, y * s, z) for x, y, z in pts]
        w = m.part("Whisk" + tag, pts[0], "Head")
        for k in range(5):
            size = (3.0, 2.1, 1.75, 1.45, 1.2)[k]
            d = unit(sub(pts[k + 1], pts[k]))
            w.beam(at(pts[k], d, -0.2), at(pts[k + 1], d, 1.7 if k == 0 else 1.2 if k < 4 else 0.0), size, size, "deep" if k < 3 else "ring")


# ---------------------------------------------------------------- the wings: a sheet each. s out along it, q up it
ROOT, SWEEP, LEAN = (12.6, 9.0, 45.6), math.radians(35), math.radians(20)
WS = (math.sin(SWEEP), math.cos(SWEEP), 0.0)
WQ = (math.cos(SWEEP) * math.sin(LEAN), -math.sin(SWEEP) * math.sin(LEAN), math.cos(LEAN))
WN = (WS[1] * WQ[2] - WS[2] * WQ[1], WS[2] * WQ[0] - WS[0] * WQ[2], WS[0] * WQ[1] - WS[1] * WQ[0])


def wing(m, s, tag):
    def flip(v):
        return (v[0], v[1] * s, v[2])

    part = m.part("Wing" + tag, flip((12.6, 9.0, 45.6)), "Body")

    def out(p, n=0.0):
        return flip(tuple(o + p[0] * a + p[1] * b + n * e for o, a, b, e in zip(ROOT, WS, WQ, WN)))

    def way(deg):
        return (math.cos(math.radians(deg)), math.sin(math.radians(deg)))

    def box(p0, p1, wide, thick, colour, side=0.0):
        """a box in the sheet from p0 to p1; side: its middle that far to the right of its line"""
        length = math.dist(p0, p1)
        e = ((p1[0] - p0[0]) / length, (p1[1] - p0[1]) / length)
        r = (e[1], -e[0])
        mid = ((p0[0] + p1[0]) / 2 + r[0] * side, (p0[1] + p1[1]) / 2 + r[1] * side)
        along = flip(tuple(e[0] * a + e[1] * b for a, b in zip(WS, WQ)))
        across = flip(tuple(r[0] * a + r[1] * b for a, b in zip(WS, WQ)))
        part._oriented(out(mid), along, across, flip(WN), (length, wide, thick), colour, False)

    def on(p, deg, d):
        e = way(deg)
        return (p[0] + e[0] * d, p[1] + e[1] * d)

    elbow, wrist = (6.2, 10.4), (9.0, 23.0)
    box((-2.4, -4.0), on(elbow, 59, 2.2), 7.6, 6.8, "body")  # the arm: two boxes, a ring at the wrist
    box(on(elbow, 257, 2.8), on(wrist, 77, 1.8), 6.0, 5.4, "body")
    box(on(wrist, 257, 1.8), on(wrist, 77, 2.4), 7.0, 6.2, "ring")
    box(on(elbow, 239, 1.6), on(elbow, 59, 2.9), 8.6, 7.8, "armour")  # and a pale one at the elbow
    # five broad panels, each a whole box hung along its finger toward the next; a finger is a box and a long point
    for deg, length, wide, thick, start, fl, up in ((74, 20.6, 12.0, 0.8, 0.0, 23.4, 0.0), (48, 25.6, 13.0, 1.4, 0.0, 28.6, 0.3),
                                                    (22, 24.0, 13.0, 2.0, 0.0, 26.6, 0.6), (-6, 23.0, 12.0, 2.6, 0.0, 25.4, 0.9),
                                                    (-36, 20.4, 10.0, 3.2, 1.0, 24.0, 1.2)):
        if wide:
            box(on(wrist, deg, start), on(wrist, deg, length), wide, thick, "armour", side=wide / 2)
            box(on(wrist, deg, length - 2.1), on(wrist, deg, length + 0.5), wide + 0.5, thick + 0.3, "ring", side=wide / 2)
        size, bone = 2.7, fl * 0.62
        box(wrist, on(wrist, deg, bone), size, 3.2 + up, "deep")
        r = way(deg - 90)
        base = on(wrist, deg, bone - 0.6)
        h, k = 1.1, (2.7 + up) / 2
        corners = [out((base[0] + r[0] * i * h, base[1] + r[1] * i * h), j * k) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        part.spike(corners, out(on(wrist, deg, fl + 1.4)), "deep")
    base = on(wrist, 130, 1.8)  # the claw of the wrist
    corners = [out((base[0] + i * 1.6, base[1] + j * 0.0), j * 1.6) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    part.spike(corners, out(on(base, 112, 6.4)), "ivory")


def arms(m):
    ar = m.part("Arms", (-14.0, 0, 38), "Body")
    pearl = (-33.6, 0.0, 41.0)
    sh, el, wr = (-11.5, 8.6, 37.6), (-22.0, 13.0, 34.0), (-30.4, 8.6, 38.8)
    u, d = unit(sub(el, sh)), unit(sub(wr, el))
    ar.beam(sh, at(el, u, 1.8), 7.0, 6.4, "body", mirror=True)
    ar.beam(at(el, d, -2.0), wr, 5.6, 5.2, "body", mirror=True)
    ar.beam(at(wr, d, -2.0), at(wr, d, 0.5), 7.2, 6.6, "armour", mirror=True)
    ar.beam(at(el, u, -1.0), at(el, u, 2.2), 8.0, 7.4, "armour", mirror=True)
    fin = at(el, (1, 0, 0), 0.5)  # a fin off the elbow
    ar.beam(fin, at(fin, unit((0.8, 0.35, -0.5)), 7.0), 3.8, 1.6, "fin", mirror=True)
    ar.beam(at(wr, d, -0.6), at(wr, d, 4.0), 6.2, 4.6, "deep", mirror=True)  # the palm
    hand = at(wr, d, 2.6)
    ar.beam(hand, (pearl[0], 2.6, pearl[2]), 2.8, 2.8, "deep", mirror=True)  # the heel of the hand, on the pearl
    for z, x in ((1.8, -0.6), (0.0, -1.2), (-1.8, -0.6)):  # three claws each, closing round its front
        root = (hand[0] - 0.4, hand[1] - 0.2, hand[2] + z)
        tip = (pearl[0] + x - 3.6, 2.4, pearl[2] + z * 1.7)
        knuckle = (pearl[0] - 1.6, 7.2, pearl[2] + z * 1.9)
        k = unit(sub(knuckle, root))
        ar.beam(root, knuckle, 1.8 + 0.1 * z, 2.0 + 0.3 * z, "deep", mirror=True)
        side = unit((-k[1], k[0], 0.0))
        up = (side[1] * k[2], -side[0] * k[2], side[0] * k[1] - side[1] * k[0])
        b0 = at(knuckle, k, -0.5)
        corners = [at(at(b0, side, i * 0.72), up, j * 0.72) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        ar.spike(corners, tip, "ivory", mirror=True)
    e = 6.7
    ar._oriented(pearl, (math.sqrt(2 / 3), 0.0, 1 / math.sqrt(3)), (-1 / math.sqrt(6), 1 / math.sqrt(2), 1 / math.sqrt(3)),
                 (-1 / math.sqrt(6), -1 / math.sqrt(2), 1 / math.sqrt(3)), (e, e, e), "gem", False)


def tail(m):
    last = len(TAIL_SIZE) - 1
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = unit(sub(b, a))
        t = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        end = at(b, d, 0.42 * TAIL_SIZE[k + 1]) if k < last else b
        t.beam(at(a, d, -0.2 * size), end, size, size, "body")
        if k < 5:  # the deep inside of the curl
            inner = (d[2], 0.0, -d[0])
            p, q = at(a, inner, size / 2 - 0.4), at(end, inner, size / 2 - 0.4)
            t.beam(at(p, d, 7.0 if k == 0 else 1.6), at(q, d, -1.2), 1.4, size - 3.0, "deep")
        if k == 6:
            continue
        if k < last:
            if k < 4:
                t.beam(at(end, d, -2.3), at(end, d, 0.4), size + 1.0, size + 1.0, "deep")
                t.beam(at(end, d, -1.7), at(end, d, 0.15), size + 1.7, size + 1.7, "armour")
            else:
                t.beam(at(end, d, -1.6), at(end, d, 0.35), size + 1.0, size + 1.0, "armour")
        else:  # the fan of three
            t.beam(at(end, d, -1.6), at(end, d, 0.6), size + 1.7, size + 1.7, "deep")
            for deg, length, wide, thick in ((112, 11.0, 4.8, 3.6), (150, 10.0, 4.6, 2.4), (72, 11.4, 4.6, 1.6)):
                v = (math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg)))
                p = at(end, d, -0.8)
                t.beam(p, at(p, v, length - 2.0), wide, thick, "fin")
                t.beam(at(p, v, 0.6), at(p, v, length * 0.62), wide * 0.4, thick + 0.5, "deep")
                t.beam(at(p, v, length - 3.0), at(p, v, length), wide + 0.9, thick + 0.3, "tip")


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 34), "Stand")
    trunk(body)
    tack(body)
    neck(m)
    head(m)
    wing(m, 1, "R")
    wing(m, -1, "L")
    arms(m)
    fan = m.part("Fan", (12, 0, 45), "Body")
    root = (11.6, 0, 43.0)
    for deg, length, wide, thick, rib in ((70, 19.0, 5.6, 3.0, 4.2), (48, 21.0, 6.0, 2.2, 3.6), (26, 18.0, 5.2, 1.4, 2.6)):
        d = (math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg)))
        fan.beam(root, at(root, d, length - 2.0), wide, thick, "fin")
        fan.beam(at(root, d, 0.7), at(root, d, length * 0.62), wide * 0.4, rib, "deep")
        fan.beam(at(root, d, length - 4.4), at(root, d, length), wide + 0.9, thick + 0.4, "ring")
    tail(m)
