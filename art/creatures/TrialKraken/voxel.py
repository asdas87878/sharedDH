"""TrialKraken: the Kraken remodelled for docs/style/11-rare-wow-study.md (round 1), beside the game's model
(art/creatures/Kraken). Zone 7's Mythic, for tools/blender/voxel_kit.py.
Its idea, kept: backwards. The mantle leads, eight arms trail and fan, and its only light runs down the inside of its grip.
What changes (the study's rules for a Mythic):
- One hero hue at full strength: crimson #E0263A in three values (crimson+, crimson, blood), no maroon, with a pale rose
  underside (the mantle's belly, the collar, the web between the arms).
- Glow as shapes, 10 to 20% of what you see: the inside of every arm is a lit aqua band 2 cubes wide down its whole
  length, and on it the suckers are big pale lit discs, wider than the band, like a string of lamps; the eyes are big
  aqua halos round a dark slit, under a heavy lid.
- The back line rises: the squid's two fins flare from the point of the mantle up and back, past the mantle's top,
  in a V. They are broad blades (a crimson plate with a lighter one on it), not spikes.
Kept from the old model: the mantle's barrel and three-block point leaning up like a prow, the collar, the narrow head,
the siphon, the beak, the skirt of eight web plates, the arms of three boxes on three joints with curling tips, no two
alike, and the short arm bitten off long ago. The rider sits on the barrel, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Kraken (trial)", "ZONE 7 / MIDNIGHT", "MYTHIC"
U = 0.64
PALETTE = {"crimson": "#E0263A", "blood": "#A8142C", "rose": "#F4A6B2", "aqua": "#2EF0D8", "pearl": "#D2FFF7",
           "black": "#160E14", "maw": "#3A0A18"}
SHADE = 0.9
SEAT = (-15.5, 10, 7.3)
GLOW = {"aqua": 0.9, "pearl": 1.0}  # the inside of the grip, and the eyes
LIGHTS = [("Head", (9.0, 0, 1.0), "#2EF0D8", 320, 1.4)]  # the grip's light, gathered between the arms
FRAME, ORTHO, ORTHO_SWIM = 3.75, 57.0, 72.0

ARMS = 8
ANGLES = [math.radians(22.5 + 45 * k) for k in range(ARMS)]  # where each arm sits round the body's axis, from the right
AXIS_Z = 1.0  # the height of the axis the arms sit round
SHORT = 5  # the arm that was bitten off
# an arm's boxes, root to tip: (length, how far it leans out from the axis in degrees, width, thickness, colour)
BOXES = ((12.5, 18, 4.0, 3.0, "crimson"), (12.5, 13, 3.1, 2.3, "crimson"), (10.5, 27, 2.3, 1.7, "blood"))
# the lit band down the inside of each box: (width, where it starts along the box), and the suckers on it:
# (disc radius, places along the box)
BANDS = ((2.4, 3.2), (2.0, 0.9), (1.4, 0.9))
DISCS = ((1.5, (4.8, 7.9, 11.0)), (1.25, (2.7, 5.7, 8.7)), (0.95, (2.5, 5.0, 7.5)))
# no two arms alike: each arm's (length, extra lean in degrees), round from the right
VARY = ((1.0, 0), (0.92, 5), (1.0, -2), (0.9, 4), (1.0, 0), (1.0, 3), (0.94, -3), (1.0, 4))
SWING = ((8, 0.0), (11, 0.9), (14, 1.8))  # each joint's swing in degrees, and how late it is


def pose(parts, phase):
    """a jet: the arms spread, then sweep together, each joint a little later than the one before it, so a wave runs
    down every arm. Each joint turns about the arm's own sideways axis. The head nods a little"""
    parts["Head"].rotation_euler.y = math.radians(2) * math.sin(phase + 0.5)
    for k, angle in enumerate(ANGLES):
        axis = (0.0, -math.sin(angle), math.cos(angle))
        for j, (swing, late) in enumerate(SWING):
            ob = parts[f"A{k + 1}{'abc'[j]}"]
            beat = math.sin(phase - late) + 0.3 * math.sin(2 * (phase - late))  # opens slowly, shuts fast
            ob.rotation_mode = "AXIS_ANGLE"
            ob.rotation_axis_angle = (math.radians(swing) * beat, *axis)


