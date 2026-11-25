"""Level 12, Prismatic: the leviathan (docs/style/13-seahorse-evolution.md). One model of the evolved rockers: the frame, the
stand and the helpers are in common.py beside this folder. VARIANT rainbow: the skin ("body", "fin", "wing") takes one straight
rainbow from nose to tail; "core" (near-black indigo), "pearl", "ivory" and "maw" (the mouth's pink) are kept plain."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 12
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
PALETTE.update({"maw": "#FF6FB0", "mauve": "#B9A8E6", "shade": "#8673C4", "core": "#241A52"})
KEEP += ["maw", "mauve", "shade"]
globals().update(c.VARIANTS[LEVEL])
GLOW = dict(c.glow_of(LEVEL), halo=0.9)  # the eyes, the neck's lines, the corona's tips
LIGHTS = [("Head", (-56.0, 0, 73.0), "#FF6FB0", 260, 3.0)]
FLOATING = ["Coil"]
SHADE = 0.82
SWING = 6
SEAT = (6, 66, 5)


# ---------------------------------------------------------------- small geometry
def add(a, b, k=1.0):
    return tuple(i + k * j for i, j in zip(a, b))


def sub(a, b):
    return tuple(i - j for i, j in zip(a, b))


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
    """along a to b, the side nearest `ref`, and the third"""
    d = unit(sub(b, a))
    thin = unit(add(ref, d, -dot(ref, d)))
    return d, cross(thin, d), thin


def bar(p, a, b, wide, thick, colour, ref=(0, 1, 0), mirror=False):
    """a whole box from a to b, `thick` along ref, `wide` across"""
    d, w, t = axes(a, b, ref)
    p._oriented(mix(a, b, 0.5), d, w, t, (math.dist(a, b), wide, thick), colour, mirror)


def point(p, at, way, size, length, colour, ref=(0, 1, 0), sink=0.6, lean=(0, 0, 0), thick=None):
    """a pyramid of base `size` (by `thick`) at `at`, its point `length` on along `way`"""
    d = unit(way)
    t = unit(add(ref, d, -dot(ref, d)))
    w = cross(t, d)
    base = add(at, d, -sink)
    hw, ht = size / 2, (thick or size) / 2
    corners = [add(add(base, w, a * hw), t, b * ht) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    p.spike(corners, add(add(at, d, length), lean), colour)


def horn(p, at, way, size, length, root, tip, ref=(0, 1, 0), sink=1.6, split=0.6, thin=0.8):
    """a horn in two tones: a block drawn in from `size` at `at`, and a point on it"""
    d = unit(way)
    t = unit(add(ref, d, -dot(ref, d)))
    w = cross(t, d)

    def ring(s, r):
        mid = add(at, d, s)
        return [add(add(mid, w, a * r / 2), t, b * r / 2 * thin) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

    end = size * (1 - split * 0.82)
    p.solid(ring(-sink, size) + ring(length * split, end), [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], root)
    p.spike(ring(length * split - 0.6, end * 0.88), add(at, d, length * 1.06), tip)


def flip(v, side):
    return (v[0], v[1] * side, v[2])


def along(p, pts, sizes, colours, ref=(0, 1, 0), flat=1.0):
    """a run of boxes through pts, each starting inside the one before; `flat`: how thick along ref, as a share"""
    for k in range(len(sizes)):
        a, b = pts[k], pts[k + 1]
        if k:
            a = add(a, unit(sub(pts[k], pts[k - 1])), -0.5 * sizes[k - 1])
        bar(p, a, b, sizes[k], sizes[k] * flat, colours[k] if isinstance(colours, (list, tuple)) else colours, ref)


def plates(p, pts, wides, thick, colour, normal_of, tip=0.9, over=1.22, step=None):
    """overlapping plates laid along pts (x, z), each turned so its far edge stands proud of the next; normal_of: +1 or -1,
    which side of the line is out; step: the colour of a thinner shadow step under each one's lower edge"""
    for k, wide in enumerate(wides):
        a, b = (pts[k][0], 0.0, pts[k][1]), (pts[k + 1][0], 0.0, pts[k + 1][1])
        d = unit(sub(b, a))
        out = (-d[2] * normal_of, 0.0, d[0] * normal_of)
        b = add(a, sub(b, a), over)
        lo, hi = add(a, out, -0.2), add(b, out, tip)
        bar(p, lo, hi, wide, thick, colour, out)
        if step:
            run = unit(sub(hi, lo))
            bar(p, add(add(hi, run, -2.2), out, -0.2), add(add(hi, run, 1.7), out, -0.2), wide - 1.0, thick - 2.0, step, out)


