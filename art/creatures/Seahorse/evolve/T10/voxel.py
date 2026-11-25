"""Seahorse rocker, level 10 "Abyssal" (docs/style/13-seahorse-evolution.md): the deep-sea maw. The head is the animal: an
angler's underbite wide enough to swallow the player beside it, its corners turned up into a grin, uneven ivory fangs, the
inside lit; small cruel eyes under a heavy brow; a lure in front. Behind it a hunched, dark trunk under a wreck's riveted hull
plates, four lit gill slots a side, torn fins like wings, four tentacles. Still the seahorse's family: the coronet (a crest of
five horns on the skull), the fan behind the seat (the back plates' spines, webbed), the ringed tail in its curl.
Values, dark to light: body (near black) < belly (jaw, undersides) < armour and ring (plates, lips, bones, rings) < spike
(points, rims, rivets) < ivory. Cyan only inside the mouth, in the gills, the lure, the eyes, the jaw's lights, the tail's studs and the fins' edges."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 10
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
PALETTE.update({"maw": "#128FB4", "gullet": "#06101F", "tongue": "#0F6288"})
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW = {"tip": 0.8, "halo": 0.9, "maw": 0.3, **c.glow_of(LEVEL)}
LIGHTS = [("Head", (-40.0, 0, 42.0), "#2FE6FF", 150, 1.0), ("Lure", (-55.6, 0, 69.0), "#2FE6FF", 60, 0.8)]
FLOATING = ["Coil"]
FRAME, ORTHO = 6.0, 80.0
SWING = 7
SEAT = (2.0, 56.0, 4.6)

# the trunk: (from, to, cubes out, bottom, top, top steps, the pale belly up to here)
TS, BS = [(4, 3), (2, 4)], [(5, 2), (2, 3)]
SLICES = ((-17, -14, 9, 35, 57, [(3, 3)], 36), (-14, -8, 13, 28, 60, TS, 33), (-8, 8, 13, 27, 54, TS, 32),
          (8, 14, 13, 28, 59, TS, 33), (14, 19, 11, 30, 56, [(4, 3), (2, 3)], 34), (19, 22, 9, 33, 52, [(3, 3), (1, 2)], 36))
TAIL = ((14.0, 0, 43.0), (23.0, 0, 42.4), (30.4, 0, 37.0), (33.2, 0, 28.4), (31.0, 0, 20.0), (24.8, 0, 16.0), (18.8, 0, 18.6),
        (18.4, 0, 24.2), (22.6, 0, 26.6))
TAIL_SIZE = (14.8, 13.1, 11.5, 9.9, 8.4, 6.9, 5.4, 4.0)


# ---------------------------------------------------------------- small geometry
def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def slab(part, a, b, wide, thick, colour, y=0.0, mirror=False):
    """a box lying across the animal: from a to b (x, z) in the side view, `wide` across, `thick` through"""
    part.beam((a[0], y, a[1]), (b[0], y, b[1]), wide, thick, colour, flat="z", mirror=mirror)


def rail(part, a, b, y0, y1, thick, colour):
    """the same on both sides, from y0 to y1 out: a lip, a jaw's arm"""
    slab(part, a, b, y1 - y0, thick, colour, (y0 + y1) / 2, True)


def point(part, root, way, length, size, colour, across=None, sunk=0.8):
    """a pyramid standing at `root`, pointing along `way`, its base `size` across and buried"""
    way = unit(way)
    ref = (0.0, 1.0, 0.0) if abs(way[1]) < 0.8 else (1.0, 0.0, 0.0)
    u = unit(cross(way, ref))
    v = cross(way, u)
    h, g = size / 2, (across or size) / 2
    b = at(root, way, -sunk)
    base = [at(at(b, u, h * i), v, g * j) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    part.spike(base, at(root, way, length), colour)


def horn(part, root, way, bend, l1, l2, size, colour="armour", tip="spike", sunk=1.5):
    """a horn: a turned block, then a point bent on from it"""
    way, bend = unit(way), unit(bend)
    end = at(root, way, l1)
    part.beam(at(root, way, -sunk), end, size, size * 0.92, colour)
    point(part, at(end, way, -0.3), bend, l2, size * 0.7, tip, sunk=size * 0.5)


def line(a, b):
    return lambda x: a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])


