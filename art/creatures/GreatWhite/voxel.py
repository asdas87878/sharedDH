"""The Great White (zone 3's Epic: the classic great white shark) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md). Designed from the real animal: the Reef Shark's bigger, heavier cousin, not a copy of it.
Its idea: the heavyweight. A thick slate torpedo over a white belly, a blunt cone of a snout full of teeth, old scars.
- The body is a torpedo in slices, thirteen cubes across and thirteen deep at the back fin, its corners cut in three
  steps where it is thick. From one slice to the next ONE thing changes by one cube (the width, the back or the belly),
  so each outline makes its own staircase: the back climbs from the brow to the fin and falls to the tail.
- One clean edge runs the whole length at one height: slate grey above it, white below, from the lip to the tail's root.
  Only the five gill slits cross it.
- The snout is a blunt cone of big tilted blocks in a chain: three low wide ones that carry the lip, each narrower and a
  step lower than the last, and two narrower ones on top of them, so its section steps in like the body's corners. The
  jaw is two boxes set back under it (a shark's underslung jaw), the mouth open on two rows of triangular teeth, with
  a thin dark gum line set inside the lips.
- A small black eye under a brow box that slants down to the front and comes past it.
- Five gill slits as shallow dents; plain fins of two or three boxes: a tall triangular back fin (its rear edge near
  upright, its front edge stepping back), long side fins, a crescent tail with nearly equal lobes on a flat, wide stock.
- Three pale scars: a long slash on the left flank, one across the forehead, two nicks on the right near the tail.
The rider sits behind the gills, in front of the back fin, legs in a slot either side."""
NAME, ZONE, RARITY = "Great White", "ZONE 3 / KELP FOREST", "EPIC"
U = 0.45
PALETTE = {"grey": "#62707C", "white": "#F2F0EA", "black": "#1F2226", "mouth": "#7A2E33", "tooth": "#FFFFFF", "gum": "#9A4F58"}
SEAT = (-4, 6, 6.6)
FRAME, ORTHO = 2.2, 31.0
TEXTURES = [{"tile": "stud", "on": "all", "colours": ["grey"]}]  # round studs on every face of the grey back
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"], "amplitudes": [1.5, 3, 5, 8, 12, 18], "phaseStep": 0.8,
        "headCounter": 2}
EDGE = 0  # the height of the edge between the grey back and the white belly, the whole length
DROP = 0.15  # how far a gum plate shows past its lip

# the body in slices (from, to, cubes out, bottom, top). One number changes from slice to slice, never two. The head's two
# slices first, then the parts behind it, each a run of slices
SKULL = ((-21, -18, 5, -5, 5), (-18, -16, 5, -5, 6))
BODY = (("S1", ((-16, -6, 6, -5, 6),)),  # the gills
        ("S2", ((-6, -2, 6, -6, 6), (-2, 5, 6, -6, 7))),  # the seat, then the back fin
        ("S3", ((5, 7, 6, -6, 6), (7, 8, 6, -5, 6), (8, 9, 5, -5, 6), (9, 11, 5, -5, 5), (11, 12, 5, -4, 5))),
        ("S4", ((12, 13, 4, -4, 5), (13, 15, 4, -4, 4), (15, 16, 4, -3, 4), (16, 17, 3, -3, 4), (17, 18, 3, -3, 3))),
        ("S5", ((18, 19, 3, -2, 3), (19, 20, 2, -2, 3), (20, 21, 2, -2, 2), (21, 23, 2, -1, 2))))  # ends in the tail's flat stock


