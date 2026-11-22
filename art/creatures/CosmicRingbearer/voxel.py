"""Ringbearer, a COSMIC (docs/design/cosmic.md, concept 6) for tools/blender/voxel_kit.py: a turtle whose shell is a
banded planet. The body under it, the head, the flippers and the tail are from the Archelon (art/creatures/Archelon,
not changed), made calm: one dusky blue, a pale plastron, a dark beak.
- The planet: a round ball, not a dome of plates. Gas-giant belts in a calm palette (cream, sand, ochre, rust), their
  edges wavering as if they flowed; a hexagon of storm round the north pole, where the rider sits; one oval storm on the
  front-left flank.
- The ring: ice shards (long double points, glowing pale blue, some dark) in two bands with a gap between, tilted
  26 degrees so its front rises high ahead of the rider and its back passes under the tail. It turns once a swim.
- Two moons, each on its own joint, orbiting the planet: a glowing pale moon far out, steeply tilted, once a swim, which
  carries the creature's one light; and a dark cratered moon closer in, near the ring's plane, twice a swim.
The rider sits on the pole. The turtle's head, flippers and tail come out from under the planet, below the ring."""
import math
import random

NAME, ZONE, RARITY = "Ringbearer", "UNPLACED", "COSMIC"
U = 0.6
PALETTE = {"skin": "#3F5872", "under": "#2B3A4E", "belly": "#A9B8C6", "horn": "#232A3A", "black": "#0E1117", "soft": "#BFEFFF",
           "pole": "#F4ECD6", "cream": "#EBD8B0", "sand": "#DDBA84", "ochre": "#C88D4C", "rust": "#A5553A", "deep": "#713629",
           "storm": "#C4432D", "eye": "#F4AE62",
           "ice": "#E8FBFF", "ice2": "#9EDDF4", "frost": "#5F86AE",
           "lumen": "#E2F7FF", "lumen2": "#A9DDF3", "rock": "#6E6779", "rock2": "#4C4659", "dust": "#9C806C"}
SEAT = (0, 16, 2.0)
GLOW = {"ice": 0.9, "ice2": 0.55, "lumen": 1.0, "lumen2": 0.6, "soft": 0.4}
KEEP = ["black", "soft", "ice", "ice2", "frost", "lumen", "lumen2", "storm", "eye"]
R = 16  # the planet's radius, in cubes, round (0, 0, 0)
BASE = -9  # the planet stops here; the turtle's body is under it
TILT = 26  # degrees: the ring's front rises, its back sinks
# the ring's two bands: from, to (cubes from the middle), plates, the gap between plates (radians), thickness, colour
BANDS = ((20.0, 24.2, 30, 0.035, 0.5, "ice2"), (25.4, 28.6, 26, 0.06, 0.4, "frost"))
SHARDS = 30
MOON_A = (40, 40, 3.0)  # the glowing moon: orbit radius, tilt in degrees (front up), its own radius
MOON_B = (33, 10, 2.6)  # the dark moon
MOON_A_AT = (-MOON_A[0] * math.cos(math.radians(MOON_A[1])), 0.0, MOON_A[0] * math.sin(math.radians(MOON_A[1])))
LIGHTS = [("MoonA", MOON_A_AT, "#BFE8FF", 130, 1.6)]
FLOATING = ["Ring", "MoonA", "MoonB"]
FRAME, ORTHO, ORTHO_SWIM = 4.2, 64.0, 68.0


def tilted(t):
    """the normal of a plane tilted t degrees front-up (about the y axis)"""
    a = math.radians(t)
    return (math.sin(a), 0.0, math.cos(a))


def tilt_point(p, t):
    """a point in the flat plane (z up) turned t degrees so its front (-x) rises"""
    a = math.radians(t)
    x, y, z = p
    return (x * math.cos(a) + z * math.sin(a), y, -x * math.sin(a) + z * math.cos(a))


