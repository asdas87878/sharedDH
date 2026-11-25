"""Seahorse rocker, level 2 "Painted" (docs/style/13-seahorse-evolution.md): the pot-bellied one, proud of its new paint. A
great cream belly hung out in front of it in two rounds, an S of a neck, a long trumpet snout held level with a smile at its
tip, big wide-set eyes, a coronet of three teal points, paddles for cheek fins, a tall sail of five ribbed blades behind the
seat and a fat tail in teal rings curled more than a whole turn."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 2
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW, LIGHTS = {}, []
FLOATING = ["Coil"]
FRAME, ORTHO = 3.2, 38.0
SWING = 11
SEAT = (4.4, 34.35, 3.8)

# the trunk: (from, to, cubes out, bottom, top, its top corners' steps)
TS, BS = [(2, 1), (1, 1)], [(1, 1)]
SLICES = ((-9, -6, 5, 20, 34, TS), (-6, 5, 6, 19, 34, TS), (5, 8, 5, 20, 32, TS))
# the head's frame: its middle, the way to the nose, out of the forehead
H0, PITCH = (-7.25, 0.0, 46.6), math.radians(5)
D = (-math.cos(PITCH), 0.0, -math.sin(PITCH))
N = (-math.sin(PITCH), 0.0, math.cos(PITCH))
Y = (0.0, 1.0, 0.0)
EYE_TURN = math.radians(44)
TAIL = ((5.4, 0, 27.4), (10.0, 0, 27.2), (13.5, 0, 24.6), (14.7, 0, 20.4), (15.6, 0, 15.6), (14.0, 0, 11.9), (10.8, 0, 11.3),
        (9.4, 0, 14.2), (9.2, 0, 17.7), (11.1, 0, 19.2), (12.0, 0, 15.7))
TAIL_SIZE = (7.0, 5.6, 4.2, 3.3, 3.0, 2.7, 2.4, 2.1, 1.8, 1.5)


def pose(parts, phase):
    """the head nods, the paddles and the sail wave, the tail follows"""
    parts["Neck"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.2 + math.pi)
    parts["Fan"].rotation_euler.x = math.radians(8) * math.sin(2 * phase)
    parts["FinL"].rotation_euler.z = math.radians(12) * math.sin(2 * phase)
    parts["FinR"].rotation_euler.z = -math.radians(12) * math.sin(2 * phase)
    for k, amp in enumerate((1, 1, 1, 1, 2, 2, 2, 2, 2, 2)):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians(amp) * math.sin(phase - 0.5 * (k + 1))


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def cross(a, b):
    return tuple(a[(i + 1) % 3] * b[(i + 2) % 3] - a[(i + 2) % 3] * b[(i + 1) % 3] for i in range(3))


def on_head(a, y, h):
    """a along to the nose, y out, h up, from the head's middle"""
    return tuple(o + a * d + y * w + h * n for o, d, w, n in zip(H0, D, Y, N))


def hb(part, a0, a1, w, h0, h1, colour):
    """a box on the head's middle line, w to each side"""
    part._oriented(on_head((a0 + a1) / 2, 0, (h0 + h1) / 2), D, Y, N, (a1 - a0, 2 * w, h1 - h0), colour, False)


def hs(part, a0, a1, y0, y1, h0, h1, colour):
    """a box on each side of the head"""
    part._oriented(on_head((a0 + a1) / 2, (y0 + y1) / 2, (h0 + h1) / 2), D, Y, N, (a1 - a0, y1 - y0, h1 - h0), colour, True)


def tilted(part, spot, along, roll_up, size, colour, mirror=True):
    """a box at a spot of the head's frame, running `along` (in that frame: a, y, h), its width toward roll_up"""
    way = unit(tuple(along[0] * d + along[1] * w + along[2] * n for d, w, n in zip(D, Y, N)))
    up = tuple(roll_up[0] * d + roll_up[1] * w + roll_up[2] * n for d, w, n in zip(D, Y, N))
    thin = unit(cross(way, up))
    part._oriented(on_head(*spot), way, cross(thin, way), thin, size, colour, mirror)


