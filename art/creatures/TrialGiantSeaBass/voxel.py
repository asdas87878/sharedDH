"""The Giant Sea Bass, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the
game's Giant Sea Bass (art/creatures/GiantSeaBass) and replaces nothing. Designed from the real animal.
Its idea: the boulder. A very deep, grumpy fish with a saw on its back and a giant frown.
- The body idea in numbers: about 45 cubes long; the body alone is 21 deep (0.46 of the length) and 15 wide (0.33),
  deepest two fifths of the way back; the head with its gill cover is two fifths of the length. Behind the deepest
  slice the back and the belly close in one cube at a time to a short thick stalk and a broad square tail.
- The forehead is two big blocks tilted nose-down on one straight line from the snout to the nape.
- The face: a giant frown. A wide mouth at the very front, its lips running back and DOWN to the corners, so they
  turn down seen from the front too; the lower jaw juts a full cube past the upper, a row of small teeth on it. Thick
  raised lips in pale pink-cream. Small eyes set high under a heavy level brow.
- The back fin: a saw of nine separate spines, tallest in the middle, then a soft rounded lobe. Big round side fins.
- Plum over lilac, the line low and gently wavy. The one mark: big indigo spots, 2 by 2 blocks, eight a side.
The rider sits on the nape, in front of the saw, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Giant Sea Bass (trial)", "ZONE 3 / KELP FOREST", "RARE"
U = 0.45
PALETTE = {"plum": "#7B5698", "lilac": "#DCCFE6", "lip": "#F1D9CF", "indigo": "#4B3276", "black": "#16131C"}
SHADE = 0.9
SEAT = (-2.5, 10, 6.6)
FRAME, ORTHO = 1.9, 26.0
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["plum"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [1, 3, 5, 8, 13], "phaseStep": 0.8, "headCounter": 2}

# the body in one-cube columns: x -> (cubes out, bottom, top). From one column to the next ONE number changes by one
COLS = {-4: (7, -10, 10)}
for x in range(-3, 1):
    COLS[x] = (7, -11, 10)  # the deepest slices, two fifths of the way back
for x, c in zip(range(1, 18), ((7, -10, 10), (7, -9, 10), (7, -9, 9), (7, -8, 9), (6, -8, 9), (6, -8, 8), (6, -7, 8), (6, -7, 7),
                               (5, -7, 7), (5, -6, 7), (5, -6, 6), (5, -5, 6), (4, -5, 6), (4, -5, 5), (4, -4, 5), (4, -4, 4),
                               (3, -4, 4))):
    COLS[x] = c
# the head behind the mouth (the cheeks and the gill cover): its top is buried in the forehead blocks
HEAD_COLS = dict(zip(range(-16, -4), ((4, -6, 3), (5, -6, 3), (5, -7, 3), (5, -8, 4), (6, -8, 4), (6, -9, 4), (6, -9, 5), (7, -9, 5),
                                       (7, -10, 5), (7, -10, 5), (7, -10, 5), (7, -10, 5))))
PARTS = (("S1", -4, 2), ("S2", 2, 7), ("S3", 7, 12), ("S4", 12, 18))
WAVE = (0, 0, 0, 1, 1, 1, 1, 0, 0, 0, -1, -1, -1, -1)  # the colour line's gentle wave: a cube up or down in runs of three and four


def line(x, bot, top):
    """lilac below this height: low on the flank (a third of the way up at the deepest) and gently wavy"""
    return max(bot + 2, -4 + WAVE[(x + 20) % len(WAVE)])


def steps(n):
    """the corners of the back and the belly: a boulder's broad steps where the body is thick, fewer as it thins"""
    if n >= 7:
        return [(4, 1), (2, 1), (1, 2)]
    return [(3, 1), (2, 1), (1, 1)] if n == 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def clear(n):
    return sum(t for _, t in steps(n))


def column(p, x, n, bot, top, tops=None):
    p.hull(x, x + 1, n, bot, top, "plum", steps(n) if tops is None else tops, steps(n))
    if tops is None:
        p.paint_sym(x, x + 1, n, top - 1, top, "plum+")
    p.paint_sym(x, x + 1, n, bot, line(x, bot, top), "lilac")


