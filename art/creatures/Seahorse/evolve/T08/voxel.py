"""Seahorse rocker, level 8 "Royal" (docs/style/13-seahorse-evolution.md): a peacock seadragon. A deep breast with pale
scutes, an S of a neck rising out of a ruff of eight gold-tipped blades, a long fine snout under a crown of five points; a
velvet caparison with gold hems; leaf fins draped from the flanks; twin tails sweeping out to both sides and curling. And the
showpiece, the fan behind the seat: nine feathers spread from side to side, lilac edged with gold, each ending in a diamond
(gold, magenta, dark), over a tier of short purple ones. It is finished front and back alike."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 8
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
globals().update(c.VARIANTS.get(LEVEL, {}))
PALETTE.update({"dark": "#2C1250", "lilac": "#B583EC"})
GLOW, LIGHTS = {"eye": 0.9, **c.glow_of(LEVEL)}, []
FLOATING = ["Coil"]
FRAME, ORTHO = 5.0, 60.0
SWING = 9
SEAT = (2.4, 49.0, 4.6)

R = math.radians
TS, BS = [(3, 1), (1, 2)], [(2, 2)]
BARREL = (-12, 12, 9, 25, 47)
NECK = ((-10.0, 0, 42.5), (-18.4, 0, 49.8), (-19.4, 0, 57.6), (-13.8, 0, 66.0))
NECK_SIZE = (11.6, 10.2, 9.0)
TAIL = ((8.0, 5.0, 33.0), (15.6, 8.6, 27.4), (22.6, 13.6, 23.6), (29.6, 18.6, 23.4), (33.4, 23.0, 27.6), (32.2, 24.4, 33.6), (27.6, 22.2, 37.4))
TAIL_SIZE = (9.4, 8.2, 7.0, 6.0, 5.0, 4.0)
TAIL_N = (0.55, -0.72, 0.25)
FAN, LEAN = (13.5, 0.0, 44.0), 25.0
FAN_A = (math.sin(R(LEAN)), 0.0, math.cos(R(LEAN)))  # the fan's middle, leaning back
FAN_N = (-math.cos(R(LEAN)), 0.0, math.sin(R(LEAN)))  # out of its face, towards the rider
FEATHER = (35.0, 34.0, 31.6, 28.0, 24.2)  # from the root to the middle of its diamond, from the middle feather outwards
STEP = 19.2


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


CHEST = Frame((-3.5, 0.0, 35.5), 22)
HEAD = Frame((-13.8, 0.0, 67.4), -12, 1.12)


def plate(part, p0, p1, wide, thick, normal, colour, mirror=False):
    """a flat box from p0 to p1 whose thin side faces `normal`"""
    d = way(p0, p1)
    k = sum(a * b for a, b in zip(d, normal))
    t = unit(tuple(n - k * a for n, a in zip(normal, d)))
    part._oriented(tuple((a + b) / 2 for a, b in zip(p0, p1)), d, cross(d, t), t, (math.dist(p0, p1), wide, thick), colour, mirror)


def pose(parts, phase):
    """the neck and the head nod, the fan opens and shuts a little, the tails and the leaves sway"""
    parts["Neck"].rotation_euler.y = R(1.5) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = R(3.5) * math.sin(phase - 1.2 + math.pi)
    parts["Jaw"].rotation_euler.y = -R(4) * (0.5 + 0.5 * math.sin(phase))
    parts["Fan"].rotation_euler.y = R(2) * math.sin(phase - 0.8)
    for tag, s in (("R", 1), ("L", -1)):
        parts["Fan" + tag].rotation_euler.x = -s * R(2) * (0.5 + 0.5 * math.sin(phase - 0.8))
        parts["Leaf" + tag].rotation_euler.y = R(5) * math.sin(phase - 0.9)
        for k, amp in enumerate((0.8, 1.2, 2, 2.5, 3, 4)):
            parts[f"T{tag}{k + 1}"].rotation_euler.z = s * R(amp) * math.sin(phase - 0.5 * (k + 1))


def trunk(body):
    x0, x1, n, bot, top = BARREL
    body.hull(x0, x1, n, bot, top, "body", TS, BS)
    body.paint_sym(x0, x1, n, bot, 27, "belly")
    # the rump, and the breast: whole blocks crossed, turned up, with a narrower block in front
    body.beam((3.0, 0, 35.5), (15.4, 0, 35.5), 16.6, 17.2, "body")
    body.beam((3.0, 0, 34.0), (16.6, 0, 33.0), 11.6, 12.6, "body")
    CHEST.box(body, 0.0, 13.6, -9.4, 9.0, 17.5, "body")
    CHEST.box(body, 1.5, 12.6, -10.6, 10.2, 13.4, "body")
    CHEST.box(body, 12.0, 16.6, -7.2, 6.6, 13.0, "body")
    # the scutes, overlapping like tiles from the belly up the breast
    CHEST.box(body, 2.6, 8.2, -11.5, -8.6, 10.8, "belly-")
    CHEST.box(body, 7.2, 13.4, -11.0, -7.4, 12.0, "belly")
    CHEST.box(body, 12.2, 16.0, -9.0, -5.6, 11.0, "belly-")
    CHEST.box(body, 14.6, 17.6, -7.8, -2.0, 11.4, "belly")
    CHEST.box(body, 15.0, 18.3, -2.6, 2.4, 10.4, "belly")
    CHEST.box(body, 14.8, 17.2, 1.2, 5.6, 9.4, "belly-")
    CHEST.box(body, -1.2, 0.8, -10.1, 9.6, 19.5, "ring")  # the armour ring behind it


def tack(body):
    x0, x1, n, bot, top = BARREL
    body.band(-4.0, 10.6, n, bot, top, "saddle", TS, BS, proud=0.45, stop=36.0)  # the velvet, and a flap hanging each side
    body.beam((3.2, 9.3, 44.0), (3.2, 11.2, 28.0), 15.6, 1.5, "saddle", mirror=True)
    body.beam((3.2, 10.9, 30.2), (3.2, 11.3, 27.4), 16.6, 2.4, "ring", mirror=True)
    body.beam((3.2, 10.0, 43.2), (3.2, 10.3, 41.4), 16.3, 2.0, "ring", mirror=True)
    for x in (-2.0, 3.2, 8.4):  # its points
        body._oriented((x, 11.15, 27.75), unit((1, 0, 1)), unit((1, 0, -1)), (0, 1, 0), (3.4, 3.4, 1.5), "ring", True)
    for x in (-1.6, 8.0):  # two gold diamonds on it
        body._oriented((x, 10.5, 34.6), unit((1, 0, 1)), unit((1, 0, -1)), (0, 1, 0), (4.0, 4.0, 2.6), "ring", True)
        body._oriented((x, 11.0, 34.6), unit((1, 0, 1)), unit((1, 0, -1)), (0, 1, 0), (2.3, 2.3, 2.6), "gem", True)
    body.block(-2.4, (-4.2, 4.2, 45.0, 49.0), 7.2, (-4.2, 4.2, 45.0, 49.0), "saddle-")  # the seat
    body.beam((2.4, 3.2, 46.8), (2.4, 9.0, 44.2), 7.0, 2.0, "saddle-", mirror=True)
    body.beam((-1.0, 0, 46.4), (-3.4, 0, 51.4), 3.4, 6.6, "ring")  # the pommel, gold, a gem on it
    body.beam((-2.6, 0, 49.4), (-3.8, 0, 53.0), 2.4, 3.2, "gem")
    body.beam((6.2, 0, 46.0), (8.6, 0, 53.4), 2.4, 10.2, "saddle")  # the throne's back, gold at the head
    body.beam((7.9, 0, 51.4), (9.1, 0, 55.0), 3.4, 11.4, "ring")
    body.beam((8.75, 0, 53.0), (10.05, 0, 57.4), 2.3, 5.0, "ring")


def neck(m):
    nk = m.part("Neck", NECK[0], "Body")
    for k in range(3):
        a, b, size = NECK[k], NECK[k + 1], NECK_SIZE[k]
        d = way(a, b)
        front = (-d[2], 0.0, d[0])
        nk.beam(at(a, d, -2.4), at(b, d, 2.0 if k < 2 else 3.4), size, size - 0.9, "body")
        long = math.dist(a, b)
        stops = ((4.4, 8.0, long + 0.6) if k == 0 else (1.2, 0.56 * long, long + 0.4))
        for j, (u, v) in enumerate(zip(stops, stops[1:])):  # the pale throat, from ring to ring
            nk.beam(at(at(a, d, u), front, size / 2 - 0.6), at(at(a, d, v), front, size / 2 - 0.6), 2.4 - 0.4 * j, size - 1.6, "belly" if j else "belly-")
        if k < 2:
            nk.beam(at(b, d, 1.1), at(b, d, 2.4), size + 1.0, size + 0.15, "ring")
        else:
            nk.beam(at(a, d, long - 1.4), at(a, d, long + 0.1), size + 1.5, size + 0.4, "ring")
    ruff(nk)
    # the mane: three leaf blades up the nape
    for (x, z), length, e in (((-14.8, 56.4), 8.0, (0.86, 0, 0.5)), ((-13.4, 60.8), 9.0, (0.8, 0, 0.6)), ((-11.4, 65.0), 9.6, (0.72, 0, 0.69))):
        e = unit(e)
        j = 2.2 + 0.6 * (length > 8.5) + 0.6 * (length > 9.3)
        nk.beam((x, 0, z), at((x, 0, z), e, length * 0.7), 4.6, j, "lilac")
        nk.beam(at((x, 0, z), e, length * 0.5), at((x, 0, z), e, length + 1.4), 2.8, j - 0.3, "tip")


def ruff(nk):
    """eight gold-tipped blades round the neck's foot, standing open like a collar"""
    a = NECK[0]
    d = way(NECK[0], NECK[1])
    o = at(a, d, 4.2)
    e, y = (d[2], 0.0, -d[0]), (0.0, 1.0, 0.0)  # e: the nape's side
    nk.beam(at(a, d, 2.6), at(a, d, 5.4), 13.8, 13.9, "ring")
    for k in range(4):
        for s in (1, -1):
            ang = R(22.5 + 45 * k)
            out = unit(tuple(math.cos(ang) * i + s * math.sin(ang) * j for i, j in zip(e, y)))
            u = unit(tuple(o_ + (0.85, 0.62, 0.46, 0.36)[k] * d_ for o_, d_ in zip(out, d)))
            r = at(o, out, 3.0)
            long = (13.5, 15.5, 15.0, 13.0)[k]
            t = 2.1 if k % 2 else 1.7
            plate(nk, r, at(r, u, long * 0.72), 8.6, t, cross(u, cross(d, u)), "saddle")
            plate(nk, at(r, u, long * 0.56), at(r, u, long + 1.0), 6.2, t - 0.45, cross(u, cross(d, u)), "tip")