def pose(parts, phase):
    """the head nods, the jaw works, the lure swings late, the torn fins beat slowly, the tail and tentacles follow"""
    s = math.sin
    parts["Head"].rotation_euler.y = math.radians(1.5) * s(phase + math.pi)
    parts["Jaw"].rotation_euler.y = -math.radians(5) * (0.5 + 0.5 * s(phase))
    parts["Lure"].rotation_euler.y = math.radians(5) * s(phase - 1.0)
    parts["Lure"].rotation_euler.x = math.radians(4) * s(phase - 0.4)
    parts["Fan"].rotation_euler.x = math.radians(3) * s(phase - 0.8)
    parts["WingR"].rotation_euler.x = math.radians(8) * s(phase - 0.6)
    parts["WingL"].rotation_euler.x = -math.radians(8) * s(phase - 0.6)
    for k, amp in enumerate((1, 1, 1.5, 2, 2, 2.5, 3, 4)):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians(amp) * s(phase - 0.5 * (k + 1))
    for k, name in enumerate(("UpR", "UpL", "LoR", "LoL")):
        side = 1 if name.endswith("R") else -1
        for j, amp in ((1, 5), (2, 9)):
            parts[f"{name}{j}"].rotation_euler.z = side * math.radians(amp) * s(phase - 0.9 * j - 0.7 * k)


# ---------------------------------------------------------------- the trunk
def trunk(body):
    for x0, x1, n, bot, top, ts, belly in SLICES:
        body.hull(x0, x1, n, bot, top, "body", ts, BS if n > 10 else [(2, 2)])
        body.paint_sym(x0, x1, n, bot, belly, "belly")
    # the gills: four slots a side, sunk and lit, each behind a flap of steel turned out at its back edge
    for x, z0, z1 in ((-12, 35, 46), (-7, 34, 46), (-2, 33, 45), (3, 34, 43)):
        body.carve_pair(x, x + 3, 13, 14, z0, z1)
        body.paint_pair(x, x + 3, 12, 13, z0, z1, "tip")
        a, b = (x - 1.2, 12.3, (z0 + z1) / 2), (x + 0.1, 14.0, (z0 + z1) / 2)
        body.beam(a, b, z1 - z0 + 1.5, 1.4, "armour", mirror=True)


def plate(body, x0, x1, n, top, flat, drop, side):
    """a plate of the wreck's hull: a top, a shoulder each side turned down over the steps, a side plate; its back edge a
    raised lip, rivets along it. flat: the top's half width; drop: how far the shoulder falls; side: the side plate's length"""
    lean = 0.10
    up = unit((-lean, 0, 1))
    fore = unit((1, 0, lean))
    mid = ((x0 + x1) / 2, 0.0, top + 0.35)
    long = x1 - x0
    body._oriented(mid, fore, (0.0, 1.0, 0.0), up, (long, 2 * flat, 2.2), "armour", False)
    lip = at(at(mid, fore, long / 2 - 0.5), up, 0.2)
    body._oriented(lip, fore, (0.0, 1.0, 0.0), up, (1.5, 2 * flat + 0.6, 3.0), "spike", False)
    # the shoulder
    a, b = (mid[0], flat - 0.9, top + 0.75), (mid[0], n + 1.2, top - drop)
    d = unit(sub(b, a))
    out = cross((1.0, 0.0, 0.0), d)
    out = out if out[2] > 0 else tuple(-v for v in out)
    thin = unit(at(out, (-1, 0, 0), lean))
    along = unit(at((1.0, 0.0, 0.0), out, lean))
    length = math.dist(a, b)
    cc = at(at(a, d, length / 2), out, -0.75)
    body._oriented(cc, along, d, thin, (long - 0.5, length, 2.0), "armour", True)
    body._oriented(at(at(cc, along, long / 2 - 0.65), thin, 0.25), along, d, thin, (1.3, length + 0.8, 3.1), "spike", True)
    for f in (0.28, 0.72) if side else ():
        body._oriented(at(at(at(a, d, length * f), along, -long / 2 + 1.7), out, 0.35), along, d, thin, (1.5, 1.5, 1.1), "spike", True)
    if side:  # the side plate, under the shoulder's edge
        z1 = top - drop + 1.6
        t, fo = unit((-0.06, 1.0, 0.0)), unit((1.0, 0.06, 0.0))
        body._oriented((mid[0] - 0.3, n + 0.35, z1 - side / 2), fo, (0.0, 0.0, 1.0), t, (long - 1.3, side, 2.1), "armour-", True)


