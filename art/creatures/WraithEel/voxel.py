"""The Wraith Eel (zone 9's Legendary: the ghost of an eel) for tools/blender/voxel_kit.py (docs/style/creature-brief.md).
Its idea: a skull on a ribbon. A gaunt bone head with two big hollow sockets, a small halo of cold light deep in each, and
one thin line of the same light that leaves the back of each socket and runs down the whole body, while the bone-white
body fades to cold teal toward the tail.
- The head is its own shape: a deep, wide cranium (deeper and wider than the neck behind it, as a skull sits on a spine),
  a snout of three tilted blocks, each lower and narrower than the last, a bare row of teeth with a thin dark gum line set
  inside the jaw's edge, and a lower jaw on its own joint. The brow is a slanting box that sits on the socket and comes
  past it in front.
- The body is sixteen slices, each on its own joint. From slice to slice one number changes by one cube: the back rises
  to the seat and sinks again, the belly dips under the seat, the width tapers to a ribbon.
- A ragged low fin: two leaning shards on each slice behind the seat, big then small, never the same twice running; two
  small ones on the neck; none where the rider sits. Under the tail a few more, and a torn pennant for a tail.
The rider sits on the highest, widest slice, legs in a shallow slot either side. It swims as an eel does: side to side."""
import math

NAME, ZONE, RARITY = "Wraith Eel", "ZONE 9 / BONE GRAVEYARD", "LEGENDARY"
U = 0.45
PALETTE = {"bone": "#E9E4D2", "mist": "#C6DBD0", "haze": "#98C7C2", "teal": "#5CA4A8", "glow": "#7FF3E4", "socket": "#232F3D",
           "black": "#14181C", "mouth": "#2B3E4A", "gum": "#587880", "tooth": "#FFFFFF"}
SEAT = (12.5, 6, 3.5)
GLOW = {"glow": 0.5}  # the halo in each socket and the line that runs from it down the flank
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["bone", "mist", "haze", "teal"]}]
FRAME, ORTHO, ORTHO_SWIM = 2.7, 44.0, 48.0

# the body: each slice is (length, cubes out, bottom, top, colour). One number changes from slice to slice, never two
SLICES = ((3, 2, -3, 4, "bone"), (3, 3, -3, 4, "bone"), (4, 3, -3, 5, "bone"), (4, 3, -4, 5, "bone"), (5, 3, -4, 6, "bone"),
          (4, 3, -5, 6, "bone"), (4, 3, -4, 6, "mist"), (4, 3, -4, 5, "mist"), (4, 3, -3, 5, "mist"), (3, 2, -3, 5, "haze"),
          (3, 2, -3, 4, "haze"), (3, 2, -2, 4, "haze"), (3, 2, -2, 3, "haze"), (3, 1, -2, 3, "teal"), (3, 1, -1, 3, "teal"),
          (2, 1, -1, 2, "teal"))
BODY_FROM = -4
SKULL = (3, -4, 4)
LINE = (0.35, 0.75)  # the height of the line of light on the flank
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [1, 1, 1, 2, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16]


