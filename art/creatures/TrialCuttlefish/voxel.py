"""The Cuttlefish, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Cuttlefish (art/creatures/Cuttlefish) and replaces nothing. Designed from the real animal: a flamboyant cuttlefish.
Its idea: the shield. A broad flat oval with a yellow hem, a bunch of arms with two raised like horns, and a huge W eye.
- The body idea in numbers: about 33 cubes long. The mantle is 19 long, 17 wide at the middle (half the length) and 9 deep
  (0.28), flat on top with one broad step down to the sides. From above it is an oval in broad steps.
- All round the mantle's edge runs a thin skirt fin, one cube wide and half a cube thick, in the yellow. It sits on the
  line between the violet and the cream, so from the side it IS the line.
- The head is short (5) and as wide as the mantle's front, one cube lower above and below, so the mantle makes a collar.
- Eight arms in a bunch, a quarter of the length, thick at the root, each in three blocks. The lower four hang a little,
  the upper outer pair rises like horns. Two thin feeding arms, a little longer, between them.
- The eye: a pale block four and a half cubes across on the side of the head, and on it the pupil, a W: a dark bar with
  both ends turned up.
- Colour: violet over pink-cream, the line low and straight. The one mark: yellow for the skirt and the last block of
  every arm.
The rider sits on the flat of the mantle; the broad step either side is the leg room."""
import math

NAME, ZONE, RARITY = "Cuttlefish (trial)", "ZONE 1 / SHALLOWS", "UNCOMMON"
U = 0.4
PALETTE = {"violet": "#8A44A6", "cream": "#F6DCE0", "yellow": "#FFD23F", "black": "#1B1420"}
SHADE = 0.9
SEAT = (3, 5, 6.5)
FRAME, ORTHO = 1.4, 19.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["violet"]}]

LINE = -1  # cream below this height, violet above
TOP, BOTTOM = [(2, 2)], [(2, 1)]  # the mantle's corners: one broad step above, one low one under the skirt
# the mantle: (from, to, cubes out, bottom, top). One number changes from slice to slice
SLICES = ((-4, -2, 6, -4, 5), (-2, 0, 7, -4, 5), (0, 6, 8, -4, 5), (6, 8, 7, -4, 5), (8, 10, 7, -4, 4), (10, 12, 6, -4, 4),
          (12, 14, 5, -4, 4), (14, 15, 5, -4, 3))
FIN_Z = -2.5  # the skirt runs along the lowest full row of the flank, a cube and a bit of cream showing above it
# the skirt: (flap, from, to, the body's cubes out there, height). Each run wraps one cube round the corner of a wider
# slice, and neighbours sit a fifth of a cube apart in height, so no two lie in one plane. The last one also covers the
# narrow end slice and meets the rear run
SKIRT = ((1, -3.7, -2, 6, 0.1), (1, -3, 0, 7, -0.1), (2, -1, 7, 8, 0.1), (3, 6, 11, 7, -0.1), (3, 10, 13, 6, 0.1), (3, 12, 15.7, 5, -0.1))
HINGE = {1: (-2, 7.0), 2: (3, 8.5), 3: (10.5, 6.5)}


def pose(parts, phase):
    """it hovers: the body stays level, the head and the arms nod a little, and a wave runs down the skirt twice a beat"""
    parts["Head"].rotation_euler.y = math.radians(2.5) * math.sin(phase)
    parts["Arms"].rotation_euler.y = math.radians(7) * math.sin(phase - 1.0)
    for k in (1, 2, 3):
        for name, side in ((f"FinR{k}", 1), (f"FinL{k}", -1)):
            parts[name].rotation_euler.x = side * math.radians(16) * math.sin(2 * phase - 1.6 * k)


def slab(p, x0, x1, n, bot, top, tops, bottoms):
    """a slice: stepped corners, violet with a lighter top row, cream under the line"""
    p.hull(x0, x1, n, bot, top, "violet", tops, bottoms)
    p.paint_sym(x0, x1, n, top - 1, top, "violet+")
    p.paint_sym(x0, x1, n, bot, LINE, "cream")


