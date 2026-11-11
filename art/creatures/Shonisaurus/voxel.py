"""Shonisaurus (zone 6's Legendary: a dolphin-shaped ichthyosaur the size of a whale) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. Designed from the real animal.
Its idea: a dolphin grown to the size of a whale, and one pale line that shows where its backbone goes: out of the huge
ringed eye, along the whole flank, and kinked DOWN into the long lower lobe of the tail.

It is a huge animal, and the build shows it: fine cubes, twenty-three slices, three-step corners where the body is thick.
- The body is a deep barrel. Each slice is one step bigger or smaller than the last (width, or back, or belly, never two),
  so the back, the belly and the plan outline each make their own broad staircase. The belly hangs a cube deeper than the
  back rises. The stiff chest is one piece; the joints get closer toward the tail, where it bends.
- The head has its own shape: a short deep skull that steps down once in front of the eye, a tilted forehead block, and a
  long narrow snout of three blocks in a chain, each a step lower and narrower. The lower jaw is three pale blocks that
  tilt the other way, so the snout closes to a point. No teeth: a calm giant with a dolphin's mouth line.
- The eye is very large (ichthyosaurs had the biggest eyes of any animal): a dark socket, a thin halo of soft light (the
  bony ring of the real eye), a dark pupil. The only glow on it.
- Four long narrow flippers, each three boxes swept back, on joints of their own. A low back fin behind the rider.
- The tail is a crescent whose lower lobe is the long one: the backbone kinks down into it, and the pale line follows.
The rider sits on the highest, widest part of the back, legs in a shallow slot either side, above the pale line."""
import math

NAME, ZONE, RARITY = "Shonisaurus", "ZONE 6 / TWILIGHT", "LEGENDARY"
U = 0.5
PALETTE = {"hide": "#3E5470", "belly": "#E6DFCB", "stripe": "#A8C8DA", "black": "#1E2229", "soft": "#C4F0F2"}
SEAT = (-2.5, 8, 7.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.2, 46.0, 50.0

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((2, 6, -6, 6), (2, 6, -7, 6), (2, 6, -7, 7), (2, 7, -7, 7), (2, 7, -8, 7), (2, 7, -8, 8), (5, 7, -9, 8), (2, 7, -8, 8),
          (2, 7, -8, 7), (2, 6, -8, 7), (2, 6, -7, 7), (2, 6, -7, 6), (2, 5, -7, 6), (2, 5, -6, 6), (2, 5, -6, 5), (2, 4, -6, 5),
          (2, 4, -5, 5), (2, 4, -5, 4), (2, 3, -5, 4), (2, 3, -4, 4), (2, 3, -4, 3), (2, 2, -4, 3), (2, 2, -3, 3))
# the pieces the slices are joined into: the chest is stiff, the joints come closer toward the tail
PIECES = (("Chest", 6), ("S2", 1), ("S3", 2), ("S4", 2), ("S5", 2), ("S6", 2), ("S7", 2), ("S8", 2), ("S9", 2), ("S10", 1), ("Tail", 1))
BODY_FROM = -17
SKULL = (5, -6, 6)
LINE = 0  # the row of the pale line, the whole length of the animal
CHAIN = ["Head"] + [name for name, _ in PIECES]
AMPLITUDES = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 7.5, 11.0]