# ---------------------------------------------------------------- the numbers
C = (43.8, 42.0)  # the middle of the curl, in the side view
TURN = (168, 205, 240, 275, 312, 350, 390, 432, 476, 522, 570, 622)
REACH = (30.0, 22.6, 20.4, 19.0, 17.2, 15.2, 13.2, 11.4, 9.6, 7.8, 5.8, 3.4)
TAIL = [(C[0] + r * math.cos(math.radians(a)), 0.0, C[1] + r * math.sin(math.radians(a))) for a, r in zip(TURN, REACH)]
THICK = (20.6, 19.4, 17.2, 15.4, 13.6, 12.0, 10.6, 9.4, 8.2, 7.0, 5.8)


def body(m):
    """the trunk: a whale's bulk in six slices, dark under, with the saddle's dip across it"""
    b = m.part("Body", (0, 0, 43), "Stand")
    soft, under = [(8, 3), (4, 4)], [(8, 4), (4, 4)]
    b.hull(-27, -21, 16, 38, 62, "body", [(5, 4)], [(6, 4)])
    b.hull(-21, -13, 20, 33, 68, "body", soft, under)
    b.hull(-13, 12, 22, 30, 70, "body", soft, [(9, 4), (4, 5)])
    b.hull(12, 20, 21, 32, 70, "body", soft, under)
    b.hull(20, 25, 18, 35, 67, "body", soft, [(7, 4), (3, 3)])
    b.hull(25, 29, 14, 38, 62, "body", [(5, 3)], [(5, 3)])
    b.carve(-9, 15, -30, 31, 64, 80)  # the dip
    b.paint_sym(-30, 30, 30, 28, 44, "core")
    # the pearl hoops: the seahorse's rings, short of the belly
    b.band(-11.6, -9.2, 22, 30, 70, "pearl", soft, [(9, 4), (4, 5)], proud=0.5, stop=44.5)
    b.band(16.2, 18.6, 21, 32, 70, "pearl", soft, under, proud=0.5, stop=44.5)
    b.band(21.4, 23.6, 18, 35, 67, "pearl", soft, [(7, 4), (3, 3)], proud=0.5, stop=44.5)
    # the chest: pearl scutes down the front and under to the spring
    plates(b, [(-27.4, 51.6), (-27.4, 45.4), (-23.0, 40.6), (-18.2, 35.4)], (27.6, 24.6, 19), 4.2, "pearl", -1, step="shade")
    for side in (1, -1):
        # the shoulder shells: three great lames a side, each over the next, each with a shadow step under its edge
        for cx, cy, cz, tilt, size in ((-17.4, 22.9, 51.4, 8, (12.4, 13.0, 3.2)), (-17.8, 20.4, 60.6, 32, (14.4, 12.6, 3.6)),
                                       (-18.2, 14.4, 67.4, 60, (16.4, 13.4, 4.0))):
            t = math.radians(tilt)
            out, down = (0.0, math.cos(t) * side, math.sin(t)), (0.0, math.sin(t) * side, -math.cos(t))
            b._oriented((cx, cy * side, cz), (1, 0, 0), down, out, size, "pearl", False)
            b._oriented(add(add((cx, cy * side, cz), down, size[1] / 2 - 0.4), out, -0.2), (1, 0, 0), down, out,
                        (size[0] - 1.6, 4.4, size[2] - 1.0), "shade", False)
        # a row of side scutes where the dark belly starts
        for x in (-7.4, 0.2, 7.8):
            t = math.radians(16)
            b._oriented((x, 22.4 * side, 44.6), (1, 0, 0), (0, math.sin(t) * side, -math.cos(t)), (0, math.cos(t) * side, math.sin(t)),
                        (7.0, 8.4, 2.8), "pearl", False)
        for x, y, wide in ((-8.2, 18.6, 8.2), (0.6, 18.9, 8.2), (9.1, 18.4, 8.2)):
            t = math.radians(46)
            b._oriented((x, y * side, 38.0), (1, 0, 0), (0, math.sin(t) * -side, -math.cos(t)), (0, math.cos(t) * side, -math.sin(t)),
                        (wide, 9.6, 3.4), "mauve", False)
    return b