def arm(p, points, sizes, colours, mirror=True):
    """an arm: boxes in a chain along `points`, each (wide, thick) smaller than the last and starting inside it"""
    for i, ((wide, thick), colour) in enumerate(zip(sizes, colours)):
        a, b = points[i], points[i + 1]
        if i:
            d = [u - v for u, v in zip(a, points[i - 1])]
            n = math.sqrt(sum(v * v for v in d))
            a = tuple(u - 0.6 * v / n for u, v in zip(a, d))
        p.beam(a, b, wide, thick, colour, flat="z", mirror=mirror)


def build(m):
    body = m.part("Body", (4, 0, 0))
    for s in SLICES:
        slab(body, *s, TOP, BOTTOM)
    # the skirt's rear run, fixed to the body
    body.beam((13.6, 0, FIN_Z + 0.1), (16.0, 0, FIN_Z), 10.6, 0.5, "yellow", flat="z")

    # the head: as wide as the mantle's front, one cube lower above and below
    head = m.part("Head", (-4, 0, 0), "Body")
    slab(head, -9, -4, 6, -3, 4, [(2, 1)], [(2, 1)])
    head.sym(-4, -3, 4, -1, 2, "violet-")  # a sleeve into the mantle
    # THE EYE: a pale block bulging from the side of the head, and the W standing out of it: a bar with both ends turned up
    ring = (6.0, 7.3, -1.7, 2.7)
    head.block(-8.8, ring, -4.2, ring, "cream", mirror=True)
    bar = (7.1, 7.7, -0.5, 0.5)
    head.block(-8.3, bar, -4.7, bar, "black", mirror=True)
    for x, wide, tall in ((-8.3, 1.0, 1.8), (-6.9, 0.8, 1.0), (-5.7, 1.0, 1.8)):
        stroke = (7.1, 7.7, 0.5, tall)
        head.block(x, stroke, x + wide, stroke, "black", mirror=True)

    # the arms: eight in a bunch, two rows of four. Thick at the root, three blocks each, the last one yellow
    arms = m.part("Arms", (-9, 0, 0), "Head")
    sizes, colours, under = ((2.6, 2.2), (1.9, 1.6), (1.2, 1.0)), ("violet", "violet", "yellow"), ("cream", "cream", "yellow")
    arm(arms, ((-8.4, 1.5, -1.2), (-11.6, 1.5, -1.9), (-14.2, 1.4, -2.7), (-16.2, 1.3, -3.3)), sizes, under)
    arm(arms, ((-8.4, 4.4, -1.2), (-11.4, 4.8, -1.8), (-13.8, 5.3, -2.6), (-15.6, 5.7, -3.2)), sizes, under)
    arm(arms, ((-8.4, 1.5, 1.4), (-11.6, 1.5, 1.2), (-14.2, 1.4, 0.7), (-16.4, 1.3, 0.2)), sizes, colours)
    # the upper outer pair, raised like horns
    arm(arms, ((-8.4, 4.4, 1.5), (-11.2, 5.2, 2.8), (-13.0, 6.0, 5.2), (-13.8, 6.5, 7.6)), sizes, colours)
    # the two thin feeding arms between them, a little longer
    arm(arms, ((-8.4, 2.95, 0.1), (-15.0, 2.9, -0.7), (-17.0, 2.9, -1.0)), ((0.8, 0.7), (1.3, 1.1)), ("violet+", "yellow"))

    # the skirt: three flaps a side, each on its own joint at the body's side
    fins = {}
    for k, x0, x1, n, z in SKIRT:
        mid, long = (x0 + x1) / 2, x1 - x0
        for tag, s in (("R", 1), ("L", -1)):
            name = f"Fin{tag}{k}"
            if name not in fins:
                hx, hy = HINGE[k]
                fins[name] = m.part(name, (hx, s * hy, FIN_Z), "Body")
            fins[name].beam((mid, s * (n - 1.2), FIN_Z + z), (mid, s * (n + 1.5), FIN_Z + z - 0.1), long, 0.5, "yellow", flat="z")
