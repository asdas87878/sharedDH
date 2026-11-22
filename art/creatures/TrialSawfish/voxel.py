"""The Sawfish, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Sawfish (art/creatures/Sawfish) and replaces nothing. Designed from the real animal (a Pristis sawfish).
Its idea: the chainsaw.
- The saw is a third of the whole length: 21 of about 62 cubes, 3 cubes wide and half a cube thick, the same width from
  root to a blunt square end, with nine big flat teeth a side, evenly spaced, white on the bone.
- Behind it the front half is flat (3 cubes deep) and spreads into two broad triangular side fins: from above a spade,
  22 cubes across the fin tips (0.36 of the length). Its two plates step thinner toward the tips.
- The back half is a shark's: the back rises to 7 deep, two tall back fins of one size, a tail with a long upper lobe.
- The face: two eyes on top of the head on low raised blocks with cream rings, a spiracle dent behind each. The saw is
  the face; the mouth is underneath and not built.
- Rust red over cream; the saw bone with white teeth. THE MARK: one thin cream line along each side, the widest row of
  the flank, unbroken from the saw's root to the tail. A rust row under it keeps it apart from the cream belly.
The rider sits where the back is highest, in front of the first back fin, behind the side fins."""
NAME, ZONE, RARITY = "Sawfish (trial)", "ZONE 4 / SHIPWRECKS", "RARE"
U = 0.4
PALETTE = {"rust": "#B8503C", "cream": "#F2E5CC", "bone": "#E6D6B0", "tooth": "#FFFFFF", "black": "#1C1C21"}
SHADE = 0.9
SEAT = (6, 4, 4.5)
FRAME, ORTHO = 2.1, 28.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["rust"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [2, 4, 8, 13, 20], "phaseStep": 0.9,
        "headCounter": 2}

ROUND, CUT = [(2, 1), (1, 1)], [(1, 1)]

# the body in slices (from, to, cubes out, bottom, top); one number changes by one cube from slice to slice
HEAD = ((-10, -8, 2, -1, 2), (-8, -6, 3, -1, 2), (-6, -2, 4, -1, 2), (-2, 2, 4, -1, 2))  # flat: 3 deep
BODY = (("S1", ((2, 4, 4, -1, 3), (4, 5, 4, -2, 3), (5, 8, 4, -2, 4))),  # the back rises: the seat
        ("S2", ((8, 10, 4, -3, 4), (10, 14, 3, -3, 4))),  # the deepest: the first back fin
        ("S3", ((14, 16, 3, -2, 4), (16, 21, 3, -2, 3))),  # the second back fin
        ("S4", ((21, 22, 2, -2, 3), (22, 23, 2, -1, 3), (23, 24, 2, -1, 2))))  # the stalk


def steps(bot, top):
    """top and bottom corner steps: a deep slice gets two broad steps, a flat one a single cut"""
    depth = top - bot
    return (ROUND if depth >= 5 else CUT), (ROUND if depth >= 7 else CUT)


def slab(p, x0, x1, n, bot, top):
    """a slice of body: rust, a cream belly, and THE MARK: the outermost cube of the row z = 0 (the flank's widest row)
    in cream. The outermost cube of the row below stays rust, so the line never touches the belly"""
    t, b = steps(bot, top)
    p.hull(x0, x1, n, bot, top, "rust", t, b)
    p.paint_sym(x0, x1, n, bot, -1, "cream")
    edge = max(abs(c[1]) for c in p.cells if x0 <= c[0] < x1 and c[2] == -1)
    p.paint_sym(x0, x1, edge - 1, -1, 0, "cream")
    p.paint_pair(x0, x1, n, n + 1, 0, 1, "cream")


def clear(bot, top):
    t, b = steps(bot, top)
    return sum(tall for _, tall in t), sum(tall for _, tall in b)


def dorsal(p, ox, oz):
    """a tall shark's back fin, a triangle leaning back: three boxes in the fin's own frame, their rear edges nearly in
    line, their fronts stepping back, each thinner and starting inside the last. Both back fins are this one fin"""
    ux, uz, wx, wz = 0.423, 0.906, 0.906, -0.423  # up the fin (leaning back 25 degrees) and across it, toward the rear

    def box(s0, s1, front, rear, thick):
        w = (front + rear) / 2
        p.beam((ox + s0 * ux + w * wx, 0, oz + s0 * uz + w * wz), (ox + s1 * ux + w * wx, 0, oz + s1 * uz + w * wz),
               rear - front, thick, "rust")

    box(-1.0, 2.6, -2.8, 2.2, 1.4)
    box(2.2, 4.6, -1.4, 2.0, 0.8)
    box(4.2, 6.2, -0.3, 1.8, 0.45)