def plates(body):
    plate(body, -20.4, -13.6, 11, 59.4, 7.6, 7.2, 0)
    plate(body, -13.6, -7.8, 13, 61.2, 8.6, 8.0, 6.5)
    plate(body, 8.4, 14.4, 13, 60.1, 8.7, 8.0, 7.0)
    plate(body, 13.6, 19.3, 11, 57.3, 6.7, 6.5, 6.0)
    plate(body, 18.6, 23.6, 9, 53.3, 5.6, 5.4, 0)
    # the spines in front of the rider: the first whole, the second snapped (the flaw)
    horn(body, (-16.6, 0, 60.4), (0.45, 0, 1), (0.9, 0, 1), 5.2, 6.0, 4.2, "ring", "spike")
    body.beam((-11.6, 0, 60.6), (-9.9, 0, 64.6), 3.6, 3.3, "ring")
    point(body, (-10.5, 0.5, 64.0), (0.1, 0.2, 1), 2.4, 1.6, "ivory", sunk=0.6)


def saddle(body):
    body.band(-5.2, 6.8, 13, 27, 54, "ring", TS, BS, proud=0.35, stop=47.6)  # the blanket: a steel edge, dark on it
    body.band(-4.2, 5.8, 13, 27, 54, "belly", TS, BS, proud=0.65, stop=48.6)
    body.block(-2.4, (-4.6, 4.6, 53.5, 56.0), 5.4, (-4.6, 4.6, 53.5, 56.0), "saddle")
    body.beam((1.6, 4.0, 55.0), (1.6, 9.6, 53.4), 5.4, 1.5, "saddle", flat="z", mirror=True)
    body.beam((-1.4, 0, 54.6), (-3.2, 0, 58.6), 2.4, 6.4, "saddle")  # the pommel and its horn
    body.beam((-2.7, 0, 57.0), (-3.8, 0, 60.0), 1.9, 3.2, "spike")
    body.beam((5.0, 0, 54.6), (7.0, 0, 59.6), 1.9, 9.6, "saddle")  # the cantle
    body.beam((6.7, 0, 58.6), (7.3, 0, 60.2), 2.5, 10.2, "spike")


# ---------------------------------------------------------------- the head
U1A, U1B, U2A, U2B = (-18.0, 49.8), (-38.5, 47.2), (-36.0, 47.4), (-51.6, 52.0)  # the upper lip's middle line
J1A, J1B, J2A, J2B = (-19.5, 29.4), (-41.0, 25.6), (-38.0, 25.7), (-57.6, 30.0)  # the lower jaw's
ARM_A, ARM_B = (-20.6, 47.6), (-34.6, 30.0)
u1, u2, j1, j2 = line(U1A, U1B), line(U2A, U2B), line(J1A, J1B), line(J2A, J2B)
HALF1, HALF2 = 15.0, 13.2  # how far out the lips are: behind, in front


