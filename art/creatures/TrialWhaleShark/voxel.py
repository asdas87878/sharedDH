"""The Whale Shark (trial; built from the user's reference picture, a stylised green whale shark) for
tools/blender/voxel_kit.py (docs/style/creature-brief.md). Designed from the real animal and the picture.
Its idea: the gentle giant in jade. A head wider than it is deep with the mouth right across its front, a broad flat back,
and the whale shark's own pattern: thin pale lines across the back with rows of pale dots between them.
- The head is two flat slabs, the front one lower and narrower; a brow plate slopes down over the mouth and a cream chin
  plate comes up under it, so the front is a wide soft wedge, not a brick. The mouth is one dark slot the width of the
  face with a pink lower lip. The eye is small and low, just behind the mouth's corner, in a pale ring.
- The body is thirty-one slices, deep in the belly under the seat, with a quick taper behind it in five pieces; one number changes from slice to slice. The back is highest a third of the
  way along (the seat), the belly is deepest under it, and both run out to a narrow stalk before the tail.
- Cream from the belly line down. One raised ridge runs down each flank from behind the gills to the stalk.
- The colour deepens toward the tail: the last two pieces, the tail and the fin tips are a darker sea green.
- Fins: long side fins swept back and down in three boxes, the dorsal set far back as a whale shark's is, a small
  second dorsal, belly and anal fins, and a tall crescent tail with the upper lobe the longer.
The rider sits on the high back, on a saddle of three cubes between two wells for the legs."""

import math

NAME, ZONE, RARITY = "Whale Shark (trial)", "TRIAL", "EPIC"
U = 0.5
PALETTE = {"green": "#17A57E", "dusk": "#0F7C6C", "spot": "#C4F2DA", "belly": "#F5EDE0", "lip": "#F1CDC2", "maw": "#3B2A33",
           "black": "#1B2226", "ring": "#F7F3E8"}
SEAT = (-6.5, 9, 9.5)
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["green", "dusk"]}]
FRAME, ORTHO = 4.5, 64.0
SWIM = {"chain": ["Head", "B1", "B2", "B3", "B4", "B5", "Tail"], "amplitudes": [1.5, 3, 5, 8, 11, 15], "phaseStep": 0.8, "headCounter": 1.5}
EDGE = -3  # the height where the cream belly ends

# the body: (from, to, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((-24, -23, 8, -5, 6), (-23, -22, 8, -6, 6), (-22, -20, 9, -6, 6), (-20, -18, 9, -6, 7), (-18, -16, 9, -7, 7), (-16, -14, 9, -7, 8),
          (-14, -12, 9, -8, 8), (-12, -10, 9, -8, 9), (-10, -9, 9, -9, 9), (-9, -4, 9, -10, 9), (-4, -2, 8, -10, 9), (-2, 0, 8, -9, 9),
          (0, 2, 8, -8, 9), (2, 4, 7, -8, 9), (4, 5, 7, -7, 9), (5, 7, 7, -7, 8), (7, 8, 6, -7, 8), (8, 10, 6, -6, 8), (10, 11, 6, -6, 7),
          (11, 13, 5, -6, 7), (13, 14, 5, -5, 7), (14, 16, 5, -5, 6), (16, 17, 4, -5, 6), (17, 19, 4, -4, 6), (19, 20, 4, -4, 5),
          (20, 22, 3, -4, 5), (22, 24, 3, -3, 5), (24, 26, 3, -3, 4), (26, 28, 2, -3, 4), (28, 30, 2, -2, 4), (30, 33, 2, -2, 3))
PIECES = (("B1", -24, "green"), ("B2", -2, "green"), ("B3", 8, "green"), ("B4", 17, "dusk"), ("B5", 26, "dusk"))
BACK = (8, -5, 5)  # the back of the head: cubes out, bottom, top
RIDGE = (1.2, 1.8, -22, 30)  # the flank ridge: from and to in height, from and to along the body


def frame(p0, p1):
    """a box's own directions between two points: along it, across it, and through it (the one nearest to up)"""
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    thin = [r - along[2] * a for a, r in zip(along, (0.0, 0.0, 1.0))]
    n = math.sqrt(sum(v * v for v in thin))
    thin = [v / n for v in thin]
    wide = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
    return length, along, wide, thin


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def steps_for(n):
    return [(3, 1), (2, 1), (1, 1)] if n >= 7 else ([(2, 1), (1, 1)] if n >= 5 else [(1, 1)])


