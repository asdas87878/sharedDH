"""The Swordfish (zone 5's Rare) for tools/blender/voxel_kit.py (docs/style/creature-brief.md).
Its idea: the sword. A long flat blade for a nose, a third of the whole fish, on a sleek dark blue body.
- The body is a chain of slabs that changes one thing at a time: the back climbs behind the head to a long plateau and
  falls away to a slim stalk, the belly dips under the rider and climbs to it. Dark blue above, silver below, one thin lighter line between them from
  the head to the tail.
- The head is not a box: a narrow skull, gill covers a cube wider behind it, a sloping forehead block, then two snout blocks in a chain, each lower and
  narrower, and the sword starts inside the last: three flat boxes, each thinner, and a point. A short pointed lower jaw
  under it, a dark mouth line between.
- A big eye (silver ring, dark pupil) under a short brow.
- A tall crescent back fin behind the head (three boxes, each swept further back), long narrow side fins set low,
  a small fin under the belly, and a wide crescent tail on the stalk, with a keel either side of it.
The rider sits behind the back fin, legs in a slot either side."""
NAME, ZONE, RARITY = "Swordfish", "ZONE 5 / OPEN BLUE", "RARE"
U = 0.4
PALETTE = {"blue": "#263F73", "silver": "#D3DAE0", "line": "#6C97D2", "black": "#1E232B", "mouth": "#3A2A3C"}
SEAT = (0, 5, 3.6)
FRAME, ORTHO = 2.05, 29.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["blue"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "Tail"], "amplitudes": [1, 2, 4, 6, 9, 12, 18], "phaseStep": 0.7,
        "headCounter": 2}

HEAD = ((-15, -12, 2, -3, 3), (-12, -10, 3, -3, 3))  # the skull, then the gill covers, a cube wider: (from, to, out, bottom, top)
# the body: (part, from, to, cubes out, bottom, top). One number changes from slice to slice. The back climbs in two short
# steps to a long plateau and falls away in longer ones; the belly dips under the rider and climbs to the stalk
BODY = (("S1", -10, -8, 3, -3, 4), ("S1", -8, -4, 3, -3, 5), ("S2", -4, 2, 3, -4, 5), ("S3", 2, 5, 3, -4, 4), ("S4", 5, 7, 3, -3, 4),
        ("S4", 7, 9, 3, -3, 3), ("S5", 9, 11, 2, -3, 3), ("S5", 11, 13, 2, -2, 3), ("S6", 13, 15, 1, -2, 3), ("S6", 15, 17, 1, -2, 2),
        ("S6", 17, 19, 1, -1, 2))


def steps(n, bot, top):
    """the corners: one step on the back; two under the belly where the body is deep, one where it is not"""
    up = [(1, 1)] if n >= 2 else []
    down = [(2, 1), (1, 1)] if (n >= 3 and top - bot >= 7) else ([(1, 1)] if n >= 2 else [])
    return up, down


def slab(p, x0, x1, n, bot, top):
    """a length of body: dark blue, lighter on the top row, silver below, one lighter line where they meet"""
    up, down = steps(n, bot, top)
    p.hull(x0, x1, n, bot, top, "blue", up, down)
    belly = -1 if bot <= -2 else 0
    p.paint_sym(x0, x1, n, top - 1, top, "blue+")
    p.paint_sym(x0, x1, n, belly, belly + 1, "line")
    p.paint_sym(x0, x1, n, bot, belly, "silver")
    if down:
        p.paint_sym(x0, x1, n, bot, bot + 1, "silver-")