def skull(head):
    head.hull(-33, -15, 14, 46, 66, "body", [(7, 2), (4, 2), (2, 3)])
    head.hull(-26, -13, 11, 29, 46, "body", [], [(4, 2), (2, 3)])
    head.paint_sym(-26, -13, 11, 29, 34, "belly-")
    # the forehead and the nose: turned blocks, the second smaller and starting inside the first
    slab(head, (-24.0, 61.6), (-50.0, 55.8), 17.0, 10.4, "body")
    slab(head, (-43.0, 56.6), (-53.4, 54.4), 13.0, 7.4, "armour-")
    slab(head, (-30.0, 50.4), (-50.4, 51.7), 20.4, 6.8, "body-")  # the cheek under them
    # the skull's shield: a plate down the forehead, a ridge on it, a second, narrower plate on the nose
    slab(head, (-22.0, 67.1), (-41.5, 62.4), 12.0, 2.6, "armour")
    slab(head, (-40.0, 62.3), (-51.0, 58.8), 8.4, 2.0, "armour+")
    slab(head, (-39.2, 62.9), (-42.0, 62.2), 13.4, 3.2, "ring+")
    # the lips
    rail(head, U1A, U1B, 10.4, HALF1, 4.4, "ring+")
    rail(head, U2A, U2B, 9.6, HALF2, 4.0, "ring+")
    slab(head, (-48.4, u2(-48.4) + 0.05), (-52.4, u2(-52.4) + 0.05), 2 * HALF2 + 1.0, 4.6, "ring+")
    # the gums, inside the lips' edge
    for a, b, f, y0, y1 in ((U1A, U1B, u1, 10.2, 14.0), (U2A, U2B, u2, 9.2, 12.3)):
        rail(head, (a[0] - 2.5, f(a[0] - 2.5) - 1.75), (b[0] + 0.4, f(b[0] + 0.4) - 1.75), y0, y1, 1.8, "gullet")
    slab(head, (-48.0, u2(-48.0) - 1.9), (-51.6, u2(-51.6) - 1.9), 2 * HALF2 - 1.2, 2.3, "gullet")
    # the grin's corner, turned up the cheek
    head.beam((-23.4, 14.0, 48.0), (-17.4, 17.0, 57.4), 4.4, 3.0, "ring+", mirror=True)
    # inside: the roof, the lit walls of the throat, the dark gullet in the middle of them
    slab(head, (-25.0, 48.2), (-49.4, 50.6), 19.4, 2.4, "maw")
    head.block(-35.0, (9.4, 10.5, 34.3, 47.3), -24.4, (9.4, 10.5, 34.3, 47.3), "maw", mirror=True)
    head.block(-28.0, (-9.9, 9.9, 30.4, 47.5), -25.2, (-9.9, 9.9, 30.4, 47.5), "tip")
    head.block(-28.6, (-5.2, 5.2, 34.2, 44.2), -26.0, (-5.2, 5.2, 34.2, 44.2), "gullet")
    # the temples' plates: riveted steel, a lip behind
    head.block(-31.0, (14.0, 15.6, 51.8, 59.2), -18.2, (14.0, 16.2, 51.8, 60.2), "armour", mirror=True)
    head.block(-19.6, (13.8, 16.8, 51.0, 61.0), -17.4, (13.8, 16.8, 51.0, 61.0), "spike", mirror=True)
    for x, z in ((-28.6, 57.4), (-28.6, 53.6), (-22.0, 54.2), (-22.0, 58.0)):
        head.block(x - 0.8, (15.0, 16.6, z - 0.8, z + 0.8), x + 0.8, (15.0, 16.6, z - 0.8, z + 0.8), "spike+", mirror=True)


def eyes(head):
    """set in the corner between the skull and the narrower face, so they look forward and out; the brow cuts them"""
    t, n, z = unit((0.66, 0.75, 0.0)), unit((-0.75, 0.66, 0.0)), (0.0, 0.0, 1.0)
    e = (-36.4, 12.2, 57.0)
    head._oriented(at(e, n, -1.6), t, z, n, (8.2, 7.6, 5.0), "body-", True)
    head._oriented(at(e, n, -0.4), t, z, n, (5.8, 5.4, 3.6), "halo", True)
    head._oriented(at(at(e, n, -0.1), t, -0.3), t, z, n, (1.9, 4.6, 4.0), "black", True)
    brow = ((-28.4, 16.6, 66.6), (-43.8, 6.6, 59.0))
    d = unit(sub(brow[1], brow[0]))
    up = unit(at((0, 0, 1), d, -d[2]))
    side, mid = cross(up, d), tuple((a + b) / 2 for a, b in zip(*brow))
    head._oriented(mid, d, side, up, (math.dist(*brow), 5.8, 5.2), "armour", True)
    head._oriented(at(at(mid, up, 2.6), d, 0.2), d, side, up, (math.dist(*brow) - 2.2, 4.4, 1.8), "spike", True)