def throne(b):
    """the howdah: a pearl platform in the dip, a seat with a back and arms, and a dark cloth over each flank"""
    b.sym(-5, 14, 10, 64, 66, "pearl")
    b.hull(11, 14, 5, 66, 75, "pearl", [(2, 2)])
    b.pair(4, 11, 6, 8, 66, 69, "pearl")
    b.paint_pair(4, 6, 6, 8, 68, 69, "mauve")
    for y in (3.9, -3.9):
        b.spike([(11.4, y - 1.4, 71.5), (13.6, y - 1.4, 71.5), (13.6, y + 1.4, 71.5), (11.4, y + 1.4, 71.5)], (12.8, y * 1.5, 83.0), "pearl")
    for side in (1, -1):
        def slab(x0, x1, y0, y1, z0, z1, colour):
            ya, yb = sorted((y0 * side, y1 * side))
            b.block(x0, (ya, yb, z0, z1), x1, (ya, yb, z0, z1), colour)

        slab(-2.4, 10.4, 9.0, 19.4, 63.4, 64.8, "core")
        slab(-2.6, 10.6, 17.0, 23.5, 62.2, 63.8, "core")
        slab(-2.2, 10.2, 21.6, 23.1, 54.0, 63.0, "core")
        slab(-2.8, 10.8, 21.4, 23.8, 52.4, 54.8, "pearl")
        b._oriented((4.0, 22.7 * side, 58.6), unit((1, 0, 1)), unit((-1, 0, 1)), (0, side, 0), (4.6, 4.6, 2.0), "pearl", False)


def neck(m):
    n = m.part("Neck", (-16, 0, 58), "Body")
    n.beam((-9, 0, 46), (-25, 0, 70), 26.4, 26.4, "body")
    n.beam((-21, 0, 63), (-31, 0, 86), 24.4, 24.4, "body")
    plates(n, [(-39.0, 74.5), (-36.6, 67.0), (-34.0, 60.4), (-30.2, 54.0), (-25.4, 47.0)], (20.4, 21.8, 23.2, 25.2), 4.0, "pearl", -1, step="shade")
    plates(n, [(-20.2, 90.4), (-16.8, 83.0), (-13.6, 76.2), (-9.2, 69.4)], (19, 20, 21), 3.4, "pearl", 1)
    for x, z, tall in ((-18.6, 88.0, 11), (-14.4, 80.2, 9), (-10.0, 72.8, 7)):
        point(n, (x, 0, z), (0.9, 0, 0.75), 4.6, tall, "pearl", thick=3.2, sink=2.0)
    for side in (1, -1):
        bar(n, (-13.5, 13.1 * side, 54.0), (-24.0, 13.1 * side, 69.8), 2.4, 1.2, "halo")
        bar(n, (-23.2, 12.1 * side, 66.0), (-29.0, 12.1 * side, 79.4), 2.4, 1.4, "halo")
    return n


