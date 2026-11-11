"""Kronosaurus (zone 8's Legendary: the giant pliosaur, king of the vents) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Its idea: a crocodile's skull a third of the animal, on a scarred whale's body that flies on four giant flippers. Dark
olive over bone, one sulphur line where they meet, and a sulphur halo in the eye.
It has to read as bigger and meaner than the Liopleurodon, and differs from it like this:
- The skull is longer and heavier, and wider than the neck behind it, so the head has its own shape from above: wide
  cheeks, a narrower step where the eye sits, then a deep snout of three long blocks in a chain. A ridge runs up the
  skull's roof from the snout to the nape.
- Fangs: three pairs of long teeth lean out and hang past the lower jaw, at the tip and halfway along. A thin dark gum
  line set inside the lips. The jaw is its own part and opens.
- A heavy brow starts in the cheek, sits on the eye and comes well past it in front.
- The trunk is a deeper barrel: the back arches up to a hump over the shoulders and falls to a short tail, the belly
  dips under the middle. One number changes from slice to slice, never two.
- Old scars: pale rake marks cut across the left flank and the right hip (shallow dents), all slanting the same way.
- The hind flippers are bigger than the front ones, as a pliosaur's were; each has a darker collar round its root.
The rider sits on the hump, on a saddle of back between two wells for the legs."""
import math

NAME, ZONE, RARITY = "Kronosaurus", "ZONE 8 / VENTS", "LEGENDARY"
U = 0.5
PALETTE = {"hide": "#3F482B", "belly": "#E9E0C8", "sulphur": "#D0A838", "tooth": "#FFFFFF", "mouth": "#5E222C", "gum": "#8A3F4A",
           "black": "#15181D", "halo": "#FFD36B", "scar": "#C6C3A2"}
SEAT = (3, 10, 10.5)
GLOW = {"halo": 0.4}  # only the thin halo of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
FRAME, ORTHO = 3.9, 56.0
EDGE = -1  # the height where the bone belly ends; the sulphur line is the row of cubes above it

# the body: (from, to, cubes out, bottom, top). One number changes from slice to slice, never two: the back rises to a
# hump over the shoulders and falls to the tail, the belly dips under the middle, the shoulders are the widest
SLICES = ((-16, -13, 7, -6, 7), (-13, -11, 8, -6, 7), (-11, -9, 8, -6, 8), (-9, -7, 8, -7, 8), (-7, -5, 9, -7, 8), (-5, -3, 9, -7, 9),
          (-3, -1, 9, -8, 9), (-1, 1, 10, -8, 9), (1, 5, 10, -8, 10), (5, 7, 9, -8, 10), (7, 9, 9, -7, 10), (9, 11, 9, -7, 9),
          (11, 13, 8, -7, 9), (13, 15, 8, -6, 9), (15, 17, 8, -6, 8), (17, 19, 7, -6, 8), (19, 21, 7, -6, 7), (21, 23, 7, -5, 7),
          (23, 25, 6, -5, 7), (25, 27, 6, -5, 6), (27, 29, 5, -5, 6), (29, 31, 5, -4, 6), (31, 33, 5, -4, 5), (33, 35, 4, -4, 5),
          (35, 37, 4, -4, 4))
PIECES = (("Neck", -16), ("Body", -13), ("Hip", 11), ("T1", 19), ("T2", 25), ("T3", 31))  # each piece and where it starts
CHAIN = [name for name, _ in PIECES]
AMPLITUDES = [1.0, 1.5, 3, 4.5, 6.5, 8.5]
CHEEK = (8, -5, 6)  # the back of the skull: cubes out, bottom, top


def pose(parts, phase):
    """a stiff body that flies on its flippers: they beat up and down, the big back pair half a beat behind the front;
    only a small wave runs down the hips and the tail. The jaw opens and shuts once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.6 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(11) * (0.5 + 0.5 * math.sin(phase))
    for name, side, lag in (("FlipperFR", 1, 0.0), ("FlipperFL", -1, 0.0), ("FlipperBR", 1, math.pi), ("FlipperBL", -1, math.pi)):
        parts[name].rotation_euler.x = side * math.radians(16) * math.sin(phase + lag)
        parts[name].rotation_euler.z = side * math.radians(7) * math.sin(phase + lag - 1.0)


def steps_for(n):
    """the corners of a slice, the same on the back and underneath: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 7 else ([(2, 1), (1, 1)] if n >= 5 else [(1, 1)])


