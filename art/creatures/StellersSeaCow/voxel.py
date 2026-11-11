"""Steller's Sea Cow (zone 3's Epic: the extinct giant sea cow of the kelp forests) for tools/blender/voxel_kit.py
(docs/style/creature-brief.md). Designed from the real animal.
Its idea: a gentle giant in an old tree's bark. A very long, fat barrel of a body, a head far too small for it, and
rough skin drawn as thin dark wrinkle lines that run unbroken from the neck to the tail.
- The body is fourteen slices, each one cube bigger or smaller than the last, so it swells behind the small head like
  rolls of fat and thins in a long cone to the tail. The corners are two broad steps where it is thick.
- Three lines tie the slices together on each side (two wrinkles and the pale belly's edge) and two more run down the
  back. They keep their height, so they climb the corner steps as the body thins and meet at the tail.
- The head: a small skull, a blunt muzzle of two blocks turned nose-down, a pale pad at its end with dark bristles,
  a chin under it, nostrils on top, a tiny eye in a cream ring.
- Stubby front flippers with a dark hoof-like tip, each on its own joint. A whale's flat fluke on a joint of its own.
It swims slowly by bending up and down. The rider sits on the broad back behind the shoulders."""
import math

NAME, ZONE, RARITY = "Steller's Sea Cow", "ZONE 3 / KELP FOREST", "EPIC"
U = 0.45
PALETTE = {"hide": "#877B6E", "belly": "#CBBFA9", "bark": "#584E46", "black": "#22262B", "bristle": "#F0E8D2"}
SEAT = (-4, 10, 5.5)
FRAME, ORTHO = 2.6, 36.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]

# the body: each slice is (length, cubes out, bottom, top). Each is one cube bigger or smaller than the last
SLICES = ((3, 6, -6, 6), (3, 7, -7, 7), (4, 8, -8, 8), (5, 9, -9, 9), (9, 9, -9, 10), (5, 8, -8, 9), (4, 7, -7, 8), (4, 6, -6, 7),
          (3, 5, -5, 6), (3, 4, -4, 5), (3, 3, -3, 4))
BODY_FROM = -23
SKULL = (4, -4, 4)
WRINKLES = (2, -2)  # the heights of the wrinkle lines on the sides; one more runs down the middle of the back
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail", "Fluke"]
AMPLITUDES = [0.8, 1, 1, 1.2, 1.5, 2.5, 3, 3.5, 4.5, 5.5, 6.5, 7, 10]


