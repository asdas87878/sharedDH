"""The Hellfin Shark (zone 10's Legendary: a charred shark whose fins burn) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md). A variant of the Reef Shark (art/creatures/ReefShark/voxel.py): the same animal and the
same manner (a snout of three tilted blocks, a jaw of two, the brow past the eye, the thin gum line, fins of two or three
boxes with a collar), but bigger and built from more cubes: six body pieces of stepped slabs with three-step corners, a
skull in two slabs, more teeth.
Its idea is the fins. The body is charcoal over an ash belly and stays plain. Every fin is dark, with its trailing edge
alight: a thin ember blade lies in each box of a fin and shows behind it, stopping short of the box's end, so the edge
steps like a flame; the last box of each fin is all ember. One thin ember line runs along each flank from the skull to the
tail, just above the belly (the echo), and the eye is a dark pupil in a thin ember ring under the brow.
The rider sits on the flat of the back in front of the hump that carries the back fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Hellfin Shark", "ZONE 10 / THE UNDERWORLD", "LEGENDARY"
U = 0.45
PALETTE = {"char": "#3B3741", "ash": "#8E8389", "ember": "#FF7A1E", "black": "#1B191C", "mouth": "#752222", "gum": "#5A2A30",
           "tooth": "#F6EFE2"}
SEAT = (-5, 7, 7.5)
GLOW = {"ember": 0.9}  # the burning edges of the fins, the flank line, the ring of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["char"]}]  # studs on the dark upper body only
FRAME, ORTHO, ORTHO_SWIM = 2.7, 40.0, 46.0
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"], "amplitudes": [1.5, 3, 5, 8, 12, 18], "phaseStep": 0.8,
        "headCounter": 2}
DROP = 0.15  # how far the thin gum plate shows past its lip
LINE = (-0.7, -0.3)  # the flank line's height: just above the belly

# the body behind the head: each piece is a few slabs (from x, to x, cubes out, bottom, top)
# The back climbs in broad steps to a hump that carries the back fin, the belly sags under the middle and rises to the
# tail faster than the back falls, and the width swells and tapers too
BODY = (("S1", ((-15, -11, 6, -6, 6), (-11, -7, 6, -7, 7))),
        ("S2", ((-7, -3, 7, -8, 7), (-3, 4, 7, -8, 8))),  # the seat, then the hump with the back fin
        ("S3", ((4, 8, 7, -7, 7), (8, 12, 6, -6, 7))),
        ("S4", ((12, 16, 5, -5, 6), (16, 19, 4, -4, 6))),
        ("S5", ((19, 22, 3, -3, 5), (22, 25, 2, -3, 4), (25, 27, 2, -2, 3))))
SKULL = (5, -5, 6)  # the back of the head, where S1 joins


def top_steps(n):
    """the corners of the back: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def slab(p, x0, x1, n, bot, top, top_cut=None):
    """a length of body: stepped corners, charcoal with a lighter top row, and an ash belly four rows deep that follows
    the underside (thinner toward the tail; it never comes up to the flank line)"""
    p.hull(x0, x1, n, bot, top, "char", top_cut or top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "char+")
    p.paint_sym(x0, x1, n, bot, min(bot + 4, -1), "ash")
    if bot < -2:
        p.paint_sym(x0, x1, n, bot, bot + 1, "ash-")


def line(p, x0, x1, n):
    """the flank line: a thin ember strip, 0.3 proud of the side"""
    section = (n + 0.3, n + 0.8, LINE[0], LINE[1])
    p.block(x0, section, x1, section, "ember", mirror=True)


