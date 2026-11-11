"""The Goblin Shark (zone 6's Epic: the deep-sea shark with a blade for a snout) for tools/blender/voxel_kit.py
(docs/style/creature-brief.md). Designed from the real animal.
Its idea: a long, flat blade of a snout standing out over the mouth, and under it a jaw that shoots forward.
- The body is soft and flabby: thirteen lengths of slab, each one step different from the last (width, or back, or
  belly). The back arches in two broad steps to a plateau; the belly sags under the middle and rises to a thin tail stock.
- Three lines run its whole length: the lighter top row, a thin darker line where the pink meets the pale belly, and the
  belly itself.
- The head: a low skull that steps down at the front, and the blade, three flat blocks in a chain, each thinner and
  narrower than the last and tilted a little nose-down, with a lighter plate along the top.
- The jaw is its own part, set in a recess under the skull: a pale block at the mouth's corner, two jaws in two boxes
  each, needle teeth on a thin gum line, and behind it a rose sleeve that stays hidden in the throat until the jaw
  shoots out. It slides by turning about a pivot far below it (the game's swim keeps only turns), so it goes forward
  and a little down, as the real one does.
- Small dark eyes under a short slanting brow. Low, rounded fins with darker tips; a long, low upper tail lobe.
The rider sits on the plateau behind the gills, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Goblin Shark", "ZONE 6 / TWILIGHT", "EPIC"
U = 0.45
PALETTE = {"pink": "#E9A3AA", "belly": "#F8DDD8", "black": "#2A2530", "mouth": "#6E2836", "gum": "#B4566A", "tooth": "#FFFFFF"}
SEAT = (-1, 5, 4.6)
FRAME, ORTHO = 2.05, 30.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["pink"]}]

LINE = -1  # the height of the thin line where the pink meets the belly
# the body: parts, each of a few lengths (from, to, cubes out, bottom, top). One number changes from one to the next
SKULL = (-18, -13, 3, -3, 3)
BODY = (("S1", ((-13, -11, 4, -3, 3), (-11, -9, 4, -4, 3), (-9, -6, 4, -4, 4))),
        ("S2", ((-6, -3, 4, -5, 4), (-3, 1, 4, -5, 5))),
        ("S3", ((1, 4, 4, -4, 5), (4, 6, 4, -4, 4))),
        ("S4", ((6, 8, 3, -4, 4), (8, 10, 3, -3, 4))),
        ("S5", ((10, 12, 3, -3, 3), (12, 14, 2, -3, 3), (14, 15, 2, -2, 3), (15, 16, 2, -2, 2))))
STOCK = (16, 18, 1, -1, 2)  # the tail's stock
CHAIN = ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"]
AMPLITUDES = [2, 4, 6, 9, 12, 18]
JAW_PIVOT = (-17.0, 0.0, -38.0)  # far below the jaw: a small turn about it is a slide
JAW_SLIDE = 3.0  # cubes


def pose(parts, phase):
    """a shark's swim, side to side down the chain; once a beat the jaw shoots out under the blade and draws back"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.9 * (k + 1))
    out = (0.5 + 0.5 * math.sin(phase)) ** 3
    parts["Jaw"].rotation_euler.y = -math.asin(JAW_SLIDE / (-2.4 - JAW_PIVOT[2])) * out


