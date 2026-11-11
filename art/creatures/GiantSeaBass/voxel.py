"""The Giant Sea Bass (zone 3's Rare: the huge, slow bass of the kelp forest) for tools/blender/voxel_kit.py
(docs/style/creature-brief.md). Designed from the real animal.
Its idea: a heavy dark boulder of a fish that is mostly mouth: thick pale lips, the lower jaw jutting past the upper.
- The body is deep and wide, a third as deep as the fish is long. The back rises from the head to a hump where the spines
  stand and falls in broad steps to a deep tail stock; the belly hangs deepest under the chest and holds its depth past
  the middle before it climbs. Dark grey-brown, a paler belly from chin to tail.
- The head is a third of the fish, and a wedge, not a box: two big blocks tilted nose-down make the forehead slope from
  the nape to the snout, while the mouth runs UP to the front on one slanting line. An upper lip, a dark gap, a lower lip
  and the jaw under it are all boxes laid along that line, the lips the widest things on the head, the lower lip a cube
  further out than the upper.
- A small eye with a cream ring, high on the cheek over the corner of the mouth, under a brow that slants down to the front.
- Its pattern (a Rare has one): scattered darker spots, small and large, on the flanks and the shoulders.
- The back fin's front half is a row of spines on the hump, behind the rider; the soft half is a lobe further back, over
  the anal fin.
- A broad square tail on its own joint: a deep stock, a fan of three boxes, and a tall thin plate across its end.
The rider sits behind the head, in the dip in front of the hump, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Giant Sea Bass", "ZONE 3 / KELP FOREST", "RARE"
U = 0.45
PALETTE = {"body": "#655C54", "belly": "#93887B", "lip": "#E2D3B8", "spot": "#3D3632", "black": "#1E1F22"}
SEAT = (-6.5, 7, 5.5)
FRAME, ORTHO = 1.7, 25.0
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["body"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "Tail"], "amplitudes": [1, 2, 4, 6, 8, 10, 14], "phaseStep": 0.8,
        "headCounter": 2}

# the body behind the head. Each part is a list of slices: (from, to, cubes out, bottom, top, how high the pale belly comes)
PARTS = (((-9, -4, 6, -8, 7, -5), (-4, 1, 6, -8, 8, -5)),  # the chest (the seat) and the hump: one stiff piece
         ((1, 5, 5, -7, 8, -4),),  # the belly starts to climb while the back is still at its highest
         ((5, 8, 5, -7, 7, -4),),
         ((8, 11, 4, -6, 6, -4),),
         ((11, 13, 3, -5, 5, -3), (13, 15, 3, -4, 4, -2)),
         ((15, 17, 2, -3, 3, -1),))
SKULL = (5, -7, 7)
HEAD_STEPS = [(1, 1)]

# the mouth line: from the corner of the mouth under the eye it runs up to the front. Lips, gap and jaw lie along it
M0, RISE = -3.1, 0.3
COS = 1 / math.sqrt(1 + RISE * RISE)


def mouth(x):
    return M0 + RISE * (-15 - x)


def along(p, x0, x1, lo, hi, wide, colour):
    """a box laid along the mouth line from x0 (the back) to x1 (the front), from `lo` to `hi` above the line"""
    mid = (lo + hi) / 2
    p.beam((x0, 0, mouth(x0) + mid), (x1, 0, mouth(x1) + mid), wide, (hi - lo) * COS, colour, flat="z")


def top_steps(n):
    """the corners of the back: a broad shoulder in two steps where the body is thick, one step at the tail"""
    return [(2, 1), (1, 2)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def tall(steps):
    return sum(t for _, t in steps)


def slab(p, x0, x1, n, bot, top, belly, tops=None, bottoms=None):
    """a slice of body: stepped corners, a lighter top row, a pale belly with a darker lowest row"""
    p.hull(x0, x1, n, bot, top, "body", top_steps(n) if tops is None else tops, bottom_steps(n) if bottoms is None else bottoms)
    p.paint_sym(x0, x1, n, top - 1, top, "body+")
    p.paint_sym(x0, x1, n, bot, belly, "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def build(m):
    head = m.part("Head", (-9, 0, 0))
    slab(head, -12, -9, *SKULL, -4, HEAD_STEPS, HEAD_STEPS)  # the back of the skull and the gill covers
    slab(head, -15, -12, 5, -6, 5, -4, HEAD_STEPS, HEAD_STEPS)  # the cheeks: lower, so the forehead slopes down over them
    # the forehead: two big blocks in a chain, each tilted nose-down and a step lower and narrower than the last, the
    # second starting inside the first. Their slope runs from the nape to the snout
    head.beam((-11.6, 0, 3.2), (-17.2, 0, 1.2), 8.0, 7.0, "body", flat="z")
    head.beam((-16.2, 0, 1.76), (-19.9, 0, 0.84), 6.8, 4.8, "body", flat="z")
    # the mouth, all on one slanting line. The lips are the widest pieces, so they stand proud all round; each is two
    # boxes, the front one narrower and thinner. The lower lip comes a cube past the upper: the jaw juts
    along(head, -14.5, -18.6, 0.2, 1.9, 10.0, "lip")  # the upper lip
    along(head, -18.0, -20.9, 0.4, 1.5, 9.0, "lip")
    along(head, -14.5, -20.5, -0.6, 0.6, 7.8, "spot")  # the dark inside, seen between the lips
    along(head, -14.5, -19.2, -1.6, -0.2, 9.6, "lip")  # the lower lip
    along(head, -18.6, -22.2, -1.4, -0.4, 8.6, "lip")
    along(head, -14.2, -18.8, -2.65, -0.55, 8.4, "belly")  # the jaw under it: two boxes, the smaller in front
    along(head, -18.0, -21.7, -2.4, -0.9, 7.4, "belly")
    # the eye: small, a cream ring and a dark pupil, under a brow that sits on it and slants down to the front
    ring = (5.3, 5.7, 2.2, 3.8)
    head.block(-14.6, ring, -13.0, ring, "lip+", mirror=True)
    pupil = (5.5, 5.9, 2.55, 3.45)
    head.block(-14.25, pupil, -13.35, pupil, "black", mirror=True)
    head.beam((-14.9, 5.2, 3.75), (-12.5, 5.2, 4.2), 0.9, 1.8, "body", mirror=True)
    head.dent(-11, -10, 5, -3, 4, "body-")  # the gill cover's edge

    segs, front, spans = [], SKULL, []
    front_top, front_bottom = tall(HEAD_STEPS), tall(HEAD_STEPS)
    for i, slices in enumerate(PARTS):
        x0, _, n, bot, top, _ = slices[0]
        seg = m.part(f"S{i + 1}", (x0, 0, 0), "Head" if i == 0 else f"S{i}")
        for s in slices:
            slab(seg, *s)
            spans.append((seg, s[0], s[1], s[2]))
        # a sleeve into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        fn, fbot, ftop = front
        up, down = max(tall(top_steps(n)), front_top), max(tall(bottom_steps(n)), front_bottom)
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "body-")
        segs.append(seg)
        front = slices[-1][2:5]
        front_top, front_bottom = tall(top_steps(front[0])), tall(bottom_steps(front[0]))
    # the seat: behind the head, in front of the hump, a shallow slot either side for the rider's legs
    segs[0].dent(-8, -6, 6, 1, 4, "body-")

    # the pattern: scattered darker spots of two sizes, on the flanks (the outermost column of each slice) and on the
    # shoulder step above it (inset 1)
    for x0, x1, z0, z1, inset in ((-5, -4, 1, 2, 0), (-3, -1, 0, 2, 0), (0, 1, -4, -3, 0), (0, 1, 2, 3, 0), (2, 4, -2, 0, 0),
                                  (1, 2, 3, 4, 0), (4, 5, -4, -3, 0), (6, 7, 1, 2, 0), (5, 7, -3, -2, 0), (9, 10, -1, 1, 0),
                                  (8, 9, 2, 3, 0), (11, 12, 0, 1, 0), (14, 15, -1, 0, 0), (-2, 0, 5, 7, 1), (3, 4, 6, 7, 1),
                                  (-6, -5, 5, 6, 1)):
        for p, a, b, n in spans:
            if x0 < b and x1 > a:
                p.paint_pair(x0, x1, n - inset, n - inset + 1, z0, z1, "spot")

    # the back fin's spiny half, on the hump: a low dark web with pointed spines standing out of it, raked back
    for seg, x0, x1, z, wide, thick, spines in ((segs[0], -3.4, 1.0, 8.1, 1.4, 1.0, ((-2.8, 10.0), (-1.7, 10.4), (-0.6, 10.4), (0.4, 10.2))),
                                                (segs[1], 1.3, 4.7, 8.0, 1.4, 0.8, ((1.9, 10.0), (3.0, 9.7), (4.1, 9.4)))):
        seg.beam((x0, 0, z), (x1, 0, z), wide, thick, "body-")
        for x, tip in spines:
            base = [(x - 0.5, -0.3, z + 0.2), (x + 0.5, -0.3, z + 0.2), (x + 0.5, 0.3, z + 0.2), (x - 0.5, 0.3, z + 0.2)]
            seg.spike(base, (x + 1.1, 0, tip), "belly")
    # its soft half, and the anal fin under it: each two boxes, the second smaller and thinner, roots deep in the body
    segs[2].beam((6.6, 0, 5.2), (8.8, 0, 8.2), 3.2, 0.9, "body-")
    segs[2].beam((8.0, 0, 7.4), (9.6, 0, 9.3), 2.3, 0.6, "body-")
    segs[3].beam((9.4, 0, -4.2), (11.0, 0, -6.9), 2.8, 0.9, "belly-")
    segs[3].beam((10.5, 0, -6.3), (11.6, 0, -8.0), 1.9, 0.6, "belly-")
    # the side fins: broad paddles lying back along the flank; the belly fins under the chest
    segs[0].beam((-8.0, 5.6, -2.6), (-4.6, 7.2, -3.2), 3.6, 0.9, "body-", mirror=True)
    segs[0].beam((-5.4, 6.9, -3.1), (-3.0, 7.9, -3.6), 2.6, 0.6, "body-", mirror=True)
    segs[0].beam((-6.6, 2.4, -6.6), (-4.7, 2.9, -8.4), 2.0, 0.8, "belly-", mirror=True)

    # the tail, on its own joint: broad and square. A deep stock; a fan of three boxes (the middle one, and one up and
    # back, one down and back) that flares to the tail's full height; and a tall thin plate that starts inside the fan
    # where it is tallest and runs on past its ends, so the tail ends in one straight edge
    tail = m.part("Tail", (17, 0, 0), "S6")
    tail.beam((16.3, 0, 0), (18.9, 0, 0), 5.4, 2.0, "body")
    tail.beam((18.0, 0, 0), (21.3, 0, 0), 5.0, 1.0, "body")
    for s in (1, -1):
        tail.beam((17.8, 0, 1.3 * s), (21.2, 0, 4.7 * s), 2.8, 1.3, "body")
    tail.beam((20.4, 0, 0), (22.4, 0, 0), 10.8, 0.6, "body-")
