"""Liopleurodon (zone 6's Legendary: the big-headed pliosaur) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Its idea: a crocodile's head on a barrel that flies on four wings. Blue-black over cream, one ember line where they
meet, and an ember halo in the eye.
- The head is a quarter of the animal: a wide back skull (the cheeks), a narrower step in front of it where the eye
  sits, then a deep snout of three blocks in a chain, each tilted a little nose-down, lower and narrower. Pale lips, a
  thin dark gum line, big teeth all the way along. The jaw is its own part and opens.
- The brow is a slanting box that starts in the cheek, sits on the eye and comes past it in front.
- A short neck, thicker than the head, then the barrel: the back rises to the shoulders and falls away to the tail, the
  belly dips under the middle, and the widest slice is the middle one. One number changes from slice to slice, never
  two, so each of the three outlines makes its own broad staircase.
- It is stiff, as the real animal was: the trunk is one piece, and it swims with its four flippers. Each flipper is on
  its own joint: a short arm that goes out, then a long wing in three boxes swept back from it.
- The ember line is one row of cubes painted along every slice at one height, from the corner of the mouth to the tail.
The rider sits on the middle of the barrel (it is too broad for leg slots)."""
import math

NAME, ZONE, RARITY = "Liopleurodon", "ZONE 6 / TWILIGHT", "LEGENDARY"
U = 0.45
PALETTE = {"hide": "#28344C", "belly": "#E8DFC4", "ember": "#E0672E", "tooth": "#FFFFFF", "mouth": "#5E222C", "gum": "#8A3F4A",
           "black": "#15181D", "halo": "#FFB36B"}
SEAT = (0.5, 9, 9.5)
GLOW = {"halo": 0.4}  # only the thin halo of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
FRAME, ORTHO = 3.3, 42.0
EDGE = -1  # the height where the cream belly ends; the ember line is the row of cubes above it

# the body: (from, to, cubes out, bottom, top). One number changes from slice to slice, never two: the back rises to the
# shoulders and falls to the tail, the belly dips under the middle, the middle is the widest
SLICES = ((-20, -16, 7, -6, 7), (-16, -14, 8, -6, 7), (-14, -11, 8, -6, 8), (-11, -8, 8, -7, 8), (-8, -6, 9, -7, 8), (-6, -3, 9, -7, 9),
          (-3, 4, 9, -8, 9), (4, 6, 9, -8, 8), (6, 8, 9, -7, 8), (8, 10, 8, -7, 8), (10, 12, 8, -7, 7), (12, 14, 8, -6, 7),
          (14, 16, 7, -6, 7), (16, 18, 7, -6, 6), (18, 20, 6, -6, 6), (20, 22, 6, -5, 6), (22, 24, 5, -5, 6), (24, 26, 5, -5, 5),
          (26, 28, 5, -4, 5), (28, 30, 4, -4, 5), (30, 32, 4, -4, 4), (32, 34, 3, -4, 4), (34, 36, 3, -3, 4), (36, 38, 3, -3, 3))
PIECES = (("Neck", -20), ("Body", -16), ("Hip", 12), ("T1", 18), ("T2", 24), ("T3", 30))  # each piece and where it starts
CHAIN = [name for name, _ in PIECES]
AMPLITUDES = [1.5, 1.5, 3, 5, 7, 9]


def pose(parts, phase):
    """a stiff body that flies on its flippers: they beat up and down, the back pair half a beat behind the front; only
    a small wave runs down the hips and the tail. The jaw opens and shuts once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.6 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(10) * (0.5 + 0.5 * math.sin(phase))
    for name, side, lag in (("FlipperFR", 1, 0.0), ("FlipperFL", -1, 0.0), ("FlipperBR", 1, math.pi), ("FlipperBL", -1, math.pi)):
        parts[name].rotation_euler.x = side * math.radians(15) * math.sin(phase + lag)
        parts[name].rotation_euler.z = side * math.radians(7) * math.sin(phase + lag - 1.0)


def steps_for(n):
    """the corners of a slice, the same on the back and underneath: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 7 else ([(2, 1), (1, 1)] if n >= 5 else [(1, 1)])


