"""The Octopus (zone 2's Rare: a big orange-red reef octopus) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Designed from the animal, after the Kraken's arms (art/creatures/Kraken/voxel.py), smaller and simpler.
Its idea: a clever balloon with eight curling arms. It swims as they do, backwards: the domed mantle leads, the head
follows, the arms trail behind in a loose bundle and curl out at their tips.
- The mantle is a dome: one wide plateau and broad steps down to the front and to the neck, a pale belly under it.
- The head is narrower. The eyes sit high on its sides on a bump: a pale gold iris, a flat black bar of a pupil, and a
  heavy lid that covers the top of the eye.
- Eight arms leave a flared crown. Each is three boxes on three joints, every box smaller than the one before and
  starting inside it; the last turns out, the curl. A paler plate runs under each box, on the side that faces the others.
- No two arms alike: each has its own length and lean.
Studs lie on every face of the mantle's colour, none on the arms. The rider sits on the plateau, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Octopus", "ZONE 2 / CORAL REEF", "RARE"
U = 0.45
PALETTE = {"orange": "#E4572E", "pale": "#F7CFA4", "iris": "#F4D77E", "black": "#1E1A1C"}
SEAT = (-15, 8, 6.5)
FRAME, ORTHO, ORTHO_SWIM = 1.55, 22.0, 25.0
TEXTURES = [{"tile": "stud", "on": "all", "colours": ["orange"], "parts": ["Mantle", "Head"]}]

ARMS = 8
ANGLES = [math.radians(22.5 + 45 * k) for k in range(ARMS)]  # where each arm sits round the body's axis, from the right
AXIS_Z = 1.0  # the height of the axis the arms sit round
ROOT = 2.6  # how far from the axis an arm starts, inside the crown
# an arm's boxes, root to tip: (length, how far it leans out from the axis in degrees, width, thickness, colour)
BOXES = ((8.5, 11, 2.5, 2.1, "orange"), (7.5, 7, 1.9, 1.5, "orange"), (6.5, 38, 1.3, 0.9, "orange-"))
# no two arms alike: each arm's (length, extra lean in degrees, extra curl of its last box), round from the right
VARY = ((1.0, 0, 0), (0.92, 4, 8), (1.0, -2, -6), (0.9, 3, 4), (1.0, 2, -8), (0.94, -3, 6), (1.0, 4, 0), (0.9, -1, 10))
SWING = ((8, 0.0), (10, 0.9), (12, 1.8))  # each joint's swing in degrees, and how late it is


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


def slab(p, x0, x1, n, bot, top, belly, steps_top, steps_bottom):
    """a length of soft body: stepped corners, lighter on the top row, pale from `belly` down, darker on its lowest row"""
    p.hull(x0, x1, n, bot, top, "orange", steps_top, steps_bottom)
    p.paint_sym(x0, x1, n, top - 1, top, "orange+")
    p.paint_sym(x0, x1, n, bot, belly, "pale")
    p.paint_sym(x0, x1, n, bot, bot + 1, "pale-")


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
    """one arm, at `angle` round the axis: three boxes on three joints, a paler plate under each (on the side that faces
    the axis, where the suckers are)"""
    c, s = math.cos(angle), math.sin(angle)
    start = (-3.0, ROOT * c, AXIS_Z + ROOT * s)  # inside the crown
    parent = "Head"
    scale, more, curl = VARY[k]
    for j, (length, lean, wide, thick, colour) in enumerate(BOXES):
        length, lean = length * scale, lean + more + (curl if j == 2 else 0)
        along, across, through = frame(angle, lean)
        part = m.part(f"A{k + 1}{'abc'[j]}", at(start, along, 1.6 if j == 0 else 0.6), parent)
        part._oriented(at(start, along, length / 2), along, across, through, (length, wide, thick), colour, False)
        # the paler underside: a plate a little narrower and shorter than the box, standing a little proud of it
        plate = 0.8 if j < 2 else 0.6
        t0, t1 = (1.5 if j == 0 else 0.3), length - 0.4
        centre = at(at(start, along, (t0 + t1) / 2), through, -thick / 2)
        part._oriented(centre, along, across, through, (t1 - t0, (2.2, 1.6, 1.0)[j], plate), "pale", False)
        start = at(at(start, along, length), along, -1.2)  # the next box starts inside this one
        parent = part.name


def build(m):
    # the mantle, leading: a dome. One wide plateau, a broad step down to the front and another to its blunt end; a step
    # down to the neck. Each slice is (from, to, cubes out, bottom, top, the belly's edge, top corners, bottom corners)
    mantle = m.part("Mantle", (-10, 0, 1.0))
    one, two = [(1, 1)], [(2, 1), (1, 1)]
    slab(mantle, -24, -21, 4, -2, 6, -1, two, one)
    slab(mantle, -21, -18, 5, -3, 7, -1, [(2, 1), (1, 2)], two)
    slab(mantle, -18, -12, 6, -4, 8, -2, [(2, 1), (1, 2)], two)
    slab(mantle, -12, -10, 5, -3, 7, -1, [(2, 1), (1, 2)], two)
    # the seat: on the plateau, with a shallow slot either side for the rider's legs
    mantle.dent(-16, -14, 6, 2, 5, "orange-")

    # the head, narrower, and the crown the arms leave from, flared
    head = m.part("Head", (-10, 0, 1.0), "Mantle")
    slab(head, -10, -5, 3, -2, 4, -1, one, one)
    slab(head, -5, -2, 4, -3, 5, -1, two, two)
    head.sym(-11, -10, 1, -1, 3, "orange-")  # a sleeve into the mantle, clear of its steps
    # the eyes sit high on the head's sides, on a bump: a pale gold iris on its outer face, a flat black bar of a pupil,
    # and a heavy lid that caps the bump, covers the top of the eye and stands a little proud of the pupil
    head.pair(-9, -6, 3, 5, 1, 5, "orange")
    head.paint_pair(-9, -6, 4, 5, 2, 4, "iris")
    pupil = (4.4, 4.75, 2.65, 3.2)
    head.block(-8.6, pupil, -6.4, pupil, "black", mirror=True)
    lid = (4.3, 4.9, 3.5, 4.7)
    head.block(-8.85, lid, -6.15, lid, "orange-", mirror=True)

    for k, angle in enumerate(ANGLES):
        arm(m, k, angle)
