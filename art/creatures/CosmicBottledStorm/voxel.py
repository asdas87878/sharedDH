"""Bottled Storm, a COSMIC (docs/design/cosmic.md, concept 10: a jellyfish whose bell is a glass bottle with a
thundercloud in it, its arms lightning) for tools/blender/voxel_kit.py. A new model, self-contained; its round stepped
bell and hanging arms start from the Aurora Jelly's (art/creatures/AuroraJelly), which is not changed. The Aurora Jelly is
soft light under a dark bell; this one is a made thing: glass, brass, a cork, and weather shut inside.
- The bell is a stoppered bottle: a brass base ring, a round body that swells at the middle, a brass hoop at its rim,
  two stepped shoulders, a long glass neck, a brass lip and a cork with a brass cap and a ring. Eight brass ribs run up it
  from the base to the neck, so it reads as glass held in a cage.
- The body's glass shows the storm through it: grey-violet billows tinted cyan, rising to a wavy line, clear pale glass
  above with white glints, and faint bolts behind every other pane. A bright bolt runs up each face of the neck.
- The shoulders have open skylights between the ribs: in them the real cloud, one to three cubes down, lumpy, with a
  jagged bolt across each. The rider sits on a brass saddle on the back shoulder and looks over the skylights at the
  neck and the cork.
- The storm leaks out of the open base as a lumpy cloud (its own joint: it churns, one turn a swim), and the arms are
  lightning: six jagged bolts, three joints each, hanging from it and swaying; some fork in violet.
- The cork rattles on its own joint, as if the storm were pushing at it.
No eyes, no mouth."""
import math

NAME, ZONE, RARITY = "Bottled Storm", "UNPLACED", "COSMIC"
U = 0.5
PALETTE = {
    "glass": "#A6E6EE",  # clear glass, above the storm: pale cyan
    "fog": "#56618E",  # the storm seen through glass: grey-violet, tinted cyan
    "mist": "#8F9CC6",  # the light tops of the billows seen through glass
    "glint": "#F4FFFF",
    "brass": "#C8913A",
    "cloud": "#3A3456",  # the storm itself
    "billow": "#9086C4",  # its lit tops
    "cork": "#9A6A40",
    "bolt": "#FFF09A",  # lightning: warm white, against the cool glass
    "arc": "#B49CFF",  # forks: violet
    "dim": "#F4F0C8",  # lightning seen through glass
}
Z = 1  # the height of the bell's base: the model's middle is near 0, so the views frame all of it
SEAT = (15.5, Z + 18, 2.5)
GLOW = {"bolt": 1.0, "arc": 1.0, "dim": 0.7}
KEEP = ["bolt", "arc", "dim"]
LIGHTS = [("Storm", (0.5, 0, Z - 8.0), "#CFE8FF", 160, 1.0)]  # cold white-blue, at the bottom of the cloud that leaks out
FRAME, ORTHO, ORTHO_SWIM = 3.8, 62.0, 62.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["brass"]}]

CX = 0.5
# the bell, bottom up: (cubes out, from, to), z from the base
BASE = (20, 0, 2)  # the brass base ring, open in the middle
OPEN = 12  # the base's opening: the storm comes out of it
BODY = ((19, 2, 4), (21, 4, 11), (20, 11, 13))  # the round body: it swells in the middle
RIM = (20, 13, 14)  # a brass hoop round the rim of the shoulder
SHOULDERS = ((18, 14, 17),)
NECK = (5, 17, 25)
LIP = (7, 25, 26)
CORK = (4, 26, 30)
CAP = (5, 30, 31)
GLASS = (*BODY, *SHOULDERS, NECK)
RIBS = 8  # brass ribs up the bottle, at 0, 45, 90... degrees (0 = the rider's side, the back)
# the arms: six bolts round the cloud, each three joints; a joint is two jagged strokes
ARMS = 6
ARM_ANGLES = [math.radians(30 + 60 * k) for k in range(ARMS)]
ARM_LENGTHS = (13.0, 12.0, 10.0)  # each joint's length, root to tip
ARM_WIDTHS = (2.0, 1.6, 1.15)
ARM_JOG = (2.8, 2.4, 1.9)  # how far each stroke jags sideways
ARM_SCALE = (1.0, 0.82, 0.93, 0.78, 1.0, 0.88)  # no two alike
ARM_SWING = ((6, 0.5), (9, 1.2), (12, 1.9))


def disc(n):
    """a circle in cubes, n out from the middle, cut in broad steps (as the Aurora Jelly's bell): the set of its columns"""
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


