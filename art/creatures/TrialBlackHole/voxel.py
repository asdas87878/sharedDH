"""The black hole, a trial prop (docs/design/cosmic.md) for tools/blender/voxel_kit.py: the Hollow's set piece built by
itself, to get it right. Not a creature: nothing rides it. It follows the live study made first (a web page with real
light bending), turned into pieces Roblox can show: meshes of small cubes that glow (Neon) and turn on joints.
What is taken from how a black hole looks:
- The shadow: a matte black ball.
- The photon ring: a thin white-hot ring hugging the ball, and above and below it the two ARCS of light: the far side of
  the disc, bent up over the top and under the bottom by the hole's gravity. The arc over the top is the bigger one.
  The ring and arcs stand upright and face the side. (They are a picture of bent light, so in the game they should be
  turned to face the camera; inside the Hollow's hall they already face its two openings.)
- The disc, in two rings that turn at different speeds, the inner one faster, as orbits do: a thick white-hot inner ring
  and a wide thin outer one that cools from yellow through orange to red, with a ragged edge. Spiral streaks are drawn
  into both, so as the rings turn the matter seems to wind inward. The disc leans (TILT), so its lit face shows from the
  side; the lean is in the swim, not the mesh, so a still picture shows it flat.
- A rim of loose clumps, slowest of all.
- Two jets up the disc's axis, blue-white, each a twisted column: turning it makes the light seem to climb.
Every part floats on purpose (FLOATING). The cubes are 0.25 studs, half a creature's, so the ball is round."""
import math
import os

NAME, ZONE, RARITY = "Black Hole (trial)", "UNPLACED", "COSMIC"
U = 0.25
PALETTE = {"void": "#000000", "white": "#FFF4DC", "yellow": "#FFCB52", "orange": "#FF8526", "red": "#D63A1C", "ember": "#8A2313",
           "jet": "#8FC1FF", "jetw": "#EEF6FF"}
GLOW = {"white": 1.0, "yellow": 0.9, "orange": 0.75, "red": 0.55, "ember": 0.3, "jet": 0.9, "jetw": 1.0}
SEAT = (0, 7, 1.0)  # the kit wants one; nothing rides this
FLOATING = ["Core", "DiscA", "DiscB", "Rim", "JetUp", "JetDown"]
FRAME, ORTHO, ORTHO_SWIM = 1.5, 16.0, 17.0

R = 6.6  # the ball's radius, in cubes
ARC = (6.5, 3.4)  # how thick the arc of bent light is over the top, and under the bottom
JET = 22  # how tall each jet stands above the arcs (0: none, as inside the Hollow's hall)
TILT = 14  # degrees the disc and jets lean toward the side
# turns in one loop: inner ring, outer ring, rim, jets. The game needs whole turns (it blends from the last key back to the
# first). A picture loop of 24 frames is smoother with fewer: every piece looks the same after half a turn, so halves close.
TURNS = (1, 0.5, 0.5, 1) if os.environ.get("BLACK_HOLE_SLOW") else (3, 2, 1, 2)


def pose(parts, phase):
    """the rings turn at their own speeds about the leaning axis; the jets twist the other way"""
    for name, turns in (("DiscA", TURNS[0]), ("DiscB", TURNS[1]), ("Rim", TURNS[2]), ("JetUp", -TURNS[3]), ("JetDown", TURNS[3])):
        if name in parts:
            parts[name].rotation_mode = "ZYX"  # turn about its own axis first, then lean
            parts[name].rotation_euler = (math.radians(TILT), 0.0, turns * phase)