def head(m):
    hd = m.part("Head", HEAD.o, "Neck")
    H = HEAD
    H.box(hd, -3.6, 6.4, -5.0, 4.6, 9.6, "body")  # the skull, the cheeks
    H.box(hd, -4.4, 3.6, -3.4, 3.2, 8.0, "body")
    H.sides(hd, -1.8, 4.4, -4.7, -1.6, 2.4, 5.5, "body+")
    H.box(hd, 5.0, 9.6, -3.6, 2.6, 7.0, "body")  # the long fine snout in three blocks, and its trumpet
    H.box(hd, 8.6, 17.4, -2.6, 1.0, 4.2, "body")
    H.box(hd, 16.4, 18.9, -3.1, 1.6, 5.2, "body+")
    H.box(hd, 5.6, 16.8, 0.3, 1.9, 2.2, "ring")  # the pale ridge down it
    H.sides(hd, 17.9, 19.2, -1.3, 0.1, 0.5, 1.6, "black")
    # the eye: a dark lid, the glow, a gold brow over it
    H.sides(hd, 0.4, 5.6, -1.8, 3.0, 3.6, 5.2, "black")
    H.sides(hd, 1.2, 4.8, -1.1, 2.1, 4.2, 5.75, "eye")
    H.sides(hd, 2.5, 3.4, -0.7, 1.7, 4.6, 6.05, "black")
    H.sides(hd, 0.0, 7.2, 2.4, 4.0, 2.8, 6.1, "ring")
    # the crown: a band, five points, gems of 3
    H.box(hd, -4.4, 5.4, 4.0, 6.6, 10.8, "crown")
    H.box(hd, -3.0, 4.0, 5.6, 7.6, 7.6, "saddle")
    for s, y, lean in ((3.4, 0.0, -0.26), (0.9, 3.5, -0.1), (-2.5, 3.2, 0.24)):
        for sign in ((1, -1) if y else (1,)):
            p = H.p(s, 5.1, y * sign)
            e = unit((0.21 + lean, 0.22 * sign if y else 0.0, 0.97))
            nk = 3.4 if y else 4.0
            plate(hd, p, at(p, e, 5.4), nk, nk - 0.5, (0, 1, 0) if not y else (1, 0, 0), "crown")
            q = at(p, e, 5.0)
            w = nk / 2 - 0.5
            ay = unit(at((0.0, 1.0, 0.0), e, -e[1]))
            ax = cross(ay, e)
            hd.spike([tuple(v + i * w * m_ + j * w * n_ for v, m_, n_ in zip(q, ax, ay)) for i, j in ((-1, -1), (-1, 1), (1, 1), (1, -1))], at(p, e, 10.2), "crown")
    H.tilted(hd, 5.6, 5.4, 45, (2.7, 3.6, 2.7), "gem")
    for s in (1.4, -2.6):
        hd._oriented(H.p(s, 5.3, 5.2), unit((1, 0, 1)), unit((1, 0, -1)), (0, 1, 0), (2.8, 2.8, 2.4), "gem", True)
    # the ears: two leaf fins a side, swept back
    for p, u, long, w in ((H.p(-1.2, 0.4, 4.0), (0.78, 0.5, 0.36), 11.0, 5.0), (H.p(-0.8, -2.6, 4.0), (0.8, 0.5, -0.3), 8.5, 4.2)):
        u = unit(u)
        n = unit(cross(u, (0, 0, 1)))
        plate(hd, p, at(p, u, long * 0.7), w, 2.0, n, "lilac", True)
        plate(hd, at(p, u, long * 0.5), at(p, u, long), w * 0.66, 1.5, n, "tip", True)
    jaw = m.part("Jaw", H.p(6.0, -3.4), "Head")
    H.tilted(jaw, 10.6, -3.3, -2, (12.0, 3.5, 1.8), "belly-")