def crest(head):
    """the coronet: five horns fanned over the skull"""
    for x, y, lean, l1, l2, size in ((-21.0, 0.0, 0.0, 9.5, 12.0, 6.2), (-22.4, 5.0, 0.5, 8.8, 11.2, 5.4), (-19.9, 9.4, 1.0, 8.6, 10.4, 4.8)):
        for s in ((1,) if y == 0 else (1, -1)):
            horn(head, (x, y * s, 64.6 - 0.2 * y), (0.4, lean * s, 1), (0.7, lean * s * 0.85, 1), l1, l2, size, "armour", "spike")


# fangs: (x, y, length, size across)
UPPER = ((-50.6, 4.2, 9.0, 4.2), (-49.3, 10.4, 11.0, 4.6), (-45.0, 10.9, 5.0, 3.2), (-39.8, 11.4, 9.4, 3.4), (-34.0, 12.4, 5.2, 3.2),
         (-28.8, 12.4, 7.4, 3.8))
LOWER = ((-55.6, 3.5, 5.0, 3.0), (-55.4, 7.2, 10.6, 4.6), (-54.8, 11.6, 5.6, 3.0), (-48.4, 11.5, 5.6, 3.4), (-43.2, 11.45, 10.0, 3.8), (-37.4, 12.4, 5.0, 2.6))


def fangs(head, jaw):
    for k, (x, y, length, size) in enumerate(UPPER):
        f = u2 if x < -37 else u1
        for s in (1, -1):
            point(head, (x, y * s, f(x) - 1.6), (-0.16 if x < -46 else 0.04, 0.06 * s, -1), length + 1.0, size, "ivory", sunk=1.3)
    for k, (x, y, length, size) in enumerate(LOWER):
        f = j2 if x < -38.5 else j1
        for s in (1, -1):
            far = 4.6 if k == 4 and s < 0 else length  # one is broken short
            point(jaw, (x, y * s, f(x) + 4.6), (0.06, 0.04 * s, 1), far + 1.0, size, "ivory", sunk=1.5)
    point(jaw, (-56.0, 0, j2(-56.0) + 4.6), (0.04, 0, 1), 6.4, 3.4, "ivory", sunk=1.5)
    # on the arm's slope, at the corner of the grin
    d = unit((ARM_B[0] - ARM_A[0], 0, ARM_B[1] - ARM_A[1]))
    up = (d[2], 0, -d[0])
    for along, length, size in ((14.0, 6.4, 3.2), (8.4, 4.8, 2.8)):
        r = at(at((ARM_A[0], 12.5, ARM_A[1]), d, along), up, 3.0)
        for s in (1, -1):
            point(jaw, (r[0], r[1] * s, r[2]), (up[0] - 0.1, 0.0, up[2] + 0.5), length, size, "ivory", sunk=1.0)


