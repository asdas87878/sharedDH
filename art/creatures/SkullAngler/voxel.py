"""Skull Angler (zone 9's Legendary: the Anglerfish of the Bone Graveyard) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. A variant of
art/creatures/Anglerfish/voxel.py: the same animal and the same build (a ball of mouth that carries its own lamp, an
underbite of needle teeth, a rod in joints, weak fins far back, a short fan of a tail), but bigger and from finer cubes,
so every curve has more and gentler steps.
Its idea: the face has rotted down to the bone and the lamp is a little skull. One light, and its echo deep in the socket.
- The front of the head is a bare ivory skull: two snout slabs and the cranium, with a brow ridge over a deep socket
  (two cubes deep, a small teal spark in it) and a nose hole either side of the septum.
- The flesh starts behind the eye with a darker lip one step out from the bone, and is dark grey-green over a duller
  belly; one thin dull-teal line runs along it from the lip to the tail.
- The jaw is bone too, on its own joint: a scoop in three slabs, an underbite. Long bone fangs hang from the snout and
  stand on the jaw; a thin dark gum line lies inside the edge of both.
- The flank is torn open: a shallow dark recess with two ribs standing across it.
- The lure is a bony stalk in two pieces with a knuckle at each joint, and a little glowing skull hanging from it.
- One flat ridge, seven cubes wide, runs down the whole back; it is tallest on the ball, and the rider sits astride it.
The fins and the tail are the Anglerfish's, a size up."""
import math

NAME, ZONE, RARITY = "Skull Angler", "ZONE 9 / BONE GRAVEYARD", "LEGENDARY"
U = 0.45
PALETTE = {"bone": "#EAE2CA", "flesh": "#3E4D45", "belly": "#6C7865", "seam": "#5A8F84", "tooth": "#F8F3E2", "mouth": "#2A1218",
           "gum": "#70323F", "wound": "#3B1F27", "socket": "#1B1E24", "black": "#121416", "lure": "#5CF2DA", "spark": "#5CF2DA"}
SEAT = (-7.5, 13, 3.5)
GLOW = {"lure": 0.9, "spark": 0.5}  # the little skull of the lure, and its echo: the spark deep in each socket
LIGHTS = [("Lure", (-27.2, 0, 11.8), "#5CF2DA", 45, 0.5)]
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["flesh"]}]  # studs on the flesh only: the bone stays bare
FRAME, ORTHO = 2.6, 34.0

# the corner steps of a slab, by how far out it reaches: (cubes in from the side, cubes tall), from the top down and from
# the bottom up. The top row is seven cubes wide on every slab: one flat ridge down the whole back
TOPS = {10: [(7, 3), (4, 1), (2, 2), (1, 2)], 9: [(6, 2), (3, 1), (1, 2)], 8: [(5, 1), (3, 1), (1, 2)], 7: [(4, 1), (2, 1), (1, 1)],
        6: [(3, 1), (1, 1)], 4: [(1, 1)]}
BOTS = {10: [(5, 1), (3, 1), (1, 2)], 9: [(4, 1), (2, 1), (1, 2)], 8: [(3, 1), (2, 1), (1, 1)], 7: [(3, 1), (1, 1)],
        6: [(2, 1), (1, 1)], 5: [(2, 1), (1, 1)], 4: [(1, 1)]}
EDGE = -4  # the belly's colour stops at this height the whole way along; the thin teal line lies on it
CZ = 0.5  # the height of the body's middle line (the back is one cube taller than the belly is deep)


