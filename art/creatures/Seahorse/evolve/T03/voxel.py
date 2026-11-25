"""Seahorse rocker, level 3 "Saddled" (docs/style/13-seahorse-evolution.md): a prancing steed. Still a seahorse (tube snout,
armour rings, curled tail, coronet, the fan behind the seat), carried like a proud horse: a deep chest, a neck that arches up
and over, a big head hanging from it, a finned mane, two pectoral fins lifted and bent like forelegs, and real tack: a saddle
with a horn and a cantle on a red blanket, a bridle and reins."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common as c  # noqa: E402

LEVEL = 3
GAME = c.GAME
NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)
globals().update(c.VARIANTS.get(LEVEL, {}))
GLOW, LIGHTS = {}, []
FLOATING = ["Coil"]
FRAME, ORTHO = 3.4, 40.0
SWING = 11
SEAT = (4.4, 37.9, 3.8)

# the trunk: (from, to, cubes out, bottom, top, the pale belly comes up to here)
TS, BS = [(2, 1), (1, 1)], [(1, 2)]
SLICES = ((-11, -8, 4, 24, 35, 35), (-8, -5, 5, 22, 36, 27), (-5, 7, 6, 20, 36, 23), (7, 9, 5, 22, 35, 22))
BARREL = SLICES[2]
# the neck: three blocks, up and over
NECK = ((-3.4, 0, 30.5), (-6.4, 0, 40.4), (-8.4, 0, 46.8), (-11.0, 0, 52.0))
NECK_SIZE = (8.6, 7.6, 6.6)
# the head hangs from its poll at this angle below level
POLL, HANG = (-10.5, 0.0, 52.0), math.radians(57)
D = (-math.cos(HANG), 0.0, -math.sin(HANG))  # along the head, to the nose
N = (-math.sin(HANG), 0.0, math.cos(HANG))  # out of the forehead
TAIL = ((6.0, 0, 28.6), (12.6, 0, 27.4), (17.1, 0, 22.8), (18.2, 0, 16.0), (16.4, 0, 9.9), (11.8, 0, 8.7), (10.15, 0, 13.6), (13.0, 0, 15.6))
TAIL_SIZE = (7.8, 6.9, 5.9, 5.0, 4.0, 3.1, 2.3)


def pose(parts, phase):
    """the head nods, the forelegs paddle, the fan and the tail follow"""
    parts["Neck"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 0.6)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.2 + math.pi)
    parts["Fan"].rotation_euler.x = math.radians(7) * math.sin(2 * phase)
    for name, lag in (("LegL", 0.0), ("LegR", math.pi)):
        parts[name].rotation_euler.y = math.radians(6) * math.sin(phase + lag)
    for k, amp in enumerate((1, 2, 2, 3, 3, 4, 5)):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians(amp) * math.sin(phase - 0.5 * (k + 1))


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def on_head(a, h, y=0.0):
    return tuple(p + a * d + h * n for p, d, n in zip((POLL[0], y, POLL[2]), D, N))


def hb(part, a0, a1, h0, h1, wide, colour):
    """a box in the head's frame: a0 to a1 along to the nose, h0 to h1 out of the forehead, `wide` across"""
    part._oriented(on_head((a0 + a1) / 2, (h0 + h1) / 2), D, (0.0, 1.0, 0.0), N, (a1 - a0, wide, h1 - h0), colour, False)


def hs(part, a0, a1, h0, h1, y0, y1, colour):
    """the same, on both sides of the head, from y0 to y1 out"""
    part._oriented(on_head((a0 + a1) / 2, (h0 + h1) / 2, (y0 + y1) / 2), D, (0.0, 1.0, 0.0), N, (a1 - a0, y1 - y0, h1 - h0), colour, True)


def blade(part, base, d1, d2, length, wide, thick, colour="ring", tip="tip+"):
    """a finned blade in the side view: a broad box and a narrower, thinner one that bends on from it"""
    d1, d2 = unit(d1), unit(d2)
    mid = at(base, d1, length * 0.62)
    part.beam(base, mid, wide, thick, colour)
    part.beam(at(mid, d2, -wide * 0.42), at(mid, d2, length * 0.46), wide * 0.68, thick - 0.3, tip)


