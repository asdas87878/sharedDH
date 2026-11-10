"""Dunkleosteus (zone 2's Legendary: the armoured prehistoric fish with blade jaws) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md). Third pass, in big blocks.
- The back shield is a stepped bone slab. The skull is two big blocks in a chain, each tilted nose-down and a step lower
  and narrower, each with a lighter roof plate. A heavy brow box slants over a ringed eye. A darker cheek plate hangs
  either side of the mouth.
- The jaw is its own part and chomps: two boxes, tucked between the cheek plates. The blades are pyramids: two fangs
  above, one cusp below that closes between them, a small one each side.
- The fins and the eel tail are chains of boxes; the tail's boxes turn upward one by one. The back fin has a bone collar.
- Old scars cross the shield (a Legendary's flaw).
The rider sits on the shield, legs in a slot each side."""
import math

NAME, ZONE, RARITY = "Dunkleosteus", "ZONE 2 / CORAL REEF", "LEGENDARY"
U = 0.5
PALETTE = {"bone": "#C9B994", "body": "#56788A", "belly": "#B4C4C0", "blade": "#F1EAD6", "black": "#2B2B2E", "mouth": "#4A1F24"}
SEAT = (-9, 7, 6.5)
FRAME, ORTHO = 2.0, 29.0
CHAIN = ["Head", "S1", "S2", "S3", "S4", "Tail"]
AMPLITUDES = [2, 5, 8, 12, 18]