def fan_box(part, deg, r0, r1, off, wide, mid, thick, colour, tilt=0.0):
    """a box in the fan's plane: along the feather at `deg` from the middle, r0 to r1 from the root, `off` to its side
    (tilt: it leans this much further back than the plane)"""
    a, y, b = R(deg), (0.0, 1.0, 0.0), R(tilt)
    u = tuple(math.cos(a) * i + math.sin(a) * j for i, j in zip(FAN_A, y))
    w = tuple(math.cos(a) * j - math.sin(a) * i for i, j in zip(FAN_A, y))
    u, n = (tuple(math.cos(b) * i - math.sin(b) * j for i, j in zip(u, FAN_N)), tuple(math.sin(b) * i + math.cos(b) * j for i, j in zip(u, FAN_N)))
    o = at(at(at(FAN, u, (r0 + r1) / 2), w, off), FAN_N, mid)
    part._oriented(o, u, w, n, (r1 - r0, wide, thick), colour, False)


def fan_diamond(part, deg, r, side, mid, thick, colour):
    a, y = R(deg), (0.0, 1.0, 0.0)
    u = tuple(math.cos(a) * i + math.sin(a) * j for i, j in zip(FAN_A, y))
    w = tuple(math.cos(a) * j - math.sin(a) * i for i, j in zip(FAN_A, y))
    o = at(at(FAN, u, r), FAN_N, mid)
    part._oriented(o, unit(tuple(i + j for i, j in zip(u, w))), unit(tuple(i - j for i, j in zip(u, w))), FAN_N, (side, side, thick), colour, False)