def trunk(body):
    for x0, x1, n, bot, top, belly in SLICES:
        ts, bs = (TS, BS) if n > 4 else ([(1, 1)], [(1, 1)])
        body.hull(x0, x1, n, bot, top, "body", ts, bs)
        body.paint_sym(x0, x1, n, bot, belly, "belly")
    for z in (25, 28, 31):  # the chest's scutes, between teal sides
        body.paint_sym(-11, -8, 4, z, z + 1, "belly-")
    body.paint_pair(-11, -8, 4, 5, 28, 35, "body")
    body.paint_sym(-11, -8, 4, 34, 35, "body")
    for (x0, x1), s in (((-7.1, -5.9), SLICES[1]), ((-4.1, -2.7), SLICES[2]), ((7.5, 8.5), SLICES[3])):
        body.band(x0, x1, s[2], s[3], s[4], "ring", TS, BS, proud=0.35)


def tack(body):
    x0, x1, n, bot, top, _ = BARREL
    body.band(-1.2, 6.8, n, bot, top, "cream", TS, BS, proud=0.3, stop=26.2)  # the blanket: a cream edge, red on it
    body.band(-0.4, 6.1, n, bot, top, "blanket", TS, BS, proud=0.65, stop=27.3)
    body.block(0.6, (-3.6, 3.6, 35.4, 37.9), 6.3, (-3.6, 3.6, 35.4, 37.9), "saddle")  # the seat
    body.beam((3.3, 2.8, 37.0), (3.3, 7.3, 34.7), 4.6, 1.3, "saddle", mirror=True)  # the skirts
    body.beam((3.3, 7.35, 35.3), (3.3, 7.55, 28.2), 4.2, 1.1, "saddle-", mirror=True)
    body.beam((1.6, 0, 37.0), (0.1, 0, 40.0), 2.4, 5.4, "saddle")  # the pommel, and its horn
    body.beam((0.5, 0, 39.0), (-0.5, 0, 41.6), 1.5, 1.7, "saddle-")
    body.beam((-0.4, 0, 41.2), (-0.75, 0, 42.2), 2.5, 2.7, "tip")
    body.beam((5.6, 0, 36.6), (7.5, 0, 41.2), 1.7, 7.8, "saddle-")  # the cantle
    body.beam((7.2, 0, 40.4), (7.7, 0, 41.7), 2.3, 8.3, "saddle+")
    body.block(3.0, (7.6, 8.35, 24.6, 31.4), 3.9, (7.6, 8.35, 24.6, 31.4), "saddle+", mirror=True)  # the stirrups
    body.block(2.2, (7.3, 8.7, 23.6, 24.9), 4.7, (7.3, 8.7, 23.6, 24.9), "tip", mirror=True)