def head(m):
    h = m.part("Head", (-28, 0, 80), "Neck")
    h.hull(-45, -24, 16, 80, 99, "body", [(7, 2), (3, 3)], [])
    h.hull(-41, -25, 14, 69, 80, "body", [], [(4, 3)])
    h.paint_sym(-41, -40, 12, 71, 80, "maw")
    h.beam((-40, 0, 89.4), (-59, 0, 87.2), 21.8, 14.2, "body", flat="z")
    h.beam((-54.5, 0, 87.0), (-67, 0, 84.0), 18.4, 11.4, "body", flat="z")
    h.beam((-61.0, 0, 86.0), (-70.4, 0, 83.6), 14.6, 8.2, "body", flat="z")  # the nose, under a pearl beak
    h.beam((-63.0, 0, 90.4), (-71.0, 0, 87.2), 9.4, 3.6, "pearl", flat="z")
    h.beam((-69.4, 0, 88.6), (-71.0, 0, 80.6), 5.8, 3.0, "pearl", flat="x")
    point(h, (-70.8, 0, 81.6), (-0.2, 0, -1), 4.8, 7.4, "pearl", (1, 0, 0), sink=2.4, thick=2.2)
    # the roof of the mouth, the gum's dark line and the upper teeth
    h.beam((-42, 0, 82.4), (-58.6, 0, 80.5), 20.6, 2.6, "core", flat="z")
    h.beam((-55.2, 0, 81.4), (-66.6, 0, 78.7), 17.2, 2.6, "core", flat="z")
    h.beam((-61.0, 0, 81.4), (-69.8, 0, 79.2), 13.0, 2.2, "core", flat="z")
    for x, y, z, size, length in ((-44.5, 8.4, 81.4, 3.6, 5.0), (-48.8, 8.2, 80.9, 4.0, 7.0), (-53.2, 8.2, 80.4, 4.0, 5.4),
                                  (-58.0, 6.6, 79.9, 4.2, 8.0), (-63.0, 6.2, 79.0, 4.8, 10.5), (-67.0, 4.4, 79.5, 3.4, 8.0)):
        h.tooth(x, y, z, size, length, "ivory")
    # the big eye, in a dark socket round the skull's front corner, so it looks to the side and to the front; a slit pupil.
    # Two smaller eyes behind it in the same row
    h.pair(-48, -40, 11, 18, 83, 92, "core")
    h.block(-48.5, (11.4, 16.6, 84.2, 90.4), -46.0, (11.4, 16.6, 84.2, 90.4), "halo", mirror=True)
    h.block(-49.0, (13.2, 14.9, 84.5, 90.1), -46.5, (13.2, 14.9, 84.5, 90.1), "black", mirror=True)
    h.block(-47.3, (16.0, 18.0, 84.0, 90.6), -41.0, (16.0, 18.0, 84.0, 90.6), "halo", mirror=True)
    h.block(-45.2, (16.5, 18.5, 84.3, 90.3), -43.0, (16.5, 18.5, 84.3, 90.3), "black", mirror=True)
    for x0, x1, z0, z1 in ((-38.2, -34.2, 84.8, 89.4), (-32.6, -29.6, 84.0, 87.4)):
        h.block(x0, (15.5, 17.1, z0, z1), x1, (15.5, 17.1, z0, z1), "halo", mirror=True)
        mid = (x0 + x1) / 2
        h.block(mid - 0.8, (16.0, 17.6, z0 + 0.4, z1 - 0.4), mid + 0.8, (16.0, 17.6, z0 + 0.4, z1 - 0.4), "black", mirror=True)
    # the brow: a heavy pearl bar, low in front, over the eye and back to the corona; plates on the snout, horns in a row
    for side in (1, -1):
        bar(h, (-52.0, 13.6 * side, 89.6), (-26.5, 14.6 * side, 94.6), 6.4, 4.2, "pearl", (0, 0, 1))
    h.beam((-31, 0, 97.2), (-47, 0, 97.6), 16.6, 3.0, "pearl", flat="z")
    h.beam((-42.5, 0, 96.6), (-55, 0, 95.2), 14.6, 3.4, "pearl", flat="z")
    h.beam((-51, 0, 95.6), (-63, 0, 91.6), 12.0, 3.0, "pearl", flat="z")
    for x, z, size, tall in ((-59.0, 92.8, 5.6, 13.0), (-48.5, 97.0, 5.4, 10.0), (-37.0, 99.2, 5.8, 11.0)):
        horn(h, (x, 0, z), (0.5, 0, 1), size, tall, "body-", "pearl")
    for side in (1, -1):  # nostrils and the cheeks' spikes
        bar(h, (-69.4, 7.0 * side, 85.6), (-65.2, 7.0 * side, 87.4), 2.0, 1.4, "core")
        point(h, (-29.0, 14.4 * side, 75.0), (0.75, 0.75 * side, -0.1), 5.0, 10.0, "pearl", (0, 0, 1), sink=3.6)
        point(h, (-35.0, 14.4 * side, 74.8), (0.55, 0.85 * side, -0.2), 4.0, 7.0, "pearl", (0, 0, 1), sink=3.4)
    corona(h)
    return h