def fan(m):
    mid = m.part("Fan", FAN, "Body")
    sides = {1: m.part("FanR", FAN, "Fan"), -1: m.part("FanL", FAN, "Fan"), 0: mid}
    # the boss the feathers stand in
    fan_box(mid, 0, -7.0, 6.6, 0.0, 13.0, -2.0, 8.6, "body")
    fan_box(mid, 0, -8.4, 4.4, 0.0, 16.2, -2.0, 7.4, "body")
    fan_box(mid, 0, 4.8, 8.2, 0.0, 9.8, -1.6, 8.9, "ring")
    fan_diamond(mid, 0, -0.6, 7.0, -6.4, 2.0, "tip")  # a crest on its back
    fan_diamond(mid, 0, -0.6, 3.6, -6.9, 2.2, "gem")
    for j in range(-4, 5):
        k, deg = abs(j), STEP * j
        p = sides[(j > 0) - (j < 0)]
        long, t = FEATHER[k], -1.0 * k
        bend = 0.53 * long
        fan_box(p, deg, 7.0, bend + 2.0, 0.0, 4.6, t, 2.4, "lilac")  # the feather in two blocks
        fan_box(p, deg, bend, long, 0.0, 6.4, t, 1.9, "fin")
        fan_box(p, deg, 5.0, long, 0.0, 1.3, t, 2.9, "body")  # its quill
        for s in (1, -1):  # its gold edges
            fan_box(p, deg, 9.2, bend + 1.0, s * 2.45, 1.1, t, 1.3, "tip-")
            fan_box(p, deg, bend - 0.4, long - 4.0, s * 3.65, 1.3, t, 1.2, "tip")
        size = 7.4 - 0.25 * k  # the diamond
        fan_diamond(p, deg, long, size, t, 3.6, "tip")
        fan_diamond(p, deg, long, size * 0.64, t, 4.25, "eye")
        fan_diamond(p, deg, long, size * 0.33, t, 4.9, "dark")
    for j in range(-4, 4):  # the short tier between them, leaning a little further back
        deg = STEP * (j + 0.5)
        k = (abs(2 * j + 1) - 1) // 2
        p = sides[1 if j >= 0 else -1]
        fan_box(p, deg, 5.0, 20.6 - 0.6 * k, 0.0, 5.0 + 0.1 * (j % 2), -0.7 * k - 0.4, 1.4 + 0.6 * (j % 2), "body", 7.0)


