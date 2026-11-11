"""The Devourer (zone 10's Secret: the last one, mostly mouth) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Secret by docs/style/05-rarity-look.md.
Its idea: an animal that is a mouth with a little body left over. The maw is half its length and its whole front.
- The mouth is a stepped funnel: three chambers, each smaller than the one in front, and at the back the furnace of the
  throat (a white-hot core, orange round it, a red rim). Each chamber's front edge carries a thin gum line and a ring of
  fangs, so from the front the rows stand inside one another round the fire.
- The jaws are two great hooked lips; the lower one is longer (an underbite with two tusks) and is on its own joint.
- A crown of horn spines stands round the rim: five on top, four under the lower lip.
  None behind the rim: the rider sits on a crest on the skull, far back, legs either side of it.
- A small ember eye under a heavy brow on each side, far back.
- The body is short: five slices that shrink fast to a stubby tail, small side fins, one small back fin.
- Charred plum-black, ash underneath. An ember crack each side: it starts at the corner of the mouth and runs on down
  the whole body to the tail, as if the mouth could open that far. Lava at the head, dull red at the tail. A third
  wanders down the crest of the back, where the rider sees it.
Ways to be more than a Mythic: scale (one part stretched beyond reason), light with a source (the furnace), regalia
(the crown)."""
import math

NAME, ZONE, RARITY = "The Devourer", "ZONE 10 / THE UNDERWORLD", "SECRET"
U = 0.5
SHADE = 0.76
PALETTE = {"char": "#43304A", "ash": "#74586E", "mouth": "#4A1522", "gum": "#96303A", "tooth": "#F5EBD2", "horn": "#D2BA90",
           "white": "#FFF3C2", "lava": "#FF7A1A", "red": "#C9361C", "black": "#17121A"}
SEAT = (-11, 18, 2.5)
GLOW = {"white": 1.2, "lava": 0.9, "red": 0.5}
LIGHTS = [("Head", (-9, 0, 0), "#FF7A1A", 420, 1.2)]  # the furnace
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["char"]}]
FRAME, ORTHO, ORTHO_SWIM = 4.0, 58.0, 64.0
RIDE_FOG = "#3A1420"
CHAIN = ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"]
AMPLITUDES = [3, 5, 8, 11, 14, 19]

# the body behind the skull: (from, to, cubes out, bottom, top). It shrinks fast; the belly rises faster than the back falls
BODY = ((4, 12, 11, -11, 12), (12, 19, 9, -9, 10), (19, 25, 7, -7, 8), (25, 30, 5, -4, 6), (30, 34, 3, -2, 4))
SKULL = (-6, 4, 13, -13, 13)


def pose(parts, phase):
    """a fish's swim down the short body; the great jaw drops and shuts once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.8 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(7) * (0.5 + 0.5 * math.sin(phase))


def corner(n):
    """the corner steps of a slab n cubes out: broad on the big blocks, one cube at the tail"""
    if n >= 12:
        return [(5, 2), (2, 2)]
    if n >= 8:
        return [(4, 2), (2, 1)]
    if n >= 6:
        return [(3, 1), (1, 1)]
    if n >= 4:
        return [(2, 1), (1, 1)]
    return [(1, 1)]


def tall(n):
    return sum(t for _, t in corner(n))


def lip(p, x0, x1, k):
    """the mouth side of a lip slab (its row k, from x0 to x1): a gum line one cube in from the lip's edge, the dark of
    the mouth inside it. The edge itself stays the lip's colour"""
    cells = {(i, j) for (i, j, kk) in p.cells if kk == k and x0 <= i < x1}

    def edge(i, j):
        return (i - 1, j) not in cells or (i, j - 1) not in cells or (i, j + 1) not in cells

    for i, j in cells:
        if edge(i, j):
            continue
        near = any(edge(i + a, j + b) for a in (-1, 0, 1) for b in (-1, 0, 1) if (i + a, j + b) in cells)
        p.cells[(i, j, k)] = "gum" if near else "mouth"


