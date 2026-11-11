"""The Leopard Shark (zone 3's Rare: the slim spotted shark of the kelp forest) for tools/blender/voxel_kit.py
(docs/style/creature-brief.md). Designed from the real animal: long and slim, a short blunt snout with the mouth set
back underneath, the first back fin a third of the way down, a second one nearly as big, a long low upper tail lobe.
Its one feature is the pattern: thin dark saddles across the back, one to a slice and never on a joint, and single dark
spots low on the flank between them. Everything else stays plain: sandy grey over a pale belly.
- The body is a head and six slices on joints, each one step slimmer than the last (the belly rises, then the width and
  the back come in).
- The snout is three tilted blocks in a chain, flat underneath, with a pale lip plate; the jaw is one short box under it.
- Every fin is two or three angled boxes, each smaller and thinner than the last and starting inside it.
- A calm eye: a dark pupil on a pale ring, under a level brow that only sits on it.
The rider sits behind the gills, in front of the back fin, legs in a slot either side."""
NAME, ZONE, RARITY = "Leopard Shark", "ZONE 3 / KELP FOREST", "RARE"
U = 0.4
PALETTE = {"sand": "#A5A091", "belly": "#EEE9DB", "dark": "#473F3A", "black": "#22262B", "mouth": "#6A2A32"}
SEAT = (-7, 4, 3.6)
FRAME, ORTHO = 1.55, 22.5
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["sand"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "Tail"], "amplitudes": [2, 3, 5, 7, 9, 12, 17], "phaseStep": 0.75,
        "headCounter": 2}

STEP = [(1, 1)]
HEAD = (-18, -13, 3, -3, 3, -1)  # x from, x to, cubes out, bottom, top, the belly's edge
# the body's slices, one part each: (x from, x to, cubes out, bottom, top, the belly's edge)
SLICES = ((-13, -6, 3, -3, 4, -1), (-6, 0, 3, -3, 4, -1), (0, 4, 3, -2, 4, 0), (4, 8, 2, -2, 4, 0), (8, 11, 2, -2, 3, 0),
          (11, 13, 2, -1, 3, 0))
STOCK = (13, 15, 1, -1, 3, 0)  # the tail's stock: the end of the last slice
SADDLE = 1  # the saddles come down the flank to this height


