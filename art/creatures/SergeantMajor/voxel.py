"""The Sergeant Major for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md). Third pass, built the way the
reference builds: from big blocks, each one a body part, some of them tilted.
- The body is a chain of slabs. The black bars are touches of colour, not shapes: bands a third of a cube proud of the
  body, which stop short of the belly. None sits where the body changes size: the first starts a cube behind the step up from the head, so the step reads
  as the body's and the bar as paint on it.
- The fins are big boxes: the back fin is three leaning plates in two yellows, the tail a stock and two lobes with darker
  tips, the side fins one paddle each. Every one starts inside the body, deep enough that its whole end is buried.
- The face is a muzzle box with a thick yellow slab leaning down it for the forehead, a jaw box under it and a cream lip
  block. The slab's upper end is buried in the head and its underside in the muzzle, so no air shows under it.
- A big framed eye, low and forward, with a glint: a friendly Common.
The rider sits behind the first bar, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Sergeant Major", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"yellow": "#FBEC7F", "pale": "#DFD8C6", "black": "#353534", "cream": "#EFE5CD", "white": "#FFFFFF"}
SEAT = (-1.5, 8, 6.6)
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [3, 6, 9, 12, 18], "phaseStep": 0.9, "headCounter": 2}

TOP, BOT = 8, -7  # the body: z [-7, 8), 6 cubes out either side
PROUD = 0.3  # how far a bar stands off the body, in cubes
BAR = 1.65  # how long a bar is, in cubes


def steps(n):
    """the corner steps of a body slab n cubes out: (top, bottom)"""
    if n >= 6:
        return [(3, 1), (1, 2)], [(3, 2), (1, 2)]
    if n >= 4:
        return [(2, 1), (1, 1)], [(2, 1), (1, 2)]
    return [(1, 1)], [(1, 1)]


def slab(p, x0, x1, n=6, top=TOP, bot=BOT):
    """a length of body: stepped corners, yellow on top (lighter on the top plate, darker on the shoulder), the belly steps
    darker"""
    steps_top, steps_bottom = steps(n)
    p.hull(x0, x1, n, bot, top, "pale", steps_top, steps_bottom)
    p.paint_sym(x0, x1, n, bot, bot + sum(t for _, t in steps_bottom), "pale-")
    p.paint_sym(x0, x1, n, top - sum(t for _, t in steps_top), top, "yellow-")
    p.paint_sym(x0, x1, n, top - 1, top, "yellow+")


def bar(p, x, n=6, top=TOP, bot=BOT):
    """a black bar over the body from x: a band a little proud of it, which stops where the belly begins, as the real
    fish's bars do. Its ends stay off the grid lines and clear of any step or slot in the body, so no end of it lies
    on, or close to, a face of the cubes"""
    steps_top, steps_bottom = steps(n)
    p.band(x, x + BAR, n, bot, top, "black", steps_top, steps_bottom, PROUD, stop=-3 - PROUD)


def build(m):
    head = m.part("Head", (-6, 0, 0))
    # the back of the head: a stepped slab, the eye on its side
    head.hull(-11, -6, 5, -6, 7, "pale", [(2, 1), (1, 1)], [(2, 2), (1, 1)])
    head.paint_sym(-11, -6, 5, 4, 7, "yellow-")
    head.paint_sym(-11, -6, 5, 6, 7, "yellow+")
    head.paint_sym(-11, -6, 5, -6, -3, "pale-")
    # the face: a muzzle box; a thick yellow slab leaning down it for the forehead, its upper end inside the head and its
    # underside inside the muzzle; a jaw box under it; a cream lip block. Each is a clear step narrower than what it
    # sits in, so no two sides lie close together
    muzzle = (-4.1, 4.1, -3.6, 3.6)
    head.block(-13.3, muzzle, -10.8, muzzle, "pale")
    head.beam((-10.385, 0, 5.257), (-13.2, 0, 2.895), 8.6, 1.9, "yellow", flat="z")
    jaw = (-3.3, 3.3, -4.9, -3.5)
    head.block(-12.6, jaw, -10.9, jaw, "pale-")
    lip = (-1.9, 1.9, -1.7, -0.2)
    head.block(-14.4, lip, -13.2, lip, "cream")
    # the eye: a cream frame one cube proud, low and forward, a big dark pupil with a glint
    head.pair(-11, -7, 6, 7, 0, 4, "cream")
    head.paint_pair(-10, -8, 6, 7, 1, 3, "black")
    head.paint_pair(-10, -9, 6, 7, 2, 3, "white")

    cuts = [-6, 0, 5, 10, 14]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(4)]
    slab(segs[0], -6, 0)
    slab(segs[1], 0, 5)
    slab(segs[2], 5, 10)
    slab(segs[3], 10, 12, n=5, top=7, bot=-6)
    slab(segs[3], 12, 14, n=3, top=5, bot=-4)
    bar(segs[0], -4.85)  # a cube behind the step up from the head
    bar(segs[1], 0.15)
    bar(segs[2], 5.15)
    bar(segs[3], 10.15, n=5, top=7, bot=-6)
    for i, s in enumerate(segs):  # a sleeve one cube into the piece in front, so a bending joint shows body
        if i < 3:
            s.sym(cuts[i] - 1, cuts[i], 4, -4, 5, "pale-")
        else:
            s.sym(cuts[i] - 1, cuts[i], 3, -3, 4, "pale-")
    # the seat: between the first two bars, with a shallow slot either side for the rider's legs
    segs[0].dent(-3, 0, 6, 1, 5, "pale-")

    # the back fin, behind the rider: three leaning plates, the middle one tallest, in two yellows
    segs[1].beam((2.6, 0, 7.5), (3.8, 0, 12.4), 3.4, 1.3, "yellow")
    segs[2].beam((7.3, 0, 7.5), (8.7, 0, 13.8), 3.6, 1.3, "yellow-")
    segs[3].beam((11.0, 0, 6.2), (11.9, 0, 9.4), 1.8, 1.3, "yellow")
    # the fin underneath: two plates, the second thinner
    segs[2].beam((6.6, 0, -6.4), (7.6, 0, -9.8), 3.0, 1.3, "yellow")
    segs[2].beam((8.6, 0, -6.0), (9.3, 0, -8.6), 2.2, 1.0, "yellow-")
    # the side fins: one paddle each, starting inside the body's side under the seat and swept back; small belly fins
    segs[0].beam((-2.6, 6.0, -1.0), (1.0, 8.6, -2.2), 3.0, 0.9, "yellow", mirror=True)
    segs[0].beam((-3.6, 2.4, -6.3), (-1.8, 2.9, -9.6), 1.8, 0.8, "yellow-", mirror=True)

    # the tail, on its own joint: a thick stock that starts inside the body, and two lobes that meet at a point on it,
    # each ending in a thinner, darker tip
    tail = m.part("Tail", (14, 0, 0), "S4")
    tail.beam((13.5, 0, 0.5), (16.4, 0, 0.5), 6.4, 2.4, "yellow-")
    tail.beam((14.6, 0, 2.2), (18.6, 0, 6.2), 4.8, 1.1, "yellow")
    tail.beam((17.6, 0, 5.2), (20.6, 0, 8.6), 3.6, 0.8, "yellow-")
    tail.beam((14.6, 0, -1.2), (18.6, 0, -5.2), 4.8, 1.1, "yellow")
    tail.beam((17.6, 0, -4.2), (20.6, 0, -7.6), 3.6, 0.8, "yellow-")
