"""Anomalocaris (zone 8's Legendary: the alien-looking hunter of the first seas) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. The first crawler-kind body, and
designed from the animal itself, not from any other creature here.
Its idea: a thing from before fish. A broad flat raft of a body that rows itself on a wave of flaps, two heavy hooked arms
curling under its head, and big eyes on stalks that watch.
- The body is low and wide, an oval seen from above, with a slight hump where the rider sits. It narrows one step at a time
  to the tail. No legs, no fins on the back.
- Thirteen flaps down each side, one to a slice of body: plain thin plates swept back and tipped like louvres, so each
  one's back edge lies over the next one's front edge. They are grouped six to a side on joints, and row in a wave from
  front to back. They leave the body on the line where the dark back meets the pale belly.
- Two grabbing arms from under the front of the head: four thick boxes each, every one on its own joint, curling down and
  back like a hook, with pale spines on the inside of the curl. They are the focal point.
- Big eyes on short stalks: a dark pupil on the front outer corner of each, so it looks forward and sideways, with a thin
  halo of cold light (its only glow, and its signature colour).
- A smooth dark shield on the head. A round mouth of plates on the underside. A fan of three blades each side at the tail:
  the echo of the flaps.
- The back is plain.
The rider sits on the hump, legs in a shallow slot either side, above the flaps."""
import math

NAME, ZONE, RARITY = "Anomalocaris", "ZONE 8 / VENTS", "LEGENDARY"
U = 0.5
PALETTE = {"shell": "#3B3F86", "belly": "#DCD6CC", "fin": "#8A8EE0", "arm": "#22244F", "bone": "#F0E4C8", "black": "#17161C",
           "mouth": "#3A1428", "soft": "#5FE0C8"}
SEAT = (-2, 4, 7.5)
GLOW = {"soft": 0.45}  # the halo of the eyes: nothing else on it glows
FRAME, ORTHO = 2.6, 40.0

HEAD = (-21, -14, 5, -2, 3)  # the widest piece of the head, as a slice
# the body's slices, three cubes each: (from, to, cubes out, bottom, top). One step at a time, in width or in height
SLICES = tuple((-14 + 3 * i, -11 + 3 * i, n, bot, top) for i, (n, bot, top) in enumerate(
    ((6, -2, 3), (6, -3, 3), (7, -3, 3), (7, -3, 4), (7, -3, 4), (7, -3, 3), (6, -3, 3), (6, -2, 3), (5, -2, 3), (5, -2, 2), (4, -2, 2),
     (3, -2, 2), (2, -2, 2))))
BODY = (("B1", -14, 1), ("B2", 1, 13), ("B3", 13, 25))  # the three pieces of the body: (name, from, to)
EDGE = -1.0  # the height of the line between back and belly: the flaps leave the body on it
DROOP = 0.28  # how far a flap hangs for each cube it reaches out
# the flaps, one to a slice: (middle, how far out its tip is, how far back its tip is swept)
FLAPS = [(-12.5 + 3 * i, tip, sweep) for i, (tip, sweep) in enumerate(
    ((9.6, 1.0), (10.9, 1.3), (12.0, 1.6), (12.9, 1.9), (13.4, 2.1), (13.4, 2.3), (13.0, 2.4), (12.1, 2.5), (11.1, 2.5), (10.0, 2.4),
     (8.7, 2.3), (7.2, 2.1), (5.6, 1.9)))]
FLAPS[-1] = (23.3,) + FLAPS[-1][1:]
GROUPS = ((0, 1), (2, 3), (4, 5), (6, 7), (8, 9), (10, 11, 12))  # which flaps move together, front to back
# an arm: (from, to) in the side view, width, thickness, where its spines are along it, a spine's length
ARM = (((-22.0, -0.4), (-27.5, -2.4), 2.8, 2.2, (0.45, 0.75), 1.8), ((-26.8, -2.15), (-30.2, -5.2), 2.4, 1.9, (0.4, 0.72), 1.7),
       ((-29.8, -4.8), (-30.6, -8.6), 2.0, 1.6, (0.4, 0.72), 1.5), ((-30.5, -8.1), (-28.9, -10.9), 1.5, 1.2, (0.45,), 1.1))


def pose(parts, phase):
    """the body is almost still; the flaps row in a wave from front to back and the tail fan takes it up; the arms curl
    and reach, out of step with each other"""
    parts["B2"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 2.0)
    parts["B3"].rotation_euler.y = math.radians(3) * math.sin(phase - 3.5)
    parts["Tail"].rotation_euler.y = math.radians(9) * math.sin(phase - 5.5)
    for g in range(len(GROUPS)):
        lift = math.radians(17) * math.sin(phase - 1.05 * g)
        parts[f"FlapR{g + 1}"].rotation_euler.x = lift
        parts[f"FlapL{g + 1}"].rotation_euler.x = -lift
    for side, lag in (("R", 0.0), ("L", 2.2)):
        parts[f"Arm{side}1"].rotation_euler.y = math.radians(5) * math.sin(phase + lag)
        parts[f"Arm{side}2"].rotation_euler.y = math.radians(11) * math.sin(phase + lag - 0.7)
        parts[f"Arm{side}3"].rotation_euler.y = math.radians(15) * math.sin(phase + lag - 1.4)
        parts[f"Arm{side}4"].rotation_euler.y = math.radians(19) * math.sin(phase + lag - 2.1)


