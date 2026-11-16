"""Megalodon, the trial of docs/style/07-shape-variety.md (zone 8's Legendary: the giant prehistoric shark) for
tools/blender/voxel_kit.py. A redesign beside the game's model, to test the rules for telling creatures apart.
Its body idea: THE MOUTH. It is nearly all head and jaws, and the rest falls away behind them.
- Head and jaws are over two fifths of the length. Seen from above the widest point of the animal is the jaw hinge; the
  body starts narrower than the head and thins all the way to a tail that is small for the animal.
- The body is deepest at the head: the back falls and the belly rises from there, one cube at a time. No barrel.
- The mouth gapes. The lower jaw is its own part, wider and longer than the upper (an underbite), in three tilted
  blocks. Huge teeth in an uneven row: different heights, a gap here and there, two leaning; the two sides differ.
  Dark red inside, a thin pink gum line set inside the lips.
- The upper jaw is a wide low shelf; the cranium is a narrower stack on it, so from the front the jaws flare past
  the skull. A small halo eye (its only glow) sits far forward and high under a heavy brow that comes past it.
- Colour: dark moss green on bone. The line between them is low and wavy and follows the belly up to the tail.
- The one mark is history: three pale claw scars raked along the left flank, and torn fins: blocks left out of the
  trailing edges of the back fin and the tail.
- A low, thick back fin (a sloping front block and a body of cubes); heavy side fins in two broad boxes.
The rider sits behind the head on a saddle of back, a leg slot cut either side of it."""
import math

NAME, ZONE, RARITY = "Megalodon (trial)", "ZONE 8 / VENTS", "LEGENDARY"
U = 0.5
# "fin" is the moss of the back under another name, so the studs can be kept to the head and the back
PALETTE = {"moss": "#43602C", "fin": "#43602C", "bone": "#E4D9BC", "black": "#14171B", "mouth": "#701C24", "tooth": "#FFFDF4",
           "gum": "#DC8492", "soft": "#FFC45C", "scar": "#C4CA9E"}
SEAT = (-2, 11, 4.1)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
FRAME, ORTHO, ORTHO_SWIM = 3.7, 50.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["moss"], "turned": True}]  # studs on top of the head and the back
DROP = 0.25  # how far a gum plate shows past its lip
LIP = 1.2  # the thickness of the pale lip plate under the upper jaw

# ---- the body behind the head: it starts narrower and shallower than the head and loses one cube at a time, in width,
# from the back or from the belly, never two at one place
START = (10, -10, 11)  # cubes out, bottom, top, at the back of the head
NARROWER = (1, 5, 10, 14, 18, 22, 25, 29)
LOWER = (4, 9, 13, 17, 20, 23, 26, 30)
SHALLOWER = (-3, 0, 3, 7, 11, 16, 21, 27)
JOINTS, END = (("S1", -6), ("S2", 3), ("S3", 15), ("S4", 22), ("S5", 28)), 34
CHEEK = (-12, -6, 12, -11, 12)  # the back of the head, where the jaw hinges: the deepest and widest slice
ROOF = (-20, -12, 12, -2, 11)  # the skull over the back of the mouth
CROWN = [(4, 3), (2, 2)]  # the head's top corners: two broad steps, so the cranium is narrower than the jaws


def body():
    """the slices behind the head, part by part"""
    assert len(set(NARROWER + LOWER + SHALLOWER)) == len(NARROWER + LOWER + SHALLOWER)
    cuts = sorted(set(NARROWER + LOWER + SHALLOWER + tuple(x for _, x in JOINTS)) | {END})
    out, (n, bot, top) = [], START
    for x0, x1 in zip(cuts, cuts[1:]):
        n, top, bot = n - (x0 in NARROWER), top - (x0 in LOWER), bot + (x0 in SHALLOWER)
        name = [part for part, x in JOINTS if x <= x0][-1]
        if not out or out[-1][0] != name:
            out.append((name, []))
        out[-1][1].append((x0, x1, n, bot, top))
    return tuple((name, tuple(slices)) for name, slices in out)


BODY = body()
DEPTH = {x: (bot, top) for s in (CHEEK,) + tuple(s for _, slices in BODY for s in slices) for x in range(s[0], s[1])
         for bot, top in (s[3:],)}
WAVE = (0, 0, 1, 2, 3, 3, 3, 2, 1, 0)


def edge(x):
    """the height of the line between the moss and the bone at x: low, following the belly, and wavy (less so as the
    body gets shallow)"""
    if x < CHEEK[1]:  # on the cheek it comes down from the corner of the mouth, so the bone of the jaw runs on into the belly
        return -4 - (x - CHEEK[0]) // 2
    bot, top = DEPTH[x]
    reach = 3 if top - bot >= 16 else (2 if top - bot >= 9 else 1)
    return bot + 2 + round(reach * WAVE[(x + 14) % 10] / 3)


