"""The Claw Shark (a study, not for the game as it is: built from the user's reference picture of another game's creature,
to see how a dark and red rare is put together in our style) for tools/blender/voxel_kit.py.
Its geometry, read from the picture: a shark's head with a wide open grin and one horn, on a short, humped lobster's body.
A dark blue helmet and a back of overlapping plates; two heavy clawed arms held forward and down, each a spiked shoulder
plate, an upper arm, a forearm that swells into a spiked gauntlet with gold work, a hand and three hooked talons; and from
the flanks six long legs that rise, arch over and come down to points, dark violet on top and orange underneath.
The colourway: red at full strength for the flesh, two darks (slate blue plates, violet legs) round it, and the light
underneath: a lit yellow-green belly, the orange undersides of the legs, the yellow eye. Pink only on the horn.
The rider sits on the hump behind the helmet, on a saddle of plate between two wells for the legs."""
import math

NAME, ZONE, RARITY = "Claw Shark (study)", "STUDY", "MYTHIC"
U = 0.5
PALETTE = {"red": "#D6201C", "deep": "#6E0F1E", "shell": "#2B3860", "limb": "#3A2E86", "under": "#F2622A", "bile": "#D9DC48",
           "seam": "#8F9A2C", "gold": "#F7A823", "horn": "#EC4A86", "tooth": "#FFFFFF", "maw": "#3A0A14", "eye": "#FFD21E",
           "black": "#15181D"}
SHADE = 0.86
SEAT = (-4.5, 10, 7.5)
GLOW = {"bile": 0.45, "eye": 0.8}
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["shell"]}]
FRAME, ORTHO = 3.6, 50.0

# the body: (from, to, cubes out, bottom, top). One number changes from slice to slice: the back rises to the hump the
# rider sits on and falls to the tail, the belly is deepest under the hump, the chest is the widest
SLICES = ((-10, -9, 7, -5, 8), (-9, -8, 7, -5, 9), (-8, -7, 7, -6, 9), (-7, -2, 7, -6, 10), (-2, 0, 7, -6, 9), (0, 2, 6, -6, 9),
          (2, 4, 6, -6, 8), (4, 6, 6, -5, 8), (6, 8, 5, -5, 8), (8, 10, 5, -5, 7), (10, 12, 5, -4, 7), (12, 14, 4, -4, 7),
          (14, 16, 4, -4, 6), (16, 18, 4, -3, 6))
PIECES = (("Chest", -10), ("A1", 2), ("A2", 10))
CHAIN = [name for name, _ in PIECES] + ["Tail"]
AMPLITUDES = [1.0, 3.0, 5.0, 7.0]
CHEEK = (6, -5, 7)  # the back of the skull: cubes out, bottom, top

# the legs, right side: the piece each grows from, and its line from the root, up over the arch, down to the point
LEGS = (("LegF", "Chest", ((-3, 5.5, 3), (-1, 11.5, 11), (3, 16.5, 15.5), (9, 19.5, 13.5), (14, 20.5, 7), (16, 19.5, 0.5))),
        ("LegM", "A1", ((4, 4.8, 4), (6.5, 8.5, 13.5), (11, 11.5, 20.5), (19, 13, 22), (26, 13.5, 17.5), (29, 12.5, 11))),
        ("LegB", "A2", ((11.5, 3.8, 3.5), (15.5, 6.5, 10.5), (22, 8.5, 15.5), (31, 9.5, 15), (38, 9, 9.5), (41, 7.5, 3.5))))
LEG_SIZES = ((4.0, 1.9), (3.4, 1.6), (2.8, 1.3), (2.2, 1.1))  # (width, thickness) of each box, root to tip


