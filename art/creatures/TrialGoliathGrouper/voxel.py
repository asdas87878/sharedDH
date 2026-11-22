"""The Goliath Grouper, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the
game's Goliath Grouper (art/creatures/GoliathGrouper) and replaces nothing. Designed from the real animal.
Its idea: the vacuum. A fat, wide fish that is mostly head, and the head is mostly a round open mouth.
- The body idea in numbers: about 53 cubes long; the body alone is 23 wide (0.43 of the length) and 20 deep (0.38),
  widest at the gill covers a third of the way back; the head to the gill cover is 23 cubes (0.43). Behind the gills it
  closes fast to a short stalk and a round paddle tail.
- The mouth is a cave at the very front: an opening 7 cubes wide and 5 high in a ring of thick raised lips (an
  octagon, bevelled to the front, so it reads round), dark red inside with a pink tongue on the floor and a row of tiny
  teeth just inside the upper and the lower lip.
- Small eyes set far forward and high, just above the mouth's corners, each in a pale ring: a dopey look. No brow.
- Mustard gold over cream, the line low. Small round paddle side fins, a long low back fin, a round anal fin.
- The marks (an Epic's two): five broken upright brown tiger bars down each side, ragged in whole blocks; and a fishing
  hook through the left corner of the lip, a short snapped pale line trailing back from it.
The rider sits on the broad nape behind the head's slope, in front of the back fin (too wide for leg slots)."""
import math

NAME, ZONE, RARITY = "Goliath Grouper (trial)", "ZONE 4 / SHIPWRECKS", "EPIC"
U = 0.45
PALETTE = {"gold": "#D6A62C", "cream": "#F3E6BE", "brown": "#7A5326", "lip": "#F2CF7A", "mouth": "#6A1C25", "tongue": "#EE8C98",
           "tooth": "#FFFCF2", "ring": "#FBF6E6", "black": "#1B1A1F", "metal": "#9BA4AE", "line": "#ECF1F4"}
SHADE = 0.9
SEAT = (-8, 9, 8.0)
FRAME, ORTHO = 2.0, 29.0
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["gold"]}]

# the body in slices (from, to, cubes out, bottom, top), grouped by part. The head first, to the gill cover
HEAD = ((-25, -22, 8, -7, 5), (-22, -19, 9, -7, 5), (-19, -16, 10, -9, 7), (-16, -13, 10, -9, 7), (-13, -10, 11, -9, 9),
        (-10, -7, 11, -10, 9), (-7, -4, 11, -10, 9))  # the forehead climbs in three broad steps, two cubes each
BODY = (("B1", ((-4, -1, 11, -10, 10), (-1, 2, 10, -10, 10))),
        ("B2", ((2, 4, 9, -9, 9), (4, 6, 8, -8, 8), (6, 8, 7, -7, 7))),
        ("B3", ((8, 10, 6, -6, 6), (10, 12, 5, -5, 5), (12, 15, 4, -4, 4))),
        ("Tail", ((15, 17, 3, -4, 4),)))
CHAIN = (("B1", 2.5), ("B2", 5.0), ("B3", 9.0), ("Tail", 15.0))

# the mouth: a ring of lips round an opening, centred on y = 0, z = MZ. Half width and half height of the opening and of
# the ring's outside, and how much of each corner is cut off (so the octagon reads round)
MZ = -1.5
INNER, OUTER = (3.65, 2.65, 1.2), (6.0, 5.2, 2.2)
LIP_FRONT, LIP_BACK = -27.4, -23.6  # the straight runs; the corners stand 0.2 back, so no two faces lie in one plane
BEVEL = (0.88, 1.08)  # at the front the outside is this much smaller and the opening this much bigger: the lips roll over

# the tiger bars: (centre x, width, the rows of the break), and how each two rows step left or right (ragged, whole blocks)
BARS = ((-19, 3, 0), (-12, 3, 2), (-5, 3, 1), (2, 3, 3), (9, 2, 1))
RAGGED = ((0, 1, 0, -1, 0, 1, 1, 0), (1, 0, -1, 0, 1, 0, -1, 0), (0, -1, 0, 1, 1, 0, -1, 0), (-1, 0, 1, 0, -1, 0, 1, 1),
          (0, 1, 0, 0, -1, 0, 1, 0))


def pose(parts, phase):
    """a heavy fish's swim: the big head hardly moves, the wave grows down the rear to the round tail; the paddles scull"""
    parts["Head"].rotation_euler.z = math.radians(1.2) * math.sin(phase + math.pi)
    for k, (name, degrees) in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(degrees) * math.sin(phase - 0.7 * (k + 1))
    for name, side in (("PecR", 1), ("PecL", -1)):
        parts[name].rotation_euler.z = side * math.radians(16) * (0.5 + 0.5 * math.sin(phase - 0.9))