def tails(m):
    n = len(TAIL_SIZE)
    for tag, s in (("R", 1), ("L", -1)):
        pts = [(x, y * s, z) for x, y, z in TAIL]
        nrm = unit((TAIL_N[0], TAIL_N[1] * s, TAIL_N[2]))
        for k, size in enumerate(TAIL_SIZE):
            a, b = pts[k], pts[k + 1]
            d = way(a, b)
            t = m.part(f"T{tag}{k + 1}", a, f"T{tag}{k}" if k else "Body")
            out = unit(cross(d, nrm))
            if out[2] > 0 if k < 3 else out[0] < 0:
                out = tuple(-v for v in out)
            start = at(a, d, -0.2 * size)
            end = at(b, d, 0.42 * TAIL_SIZE[k + 1] if k < n - 1 else 1.4)
            plate(t, start, end, size, size - 0.3, nrm, "body")
            plate(t, at(at(start, d, 0.7), out, size / 2 - 0.5), at(at(end, d, -0.8), out, size / 2 - 0.5), size - 3.0, 1.8, out, "belly")
            if k < n - 1:
                plate(t, at(end, d, -1.5), at(end, d, 0.3), size + 1.5, size + 1.2, nrm, "ring")
        # the tip: a gold spade with a lilac leaf each side
        end, d = pts[-1], way(pts[-2], pts[-1])
        w = unit(cross(d, nrm))
        plate(t, at(end, d, 0.2), at(end, d, 4.6), 5.6, 5.0, nrm, "ring")
        for q, long, wide, thick, col in ((0.0, 10.0, 3.4, 2.6, "tip"), (0.75, 9.0, 3.6, 1.9, "fin"), (-0.75, 9.0, 3.6, 1.3, "fin")):
            u = unit(tuple(i + q * j for i, j in zip(d, w)))
            plate(t, at(end, d, 1.6), at(at(end, d, 1.6), u, long), wide, thick, nrm, col)


def leaves(m):
    """leaf fins draped from the flanks, as a leafy seadragon's: each a broad box, a tapering one and a gold rib"""
    for tag, s in (("R", 1), ("L", -1)):
        leaf = m.part("Leaf" + tag, (-13.0, 8.0 * s, 41.0), "Body")
        for (x, y, z), out, v, long in (((-13.5, 6.8, 42.0), (0.2, 0.9, 0.1), (0.50, 0.24, -0.84), 16.0), ((-13.0, 6.0, 34.2), (-0.1, 0.95, -0.2), (0.22, 0.30, -0.93), 13.0)):
            root, out, v = (x, y * s, z), unit((out[0], out[1] * s, out[2])), unit((v[0], v[1] * s, v[2]))
            nrm = (-0.1, 0.95 * s, 0.3)
            k = sum(i * j for i, j in zip(nrm, v))
            nrm = unit(at(nrm, v, -k))
            w = cross(v, nrm)
            o = at(root, out, 5.4)
            plate(leaf, root, at(o, out, 0.4), 3.6, 1.9, (1, 0, 0.2), "lilac-")
            plate(leaf, at(o, v, -2.2), at(o, v, long * 0.56), long * 0.46, 2.6, nrm, "lilac")
            plate(leaf, at(o, v, long * 0.44), at(o, v, long - 2.2), long * 0.3, 1.8, nrm, "tip")
            e = at(o, nrm, 0.9)
            plate(leaf, at(e, v, -1.2), at(e, v, long * 0.52), 1.4, 1.7, nrm, "tip-")
            for q, t in ((1, 2.0), (-1, 1.5)):
                u = unit(tuple(0.62 * i + q * 0.8 * j for i, j in zip(v, w)))
                plate(leaf, at(o, v, long * 0.1), at(at(o, v, long * 0.1), u, long * 0.46), long * 0.28, t, nrm, "fin")


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 32.4), "Stand")
    trunk(body)
    tack(body)
    neck(m)
    head(m)
    fan(m)
    tails(m)
    leaves(m)