def pose(parts, phase):
    """a fish's swim on a whale's body: a slow wave from side to side that grows toward the tail, the head turning a
    little against it; the four flippers row gently, the hind pair half a beat after the front"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    for name, side, late in (("FlipperFR", 1, 0.0), ("FlipperFL", -1, 0.0), ("FlipperHR", 1, 1.6), ("FlipperHL", -1, 1.6)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8 - late)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.8 - late)


def top_steps(n):
    """the corners of the back: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def belly_edge(bot):
    """how high the pale belly comes: it dips under the deep middle and rises to the tail, in one line"""
    return -5 if bot <= -8 else (-4 if bot == -7 else (-3 if bot <= -5 else -2))


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, slate hide (lighter on the top row), a pale belly, and the pale line"""
    p.hull(x0, x1, n, bot, top, "hide", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    p.paint_sym(x0, x1, n, bot, belly_edge(bot), "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    p.paint_pair(x0, x1, n, n + 1, LINE, LINE + 1, "stripe")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: short and deep, one step lower in front of the eye, so the brow line already starts down to the snout
    slab(head, -20, BODY_FROM, 5, -6, 6)
    slab(head, -24, -20, 5, -6, 5)
    # the snout: a forehead block and three long narrow blocks in a chain, each tilted nose-down, a step lower and narrower
    # than the last and starting inside it. The first three have a lighter plate on top, like the body's top row
    uppers = ((-21.5, -27.5, 1.6, 0.5, 7.4, 6.6, 4.4, -22.5), (-26.5, -32.5, 0.0, -0.8, 5.6, 5.0, 3.2, -28.4),
              (-31.3, -37.0, -1.2, -1.85, 3.8, 3.4, 2.0, -33.4), (-35.8, -39.8, -2.1, -2.5, 2.4, 2.2, 0.0, 0.0))
    for x0, x1, z0, z1, wide, thick, plate, plate_from in uppers:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "hide", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.175

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.45, "hide+", flat="z")
    # the lower jaw: four pale blocks that tilt nose-UP, each narrower than the block above it and closing against it, so
    # the mouth is one line under the overhanging upper lip and the snout comes to a point
    for x0, x1, z0, z1, wide, thick in ((-20.0, -27.5, -3.9, -3.6, 6.8, 3.4), (-26.5, -32.5, -3.8, -3.45, 5.0, 2.5),
                                        (-31.3, -37.0, -3.75, -3.45, 3.2, 1.7), (-35.8, -39.2, -3.65, -3.5, 1.8, 1.1)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
    nostril = (3.5, 3.9, 1.6, 2.2)  # the nostrils: on the side, just in front of the eye, as in the real animal
    head.block(-26.6, nostril, -25.8, nostril, "black", mirror=True)
    # the eye: very large. A dark socket on the skull's side, a thin halo of soft light, a dark pupil standing out of it
    socket = (5.38, 5.97, -2.6, 1.8)
    head.block(-23.6, socket, -19.2, socket, "hide-", mirror=True)
    halo = (5.85, 6.15, -2.2, 1.4)
    head.block(-23.2, halo, -19.6, halo, "soft", mirror=True)
    pupil = (5.97, 6.33, -1.8, 1.0)
    head.block(-22.8, pupil, -20.0, pupil, "black", mirror=True)

    # the body: twenty-three slices in eleven pieces, each piece on its own joint
    segs, spans, x, k = {}, [], BODY_FROM, 0
    for name, count in PIECES:
        seg = m.part(name, (x, 0, 0), CHAIN[CHAIN.index(name) - 1])
        segs[name] = seg
        first = True
        for length, n, bot, top in SLICES[k:k + count]:
            slab(seg, x, x + length, n, bot, top)
            if first:
                # a sleeve into the piece in front, so a bending joint shows body. It is sized from the smaller of the two
                # pieces and stays clear of both pieces' steps
                fn, fbot, ftop = spans[-1] if spans else SKULL
                up = max(len(top_steps(n)), len(top_steps(fn)))
                down = max(len(bottom_steps(n)), len(bottom_steps(fn)))
                seg.sym(x - 1, x, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "hide-")
                first = False
            spans.append((n, bot, top))
            x += length
        k += count
    # the seat: the highest, widest slice, a shallow slot either side for the rider's legs, above the pale line
    segs["S2"].dent(-4, -1, 7, 2, 5, "hide-")

    # the low back fin, behind the rider: two boxes leaning back, the second smaller, thinner and darker
    segs["S5"].beam((9.6, 0, 3.6), (13.2, 0, 6.4), 4.6, 1.4, "hide")
    segs["S5"].beam((12.4, 0, 6.0), (14.6, 0, 7.5), 2.6, 0.9, "hide-")

    # the four flippers: long and narrow, each on its own joint, three boxes swept out, down and back, each smaller and
    # thinner than the last and starting inside it
    front = (((-12.6, 3.2, -4.4), (-8.8, 9.0, -7.2), 3.8, 1.4, "hide"), ((-9.64, 7.72, -6.58), (-3.4, 12.8, -9.4), 3.1, 1.0, "hide"),
             ((-4.52, 11.89, -8.89), (0.0, 14.8, -10.6), 2.1, 0.55, "hide-"))
    hind = (((13.6, 2.6, -3.8), (16.6, 7.2, -6.0), 3.1, 1.2, "hide"), ((15.94, 6.19, -5.52), (20.8, 10.2, -7.7), 2.5, 0.85, "hide"),
            ((19.93, 9.48, -7.31), (23.4, 11.8, -8.7), 1.7, 0.45, "hide-"))
    for tag, boxes, parent, pivot in (("F", front, "Chest", (-11.8, 5.0, -5.0)), ("H", hind, "S6", (14.0, 4.2, -4.4))):
        for letter, side in (("R", 1), ("L", -1)):
            part = m.part(f"Flipper{tag}{letter}", (pivot[0], pivot[1] * side, pivot[2]), parent)
            for p0, p1, wide, thick, colour in boxes:
                part.beam((p0[0], p0[1] * side, p0[2]), (p1[0], p1[1] * side, p1[2]), wide, thick, colour, flat="z")

    # the tail, on the last slice's joint: a root block, a short upper lobe and a long lower one, three boxes in a line
    # that kinks down from the body as the backbone did. The pale line leaves the flank here and runs down the lower lobe
    tail = segs["Tail"]
    tail.beam((30.4, 0, 0.0), (33.6, 0, -0.6), 4.6, 2.0, "hide")
    tail.beam((32.0, 0, 0.4), (35.4, 0, 4.9), 3.0, 1.3, "hide")
    tail.beam((34.7, 0, 4.0), (37.2, 0, 7.4), 2.1, 0.8, "hide-")
    tail.beam((31.6, 0, 0.8), (36.8, 0, -5.2), 3.6, 1.7, "hide")
    tail.beam((35.86, 0, -4.12), (39.0, 0, -8.3), 2.6, 1.1, "hide")
    tail.beam((38.37, 0, -7.46), (40.3, 0, -10.2), 1.7, 0.6, "hide-")
    tail.beam((31.29, 0, 1.16), (36.44, 0, -4.78), 0.9, 2.3, "stripe")
