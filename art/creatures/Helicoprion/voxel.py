"""Helicoprion (zone 5's Legendary: the prehistoric "buzz-saw shark") for tools/blender/voxel_kit.py
(docs/style/creature-brief.md). Designed from the real animal: a long shark-like fish whose lower jaw carried a spiral
whorl of teeth.
Its idea: a shark with a circular saw for a jaw. One upright disc of bone on the middle line of the lower jaw, a ring of
pointed teeth round its rim, hanging below the chin and standing in front of the open mouth. Everything else is plain.
- The body is twenty slices on eleven joints. From one to the next one thing changes by one cube (the back, the
  belly or the width), so the back arches, the belly curves and the top view tapers, each in its own staircase.
- Three lines run the whole length: the pale belly, one thin aqua row where it meets the teal, a lighter top row.
- The head is a wedge: a skull and three blocks in a chain, each lower and narrower, over a wide open mouth. No teeth in
  the jaws: the whorl is the only bite it has.
- The whorl: an eight-sided disc held by a keel under the jaw, a darker hub and a boss on each face, and twelve teeth on
  the rim that shows. The teeth are biggest in the mouth and get smaller round the front and underneath, as the real
  spiral's do, and lean the way the saw would turn.
- A tall back fin, long side fins, a small second fin, a tall shark's tail with dark tips.
- The eye: a dark pupil in a thin halo of soft light (the only glow), under a brow that comes past it.
The rider sits behind the gills, in front of the back fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Helicoprion", "ZONE 5 / OPEN BLUE", "LEGENDARY"
U = 0.45
PALETTE = {"teal": "#1B6F78", "belly": "#E2D3B4", "line": "#63CFC2", "tooth": "#FBF7EA", "mouth": "#5B2233", "black": "#1C2024",
           "soft": "#FFD27A"}
SEAT = (-12, 7, 6.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
FRAME, ORTHO = 2.6, 37.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["teal"]}]

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((4, 5, -5, 6), (2, 5, -6, 6), (2, 6, -6, 6), (3, 6, -6, 7), (2, 6, -7, 7), (5, 6, -7, 8), (2, 5, -7, 8), (2, 5, -7, 7),
          (2, 5, -6, 7), (2, 4, -6, 7), (2, 4, -6, 6), (2, 4, -5, 6), (2, 4, -5, 5), (2, 3, -5, 5), (2, 3, -4, 5), (2, 3, -4, 4),
          (2, 3, -3, 4), (2, 2, -3, 4), (2, 2, -3, 3), (2, 2, -2, 3))
GROUPS = (1, 2, 2, 1, 2, 2, 2, 2, 2, 2, 2)  # slices to a joint: a part is about as long as it is thick
BODY_FROM = -22
SKULL = (5, -5, 5)
SWIM = {"chain": ["Head"] + [f"S{i + 1}" for i in range(len(GROUPS))] + ["Tail"],
        "amplitudes": [1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8, 10], "phaseStep": 0.4, "headCounter": 2}

WHORL = (-32.4, -5.8)  # the middle of the disc, in the side view (x, z)
RADIUS = 3.6


def top_steps(n):
    """the corners of the back: one narrow row and one broad step where the body is thick, fewer as it thins"""
    return [(2, 1), (1, 2)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def tall(steps):
    return sum(t for _, t in steps)


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, teal with a lighter top row, a pale belly and one thin aqua row above it"""
    p.hull(x0, x1, n, bot, top, "teal", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "teal+")
    edge = -2 if bot <= -3 else -1
    p.paint_sym(x0, x1, n, bot, edge, "belly")
    p.paint_sym(x0, x1, n, edge, edge + 1, "line")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def ring(radius, turn=0.0):
    """an eight-sided outline round the whorl's middle, in the side view"""
    return [(WHORL[0] + radius * math.cos(math.radians(turn + 45 * k)), WHORL[1] + radius * math.sin(math.radians(turn + 45 * k)))
            for k in range(8)]


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    slab(head, -28, BODY_FROM, *SKULL)
    head.sym(-28, -26, 4, -5, -4, "belly-")  # the jaw's hinge: the bottom row is wider here, so the jaw's root is buried
    # the snout: three big blocks in a chain, each a step lower and narrower than the last and starting inside it. Each has a
    # pale lip plate underneath; the first two have a lighter plate on top, which starts past the end of the block before
    # The underside steps UP toward the tip: the upper jaw makes room for the whorl that stands in the mouth
    blocks = ((-27.0, -31.0, 1.55, 1.25, 8.6, 4.7, 5.0, -27.0, 0.8), (-30.3, -33.4, 1.5, 1.2, 6.4, 3.0, 3.4, -31.8, 0.5),
              (-32.8, -35.0, 0.9, 0.6, 4.2, 1.9, 0.0, 0.0, 0.4))
    for x0, x1, z0, z1, wide, thick, plate, plate_from, lip_thick in blocks:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "teal", flat="z")
        lip = thick / 2 + lip_thick / 2
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, lip_thick, "belly", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.5, "teal+", flat="z")
    nostril = (1.9, 2.3, 0.5, 1.0)
    head.block(-34.5, nostril, -33.8, nostril, "black", mirror=True)
    # the mouth, wide open: a dark inside that ends inside the lip and the jaw, and a lower jaw of two boxes with no teeth
    mouth = (-3.4, 3.4, -3.9, -1.5)
    head.block(-30.0, mouth, -27.8, mouth, "mouth")
    head.beam((-27.0, 0, -4.1), (-30.2, 0, -4.3), 7.6, 1.7, "belly", flat="z")
    head.beam((-29.6, 0, -4.25), (-33.0, 0, -4.45), 4.6, 1.2, "belly", flat="z")
    # the keel under the jaw that carries the whorl: one block sloping down from the throat, its end inside the disc
    head.beam((-26.0, 0, -3.9), (-30.4, 0, -6.1), 3.0, 3.4, "belly-", flat="z")
    # the whorl: an upright disc on the middle line, a darker hub and a boss on each face (steps of 0.3 cube)
    head.prism(ring(RADIUS, 22.5), -0.7, 0.7, "tooth")
    head.prism(ring(2.3), 0.3, 1.0, "tooth-", mirror=True)
    head.prism(ring(1.0, 22.5), 0.6, 1.3, "tooth", mirror=True)
    # its teeth: one on each corner and each flat of the rim that shows, bases sunk in the disc. The biggest stand in the
    # mouth; they get smaller round the front and underneath, and each leans the way the saw would turn
    for i in range(12):
        a = math.radians(90 + 22.5 * i)
        rx, rz = math.cos(a), math.sin(a)
        tx, tz = -rz, rx
        rim = RADIUS if i % 2 else RADIUS * math.cos(math.radians(22.5))
        long, half = 1.6 - 0.06 * i, 0.65 - 0.014 * i
        bx, bz = WHORL[0] + (rim - 0.35) * rx, WHORL[1] + (rim - 0.35) * rz
        base = [(bx - half * tx, -0.5, bz - half * tz), (bx + half * tx, -0.5, bz + half * tz),
                (bx + half * tx, 0.5, bz + half * tz), (bx - half * tx, 0.5, bz - half * tz)]
        head.spike(base, (WHORL[0] + (rim + long) * rx + 0.3 * tx, 0.0, WHORL[1] + (rim + long) * rz + 0.3 * tz), "tooth")
    # the eye: a dark socket on the skull's side, a thin halo of soft light, a dark pupil standing out of it. The brow sits
    # on the eye, cuts across its top and comes past it in front, so the fish scowls
    socket = (5.38, 5.97, -0.6, 1.9)
    head.block(-27.0, socket, -24.2, socket, "teal-", mirror=True)
    halo = (5.85, 6.15, -0.25, 1.55)
    head.block(-26.65, halo, -24.55, halo, "soft", mirror=True)
    pupil = (5.97, 6.35, 0.1, 1.2)
    head.block(-26.25, pupil, -24.95, pupil, "black", mirror=True)
    head.beam((-27.5, 5.8, 1.3), (-23.8, 5.8, 1.7), 1.2, 1.4, "teal", mirror=True)

    # the body: twenty slices on eleven joints
    segs, firsts, x, k, last = [], [], BODY_FROM, 0, SKULL
    for i, count in enumerate(GROUPS):
        seg = m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}")
        segs.append(seg)
        for j in range(count):
            length, n, bot, top = SLICES[k]
            slab(seg, x, x + length, n, bot, top)
            if j == 0:
                # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two
                # pieces and kept clear of both pieces' steps
                fn, fbot, ftop = last
                up = max(tall(top_steps(n)), tall(top_steps(fn)))
                down = max(tall(bottom_steps(n)), tall(bottom_steps(fn)))
                seg.sym(x - 1, x, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "teal-")
            last = (n, bot, top)
            x += length
            k += 1
    end = x
    # gill slits: three shallow lines in the side, behind the head
    for x in (-21, -19):
        segs[0].dent(x, x + 1, 5, -1, 3, "teal-")
    segs[1].dent(-17, -16, 5, -1, 3, "teal-")
    # the seat: behind the gills, in front of the back fin, with a slot either side for the rider's legs
    segs[2].dent(-13, -11, 6, 1, 4, "teal-")

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it,
    # the first starting deep in the body. The big fins have a darker collar round the root and a dark tip
    segs[3].beam((-6.6, 0, 5.43), (-4.6, 0, 8.65), 5.8, 2.0, "teal-")  # the back fin's collar
    segs[3].beam((-6.5, 0, 5.6), (-2.3, 0, 12.4), 5.2, 1.5, "teal")  # the back fin: tall, swept back
    segs[3].beam((-3.1, 0, 11.1), (-0.2, 0, 16.2), 3.8, 1.1, "teal")
    segs[3].beam((-1.0, 0, 14.9), (0.8, 0, 18.4), 2.7, 0.7, "teal-")
    segs[0].beam((-20.1, 2.6, -2.98), (-18.41, 4.86, -3.33), 5.0, 1.8, "teal-", flat="z", mirror=True)  # the side fins' collars
    segs[0].beam((-20.0, 2.7, -3.0), (-15.2, 9.2, -4.0), 4.4, 1.4, "teal", flat="z", mirror=True)  # the side fins
    segs[0].beam((-16.0, 8.1, -3.85), (-12.8, 12.6, -4.6), 3.4, 1.0, "teal", flat="z", mirror=True)
    segs[0].beam((-13.8, 11.2, -4.4), (-11.4, 14.8, -5.0), 2.5, 0.6, "teal-", flat="z", mirror=True)
    segs[8].beam((13.0, 0, 4.2), (15.0, 0, 7.0), 2.2, 1.0, "teal")  # the second back fin
    segs[8].beam((14.3, 0, 6.0), (15.8, 0, 8.2), 1.5, 0.6, "teal-")

    # the tail, on its own joint: a root block, a long upper lobe in three boxes and a shorter lower one, dark tips
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(GROUPS)}")
    tail.beam((end - 0.6, 0, 0.5), (end + 2.5, 0, 0.5), 2.4, 1.7, "teal")
    tail.beam((end + 1.1, 0, 1.2), (end + 5.3, 0, 7.9), 4.9, 1.3, "teal")
    tail.beam((end + 4.3, 0, 6.6), (end + 8.5, 0, 13.4), 3.8, 0.95, "teal")
    tail.beam((end + 7.4, 0, 12.0), (end + 10.2, 0, 16.6), 2.9, 0.6, "teal-")
    tail.beam((end + 1.6, 0, -0.9), (end + 5.0, 0, -6.0), 4.3, 1.0, "teal")
    tail.beam((end + 4.0, 0, -4.8), (end + 7.2, 0, -9.6), 3.4, 0.6, "teal-")