CHAIN = ["Head"] + [name for name, _ in BODY] + ["Tail"]
AMPLITUDES = [1, 2, 3.5, 5.5, 8.5, 13]


def pose(parts, phase):
    """a heavy swim: the great head hardly moves, a slow wave grows down the short body to the small tail. The jaw
    hangs open at rest and bites up a little once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.8 * (k + 1))
    parts["Jaw"].rotation_euler.y = math.radians(4) * (0.5 + 0.5 * math.sin(phase))


def steps(n):
    """the corners of the back and the belly: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 9 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def slab(p, x0, x1, n, bot, top, crown=None):
    """a slice of body: stepped corners, moss with a lighter top row, bone below the wavy line with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "moss", crown or steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "moss+")
    for x in range(x0, x1):
        p.paint_sym(x, x + 1, n, bot, edge(x), "bone")
    p.paint_sym(x0, x1, n, bot, bot + 1, "bone-")


def fill(p, x0, x1, n, z0, z1, colour):
    """cubes where there are none yet (a fin of cubes standing on the back keeps the back's own colours inside)"""
    for i in range(x0, x1):
        for j in range(-n, n + 1):
            for k in range(z0, z1):
                p.cells.setdefault((i, j, k), colour)


def scar(parts, x0, x1, z):
    """a length of scar: the outermost cubes of the left flank from x0 to x1 at height z, painted pale. parts: (part, the
    x it starts at), front first"""
    for x in range(x0, x1):
        p = [part for part, start in parts if start <= x][-1]
        js = [j for (i, j, k) in p.cells if i == x and k == z]
        if js:
            p.cells[(x, min(js), z)] = "scar"


def line(blocks):
    """for a chain of tilted blocks (from, to, the middle's height at each end, width, thickness): the middle's height
    of block k at x"""
    def mid(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    return mid


def build(m):
    head = m.part("Head", (CHEEK[1], 0, 0))
    # the back of the head in cubes. The cheek is the deepest, widest slice of the animal, and a block either side of it
    # is the jaw's hinge: the widest point. In front of it the skull roofs the back of the mouth
    slab(head, *CHEEK, crown=CROWN)
    head.pair(-12, -7, 13, 14, -9, 1, "moss")
    for x in range(-12, -7):
        head.paint_pair(x, x + 1, 13, 14, -9, edge(x), "bone")
    x0, x1, n, bot, top = ROOF
    head.hull(x0, x1, n, bot, top, "moss", CROWN, ())
    head.paint_sym(x0, x1, n, top - 1, top, "moss+")
    head.paint_sym(x0, x1, n, bot, bot + 1, "bone")  # the lip
    head.paint(-12, -11, -11, 12, -4, -2, "mouth")  # the corner of the mouth, dark inside

    # the upper jaw: a wide, low shelf of three tilted blocks in a chain, each narrower than the last, a bone lip plate
    # under each and a thin gum plate under that, set in from the lip's edge. (from, to, the middle's height at each
    # end, width, thickness, where its gum starts)
    upper = ((-19.5, -27.5, 2.3, 1.9, 23.4, 5.8, -19.9), (-26.0, -33.5, 2.0, 1.6, 19.4, 5.0, -27.8), (-32.0, -38.0, 1.7, 1.2, 14.8, 4.4, -33.8))
    umid = line(upper)

    def lip_bottom(x):
        """the underside of the upper lip at x"""
        if x > -20:
            return float(ROOF[3])
        k = 0 if x > -27.5 else (1 if x > -33.5 else 2)
        return umid(k, x) - upper[k][5] / 2 - LIP

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(upper):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "moss", flat="z")
        lip = thick / 2 + LIP / 2
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, LIP, "bone", flat="z")
        low = thick / 2 + LIP + DROP / 2 - 0.025
        head.beam((gum_from, 0, umid(k, gum_from) - low), (x1 + 0.3, 0, umid(k, x1 + 0.3) - low), wide - 1.0, DROP + 0.05, "gum", flat="z")
    gum = (-12.0, 12.0, ROOF[3] - DROP, ROOF[3] + 0.05)
    head.block(-19.8, gum, -11.8, gum, "gum")
    # the cranium: two narrower blocks lying on the shelf, so the jaws flare past the skull. It stays high almost to the
    # nose and ends in a wall: a blunt, heavy forehead, not a pointed snout. (the block it lies on, from, to, width,
    # thickness, how far it is sunk into the shelf)
    for k, x0, x1, wide, thick, sunk in ((0, -19.5, -28.0, 16.4, 5.2, 0.05), (1, -26.5, -36.0, 12.4, 4.2, 0.5)):
        rise = upper[k][5] / 2 + thick / 2 - sunk
        head.beam((x0, 0, umid(k, x0) + rise), (x1, 0, umid(k, x1) + rise), wide, thick, "moss", flat="z")
    nostril = (4.2, 4.9, 2.1, 2.9)
    head.block(-38.4, nostril, -37.6, nostril, "black", mirror=True)
    # the eye: small for the head, far forward and high on the side of the cranium. A dark socket, a thin halo of soft
    # light, a dark pupil; and a heavy brow that slants down to the front, cuts the top of the eye and comes well past it
    socket = (6.0, 6.45, 4.6, 6.8)
    head.block(-33.4, socket, -30.8, socket, "moss-", mirror=True)
    halo = (6.3, 6.65, 4.8, 6.6)
    head.block(-33.1, halo, -31.1, halo, "soft", mirror=True)
    pupil = (6.5, 6.95, 5.1, 6.3)
    head.block(-32.7, pupil, -31.5, pupil, "black", mirror=True)
    head.beam((-35.2, 6.5, 6.85), (-28.5, 6.5, 8.1), 2.4, 2.6, "moss", mirror=True)
    # the dark inside of the mouth: one block that widens and shallows to the corner, behind the teeth all the way, its
    # top inside the lips and its bottom inside the lower jaw
    head.block(-11.5, (-10.2, 10.2, -4.7, -1.4), -36.2, (-5.2, 5.2, -10.05, -1.4), "mouth")
    # the upper teeth, hanging from the gum: (x, length, lean along x) down each side, the two sides not the same
    for side, row in ((1, ((-14.0, 1.3, 0), (-17.2, 1.9, 0), (-21.6, 2.6, 0), (-24.9, 3.7, 0.5), (-29.0, 2.4, 0), (-31.9, 3.9, 0),
                           (-35.0, 3.0, 0))),
                      (-1, ((-14.0, 1.5, 0), (-17.2, 1.2, 0), (-21.6, 3.1, 0), (-29.0, 3.5, -0.7), (-31.9, 2.5, 0), (-35.0, 3.6, 0)))):
        for x, length, lean in row:
            y = 11.3 if x > -20 else (10.3 if x > -27.5 else (8.4 if x > -33.5 else 6.1))
            head.tooth(x, side * y, lip_bottom(x) - DROP + 0.15, 1.3, length, "tooth", mirror=False, lean=(lean, 0.0), long=2.0)
    for y, length, lean in ((-4.6, 3.7, 0), (-2.3, 2.2, 0), (2.3, 3.3, 0.5), (4.6, 2.6, 0)):  # across the front: one is gone
        head.tooth(-37.0, y, lip_bottom(-37.0) - DROP + 0.15, 1.9, length, "tooth", mirror=False, lean=(0.0, lean), long=1.2)

    # the lower jaw, on its own joint at the hinge and hanging wide open: three tilted blocks in a chain, each wider and
    # longer than the upper jaw over it, so it juts out in front and at the sides. A gum line inside its edge, the
    # mouth's floor inside that, and its own uneven row of teeth
    jaw = m.part("Jaw", (-10, 0, -5.9), "Head")
    lower = ((-8.0, -23.0, -5.5, -8.6, 26.4, 5.0, -12.4), (-21.5, -33.0, -8.4, -10.6, 22.6, 4.4, -23.3), (-31.5, -42.0, -10.4, -12.2, 16.6, 3.8, -33.3))
    jmid = line(lower)

    def jaw_top(x):
        k = 0 if x > -22.5 else (1 if x > -32.5 else 2)
        return jmid(k, x) + lower[k][5] / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(lower):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "bone", flat="z")
        up = thick / 2 + DROP / 2 - 0.025
        jaw.beam((gum_from, 0, jmid(k, gum_from) + up), (x1 + 0.35, 0, jmid(k, x1 + 0.35) + up), wide - 1.0, DROP + 0.05, "gum", flat="z")
    # the mouth's floor: a dark red plate on each block that leaves the gum a thin line round it; the teeth stand on its edge
    for k, (x0, x1) in enumerate(((-12.6, -22.5), (-23.5, -32.5), (-33.5, -40.9))):
        up = lower[k][5] / 2 + 0.35
        jaw.beam((x0, 0, jmid(k, x0) + up), (x1, 0, jmid(k, x1) + up), lower[k][4] - 2.6, 0.5, "mouth", flat="z")
    for side, row in ((1, ((-15.5, 1.2, 0), (-18.8, 1.8, 0), (-24.6, 2.5, 0), (-27.8, 3.5, 0), (-34.6, 3.9, 0), (-37.4, 2.8, 0.6),
                           (-40.0, 4.3, 0))),
                      (-1, ((-15.5, 1.4, 0), (-18.8, 1.4, 0), (-24.6, 3.1, 0), (-27.8, 2.0, 0), (-30.6, 3.3, 0), (-34.6, 2.6, 0),
                            (-40.0, 3.1, 0)))):
        for x, length, lean in row:
            y = 12.0 if x > -22.5 else (10.1 if x > -32.5 else 7.1)
            jaw.tooth(x, side * y, jaw_top(x) + DROP - 0.45, 1.3, -length, "tooth", mirror=False, lean=(lean, 0.0), long=2.0)
    for y, length, lean in ((-5.0, 3.4, 0), (-2.5, 4.6, 0), (0.0, 3.0, 0), (2.5, 4.1, 0.5), (5.0, 2.6, 0)):
        jaw.tooth(-41.0, y, jaw_top(-41.0) + DROP - 0.4, 1.9, -length, "tooth", mirror=False, lean=(0.0, lean), long=1.2)

    # the body
    segs, before = {}, None
    for i, (name, slices) in enumerate(BODY):
        seg = segs[name] = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else BODY[i - 1][0])
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top = slices[0]
        if before is None:
            seg.sym(x0 - 1, x0, 8, -7, 7, "moss-")
        else:
            _, _, fn, fbot, ftop = before
            clear = max(len(steps(n)), len(steps(fn)))
            seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "moss-")
        before = slices[-1]
    s1, s2, s3, s4, s5 = (segs[name] for name, _ in BODY)

    for x in (-5, -3, -1):  # gill slits: quiet darker lines in the side, behind the head
        s1.dent(x, x + 1, 10, -3, 4, "moss-")
    # the seat: a saddle of back seven cubes wide between two slots for the rider's legs
    s1.carve_pair(-4, 0, 4, 7, 8, 11)
    s1.paint_pair(-4, 0, 4, 7, 7, 8, "moss-")
    # the one mark: three claw scars raked along the left flank: thin pale lines of unequal length that sink to the rear,
    # each length starting on the last cube of the one before, so a line is unbroken
    flank = ((s1, -6), (s2, 3))
    for z0, cuts in ((6, (1, 5, 9, 13)), (3, (0, 4, 9, 14)), (0, (3, 7, 11))):
        for k, (x0, x1) in enumerate(zip(cuts, cuts[1:])):
            scar(flank, x0, x1 + (k < len(cuts) - 2), z0 - k)

    # the back fin: low and thick. A body of cubes in two blocks behind one sloping front block, and its trailing edge
    # torn: a bite left out of the middle of it and a nick under its top corner
    fill(s2, 7, 15, 1, 7, 12, "fin")
    fill(s2, 10, 15, 1, 12, 16, "fin")
    s2.carve(13, 15, -1, 2, 10, 12)
    s2.carve(14, 15, -1, 2, 14, 15)
    s2.beam((4.0, 0, 9.0), (10.3, 0, 15.5), 4.6, 3.6, "fin")
    # the side fins: heavy, two broad thick boxes swept back and a little down, from low on the flank
    s1.beam((-1.5, 7.0, -5.5), (5.5, 17.0, -8.0), 11.0, 3.0, "fin", flat="z", mirror=True)
    s1.beam((4.2, 15.2, -7.6), (9.6, 22.4, -9.6), 7.6, 1.9, "fin-", flat="z", mirror=True)
    s3.beam((16.5, 3.0, -2.5), (20.0, 6.5, -5.6), 3.2, 1.0, "bone-", flat="z", mirror=True)  # the belly fins
    s4.beam((24.0, 0, 3.6), (26.8, 0, 6.9), 2.6, 1.2, "fin")  # the second back fin: small

    # the tail, on its own joint, small for the animal: a short stock, then two rays (sloping blocks) with a web of
    # cubes between and behind them. The web's trailing edge is torn: cubes left out of both lobes
    tail = m.part("Tail", (END, 0, 0.5), "S5")
    tail.sym(END, END + 3, 2, -2, 3, "moss")
    tail.paint_sym(END, END + 3, 2, -2, 0, "bone")
    tail.paint_sym(END, END + 3, 2, -2, -1, "bone-")
    tail.sym(END - 1, END, 1, -1, 2, "moss-")  # its sleeve
    for k, i0, i1 in ((9, 40, 42), (8, 39, 42), (7, 39, 42), (6, 38, 41), (5, 37, 39), (4, 37, 39), (3, 36, 41), (2, 36, 40),
                      (1, 36, 39), (0, 36, 38), (-1, 36, 39), (-2, 36, 40), (-3, 36, 38), (-4, 37, 40), (-5, 38, 40), (-6, 39, 40)):
        fill(tail, i0, i1, 0, k, k + 1, "fin")
    tail.beam((35.0, 0, 1.5), (40.5, 0, 9.8), 2.6, 1.6, "fin")
    tail.beam((35.0, 0, 0.0), (39.6, 0, -6.2), 2.4, 1.6, "fin")
