"""Halfbone Megalodon (zone 9's Mythic: the Megalodon of art/creatures/Megalodon, half of it eaten away) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed as a Mythic by docs/style/05-rarity-look.md.
Its idea: the front half is still a shark, the back half is only its bones, and it swims on anyway.
Three ways to be Mythic: material (bone), void (you see through the back half) and light (the cold glow that drives it).
- The front is the Megalodon as it was: the blunt head that is mostly mouth, the gills, the huge side fins, the seat.
- Just behind the seat the flesh stops in a ragged edge of big bites: the upper flank gone on both sides (deeper on the
  left), a tongue of skin left lying on the first vertebra, a flap of belly skin either side, a notch in the belly.
  Dark meat shows inside the skin.
- From there it is a chunky spine: seven block vertebrae, each a step smaller or lower than the last, so the back still
  falls to the tail in one line. Between every two vertebrae a thin disc of cold teal light: the line that runs to the tail.
- Five pairs of broad ribs, each three blocks in a chain, swept back, smaller toward the tail: the belly's old outline.
  Inside them, under the spine where the heart was, a lump of the same teal light.
- The back fin is three bony rays, tall to short; the tail is a bone plate with the crescent's two lobes as bare struts
  and two short rays in the fork. Every bone starts inside another.
- The eye: a dark pupil in a thin ring of the same teal, under the scowling brow.
Fixed from the base: the rider's legs have two troughs either side of the middle of the back; the lower jaw has a keel.
The rider sits behind the gills, in front of the torn edge."""
import math

NAME, ZONE, RARITY = "Halfbone Megalodon", "ZONE 9 / BONE GRAVEYARD", "MYTHIC"
U = 0.5
PALETTE = {"back": "#343F4D", "white": "#ECE8DC", "black": "#14171B", "mouth": "#6A2630", "tooth": "#FFFFFF", "gum": "#7E3A44",
           "bone": "#CDC3A4", "teal": "#3FE6D2", "soft": "#3FE6D2"}
SEAT = (-12, 11, 1.5)  # the rider sits on the middle of the back, legs in the troughs either side
GLOW = {"teal": 0.9, "soft": 0.5}  # teal: the discs between the vertebrae and the lump inside the ribs; soft: the eye's ring
LIGHTS = [("B2", (3.0, 0, -5.5), "#3FE6D2", 150, 0.8)]  # the lump's light on the inside of the ribs
FRAME, ORTHO, ORTHO_SWIM = 3.7, 50.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"], "parts": ["Head", "S1", "S2"]}]  # studs on the flesh's back only
EDGE = -1  # the height of the edge between the dark back and the pale belly
DROP = 0.25  # how far a gum plate shows past its lip
LIP = 1.2  # the thickness of the pale lip plate under the snout

# the flesh in slices (from, to, cubes out, bottom, top). One number changes from slice to slice, never two
SKULL = ((-31, -29, 9, -9, 9), (-29, -27, 9, -9, 10))  # short: the head is mostly snout and jaw
FLESH = (("S1", ((-27, -23, 10, -9, 10), (-23, -19, 10, -10, 10), (-19, -14, 10, -10, 11))),  # the gills
         ("S2", ((-14, -10, 10, -11, 11), (-10, -5, 10, -11, 12))))  # the seat, then the shoulder's hump and the torn edge
TORN = -5  # where the flesh ends
# the spine: (part, from, cubes out, bottom, top), each vertebra LONG cubes long with one cube of light before the next.
# One thing changes from one to the next: it sinks a cube, or loses a cube of height, or of width
LONG = 4
SPINE = (("B1", -5, 3, 4, 10), ("B2", 0, 3, 4, 10), ("B2", 5, 3, 3, 9), ("B3", 10, 3, 3, 8), ("B3", 15, 2, 3, 8), ("B4", 20, 2, 2, 7),
         ("B4", 25, 2, 1, 6))
HUB = (30, 36, 2, -2, 4)  # the tail's bone plate
RIBS = ((1, 1.33), (2, 1.2), (3, 1.02), (4, 0.8), (5, 0.58))  # which vertebra carries a pair of ribs, and its size
CHAIN = ["Head", "S1", "S2", "B1", "B2", "B3", "B4", "Tail"]
AMPLITUDES = [1, 2, 3.5, 5.5, 8, 11, 16]