def pose(parts, phase):
    """a shrimp's swim: a wave runs down the body and the tail; the legs open and sweep together one pair after the
    other, their outer halves a little later; the arms row; the jaw shuts and opens"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.6 * (k + 1))
    parts["Jaw"].rotation_euler.y = math.radians(9) * (0.5 + 0.5 * math.sin(phase))
    for k, (name, _, _) in enumerate(LEGS):
        for tag, side in (("R", 1), ("L", -1)):
            lag = 0.9 * k
            parts[name + tag].rotation_euler.z = side * math.radians(7) * math.sin(phase - lag)
            parts[name + tag].rotation_euler.x = side * math.radians(5) * math.sin(phase - lag - 0.8)
            parts[name + tag + "2"].rotation_euler.z = side * math.radians(8) * math.sin(phase - lag - 0.9)
    for tag, side in (("R", 1), ("L", -1)):
        parts["Arm" + tag].rotation_euler.z = side * math.radians(5) * math.sin(phase)
        parts["Arm" + tag].rotation_euler.y = math.radians(4) * math.sin(phase + 1.0)
        parts["Claw" + tag].rotation_euler.y = math.radians(6) * math.sin(phase + 0.4)


def steps_for(n):
    return [(3, 1), (2, 1), (1, 1)] if n >= 7 else ([(2, 1), (1, 1)] if n >= 5 else [(1, 1)])


def dress(p, x0, x1, n, bot, top, steps):
    """a slice's colours: the plate on the back (its top row lighter), red flanks, and the lit belly on the lower steps,
    cut into segments by a darker seam every third cube"""
    p.paint_sym(x0, x1, n, top - steps, top, "shell")
    p.paint_sym(x0, x1, n, top - 1, top, "shell+")
    p.paint_sym(x0, x1, n, bot, bot + steps, "bile")
    for x in range(x0, x1):
        if x % 3 == 0:
            p.paint_sym(x, x + 1, n, bot, bot + steps, "seam")


def frame(p0, p1):
    """a box's own directions between two points: along it, across it, and through it (the one nearest to up)"""
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    along = [v / length for v in d]
    thin = [r - along[2] * a for a, r in zip(along, (0.0, 0.0, 1.0))]
    n = math.sqrt(sum(v * v for v in thin))
    thin = [v / n for v in thin]
    wide = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
    return length, along, wide, thin


def at(p, v, d):
    return tuple(a + b * d for a, b in zip(p, v))


