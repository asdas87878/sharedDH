"""The Parrotfish (zone 2's Uncommon: a reef parrotfish) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a chunky, gaudy reef fish with a blunt round head that ends in a pale beak of two fused plates.
- The body is five deep slices on joints: a long level back, a belly that dips under the rider, a deep tail stock.
- The head is two slabs and two blunt blocks in a chain, each a step smaller, so the forehead is steep and round. The
  beak is its one odd feature: two blunt pale plates, the upper one over the lower, a dark line between.
- Two thin stripes run the whole length at fixed heights, orange above and pink below; the belly is pink.
- A low orange back fin in three boxes behind the rider, a broad fan tail (pink web, orange tips) on its own joint, and
  two paddle side fins on joints of their own: a parrotfish rows with them.
- A friendly eye: a cream ring and a dark pupil.
The rider sits on the high back behind the head, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Parrotfish", "ZONE 2 / CORAL REEF", "UNCOMMON"
U = 0.4
PALETTE = {"teal": "#1FB8AC", "pink": "#F27BA6", "orange": "#F7983A", "beak": "#F3ECD6", "black": "#22262B"}
SEAT = (-4, 6, 4.6)
FRAME, ORTHO = 1.15, 17.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["teal"]}]

# the body behind the head: each slice is (from, to, cubes out, bottom, top)
SLICES = ((-10, -6, 4, -5, 6), (-6, -1, 4, -6, 6), (-1, 3, 3, -5, 5), (3, 6, 2, -4, 4), (6, 8, 1, -3, 3))
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [1.5, 2.5, 4, 7, 10, 16]
STRIPES = ((1, "orange"), (-1, "pink"))  # the two thin lines, at the same height on every slice


def pose(parts, phase):
    """a reef fish's swim: a stiff body with a small wave that grows to the tail, and two side fins that row, twice a beat"""
    parts["Head"].rotation_euler.z = -math.radians(2) * math.sin(phase)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.8 * (k + 1))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(14) * math.sin(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(12) * math.sin(2 * phase - 1.2)


def steps(n):
    """the corners: two broad steps where the body is thick, one where it thins, none on the tail stock"""
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def slab(p, x0, x1, n, bot, top, top_steps=None):
    """a slice of body: teal, lighter on the top row, a pink belly on the corner rows, and the two stripes"""
    low = steps(n)
    p.hull(x0, x1, n, bot, top, "teal", low if top_steps is None else top_steps, low)
    p.paint_sym(x0, x1, n, top - 1, top, "teal+")
    if low:
        p.paint_sym(x0, x1, n, bot, bot + len(low), "pink")
        if len(low) > 1:
            p.paint_sym(x0, x1, n, bot, bot + 1, "pink-")
    for z, colour in STRIPES:
        p.paint_sym(x0, x1, n, z, z + 1, colour)


def build(m):
    head = m.part("Head", (-10, 0, 0))
    slab(head, -14, -10, 4, -5, 5, [(1, 1)])  # the back of the head: the eye sits on its side
    slab(head, -16, -14, 3, -4, 4)  # the brow, a step smaller all round
    # the snout: two blunt blocks in a chain, each tilted a little nose-down, smaller, and starting inside the last
    head.beam((-15.2, 0, -0.1), (-16.9, 0, -0.4), 5.4, 6.2, "teal", flat="z")
    head.beam((-16.4, 0, -0.6), (-17.6, 0, -0.85), 3.8, 4.4, "teal", flat="z")
    # the beak: two blunt plates of fused teeth, the upper one longer and over the lower, a dark line between them
    head.taper(-17.2, (1.7, -0.9, 1.0), -18.6, (1.35, -0.9, 0.5), "beak")
    head.taper(-17.2, (1.4, -2.7, -1.25), -18.2, (1.1, -2.4, -1.25), "beak")
    gap = (-1.05, 1.05, -1.45, -0.7)
    head.block(-17.9, gap, -17.0, gap, "black")
    # the eye: a cream ring on the side of the head, a dark pupil a little forward in it
    ring = (4.38, 4.8, 1.5, 3.75)
    head.block(-13.5, ring, -11.2, ring, "beak", mirror=True)
    pupil = (4.7, 5.1, 2.2, 3.3)
    head.block(-13.1, pupil, -12.0, pupil, "black", mirror=True)

    segs = []
    spans = [(-14, -10, 4, -5, 5)] + list(SLICES)
    for i, (x0, x1, n, bot, top) in enumerate(SLICES):
        seg = m.part(f"S{i + 1}", (x0, 0, 0), "Head" if i == 0 else f"S{i}")
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        fn, fbot, ftop = spans[i][2:5]
        small = min(n, fn)
        up = max(len(steps(n)), len(steps(fn)))
        down = up
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "teal-")
        segs.append(seg)
    # the seat: on the high back behind the head, a shallow slot either side for the rider's legs
    segs[1].dent(-5, -3, 4, 2, 4, "teal-")

    # the back fin: low and long, three boxes down the back behind the rider, each smaller and thinner than the last
    segs[2].beam((-0.6, 0, 5.5), (3.1, 0, 5.1), 3.6, 1.2, "orange")
    segs[3].beam((2.9, 0, 4.8), (6.1, 0, 4.0), 2.6, 0.9, "orange")
    segs[4].beam((5.9, 0, 3.9), (7.8, 0, 3.4), 2.0, 0.6, "orange")
    segs[3].beam((3.4, 0, -3.3), (5.4, 0, -5.2), 2.0, 0.7, "pink")  # the anal fin
    segs[0].beam((-8.4, 1.7, -4.4), (-6.3, 2.1, -6.3), 2.2, 0.6, "pink", mirror=True)  # the belly fins

    # the side fins, each on its own joint: a pink paddle swept back and out, an orange tip
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-8.4, 4.3 * side, -1.8), "S1")
        fin.beam((-8.9, 3.4 * side, -1.8), (-5.7, 5.8 * side, -2.4), 2.2, 0.8, "pink")
        fin.beam((-6.4, 5.3 * side, -2.25), (-4.3, 6.8 * side, -2.7), 1.6, 0.4, "orange")

    # the tail, on its own joint: a deep root block, a pink web, two lobes swept up and down, orange tips: a broad fan
    tail = m.part("Tail", (8, 0, 0), "S5")
    tail.beam((7.6, 0, 0), (9.6, 0, 0), 4.8, 1.6, "teal")
    tail.beam((9.2, 0, 0), (11.9, 0, 0), 4.6, 0.6, "pink")
    for s in (1, -1):
        tail.beam((8.9, 0, 1.1 * s), (11.8, 0, 3.7 * s), 3.0, 1.0, "teal")
        tail.beam((11.1, 0, 3.1 * s), (12.6, 0, 4.5 * s), 2.0, 0.5, "orange")