def corona(h):
    """nine horns fanned behind the head like a rising sun, each a rainbow root in two tones, a pearl box and a lit tip"""
    h.hull(-29, -24, 18, 78, 102, "core", [(6, 3), (3, 3)], [(3, 3)])
    far = (18, 21, 24, 18, 20, 18, 24, 21, 18)
    for k, length in enumerate(far):
        a = math.radians(-12 + k * 204 / 8)
        way = unit((0.26, math.cos(a), math.sin(a)))
        base = 1 / math.sqrt((math.cos(a) / 16.5) ** 2 + (math.sin(a) / 13.5) ** 2)
        mid = (-26.5, 0.0, 87.0)
        at = lambda r: add(mid, way, base + r)  # noqa: E731
        ref = unit(cross(way, (1, 0, 0)))
        bar(h, at(-5), at(length * 0.44), 6.4, 5.8, "body", ref)
        bar(h, at(length * 0.3), at(length * 0.7), 5.2, 4.7, "body-", ref)
        bar(h, at(length * 0.56), at(length * 0.86), 4.1, 3.7, "pearl", ref)
        point(h, at(length * 0.86), way, 3.6, length * 0.14 + 2.8, "halo", ref, sink=0.8, thick=3.2)


def jaw(m):
    j = m.part("Jaw", (-38, 0, 75), "Head")
    j.beam((-34, 0, 74), (-57, 0, 62.2), 21.4, 9, "body", flat="z")
    j.beam((-53.5, 0, 63.2), (-69.0, 0, 56.8), 17.0, 7.6, "body", flat="z")
    # the mouth's floor and the tongue, pink; a dark gum; the lower teeth between the upper ones
    j.beam((-38, 0, 76.4), (-56.6, 0, 66.9), 19.8, 1.8, "core", flat="z")
    j.beam((-54.5, 0, 67.4), (-68.5, 0, 61.6), 15.6, 1.8, "core", flat="z")
    j.beam((-38, 0, 77.4), (-55, 0, 68.8), 13.0, 2.6, "maw", flat="z")
    j.beam((-52, 0, 69.8), (-65, 0, 64.6), 9.0, 2.2, "maw", flat="z")
    for x, y, z, size, length in ((-46.6, 7.8, 71.8, 3.6, 4.6), (-51.0, 7.8, 69.5, 4.0, 5.6), (-55.6, 5.6, 66.9, 4.0, 7.0),
                                  (-60.4, 5.6, 64.7, 4.0, 5.2), (-65.0, 5.3, 62.8, 4.6, 8.8)):
        j.tooth(x, y, z, size, -length, "ivory")
    j.tooth(-66.4, 1.9, 62.2, 3.2, -5.4, "ivory", long=3.0)
    # the chin: pearl plates under it
    plates(j, [(-40, 65.2), (-50.6, 60.0), (-60.0, 55.8)], (16, 14.4), 3.0, "pearl", 1)
    point(j, (-66.8, 0, 56.0), (-0.75, 0, -0.7), 6.4, 7.0, "pearl", sink=3.0, thick=6.0)
    for side in (1, -1):  # the tusks, and a pearl guard over the jaw's corner
        along(j, [flip(v, side) for v in ((-47.5, 6.0, 66.2), (-55.5, 14.8, 61.6), (-62.8, 19.0, 63.0), (-67.4, 18.8, 69.0))], (6.2, 4.8, 3.3), "ivory")
        point(j, (-67.4, 18.8 * side, 69.0), (-4.6, -0.2 * side, 6.0), 3.0, 7.0, "ivory", sink=1.0, lean=(2.2, 0, 1.6))
        bar(j, (-37.0, 11.0 * side, 73.0), (-50.0, 11.0 * side, 66.2), 5.0, 2.0, "pearl")
    for y, x, drop in ((-8, -54, 18), (-4.2, -58, 23), (0, -61.5, 28), (4.2, -58, 23), (8, -54, 18)):  # the beard
        pts = [(x, y, 61.0), (x + 2.2, y * 1.1, 59 - drop * 0.36), (x + 1.0, y * 1.25, 59 - drop * 0.7), (x - 3.5, y * 1.4, 59 - drop)]
        along(j, pts, (4.6, 3.7, 2.8), ("body", "body", "fin"))
    return j