def steps(n, tall):
    """the corners: a wide plateau and broad steps where the body is big, fewer as it thins"""
    if n >= 10 and tall >= 16:
        return [(4, 1), (2, 1), (1, 2)]
    if n >= 9:
        return [(3, 1), (1, 2)]
    return [(2, 1), (1, 1)] if n >= 5 else [(1, 1)]


def rows(n, tall):
    return sum(t for _, t in steps(n, tall))


def line(bot):
    """cream below this height: low on the flank"""
    return -4 if bot <= -6 else bot + 2


def slab(p, x0, x1, n, bot, top):
    st = steps(n, top - bot)
    p.hull(x0, x1, n, bot, top, "gold", st, st)
    p.paint_sym(x0, x1, n, top - 1, top, "gold+")
    p.paint_sym(x0, x1, n, bot, line(bot), "cream")
    p.paint_sym(x0, x1, n, bot, bot + 1, "cream-")


def octagon(half_w, half_h, cut, scale=1.0):
    w, h, c = half_w * scale, half_h * scale, cut * scale
    return [(w, h - c), (w - c, h), (-(w - c), h), (-w, h - c), (-w, -(h - c)), (-(w - c), -h), (w - c, -h), (w, -(h - c))]


def lips(p):
    """the ring of lips: eight blocks, each between the inside and the outside octagon, bevelled to the front"""
    inner_b, outer_b = octagon(*INNER), octagon(*OUTER)
    inner_f, outer_f = octagon(*INNER, scale=BEVEL[1]), octagon(*OUTER, scale=BEVEL[0])
    for k in range(8):
        a, b = k, (k + 1) % 8
        verts = []
        back = 0.0 if k % 2 else 0.2
        for x, inner, outer in ((LIP_FRONT + back, inner_f, outer_f), (LIP_BACK - back, inner_b, outer_b)):
            for y, z in (inner[a], inner[b], outer[b], outer[a]):
                verts.append((x, y, z + MZ))
        faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        p.solid(verts, faces, "lip")


def opening(x):
    """the opening's half width and half height at x (the bevel widens it toward the front)"""
    f = (LIP_BACK - x) / (LIP_BACK - LIP_FRONT)
    s = 1.0 + (BEVEL[1] - 1.0) * f
    return INNER[0] * s, INNER[1] * s


