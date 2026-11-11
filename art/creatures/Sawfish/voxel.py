"""The Sawfish (zone 4's Rare: a shark-like ray) for tools/blender/voxel_kit.py (docs/style/creature-brief.md).
Its idea: the saw. A long flat snout, a quarter of the animal, edged on both sides with a row of small teeth.
- The head is flat and wide, as a ray's is: a low skull, then two blocks in a chain, each tilted nose-down, lower and
  narrower than the last, and the saw starts inside the second. The eyes sit up on the corners of the skull, each under a
  brow bar; the mouth is a short dark line underneath.
- The saw is two flat blocks, the second thinner and narrower, in its own bony colour (so the back's studs stay off it).
  Its teeth are small pyramids pointing out sideways, bases sunk into the edge.
- The body is eleven slices, one step at a time: flat at the head, the back rising to the seat and falling to the tail, the
  belly dipping under the middle. Sandy brown over a pale underside; the pale edge is one level line.
- Broad wing-like side fins of three boxes swept back from behind the head; two back fins set far back; a shark's tail
  with a long upper lobe.
The rider sits where the back is highest, behind the wings, legs in a slot either side."""
NAME, ZONE, RARITY = "Sawfish", "ZONE 4 / SHIPWRECKS", "RARE"
U = 0.4
PALETTE = {"sand": "#B8996A", "pale": "#EFE7D2", "saw": "#C9B187", "tooth": "#FBF6E6", "black": "#2A2B2E"}
SEAT = (2, 4, 4.5)
FRAME, ORTHO = 2.0, 28.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["sand"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"], "amplitudes": [1, 3, 6, 10, 14, 20], "phaseStep": 0.9,
        "headCounter": 2}

ROUND, CUT, PLAIN = [(2, 1), (1, 1)], [(1, 1)], []


def slab(p, x0, x1, n, bot, top, top_steps, bottom_steps):
    """a slice of body: stepped corners, sandy with a lighter top row, pale below the level line z = 0"""
    p.hull(x0, x1, n, bot, top, "sand", top_steps, bottom_steps)
    p.paint_sym(x0, x1, n, top - 1, top, "sand+")
    p.paint_sym(x0, x1, n, bot, 0, "pale")
    if bot <= -2:
        p.paint_sym(x0, x1, n, bot, bot + 1, "pale-")