def face(part, spot, turn, boxes, roll=0.0):
    """boxes on a plane turned `turn` out from straight ahead, on both sides: (t0, t1, u0, u1, d0, d1, colour), t toward the
    nose, u up, d out of the plane"""
    out = tuple(math.cos(turn) * d + math.sin(turn) * w for d, w in zip(D, Y))
    fore = tuple(math.sin(turn) * d - math.cos(turn) * w for d, w in zip(D, Y))
    t = tuple(math.cos(roll) * f + math.sin(roll) * n for f, n in zip(fore, N))
    u = tuple(math.cos(roll) * n - math.sin(roll) * f for f, n in zip(fore, N))
    for t0, t1, u0, u1, d0, d1, colour in boxes:
        mid = tuple(s + (t0 + t1) / 2 * i + (u0 + u1) / 2 * j + (d0 + d1) / 2 * k for s, i, j, k in zip(spot, t, u, out))
        part._oriented(mid, t, u, out, (t1 - t0, u1 - u0, d1 - d0), colour, True)


def trunk(body):
    for x0, x1, n, bot, top, ts in SLICES:
        body.hull(x0, x1, n, bot, top, "body", ts, BS)
    body.sym(-7, 0, 4, 34, 36, "body")  # the shoulders, under the neck
    body.paint_sym(-9, -6, 5, 20, 32, "belly")
    body.paint_sym(-6, 5, 6, 19, 22, "belly")
    body.paint_sym(5, 8, 5, 20, 23, "belly")
    # the pot: two rounds, the outer one of two boxes crossing, so it reads round
    for x, root, y, z0, z1, colour in ((-10.6, -8.5, 4.7, 20.7, 31.0, "belly"),
                                       (-12.0, -9.5, 3.8, 22.8, 28.4, "fin"), (-12.35, -9.5, 3.0, 22.0, 29.2, "fin")):
        body.block(x, (-y, y, z0, z1), root, (-y, y, z0, z1), colour)
    for z in (23.2, 25.2, 27.2):  # its creases
        body.block(-12.5, (-2.3, 2.3, z, z + 0.5), -11.5, (-2.3, 2.3, z, z + 0.5), "belly-")
    q = math.sqrt(0.5)  # the painted diamond on each flank
    for size, out, colour in ((3.9, 6.85, "fin"), (2.2, 7.2, "ring")):
        body._oriented((-0.3, (out + 5.9) / 2, 27.6), (q, 0.0, q), (0.0, 1.0, 0.0), (-q, 0.0, q), (size, out - 5.9, size), colour, True)
    for x in (-5.2, 2.6):
        body.band(x, x + 2.0, 6, 19, 34, "ring", TS, BS, proud=0.35, stop=21.6)


