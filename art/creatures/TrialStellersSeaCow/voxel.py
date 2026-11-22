"""Steller's Sea Cow, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the
game's Steller's Sea Cow (art/creatures/StellersSeaCow) and replaces nothing. Designed from the real animal.
Its idea: the barrel. A huge round body with a comically small head, stub arms and a whale's fluke.
- The body in numbers: 64 cubes long (29 studs); the body alone is 22 deep (0.34 of the length) and 25 wide (0.39),
  biggest at the middle, with three-step corners. Its outline is drawn by a rounded profile (PROFILE), so it swells
  fast behind the neck, stays full through the middle and narrows quickly behind to a thick stalk.
- The head is a tenth of the length and half the body's depth, on a short thick neck a step under the barrel.
- The face: a broad square pale muzzle pad turned down at the front with rows of bristle dots, a dark mouth line under
  it, tiny eyes (a dark block in a pale ring) far apart on the sides of the head. Gentle: no brow.
- Dusty teal over pale; the line between them low on the flank in three long waves.
- The marks (an Epic's two): a bright kelp frond trailing from the right of the mouth on its own joint, and three small
  clusters of cream barnacles on the back and the shoulder, clear of the seat.
It swims slowly by bending up and down. The rider sits on the top of the barrel."""
import math

NAME, ZONE, RARITY = "Steller's Sea Cow (trial)", "ZONE 3 / KELP FOREST", "EPIC"
U = 0.45
PALETTE = {"teal": "#5E9396", "pale": "#DCE6D2", "black": "#161A1F", "mouth": "#3E3442", "bristle": "#4E6B6D",
           "kelp": "#4FC244", "barnacle": "#F2ECD2"}
SHADE = 0.9
SEAT = (-4, 11, 6.5)
FRAME, ORTHO = 2.6, 36.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["teal"]}]

PEAK, FRONT, REAR = -4, 18, 15  # the barrel's biggest slice and how far it runs in front of and behind it
BARREL = (-22, 11)  # the barrel's slices, x from and to
NECK = ((-25, -22, 6, -7, 7),)
STALK = ((11, 14, 4, -4, 5), (14, 18, 3, -3, 4))
HEAD = (-29, -25, 4, -6, 5)
SEGMENTS = (("S1", -25), ("S2", -13), ("S3", 1), ("S4", 11))  # each body joint and where it starts
CHAIN = ["Head", "S1", "S2", "S3", "S4", "Fluke"]
AMPLITUDES = [1.0, 1.5, 2.5, 5.0, 9.0, 14.0]


def round_(t, p):
    """a superellipse: 1 at the middle, falling slowly, then fast at the ends (a barrel, not a cone)"""
    return max(0.0, 1 - abs(t) ** p) ** (1 / p)


def profile():
    """the body's slices (x from, x to, cubes out, bottom, top), each 1 cube long through the barrel, merged where
    nothing changes. In front of the middle a number changes by at most one cube from slice to slice; behind it by
    at most two, so it narrows quickly to the stalk"""
    raw = {}
    for x in range(*BARREL):
        t = (x + 0.5 - PEAK) / (FRONT if x + 0.5 < PEAK else REAR)
        raw[x] = [round(12 * round_(t, 2.6)), round(11 * round_(t, 2.4)), round(11 * round_(t, 2.0))]
    for x in range(PEAK - 1, BARREL[0] - 1, -1):
        raw[x] = [max(v, w - 1) for v, w in zip(raw[x], raw[x + 1])]
    for x in range(PEAK + 1, BARREL[1]):
        raw[x] = [max(v, w - 2) for v, w in zip(raw[x], raw[x - 1])]
    out = list(NECK)
    for x in range(*BARREL):
        low = (6, 7, 7) if x < PEAK else (5, 5, 6)
        n, bot, top = max(raw[x][0], low[0]), -max(raw[x][1], low[1]), max(raw[x][2], low[2])
        if out[-1][2:] == (n, bot, top):
            out[-1] = (out[-1][0], x + 1, n, bot, top)
        else:
            out.append((x, x + 1, n, bot, top))
    return out + list(STALK)


SLICES = profile()