def square(centre, a, b, ha, hb):
    """four corners round a point, ha out along a and hb out along b: the base of a spike"""
    return [at(at(centre, a, i * ha), b, j * hb) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def limb_box(part, p0, p1, wide, thick, colour, under=None, inset=0.6):
    """a box from p0 to p1 and, if asked, a strip of another colour down its underside: narrower, shorter, 0.4 proud"""
    part.beam(p0, p1, wide, thick, colour, flat="z")
    if under:
        length, along, across, thin = frame(p0, p1)
        mid = at(at(p0, along, length / 2), thin, -(thick / 2 + 0.05))
        part._oriented(mid, along, across, thin, (length - 2 * inset, wide - 0.8, 0.7), under, False)


def leg(m, name, s, parent, line):
    """one leg on two joints: two boxes up from the body, then two over the arch and down, then a point. Each box is
    smaller than the last and starts inside it. A short spike stands on the top of the arch"""
    pts = [(x, y * s, z) for x, y, z in line]
    upper = m.part(name, pts[0], parent)
    lower = m.part(name + "2", pts[2], name)
    for i in range(4):
        part = upper if i < 2 else lower
        _, along, _, _ = frame(pts[i], pts[i + 1])
        start = pts[i] if i == 0 else at(pts[i], along, -0.7)
        limb_box(part, start, pts[i + 1], LEG_SIZES[i][0], LEG_SIZES[i][1], "limb", "under")
    _, along, across, thin = frame(pts[1], pts[2])
    knee = at(at(pts[2], along, -1.1), thin, LEG_SIZES[1][1] / 2 - 0.35)
    upper.spike(square(knee, along, across, 0.75, 0.75), at(at(knee, thin, 2.8), along, 0.9), "limb-")
    # the point: a pyramid from inside the last box
    _, along, across, thin = frame(pts[3], pts[4])
    lower.spike(square(at(pts[4], along, -0.5), across, thin, 0.85, 0.4), pts[5], "limb-")


def build(m):
    cn, cbot, ctop = CHEEK
    head = m.part("Head", (-10, 0, 0))
    # the skull: deep, wide cheeks at the back under the helmet, a narrower step in front that carries the eye, its
    # underside the roof of the mouth
    head.hull(-16, -10, cn, cbot, ctop, "red", [(2, 1), (1, 1)], [(2, 1), (1, 1)])
    head.paint_sym(-16, -10, cn, 5, 7, "shell")
    head.paint_sym(-16, -10, cn, 6, 7, "shell+")
    head.paint_sym(-16, -10, cn, -5, -4, "red-")
    head.hull(-20, -16, 5, -1, 6, "red", [(1, 1)], [])
    head.sym(-20, -16, 3, -4, -1, "maw")  # the dark of the mouth, set in from the teeth
    # the snout: short and blunt, three blocks in a chain, each tilted a little nose-down, lower and narrower than the
    # last, their undersides rising to the tip as a shark's does
    blocks = ((-19.5, -23.0, 2.4, 2.1, 9.4, 6.4), (-22.3, -25.0, 1.95, 1.7, 6.8, 4.6), (-24.5, -26.2, 1.6, 1.45, 4.0, 2.8))

    def lip(k, x):
        x0, x1, z0, z1, _, thick = blocks[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) - thick / 2

    for x0, x1, z0, z1, wide, thick in blocks:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "red", flat="z")
    nostril = (1.0, 1.7, 2.2, 2.75)
    head.block(-25.8, nostril, -25.1, nostril, "black", mirror=True)
    # the upper teeth: big white points, bases sunk in, smaller toward the tip
    for x, size, length in ((-17.0, 1.5, 1.3), (-18.8, 1.6, 2.0)):
        head.tooth(x, 5.2 - size / 2, -0.75, size, length, "tooth")
    for k, x, size, length in ((0, -20.4, 1.6, 2.4), (0, -22.0, 1.4, 2.3), (1, -23.9, 1.4, 2.2), (2, -25.5, 1.1, 1.6)):
        head.tooth(x, blocks[k][4] / 2 - 0.3 - size / 2, lip(k, x) + 0.3, size, length, "tooth")
    # the eye on the front step: a dark socket, the lit yellow eye, a thin dark pupil. The helmet comes down over it as a
    # brow that slants down to the front and comes past the eye, so it scowls
    socket = (5.38, 5.94, 2.0, 4.8)
    head.block(-19.6, socket, -16.6, socket, "maw", mirror=True)
    eye = (5.85, 6.07, 2.3, 4.5)
    head.block(-19.3, eye, -16.9, eye, "eye", mirror=True)
    pupil = (5.97, 6.2, 2.55, 4.25)
    head.block(-18.45, pupil, -17.75, pupil, "black", mirror=True)
    head.beam((-21.0, 5.25, 3.6), (-15.2, 5.25, 5.4), 1.7, 2.2, "shell", mirror=True)
    # the helmet's visor: one plate sloping down the forehead from the skull's top; two short spikes at its back corners
    head.beam((-21.4, 0, 5.9), (-14.0, 0, 6.3), 8.2, 1.2, "shell", flat="z")
    head.tooth(-11.6, 3.3, 6.7, 1.5, -2.6, "shell-", lean=(1.1, 0.5))
    # the horn: a thick root leaning forward, then a point that turns up
    head.beam((-17.4, 0, 6.0), (-19.6, 0, 9.8), 2.5, 2.3, "horn", flat="y")
    head.tooth(-19.5, 0, 9.1, 1.8, -5.2, "horn", mirror=False, lean=(1.2, 0.0))
    # gills: three dark slits in the cheek
    for x in (-15, -13, -11):
        head.dent(x, x + 1, 6, -1, 4, "deep")

    # the lower jaw, on its own joint, held open: two deep boxes in a chain dropping away from the skull, the dark of the
    # mouth laid on top, and teeth that point up, starting where the gap is wide enough for them
    jaw = m.part("Jaw", (-15, 0, -4), "Head")
    jaws = ((-14.4, -20.6, -4.4, -7.3, 9.8, 3.0), (-19.8, -24.0, -6.9, -8.5, 6.8, 2.2))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 * math.hypot(x1 - x0, z1 - z0) / abs(x1 - x0)

    for k, (x0, x1, z0, z1, wide, thick) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "red", flat="z")
        a, b = x0 - 1.2, x1 + 0.5
        jaw.beam((a, 0, jaw_top(k, a) + 0.15), (b, 0, jaw_top(k, b) + 0.15), wide - 1.2, 0.4, "maw", flat="z")
    jaw.beam((-16.5, 0, -7.05), (-19.4, 0, -8.41), 7.6, 0.5, "red-", flat="z")  # a darker chin plate
    for k, x, size, length in ((0, -18.0, 1.3, 1.3), (0, -19.6, 1.4, 1.9), (1, -21.4, 1.4, 2.0), (1, -23.0, 1.2, 1.8)):
        jaw.tooth(x, jaws[k][4] / 2 - 0.25 - size / 2, jaw_top(k, x) - 0.3, size, -length, "tooth", lean=(-0.3, 0.0))

    # the body: the chest, and the tail in two pieces
    made, prev, starts = {}, (cn, cbot, ctop, 2), dict((x, name) for name, x in PIECES)
    for x0, x1, n, bot, top in SLICES:
        steps = steps_for(n)
        if x0 in starts:
            parent = "Head" if not made else list(made)[-1]
            seg = made[starts[x0]] = m.part(starts[x0], (x0, 0, 0), parent)
            fn, fbot, ftop, fsteps = prev
            clear = max(len(steps), fsteps)
            seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "deep")
        seg.hull(x0, x1, n, bot, top, "red", steps, steps)
        dress(seg, x0, x1, n, bot, top, len(steps))
        prev = (n, bot, top, len(steps))
    # each piece is an armour segment: the last row of its red flank is a tone darker
    ends = [x for _, x in PIECES[1:]] + [SLICES[-1][1]]
    for (name, _), end in zip(PIECES, ends):
        for cell, colour in list(made[name].cells.items()):
            if cell[0] == end - 1 and colour == "red":
                made[name].cells[cell] = "deep"
    chest = made["Chest"]
    # the saddle: three cubes of plate between two wells for the rider's legs
    chest.carve_pair(-6, -3, 2, 4, 8, 10)
    # the plates of the back. On the chest: one that climbs from the helmet to the hump in front of the rider, a raised
    # rim behind the saddle, and two spikes on each shoulder. Each piece of the tail carries one plate, lying level while
    # the back falls away under it, so its back edge stands over the next, with a short spike on it
    chest.beam((-13.5, 0, 5.1), (-8.6, 0, 10.6), 10.4, 1.6, "shell", flat="z")
    chest.beam((-9.6, 0, 9.2), (-6.3, 0, 12.4), 8.4, 1.3, "shell+", flat="z")
    chest.beam((-2.4, 0, 8.3), (1.9, 0, 9.75), 9.8, 0.9, "shell", flat="z")
    for x, y, z, tall in ((-8.0, 4.5, 7.5, 3.0), (-6.6, 5.6, 6.6, 3.4)):
        chest.tooth(x, y, z, 1.6, -tall, "shell-", lean=(1.0, 0.6))
    for name, x0, x1, z0, z1, wide in (("A1", 2.4, 10.7, 7.95, 8.2, 9.6), ("A2", 10.4, 16.6, 6.95, 7.25, 8.2)):
        made[name].beam((x0, 0, z0), (x1, 0, z1), wide, 0.9, "shell", flat="z")
        made[name].tooth(x1 - 1.2, 0, z1 + 0.2, 1.3, -1.6, "shell-", mirror=False, lean=(0.9, 0.0), long=2.0)
    # the tail fan: a red stalk, then two flat blocks that widen, the last the widest and thinnest
    tail = m.part("Tail", (18, 0, 1.5), "A2")
    tail.beam((17.2, 0, 1.4), (20.6, 0, 1.3), 6.4, 3.2, "red", flat="z")
    tail.block(19.8, (-2.8, 2.8, 0.5, 2.2), 24.6, (-5.8, 5.8, 1.0, 2.0), "shell")
    tail.block(23.0, (-4.4, 4.4, 1.15, 1.85), 26.2, (-7.0, 7.0, 1.4, 1.7), "shell-")

    # the arms: a spiked shoulder plate and an upper arm on one joint. On the next, in one line: the forearm, a gold ring,
    # the gauntlet it swells into (two gold strips on top, two spikes on its outer side), an elbow spike, the hand, and
    # three talons that each run forward and hook down
    for tag, s in (("R", 1), ("L", -1)):
        arm = m.part("Arm" + tag, (-9, 6.3 * s, -2.8), "Chest")
        arm.beam((-7.0, 4.2 * s, -1.6), (-13.5, 10.5 * s, -6.0), 3.4, 3.0, "red-", flat="z")
        arm.beam((-7.4, 6.0 * s, -0.3), (-11.8, 10.8 * s, -2.6), 5.4, 1.3, "shell", flat="z")
        arm.tooth(-10.3, 9.2 * s, -1.9, 1.6, -3.0, "shell-", mirror=False, lean=(0.9, 0.8 * s))
        claw = m.part("Claw" + tag, (-13.2, 10.2 * s, -5.8), "Arm" + tag)
        e, w = (-12.4, 10.3 * s, -5.5), (-23.0, 9.0 * s, -8.8)
        _, along, across, thin = frame(e, w)
        out = across if across[1] * s > 0 else tuple(-v for v in across)  # away from the body

        def box(a0, a1, wide, thick, colour, lift=0.0, side=0.0):
            mid = at(at(at(e, along, (a0 + a1) / 2), thin, lift), out, side)
            claw._oriented(mid, along, across, thin, (a1 - a0, wide, thick), colour, False)

        box(0.0, 6.0, 4.4, 3.6, "red")
        box(3.2, 4.6, 5.2, 4.2, "gold")
        box(4.4, 10.8, 5.8, 4.6, "red")
        for side in (-1.5, 1.5):
            box(5.2, 10.2, 0.9, 0.6, "gold", lift=2.35, side=side)
        for a in (6.2, 9.0):
            root = at(at(e, along, a), out, 2.5)
            claw.spike(square(root, along, thin, 0.85, 0.85), at(at(root, out, 3.0), along, -1.3), "deep")
        elbow = at(at(e, along, 1.0), thin, 1.4)
        claw.spike(square(elbow, along, across, 0.9, 0.8), at(at(elbow, thin, 3.4), along, -2.0), "deep")
        box(10.1, 13.9, 4.8, 3.6, "red")
        for off in (-1.6, 0.0, 1.6):
            root = at(at(at(e, along, 13.3), out, off), thin, -0.5)
            knuckle = at(at(root, along, 3.2), thin, -1.5)
            claw.beam(root, knuckle, 1.3, 1.5, "deep", flat="z")
            _, t_along, t_across, t_thin = frame(root, knuckle)
            claw.spike(square(at(knuckle, t_along, -0.4), t_across, t_thin, 0.55, 0.6), at(at(knuckle, along, 1.8), thin, -3.9), "deep")

    for name, parent, line in LEGS:
        leg(m, name + "R", 1, parent, line)
        leg(m, name + "L", -1, parent, line)