def neck_and_head(m):
    neck = m.part("Neck", (-6.5, 0, 35), "Body")
    for k in range(3):
        a, b, size = NECK[k], NECK[k + 1], NECK_SIZE[k]
        d = unit(tuple(j - i for i, j in zip(a, b)))
        a2 = a if k == 0 else at(a, d, -size * 0.36)
        neck.beam(a2, at(b, d, 0.8), size, size, "body")
        front = (-d[2], 0.0, d[0])
        if k < 2:  # the pale throat
            p, q = at(at(a, d, 6.2 if k == 0 else 0.4), front, size / 2 - 0.5), at(at(b, d, -0.4), front, size / 2 - 0.5)
            neck.beam(p, q, 1.5, size - 2.6, "belly")
    c.collar(neck, NECK[0], NECK[1], NECK_SIZE[0], back=0.6, past=1.2, grow=0.9)
    c.collar(neck, NECK[1], NECK[2], NECK_SIZE[1], back=0.5, past=1.2, grow=0.9)
    # the mane: two blades on the neck, two on the head
    blade(neck, (-4.7, 0, 42.0), (0.62, 0, 0.8), (0.6, 0, 0.8), 5.0, 3.8, 1.2)
    blade(neck, (-5.8, 0, 45.4), (0.66, 0, 0.75), (0.75, 0, 0.66), 5.8, 4.0, 2.1)
    blade(neck, (-7.0, 0, 48.6), (0.72, 0, 0.7), (0.85, 0, 0.5), 6.4, 4.2, 1.5)

    head = m.part("Head", POLL, "Neck")
    hb(head, -1.0, 8.2, -4.4, 4.4, 9.0, "body")  # the skull
    hs(head, 1.2, 6.8, -4.0, -0.9, 3.5, 5.2, "body-")  # the jowls and the chin
    hb(head, 1.8, 6.2, -5.4, -3.4, 7.0, "body-")
    hb(head, 6.8, 11.0, -3.2, 2.8, 6.4, "body")  # the muzzle, the tube and its flared tip
    hb(head, 10.2, 15.6, -2.5, 1.7, 4.4, "body")
    hb(head, 14.8, 17.2, -3.2, 2.3, 5.8, "tip")
    hb(head, 16.4, 17.55, -2.0, 1.0, 3.6, "ring-")  # the mouth's hole
    hb(head, 1.4, 7.9, 3.0, 4.75, 3.4, "cream")  # the blaze
    hb(head, 7.6, 10.8, 1.0, 3.2, 2.6, "cream")
    hb(head, 10.4, 15.0, 1.0, 2.05, 1.8, "cream")
    # the eye
    e = math.radians(22)
    ed, en = (-math.cos(e), 0.0, -math.sin(e)), (-math.sin(e), 0.0, math.cos(e))
    ex, ez = on_head(4.5, 1.15)[0], on_head(4.5, 1.15)[2]

    def eye(a0, a1, h0, h1, y0, y1, colour):
        a, h = (a0 + a1) / 2, (h0 + h1) / 2
        head._oriented((ex + a * ed[0] + h * en[0], (y0 + y1) / 2, ez + a * ed[2] + h * en[2]), ed, (0.0, 1.0, 0.0), en,
                       (a1 - a0, y1 - y0, h1 - h0), colour, True)

    eye(-2.2, 2.2, -2.2, 2.2, 3.8, 5.8, "cream")
    eye(-1.5, 1.7, -1.7, 1.6, 4.4, 6.15, "black")
    eye(0.3, 1.4, 0.1, 1.2, 4.9, 6.5, "cream")
    e = math.radians(-4)  # the lid: level, a gentle look
    ed, en = (-math.cos(e), 0.0, -math.sin(e)), (-math.sin(e), 0.0, math.cos(e))
    eye(-2.2, 1.6, 1.6, 2.7, 3.6, 6.8, "body-")
    # the bridle: a headband, a noseband, a cheek strap between them, the bit's ring
    hb(head, -0.4, 0.5, 3.9, 4.8, 9.7, "saddle")
    hs(head, -0.6, 0.7, -3.9, 4.05, 4.0, 5.0, "saddle")
    hb(head, 8.9, 9.9, 2.4, 3.55, 6.9, "saddle")
    hs(head, 8.75, 10.05, -2.9, 2.5, 2.8, 3.6, "saddle")
    hb(head, 8.9, 9.9, -3.65, -2.8, 6.9, "saddle")
    hs(head, 0.1, 7.8, -1.75, -0.55, 4.0, 5.6, "saddle")
    hs(head, 6.0, 9.6, -1.6, -0.7, 2.6, 5.0, "saddle-")
    hs(head, 8.5, 10.3, -2.2, -0.3, 2.6, 4.1, "tip")
    # the coronet and the ears
    crown = on_head(0.2, 3.0)
    head.beam(crown, at(crown, unit((0.25, 0, 1)), 4.2), 3.6, 3.4, "body")
    top = at(crown, unit((0.25, 0, 1)), 3.2)
    head.beam(top, at(top, unit((0.5, 0, 1)), 3.4), 2.6, 2.4, "tip")
    prong = at(on_head(0.6, 3.2, 1.3), (0, 0, 1), 0.2)
    head.beam(prong, at(prong, unit((0.3, 0.42, 1)), 5.2), 2.2, 1.9, "tip", mirror=True)
    ear, way = on_head(0.8, 2.6, 3.0), unit((0.45, 0.75, 1))
    head.beam(ear, at(ear, way, 5.6), 3.4, 1.7, "body", mirror=True)
    head.beam(at(ear, way, 3.4), at(ear, unit((0.6, 0.8, 1)), 7.6), 2.2, 1.1, "fin", mirror=True)
    for way, length, wide, thick, gill in ((unit((0.8, 0.6, 0.5)), 7.6, 3.2, 1.3, on_head(2.2, -1.4, 3.4)),
                                           (unit((0.75, 0.6, -0.2)), 6.4, 2.6, 0.9, on_head(2.6, -2.2, 3.4))):  # the cheek fins
        head.beam(gill, at(gill, way, length), wide, thick, "fin", mirror=True)
    hs(head, 15.3, 16.3, 1.6, 2.55, 0.9, 2.0, "ring-")  # nostrils
    blade(head, on_head(0.3, -2.4), (0.66, 0, 0.75), (0.9, 0, 0.42), 7.0, 4.3, 2.4)
    blade(head, on_head(0.3, 0.6), (0.5, 0, 0.87), (0.85, 0, 0.52), 7.4, 4.3, 1.8)
    # the reins, over the neck's sides to the horn
    bit = on_head(9.4, -1.3, 3.5)
    run = (bit, (-9.6, 5.3, 41.4), (-3.2, 4.6, 39.4), (0.2, 0.3, 40.4))
    for k, (wide, thick) in enumerate(((1.4, 1.1), (1.1, 0.8), (0.8, 0.5))):
        d = unit(tuple(j - i for i, j in zip(run[k], run[k + 1])))
        neck.beam(run[k] if k == 0 else at(run[k], d, -0.35), at(run[k + 1], d, 0.5 if k < 2 else 0), wide, thick, "saddle", mirror=True)