def build(m):
    head = m.part("Head", (-9, 0, 0))
    slab(head, -13, -9, 4, -1, 2, CUT, CUT)  # the skull: low and wide
    # the snout: two blocks in a chain, each tilted nose-down, lower and narrower than the last, with a pale plate
    # underneath and a lighter plate on top that starts past the end of the block before
    for x0, x1, z0, z1, wide, thick, plate, plate_from in ((-12.4, -15.0, 0.7, 0.4, 6.6, 2.2, 4.4, -13.3),
                                                           (-14.4, -17.0, 0.4, 0.05, 4.8, 1.6, 3.0, -15.3)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "sand", flat="z")
        lip = thick / 2 + 0.15
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.6, "pale", flat="z")

        def top(x):
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

        head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.5, "sand+", flat="z")
    # the saw: two flat blocks, the second narrower and thinner and starting inside the first
    head.beam((-16.4, 0, 0.1), (-24.4, 0, -0.1), 3.2, 1.2, "saw", flat="z")
    head.beam((-23.8, 0, -0.1), (-31.0, 0, -0.1), 2.6, 0.7, "saw", flat="z")

    def saw_tooth(x, half, z, tall):
        """a small pyramid pointing out sideways from the saw's edge, its base sunk into it; and its mirror"""
        y = half - 0.15
        base = [(x - 0.35, y, z - tall / 2), (x + 0.35, y, z - tall / 2), (x + 0.35, y, z + tall / 2), (x - 0.35, y, z + tall / 2)]
        head.spike(base, (x, y + 1.15, z), "tooth", mirror=True)

    for x in (-17.9, -19.3, -20.7, -22.1, -23.5):
        saw_tooth(x, 1.6, 0.1 - 0.2 * (-16.4 - x) / 8.0, 0.55)
    for x in (-25.0, -26.4, -27.8, -29.2, -30.5):
        saw_tooth(x, 1.3, -0.1, 0.45)
    # the eyes: a dark block set in the step of each corner of the skull, standing a little out of its side, under a brow
    # bar that cuts its top and comes a little past it. Both start inside the skull
    eye = (3.4, 4.75, 0.5, 1.6)
    head.block(-12.4, eye, -10.8, eye, "black", mirror=True)
    head.beam((-12.7, 3.95, 1.6), (-10.5, 3.95, 1.6), 0.5, 2.1, "sand", mirror=True)
    # the mouth: a short dark line under the skull
    mouth = (-1.8, 1.8, -1.15, -0.9)
    head.block(-12.4, mouth, -11.8, mouth, "sand-")

    # the body: eleven slices. From one slice to the next one thing changes by one cube: the back, the belly or the
    # width. The back rises from the flat head to the seat and falls to the tail; the belly dips under the middle
    s1 = m.part("S1", (-9, 0, 0), "Head")
    slab(s1, -9, -6, 4, -1, 3, ROUND, CUT)
    slab(s1, -6, -3, 4, -2, 3, ROUND, CUT)
    s2 = m.part("S2", (-3, 0, 0), "S1")
    slab(s2, -3, 0, 4, -2, 4, ROUND, CUT)
    slab(s2, 0, 4, 4, -3, 4, ROUND, CUT)  # the deepest: the seat
    s3 = m.part("S3", (4, 0, 0), "S2")
    slab(s3, 4, 8, 3, -3, 4, ROUND, CUT)
    slab(s3, 8, 11, 3, -2, 4, ROUND, CUT)
    s4 = m.part("S4", (11, 0, 0), "S3")
    slab(s4, 11, 14, 3, -2, 3, CUT, CUT)
    slab(s4, 14, 16, 2, -2, 3, CUT, CUT)
    s5 = m.part("S5", (16, 0, 0), "S4")
    slab(s5, 16, 18, 2, -1, 3, CUT, CUT)
    slab(s5, 18, 20, 2, -1, 2, CUT, CUT)
    slab(s5, 20, 22, 1, -1, 2, PLAIN, PLAIN)
    # sleeves: one cube into the piece in front, inside both pieces' steps
    s1.sym(-10, -9, 2, 0, 1, "sand-")
    s2.sym(-4, -3, 2, -1, 1, "sand-")
    s3.sym(3, 4, 1, -2, 2, "sand-")
    s4.sym(10, 11, 1, -1, 2, "sand-")
    s5.sym(15, 16, 0, 0, 2, "sand-")
    # the seat: a shallow slot either side for the rider's legs
    s2.dent(1, 3, 4, 0, 2, "sand-")

    # the wings: broad side fins swept back from behind the head, three boxes, each smaller and thinner and starting
    # inside the last, the tip a tone darker. The first starts deep in the body, so its whole end is buried
    s1.beam((-6.0, 2.2, 0.3), (-3.4, 6.8, 0.0), 6.4, 1.2, "sand", flat="z", mirror=True)
    s1.beam((-4.0, 6.0, 0.05), (-2.0, 8.6, -0.15), 4.6, 0.8, "sand", flat="z", mirror=True)
    s1.beam((-2.6, 7.9, -0.1), (-1.3, 9.7, -0.25), 2.8, 0.5, "sand-", flat="z", mirror=True)
    # the belly fins, under the first back fin
    s3.beam((6.4, 1.8, -1.5), (8.6, 4.6, -2.6), 2.6, 0.6, "sand-", flat="z", mirror=True)
    # two back fins set far back, the second a little smaller: each a broad base box, a smaller one and a darker tip
    s3.beam((6.6, 0, 1.6), (8.9, 0, 5.6), 4.6, 1.0, "sand")
    s3.beam((8.3, 0, 4.8), (10.2, 0, 7.2), 3.0, 0.7, "sand")
    s3.beam((9.6, 0, 6.5), (10.9, 0, 8.4), 1.9, 0.4, "sand-")
    s4.beam((12.9, 0, 1.2), (14.8, 0, 4.6), 3.4, 1.0, "sand")
    s4.beam((14.3, 0, 3.9), (15.8, 0, 5.9), 2.3, 0.7, "sand")
    s4.beam((15.3, 0, 5.3), (16.4, 0, 6.9), 1.5, 0.4, "sand-")

    # a shark's tail on its own joint: a root block, a long upper lobe in three boxes, a short lower one
    tail = m.part("Tail", (22, 0, 0.5), "S5")
    tail.beam((21.6, 0, 0.5), (23.8, 0, 0.5), 2.5, 1.4, "sand")
    tail.beam((22.8, 0, 1.0), (26.0, 0, 4.4), 3.4, 1.1, "sand")
    tail.beam((25.3, 0, 3.7), (28.4, 0, 6.9), 2.6, 0.8, "sand")
    tail.beam((27.7, 0, 6.2), (30.0, 0, 8.6), 1.9, 0.5, "sand-")
    tail.beam((22.8, 0, 0.0), (25.0, 0, -2.6), 2.6, 0.8, "sand-")