def plate(p, outline, z0, z1, colour):
    """a flat plate drawn in the top view (x, y corners, in order) and given thickness from z0 to z1; and its mirror"""
    n = len(outline)
    verts = [(x, y, z0) for x, y in outline] + [(x, y, z1) for x, y in outline]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    p.solid(verts, faces, colour, mirror=True)


def build(m):
    head = m.part("Head", (2, 0, 0))
    for s in HEAD:
        slab(head, *s)

    # THE SAW: one flat bone blade, 3 wide and half a cube thick, the same width to a blunt square end, its root deep
    # in the head. Nine big flat teeth a side, evenly spaced, pointing straight out, their bases sunk into its edge
    blade = (-1.5, 1.5, 0.2, 0.7)
    head.block(-31.0, blade, -8.5, blade, "bone")
    for i in range(9):
        x = -30.0 + 2.3 * i
        base = [(x - 0.7, 1.3, 0.25), (x + 0.7, 1.3, 0.25), (x + 0.7, 1.3, 0.65), (x - 0.7, 1.3, 0.65)]
        head.spike(base, (x, 3.4, 0.45), "tooth", mirror=True)

    # the side fins: the head runs into two broad triangles, lying flat and low on the flank (under the line). A thick
    # inner plate and a thinner outer one that starts inside it
    plate(head, [(-9.6, 2.0), (-4.26, 7.4), (1.75, 7.4), (2.0, 2.0)], -0.85, -0.1, "rust")
    plate(head, [(-4.9, 6.4), (-0.15, 11.2), (1.6, 10.4), (1.45, 6.4)], -0.7, -0.25, "rust")

    # the eyes, on top of the head: a low raised block, a cream ring on it, a black pupil set to the outer side
    head.block(-6.4, (1.2, 3.8, 1.5, 2.6), -3.6, (1.2, 3.8, 1.5, 2.6), "rust", mirror=True)
    head.block(-6.1, (1.55, 3.45, 2.3, 2.95), -3.9, (1.55, 3.45, 2.3, 2.95), "cream", mirror=True)
    head.block(-5.55, (2.05, 3.25, 2.7, 3.25), -4.35, (2.05, 3.25, 2.7, 3.25), "black", mirror=True)
    # a spiracle dent behind each eye: the top cubes cut out and filled again half a cube short of the top, so it holds a shadow
    head.carve_pair(-3, -2, 2, 4, 1, 2)
    head.block(-3, (1.5, 3.5, 0.6, 1.45), -2, (1.5, 3.5, 0.6, 1.45), "rust-", mirror=True)

    segs, before = {}, HEAD[-1]
    for i, (name, slices) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, sized from the smaller of the two pieces, clear of both pieces' steps
        x0, _, n, bot, top = slices[0]
        _, _, fn, fbot, ftop = before
        (t0, b0), (t1, b1) = clear(bot, top), clear(fbot, ftop)
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + max(b0, b1), min(top, ftop) - max(t0, t1), "rust-")
        before = slices[-1]
    s1, s2, s3, s4 = (segs[name] for name, _ in BODY)

    # two tall back fins of one size, well apart: the first over the deepest slice, the second near the stalk
    dorsal(s2, 10.6, 4)
    dorsal(s3, 17.6, 3)
    # the belly fins, under the first back fin
    s2.beam((9.0, 1.2, -2.3), (11.8, 4.8, -3.3), 2.4, 0.6, "rust", flat="z", mirror=True)

    # a shark's tail on its own joint: a narrow stock carrying the line to its end, a long upper lobe in three boxes, a
    # short lower one
    tail = m.part("Tail", (24, 0, 0.5), "S4")
    slab(tail, 24, 27, 1, -1, 2)
    tail.sym(23, 24, 0, 0, 1, "rust-")
    tail.beam((25.0, 0, 1.2), (28.2, 0, 3.2), 2.8, 1.3, "rust")
    tail.beam((27.6, 0, 2.9), (30.4, 0, 4.6), 2.0, 0.75, "rust")
    tail.beam((29.8, 0, 4.3), (32.0, 0, 5.6), 1.2, 0.4, "rust")
    tail.beam((25.2, 0, 0.0), (26.8, 0, -1.8), 2.0, 0.6, "rust")
    tail.beam((26.3, 0, -1.4), (27.3, 0, -2.6), 1.2, 0.3, "rust")