def steps(n):
    """the corner steps of a slab n cubes out: rounder the bigger it is"""
    return {8: [(5, 1), (3, 1), (2, 1), (1, 2)], 7: [(4, 1), (2, 1), (1, 2)], 6: [(3, 1), (2, 1), (1, 1)], 5: [(3, 1), (1, 1)], 4: [(2, 1), (1, 1)], 3: [(1, 1)]}.get(n, [])


def slab(p, x0, x1, n, bot, top, colour="crimson", belly=3):
    """a length of soft body: stepped corners, lighter on the top row, the pale rose underneath"""
    st = steps(n)
    p.hull(x0, x1, n, bot, top, colour, st, st)
    p.paint_sym(x0, x1, n, top - 1, top, colour + "+")
    p.paint_sym(x0, x1, n, bot, bot + belly, "rose")


def frame(angle, lean):
    """the three directions of an arm's box at `angle` round the axis, leaning out by `lean` degrees: along it, across it
    (sideways), and through it (outward from the axis)"""
    c, s, f = math.cos(angle), math.sin(angle), math.radians(lean)
    along = (math.cos(f), math.sin(f) * c, math.sin(f) * s)
    through = (-math.sin(f), math.cos(f) * c, math.cos(f) * s)
    across = (0.0, -s, c)
    return along, across, through


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def disc(part, centre, along, across, out, r, low, high, colour):
    """a round sucker: an eight-sided disc of radius r lying on the arm, from `low` to `high` along `out` (its root buried)"""
    ring = [(math.cos(math.radians(22.5 + 45 * i)), math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]
    verts = []
    for h in (low, high):
        for ca, sa in ring:
            verts.append(tuple(c + a * r * ca + w * r * sa + o * h for c, a, w, o in zip(centre, along, across, out)))
    faces = [tuple(range(8)), tuple(range(8, 16))] + [(i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8)]
    part.solid(verts, faces, colour)


def arm(m, k, angle):
    """one arm, at `angle` round the axis: three boxes on three joints, then a thin tip; down the inside of the three boxes
    a lit band, and on it the suckers as big lit discs"""
    c, s = math.cos(angle), math.sin(angle)
    start = (-0.6, 3.2 * c, AXIS_Z + 3.2 * s)  # inside the crown
    parent = "Head"
    scale, more = VARY[k]
    for j, (length, lean, wide, thick, colour) in enumerate(BOXES):
        length, lean = length * scale, lean + more
        if k == SHORT and j == 2:
            length = 4.5  # the stump
        along, across, through = frame(angle, lean)
        inward = tuple(-v for v in through)
        part = m.part(f"A{k + 1}{'abc'[j]}", at(start, along, 1.6 if j == 0 else 0.6), parent)
        part._oriented(at(start, along, length / 2), along, across, through, (length, wide, thick), colour, False)
        # the band: 0.3 proud of the inside face, its root sunk 0.2 into the box
        band_w, band_from = BANDS[j]
        band_to = length - 0.5
        band_mid = at(at(start, along, (band_from + band_to) / 2), inward, thick / 2 + 0.15)
        part._oriented(band_mid, along, across, inward, (band_to - band_from, band_w, 0.7), "aqua", False)
        r, places = DISCS[j]
        for t in places:
            if t > band_to - r:
                continue
            disc(part, at(start, along, t), along, across, inward, r, thick / 2 - 0.35, thick / 2 + 0.9, "pearl")
        end = at(start, along, length)
        if j == 2 and k != SHORT:  # the last thin tip, in two boxes, curling out and away
            tip_start = at(end, along, -1.0)
            for tip_lean, tip_length, tip_wide, tip_thick in ((44, 4.5, 1.3, 0.9), (66, 3.0, 0.7, 0.5)):
                tip_along, tip_across, tip_through = frame(angle, tip_lean + more)
                part._oriented(at(tip_start, tip_along, tip_length / 2), tip_along, tip_across, tip_through, (tip_length, tip_wide, tip_thick),
                               colour, False)
                tip_start = at(tip_start, tip_along, tip_length - 0.7)
        start = at(end, along, -1.2)  # the next box starts inside this one
        parent = part.name


def fin_plate(part, origin, along, out, outline, low, high, colour):
    """a flat blade drawn in the fin's own plane (a along the body, b out and up) from `low` to `high` through it"""
    normal = (along[1] * out[2] - along[2] * out[1], along[2] * out[0] - along[0] * out[2], along[0] * out[1] - along[1] * out[0])
    n = len(outline)
    verts = []
    for h in (low, high):
        for a, b in outline:
            verts.append(tuple(o + al * a + ou * b + no * h for o, al, ou, no in zip(origin, along, out, normal)))
    faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    part.solid(verts, faces, colour, mirror=True)


def build(m):
    # the mantle: a squid's, leading. A full barrel just behind its opening, stepping in one cube at a time, then a long
    # point of three whole blocks in a chain, each smaller than the last and each turned a little further up, so the whole
    # shape leans up into its swim like a prow. Each slice of the barrel is (from, to, cubes out, bottom, top)
    mantle = m.part("Mantle", (-9, 0, 1.5))
    for x0, x1, n, bot, top in ((-12, -9, 7, -6, 9), (-18, -12, 8, -7, 10), (-21, -18, 7, -6, 9), (-23, -21, 6, -5, 9)):
        slab(mantle, x0, x1, n, bot, top)
    slab(mantle, -9, -8, 5, -4, 7, "rose")  # the pale lining, where it opens round the neck
    st = steps(7)
    mantle.band(-10.7, -9.35, 7, -6, 9, "rose", st, st, proud=0.35)  # the collar: a raised lip round the opening
    # the point. Each block is (from, to, width, height, colour); each starts inside the one before. On the back of each
    # lies a lighter plate, and under each a rose one, narrower than the block. Then a dark spike, as the arms end
    point = (((-22.4, 1.6), (-28.2, 2.6), 9.6, 12.4, "crimson", 1.2), ((-27.3, 2.5), (-33.0, 4.3), 7.0, 8.6, "crimson", 1.6),
             ((-32.1, 4.1), (-36.4, 6.4), 4.4, 5.0, "blood", 1.6))
    for (x0, z0), (x1, z1), wide, tall, colour, plate in point:
        mantle.beam((x0, 0, z0), (x1, 0, z1), wide, tall, colour, flat="z")
        length = math.hypot(x1 - x0, z1 - z0)
        ax, az = (x1 - x0) / length, (z1 - z0) / length
        ux, uz = (az, -ax) if ax < 0 else (-az, ax)  # up from the block's back
        for sign, tone in ((1, colour + "+"), (-1, "rose")):
            rise = sign * (tall / 2 + 0.05)
            start = plate if sign > 0 else 0.3  # the plate on the back starts past the block before; the belly's runs its length
            mantle.beam((x0 + ax * start + ux * rise, 0, z0 + az * start + uz * rise),
                        (x1 - ax * 0.45 + ux * rise, 0, z1 - az * 0.45 + uz * rise), wide - 2.2, 0.9, tone, flat="z")
    (x0, z0), (x1, z1) = point[-1][:2]
    length = math.hypot(x1 - x0, z1 - z0)
    ax, az = (x1 - x0) / length, (z1 - z0) / length
    ux, uz = (az, -ax) if ax < 0 else (-az, ax)
    cx, cz = x1 - ax * 0.5, z1 - az * 0.5
    mantle.spike([(cx - ux * 2.25, -1.95, cz - uz * 2.25), (cx - ux * 2.25, 1.95, cz - uz * 2.25), (cx + ux * 2.25, 1.95, cz + uz * 2.25),
                  (cx + ux * 2.25, -1.95, cz + uz * 2.25)], (cx + ax * 4.6, 0.0, cz + az * 4.6 + 0.6), "blood")
    # the fins: two broad blades rooted along the point, flaring up and back past the mantle's top in a V. Drawn in the
    # fin's own plane: a runs back along the point, b out and up at 62 degrees from level. A lighter plate lies on each
    tilt = math.radians(62)
    f_along = (0.995, 0.0, -0.0995)
    f_out = (0.0, math.cos(tilt), math.sin(tilt))
    f_origin = (-35.6, 0.9, 6.0)
    fin_plate(mantle, f_origin, f_along, f_out, [(0, 0), (7.5, 6.5), (12.6, 11.2), (15.4, 11.6), (15.8, 7.5), (14.0, 0)], -0.45, 0.45, "crimson")
    inner = [(4.0, 2.5), (8.0, 5.8), (12.0, 9.6), (14.2, 9.9), (14.4, 6.8), (12.6, 2.5)]
    for low, high in ((0.25, 0.75), (-0.75, -0.25)):
        fin_plate(mantle, f_origin, f_along, f_out, inner, low, high, "crimson+")
    # the seat: on top of the sack, with a shallow slot either side for the rider's legs
    mantle.dent(-17, -14, 7, 5, 7, "crimson-")

    # the head, narrow, and the crown the arms leave from, flared
    head = m.part("Head", (-8, 0, 1.0), "Mantle")
    slab(head, -8, -3, 4, -3, 5, belly=2)
    slab(head, -3, 1, 6, -5, 7)
    head.sym(-9, -8, 2, -1, 4, "crimson-")  # a sleeve into the mantle, clear of its steps
    # the eyes: big turrets high on the head's sides, their outer face a glowing aqua halo round a dark slit of a pupil
    # lying flat, under a heavy lid of blood that covers the top of the eye
    head.pair(-8, -3, 3, 6, 2, 8, "crimson")
    head.paint_pair(-8, -3, 5, 6, 2, 7, "aqua")
    pupil = (5.45, 5.8, 3.2, 5.6)
    head.block(-7.1, pupil, -3.9, pupil, "black", mirror=True)
    head.paint_pair(-8, -3, 3, 6, 7, 8, "blood")
    lid = (5.2, 6.1, 6.6, 7.75)
    head.block(-7.8, lid, -3.2, lid, "blood", mirror=True)
    # the siphon: a short tube under the head on the right, pointing back, dark inside
    head.beam((-6.8, 1.6, -1.4), (-3.7, 2.5, -3.9), 1.6, 1.6, "rose", flat="z")
    head.beam((-4.5, 2.27, -3.25), (-3.3, 2.62, -4.22), 1.0, 1.0, "maw", flat="z")
    # the beak, in the middle of the arms: two dark points, in a dark mouth
    head.paint(0, 1, -2, 3, -1, 3, "maw")
    head.spike([(0.9, -0.8, 1.05), (0.9, 0.8, 1.05), (0.9, 0.8, 2.1), (0.9, -0.8, 2.1)], (2.7, 0.0, 0.95), "black")
    head.spike([(0.9, -0.7, -0.1), (0.9, 0.7, -0.1), (0.9, 0.7, 0.95), (0.9, -0.7, 0.95)], (2.2, 0.0, 1.1), "black")
    # the web: a skirt of eight lit plates (the inside of the grip, where its light starts) flaring out round the arms' roots, one between each pair of arms
    for k in range(ARMS):
        angle = math.radians(45 * k)
        along, across, through = frame(angle, 20)
        start = (0.3, 4.9 * math.cos(angle), AXIS_Z + 4.9 * math.sin(angle))
        head._oriented(at(start, along, 3.25), along, across, through, (6.5, 4.8, 0.6), "aqua", False)

    for k, angle in enumerate(ANGLES):
        arm(m, k, angle)
