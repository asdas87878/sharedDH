"""The Goliath Grouper (zone 4's Epic) for tools/blender/voxel_kit.py (docs/style/creature-brief.md).
Its idea: bulk and the mouth. A barrel of a fish, as wide as a rider is tall, with a huge wide mouth in thick lips that
hangs a little open and gapes as it swims.
- The body is a few big slabs with broad two-step corners: a deep belly that sags under the middle, a back that arches
  and falls to a thick tail stock. Olive-brown over a tan belly, with big dark blotches and a few small dark spots.
- The head is big blocks, each turned: a sloping forehead, an upper jaw that rises to the front, a thick lip under it.
  The lower jaw is its own part (two blocks and a lip that juts past the upper one) and opens. No teeth: lips.
- Small eyes set forward and high, a cream ring and a dark pupil under a short brow.
- Rounded fins: a long low dorsal that rises to a rounded soft part, paddle side fins on their own joints, a rounded
  anal fin, a fan of a tail (a root, a middle and two short lobes).
The rider sits on the broad back behind the head, in front of the dorsal fin (the back is too wide for leg slots)."""
import math

NAME, ZONE, RARITY = "Goliath Grouper", "ZONE 4 / SHIPWRECKS", "EPIC"
U = 0.45
PALETTE = {"olive": "#857643", "belly": "#CDBB80", "blotch": "#54452A", "lip": "#B29C62", "mouth": "#5A262B", "black": "#1E1F22",
           "cream": "#E9DDB0"}
SEAT = (-7, 10, 8.6)
FRAME, ORTHO = 2.0, 29.0
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["olive"]}]
BELLY = -4  # the pale belly comes up to this height
CHAIN = (("B2", 2.5), ("B3", 4.5), ("B4", 6.5), ("B5", 8.5), ("Tail", 14.0))


