"""Dakosaurus (zone 3's Legendary: the prehistoric sea crocodile with a meat-eating dinosaur's head) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Designed from the real animal: a metriorhynchid, a crocodile that went to sea for good.
Its idea: a crocodile that turned into a shark and kept a tyrant's skull. All the weight is in the head.
- The skull is short and deep, not a crocodile's long flat one: a tall box, then a snout of three deep blocks in a chain,
  each tilted nose-down, lower and narrower, ending blunt. Pale lips with a thin dark gum line set inside their edge, and
  few, big blade teeth (long along the jaw, thin across). The jaw is its own part, three boxes, and opens.
- The brow is a slanting bar that sits on the eye, cuts the top of its square and runs on past it along the snout.
- The body is fourteen slices on joints. Each differs from the last by one cube in one thing: width, back or belly. The
  back arches to the seat and the belly hangs under the shoulders; the tail gets narrow before it gets low.
- One thin amber stripe runs along the flank from the skull to the bend of the tail, at one height the whole way: a
  raised strip half a cube tall on every slice.
- A low row of dark scutes down the spine, none at the seat.
- Four paddles, each on its own joint: two boxes swept back.
- The tail bends down and its end becomes the lower lobe of a shark-like fluke (on a joint); a fin stands up from the bend.
- The eye: a dark pupil in a thin soft halo, the only thing on it that glows; the stripe is its echo.
The skull stands a cube above the neck; the back rises again to the seat and the belly hangs deepest just behind it.
The rider sits on the fourth slice, where the back is highest, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Dakosaurus", "ZONE 3 / KELP FOREST", "LEGENDARY"
U = 0.45
PALETTE = {"hide": "#2E7350", "belly": "#EADFB8", "tooth": "#FFFFFF", "mouth": "#6A2630", "gum": "#9A4F58", "black": "#22262B",
           "stripe": "#F2A23A", "soft": "#F6D27A"}
SEAT = (0, 6, 6.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
FRAME, ORTHO = 2.8, 38.0

# the body: each slice is (from, to, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((-14, -10, 5, -4, 5), (-10, -6, 5, -5, 5), (-6, -2, 5, -5, 6), (-2, 2, 6, -5, 6), (2, 6, 6, -6, 6), (6, 10, 6, -5, 6),
          (10, 14, 6, -5, 5), (14, 17, 5, -5, 5), (17, 20, 5, -4, 5), (20, 23, 4, -4, 5), (23, 26, 4, -4, 4), (26, 29, 3, -4, 4),
          (29, 32, 3, -3, 4), (32, 34, 3, -3, 3))
SKULL = (4, -4, 6)
EDGE = -1  # the pale belly comes up to here
STRIPE = (0.25, 0.75)  # the stripe's height on the flank
# the scutes on each slice: (where along it, half its length, its height). None on the fourth: the seat
SCUTES = (((1.0, 0.8, 0.9), (3.0, 0.8, 0.9)), ((1.0, 0.8, 0.9), (3.0, 0.8, 0.9)), ((1.0, 0.8, 0.9), (2.9, 0.8, 0.9)), (),
          ((1.1, 0.8, 0.9), (3.0, 0.8, 0.9)), ((1.0, 0.8, 0.9), (3.0, 0.8, 0.9)), ((1.0, 0.8, 0.9), (3.0, 0.8, 0.9)),
          ((1.5, 0.8, 0.85),), ((1.5, 0.75, 0.8),), ((1.5, 0.75, 0.75),), ((1.5, 0.7, 0.7),), ((1.5, 0.65, 0.65),), ((1.5, 0.6, 0.6),),
          ((1.0, 0.5, 0.5),))
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail", "Fluke"]
AMPLITUDES = [1, 2, 2, 2, 3, 3, 4, 4, 5, 6, 7, 8, 9, 10, 12, 15]


def pose(parts, phase):
    """a crocodile's swim: the wave runs side to side down the chain and grows toward the tail, so the seat stays calm.
    The jaw opens and shuts once a beat; the paddles row a little, the back pair half a beat behind the front"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.45 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(11) * (0.5 + 0.5 * math.sin(phase))
    for name, side, lag in (("PaddleFR", 1, 0.0), ("PaddleFL", -1, 0.0), ("PaddleBR", 1, math.pi), ("PaddleBL", -1, math.pi)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase + lag)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase + lag - 1.0)


