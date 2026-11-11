"""The Void Whale (zone 7's SECRET) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed by
docs/style/05-rarity-look.md ("Ways to feel Mythic": void, light, impossible parts).
Its idea: a whale-shaped hole full of stars. The outline is a plain humpback in the darkest navy; everything bright on it
is a star, or the thin line of light that draws its edge.
- The outline first, as three staircases that never step at the same place (`N`, `BOT`, `TOP`: the plan, the belly, the
  back). A deep throat and chest that rise to a tall, narrow tail stock; a back that climbs from a flat snout to the
  shoulder and falls again behind a small hump; a plan that is round at the nose, widest at the flippers and thin at the
  tail.
- The head has its own shape: a flat, narrow lid (the upper jaw) lying on a wider, much deeper lower jaw whose chin juts
  out in front, so the mouth is the ledge between them. It ends at the full block of the skull, where the eye sits.
- A whale is stiff: the body is six pieces on six joints, short ones toward the tail, not a joint to every slice.
- The body is one colour. Stars are single cubes set flush in the surface (white, pale blue, violet; scattered by a fixed
  seed, never close together), a few bigger ones (a white cube with four coloured ones round it), and one small spiral on
  each flank.
- A thin line of pale light runs down the middle of the back from the blowhole to the tail, and round the fluke's
  trailing edge.
- Its breath is stars: six small cubes float above the blowhole (the part `Spout`, declared in FLOATING).
- A calm white eye: a low, wide block of light at the corner of the mouth, no pupil.
The rider sits on the shoulder, on the line of light, in front of the hump."""
import math
import random

NAME, ZONE, RARITY = "Void Whale", "ZONE 7 / MIDNIGHT", "SECRET"
U = 0.5
PALETTE = {"void": "#0E1434", "star": "#FFFFFF", "ice": "#A4D2FF", "violet": "#B48CFF"}
SEAT = (-8, 8, 8.5)
GLOW = {"star": 1.0, "ice": 0.9, "violet": 0.9}  # the stars, the rim line, the eye
FLOATING = ["Spout"]  # the breath of stars above the blowhole
FRAME, ORTHO, ORTHO_SWIM = 3.7, 52.0, 58.0

# the three outlines, each a staircase of (from x, value): cubes out to the side, the belly, the back. No two step at one x
N = ((-40, 3), (-39, 4), (-37, 5), (-34, 6), (-30, 7), (-24, 8), (-3, 7), (4, 6), (10, 5), (16, 4), (23, 3), (30, 2))
BOT = ((-40, -4), (-38, -5), (-36, -6), (-33, -7), (-31, -8), (-28, -9), (-5, -8), (1, -7), (6, -6), (11, -5), (17, -4), (22, -3), (27, -2))
TOP = ((-39, 2), (-35, 3), (-29, 4), (-26, 5), (-22, 6), (-17, 7), (-12, 8), (9, 7), (19, 6), (28, 5))
NOSE, LID_FROM, SKULL_FROM, END = -40, -39, -22, 38  # in front of SKULL_FROM the head is a lid on a jaw, split at z = 0
JOINTS = (-17, -5, 6, 16, 23, 30)  # where the body's pieces begin
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(JOINTS))] + ["Tail", "Fluke"]
AMPLITUDES = [1.5, 2.5, 4, 5, 6, 7, 8, 14]

SPIRAL = (((0, 0), "star"), ((1, 0), "ice"), ((1, 1), "ice"), ((0, 2), "violet"), ((-1, 2), "violet"), ((-2, 1), "violet"),
          ((-1, 0), "ice"), ((-1, -1), "ice"), ((0, -2), "violet"), ((1, -2), "violet"), ((2, -1), "violet"))
SPIRAL_AT = (-8, -1)  # its middle, on the flank under the rider
BIG_SIDE = ((-27, -4, "ice"), (7, -2, "violet"), (20, 2, "ice"))  # the bigger stars on each flank: (x, z) of the middle, the arms' colour
BIG_TOP = ((1, 3, "ice"), (-32, -2, "violet"))  # and on the back: (x, column)
TINTS = ("star", "star", "ice", "ice", "violet")
SIDE_STARS, TOP_STARS = 28, 12  # how many single stars are scattered on each flank and on the back


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


def at(profile, x):
    """the value of a staircase at x"""
    return [v for x0, v in profile if x0 <= x][-1]


def steps(n):
    """the corners of a slice: a broad shoulder where the body is thick, less as it thins"""
    return [(3, 1), (1, 2)] if n >= 7 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def lid_steps(n):
    return [(2, 1), (1, 1)] if n >= 5 else [(1, 1)]