def lower_jaw(jaw):
    slab(jaw, J1A, J1B, 26.2, 8.4, "belly-")
    slab(jaw, J2A, J2B, 25.0, 8.0, "belly-")
    rail(jaw, ARM_A, ARM_B, 10.7, 14.2, 6.4, "belly-")  # the arms up to the hinge
    # the lips: along the sides, across the chin, up the arms
    rail(jaw, (-31.5, j1(-31.5) + 3.7), (J1B[0], j1(J1B[0]) + 3.7), 11.0, 13.85, 2.8, "ring+")
    rail(jaw, (-38.6, j2(-38.6) + 3.6), (J2B[0] + 0.2, j2(J2B[0] + 0.2) + 3.6), 9.4, 13.55, 3.0, "ring+")
    slab(jaw, (-53.8, j2(-53.8) + 3.5), (-58.4, j2(-58.4) + 3.5), 27.6, 4.3, "ring+")
    d = unit((ARM_B[0] - ARM_A[0], 0, ARM_B[1] - ARM_A[1]))
    up = (d[2], 0, -d[0])
    a, b = at(at((ARM_A[0], 0, ARM_A[1]), d, 2.5), up, 2.5), at(at((ARM_B[0], 0, ARM_B[1]), up, 2.5), d, 2.0)
    rail(jaw, (a[0], a[2]), (b[0], b[2]), 11.3, 14.8, 2.4, "ring+")
    # the hinge: a riveted plate
    for size, y1, colour in ((9.2, 15.9, "armour"), (3.2, 16.8, "spike+")):
        jaw._oriented((-21.6, (12.6 + y1) / 2, 45.8), unit((1, 0, 1)), (0.0, 1.0, 0.0), unit((-1, 0, 1)), (size, y1 - 12.6, size), colour, True)
    # the floor and the tongue
    slab(jaw, (-27.0, j1(-27.0) + 3.8), (-40.0, j1(-40.0) + 3.8), 19.0, 1.9, "maw")
    slab(jaw, (-38.4, j2(-38.4) + 3.4), (-55.0, j2(-55.0) + 3.4), 18.4, 2.4, "maw")
    slab(jaw, (-29.5, 30.6), (-41.8, 36.2), 10.0, 5.2, "tongue")
    slab(jaw, (-40.2, 36.0), (-51.6, 34.2), 8.2, 4.2, "tongue")
    # lights along the jaw, as a deep-sea fish has them
    for x, size in ((-53.2, 2.7), (-47.6, 2.3), (-42.6, 1.9)):
        jaw._oriented((x, 12.4, j2(x) - 0.8), unit((1, 0, -0.22)), (0.0, 1.0, 0.0), unit((0.22, 0, 1)), (size, 1.4, size), "tip", True)
    # the chin's plates and spikes
    slab(jaw, (-23.0, j1(-23.0) - 4.2), (-39.5, j1(-39.5) - 4.2), 19.0, 2.4, "armour")
    slab(jaw, (-38.4, j2(-38.4) - 4.0), (-56.4, j2(-56.4) - 4.0), 17.0, 2.2, "armour")
    for x, y, length in ((-54.6, 5.6, 6.4), (-47.0, 6.8, 5.2), (-40.0, 7.4, 4.4)):
        for s in (1, -1):
            point(jaw, (x, y * s, j2(x) - 4.7), (-0.35, 0.25 * s, -1), length, 3.4, "spike", sunk=0.9)


def lure(p):
    pts = ((-29.5, 0, 63.6), (-34.6, 0, 72.0), (-41.0, 0, 78.6), (-48.4, 0, 81.6), (-55.2, 0, 78.6))
    for k, size in enumerate((5.2, 4.4, 3.6, 2.9)):
        a, b = pts[k], pts[k + 1]
        d = unit(sub(b, a))
        end = at(b, d, 0.7)
        p.beam(at(a, d, -0.3 * size), end, size, size * 0.94, "body")
        p.beam(at(end, d, -1.3), at(end, d, 0.35), size + 0.8, size * 0.94 + 0.8, "ring" if k < 3 else "armour")
    # the lantern: a lit block in three dark claws
    cx, cz = -55.6, 70.4
    p.beam((cx, 0, 79.0), (cx, 0, 73.6), 2.6, 2.4, "body")
    p._oriented((cx, 0, cz + 3.4), (1.0, 0, 0), (0, 1.0, 0), (0, 0, 1.0), (7.4, 7.6, 2.2), "armour", False)
    q = math.radians(45)
    p._oriented((cx, 0, cz), (math.cos(q), math.sin(q), 0), (-math.sin(q), math.cos(q), 0), (0, 0, 1.0), (5.0, 5.0, 6.2), "tip", False)
    for deg in (180, 60, -60):
        r = (math.cos(math.radians(deg)), math.sin(math.radians(deg)), 0)
        a = (cx + 1.2 * r[0], 1.2 * r[1], cz + 3.3)
        b = (cx + 5.6 * r[0], 5.6 * r[1], cz + 1.0)
        e = (cx + 3.6 * r[0], 3.6 * r[1], cz - 4.2)
        p.beam(a, at(b, unit(sub(b, a)), 0.8), 1.9, 1.7, "armour-")
        d = unit(sub(e, b))
        p.beam(at(b, d, -0.4), e, 1.35, 1.2, "armour-")
        point(p, at(e, d, -0.4), (-0.8 * r[0], -0.8 * r[1], -0.8), 2.6, 0.8, "spike", sunk=0.35)


