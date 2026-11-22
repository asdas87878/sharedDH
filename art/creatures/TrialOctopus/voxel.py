"""The Octopus, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Octopus (art/creatures/Octopus) and replaces nothing. Designed from the real animal.
Its idea: the bulb. A tall red mantle leaning back over the arms, a low sleepy head in front, eight thick arms fanning
out behind. Unlike the old model (mantle first, a low dome), this one swims eyes first, the bulb towering behind them.
- The bulb in numbers: 19 cubes high (8.6 studs), 17 wide (7.7 studs), 19 long (8.6 studs) with its overhang. Its front is low and steps
  up and back; its flat top (the seat) is behind the head; its back hangs out over the arms.
- The head is lower and narrower (9 to 13 cubes wide, 11 high), in front of and under the bulb; the arms leave its
  flared back. An eye on each side on a raised bump: a gold eye, a dark bar pupil lying level, and a heavy red lid
  cutting the top third (sleepy and a little cross).
- Eight arms trail behind, each three blocks, 3 cubes thick at the root and thinner at each block; the last block curls
  outward. A web of thin plates joins the roots; the side arms lean out more than the upper and lower ones, so the arms
  fan out in a skirt seen from above. No two arms alike.
- Tomato red over cream: cream under the head.
- The one mark: two rows of cream suckers, one block each, under every arm (on the side that faces the others).
Studs lie on every face of the red, on the mantle and the head only. The rider sits on the bulb's flat top."""
import math

NAME, ZONE, RARITY = "Octopus (trial)", "ZONE 2 / CORAL REEF", "RARE"
U = 0.45
PALETTE = {"red": "#E2452F", "cream": "#F8DDBB", "iris": "#F4D77E", "black": "#1E1A1C"}
SHADE = 0.9
SEAT = (-8, 23, 8.5)
FRAME, ORTHO, ORTHO_SWIM = 2.3, 34.0, 32.0
TEXTURES = [{"tile": "stud", "on": "all", "colours": ["red"], "parts": ["Mantle", "Head"]}]

ARMS = 8
ANGLES = [math.radians(22.5 + 45 * k) for k in range(ARMS)]  # where each arm sits round the body's axis, from the right
AXIS_X, AXIS_Z = -10.0, -1.5  # where the arms start (inside the crown), and the height of the axis they sit round
ROOT = 3.5  # how far from the axis an arm starts
# an arm's blocks, root to tip: (length, how far it leans out from the axis in degrees, width, thickness). The lean is
# for a side arm; an upper or lower arm leans out less (SPREAD), so the arms make a flat skirt seen from above
BOXES = ((12.0, 30, 3.0, 2.8), (11.0, 17, 2.2, 2.0), (6.5, 60, 1.5, 1.3))
SPREAD = (0.3, 0.7)  # an arm's lean is scaled by SPREAD[0] + SPREAD[1] * |cos(its angle)|
# no two arms alike: each arm's (length, extra lean in degrees, extra curl of its last block), round from the right
VARY = ((1.0, 0, 0), (0.92, 3, 10), (1.0, -2, -6), (0.9, 2, 6), (1.0, 2, -8), (0.94, -3, 8), (1.0, 3, 0), (0.9, -1, 12))
# the suckers on each block: where along it (from its start), in two rows either side of its middle
CURL_UP = (5, 6)  # the two lowest arms curl up at the tip (toward the others) instead of out and down
SUCKERS = ((5.0, 8.2), (3.4, 6.6), (3.0,))
SWING = ((6, 0.0), (10, 0.9), (13, 1.8))  # each joint's swing in degrees, and how late it is


def pose(parts, phase):
    """a jet: the arms spread, then sweep together, each joint a little later than the one before it, so a wave runs
    down every arm. Each joint turns about the arm's own sideways axis. The bulb rocks a little"""
    parts["Mantle"].rotation_euler.y = math.radians(2) * math.sin(phase + 0.5)
    for k, angle in enumerate(ANGLES):
        axis = (0.0, -math.sin(angle), math.cos(angle))
        for j, (swing, late) in enumerate(SWING):
            ob = parts[f"A{k + 1}{'abc'[j]}"]
            beat = math.sin(phase - late) + 0.3 * math.sin(2 * (phase - late))  # opens slowly, shuts fast
            ob.rotation_mode = "AXIS_ANGLE"
            ob.rotation_axis_angle = (math.radians(swing) * beat, *axis)