def slab(p, x0, x1, n, bot, top, belly):
    """a length of body: sandy grey, a lighter top row, pale from `belly` down, one step cut from every corner"""
    steps = STEP if n >= 2 else []
    p.hull(x0, x1, n, bot, top, "sand", steps, steps)
    p.paint_sym(x0, x1, n, top - 1, top, "sand+")
    p.paint_sym(x0, x1, n, bot, belly, "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def saddle(p, x0, x1, n, bot, top):
    """a dark saddle across the back: a thin raised band that stops halfway down the flank"""
    steps = STEP if n >= 2 else []
    p.band(x0, x1, n, bot, top, "dark", steps, steps, stop=SADDLE)


def spot(p, x, n, z):
    """one dark spot on the flank, either side: a cube of the outer column painted"""
    p.paint_pair(x, x + 1, n, n + 1, z, z + 1, "dark")


def build(m):
    head = m.part("Head", (-13, 0, 0))
    slab(head, *HEAD)
    # the snout: three blocks in a chain, each tilted nose-down, narrower and thinner than the last and starting inside
    # it. Their undersides lie in one line (a shark's flat chin); their tops step down to a blunt tip. A pale lip plate
    # under each
    for x0, x1, z0, z1, wide, thick in ((-17.5, -19.8, 0.6, 0.3, 6.0, 3.0), (-19.3, -21.1, 0.25, 0.0, 5.0, 2.3),
                                        (-20.7, -21.85, -0.05, -0.25, 3.6, 1.6)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "sand", flat="z")
        lip = thick / 2 + 0.35
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.7, "belly", flat="z")
    # the mouth: low, set back under the snout. One short jaw box; the dark inside stays behind the lips
    mouth = (-1.9, 1.9, -2.3, -1.5)
    head.block(-19.8, mouth, -17.7, mouth, "mouth")
    head.beam((-17.6, 0, -2.4), (-20.1, 0, -2.5), 4.6, 0.8, "belly", flat="z")
    # the eye: a pale ring, a dark pupil standing out of it, a level brow that sits on its top
    ring = (3.3, 3.8, 0.2, 1.8)
    head.block(-17.7, ring, -16.1, ring, "belly", mirror=True)
    pupil = (3.6, 4.1, 0.5, 1.4)
    head.block(-17.3, pupil, -16.5, pupil, "black", mirror=True)
    head.beam((-17.9, 3.7, 1.65), (-15.8, 3.7, 1.85), 0.8, 1.2, "sand", mirror=True)
    saddle(head, -15.4, -14.4, *HEAD[2:5])

    segs, before = [], HEAD
    for i, (x0, x1, n, bot, top, belly) in enumerate(SLICES):
        seg = m.part(f"S{i + 1}", (x0, 0, 0), "Head" if i == 0 else f"S{i}")
        slab(seg, x0, x1, n, bot, top, belly)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # clear of both pieces' corner steps
        small = min(n, before[2])
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, before[3]) + 1, min(top, before[4]) - 1, "sand-")
        segs.append(seg)
        before = (x0, x1, n, bot, top, belly)
    s1, s2, s3, s4, s5, s6 = segs
    slab(s6, *STOCK)

    # gill slits and the seat's leg slots: shallow lines in the side
    for x in (-12, -10):
        s1.dent(x, x + 1, 3, -1, 1, "sand-")
    s1.dent(-8, -6, 3, 0, 3, "sand-")

    # the pattern: one thin saddle to a slice, in its middle (never on a joint, never where the body changes size), and
    # single spots low on the flank between them
    saddle(s1, -10.95, -10.05, 3, -3, 4)
    saddle(s2, -3.2, -2.1, 3, -3, 4)  # this one runs under the back fin
    saddle(s3, 1.5, 2.6, 3, -2, 4)
    saddle(s4, 5.4, 6.4, 2, -2, 4)  # under the second back fin
    saddle(s5, 9.05, 9.95, 2, -2, 3)
    saddle(s6, 11.6, 12.4, 2, -1, 3)
    for seg, x, n, z in ((s2, -5, 3, 0), (s2, -2, 3, -1), (s2, -1, 3, 2), (s3, 0, 3, 0), (s3, 3, 3, 0), (s4, 7, 2, 0),
                         (s5, 10, 2, 0), (s6, 14, 1, 1)):
        spot(seg, x, n, z)

    # the first back fin: three boxes leaning back, the root deep in the back
    s2.beam((-3.5, 0, 2.6), (-1.3, 0, 6.0), 4.0, 1.2, "sand")
    s2.beam((-2.0, 0, 5.3), (-0.6, 0, 7.5), 2.6, 0.9, "sand")
    s2.beam((-1.2, 0, 6.8), (-0.2, 0, 8.5), 1.6, 0.6, "sand-")
    # the second back fin, three quarters of the first
    s4.beam((5.3, 0, 2.8), (6.9, 0, 5.6), 2.6, 0.9, "sand")
    s4.beam((6.4, 0, 5.0), (7.5, 0, 6.8), 1.6, 0.6, "sand-")
    # the side fins: broad, low on the flank under the gills, swept back
    s1.beam((-11.2, 2.2, -1.6), (-8.9, 5.8, -2.2), 3.4, 1.1, "sand", flat="z", mirror=True)
    s1.beam((-9.5, 5.0, -2.07), (-7.7, 7.6, -2.5), 2.5, 0.7, "sand", flat="z", mirror=True)
    s1.beam((-8.3, 6.9, -2.385), (-7.0, 8.8, -2.7), 1.8, 0.35, "sand-", flat="z", mirror=True)
    # the belly fins and the anal fin
    s3.beam((1.3, 1.5, -1.3), (3.1, 3.3, -3.2), 2.0, 0.6, "belly-", flat="z", mirror=True)
    s5.beam((8.9, 0, -0.8), (10.0, 0, -3.2), 1.8, 0.8, "belly-")
    s5.beam((9.6, 0, -2.6), (10.5, 0, -4.0), 1.2, 0.5, "sand-")

    # the tail, on its own joint: a root block, a long low upper lobe in three boxes (a fifth of the animal's length), a
    # short lower lobe
    tail = m.part("Tail", (15, 0, 1), "S6")
    tail.beam((14.5, 0, 1.0), (16.6, 0, 1.0), 2.4, 1.3, "sand")
    tail.beam((15.6, 0, 1.4), (18.7, 0, 3.4), 2.6, 1.0, "sand")
    tail.beam((18.0, 0, 2.95), (21.3, 0, 5.0), 2.0, 0.7, "sand")
    tail.beam((20.6, 0, 4.55), (23.4, 0, 6.28), 1.5, 0.4, "sand-")
    tail.beam((15.7, 0, 0.7), (17.3, 0, -1.3), 2.2, 0.7, "sand")
    tail.beam((16.8, 0, -0.7), (17.8, 0, -2.2), 1.5, 0.4, "sand-")