def steps(n):
    """the corners: two steps where the body is thick, one where it is thin, none on the tail's stock"""
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def slab(p, x0, x1, n, bot, top):
    """a length of body: stepped corners, a lighter top row, a thin darker line over a pale belly"""
    p.hull(x0, x1, n, bot, top, "pink", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "pink+")
    p.paint_sym(x0, x1, n, LINE, LINE + 1, "pink-")
    p.paint_sym(x0, x1, n, bot, LINE, "belly")
    if bot <= -3:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def build(m):
    head = m.part("Head", (-13, 0, 0))
    slab(head, *SKULL)
    head.carve(-18, -16, -3, 4, 2, 3)  # the skull steps down at the front, where the blade comes out of it
    head.paint_sym(-18, -16, 3, 1, 2, "pink+")
    head.carve(-18, -15, -3, 4, -3, -1)  # the recess the jaw sits in
    # the blade: three flat blocks in a chain, each tilted a little nose-down, thinner and narrower than the last and
    # starting inside it. A lighter plate runs along the top of the first two
    blades = ((-14.5, -20.5, 1.8, 1.0, 4.4, 2.2, 2.6, -16.3), (-19.5, -24.0, 1.2, 0.95, 3.6, 1.3, 2.0, -20.9), (-23.2, -27.0, 1.05, 0.9, 2.6, 0.8, 0.0, 0.0))
    for x0, x1, z0, z1, wide, thick, plate, plate_from in blades:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "pink", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.5, "pink+", flat="z")
    # the eye: small and dark, on the side of the skull, under a short brow that slants down to the front and comes past it
    eye = (3.3, 3.8, 0.0, 1.0)
    head.block(-17.4, eye, -16.2, eye, "black", mirror=True)
    head.beam((-17.8, 3.45, 0.85), (-15.7, 3.45, 1.3), 0.7, 1.0, "pink", mirror=True)

    # the jaw, its own part: it slides out from under the skull. A pale block at the mouth's corner holds the two jaws;
    # behind it a rose sleeve reaches back into the throat, and shows only when the jaw is out
    jaw = m.part("Jaw", JAW_PIVOT, "Head")
    corner = (-3.0, 3.0, -3.3, -1.1)
    jaw.block(-16.6, corner, -15.0, corner, "belly")
    sleeve = (-2.1, 2.1, -2.65, -1.4)
    jaw.block(-16.0, sleeve, -11.5, sleeve, "gum")
    # the dark inside of the mouth, two blocks that stay behind the teeth and end inside the jaws
    inside = (-1.6, 1.6, -2.7, -1.8)
    jaw.block(-17.8, inside, -15.8, inside, "mouth")
    jaw.block(-19.2, (-0.55, 0.55, -3.3, -1.95), -17.6, (-0.55, 0.55, -3.0, -1.95), "mouth")
    upper = ((-16.0, -18.6, -1.65, -1.75, 5.2, 0.7), (-18.0, -19.9, -1.75, -1.8, 3.4, 0.36))
    lower = ((-16.0, -18.4, -2.75, -3.2, 4.8, 0.7), (-17.8, -19.5, -3.09, -3.5, 3.0, 0.36))  # it hangs open a little, hinged at the corner

    def edge(jaws, k, x, side):
        """the underside (side -1) or the top (side 1) of jaw block k at x"""
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + side * thick / 2

    for jaws, side in ((upper, -1), (lower, 1)):
        for k, (x0, x1, z0, z1, wide, thick) in enumerate(jaws):
            jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
            a, b = x0 - 0.6 - 0.05 * k, x1 + 0.3  # a thin gum line, set inside the lip's edge
            jaw.beam((a, 0, edge(jaws, k, a, side) + side * 0.05), (b, 0, edge(jaws, k, b, side) + side * 0.05), wide - 0.6, 0.2, "gum", flat="z")
    # needle teeth, their bases sunk in the gums: long ones down from the upper jaw, shorter ones up between them
    for k, x, y, long in ((0, -16.9, 2.0, 0.7), (0, -17.5, 2.0, 0.8), (0, -18.05, 2.0, 0.85), (1, -19.15, 1.1, 0.95), (1, -19.35, 0.4, 1.0)):
        jaw.tooth(x, y, edge(upper, k, x, -1) - 0.05, 0.4, long, "tooth")
    for k, x, y, long in ((0, -17.2, 1.8, 0.6), (0, -17.82, 1.8, 0.65), (1, -18.95, 0.9, 0.7)):
        jaw.tooth(x, y, edge(lower, k, x, 1) + 0.05, 0.4, -long, "tooth")

    # the body
    front, parent, segs = SKULL, "Head", {}
    for name, lengths in BODY:
        seg = segs[name] = m.part(name, (lengths[0][0], 0, 0), parent)
        for span in lengths:
            slab(seg, *span)
        # a sleeve one cube into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        x0, _, n, bot, top = lengths[0]
        fn, fbot, ftop = front[2:]
        deep = max(len(steps(n)), len(steps(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + deep, min(top, ftop) - deep, "pink-")
        front, parent = lengths[-1], name
    for x in (-12, -10):  # gill slits
        segs["S1"].dent(x, x + 1, 4, 0, 1, "pink-")
    segs["S2"].dent(-2, 0, 4, 1, 3, "pink-")  # the rider's leg slots

    # the fins: low and rounded, each two boxes, the second smaller, thinner and darker and starting inside the first
    segs["S1"].beam((-8.6, 2.2, -2.4), (-5.8, 6.4, -3.3), 3.2, 1.0, "pink", flat="z", mirror=True)  # the side fins
    segs["S1"].beam((-6.4, 5.6, -3.15), (-4.4, 8.4, -3.75), 2.3, 0.6, "pink-", flat="z", mirror=True)
    segs["S3"].beam((2.4, 0, 3.6), (5.2, 0, 5.9), 3.0, 1.2, "pink")  # the first back fin
    segs["S3"].beam((4.5, 0, 5.3), (6.3, 0, 6.3), 2.0, 0.8, "pink-")
    segs["S5"].beam((11.6, 0, 1.8), (13.6, 0, 4.3), 2.4, 0.9, "pink")  # the second
    segs["S5"].beam((13.0, 0, 3.7), (14.4, 0, 5.0), 1.6, 0.6, "pink-")
    segs["S4"].beam((7.0, 1.2, -3.0), (9.2, 3.2, -5.0), 2.4, 0.7, "pink", flat="z", mirror=True)  # the belly fins
    segs["S5"].beam((11.8, 0, -1.6), (13.8, 0, -4.0), 2.6, 0.9, "pink")  # the anal fin
    segs["S5"].beam((13.2, 0, -3.4), (14.4, 0, -4.7), 1.7, 0.6, "pink-")

    # the tail, on its own joint: a short stock, a long low upper lobe in three boxes, and only a nub underneath
    tail = m.part("Tail", (STOCK[0], 0, 0), "S5")
    slab(tail, *STOCK)
    tail.sym(STOCK[0] - 1, STOCK[0], 0, 0, 1, "pink-")
    tail.beam((17.1, 0, 0.6), (21.0, 0, 2.7), 3.0, 1.3, "pink")
    tail.beam((20.2, 0, 2.3), (24.0, 0, 4.1), 2.6, 0.9, "pink")
    tail.beam((23.2, 0, 3.75), (26.4, 0, 5.3), 1.9, 0.5, "pink-")
    tail.beam((17.0, 0, 0.2), (18.8, 0, -1.6), 2.0, 0.8, "pink-")
