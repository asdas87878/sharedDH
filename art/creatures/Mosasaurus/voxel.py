"""Mosasaurus (zone 7's Legendary: the giant prehistoric sea lizard) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. The shark-lizard body.
Its idea: the lizard that became a shark. A long hunting snout, a lizard's ridged back, a shark's tail, and a line of cold
light along the edge where its dark back meets its pale belly: the sense it hunts by in the dark.
- A headline Legendary: about 43 studs, long and lean.
- The snout is three long blocks in a chain, each tilted nose-down, lower and narrower: a long, low wedge. Each has a pale
  lip plate with a thin dark gum line, and pointed teeth all the way along. The jaw is its own part, three boxes, and opens.
- The body is sixteen slices. From the shoulders back each is one step smaller than the last, in width or in height,
  never both, so it tapers smoothly into a long tail and bends like a serpent. A ridge of pale scutes runs down
  the spine, biggest over the shoulders, and turns into a low crest of plates on the tail.
- The light follows the body's own lines: the edge of the belly along each slice and the back of the skull, and the
  leading edge of the tail fin. Nowhere else.
- Four flippers, each on its own joint: three stacked paddles swept back, with raised ridges fanning along them like the
  bones of a hand.
- The tail turns down at its end and carries a shark's fluke on a joint of its own: two lobes, each in two boxes.
- The eye keeps a dark pupil with a thin halo of the same cold light. The brow sits on the eye: it covers the top of the
  eye's square, slanting, and stands only a little proud of the pupil.
The rider sits on the third slice, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Mosasaurus", "ZONE 7 / MIDNIGHT", "LEGENDARY"
U = 0.5
PALETTE = {"hide": "#2F4B56", "belly": "#D9D3BE", "tooth": "#FFFFFF", "mouth": "#6A2630", "gum": "#9A4F58", "black": "#22262B",
           "lume": "#63E6D0"}
SEAT = (-3, 6, 6.5)
GLOW = {"lume": 0.4}  # its signature colour: the belly's edge, the tail fin's leading edge and the halo of the eye
FRAME, ORTHO = 3.2, 47.0
SLICES = 16
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(SLICES)] + ["Tail", "Fluke"]
AMPLITUDES = [2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 10, 11, 12, 14, 17]


def pose(parts, phase):
    """a serpent's swim down the long chain; the jaw opens and shuts once a beat; the flippers paddle a little, the back
    pair half a beat behind the front"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(11) * (0.5 + 0.5 * math.sin(phase))
    for name, side, lag in (("FlipperFR", 1, 0.0), ("FlipperFL", -1, 0.0), ("FlipperBR", 1, math.pi), ("FlipperBL", -1, math.pi)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase + lag)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase + lag - 1.0)


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
    p.paint_sym(x0, x1, n, bot, bot + len(steps), "belly-")


def flipper(part, side, boxes):
    """a flipper on one side (side: 1 right, -1 left): boxes as (from, to, width, thickness, colour), lying flat"""
    for (ax, ay, az), (bx, by, bz), wide, thick, colour in boxes:
        part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")