def dress(p, x0, x1, n, bot, top, steps):
    """the colours of a slice: lighter on the top row, a darker line on the lowest step of the back, the bone belly, and
    the sulphur line on the row above it"""
    if steps > 1:
        p.paint_sym(x0, x1, n, top - steps, top - steps + 1, "hide-")
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    p.paint_sym(x0, x1, n, bot, EDGE, "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    p.paint_sym(x0, x1, n, EDGE, EDGE + 1, "sulphur")


# a flipper, drawn from its root: a short arm that goes out from the body, then a long wing in three boxes swept back
# from it, each smaller and thinner than the last and starting inside it. (from, to, width, thickness, colour)
WING = (((-0.6, -1.8, 0.3), (0.4, 3.0, -0.6), 6.4, 2.0, "hide"), ((0.0, 1.08, -0.24), (5.6, 8.7, -1.7), 6.0, 1.3, "hide"),
        ((3.92, 6.41, -1.26), (9.4, 12.3, -2.5), 4.4, 0.8, "hide"), ((7.76, 10.53, -2.13), (11.8, 14.3, -3.0), 2.8, 0.45, "hide-"))


def build(m):
    cn, cbot, ctop = CHEEK
    head = m.part("Head", (-16, 0, 0))
    # the skull: the wide cheeks at the back (wider than the neck), and a narrower, lower step in front where the eye sits
    head.hull(-20, -16, cn, cbot, ctop, "hide", [(2, 1)], [(2, 1)])
    dress(head, -20, -16, cn, cbot, ctop, 1)
    head.hull(-26, -20, 7, -5, 5, "hide", [(1, 1)], [(1, 1)])
    dress(head, -26, -20, 7, -5, 5, 1)
    # the snout: three long, deep blocks in a chain, each tilted a little nose-down, lower and narrower than the last. Each
    # has a pale lip plate underneath with a thin dark gum line; the first two have a lighter plate on top, which starts
    # past the end of the block before. (from, to, middle height at each end, width, thickness, plate, plate from, gum from)
    blocks = ((-25.5, -32.5, 2.0, 1.6, 12.6, 4.4, 7.4, -25.5, -25.5), (-31.8, -38.2, 1.5, 1.15, 9.8, 3.6, 5.4, -32.7, -32.8),
              (-37.6, -42.3, 1.1, 0.9, 7.2, 2.9, 0.0, 0.0, -38.5))

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
    # the ridge on the skull's roof: one long low block that climbs from the snout to the nape, a tone darker
    head.beam((-27.0, 0, 4.2), (-15.7, 0, 6.0), 3.0, 1.4, "hide-", flat="z")
    # the dark inside of the mouth: three blocks that stay behind the teeth and end inside the lips and the jaw
    for x0, x1, half, low, high in ((-32.0, -25.6, 4.0, -3.05, -0.85), (-37.4, -32.0, 2.9, -3.05, -0.9), (-40.6, -37.4, 1.5, -3.0, -0.95)):
        head.block(x0, (-half, half, low, high), x1, (-half, half, low, high), "mouth")
    # the upper teeth, each with its base sunk into the gum. Three pairs are fangs: long, leaning out, hanging past the
    # lower jaw: two at the tip of the snout and one halfway along. (block, x, size, length, lean out)
    for k, x, size, length, lean in ((0, -27.2, 1.0, 1.2, 0.0), (0, -28.7, 1.0, 1.2, 0.0), (0, -30.2, 1.0, 1.25, 0.0), (0, -31.7, 1.0, 1.3, 0.0),
                                     (1, -33.6, 1.4, 2.6, 1.5), (1, -35.0, 1.0, 1.35, 0.0), (1, -36.3, 1.0, 1.35, 0.0), (1, -37.5, 0.95, 1.3, 0.0),
                                     (2, -39.0, 0.9, 1.25, 0.0), (2, -40.15, 1.4, 2.8, 1.4), (2, -41.4, 1.1, 2.1, 1.0)):
        head.tooth(x, blocks[k][4] / 2 - 0.55 - size / 2, lip_bottom(k, x) - 0.05, size, length, "tooth", lean=(0.0, lean))  # outer edges in line
    # the eye, on the step in front of the cheek: a dark socket, a thin halo of soft light, a dark pupil standing out of
    # it. The heavy brow starts in the cheek, sits on the eye and comes well past it in front, slanting down, so it
    # scowls: it hides the front of the halo's top and lets the back of it show
    socket = (7.38, 7.94, 0.4, 3.2)
    head.block(-25.6, socket, -22.8, socket, "hide-", mirror=True)
    halo = (7.85, 8.07, 0.8, 2.8)
    head.block(-25.2, halo, -23.2, halo, "halo", mirror=True)
    pupil = (7.97, 8.2, 1.05, 2.55)
    head.block(-24.95, pupil, -23.45, pupil, "black", mirror=True)
    head.beam((-27.8, 7.25, 2.75), (-19.2, 7.25, 3.95), 1.7, 2.2, "hide", mirror=True)
    nostril = (1.4, 2.0, 2.3, 2.75)
    head.block(-39.6, nostril, -39.0, nostril, "black", mirror=True)

    # the lower jaw, on its own joint: three boxes in a chain like the snout, deep at the hinge, with its own gum line
    # and teeth, and a darker chin plate. It is narrower than the snout, so the fangs hang outside it
    jaw = m.part("Jaw", (-25.0, 0, -2.8), "Head")
    jaws = ((-25.3, -32.6, -3.55, -3.45, 11.6, 2.0, -26.2), (-31.9, -38.2, -3.45, -3.3, 8.4, 1.5, -32.9),
            (-37.6, -41.5, -3.35, -3.2, 5.4, 1.1, -38.5))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    jaw.beam((-27.0, 0, -4.66), (-32.0, 0, -4.58), 8.0, 0.4, "belly-", flat="z")
    for k, x in ((0, -27.95), (0, -29.45), (0, -30.95), (1, -34.3), (1, -35.65), (1, -36.9), (2, -39.5), (2, -40.7)):
        jaw.tooth(x, jaws[k][4] / 2 - 0.85, jaw_top(k, x) + 0.05, (0.85, 0.85, 0.75)[k], -1.05, "tooth")

    # the body: the neck, the barrel in one stiff piece, the hips, and the short tail in three pieces
    made, prev, starts = {}, (cn, cbot, ctop, 1), dict((x, name) for name, x in PIECES)
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

    # the old scars: pale rake marks cut a third of a cube into the hide, slanting down and back. Three across the left
    # flank behind the rider, two on the right hip
    for x, z0, z1 in ((5, 5, 7), (6, 3, 5), (7, 1, 3), (8, 4, 6), (9, 2, 4)):
        made["Body"].dent(x, x + 1, -9, z0, z1, "scar", pair=False)
    for x, z0, z1 in ((11, 4, 6), (12, 2, 4), (13, 1, 2)):
        made["Hip"].dent(x, x + 1, -8, z0, z1, "scar", pair=False)
    for x, z0, z1 in ((12, 3, 5), (13, 1, 3), (15, 3, 5), (16, 1, 3)):
        made["Hip"].dent(x, x + 1, 8, z0, z1, "scar", pair=False)
    # the seat: on the hump. The back is far too wide to sit astride, so the rider gets a saddle of back three cubes
    # wide between two wells for the legs
    made["Body"].carve_pair(2, 5, 2, 4, 8, 10)

    # the tail's end: three blunt boxes, each smaller and starting inside the last
    made["T3"].beam((36.5, 0, 0.0), (39.4, 0, 0.0), 6.6, 5.6, "hide")
    made["T3"].beam((38.6, 0, 0.0), (40.7, 0, -0.1), 4.4, 3.6, "hide")
    made["T3"].beam((40.0, 0, -0.1), (41.6, 0, -0.2), 2.6, 2.0, "hide-")

    def flipper(name, side, parent, root, size):
        """a flipper on its own joint (side: 1 right, -1 left), WING drawn `size` times as big from `root`, with a darker
        collar round the root of its arm, a little wider and thicker than the arm"""
        part = m.part(name, (root[0], root[1] * side, root[2]), parent)

        def at(p):
            return (root[0] + size * p[0], side * (root[1] + size * p[1]), root[2] + size * p[2])

        (a, b, wide, thick, _) = WING[0]
        inner, outer = (tuple(a[i] + f * (b[i] - a[i]) for i in range(3)) for f in (-0.07, 0.62))  # it starts deeper than the arm
        part.beam(at(inner), at(outer), (wide + 0.8) * size, (thick + 0.6) * size, "hide-", flat="z")
        for a, b, wide, thick, colour in WING:
            part.beam(at(a), at(b), wide * size, thick * size, colour, flat="z")

    for name, side in (("FlipperFR", 1), ("FlipperFL", -1)):
        flipper(name, side, "Body", (-6.0, 9.3, -3.0), 1.15)
    for name, side in (("FlipperBR", 1), ("FlipperBL", -1)):
        flipper(name, side, "Hip", (15.0, 8.3, -3.0), 1.28)
