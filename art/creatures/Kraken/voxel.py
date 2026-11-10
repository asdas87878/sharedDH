"""The Kraken (zone 7's Mythic: a giant of the deep, half octopus, half squid) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Mythic by docs/style/05-rarity-look.md. The first tentacled creature, designed
from the animals: an octopus's arms and eyes behind a giant squid's mantle, jetting.
Its idea: the grip of the deep. A long spearhead that drags eight long arms through the dark, and the only light it has
runs down the inside of its grip and along its fins.
- It swims as they do: backwards. The mantle leads, the head follows, the arms trail behind and fan out, each curling a
  little further from the axis toward its tip, no two alike.
- The mantle is a squid's (reworked 2026-11-10: it was a ball). A full barrel just behind its opening, stepping in a cube
  at a time, then a long point of three whole blocks in a chain, each smaller and turned a little further up, ending in a
  dark spike: the whole shape leans up into its swim like a prow. A pale raised collar round the opening. A lighter
  plate on the back of each block of the point and a darker one beneath: the mantle's one rhythm. The rider sits on the
  barrel.
- Two fins near the point, swept back from it like an arrowhead and lifted a little, each on its own joint: two flat boxes
  on one line and a rib down the middle. Four spots of the suckers' light sit along each rib, smaller toward the end, so
  the light can be seen from the side and from above, not only from beneath.
- The head is narrow. The eyes bulge high on its sides: a matte gold iris, a dark slit of a pupil lying flat, a heavy lid
  that covers the top of the eye and stands only a little proud of it. They do not glow.
- Eight thick arms leave a flared crown, joined at the base by a web: a skirt of eight plates. Each arm is three boxes on
  three joints and a thin curling tip, every box a step smaller than the one before, and each a tone darker: wine at the root,
  near-black at the tip. One arm is short: bitten off long ago (its flaw).
- Under each arm, two rows of suckers, and they are the light: a cold green, following the arms' own lines.
- A beak in the middle of the arms, a siphon under the head.
Mythic by scale (the longest reach of any creature, eight arms on twenty-four joints), light (the suckers, echoed on the
fins) and a shift of colour along the body. The rider sits on the mantle, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Kraken", "ZONE 7 / MIDNIGHT", "MYTHIC"
U = 0.64
PALETTE = {"wine": "#63233A", "dusk": "#2B1420", "web": "#8E4F6C", "iris": "#D8B24C", "black": "#17141A", "beak": "#2A2226",
           "mouth": "#3A0F1C", "lume": "#B4F25A"}
SEAT = (-15.5, 10, 7.3)
GLOW = {"lume": 0.7}  # its signature colour: the suckers, and the spots along the fins
LIGHTS = [("Head", (9.0, 0, 1.0), "#B4F25A", 260, 1.2)]  # the suckers' light, gathered between the arms
FRAME, ORTHO, ORTHO_SWIM = 3.75, 57.0, 72.0

ARMS = 8
ANGLES = [math.radians(22.5 + 45 * k) for k in range(ARMS)]  # where each arm sits round the body's axis, from the right
AXIS_Z = 1.0  # the height of the axis the arms sit round
SHORT = 5  # the arm that was bitten off
FIN_LIGHTS = True  # spots of the suckers' light along each fin's rib
# an arm's boxes, root to tip: (length, how far it leans out from the axis in degrees, width, thickness, colour)
BOXES = ((12.5, 16, 3.6, 3.0, "wine"), (12.5, 12, 2.7, 2.2, "wine-"), (10.5, 26, 1.8, 1.4, "dusk"))
# no two arms alike: each arm's (length, extra lean in degrees), round from the right
VARY = ((1.0, 0), (0.92, 5), (1.0, -2), (0.9, 4), (1.0, 0), (1.0, 3), (0.94, -3), (1.0, 4))
SWING = ((8, 0.0), (11, 0.9), (14, 1.8))  # each joint's swing in degrees, and how late it is


def pose(parts, phase):
    """a jet: the arms spread, then sweep together, each joint a little later than the one before it, so a wave runs
    down every arm. Each joint turns about the arm's own sideways axis. The head nods a little"""
    parts["Head"].rotation_euler.y = math.radians(2) * math.sin(phase + 0.5)
    for name, side in (("FinR", 1), ("FinL", -1)):  # the fins beat with the jet, a little after the arms
        parts[name].rotation_euler.x = side * math.radians(9) * math.sin(phase - 0.6)
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


