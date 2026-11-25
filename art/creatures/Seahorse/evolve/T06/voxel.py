"""Seahorse rocker, level 6 "Spiked" (docs/style/13-seahorse-evolution.md): a seadragon. A long body bent like a bow over its
spring, the neck rising out of the low chest in an S, a hooked beak under a heavy brow with a sharp red eye patch, and spikes
everywhere, silver with red points: a fan of five over the head, seven down the back (the tallest in a fan behind the seat),
four pairs swept back from the flanks, one on every block of the tail. Red torn leaf flags on four of them; the tail curls
under to a fork of two blades."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 6
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
PALETTE.update({"leaf": "#B4232F"})  # the torn leaves: a deeper red than the points, so they read apart from them
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW, LIGHTS = {}, []
FLOATING = ["Coil"]
FRAME, ORTHO = 3.4, 40.0
SWING = 10
SEAT = (2.6, 40.2, 3.6)

NECK = ((-12.6, 0, 26.8), (-20.0, 0, 33.0), (-23.4, 0, 41.2), (-21.6, 0, 49.4))
NECK_SIZE = (10.6, 9.4, 8.2)
NECK_WIDE = (9.6, 8.7, 7.8)
TAIL = ((12.4, 0, 27.6), (18.4, 0, 27.2), (23.8, 0, 28.0), (28.0, 0, 25.4), (29.2, 0, 20.0), (27.0, 0, 15.2), (22.4, 0, 13.4), (18.8, 0, 16.0), (20.2, 0, 19.6))
TAIL_SIZE = (8.8, 7.8, 6.9, 6.0, 5.1, 4.2, 3.4, 2.7)
TAIL_SPIKE = (6.6, 7.4, 5.6, 3.6, 3.4, 3.2, 3.0, 0)


def pose(parts, phase):
    """the head strikes a little, the beak opens, the fan and the side spikes bristle, the tail follows"""
    parts["Neck"].rotation_euler.y = math.radians(2) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.2 + math.pi)
    parts["Jaw"].rotation_euler.y = math.radians(-4) * (0.5 + 0.5 * math.sin(phase))
    parts["Fan"].rotation_euler.y = math.radians(3) * math.sin(phase - 0.8)
    for name, s in (("FinL", -1), ("FinR", 1)):
        parts[name].rotation_euler.x = s * math.radians(4) * math.sin(phase)
    for k, amp in enumerate((1, 1, 2, 2, 3, 3, 4, 5)):
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


def frustum(part, q, way, length, s0, s1, colour, ref=(0.0, 1.0, 0.0), mirror=False):
    """a tapered square shaft from q along `way`, s0 across at its root and s1 at its end"""
    w = unit(way)
    p1, p2 = square_to(w, ref if abs(sum(i * j for i, j in zip(w, ref))) < 0.9 else (1.0, 0.0, 0.0))
    verts = []
    for d, size in ((0.0, s0), (length, s1)):
        h = size / 2
        verts += [tuple(o + d * a + i * h * b + j * h * e for o, a, b, e in zip(q, w, p1, p2)) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    part.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour, mirror)


def point(part, q, way, size, long, colour, ref=(0.0, 1.0, 0.0), mirror=False):
    """a pyramid from q along `way`"""
    w = unit(way)
    p1, p2 = square_to(w, ref if abs(sum(i * j for i, j in zip(w, ref))) < 0.9 else (1.0, 0.0, 0.0))
    h = size / 2
    base = [tuple(o + i * h * b + j * h * e for o, b, e in zip(q, p1, p2)) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    part.spike(base, at(q, w, long), colour, mirror)


def thorn(part, q, way, size, tall, then=None, mirror=False, colour="armour"):
    """a silver spike with a red barb for a point, `tall` from q (inside its host); `then`: it bends that way half up"""
    w = unit(way)
    if then is None:
        shaft = 0.62 * tall
        frustum(part, q, w, shaft, size, size * 0.5, colour, mirror=mirror)
        end, last, w2 = at(q, w, shaft), size * 0.5, w
    else:
        w2 = unit(then)
        mid = at(q, w, 0.4 * tall)
        frustum(part, q, w, 0.4 * tall, size, size * 0.8, colour, mirror=mirror)
        frustum(part, at(mid, w2, -1.0), w2, 0.26 * tall + 1.0, size * 0.62, size * 0.44, colour + "+" if colour == "armour" else colour, mirror=mirror)
        end, last = at(mid, w2, 0.26 * tall), size * 0.44
    point(part, at(end, w2, -0.8), w2, last + 0.9, tall * 0.36 + 0.8, "tip", mirror=mirror)


def flag(part, q, along, mirror=False):
    """a torn leaf, about 7 by 4, flying from q (inside a spike's shaft)"""
    u = unit(along)
    hang, thin = square_to(u, (0.0, 0.0, -1.0))
    for turn, long, tall, thick, colour in ((-0.2, 8.6, 2.0, 0.7, "leaf"), (0.12, 6.6, 2.2, 1.05, "leaf-"), (0.44, 7.6, 1.8, 0.4, "leaf")):
        w = unit(tuple(a + turn * b for a, b in zip(u, hang)))
        part._oriented(at(q, w, long / 2), w, cross(thin, w), thin, (long, tall, thick), colour, mirror)


HEAD = Frame(-17.9, 51.2, 22)
A, B = Frame(-5.4, 29.5, 15), Frame(-12.4, 27.5, 33)  # the bow's front half, then its rear half (a runs to the nose)
C = Frame(5.4, 29.5, -13)


def trunk(body):
    body.hull(-7, 8, 6, 22, 37, "body", [(2, 2)])
    body.paint_sym(-7, 8, 6, 22, 25, "belly")
    body.paint_sym(-5, 6, 5, 22, 23, "ring-")  # where the spring is bolted on
    # the bow: two bent lengths in front, one behind
    for f, a0, a1, w, d in ((A, -2.0, 8.4, 12.5, 14.4), (B, -2.0, 6.4, 11.7, 13.4), (C, -9.4, 2.0, 12.5, 14.0)):
        f.box(body, a0, a1, -d / 2 + 2.0, d / 2 - 2.2, w, "body")
        f.box(body, a0 - 0.3, a1 + 0.4, -d / 2 + 0.4, d / 2, w - 4.2, "body")
        f.box(body, a0 + 0.5, a1 - 0.6, -d / 2 - 0.2, -d / 2 + 3.4, w - 2.2, "belly")
    # the armour rings: each a pair of crossed plates, its back's plate standing up
    for f, a, w, d, wide in ((A, 1.2, 12.5, 14.4, 2.4), (A, 6.9, 12.5, 14.4, 2.4), (C, -1.2, 12.5, 14.0, 2.4), (C, -7.8, 12.5, 14.0, 2.4)):
        f.box(body, a - wide / 2 - 0.3, a + wide / 2 + 0.3, d / 2 - 1.6, d / 2 + 0.9, w - 2.6, "ring")
        f.roll(body, a - wide / 2, a + wide / 2, d / 2 - 1.5, w / 2 - 1.3, 45, 4.6, 2.2, "ring-")
        f.side(body, a - wide / 2 - 0.15, a + wide / 2 + 0.15, -d / 2 + 2.6, d / 2 - 2.4, w / 2 - 1.2, w / 2 + 0.8, "ring")
    # the breast plate
    for a, h, w, colour in ((6.2, 0.2, 8.8, "armour"), (5.4, -4.6, 8.0, "armour-")):
        B.box(body, a, a + 1.9, h - 3.2, h + 3.0, w, colour)
    # the shoulder's spike and the loin's, out of the rings
    thorn(body, A.pt(7.2, 5.0), (0.0, 0, 1), 4.2, 11.5, (0.3, 0, 1))
    thorn(body, C.pt(-7.6, 5.0), (0.2, 0, 1), 3.7, 14.0, (0.5, 0, 1))
    flag(body, at(C.pt(-7.6, 5.0), unit((0.3, 0, 1)), 5.9), (1, 0, -0.06))
    # the flanks' other spikes, swept back
    thorn(body, A.pt(1.2, -0.6, 4.0), (0.6, 1, 0.12), 3.3, 11.5, mirror=True)
    thorn(body, C.pt(-1.2, -0.8, 4.0), (0.5, 1, 0.1), 3.3, 12.0, mirror=True)
    thorn(body, C.pt(-7.8, -0.4, 4.0), (0.9, 1, 0.25), 3.6, 16.0, mirror=True)


def saddle(body):
    body.block(-2.4, (-5.6, 5.6, 35.6, 38.4), 7.0, (-5.6, 5.6, 35.6, 38.4), "blanket")
    body.block(-1.6, (-3.6, 3.6, 37.2, 40.2), 6.2, (-3.6, 3.6, 37.2, 40.2), "saddle")
    body.beam((2.3, 4.8, 38.2), (2.3, 7.8, 34.6), 8.8, 1.4, "blanket", mirror=True)
    body.beam((2.3, 7.1, 35.6), (2.3, 7.3, 29.0), 8.4, 1.3, "blanket-", mirror=True)
    body.beam((2.4, 2.8, 39.6), (2.4, 7.4, 36.2), 5.0, 1.2, "saddle", mirror=True)
    body.beam((2.4, 7.5, 36.8), (2.4, 8.0, 31.0), 3.0, 1.2, "saddle-", mirror=True)
    body.beam((2.4, 7.9, 31.8), (2.4, 8.2, 28.8), 4.0, 1.8, "armour", mirror=True)
    body.beam((-1.2, 0, 39.2), (-2.6, 0, 42.4), 2.2, 5.0, "saddle-")
    body.beam((-2.1, 0, 41.8), (-2.8, 0, 43.2), 2.9, 5.7, "armour")
    body.beam((5.6, 0, 39.0), (7.0, 0, 43.2), 1.9, 7.9, "saddle-")
    body.beam((6.7, 0, 42.4), (7.2, 0, 43.8), 2.6, 8.7, "armour")


def neck_and_head(m):
    neck = m.part("Neck", (-14, 0, 28.4), "Body")
    for k, size in enumerate(NECK_SIZE):
        a, b = NECK[k], NECK[k + 1]
        d = toward(a, b)
        front = (-d[2], 0.0, d[0])
        end = at(b, d, 0.36 * NECK_SIZE[k + 1] if k < 2 else 1.2)
        neck.beam(at(a, d, -0.25 * size if k else -1.0), end, size, NECK_WIDE[k], "body")
        for i in range(2):  # the throat's plates, each a step under the next
            n = math.dist(a, end)
            lo, hi = (0.05, 0.5) if i == 0 else (0.44, 0.9)
            q = at(a, front, size / 2 - 1.2 - 0.2 * i)
            neck.beam(at(q, d, n * lo + (4.4 if k == 0 and i == 0 else 0)), at(q, d, n * hi), 4.0, ((7.0, 6.7), (6.2, 5.8), (5.0, 4.7))[k][i], "belly" if i == 0 else "belly-")
        if k < 2:
            neck.beam(at(end, d, -1.6), at(end, d, 0.5), size + 1.5, size + 0.6, "ring" if k == 0 else "ring-")
        back = tuple(-v for v in front)
        q = at(at(a, d, (0.6, 0.55, 0.55)[k] * math.dist(a, b)), back, size / 2 - 1.4)
        if k:
            lean = unit(tuple(i + 0.15 * j for i, j in zip(back, (0, 0, 1))))
            thorn(neck, q, lean, (0, 4.0, 3.2)[k], (0, 12.5, 13.0)[k], unit(tuple(i + j for i, j in zip(back, (0, 0, (0, 0.45, 1.2)[k])))))

    head, f = m.part("Head", (-21.4, 0, 49.8), "Neck"), HEAD
    f.box(head, -4.2, 10.0, -4.8, 4.4, 9.4, "body")
    f.box(head, -2.6, 7.0, 3.0, 6.0, 6.4, "body-")  # the crown
    f.box(head, -3.0, 7.6, -5.4, -3.6, 7.0, "belly")
    f.side(head, -3.9, 2.4, -4.6, 2.6, 3.6, 5.5, "body-")  # the cheeks
    # the beak: two bent lengths and a hook
    for p, q, tall, wide, colour in (((8.0, 0.6), (16.4, 0.0), 6.0, 7.2, "armour"), ((15.0, 0.5), (21.4, -2.2), 4.7, 5.8, "armour")):
        head.beam(f.pt(*p), f.pt(*q), tall, wide, colour)
    head.beam(f.pt(20.0, -1.2), f.pt(22.6, -5.0), 3.7, 4.6, "armour-")
    point(head, f.pt(21.7, -3.8), tuple(-0.12 * v - n for v, n in zip(f.d, f.n)), 2.8, 6.0, "spike")
    f.side(head, 13.4, 16.4, 0.5, 1.7, 2.6, 3.95, "black")  # the nostril
    jaw = m.part("Jaw", f.pt(6.0, -3.4), "Head")
    jaw.beam(f.pt(5.0, -3.6), f.pt(16.4, -6.4), 2.6, 5.4, "armour-")
    point(jaw, at(f.pt(16.4, -6.4), toward(f.pt(5.0, -3.6), f.pt(16.4, -6.4)), -1.2), toward(f.pt(16.4, -6.4), f.pt(19.6, -5.0)), 2.2, 4.4, "armour")
    f.box(jaw, 5.4, 11.6, -4.2, -2.6, 4.4, "black")  # the dark of the mouth
    # the red patch, the eye in it, the brow over it
    def eye(t0, t1, h0, h1, out, thick, colour):  # in a plane turned a third forward, so the pair shows past the beak
        (a0, y0), (a1, y1) = (0.4, 8.2), (10.2, 4.9)
        p = [f.pt(a0 + (a1 - a0) * t + 0.319 * out, (h0 + h1) / 2, y0 + (y1 - y0) * t + 0.948 * out) for t in (t0, t1)]
        u = toward(*p)
        w = cross(u, f.n)
        o = tuple((m + n) / 2 for m, n in zip(*p))
        w = w if w[1] > 0 else tuple(-v for v in w)
        head._oriented(at(o, w, -thick / 2), u, w, f.n, (math.dist(*p), thick, h1 - h0), colour, True)

    eye(-0.05, 1.0, -3.4, 2.8, 0.0, 4.6, "tip")
    way = tuple(0.55 * y - v + 0.1 * n for n, v, y in zip(f.n, f.d, (0.0, 1.0, 0.0)))
    thorn(head, f.pt(-1.6, -2.6, 4.0), way, 3.0, 11.0, mirror=True)  # the cheeks' spikes
    eye(0.36, 0.9, -1.5, 2.2, 0.45, 2.4, "cream")
    eye(0.54, 0.86, -1.1, 1.8, 0.85, 2.0, "black")
    eye(0.66, 0.77, 0.3, 1.2, 1.25, 1.6, "cream")
    f.slab(head, (-2.4, 5.2), (10.6, 2.0), 2.8, 2.4, 6.4, "armour")
    f.slab(head, (8.8, 2.2), (12.6, 1.4), 2.0, 2.2, 5.6, "armour-")
    f.box(head, 7.2, 13.0, 2.4, 4.6, 3.6, "armour-")  # the keel between the brows
    # the crest: five spikes fanned
    for deg, tall, size in ((0, 14.0, 3.6), (32, 12.4, 3.3), (64, 10.0, 3.0)):
        r = math.radians(deg)
        way = tuple(math.cos(r) * (0.8 * n - 0.6 * v) + math.sin(r) * y for n, v, y in zip(f.n, f.d, (0.0, 1.0, 0.0)))
        thorn(head, f.pt(-0.6, 3.0, 2.6 * math.sin(r)), way, size, tall, mirror=deg > 0)


def fan(m):
    part = m.part("Fan", (9.6, 0, 34), "Body")
    w, q = unit((0.24, 0.0, 1.0)), (9.8, 0.0, 32.4)
    thin = (w[2], 0.0, -w[0])
    thorn(part, q, w, 5.0, 20.5, (0.5, 0, 1))
    for s in (1,):
        r = math.radians(43)
        way = tuple(math.cos(r) * a + math.sin(r) * b for a, b in zip(w, (0.0, 1.0, 0.0)))
        thorn(part, (9.8, 1.4, 32.6), way, 3.8, 17.0, mirror=True)
        r = math.radians(20)
        way = tuple(math.cos(r) * a + math.sin(r) * b for a, b in zip(w, (0.0, 1.0, 0.0)))
        across = cross(thin, way)
        part._oriented(at((9.8, 2.7, 32.4), way, 6.2), way, across, thin, (12.4, 4.6, 1.1), "fin", True)
    flag(part, at(at(q, w, 8.2), unit((0.5, 0, 1)), 3.2), (1, 0, 0.16))


def sides(m):
    """the front pair of side spikes, the longest, each with its leaf"""
    for s, tag in ((1, "R"), (-1, "L")):
        fin = m.part("Fin" + tag, (-12.0, 5.4 * s, 28.0), "Body")
        q, w = A.pt(7.2, -1.0, 4.2 * s), unit((0.55, 1.0 * s, 0.2))
        thorn(fin, q, w, 4.2, 17.6)
        flag(fin, at(q, w, 6.4), (1, 0.25 * s, -0.25))


def tail(m):
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = toward(a, b)
        part = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        end = at(b, d, 0.42 * TAIL_SIZE[k + 1]) if k < 7 else b
        part.beam(at(a, d, -0.2 * size if k else -2.0), end, size, size - (0.8 if k == 0 else 0.3), "body")
        outer = (-d[2], 0.0, d[0])
        if k < 5:
            p = at(a, outer, -size / 2 + 0.4)
            part.beam(at(p, d, 2.6 if k == 0 else 1.4), at(at(end, outer, -size / 2 + 0.4), d, -1.0), 1.4, size - 2.8, "belly")
        if k < 7:
            part.beam(at(end, d, -1.3), at(end, d, 0.35), size + 1.1, size + 1.0, "ring" if k % 2 else "ring-")
        if TAIL_SPIKE[k]:
            q = at(at(a, d, 0.5 * math.dist(a, b)), outer, size / 2 - 1.2)
            thorn(part, q, tuple(i + 0.45 * j for i, j in zip(outer, d)), max(1.9, size * 0.42), TAIL_SPIKE[k] + 1.2)
        if k == 7:  # the fork
            part._oriented(at(b, d, 0.2), d, (0.0, 1.0, 0.0), outer, (3.0, 3.6, 4.6), "ring", False)
            for s, tall in ((1, 4.8), (-1, 5.2)):
                thorn(part, at(at(b, d, 0.1), outer, 1.1 * s), tuple(i + 0.62 * s * j for i, j in zip(d, outer)), 2.2, tall)


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 27), "Stand")
    trunk(body)
    saddle(body)
    neck_and_head(m)
    fan(m)
    sides(m)
    tail(m)