def steps(n):
    """the corner steps of a slice n cubes out: (top, bottom). A wide slice is rounded in two steps, like a shell"""
    if n >= 6:
        return [(3, 1), (1, 1)], [(2, 1)]
    return ([(2, 1)] if n == 5 else [(1, 1)]), [(1, 1)]


def slab(p, x0, x1, n, bot, top):
    """a slice of body: dark above (lighter on the top row), pale below the line"""
    top_steps, bottom_steps = steps(n)
    p.hull(x0, x1, n, bot, top, "shell", top_steps, bottom_steps)
    p.paint_sym(x0, x1, n, top - 1, top, "shell+")
    p.paint_sym(x0, x1, n, bot, int(EDGE), "belly")
    if bot <= -3:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def out_at(x):
    """how many cubes out the body is at x"""
    for x0, x1, n, _, _ in SLICES:
        if x0 <= x < x1:
            return n
    return SLICES[-1][2]


def root_at(x):
    """how far out a flap at x may start and still have its whole end inside the body: inside the outermost column that
    runs the body's full depth, in every slice the flap's end lies in"""
    cols = [(n - 2 if n >= 6 else n - 1) for x0, x1, n, _, _ in (HEAD,) + SLICES if x0 < x + 1.7 and x1 > x - 1.7]
    return min(cols) - 0.3


def louvre(part, side, x, tip, sweep, wide=3.3, thick=0.5, tilt=12.0):
    """one flap on one side (side: 1 right, -1 left): a plain thin plate from inside the body's side, out to `tip`, back by
    `sweep` and down as it goes, turned about its own length so its back edge is higher than its front: the next flap's
    front edge then lies under it, like a louvre"""
    root = root_at(x)
    p0, p1 = (x, side * root, EDGE), (x + sweep, side * tip, EDGE - DROOP * (tip - root))
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    across = [along[1] * side, -along[0] * side, 0.0]  # level, pointing back
    size = math.sqrt(sum(v * v for v in across))
    across = [v / size for v in across]
    up = [along[1] * across[2] - along[2] * across[1], along[2] * across[0] - along[0] * across[2], along[0] * across[1] - along[1] * across[0]]
    if up[2] < 0:
        up = [-v for v in up]
    c, s = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
    across, up = [w * c + t * s for w, t in zip(across, up)], [t * c - w * s for w, t in zip(across, up)]
    verts = []
    for end in (-1, 1):
        for sw, st in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(tuple((a + b) / 2 + end * al * length / 2 + sw * w * wide / 2 + st * t * thick / 2
                               for a, b, al, w, t in zip(p0, p1, along, across, up)))
    part.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], "fin")