# the forehead: one straight line from the snout to the nape; its blocks lie with their tops on it
SLOPE = 0.42
COS = 1 / math.sqrt(1 + SLOPE * SLOPE)


def brow_line(x):
    return 2.95 + (x + 20) * SLOPE


def forehead(p, xa, xb, wide, thick, colour, sink=0.0):
    """a block whose top lies `sink` under the forehead line from xa (front) to xb (back)"""
    drop = thick / 2 / COS + sink
    p.beam((xa, 0, brow_line(xa) - drop), (xb, 0, brow_line(xb) - drop), wide, thick, colour, flat="z")


def rod(p, a, b, size, colour, mirror=False):
    """a lip: a thick square rod from a to b"""
    p.beam(a, b, size, size, colour, flat="z", mirror=mirror)


def disc(p, root, along, r_along, r_up, thick, colour):
    """a round fin: an octagon `thick` through, from its root (buried in the flank) out along `along`, upright, mirrored"""
    n = math.sqrt(sum(v * v for v in along))
    a = [v / n for v in along]
    up = (0.0, 0.0, 1.0)
    t = [a[1] * up[2] - a[2] * up[1], a[2] * up[0] - a[0] * up[2], a[0] * up[1] - a[1] * up[0]]  # its thin side
    tn = math.sqrt(sum(v * v for v in t))
    t = [v / tn for v in t]
    centre = [r + v * r_along for r, v in zip(root, a)]
    verts = []
    for side in (-1, 1):
        for k in range(8):
            ang = math.pi / 8 + k * math.pi / 4
            ca, cu = math.cos(ang) * r_along, math.sin(ang) * r_up
            verts.append(tuple(c + ca * av + cu * uv + side * thick / 2 * tv for c, av, uv, tv in zip(centre, a, up, t)))
    faces = [tuple(range(8)), tuple(range(15, 7, -1))] + [(k, (k + 1) % 8, 8 + (k + 1) % 8, 8 + k) for k in range(8)]
    p.solid(verts, faces, colour, mirror=True)