def horn(p, a, b, c, w, mirror=True):
    """a horn spine: a thick root box from a (buried) to b, then a point from inside its end to c"""
    flat = "z" if abs(b[1] - a[1]) > max(abs(b[0] - a[0]), abs(b[2] - a[2])) else "y"
    p.beam(a, b, w, w * 0.9, "horn-", flat=flat, mirror=mirror)
    q = [bv - 0.28 * (bv - av) for av, bv in zip(a, b)]
    d = [cv - qv for qv, cv in zip(q, c)]
    length = math.sqrt(sum(v * v for v in d))
    d = [v / length for v in d]
    ref = (0.0, 1.0, 0.0) if abs(d[1]) < 0.75 else (0.0, 0.0, 1.0)
    u = [d[1] * ref[2] - d[2] * ref[1], d[2] * ref[0] - d[0] * ref[2], d[0] * ref[1] - d[1] * ref[0]]
    n = math.sqrt(sum(v * v for v in u))
    u = [v / n for v in u]
    v = [d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0]]
    s = w * 0.34
    base = [tuple(qv + s * (su * uv + sv * vv) for qv, uv, vv in zip(q, u, v)) for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    p.spike(base, tuple(c), "horn", mirror=mirror)


def fang_in(p, x, y, z, size, length):
    """a fang standing out of a side wall of the mouth at y, pointing in toward the middle (and its mirror)"""
    h = size / 2
    base = [(x - h, y + 0.25, z - h), (x + h, y + 0.25, z - h), (x + h, y + 0.25, z + h), (x - h, y + 0.25, z + h)]
    p.spike(base, (x, y - length, z * 0.85), "tooth", mirror=True)


def crack(p, x0, x1, n, k, colour, n_next=None):
    """a length of the ember crack: one row of cubes in the outermost column, at height k. Where the next slice is
    narrower the row turns across the step, so the line is unbroken"""
    p.paint_pair(x0, x1, n, n + 1, k, k + 1, colour)
    if n_next is not None and n_next < n:
        p.paint_pair(x1 - 1, x1, n_next + 1, n + 1, k, k + 1, colour)


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, a lighter top row, ash underneath"""
    p.hull(x0, x1, n, bot, top, "char", corner(n), corner(n))
    p.paint_sym(x0, x1, n, top - 1, top, "char+")
    p.paint_sym(x0, x1, n, bot, bot + max(2, round((top - bot) * 0.22)), "ash")
    p.paint_sym(x0, x1, n, bot, bot + 1, "ash-")


def build(m):
    head = m.part("Head", (-6, 0, 0))
    # ---- the upper jaw. Its outline is an arch: a lip whose tip hooks down, a roof, then the cheeks, which come down in
    # two steps to close on the lower jaw; the skull behind them is a step smaller all round
    head.hull(-44, -40, 9, 9, 13, "char", corner(9))  # the lip's tip hooks down two cubes
    head.hull(-40, -30, 12, 11, 15, "char", corner(12))  # the lip: a roof over the first ring
    head.hull(-30, -24, 15, 6, 16, "char", corner(15))  # the cheeks come down in two steps
    head.hull(-24, -18, 15, 3, 16, "char", corner(15))
    head.hull(-18, -6, 14, 0, 15, "char", corner(14))  # and close on the lower jaw
    slab(head, *SKULL)
    head.paint_sym(-44, -40, 9, 12, 13, "char+")
    head.paint_sym(-40, -30, 12, 14, 15, "char+")
    head.paint_sym(-30, -18, 15, 15, 16, "char+")
    head.paint_sym(-18, -6, 14, 14, 15, "char+")
    # the mouth's chambers, each smaller than the one in front, and the furnace in the skull's face
    head.carve(-30, -18, -9, 10, 3, 8)
    head.carve(-18, -6, -6, 7, 0, 5)
    lip(head, -44, -40, 9)
    lip(head, -40, -30, 11)
    head.paint(-30, -18, -10, 11, 3, 9, "mouth")
    head.paint(-30, -29, -10, 11, 6, 11, "mouth")
    head.paint(-30, -29, -10, 11, 6, 9, "gum")  # the second ring's gum line: the front edge of its chamber
    head.paint(-18, -6, -7, 8, 0, 6, "mouth")
    head.paint(-18, -17, -13, 14, 0, 3, "mouth")
    head.paint(-18, -17, -9, 10, 0, 8, "mouth")
    head.paint(-18, -17, -7, 8, 0, 6, "gum")
    head.paint(-6, -3, -6, 7, -5, 5, "red")  # the furnace: a red rim, orange inside, a white-hot core
    head.carve(-6, -3, -4, 5, -3, 3)
    head.paint(-3, -2, -4, 5, -3, 3, "lava")
    head.paint(-3, -2, -1, 2, -1, 1, "white")
    # the first ring's upper fangs: across the lip's tip, the two long ones off the middle, then down each side
    for y, length in ((0, 5.4), (2.8, 6.0), (5.6, 8.0), (8.0, 4.8)):
        head.tooth(-42.5, y, 9.25, 2.3, length, "tooth", mirror=y != 0)
    for x, length in ((-37.6, 6.0), (-34.6, 5.2), (-31.8, 4.4)):
        head.tooth(x, 9, 11.25, 2.2, length, "tooth")
    # the second and third rings: smaller fangs from each chamber's roof and walls
    for y, length in ((0, 4.6), (3.4, 4.6), (6.8, 3.8)):
        head.tooth(-28.9, y, 8.25, 2.0, length, "tooth", mirror=y != 0)
    fang_in(head, -28.9, 9.5, 7.0, 1.6, 3.6)
    for y in (1.6, 4.6):
        head.tooth(-17.1, y, 5.25, 1.6, 3.0, "tooth")
    fang_in(head, -17.1, 6.5, 2.6, 1.4, 2.4)
    # the crest: the rider's seat, with room for a leg either side. It starts low behind the crown
    head.sym(-23, -18, 2, 16, 17, "char+")
    head.sym(-18, -6, 2, 15, 18, "char")
    head.sym(-6, 4, 2, 13, 15, "char")
    head.paint_sym(-18, -6, 2, 17, 18, "char+")
    head.paint_sym(-6, 4, 2, 14, 15, "char+")
    # the eye: small, far back on the cheek. A dark socket, a thin ring of ember, a black pupil, under a heavy brow that
    # slants down to the front and comes past it
    socket, halo, pupil = (14.2, 14.8, 4.25, 7.65), (14.6, 15.1, 4.7, 7.2), (14.9, 15.4, 5.2, 6.6)
    head.block(-11.6, socket, -6.8, socket, "char-", mirror=True)
    head.block(-11.0, halo, -7.4, halo, "lava", mirror=True)
    head.block(-10.0, pupil, -8.4, pupil, "black", mirror=True)
    head.beam((-13.8, 14.9, 6.5), (-6.6, 14.9, 8.7), 2.5, 2.4, "char", mirror=True)
    # the crown: horn spines round the rim, the tallest in the middle
    horn(head, (-36.5, 0, 13.5), (-37.2, 0, 18.8), (-40.4, 0, 24.8), 2.5, mirror=False)
    horn(head, (-36.3, 4.6, 13.5), (-36.9, 5.7, 17.8), (-39.5, 7.3, 22.8), 2.2)
    horn(head, (-36.0, 8.2, 12.0), (-36.6, 11.2, 15.6), (-38.9, 14.0, 19.6), 2.0)
    # the ember crack: from the corner of the mouth back along the skull
    crack(head, -18, -6, 14, 0, "lava")
    head.paint_pair(-13, -12, 14, 15, 1, 3, "lava")
    crack(head, -6, 0, 13, 0, "lava")
    crack(head, -1, 4, 13, 1, "lava", 11)
    head.paint_pair(-4, -3, 13, 14, -2, 0, "lava")
    # and a second crack down the spine, along the crest: it wanders from side to side, and passes between the rider's legs
    for x0, x1, j, k in ((-23, -18, 0, 16), (-18, -12, 0, 17), (-13, -8, 1, 17), (-9, -6, 0, 17), (-6, 0, 0, 14), (-1, 4, -1, 14),
                         (3, 4, 0, 14)):
        head.paint(x0, x1, j, j + 1, k, k + 1, "lava")
    head.paint(-7, -6, 0, 1, 15, 18, "lava")  # down the step at the back of the seat

    # ---- the lower jaw, on its own joint: the same steps upside down, a longer lip (an underbite), deeper in the middle
    jaw = m.part("Jaw", (-5, 0, -1), "Head")
    jaw.hull(-47, -42, 9, -14, -10, "char", [], corner(9))
    jaw.hull(-42, -30, 12, -16, -12, "char", [], corner(12))
    jaw.hull(-30, -24, 15, -17, -6, "char", [], corner(15))
    jaw.hull(-24, -18, 15, -17, -3, "char", [], corner(15))
    jaw.hull(-18, -6, 14, -15, 0, "char", [], corner(14))
    jaw.sym(-6, -5, 11, -9, -6, "char-")  # a sleeve into the skull
    jaw.carve(-30, -18, -9, 10, -8, -3)
    jaw.carve(-18, -6, -6, 7, -5, 0)
    for x0, x1, n, bot, ash in ((-47, -42, 9, -14, -12), (-42, -30, 12, -16, -13), (-30, -18, 15, -17, -12), (-18, -6, 14, -15, -10)):
        jaw.paint_sym(x0, x1, n, bot, ash, "ash")
        jaw.paint_sym(x0, x1, n, bot, bot + 1, "ash-")
    lip(jaw, -47, -42, -11)
    lip(jaw, -42, -30, -13)
    jaw.paint(-30, -18, -10, 11, -9, -3, "mouth")
    jaw.paint(-30, -29, -10, 11, -12, -6, "mouth")
    jaw.paint(-30, -29, -10, 11, -9, -6, "gum")
    jaw.paint(-18, -6, -7, 8, -6, 0, "mouth")
    jaw.paint(-18, -17, -13, 14, -3, 0, "mouth")
    jaw.paint(-18, -17, -9, 10, -8, 0, "mouth")
    jaw.paint(-18, -17, -7, 8, -6, 0, "gum")
    for y, length in ((1.5, 5.4), (4.4, 6.0), (7.4, 8.6)):  # the outer two are the tusks of the underbite
        jaw.tooth(-45.5, y, -10.25, 2.4, -length, "tooth")
    jaw.tooth(-43.3, 8, -10.25, 2.2, -5.0, "tooth")
    for x, length in ((-39.6, 6.2), (-36.6, 5.6), (-33.6, 5.0), (-31.0, 4.2)):
        jaw.tooth(x, 9, -12.25, 2.2, -length, "tooth")
    for y in (1.7, 5.1):
        jaw.tooth(-28.9, y, -8.25, 2.0, -4.4, "tooth")
    fang_in(jaw, -28.9, 9.5, -7.0, 1.6, 3.6)
    for y in (0, 3.2):
        jaw.tooth(-17.1, y, -5.25, 1.6, -3.0, "tooth", mirror=y != 0)
    fang_in(jaw, -17.1, 6.5, -2.6, 1.4, 2.4)
    horn(jaw, (-37.0, 8.2, -13.0), (-37.6, 11.2, -16.4), (-39.8, 13.8, -19.8), 1.9)
    horn(jaw, (-37.5, 4.0, -14.5), (-38.2, 4.9, -18.4), (-40.8, 5.9, -22.2), 2.1)

    # ---- the body: five slices that shrink fast, each on its own joint
    segs, prev = [], SKULL
    for i, (x0, x1, n, bot, top) in enumerate(BODY):
        seg = m.part(f"S{i + 1}", (x0, 0, 0), "Head" if i == 0 else f"S{i}")
        slab(seg, x0, x1, n, bot, top)
        small = min(n, prev[2])
        clear = max(tall(n), tall(prev[2]))
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, prev[3]) + clear, min(top, prev[4]) - clear, "char-")
        segs.append(seg)
        prev = (x0, x1, n, bot, top)
    # the crest runs on down the back, smaller on each slice
    segs[0].sym(4, 12, 1, 12, 14, "char")
    segs[0].paint_sym(4, 12, 1, 13, 14, "char+")
    segs[1].sym(12, 19, 1, 10, 11, "char+")
    segs[0].paint(4, 12, 0, 1, 13, 14, "lava")
    segs[0].paint(11, 12, 0, 1, 11, 14, "lava")
    segs[1].paint(12, 19, 0, 1, 10, 11, "red")
    # the crack runs on to the tail, cooling as it goes
    crack(segs[0], 4, 8, 11, 1, "lava")
    segs[0].paint_pair(7, 8, 11, 12, 1, 4, "lava")
    crack(segs[0], 7, 12, 11, 3, "lava", 9)
    crack(segs[1], 12, 16, 9, 3, "lava")
    crack(segs[1], 15, 19, 9, 2, "lava", 7)
    segs[1].paint_pair(14, 15, 9, 10, 0, 3, "lava")
    crack(segs[2], 19, 22, 7, 2, "red")
    crack(segs[2], 21, 25, 7, 1, "red", 5)
    crack(segs[3], 25, 28, 5, 1, "red")
    crack(segs[3], 27, 30, 5, 2, "red", 3)
    crack(segs[4], 30, 33, 3, 2, "red")
    # small side fins and one small back fin: two boxes each, the second smaller and thinner
    segs[0].beam((5.7, 9.0, -5.2), (11.5, 15.0, -7.0), 4.2, 1.3, "char", flat="z", mirror=True)
    segs[0].beam((10.3, 13.8, -6.65), (14.6, 17.6, -8.0), 2.9, 0.8, "ash", flat="z", mirror=True)
    segs[2].beam((20.8, 0, 6.2), (24.0, 0, 11.2), 3.6, 1.3, "char")
    segs[2].beam((23.2, 0, 10.2), (26.0, 0, 13.6), 2.4, 0.8, "ash")

    # ---- the stubby tail: a stock and two short lobes
    tail = m.part("Tail", (34, 0, 1), "S5")
    tail.beam((33.6, 0, 1.0), (37.2, 0, 1.0), 4.4, 3.0, "char")
    tail.beam((35.8, 0, 1.7), (40.2, 0, 7.1), 3.8, 1.6, "char")
    tail.beam((39.2, 0, 6.1), (43.0, 0, 10.3), 2.6, 0.9, "ash")
    tail.beam((35.8, 0, 0.3), (39.6, 0, -4.1), 3.3, 1.2, "char")
    tail.beam((38.8, 0, -3.3), (42.0, 0, -6.7), 2.3, 0.5, "ash")
