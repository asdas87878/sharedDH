"""The Butterflyfish, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the
game's Butterflyfish (art/creatures/Butterflyfish) and replaces nothing. Designed from the real animal, a copperband
butterflyfish.
Its idea: the disc with the straw.
- The body idea in numbers: about 29.5 cubes long. A tall thin disc, 22 cubes tall with its fins (0.75 of the length)
  and 7 wide at the middle (0.24): the back fin and the belly fin carry the disc's outline on, up to a peak near the
  rear and then almost straight down to the stalk. The disc's side outline rises in broad steps to a flat top and falls
  the same way behind it, and its section is a lens (the outer column stops three cubes short of the rim), so it
  reads round, not as a box. In front of it a long thin tube snout, 5.6 cubes (a fifth of the length) and 2 thick,
  tilted a little down. A small fan tail on a short stalk. Pale side fins low behind the gill, swept back along the
  flank and bending out.
- The face: the eye sits inside the first band, a dark pupil in a thin pale ring. The mouth is the dark end of the straw.
- Pearl white, a little warmer and darker on the belly, from the chest to the belly fin.
- The one mark: three upright copper bands, each 2 cubes wide, top to bottom: through the eye, at the middle, and at
  the back of the disc through both fins; one false eye, a dark block in a pale ring, high on the back fin in the last
  band; a thin copper edge on the tail.
The rider sits on the flat top of the disc between the forehead and the back fin, legs in a slot either side."""
NAME, ZONE, RARITY = "Butterflyfish (trial)", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"white": "#F4F1E6", "belly": "#EEE2C6", "copper": "#E8892B", "black": "#17171C", "mouth": "#7A3B2A"}
SHADE = 0.9
SEAT = (-2.0, 9, 2.6)
FRAME, ORTHO = 1.2, 15.5
SWIM = {"chain": ["Head", "Rear", "Stalk", "Tail"], "amplitudes": [5, 10, 18], "phaseStep": 0.9, "headCounter": 2}
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["white"]}]

STEP = [(1, 1)]
LENS = [(1, 3)]  # the disc's section: the outer column stops three cubes short of the rim, so the flank bulges like a lens
BELLY = -3  # the warmer belly comes up to here, in one level line from the chest to the stalk
BANDS = ((-9, -7), (-1, 1), (6, 8))  # the three copper bands, each two cubes wide


def slab(p, x0, x1, n, bot, top, steps=STEP):
    """a slice of the disc: one-step corners, white with a lighter top row, the warmer belly below the belly line"""
    p.hull(x0, x1, n, bot, top, "white", steps, steps)
    if steps:
        p.paint_sym(x0, x1, n, top - 1, top, "white+")
    p.paint_sym(x0, x1, n, bot, BELLY, "belly")


def band(p, x0, x1, n, bot, top):
    """a copper band painted on the cubes, top to bottom"""
    p.paint_sym(x0, x1, n, bot, top, "copper")
    p.paint_sym(x0, x1, n, top - 1, top, "copper+")


def brow(x):
    """the top of the forehead ridge: one steep line from the root of the snout to the front of the flat top"""
    return 2.02 + 1.349 * (x + 10.1)


def chest(x):
    """the underside of the chest ridge: from under the snout down to the belly"""
    return -3.1 - 1.16 * (x + 10.0)


