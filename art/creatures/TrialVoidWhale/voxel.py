"""The Void Whale (zone 7's SECRET), remodelled for workout 11 (docs/style/11-rare-wow-study.md, round 1).
Its idea, kept: a whale-shaped hole full of stars. Now in two layers: an electric indigo skin over a near-black core, the
core showing through the belly as deep space with a glowing nebula in it, and a pale lavender crystal shell breaking out
of the back like comet fragments.
- The outline is the old humpback's (three staircases that never step at one x: the plan, the belly, the back), the head
  a flat lid on a deep jaw, six pieces on six joints, long flippers and a fluke on their own joints.
- Colour from the top down: the back in light indigo, the flanks in electric indigo, one row of deep indigo, then the void.
  The line between skin and void runs in three broad waves.
- Glow as shapes (about a quarter of the side view): two big nebula clouds in the void, each fading magenta to violet to
  cyan, with ragged stepped edges; a dozen big star crosses; a cyan rim on the
  outline: the keel under the belly, the mouth, the trailing edges of the flippers and the fluke.
- The shell: faceted lavender crystals rising from the back behind the seat, the first as tall as a third of the body,
  each leaning back like a comet's fragment, a smaller pair beside the first two; two splinters float above them.
- A calm white eye in a cyan ring; its breath is stars (the part `Spout`).
The rider sits on the shoulder, in front of the crystals."""
import math
import random

NAME, ZONE, RARITY = "Void Whale (trial)", "ZONE 7 / MIDNIGHT", "SECRET"
U = 0.5
PALETTE = {"sky": "#5B40F4", "indigo": "#3A1FD6", "deep": "#23128C", "void": "#0C0826", "shell": "#D8CCFF",
           "magenta": "#FF2FD2", "violet": "#9A4BFF", "cyan": "#2FE4FF", "star": "#FFFFFF"}
SHADE = 0.9
SEAT = (-8, 8, 8.5)
GLOW = {"magenta": 0.9, "violet": 0.9, "cyan": 0.9, "star": 1.0}
FLOATING = ["Spout", "Splinters"]  # the breath of stars, and the crystal splinters over the back
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["sky"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0

# the three outlines, each a staircase of (from x, value): cubes out to the side, the belly, the back. No two step at one x
N = ((-40, 3), (-39, 4), (-37, 5), (-34, 6), (-30, 7), (-24, 8), (-3, 7), (4, 6), (10, 5), (16, 4), (23, 3), (30, 2))
BOT = ((-40, -4), (-38, -5), (-36, -6), (-33, -7), (-31, -8), (-28, -9), (-5, -8), (1, -7), (6, -6), (11, -5), (17, -4), (22, -3), (27, -2))
TOP = ((-39, 2), (-35, 3), (-29, 4), (-26, 5), (-22, 6), (-17, 7), (-12, 8), (9, 7), (19, 6), (28, 5))
NOSE, LID_FROM, SKULL_FROM, END = -40, -39, -22, 38  # in front of SKULL_FROM the head is a lid on a jaw, split at z = 0
JOINTS = (-17, -5, 6, 16, 23, 30)  # where the body's pieces begin
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(JOINTS))] + ["Tail", "Fluke"]
AMPLITUDES = [1.5, 2.5, 4, 5, 6, 7, 8, 14]

# the nebula: two clouds on both flanks: (from x, to x, the middle's height at the front and at the back, the most it
# reaches up and down from it, a seed for its ragged edge). Each fades magenta to violet to cyan along its length
CLOUDS = ((-33, -14, -4.5, -4.0, 2.6, 11), (-4, 12, -3.6, -2.0, 2.2, 23))
# the stars: crosses (arms of 2 cubes, or 3 for the biggest), (x, z) of the middle on each flank; a few near the clouds
STARS = ((-37, -4, 2), (-26, -4, 2), (-14, 1, 2), (-9, -3, 3), (5, 1, 2), (14, -2, 2), (22, 2, 2))
TOP_STARS = ((-20, 3), (-20, -3))  # on the back, in front of the seat


