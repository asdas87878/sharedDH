"""The Storm Serpent, a trial of docs/style/11-rare-wow-study.md (Remodels, round 1), for tools/blender/voxel_kit.py. It
stands beside the game's Storm Serpent (art/creatures/StormSerpent) and replaces nothing.
Its idea, which is its name: a storm cloud drawn out into a serpent, with the lightning still in it.
- The body keeps the old model's seventeen slices on joints: a nearly level back, a belly keel that sweeps down to a wide
  chest and up again, the head and tail carried high. It swims side to side like a sea snake.
- Colour as a thunderhead is coloured: electric royal blue flanks in three values over a dark navy belly (a storm is dark
  underneath), and on top a shell of four big faceted cloud masses, pale with lilac puffs, the biggest (behind the
  rider) about half the body's height above the back. None at the seat.
- The lightning is glow in wide shapes (about a quarter of the side view): one bolt down each flank in four long
  straight strokes with sharp turns (a long dive from the eye under the rider, a short sharp rise, a long fall, a rise
  along the tail), each slice carrying its own straight block of it, 2 cubes tall and a little proud, so it breaks at the
  joints as it swims; one fork. Bolt spines stand out of the gaps between the cloud masses. The eyes glow and the bolt
  starts at them; the mouth is lit inside; the horns and the forked tail end in light, and the bolt jumps a gap past
  each tip (loose chips of light).
- The head is the old viper's wedge: a skull wider than the neck, a snout of three blocks stepping down and in, two horns
  swept back and out like bolts, a scowling brow, two long fangs.
The rider sits on the shoulders, legs in a slot either side, above the bolt."""
import math

NAME, ZONE, RARITY = "Storm Serpent (trial)", "ZONE 5 / OPEN BLUE", "SECRET"
U = 0.45
PALETTE = {"royal": "#1F5BFF", "navy": "#17246E", "cloud": "#ECEAFF", "lilac": "#BDB6F4", "bolt": "#FFEA7A",
           "pupil": "#121433", "tooth": "#FFFFFF"}
SHADE = 0.9
SEAT = (-15.5, 5, 4.6)
GLOW = {"bolt": 0.9}  # the lightning: the flank bolts and forks, the crest bolts, the eyes, the mouth, the horn and tail tips
KEEP = ["pupil", "tooth"]
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["royal"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.2, 46.0, 52.0

# the body: each slice is (length, cubes out, bottom, top, how high the dark belly comes): the old model's numbers
SLICES = ((3, 3, 0, 6, 2), (4, 3, -1, 6, 1), (4, 4, -2, 6, 0), (4, 4, -3, 5, -1), (5, 4, -4, 5, -1), (5, 5, -5, 5, -2),
          (5, 5, -5, 5, -2), (5, 4, -4, 5, -1), (4, 4, -4, 4, -1), (4, 4, -3, 4, -1), (4, 3, -3, 4, -1), (4, 3, -2, 4, 0),
          (3, 3, -1, 4, 0), (3, 2, -1, 4, 0), (3, 2, 0, 4, 1), (3, 2, 1, 5, 2), (3, 1, 2, 5, 3))
HZ, TZ = 3, 3  # how high the head and the tail are carried
BODY_FROM = -33
SEAT_SLICE = 4
DENT = (-17, -14, 1, 3)  # the rider's leg slot on the seat slice: x from, x to, z from, z to
# the crest: four big cloud masses, (slice, height above the back as a share of 10 cubes, how long, how far the back
# puff reaches), the biggest
# behind the rider about half the body's height; none at the seat. Bolts of light stand out of the gaps between them:
# (slice, x on it, size)
MASSES = ((2, 0.36, 1.0, 0), (6, 0.46, 1.15, 1.0), (9, 0.4, 1.0, 1.0), (12, 0.3, 0.85, 1.0))
SPINES = ((8, -0.5, 1.2), (11, 0.5, 1.05), (14, 1.5, 0.85))
# the flank bolt: four long straight strokes with sharp turns, (x, height of its centre) at each end and turn: from the
# eye a long dive under the rider to the chest, a sharp short rise, a long fall, and a rise along the tail. Each slice carries its own
# straight piece of a stroke, so the bolt breaks at the joints as it swims
BOLT = ((-37.5, 4.3), (-8.2, -2.4), (-3.2, 1.4), (9.8, -0.4), (32.5, 3.6))
FORK = ((-2.4, 0.8), (1.6, -1.5))  # one fork, from the high turn back and down toward the belly
FLOATING = ["Sparks", "TailSparks"]  # the bolt jumps a gap: a loose chip of light past each horn, the head bolt, the tail's ends
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 12]