def fill(p, cols, z0, z1, colour):
    for i, j in cols:
        for k in range(z0, z1):
            p.cells[(i, j, k)] = colour


def angle_of(i, j):
    return math.atan2(j, i) % (2 * math.pi)


def rib_gap(i, j):
    """how far a column is from the nearest rib, in cubes along the circle"""
    a = angle_of(i, j)
    step = 2 * math.pi / RIBS
    off = abs(a - step * round(a / step))
    return off * max(math.hypot(i, j), 1.0)


def sector(i, j):
    """which pane a column is in: 0 is the back (+x, behind the rider's saddle), counting round"""
    return int(angle_of(i, j) // (2 * math.pi / RIBS))


def wave(a, seed):
    return math.sin(3 * a + seed) + 0.6 * math.sin(7 * a + 2.1 * seed) + 0.35 * math.sin(13 * a + 0.7 * seed)


def unit(v):
    n = math.sqrt(sum(a * a for a in v))
    return tuple(a / n for a in v)


def beat(phase):
    return math.sin(phase) + 0.3 * math.sin(2 * phase)


def arm_frame(k):
    """an arm's directions: out from the middle, and across it (the way its strokes jag)"""
    a = ARM_ANGLES[k]
    return (math.cos(a), math.sin(a), 0.0), (-math.sin(a), math.cos(a), 0.0)


def pose(parts, phase):
    """the storm churns (one turn a swim) and the bell pulses: the bolts swing out and back, each joint a little later,
    each arm a little out of step; the cork rattles three times a swim"""
    parts["Storm"].rotation_euler.z = phase
    parts["Cork"].rotation_euler.x = math.radians(4) * math.sin(3 * phase)
    parts["Cork"].rotation_euler.y = math.radians(3) * math.sin(3 * phase + 1.3)
    for k in range(ARMS):
        _, across = arm_frame(k)
        for j, (deg, late) in enumerate(ARM_SWING):
            ob = parts[f"A{k + 1}{'abc'[j]}"]
            ob.rotation_mode = "AXIS_ANGLE"
            ob.rotation_axis_angle = (math.radians(deg) * beat(phase - late - 0.6 * k), *across)


def bottle(bell):
    """the solid bottle, glass and brass; everything inside its skin is the cloud. Returns the skin"""
    n, z0, z1 = BASE
    fill(bell, disc(n) - disc(OPEN), Z + z0, Z + z1, "brass")
    fill(bell, disc(OPEN), Z + z0, Z + z1, "cloud")
    for n, z0, z1 in GLASS:
        fill(bell, disc(n), Z + z0, Z + z1, "glass")
    fill(bell, disc(RIM[0]), Z + RIM[1], Z + RIM[2], "brass")
    fill(bell, disc(LIP[0]), Z + LIP[1], Z + LIP[2], "brass")
    cells = bell.cells
    near = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    skin = {c for c in cells if any((c[0] + a, c[1] + b, c[2] + d) not in cells for a, b, d in near)}
    for c in cells:
        if c not in skin:
            cells[c] = "cloud"
    return skin


def paint_glass(cells, skin):
    """the ribs; the storm seen through the body's glass up to a wavy line, clear above; the neck's foot cloudy"""
    for c in skin:
        i, j, k = c
        z = k - Z
        if cells[c] != "glass":
            continue
        a = angle_of(i, j)
        top = (i, j, k + 1) not in cells  # a face that looks up
        if rib_gap(i, j) < 0.75 and z < NECK[1]:
            cells[c] = "brass"
        elif z >= NECK[1]:
            cells[c] = "fog" if z < NECK[1] + 2 else "glass"
        elif top or z >= SHOULDERS[0][1]:
            cells[c] = "glass"
        else:
            level = 7.5 + 2.0 * wave(a, 0.4)
            if z > level + 0.8:
                cells[c] = "glass"
            elif z > level - 0.5:
                cells[c] = "mist"
            elif z == BODY[0][1]:
                cells[c] = "fog-"
            else:
                cells[c] = "mist" if wave(a * 2.3, 1.7 + 0.5 * z) > 1.3 else "fog"
    for c in skin:  # glints on the clear glass, bolts in the storm behind it, and a bolt up each face of the neck
        i, j, k = c
        z = k - Z
        if cells[c] not in ("fog", "mist", "glass"):
            continue
        a, r = angle_of(i, j), math.hypot(i, j)
        side = (i, j, k + 1) in cells
        if not side:
            continue
        s = (a % (2 * math.pi / RIBS)) * r  # cubes along the pane from its rib
        if z < NECK[1] and cells[c] == "glass" and 2.4 <= s - 0.6 * (z - BODY[0][1]) < 3.4:
            cells[c] = "glint"
        if z < SHOULDERS[0][1] and cells[c] in ("fog", "mist") and sector(i, j) % 2 == 1 and z >= BODY[0][1] + 1:
            jag = (sector(i, j) + 0.55) * 2 * math.pi / RIBS + 0.07 * (1 if (z // 2) % 2 else -1)
            if abs(a - jag) * r < 0.75:
                cells[c] = "dim"
        if z >= NECK[1] and r > 3:
            for q in range(4):
                jag = q * math.pi / 2 + (0.17 if (z // 2) % 2 else -0.17)
                if abs((a - jag + math.pi) % (2 * math.pi) - math.pi) * r < 0.8:
                    cells[c] = "bolt"


def skylights(cells):
    """the shoulder's top opens between the ribs in eight big wedges round the neck: in each the cloud lies two to four
    cubes down, its billows rising nearer, and one jagged bolt runs out across it at a single depth"""
    n, z0, z1 = SHOULDERS[0]
    inner = NECK[0]
    top = Z + z1 - 1
    opened = set()
    for i, j in disc(n):
        r = math.hypot(i, j)
        if r <= inner + 0.8 or r >= n - 0.8 or rib_gap(i, j) < 1.3:
            continue
        if (i, j, top) not in cells or (i, j, top + 1) in cells:
            continue
        if i >= 12 and abs(j) <= 3:  # the saddle's footing
            continue
        a = angle_of(i, j)
        lump = wave(a * 1.3, 0.35 * r)  # billows: the high ones push up out of the open panes
        if lump > 0.75:
            rise = 2 if lump > 1.25 else 1
            for k in range(top - 1, top + rise + 1):
                cells[(i, j, k)] = "billow"
            cells[(i, j, top + rise)] = "billow+"
            continue
        depth = 3 if lump < -0.5 else (2 if lump < 0.25 else 1)
        for k in range(top - depth + 1, top + 1):
            cells.pop((i, j, k), None)
        cells[(i, j, top - depth)] = ("billow", "cloud+", "cloud")[depth - 1]
        opened.add((i, j))
    for sec in range(RIBS):  # one bolt per wedge, all at one depth so it reads as a line, through the low cloud only
        mid = (sec + 0.5) * 2 * math.pi / RIBS
        for step in range(80):
            r = inner + 1.0 + step * 0.15
            if r >= n - 1.0:
                break
            a = mid + (0.2 if (step // 10) % 2 else -0.2) * (inner + 4) / r
            x, y = r * math.cos(a), r * math.sin(a)
            for i, j in {(round(x), round(y))}:
                if (i, j) in opened:
                    for k in range(top - 1, top + 1):
                        cells.pop((i, j, k), None)
                    cells[(i, j, top - 2)] = "bolt"
                    cells.setdefault((i, j, top - 3), "cloud")


def build(m):
    bell = m.part("Bell", (CX, 0, Z))
    skin = bottle(bell)
    paint_glass(bell.cells, skin)
    skylights(bell.cells)
    # sparks: from the highest billow in some wedges, a bolt leaps up and over onto the nearest brass rib
    top = Z + SHOULDERS[0][2] - 1
    for sec in (1, 2, 5, 6):
        heads = [c for c, colour in bell.cells.items() if colour == "billow+" and sector(c[0], c[1]) == sec]
        if not heads:
            continue
        i, j, k = max(heads, key=lambda c: (c[2], -abs(angle_of(c[0], c[1]) - (sec + 0.5) * math.pi / 4)))
        r = math.hypot(i, j)
        rib = (sec + (1 if angle_of(i, j) > (sec + 0.5) * math.pi / 4 else 0)) * math.pi / 4
        p0 = (i + 0.5, j, k + 0.4)
        p1 = ((i + 0.5 + r * math.cos(rib)) / 2 + 0.6, (j + r * math.sin(rib)) / 2 - 0.4, k + 2.6)
        p2 = (r * math.cos(rib) + 0.5, r * math.sin(rib), top + 0.6)
        d0 = unit(tuple(b - a for a, b in zip(p0, p1)))
        bell.beam(p0, tuple(a + b * 0.35 for a, b in zip(p1, d0)), 0.6, 0.6, "bolt")
        bell.beam(p1, p2, 0.5, 0.5, "bolt")
    # the rider's saddle: brass, on the back shoulder, with a raised back edge
    zs = Z + SHOULDERS[0][2]
    bell.box(13, 18, -2, 3, zs, zs + 1, "brass")
    bell.box(17, 18, -2, 3, zs + 1, zs + 2, "brass")

    # ---- the cork, on its own joint: cork with a dark band, a brass cap and a ring to pull it by
    cork = m.part("Cork", (CX, 0, Z + CORK[1]), "Bell")
    fill(cork, disc(CORK[0]), Z + CORK[1], Z + CORK[2], "cork")
    fill(cork, disc(CORK[0]), Z + CORK[1] + 1, Z + CORK[1] + 2, "cork-")
    fill(cork, disc(CAP[0]), Z + CAP[1], Z + CAP[2], "brass")
    top = Z + CAP[2]
    for i, k in ((-2, 0), (-2, 1), (-2, 2), (-1, 3), (0, 3), (1, 3), (2, 3), (3, 2), (3, 1), (3, 0)):
        cork.cells[(i, 0, top + k)] = "brass"

    # ---- the storm leaking out of the base: lumpy cloud on its own joint, the arms hang from it
    storm = m.part("Storm", (CX, 0, Z), "Bell")
    for n, z0, z1 in ((13, -3, 0), (10, -5, -3), (6, -6, -5)):
        fill(storm, disc(n), Z + z0, Z + z1, "cloud")
    for i, j in disc(15) - disc(12):  # lumps round its edge
        a = angle_of(i, j)
        if wave(a, 2.2) > 0.5:
            fill(storm, [(i, j)], Z - 3 + (1 if wave(a, 0.9) > 0.8 else 0), Z, "cloud")
    for i, j in disc(12) - disc(9):
        if wave(angle_of(i, j), 3.1) > 0.9:
            fill(storm, [(i, j)], Z - 5, Z - 3, "cloud")
    for c in list(storm.cells):  # the cloud's undersides darker
        if (c[0], c[1], c[2] - 1) not in storm.cells:
            storm.cells[c] = "cloud-"
    for step in range(12):  # a bolt wound round the underside
        a = step * 0.5
        r = 4 + step * 0.75
        i, j = round(r * math.cos(a)), round(r * math.sin(a))
        col = [c for c in storm.cells if c[0] == i and c[1] == j]
        if col:
            storm.cells[min(col, key=lambda c: c[2])] = "arc"

    # ---- the arms: lightning. Each joint is two strokes, the second jagging back across the first
    for k in range(ARMS):
        out, across = arm_frame(k)
        side = 1 if k % 2 else -1
        start = (CX + 6.0 * out[0], 6.0 * out[1], Z - 3.5)
        parent = "Storm"
        for j, (length, width, jog) in enumerate(zip(ARM_LENGTHS, ARM_WIDTHS, ARM_JOG)):
            length *= ARM_SCALE[k]
            part = m.part(f"A{k + 1}{'abc'[j]}", start, parent)
            colour = "bolt" if j < 2 else "arc"
            lean = 0.18 + 0.06 * j  # out from the middle as it hangs
            p0 = start
            for stroke in range(2):
                side = -side
                drop = length / 2
                p1 = (p0[0] + out[0] * lean * drop + across[0] * side * jog,
                      p0[1] + out[1] * lean * drop + across[1] * side * jog,
                      p0[2] - drop)
                d = unit(tuple(b - a for a, b in zip(p0, p1)))
                # the first stroke starts deep in the cloud; each later one starts at the corner, inside the end of
                # the last, which runs on past the corner (a jag doubles back, so backing up would leave it)
                back = 0.9 if (j == 0 and stroke == 0) else 0.0
                a0 = tuple(a - b * back for a, b in zip(p0, d))
                a1 = tuple(a + b * 0.6 * width for a, b in zip(p1, d))
                w = width * (1 - 0.15 * stroke)
                part.beam(a0, a1, w, w, colour)
                if stroke == 0 and j < 2 and (k + j) % 2 == 0:  # a fork off the corner, in violet
                    f1 = (p1[0] - across[0] * side * jog * 1.1 + out[0] * 1.2,
                          p1[1] - across[1] * side * jog * 1.1 + out[1] * 1.2,
                          p1[2] - drop * 0.55)
                    fd = unit(tuple(b - a for a, b in zip(p1, f1)))
                    f0 = tuple(a - b * 0.4 for a, b in zip(p1, fd))
                    part.beam(f0, f1, width * 0.5, width * 0.5, "arc")
                p0 = p1
            start, parent = p0, part.name