def steps(n):
    """the corners of the back and the belly: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, grey with a lighter top row, white below the edge with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "grey", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "grey+")
    p.paint_sym(x0, x1, n, bot, EDGE, "white")
    p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


def build(m):
    head = m.part("Head", (SKULL[-1][1], 0, 0))
    for s in SKULL:  # the back of the head: the eye sits on its side
        slab(head, *s)
    head.sym(-21, -19, 4, -5, -4, "white-")  # the jaw's hinge: the bottom row is wider here, so the jaw's root is buried
    # the snout, a blunt cone: three low, wide blocks in a chain, each tilted nose-down, narrower, and a step lower on top
    # than the last, with a white lip plate underneath; the underside rises a little to the tip. (from, to, the middle's
    # height at each end, width, thickness, where its gum starts)
    blocks = ((-20.5, -24.0, 1.35, 1.05, 9.6, 2.7, -20.5), (-23.4, -26.3, 1.15, 0.9, 7.4, 2.1, -24.3), (-25.4, -28.0, 1.325, 1.1, 5.0, 2.35, 0.0))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        """the underside of block k's lip plate at x"""
        return middle(k, x) - blocks[k][5] / 2 - 0.8

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "grey", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "white", flat="z")
        if gum_from:  # a thin gum plate under the lip, set in from its edge, that the teeth hang from
            mid = 0.025 - DROP / 2
            head.beam((gum_from, 0, lip_bottom(k, gum_from) + mid), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) + mid), wide - 1.0, DROP + 0.05,
                      "gum", flat="z")
    # the top of the cone: two narrower, lighter blocks lying on the first two, each starting inside the one behind, so the
    # snout's section steps in like the body's corners and its top comes down to the tip in three steps
    for k, x0, x1, wide, thick in ((0, -20.5, -23.8, 6.6, 1.9), (1, -23.2, -25.7, 5.4, 1.3)):
        rise = blocks[k][5] / 2 + thick / 2 - 0.05
        head.beam((x0, 0, middle(k, x0) + rise), (x1, 0, middle(k, x1) + rise), wide, thick, "grey+", flat="z")
    # the mouth, set back under the snout and open. Its dark inside is two blocks that stay behind the teeth and end
    # inside the lips and the jaw. The lower jaw is two boxes, the smaller in front, ending well short of the snout's tip
    mouth = (-2.8, 2.8, -3.0, -0.6)
    head.block(-23.8, mouth, -20.8, mouth, "mouth")
    mouth = (-1.9, 1.9, -2.9, -0.45)
    head.block(-24.6, mouth, -23.9, mouth, "mouth")
    jaws = ((-20.9, -24.0, -3.4, -3.25, 8.4, 1.6, -20.9), (-23.4, -25.9, -3.25, -2.95, 6.2, 1.1, -24.3))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "white", flat="z")
        mid = DROP / 2 - 0.025  # the lower gum lies inside the jaw's own edge all round
        head.beam((gum_from, 0, jaw_top(k, gum_from) + mid), (x1 + 0.35, 0, jaw_top(k, x1 + 0.35) + mid), wide - 1.0, DROP + 0.05, "gum",
                  flat="z")
    # triangular teeth, each with its base sunk a little into a gum: a row down each side and across the front of the
    # upper lip, a row up from the lower jaw that stands a little inside it
    for k, x in ((0, -21.4), (0, -22.25), (0, -23.1), (1, -24.75)):
        head.tooth(x, (3.9, 2.8)[k], lip_bottom(k, x) - DROP + 0.1, 0.8, 0.85, "tooth")
    front = lip_bottom(1, -25.6) - DROP + 0.1
    head.tooth(-25.6, 0.0, front, 0.75, 0.9, "tooth", mirror=False)
    for y in (0.8, 1.6, 2.4):
        head.tooth(-25.6, y, front, 0.75, 0.85, "tooth")
    for x in (-21.6, -22.4, -23.2):
        head.tooth(x, 3.35, jaw_top(0, x) + DROP - 0.1, 0.7, -0.6, "tooth")
    front = jaw_top(1, -25.15) + DROP - 0.1
    head.tooth(-25.15, 0.0, front, 0.7, -0.6, "tooth", mirror=False)
    for y in (0.8, 1.6):
        head.tooth(-25.15, y, front, 0.7, -0.6, "tooth")
    # the eye: a small black block on the side of the head, under a brow box that slants down to the front. The brow comes
    # past the eye in front and behind and cuts across its top, so the shark scowls; it stands a little proud of the eye
    head.pair(-20, -18, 6, 7, 1, 3, "black")
    head.beam((-20.9, 5.7, 2.55), (-17.2, 5.7, 3.35), 1.3, 2.6, "grey", mirror=True)
    # the part in front of the eye: a slimmer block on the same line, starting inside the first and ending on the snout
    head.beam((-22.2, 5.75, 2.28), (-20.4, 5.75, 2.66), 0.9, 2.1, "grey", mirror=True)
    # a pale scar across the forehead (the rider sees this one)
    for x, y in ((-20, -2), (-19, -1), (-18, 0), (-17, 1)):  # it climbs the step in the forehead
        head.paint(x, x + 1, y, y + 1, 4 if x < -18 else 5, 5 if x < -18 else 6, "white-")

    segs, before = {}, SKULL[-1]
    for i, (name, slices) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top = slices[0]
        _, _, fn, fbot, ftop = before
        clear = max(len(steps(n)), len(steps(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "grey-")
        before = slices[-1]
    s1, s2, s3, s4, s5 = (segs[name] for name, _ in BODY)

    for x in (-15, -13, -11, -9, -7):  # five gill slits: shallow lines in the side, across the edge
        s1.dent(x, x + 1, 6, -1, 2, "grey-")
    # the seat: behind the gills, in front of the back fin, with a slot either side for the rider's legs (in the body's
    # own grey, so it isn't read as a sixth gill)
    s2.dent(-5, -3, 6, 0, 3, "grey")
    # old scars, pale: a long slash on the left flank, two nicks on the right near the tail
    for x, z in ((-1, 3), (0, 3), (1, 2), (2, 2), (3, 1), (4, 1)):
        s2.paint(x, x + 1, -6, -5, z, z + 1, "white-")
    for x, z in ((9, 2), (10, 1)):
        s3.paint(x, x + 1, 5, 6, z, z + 1, "white-")
    for x, z in ((13, 1), (14, 0)):
        s4.paint(x, x + 1, 4, 5, z, z + 1, "white-")

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it,
    # the first starting deep enough in the body that its whole end is buried.
    # The back fin: a tall triangle. Its three boxes stand nearly upright and line up at the rear, so the rear edge is one
    # near-upright line and the front edge steps back to the point
    s2.beam((1.2, 0, 5.4), (2.5, 0, 10.2), 6.4, 1.5, "grey")
    s2.beam((2.96, 0, 9.0), (4.2, 0, 12.4), 4.2, 1.0, "grey")
    s2.beam((4.4, 0, 11.6), (5.8, 0, 14.6), 2.6, 0.6, "grey-")
    # the side fins: long, swept back and a little down, from low on the flank under the last gill slits
    s1.beam((-11.6, 3.8, -2.2), (-6.8, 10.2, -3.3), 5.4, 1.4, "grey", flat="z", mirror=True)
    s1.beam((-7.6, 9.2, -3.13), (-4.8, 12.3, -3.8), 3.8, 0.9, "grey", flat="z", mirror=True)
    s1.beam((-5.5, 11.52, -3.63), (-3.6, 13.5, -4.15), 2.5, 0.5, "grey-", flat="z", mirror=True)
    s3.beam((9.2, 1.8, -3.6), (11.6, 4.4, -5.8), 2.4, 0.7, "white-", flat="z", mirror=True)  # the belly fins
    s4.beam((15.6, 0, 3.0), (17.2, 0, 5.2), 1.9, 0.9, "grey")  # the second back fin: tiny on a great white
    s4.beam((16.6, 0, -2.0), (18.0, 0, -4.0), 1.7, 0.8, "white-")  # the anal fin, as small

    # the tail, on its own joint: a short square stock of cubes that carries on from the body's flat end, all grey (the
    # belly's edge stops at the tail's root), then a crescent of two lobes, nearly equal, each in three boxes that sweep back more toward the tip. The lobes'
    # roots and the fork between them lie wholly inside the stock
    tail = m.part("Tail", (23, 0, 0.5), "S5")
    tail.sym(23, 27, 1, -1, 2, "grey")
    tail.sym(22, 23, 0, 0, 1, "grey-")  # its sleeve
    tail.beam((24.6, 0, 1.0), (26.3, 0, 5.4), 4.8, 1.3, "grey")
    tail.beam((25.9, 0, 4.5), (27.8, 0, 7.8), 3.6, 0.9, "grey")
    tail.beam((27.4, 0, 7.1), (29.0, 0, 9.2), 2.4, 0.55, "grey-")
    tail.beam((24.6, 0, 0.0), (26.1, 0, -4.0), 4.4, 1.0, "grey")
    tail.beam((25.7, 0, -3.1), (27.4, 0, -6.0), 3.3, 0.7, "grey")
    tail.beam((27.0, 0, -5.35), (28.5, 0, -7.2), 2.2, 0.4, "grey-")