def pose(parts, phase):
    """a sea snake's swim: the wave runs down the chain from side to side, small at the shoulders where the rider sits,
    wide at the tail. The head turns a little against it"""
    parts["Head"].rotation_euler.z = math.radians(3) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))


def top_steps(n):
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n >= 3 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def wall(n, bot, top):
    """the flat side of a slice, between its corner steps"""
    return bot + len(bottom_steps(n)), top - len(top_steps(n))


def half_tall(n):
    """half the flank bolt's height: over two cubes on the body, thinner down the tail"""
    return 1.05 if n >= 4 else (0.95 if n == 3 else (0.8 if n == 2 else 0.65))


def bolt_piece(p, xa, xb, za, zb, hw, n, proud=0.8):
    """a straight piece of a stroke on both flanks: a block from (xa, za) to (xb, zb), 2 hw tall, standing a little
    proud of the flat side. It reaches 0.8 into the body, so it stays buried where it runs over the first corner step"""
    a, b = (n - 0.8, n + proud, za - hw, za + hw), (n - 0.8, n + proud, zb - hw, zb + hw)
    p.block(xa, a, xb, b, "bolt", mirror=True)


def stroke_z(points, x):
    for (xa, za), (xb, zb) in zip(points, points[1:]):
        if xa <= x <= xb:
            return za + (zb - za) * (x - xa) / (xb - xa)
    return None


def slab(p, x0, x1, n, bot, top, edge):
    """a slice of body: stepped corners, royal blue (lighter on the top row), a dark navy belly up to `edge`"""
    p.hull(x0, x1, n, bot, top, "royal", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "royal+")
    p.paint_sym(x0, x1, n, bot, edge, "navy")
    if bottom_steps(n):
        p.paint_sym(x0, x1, n, bot, bot + 1, "navy-")


def puff(p, rings, colour):
    """a faceted cloud puff: a stack of level rectangles (x from, x to, half width, z), the middle one widest, joined by
    flat facets, like a chamfered block"""
    verts = []
    for xa, xb, w, z in rings:
        verts += [(xa, -w, z), (xb, -w, z), (xb, w, z), (xa, w, z)]
    last = 4 * (len(rings) - 1)
    faces = [(0, 1, 2, 3), (last, last + 1, last + 2, last + 3)]
    for a in range(0, last, 4):
        b = a + 4
        faces += [(a, a + 1, b + 1, b), (a + 1, a + 2, b + 2, b + 1), (a + 2, a + 3, b + 3, b + 2), (a + 3, a, b, b + 3)]
    p.solid(verts, faces, colour)


def mass(p, x0, x1, top, h, s, half, front=True, rear=1.0):
    """a big storm-cloud mass on the back: a large pale faceted puff with a second one rising from its back, its root sunk
    in the slice's top, a
    lilac puff low behind it and (unless the rider sits in front) another low in front, long enough to overlap the next
    mass. rear: how far the back puff reaches"""
    xa, xb = x0 + 0.4, x1 - 0.4
    w = half + 0.8
    puff(p, [(xa, xb, half - 0.5, top - 0.8), (xa - 2.4 * s, xb + 2.6 * s, w, top + 0.35 * h),
             (xa - 1.4 * s, xb + 2.2 * s, 0.85 * w, top + 0.75 * h), (xa + 0.4 * s, xb + 1.2 * s, 0.5 * w, top + h)], "cloud")
    # a second billow rising out of the back of the first, so the top line is a cumulus's double bump
    puff(p, [(xa + 1.0 * s, xb + 0.6 * s, 0.45 * w, top + 0.55 * h), (xa + 0.6 * s, xb + 2.0 * s, 0.66 * w, top + 0.9 * h),
             (xa + 1.4 * s, xb + 1.5 * s, 0.3 * w, top + 1.12 * h)], "cloud")
    bh = 0.72 * h
    if rear:
        puff(p, [(xb - 1.6, xb - 0.2, half - 0.9, top - 1.0), (xb - 0.6, xb + 4.6 * s * rear, w - 0.7, top + 0.4 * bh),
                 (xb + 0.4 * s, xb + 3.8 * s * rear, 0.36 * w, top + bh)], "lilac")
    if front:
        fh = 0.65 * h
        puff(p, [(xa + 0.2, xa + 1.6, half - 1.0, top - 1.1), (xa - 4.2 * s, xa + 0.8, w - 1.05, top + 0.45 * fh),
                 (xa - 3.4 * s, xa + 0.2, 0.32 * w, top + fh)], "lilac")