def steps(n):
    """the corners: three steps where the body is big, fewer as it thins"""
    if n >= 11:
        return [(6, 2), (3, 2), (1, 2)]
    if n >= 9:
        return [(4, 2), (2, 2), (1, 1)]
    if n >= 7:
        return [(3, 1), (2, 1), (1, 1)]
    return [(2, 1), (1, 1)] if n >= 5 else [(1, 1)]


def clear(n):
    return sum(tall for _, tall in steps(n))


def line(x, bot, top):
    """the colour line: pale below this height. Low on the flank in three long waves from the head to the stalk"""
    wave = -3.6 + 1.7 * math.sin(2 * math.pi * (x + 29) / 16.5)
    return int(min(max(math.floor(wave + 0.5), bot + 1), bot + (top - bot) * 0.45))


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, teal with a lighter top row, pale below the wavy line"""
    p.hull(x0, x1, n, bot, top, "teal", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "teal+")
    for x in range(x0, x1):
        z = line(x, bot, top)
        p.paint_sym(x, x + 1, n, bot, z, "pale")
        if z - bot >= 3:
            p.paint_sym(x, x + 1, n, bot, bot + 1, "pale-")


def surface(x, y):
    """the height of the body's top at (x, y): the top of the highest cube in that column"""
    for x0, x1, n, bot, top in SLICES:
        if x0 <= x < x1:
            z = top
            for inset, tall in steps(n):
                if abs(y) <= n - inset + 0.5:
                    return z
                z -= tall
            return z
    raise ValueError(x)


def barnacles(part, sizes):
    """a cluster of cream barnacles: each a low base and a smaller cap on it, set into the body's top"""
    for bx, by, size, tall in sizes:
        z = surface(bx, by)
        h, c = size / 2, size * 0.28
        part.block(bx - h, (by - h, by + h, z - 0.4, z + tall), bx + h, (by - h, by + h, z - 0.4, z + tall), "barnacle")
        part.block(bx - c, (by - c, by + c, z + 0.1, z + tall + 0.35), bx + c, (by - c, by + c, z + 0.1, z + tall + 0.35),
                   "barnacle-")


