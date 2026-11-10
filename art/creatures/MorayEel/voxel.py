"""The Moray Eel (zone 2's Rare: a green moray) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a long green ribbon that swims like a snake behind a heavy, scowling head whose mouth never quite shuts.
- The body is eleven short slices, each on its own joint, bending side to side. From one slice to the next one thing
  changes by one cube. It is taller than it is wide, like the real animal, and ends in a thin dark tail blade.
- One low fin ridge runs the whole back as a thin darker stripe (very low under the rider), and a second runs under the
  back half, so the tail reads as a ribbon.
- The one pattern: paler mottled spots on the flanks and shoulders.
- The head is wider than the neck. A sloping forehead, a snout of two blocks, a pale lip with a thin dark gum line set
  inside its edge, small pointed teeth and a longer pair in front. The lower jaw is its own part, drawn open; it gulps.
- The eye is a small dark block under a darker brow that slants down and comes past it in front.
The rider sits just behind the head, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Moray Eel", "ZONE 2 / CORAL REEF", "RARE"
U = 0.4
PALETTE = {"green": "#6A9A3E", "belly": "#C2CF78", "fin": "#3A6238", "spot": "#B5D56A", "mouth": "#7A2E33", "gum": "#8C3F4A",
           "tooth": "#FFFFFF", "black": "#22262B"}
SEAT = (-10, 4, 2.6)
FRAME, ORTHO, ORTHO_SWIM = 1.9, 26.0, 28.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["green"]}]

BODY_FROM = -16
SKULL = (3, -3, 4)
# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((4, 2, -3, 4), (4, 2, -3, 4), (4, 2, -3, 4), (4, 2, -3, 4), (4, 2, -3, 3), (4, 2, -2, 3), (3, 2, -2, 3), (3, 1, -2, 3),
          (3, 1, -2, 2), (3, 1, -1, 2), (3, 0, -1, 2))
SEAT_SLICE = 1
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [2, 3, 5, 7, 9, 11, 12, 13, 14, 15, 16, 18]
STEP = 0.6
# paler spots, per slice: (cubes from the slice's front, side, rows down from the shoulder, cubes long)
SPOTS = (((1, 1, 0, 2), (0, -1, 1, 1), (2, -1, 0, 1)),
         ((3, 1, 0, 1), (0, -1, 0, 2)),
         ((0, 1, 1, 2), (2, -1, 0, 1)),
         ((2, 1, 0, 1), (1, -1, 1, 2)),
         ((0, 1, 0, 2), (3, -1, 0, 1), (1, -1, 2, 1)),
         ((1, 1, 1, 2), (2, -1, 0, 1)),
         ((0, -1, 1, 1), (2, 1, 0, 1)),
         ((1, 1, 0, 1), (0, -1, 1, 1)),
         ((2, -1, 0, 1), (0, 1, 1, 1)),
         ((1, 1, 0, 1),),
         ())


def pose(parts, phase):
    """an eel's swim: one wave runs down the whole chain side to side, small at the neck and wide at the tail. The head
    turns a little against the body's mean, so the animal keeps its line. The jaw gulps once a beat"""
    run, total = 0.0, 0.0
    for k, name in enumerate(CHAIN):
        turn = math.radians(AMPLITUDES[k]) * math.sin(phase - STEP * (k + 1))
        parts[name].rotation_euler.z = turn
        run += turn
        total += run
    parts["Head"].rotation_euler.z = -0.7 * total / len(CHAIN)
    parts["Jaw"].rotation_euler.y = math.radians(4) * (0.5 + 0.5 * math.sin(phase))


def steps(n):
    return [(1, 1)] if n >= 1 else []