def dress(p, x0, x1, n, bot, top, base, lines=True):
    """a slice's colours: a lighter top row, cream from the belly line down, and the pattern: a thin pale line across the
    back and down the flank every sixth cube, and between the lines pale dots, three across the back and in rows down
    the flank"""
    p.paint_sym(x0, x1, n, top - 1, top, base + "+")
    edge = max(EDGE, bot + 1)
    p.paint_sym(x0, x1, n, bot, edge, "belly")
    if bot + 1 < edge:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    every = 6 if lines else 3
    for (i, j, k), colour in list(p.cells.items()):
        if not (x0 <= i < x1 and colour.startswith(base)):
            continue
        if lines and i % 6 == 0:
            p.cells[(i, j, k)] = "spot"
        elif i % every == (3 if lines else 0) and ((k == top - 1 and j % 4 == 0) or (edge < k < top - len(steps_for(n)) and k % 3 == 0)):
            p.cells[(i, j, k)] = "spot"


def build(m):
    hn, hbot, htop = BACK
    head = m.part("Head", (-24, 0, 0))
    # the head: two flat slabs, the front one lower and narrower. Dots but no lines, as on the real animal
    head.hull(-30, -24, hn, hbot, htop, "green", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    dress(head, -30, -24, hn, hbot, htop, "green", lines=False)
    head.hull(-35, -30, 7, -4, 4, "green", [(2, 1)], [(2, 1)])
    dress(head, -35, -30, 7, -4, 4, "green", lines=False)
    # the mouth, right across the front: a slot one cube tall and one deep, dark at the back, the lip under it pink
    head.paint(-35, -30, -8, 9, -4, -1, "belly")
    head.carve(-35, -34, -5, 6, -1, 0)
    head.paint(-34, -33, -5, 6, -1, 0, "maw")
    head.paint(-35, -34, -5, 6, -2, -1, "lip")
    # a brow plate sloping down over the mouth, and a cream chin plate coming up under it: the front becomes a wedge
    head.beam((-29.5, 0, 3.9), (-35.3, 0, 2.6), 12.4, 1.8, "green", flat="z")
    head.beam((-29.5, 0, -3.8), (-35.2, 0, -2.6), 12.0, 1.4, "belly", flat="z")
    # the eye: low, behind the mouth's corner, big and friendly: a pale ring of nine cubes, a dark pupil standing out of it, a glint
    head.pair(-34, -31, 7, 8, -1, 2, "ring")
    pupil = (7.45, 7.85, -0.4, 1.4)
    head.block(-33.4, pupil, -31.6, pupil, "black", mirror=True)
    glint = (7.8, 8.0, 0.7, 1.2)
    head.block(-33.1, glint, -32.6, glint, "ring", mirror=True)
    # gills: three long slits in the side of the head
    for x in (-29, -27, -25):
        head.dent(x, x + 1, 8, -2, 2, "dusk")

    # the body
    made, prev = {}, (hn, hbot, htop, 2)
    starts = dict((x, (name, base)) for name, x, base in PIECES)
    for x0, x1, n, bot, top in SLICES:
        steps = steps_for(n)
        if x0 in starts:
            name, base = starts[x0]
            parent = "Head" if not made else list(made)[-1]
            seg = made[name] = m.part(name, (x0, 0, 0), parent)
            fn, fbot, ftop, fsteps = prev
            clear = max(len(steps), fsteps)
            seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, base + "-")
        seg.hull(x0, x1, n, bot, top, base, steps, steps)
        dress(seg, x0, x1, n, bot, top, base)
        prev = (n, bot, top, len(steps))
    # the ridge down each flank: a strip 0.3 proud, one length to each run of slices of the same width in a piece
    z0, z1, r0, r1 = RIDGE
    ends = [x for _, x, _ in PIECES[1:]] + [SLICES[-1][1]]
    for (name, start, base), end in zip(PIECES, ends):
        runs = []
        for x0, x1, n, _, _ in SLICES:
            if x0 >= start and x1 <= end and x1 > r0 and x0 < r1:
                a, b = max(x0, r0), min(x1, r1)
                if runs and runs[-1][2] == n:
                    runs[-1] = (runs[-1][0], b, n)
                else:
                    runs.append((a, b, n))
        for a, b, n in runs:
            section = (n + 0.2, n + 0.8, z0, z1)
            made[name].block(a + 0.15, section, b - 0.15, section, base + "+", mirror=True)
    # the saddle: three cubes of back between two wells for the rider's legs
    made["B1"].carve_pair(-8, -5, 2, 4, 7, 9)

    # the side fins: three boxes swept back and down, each smaller and thinner than the last and starting inside it.
    # On top of each, pale spots like the back's: flat studs a third of a cube proud, their undersides sunk in the fin
    b1 = made["B1"]
    fins = (((-17.5, 4.5, -5.0), (-11.5, 13.5, -8.0), 9.0, 2.0, "green", ((0.45, -2.2), (0.45, 1.6), (0.8, -0.4), (0.8, 2.6))),
            ((-12.3, 12.5, -7.7), (-5.5, 19.5, -10.2), 7.0, 1.3, "green", ((0.4, -1.6), (0.4, 1.6), (0.75, 0.0))),
            ((-6.5, 18.5, -9.8), (-0.5, 23.0, -11.8), 4.4, 0.7, "dusk", ((0.45, 0.0),)))
    for side in (1, -1):
        for p0, p1, wide, thick, colour, spots in fins:
            p0, p1 = (p0[0], p0[1] * side, p0[2]), (p1[0], p1[1] * side, p1[2])
            b1.beam(p0, p1, wide, thick, colour, flat="z")
            length, along, across, thin = frame(p0, p1)
            for f, off in spots:
                mid = at(at(at(p0, along, length * f), across, off), thin, thick / 2 + 0.05)
                b1._oriented(mid, along, across, thin, (1.2, 1.2, 0.5), "spot", False)
    # the dorsal, set far back, in three boxes; the small second dorsal; the belly fins and the anal fin
    b2 = made["B2"]
    b2.beam((2.5, 0, 6.6), (6.5, 0, 13.5), 7.0, 1.5, "green")
    b2.beam((5.8, 0, 12.4), (8.8, 0, 17.0), 4.6, 1.0, "green")
    b2.beam((8.2, 0, 16.0), (9.8, 0, 18.6), 2.8, 0.6, "dusk")
    made["B4"].beam((19.6, 0, 3.8), (21.8, 0, 7.6), 2.8, 0.9, "dusk")
    made["B4"].beam((21.2, 0, 6.7), (22.6, 0, 8.8), 1.8, 0.6, "dusk-")
    made["B3"].beam((11.5, 2.0, -4.2), (14.5, 5.5, -8.0), 3.2, 0.8, "belly-", flat="z", mirror=True)
    made["B4"].beam((20.5, 0, -2.4), (22.7, 0, -5.8), 2.6, 0.8, "dusk")

    # the tail, on its own joint: a root block, a long broad upper lobe in three boxes and a shorter lower one in two.
    # Over them, fin rays: thin bright strips that fan out from inside the root block, standing a little proud on both
    # sides. They start apart and spread, so no two ever overlap
    tail = m.part("Tail", (33, 0, 0.5), "B5")
    tail.beam((32.4, 0, 0.5), (35.6, 0, 0.5), 4.4, 2.4, "dusk")
    tail.beam((34.3, 0, 1.2), (39.8, 0, 10.0), 8.4, 1.7, "dusk")
    tail.beam((38.9, 0, 8.6), (43.4, 0, 16.2), 6.6, 1.2, "dusk")
    tail.beam((42.6, 0, 14.8), (45.4, 0, 20.2), 4.6, 0.7, "dusk-")
    tail.beam((34.3, 0, -0.2), (38.2, 0, -6.6), 7.0, 1.3, "dusk")
    tail.beam((37.4, 0, -5.4), (40.2, 0, -11.0), 4.8, 0.7, "dusk-")
    for p0, p1 in (((33.4, 0, 1.9), (40.6, 0, 15.6)), ((34.3, 0, 1.5), (42.8, 0, 14.0)), ((35.0, 0, 0.9), (41.6, 0, 8.0)),
                   ((34.2, 0, -0.6), (38.6, 0, -9.8)), ((35.0, 0, -0.2), (39.8, 0, -5.6))):
        tail.beam(p0, p1, 0.7, 2.05, "green")