def dress(p, x0, x1, n, bot, top, steps):
    """the colours of a slice: lighter on the top row, a darker line on the lowest step of the back, the cream belly, and
    the ember line on the row above it"""
    if steps > 1:
        p.paint_sym(x0, x1, n, top - steps, top - steps + 1, "hide-")
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    p.paint_sym(x0, x1, n, bot, EDGE, "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    p.paint_sym(x0, x1, n, EDGE, EDGE + 1, "ember")


def build(m):
    head = m.part("Head", (-20, 0, 0))
    # the skull: the wide cheeks at the back, and a narrower, lower step in front of them where the eye sits
    head.hull(-24, -20, 7, -5, 6, "hide", [(2, 1)], [(2, 1)])
    dress(head, -24, -20, 7, -5, 6, 1)
    head.hull(-28, -24, 6, -5, 5, "hide", [(1, 1)], [(1, 1)])
    dress(head, -28, -24, 6, -5, 5, 1)
    # the snout: three deep blocks in a chain, each tilted a little nose-down, lower and narrower than the last. Each has
    # a pale lip plate underneath with a thin dark gum line; the first two have a lighter plate on top, which starts past
    # the end of the block before. (from, to, middle height at each end, width, thickness, plate, plate from, gum from)
    blocks = ((-27.5, -32.5, 1.9, 1.55, 11.0, 4.0, 6.4, -27.5, -27.5), (-31.8, -36.6, 1.45, 1.2, 8.4, 3.2, 4.6, -32.7, -32.8),
              (-36.0, -40.0, 1.15, 0.95, 6.0, 2.5, 0.0, 0.0, -36.9))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.8

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "hide", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "belly", flat="z")
        if plate:
            rise = thick / 2 + 0.175
            head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.45, "hide+", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                  flat="z")
    # the dark inside of the mouth: three blocks that stay behind the teeth and end inside the lips and the jaw
    for x0, x1, half, low, high in ((-32.0, -27.6, 3.5, -3.0, -0.75), (-35.9, -32.0, 2.3, -3.05, -0.8), (-38.6, -35.9, 1.1, -2.95, -0.85)):
        head.block(x0, (-half, half, low, high), x1, (-half, half, low, high), "mouth")
    # big pointed teeth all the way along the upper jaw, each with its base sunk into the gum; the longest in the middle
    for k, x in ((0, -28.8), (0, -30.2), (0, -31.6), (1, -33.4), (1, -34.6), (1, -35.8), (2, -37.4), (2, -38.4), (2, -39.25)):
        head.tooth(x, (4.45, 3.15, 2.0)[k], lip_bottom(k, x) - 0.05, (0.95, 0.95, 0.85)[k], (1.2, 1.3, 1.2)[k], "tooth")
    # the eye, on the step in front of the cheek: a dark socket, a thin halo of soft light, a dark pupil standing out of
    # it. The brow starts in the cheek, sits on the eye and comes past it in front, slanting down, so it scowls: it hides
    # the front of the halo's top and lets the back of it show
    socket = (6.38, 6.94, 0.6, 3.4)
    head.block(-27.5, socket, -24.8, socket, "hide-", mirror=True)
    halo = (6.85, 7.07, 1.0, 3.0)
    head.block(-27.1, halo, -25.1, halo, "halo", mirror=True)
    pupil = (6.97, 7.2, 1.25, 2.75)
    head.block(-26.85, pupil, -25.35, pupil, "black", mirror=True)
    head.beam((-28.4, 6.35, 3.07), (-23.6, 6.35, 4.13), 1.45, 2.0, "hide", mirror=True)
    nostril = (1.3, 1.9, 2.2, 2.55)
    head.block(-38.6, nostril, -38.0, nostril, "black", mirror=True)

    # the lower jaw, on its own joint: three boxes in a chain like the snout, with its own gum line and teeth, and a
    # darker chin plate
    jaw = m.part("Jaw", (-27.0, 0, -2.8), "Head")
    jaws = ((-27.3, -32.6, -3.45, -3.35, 10.0, 1.7, -28.2), (-31.9, -36.6, -3.35, -3.2, 7.6, 1.3, -32.9),
            (-36.0, -39.3, -3.25, -3.1, 5.2, 0.95, -36.9))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    jaw.beam((-28.6, 0, -4.37), (-32.0, 0, -4.31), 7.0, 0.4, "belly-", flat="z")
    for k, x in ((0, -29.5), (0, -30.7), (0, -31.85), (1, -33.7), (1, -34.8), (1, -35.85), (2, -37.4), (2, -38.5)):
        jaw.tooth(x, (4.15, 2.95, 1.75)[k], jaw_top(k, x) + 0.05, 0.8, -1.0, "tooth")

    # the body: the neck, the barrel in one stiff piece, the hips, and the short tail in three pieces
    made, prev, starts = {}, (7, -5, 6, 1), dict((x, name) for name, x in PIECES)
    for x0, x1, n, bot, top in SLICES:
        steps = steps_for(n)
        if x0 in starts:
            parent = "Head" if not made else list(made)[-1]
            seg = made[starts[x0]] = m.part(starts[x0], (x0, 0, 0), parent)
            # a sleeve into the piece in front, so a bending joint shows body. It is sized from the smaller of the two
            # pieces and stays clear of both pieces' steps
            fn, fbot, ftop, fsteps = prev
            clear = max(len(steps), fsteps)
            seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "hide-")
        seg.hull(x0, x1, n, bot, top, "hide", steps, steps)
        dress(seg, x0, x1, n, bot, top, len(steps))
        prev = (n, bot, top, len(steps))

    # the tail's end: two blunt boxes, the second smaller and starting inside the first
    made["T3"].beam((37.5, 0, 0.3), (39.6, 0, 0.3), 4.4, 3.8, "hide")
    made["T3"].beam((38.9, 0, 0.3), (40.6, 0, 0.2), 2.8, 2.2, "hide-")

    def flipper(name, side, parent, root, boxes):
        """a flipper on its own joint (side: 1 right, -1 left): a short arm that goes out from the body, then a long wing
        in three boxes swept back from it, each smaller and thinner than the last and starting inside it"""
        part = m.part(name, (root[0], root[1] * side, root[2]), parent)
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in boxes:
            part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")

    for name, side in (("FlipperFR", 1), ("FlipperFL", -1)):
        flipper(name, side, "Body", (-10.0, 8.3, -2.6),
                (((-10.6, 6.5, -2.3), (-9.6, 11.3, -3.2), 6.4, 2.0, "hide"), ((-10.0, 9.38, -2.84), (-4.4, 17.0, -4.3), 6.0, 1.3, "hide"),
                 ((-6.08, 14.71, -3.86), (-0.6, 20.6, -5.1), 4.4, 0.8, "hide"), ((-2.24, 18.83, -4.73), (1.8, 22.6, -5.6), 2.8, 0.45, "hide-")))
    for name, side in (("FlipperBR", 1), ("FlipperBL", -1)):
        flipper(name, side, "Hip", (14.0, 7.6, -2.6),
                (((13.2, 5.6, -2.3), (14.1, 10.1, -3.1), 5.8, 1.9, "hide"), ((13.74, 8.3, -2.78), (18.9, 15.2, -4.1), 5.4, 1.2, "hide"),
                 ((17.35, 13.13, -3.7), (22.3, 18.4, -4.8), 4.0, 0.75, "hide"), ((20.82, 16.82, -4.47), (24.4, 20.2, -5.25), 2.5, 0.45, "hide-")))