def slab(p, x0, x1, n, bot, top):
    """a slice of body: one corner step top and bottom, a lighter top row, a pale belly"""
    p.hull(x0, x1, n, bot, top, "green", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "green+")
    p.paint_sym(x0, x1, n, bot, bot + (2 if top - bot >= 5 else 1), "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: wider than the neck, pale under the jaw line. Its lower front is cut away: the corner of the mouth
    head.hull(-21, BODY_FROM, 3, -3, 4, "green", [(1, 1)], [(1, 1)])
    head.paint_sym(-21, BODY_FROM, 3, 3, 4, "green+")
    head.paint_sym(-21, BODY_FROM, 3, -3, -1, "belly")
    head.paint_sym(-21, BODY_FROM, 3, -3, -2, "belly-")
    head.carve(-21, -19, -4, 5, -3, -1)
    head.paint(-18, -16, 3, 4, 2, 3, "spot")
    head.paint(-19, -18, -3, -2, 2, 3, "spot")
    head.paint(-17, -16, -3, -2, 0, 1, "spot")
    # the forehead: one block sloping from the skull's top down onto the snout
    head.beam((-19.4, 0, 2.9), (-23.0, 0, 2.2), 4.4, 1.6, "green", flat="z")
    # the snout: two blocks in a chain, each tilted a little nose-down, lower and narrower than the last. Each has a
    # pale lip plate underneath and a thin dark gum line set inside the lip's edge
    blocks = ((-19.3, -24.0, 1.085, 0.85, 5.4, 3.4, -19.1), (-23.4, -27.0, 0.5, 0.3, 3.2, 2.1, -24.2))

    def lip_bottom(k, x):
        x0, x1, z0, z1, _, thick = blocks[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) - thick / 2 - 0.6

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "green", flat="z")
        lip = thick / 2 + 0.3
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.5, 0.6, "belly", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.1, 0.2, "gum",
                  flat="z")
    # the dark inside of the mouth: two blocks that stay behind the teeth, end inside the lips and reach down into the jaw
    head.block(-23.2, (-1.2, 1.2, -3.15, -1.0), -18.6, (-1.2, 1.2, -1.95, -1.0), "mouth")
    head.block(-25.0, (-0.4, 0.4, -3.5, -1.0), -23.2, (-0.4, 0.4, -3.15, -1.0), "mouth")
    # the upper teeth: small points down each side, bases sunk into the gum, and a longer pair in front
    for k, x in ((0, -20.4), (0, -21.3), (0, -22.2), (0, -23.1), (1, -24.7), (1, -25.6)):
        head.tooth(x, (1.8, 0.75)[k], lip_bottom(k, x) - 0.05, 0.55, 0.7, "tooth")
    head.tooth(-26.3, 0.5, lip_bottom(1, -26.3) - 0.05, 0.6, 0.9, "tooth")
    # the eye: a small dark block on the skull's side, low and well forward, over the mouth. The brow sits on it, slants
    # down to the front and comes past the eye there, so the eel scowls
    pupil = (3.2, 3.85, 0.4, 1.5)
    head.block(-20.8, pupil, -19.6, pupil, "black", mirror=True)
    head.beam((-18.4, 3.35, 2.05), (-22.0, 3.35, 1.3), 1.0, 1.4, "green-", mirror=True)

    # the lower jaw, on its own joint and drawn open: two boxes in a chain, a gum line and teeth of its own
    jaw = m.part("Jaw", (-18.5, 0, -1.7), "Head")
    jaws = ((-17.8, -22.6, -2.2, -3.25, 4.6, 1.4, -18.4), (-22.0, -26.3, -3.14, -4.0, 3.0, 1.0, -22.9))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        slope = (z1 - z0) / (x1 - x0)
        return z0 + slope * (x - x0) + thick / 2 * math.sqrt(1 + slope * slope)

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.35, 0, jaw_top(k, x1 + 0.35) + 0.05), wide - (0.6, 1.0)[k], 0.2, "gum",
                 flat="z")
    for k, x in ((0, -20.85), (0, -21.75), (1, -23.5), (1, -24.5)):
        jaw.tooth(x, (1.7, 0.72)[k], jaw_top(k, x) + 0.05, 0.5, -0.6, "tooth")
    jaw.beam((-19.4, 0, -3.42), (-24.4, 0, -4.28), 2.6, 0.6, "belly-", flat="z")  # a chin plate under it: the jaw has depth
    jaw.tooth(-25.55, 0.55, jaw_top(1, -25.55) + 0.05, 0.55, -0.75, "tooth")

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
        # kept a cube inside both pieces' corner steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        small = min(n, fn)
        if small >= 2:
            seg.sym(x0 - 1, x0, small - 1, max(bot, fbot) + 2, min(top, ftop) - 2, "green-")
        elif small == 1:
            seg.sym(x0 - 1, x0, 0, max(bot, fbot) + 1, min(top, ftop) - 1, "green-")
        # the fin ridge: one thin dark stripe along the whole back, standing on each slice (very low under the rider)
        # and rising behind him). Its foot is sunk into the slice in a shallow V, so its ends stand on the slice's edge
        tall, mid = (0.3 if i <= SEAT_SLICE else 0.8), (x0 + x1) / 2
        seg.prism([(x0, top), (mid, top - 0.15), (x1, top), (x1, top + tall), (x0, top + tall)], -0.3, 0.3, "fin")
        if i >= 6:  # and under the tail half
            seg.prism([(x0, bot), (mid, bot + 0.15), (x1, bot), (x1, bot - 0.7), (x0, bot - 0.7)], -0.3, 0.3, "fin")
        for dx, side, row, long in SPOTS[i]:
            seg.paint(x0 + dx, x0 + dx + long, side * n, side * n + 1, top - 2 - row, top - 1 - row, "spot")
    # the seat: behind the head, a shallow slot either side for the rider's legs
    segs[SEAT_SLICE].dent(-11, -9, 2, 0, 2, "green-")

    # the tail, on its own joint: a thin dark blade in two boxes, the second smaller and thinner: the fin wraps the tip
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(SLICES)}")
    tail.beam((end - 0.6, 0, 0.5), (end + 2.4, 0, 0.5), 2.6, 0.6, "fin")
    tail.beam((end + 1.6, 0, 0.5), (end + 4.2, 0, 0.5), 1.5, 0.3, "fin")