def build(m):
    head = m.part("Head", (-4, 0, 0))
    for s in HEAD:
        slab(head, *s)

    # THE MOUTH: a cave cut into the front of the head, its walls painted dark red, a ring of thick lips round it
    head.carve(-25, -20, -3, 4, -4, 1)
    for k in (-4, 0):  # its corners filled again, so the cave is as round as the lips
        head.pair(-25, -20, 3, 4, k, k + 1, "mouth")
    head.paint(-25, -19, -4, 5, -5, 2, "mouth")
    lips(head)
    head.block(-25.3, (-1.6, 1.6, -4.3, -3.45), -19.6, (-2.3, 2.3, -4.3, -3.25), "tongue")  # on the floor, its root in the back wall
    # tiny teeth just inside the lips: five hanging from the upper lip, four standing on the lower one
    tx = -25.3
    hw, hh = opening(tx)
    for y in (0.0, 1.0, 2.0):
        head.tooth(tx, y, MZ + hh + 0.15, 0.7, 0.8, "tooth", mirror=y > 0)
    for y in (0.5, 1.5):
        head.tooth(tx, y, MZ - hh - 0.15, 0.7, -0.8, "tooth")

    # the eyes: small, far forward and high, just above the mouth's corners; a pale ring, a dark pupil, no brow
    ring = (6.0, 8.95, 1.25, 3.75)
    head.block(-24.3, ring, -22.15, ring, "ring", mirror=True)
    pupil = (8.5, 9.3, 1.9, 2.95)
    head.block(-23.75, pupil, -22.75, pupil, "black", mirror=True)

    # THE SECOND MARK: a hook through the left corner of the lip (it goes in under the corner and its bend hangs below),
    # the shank up the outside to the eye, and a short pale line from the eye that trails back and ends snapped
    hx, side = -26.0, -1  # on the left: the side the 3/4 view sees
    for ((y0, z0), (y1, z1)), size in ((((5.0, -3.8), (6.0, -6.6)), 0.55), (((5.9, -6.3), (6.9, -7.5)), 0.3),
                                       (((6.6, -7.45), (8.1, -7.1)), 0.55), (((7.95, -7.0), (8.5, -5.6)), 0.3),
                                       (((8.45, -5.8), (8.6, -1.2)), 0.55)):
        head.beam((hx, y0 * side, z0), (hx, y1 * side, z1), size, size, "metal")
    eye = (8.15 * side, 9.05 * side, -1.4, -0.5)
    head.block(hx - 0.45, eye, hx + 0.45, eye, "metal")  # the eye of the hook
    head.beam((hx, 8.6 * side, -0.95), (-24.4, 10.0 * side, -1.0), 0.56, 0.3, "line")
    head.beam((-24.55, 9.95 * side, -0.95), (-19.6, 10.9 * side, -2.6), 0.3, 0.56, "line")
    head.beam((-19.75, 10.85 * side, -2.55), (-18.6, 11.0 * side, -2.1), 0.25, 0.25, "line")  # the snapped end, frayed in two
    head.beam((-19.75, 10.85 * side, -2.55), (-18.7, 11.25 * side, -3.1), 0.25, 0.25, "line")

    # the body, each part one to three slabs, with a hidden sleeve into the piece in front (sized from the smaller of the
    # two and clear of both pieces' corner steps)
    parts, before, parent = {"Head": head}, HEAD[-1], "Head"
    for name, slabs in BODY:
        p = parts[name] = m.part(name, (slabs[0][0], 0, 0), parent)
        for s in slabs:
            slab(p, *s)
        x0, _, n, bot, top = slabs[0]
        _, _, fn, fbot, ftop = before
        deep = max(rows(n, top - bot), rows(fn, ftop - fbot))
        p.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + deep, min(top, ftop) - deep, "gold-")
        before, parent = slabs[-1], name

    # THE FIRST MARK: five broken upright tiger bars down each side. They run from the colour line up to the row under the
    # back's top and on the outer four columns (so they wrap over the shoulder's steps, not across the back), each row of two shifted a block left or right
    tops = {x: (top, bot, n) for x0, x1, n, bot, top in HEAD + tuple(s for _, ss in BODY for s in ss) for x in range(x0, x1)}
    for k, (cx, width, gap) in enumerate(BARS):
        for x in range(cx - 3, cx + 4):
            top, bot, n = tops[x]
            for z in range(line(bot), top - 1):
                band = (z - line(bot)) // 2
                if band == gap + 1:
                    continue  # the break
                x0 = cx - width // 2 + RAGGED[k][band % len(RAGGED[k])]
                if x0 <= x < x0 + width:
                    for p in parts.values():
                        p.paint_pair(x, x + 1, n - 4, n + 1, z, z + 1, "brown")  # the flank and the shoulder only

    # the gill cover's edge: a quiet line down the flank where the head ends
    head.dent(-5, -4, 11, -3, 5, "gold-")

    b1, b2, b3, tail = parts["B1"], parts["B2"], parts["B3"], parts["Tail"]
    # the back fin: long and low, a spiny front that hugs the back, a soft rounded rear, starting behind the rider
    b1.beam((-2.4, 0, 10.5), (2.6, 0, 10.2), 2.6, 1.3, "gold-")
    b2.beam((2.0, 0, 9.9), (7.8, 0, 8.4), 3.6, 1.0, "gold-")
    b3.beam((7.4, 0, 8.2), (11.6, 0, 5.8), 3.4, 0.7, "gold-")
    b3.beam((10.8, 0, 6.0), (13.2, 0, 4.4), 2.2, 0.4, "gold-")
    # the anal fin: round, two boxes
    b2.beam((5.4, 0, -5.2), (8.6, 0, -9.2), 3.0, 1.0, "gold-")
    b2.beam((7.4, 0, -7.8), (10.2, 0, -9.2), 2.2, 0.7, "gold-")
    # the belly fins: a small pair under the chest
    head.beam((-8.8, 3.5, -8.6), (-5.6, 4.8, -11.8), 2.4, 0.7, "gold-", flat="z", mirror=True)
    # the side fins: small round paddles, low on the flank behind the gill cover, each on its own joint
    for name, side in (("PecR", 1), ("PecL", -1)):
        pec = m.part(name, (-3.0, 11.0 * side, -4.0), "B1")
        pec.beam((-2.9, 10.6 * side, -4.0), (0.4, 11.9 * side, -5.0), 2.6, 1.0, "gold-")
        pec.beam((-0.4, 11.7 * side, -4.8), (3.2, 12.6 * side, -6.0), 4.0, 0.7, "gold-")
        pec.beam((2.6, 12.45 * side, -5.8), (4.2, 12.8 * side, -6.3), 2.4, 0.3, "gold-")

    # the tail: a round paddle. A root, a middle, and two short lobes turned out, so its outline is round
    tail.beam((16.0, 0, 0), (21.0, 0, 0), 8.6, 1.5, "gold")
    tail.beam((20.4, 0, 0), (25.4, 0, 0), 7.4, 0.9, "gold-")
    tail.beam((19.4, 0, 2.4), (24.2, 0, 5.0), 3.6, 1.25, "gold-")
    tail.beam((19.4, 0, -2.4), (24.2, 0, -5.0), 3.6, 1.25, "gold-")