# ---------------------------------------------------------------- fins, fan, tail, tentacles
def wing(m, tag, s):
    """a torn fin: an arm of two boxes, three bones, three panels of two unequal strips with a lit edge each. Drawn in its
    own plane: u out (and up), v back (and down)"""
    root = (7.5, 10.5 * s, 48.0)
    e1 = unit((0.16, 0.68 * s, 0.70))
    e2 = (0.52, 0.0, -0.85)
    e2 = unit(at(e2, e1, -sum(a * b for a, b in zip(e1, e2))))
    n = cross(e1, e2)
    n = n if n[2] > 0 else tuple(-v for v in n)
    w = m.part("Wing" + tag, at(root, e1, 1.5), "Body")

    def pt(u, v, h=0.0):
        return at(at(at(root, e1, u), e2, v), n, h)

    def bar(a, b, wide, thick, colour, h=0.0):
        a, b = pt(*a, h), pt(*b, h)
        d = unit(sub(b, a))
        w._oriented(tuple((i + j) / 2 for i, j in zip(a, b)), d, cross(n, d), n, (math.dist(a, b), wide, thick), colour, False)

    def spur(a, way, length, size, colour="spike", sunk=1.0):
        point(w, pt(*a), tuple(x * way[0] + y * way[1] for x, y in zip(e1, e2)), length, size, colour, sunk=sunk)

    bar((-2.0, 0.6), (3.4, -0.9), 9.0, 7.4, "armour")  # the shoulder's cap
    bar((0.5, 0.0), (13.2, -3.3), 6.4, 5.6, "ring")
    bar((10.6, -3.0), (25.4, 1.6), 4.6, 4.0, "ring")
    bar((10.8, -2.7), (13.9, -3.5), 7.6, 6.4, "armour")
    spur((11.0, -5.0), (-0.1, -1), 7.0, 3.0)
    spur((24.8, 1.4), (0.95, 0.45), 4.4, 2.8, sunk=1.9)
    # panels: each two strips side by side: (u at the root, v, the way, length, width, thickness)
    strips = ((22.6, 0.2, (0.24, 1), 9.5, 4.8, 1.5), (18.4, -0.6, (0.20, 1), 17.0, 4.6, 1.15), (14.2, -1.6, (0.13, 1), 20.0, 4.8, 1.5),
              (9.8, -1.8, (0.08, 1), 15.0, 4.8, 1.15), (5.4, -0.6, (0.02, 1), 16.0, 4.8, 1.5), (1.4, 0.0, (-0.04, 1), 9.5, 4.2, 1.15))
    for k, (u, v, way, length, wide, thick) in enumerate(strips):
        d = unit((way[0], way[1], 0))
        end = (u + d[0] * length, v + d[1] * length)
        bar((u, v), end, wide, thick, "belly" if k % 2 else "wing+")
        bar((end[0] - d[0] * 0.9, end[1] - d[1] * 0.9), (end[0] + d[0] * 0.6, end[1] + d[1] * 0.6), wide + 0.5, thick + 0.8, "tip")
    for u, v, way, length in ((20.6, 0.6, (0.22, 1), 13.5), (12.2, -1.0, (0.11, 1), 22.0), (3.4, 0.0, (-0.01, 1), 13.5)):
        d = unit((way[0], way[1], 0))
        end = (u + d[0] * length, v + d[1] * length)
        bar((u, v), end, 2.1, 2.7, "ring+")
        spur(end, d[:2], 4.6, 1.4, sunk=0.7)


