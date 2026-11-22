"""Helicoprion, a trial of docs/style/10-sharks-round-2.md, for tools/blender/voxel_kit.py. It stands beside the game's
Helicoprion (art/creatures/Helicoprion) and replaces nothing. Designed from the real animal: a long slim fish whose lower
jaw carried a spiral whorl of teeth, the old teeth coiled inward and the new ones growing at the outer end.
Its idea: the buzz-saw. A slim long fish with a short low head, and the lower jaw running out past the small upper jaw and
curling up into a great toothed wheel that stands in front of the face, higher than the snout.
- The body is nineteen slices on ten joints. From one to the next one thing changes by one cube (the back, the belly or
  the width): the back rises from the low head to the shoulders, the belly is deepest under the seat, and from there one
  long even taper runs to a thin stalk and a crescent tail.
- The head is low and short: a skull a step lower than the shoulders and three snout blocks in a chain, each lower and
  narrower. The upper jaw is small and toothless; a dark mouth opens under it.
- The whorl is the face: a sixteen-sided wheel on the lower jaw's tip, a third taller than the head, its top above the
  snout so it shows from the riding camera. Three rings of bone white on a dark gum: sixteen big teeth round the rim
  (biggest on top, all leaning the way the coil grows), a raised inner ring with ten small teeth, and a white hub.
- One hue: bright teal over cream, the line straight and low along the flank, the whole lower jaw cream.
- A white eye with a dark pupil under a brow that comes past it.
The rider sits on the shoulders, behind the gills and well in front of the back fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Helicoprion (trial)", "ZONE 5 / OPEN BLUE", "LEGENDARY"
U = 0.45
PALETTE = {"teal": "#1E9AA3", "cream": "#F3E5C3", "tooth": "#FFFBEF", "gum": "#8E3A52", "black": "#1A1E24"}
SHADE = 0.9
SEAT = (-5, 6, 6.5)
FRAME, ORTHO = 2.7, 40.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["teal"]}]

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((2, 5, -5, 5), (2, 5, -6, 5), (2, 6, -6, 5), (2, 6, -7, 5), (2, 6, -7, 6), (7, 6, -7, 6), (2, 6, -6, 6),
          (2, 5, -6, 6), (2, 5, -5, 6), (2, 5, -5, 5), (2, 4, -5, 5), (2, 4, -4, 5), (2, 4, -4, 4), (2, 3, -4, 4),
          (2, 3, -3, 4), (2, 3, -3, 3), (2, 2, -3, 3), (2, 2, -2, 3), (2, 2, -2, 2))
GROUPS = (2, 3, 1, 2, 2, 2, 2, 2, 2, 1)  # slices to a joint: a part is about as long as it is thick
BODY_FROM = -19
SKULL = (5, -5, 4)  # cubes out, bottom, top: a step lower than the shoulders
SWIM = {"chain": ["Head"] + [f"S{i + 1}" for i in range(len(GROUPS))] + ["Tail"],
        "amplitudes": [1.5, 2, 2.5, 3, 4, 5, 6, 7, 8.5, 10, 12], "phaseStep": 0.42, "headCounter": 2}

WHORL = (-37.0, 5.0)  # the middle of the wheel, in the side view (x, z)
RADIUS = 6.0
HALF = 1.6  # the wheel's half thickness


def top_steps(n):
    """the corners of the back: one narrow row and one broad step where the body is thick, fewer as it thins"""
    return [(2, 1), (1, 2)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def tall(steps):
    return sum(t for _, t in steps)


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, teal with a lighter top row, cream below a straight low line"""
    p.hull(x0, x1, n, bot, top, "teal", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "teal+")
    p.paint_sym(x0, x1, n, bot, max(-1, bot + 2), "cream")
    p.paint_sym(x0, x1, n, bot, bot + 1, "cream-")