def pose(parts, phase):
    """it flies like the Archelon, gently; the ring turns once a swim about its own leaning axis; the far moon once, the
    near moon twice (whole turns: the game blends the last key back to the first)"""
    for tag, side in (("R", 1), ("L", -1)):
        parts[f"Wing{tag}1"].rotation_euler.x = side * math.radians(15) * math.sin(phase)
        parts[f"Wing{tag}2"].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.9)
        parts[f"Wing{tag}3"].rotation_euler.x = side * math.radians(9) * math.sin(phase - 1.8)
        parts[f"FlipB{tag}"].rotation_euler.z = math.radians(8) * math.sin(phase + 1.2)
        parts[f"FlipB{tag}"].rotation_euler.x = side * math.radians(5) * math.sin(phase + math.pi)
    parts["Shell"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi / 2)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 0.5)
    parts["Jaw"].rotation_euler.y = -math.radians(7) * (0.5 + 0.5 * math.sin(phase + 2.0))
    parts["Tail"].rotation_euler.z = math.radians(7) * math.sin(phase - 1.5)
    for name, turns, t in (("Ring", 1, TILT), ("MoonA", 1, MOON_A[1]), ("MoonB", 2, MOON_B[1])):
        ob = parts[name]
        ob.rotation_mode = "AXIS_ANGLE"
        ob.rotation_axis_angle = (turns * phase, *tilted(t))


def band_of(z, lon):
    """the planet's colour at height z (a cube's middle) and longitude lon: belts whose edges waver"""
    w = z + 0.55 * math.sin(2 * lon + 0.5 * z)
    for top, colour in ((13.2, "pole"), (10.6, "sand"), (8.4, "cream"), (5.6, "ochre"), (2.6, "cream"), (0.4, "rust"),
                        (-2.4, "sand"), (-5.2, "ochre"), (-7.2, "rust")):
        if w >= top:
            return colour
    return "deep"


def fan(part, s, root, droop, rows):
    """boxes lying flat, fanned from `root` like the bones of a hand (the Archelon's flippers)"""
    rx, ry, rz = root

    def at(angle, t, across=0.0, lift=0.0):
        a = math.radians(angle)
        dx, dy = math.sin(a), math.cos(a)
        return (rx + dx * t + dy * across, s * (ry + dy * t - dx * across), rz - droop * t + lift)

    for angle, t0, t1, across, wide, thick, colour in rows:
        part.beam(at(angle, t0, across), at(angle, t1, across), wide, thick, colour, flat="z")
    return at


def ball(p, centre, r, colour, spots=(), spot_colour=None):
    """a voxel ball round centre; cubes whose direction from the middle is near one of `spots` take spot_colour"""
    cx, cy, cz = centre
    for i in range(math.floor(cx - r) - 1, math.ceil(cx + r) + 1):
        for j in range(math.floor(cy - r) - 1, math.ceil(cy + r) + 1):
            for k in range(math.floor(cz - r) - 1, math.ceil(cz + r) + 1):
                d = (i + 0.5 - cx, j - cy, k + 0.5 - cz)
                n = math.sqrt(sum(v * v for v in d))
                if n <= r:
                    near = any(sum(a * b for a, b in zip(d, s)) > 0.82 * n for s in spots) if n > 0 else False
                    p.cells[(i, j, k)] = spot_colour if near else colour