def build(m):
    head = m.part("Head", (1, 0, 0))
    slab(head, -10, -7, 1, -3, 2, ())  # the face: small and narrow, the eye on its side
    slab(head, -7, -5, 2, -6, 6)  # the shoulder
    slab(head, -5, -3, 3, -8, 8, LENS)  # one broad step up to the flat top
    slab(head, -3, 1, 3, -9, 9, LENS)  # the disc's flat top: the fish is thickest here, and the rider sits on it
    band(head, -9, -7, 1, -3, 2)
    band(head, -1, 1, 3, -9, 9)

    # the forehead: a narrow ridge tilted steeply from the root of the snout to the flat top, and a wider, lower block
    # under its upper half, so the section steps in as the body's does. The chest is the same, upside down
    head.beam((-9.136, 0, 1.305), (-4.036, 0, 8.185), 2.0, 2.4, "white", flat="z")
    head.beam((-6.197, 0, 4.764), (-3.697, 0, 8.134), 4.4, 2.0, "white", flat="z")
    head.beam((-9.091, 0, -2.317), (-4.091, 0, -8.117), 2.0, 2.4, "belly", flat="z")
    head.beam((-6.243, 0, -5.157), (-3.743, 0, -8.057), 4.4, 2.0, "belly", flat="z")
    # the first band carries on over the forehead ridge and under the chest ridge, a little proud of both
    a, b = BANDS[0]
    head.prism([(a, 1.6), (b, 1.6), (b, brow(b) + 0.42), (a, brow(a) + 0.42)], -1.25, 1.25, "copper")
    head.prism([(a, -2.6), (a, chest(a) - 0.38), (b, chest(b) - 0.38), (b, -2.6)], -1.25, 1.25, "copper")

    # the straw: two long thin blocks in a chain, tilted a little down, the second thinner and starting inside the first.
    # The mouth is its dark end
    head.beam((-9.0, 0, -0.5), (-13.0, 0, -0.85), 2.2, 2.2, "white", flat="z")
    head.beam((-12.3, 0, -0.8), (-15.3, 0, -1.1), 1.8, 1.8, "white", flat="z")
    lips = (-0.55, 0.55, -1.65, -0.6)
    head.block(-15.6, lips, -14.9, lips, "mouth")

    # the eye, inside the first band: a thin pale ring standing out of the band, a dark pupil standing out of the ring
    ring = (1.2, 1.85, -0.65, 1.45)
    head.block(-8.95, ring, -7.05, ring, "white", mirror=True)
    pupil = (1.2, 2.15, -0.3, 1.1)
    head.block(-8.65, pupil, -7.35, pupil, "black", mirror=True)

    # the side fins: low behind the gill, lying back along the flank and bending a little out, a root blade and a
    # smaller, thinner tip
    head.beam((-4.7, 3.0, -1.4), (-1.5, 4.4, -2.0), 2.6, 0.5, "belly", mirror=True)
    head.beam((-2.2, 4.0, -1.9), (0.8, 5.5, -2.7), 1.8, 0.3, "belly", mirror=True)
    head.dent(-3, -1, 3, 2, 5, "white")  # the rider's leg slots

    # the rear of the disc: the flat top carries on for three cubes, then two lower, narrower slabs that the fins cover
    rear = m.part("Rear", (1, 0, 0), "Head")
    slab(rear, 1, 3, 3, -9, 9, LENS)
    slab(rear, 3, 5, 3, -8, 8, LENS)
    slab(rear, 5, 7, 2, -7, 7, [(1, 2)])
    slab(rear, 7, 9, 1, -4, 4, ())
    rear.sym(0, 1, 2, -6, 6, "white-")  # the sleeve into the head
    band(rear, 6, 7, 2, -7, 7)
    band(rear, 7, 8, 1, -4, 4)
    # the back fin and the belly fin carry the disc's outline on, in three boxes each, every one smaller and thinner
    # than the last and starting inside it: a long one that rises out of the flat top to the peak, one that turns
    # down from the peak, and one that drops almost straight to the stalk
    for s, first, second in ((1, "white", "white-"), (-1, "belly", "belly-")):
        rear.beam((1.888, 0, s * 7.187), (7.088, 0, s * 9.337), 3.6, 1.6, first)
        rear.beam((5.235, 0, s * 10.03), (7.735, 0, s * 7.02), 2.8, 1.2, first)
        rear.beam((7.57, 0, s * 7.64), (8.39, 0, s * 2.99), 2.4, 0.8, second)
    # the last band carries on through both fins, a little proud of them
    a, b = BANDS[2]
    rear.prism([(a, 3.5), (b, 3.5), (b, 9.28), (6.358, 11.253), (a, 11.105)], -1.05, 1.05, "copper")
    rear.prism([(a, -3.5), (a, -11.105), (6.358, -11.253), (b, -9.28), (b, -3.5)], -1.05, 1.05, "copper")
    # the false eye: a dark block in a pale ring, high on the back fin, inside the last band
    ring = (0.9, 1.35, 7.3, 9.0)
    rear.block(6.15, ring, 7.85, ring, "white", mirror=True)
    spot = (0.9, 1.6, 7.6, 8.7)
    rear.block(6.45, spot, 7.55, spot, "black", mirror=True)

    # the tail stalk: short
    stalk = m.part("Stalk", (9, 0, 0), "Rear")
    slab(stalk, 9, 11, 1, -2, 2, ())
    stalk.sym(8, 9, 0, -1, 1, "white-")

    # the tail: a root block and one small fan, with a thin copper edge
    tail = m.part("Tail", (11, 0, 0), "Stalk")
    tail.beam((10.4, 0, 0), (11.7, 0, 0), 3.0, 1.4, "white")
    tail.prism([(11.2, -1.4), (13.6, -3.3), (13.6, 3.3), (11.2, 1.4)], -0.45, 0.45, "white")
    tail.prism([(13.3, -3.36), (14.0, -3.92), (14.0, 3.92), (13.3, 3.36)], -0.7, 0.7, "copper")
