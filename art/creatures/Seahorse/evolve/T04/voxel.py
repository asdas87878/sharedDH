"""Seahorse rocker, level 4 "Racer" (docs/style/13-seahorse-evolution.md): a seahorse stretched into a speedster. The whole
trunk leans 12 degrees nose-down and tapers to both ends in plan (whole blocks turned), the neck is thrust forward, the head is
a long flat-topped dart with a gold goggle brow, and everything lies back: the crest, the mane, two pairs of blade fins. Air
scoops on the shoulders, gold stripes down the back and the flanks, and for the fan a spoiler 21 wide with end plates that
carry its number. The tail streams straight back, then curls."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 4
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW, LIGHTS = {}, []
FLOATING = ["Coil"]
FRAME, ORTHO = 3.4, 40.0
SWING = 10
SEAT = (3.0, 38.6, 3.8)

TAIL = ((12.0, 0, 31.4), (19.5, 0, 33.6), (26.6, 0, 33.2), (32.0, 0, 28.8), (33.0, 0, 22.0), (29.4, 0, 16.6), (23.4, 0, 16.6), (21.4, 0, 21.2), (24.6, 0, 23.6))
TAIL_SIZE = (8.4, 7.6, 6.8, 6.0, 5.2, 4.3, 3.4, 2.6)


def pose(parts, phase):
    """the head nods, the fins feather, the spoiler flexes, the tail follows"""
    parts["Neck"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = math.radians(3) * math.sin(phase - 1.2 + math.pi)
    parts["Fan"].rotation_euler.y = math.radians(2) * math.sin(phase - 0.8)
    for name, s, lag, amp in (("FinL", -1, 0.0, 7), ("FinR", 1, 0.0, 7), ("Fin2L", -1, 1.2, 6), ("Fin2R", 1, 1.2, 6)):
        parts[name].rotation_euler.x = s * math.radians(amp) * math.sin(phase - lag)
    for k, amp in enumerate((1, 1, 2, 2, 3, 3, 4, 5)):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians(amp) * math.sin(phase - 0.5 * (k + 1))


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def toward(a, b):
    return unit(tuple(j - i for i, j in zip(a, b)))


class Frame:
    """a leaning part of the animal: a runs to the nose, h out of its back, y to the side; `deg` nose-down"""

    def __init__(self, x, z, deg):
        r = math.radians(deg)
        self.o, self.d, self.n = (x, 0.0, z), (-math.cos(r), 0.0, -math.sin(r)), (-math.sin(r), 0.0, math.cos(r))

    def pt(self, a, h, y=0.0):
        return (self.o[0] + a * self.d[0] + h * self.n[0], y, self.o[2] + a * self.d[2] + h * self.n[2])

    def box(self, part, a0, a1, h0, h1, wide, colour):
        part._oriented(self.pt((a0 + a1) / 2, (h0 + h1) / 2), self.d, (0.0, 1.0, 0.0), self.n, (a1 - a0, wide, h1 - h0), colour, False)

    def side(self, part, a0, a1, h0, h1, y0, y1, colour):
        part._oriented(self.pt((a0 + a1) / 2, (h0 + h1) / 2, (y0 + y1) / 2), self.d, (0.0, 1.0, 0.0), self.n, (a1 - a0, y1 - y0, h1 - h0), colour, True)

    def yaw(self, part, a0, y0, a1, y1, h0, h1, thick, colour):
        """a box turned in plan: its outer face runs from (a0, y0) to (a1, y1), `thick` deep inward; both sides"""
        n = math.hypot(a1 - a0, y1 - y0)
        ca, sy = (a1 - a0) / n, (y1 - y0) / n
        along = tuple(ca * d + sy * y for d, y in zip(self.d, (0.0, 1.0, 0.0)))
        out = tuple(-sy * d + ca * y for d, y in zip(self.d, (0.0, 1.0, 0.0)))
        if out[1] < 0:
            out = tuple(-v for v in out)
        mid = at(self.pt((a0 + a1) / 2, (h0 + h1) / 2, (y0 + y1) / 2), out, -thick / 2)
        part._oriented(mid, along, out, self.n, (n, thick, h1 - h0), colour, True)

    def slab(self, part, p0, p1, tall, y0, y1, colour):
        """a box lying in the side view between (a, h) points p0 and p1, `tall` across, from y0 to y1 out; both sides"""
        a, b = self.pt(*p0, (y0 + y1) / 2), self.pt(*p1, (y0 + y1) / 2)
        u = toward(a, b)
        part._oriented(tuple((i + j) / 2 for i, j in zip(a, b)), u, (0.0, 1.0, 0.0), (-u[2], 0.0, u[0]), (math.dist(a, b), y1 - y0, tall), colour, True)


TRUNK, HEAD = Frame(0.0, 29.2, 12), Frame(-15.8, 41.2, 10)


def trunk(body):
    body.sym(-6, 7, 6, 20, 22, "ring")  # the spring's plate, level
    body.sym(-5, 6, 5, 22, 25, "ring-")
    t = TRUNK
    # the barrel, and both ends tapering in plan
    t.box(body, -8, 8, -6.6, 7, 11.6, "body")
    t.box(body, -8.4, 8.4, -4.2, 4.0, 15, "body")
    t.box(body, 7, 14.2, -5.6, 6.0, 8.6, "body")
    t.box(body, -16.4, -7, -5.2, 6.2, 8.6, "body")
    t.yaw(body, 7.6, 7.45, 16.0, 4.6, -3.8, 3.6, 4.2, "body")
    t.yaw(body, -7.6, 7.45, -19.0, 4.2, -3.8, 3.6, 4.0, "body")
    t.box(body, 12, 17.0, -3.2, 4.2, 7, "body")
    # the pale keel
    t.box(body, -7.7, 7.7, -7.4, -4.8, 10.5, "belly")
    t.box(body, 7, 14.6, -6.2, -3.4, 7.6, "belly")
    t.box(body, -16.0, -7, -6.1, -3.4, 7.4, "belly")
    t.box(body, 12.0, 17.5, -4.1, -1.2, 5.4, "belly")
    # the gold: a stripe along each flank, and one down the back
    t.side(body, -8.6, 8.6, 0.3, 3.2, 6.6, 7.95, "ring")
    t.yaw(body, 7.9, 7.85, 16.4, 4.95, 0.5, 3.0, 1.4, "ring")
    t.yaw(body, -7.9, 7.85, -19.4, 4.55, 0.5, 3.0, 1.4, "ring")
    t.box(body, -8.3, 8.3, 6.2, 7.4, 3, "ring")
    t.box(body, -17.0, -7.5, 5.4, 6.6, 2.7, "ring")
    # the air scoops on the shoulders, and the gills behind them
    t.yaw(body, 3.6, 7.2, 12.0, 5.7, 2.6, 6.6, 3.4, "body+")
    t.yaw(body, 8.0, 6.0, 12.4, 5.2, 3.5, 5.6, 2.2, "saddle-")
    for a in (3.4, 1.2, -1.0):
        t.slab(body, (a, -3.4), (a - 1.0, -0.4), 1.0, 6.8, 7.9, "body-")


def seat(body):
    body.block(-0.6, (-3.7, 3.7, 34.6, 38.6), 6.4, (-3.7, 3.7, 34.6, 38.6), "saddle")
    body.beam((3.0, 3.2, 37.6), (3.0, 7.5, 35.6), 5.0, 1.3, "saddle", mirror=True)
    body.beam((3.0, 6.9, 36.2), (3.0, 7.9, 29.6), 4.4, 1.2, "saddle-", mirror=True)
    body.beam((3.0, 7.7, 30.6), (3.0, 8.2, 26.8), 2.4, 0.7, "ring", mirror=True)  # the stirrup
    body.beam((0.9, 0, 36.0), (-1.8, 0, 40.2), 2.2, 5.8, "saddle-")
    body.beam((5.6, 0, 37.4), (8.6, 0, 42.6), 2.0, 8.0, "saddle-")  # the bucket seat's back
    body.beam((8.2, 0, 41.8), (8.9, 0, 43.2), 2.6, 8.6, "ring")


def neck_and_head(m):
    neck = m.part("Neck", (-8, 0, 32), "Body")
    p, q, r = (-5.6, 0, 29.6), (-12.6, 0, 36.0), (-19.0, 0, 41.0)
    neck.beam(p, q, 10.0, 9.2, "body")
    neck.beam(at(q, unit((6.4, 0, -5.0)), 2.4), r, 8.6, 8.0, "body")
    d = toward(p, q)
    under = (d[2], 0.0, -d[0])
    under = under if under[2] < 0 else tuple(-v for v in under)
    neck.beam(at(at(p, d, 4.0), under, 4.6), at(at(r, d, -2.6), under, 3.7), 1.6, 5.4, "belly")
    neck.beam(at(q, d, -1.2), at(q, d, 0.6), 11.2, 10.4, "ring")
    # the mane: one blade lying back along the neck
    base, w = (-11.0, 0, 37.0), unit((0.8, 0, 0.6))
    neck.beam(base, at(base, w, 7.0), 4.4, 3.4, "fin")
    neck.beam(at(base, w, 5.6), at(base, w, 8.4), 3.4, 2.7, "tip")

    head, f = m.part("Head", (-16.0, 0, 40.2), "Neck"), HEAD
    f.box(head, -1.6, 9.0, -4.6, 3.7, 10, "body")  # the skull
    f.side(head, 0.2, 6.6, -4.1, -0.9, 4.0, 5.8, "body-")  # the jowls
    f.box(head, 0.6, 8.0, -5.6, -3.6, 7.4, "belly")
    f.box(head, 8.0, 14.6, -2.9, 3.1, 6.6, "body")  # the snout, flat on top
    f.box(head, 13.6, 19.0, -2.0, 2.6, 4.8, "body")
    f.box(head, 18.2, 20.8, -2.6, 3.0, 6.2, "tip")
    f.box(head, 20.0, 21.2, -1.5, 1.6, 4.0, "saddle-")  # the mouth's hole
    f.box(head, 8.2, 14.0, -3.5, -1.6, 4.4, "belly")
    f.box(head, -1.2, 8.6, 3.0, 4.1, 2.8, "ring")  # the stripe runs on to the nose
    f.box(head, 8.2, 14.2, 2.4, 3.55, 2.4, "ring")
    f.box(head, 13.8, 18.4, 1.9, 2.8, 2.0, "ring")
    # the eye, turned a third forward so the pair glares past the snout, and the goggles' brow lying on it
    def eye(t0, t1, h0, h1, out, thick, colour):
        (a0, y0), (a1, y1) = (3.0, 8.0), (9.6, 4.5)
        p = [(a0 + (a1 - a0) * t + 0.469 * out, y0 + (y1 - y0) * t + 0.883 * out) for t in (t0, t1)]
        f.yaw(head, *p[0], *p[1], h0, h1, thick, colour)

    eye(-0.05, 0.94, -3.5, -2.0, 0.28, 4.4, "body-")
    eye(0.0, 1.0, -2.6, 2.7, 0.0, 4.2, "cream")
    eye(0.36, 0.92, -2.15, 1.9, 0.5, 2.6, "black")
    eye(0.5, 0.68, 0.1, 1.2, 0.95, 2.0, "cream")
    head.beam(f.pt(0.2, 4.6, 8.4), f.pt(12.2, 1.2, 1.5), 3.0, 2.2, "ring", flat="z", mirror=True)
    f.slab(head, (8.6, 1.6), (11.4, 1.1), 1.7, 2.4, 4.7, "ring")
    f.slab(head, (0.7, 3.4), (0.7, -3.0), 1.6, 3.9, 5.25, "saddle")  # the strap
    # the crest: a tall blade swept flat back from the crown, and a lower one each side of it
    for y, base, way, length, wide, thick, colour in ((0.0, (4.4, -0.6), (0.8, 0, 0.6), 14.5, 5.0, 2.2, "body"), (3.1, (3.0, 0.2), (0.93, 0.2, 0.3), 10.6, 4.0, 1.5, "fin")):
        b, w = f.pt(*base, y), unit(way)
        head.beam(b, at(b, w, length), wide, thick, colour, mirror=y > 0)
        head.beam(at(b, w, length - 4.4), at(b, unit((way[0], way[1], way[2] - 0.12)), length + 2.6), wide - 1.4, thick - 0.5, "tip", mirror=y > 0)
    b, w = f.pt(1.0, -2.2, 4.0), unit((0.88, 0.46, -0.1))  # the cheek fin
    head.beam(b, at(b, w, 8.0), 4.2, 1.3, "fin", mirror=True)
    f.side(head, 18.8, 20.0, 1.9, 3.4, 0.9, 2.0, "ring-")


def fins(m):
    """two pairs of blades, swept back and rolled, so they show from the side, the front and above"""
    for name, roll, root, mid, tip, wide in (("Fin", 34, (-11.0, 1.2, 27.6), (-4.0, 9.4), (5.4, 11.6), 7.6),
                                       ("Fin2", -28, (6.4, 3.4, 29.6), (14.0, 9.4), (21.8, 11.4), 6.6)):
        for s, tag in ((1, "R"), (-1, "L")):
            slope = math.tan(math.radians(roll))
            r, k, e = ((p[0], p[1] * s, root[2] - slope * (p[1] - root[1])) for p in (root, mid, tip))
            fin = m.part(name + tag, at(r, toward(r, k), 3.0), "Body")

            def blade(p, q, w, thick, colour):
                u = toward(p, q)
                ref = (0.0, math.sin(math.radians(roll)) * s, math.cos(math.radians(roll)))
                dot = sum(i * j for i, j in zip(u, ref))
                thin = unit(tuple(i - dot * j for i, j in zip(ref, u)))
                wide_way = (u[1] * thin[2] - u[2] * thin[1], u[2] * thin[0] - u[0] * thin[2], u[0] * thin[1] - u[1] * thin[0])
                fin._oriented(tuple((i + j) / 2 for i, j in zip(p, q)), u, wide_way, thin, (math.dist(p, q), w, thick), colour, False)

            blade(r, k, wide, 2.2, "body-")
            u = toward(k, e)
            blade(at(k, u, -1.3), e, wide - 2.2, 1.5, "fin")
            blade(at(e, u, -3.4), at(e, u, 1.6), wide - 3.2, 0.9, "tip")


def spoiler(m):
    fan = m.part("Fan", (12, 0, 37), "Body")
    f = Frame(16.4, 46.8, 10)
    for s in (1, -1):
        a, b = (9.0, 2.6 * s, 32.6), (15.9, 5.4 * s, 45.8)
        fan.beam(a, b, 3.6, 1.6, "ring")
    f.box(fan, -3.4, 3.6, -0.75, 0.75, 20.4, "body")
    f.box(fan, -4.4, -2.2, -0.3, 1.7, 19.6, "ring")  # the trailing edge, kicked up
    f.box(fan, 2.8, 4.2, -0.45, 0.45, 19.6, "fin")
    f.side(fan, -5.2, 4.4, -3.0, 3.4, 9.6, 10.9, "body-")  # the end plates
    f.side(fan, -4.4, 3.6, -2.2, 2.6, 10.2, 11.2, "fin")
    for s in (1, -1):  # the number, the right way round on both sides
        for a0, a1, h0, h1 in ((-1.2, -0.1, -2.0, 2.4), (-1.8, 2.3, -0.95, 0.05), (1.0, 2.0, -0.6, 2.4)):
            a0, a1 = (a0, a1) if s < 0 else (-a1 - 0.8, -a0 - 0.8)
            dy = 0.0 if h1 - h0 > 3 else 0.2 if h1 - h0 > 2 else 0.4
            fan._oriented(f.pt((a0 + a1) / 2, (h0 + h1) / 2, s * (11.2 + dy / 2)), f.d, (0.0, 1.0, 0.0), f.n, (a1 - a0, 0.6 + dy, h1 - h0), "black", False)


def tail(m):
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = toward(a, b)
        part = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        end = at(b, d, 0.42 * TAIL_SIZE[k + 1]) if k < 7 else b
        part.beam(at(a, d, -0.2 * size if k else -2.0), end, size, size - (0.35 if k == 0 else 0), "body")
        if k < 5:
            inner = (d[2], 0.0, -d[0])
            p, q = at(a, inner, size / 2 - 0.4), at(end, inner, size / 2 - 0.4)
            part.beam(at(p, d, 3.0 if k == 0 else 1.2), at(q, d, -1.0), 1.4, size - 2.8, "belly")
        if k == 6:
            continue
        cap = ("ring", 1.2, 1.0) if k < 6 else ("tip", 2.2, 0.5)
        part.beam(at(end, d, -cap[1]), at(end, d, 0.35 if k < 6 else 1.6), size + cap[2], size + cap[2], cap[0])


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 25), "Stand")
    trunk(body)
    seat(body)
    neck_and_head(m)
    fins(m)
    spoiler(m)
    tail(m)