def legs(m):
    """the pectoral fins, lifted and bent like a prancing horse's forelegs: the left one high, the right one lower"""
    for tag, s, hip, knee, foot in (("R", 1, (-7.2, 7.9, 27.6), (-13.4, 7.9, 25.8), (-11.0, 7.9, 17.8)),
                                    ("L", -1, (-7.2, 7.9, 28.4), (-14.2, 7.9, 30.6), (-13.0, 7.9, 21.4))):
        hip, knee, foot = ((x, y * s, z) for x, y, z in (hip, knee, foot))
        leg = m.part("Leg" + tag, (-7.2, 5.2 * s, hip[2]), "Body")
        u = unit(tuple(b - a for a, b in zip(hip, knee)))
        up = (-u[2], 0.0, u[0]) if u[0] > 0 else (u[2], 0.0, -u[0])
        leg._oriented((hip[0] + 0.6, 6.0 * s, hip[2]), u, (0.0, 1.0, 0.0), up, (6.0, 5.2, 6.0), "body-", False)  # the shoulder
        leg.beam(hip, at(knee, u, 2.0), 4.6, 4.2, "body")
        d = unit(tuple(b - a for a, b in zip(knee, foot)))
        leg.beam(at(knee, d, -0.4), foot, 3.4, 3.3, "body")
        leg.beam(at(foot, d, -1.0), at(foot, d, 2.0), 4.5, 4.4, "tip")  # the hoof
        back = (d[2], 0.0, -d[0])
        back = back if back[0] > 0 else tuple(-v for v in back)
        p = at(foot, d, -2.0)
        leg.beam(p, at(p, unit(tuple(b - 0.2 * a for a, b in zip(d, back))), 6.2), 3.2, 1.8, "fin")  # the feather


def build(m):
    c.stand(m, LEVEL, GAME)
    body = m.part("Body", (0, 0, 25), "Stand")
    trunk(body)
    tack(body)
    neck_and_head(m)
    legs(m)
    # the fan behind the seat
    fan = m.part("Fan", (8, 0, 33), "Body")
    root = (6.6, 0, 31.5)
    for deg, length, wide, thick in ((68, 13.0, 4.0, 2.2), (45, 14.5, 4.4, 1.55), (22, 12.0, 3.8, 0.9)):
        d = (math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg)))
        fan.beam(root, at(root, d, length - 1.6), wide, thick, "fin")
        fan.beam(at(root, d, length - 3.0), at(root, d, length), wide + 0.7, thick + 0.3, "tip")
    # the tail
    for k, size in enumerate(TAIL_SIZE):
        a, b = TAIL[k], TAIL[k + 1]
        d = unit(tuple(j - i for i, j in zip(a, b)))
        tail = m.part(f"T{k + 1}", a, f"T{k}" if k else "Body")
        end = at(b, d, 0.42 * TAIL_SIZE[k + 1]) if k < 6 else b
        tail.beam(at(a, d, -0.2 * size), end, size, size, "body")
        if k < 4:  # the pale inside of the curl
            inner = (d[2], 0.0, -d[0])
            p, q = at(a, inner, size / 2 - 0.4), at(end, inner, size / 2 - 0.4)
            tail.beam(at(p, d, 3.4 if k == 0 else 1.2), at(q, d, -1.0), 1.4, size - 2.6, "belly")
        if k == 5:
            continue
        cap = ("ring", 1.2, 0.9 if k < 4 else 0.7) if k < 6 else ("tip", 1.4, 0.4)  # an armour ring over the block's end; the last one the tip
        tail.beam(at(end, d, -cap[1]), at(end, d, 0.35 if k < 6 else 1.6), size + cap[2], size + cap[2], cap[0])