def fan(m):
    """behind the seat: the last three plates' spines, webbed: a fan seen from the side, thin from behind"""
    f = m.part("Fan", (13.0, 0, 55.0), "Body")
    root = (9.5, 0, 52.5)
    for deg, length, size in ((78, 29.0, 3.8), (52, 30.0, 3.5), (26, 26.0, 3.2)):
        d = (math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg)))
        f.beam(at(root, d, 3.0), at(root, d, length - 8.0), size, size * 0.9, "ring")
        point(f, at(root, d, length - 8.6), at(d, (0.35, 0, -0.1), 1), 9.0, size * 0.78, "spike+", sunk=0.9)
    for deg, length, wide, thick in ((65, 21.0, 9.2, 1.7), (39, 19.5, 8.8, 1.0)):
        d = (math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg)))
        f.beam(at(root, d, 4.0), at(root, d, length), wide, thick, "belly")
        f.beam(at(root, d, length - 0.9), at(root, d, length + 0.7), wide + 0.6, thick + 0.4, "tip")


def tail(m):
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = unit(sub(b, a))
        p = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        last = k == len(TAIL_SIZE) - 1
        end = b if last else at(b, d, 0.40 * TAIL_SIZE[k + 1])
        p.beam(at(a, d, -0.2 * size), end, size, size, "body")
        outer = (-d[2], 0.0, d[0])  # the back of the curl
        mid = at(a, d, math.dist(a, end) * 0.45)
        if k < 6:  # the lit studs, the keel's spikes
            for s in (1, -1):
                q = (mid[0], s * (size / 2), mid[2])
                p._oriented(at(q, outer, -size * 0.22), d, (0.0, 1.0, 0.0), outer, (size * 0.22, 1.2, size * 0.22), "tip", False)
            point(p, at(mid, outer, size / 2), at(outer, d, 0.7), size * 0.42, size * 0.36, "spike", sunk=0.6 + 0.16 * size)
        if not last:
            g = 0.5 + size * 0.06
            p.beam(at(end, d, -1.0 - size * 0.10), at(end, d, 0.4), size + g, size + g, "ring+")
        else:
            p.beam(at(end, d, -1.6), at(end, d, 1.4), size + 0.5, size + 0.5, "spike")


def tentacle(m, name, pts, sizes):
    for j in (0, 1):
        p = m.part(f"{name}{j + 1}", pts[2 * j], f"{name}1" if j else "Body")
        for k in (2 * j, 2 * j + 1):
            a, b, size = pts[k], pts[k + 1], sizes[k]
            d = unit(sub(b, a))
            end = at(b, d, size * 0.3)
            p.beam(at(a, d, -size * 0.25), end, size, size, "body" if k < 2 else "belly")
            p.beam(at(end, d, -1.5), at(end, d, 0.3), size + 0.7, size + 0.7, "armour")
            if k == 3:
                point(p, end, at(d, (0, 0, 1), 0.35), 4.6, size * 0.8, "spike", sunk=0.6)


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 36), "Stand")
    trunk(body)
    plates(body)
    saddle(body)
    head = m.part("Head", (-16, 0, 46), "Body")
    skull(head)
    eyes(head)
    crest(head)
    jaw = m.part("Jaw", (-21.6, 0, 45.8), "Head")
    lower_jaw(jaw)
    fangs(head, jaw)
    lure(m.part("Lure", (-29.5, 0, 63.6), "Head"))
    for tag, s in (("R", 1), ("L", -1)):
        wing(m, tag, s)
    fan(m)
    tail(m)
    for tag, s in (("R", 1), ("L", -1)):
        tentacle(m, "Up" + tag, [(x, y * s, z) for x, y, z in ((15, 6.5, 46), (22, 12.5, 51.5), (29, 17.5, 55), (36, 21, 54), (39, 22, 47))],
                 (6.2, 5.0, 3.8, 2.6))
        tentacle(m, "Lo" + tag, [(x, y * s, z) for x, y, z in ((15, 7.0, 38), (22, 14.5, 37.5), (29, 21.0, 36), (35, 26.0, 37.5), (37.5, 29.5, 42.5))],
                 (6.0, 4.8, 3.6, 2.4))