def pose(parts, phase):
    """a slow whale's swim: a small wave runs down the body up and down and grows to the fluke; the flippers row"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.4 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.8)


def steps_of(n):
    """the corners of a slice: two broad steps where the body is thick, one where it is thin"""
    if n >= 8:
        return [(4, 2), (2, 2)]
    if n == 7:
        return [(3, 2), (1, 1)]
    if n == 6:
        return [(3, 1), (1, 1)]
    return [(2, 2)] if n == 5 else ([(2, 1)] if n == 4 else [(1, 1)])


def tall(steps):
    return sum(t for _, t in steps)


def half(n, bot, top, z):
    """the outermost column of a slice in row z"""
    zz = top
    for inset, t in steps_of(n):
        if zz - t <= z < zz:
            return n - inset
        zz -= t
    zz = bot
    for inset, t in steps_of(n):
        if zz <= z < zz + t:
            return n - inset
        zz += t
    return n


def slab(p, x0, x1, n, bot, top, wrinkles=True):
    """a slice of body: stepped corners, a lighter back (the top step), a pale belly (the bottom steps, so its edge
    follows the belly's curve), and the wrinkle lines: one row of bark at two fixed heights on the sides and one column
    down the middle of the back"""
    steps = steps_of(n)
    p.hull(x0, x1, n, bot, top, "hide", steps, steps)
    p.paint_sym(x0, x1, n, top - steps[0][1], top, "hide+")
    p.paint_sym(x0, x1, n, bot, bot + tall(steps), "belly")
    if len(steps) > 1:
        p.paint_sym(x0, x1, n, bot, bot + steps[0][1], "belly-")
    if not wrinkles:
        return
    for z in WRINKLES:
        p.paint_sym(x0, x1, n, z, z + 1, "bark")
    p.paint_sym(x0, x1, 0, top - steps[0][1], top, "bark")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: a small box with stepped corners, pale under the jaw line
    slab(head, -28, BODY_FROM, *SKULL, wrinkles=False)
    # the muzzle: two big blocks in a chain, each turned nose-down, lower and narrower than the last, then a pale pad
    # round the blunt end, a little wider than the block it sits on
    head.beam((-26.5, 0, 0.0), (-30.2, 0, -1.2), 6.6, 5.6, "hide", flat="z")
    head.beam((-29.2, 0, -1.2), (-32, 0, -2.6), 5.6, 4.6, "hide", flat="z")
    head.beam((-31.3, 0, -2.25), (-32.5, 0, -2.85), 6.2, 5.2, "belly", flat="z")
    # the chin: a pale box under the skull that the muzzle overhangs
    head.beam((-24.5, 0, -3.0), (-29.6, 0, -4.3), 4.2, 1.6, "belly", flat="z")
    # the bristles: short dark stubs standing out of the pale pad, in two rows (dark, so they don't read as teeth)
    dx, dz = -2.8 / math.hypot(2.8, 1.4), -1.4 / math.hypot(2.8, 1.4)  # the muzzle's direction; (-dz, dx) is across it
    for v, ys in ((1.2, (0.7, 2.1)), (-0.2, (1.4,)), (-1.5, (0.7, 2.1))):
        for y in ys:
            cx, cz = -32.5 - dx * 0.35 - dz * v, -2.85 - dz * 0.35 + dx * v  # 0.35 inside the pad's end
            base = [(cx + dz * 0.2, y - 0.2, cz - dx * 0.2), (cx + dz * 0.2, y + 0.2, cz - dx * 0.2),
                    (cx - dz * 0.2, y + 0.2, cz + dx * 0.2), (cx - dz * 0.2, y - 0.2, cz + dx * 0.2)]
            head.spike(base, (cx + dx * 1.15, y, cz + dz * 1.15), "bark", mirror=True)
    # the nostrils, on top of the muzzle
    nostril = (0.7, 1.5, 0.2, 1.0)
    head.block(-31.2, nostril, -30.4, nostril, "bark", mirror=True)
    # the eye: tiny, a dark pupil in a cream ring (a gentle animal: no brow)
    ring = (4.3, 4.75, 0.15, 1.85)
    head.block(-27.2, ring, -25.4, ring, "bristle", mirror=True)
    pupil = (4.4, 5.0, 0.5, 1.5)
    head.block(-26.8, pupil, -25.8, pupil, "black", mirror=True)

    # the body: eleven slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept inside the rows where both are full width
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        clear = max(tall(steps_of(n)), tall(steps_of(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "hide-")

    # the front flippers, each on its own joint: a stubby arm out and down from the shoulder, a smaller paddle turned
    # back from it, and a dark hoof-like tip
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (-15.0, 6.5 * side, -5.5), "S3")
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in (((-15.0, 4.5, -4.8), (-13.6, 8.6, -7.8), 3.8, 1.8, "hide"),
                                                                ((-14.1, 7.8, -7.2), (-12.4, 9.8, -9.4), 3.2, 1.2, "hide"),
                                                                ((-12.9, 9.3, -8.9), (-12.1, 10.2, -9.9), 2.6, 0.7, "bark")):
            part.beam((ax, ay * side, az), (bx, by * side, bz), wide, thick, colour, flat="z")

    # the tail: a short stock, then a whale's flat fluke on a joint of its own: a hub and two lobes swept back, each
    # ending in a darker tip
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(SLICES)}")
    tail.beam((end - 0.4, 0, 0.5), (end + 2.6, 0, 0.5), 4.4, 3.2, "hide", flat="z")
    fluke = m.part("Fluke", (end + 2, 0, 0.5), "Tail")
    fluke.beam((end + 1.5, 0, 0.5), (end + 5.7, 0, 0.5), 8.5, 1.9, "hide", flat="z")
    fluke.beam((end + 3.6, 2.6, 0.5), (end + 6.0, 8.6, 0.5), 4.4, 1.2, "hide", flat="z", mirror=True)
    fluke.beam((end + 5.5, 7.4, 0.5), (end + 6.7, 10.2, 0.5), 3.0, 0.6, "hide-", flat="z", mirror=True)