def pose(parts, phase):
    """a shark's swim, heavy: a slow wave side to side that grows toward the tail, the head turning a little against it.
    The jaw hangs open at rest and bites up a little once a beat"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.75 * (k + 1))
    parts["Jaw"].rotation_euler.y = math.radians(5) * (0.5 + 0.5 * math.sin(phase))


def steps(n):
    """the corners of the back and the belly: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 9 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, dark with a lighter top row, pale below the edge with a darker bottom row"""
    p.hull(x0, x1, n, bot, top, "back", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "back+")
    p.paint_sym(x0, x1, n, bot, EDGE, "white")
    p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


def meat(p, x0, x1, n, bot, top):
    """the inside of a slice of body, behind its skin one cube thick, painted as dark meat: what a bite shows"""
    for z in range(bot + 1, top - 1):
        inset = 0
        for k, (i, _) in enumerate(steps(n)):
            if z in (top - 1 - k, bot + k):
                inset = i
        p.paint_sym(x0, x1, n - inset - 1, z, z + 1, "mouth")


def lerp(a, b, f):
    return tuple(u + (v - u) * f for u, v in zip(a, b))


def rib(p, xc, zc, s):
    """a pair of broad ribs from the side of a vertebra: three blocks in a chain, out, then down, then in under the
    belly, each smaller and thinner than the last and starting inside it, all swept back a little"""
    k = 0.6 + 0.4 * s
    wide, thick = 3.0 * k, 1.4 * k

    def at(dx, dy, dz):
        return (xc + dx * s, 1.2 + dy * s, zc + 0.3 + dz * s)

    p0, p1, q1, r1 = at(0, 0, 0), at(0.6, 6.8, -2.9), at(1.4, 6.3, -11.0), at(2.0, 3.4, -13.6)
    q0 = lerp(p0, p1, 0.85)
    r0 = lerp(q0, q1, 0.88)
    p.beam(p0, p1, wide, thick, "bone", flat="z", mirror=True)
    p.beam(q0, q1, wide - 0.5, thick - 0.35, "bone", flat="y", mirror=True)
    p.beam(r0, r1, wide - 0.9, thick - 0.65, "bone-", flat="y", mirror=True)


def knob(p, xc, top, rise, wide, thick):
    """the spine on top of a vertebra: one short block leaning back, its foot inside the bone"""
    p.beam((xc - 0.2, 0, top - 0.8), (xc - 0.2 + 0.45 * (rise + 0.8), 0, top + rise), wide, thick, "bone")


def build(m):
    head = m.part("Head", (SKULL[-1][1], 0, 0))
    for s in SKULL:  # the back of the head: the eye sits on its side
        slab(head, *s)
    head.sym(-31, -29, 8, -9, -7, "white")  # the jaw's hinge: the bottom rows are wider here, so the jaw's root is buried
    head.paint_sym(-31, -29, 8, -9, -8, "white-")
    # the snout, a blunt cone as long as the mouth: three low, wide blocks in a chain, each tilted nose-down and narrower
    # than the last, with a pale lip plate underneath; the underside rises a little to the tip. (from, to, the middle's
    # height at each end, width, thickness, where its gum starts)
    blocks = ((-30.5, -37.2, 1.6, 1.1, 17.4, 5.2, -30.5), (-36.4, -40.4, 1.2, 0.8, 13.6, 4.2, -37.5), (-39.6, -41.8, 1.45, 1.27, 9.4, 3.9, 0.0))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        """the underside of block k's lip plate at x"""
        return middle(k, x) - blocks[k][5] / 2 - LIP

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "back", flat="z")
        lip = thick / 2 + LIP / 2
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, LIP, "white", flat="z")
        if gum_from:  # a thin gum plate under the lip, set in from its edge, that the teeth hang from
            mid = 0.025 - DROP / 2
            head.beam((gum_from, 0, lip_bottom(k, gum_from) + mid), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) + mid), wide - 1.0, DROP + 0.05,
                      "gum", flat="z")
    # the forehead: two narrower, lighter blocks lying on the first two, each starting inside the one behind, so the
    # snout's section steps in like the body's corners and its top comes down to the nose in three steps
    for k, x0, x1, wide, thick in ((0, -30.5, -36.6, 12.4, 4.2), (1, -35.8, -39.8, 8.6, 2.8)):
        rise = blocks[k][5] / 2 + thick / 2 - 0.05
        head.beam((x0, 0, middle(k, x0) + rise), (x1, 0, middle(k, x1) + rise), wide, thick, "back+", flat="z")
    nostril = (4.4, 4.95, 0.3, 1.2)
    head.block(-41.4, nostril, -40.5, nostril, "black", mirror=True)
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    mouth = (-5.4, 5.4, -8.2, -1.8)
    head.block(-37.0, mouth, -30.0, mouth, "mouth")
    mouth = (-3.9, 3.9, -8.6, -1.7)
    head.block(-38.8, mouth, -36.9, mouth, "mouth")
    # the upper teeth, big triangles with their bases sunk a little into the gum: blades down each side, a row across the front
    for k, x in ((0, -31.7), (0, -33.2), (0, -34.7), (0, -36.15), (1, -38.3)):
        head.tooth(x, (7.7, 5.8)[k], lip_bottom(k, x) - DROP + 0.1, 1.0, 2.2, "tooth", long=1.4)
    front = lip_bottom(1, -39.6) - DROP + 0.1
    head.tooth(-39.6, 0.0, front, 1.35, 2.3, "tooth", mirror=False, long=0.9)
    for y in (1.45, 2.9, 4.35):
        head.tooth(-39.6, y, front, 1.35, 2.2, "tooth", long=0.9)
    # the eye: small, on the side of the head over the corner of the mouth. A dark socket, a thin ring of the cold teal
    # light, a dark pupil standing out of it. The brow box slants down to the front, cuts across the top of the eye and
    # comes past it in front and behind, so the shark scowls; a slimmer block carries its line on along the snout
    socket = (9.38, 9.97, 2.6, 5.4)
    head.block(-30.6, socket, -27.8, socket, "back-", mirror=True)
    halo = (9.85, 10.15, 3.0, 5.0)
    head.block(-30.25, halo, -28.15, halo, "soft", mirror=True)
    pupil = (9.97, 10.35, 3.4, 4.6)
    head.block(-29.9, pupil, -28.5, pupil, "black", mirror=True)
    head.beam((-32.4, 9.85, 4.5), (-27.6, 9.85, 5.75), 1.7, 2.2, "back", mirror=True)
    head.beam((-35.0, 9.3, 3.74), (-30.6, 9.3, 4.89), 1.2, 1.7, "back", mirror=True)

    # the lower jaw, on its own joint, hanging open: two deep boxes, the smaller in front, ending short of the nose,
    # with a keel under them, a gum line inside their edge and a row of teeth that stands a little inside the upper row
    jaw = m.part("Jaw", (-29.5, 0, -6.6), "Head")
    jaws = ((-29.6, -37.4, -6.59, -9.4, 15.4, 3.0, -31.3), (-36.6, -40.1, -9.05, -9.2, 11.6, 2.2, -37.7))

    def jaw_mid(k, x):
        x0, x1, z0, z1 = jaws[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def jaw_top(k, x):
        return jaw_mid(k, x) + jaws[k][5] / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "white", flat="z")
        mid = DROP / 2 - 0.025  # the lower gum lies inside the jaw's own edge all round
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + mid), (x1 + 0.35, 0, jaw_top(k, x1 + 0.35) + mid), wide - 1.0, DROP + 0.05, "gum",
                 flat="z")
    # the keel: a deep chin block under the jaw, narrower than it, so the jaw's section steps in like the body's corners
    # and it is not a flat tray
    under = jaws[0][5] / 2 + 0.75
    jaw.beam((-31.0, 0, jaw_mid(0, -31.0) - under), (-35.8, 0, jaw_mid(0, -35.8) - under), 10.6, 1.6, "white-", flat="z")
    for x in (-32.45, -33.95, -35.45):  # sunk deeper than the others: the jaw slopes, and the whole base must lie in it
        jaw.tooth(x, 6.7, jaw_top(0, x) + DROP - 0.45, 1.0, -2.05, "tooth", long=1.4)
    jaw.tooth(-38.3, 4.8, jaw_top(1, -38.3) + DROP - 0.1, 1.0, -1.6, "tooth", long=1.4)
    front = jaw_top(1, -39.35) + DROP - 0.1
    jaw.tooth(-39.35, 0.0, front, 1.15, -1.7, "tooth", mirror=False, long=0.8)
    for y in (1.25, 2.5, 3.75):
        jaw.tooth(-39.35, y, front, 1.15, -1.6, "tooth", long=0.8)

    # the flesh that is left: the gills and the seat
    segs, before = {}, SKULL[-1]
    for i, (name, slices) in enumerate(FLESH):
        seg = segs[name] = m.part(name, (slices[0][0], 0, 0), "Head" if i == 0 else FLESH[i - 1][0])
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top = slices[0]
        _, _, fn, fbot, ftop = before
        clear = max(len(steps(n)), len(steps(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "back-")
        before = slices[-1]
    s1, s2 = segs["S1"], segs["S2"]

    for x in (-26, -24, -22, -20, -18):  # five long gill slits: shallow lines in the side, across the edge
        s1.dent(x, x + 1, 10, -3, 3, "back-")
    # the side fins: huge, swept back and a little down, from low on the flank under the last gill slits. Each is three
    # boxes, every box smaller and thinner than the one before and starting inside it
    s1.beam((-19.5, 6.5, -4.2), (-12.5, 16.8, -6.2), 9.0, 2.2, "back", flat="z", mirror=True)
    s1.beam((-13.8, 15.2, -5.9), (-9.0, 22.0, -7.2), 6.6, 1.5, "back", flat="z", mirror=True)
    s1.beam((-10.0, 20.6, -6.95), (-6.6, 25.6, -7.9), 4.4, 0.9, "back-", flat="z", mirror=True)

    # the torn edge. Inside the skin the last slice is dark meat, so every bite shows it
    meat(s2, *FLESH[-1][1][-1])
    # the seat: the back is far too wide to straddle, so the rider sits on its middle with a trough either side for the legs
    s2.carve_pair(-14, -10, 2, 5, 9, 11)
    s2.paint_pair(-14, -10, 2, 5, 8, 9, "back-")
    s2.paint_pair(-10, -9, 2, 5, 9, 11, "back")  # the troughs' rear walls are skin, not the meat behind them
    # big bites, none like another: the upper flank gone on both sides (deeper on the left), right through the back, so
    # the flesh narrows to the spine seen from above; a notch in the belly
    s2.carve(TORN - 4, TORN, 6, 11, 2, 12)
    s2.carve(TORN - 5, TORN, -10, -5, 2, 12)
    s2.carve(TORN - 3, TORN, -3, 4, -11, -8)
    # what hangs on past the edge: a tongue of skin lying on the first vertebra, longer on one side, and a flap of belly
    # skin either side with meat on its inside
    s2.box(TORN, TORN + 4, -3, 1, 10, 11, "back")
    s2.box(TORN, TORN + 4, -3, 1, 11, 12, "back+")
    s2.box(TORN, TORN + 2, 1, 4, 10, 11, "back")
    s2.box(TORN, TORN + 2, 1, 4, 11, 12, "back+")
    for x1, j, inner in ((TORN + 4, 10, 9), (TORN + 3, -10, -9)):
        s2.box(TORN, x1, j, j + 1, -8, -1, "white")
        s2.box(TORN, x1, inner, inner + 1, -8, -1, "mouth")

    # the spine: block vertebrae with cut corners. Each part carries the disc of light in front of each of its vertebrae;
    # the first disc of a part goes on a cube into the vertebra in front (its sleeve), so a bending joint stays closed
    bones = {}
    for i, (name, x0, n, bot, top) in enumerate(SPINE):
        if name not in bones:
            parent = "S2" if i == 0 else SPINE[i - 1][0]
            bones[name] = m.part(name, (x0 if i == 0 else x0 - 1, 0, (bot + top) / 2), parent)
        p = bones[name]
        p.hull(x0, x0 + LONG, n, bot, top, "bone", [(1, 1)], [(1, 1)])
        p.paint_sym(x0, x0 + LONG, n, top - 1, top, "bone+")
        p.paint_sym(x0, x0 + LONG, n, bot, bot + 1, "bone-")
        if i == 0:
            p.sym(x0 - 1, x0, n - 1, bot + 1, top - 1, "bone-")  # into the meat
            continue
        _, _, fn, fbot, ftop = SPINE[i - 1]
        ln, lbot, ltop = min(n, fn) - 1, max(bot, fbot) + 1, min(top, ftop) - 1
        p.sym(x0 - 1, x0, ln, lbot, ltop, "teal")
        if SPINE[i - 1][0] != name:
            p.sym(x0 - 2, x0 - 1, ln, lbot, ltop, "bone-")
    b1, b2, b3, b4 = (bones[f"B{i}"] for i in range(1, 5))

    # the lump of light where the heart was: under the spine, inside the first ribs, in two steps
    b2.hull(0, 5, 3, -3, 4, "teal", [(1, 1)], [(1, 1)])
    b2.hull(5, 8, 2, -2, 3, "teal", [(1, 1)], [(1, 1)])

    for i, s in RIBS:
        name, x0, _, bot, top = SPINE[i]
        rib(bones[name], x0 + LONG / 2, (bot + top) / 2, s)

    # the back fin's bones: three rays, tall to short, one to a vertebra; the first two are two blocks each, swept back
    # more toward the tip
    b2.beam((1.5, 0, 8.5), (4.7, 0, 18.0), 2.8, 1.6, "bone")
    b2.beam((4.3, 0, 16.8), (8.0, 0, 24.0), 1.9, 1.0, "bone-")
    b2.beam((6.5, 0, 7.5), (9.0, 0, 15.5), 2.1, 1.2, "bone")
    b2.beam((8.6, 0, 14.3), (10.5, 0, 19.0), 1.3, 0.7, "bone-")
    b3.beam((11.5, 0, 6.5), (13.4, 0, 12.2), 1.7, 0.9, "bone")
    # a short spine on each vertebra behind them, smaller toward the tail: the back's line
    knob(b3, 17, 8, 2.4, 1.8, 1.2)
    knob(b4, 22, 7, 2.0, 1.7, 1.2)
    knob(b4, 27, 6, 1.6, 1.5, 1.0)

    # the tail, on its own joint: a bone plate, the crescent's two lobes as bare struts of three blocks each that sweep
    # back more toward the tip, and two short rays in the fork between them. Every root lies inside the plate
    x0, x1, n, bot, top = HUB
    _, _, fn, fbot, ftop = SPINE[-1]
    tail = m.part("Tail", (x0 - 1, 0, 0.5), SPINE[-1][0])
    tail.hull(x0, x1, n, bot, top, "bone", [(1, 1)], [(1, 1)])
    tail.paint_sym(x0, x1, n, top - 1, top, "bone+")
    tail.paint_sym(x0, x1, n, bot, bot + 1, "bone-")
    ln, lbot, ltop = min(n, fn) - 1, max(bot, fbot) + 1, min(top, ftop) - 1
    tail.sym(x0 - 1, x0, ln, lbot, ltop, "teal")
    tail.sym(x0 - 2, x0 - 1, ln, lbot, ltop, "bone-")
    tail.beam((33.8, 0, 1.0), (36.6, 0, 8.1), 3.2, 2.2, "bone")
    tail.beam((36.0, 0, 6.8), (39.0, 0, 12.6), 2.4, 1.5, "bone")
    tail.beam((38.4, 0, 11.5), (40.5, 0, 15.9), 1.6, 0.8, "bone-")
    tail.beam((33.8, 0, 0.0), (36.2, 0, -6.1), 3.0, 1.9, "bone")
    tail.beam((35.7, 0, -5.0), (38.2, 0, -9.8), 2.2, 1.2, "bone")
    tail.beam((37.6, 0, -8.9), (39.8, 0, -12.4), 1.5, 0.6, "bone-")
    tail.beam((35.0, 0, 1.6), (39.0, 0, 6.0), 1.3, 1.0, "bone-")
    tail.beam((35.0, 0, -0.6), (38.4, 0, -4.2), 1.2, 0.8, "bone-")