def neck_and_head(m):
    neck = m.part("Neck", (-4.0, 0, 35), "Body")
    neck.beam((-3.0, 0, 32.6), (-4.8, 0, 40.0), 7.8, 7.4, "body")
    neck.beam((-4.2, 0, 38.4), (-7.1, 0, 45.4), 6.8, 6.6, "body")
    c.collar(neck, (-3.0, 0, 32.6), (-4.8, 0, 40.0), 7.8, back=1.2, past=0.8, grow=1.0)
    neck.beam((-7.5, 0, 35.2), (-8.5, 0, 39.2), 1.6, 4.8, "belly")  # the pale throat

    head = m.part("Head", (-6.9, 0, 43.5), "Neck")
    hb(head, -4.6, 4.2, 4.9, -3.6, 3.6, "body")  # the skull: boxes crossing, so every edge is cut by one step
    hb(head, -3.6, 3.2, 4.0, -4.7, 4.7, "body")
    hb(head, 0.0, 5.2, 3.8, -2.5, 2.7, "body")
    hb(head, -5.4, 0.0, 3.8, -2.6, 2.9, "body")
    # the snout: a root sloping off the forehead, a long tube, and a flared tip that smiles
    tilted(head, (5.2, 0, 1.1), (1, 0, -0.5), (0, 1, 0), (4.6, 4.2, 2.2), "body", False)
    hb(head, 4.4, 7.6, 2.6, -3.2, 0.5, "body")
    hb(head, 6.6, 9.2, 1.95, -2.8, 0.0, "body")
    hb(head, 8.6, 11.0, 1.75, -2.6, -0.2, "body")
    hb(head, 8.4, 9.6, 2.25, -3.1, 0.3, "ring")  # a painted ring round it
    hb(head, 10.4, 12.6, 2.6, -3.7, 0.7, "tip")
    hb(head, 11.6, 12.9, 2.8, -2.6, -1.6, "ring-")  # the smile: a line across the front, its corners turned up
    hs(head, 12.0, 12.75, 1.6, 2.4, -2.0, -0.7, "ring-")
    tilted(head, (11.75, 2.45, -1.6), (-1, 0, 0.9), (0, 1, 0), (2.2, 1.0, 0.9), "ring-")
    # the eyes
    spot = on_head(4.6, 4.9, 0.4)
    face(head, spot, EYE_TURN, [
        (-3.2, 3.1, -3.1, 2.95, -3.6, -0.6, "body-"),
        (-2.7, 2.7, -2.65, 2.65, -2.0, 0.1, "cream"),
        (-1.8, 2.1, -2.2, 1.9, -0.8, 0.5, "black"),
        (0.2, 1.7, 0.2, 1.5, -0.3, 0.85, "cream"),
        (-1.3, -0.5, -1.6, -0.8, -0.3, 0.8, "cream")])
    face(head, spot, EYE_TURN, [(-3.1, 2.6, 1.9, 3.1, -4.4, 0.75, "body")], math.radians(7))  # the lid: easy-going
    # the coronet: a band and three points
    hb(head, -2.9, 2.3, 3.0, 3.9, 5.6, "ring")
    top, way = on_head(-0.4, 0, 4.4), unit((0.35, 0, 1))
    head.beam(top, at(top, way, 4.8), 3.6, 3.4, "tip")
    p = at(top, way, 3.6)
    head.beam(p, at(p, unit((0.7, 0, 1)), 3.4), 2.4, 2.2, "tip+")
    p, way = on_head(0.0, 1.8, 4.6), unit((0.15, 0.55, 1))
    head.beam(p, at(p, way, 3.8), 2.8, 2.6, "tip", mirror=True)
    p = at(p, way, 2.6)
    head.beam(p, at(p, unit((0.4, 0.75, 1)), 2.8), 1.9, 1.7, "tip+", mirror=True)
    # the cheek fins
    for tag, s in (("L", -1), ("R", 1)):
        fin = m.part("Fin" + tag, on_head(-2.0, 4.6 * s, -1.9), "Head")
        way, up = unit((0.62, 0.8 * s, -0.12)), (0.0, 0.0, 1.0)
        thin = unit(cross(way, up))
        wide = cross(thin, way)
        p = on_head(-1.7, 3.9 * s, -1.8)
        fin._oriented(at(p, way, 1.0), way, wide, thin, (4.2, 3.0, 2.2), "body", False)
        fin._oriented(at(p, way, 3.2), way, wide, thin, (4.8, 4.3, 1.5), "fin", False)
        fin._oriented(at(p, way, 5.9), way, wide, thin, (2.6, 5.4, 1.85), "tip", False)


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 25), "Stand")
    trunk(body)
    neck_and_head(m)
    # the sail behind the seat: five blades, each with a rib and a teal tip
    fan = m.part("Fan", (7.4, 0, 30), "Body")
    root = (6.2, 0, 29.0)
    for deg, length, wide, thick in ((82, 17.0, 4.6, 3.7), (64, 16.8, 5.0, 3.1), (46, 14.0, 5.0, 2.5), (28, 11.4, 4.8, 1.9),
                                     (10, 9.6, 4.2, 1.3)):
        d = (math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg)))
        fan.beam(root, at(root, d, length - 2.2), wide, thick, "fin")
        fan.beam(at(root, d, length - 3.6), at(root, d, length), wide + 0.5, thick + 0.3, "tip")
        fan.beam(at(root, d, 0.6), at(root, d, length - 4.6), 1.2, thick + 0.3, "body")
    # the tail
    last = len(TAIL_SIZE) - 1
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = unit(tuple(j - i for i, j in zip(a, b)))
        tail = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        end = at(b, d, (0.4 if k in (6, 7) else 0.54) * TAIL_SIZE[k + 1]) if k < last else b
        tail.beam(at(a, d, -0.2 * size), end, size, size, "body" if k < last else "tip+")
        if k < 5:
            tail.beam(at(end, d, -2.0 + 0.2 * k), at(end, d, 0.35), size + 0.7, size + 0.7, "ring")
        if k < 3:
            inner = (d[2], 0.0, -d[0])  # the pale inside of the curl
            p, q = at(a, inner, size / 2 - 0.55), at(end, inner, size / 2 - 0.55)
            tail.beam(at(p, d, 3.8 if k == 0 else 1.2), at(q, d, -1.0), 1.4, size - 2.0, "belly")