def shard(p, centre, along, size, wide, colour):
    """an ice shard: a long double point (eight faces) round centre, pointing along `along`"""
    ax = [v / math.sqrt(sum(a * a for a in along)) for v in along]
    ref = (0.0, 0.0, 1.0) if abs(ax[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = [ax[1] * ref[2] - ax[2] * ref[1], ax[2] * ref[0] - ax[0] * ref[2], ax[0] * ref[1] - ax[1] * ref[0]]
    nu = math.sqrt(sum(v * v for v in u))
    u = [v / nu for v in u]
    w = [ax[1] * u[2] - ax[2] * u[1], ax[2] * u[0] - ax[0] * u[2], ax[0] * u[1] - ax[1] * u[0]]
    c = centre
    tip0 = tuple(c[a] + ax[a] * size / 2 for a in range(3))
    tip1 = tuple(c[a] - ax[a] * size * 0.32 for a in range(3))  # the back point is short: a shard, not a spindle
    mid = [tuple(c[a] + (u[a] * su + w[a] * sw) * wide / 2 for a in range(3)) for su, sw in ((1, 0), (0, 0.65), (-1, 0), (0, -0.65))]
    verts = [tip0, tip1] + mid
    faces = [(0, 2, 3), (0, 3, 4), (0, 4, 5), (0, 5, 2), (1, 3, 2), (1, 4, 3), (1, 5, 4), (1, 2, 5)]
    p.solid(verts, faces, colour)


def build(m):
    # ---- the planet: the shell. A ball cut off at BASE, the belts by height, the polar hexagon, one storm
    shell = m.part("Shell", (0, 0, 0))
    storm_lon, storm_lat = math.radians(-140), math.radians(15)  # front-left, high: the 3/4 view and the rider see it
    for i in range(-R - 1, R + 1):
        for j in range(-R - 1, R + 2):
            for k in range(BASE, R + 1):
                x, z = i + 0.5, k + 0.5
                r2 = x * x + j * j + z * z
                if r2 > R * R:
                    continue
                lon = math.atan2(j, x)
                colour = band_of(z, lon)
                lat = math.asin(max(-1.0, min(1.0, z / math.sqrt(r2))))
                dl = (lon - storm_lon + math.pi) % (2 * math.pi) - math.pi
                e = (dl / 0.30) ** 2 + ((lat - storm_lat) / 0.15) ** 2
                if e < 1.0:
                    colour = "eye" if e < 0.3 else "storm"
                shell.cells[(i, j, k)] = colour
    # the polar hexagon: a ring of ochre, six-sided, round the rider
    for (i, j, k) in [c for c in shell.cells if c[2] >= 11]:
        x = i + 0.5
        if any((i, j, kk) in shell.cells for kk in range(k + 1, k + 2)):
            continue  # only the top of each column
        hexd = max(abs(x * math.cos(a) + j * math.sin(a)) for a in (0, math.pi / 3, 2 * math.pi / 3))
        if 5.2 <= hexd < 6.6:
            shell.cells[(i, j, k)] = "ochre"

    # the turtle under the planet: the body (dark leather), the plastron, the collar the neck comes out of
    shell.hull(-13, 13, 11, -13, BASE, "under", [], [(2, 1), (1, 1)])
    shell.paint_sym(-13, 13, 11, BASE - 1, BASE, "skin-")
    shell.sym(-11, 11, 7, -14, -13, "belly")
    shell.sym(-9, 9, 5, -15, -14, "belly-")
    shell.hull(-16, -13, 5, -10, -3, "under", [(2, 1), (1, 1)], [(1, 1)])
    shell.paint_pair(-11, -2, 8, 12, -12, -10, "skin")  # where the front flippers leave the body
    shell.paint_pair(8, 12, 6, 10, -13, -11, "skin")

    # ---- the head (the Archelon's, lower and further back), its own joint: dusky skin, a dark hooked beak
    dx, dz = 3, -6
    head = m.part("Head", (-16 + dx, 0, -0.5 + dz), "Shell")
    head.sym(-22 + dx, -19 + dx, 2, -3 + dz, 2 + dz, "skin")
    head.paint_sym(-22 + dx, -19 + dx, 2, -3 + dz, -1 + dz, "belly")
    head.sym(-19 + dx, -16 + dx, 1, -1 + dz, 1 + dz, "skin-")
    head.hull(-28 + dx, -22 + dx, 3, -3 + dz, 3 + dz, "skin", [(1, 1)], [(1, 1)])
    head.sym(-27 + dx, -22 + dx, 4, -2 + dz, 0 + dz, "skin")
    head.paint_sym(-28 + dx, -22 + dx, 4, -3 + dz, -1 + dz, "belly")
    head.paint_sym(-28 + dx, -22 + dx, 3, 2 + dz, 3 + dz, "under")
    head.block(-27.6 + dx, (-2.6, 2.6, -0.9 + dz, 2.4 + dz), -32.4 + dx, (-1.2, 1.2, -1.6 + dz, 0.6 + dz), "horn")
    head.spike([(-32.3 + dx, -1.05, -1.2 + dz), (-30.7 + dx, -1.05, -1.2 + dz), (-30.7 + dx, 1.05, -1.2 + dz), (-32.3 + dx, 1.05, -1.2 + dz)],
               (-31.0 + dx, 0.0, -4.3 + dz), "horn")
    socket = (3.4, 3.85, -0.2 + dz, 2.0 + dz)
    head.block(-25.9 + dx, socket, -23.7 + dx, socket, "under", mirror=True)
    halo = (3.75, 4.0, 0.15 + dz, 1.65 + dz)
    head.block(-25.55 + dx, halo, -24.05 + dx, halo, "soft", mirror=True)
    pupil = (3.9, 4.2, 0.45 + dz, 1.35 + dz)
    head.block(-25.25 + dx, pupil, -24.35 + dx, pupil, "black", mirror=True)
    head.beam((-26.2 + dx, 3.76, 1.55 + dz), (-23.4 + dx, 3.76, 1.95 + dz), 1.0, 1.12, "under", mirror=True)
    jaw = m.part("Jaw", (-27.5 + dx, 0, -1.6 + dz), "Head")
    jaw.block(-27.6 + dx, (-2.2, 2.2, -1.85 + dz, -1.05 + dz), -30.4 + dx, (-1.0, 1.0, -2.05 + dz, -1.5 + dz), "horn-")

    # ---- the flippers (the Archelon's), from under the planet, well below the ring
    fx, fz = 5.5, -9.5
    for s, tag in ((1, "R"), (-1, "L")):
        arm = m.part(f"Wing{tag}1", (-11.5 + fx, 10.5 * s, -1.0 + fz), "Shell")
        at = fan(arm, s, (-11.5 + fx, 9.0, -1.0 + fz), 0.04,
                 ((-8, 0.0, 10.0, -1.6, 1.6, 2.6, "under"), (-8, 0.4, 9.8, 0.3, 3.6, 2.1, "skin"), (2, 0.3, 8.6, 2.9, 2.6, 1.3, "skin")))
        ex, ey, ez = at(-8, 9.6)
        blade = m.part(f"Wing{tag}2", (ex, ey, ez), f"Wing{tag}1")
        at = fan(blade, s, (ex, ey * s, ez), 0.04,
                 ((27, -1.0, 10.6, -1.0, 1.5, 1.8, "under"), (33, -1.6, 10.2, 0.6, 3.0, 1.5, "skin"), (45, -1.4, 9.0, 1.5, 2.8, 1.0, "skin"),
                  (59, -1.2, 7.2, 2.1, 2.6, 0.55, "skin-")))
        wx, wy, wz = at(27, 10.3)
        tip = m.part(f"Wing{tag}3", (wx, wy, wz), f"Wing{tag}2")
        at = fan(tip, s, (wx, wy * s, wz), 0.04,
                 ((46, -1.0, 10.0, -0.8, 1.2, 1.25, "under"), (53, -1.4, 7.8, 0.4, 2.4, 0.8, "skin"), (68, -1.2, 5.6, 1.0, 2.2, 0.35, "skin-")))
        end = 9.8
        tip.spike([at(46, end, -1.2, -0.45), at(46, end, -0.4, -0.45), at(46, end, -0.4, 0.45), at(46, end, -1.2, 0.45)],
                  at(46, end + 2.4, -0.5), "horn")
        back = m.part(f"FlipB{tag}", (11.0, 7.0 * s, -12.5), "Shell")
        fan(back, s, (11.0, 5.5, -12.5), 0.05,
            ((50, -1.5, 9.4, -0.9, 1.4, 1.5, "under"), (58, -1.2, 8.6, 0.5, 2.8, 1.1, "skin"), (73, -0.6, 6.4, 1.3, 2.4, 0.6, "skin-")))

    # ---- the tail: short, low, under the ring's back
    tail = m.part("Tail", (12.0, 0, -13.0), "Shell")
    tail.beam((11.4, 0, -12.8), (17.6, 0, -14.4), 2.6, 1.6, "skin", flat="z")
    tail.beam((16.6, 0, -14.1), (20.4, 0, -15.0), 1.7, 1.1, "skin-", flat="z")
    tail.spike([(19.9, -0.6, -15.4), (19.9, 0.6, -15.4), (19.9, 0.6, -14.5), (19.9, -0.6, -14.5)], (23.0, 0.0, -15.4), "horn")

    # ---- the ring, on its own joint at the planet's middle, in the tilted plane: two bands of flat ice plates with a dark
    # gap between (an inner bright band, an outer darker one in shorter plates), and bright shards standing out of them
    ring = m.part("Ring", (0, 0, 0), "Shell")
    rnd = random.Random(26)
    for (r0, r1, count, gap, thick, colour) in BANDS:
        step = 2 * math.pi / count
        for n in range(count):
            a0, a1 = n * step + gap / 2, (n + 1) * step - gap / 2
            lift = 0.18 if n % 2 else -0.18  # neighbours sit at two heights, so no two faces share a plane
            pts = [(r * math.cos(t), r * math.sin(t)) for r, t in ((r0, a0), (r0, a1), (r1, a1), (r1, a0))]
            verts = [tilt_point((x, y, lift + h), TILT) for h in (-thick / 2, thick / 2) for x, y in pts]
            ring.solid(verts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour)
    for n in range(SHARDS):
        ang = 2 * math.pi * (n + rnd.uniform(0.15, 0.85)) / SHARDS
        rad = rnd.uniform(BANDS[0][0] + 0.6, BANDS[0][1] - 0.4) if n % 3 else rnd.uniform(BANDS[1][0] + 0.4, BANDS[1][1] - 0.4)
        flat = (rad * math.cos(ang), rad * math.sin(ang), 0.0)
        # each stands out of the ring at a slant, along its orbit and up or down
        tang = (-math.sin(ang) + rnd.uniform(-0.5, 0.5), math.cos(ang) + rnd.uniform(-0.5, 0.5), rnd.choice((1, -1)) * rnd.uniform(0.6, 1.3))
        size = rnd.uniform(2.0, 3.4)
        shard(ring, tilt_point(flat, TILT), tilt_point(tang, TILT), size, size * 0.4, "ice")

    # ---- the moons, each on its own joint at the planet's middle
    moon_a = m.part("MoonA", (0, 0, 0), "Shell")
    ball(moon_a, MOON_A_AT, MOON_A[2], "lumen", spots=[(0.6, 0.5, 0.62), (-0.2, -0.7, 0.68), (0.1, 0.9, -0.42)], spot_colour="lumen2")
    moon_b = m.part("MoonB", (0, 0, 0), "Shell")
    b_at = tilt_point((0.0, -MOON_B[0], 0.0), MOON_B[1])
    ball(moon_b, b_at, MOON_B[2], "rock", spots=[(0.5, 0.6, 0.62), (-0.6, -0.3, 0.74), (0.2, -0.8, -0.56), (-0.4, 0.8, 0.45)], spot_colour="rock2")
