"""The Hammerhead Shark, a trial of docs/style/07-shape-variety.md, for tools/blender/voxel_kit.py. A great hammerhead,
designed from the real animal. Its body idea is "the hammer": the head is the whole design, the rest is kept slim.
- The hammer is a plank two cubes thick and 27 across (over half the animal's length). Its front edge is not a bar: a
  notch at the centre, a long lobe either side, and the ends stepped back, so it reads as a shallow scallop swept back.
- An eye on each end: a pale block taller than the plank, the dark pupil on its front outer corner, so it shows from the
  side and from the front.
- A thin neck (3 cubes wide, then 5) joins it to the slimmest body of our sharks: 7 cubes deep at most on 50 long.
- The tallest back fin: narrow, nearly upright, almost twice the body's depth. A long upper tail lobe.
- The mouth is a small downturned slit cut into the underside of the hammer. No teeth on show.
- Copper-bronze on cream, the line between them low and straight. The one mark: a darker bronze band along the
  hammer's front edge, one block deep.
The rider sits on the back between the neck and the back fin, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Hammerhead Shark (trial)", "ZONE 4 / SHIPWRECKS", "RARE"
U = 0.4
PALETTE = {"back": "#B5713A", "belly": "#F2E7CC", "band": "#6B4022", "eye": "#FFF7E0", "black": "#1F2225",
           "mouth": "#4A2622"}
SEAT = (-8, 4, 3.6)
FRAME, ORTHO = 2.3, 31.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "Tail"], "amplitudes": [2, 3, 4, 6, 8, 10, 13, 18],
        "phaseStep": 0.6, "headCounter": 3}

LINE = -1  # the height where bronze meets cream: low, and the same along the whole flank
# the neck (part of the head) and the body: (part, from, to, cubes out, bottom, top)
NECK = (("Head", -20, -17, 1, -2, 2), ("Head", -17, -14, 2, -2, 3))
SLICES = (("S1", -14, -10, 3, -3, 3), ("S2", -10, -5, 3, -3, 4), ("S3", -5, 0, 3, -3, 4), ("S4", 0, 4, 3, -3, 3),
          ("S5", 4, 8, 2, -3, 3), ("S6", 8, 11, 2, -2, 3), ("S6", 11, 14, 2, -2, 2), ("S7", 14, 17, 1, -2, 2),
          ("S7", 17, 20, 1, -2, 1))
# the hammer seen from above: (columns from, to, front, back). The mirror is made for you
HAMMER = ((0, 2, -24, -20), (2, 9, -25, -20), (9, 12, -24, -19), (12, 14, -23, -19))


def steps(n):
    """the corner steps: one where the body is wide enough to carry it, none on the neck and the tail stock"""
    return [(1, 1)] if n >= 2 else []


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, cream below the line"""
    p.hull(x0, x1, n, bot, top, "back", steps(n), steps(n))
    p.paint_sym(x0, x1, n, bot, max(LINE, bot + 1), "belly")