def build(m):
    head = m.part("Head", (-4, 0, 0))
    for x, (n, bot, top) in HEAD_COLS.items():
        column(head, x, n, bot, top, tops=[])
    head.dent(-5, -4, 7, -5, 4, "plum-")  # the gill cover's edge
    forehead(head, -12.0, -3.6, 13.6, 6.5, "plum")
    forehead(head, -18.6, -11.0, 10.0, 4.8, "plum", 0.35)
    forehead(head, -20.4, -17.8, 7.0, 3.2, "plum", 0.7)

    # THE MOUTH: a giant frown. The upper lip: a rod across the front and a rod each side running back and DOWN to the
    # corner. The lower lip the same a full cube further forward and lower. The dark inside sits behind them
    head.block(-20.2, (-3.0, 3.0, -3.4, -1.2), -14.6, (-5.0, 5.0, -6.6, -3.4), "indigo")
    rod(head, (-20.2, -3.2, -1.2), (-20.2, 3.2, -1.2), 1.7, "lip")
    rod(head, (-20.2, 1.6, -1.2), (-14.2, 6.0, -5.6), 1.7, "lip", mirror=True)
    rod(head, (-21.3, -3.4, -3.0), (-21.3, 3.4, -3.0), 1.7, "lip")
    rod(head, (-21.3, 1.8, -3.0), (-14.4, 5.9, -6.9), 1.7, "lip", mirror=True)
    # a row of small teeth on the jutting lower lip, in front of the upper one
    for y in (-2.4, -0.8, 0.8, 2.4):
        head.tooth(-21.5, y, -2.3, 0.6, -0.6, "lip+", mirror=False)
    # the jaw under the lower lip: three blocks, each starting inside the last, down to the throat
    head.beam((-21.3, 0, -4.1), (-17.4, 0, -5.5), 5.6, 2.0, "lilac", flat="z")
    head.beam((-18.2, 0, -5.4), (-11.6, 0, -7.8), 9.7, 2.8, "lilac", flat="z")

    # the eye: small and high, a lilac ring and a dark pupil, under a heavy LEVEL brow (grumpy, not evil)
    ring = (6.2, 7.0, 3.6, 5.6)
    head.block(-11.6, ring, -9.6, ring, "lilac+", mirror=True)
    pupil = (6.5, 7.25, 4.0, 5.2)
    head.block(-11.2, pupil, -10.0, pupil, "black", mirror=True)
    head.beam((-12.4, 6.6, 6.2), (-9.0, 6.6, 6.2), 1.7, 1.2, "plum", flat="y", mirror=True)

    segs, before = {}, HEAD_COLS[-5]
    for i, (name, x0, x1) in enumerate(PARTS):
        seg = segs[name] = m.part(name, (x0, 0, 0), "Head" if i == 0 else PARTS[i - 1][0])
        for x in range(x0, x1):
            column(seg, x, *COLS[x])
        n, bot, top = COLS[x0]
        fn, fbot, ftop = before
        gap = max(clear(n), clear(fn))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + gap, min(top, ftop) - gap, "plum-")
        before = COLS[x1 - 1]
    s1, s2, s3, s4 = (segs[name] for name, _, _ in PARTS)
    s1.dent(-3, -1, 6, 6, 8, "plum-")  # the rider's leg slots

    # THE MARK: big indigo spots, 2 by 2 blocks, eight a side on the flank behind the head, flush
    for x, z in ((-3, 2), (-1, -4), (1, 3), (3, -2), (5, 2), (7, -3), (9, 1), (12, -1)):
        for p, (name, x0, x1) in zip((s1, s2, s3, s4), PARTS):
            for xx in (x, x + 1):
                if x0 <= xx < x1:
                    n = COLS[xx][0]
                    p.paint_pair(xx, xx + 1, n, n + 1, z, z + 2, "indigo")

    # the saw: nine separate thin spines, tallest in the middle, each a tall box standing on the back, raked a little
    for k, h in enumerate((2.5, 3.6, 4.6, 5.4, 5.8, 5.4, 4.6, 3.6, 2.6)):
        x = 0.4 + k
        top = COLS[int(math.floor(x))][2]
        seg = s1 if x < 2 else (s2 if x < 7 else s3)
        seg.beam((x, 0, top - 0.7), (x + 0.5, 0, top + h), 0.6, 0.5, "plum")
    # the soft lobe behind it: two rounded boxes, low and long
    s3.beam((9.3, 0, 6.0), (12.6, 0, 7.4), 3.0, 0.9, "plum")
    s3.beam((10.0, 0, 6.6), (11.8, 0, 8.6), 2.0, 0.5, "plum")

    # the side fins: big and round, a fan of three paddles splayed out from the flank behind the gill cover
    disc(s1, (-3.2, 6.6, -3.0), (1.0, 0.6, -0.12), 3.0, 2.9, 0.7, "plum")
    # the anal fin (the belly fins are left out: they would hang under the seat's slice and cost triangles)
    s3.beam((8.4, 0, -5.2), (11.4, 0, -8.4), 2.4, 0.8, "lilac")

    # the tail, on its own joint: a short deep stock, a broad square fan with a straight rear edge, and three thicker
    # rays on it (the middle one level, one up and back, one down and back), their roots in the stock
    tail = m.part("Tail", (18, 0, 0), "S4")
    tail.sym(18, 20, 2, -4, 4, "plum")
    tail.sym(17, 18, 1, -1, 2, "plum-")  # its sleeve
    tail.prism(((18.6, -2.4), (20.9, -6.8), (23.0, -8.0), (23.0, 9.0), (20.9, 7.8), (18.6, 3.4)), -0.5, 0.5, "plum-")
    tail.beam((19.0, 0, 0.5), (22.5, 0, 0.5), 2.4, 1.7, "plum")
    for s in (1, -1):
        tail.beam((19.0, 0, 0.5 + 1.0 * s), (21.8, 0, 0.5 + 6.2 * s), 2.2, 1.3, "plum")