def pose(parts, phase):
    """an eel's swim: one wave runs down the ribbon side to side, small in front of the rider and wide at the tail; the
    head turns a little against it, and the jaw hangs open and shuts once a beat"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.45 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))


def top_steps(n):
    return [(2, 1), (1, 1)] if n >= 3 else [(1, 1)]


def bottom_steps(n):
    return [(1, 1)]


def slab(p, x0, x1, n, bot, top, colour):
    """a slice of body: stepped corners, lighter on the top row, darker on the bottom row"""
    p.hull(x0, x1, n, bot, top, colour, top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, colour + "+")
    p.paint_sym(x0, x1, n, bot, bot + 1, colour + "-")


def line(p, x0, x1, n):
    """the thin line of light on each flank, 0.3 proud"""
    section = (n + 0.3, n + 0.8, LINE[0], LINE[1])
    p.block(x0, section, x1, section, "glow", mirror=True)


def shard(p, x, z, length, wide, thick, colour, down=False):
    """one leaning shard of the ragged fin: a box that starts a cube inside the body and leans back"""
    s = -1 if down else 1
    p.beam((x, 0, z - s * 1.0), (x + length * 0.82, 0, z - s * 1.0 + s * length * 0.57), wide, thick, colour)


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the cranium: a deep, wide box with stepped corners. The snout and the jaw start inside its front
    head.hull(-12, BODY_FROM, 3, -4, 4, "bone", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-12, BODY_FROM, 3, 3, 4, "bone+")
    head.paint_sym(-12, BODY_FROM, 3, -4, -3, "bone-")
    # the snout: three blocks in a chain, each tilted nose-down, lower and narrower than the last, each with a lip plate
    # underneath and a thin dark gum line set inside the lip's edge
    blocks = ((-11.5, -15.2, 1.2, 0.9, 6.0, 3.0, -11.5), (-14.6, -18.2, 0.75, 0.45, 4.2, 2.3, -15.4), (-17.6, -19.4, 0.3, 0.15, 2.8, 1.6, -18.4))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.7

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "bone", flat="z")
        lip = thick / 2 + 0.35
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.7, "bone-", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                  flat="z")
    # the nose holes of a skull: two small dark blocks on the last block
    nostril = (0.35, 0.95, 0.75, 1.2)
    head.block(-19.0, nostril, -18.3, nostril, "socket", mirror=True)
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    head.block(-14.5, (-1.7, 1.7, -3.0, -0.8), -11.8, (-1.7, 1.7, -3.0, -0.8), "mouth")
    head.block(-17.4, (-1.0, 1.0, -3.05, -0.95), -14.6, (-1.0, 1.0, -3.05, -0.95), "mouth")
    # the upper teeth: a bare row down each side, bases sunk in the gum, two longer ones at the front
    for k, x in ((0, -12.6), (0, -13.7), (0, -14.8), (1, -15.9), (1, -16.7), (1, -17.5)):
        head.tooth(x, (2.1, 1.25)[k], lip_bottom(k, x) - 0.05, 0.6, 0.8, "tooth")
    head.tooth(-18.75, 0.55, lip_bottom(2, -18.75) - 0.05, 0.55, 1.15, "tooth")
    # the sockets: a big hollow in each side of the cranium, dark, with a small halo of light deep in it round a dark pupil
    head.dent(-11, -8, 3, -1, 2, "socket", depth=0.6)
    halo = (2.7, 3.1, -0.15, 1.25)
    head.block(-10.4, halo, -9.0, halo, "glow", mirror=True)
    pupil = (2.9, 3.25, 0.2, 0.9)
    head.block(-10.05, pupil, -9.35, pupil, "black", mirror=True)
    # the brow: a slanting box that sits on the socket, cuts across its top and comes past it in front
    head.beam((-12.5, 3.15, 1.5), (-7.4, 3.15, 2.3), 1.0, 1.7, "bone", mirror=True)
    # the line of light leaves the back of the socket
    section = (3.3, 3.8, LINE[0], LINE[1])
    head.block(-7.7, section, BODY_FROM - 0.2, section, "glow", mirror=True)

    # the lower jaw, on its own joint: two slim boxes in a chain, narrower than the snout, with its own gum line and teeth
    jaw = m.part("Jaw", (-11.2, 0, -3.0), "Head")
    jaws = ((-11.2, -15.0, -3.1, -3.2, 4.4, 1.0, -12.2), (-14.4, -18.0, -3.2, -3.1, 3.0, 0.8, -15.3))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "bone-", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    for k, x in ((0, -13.1), (0, -14.3), (1, -15.6), (1, -16.5), (1, -17.3)):
        jaw.tooth(x, (1.6, 0.9)[k], jaw_top(k, x) + 0.05, 0.5, -0.6, "tooth")

    # the body: sixteen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top, colour) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top, colour))
        x += length
    end = x
    last = len(SLICES) - 1
    for i, (seg, (x0, x1, n, bot, top, colour)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top, colour)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)))
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + 1, min(top, ftop) - up, colour + "-")
        # the line of light: each length starts and ends a little behind its slice, so the lengths meet end to end
        line(seg, x0 + 0.2, x1 + (0.2 if i < last else -0.2), n)
        # the ragged fin: two leaning shards on each slice behind the seat, big then small, their sizes never the same
        # twice running; two small ones on the neck; none from there to behind the rider
        if 6 <= i < last:  # (the last slice carries the tail)
            big = (3.4, 2.7, 3.1)[i % 3] if x1 - x0 >= 4 else (2.3, 1.9, 2.1)[i % 3]  # each stays over its own slice
            small_one = (1.8, 2.3)[i % 2] if x1 - x0 >= 4 else (1.3, 1.6)[i % 2]
            if abs(((x1 - x0) * 0.58 - 0.7) * 0.82 + small_one - big) < 0.2:  # the two never end in one plane
                small_one -= 0.4
            shard(seg, x0 + 0.7, top, big, 1.9 if n >= 2 else 1.6, 0.7, "teal")
            shard(seg, x0 + (x1 - x0) * 0.58, top, small_one, 1.3, 0.4, "teal-")
        elif i < 3:
            shard(seg, x0 + 0.8, top, (2.0, 2.4, 2.8)[i], 1.5, 0.7, "teal")
        if i >= 11:  # and under the tail, where an eel's fin runs round
            shard(seg, x0 + 0.8, bot, (2.5, 2.0)[i % 2], 1.3, 0.4, "teal-", down=True)
    # the seat: the highest, widest slice, a shallow slot either side for the rider's legs
    segs[4].dent(11, 14, 3, 1, 4, "bone-")

    # the tail, on its own joint: a torn pennant of three boxes, each smaller and thinner than the last
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(SLICES)}")
    tail.beam((end - 0.5, 0, 0.5), (end + 2.0, 0, 0.5), 1.6, 0.7, "teal")
    tail.beam((end + 1.0, 0, 0.6), (end + 4.4, 0, 1.7), 1.9, 0.4, "teal")
    tail.beam((end + 3.6, 0, 1.4), (end + 6.0, 0, 2.5), 1.2, 0.15, "teal-")