def build(m):
    head = m.part("Head", (-14, 0, 0))
    # the head: a low smooth shield, a step narrower than the body, rounding to the nose one step at a time
    for x0, x1, n, bot, top in (HEAD, (-23, -21, 4, -2, 3), (-25, -23, 4, -2, 2), (-26, -25, 3, -2, 2)):
        top_steps, bottom_steps = steps(n)
        head.hull(x0, x1, n, bot, top, "shell", top_steps, bottom_steps)
        head.paint_sym(x0, x1, n, top - 1, top, "shell+")
        head.paint_sym(x0, x1, n, bot, int(EDGE), "belly")
    # the head shield: a low dark boss on the top of the head, in two tiers so it is rounded
    for x0, x1, half, high in ((-22.2, -15.0, 3.1, 3.2), (-22.7, -14.5, 2.2, 3.4)):
        plate = (-half, half, 2.9, high)
        head.block(x0, plate, x1, plate, "arm")
    # the eyes on their stalks: a short thick stalk out of each side of the head, a big pale eyeball on its end, and a dark
    # pupil set on the eyeball's front outer corner (so it looks forward and sideways) with a thin halo of cold light
    head.beam((-17.5, 3.0, 1.1), (-17.6, 6.4, 3.9), 1.6, 1.6, "arm", mirror=True)
    ball = (5.4, 8.2, 2.8, 5.6)
    head.block(-19.0, ball, -16.2, ball, "bone", mirror=True)
    head.beam((-17.4, 6.6, 4.2), (-19.15, 8.35, 4.2), 1.9, 1.8, "soft", flat="z", mirror=True)
    head.beam((-17.6, 6.8, 4.2), (-19.35, 8.55, 4.2), 1.4, 1.3, "black", flat="z", mirror=True)
    # the mouth, underneath: a dark ring, a round of pale plates inside it, a dark middle
    for (x0, x1, half, low), colour in (((-19.4, -15.4, 2.0, -2.3), "arm"), ((-18.8, -16.0, 1.4, -2.45), "bone"), ((-18.0, -16.8, 0.6, -2.6), "mouth")):
        ring = (-half, half, low, -1.9)
        head.block(x0, ring, x1, ring, colour)

    # the grabbing arms: four boxes each, every one smaller than the last and starting inside it, each on its own joint,
    # curling down and back. Pale spines on the inside of the curl, and a hook at the end
    for name, side in (("R", 1), ("L", -1)):
        y = 2.2 * side
        parent = "Head"
        for k, ((ax, az), (bx, bz), wide, thick, spines, tall) in enumerate(ARM):
            part = m.part(f"Arm{name}{k + 1}", (ax, y, az), parent)
            parent = part.name
            part.beam((ax, y, az), (bx, y, bz), wide, thick, "arm")
            length = math.hypot(bx - ax, bz - az)
            dx, dz = (bx - ax) / length, (bz - az) / length
            ix, iz = -dz, dx  # the inside of the curl
            for f in spines:
                cx, cz = ax + f * (bx - ax) + ix * (wide / 2 - 0.3), az + f * (bz - az) + iz * (wide / 2 - 0.3)
                base = [(cx - 0.5 * dx, y - 0.45, cz - 0.5 * dz), (cx + 0.5 * dx, y - 0.45, cz + 0.5 * dz),
                        (cx + 0.5 * dx, y + 0.45, cz + 0.5 * dz), (cx - 0.5 * dx, y + 0.45, cz - 0.5 * dz)]
                part.spike(base, (cx + ix * (tall + 0.3) + 0.3 * dx, y, cz + iz * (tall + 0.3) + 0.3 * dz), "bone")
            if k == len(ARM) - 1:  # the hook: the curl goes on to a point
                cx, cz = bx - 0.4 * dx, bz - 0.4 * dz
                base = [(cx - 0.45 * ix, y - 0.4, cz - 0.45 * iz), (cx + 0.45 * ix, y - 0.4, cz + 0.45 * iz),
                        (cx + 0.45 * ix, y + 0.4, cz + 0.45 * iz), (cx - 0.45 * ix, y + 0.4, cz - 0.45 * iz)]
                part.spike(base, (bx + 1.3 * dx + 0.9 * ix, y, bz + 1.3 * dz + 0.9 * iz), "bone")

    # the body: three pieces, each a run of slices
    bodies = {}
    for k, (name, start, end) in enumerate(BODY):
        part = m.part(name, (start, 0, 0), "Head" if k == 0 else BODY[k - 1][0])
        bodies[name] = part
        for x0, x1, n, bot, top in SLICES:
            if start <= x0 < end:
                slab(part, x0, x1, n, bot, top)
        # a sleeve into the piece in front, sized from the smaller of the two and clear of the steps of both
        first = next(s for s in SLICES if s[0] == start)
        before = HEAD if k == 0 else next(s for s in SLICES if s[1] == start)
        n, bot, top = min(first[2], before[2]), max(first[3], before[3]), min(first[4], before[4])
        part.sym(start - 1, start, max(n - 3, 0), bot + 1, top - 1, "shell-")
    # the seat: on the hump, a shallow slot either side for the rider's legs, above the flaps
    for side in (1, -1):
        bodies["B1"].carve(-3, -1, 7 * side, 7 * side + 1, 0, 2)
        slot = (6.45, 7.2, 0, 1.85) if side > 0 else (-7.2, -6.45, 0, 1.85)
        bodies["B1"].block(-3, slot, -1, slot, "shell-")

    # the flaps: thirteen a side, in six groups a side that each move on a joint
    for g, group in enumerate(GROUPS):
        xs = [FLAPS[i][0] for i in group]
        middle = sum(xs) / len(xs)
        owner = next(name for name, start, end in BODY if start <= middle < end)
        for name, side in (("R", 1), ("L", -1)):
            part = m.part(f"Flap{name}{g + 1}", (middle, side * (out_at(middle) + 0.5), EDGE), owner)
            for i in group:
                louvre(part, side, *FLAPS[i])

    # the tail: a short stock, and a fan of three blades each side, rising and spreading
    tail = m.part("Tail", (25, 0, 0), "B3")
    stock = (-2.1, 2.1, -1.5, 1.6)
    tail.block(24.9, stock, 26.8, stock, "shell")
    tail.beam((25.6, 0.7, 0.9), (31.0, 3.0, 5.6), 2.4, 0.5, "fin", flat="z", mirror=True)
    tail.beam((25.6, 0.7, 0.5), (31.4, 5.6, 3.0), 2.4, 0.5, "fin", flat="z", mirror=True)
    tail.beam((25.6, 0.7, 0.1), (30.4, 7.2, 0.2), 2.4, 0.5, "fin", flat="z", mirror=True)