def curl(m):
    """the seahorse's tail made giant: eleven blocks round one and a quarter turns, a pearl ring on every block"""
    parts = []
    for k in range(11):
        a, b, size = TAIL[k], TAIL[k + 1], THICK[k]
        d = unit(sub(b, a))
        p = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        p.beam(add(a, d, -size * 0.4), add(b, d, size * 0.2 if k < 10 else 1.0), size, size, "body")
        ring = max(2.4, size * 0.2)
        if k < 10:
            p.beam(add(b, d, -ring), add(b, d, 0.1), size + 1.5, size + 1.5, "pearl")
        p.beam(add(a, d, size * 0.1), add(b, d, -ring / 2), size * 0.5, size * 0.5, "body")
        if 4 <= k <= 9:  # a pearl plate along the outside of the far half, and spines on the top
            mid = mix(a, b, 0.4)
            out = unit(sub(mid, (C[0], 0.0, C[1])))
            out = unit(add(out, d, -dot(out, d)))
            bar(p, add(add(a, d, size * 0.06), out, size / 2 - 0.3), add(add(b, d, -ring - 0.9), out, size / 2 - 0.3), size * 0.52, 2.2, "pearl", out)
        if 6 <= k <= 8:
            point(p, add(mid, out, size / 2 - 0.4), add(out, d, 0.35), size * 0.42, 8.6 - 0.5 * k, "pearl", sink=1.6, thick=size * 0.3)
        parts.append(p)
    return parts