def pose(parts, phase):
    """a slow whale's swim: a wave runs down the body up and down and grows to the fluke; the arms row; the kelp trails"""
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.6 * k)
    for name, side in (("ArmR", 1), ("ArmL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.y = math.radians(12) * math.sin(phase - 1.6)
    parts["Kelp"].rotation_euler.z = math.radians(10) * math.sin(phase - 1.2)
    parts["Kelp"].rotation_euler.x = math.radians(6) * math.sin(phase - 2.0)


def build(m):
    head = m.part("Head", (HEAD[1], 0, 0))
    slab(head, *HEAD)
    # the muzzle: a teal block turned nose-down, then the broad square pale pad on its end, a little bigger, facing
    # forward and down
    head.beam((-27.0, 0, -0.6), (-30.4, 0, -2.6), 8.0, 6.4, "teal", flat="z")
    d = (-1.0 / math.hypot(1.0, 1.0), -1.0 / math.hypot(1.0, 1.0))  # the pad's facing in the side view
    end = (-31.4, -3.4)
    start = (end[0] - d[0] * 1.8, end[1] - d[1] * 1.8)
    head.beam((start[0], 0, start[1]), (end[0], 0, end[1]), 9.7, 6.0, "pale", flat="z")
    # the bristle dots: three rows of small dark blocks standing out of the pad's face, staggered
    across = (-d[1], d[0]) if -d[1] < 0 else (d[1], -d[0])  # up the face, toward the top of the head
    for v, ys in ((1.7, (-3.0, -1.0, 1.0, 3.0)), (0.0, (-3.6, -2.0, 0.0, 2.0, 3.6)), (-1.7, (-3.0, -1.0, 1.0, 3.0))):
        for y in ys:
            cx, cz = end[0] + across[0] * v, end[1] + across[1] * v
            head.beam((cx - d[0] * 0.3, y, cz - d[1] * 0.3), (cx + d[0] * 0.35, y, cz + d[1] * 0.35), 0.75, 0.75, "bristle",
                      flat="z")
    # the chin: a pale block under the skull that the pad overhangs, and the dark mouth line between them
    head.beam((-24.6, 0, -5.6), (-29.6, 0, -6.6), 6.4, 2.2, "pale", flat="z")
    head.beam((-26.4, 0, -5.55), (-30.0, 0, -5.9), 6.0, 0.6, "mouth", flat="z")
    # the eyes: tiny, far apart on the sides of the head, a dark block in a pale ring; no brow
    ring = (4.3, 4.8, 0.0, 2.2)
    head.block(-28.4, ring, -26.2, ring, "pale+", mirror=True)
    pupil = (4.4, 5.1, 0.5, 1.7)
    head.block(-27.9, pupil, -26.7, pupil, "black", mirror=True)

    # the body: slices on four joints, each with a sleeve into the piece in front so a bend shows body
    segs, before = {}, HEAD
    for i, (name, x0) in enumerate(SEGMENTS):
        x1 = SEGMENTS[i + 1][1] if i + 1 < len(SEGMENTS) else STALK[-1][1]
        seg = segs[name] = m.part(name, (x0, 0, 0), "Head" if i == 0 else SEGMENTS[i - 1][0])
        mine = [s for s in SLICES if x0 <= s[0] < x1]
        for s in mine:
            slab(seg, *s)
        _, _, n, bot, top = mine[0]
        _, _, fn, fbot, ftop = before
        gap = max(clear(n), clear(fn))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + gap, min(top, ftop) - gap, "teal-")
        before = mine[-1]
    s1, s2, s3, s4 = (segs[name] for name, _ in SEGMENTS)

    # the stub arms, each on its own joint: a short thick arm forward and down from low on the shoulder, and a blunt
    # paddle turned further down
    for name, side in (("ArmR", 1), ("ArmL", -1)):
        arm = m.part(name, (-17.0, 7.5 * side, -6.5), "S1")
        arm.beam((-16.6, 7.0 * side, -6.0), (-20.0, 10.4 * side, -10.2), 3.8, 2.8, "teal", flat="z")
        arm.beam((-18.4, 8.8 * side, -8.2), (-22.6, 11.0 * side, -12.6), 3.0, 1.3, "teal", flat="z")

    # THE MARKS. The kelp frond, on its own joint at the right corner of the mouth: three bright blades trailing back
    # and down, each smaller than the last and starting inside it
    kelp = m.part("Kelp", (-28.0, 3.4, -5.8), "Head")
    kelp.beam((-28.2, 1.6, -4.2), (-27.8, 6.2, -7.2), 2.6, 0.75, "kelp", flat="y")
    kelp.beam((-28.0, 5.6, -6.6), (-26.4, 7.4, -10.2), 2.2, 0.5, "kelp", flat="y")
    kelp.beam((-26.7, 7.2, -9.6), (-25.2, 7.8, -13.2), 1.8, 0.25, "kelp+", flat="y")
    # three clusters of barnacles: on the right shoulder, on the back behind the seat (left), and high on the right
    # flank behind it
    barnacles(s1, ((-16.0, 3.0, 1.6, 0.6), (-16.2, 4.9, 1.0, 0.4), (-15.6, 4.3, 0.8, 0.2)))
    barnacles(s2, ((-10.0, -4.0, 1.6, 0.55), (-10.3, -5.5, 1.0, 0.35), (-9.7, -2.6, 0.8, 0.2)))
    barnacles(s3, ((3.0, 3.0, 1.6, 0.6), (2.6, 4.6, 1.0, 0.4), (3.4, 1.5, 0.8, 0.2)))

    # the fluke on its own joint: a hub off the stalk's end and two broad lobes swept back, as wide as the body, their
    # tips lifted a little
    fluke = m.part("Fluke", (17.5, 0, 0.5), "S4")
    fluke.beam((17.0, 0, 0.5), (22.4, 0, 0.5), 6.0, 2.8, "teal", flat="z")
    fluke.beam((20.4, 1.4, 0.5), (26.6, 9.6, 1.3), 5.4, 2.0, "teal", flat="z", mirror=True)
    fluke.beam((25.4, 8.4, 1.15), (29.4, 12.4, 1.6), 3.8, 1.2, "teal", flat="z", mirror=True)