def black_hole(m, parent, cx, cz, jet, rim=True, fine=1, axis="z", face="side", names=None):
    """the whole set piece round (cx, 0, cz), counted in the parts' own cubes (whole numbers, so the ball sits on cube
    edges). Every ring's pattern repeats after half a turn.
    fine: the parts' cubes are this many times smaller than the model's (Part.fine); the pivots are then cx / fine.
    axis: the disc's axis, "z" (the disc lies flat) or "x" (it stands upright, facing along the body).
    face: the picture of bent light (the ring and the arcs), a plate one cube thick: "side" faces across the body (as in
    the side view), "back" faces along it, toward a camera behind the creature, "front" lies in the disc's own plane's
    normal (face on to the disc: then it is a ring, with no arcs, since a hole seen face on shows a ring).
    names: the parts' names, if not Core, DiscA, DiscB, Rim, JetUp, JetDown. Returns the parts by those names."""
    names = names or {}

    def name(n):
        return names.get(n, n)

    def put(p, a, b, c, colour):
        """local (a: across, b: across, c: along the axis), measured from the middle, into the part's cells"""
        if axis == "z":
            p.cells[(cx + math.floor(a), int(b), cz + math.floor(c))] = colour
        else:
            p.cells[(cx + math.floor(c), int(b), cz + math.floor(a))] = colour

    def grid(reach, low, high):
        for i in range(-reach, reach):
            for j in range(-reach, reach + 1):
                for k in range(low, high):
                    yield i + 0.5, float(j), k + 0.5

    def part(n, parent_name):
        p = m.part(name(n), (cx / fine, 0, cz / fine), parent_name)
        p.fine = fine
        return p

    parts = {}
    core = parts["Core"] = part("Core", parent)
    for a, b, c in grid(15, -15, 15):
        if a * a + b * b + c * c <= R * R:
            put(core, a, b, c, "void")
            continue
        # the plate of bent light: one cube thick, left out where the disc crosses it
        if face == "side":
            on, u, v = b == 0, a, c  # v: up the plate
        elif face == "back":
            on, u, v = a == 0.5, b, c
        else:
            on, u, v = c == 0.5, a, b
        if not on or (face != "front" and abs(v) < 3):
            continue
        rho = math.hypot(u, v)
        if face == "front":
            arc = 2.2  # face on: an even ring all round
        else:
            arc = (ARC[0] if v > 0 else ARC[1]) * (abs(v) / rho) ** 2.5  # thickest at the very top; the lower arc smaller
        if rho <= R + 1.3:
            put(core, a, b, c, "white")
        elif rho <= R + 1.3 + arc:
            put(core, a, b, c, "yellow" if rho <= R + 1.3 + arc * 0.45 else "orange")

    da = parts["DiscA"] = part("DiscA", name("Core"))  # the hot inner ring: four cubes thick
    for a, b, c in grid(14, -2, 2):
        r, t = math.hypot(a, b), math.atan2(b, a)
        if 9.2 <= r < 13.4:
            put(da, a, b, c, "yellow" if math.sin(4 * t - 5 * math.log(r)) > 0.5 else "white")

    db = parts["DiscB"] = part("DiscB", name("Core"))  # the wide outer ring: two cubes thick, cooling outward, ragged edge
    for a, b, c in grid(23, -1, 1):
        r, t = math.hypot(a, b), math.atan2(b, a)
        if not 13.4 <= r < 22.4:
            continue
        streak = math.sin(2 * t + 6 * math.log(r))
        if (r > 17.5 and streak < -0.8) or (r > 20.6 and math.sin(8 * t + 1.3) > 0.2):
            continue  # gaps along the streaks, and bites out of the edge
        heat = (0 if r < 16.0 else 1 if r < 19.4 else 2) - (1 if streak > 0.55 else 0)
        put(db, a, b, c, ("white", "yellow", "orange", "red")[heat + 1])

    if rim:
        p = parts["Rim"] = part("Rim", name("Core"))  # loose clumps beyond the disc
        for a, b, c in grid(28, -1, 1):
            r, t = math.hypot(a, b), math.atan2(b, a)
            if 24.2 <= r < 27.2 and math.sin(4 * t + 1.1 * r) > 0.6:
                put(p, a, b, c, "ember" if math.sin(12 * t) > 0 else "red")

    if jet:
        start = math.ceil(R + 1.3 + (ARC[0] if face != "front" else 2.2)) + 1  # the first row past the arc
        for n_, sign in (("JetUp", 1), ("JetDown", -1)):
            p = parts[n_] = part(n_, name("Core"))
            for n in range(jet):
                c = sign * (start + n + 0.5)
                colour = "jetw" if n % 6 < 3 else "jet"
                for a in (-0.5, 0.5):
                    for b in ((-1, 0, 1) if n < jet - 5 else (0,)):
                        put(p, a, b, c, colour)
                if n < jet - 7 and n % 2 == 0:  # a pair of nubs that wind round the column
                    ang = n * math.radians(28)
                    a, b = round(2.7 * math.cos(ang) - 0.5) + 0.5, round(2.7 * math.sin(ang))
                    put(p, a, b, c, "jet")
                    put(p, -a, -b, c, "jet")
    return parts


def build(m):
    black_hole(m, None, 0, 0, JET)