def rows(n):
    return sum(tall for _, tall in steps(n))


def lerp(a, b, f):
    return tuple(p + (q - p) * f for p, q in zip(a, b))


# ---- stars: cubes of the surface repainted, so they lie flush
def outer(p, x, z, side):
    """the outermost cube of the part at (x, z) on one side"""
    js = [c[1] for c in p.cells if c[0] == x and c[2] == z]
    return (max(js) if side > 0 else min(js)) if js else None


CROSS = ((1, 0), (-1, 0), (0, 1), (0, -1))  # a big star: a white cube with four coloured ones round it, like a twinkle


def side_star(p, x, z, colour, side, big=False):
    spots = [(x, z)] + ([(x + a, z + b) for a, b in CROSS] if big else [])
    js = [outer(p, a, b, side) for a, b in spots]
    if None in js or len(set(js)) > 1:  # a big star must lie on one flat face
        return False
    for k, ((a, b), j) in enumerate(zip(spots, js)):
        p.cells[(a, j, b)] = "star" if big and k == 0 else colour
    return True


def top_star(p, x, j, colour, big=False):
    spots = [(x, j)] + ([(x + a, j + b) for a, b in CROSS] if big else [])
    ks = [max([c[2] for c in p.cells if c[0] == a and c[1] == b], default=None) for a, b in spots]
    if None in ks or len(set(ks)) > 1:
        return False
    for i, ((a, b), k) in enumerate(zip(spots, ks)):
        p.cells[(a, b, k)] = "star" if big and i == 0 else colour
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
        # the head in front of the skull. The lower jaw: wide and deep, its chin rounded in steps. The upper jaw: a flat
        # lid lying on it, a cube narrower all round and a cube shorter in front, so the mouth is a ledge
        p.hull(x0, x1, n, bot, 0, "void", (), steps(n))
        if x0 >= LID_FROM:
            p.hull(x0, x1, n - 1, 0, at(TOP, x0), "void", lid_steps(n - 1), ())
    # a sleeve at each joint, into the piece in front: sized from the smaller of the two and clear of both pieces' steps
    for seg, x in zip(segs, JOINTS):
        n, fn = at(N, x), at(N, x - 1)
        clear = max(rows(n), rows(fn))
        seg.sym(x - 1, x, max(min(n, fn) - 2, 0), max(at(BOT, x), at(BOT, x - 1)) + clear, min(at(TOP, x), at(TOP, x - 1)) - clear, "void")
    # the line of light down the middle of the back, from behind the blowhole to the tail: one bar to every level stretch
    # of every piece. It stops a little short of a lower neighbour, so its end never lies in the plane of the step
    runs = sorted({x for x, _ in TOP if x > SKULL_FROM} | set(JOINTS) | {SKULL_FROM, END})
    for x0, x1 in zip(runs, runs[1:]):
        top = at(TOP, x0)
        before, behind = at(TOP, x0 - 1), (at(TOP, x1) if x1 < END else top - 1)
        ridge = (-0.5, 0.5, top - 0.3, top + 0.4)
        part_at(x0).block(x0 + (0.2 if before < top else 0.0), ridge, x1 - (0.2 if behind < top else 0.0), ridge, "ice")

    # the blowhole's guard: a low block on the lid that runs into the skull
    guard = (-1.5, 1.5, 4.6, 5.6)
    head.block(-25.6, guard, -21.5, guard, "void")
    # the eye: calm, a low wide block of white light at the corner of the mouth
    # and a thin rim of pale blue round it, which no star has
    halo = (8.3, 8.65, 0.1, 1.9)
    head.block(-21.9, halo, -18.9, halo, "ice", mirror=True)
    eye = (8.3, 8.85, 0.45, 1.55)
    head.block(-21.5, eye, -19.3, eye, "star", mirror=True)

    # the breath: star cubes that float above the blowhole
    spout = m.part("Spout", (-24, 0, 5), "Head")
    for (x, y, z), size, colour in (((-24.0, 0.0, 7.6), 0.9, "star"), ((-23.2, 0.9, 9.1), 0.7, "ice"), ((-24.5, -0.8, 10.3), 0.7, "violet"),
                                    ((-22.7, -0.4, 11.7), 0.6, "star"), ((-23.5, 1.1, 13.1), 0.5, "ice"),
                                    ((-21.8, 0.3, 14.3), 0.4, "violet")):
        h = size / 2
        spout.block(x - h, (y - h, y + h, z - h, z + h), x + h, (y - h, y + h, z - h, z + h), colour)

    # the small fin on its hump, two thirds of the way back: two boxes leaning back, the first buried deep
    segs[2].beam((14.4, 0, 5.4), (16.3, 0, 7.95), 2.8, 1.4, "void")
    segs[2].beam((15.6, 0, 7.4), (17.6, 0, 8.9), 1.6, 0.6, "void")

    # the flippers, each on its own joint: a humpback's, a third of its length. An arm that goes out and down from the
    # shoulder, a long paddle that sweeps back from it, a thin tip
    a, b, c, d = (-14.5, 5.0, -6.0), (-11.5, 11.5, -7.5), (-3.5, 15.5, -9.3), (2.0, 17.8, -10.4)
    b2 = lerp(a, b, 0.72)
    b3 = lerp(b2, c, 0.8)
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (-14.5, 7.5 * side, -6.0), "S1")
        for p0, p1, wide, thick in ((a, b, 5.0, 1.5), (b2, c, 4.4, 1.1), (b3, d, 3.0, 0.7)):
            part.beam((p0[0], p0[1] * side, p0[2]), (p1[0], p1[1] * side, p1[2]), wide, thick, "void", flat="z")

    # the tail: a stock taller than it is wide, then the fluke on a joint of its own: a hub and two lobes swept back, each
    # ending in a thinner tip. The line of light runs on along the stock and round the trailing edge
    end, mid = END, 1.5
    tail = m.part("Tail", (end, 0, mid), f"S{len(JOINTS)}")
    tail.beam((end - 0.5, 0, mid), (end + 3, 0, mid), 2.6, 4.0, "void", flat="z")
    ridge = (-0.5, 0.5, mid + 1.7, mid + 2.4)
    tail.block(end, ridge, end + 2.8, ridge, "ice")
    fluke = m.part("Fluke", (end + 2, 0, mid), "Tail")
    fluke.beam((end + 1.5, 0, mid), (end + 5.5, 0, mid), 9.0, 2.2, "void", flat="z")
    notch = (-1.9, 1.9, mid - 0.5, mid + 0.5)  # across the notch between the lobes, inside the hub's thickness
    fluke.block(end + 5.0, notch, end + 5.8, notch, "ice")
    for p0, p1, wide, thick, rim in (((end + 3.0, 2.5), (end + 8.0, 9.5), 5.6, 1.4, 1.8), ((end + 6.8, 8.0), (end + 9.5, 12.5), 3.6, 0.8, 1.1)):
        fluke.beam((p0[0], p0[1], mid), (p1[0], p1[1], mid), wide, thick, "void", flat="z", mirror=True)
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        length = math.hypot(dx, dy)
        ax, ay = dx / length, dy / length
        ox, oy = ay * (wide / 2 - 0.1), -ax * (wide / 2 - 0.1)  # to the trailing edge
        fluke.beam((p0[0] + ox, p0[1] + oy, mid), (p1[0] + ox + ax * 0.25, p1[1] + oy + ay * 0.25, mid), 0.6, rim, "ice", flat="z",
                   mirror=True)

    # ---- the stars
    sx, sz = SPIRAL_AT
    for side in (1, -1):
        taken = [(sx, sz, 5), (-20, 1, 4)]  # the spiral and the eye keep a clear space round them
        for (dx, dz), colour in SPIRAL:
            side_star(part_at(sx + dx * side), sx + dx * side, sz + dz, colour, side)
        for x, z, colour in BIG_SIDE:
            if side_star(part_at(x), x, z, colour, side, big=True):
                taken.append((x, z, 5))
        rng = random.Random(7 if side > 0 else 19)
        count = 0
        for _ in range(900):
            if count >= SIDE_STARS:
                break
            x, z = rng.randint(-38, 37), rng.randint(-7, 6)
            if any(max(abs(x - a), abs(z - b)) < r for a, b, r in taken):
                continue
            if side_star(part_at(x), x, z, rng.choice(TINTS), side):
                taken.append((x, z, 3))
                count += 1
    taken = [(15, 0, 4), (-23, 0, 4)]  # the hump and the blowhole
    for x, j, colour in BIG_TOP:
        if top_star(part_at(x), x, j, colour, big=True):
            taken.append((x, j, 5))
    rng = random.Random(3)
    count = 0
    for _ in range(600):
        if count >= TOP_STARS:
            break
        x, j = rng.randint(-36, 35), rng.randint(-5, 5)
        if j == 0 or any(max(abs(x - a), abs(j - b)) < r for a, b, r in taken):
            continue
        p = part_at(x)
        if (x, j, at(TOP, x) - 1) not in p.cells:  # only on the flat of the back
            continue
        if top_star(p, x, j, rng.choice(TINTS)):
            taken.append((x, j, 3))
            count += 1