def slab(p, x0, x1, n, bot, top, colour="wine"):
    """a length of soft body: stepped corners, lighter on the top row, darker underneath"""
    st = steps(n)
    p.hull(x0, x1, n, bot, top, colour, st, st)
    p.paint_sym(x0, x1, n, top - 1, top, colour + "+")
    p.paint_sym(x0, x1, n, bot, bot + 2, colour + "-")


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


def arm(m, k, angle):
    """one arm, at `angle` round the axis: three boxes on three joints, then a thin tip; suckers under the first three"""
    c, s = math.cos(angle), math.sin(angle)
    start = (-0.6, 3.2 * c, AXIS_Z + 3.2 * s)  # inside the crown
    parent = "Head"
    scale, more = VARY[k]
    for j, (length, lean, wide, thick, colour) in enumerate(BOXES):
        length, lean = length * scale, lean + more
        if k == SHORT and j == 2:
            length = 4.5  # the stump
        along, across, through = frame(angle, lean)
        part = m.part(f"A{k + 1}{'abc'[j]}", at(start, along, 1.6 if j == 0 else 0.6), parent)
        part._oriented(at(start, along, length / 2), along, across, through, (length, wide, thick), colour, False)
        # the suckers, on the side that faces the axis: two rows on the thick boxes, one on the thin
        size = ((1.0, 0.9, 0.5), (0.8, 0.7, 0.45), (0.75, 0.75, 0.4))[j]
        rows = ((-0.9, 0.9), (-0.65, 0.65), (0.0,))[j]
        places = ((5.6, 8.1, 10.6), (2.6, 6.0, 9.4), (2.6, 5.6, 8.6))[j]
        for t in places:
            if t > length - 0.8:
                continue
            for off in rows:
                centre = at(at(at(start, along, t), across, off), through, -(thick / 2 + size[2] / 2 - 0.1))
                part._oriented(centre, along, across, through, size, "lume", False)
        end = at(start, along, length)
        if j == 2 and k != SHORT:  # the last thin tip, in two boxes, curling out and away
            tip_start = at(end, along, -1.0)
            for tip_lean, tip_length, tip_wide, tip_thick in ((42, 4.5, 1.1, 0.8), (64, 3.0, 0.6, 0.4)):
                tip_along, tip_across, tip_through = frame(angle, tip_lean + more)
                part._oriented(at(tip_start, tip_along, tip_length / 2), tip_along, tip_across, tip_through, (tip_length, tip_wide, tip_thick),
                               colour, False)
                tip_start = at(tip_start, tip_along, tip_length - 0.7)
        start = at(end, along, -1.2)  # the next box starts inside this one
        parent = part.name