def build(m):
    head = m.part("Head", (-14, 0, 0))
    # the hammer: a plank two cubes thick, bronze on top and cream underneath, a darker band on its front edge
    for j0, j1, front, back in HAMMER:
        head.pair(front, back, j0, j1, -1, 1, "back")
    head.paint_sym(-25, -19, 13, -1, 0, "belly")
    for j0, j1, front, back in HAMMER:
        head.paint_pair(front, front + 1, j0, j1, 0, 1, "band")
    for i, j in ((-24, 2), (-24, 8), (-23, 11)):  # the band turns the corner at each step, so it is one line
        head.paint_pair(i, i + 1, j, j + 1, 0, 1, "band")
    for name, x0, x1, n, bot, top in NECK:
        slab(head, x0, x1, n, bot, top)

    # an eye on each end: a pale block standing off the plank's end, a cap above and below so it is taller than the
    # plank, and the pupil wrapped round its front outer corner so it shows from the side and from the front
    head.pair(-23, -20, 14, 16, -1, 1, "eye")
    for z0, z1 in ((0.9, 1.45), (-1.45, -0.9)):
        cap = (13.8, 15.2, z0, z1)
        head.block(-22.7, cap, -20.3, cap, "eye", mirror=True)
    front = (14.3, 15.3, -0.75, 0.75)
    head.block(-23.35, front, -22.6, front, "black", mirror=True)
    side = (15.2, 15.8, -0.6, 0.6)
    head.block(-23.2, side, -21.6, side, "black", mirror=True)

    # the mouth: a small downturned slit cut into the underside of the hammer, its corners turned back
    head.carve(-23, -22, -2, 3, -1, 0)
    head.carve_pair(-22, -21, 2, 3, -1, 0)
    slit = (-2.5, 2.5, -0.7, 0.05)
    head.block(-23, slit, -22, slit, "mouth")
    corner = (1.5, 2.5, -0.7, 0.05)
    head.block(-22, corner, -21, corner, "mouth", mirror=True)

    # the body: slices on their own joints, each with a sleeve into the piece in front
    parts, before = {}, NECK[-1]
    for name, x0, x1, n, bot, top in SLICES:
        if name not in parts:
            parent = "Head" if not parts else list(parts)[-1]
            parts[name] = m.part(name, (x0, 0, 0), parent)
            fn, fbot, ftop = before[3:]
            deep = max(len(steps(n)), len(steps(fn)))
            parts[name].sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + deep, min(top, ftop) - deep, "back-")
        slab(parts[name], x0, x1, n, bot, top)
        before = (name, x0, x1, n, bot, top)
    for x in (-13, -11):  # gill slits: two short quiet lines
        parts["S1"].dent(x, x + 1, 3, 0, 2, "back-")
    parts["S2"].dent(-9, -7, 3, 0, 3, "back-")  # the rider's leg slots

    # the back fin: the tallest of our sharks. Narrow, nearly upright, three boxes each starting inside the last
    s3 = parts["S3"]
    s3.beam((-2.2, 0, 2.6), (-0.8, 0, 9.2), 4.0, 1.3, "back")
    s3.beam((-1.3, 0, 8.2), (0.3, 0, 13.8), 2.9, 1.0, "back")
    s3.beam((-0.2, 0, 12.9), (1.1, 0, 17.2), 1.9, 0.7, "back-")
    s1 = parts["S1"]  # the side fins: slim, swept back
    s1.beam((-12.4, 2.2, -1.4), (-10.0, 5.8, -2.0), 2.7, 0.9, "back", flat="z", mirror=True)
    s1.beam((-10.5, 5.2, -1.9), (-8.7, 7.8, -2.4), 1.9, 0.6, "back", flat="z", mirror=True)
    s1.beam((-9.1, 7.2, -2.3), (-7.9, 9.0, -2.6), 1.3, 0.3, "back-", flat="z", mirror=True)
    parts["S6"].beam((9.0, 0, 2.4), (10.4, 0, 4.8), 1.6, 0.8, "back")  # the small second back fin
    parts["S5"].beam((4.8, 0.5, -1.9), (6.6, 2.2, -3.8), 1.6, 0.5, "back", flat="z", mirror=True)  # the belly fins

    # the tail, on its own joint: a root block, a long upper lobe in three boxes and a short lower one
    tail = m.part("Tail", (20, 0, 0), "S7")
    tail.beam((19.4, 0, -0.5), (21.6, 0, -0.5), 2.6, 1.4, "back")
    tail.beam((20.4, 0, -0.2), (22.6, 0, 4.6), 3.2, 1.1, "back")
    tail.beam((22.0, 0, 3.8), (23.9, 0, 8.6), 2.4, 0.8, "back")
    tail.beam((23.4, 0, 7.8), (24.6, 0, 11.8), 1.7, 0.5, "back-")
    tail.beam((20.4, 0, -0.8), (22.2, 0, -4.0), 2.6, 0.8, "back")
    tail.beam((21.8, 0, -3.4), (22.9, 0, -5.6), 1.8, 0.5, "back-")
