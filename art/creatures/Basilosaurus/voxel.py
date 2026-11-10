"""Basilosaurus (zone 7's Legendary: the prehistoric whale as long and thin as a sea serpent) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Designed from the real animal, not from another creature's build.
Its idea: a whale that is still half a serpent. A small toothy head on an endless body, and two tiny hind legs it no
longer needs, far back, as the only bright thing on it.
- The head is small for the body: a short skull box and a long, narrow snout of three blocks in a chain. The nostrils sit
  halfway up the snout, on their way to becoming a blowhole. Pointed teeth at the front; broad blade teeth in pairs at the
  back, like a saw. The thin dark gum line. The jaw is its own part and opens.
- The body is seventeen slices. Each is one step bigger or smaller than the last, in width or in height, never both: a
  short neck, a long even middle with a deeper belly, a very long taper. A small knuckle of spine stands on the back of
  each slice: the backbone of a serpent, not a row of spikes. The flank is plain: dark above, pale below.
- The front flippers have an elbow: an upper arm that goes out, a paddle that turns back from it.
- The hind legs are two tiny bent limbs far down the body, with amber feet: the one accent, and the head's echo.
- A small flat tail fluke, on a joint of its own. It swims by bending up and down, as whales do.
- The eye is small, with a dark pupil and a thin halo of soft light, under a brow that sits on it.
The rider sits behind the flippers, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Basilosaurus", "ZONE 7 / MIDNIGHT", "LEGENDARY"
U = 0.52
PALETTE = {"hide": "#535D68", "belly": "#D8D2B8", "tooth": "#FFFFFF", "mouth": "#6A2630", "gum": "#9A4F58", "black": "#22262B",
           "amber": "#E2A03C", "soft": "#F2C46A"}
SEAT = (6, 5, 5.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
FRAME, ORTHO, ORTHO_SWIM = 3.25, 47.5, 52.0
SLICES = 17
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(SLICES)] + ["Tail", "Fluke"]
AMPLITUDES = [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 10, 11, 12, 13, 16]


def pose(parts, phase):
    """a whale's swim on a serpent's body: the wave runs down the long chain up and down, not side to side. The jaw opens
    and shuts once a beat; the flippers row a little; the fluke beats at the end of the wave"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(10) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(12) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(7) * math.sin(phase - 1.8)