def pose(parts, phase):
    """the fish swim down the chain, and the jaw opens and shuts once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.9 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))


def slab(p, x0, x1, n, bot, top):
    """a length of body: stepped corners, lighter on top, the shoulder step darker, a pale belly"""
    steps = [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])
    p.hull(x0, x1, n, bot, top, "body", steps, steps)
    if steps:
        p.paint_sym(x0, x1, n, top - len(steps), top - 1, "body-")
    p.paint_sym(x0, x1, n, top - 1, top, "body+")
    p.paint_sym(x0, x1, n, bot, bot + max(2, (top - bot) // 3), "belly")
    p.paint_sym(x0, x1, n, bot, bot + len(steps), "belly-")


def build(m):
    head = m.part("Head", (-8, 0, 0))
    # the back shield: a stepped bone slab, proud of the body behind, with a low crest and a darker seam at its front
    head.hull(-14, -8, 6, -6, 7, "bone", [(3, 1), (1, 2)], [(3, 1), (1, 2)])
    head.paint_sym(-14, -8, 6, -6, -3, "bone-")
    head.paint_sym(-14, -8, 6, 6, 7, "bone+")
    head.paint_sym(-14, -13, 6, -6, 7, "bone-")
    head.sym(-13, -9, 1, 7, 8, "bone")
    # the skull: two big blocks in a chain, each tilted nose-down and a step lower and narrower, each with a lighter roof
    # plate on top (the second plate starts past the end of the first block)
    for x0, x1, z0, z1, wide, thick, plate, plate_from in ((-13.4, -18.2, 1.9, 1.2, 10.6, 7.8, 6.6, -13.4),
                                                           (-17.4, -21.4, 0.6, -0.2, 8.0, 5.6, 4.6, -18.5)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "bone", flat="z")

        def top(x):
            return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

        head.beam((plate_from, 0, top(plate_from)), (x1 + 0.6, 0, top(x1 + 0.6)), plate, 0.5, "bone+", flat="z")
    # a darker cheek plate hanging either side of the mouth
    cheek = (3.9, 5.1, -4.4, -1.6)
    head.block(-17.8, cheek, -13.6, cheek, "bone-", mirror=True)
    # the dark inside of the mouth: a block behind the blades, between the cheeks, ending inside the skull and the jaw
    mouth = (-3.0, 3.0, -4.6, -1.8)
    head.block(-19.8, mouth, -13.6, mouth, "mouth")
    # the upper blades: two fangs at the front, hanging forward of the lower jaw
    head.spike([(-20.6, 1.3, -2.4), (-18.6, 1.3, -2.4), (-18.6, 3.6, -2.4), (-20.6, 3.6, -2.4)], (-21.3, 2.4, -5.8), "blade", mirror=True)
    # the eye: a pale ring on the skull's side, a dark square standing out of it, under a heavy brow that slants down to
    # the front
    ring = (5.2, 5.75, 0.4, 3.4)
    head.block(-17.6, ring, -15.2, ring, "blade", mirror=True)
    pupil = (5.6, 6.0, 1.1, 2.7)
    head.block(-17.0, pupil, -15.8, pupil, "black", mirror=True)
    head.beam((-18.0, 5.55, 3.2), (-14.0, 5.55, 4.6), 1.6, 1.5, "bone", mirror=True)
    # old scars across the shield's left side: two slashes, cut shallow so they read as lines, not missing blocks
    for x, z in ((-13, 3), (-12, 2), (-11, 1), (-13, 0), (-12, -1), (-11, -2)):
        head.dent(x, x + 1, -6, z, z + 1, "bone-", pair=False)
    # the seat on the shield: a slot either side for the rider's legs
    head.dent(-10, -8, 6, 1, 4, "bone-")

    # the jaw, on its own joint: two boxes, the smaller in front, tucked between the cheek plates, a darker chin plate
    jaw = m.part("Jaw", (-13, 0, -4), "Head")
    jaw.beam((-13.8, 0, -5.1), (-18.4, 0, -5.1), 6.6, 1.6, "bone", flat="z")
    jaw.beam((-17.8, 0, -4.95), (-20.0, 0, -4.82), 5.4, 1.2, "bone", flat="z")
    jaw.beam((-14.4, 0, -6.0), (-17.6, 0, -6.0), 4.6, 0.5, "bone-", flat="z")
    # the lower blades: one cusp that closes between the two fangs, and a small one each side behind it
    jaw.spike([(-19.8, -1.0, -4.45), (-18.3, -1.0, -4.45), (-18.3, 1.0, -4.45), (-19.8, 1.0, -4.45)], (-19.6, 0.0, -2.2), "blade")
    jaw.spike([(-18.6, 1.9, -4.45), (-17.2, 1.9, -4.45), (-17.2, 2.9, -4.45), (-18.6, 2.9, -4.45)], (-18.0, 2.4, -3.2), "blade", mirror=True)

    cuts = [-8, -1, 6, 12, 18]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(4)]
    slab(segs[0], -8, -1, 5, -5, 6)
    slab(segs[1], -1, 6, 4, -4, 5)
    slab(segs[2], 6, 12, 3, -3, 4)
    slab(segs[3], 12, 18, 2, -2, 3)
    segs[0].sym(-9, -8, 4, -4, 5, "body-")  # sleeves, one cube into the piece in front
    segs[1].sym(-2, -1, 3, -3, 4, "body-")
    segs[2].sym(5, 6, 2, -2, 3, "body-")
    segs[3].sym(11, 12, 1, -1, 2, "body-")

    # the back fin: two boxes, the first in a bone collar
    segs[1].beam((1.6, 0, 3.4), (2.75, 0, 5.6), 4.9, 1.6, "bone-")
    segs[1].beam((1.6, 0, 3.4), (3.8, 0, 7.6), 4.4, 1.2, "body-")
    segs[1].beam((3.2, 0, 6.6), (4.8, 0, 9.2), 2.8, 0.9, "body")
    # the side fins: two boxes each, starting inside the body's side and swept back; small belly fins
    segs[0].beam((-6.4, 3.9, -2.3), (-2.9, 8.4, -3.05), 4.2, 1.0, "body", flat="z", mirror=True)
    segs[0].beam((-3.7, 7.5, -2.9), (-1.3, 10.2, -3.4), 3.0, 0.7, "body-", flat="z", mirror=True)
    segs[2].beam((7.0, 1.4, -2.2), (9.4, 2.6, -4.6), 2.0, 0.7, "body-", flat="z", mirror=True)

    # the tail, on its own joint: long and eel-like, a chain of boxes that turns upward box by box, with a low lobe
    # underneath
    tail = m.part("Tail", (18, 0, 0), "S4")
    tail.beam((17.6, 0, 0.5), (20.6, 0, 0.9), 3.4, 1.6, "body")
    tail.beam((19.8, 0, 0.9), (23.0, 0, 3.4), 3.0, 1.3, "body")
    tail.beam((22.2, 0, 2.8), (24.8, 0, 6.6), 2.6, 1.0, "body-")
    tail.beam((24.2, 0, 5.8), (25.6, 0, 9.0), 2.0, 0.7, "body-")
    tail.beam((19.4, 0, 0.3), (22.4, 0, -1.6), 2.4, 1.0, "body-")