def pose(parts, phase):
    """the Anglerfish's slow waddle: the ball rolls and yaws a little and the back end swings wide behind it; the fins
    flutter twice a beat; the jaw gulps once a beat; the lure sways late, each joint later than the one before"""
    s = math.sin
    parts["Body"].rotation_euler.x = math.radians(3) * s(phase)
    parts["Body"].rotation_euler.z = math.radians(3) * s(phase + math.pi)
    for name, amp, lag in (("B2", 4, 0.5), ("B3", 6, 0.9), ("B4", 8, 1.3), ("B5", 10, 1.7), ("Tail", 16, 2.2)):
        parts[name].rotation_euler.z = math.radians(amp) * s(phase - lag)
    parts["Jaw"].rotation_euler.y = -math.radians(8) * (0.5 + 0.5 * s(phase - 0.6))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(14) * s(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(8) * s(2 * phase - 1.0)
    parts["Rod1"].rotation_euler.x = math.radians(6) * s(phase - 1.2)
    parts["Rod1"].rotation_euler.y = math.radians(4) * s(phase - 1.0)
    parts["Rod2"].rotation_euler.x = math.radians(8) * s(phase - 2.0)
    parts["Rod2"].rotation_euler.y = math.radians(5) * s(phase - 1.8)
    parts["Lure"].rotation_euler.x = math.radians(15) * s(phase - 2.9)
    parts["Lure"].rotation_euler.y = math.radians(9) * s(phase - 2.6)


def slab(p, x0, x1, n, bot, top):
    """a slice of the fleshy ball: stepped corners, lighter on the top row, the duller belly below the line, and the
    thin teal line on it"""
    under = BOTS[n]
    p.hull(x0, x1, n, bot, top, "flesh", TOPS[n], under)
    p.paint_sym(x0, x1, n, top - 1, top, "flesh+")
    p.paint_sym(x0, x1, n, EDGE, EDGE + 1, "seam")
    p.paint_sym(x0, x1, n, bot, EDGE, "belly")
    p.paint_sym(x0, x1, n, bot, bot + len(under) - 1, "belly-")


def bone(p, x0, x1, n, bot, top, flat=False):
    """a slab of the skull: bare bone, lighter on the top row; flat: a flat underside (the roof of the mouth)"""
    under = [] if flat else BOTS[n]
    p.hull(x0, x1, n, bot, top, "bone", TOPS[n], under)
    p.paint_sym(x0, x1, n, top - 1, top, "bone+")
    if under:
        p.paint_sym(x0, x1, n, bot, bot + len(under) - 1, "bone-")


def needle(p, end, d, length, colour):
    """a pale needle on the end of a fin ray: a spike whose base sits inside the ray's end (end: the ray's end in the side
    view, d: its direction there)"""
    (ex, ez), (dx, dz) = end, d
    cx, cz, px, pz = ex - 0.8 * dx, ez - 0.8 * dz, -0.7 * dz, 0.7 * dx
    base = [(cx - px, -0.45, cz - pz), (cx + px, -0.45, cz + pz), (cx + px, 0.45, cz + pz), (cx - px, 0.45, cz - pz)]
    p.spike(base, (ex + length * dx, 0.0, ez + length * dz), colour)


def build(m):
    body = m.part("Body", (-5, 0, 0))
    # the skull: two snout slabs that overhang the mouth, each a step lower and narrower, then the cranium, which is the
    # front of the ball. All bare bone
    bone(body, -25, -22, 6, 2, 7, flat=True)
    bone(body, -22, -18, 7, 1, 9, flat=True)
    bone(body, -18, -13, 8, -10, 11)
    # the flesh: a darker lip one step out from the bone, then the ball itself, with the tall ridge the rider sits astride
    slab(body, -13, -11, 9, -11, 12)
    body.paint_sym(-13, -12, 9, -11, 12, "flesh-")
    slab(body, -11, -4, 10, -12, 13)
    # the deep socket: two cubes into the side of the cranium, dark at the back, a small teal spark in it
    body.carve_pair(-17, -14, 7, 9, 2, 6)
    body.paint_pair(-17, -14, 6, 7, 2, 6, "socket")
    spark = (6.4, 7.2, 3.4, 4.6)
    body.block(-16.1, spark, -14.9, spark, "spark", mirror=True)
    # the brow ridge: a bone box on the socket, slanting down to the front and coming past it: it cuts the top of the
    # socket's square, so the skull scowls
    body.beam((-18.5, 7.75, 5.4), (-13.5, 7.75, 6.9), 1.5, 2.9, "bone", mirror=True)
    # the nose: a hole either side of the septum, in the front of the snout
    body.carve_pair(-25, -24, 1, 3, 4, 6)
    body.paint(-24, -23, -2, 3, 4, 6, "socket")
    # the back of the mouth, seen past the teeth
    body.paint(-18, -17, -7, 8, -4, 1, "mouth")
    # the dark inside of the mouth: two blocks, narrower than the gums, ending inside the snout, the jaw and the cranium
    inside = (-5.6, 5.6, -4.6, 1.6)
    body.block(-22.2, inside, -17.6, inside, "mouth")
    inside = (-4.6, 4.6, -3.6, 2.6)
    body.block(-23.8, inside, -21.8, inside, "mouth")
    # the upper gum: a thin dark plate under each snout slab, set in from its edge, that the fangs hang from
    gum = (-7.0, 7.0, 0.75, 1.2)
    body.block(-21.6, gum, -18.0, gum, "gum")
    gum = (-6.0, 6.0, 1.75, 2.2)
    body.block(-24.5, gum, -21.9, gum, "gum")
    # the upper fangs: long bone needles leaning inward. A row across the front, then down each side
    for y, long in ((0.0, 3.0), (1.7, 3.7), (3.4, 3.2)):
        body.tooth(-24.1, y, 1.87, 0.8, long, "tooth", mirror=y > 0, lean=(0.4, -0.1 * y))
    for x, y, z, long in ((-24.0, 5.2, 1.87, 2.8), (-22.6, 5.4, 1.87, 3.5), (-20.4, 6.4, 0.87, 3.3), (-18.9, 6.4, 0.87, 2.5)):
        body.tooth(x, y, z, 0.9, long, "tooth", lean=(0.2, -0.6))
    # where the stalk of the lure grows from the forehead: a low bone collar
    ring = (-1.3, 1.3, 10.6, 11.5)
    body.block(-17.2, ring, -14.8, ring, "bone-")
    # the torn flank: a shallow dark recess with two ribs standing across it, each in two pieces: it bends back as it
    # goes down
    body.dent(-10, -5, 10, -6, 4, "wound")
    for x in (-9.4, -7.0):
        body.beam((x, 10.45, 4.8), (x + 0.5, 10.45, -1.5), 1.2, 0.9, "bone", mirror=True)
        body.beam((x + 0.4, 10.4, -0.9), (x + 2.0, 10.4, -7.3), 1.0, 0.7, "bone", mirror=True)
    # the seat: the rider sits astride the ridge, legs in a shallow slot either side of it
    body.dent(-9, -6, 3, 10, 12, "flesh-")

    # the jaw, on its own joint: a bone scoop in three slabs that step up and forward, past the snout
    jaw = m.part("Jaw", (-18, 0, -5), "Body")
    for x0, x1, n, bot in ((-22, -18, 7, -9), (-25, -22, 6, -8), (-28, -25, 5, -7)):
        jaw.hull(x0, x1, n, bot, bot + 5, "bone", [], BOTS[n])
        jaw.paint_sym(x0, x1, n, bot, bot + 1, "bone-")
    # the lower gum, inside the jaw's own edge all round, and the dark floor of the mouth where it shows in front
    for x0, x1, half, top in ((-21.7, -18.3, 7.0, -4), (-24.7, -22.4, 6.0, -3), (-27.5, -25.7, 5.0, -2)):
        plate = (-half, half, top - 0.2, top + 0.25)
        jaw.block(x0, plate, x1, plate, "gum")
    floor = (-3.7, 3.7, -2.3, -1.5)
    jaw.block(-26.4, floor, -25.3, floor, "mouth")
    # the lower fangs: six long ones on the chin, standing in front of the face, and shorter ones along each side, set
    # between the upper ones
    for y, long in ((0.9, 4.2), (2.6, 3.7), (4.2, 3.0)):
        jaw.tooth(-27.0, y, -1.87, 1.0, -long, "tooth", lean=(0.6, -0.12 * y))
    for x, y, z, long in ((-23.4, 5.4, -2.87, 3.3), (-21.2, 6.4, -3.87, 3.1), (-19.7, 6.4, -3.87, 2.4)):
        jaw.tooth(x, y, z, 0.9, -long, "tooth", lean=(0.2, -0.55))

    # the lure: a bony stalk from the forehead in two pieces, each on its own joint, with a knuckle at each joint; then
    # a thin line and the little glowing skull on a third, hanging in front of the face, over the mouth
    rod1 = m.part("Rod1", (-16.0, 0, 11.0), "Body")
    rod1.beam((-15.8, 0, 9.6), (-19.4, 0, 17.6), 1.6, 1.4, "bone")
    rod2 = m.part("Rod2", (-19.4, 0, 17.6), "Rod1")
    rod2.beam((-19.1, 0, 17.0), (-25.6, 0, 21.0), 1.2, 1.0, "bone")
    knuckle = (-0.95, 0.95, 16.2, 18.5)
    rod2.block(-20.4, knuckle, -18.3, knuckle, "bone-")
    lure = m.part("Lure", (-25.6, 0, 21.0), "Rod2")
    knuckle = (-0.75, 0.75, 20.3, 21.8)
    lure.block(-26.4, knuckle, -24.8, knuckle, "bone-")
    lure.beam((-25.7, 0, 20.6), (-27.2, 0, 13.4), 0.55, 0.5, "bone-")
    cap = (-0.8, 0.8, 13.2, 13.9)
    lure.block(-28.0, cap, -26.4, cap, "bone")
    cranium = (-1.4, 1.4, 10.9, 13.4)
    lure.block(-28.6, cranium, -25.8, cranium, "lure")
    chin = (-0.95, 0.95, 9.9, 11.1)
    lure.block(-28.4, chin, -26.6, chin, "lure")
    hole = (0.45, 1.25, 11.5, 12.5)  # its sockets: a dark block on the front and one on the side, either side
    lure.block(-28.8, hole, -28.4, hole, "black", mirror=True)
    hole = (1.2, 1.55, 11.55, 12.45)
    lure.block(-28.3, hole, -27.5, hole, "black", mirror=True)

    # the back of the ball: five more slabs, each one step smaller and the last three closing faster, as a ball does, in
    # four parts, so the back end swings
    b2 = m.part("B2", (-4, 0, CZ), "Body")
    slab(b2, -4, 0, 9, -11, 12)
    b2.sym(-5, -4, 6, -6, 6, "flesh-")  # a sleeve into the ball, clear of its steps
    b3 = m.part("B3", (0, 0, CZ), "B2")
    slab(b3, 0, 3, 8, -10, 11)
    b3.sym(-1, 0, 5, -5, 6, "flesh-")
    b4 = m.part("B4", (3, 0, CZ), "B3")
    slab(b4, 3, 6, 7, -8, 9)
    slab(b4, 6, 9, 6, -6, 7)
    b4.sym(2, 3, 4, -4, 5, "flesh-")
    b5 = m.part("B5", (9, 0, CZ), "B4")
    slab(b5, 9, 12, 4, -4, 5)
    b5.sym(8, 9, 3, -2, 3, "flesh-")
    # the low fins, far back: one above and one below, two small boxes each
    for up in (1, -1):
        b4.beam((7.2, 0, CZ + up * 4.4), (10.2, 0, CZ + up * 8.6), 3.8, 1.6, "flesh-")
        b4.beam((9.0, 0, CZ + up * 7.3), (11.2, 0, CZ + up * 10.2), 2.6, 1.0, "flesh")

    # the side fins: weak little paddles on their own joints, behind the widest part, swept back
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (1.2, side * 8.2, -2.8), "B3")
        fin.beam((1.0, side * 6.4, -2.7), (5.8, side * 12.2, -4.1), 4.8, 1.6, "flesh-", flat="z")
        fin.beam((4.8, side * 11.2, -3.85), (7.8, side * 14.0, -4.7), 3.4, 1.0, "flesh", flat="z")

    # the tail, on its own joint: a stalk in two boxes and a small fan: a thin web with three rays on it, each ending in a
    # pale needle that stands out past the web: the teeth's echo
    tail = m.part("Tail", (12, 0, CZ), "B5")
    tail.beam((11.3, 0, CZ), (15.6, 0, CZ), 6.6, 4.4, "flesh")
    tail.beam((14.6, 0, CZ), (19.2, 0, CZ), 5.0, 3.2, "flesh")
    tail.prism([(18.2, CZ - 2.4), (26.0, CZ - 7.8), (26.0, CZ + 7.8), (18.2, CZ + 2.4)], -0.35, 0.35, "flesh")
    for up in (1, -1):
        tail.beam((17.6, 0, CZ + up * 1.4), (26.2, 0, CZ + up * 8.2), 2.8, 1.8, "flesh-")
        needle(tail, (26.2, CZ + up * 8.2), (0.784, up * 0.62), 2.8, "tooth-")
    tail.beam((18.0, 0, CZ), (26.8, 0, CZ), 2.4, 1.4, "flesh-")
    needle(tail, (26.8, CZ), (1.0, 0.0), 2.8, "tooth-")