def wing(m, name, side, root, u, v, arm, tips, sizes, wide, reach, tones=("body", "wing")):
    """one wing: an arm of two dark boxes from `root` to the wrist, dark fingers fanned from the wrist, and on each finger a
    broad rainbow panel reaching toward the next. Points are (out, up) in the wing's own plane (u, v)"""
    u = unit(u)
    v = unit(add(v, u, -dot(u, v)))
    n = cross(u, v)

    def P(q, off=0.0):
        return flip(add(add(add(root, u, q[0]), v, q[1]), n, off), side)

    def W(q):
        return flip(add(tuple(q[0] * i for i in u), v, q[1]), side)

    N = flip(n, side)
    w = m.part(name, P((0, 0)), "Body")
    s0, s1, f0, f1 = sizes
    elbow, wrist = arm
    bar(w, P((-elbow[0] * 0.45, -elbow[1] * 0.45)), P(elbow), s0, s0 * 0.94, "core", N)
    e = unit((elbow[0], elbow[1], 0))
    bar(w, P((elbow[0] - e[0] * s1 * 0.5, elbow[1] - e[1] * s1 * 0.5)), P(wrist), s1, s1 * 0.94, "core", N)
    for k, tip in enumerate(tips):
        d = unit((tip[0] - wrist[0], tip[1] - wrist[1], 0))
        length = math.dist(tip, wrist)
        q = (d[1], -d[0])  # toward the next finger

        def spot(s, o=0.0):
            return (wrist[0] + d[0] * s + q[0] * o, wrist[1] + d[1] * s + q[1] * o)

        # every finger and panel lies at its own depth, so nothing shares a plane
        bar(w, P(spot(-1.0)), P(spot(length * 0.6)), f0, 5.2 - 0.3 * k, "core", N)
        bar(w, P(spot(length * 0.55)), P(spot(length)), f1, 3.3, "core", N)
        point(w, P(spot(length)), W(d), f1 * 0.95, f1 * 1.6, "pearl", N, thick=2.6)
        if k < len(wide):
            off = (k - (len(wide) - 1) / 2) * 0.4
            for near, far, across, colour, th in ((0.0, reach, wide[k], tones[0], 1.0), (reach * 0.62, reach + 0.08, wide[k] * 0.62, tones[1], 1.4)):
                w._oriented(P(spot(length * (near + far) / 2, across / 2), off), W(d), W(q), N, (length * (far - near), across, th), colour, False)
    up = unit((wrist[0] - elbow[0], wrist[1] - elbow[1], 0))  # the wrist's claw
    point(w, P(wrist), W((up[0] - 0.5, up[1] + 0.5)), s1 * 0.56, s1 * 1.6, "pearl", N, sink=s1 * 0.39, thick=s1 * 0.46)
    return w


def swept(sweep, lean):
    """a wing's two directions, its span swept back and its top leaned out, in degrees"""
    a, b = math.radians(sweep), math.radians(lean)
    u = (math.sin(a), math.cos(a), 0.0)
    return u, (-math.cos(a) * math.sin(b), math.sin(a) * math.sin(b), math.cos(b))


def wings(m):
    for side, tag in ((1, "R"), (-1, "L")):
        u, v = swept(35, 30)
        w = wing(m, "Wing" + tag, side, (19.0, 14.0, 60.0), u, v, ((7, 9), (12, 23)),
                 ((15, 55), (30, 50), (36, 33), (36, 8), (20, -10)), (10, 8.4, 2.8, 2.0), (19, 16.5, 20, 20), 0.88)
        bar(w, flip((18.6, 12.0, 57.0), side), flip((19.2, 19.6, 65.4), side), 12.4, 11.6, "pearl", (1, 0, 0))
        u, v = swept(40, 28)
        wing(m, "Wing2" + tag, side, (26.0, 9.5, 43.6), u, v, ((7, 0), (13, 2)),
             ((23, 19), (31, 9), (31, -6), (19, -18)), (8.6, 7.2, 2.4, 1.8), (13, 13, 14), 0.88, ("wing", "body"))


def sail(m):
    s = m.part("Sail", (22, 0, 58), "Body")
    for k in range(9):
        a = math.radians(81 - 8.0 * k)
        length = (50, 56, 58, 57, 54, 49, 44, 38, 33)[k]
        x0, z0 = 20.4 + 0.8 * k, 55.3 - 1.1 * k
        way = (math.cos(a), 0, math.sin(a))
        at = lambda r: add((x0, 0, z0), way, r)  # noqa: E731
        th = 6.2 - 0.52 * k
        bar(s, at(0), at(length * 0.62), 8.6, th, "fin")
        bar(s, at(length * 0.54), at(length * 0.9), 6.2, th - 1.3, "fin")
        point(s, at(length * 0.9), way, 5.6, length * 0.1 + 3, "body", sink=1.2, thick=max(1.0, th - 2.0))
        bar(s, at(length * 0.05), at(length * 0.58), 1.9, th + 1.3, "core")
    return s