def fin(p, a, b, wide, thick, colour, edge=0.0, split=0.0, flat="y", mirror=False):
    """one box of a fin from a to b. edge: an ember blade lies in its trailing side and shows `edge` behind it; it is
    thinner than the box and stops short of the box's end. split: from that share of the box's length on, the blade shows
    only half as far. So a fin's burning edge goes up in steps, like a flame: wide, narrow, a notch, and the next box"""
    p.beam(a, b, wide, thick, colour, flat=flat, mirror=mirror)
    if not edge:
        return
    d = [q - s for s, q in zip(a, b)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    ref = (0.0, 1.0, 0.0) if flat == "y" else (0.0, 0.0, 1.0)
    dot = sum(s * r for s, r in zip(along, ref))
    thin = [r - dot * s for s, r in zip(along, ref)]
    size = math.sqrt(sum(v * v for v in thin))
    thin = [v / size for v in thin]
    back = [x - along[0] * s - thin[0] * t for x, s, t in zip((1.0, 0.0, 0.0), along, thin)]  # toward the tail, across the box
    size = math.sqrt(sum(v * v for v in back))
    back = [v / size for v in back]
    runs = [(0.3, split * length, edge), (split * length, length - 0.5, edge / 2)] if split else [(0.3, length - 0.5, edge)]
    for t0, t1, show in runs:
        across = show + 0.8
        off = wide / 2 + show - across / 2
        p0 = tuple(s + t0 * al + off * bk for s, al, bk in zip(a, along, back))
        p1 = tuple(s + t1 * al + off * bk for s, al, bk in zip(a, along, back))
        p.beam(p0, p1, across, thick - 0.3, "ember", flat=flat, mirror=mirror)


def build(m):
    head = m.part("Head", (-15, 0, 0))
    slab(head, -23, -19, 5, -5, 5, [(2, 1), (1, 1)])  # the skull, in two slabs: the eye sits on the side of the first
    slab(head, -19, -15, *SKULL)
    head.sym(-23, -20, 4, -5, -4, "ash-")  # the jaw's hinge: the bottom row is wider here, so the jaw's root is buried
    # the snout: three big blocks in a chain, each tilted nose-down and a step lower and narrower than the last. Each has
    # an ash lip plate underneath; the first two have a lighter plate on top, which starts past the end of the block before
    blocks = ((-22.4, -27.0, 1.6, 1.1, 8.4, 4.2, 5.2, -22.4, -22.4), (-26.2, -30.6, 1.0, 0.45, 6.6, 3.2, 3.6, -27.2, -27.3),
              (-29.8, -33.3, 0.35, -0.05, 4.6, 2.3, 0.0, 0.0, 0.0))

    def lip_bottom(k, x):
        """the underside of block k's lip plate at x"""
        x0, x1, z0, z1, _, thick = blocks[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) - thick / 2 - 0.8

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "char", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "ash", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.5, "char+", flat="z")
            mid = 0.025 - DROP / 2  # the gum plate under the lip, set in from its edge: the teeth hang from it
            head.beam((gum_from, 0, lip_bottom(k, gum_from) + mid), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) + mid), wide - 1.0, DROP + 0.05,
                      "gum", flat="z")
    # the mouth, set back under the snout and open. Its dark inside is two blocks that stay behind the teeth and end
    # inside the lips and the jaw. The lower jaw is two boxes, the smaller in front
    mouth = (-2.2, 2.2, -4.1, -1.2)
    head.block(-27.0, mouth, -22.8, mouth, "mouth")
    mouth = (-1.1, 1.1, -4.3, -1.4)
    head.block(-29.4, mouth, -27.1, mouth, "mouth")
    jaws = ((-22.9, -27.2, -4.2, -4.4, 7.2, 1.5, -22.9), (-26.5, -30.9, -4.4, -4.6, 5.0, 0.9, -27.5))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "ash", flat="z")
        mid = DROP / 2 - 0.025  # the lower gum lies inside the jaw's own edge all round
        head.beam((gum_from, 0, jaw_top(k, gum_from) + mid), (x1 + 0.35, 0, jaw_top(k, x1 + 0.35) + mid), wide - 1.0, DROP + 0.05, "gum",
                  flat="z")
    head.beam((-23.0, 0, -5.1), (-27.0, 0, -5.29), 5.0, 0.5, "ash-", flat="z")  # a chin plate under it
    # pointed teeth, each with its base sunk a little into a gum: down along each side and across the front, up from the jaw
    for k, x in ((0, -23.15), (0, -24.2), (0, -25.25), (0, -26.3), (1, -27.85), (1, -28.9)):
        head.tooth(x, (3.2, 2.3)[k], lip_bottom(k, x) - 0.05, 0.9, 1.0, "tooth")
    front = lip_bottom(1, -29.95) - 0.05
    head.tooth(-29.95, 0.0, front, 0.9, 1.05, "tooth", mirror=False)
    for y in (1.15, 2.3):
        head.tooth(-29.95, y, front, 0.9, 1.0, "tooth")
    for k, x in ((0, -24.0), (0, -25.2), (0, -26.4), (1, -28.0), (1, -29.05), (1, -30.1)):
        head.tooth(x, (2.65, 1.6)[k], jaw_top(k, x) + 0.05, 0.8, -0.7, "tooth")
    # the eye: a thin ember ring on the skull's side, a dark pupil standing out of it, under a brow box that slants down
    # to the front, cuts the top of the eye and comes past it. A slimmer block carries the brow on in front of the skull
    ring = (5.3, 5.85, -0.2, 2.0)
    head.block(-22.4, ring, -19.7, ring, "ember", mirror=True)
    pupil = (5.6, 6.15, 0.55, 1.7)
    head.block(-21.6, pupil, -20.5, pupil, "black", mirror=True)
    head.beam((-22.6, 5.6, 1.65), (-18.4, 5.6, 2.45), 1.3, 1.8, "char", mirror=True)
    head.beam((-25.2, 5.65, 1.16), (-22.2, 5.65, 1.73), 0.9, 1.2, "char", mirror=True)
    nostril = (2.0, 2.5, -0.1, 0.45)
    head.block(-32.8, nostril, -32.0, nostril, "black", mirror=True)
    line(head, -22.7, -14.7, 5)

    # the body: five pieces, each one or two slabs, with a sleeve into the piece in front so a bending joint shows body
    segs, last = {}, SKULL
    for i, (name, slabs) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slabs[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for x0, x1, n, bot, top in slabs:
            slab(seg, x0, x1, n, bot, top)
        x0, _, n, bot, top = slabs[0]
        fn, fbot, ftop = last
        up = max(len(top_steps(n)), len(top_steps(fn)))
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "char-")
        last = slabs[-1][2:]
    s1, s2, s3, s4, s5 = (segs[name] for name, _ in BODY)
    # the flank line, piece by piece. No strip ends in the plane of a slab's end: where the body keeps its width a strip
    # runs 0.3 past its piece and the next starts there; where the body narrows it stops 0.15 short of the step and the
    # next, a cube further in, starts there, inside the wider slab
    line(s1, -14.7, -6.7, 6)
    line(s2, -6.7, 4.3, 7)
    line(s3, 4.3, 7.85, 7)
    line(s3, 7.85, 11.85, 6)
    line(s4, 11.85, 15.85, 5)
    line(s4, 15.85, 18.85, 4)
    line(s5, 18.85, 21.85, 3)
    line(s5, 21.85, 26.6, 2)
    for x in (-14, -12, -10):  # gill slits: shallow lines in the side, above the flank line
        s1.dent(x, x + 1, 6, 0, 3, "char-")
    s2.dent(-6, -3, 7, 1, 4, "char-")  # the seat: a slot either side for the rider's legs

    # the fins: each a few boxes at an angle, every box smaller and thinner than the one before and starting inside it,
    # with a darker collar round the root of the big ones. The trailing edges burn; the last box is all ember
    s2.beam((1.0, 0, 5.4), (4.3, 0, 9.5), 7.7, 2.6, "char-")  # the back fin's collar: on the hump, behind the seat
    fin(s2, (1.0, 0, 5.4), (6.5, 0, 12.3), 7.0, 2.0, "char", edge=1.1, split=0.78)
    fin(s2, (5.4, 0, 11.1), (8.55, 0, 16.2), 4.8, 1.4, "char", edge=0.9, split=0.62)
    s2.beam((7.5, 0, 15.0), (9.6, 0, 18.75), 3.4, 0.8, "ember")
    s1.beam((-12.0, 4.3, -3.0), (-9.4, 7.57, -3.48), 6.9, 1.9, "char-", flat="z", mirror=True)  # the side fins' collars
    fin(s1, (-12.0, 4.3, -3.0), (-6.6, 11.1, -4.0), 6.3, 1.5, "char", edge=1.1, split=0.88, flat="z", mirror=True)
    fin(s1, (-7.5, 9.9, -3.85), (-3.9, 14.7, -4.6), 4.5, 0.9, "char", edge=1.2, split=0.62, flat="z", mirror=True)
    s1.beam((-5.1, 13.2, -4.35), (-2.4, 17.1, -4.95), 3.6, 0.3, "ember", flat="z", mirror=True)
    fin(s5, (20.2, 0, 4.0), (22.6, 0, 7.15), 2.7, 1.3, "char", edge=0.6)  # the second back fin
    s5.beam((21.55, 0, 5.95), (23.5, 0, 8.5), 2.0, 0.7, "ember")
    fin(s5, (20.2, 0, -2.0), (22.6, 0, -5.15), 2.7, 1.3, "char", edge=0.6)  # the anal fin
    s5.beam((21.55, 0, -3.95), (23.5, 0, -6.5), 2.0, 0.7, "ember")
    fin(s4, (12.6, 2.2, -3.4), (15.8, 5.0, -6.6), 3.0, 0.9, "char", edge=0.6, flat="z", mirror=True)  # the belly fins

    # the tail, on its own joint: a root block, a long upper lobe in three boxes and a short lower one in two. The fork
    # between them is where it burns
    tail = m.part("Tail", (27, 0, 0.5), "S5")
    tail.beam((26.4, 0, 0.5), (30.2, 0, 0.5), 3.8, 2.6, "char")
    fin(tail, (28.4, 0, 1.2), (32.9, 0, 8.4), 5.2, 2.0, "char", edge=1.0, split=0.68)
    fin(tail, (31.85, 0, 7.05), (36.35, 0, 14.25), 4.0, 1.4, "char", edge=0.9, split=0.62)
    tail.beam((35.15, 0, 12.75), (38.15, 0, 17.7), 3.1, 0.8, "ember")
    fin(tail, (28.4, 0, -0.2), (32.15, 0, -5.45), 4.6, 1.4, "char", edge=0.9, split=0.66)
    tail.beam((31.1, 0, -4.25), (34.1, 0, -8.75), 3.5, 0.6, "ember")