def crest_bolt(p, x, zb, s):
    """a bolt standing up like the lightning sign, its root at height zb (sunk in the back or a cloud): a stroke leaning
    forward, then a longer one kinked back, each starting inside the one before. Returns its tip and the way it points"""
    z = zb - 1.6 * s
    a0, a1 = (x + 1.5 * s, 0, z + 1.6 * s), (x + 0.7 * s, 0, z + 4.2 * s)
    b0, b1 = (x + 0.5 * s, 0, z + 3.25 * s), (x + 2.8 * s, 0, z + 6.0 * s)
    p.beam(a0, a1, max(1.6 * s, 1.2), 0.9, "bolt")
    p.beam(b0, b1, max(1.1 * s, 0.9), 0.6, "bolt")
    return b1, (b1[0] - b0[0], b1[2] - b0[2])


def build(m):
    head = m.part("Head", (BODY_FROM, 0, HZ))
    # the skull: wider than the neck behind it, dark under the jaw line
    skull = (4, HZ - 3, HZ + 4)
    head.hull(-40, BODY_FROM, 4, HZ - 3, HZ + 4, "royal", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-40, BODY_FROM, 4, HZ + 3, HZ + 4, "royal+")
    head.paint_sym(-40, BODY_FROM, 4, HZ - 3, HZ - 1, "navy")
    head.paint_sym(-40, BODY_FROM, 4, HZ - 3, HZ - 2, "navy-")
    # the snout: three blocks in a chain, each tilted nose-down, a step lower and narrower than the last, each with a dark
    # lip plate underneath; the first two have a lighter plate on top, which starts past the end of the block before
    blocks = ((-39.5, -43.0, 1.1, 0.7, 7.4, 3.4, 4.4, -39.5), (-42.4, -45.4, 0.75, 0.35, 5.6, 2.7, 3.0, -43.8),
              (-44.8, -47.0, 0.4, 0.15, 3.8, 2.0, 0.0, 0.0))
    blocks = tuple((b[0], b[1], b[2] + HZ, b[3] + HZ) + b[4:] for b in blocks)

    def lip_bottom(k, x):
        x0, x1, z0, z1, _, thick = blocks[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) - thick / 2 - 0.8

    for x0, x1, z0, z1, wide, thick, plate, plate_from in blocks:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "royal", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "navy", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.5, "royal+", flat="z")
    # the mouth: open a little, lit inside like the heart of a storm. The light is two blocks that end inside the lips
    # and the jaw; the lower jaw is two dark boxes, the smaller in front, hanging below the lip
    mouth = (-2.8, 2.8, HZ - 2.8, HZ - 1.1)
    head.block(-43.0, mouth, -38.5, mouth, "bolt")
    mouth = (-1.5, 1.5, HZ - 3.3, HZ - 1.3)
    head.block(-45.4, mouth, -42.8, mouth, "bolt")
    head.beam((-38.8, 0, HZ - 2.95), (-43.2, 0, HZ - 3.2), 6.4, 1.1, "navy", flat="z")
    head.beam((-42.6, 0, HZ - 3.15), (-45.8, 0, HZ - 3.35), 4.2, 0.7, "navy", flat="z")
    # two long fangs from the upper lip, leaning out past the jaw, and two short ones from the jaw
    head.tooth(-44.6, 2.1, lip_bottom(1, -44.6) + 0.15, 0.85, 2.0, "tooth", lean=(0.2, 0.3))
    head.tooth(-42.4, 2.3, HZ - 2.7, 0.7, -1.0, "tooth", lean=(0.1, 0.1))
    # the eye glows: a block of light with a dark slit at its front, under a dark brow box that slants down to the front
    # and comes past it
    eye = (4.2, 5.0, HZ - 0.1, HZ + 2.0)
    head.block(-39.6, eye, -37.1, eye, "bolt", mirror=True)
    pupil = (4.8, 5.3, HZ + 0.2, HZ + 1.6)
    head.block(-39.2, pupil, -38.6, pupil, "pupil", mirror=True)
    head.beam((-40.6, 4.5, HZ + 1.55), (-36.4, 4.5, HZ + 2.55), 1.2, 2.2, "navy", mirror=True)
    # the horns: swept back and out, each a pale root like the cloud shell and a kinked end of light
    head.beam((-36.8, 2.4, HZ + 2.0), (-32.2, 4.4, HZ + 5.5), 1.7, 1.2, "lilac", mirror=True)
    head.beam((-33.6, 3.8, HZ + 4.4), (-28.8, 5.7, HZ + 6.0), 1.5, 0.7, "bolt", mirror=True)
    # a big bolt stands out of the skull behind the eyes
    tip, way = crest_bolt(head, -37.6, HZ + 3.5, 1.2)
    # the bolts jump a gap: a loose chip of light past the end of each horn and of the head bolt, turned a little
    sparks = m.part("Sparks", (BODY_FROM, 0, HZ), "Head")
    sparks.beam((-27.9, 6.15, HZ + 6.7), (-26.6, 6.8, HZ + 8.1), 1.1, 0.5, "bolt", mirror=True)
    d = math.hypot(*way)
    ux, uz = way[0] / d, way[1] / d
    sparks.beam((tip[0] + 0.9 * ux, 0, tip[2] + 0.9 * uz + 0.3), (tip[0] + 2.4 * ux - 0.4, 0, tip[2] + 2.4 * uz + 0.6), 1.1, 0.5, "bolt")
    # the flank bolt begins at the glowing eye
    bolt_piece(head, -37.5, BODY_FROM - 0.2, BOLT[0][1], stroke_z(BOLT, BODY_FROM - 0.2), 1.05, 4)

    # the body: seventeen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top, edge) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top, edge))
        x += length
    end = x

    for i, (seg, (x0, x1, n, bot, top, edge)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top, edge)
        # a sleeve into the piece in front, so a bending joint shows body: one cube inside the flat sides both pieces
        # share, or, where there is no such room, a core clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else skull
        small = min(n, fn)
        low = max(wall(n, bot, top)[0], wall(fn, fbot, ftop)[0] if i else fbot + 1) + 1
        high = min(wall(n, bot, top)[1], wall(fn, fbot, ftop)[1]) - 1
        if high > low and small >= 2:
            seg.sym(x0 - 1, x0, small - 1, low, high, "royal-")
        else:
            down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if i else 1)
            up = max(len(top_steps(n)), len(top_steps(fn)) if i else 2)
            seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "royal-")
        # this slice's piece of the bolt (two where a turn falls inside it)
        xa, xb = x0 - 0.2, min(x1 - 0.2, BOLT[-1][0])
        cuts = [xa] + [bx for bx, _ in BOLT if xa < bx < xb] + [xb]
        for k, (ca, cb) in enumerate(zip(cuts, cuts[1:])):
            if cb > ca:
                bolt_piece(seg, ca, cb, stroke_z(BOLT, ca), stroke_z(BOLT, cb), half_tall(n), n, 0.8 if k % 2 == 0 else 0.65)
        # the fork, thinner and less proud than the bolt
        if x0 <= FORK[0][0] < x1:
            (fa, za), (fb, zb) = FORK
            p0, p1 = (n - 0.6, n + 0.65, za - 0.65, za + 0.65), (n - 0.6, n + 0.65, zb - 0.45, zb + 0.45)
            seg.block(fa, p0, min(fb, x1 - 0.2), p1, "bolt", mirror=True)
    for k, h, s, rear in MASSES:
        x0, x1, n, bot, top, edge = spans[k]
        mass(segs[k], x0, x1, top, 10 * h, s, 2.0 if n >= 4 else 1.0, front=k != SEAT_SLICE + 2, rear=rear)
    for k, dx, s in SPINES:
        x0, x1, n, bot, top, edge = spans[k]
        crest_bolt(segs[k], x0 + dx, top - 0.5, s)
    # the seat: on the shoulders, a shallow slot either side for the rider's legs, above the bolt
    segs[SEAT_SLICE].dent(DENT[0], DENT[1], 4, DENT[2], DENT[3], "royal-")

    # the tail, on its own joint: a root block and two lobes that fork like a bolt, each steep, then flat, then steep
    # again, every box smaller and thinner than the one before and starting inside it; the last of each is light
    tail = m.part("Tail", (end, 0, TZ), f"S{len(SLICES)}")
    tail.beam((end - 0.5, 0, TZ), (end + 2.5, 0, TZ), 1.6, 1.5, "royal")
    tail.beam((end + 1.2, 0, TZ), (end + 5.0, 0, TZ + 4.6), 2.0, 1.2, "royal")
    tail.beam((end + 4.1, 0, TZ + 3.7), (end + 9.0, 0, TZ + 5.2), 1.5, 0.8, "navy")
    tail.beam((end + 7.6, 0, TZ + 4.75), (end + 11.4, 0, TZ + 9.4), 1.4, 0.5, "bolt")
    tail.beam((end + 1.2, 0, TZ), (end + 4.2, 0, TZ - 3.8), 1.8, 0.9, "royal")
    tail.beam((end + 3.4, 0, TZ - 3.0), (end + 7.4, 0, TZ - 4.2), 1.3, 0.6, "navy")
    tail.beam((end + 6.4, 0, TZ - 3.9), (end + 9.0, 0, TZ - 7.4), 1.2, 0.35, "bolt")
    sparks = m.part("TailSparks", (end, 0, TZ), "Tail")
    sparks.beam((end + 11.9, 0, TZ + 10.1), (end + 12.9, 0, TZ + 11.6), 1.1, 0.4, "bolt")
    sparks.beam((end + 9.4, 0, TZ - 8.1), (end + 10.2, 0, TZ - 9.4), 1.0, 0.35, "bolt")
