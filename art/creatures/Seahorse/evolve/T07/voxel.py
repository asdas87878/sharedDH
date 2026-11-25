"""Seahorse rocker, level 7 "Knight" (docs/style/13-seahorse-evolution.md): a hippocamp. In front a war horse, reared up 25
degrees on its spring: a deep chest behind a silver peytral, two forelegs lifted with finned hooves, an upright neck, a head
in a closed helm with an aqua eye behind the visor's slit, and a lance for a horn. Behind it a big fish: a thick tapering
hind body under a crupper of three lames, the tail sweeping down, back and up to a wide fluke. The seahorse's marks: the
armour rings, the crest (a plume and a finned mane), the curl, and the fan behind the seat, here two wings of finned blades."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 7
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW, LIGHTS = {"eye": 0.9, **c.glow_of(LEVEL)}, []
FLOATING = ["Coil"]
FRAME, ORTHO = 5.0, 60.0
SWING = 9
SEAT = (6.2, 47.2, 4.6)

R = math.radians
TS, BS = [(3, 1), (1, 2)], [(2, 2)]
BARREL = (-7, 13, 9, 24, 42)
NECK = ((-10.0, 0, 46.5), (-13.6, 0, 56.0), (-16.6, 0, 64.0))
NECK_SIZE = (13.0, 11.2)
TAIL = ((8.0, 0, 33.4), (17.6, 0, 27.6), (22.7, 0, 23.6), (28.0, 0, 22.5), (32.4, 0, 24.8), (35.0, 0, 30.2), (35.0, 0, 37.8), (32.8, 0, 45.2))
TAIL_SIZE = (16.6, 13.4, 11.2, 9.0, 7.8, 6.6, 5.4)


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def way(a, b):
    return unit(tuple(q - p for p, q in zip(a, b)))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


class Frame:
    """a set of axes in the side view: `s` runs along D, `h` out along N, y across"""

    def __init__(self, origin, deg, scale=1.0):
        self.o, self.deg, self.k = origin, deg, scale
        a = R(deg)  # how far D points up from level, going forward (-x)
        self.D = (-math.cos(a), 0.0, math.sin(a))
        self.N = (math.sin(a), 0.0, math.cos(a))

    def p(self, s, h, y=0.0):
        s, h, y = s * self.k, h * self.k, y * self.k
        return (self.o[0] + s * self.D[0] + h * self.N[0], y, self.o[2] + s * self.D[2] + h * self.N[2])

    def box(self, part, s0, s1, h0, h1, wide, colour):
        part._oriented(self.p((s0 + s1) / 2, (h0 + h1) / 2), self.D, (0.0, 1.0, 0.0), self.N, tuple(v * self.k for v in (s1 - s0, wide, h1 - h0)), colour, False)

    def sides(self, part, s0, s1, h0, h1, y0, y1, colour):
        part._oriented(self.p((s0 + s1) / 2, (h0 + h1) / 2, (y0 + y1) / 2), self.D, (0.0, 1.0, 0.0), self.N,
                       tuple(v * self.k for v in (s1 - s0, y1 - y0, h1 - h0)), colour, True)

    def tilted(self, part, s, h, deg, size, colour, y=None):
        """a box whose middle is at (s, h), turned `deg` more than the frame; size (along, across, deep); y: a pair there"""
        f = Frame((0, 0, 0), self.deg + deg)
        part._oriented(self.p(s, h, y or 0.0), f.D, (0.0, 1.0, 0.0), f.N, tuple(v * self.k for v in size), colour, y is not None)


CHEST = Frame((-2.5, 0.0, 35.5), 25)
HEAD = Frame((-17.0, 0.0, 67.0), -36, 1.14)


def blade(part, base, d1, d2, length, wide, thick, colour="fin", tip="tip"):
    """a finned blade in the side view: a broad box, and a narrower and thinner one that bends on from it"""
    d1, d2 = unit(d1), unit(d2)
    mid = at(base, d1, length * 0.62)
    part.beam(base, mid, wide, thick, colour)
    part.beam(at(mid, d2, -wide * 0.42), at(mid, d2, length * 0.46), wide * 0.68, thick - 0.4, tip)


def plate(part, p0, p1, wide, thick, normal, colour, mirror=False):
    """a flat box from p0 to p1 whose thin side faces `normal`"""
    d = way(p0, p1)
    k = sum(a * b for a, b in zip(d, normal))
    t = unit(tuple(n - k * a for n, a in zip(normal, d)))
    w = (d[1] * t[2] - d[2] * t[1], d[2] * t[0] - d[0] * t[2], d[0] * t[1] - d[1] * t[0])
    part._oriented(tuple((a + b) / 2 for a, b in zip(p0, p1)), d, w, t, (math.dist(p0, p1), wide, thick), colour, mirror)


def pose(parts, phase):
    """the neck and the head nod, the forelegs paddle, the wings beat a little, the tail follows"""
    parts["Neck"].rotation_euler.y = R(1.5) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = R(3.5) * math.sin(phase - 1.2 + math.pi)
    parts["Jaw"].rotation_euler.y = -R(4) * (0.5 + 0.5 * math.sin(phase))
    for tag, lag in (("L", 0.0), ("R", math.pi)):
        parts["Leg" + tag].rotation_euler.y = R(6) * math.sin(phase + lag)
        parts["Shin" + tag].rotation_euler.y = R(8) * math.sin(phase + lag - 0.8)
        parts["Fan" + tag].rotation_euler.x = (1 if tag == "R" else -1) * R(6) * math.sin(phase - 0.5)
    for k, amp in enumerate((0.8, 1.2, 2, 2.5, 3, 4, 5)):
        parts[f"T{k + 1}"].rotation_euler.y = R(amp) * math.sin(phase - 0.5 * (k + 1))


def trunk(body):
    x0, x1, n, bot, top = BARREL
    body.hull(x0, x1, n, bot, top, "body", TS, BS)
    body.paint_sym(x0, x1, n, bot, 26, "belly")
    # the chest: two whole blocks crossed, turned up, and the breast in front
    CHEST.box(body, 0.0, 19.0, -10.0, 9.6, 20.6, "body")
    CHEST.box(body, 2.2, 18.0, -11.4, 11.0, 15.4, "body")
    CHEST.box(body, 16.5, 21.6, -7.6, 7.6, 14.6, "body")
    CHEST.box(body, 3.0, 17.2, -12.3, -9.0, 12.6, "belly")
    CHEST.box(body, 14.0, 20.3, -9.4, -5.2, 13.2, "belly")
    CHEST.box(body, -0.9, 1.0, -10.5, 10.2, 21.5, "ring")  # the armour ring behind it
    # the peytral: a great breastplate with a keel, a lower lame, and a strap plate along each flank
    CHEST.box(body, 18.0, 22.9, -2.6, 8.4, 17.4, "armour")
    CHEST.box(body, 18.3, 22.3, -6.6, -1.8, 14.2, "armour-")
    CHEST.box(body, 20.4, 24.3, -5.2, 7.4, 4.6, "armour")
    CHEST.box(body, 18.2, 23.5, 7.2, 9.0, 18.4, "tip")
    CHEST.tilted(body, 24.2, -1.4, 45, (5.6, 3.6, 5.6), "tip")


def shoulders(body):
    """two plates a side, standing off over the shoulders, each with a bright lip"""
    for s, (h0, y0), (h1, y1), wide, thick, colour in ((8.5, (8.0, 7.0), (6.2, 17.0), 10.6, 3.0, "armour"), (8.0, (4.4, 8.5), (0.6, 20.4), 12.6, 2.3, "armour-")):
        a, b = CHEST.p(s, h0, y0), CHEST.p(s, h1, y1)
        d = way(a, b)
        n = unit(cross(CHEST.D, d))
        plate(body, a, b, wide, thick, n, colour, True)
        plate(body, at(b, d, -1.3), at(b, d, 0.5), wide + 1.0, thick + 0.8, n, "tip", True)


def tack(body):
    x0, x1, n, bot, top = BARREL
    body.band(-2.0, 11.7, n, bot, top, "blanket", TS, BS, proud=0.45, stop=33.0)  # the caparison, and a flap hanging each side
    body.beam((4.6, 9.3, 40.6), (4.6, 11.1, 24.2), 13.4, 1.4, "blanket", mirror=True)
    body.beam((4.6, 10.62, 28.6), (4.6, 10.99, 25.2), 13.7, 1.8, "tip", mirror=True)
    body.beam((4.6, 10.9, 26.0), (4.6, 11.25, 22.8), 14.2, 2.4, "cream", mirror=True)
    body.block(1.0, (-4.0, 4.0, 41.5, 47.2), 10.4, (-4.0, 4.0, 41.5, 47.2), "saddle")  # the war saddle
    body.beam((5.6, 3.0, 45.4), (5.6, 9.2, 42.2), 6.6, 1.8, "saddle", mirror=True)
    body.beam((5.6, 9.6, 43.0), (5.6, 10.9, 34.0), 6.0, 2.0, "saddle", mirror=True)
    body.beam((5.6, 11.15, 41.4), (5.6, 12.1, 36.0), 3.4, 1.2, "saddle+", mirror=True)
    body.beam((2.6, 0, 45.6), (0.6, 0, 49.4), 2.4, 6.6, "saddle-")  # the pommel, plated
    body.beam((1.4, 0, 48.4), (0.5, 0, 50.4), 3.6, 7.4, "armour")
    body.beam((9.4, 0, 45.2), (12.0, 0, 51.6), 2.4, 10.4, "saddle-")  # the cantle
    body.beam((11.2, 0, 49.8), (12.5, 0, 53.2), 3.3, 11.4, "armour")
    body.beam((5.5, 11.6, 36.6), (5.5, 12.3, 29.0), 1.5, 0.9, "saddle+", mirror=True)  # the stirrups
    body.block(3.7, (11.2, 13.2, 27.4, 29.4), 7.3, (11.2, 13.2, 27.4, 29.4), "armour", mirror=True)


def neck(m):
    nk = m.part("Neck", NECK[0], "Body")
    for k in range(2):
        a, b, size = NECK[k], NECK[k + 1], NECK_SIZE[k]
        d = way(a, b)
        front = (-d[2], 0.0, d[0])
        nk.beam(at(a, d, -3.0 if k else -2.0), at(b, d, 2.0), size, size - 0.8, "body")
        stops = [1.0] + [f * math.dist(a, b) for f in ((0.42, 0.9) if k == 0 else (0.5, 1.0))]
        for j, (u, v) in enumerate(zip(stops, stops[1:])):  # the pale throat, from ring to ring, and the rings
            nk.beam(at(at(a, d, u), front, size / 2 - 0.6), at(at(a, d, v), front, size / 2 - 0.6), 2.4 - 0.4 * j, size - 4.3, "belly")
            if j < 1 or k == 0:
                p = at(a, d, v)
                nk.beam(at(p, d, -0.9), at(p, d, 0.9), size + 1.7, size + 0.7, "ring")
    for (x, z), length, d1, d2, thick in (((-9.4, 56.0), 7.0, (0.8, 0, 0.6), (0.7, 0, 0.7), 2.4),
                                          ((-11.0, 59.6), 8.0, (0.78, 0, 0.62), (0.75, 0, 0.66), 3.0),
                                          ((-12.4, 63.4), 9.0, (0.74, 0, 0.67), (0.82, 0, 0.57), 2.5)):
        blade(nk, (x, 0, z), d1, d2, length, 4.6, thick)


def head(m):
    hd = m.part("Head", HEAD.o, "Neck")
    H = HEAD
    H.box(hd, -2.6, 9.4, -5.6, 4.4, 10.0, "body")  # the skull, the jowls
    H.sides(hd, 0.4, 7.4, -6.4, -1.6, 2.0, 5.6, "body-")
    H.box(hd, 7.0, 14.8, -3.6, 2.6, 6.5, "body")  # the muzzle and the nose
    H.box(hd, 13.4, 17.6, -4.1, 2.1, 7.4, "body+")
    H.box(hd, 10.4, 17.85, -3.1, -2.3, 7.8, "black")  # the mouth's line, the nostrils
    H.sides(hd, 16.4, 17.95, -1.7, -0.3, 1.5, 2.9, "black")
    # the helm: a skull plate, a face plate in two tiers with a teal ridge, a visor over each eye with a slit, a cheek guard
    H.box(hd, -2.0, 9.0, 2.6, 6.0, 11.0, "armour")
    H.box(hd, 7.4, 13.0, 0.4, 4.1, 8.8, "armour")
    H.box(hd, 11.8, 18.1, 0.7, 3.1, 6.0, "armour")
    H.box(hd, 16.9, 18.5, -1.1, 2.7, 2.6, "armour")
    H.box(hd, 8.0, 17.3, 2.6, 4.7, 2.2, "tip")
    H.tilted(hd, 11.6, -2.6, 45, (3.4, 2.6, 3.4), "armour", 3.0)  # the bit: a plate at the mouth's corner, its strap
    H.tilted(hd, 11.6, -2.6, 45, (1.5, 3.2, 1.5), "black", 3.0)
    H.box(hd, -1.4, 7.6, 5.0, 6.9, 5.2, "armour+")
    H.sides(hd, -0.6, 8.7, 1.2, 4.9, 4.2, 6.8, "armour")
    H.sides(hd, -1.4, 9.2, -3.9, -1.0, 4.2, 6.5, "armour")
    H.sides(hd, -2.3, 1.2, -5.0, 4.05, 4.0, 7.2, "armour-")
    H.sides(hd, 0.6, 9.75, -1.4, 1.6, 4.0, 5.75, "black")
    H.sides(hd, 3.4, 9.0, -0.8, 1.0, 4.4, 6.3, "eye")
    # the slit's front end, turned in round the cheek between two plates, so it glares forward
    p0, p1 = H.p(7.8, 1.5, 6.9), H.p(11.3, -0.2, 2.1)
    n = unit(tuple(0.75 * i + j for i, j in zip(H.D, (0, 0.6, 0))))
    plate(hd, p0, p1, 4.6, 2.2, n, "black", True)
    e = at(p0, n, 1.0)
    plate(hd, at(e, way(p0, p1), 0.2), at(e, way(p0, p1), 6.0), 2.8, 1.7, n, "eye", True)
    for h, tall, thick in ((2.6, 2.4, 3.8), (-2.5, 2.0, 3.0)):
        plate(hd, H.p(7.6, 1.5 + h, 7.0), H.p(11.1, -0.2 + h, 2.1), tall, thick, n, "armour", True)
    # the lance: three collars and a point
    root, d = H.p(4.4, 4.8), unit((-math.cos(R(53)), 0, math.sin(R(53))))
    hd.beam(at(root, d, -2.0), at(root, d, 1.6), 6.8, 6.6, "armour-")
    hd.beam(at(root, d, 0.0), at(root, d, 7.2), 5.0, 4.8, "spike")
    hd.beam(at(root, d, 6.2), at(root, d, 7.8), 5.6, 5.8, "tip")
    hd.beam(at(root, d, 6.8), at(root, d, 12.0), 3.8, 3.7, "spike")
    hd.beam(at(root, d, 11.1), at(root, d, 12.5), 4.5, 4.6, "tip")
    hd.beam(at(root, d, 11.6), at(root, d, 15.2), 2.8, 2.7, "spike")
    s, n = at(root, d, 14.8), (d[2], 0.0, -d[0])
    hd.spike([(s[0] + n[0] * j * 1.7, k * 1.7, s[2] + n[2] * j * 1.7) for j, k in ((-1, -1), (-1, 1), (1, 1), (1, -1))], at(root, d, 20.4), "eye")
    # ears in guards, and the plume: three blades down the middle and a pair leaning out
    p, e = H.p(-0.2, 4.0, 4.0), unit((0.1, 0.16, 1))
    hd.beam(p, at(p, e, 6.2), 3.8, 2.6, "armour", mirror=True)
    hd.beam(at(p, e, 3.2), at(p, e, 9.0), 2.4, 1.7, "body", mirror=True)
    for p, length, d1, d2, thick in ((H.p(-1.6, 0.6), 10.0, (0.85, 0, 0.53), (0.95, 0, 0.3), 4.2), (H.p(-1.2, 3.8), 11.5, (0.55, 0, 0.84), (0.85, 0, 0.53), 3.4),
                                     (H.p(0.6, 5.2), 11.0, (0.15, 0, 0.99), (0.6, 0, 0.8), 2.6)):
        blade(hd, p, d1, d2, length, 5.6, thick)
    for p, d1, d2, length in ((H.p(-1.0, 3.6, 2.0), (0.5, 0.42, 0.76), (0.75, 0.5, 0.4), 10.0), (H.p(-1.4, 0.4, 2.6), (0.75, 0.5, 0.42), (0.85, 0.5, 0.1), 9.0)):
        d1, d2 = unit(d1), unit(d2)
        mid = at(p, d1, length * 0.6)
        n = unit((d1[1] * d2[2] - d1[2] * d2[1], d1[2] * d2[0] - d1[0] * d2[2], d1[0] * d2[1] - d1[1] * d2[0]))
        plate(hd, p, mid, 4.4, 1.8, n, "fin", True)
        plate(hd, at(mid, d2, -1.4), at(mid, d2, length * 0.45), 3.0, 1.2, n, "tip", True)
    jaw = m.part("Jaw", H.p(6.0, -4.0), "Head")
    H.tilted(jaw, 10.6, -5.2, -7, (10.8, 5.6, 2.6), "body-")
    H.tilted(jaw, 15.0, -5.8, -7, (3.8, 6.7, 3.5), "belly")


def legs(m):
    for tag, s, hip, knee, foot in (("L", -1, (-12.6, 11.2, 38.4), (-27.2, 16.0, 43.6), (-27.4, 16.8, 31.0)),
                                    ("R", 1, (-12.4, 11.2, 36.0), (-25.8, 16.0, 32.6), (-21.4, 16.8, 21.6))):
        hip, knee, foot = ((x, y * s, z) for x, y, z in (hip, knee, foot))
        leg = m.part("Leg" + tag, hip, "Body")
        u = way(hip, knee)
        leg.beam(at(hip, u, -2.4), at(hip, u, 9.6), 8.4, 6.6, "body")  # the thigh in two blocks
        leg.beam(at(hip, u, 7.0), at(knee, u, 2.0), 6.6, 5.6, "body")
        # the pauldron: three plates over the shoulder, each smaller, with a bright lip
        p = at(hip, u, 1.0)
        leg.beam(at(p, u, -5.6), at(p, u, 0.4), 14.2, 11.0, "armour")
        leg.beam(at(p, u, -0.6), at(p, u, 3.4), 12.2, 10.0, "armour-")
        leg.beam(at(p, u, 2.4), at(p, u, 5.8), 10.4, 9.0, "armour")
        leg.beam(at(p, u, -6.2), at(p, u, -4.6), 15.2, 11.9, "tip")
        k = at(knee, u, 0.2)
        leg.beam(at(k, u, -1.6), at(k, u, 2.4), 7.4, 6.5, "armour")  # the knee
        leg.beam(at(k, u, 1.4), at(k, u, 3.6), 4.2, 4.0, "armour+")
        d = way(knee, foot)
        shin = m.part("Shin" + tag, knee, "Leg" + tag)
        shin.beam(at(knee, d, 0.0), at(foot, d, 0.6), 5.4, 5.0, "body")
        back = (d[2], 0.0, -d[0])
        back = back if back[0] > 0 else tuple(-v for v in back)
        shin.beam(at(at(knee, d, 2.6), back, -2.0), at(at(foot, d, -2.6), back, -2.0), 3.0, 4.0, "armour")  # the greave
        shin.beam(at(foot, d, -1.8), at(foot, d, 2.2), 7.0, 6.6, "tip")  # the hoof and its shoe
        shin.beam(at(foot, d, 1.4), at(foot, d, 3.6), 7.8, 7.4, "armour")
        for j, (far, up, yy) in enumerate(((10.0, 0.9, 0.0), (8.0, 0.5, 2.2), (8.0, 0.5, -2.2))):  # the fetlock's fin
            f = at(foot, d, -0.8)
            f = (f[0], f[1] + yy * 0.6, f[2])
            e = unit(tuple(b - up * a for a, b in zip(d, back)))
            e = unit((e[0], yy * 0.22, e[2]))
            shin.beam(f, at(f, e, far), 4.0 - 0.4 * j, 1.9 - 0.2 * j, "fin")


def wings(m):
    """the fan behind the seat: three finned blades a side, swept out, up and back"""
    for tag, s in (("R", 1), ("L", -1)):
        w = m.part("Fan" + tag, (11.0, 7.0 * s, 38.0), "Body")
        root = (10.4, 6.4 * s, 37.6)
        dirs = [unit((x, y * s, z)) for x, y, z in ((0.30, 0.45, 0.84), (0.42, 0.68, 0.60), (0.52, 0.80, 0.26), (0.58, 0.78, -0.16))]
        a, b = dirs[0], dirs[3]
        n = unit((a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]))
        for d, length, wide, thick in zip(dirs, (24.0, 18.5, 14.5, 11.5), (7.2, 7.2, 6.6, 5.6), (4.2, 3.15, 2.1, 1.05)):
            plate(w, root, at(root, d, length * 0.66), wide, thick, n, "fin")
            plate(w, at(root, d, length * 0.52), at(root, d, length), wide * 0.74, thick - 0.69, n, "fin")
            plate(w, at(root, d, length * 0.82), at(root, d, length + 2.0), wide * 0.74 + 0.9, thick + 0.72, n, "tip")
            plate(w, at(root, d, 2.0), at(root, d, length * 0.9), 1.5, thick + 1.65, n, "body")
        plate(w, at(root, dirs[1], -2.0), at(root, dirs[1], 6.2), 10.0, 5.2, n, "armour")


def tail(m):
    n = len(TAIL_SIZE)
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = way(a, b)
        up = (-d[2], 0.0, d[0])  # out of the back, on the curl's inside
        t = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        end = at(b, d, 0.4 * TAIL_SIZE[k + 1]) if k < n - 1 else at(b, d, 1.0)
        start = at(a, d, (-0.1 if k == 0 else -0.2) * size)
        if k < 2:  # the fish's body: two blocks crossed
            t.beam(start, end, size, size - 4.0, "body")
            t.beam(at(start, d, 0.4), at(end, d, -0.4), size - 4.0, size, "body")
            t.beam(at(at(start, d, 0.8), up, -size / 2 + 0.4), at(at(end, d, -0.8), up, -size / 2 + 0.4), 2.2, size - 5.4, "belly")
        else:
            t.beam(start, end, size, size, "body")
            t.beam(at(at(start, d, 0.6), up, -size / 2 + 0.5), at(at(end, d, -0.8), up, -size / 2 + 0.5), 1.4, size - 2.8, "belly")
        if 1 < k < n - 1:
            t.beam(at(end, d, -1.5), at(end, d, 0.3), size + 0.8, size + 0.8, "ring")
        if k == 0:  # the crupper: three lames over the hind body, each in two blocks (the back, and both flanks), its back lip proud
            for f, wide in ((1.4, 1.6), (5.0, 0.8), (8.6, 0.1)):
                p = at(a, d, f)
                q = unit(tuple(i + 0.2 * j for i, j in zip(d, up)))
                for h0, h1, w in ((size / 2 - 3.0, size / 2 + 1.2, size - 3.4 + wide), (size / 2 - 8.4, size / 2 - 1.2, size + 1.2 + wide)):
                    mid = at(p, up, (h0 + h1) / 2)
                    t.beam(at(mid, q, -2.6), at(mid, q, 2.2), h1 - h0, w, "armour")
                    t.beam(at(mid, q, 1.4), at(mid, q, 2.9), h1 - h0 + 0.9, w + 0.9, "blanket")
    # the fluke
    end = TAIL[-1]
    d = way(TAIL[-2], TAIL[-1])
    t.beam(at(end, d, -2.4), at(end, d, 3.4), 7.6, 7.8, "ring")
    nrm = unit((0.62, 0, 0.78))
    for s in (1, -1):
        r = at(end, d, 0.8)
        a, k1 = (r[0], 0.4 * s, r[2]), (r[0] + 3.0, 7.4 * s, r[2] + 4.0)
        k2 = (r[0] + 7.4, 11.6 * s, r[2] + 11.6)
        u0, u = way(a, k1), way(k1, k2)
        nrm = unit((u0[1] * u[2] - u0[2] * u[1], u0[2] * u[0] - u0[0] * u[2], u0[0] * u[1] - u0[1] * u[0]))
        plate(t, a, at(a, u0, 5.0), 4.4 + 0.4 * s, 2.3 + 0.35 * s, nrm, "fin")
        plate(t, at(a, u0, 2.4), at(k1, u0, 3.0), 8.6, 3.2, nrm, "fin")
        plate(t, at(k1, u, -0.8), k2, 6.6, 2.0, nrm, "tip")
        plate(t, at(a, u0, 1.0), at(k1, u0, 1.2), 1.7, 4.0, nrm, "body")
    plate(t, at(end, d, -0.7), at(end, unit((0.35, 0, 1)), 8.0), 4.8, 1.6, nrm, "fin")


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 31), "Stand")
    trunk(body)
    shoulders(body)
    tack(body)
    neck(m)
    head(m)
    legs(m)
    wings(m)
    tail(m)