def frame(angle, lean):
    """the three directions of a block at `angle` round the axis, leaning out by `lean` degrees: along it, across it
    (sideways), and through it (outward from the axis)"""
    c, s, f = math.cos(angle), math.sin(angle), math.radians(lean)
    along = (math.cos(f), math.sin(f) * c, math.sin(f) * s)
    through = (-math.sin(f), math.cos(f) * c, math.cos(f) * s)
    across = (0.0, -s, c)
    return along, across, through


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def arm(m, k, angle):
    """one arm at `angle` round the axis: three blocks on three joints, each smaller than the last and starting inside
    it, with two rows of suckers under it"""
    c, s = math.cos(angle), math.sin(angle)
    start = (AXIS_X, ROOT * c, AXIS_Z + ROOT * s)  # inside the crown
    parent = "Head"
    scale, more, curl = VARY[k]
    spread = SPREAD[0] + SPREAD[1] * abs(c)
    for j, (length, lean, wide, thick) in enumerate(BOXES):
        length, lean = length * scale, lean * spread + more + (curl if j == 2 else 0)
        if j == 2 and k in CURL_UP:
            lean = -0.4 * BOXES[2][1] + curl
        along, across, through = frame(angle, lean)
        part = m.part(f"A{k + 1}{'abc'[j]}", at(start, along, 1.6 if j == 0 else 0.6), parent)
        part._oriented(at(start, along, length / 2), along, across, through, (length, wide, thick), "red", False)
        # the suckers: cream pads standing proud of the block's lowest face, so they show along the arm's lower edge,
        # two rows, one block each (staggered, as on the animal, 0.3 apart, and 0.3 short of the face's edges)
        faces = ((through, across, thick, wide), (tuple(-v for v in through), across, thick, wide),
                 (across, through, wide, thick), (tuple(-v for v in across), through, wide, thick))
        down, side_dir, depth, face = min(faces, key=lambda f: f[0][2])
        size, proud, shift = (1.2, 1.0, 0.8)[j], (0.45, 0.4, 0.35)[j], (0.75, 0.65, 0.55)[j]
        for t in SUCKERS[j]:
            for side in (-1, 1):
                foot = at(at(start, along, t * scale + side * shift), side_dir, side * (face / 4 - 0.075))
                centre = at(foot, down, depth / 2 + proud / 2 - 0.15)
                part._oriented(centre, along, side_dir, down, (size, face / 2 - 0.45, proud + 0.3), "cream", False)
        start = at(at(start, along, length), along, -1.2)  # the next block starts inside this one
        parent = part.name


def web(head, k):
    """a thin plate between arm k and the next, joining their roots for the first quarter of their length"""
    mid = ANGLES[k] + math.radians(22.5)
    spread = SPREAD[0] + SPREAD[1] * (abs(math.cos(ANGLES[k])) + abs(math.cos(ANGLES[(k + 1) % ARMS]))) / 2
    lean = math.degrees(math.atan(math.cos(math.radians(22.5)) * math.tan(math.radians(BOXES[0][1] * spread))))
    along, across, through = frame(mid, lean)
    r = ROOT * math.cos(math.radians(22.5))
    start = (AXIS_X, r * math.cos(mid), AXIS_Z + r * math.sin(mid))
    head._oriented(at(start, along, 5.0), along, across, through, (6.0, 5.2, 0.4), "red", False)


def build(m):
    # the head, in front and low: a rounded front, the eyes, and the flared back the arms leave
    head = m.part("Head", (-14, 0, 0))
    head.hull(-22, -19, 4, -4, 4, "red", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    head.hull(-19, -13, 5, -5, 5, "red", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    head.hull(-13, -8, 6, -6, 5, "red", [(2, 1), (1, 1)], [(2, 1), (1, 2)])
    # the eyes: on a raised bump on each side, a gold eye, a dark bar pupil lying level, and a heavy lid of the body
    # colour cutting the top third of the eye
    head.pair(-20, -12, 6, 7, -2, 4, "red")
    head.paint_pair(-19, -13, 6, 7, -1, 3, "iris")
    head.paint_sym(-22, -8, 7, -6, -1, "cream")  # cream under the head, the bumps' lowest row too
    pupil = (6.45, 6.8, 0.1, 0.9)
    head.block(-18.3, pupil, -13.7, pupil, "black", mirror=True)
    lid = (6.2, 7.1, 1.7, 3.7)
    head.block(-19.3, lid, -12.7, lid, "red", mirror=True)
    for k in range(ARMS):
        web(head, k)

    # the bulb: a tall rounded mantle leaning back over the arms. Its front is low and steps up and back, its flat top
    # (the seat) is behind the head, its back hangs out over the arms. Each slice is (from, to, cubes out, bottom, top,
    # top corners, bottom corners); the corners are one broad step and a narrow one. Its lower front sits in the head
    mantle = m.part("Mantle", (-12, 0, 5), "Head")
    for x0, x1, n, z0, z1, top, bottom in (
        (-18, -15, 6, 4, 13, [(2, 2)], []),
        (-15, -11, 8, 4, 19, [(3, 2)], [(1, 1)]),
        (-11, -9, 8, 4, 23, [(3, 1), (1, 2)], [(2, 1), (1, 1)]),
        (-9, -4, 8, 6, 23, [(3, 1), (1, 2)], [(2, 1), (1, 1)]),
        (-4, -1, 7, 9, 23, [(3, 1), (1, 2)], [(2, 1), (1, 1)]),
        (-1, 1, 6, 12, 22, [(2, 1), (1, 2)], [(2, 1)]),
    ):
        mantle.hull(x0, x1, n, z0, z1, "red", top, bottom)
    mantle.paint_sym(-11, -1, 8, 22, 23, "red+")  # the top a little lighter, as light falls on it

    for k, angle in enumerate(ANGLES):
        arm(m, k, angle)
