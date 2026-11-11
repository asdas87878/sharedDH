"""The Aurora Jelly (zone 6's Secret: a giant jellyfish that glows like the northern lights) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed by docs/style/05-rarity-look.md.
Its idea: the northern lights, hung under a dark bell. Two ways to be more than Mythic: light (three bands of aurora)
and scale (threads stretched far beyond reason: the bell is a third of its height).
- The bell is a dome in three big round blocks: a wide plateau, one broad step, a wall. Each block is a circle cut in
  broad steps, so it is round from above too. A smaller cap on top is the rider's seat, cut away either side for the legs.
- The light follows the bell's own lines: the rim of each block is one thin line of light, green on the plateau, teal
  on the step, violet on the wall. Nothing else on the bell: its tops and walls stay plain deep indigo.
- A scalloped skirt hangs under the wall: four flaps on hinges, with blunt tabs. It opens slowly and shuts fast (the pulse).
- Four thick frilled arms hang from a block under the middle, each three boxes on three joints with a ruffle either
  side in two steps, and the same three lights running down its outer face.
- Eight long threads hang from under the rim, each three thin boxes on three joints, no two the same length; they
  trail a little behind, and their last box is light (the hem of the curtain).
No eyes, no mouth: a jellyfish has none. Studs lie on the faces that look up. The rider sits on the saddle."""
import math

NAME, ZONE, RARITY = "Aurora Jelly", "ZONE 6 / TWILIGHT", "SECRET"
U = 0.45
PALETTE = {"indigo": "#2D2B78", "frill": "#6D5FCB", "green": "#5CF59B", "teal": "#33D6D0", "violet": "#B77DFF"}
Z = 17  # the height of the bell's underside: the model's middle is near 0, so the views frame all of it
SEAT = (0.5, Z + 20, 2.5)
GLOW = {"green": 1.0, "teal": 1.0, "violet": 1.0}  # the aurora: the rims of the bell's blocks, the arms' lines, the threads' ends
LIGHTS = [("Bell", (0.5, 0, Z - 10.0), "#6FF2C4", 120, 1.0)]  # its light gathered under the bell, on the arms
FRAME, ORTHO, ORTHO_SWIM = 3.6, 70.0, 70.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["indigo"]}]

CX = 0.5  # the bell's middle: cube column 0 spans x from 0 to 1
# the bell's blocks, bottom up: (cubes out, from, to, the light on its rim)
TIERS = ((24, 0, 8, "violet"), (20, 8, 13, "teal"), (14, 13, 17, "green"), (7, 17, 20, None))
ARM_ANGLES = [math.radians(45 + 90 * k) for k in range(4)]
# an arm's boxes, root to tip: (length, lean out in degrees, width, thickness, its light)
ARM_BOXES = ((14.0, 14, 7.0, 5.0, "green"), (13.0, 24, 5.4, 3.8, "teal"), (12.0, 6, 3.8, 2.6, "violet"))
ARM_SWING = ((5, 0.5), (7, 1.2), (10, 1.9))  # each joint's swing in degrees, and how late it is
THREADS = 8
THREAD_ANGLES = [math.radians(22.5 + 45 * k) for k in range(THREADS)]
# a thread's boxes: (length, lean out in degrees, how far it trails behind, thickness)
THREAD_BOXES = ((21.0, 3, 0.04, 1.7), (20.0, 5, 0.10, 1.3), (18.0, 8, 0.17, 0.9))
THREAD_VARY = (1.0, 0.86, 0.95, 0.8, 1.0, 0.84, 0.93, 0.88)  # no two alike
THREAD_SWING = ((4, 0.8), (7, 1.7), (11, 2.6))


