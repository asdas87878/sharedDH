"""Seahorse rocker, level 5 "Iron" (docs/style/13-seahorse-evolution.md): a battering ram. A hunched trunk 23 wide under four
great overlapping shells (a plateau, a sloped side and a hanging flank each, a raised lip with rivets), the head carried low in
front behind an iron brow plate, ram horns curled round both cheeks, a blunt muzzle in an iron ring, shields for fins, a breast
plate, and the seahorse's tail in thick collars curling up to a mace over the rump."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 5
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
PALETTE.update({"iron": "#46525F", "bone": "#E6DDC6"})  # gunmetal: rivets, muzzle ring, mace, so the silver has something dark to sit on
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW, LIGHTS = {}, []
FLOATING = ["Coil"]
FRAME, ORTHO = 3.4, 40.0
SWING = 10
SEAT = (3.4, 45.8, 3.8)

TAIL = ((7.6, 0, 33.4), (13.2, 0, 31.2), (18.0, 0, 31.0), (21.4, 0, 33.8), (22.8, 0, 38.2), (22.2, 0, 43.2), (20.0, 0, 47.0))
TAIL_SIZE = (11.0, 10.0, 9.0, 8.0, 7.0, 6.2)
# the shells: x and z of each plateau's middle, its tilt (nose-down), half its length, how far it stands out over the next
SHELLS = ((-9.6, 41.4, 24, 4.6, 0.9), (-2.9, 42.6, 5, 4.4, 0.6), (4.0, 41.9, -9, 4.4, 0.3), (9.8, 38.8, -32, 4.4, 0.0))
# a ram's horn in the head's frame, right side: a, h, y
HORN = ((0.0, 0.0), (3.4, 6.6), (9.6, 8.0), (13.2, 3.4), (11.4, -2.2), (6.0, -3.0))
HORN_SIZE = (6.4, 5.7, 4.9, 4.0, 3.0)


def pose(parts, phase):
    """the head butts, the shields shrug, the mace swings"""
    parts["Neck"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.2 + math.pi)
    for name, s in (("FinL", -1), ("FinR", 1)):
        parts[name].rotation_euler.x = s * math.radians(3) * math.sin(phase)
    for k, amp in enumerate((1, 1, 2, 2, 3, 3)):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians(amp) * math.sin(phase - 0.5 * (k + 1))


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def toward(a, b):
    return unit(tuple(j - i for i, j in zip(a, b)))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def square_to(w, ref):
    """two directions at right angles to w: the first as near `ref` as it can be"""
    dot = sum(i * j for i, j in zip(w, ref))
    p = unit(tuple(r - dot * v for r, v in zip(ref, w)))
    return p, cross(w, p)


def spike(part, q, way, size, reach, tall, colour, ref=(0.0, 1.0, 0.0)):
    """a pyramid pointing `way` from q: its base 0.7 under `reach`, its point `tall` over it"""
    w = unit(way)
    p1, p2 = square_to(w, ref if abs(sum(i * j for i, j in zip(w, ref))) < 0.9 else (1.0, 0.0, 0.0))
    h = size / 2
    base = [tuple(o + (reach - 0.7) * a + i * h * b + j * h * e for o, a, b, e in zip(q, w, p1, p2)) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    part.spike(base, at(q, w, reach + tall), colour)


class Frame:
    """a leaning part of the animal: a runs to the nose, h out of its back, y to the side; `deg` nose-down"""

    def __init__(self, x, z, deg):
        r = math.radians(deg)
        self.o, self.d, self.n = (x, 0.0, z), (-math.cos(r), 0.0, -math.sin(r)), (-math.sin(r), 0.0, math.cos(r))

    def pt(self, a, h, y=0.0):
        return (self.o[0] + a * self.d[0] + h * self.n[0], y, self.o[2] + a * self.d[2] + h * self.n[2])

    def box(self, part, a0, a1, h0, h1, wide, colour):
        part._oriented(self.pt((a0 + a1) / 2, (h0 + h1) / 2), self.d, (0.0, 1.0, 0.0), self.n, (a1 - a0, wide, h1 - h0), colour, False)

    def side(self, part, a0, a1, h0, h1, y0, y1, colour, mirror=True):
        part._oriented(self.pt((a0 + a1) / 2, (h0 + h1) / 2, (y0 + y1) / 2), self.d, (0.0, 1.0, 0.0), self.n, (a1 - a0, abs(y1 - y0), h1 - h0), colour, mirror)

    def slab(self, part, p0, p1, tall, y0, y1, colour):
        """a box lying in the side view between (a, h) points p0 and p1, `tall` across, from y0 to y1 out; both sides"""
        a, b = self.pt(*p0, (y0 + y1) / 2), self.pt(*p1, (y0 + y1) / 2)
        u = toward(a, b)
        part._oriented(tuple((i + j) / 2 for i, j in zip(a, b)), u, (0.0, 1.0, 0.0), (-u[2], 0.0, u[0]), (math.dist(a, b), y1 - y0, tall), colour, True)

    def roll(self, part, a0, a1, h, y, deg, long, thick, colour):
        """a slab on the round of the back: its middle at (h, y), `long` across and `thick` through, rolled `deg` down; both sides"""
        r = math.radians(deg)
        across = tuple(math.cos(r) * v - math.sin(r) * n for v, n in zip((0.0, 1.0, 0.0), self.n))
        out = tuple(math.sin(r) * v + math.cos(r) * n for v, n in zip((0.0, 1.0, 0.0), self.n))
        part._oriented(self.pt((a0 + a1) / 2, h, y), self.d, across, out, (a1 - a0, long, thick), colour, True)


HEAD = Frame(-13.2, 38.4, 14)


def trunk(body):
    ts, bs = [(3, 2), (1, 2)], [(2, 2)]
    body.hull(-10, 8, 10, 22, 41, "body", ts, bs)
    body.hull(-14, -10, 8, 24, 39, "body", [(2, 2)], [(2, 2)])
    body.hull(8, 12, 8, 25, 38, "body", [(2, 2)], [(2, 2)])
    body.paint_sym(-10, 8, 10, 22, 25, "belly")
    body.paint_sym(-14, -10, 8, 24, 27, "belly")
    body.paint_sym(8, 12, 8, 25, 27, "belly")
    body.paint_sym(-5, 6, 6, 22, 23, "iron")  # where the spring is bolted on
    for x0 in (-10, -4, 2):  # the belly's scutes
        body.paint_sym(x0, x0 + 1, 10, 22, 25, "belly-")
    # the breast plate: three plates down the chest, each over the next
    for z, w, colour in ((36.0, 13.7, "armour"), (32.2, 14.9, "armour-"), (28.6, 12.0, "armour")):
        body.beam((-12.8, 0, z + 2.6), (-15.6, 0, z - 2.2), 2.6, w, colour)
    for z in (33.2, 29.6):
        for y in (2.4, 5.0):
            body.block(-16.6, (y - 0.7, y + 0.7, z - 1.4, z), -14.4, (y - 0.7, y + 0.7, z - 1.4, z), "iron", mirror=True)


def shell(body, x, z, deg, half, out):
    f = Frame(x, z, deg)

    def lay(a0, a1, g, colour, side_colour, flank):
        under = 0.3 if g else 0.0  # a lip holds the plate's end, inside and out
        f.box(body, a0, a1, -1.2 - under, 1.5 + g, 14.7 + g + out * 2, colour)
        shift = (g - under) / 2 * 0.707
        if out == 0.9:  # the shoulder's shell is a plateau alone: the horns and the shields hang there
            return
        f.roll(body, a0 + 0.15, a1 - 0.15, -1.5 + shift + out * 0.3, 8.9 + shift + out * 0.5, 45, 7.4 + 2 * under, 2.4 + g + under, colour)
        f.side(body, a0 + 0.3, a1 - 0.3, flank - g, -2.8 + under, 8.8 + out - under * 1.5, 11.5 + g + out, side_colour)

    lay(-half, half, 0.0, "armour", "armour-", -10.4)
    lay(-half - 0.8, -half + 1.0, 0.75, "iron", "iron", -10.6)
    for y in (2.2, 6.0):
        f.side(body, -half + 1.6, -half + 3.1, 1.0, 2.2, y - 0.75, y + 0.75, "iron")
    for h in (-7.4,) if out < 0.9 else ():
        f.side(body, -half + 1.6, -half + 3.1, h - 0.75, h + 0.75, 10.6, 12.2 + out, "iron")


def saddle(body):
    body.block(-0.6, (-5.0, 5.0, 41.6, 44.4), 7.2, (-5.0, 5.0, 41.6, 44.4), "blanket")
    body.block(0.4, (-3.7, 3.7, 43.0, 45.8), 6.5, (-3.7, 3.7, 43.0, 45.8), "saddle")
    body.beam((3.4, 3.0, 45.0), (3.4, 8.6, 41.8), 4.8, 1.3, "saddle", mirror=True)
    body.beam((3.4, 8.0, 43.0), (3.4, 12.3, 38.2), 4.2, 1.3, "saddle-", mirror=True)
    body.beam((3.4, 11.8, 39.4), (3.4, 12.9, 33.6), 3.0, 1.2, "saddle-", mirror=True)
    body.beam((3.4, 12.6, 34.6), (3.4, 12.8, 31.6), 4.2, 2.0, "iron", mirror=True)
    body.beam((1.0, 0, 44.6), (-1.0, 0, 48.0), 2.4, 5.4, "saddle-")
    body.beam((-0.4, 0, 47.2), (-1.0, 0, 48.6), 3.0, 6.2, "armour")
    body.beam((6.2, 0, 44.4), (7.8, 0, 49.0), 2.0, 8.0, "saddle-")
    body.beam((7.5, 0, 48.2), (8.0, 0, 49.6), 2.7, 8.8, "armour")


def neck_and_head(m):
    neck = m.part("Neck", (-11, 0, 36), "Body")
    n0, n1 = (-9.4, 0, 35.4), (-17.0, 0, 37.8)
    d = toward(n0, n1)
    neck.beam(n0, n1, 11.0, 11.0, "body")
    for k, (g, colour) in enumerate(((1.7, "ring"), (1.3, "ring-"))):  # its collars
        neck.beam(at(n0, d, 2.9 + 1.7 * k), at(n0, d, 4.9 + 1.7 * k), 11 + g, 11 + g, colour)

    head, f = m.part("Head", (-14, 0, 37.6), "Neck"), HEAD
    f.box(head, -0.6, 11.0, -6.2, 5.0, 13.3, "body")  # the skull
    f.side(head, 0.6, 7.6, -5.6, -1.2, 5.4, 7.0, "body-")  # the jowls
    f.box(head, 1.6, 9.6, -7.4, -5.4, 9.6, "belly")
    f.box(head, 10.0, 16.6, -5.2, 1.7, 9.0, "body")  # the snout and its iron ring
    f.box(head, 13.2, 16.0, -6.2, 2.6, 10.8, "iron")
    f.box(head, 15.2, 18.6, -4.9, 1.4, 10.2, "body")  # the nose: wider than tall, over a lower lip
    f.box(head, 14.6, 17.6, -6.6, -4.6, 8.2, "body-")
    f.box(head, 18.0, 18.95, -3.6, -2.7, 7.2, "black")  # the mouth, turned down at its ends, and slanted nostrils at the corners
    for (h, y), (ky, kn), long, wide, deep in (((-3.5, 3.9), (0.5, -0.86), 1.9, 0.9, 0.7), ((-0.5, 3.5), (0.8, 0.6), 2.5, 1.4, 0.9)):
        u = unit(tuple(ky * v + kn * n for v, n in zip((0.0, 1.0, 0.0), f.n)))
        head._oriented(f.pt(18.1 + deep / 2, h, y), u, cross(f.d, u), f.d, (long, wide, deep), "black", True)
    head.beam(f.pt(17.8, -1.4, 1.6), f.pt(19.7, -5.4, 2.0), 1.0, 1.0, "armour", mirror=True)  # the ring in its nose
    f.box(head, 18.9, 20.5, -6.2, -4.7, 5.6, "armour")
    for y in (2.0, 4.6):
        f.side(head, 14.0, 15.2, 2.0, 3.2, y - 0.6, y + 0.6, "armour")
    for h in (-3.6, -0.4):
        f.side(head, 14.0, 15.2, h - 0.6, h + 0.6, 4.8, 6.0, "armour")
    # the brow plate: a slab over the crown, a second down the forehead, a keel up the middle, rivets
    f.box(head, -2.4, 6.4, 4.0, 6.6, 11.7, "armour")
    for p, q, tall, wide, colour in (((4.6, 5.4), (13.0, 2.6), 3.0, 14.1, "armour"), ((11.4, 3.4), (13.8, 2.5), 4.0, 15.2, "armour+"),
                                     ((-1.4, 7.0), (6.0, 6.6), 2.0, 3.4, "armour+"), ((5.4, 6.6), (14.6, 3.6), 2.2, 4.2, "iron")):
        head.beam(f.pt(*p), f.pt(*q), tall, wide, colour)
    for y in (4.0, 6.1):
        a = f.pt(9.6, 4.4, y)
        head.beam(a, at(a, unit(tuple(0.95 * n + 0.3 * v for n, v in zip(f.n, f.d))), 1.4), 1.5, 1.5, "iron", mirror=True)
    # the eye, deep under the plate
    f.side(head, 6.2, 11.5, -2.2, 2.4, 5.0, 7.25, "cream")
    f.side(head, 8.6, 12.0, -1.7, 2.0, 5.7, 7.75, "black")
    f.side(head, 9.4, 10.4, -0.6, 0.4, 6.2, 8.0, "cream")
    f.slab(head, (3.4, 3.7), (12.6, 0.9), 2.2, 4.6, 8.2, "iron")
    # the horns
    # the crest: two iron-tipped blades on the crown
    for p, q, wide, thick in (((2.4, 5.0), (-2.6, 11.4), 4.4, 3.0), ((-0.8, 4.6), (-6.0, 8.6), 3.8, 1.9)):
        a, b = f.pt(*p), f.pt(*q)
        d = toward(a, b)
        head.beam(a, b, wide, thick, "armour")
        head.beam(at(b, d, -1.4), at(b, d, 0.8), wide + 0.9, thick + 0.8, "iron")
    for s in (1, -1):  # a curl in a plane turned 40 degrees outward, so it is a ram's horn from the front and the side
        turn = math.radians(40)
        back = tuple(-math.cos(turn) * v + s * math.sin(turn) * y for v, y in zip(f.d, (0.0, 1.0, 0.0)))
        out = cross(back, f.n)

        def spot(u, h):
            return tuple(o + u * e + h * n for o, e, n in zip(f.pt(5.0, 1.2, 4.6 * s), back, f.n))

        for k, size in enumerate(HORN_SIZE):
            p, q = spot(*HORN[k]), spot(*HORN[k + 1])
            d = toward(p, q)
            p, q = at(p, d, -0.25 * size if k else 0.0), at(q, d, 0.4 * HORN_SIZE[k + 1] if k < 4 else 0.0)
            wide = size - 0.35
            head._oriented(tuple((m + n) / 2 for m, n in zip(p, q)), d, cross(d, out), out, (math.dist(p, q), size, wide), ("iron", "iron", "bone-", "bone", "bone+")[k], False)
            if k < 2:
                head._oriented(at(q, d, -0.4), d, cross(d, out), out, (1.5, size + 0.8, wide + 0.7), "armour", False)
        d = toward(spot(*HORN[4]), spot(*HORN[5]))
        tip = spot(3.0, -0.4)
        spike(head, at(spot(*HORN[5]), d, -0.5), toward(spot(*HORN[5]), tip), 2.0, 0.0, 5.0, "bone+")


def shields(m):
    for s, tag in ((1, "R"), (-1, "L")):
        fin = m.part("Fin" + tag, (-8.0, 10.0 * s, 33.0), "Body")
        fin.beam((-5.0, 8.0 * s, 31.6), (-5.2, 13.0 * s, 29.6), 5.0, 4.6, "body-")
        f = Frame(-5.2, 28.8, 10)
        for a0, a1, h0, h1, y0, y1, colour in ((-4.2, 4.2, -3.6, 5.2, 12.4, 14.0, "blanket"), (-3.0, 3.0, -6.4, -2.6, 12.7, 13.7, "armour-"),
                                               (-4.9, 4.9, 4.2, 6.2, 12.1, 14.4, "armour+"), (-1.7, 1.7, -1.2, 2.2, 13.2, 15.2, "iron")):
            f.side(fin, a0, a1, h0, h1, y0 * s, y1 * s, colour, mirror=False)


def fan(m):
    part = m.part("Fan", (9, 0, 41), "Body")
    for y, way, length, wide, thick, colour in ((0.0, (0.3, 0, 1), 11.0, 5.4, 2.0, "armour"), (2.6, (0.34, 0.6, 1), 10.4, 4.6, 1.5, "ring-")):
        w, b = unit(way), (8.6, y, 38.4)
        thin, across = square_to(w, (1.0, 0.0, 0.0))
        part._oriented(at(b, w, length / 2), w, across, thin, (length, wide, thick), colour, y > 0)
        part._oriented(at(b, w, length - 0.6), w, across, thin, (2.2, wide + 0.8, thick + 0.8), "tip", y > 0)


def tail(m):
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = toward(a, b)
        part = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        end = at(b, d, 0.3 * TAIL_SIZE[k + 1] if k < 5 else 1.0)
        part.beam(at(a, d, -0.2 * size), end, size, size, "body")
        part.beam(at(end, d, -2.4), at(end, d, 0.4), size + 1.5, size + 1.5, "ring" if k % 2 == 0 else "ring-")
    u = toward(TAIL[5], TAIL[6])  # the mace
    n, y, q = (-u[2], 0.0, u[0]), (0.0, 1.0, 0.0), at(TAIL[6], u, 5.0)
    part._oriented(q, u, y, n, (9.0, 9.0, 9.0), "iron", False)
    part._oriented(at(q, u, 4.0), u, y, n, (2.2, 10.0, 10.0), "armour-", False)
    for way in (y, (0.0, -1.0, 0.0), n, tuple(-i for i in n)):
        spike(part, q, way, 3.6, 5.0, 4.2, "fin", ref=u)
    spike(part, q, u, 3.8, 5.1, 4.4, "fin")
    for i in (1, -1):
        for j in (1, -1):
            spike(part, q, tuple(a + i * b + j * e for a, b, e in zip(u, y, n)), 2.8, 5.4, 6.0, "fin")


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 29), "Stand")
    trunk(body)
    for s in SHELLS:
        shell(body, *s)
    saddle(body)
    neck_and_head(m)
    shields(m)
    fan(m)
    tail(m)