def build(m):
    head = m.part("Head", (-13, 0, 0))
    # the back of the skull: a low stepped slab, pale below the jaw line; its bottom row is wider at the front, so the
    # jaw's root is buried
    head.hull(-18, -13, 4, -4, 4, "hide", [(2, 1)], [(2, 1)])
    head.paint_sym(-18, -13, 4, 3, 4, "hide+")
    head.paint_sym(-18, -13, 4, -4, -1, "belly")
    head.paint_sym(-18, -13, 4, -4, -3, "belly-")
    head.sym(-18, -16, 3, -4, -3, "belly-")
    # the snout: three long blocks in a chain, each tilted nose-down, lower and narrower than the last. Each has a pale
    # lip plate underneath with a thin dark gum line; the first two have a lighter plate on top, which starts past the end
    # of the block before
    blocks = ((-17.5, -22.0, 1.35, 1.05, 7.6, 3.1, 4.4, -17.5, -17.5), (-21.4, -26.0, 0.95, 0.65, 5.6, 2.2, 3.0, -22.2, -22.3),
              (-25.4, -30.0, 0.75, 0.5, 3.8, 1.6, 0.0, 0.0, -26.3))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.7

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "hide", flat="z")
        lip = thick / 2 + 0.35
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.7, "belly", flat="z")
        if plate:
            rise = thick / 2 + 0.175
            head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.45, "hide+", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                  flat="z")
    # the dark inside of the mouth: three blocks that stay behind the teeth and end inside the lips and the jaw
    for x0, x1, half, low, high in ((-21.8, -17.6, 2.1, -2.75, -0.75), (-26.0, -21.8, 1.25, -2.75, -0.7), (-29.0, -26.0, 0.4, -2.65, -0.6)):
        head.block(x0, (-half, half, low, high), x1, (-half, half, low, high), "mouth")
    # pointed teeth all the way along the upper jaw, each with its base sunk into the gum
    for k, x in ((0, -18.4), (0, -19.6), (0, -20.8), (1, -22.9), (1, -24.1), (1, -25.2), (2, -26.9), (2, -28.0), (2, -29.1)):
        head.tooth(x, (2.9, 1.9, 1.0)[k], lip_bottom(k, x) - 0.05, 0.7, 0.9 if k < 2 else 0.75, "tooth")
    # the eye: a pale ring on the skull's side, a thin halo of cold light, a dark pupil standing out of it. The brow sits
    # on the eye: a slanting box that covers the top of the eye's square (more at the front, so it scowls) and all of the
    # ring above it, and stands only a little proud of the pupil
    ring = (4.4, 4.95, 0.3, 2.6)
    head.block(-17.2, ring, -15.0, ring, "belly", mirror=True)
    halo = (4.8, 5.08, 0.6, 2.3)
    head.block(-16.85, halo, -15.35, halo, "lume", mirror=True)
    pupil = (4.9, 5.25, 0.85, 2.05)
    head.block(-16.6, pupil, -15.6, pupil, "black", mirror=True)
    head.beam((-17.5, 4.785, 2.15), (-14.6, 4.785, 2.75), 1.3, 1.17, "hide", mirror=True)
    # the line of light runs on along the back of the skull, on the edge of the pale under-jaw
    line = (4.45, 4.68, -1.15, -0.85)
    head.block(-17.9, line, -13.1, line, "lume", mirror=True)
    nostril = (1.5, 2.05, 0.75, 1.1)
    head.block(-28.6, nostril, -28.0, nostril, "black", mirror=True)

    # the lower jaw, on its own joint: three boxes in a chain like the snout, a little shorter than it, with its own gum
    # line and teeth, and a darker chin plate
    jaw = m.part("Jaw", (-17.2, 0, -2.4), "Head")
    jaws = ((-17.4, -22.2, -2.95, -2.85, 6.6, 1.4, -18.2), (-21.6, -26.2, -2.85, -2.7, 4.8, 1.0, -22.5),
            (-25.6, -29.2, -2.75, -2.6, 3.0, 0.6, -26.5))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 - 0.3, 0, jaw_top(k, x1 - 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    jaw.beam((-19.0, 0, -3.74), (-21.6, 0, -3.69), 4.6, 0.4, "belly-", flat="z")
    for k, x in ((0, -18.9), (0, -20.1), (0, -21.3), (1, -23.2), (1, -24.4), (1, -25.5), (2, -27.0), (2, -28.2)):
        jaw.tooth(x, (2.55, 1.7, 0.8)[k], jaw_top(k, x) + 0.05, 0.6, -0.6, "tooth")

    # the body: sixteen slices. From the shoulders back each is one step smaller than the one before, in width or in height
    # but not both, so the taper into the long tail is smooth. Each is (from, to, cubes out, bottom, top, the belly's edge)
    slices = ((-13, -9, 5, -4, 5, -1), (-9, -5, 6, -5, 6, -1), (-5, -1, 6, -5, 6, -1), (-1, 3, 6, -5, 6, -1), (3, 7, 6, -5, 6, -1),
              (7, 11, 5, -4, 5, -1), (11, 14, 5, -4, 5, -1), (14, 17, 5, -4, 4, -1), (17, 20, 4, -4, 4, -1), (20, 23, 4, -4, 3, -1),
              (23, 26, 4, -3, 3, 0), (26, 29, 3, -3, 3, 0), (29, 32, 3, -2, 3, 0), (32, 35, 3, -2, 2, 0), (35, 38, 2, -2, 2, 0),
              (38, 41, 2, -1, 2, 0))
    scutes = (0.8, 1.1, 0.0, 1.5, 1.5, 1.3, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.0, 0.0, 0.0)  # the ridge: a scute's half length
    segs = [m.part(f"S{i + 1}", (sl[0], 0, 0), "Head" if i == 0 else f"S{i}") for i, sl in enumerate(slices)]
    for i, (seg, (x0, x1, n, bot, top, edge)) in enumerate(zip(segs, slices)):
        slab(seg, x0, x1, n, bot, top, edge)
        # a sleeve into the piece in front, so a bending joint shows body. It is sized from the smaller of the two pieces
        # and stays clear of its steps, so none of its faces lies in the plane of a face that shows
        fn, fbot, ftop = slices[i - 1][2:5] if i else (4, -4, 4)
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + 2, min(top, ftop) - 2, "hide-")
        # the line of cold light: it lies on the edge where the dark back meets the pale belly, the length of the slice
        if i < len(slices) - 1:  # (not on the last slice, which is too small for it: the tail fin picks the line up)
            line = (n + 0.45, n + 0.68, edge - 0.15, edge + 0.15)
            seg.block(x0 + 0.2, line, x1 - 0.2, line, "lume", mirror=True)
        half = scutes[i]
        if half:  # the ridge: a pale scute on the spine, leaning back; biggest over the shoulders (the rider sits on the third)
            mid = (x0 + x1) / 2 - 0.3
            seg.spike([(mid - half, -0.7, top - 0.15), (mid + half, -0.7, top - 0.15), (mid + half, 0.7, top - 0.15), (mid - half, 0.7, top - 0.15)],
                      (mid + 1.0, 0.0, top + 2.0 * half), "belly")
        if i >= 13:  # on the tail the ridge becomes a low crest: one thin plate standing on each slice, leading to the fluke
            tall = (1.4, 1.6, 1.9)[i - 13]
            seg.beam((x0 + 0.3, 0, top + tall / 2 - 0.8), (x1 - 0.3, 0, top + tall / 2 - 0.8), tall, 0.6, "hide-")
    # the seat: a shallow slot either side for the rider's legs, above the line of light
    segs[2].dent(-4, -2, 6, 1, 4, "hide-")

    def paddle(name, side, parent, root, boxes, ridges):
        """a flipper on its own joint (side: 1 right, -1 left): stacked boxes lying flat, each smaller than the last, and
        raised ridges fanning along them like the bones of a hand. Each is (from, to, width, thickness[, colour])"""
        part = m.part(name, (root[0], root[1] * side, root[2]), parent)
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in boxes:
            part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")
        for (ax, ay, az), (bx, by, bz), wide, thick in ridges:
            part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, "hide+", flat="z")

    # the front flippers: big, three stacked paddles swept back, three ridges
    for name, side in (("FlipperFR", 1), ("FlipperFL", -1)):
        paddle(name, side, "S2", (-6.6, 4.9, -2.1),
               (((-6.6, 4.2, -2.1), (-1.88, 10.28, -3.45), 5.9, 1.3, "hide"), ((-3.2, 8.57, -3.07), (1.37, 13.79, -4.26), 4.9, 1.0, "hide"),
                ((0.08, 12.33, -3.92), (3.26, 15.95, -4.73), 3.2, 0.6, "hide-")),
               (((-8.04, 4.95, -2.05), (-0.53, 13.25, -3.99), 0.6, 1.8), ((-6.78, 3.97, -2.05), (0.56, 12.84, -4.06), 0.6, 1.8),
                ((-5.52, 2.99, -2.05), (1.37, 12.17, -3.99), 0.6, 1.8)))
    # the back flippers: two paddles, two ridges
    for name, side in (("FlipperBR", 1), ("FlipperBL", -1)):
        paddle(name, side, "S9", (18.3, 4.0, -1.0),
               (((18.3, 3.0, -1.0), (21.54, 6.84, -2.08), 4.0, 1.0, "hide"), ((20.63, 5.76, -1.78), (23.82, 9.48, -2.86), 3.1, 0.7, "hide-")),
               (((17.5, 3.27, -0.94), (22.5, 8.5, -2.5), 0.45, 1.4), ((18.7, 2.27, -0.94), (23.4, 7.7, -2.5), 0.45, 1.4)))

    # the tail runs on from the last slice: two slim boxes, the second turning downward, then a shark's fluke on a joint of
    # its own. The fluke is a hub with two lobes, each in two boxes; the upper one carries a rib of cold light along its
    # leading edge: the line of the body, picked up again at the tail
    tail = m.part("Tail", (41, 0, 0.5), "S16")
    tail.beam((40.6, 0, 0.5), (45.4, 0, 0.5), 2.6, 1.8, "hide")
    tail.beam((44.4, 0, 0.5), (48.5, 0, -1.0), 2.4, 1.5, "hide")
    fluke = m.part("Fluke", (47.6, 0, -0.7), "Tail")
    fluke.beam((47.4, 0, -0.6), (49.4, 0, -1.3), 4.2, 1.8, "hide")
    fluke.beam((48.2, 0, -1.0), (53.6, 0, -6.2), 3.0, 1.1, "hide")
    fluke.beam((52.5, 0, -5.1), (55.2, 0, -8.6), 2.0, 0.7, "hide-")
    fluke.beam((47.6, 0, -0.5), (51.2, 0, 6.7), 3.4, 0.8, "hide")
    fluke.beam((50.5, 0, 5.3), (52.9, 0, 10.3), 2.3, 0.5, "hide-")
    fluke.beam((45.95, 0, 0.0), (49.5, 0, 7.1), 0.5, 1.2, "lume")