def arms(m):
    for side, tag in ((1, "R"), (-1, "L")):
        a = m.part("Arm" + tag, (-16, 18 * side, 49), "Body")

        def F(x, y, z):
            return flip((x, y, z), side)

        along(a, [F(-12, 11, 49), F(-25, 33, 41), F(-47, 30.5, 41), F(-56, 28, 44)], (14.2, 12.0, 10.6), ("body", "body", "body"), (0, 0, 1))
        bar(a, F(-25, 33.7, 41.2), F(-45.6, 36.5, 41.2), 9.0, 3.0, "pearl", F(0, 1, 0))
        bar(a, F(-13.5, 22.4, 48.0), F(-21.0, 34.4, 43.6), 10.0, 3.0, "pearl", F(0.5, 0.5, 1.0))
        point(a, F(-25, 34, 41), F(0.8, 0.8, 0.1), 7.0, 9.0, "pearl", (0, 0, 1), sink=3.0)
        for dz, dx in ((4.0, 0.0), (0.0, -0.9), (-4.0, 0.7)):
            pts = [F(-53 + dx, 28.6, 43.4 + dz * 0.7), F(-63 + dx, 27.0, 45 + 1.5 * dz), F(-66.4 + dx, 21.6, 45.4 + 1.7 * dz)]
            along(a, pts, (4.8, 3.8), "core", (0, 0, 1))
            point(a, pts[-1], sub(pts[2], pts[1]), 3.4, 7.0, "ivory", (0, 0, 1), sink=1.0, lean=F(2.0, -1.5, 0))


def tentacles(m):
    for side, tag in ((1, "R"), (-1, "L")):
        t = m.part("Tent" + tag, (23, 12 * side, 44), "Body")
        for pts in (((20, 8, 38), (34, 20, 25.5), (47, 22, 21.5), (57, 25, 25), (62, 20, 34), (62, 17, 42)),
                    ((21, 6, 53), (35, 17, 60), (48, 20, 63), (57, 22, 60), (62, 18, 66), (63, 15, 72))):
            along(t, [flip(v, side) for v in pts], (7.4, 6.2, 5.0, 3.8, 2.8), ("body-", "fin", "fin", "fin", "body"))


def build(m):
    c.stand(m, LEVEL, GAME)
    b = body(m)
    throne(b)
    neck(m)
    head(m)
    jaw(m)
    curl(m)
    wings(m)
    sail(m)
    arms(m)
    tentacles(m)


def pose(parts, phase):
    s = math.sin
    r = math.radians
    parts["Neck"].rotation_euler.y = r(2.0) * s(phase - 0.4)
    parts["Head"].rotation_euler.y = r(3.0) * s(phase - 0.8)
    parts["Jaw"].rotation_euler.y = -r(5.0) * (0.5 + 0.5 * s(phase + 0.6))
    for side, tag in ((1, "R"), (-1, "L")):
        parts["Wing" + tag].rotation_euler.x = side * r(8.0) * s(phase)
        parts["Wing" + tag].rotation_euler.z = side * r(3.0) * s(phase - 0.8)
        parts["Wing2" + tag].rotation_euler.x = side * r(9.0) * s(phase - 0.9)
        parts["Arm" + tag].rotation_euler.y = r(3.0) * s(phase + 0.5 * side)
        parts["Tent" + tag].rotation_euler.z = side * r(4.0) * s(phase - 1.2)
        parts["Tent" + tag].rotation_euler.y = r(3.0) * s(phase - 0.6)
    parts["Sail"].rotation_euler.y = r(1.5) * s(phase - 1.0)
    for k in range(11):
        parts[f"T{k + 1}"].rotation_euler.y = r(0.5 + 0.12 * k) * s(phase - 0.35 * k)
