"""The Cuttlefish (zone 1's Uncommon) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a chunky oval loaf that hovers, a rippling skirt down each side, a bunch of little arms and a sleepy W eye.
- The mantle is one rigid loaf in nine slices: an oval from above, an arched back, a belly that lifts at the rear.
- The head is one size smaller all round, so the mantle's edge makes a collar behind it.
- The fin skirt is four flaps a side, each on its own joint, each two flat boxes (a sand one and a thinner cream one).
  They follow the body's width, and a wave runs down them.
- Eight arms in a bunch, two rows of four, each a block and a slimmer tip; the lower outer pair is longer, splays, and ends in sand.
- The eye: a pale block bulging from the side of the head, a W-shaped dark pupil, a lid box sitting on it.
- Its one pattern: thin zebra stripes across the back, every third cube, in the sand tone, from fin to fin.
The rider sits on the widest slice, legs in a slot either side above the skirt."""
import math

NAME, ZONE, RARITY = "Cuttlefish", "ZONE 1 / SHALLOWS", "UNCOMMON"
U = 0.4
PALETTE = {"brown": "#8E5B3C", "cream": "#F3E6C8", "sand": "#DDB682", "black": "#231C1A"}
SEAT = (3.5, 5, 5.5)
FRAME, ORTHO = 1.3, 18.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["brown"]}]

# the mantle: (from, to, cubes out, bottom, top). One number changes from slice to slice
SLICES = ((-5, -2, 4, -3, 4), (-2, 1, 4, -3, 5), (1, 6, 5, -3, 5), (6, 8, 4, -3, 5), (8, 11, 4, -3, 4), (11, 13, 3, -3, 4),
          (13, 15, 3, -3, 3), (15, 16, 3, -2, 3), (16, 17, 2, -2, 3))
STRIPES = (-4, -1, 2, 5, 8, 11, 14)
# the skirt: (from, to, the body's side there), one flap each
FLAPS = ((-4.6, 0.8, 4.5), (1.2, 5.8, 5.5), (6.2, 10.8, 4.5), (11.2, 15.8, 3.5))
FIN_Z = -0.5


def pose(parts, phase):
    """it hovers: the body stays level, the head and the arms nod a little, and a wave runs down the skirt twice a beat"""
    parts["Head"].rotation_euler.y = math.radians(2.5) * math.sin(phase)
    parts["Arms"].rotation_euler.y = math.radians(6) * math.sin(phase - 1.0)
    for k in range(len(FLAPS)):
        for name, side in ((f"FinR{k + 1}", 1), (f"FinL{k + 1}", -1)):
            parts[name].rotation_euler.x = side * math.radians(24) * math.sin(2 * phase - 1.5 * k)


def top_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def bottom_steps(n):
    return [(2, 1)] if n >= 4 else [(1, 1)]


def slab(p, x0, x1, n, bot, top):
    """a slice of the body: stepped corners, brown with a lighter top row, cream under the fin line"""
    p.hull(x0, x1, n, bot, top, "brown", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "brown+")
    p.paint_sym(x0, x1, n, bot, -1, "cream")
    p.paint_sym(x0, x1, n, bot, bot + 1, "cream-")


def arm(p, points, sizes, colours):
    """an arm: boxes in a chain along `points`, each (wide, thick) smaller than the last and starting inside it"""
    for i, ((wide, thick), colour) in enumerate(zip(sizes, colours)):
        a, b = points[i], points[i + 1]
        if i:
            d = [u - v for u, v in zip(a, points[i - 1])]
            n = math.sqrt(sum(v * v for v in d))
            a = tuple(u - 0.5 * v / n for u, v in zip(a, d))
        p.beam(a, b, wide, thick, colour, flat="z", mirror=True)


def build(m):
    body = m.part("Body", (3, 0, 0))
    for x0, x1, n, bot, top in SLICES:
        slab(body, x0, x1, n, bot, top)
    for x in STRIPES:  # the zebra stripes: one cube row across the back, down to the skirt on both sides
        body.paint_sym(x, x + 1, 5, 0, 6, "sand")
    body.dent(3, 5, 5, 0, 2, "brown-")  # the rider's leg slots

    # the head: one size smaller than the mantle's front all round
    head = m.part("Head", (-5, 0, 0), "Body")
    head.hull(-9, -5, 3, -2, 3, "brown", [(1, 1)], [(1, 1)])
    head.paint_sym(-9, -5, 3, 2, 3, "brown+")
    head.paint_sym(-9, -5, 3, -2, -1, "cream-")
    head.paint_sym(-7, -6, 2, 2, 3, "sand")  # the stripes start on the head
    head.sym(-5, -4, 1, -1, 2, "brown-")  # a sleeve into the mantle
    # the eye: a pale block bulging from the side, a W-shaped pupil standing out of it, a lid sitting on its top
    eye = (2.4, 4.0, -0.7, 1.7)
    head.block(-8.6, eye, -5.6, eye, "cream", mirror=True)
    bar = (3.9, 4.3, -0.2, 0.3)
    head.block(-8.3, bar, -5.9, bar, "black", mirror=True)
    for x, tall in ((-8.3, 1.2), (-7.35, 0.8), (-6.4, 1.2)):
        stroke = (3.9, 4.3, 0.3, tall)
        head.block(x, stroke, x + 0.5, stroke, "black", mirror=True)
    lid = (2.4, 4.2, 1.4, 1.85)
    head.block(-8.8, lid, -5.4, lid, "brown", mirror=True)

    # the arms: two rows of four in a bunch. The lower outer pair is longer and splays out
    arms = m.part("Arms", (-9, 0, 0), "Head")
    short, slim = (1.2, 1.2), (0.8, 0.75)
    arm(arms, ((-8.4, 0.8, 1.2), (-11.4, 0.8, 1.1), (-13.4, 0.75, 0.9)), (short, slim), ("brown", "brown+"))
    arm(arms, ((-8.4, 2.3, 1.2), (-11.0, 2.2, 1.05), (-12.7, 2.05, 0.8)), (short, slim), ("brown", "brown+"))
    arm(arms, ((-8.4, 0.8, -0.3), (-11.0, 0.8, -0.75), (-12.8, 0.75, -1.25)), (short, slim), ("brown", "brown+"))
    arm(arms, ((-8.4, 2.3, -0.3), (-12.2, 2.5, -0.9), (-15.4, 2.9, -1.5)), (short, slim), ("brown", "sand"))

    # the skirt: four flaps a side, each on its own joint at the body's side
    for k, (x0, x1, side) in enumerate(FLAPS):
        mid, long = (x0 + x1) / 2, x1 - x0
        for name, s in ((f"FinR{k + 1}", 1), (f"FinL{k + 1}", -1)):
            fin = m.part(name, (mid, s * side, FIN_Z), "Body")
            fin.beam((mid, s * (side - 0.9), FIN_Z), (mid, s * (side + 1.3), FIN_Z - 0.1), long, 0.7, "sand", flat="z")
            fin.beam((mid, s * (side + 0.8), FIN_Z - 0.1), (mid, s * (side + 2.2), FIN_Z - 0.22), long - 1.0, 0.3, "cream", flat="z")