def steps_for(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, green hide (lighter on the top row, darker on the shoulder step), a pale belly,
    and the amber stripe: a thin raised strip on each side, a hair short of the slice's ends"""
    steps = steps_for(n)
    p.hull(x0, x1, n, bot, top, "hide", steps, steps)
    if len(steps) > 1:
        p.paint_sym(x0, x1, n, top - 2, top - 1, "hide-")
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    p.paint_sym(x0, x1, n, bot, EDGE, "belly")
    p.paint_sym(x0, x1, n, bot, bot + len(steps), "belly-")
    strip(p, x0, x1, n)


def strip(p, x0, x1, n):
    line = (n + 0.45, n + 0.7, STRIPE[0], STRIPE[1])
    p.block(x0 + 0.12, line, x1 - 0.12, line, "stripe", mirror=True)


def build(m):
    head = m.part("Head", (-14, 0, 0))
    # the back of the skull: a tall narrow box that stands a cube above the neck, pale below the jaw line; its bottom
    # row is wider at the front, so the jaw's root is buried. The stripe starts here, under the eye
    n, bot, top = SKULL
    head.hull(-19, -14, n, bot, top, "hide", [(2, 1)], [(2, 1)])
    head.paint_sym(-19, -14, n, top - 1, top, "hide+")
    head.paint_sym(-19, -14, n, bot, EDGE, "belly")
    head.paint_sym(-19, -14, n, bot, bot + 1, "belly-")
    strip(head, -19, -14, n)
    head.sym(-19, -17, 3, -4, -3, "belly-")
    # the snout: three deep blocks in a chain, each tilted nose-down, lower and narrower than the last, ending blunt. Each
    # has a pale lip plate underneath with a thin dark gum line; the first two have a lighter plate on top, which starts
    # past the end of the block before
    blocks = ((-18.5, -22.7, 2.65, 2.25, 8.4, 4.4, 4.6, -18.5, -18.5), (-22.1, -26.3, 2.2, 1.8, 6.6, 3.6, 3.4, -22.9, -23.0),
              (-25.7, -29.2, 1.8, 1.45, 4.8, 2.9, 0.0, 0.0, -26.6))

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
    for x0, x1, half, low, high in ((-22.0, -18.6, 2.0, -2.4, -0.2), (-25.6, -22.0, 1.4, -2.6, -0.25), (-28.0, -25.6, 0.6, -2.7, -0.3)):
        head.block(x0, (-half, half, low, high), x1, (-half, half, low, high), "mouth")
    # the upper teeth: few and big, blades long along the jaw and thin across it, each with its base sunk into the gum
    for k, x in ((0, -19.6), (0, -20.7), (0, -21.8), (1, -23.5), (1, -24.5), (1, -25.5), (2, -27.15), (2, -28.25)):
        size, length, long = ((0.75, 1.5, 1.0), (0.75, 1.5, 0.95), (0.65, 1.25, 0.85))[k]
        head.tooth(x, (3.3, 2.4, 1.5)[k], lip_bottom(k, x) - 0.05, size, length, "tooth", long=long)
    # the eye: a dark socket on the skull's side, a thin halo of soft light, a dark pupil standing out of it. The brow
    # sits on the eye: a slanting bar that covers the top of the eye's square (more at the front, so it scowls), stands a
    # little proud of the pupil, and runs on past the eye along the side of the snout
    ring = (4.4, 4.95, 2.1, 4.4)
    head.block(-18.3, ring, -16.0, ring, "hide-", mirror=True)
    halo = (4.85, 5.1, 2.4, 4.1)
    head.block(-18.0, halo, -16.3, halo, "soft", mirror=True)
    pupil = (5.0, 5.3, 2.7, 3.8)
    head.block(-17.7, pupil, -16.6, pupil, "black", mirror=True)
    head.beam((-20.6, 4.775, 3.65), (-15.2, 4.775, 4.7), 1.3, 1.35, "hide", mirror=True)
    nostril = (2.1, 2.55, 2.0, 2.4)
    head.block(-28.7, nostril, -28.1, nostril, "black", mirror=True)

    # the lower jaw, on its own joint: three boxes in a chain like the snout, a little shorter than it (an overbite), with
    # its own gum line and blade teeth, and a darker chin plate
    jaw = m.part("Jaw", (-18.2, 0, -2.3), "Head")
    jaws = ((-18.4, -22.8, -2.8, -2.9, 6.4, 2.0, -19.2), (-22.2, -26.4, -2.85, -2.8, 5.2, 1.5, -23.1),
            (-25.8, -28.6, -2.75, -2.65, 3.6, 1.0, -26.7))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    jaw.beam((-19.6, 0, -3.95), (-22.4, 0, -4.01), 4.4, 0.4, "belly-", flat="z")
    for k, x in ((0, -20.15), (0, -21.25), (1, -24.0), (1, -25.0), (2, -27.7)):
        jaw.tooth(x, (2.5, 1.9, 1.1)[k], jaw_top(k, x) + 0.05, 0.65, -0.95 if k < 2 else -0.8, "tooth", long=(0.9, 0.8, 0.75)[k])

    # the body: fourteen slices, each on its own joint
    segs = [m.part(f"S{i + 1}", (sl[0], 0, 0), "Head" if i == 0 else f"S{i}") for i, sl in enumerate(SLICES)]
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, SLICES)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body. It is sized from the smaller of the two pieces
        # and stays clear of their steps, so none of its faces lies in the plane of a face that shows
        fn, fbot, ftop = SLICES[i - 1][2:5] if i else SKULL
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + 2, min(top, ftop) - 2, "hide-")
        # the scutes: low dark keels on the spine, leaning back, smaller toward the tail
        for at, half, tall in SCUTES[i]:
            mid, wide, low = x0 + at, 0.7 if n >= 4 else 0.55, top - 0.15
            seg.spike([(mid - half, -wide, low), (mid + half, -wide, low), (mid + half, wide, low), (mid - half, wide, low)],
                      (mid + 0.5 * half, 0.0, top + tall), "hide-")
    # the seat: a shallow slot either side for the rider's legs, above the stripe
    segs[3].dent(-1, 1, 6, 1, 4, "hide-")

    def paddle(name, side, parent, root, boxes):
        """a paddle limb on its own joint (side: 1 right, -1 left): two boxes lying flat, the second smaller, thinner and
        swept further back, starting inside the first. Each is (from, to, width, thickness, colour)"""
        part = m.part(name, (root[0], root[1] * side, root[2]), parent)
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in boxes:
            part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")

    for name, side in (("PaddleFR", 1), ("PaddleFL", -1)):
        paddle(name, side, "S2", (-8.4, 4.8, -2.4),
               (((-8.4, 4.0, -2.3), (-5.4, 8.6, -3.6), 3.8, 1.2, "hide"), ((-6.2, 7.4, -3.3), (-3.0, 11.4, -4.4), 2.9, 0.8, "hide-")))
    for name, side in (("PaddleBR", 1), ("PaddleBL", -1)):
        paddle(name, side, "S9", (18.5, 4.8, -1.5),
               (((18.5, 4.0, -1.4), (21.5, 8.4, -2.6), 4.2, 1.1, "hide"), ((20.7, 7.3, -2.3), (24.3, 11.2, -3.35), 3.2, 0.7, "hide-")))

    # the tail runs on from the last slice: a stock taller than it is wide, then a box that bends down. The stripe runs
    # along both, as thin raised strips, and ends at the fluke
    tail = m.part("Tail", (34, 0, 0), "S14")
    tail.beam((33.6, 0, 0.2), (37.6, 0, -0.2), 4.4, 4.0, "hide")
    tail.beam((36.8, 0, -0.1), (41.4, 0, -2.6), 4.0, 2.6, "hide")
    tail.beam((33.8, 2.0, 0.48), (37.4, 2.0, 0.12), 0.5, 0.3, "stripe", mirror=True)
    tail.beam((37.38, 1.3, -0.08), (40.98, 1.3, -2.04), 0.5, 0.3, "stripe", mirror=True)
    # the fluke, on a joint of its own: the long lower lobe that carries the tail's line on down (two boxes), and a
    # shorter fin standing up from the bend (two boxes): a shark's tail upside down, as the real animal's was. Both
    # roots are buried in the tail's bent box
    fluke = m.part("Fluke", (40.2, 0, -2.0), "Tail")
    fluke.beam((40.4, 0, -2.0), (44.6, 0, -6.0), 3.4, 1.5, "hide")
    fluke.beam((43.7, 0, -5.1), (45.9, 0, -8.0), 2.3, 0.9, "hide-")
    fluke.beam((39.4, 0, -1.1), (42.6, 0, 4.3), 4.4, 1.1, "hide")
    fluke.beam((41.9, 0, 3.1), (44.0, 0, 7.0), 2.9, 0.6, "hide-")