def pose(parts, phase):
    """a whale's swim: the wave runs down the body up and down and ends in the fluke's beat; the long flippers row slowly;
    the stars of its breath sway round the blowhole"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(11) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(5) * math.sin(phase - 1.8)
    parts["Spout"].rotation_euler.z = math.radians(28) * math.sin(phase)
    parts["Splinters"].rotation_euler.x = math.radians(6) * math.sin(phase - 1.0)


def at(profile, x):
    """the value of a staircase at x"""
    return ([v for x0, v in profile if x0 <= x] or [profile[0][1]])[-1]


def steps(n):
    """the corners of a slice: a broad shoulder where the body is thick, less as it thins"""
    return [(3, 1), (1, 2)] if n >= 7 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def lid_steps(n):
    return [(2, 1), (1, 1)] if n >= 5 else [(1, 1)]


def rows(n):
    return sum(tall for _, tall in steps(n))


def lerp(a, b, f):
    return tuple(p + (q - p) * f for p, q in zip(a, b))


def skin_line(x):
    """the lowest row of indigo skin at x: halfway down the body, in three broad waves; the mouth line on the head"""
    if x < SKULL_FROM:
        return 0
    wave = math.sin((x + 22) * 2 * math.pi / 26)
    return math.floor(at(BOT, x) + 0.56 * (at(TOP, x) - at(BOT, x)) + 0.5) + (1 if wave > 0.55 else (-1 if wave < -0.55 else 0))


def jitter(x, z):
    """a fixed ragged edge for the clouds, -1 to 1 per cube"""
    h = (x * 73856093) ^ (z * 19349663)
    return ((h % 1000) / 500.0) - 1.0


def crystal(p, base, tip, r, colour, body=0.68, mirror=False):
    """a faceted crystal: a four-sided prism turned so its edges face front, back and sides, widening a little from its
    buried base, then a point"""
    a = [t - b for b, t in zip(base, tip)]
    length = math.sqrt(sum(v * v for v in a))
    a = [v / length for v in a]
    ref = (0.0, 1.0, 0.0) if abs(a[1]) < 0.9 else (1.0, 0.0, 0.0)
    dot = sum(x * y for x, y in zip(a, ref))
    u = [y - dot * x for x, y in zip(a, ref)]
    n = math.sqrt(sum(v * v for v in u))
    u = [v / n for v in u]
    w = [a[1] * u[2] - a[2] * u[1], a[2] * u[0] - a[0] * u[2], a[0] * u[1] - a[1] * u[0]]
    mid = [b + v * length * body for b, v in zip(base, a)]
    corners = (u, w, [-v for v in u], [-v for v in w])
    verts = [tuple(b + c * r * 0.8 for b, c in zip(base, d)) for d in corners]
    verts += [tuple(m + c * r for m, c in zip(mid, d)) for d in corners]
    verts.append(tuple(tip))
    faces = [(3, 2, 1, 0)] + [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)] + [(4 + i, 4 + (i + 1) % 4, 8) for i in range(4)]
    p.solid(verts, faces, colour, mirror)


def outer(p, x, z, side):
    """the outermost cube of the part at (x, z) on one side"""
    if p is None:
        return None
    js = [c[1] for c in p.cells if c[0] == x and c[2] == z]
    return (max(js) if side > 0 else min(js)) if js else None


NEAR = ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, -1), (3, 0), (-3, 0))  # where a star may slide to


def cross(arm):
    """a star: a cube with four arms `arm` cubes long"""
    return ((0, 0),) + tuple((a * k, b * k) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)) for k in range(1, arm + 1))


def nebula():
    """the clouds as {(x, z): colour}: each column of a cloud spans a stretch of rows whose top and bottom wander in steps
    of 1 to 3 cubes every 1 to 3 columns, deepest in the middle and thin at the ends; the colour runs magenta, violet,
    cyan from front to back, the borders between them stepped too"""
    gas = {}
    for x0, x1, z0, z1, reach, seed in CLOUDS:
        rng = random.Random(seed)
        up = down = 0
        hold = 0
        for x in range(x0, x1 + 1):
            t = (x - x0) / (x1 - x0)
            if hold <= 0:
                up = max(-1, min(2, up + rng.choice((-2, -1, 1, 2))))
                down = max(-1, min(2, down + rng.choice((-2, -1, 1, 2))))
                hold = rng.randint(2, 3)
            hold -= 1
            body = reach * math.sin(math.pi * t) ** 0.6
            mid = z0 + (z1 - z0) * t
            top, bottom = round(mid + body + up), round(mid - body - down)
            for z in range(bottom, top + 1):
                f = t + 0.12 * ((z * 7 + x * 3) % 3 - 1)
                gas[(x, z)] = "magenta" if f < 0.3 else ("violet" if f < 0.6 else "cyan")
    return gas


def side_star(part_at, x, z, shape, side):
    """a star painted flush on a flank: every cube of it must lie on one flat face"""
    spots = [(x + a, z + b) for a, b in shape]
    js = [outer(part_at(a), a, b, side) for a, b in spots]
    if None in js or len(set(js)) > 1:
        return False
    for (a, b), j in zip(spots, js):
        part_at(a).cells[(a, j, b)] = "star"
    return True


def top_star(part_at, x, j, shape):
    spots = [(x + a, j + b) for a, b in shape]
    ks = [max([c[2] for c in part_at(a).cells if c[0] == a and c[1] == b], default=None) for a, b in spots]
    if None in ks or len(set(ks)) > 1:
        return False
    for (a, b), k in zip(spots, ks):
        part_at(a).cells[(a, b, k)] = "star"
    return True


def build(m):
    head = m.part("Head", (JOINTS[0], 0, 0))
    segs = [m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}") for i, x in enumerate(JOINTS)]
    starts = [NOSE] + list(JOINTS)
    places = [(p, x0, x1) for p, x0, x1 in zip([head] + segs, starts, starts[1:] + [END])]

    def part_at(x):
        for p, x0, x1 in places:
            if x0 <= x < x1:
                return p
        return None

    # the cubes: one run for every stretch between two steps of any of the three outlines
    cuts = sorted({x for prof in (N, BOT, TOP) for x, _ in prof} | set(JOINTS) | {NOSE, SKULL_FROM, END})
    for x0, x1 in zip(cuts, cuts[1:]):
        p, n, bot = part_at(x0), at(N, x0), at(BOT, x0)
        if x0 >= SKULL_FROM:
            p.hull(x0, x1, n, bot, at(TOP, x0), "void", steps(n), steps(n))
            continue
        p.hull(x0, x1, n, bot, 0, "void", (), steps(n))
        if x0 >= LID_FROM:
            p.hull(x0, x1, n - 1, 0, at(TOP, x0), "void", lid_steps(n - 1), ())
    for seg, x in zip(segs, JOINTS):
        n, fn = at(N, x), at(N, x - 1)
        clear = max(rows(n), rows(fn))
        seg.sym(x - 1, x, max(min(n, fn) - 2, 0), max(at(BOT, x), at(BOT, x - 1)) + clear, min(at(TOP, x), at(TOP, x - 1)) - clear, "void")

    gas = nebula()
    # ---- the colours of the body, from the top down: the back light, the flanks electric, one deep row, then the void
    # with the nebula in it, and the keel lit
    for p in [head] + segs:
        for (x, j, z) in list(p.cells):
            top, bot, line = at(TOP, x), at(BOT, x), skin_line(x)
            if z == top - 1 and z >= line:
                colour = "sky"
            elif z >= top - 3 and z >= line:
                colour = "indigo"
            elif z >= line:
                colour = "deep"
            else:
                colour = "void"
            if z == bot:
                colour = "cyan"
            elif j != 0 and bot + 2 <= z < top - 3 and (x, z) in gas:
                colour = gas[(x, z)]
            p.cells[(x, j, z)] = colour
    # the lit mouth: the jaw's top row along its side and across the chin, under the lid
    for x in range(NOSE, SKULL_FROM):
        n = at(N, x)
        for z in (-1,):
            for j in (n, -n):
                if (x, j, z) in head.cells:
                    head.cells[(x, j, z)] = "cyan"
    for j in range(-at(N, NOSE), at(N, NOSE) + 1):
        head.cells[(NOSE, j, -1)] = "cyan"

    # ---- the stars, flush in the surface
    placed = 0
    for side in (1, -1):
        for x, z, arm in STARS:
            placed += any(side_star(part_at, x + dx, z + dz, cross(arm), side) for dx, dz in NEAR)
    placed += sum(top_star(part_at, x, j, cross(2)) for x, j in TOP_STARS)
    print(f"  stars: {placed} of {2 * len(STARS) + len(TOP_STARS)} placed (not cubes, a check)")
    # each crystal of the middle row stands in a lit socket: a diamond of cyan on the back round its base
    for bx, reach in ((3, 4), (12, 3), (20, 2), (26, 1)):
        p = part_at(bx)
        for (x, j, z) in list(p.cells):
            if z == at(TOP, x) - 1 and abs(x - bx) + abs(j) <= reach and part_at(x) is p:
                p.cells[(x, j, z)] = "cyan"

    # the blowhole's guard: a low block on the lid that runs into the skull
    guard = (-1.5, 1.5, 4.6, 5.6)
    head.block(-25.6, guard, -21.5, guard, "sky")
    # the eye: calm, a wide block of white light in a cyan ring, at the corner of the mouth
    halo = (8.3, 8.75, 0.2, 2.8)
    head.block(-22.4, halo, -18.6, halo, "cyan", mirror=True)
    eye = (8.3, 9.05, 0.6, 2.4)
    head.block(-21.9, eye, -19.1, eye, "star", mirror=True)

    # the breath: star cubes that float above the blowhole
    spout = m.part("Spout", (-24, 0, 5), "Head")
    for (x, y, z), size, colour in (((-24.0, 0.0, 7.6), 1.1, "star"), ((-23.1, 1.0, 9.2), 0.9, "cyan"), ((-24.6, -0.9, 10.5), 0.9, "magenta"),
                                    ((-22.6, -0.4, 12.0), 0.7, "star"), ((-23.5, 1.1, 13.4), 0.6, "cyan"),
                                    ((-21.8, 0.3, 14.6), 0.5, "magenta")):
        h = size / 2
        spout.block(x - h, (y - h, y + h, z - h, z + h), x + h, (y - h, y + h, z - h, z + h), colour)

    # ---- the shell: crystals rising from the back behind the seat, leaning back like a comet's fragments. Each base is
    # buried two cubes deep in the top of its piece; the first stands a third of the body's height above the back
    crystal(segs[1], (1.5, 0.0, 5.6), (8.5, 0.0, 17.5), 2.4, "shell")
    crystal(segs[1], (3.4, 1.8, 5.8), (8.0, 5.8, 13.2), 1.4, "shell+", mirror=True)
    crystal(segs[2], (11.0, 0.0, 4.8), (16.5, 0.0, 14.0), 1.9, "shell")
    crystal(segs[2], (12.8, 1.5, 4.8), (16.0, 4.6, 10.8), 1.1, "shell+", mirror=True)
    crystal(segs[3], (19.2, 0.0, 4.0), (24.0, 0.0, 11.2), 1.5, "shell")
    crystal(segs[4], (25.2, 0.0, 3.0), (29.2, 0.0, 8.2), 1.1, "shell")
    # two splinters float behind the tallest, as if broken off it
    splinters = m.part("Splinters", (8.5, 0, 14), "S2")
    crystal(splinters, (10.6, 0.0, 17.9), (12.8, 0.0, 19.9), 0.65, "shell+")
    crystal(splinters, (13.6, 0.0, 16.4), (15.3, 0.0, 17.9), 0.45, "shell+")

    # the flippers, each on its own joint: a humpback's, a third of its length, in indigo, the tip lit cyan
    a, b, c, d = (-14.5, 5.0, -6.0), (-11.5, 11.5, -7.5), (-3.5, 15.5, -9.3), (2.0, 17.8, -10.4)
    b2 = lerp(a, b, 0.72)
    b3 = lerp(b2, c, 0.8)
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (-14.5, 7.5 * side, -6.0), "S1")
        for p0, p1, wide, thick, colour in ((a, b, 5.0, 1.5, "indigo"), (b2, c, 4.4, 1.1, "indigo"), (b3, d, 3.0, 0.7, "cyan")):
            part.beam((p0[0], p0[1] * side, p0[2]), (p1[0], p1[1] * side, p1[2]), wide, thick, colour, flat="z")

    # the tail: a stock taller than it is wide, then the fluke on a joint of its own: a hub and two lobes swept back, each
    # ending in a thinner tip, rimmed in cyan along the trailing edge
    end, mid = END, 1.5
    tail = m.part("Tail", (end, 0, mid), f"S{len(JOINTS)}")
    tail.beam((end - 0.5, 0, mid), (end + 3, 0, mid), 2.6, 4.0, "indigo", flat="z")
    fluke = m.part("Fluke", (end + 2, 0, mid), "Tail")
    fluke.beam((end + 1.5, 0, mid), (end + 5.5, 0, mid), 9.0, 2.2, "indigo", flat="z")
    notch = (-1.9, 1.9, mid - 0.5, mid + 0.5)
    fluke.block(end + 5.0, notch, end + 5.8, notch, "cyan")
    for p0, p1, wide, thick, rim in (((end + 3.0, 2.5), (end + 8.0, 9.5), 5.6, 1.4, 1.8), ((end + 6.8, 8.0), (end + 9.5, 12.5), 3.6, 0.8, 1.1)):
        fluke.beam((p0[0], p0[1], mid), (p1[0], p1[1], mid), wide, thick, "indigo", flat="z", mirror=True)
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        length = math.hypot(dx, dy)
        ax, ay = dx / length, dy / length
        ox, oy = ay * (wide / 2 - 0.25), -ax * (wide / 2 - 0.25)
        fluke.beam((p0[0] + ox, p0[1] + oy, mid), (p1[0] + ox + ax * 0.25, p1[1] + oy + ay * 0.25, mid), 1.0, rim, "cyan", flat="z",
                   mirror=True)