def ring(radius, count=16, turn=None):
    """a many-sided outline round the whorl's middle, in the side view, a flat facing straight back"""
    turn = 180.0 / count if turn is None else turn
    return [(WHORL[0] + radius * math.cos(math.radians(turn + 360.0 / count * k)),
             WHORL[1] + radius * math.sin(math.radians(turn + 360.0 / count * k))) for k in range(count)]


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    slab(head, -27, BODY_FROM, *SKULL)
    # the snout: three blocks in a chain, each lower and narrower than the last and starting inside it, a lighter plate on
    # the first two, and a cream lip plate under each (the small upper jaw)
    blocks = ((-26.0, -29.4, 1.7, 1.2, 9.4, 4.8, 5.6), (-28.8, -31.8, 1.0, 0.6, 6.4, 3.4, 0.0))
    for x0, x1, z0, z1, wide, thick, plate in blocks:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "teal", flat="z")
        lip = thick / 2 + 0.35
        head.beam((x0 + 0.3, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.6, 0.7, "cream", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((x0 - 1.0, 0, top(x0 - 1.0)), (x1 + 0.8, 0, top(x1 + 0.8)), plate, 0.5, "teal+", flat="z")
    # the mouth: a dark wedge between the small upper jaw and the lower jaw, its back end inside the cheek
    head.block(-30.6, (-2.6, 2.6, -3.0, -1.2), -26.0, (-3.4, 3.4, -3.2, -1.0), "gum-")
    # the lower jaw: three cream blocks, the first deep at the throat, running out past the snout and climbing into the
    # whorl, its last block's end buried in the wheel
    head.beam((-21.0, 0, -4.0), (-28.8, 0, -3.6), 8.0, 2.4, "cream", flat="z")
    head.beam((-22.0, 0, -5.2), (-27.6, 0, -4.9), 6.6, 1.2, "cream-", flat="z")  # the chin under it
    head.beam((-28.2, 0, -3.65), (-34.2, 0, -0.6), 5.2, 2.0, "cream", flat="z")
    # the jaw's tip curls on under the whorl and cups it: the wheel sits in the jaw
    head.beam((-33.8, 0, -1.1), (-39.2, 0, -1.4), 4.4, 1.8, "cream", flat="z")

    # THE WHORL: a dark wheel of gum with a raised inner ring and a small hub, steps of 0.3 cube; the upper jaw's tip
    # butts into its back
    head.prism(ring(RADIUS), -HALF, HALF, "gum")
    head.prism(ring(3.9, 12), HALF - 0.3, HALF + 0.6, "gum-", mirror=True)
    head.prism(ring(1.5, 8), HALF + 0.3, HALF + 0.9, "tooth", mirror=True)

    def tooth_ring(count, start, root, tip, half, y0, y1, ytip, lean, grow=0.0, skip=(), spiral=0.0):
        """teeth round the whorl's middle: bases centred at radius `root` spanning y0..y1, points out to `tip` (plus `grow`
        more on the top of the wheel), each leaning `lean` the way the coil grows"""
        for i in range(count):
            a = start + 360.0 / count * i
            if round(a % 360, 1) in skip:
                continue
            r = math.radians(a)
            rx, rz, tx, tz = math.cos(r), math.sin(r), -math.sin(r), math.cos(r)
            bx, bz = WHORL[0] + root * rx, WHORL[1] + root * rz
            reach = tip + grow * max(0.0, math.sin(r)) + spiral * i / count
            base = [(bx - half * tx, y0, bz - half * tz), (bx + half * tx, y0, bz + half * tz),
                    (bx + half * tx, y1, bz + half * tz), (bx - half * tx, y1, bz - half * tz)]
            head.spike(base, (WHORL[0] + reach * rx + lean * tx, ytip, WHORL[1] + reach * rz + lean * tz), "tooth",
                       mirror=y0 > 0)

    flat = RADIUS * math.cos(math.radians(180.0 / 16))
    # the rim: big teeth on every flat that is not in the jaw or against the snout, biggest on top (the newest, and the
    # ones the rider sees)
    tooth_ring(16, 0.0, flat - 0.35, flat + 2.0, 0.82, -1.35, 1.35, 0.0, 0.5, grow=1.2,
               skip=(0.0, 270.0, 292.5, 315.0, 337.5))
    # the face: a ring of white teeth lying on the wheel round the raised ring, on both faces, growing as they go round:
    # the coil seen from the side, its middle the white hub
    tooth_ring(12, 15.0, 3.6, 4.9, 0.62, HALF - 0.2, HALF + 0.4, HALF + 0.25, 0.35, spiral=0.75)

    # the eye: a white block on the skull's side with a dark pupil standing out of it, under a brow that cuts across its
    # top and comes past it in front, so the fish scowls
    white = (5.35, 5.65, -0.5, 1.9)
    head.block(-26.2, white, -23.6, white, "tooth", mirror=True)
    pupil = (5.5, 5.95, -0.1, 1.4)
    head.block(-25.9, pupil, -24.5, pupil, "black", mirror=True)
    head.beam((-27.0, 5.5, 1.5), (-23.0, 5.5, 2.1), 1.3, 1.5, "teal-", mirror=True)

    # the body: nineteen slices on ten joints
    segs, x, k, last = [], BODY_FROM, 0, SKULL
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
    for x in (-18, -16):
        segs[0].dent(x, x + 1, 5, -1, 2, "teal-")
    segs[1].dent(-14, -13, 6, -1, 2, "teal-")
    # the seat: on the shoulders, with a slot either side for the rider's legs
    segs[2].dent(-6, -4, 6, 0, 3, "teal-")

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it,
    # the first starting deep in the body
    s = segs[4]  # the back fin: a swept triangle well behind the seat, lower than the old one's
    s.beam((2.4, 0, 4.6), (5.4, 0, 9.6), 4.6, 1.5, "teal")
    s.beam((4.7, 0, 8.6), (7.2, 0, 12.0), 3.2, 1.0, "teal")
    s.beam((6.6, 0, 11.2), (8.4, 0, 13.4), 2.0, 0.6, "teal-")
    # the side fins: long and swept back like wings, from low on the shoulders
    p = segs[1]
    p.beam((-14.4, 3.0, -4.6), (-9.6, 9.6, -5.8), 4.6, 1.4, "teal", flat="z", mirror=True)
    p.beam((-10.6, 8.6, -5.6), (-6.6, 13.2, -6.6), 3.4, 1.0, "teal", flat="z", mirror=True)
    p.beam((-7.4, 12.4, -6.45), (-4.6, 15.4, -7.2), 2.3, 0.6, "teal-", flat="z", mirror=True)
    segs[5].beam((6.6, 1.6, -3.8), (9.4, 3.8, -5.4), 2.2, 0.7, "teal", flat="z", mirror=True)  # the belly fins, small

    # the tail, on its own joint: a short stock, then a crescent of two lobes, nearly equal, each in three boxes that
    # sweep back more toward the tip
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(GROUPS)}")
    tail.sym(end, end + 3, 1, -1, 2, "teal")
    tail.sym(end - 1, end, 0, 0, 1, "teal-")  # its sleeve
    tail.beam((end + 1.4, 0, 1.0), (end + 3.8, 0, 6.6), 4.8, 1.6, "teal")
    tail.beam((end + 3.3, 0, 5.6), (end + 5.9, 0, 9.8), 3.5, 1.0, "teal")
    tail.beam((end + 5.5, 0, 9.0), (end + 8.0, 0, 11.6), 2.2, 0.6, "teal-")
    tail.beam((end + 1.4, 0, 0.0), (end + 3.6, 0, -5.0), 4.4, 1.0, "teal")
    tail.beam((end + 3.1, 0, -4.1), (end + 5.6, 0, -7.9), 3.2, 0.7, "teal")
    tail.beam((end + 5.2, 0, -7.2), (end + 7.4, 0, -9.4), 2.0, 0.4, "teal-")