def pose(parts, phase):
    """a heavy fish's swim: the front half hardly moves, the wave grows down the rear half to the tail fan. The mouth
    gapes once a beat and the side fins scull"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, (name, degrees) in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(degrees) * math.sin(phase - 0.7 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(7) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("PecR", 1), ("PecL", -1)):
        parts[name].rotation_euler.z = side * math.radians(14) * (0.5 + 0.5 * math.sin(phase - 0.9))


def steps(n):
    """the corners: a wide plateau and two broad steps where the body is thick, fewer as it thins"""
    return [(3, 1), (1, 2)] if n >= 7 else ([(2, 1), (1, 1)] if n >= 5 else [(1, 1)])


def rows(n):
    return sum(tall for _, tall in steps(n))


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, olive (lighter on the plateau of the back), a tan belly"""
    p.hull(x0, x1, n, bot, top, "olive", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "olive+")
    p.paint_sym(x0, x1, n, bot, max(bot + 1, BELLY), "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


SKULL = (-19, -13, 7, -8, 8)
BODY = (("B1", ((-13, -9, 8, -8, 9), (-9, -5, 8, -9, 10))),
        ("B2", ((-5, 2, 8, -10, 10),)),
        ("B3", ((2, 5, 7, -10, 9), (5, 8, 7, -9, 9))),
        ("B4", ((8, 11, 6, -8, 8), (11, 14, 5, -7, 7))),
        ("B5", ((14, 17, 4, -6, 6), (17, 19, 3, -5, 5))),
        ("Tail", ((19, 21, 2, -4, 4),)))
# dark blotches, each two boxes that overlap (x0, x1, z0, z1), and small spots (x, z), painted on both flanks
BLOTCHES = {"B1": ((-12, -10, 2, 6), (-11, -9, 4, 8)), "B2": ((-3, -1, -2, 3), (-2, 1, 1, 5)), "B3": ((3, 5, 4, 8), (4, 6, 2, 5)),
            "B4": ((9, 11, -2, 3), (10, 12, 1, 5)), "B5": ((15, 17, 0, 4),)}
SPOTS = {"B1": ((-8, 2), (-7, -2), (-12, -2)), "B2": ((-4, 6), (0, -2)), "B3": ((7, -1), (7, 6)), "B4": ((13, 0),)}


def build(m):
    head = m.part("Head", (-13, 0, 0))
    slab(head, *SKULL)
    head.paint_sym(-16, -15, 7, 2, 3, "blotch")  # a spot on the cheek
    head.paint_sym(-18, -17, 7, -3, -2, "blotch")
    # the forehead: one big block turned nose-down, so its top is the slope from the snout to the back
    head.beam((-17.5, 0, 4.2), (-22.5, 0, 1.2), 12.6, 7.0, "olive", flat="z")
    # the upper jaw: a block turned nose-UP, so the mouth line rises to the front; a thick lip under it, wider than the
    # jaw and standing out in front of it
    head.beam((-17.5, 0, -1.2), (-25.5, 0, 1.2), 11.4, 4.0, "olive", flat="z")
    head.beam((-18.2, 0, -3.5), (-26.67, 0, -0.96), 12.2, 1.4, "lip", flat="z")
    # the dark inside of the mouth: set back behind the lips, ending inside the jaws
    mouth = (-5.2, 5.2, -4.9, -1.6)
    head.block(-25.8, mouth, -18.5, mouth, "mouth")
    # the eye: small, forward and high on the forehead's side. A cream ring, a dark pupil, a short brow sitting on it
    ring = (6.0, 6.6, 2.7, 4.5)
    head.block(-22.5, ring, -20.7, ring, "cream", mirror=True)
    pupil = (6.4, 6.85, 3.1, 4.1)
    head.block(-22.1, pupil, -21.1, pupil, "black", mirror=True)
    head.beam((-22.7, 6.2, 4.35), (-20.2, 6.2, 5.1), 1.0, 1.6, "olive-", mirror=True)

    # the lower jaw, on its own joint at the corner of the mouth: two blocks, the front one slimmer and turned up, and a
    # thick lip that juts past the upper one
    jaw = m.part("Jaw", (-19, 0, -4.4), "Head")
    jaw.beam((-18.0, 0, -6.2), (-23.5, 0, -5.9), 12.0, 3.4, "belly", flat="z")
    jaw.beam((-22.5, 0, -5.6), (-26.2, 0, -4.9), 11.0, 2.2, "belly", flat="z")
    jaw.beam((-21.5, 0, -4.6), (-26.9, 0, -3.77), 12.6, 1.2, "lip", flat="z")

    # the body: big slabs, each part one or two of them
    parts, before, parent = {}, SKULL, "Head"
    for name, slabs in BODY:
        p = parts[name] = m.part(name, (slabs[0][0], 0, 0), parent)
        for x0, x1, n, bot, top in slabs:
            slab(p, x0, x1, n, bot, top)
        # a sleeve into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        x0, _, n, bot, top = slabs[0]
        _, _, fn, fbot, ftop = before
        deep = max(rows(n), rows(fn))
        p.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + deep, min(top, ftop) - deep, "olive-")
        for bx0, bx1, z0, z1 in BLOTCHES.get(name, ()):
            p.paint_sym(bx0, bx1, 8, z0, z1, "blotch")
        for x, z in SPOTS.get(name, ()):
            p.paint_sym(x, x + 1, 8, z, z + 1, "blotch")
        before, parent = slabs[-1], name
    parts["B1"].dent(-13, -12, 8, -4, 5, "olive-")  # the edge of the gill cover

    # the dorsal fin: a long low spiny part that rises to the back, a taller soft part, a rear lobe that turns down to
    # the tail stock, so the outline is one round line. It starts behind the rider
    parts["B2"].beam((-3.8, 0, 9.4), (2.6, 0, 10.6), 3.2, 1.2, "olive-")
    parts["B3"].beam((1.6, 0, 10.2), (8.6, 0, 9.9), 5.0, 0.9, "olive-")
    parts["B4"].beam((7.6, 0, 9.6), (12.4, 0, 7.6), 4.6, 0.6, "blotch")
    # the anal fin: rounded, two boxes
    parts["B4"].beam((10.2, 0, -6.0), (13.4, 0, -9.0), 4.4, 0.9, "olive-")
    parts["B4"].beam((12.4, 0, -8.2), (14.8, 0, -9.2), 3.0, 0.6, "blotch")
    # the belly fins: a small pair under the chest
    parts["B1"].beam((-10.5, 3.0, -6.6), (-7.8, 4.0, -10.6), 2.6, 0.6, "olive-", mirror=True)
    # the side fins: big rounded paddles standing off the flank, each on its own joint
    for name, side in (("PecR", 1), ("PecL", -1)):
        pec = m.part(name, (-11.0, 8.0 * side, -2.4), "B1")
        pec.beam((-11.5, 7.8 * side, -2.4), (-5.5, 9.8 * side, -3.6), 5.0, 0.9, "olive-")
        pec.beam((-6.8, 9.35 * side, -3.3), (-3.0, 10.6 * side, -4.2), 3.8, 0.6, "blotch")

    # the tail fan: a root block, a middle and two short lobes turned out, so the outline is round
    tail = parts["Tail"]
    tail.beam((20.0, 0, 0), (23.5, 0, 0), 9.6, 1.5, "olive")
    tail.beam((22.5, 0, 0), (26.6, 0, 0), 7.2, 0.9, "blotch")
    tail.beam((21.8, 0, 2.6), (25.6, 0, 5.1), 3.8, 1.2, "olive-")
    tail.beam((21.8, 0, -2.6), (25.6, 0, -5.1), 3.8, 1.2, "olive-")