def build(m):
    # the mantle: a squid's, leading. A full barrel just behind its opening, stepping in one cube at a time, then a long
    # point of three whole blocks in a chain, each smaller than the last and each turned a little further up, so the whole
    # shape leans up into its swim like a prow. Each slice of the barrel is (from, to, cubes out, bottom, top)
    mantle = m.part("Mantle", (-9, 0, 1.5))
    for x0, x1, n, bot, top in ((-12, -9, 7, -6, 9), (-18, -12, 8, -7, 10), (-21, -18, 7, -6, 9), (-23, -21, 6, -5, 9)):
        slab(mantle, x0, x1, n, bot, top)
    slab(mantle, -9, -8, 5, -4, 7, "web")  # the pale lining, where it opens round the neck
    # the collar: a raised lip round the opening
    st = steps(7)
    mantle.band(-10.7, -9.35, 7, -6, 9, "web", st, st, proud=0.35)
    # the point. Each block is (from, to, width, height, colour); each starts inside the one before. On the back of each
    # lies a lighter plate, and under each a darker one, narrower than the block: its rounded corners, and the mantle's
    # one rhythm. Then a dark spike, as the arms end
    point = (((-22.4, 1.6), (-28.2, 2.6), 9.6, 12.4, "wine", 1.2), ((-27.3, 2.5), (-33.0, 4.3), 7.0, 8.6, "wine", 1.6),
             ((-32.1, 4.1), (-36.4, 6.4), 4.4, 5.0, "wine-", 1.6))
    for (x0, z0), (x1, z1), wide, tall, colour, plate in point:
        mantle.beam((x0, 0, z0), (x1, 0, z1), wide, tall, colour, flat="z")
        length = math.hypot(x1 - x0, z1 - z0)
        ax, az = (x1 - x0) / length, (z1 - z0) / length
        ux, uz = (az, -ax) if ax < 0 else (-az, ax)  # up from the block's back
        for sign, tone in ((1, {"wine": "wine+", "wine-": "wine"}[colour]), (-1, {"wine": "wine-", "wine-": "dusk"}[colour])):
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
                  (cx + ux * 2.25, -1.95, cz + uz * 2.25)], (cx + ax * 4.6, 0.0, cz + az * 4.6 + 0.6), "dusk")
    # the seat: on top of the sack, with a shallow slot either side for the rider's legs
    mantle.dent(-17, -14, 7, 5, 7, "wine-")

    # the fins: a pair near the point, swept back from it like an arrowhead and lifted a little, each on its own joint.
    # Two flat boxes on one line, the second narrower and thinner and starting inside the first, and one rib down the
    # middle of both
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-30.0, 3.0 * side, 5.5), "Mantle")

        def along(t):
            return (-33.5 + 9.0 * t, side * (0.8 + 8.5 * t), 5.4 + 3.0 * t)

        fin.beam(along(0.0), along(1.0), 5.5, 1.0, "wine", flat="z")
        fin.beam(along(0.62), along(1.35), 3.2, 0.6, "wine-", flat="z")
        fin.beam(along(-0.06), along(1.25), 0.6, 1.5, "wine+", flat="z")
        if FIN_LIGHTS:  # the suckers' light, echoed: a few spots along the rib, smaller toward the end, above and below
            length = math.sqrt(9.0 ** 2 + 8.5 ** 2 + 3.0 ** 2)
            ahead = (9.0 / length, side * 8.5 / length, 3.0 / length)
            flat = math.hypot(9.0, 8.5)
            across = (8.5 / flat, -side * 9.0 / flat, 0.0)
            normal = (ahead[1] * across[2] - ahead[2] * across[1], ahead[2] * across[0] - ahead[0] * across[2],
                      ahead[0] * across[1] - ahead[1] * across[0])
            for t, size in ((0.34, 1.1), (0.6, 1.0), (0.84, 0.9), (1.06, 0.8)):
                for face in (1, -1):
                    fin._oriented(at(along(t), normal, face * 0.54), ahead, across, normal, (size, size, 0.68), "lume", False)

    # the head, narrow, and the crown the arms leave from, flared
    head = m.part("Head", (-8, 0, 1.0), "Mantle")
    slab(head, -8, -3, 4, -3, 5)
    slab(head, -3, 1, 6, -5, 7)
    head.sym(-9, -8, 2, -1, 4, "wine-")  # a sleeve into the mantle, clear of its steps
    # the eyes bulge high on the head's sides: a turret of cubes, a matte gold iris on its outer face, a dark slit of a
    # pupil lying flat, and a heavy lid that covers the top of the eye and stands only a little proud of the pupil
    head.pair(-7, -4, 3, 6, 3, 7, "wine")
    head.paint_pair(-7, -4, 5, 6, 4, 6, "iris")
    pupil = (5.45, 5.75, 4.75, 5.3)
    head.block(-6.7, pupil, -4.3, pupil, "black", mirror=True)
    lid = (5.3, 5.87, 5.5, 6.5)
    head.block(-6.9, lid, -4.1, lid, "wine-", mirror=True)
    # the siphon: a short tube under the head on the right, pointing back, dark inside
    head.beam((-6.8, 1.6, -1.4), (-3.7, 2.5, -3.9), 1.6, 1.6, "web", flat="z")
    head.beam((-4.5, 2.27, -3.25), (-3.3, 2.62, -4.22), 1.0, 1.0, "mouth", flat="z")
    # the beak, in the middle of the arms: two dark points, in a dark mouth
    head.paint(0, 1, -2, 3, -1, 3, "mouth")
    head.spike([(0.9, -0.8, 1.05), (0.9, 0.8, 1.05), (0.9, 0.8, 2.1), (0.9, -0.8, 2.1)], (2.7, 0.0, 0.95), "beak")
    head.spike([(0.9, -0.7, -0.1), (0.9, 0.7, -0.1), (0.9, 0.7, 0.95), (0.9, -0.7, 0.95)], (2.2, 0.0, 1.1), "beak")
    # the web: a skirt of eight plates flaring out round the arms' roots, one between each pair of arms
    for k in range(ARMS):
        angle = math.radians(45 * k)
        along, across, through = frame(angle, 20)
        start = (0.3, 4.9 * math.cos(angle), AXIS_Z + 4.9 * math.sin(angle))
        head._oriented(at(start, along, 3.25), along, across, through, (6.5, 4.8, 0.6), "web", False)

    for k, angle in enumerate(ANGLES):
        arm(m, k, angle)