def steps_for(n):
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def slab(p, x0, x1, n, bot, top, edge):
    """a slice of body: stepped corners, dark hide (lighter on the top row, darker on the shoulder step), a pale belly up
    to the height `edge`"""
    steps = steps_for(n)
    p.hull(x0, x1, n, bot, top, "hide", steps, steps)
    if len(steps) > 1:
        p.paint_sym(x0, x1, n, top - len(steps), top - 1, "hide-")
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    p.paint_sym(x0, x1, n, bot, edge, "belly")
    if steps:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def build(m):
    head = m.part("Head", (-6, 0, 0))
    # the skull: a small box, pale under the jaw line. The snout and the jaw both start inside its front face
    head.hull(-11, -6, 3, -4, 3, "hide", [(1, 1)], [(1, 1)])
    head.paint_sym(-11, -6, 3, 2, 3, "hide+")
    head.paint_sym(-11, -6, 3, -4, -1, "belly")
    head.paint_sym(-11, -6, 3, -4, -3, "belly-")
    # the snout: three long, narrow blocks in a chain, each tilted a little nose-down, lower and narrower than the last.
    # Each has a pale lip plate underneath with a thin dark gum line; the first two have a lighter plate on top, which
    # starts past the end of the block before
    blocks = ((-10.5, -14.5, 0.55, 0.3, 5.4, 2.8, 3.0, -10.5, -10.5), (-13.9, -18.3, 0.25, 0.0, 4.0, 2.2, 2.0, -14.9, -14.8),
              (-17.7, -22.0, -0.05, -0.25, 2.8, 1.7, 0.0, 0.0, -18.6))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.6

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "hide", flat="z")
        lip = thick / 2 + 0.3
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.6, "belly", flat="z")
        if plate:
            rise = thick / 2 + 0.175
            head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.45, "hide+", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                  flat="z")
    # the nostrils: halfway up the snout, on top, not at its tip (a whale in the making)
    nostril = (0.35, 0.85, 1.5, 1.75)
    head.block(-16.6, nostril, -16.0, nostril, "black", mirror=True)
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    for x0, x1, half in ((-14.0, -10.8, 1.3), (-17.9, -14.0, 0.6)):
        head.block(x0, (-half, half, -2.85, -1.2), x1, (-half, half, -2.85, -1.2), "mouth")
    # the upper teeth, each with its base sunk into the gum: broad blades in pairs at the back, like a saw; pointed ones
    # along the front of the snout
    for x in (-11.7, -13.1):
        head.tooth(x, 1.9, lip_bottom(0, x) - 0.05, 0.55, 0.75, "tooth", long=1.2)
    for k, x in ((1, -15.4), (1, -16.5), (1, -17.6), (2, -19.2), (2, -20.3), (2, -21.3)):
        head.tooth(x, (0.0, 1.2, 0.6)[k], lip_bottom(k, x) - 0.05, 0.5, 1.0 if k == 1 else 0.85, "tooth")
    # the eye: small, a dark socket on the skull's side, a thin halo of soft light, a dark pupil standing out of it. The brow
    # sits on the eye: it covers the top of the eye's square, slanting, and stands only a little proud of the pupil
    ring = (3.4, 3.9, 0.0, 1.6)
    head.block(-9.6, ring, -7.8, ring, "hide-", mirror=True)
    halo = (3.8, 4.05, 0.25, 1.4)
    head.block(-9.35, halo, -8.05, halo, "soft", mirror=True)
    pupil = (3.9, 4.2, 0.45, 1.2)
    head.block(-9.15, pupil, -8.25, pupil, "black", mirror=True)
    head.beam((-9.9, 3.76, 1.3), (-7.5, 3.76, 1.5), 0.9, 1.12, "hide", mirror=True)

    # the lower jaw, on its own joint: three slim boxes in a chain like the snout, with its own gum line and teeth
    jaw = m.part("Jaw", (-10.5, 0, -2.6), "Head")
    jaws = ((-10.7, -14.7, -3.05, -3.1, 4.6, 1.2, -10.9), (-14.1, -18.4, -3.1, -3.05, 3.2, 0.9, -15.0),
            (-17.8, -21.2, -3.05, -2.95, 2.0, 0.6, -18.7))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    for x in (-12.3, -13.7):
        jaw.tooth(x, 1.7, jaw_top(0, x) + 0.05, 0.5, -0.55, "tooth", long=1.1)
    for k, x in ((1, -15.6), (1, -16.8), (1, -17.7), (2, -19.3), (2, -20.4)):
        jaw.tooth(x, (0.0, 1.0, 0.45)[k], jaw_top(k, x) + 0.05, 0.45, -0.55, "tooth")

    # the body: seventeen slices. Each is one step bigger or smaller than the one before, in width or in height but not
    # both: a short neck, a long even middle, a very long taper. Each is (from, to, cubes out, bottom, top, belly's edge)
    slices = ((-6, -3, 3, -4, 4, -1), (-3, 0, 4, -4, 4, -1), (0, 4, 4, -4, 5, -1), (4, 8, 5, -4, 5, -1), (8, 12, 5, -5, 5, -1),
              (12, 16, 5, -5, 5, -1), (16, 20, 5, -5, 5, -1), (20, 24, 5, -4, 5, -1), (24, 27, 4, -4, 5, -1), (27, 30, 4, -4, 4, -1),
              (30, 33, 4, -3, 4, -1), (33, 36, 4, -3, 3, -1), (36, 39, 3, -3, 3, -1), (39, 42, 3, -2, 3, 0), (42, 45, 3, -2, 2, 0),
              (45, 48, 2, -2, 2, 0), (48, 51, 2, -1, 2, 0))
    segs = [m.part(f"S{i + 1}", (sl[0], 0, 0), "Head" if i == 0 else f"S{i}") for i, sl in enumerate(slices)]
    for i, (seg, (x0, x1, n, bot, top, edge)) in enumerate(zip(segs, slices)):
        slab(seg, x0, x1, n, bot, top, edge)
        # a sleeve into the piece in front, so a bending joint shows body. It is sized from the smaller of the two pieces
        # and stays clear of its steps, so none of its faces lies in the plane of a face that shows
        fn, fbot, ftop = slices[i - 1][2:5] if i else (3, -4, 3)
        small = min(n, fn)
        clear = 2 if small >= 4 else 1
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "hide-")
        # the backbone: one small knuckle on the back of each slice, smaller as the body thins (none under the rider)
        if 1 <= i <= 15 and i != 3:
            half, tall = (0.6, 0.6) if n >= 4 else ((0.5, 0.5) if n == 3 else (0.4, 0.35))
            mid = (x0 + x1) / 2
            knuckle = (-half, half, top - 0.12, top + tall)
            seg.block(mid - 0.8, knuckle, mid + 0.8, knuckle, "hide")
    # the seat: behind the flippers, a shallow slot either side for the rider's legs
    segs[3].dent(5, 7, 5, 0, 3, "hide-")

    # the front flippers, each on its own joint, with an elbow: an upper arm that goes out from the shoulder, then a
    # paddle that turns back from it, in two boxes
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (1.6, 3.8 * side, -1.3), "S3")
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in (((1.6, 3.6, -1.3), (4.05, 9.1, -2.82), 3.0, 1.2, "hide"),
                                                                ((3.4, 7.65, -2.42), (9.8, 10.25, -3.82), 3.6, 0.8, "hide"),
                                                                ((8.5, 9.72, -3.54), (12.0, 11.2, -4.3), 2.4, 0.45, "hide-")):
            part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")

    # the hind legs: two tiny bent limbs far down the body, left over from when it walked. A thigh, and an amber foot:
    # the one accent on the animal
    segs[13].beam((40.2, 2.9, -0.6), (41.9, 5.0, -1.9), 1.2, 0.8, "hide-", flat="z", mirror=True)
    segs[13].beam((41.45, 4.44, -1.55), (43.4, 5.3, -2.9), 0.8, 0.45, "amber", flat="z", mirror=True)

    # the tail: a short stock, taller than the fluke is thick (a whale's keel), then a flat fluke on a joint of its own: a hub and two lobes swept back, each ending
    # in a darker tip. It lies flat, as a whale's does
    tail = m.part("Tail", (51, 0, 0.5), "S17")
    tail.beam((50.6, 0, 0.5), (53.6, 0, 0.5), 2.8, 2.2, "hide", flat="z")
    fluke = m.part("Fluke", (53.0, 0, 0.5), "Tail")
    fluke.beam((52.6, 0, 0.5), (55.9, 0, 0.5), 6.8, 1.8, "hide", flat="z")
    fluke.beam((54.2, 1.8, 0.5), (59.0, 7.0, 0.5), 4.0, 1.0, "hide", flat="z", mirror=True)
    fluke.beam((57.8, 5.7, 0.5), (60.4, 8.7, 0.5), 2.6, 0.6, "hide-", flat="z", mirror=True)