def unit(v):
    n = math.sqrt(sum(a * a for a in v))
    return tuple(a / n for a in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def hang(angle, lean, trail=0.0):
    """the three directions of a box that hangs at `angle` round the bell's axis: along it (down, leaning out by `lean`
    degrees and trailing behind by `trail`), across it (round the bell) and through it (outward)"""
    r, f = (math.cos(angle), math.sin(angle), 0.0), math.radians(lean)
    along = unit((math.sin(f) * r[0] + trail, math.sin(f) * r[1], -math.cos(f)))
    across = unit(cross(along, r))
    return along, across, cross(across, along)


def thread_axis(k):
    """a thread sways in and out and a little fore and aft: one slanting axis each"""
    across = hang(THREAD_ANGLES[k], 0)[1]
    return unit((across[0], across[1] + 1.2, 0.0))


def beat(phase):
    return math.sin(phase) + 0.3 * math.sin(2 * phase)  # opens slowly, shuts fast


def pose(parts, phase):
    """a slow pulse: the skirt's four flaps open and shut; the arms follow, each joint a little later; a wave runs down
    every thread, each thread a little out of step with the next"""
    swing = math.radians(9) * beat(phase)
    parts["SkirtR"].rotation_euler.x = swing
    parts["SkirtL"].rotation_euler.x = -swing
    parts["SkirtB"].rotation_euler.y = -swing
    parts["SkirtF"].rotation_euler.y = swing
    for k, angle in enumerate(ARM_ANGLES):
        axis = hang(angle, 0)[1]
        for j, (deg, late) in enumerate(ARM_SWING):
            ob = parts[f"A{k + 1}{'abc'[j]}"]
            ob.rotation_mode = "AXIS_ANGLE"
            ob.rotation_axis_angle = (math.radians(deg) * beat(phase - late), *axis)
    for k in range(THREADS):
        axis = thread_axis(k)
        for j, (deg, late) in enumerate(THREAD_SWING):
            ob = parts[f"T{k + 1}{'abc'[j]}"]
            ob.rotation_mode = "AXIS_ANGLE"
            ob.rotation_axis_angle = (math.radians(deg) * math.sin(phase - late - 0.8 * k), *axis)


def disc(n):
    """a circle in cubes, n out from the middle, cut in broad steps (a wide flat side, two steps at each corner; one step
    when it is small): the set of its columns (i, j)"""
    if n <= 8:
        a = round(0.45 * n)
        steps = ((a, n), (n, a))
    else:
        a, b, c = round(0.42 * n), round(0.71 * n), round(0.83 * n)
        steps = ((a, n), (b, c), (c, b), (n, a))
    cells = set()
    for i in range(-n, n + 1):
        out = next(o for upto, o in steps if abs(i) <= upto)
        cells.update((i, j) for j in range(-out, out + 1))
    return cells


def rim(cells, t):
    """the columns of a disc within t of its edge"""
    return {(i, j) for i, j in cells if any((i + a, j + b) not in cells for a in range(-t, t + 1) for b in range(-t, t + 1))}


def fill(p, cols, z0, z1, colour):
    for i, j in cols:
        for k in range(z0, z1):
            p.cells[(i, j, k)] = colour


def build(m):
    # the bell: three round blocks, each lighter on its top and with one line of light round its rim
    bell = m.part("Bell", (CX, 0, Z))
    for n, z0, z1, light in TIERS:
        cols = disc(n)
        fill(bell, cols, Z + z0, Z + z1, "indigo")
        fill(bell, cols, Z + z1 - 1, Z + z1, "indigo+")
        if light:
            fill(bell, rim(cols, 1), Z + z1 - 1, Z + z1, light)
    fill(bell, disc(24) - rim(disc(24), 1), Z, Z + 1, "indigo-")  # its underside
    # the seat: the cap is cut away either side of the rider, so the legs hang down to the plateau
    bell.carve_pair(-1, 2, 3, 5, Z + 17, Z + 20)
    # the block under the middle that the arms hang from
    fill(bell, disc(9), Z - 5, Z, "frill")
    fill(bell, disc(9), Z - 5, Z - 4, "frill-")

    # the skirt: the rim's underside as four flaps, each on a hinge along its side of the bell, with blunt tabs hanging
    # from it. A sleeve reaches a cube up into the wall, so an open flap shows no gap
    edge = rim(disc(24), 3)
    for name, sx, sy in (("SkirtF", -1, 0), ("SkirtB", 1, 0), ("SkirtR", 0, 1), ("SkirtL", 0, -1)):
        flap = m.part(name, (CX + 23 * sx, 23 * sy, Z), "Bell")
        for i, j in edge:
            mine = (abs(i) >= 18 and i * sx > 0) if sx else (abs(i) < 18 and j * sy > 0)
            if not mine:
                continue
            u, v = (abs(j), abs(i)) if sx else (abs(i), abs(j))  # along the flap from its middle, and outward
            fill(flap, [(i, j)], Z - 1, Z, "frill")
            if (v >= 22 and (u <= 2 or 6 <= u <= 9)) or (18 <= v <= 20 and 12 <= u <= 16):
                fill(flap, [(i, j)], Z - 4, Z - 1, "frill")
                fill(flap, [(i, j)], Z - 4, Z - 3, "frill-")
            if u <= 9 and v in (22, 23):
                fill(flap, [(i, j)], Z, Z + 1, "indigo-")

    # the four arms: three boxes on three joints, each smaller than the last and starting inside it. A ruffle either
    # side in two steps (a wider plate, then a narrower, thinner one), and a line of light down the outer face
    for k, angle in enumerate(ARM_ANGLES):
        start, parent = (CX + 5.2 * math.cos(angle), 5.2 * math.sin(angle), Z - 2.0), "Bell"
        for j, (length, lean, wide, thick, light) in enumerate(ARM_BOXES):
            along, across, through = hang(angle, lean, 0.05 * (j + 1))
            part = m.part(f"A{k + 1}{'abc'[j]}", at(start, along, 0.6), parent)

            def box(t0, t1, w, t, colour, out=0.0):
                part._oriented(at(at(start, along, (t0 + t1) / 2), through, out), along, across, through, (t1 - t0, w, t), colour, False)

            box(0.0, length, wide, thick, "indigo")
            first = 3.6 if j == 0 else 1.6  # clear of the block under the bell, and of the ruffle of the box before
            box(first, 0.62 * length, wide + 3.6, 1.3, "frill")
            box(0.5 * length, length - 0.35, wide + 1.9, 0.9, "frill-")
            box(first + 0.4, length - 0.7, 1.4, 0.6, light, out=thick / 2)
            start, parent = at(start, along, length - 1.2), part.name

    # the threads: three thin boxes on three joints, hanging from under the rim, trailing a little behind. The last is light
    for k, angle in enumerate(THREAD_ANGLES):
        start, parent = (CX + 19.0 * math.cos(angle), 19.0 * math.sin(angle), Z + 1.5), "Bell"
        for j, (length, lean, trail, thick) in enumerate(THREAD_BOXES):
            length *= THREAD_VARY[k]
            along, across, through = hang(angle, lean, trail)
            part = m.part(f"T{k + 1}{'abc'[j]}", at(start, along, 2.1 if j == 0 else 0.6), parent)
            colour = ("frill", "frill-", ("green", "teal")[k % 2])[j]
            part._oriented(at(start, along, length / 2), along, across, through, (length, thick, thick), colour, False)
            start, parent = at(start, along, length - 1.2), part.name