def build(m):
    head = m.part("Head", (-10, 0, 0))
    for piece in HEAD:  # a narrow skull with the eye on its side, and the gill covers behind it, as wide as the body
        slab(head, *piece)
    # the forehead: one narrow block sloping down from the nape to the snout, so the head's top line falls to the sword
    head.beam((-11.5, 0, 2.0), (-17.5, 0, 1.2), 2.6, 1.6, "blue+", flat="z")
    # the snout: two blocks in a chain, each tilted nose-down, lower and narrower than the last
    head.beam((-13.5, 0, 0.35), (-18.0, 0, 0.0), 4.4, 3.0, "blue", flat="z")
    head.beam((-17.2, 0, 0.3), (-21.0, 0, 0.0), 3.2, 2.0, "blue", flat="z")
    # the sword: three flat boxes in a chain, each narrower and thinner and starting inside the last, and a point
    head.beam((-20.0, 0, 0.0), (-27.0, 0, -0.1), 2.6, 1.1, "blue-", flat="z")
    head.beam((-26.0, 0, -0.08), (-32.5, 0, -0.17), 1.9, 0.75, "blue-", flat="z")
    head.beam((-31.5, 0, -0.16), (-35.2, 0, -0.21), 1.2, 0.4, "blue-", flat="z")
    head.spike([(-34.9, -0.4, -0.32), (-34.9, 0.4, -0.32), (-34.9, 0.4, -0.09), (-34.9, -0.4, -0.09)], (-36.3, 0, -0.22), "blue-")
    # the lower jaw: short and pointed, two boxes; a dark mouth line between it and the snout, set inside both lips
    head.beam((-11.8, 0, -2.36), (-18.2, 0, -2.15), 3.6, 0.9, "silver", flat="z")
    head.beam((-17.4, 0, -2.2), (-22.0, 0, -1.55), 2.4, 0.9, "silver", flat="z")
    mouth = (-1.4, 1.4, -2.0, -0.9)
    head.block(-17.7, mouth, -13.9, mouth, "mouth")
    mouth = (-0.8, 0.8, -1.9, -0.6)
    head.block(-20.6, mouth, -17.6, mouth, "mouth")
    # the eye: big, a silver ring and a dark pupil standing out of it, under a short brow that cuts its top
    ring = (2.35, 2.8, -0.1, 1.9)
    head.block(-14.5, ring, -12.6, ring, "silver", mirror=True)
    pupil = (2.7, 3.1, 0.35, 1.5)
    head.block(-14.1, pupil, -13.1, pupil, "black", mirror=True)
    head.beam((-14.7, 2.3, 1.7), (-11.7, 2.3, 2.15), 1.0, 2.0, "blue", mirror=True)

    parts, before = {}, ("Head",) + HEAD[-1][2:]
    for name, x0, x1, n, bot, top in BODY:
        if name not in parts:
            parts[name] = m.part(name, (x0, 0, 0), before[0])
            # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces
            # and clear of both pieces' corner steps
            pn, pbot, ptop = before[1:]
            up = max(len(steps(n, bot, top)[0]), len(steps(pn, pbot, ptop)[0]))
            down = max(len(steps(n, bot, top)[1]), len(steps(pn, pbot, ptop)[1]))
            parts[name].sym(x0 - 1, x0, max(min(n, pn) - 1, 0), max(bot, pbot) + down, min(top, ptop) - up, "blue-")
        slab(parts[name], x0, x1, n, bot, top)
        before = (name, n, bot, top)
    s1, s2, s5, s6 = parts["S1"], parts["S2"], parts["S5"], parts["S6"]
    s1.dent(-9, -8, 3, -1, 2, "blue-")  # the gill slit behind the cover
    s2.dent(-1, 1, 3, 1, 4, "blue-")  # the seat: a slot either side for the rider's legs

    # the back fin: tall, on the front of the back's plateau, a crescent: three boxes, each smaller and swept further back
    s1.beam((-6.1, 0, 3.8), (-4.9, 0, 8.4), 3.8, 1.2, "blue")
    s1.beam((-5.4, 0, 7.6), (-4.0, 0, 11.0), 2.5, 0.9, "blue")
    s1.beam((-4.5, 0, 10.2), (-2.8, 0, 11.9), 1.6, 0.6, "blue-")
    # the side fins: long and narrow, set low, swept back and down
    s1.beam((-8.3, 1.8, -1.5), (-6.2, 5.6, -2.7), 2.2, 1.0, "blue", flat="z", mirror=True)
    s1.beam((-6.8, 4.8, -2.45), (-3.6, 8.2, -3.7), 1.6, 0.65, "blue", flat="z", mirror=True)
    s1.beam((-4.3, 7.5, -3.45), (-2.2, 9.2, -4.2), 1.1, 0.3, "blue-", flat="z", mirror=True)
    # a fin under the belly, and a tiny second back fin near the tail
    s5.beam((10.2, 0, -2.2), (11.8, 0, -4.6), 2.0, 0.8, "blue")
    s5.beam((11.3, 0, -3.9), (12.6, 0, -5.6), 1.3, 0.5, "blue-")
    s6.beam((13.6, 0, 2.5), (14.6, 0, 4.0), 1.1, 0.6, "blue-")
    # a keel either side of the stalk
    s6.beam((16.3, 1.6, 0.5), (18.6, 1.6, 0.5), 1.4, 0.6, "blue-", flat="z", mirror=True)

    # the tail, on its own joint: a root block and a wide crescent, each lobe three boxes swept further back
    tail = m.part("Tail", (19, 0, 0.5), "S6")
    tail.beam((18.3, 0, 0.5), (20.8, 0, 0.5), 2.4, 1.4, "blue")
    for s in (1, -1):
        def z(v):
            return 0.5 + s * (v - 0.5)

        tail.beam((19.4, 0, z(0.9)), (20.6, 0, z(4.8)), 2.6, 1.0, "blue")
        tail.beam((20.2, 0, z(4.0)), (22.0, 0, z(7.4)), 1.9, 0.7, "blue")
        tail.beam((21.6, 0, z(6.8)), (22.9, 0, z(8.3)), 1.3, 0.4, "blue-")
