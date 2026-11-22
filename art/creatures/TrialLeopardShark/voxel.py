"""The Leopard Shark, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the
game's Leopard Shark (art/creatures/LeopardShark) and replaces nothing. Designed from the real animal.
Its idea: the slinker. Long and low, a flat spade of a head, two small back fins alike, a long low tail.
- The body idea in numbers: about 45 cubes long (18 studs); the body alone is 6 deep (0.14 of the length) and 7 wide
  (0.16): wider than deep. No chest: the depth stays the same from the head to the tail; only the width comes in.
- The head is flat and broad: level on top, then a short rounded snout of three wide low blocks, a spade from above.
- Two back fins of one size and shape (rounded triangles), one at the middle and one at seven tenths. The tail is a
  quarter of the length and lies low: a long upper lobe at 20 degrees with a notch near its end, almost no lower lobe.
- The face: a small mouth set back under the snout, a level dark line with its corners turned down (a frown) and four
  tiny teeth. Oval cat eyes on the sides: pale, an upright slit pupil, a lid over the top third (sleepy).
- Colour: ivory on top, white below, the line low and straight.
- The one mark: seven chocolate saddles across the back, each 2 cubes wide and reaching halfway down the sides, one
  round spot on the flank between each pair; they go on as bars across the tail.
The rider sits between the second and third saddles, in front of the first back fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Leopard Shark (trial)", "ZONE 3 / KELP FOREST", "RARE"
U = 0.4
PALETTE = {"ivory": "#EFE3C2", "white": "#FBF8EE", "choc": "#5B3A2A", "eye": "#DCE8A4", "black": "#1E1A1A",
           "mouth": "#4A2026"}
SHADE = 0.9
SEAT = (-9, 3, 3.5)
FRAME, ORTHO = 1.55, 22.5
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["ivory"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"], "amplitudes": [2, 3, 5, 7, 10, 16], "phaseStep": 0.75,
        "headCounter": 2}

STEP = [(1, 1)]
BELLY = -1  # white below this height: the line low and straight
HEAD = (-17, -14, 3, -3, 3)  # the head behind the snout: x from, x to, cubes out, bottom, top
# the body's slices, one part each. The depth never changes; the width comes in once, at S5
SLICES = ((-14, -8, 3, -3, 3), (-8, -4, 3, -3, 3), (-4, 3, 3, -3, 3), (3, 7, 3, -3, 3), (7, 11, 2, -3, 3))
# THE MARK: seven saddles 2 cubes wide (x from), evenly spaced, none on a joint or on the seat's leg slots
SADDLES = (-16.2, -12.3, -7.7, -3.7, 0.47, 4.63, 8.8)
SPOTS = (-14, -10, -5, -1, 3, 7)  # one cube on the flank between each pair (x of the cube)
SADDLE_STOP = 0  # halfway down the side


def slab(p, x0, x1, n, bot, top):
    """a length of body: ivory, white from the line down with a shade on the bottom row, one step cut from every corner"""
    steps = STEP if n >= 2 else []
    p.hull(x0, x1, n, bot, top, "ivory", steps, steps)
    p.paint_sym(x0, x1, n, bot, BELLY, "white")
    p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


def find(x):
    """the slice that holds x"""
    for s in (HEAD,) + SLICES:
        if s[0] <= x < s[1]:
            return s
    raise ValueError(x)


def dorsal(p, a):
    """a back fin, a rounded triangle leaning back, its root front at x = a: three boxes, each smaller and thinner,
    the last one rounding the tip. Both back fins are this one"""
    p.beam((a + 1.6, 0, 2.2), (a + 2.4, 0, 4.5), 3.4, 1.2, "ivory")
    p.beam((a + 2.3, 0, 4.0), (a + 3.1, 0, 5.5), 2.2, 0.8, "ivory")
    p.beam((a + 2.95, 0, 5.15), (a + 3.45, 0, 6.1), 1.2, 0.4, "ivory-")


# the tail's upper lobe: a line along its top edge, rising at 20 degrees from ORIGIN; pieces hang under it
ANGLE = math.radians(20)
UX, UZ = math.cos(ANGLE), math.sin(ANGLE)
NX, NZ = math.sin(ANGLE), -math.cos(ANGLE)  # down, square to the line
ORIGIN = (12.4, 2.4)


def on_lobe(s, w):
    return (ORIGIN[0] + UX * s + NX * w, 0, ORIGIN[1] + UZ * s + NZ * w)


def lobe(p, s0, s1, drop, deep, thick, colour):
    """a piece of the upper lobe from s0 to s1 along the line, its top edge `drop` under the line, `deep` deep"""
    w = drop + deep / 2
    p.beam(on_lobe(s0, w), on_lobe(s1, w), deep, thick, colour)


def bar(p, s, drop, reach, thick, wide):
    """a chocolate bar across the lobe piece at s (its top edge `drop` under the line), from just under that edge down to
    `reach`: a plate on each side, standing 0.15 proud, its inner face sunk in the lobe"""
    inner = max(thick / 2 - 0.3, 0.05)
    mid = (inner + thick / 2 + 0.15) / 2
    a, b = on_lobe(s, drop + 0.3), on_lobe(s, reach)
    p.beam((a[0], mid, a[2]), (b[0], mid, b[2]), wide, thick / 2 + 0.15 - inner, "choc", flat="y", mirror=True)


def build(m):
    head = m.part("Head", (HEAD[1], 0, 0))
    slab(head, *HEAD)
    # the snout, a short flat spade: three wide low blocks in a chain, each narrower and thinner than the last and starting
    # inside it, their tops stepping down to a blunt rounded tip. A white plate under each, so the underside is white
    for x0, z0, x1, z1, wide, thick in ((-16.6, 1.05, -19.8, 0.75, 7.6, 3.2), (-19.4, 0.85, -21.8, 0.5, 5.6, 2.6),
                                        (-21.4, 0.45, -22.6, 0.3, 3.8, 1.9)):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "ivory", flat="z")
        lip = thick / 2 + 0.3
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 1.2, 0.6, "white", flat="z")
    # THE MOUTH, set back under the snout: a dark slot between the upper lip and a jaw of two blocks, level, with its
    # corners turned down at the back (a frown), and four tiny teeth hanging in front of the dark
    head.block(-19.1, (-2.2, 2.2, -2.5, -1.1), -16.9, (-2.2, 2.2, -2.5, -1.1), "mouth")
    corner = (2.0, 2.95, -2.7, -1.3)
    head.block(-17.7, corner, -16.5, corner, "mouth", mirror=True)
    head.beam((-16.8, 0, -2.7), (-19.9, 0, -2.65), 5.4, 0.8, "white", flat="z")
    head.beam((-19.5, 0, -2.7), (-20.5, 0, -2.68), 3.8, 0.4, "white-", flat="z")
    for y in (0.6, 1.6):
        head.tooth(-19.35, y, -1.3, 0.4, 0.5, "white")
    # the eye: a pale oval on the side of the snout's root, an upright slit pupil standing out of it, and a lid over the
    # top third: sleepy
    head.block(-19.0, (3.6, 4.1, 0.4, 1.8), -17.0, (3.6, 4.1, 0.4, 1.8), "eye", mirror=True)
    head.block(-19.3, (3.6, 3.95, 0.75, 1.45), -16.7, (3.6, 3.95, 0.75, 1.45), "eye", mirror=True)
    head.block(-18.2, (3.6, 4.4, 0.55, 1.7), -17.8, (3.6, 4.4, 0.55, 1.7), "black", mirror=True)
    head.block(-19.6, (3.6, 4.7, 1.35, 2.3), -16.85, (3.6, 4.7, 1.35, 2.3), "ivory", mirror=True)

    segs, before = [], HEAD
    for i, (x0, x1, n, bot, top) in enumerate(SLICES):
        seg = m.part(f"S{i + 1}", (x0, 0, 0), "Head" if i == 0 else f"S{i}")
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # clear of both pieces' corner steps
        small = min(n, before[2])
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, before[3]) + 1, min(top, before[4]) - 1, "ivory-")
        segs.append(seg)
        before = (x0, x1, n, bot, top)
    s1, s2, s3, s4, s5 = segs
    parts = {HEAD: head, **dict(zip(SLICES, segs))}

    # the seat's leg slots, between the second and third saddles
    s1.dent(-10, -8, 3, 0, 2, "ivory")

    # THE MARK: the saddles, thin raised bands across the back that stop halfway down the side, and a spot between each pair
    for x in SADDLES:
        s = find(x)
        parts[s].band(x, x + 2, s[2], s[3], s[4], "choc", STEP, STEP, stop=SADDLE_STOP)
    for x in SPOTS:
        s = find(x)
        parts[s].paint_pair(x, x + 1, s[2], s[2] + 1, -1, 0, "choc")

    # the two back fins, alike: one at the middle, one at seven tenths
    dorsal(s3, -1.9)
    dorsal(s5, 7.4)
    # the side fins: broad and rounded, held flat, low on the flank behind the head
    s1.beam((-12.6, 2.6, -2.0), (-10.9, 5.9, -2.3), 3.6, 1.0, "ivory", flat="z", mirror=True)
    s1.beam((-11.4, 5.3, -2.245), (-10.2, 7.7, -2.463), 2.6, 0.6, "ivory", flat="z", mirror=True)
    s1.beam((-10.6, 7.2, -2.418), (-9.9, 8.5, -2.536), 1.5, 0.3, "ivory-", flat="z", mirror=True)
    # the belly fins and the anal fin: small
    s4.beam((4.0, 1.6, -2.2), (5.6, 3.7, -3.0), 1.8, 0.6, "ivory", flat="z", mirror=True)
    s5.beam((8.2, 0, -2.4), (9.6, 0, -3.9), 1.6, 0.7, "ivory")

    # the tail, on its own joint: a slim stock, then the long low upper lobe along a line at 20 degrees: a root piece, a
    # blade, a narrow neck at the notch, and the end lobe past it. Almost no lower lobe. Bars across it carry the saddles on
    tail = m.part("Tail", (11, 0, 0), "S5")
    tail.sym(11, 12, 1, -3, 3, "ivory")
    tail.sym(12, 14, 1, -2, 3, "ivory")
    tail.sym(14, 15, 1, -1, 2, "ivory")
    tail.paint_sym(11, 15, 1, -3, BELLY, "white")
    tail.sym(10, 11, 0, -2, 2, "ivory-")  # its sleeve
    lobe(tail, 0.0, 5.4, 0.0, 3.0, 1.6, "ivory")
    lobe(tail, 4.9, 8.4, 0.2, 2.2, 1.2, "ivory")
    lobe(tail, 7.9, 9.9, 0.4, 0.8, 0.9, "ivory")  # the neck at the notch
    lobe(tail, 9.5, 11.4, 0.6, 0.8, 0.6, "ivory")  # the end lobe's top
    lobe(tail, 9.7, 11.2, 1.1, 1.6, 0.3, "ivory-")  # its flap, hanging behind the notch
    tail.beam((14.0, 0, -0.6), (15.8, 0, -1.8), 1.4, 0.7, "ivory")  # the lower lobe: a stub
    bar(tail, 2.2, 0.0, 2.7, 1.6, 1.0)
    bar(tail, 6.6, 0.2, 2.1, 1.2, 1.0)
    bar(tail, 10.5, 0.6, 2.4, 0.6, 0.8)
