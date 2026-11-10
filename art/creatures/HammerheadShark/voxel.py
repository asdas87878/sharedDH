"""The Hammerhead Shark (zone 4's Rare) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its one idea is the head: a wide flat hammer, far wider than the body, with an eye at each end. Nothing else is added.
- The hammer is one flat slab of cubes, two thick: a wide plateau in the middle and one step back to each wing, so its
  front edge reads as an arc. Olive on top, pale underneath. Each end face carries an eye: a pale ring and a dark pupil.
- The head joins it the way a snout is made: a big block tilted nose-down out of the head slab, then a smaller lighter
  plate on top that runs down onto the hammer. The mouth is small and set back under it, behind the hammer.
- The body is slices, each on its own joint, each one cube different from the last in width, back or belly.
- A tall first dorsal in three boxes, a long upper tail lobe in three, side fins in three, all starting inside the last.
The rider sits in front of the dorsal, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Hammerhead Shark", "ZONE 4 / SHIPWRECKS", "RARE"
U = 0.4
PALETTE = {"back": "#7D8468", "belly": "#ECE7D6", "black": "#1F2225", "mouth": "#6E2A30", "tooth": "#FFFFFF"}
SEAT = (-6, 4, 4.6)
FRAME, ORTHO = 2.15, 31.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "Tail"], "amplitudes": [2, 3, 4, 6, 8, 10, 13, 18],
        "phaseStep": 0.6, "headCounter": 3}

# the body behind the head: (part, from, to, cubes out, bottom, top). One number changes from slice to slice
SLICES = (("S1", -14, -9, 4, -3, 3), ("S2", -9, -3, 4, -3, 4), ("S3", -3, 2, 4, -3, 4), ("S4", 2, 6, 3, -3, 4),
          ("S5", 6, 10, 3, -3, 3), ("S6", 10, 13, 2, -3, 3), ("S6", 13, 15, 2, -2, 3), ("S7", 15, 17, 2, -2, 2),
          ("S7", 17, 19, 1, -2, 2))
HEAD = (-18, -14, 3, -3, 3)


def steps(n):
    """the corner steps: two where the body is widest, one where it is slimmer, none on the tail stock"""
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, a lighter top row, a pale belly two rows deep"""
    p.hull(x0, x1, n, bot, top, "back", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "back+")
    p.paint_sym(x0, x1, n, bot, bot + 2, "belly")
    if steps(n):
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def build(m):
    head = m.part("Head", (-14, 0, 0))
    slab(head, *HEAD)
    # the hammer: a flat slab, a wide plateau and one step back to each wing. Olive on top, pale underneath
    head.sym(-24, -20, 5, -2, 0, "back")
    head.pair(-23, -20, 6, 10, -2, 0, "back")
    head.paint_sym(-24, -20, 9, -2, -1, "belly")
    # an eye on each end of the hammer: a pale ring, a dark pupil standing out of it
    ring = (9.2, 9.7, -1.75, -0.25)
    head.block(-22.4, ring, -20.6, ring, "belly", mirror=True)
    pupil = (9.4, 9.95, -1.5, -0.5)
    head.block(-22.1, pupil, -20.9, pupil, "black", mirror=True)

    # the neck: a big block tilted nose-down out of the head slab and into the hammer, a pale lip plate under it, and a
    # smaller lighter plate on top that starts inside it and runs down onto the hammer
    def mid(x):
        return 0.45 + (x + 17.2) * 0.9 / 4.3

    head.beam((-17.2, 0, mid(-17.2)), (-21.5, 0, mid(-21.5)), 6.2, 2.6, "back", flat="z")
    head.beam((-17.2, 0, mid(-17.2) - 1.35), (-20.25, 0, mid(-20.25) - 1.35), 5.8, 0.8, "belly", flat="z")
    head.beam((-19.3, 0, 0.75), (-23.0, 0, -0.1), 4.4, 0.7, "back+", flat="z")

    def lip_bottom(x):
        return mid(x) - 1.759

    # the mouth: small, set back under the neck, behind the hammer. A dark inside that ends in the head and in the jaw,
    # a pale lower jaw hanging a little open, two teeth a side
    head.block(-19.95, (-2.1, 2.1, -3.05, -1.2), -17.5, (-2.1, 2.1, -2.5, -1.2), "mouth")
    head.beam((-17.0, 0, -2.6), (-19.6, 0, -3.2), 4.6, 0.6, "belly", flat="z")
    for x in (-19.4, -18.6):
        head.tooth(x, 2.45, lip_bottom(x) + 0.1, 0.5, 0.6, "tooth")

    # the body: slices on their own joints, each with a sleeve into the piece in front
    parts, before = {}, HEAD
    for name, x0, x1, n, bot, top in SLICES:
        if name not in parts:
            parent = "Head" if not parts else list(parts)[-1]
            parts[name] = m.part(name, (x0, 0, 0), parent)
            fn, fbot, ftop = before[2:]
            deep = max(len(steps(n)), len(steps(fn)))
            parts[name].sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + deep, min(top, ftop) - deep, "back-")
        slab(parts[name], x0, x1, n, bot, top)
        before = (x0, x1, n, bot, top)
    for x in (-13, -11):  # gill slits: shallow lines in the side
        parts["S1"].dent(x, x + 1, 4, -1, 1, "back-")
    parts["S2"].dent(-7, -5, 4, 0, 2, "back-")  # the rider's leg slots

    # the fins: each a few boxes at an angle, every box smaller and thinner than the last and starting inside it
    s3 = parts["S3"]  # the first dorsal: tall, swept back
    s3.beam((-1.3, 0, 2.6), (2.0, 0, 7.65), 4.0, 1.3, "back")
    s3.beam((1.4, 0, 6.8), (3.4, 0, 10.4), 2.9, 1.0, "back")
    s3.beam((2.9, 0, 9.5), (4.1, 0, 12.3), 2.0, 0.7, "back-")
    s1 = parts["S1"]  # the side fins
    s1.beam((-12.5, 2.2, -1.5), (-9.1, 6.6, -2.3), 3.6, 1.0, "back", flat="z", mirror=True)
    s1.beam((-9.7, 5.8, -2.15), (-7.5, 8.8, -2.75), 2.6, 0.7, "back", flat="z", mirror=True)
    s1.beam((-8.0, 8.0, -2.6), (-6.4, 10.3, -3.0), 1.9, 0.4, "back-", flat="z", mirror=True)
    parts["S6"].beam((11.0, 0, 2.3), (12.8, 0, 4.6), 1.6, 0.8, "back")  # the small second dorsal
    parts["S5"].beam((7.0, 1.4, -1.9), (9.0, 3.2, -3.9), 1.8, 0.6, "belly-", flat="z", mirror=True)  # the belly fins

    # the tail, on its own joint: a root block, a long upper lobe in three boxes and a short lower one
    tail = m.part("Tail", (19, 0, 0), "S7")
    tail.beam((18.6, 0, 0.0), (20.8, 0, 0.0), 2.6, 1.4, "back")
    tail.beam((19.8, 0, 0.5), (22.9, 0, 4.9), 3.4, 1.1, "back")
    tail.beam((22.2, 0, 4.0), (24.9, 0, 8.2), 2.6, 0.8, "back")
    tail.beam((24.3, 0, 7.3), (25.4, 0, 10.3), 2.0, 0.5, "back-")
    tail.beam((19.8, 0, -0.4), (22.0, 0, -3.6), 2.8, 0.8, "back")
    tail.beam((21.4, 0, -2.9), (23.0, 0, -5.4), 2.0, 0.5, "back-")
