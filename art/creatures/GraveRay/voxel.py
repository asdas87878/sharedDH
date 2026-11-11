"""The Grave Ray (zone 9's Legendary: a dead manta that still flies) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. A variant of the Manta Ray
(art/creatures/MantaRay/voxel.py): the same animal, the same size and seat, the same three-plate wings and their flap.
Its idea: a kite of bone. The skin has gone pale bone-grey and thin, and the skeleton shows through it as one drawing in
ivory: the backbone down the middle, three ribs a side, and each rib running on along the wing as a raised spar.
- The spars fan from the body: the first follows the leading edge to the tip, bending back at each of the wing's joints
  like an arm; the second and the third cross the wing and come out past its trailing edge as bare bone points.
- The trailing edge is ragged: between the bone points hang a few torn tabs of skin, each thinner than the wing and
  starting inside it, no two the same.
- The eyes are hollow sockets: a dark square recess under a bony brow that slants down to the front and comes past it,
  with one small teal light deep inside. Nothing else glows.
- The tail is the bare backbone: a thin cord with vertebrae on it, each smaller than the last, in three lengths on
  joints of their own. It answers the spine painted down the back.
- Darker underneath, with the five gill slits a side as dark gaps. The horns end in bone.
The rider sits on the ridge, legs in a shallow slot either side; only the flat painted spine runs under the seat."""
import math

NAME, ZONE, RARITY = "Grave Ray", "ZONE 9 / BONE GRAVEYARD", "LEGENDARY"
U = 0.4
PALETTE = {"hide": "#A3A59F", "under": "#6C6F7A", "ivory": "#F2ECD6", "socket": "#23262E", "teal": "#3FE6CF"}
SEAT = (0, 5, 2.58)
GLOW = {"teal": 0.8}  # only the small light in each socket
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
FRAME, ORTHO, ORTHO_SWIM = 2.1, 54.0, 56.0
SIDES = (("R", 1), ("L", -1))
RIBS = (-8, -5, -2)  # where the three ribs cross the body (each runs on along the wing as a spar)


def pose(parts, phase):
    """the wings flap slowly in a wave that runs from the root to the tip; the body rises and dips a little against them;
    the horns open and close; the tail trails, each length a little later than the one before"""
    for name, side in SIDES:
        parts["Wing" + name + "1"].rotation_euler.x = side * math.radians(15) * math.sin(phase)
        parts["Wing" + name + "2"].rotation_euler.x = side * math.radians(15) * math.sin(phase - 0.9)
        parts["Wing" + name + "3"].rotation_euler.x = side * math.radians(16) * math.sin(phase - 1.8)
        parts["Horn" + name].rotation_euler.z = side * math.radians(7) * math.sin(phase - 0.6)
    parts["Body"].rotation_euler.y = math.radians(1.5) * math.sin(phase - 1.2)
    parts["Tail1"].rotation_euler.y = math.radians(5) * math.sin(phase - 1.4)
    parts["Tail2"].rotation_euler.y = math.radians(8) * math.sin(phase - 2.2)
    parts["Tail3"].rotation_euler.y = math.radians(11) * math.sin(phase - 3.0)
    parts["Tail2"].rotation_euler.z = math.radians(4) * math.sin(phase - 0.4)
    parts["Tail3"].rotation_euler.z = math.radians(6) * math.sin(phase - 1.2)


def plate(part, side, inner, outer, colour):
    """a flat wing plate between two cross-sections: at y it runs from its leading edge to its trailing edge and from its
    underside to its top. Each of inner and outer is (y, leading x, trailing x, underside z, top z). side: 1 right, -1 left"""
    verts = []
    for y, lead, trail, low, high in (inner, outer):
        verts += [(lead, side * y, low), (trail, side * y, low), (trail, side * y, high), (lead, side * y, high)]
    part.solid(verts, [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], colour)


def wing_plate(part, side, inner, outer, white, inset=0.3):
    """a bone-grey wing plate with its darker underside: a thinner plate set in from the edges, its top just inside"""
    plate(part, side, inner, outer, "hide")
    (ya, la, ta, za, _), (yb, lb, tb, zb, _) = inner, outer
    plate(part, side, (ya + 0.2, la + inset, ta - inset, za - white, za + 0.05), (yb - 0.2, lb + inset, tb - inset, zb - white, zb + 0.05), "under")


def levels(inner, outer, y):
    """the underside and the top of a wing plate at y"""
    t = (y - inner[0]) / (outer[0] - inner[0])
    return inner[3] + (outer[3] - inner[3]) * t, inner[4] + (outer[4] - inner[4]) * t


def spar(part, side, inner, outer, a, b, deep=0.15):
    """a raised ivory bone line on a wing plate, 0.3 proud of its top, from a = (y, middle x, width) to b. `deep`: how far
    it reaches down into the plate (a spar that comes out past the trailing edge is deep, so its end is a solid point)"""
    ends = []
    for y, x, wide in (a, b):
        top = levels(inner, outer, y)[1]
        ends.append((y, x - wide / 2, x + wide / 2, top - deep, top + 0.3))
    plate(part, side, ends[0], ends[1], "ivory")


def tab(part, side, inner, outer, a, b, inset=0.25, colour="hide"):
    """a torn tab of skin hanging past the trailing edge (or, in ivory, the bare end of a spar): thinner than the plate
    and starting inside it. a and b are (y, leading x, trailing x)"""
    ends = []
    for y, lead, trail in (a, b):
        low, high = levels(inner, outer, y)
        ends.append((y, lead, trail, low + inset, high - inset))
    plate(part, side, ends[0], ends[1], colour)


def vertebrae(part, x0, x1, cord, bones, blades=True):
    """a length of bare backbone: vertebrae on a thin cord. cord: (height, width). bones: (middle x, length, half width,
    half height) each. The cord is in lengths that each start inside one vertebra and end inside the next (the first
    starts at x0, in the piece in front; with x1 a last one runs on to a bare tip). With blades (the biggest vertebrae, next to the body), a
    small one leans back on each"""
    stops = [x0] + [b[0] for b in bones] + ([x1] if x1 else [])
    for k, (a, b) in enumerate(zip(stops, stops[1:])):
        part.beam((a + (0.1 if k else 0.0), 0, 0), (b - (0.1 if k < len(bones) else 0.0), 0, 0), cord[0], cord[1], "ivory-")
    for x, long, hw, hz in bones:
        box = (-hw, hw, -hz, hz)
        part.block(x - long / 2, box, x + long / 2, box, "ivory")
        if blades:
            part.beam((x - 0.1, 0, hz - 0.2), (x + 0.4, 0, hz + 0.6), 0.45, 0.45, "ivory")


def build(m):
    body = m.part("Body", (0, 0, 0))
    # the body: a flat lens. A wide slab three cubes thick, a narrower step on top of it and underneath, a ridge down the
    # middle. From the shoulders back it narrows one step at a time to the root of the tail
    body.hull(-13, -10, 5, -2, 3, "hide", [(2, 1)], [(2, 1)])  # the head
    body.hull(-10, 5, 6, -2, 4, "hide", [(4, 1), (2, 1)], [(2, 1)])  # between the wings
    body.sym(-4, 3, 2, 4, 5, "hide+")  # the ridge: the highest part, where the rider sits
    body.sym(-6, -4, 1, 4, 5, "hide+")  # it narrows a step at each end, so it reads as a rise, not a box
    body.sym(3, 5, 1, 4, 5, "hide+")
    body.hull(5, 8, 5, -2, 3, "hide", [(3, 1)], [(2, 1)])
    body.hull(8, 10, 4, -2, 3, "hide", [(2, 1)], [(2, 1)])
    body.hull(10, 12, 3, -1, 2, "hide", [(1, 1)])
    body.sym(12, 14, 2, -1, 1, "hide")
    body.sym(14, 15, 1, -1, 1, "hide")
    body.paint(-13, 15, -8, 9, -2, 0, "under")  # darker below the middle line
    body.paint_sym(-13, -10, 3, 2, 3, "hide+")  # the top rows a tone lighter
    body.paint_sym(-10, 5, 2, 3, 4, "hide+")
    body.paint_sym(5, 10, 2, 2, 3, "hide+")
    body.paint_sym(10, 12, 2, 1, 2, "hide+")
    # the skeleton shows through, drawn flat in ivory: three ribs a side, from the backbone down the steps to the edge of
    # the body, where each runs on along the wing as a spar
    for x in RIBS:
        body.paint_pair(x, x + 1, 1, 3, 3, 5, "ivory")
        body.paint_pair(x, x + 1, 3, 5, 2, 3, "ivory")
        body.paint_pair(x, x + 1, 5, 7, 1, 2, "ivory")
    # the backbone: one cube row down the middle of the back, from the head to the root of the tail (flat under the rider)
    body.paint(-13, -10, 0, 1, 2, 3, "ivory")
    body.paint(-10, 12, 0, 1, 1, 5, "ivory")
    body.paint(12, 15, 0, 1, 0, 1, "ivory")
    # the belly: five gill slits a side, dark gaps
    for x in (-9, -7, -5, -3, -1):
        body.paint_pair(x, x + 1, 1, 4, -2, -1, "socket")
    # the mouth: a wide dark slot across the very front
    body.carve(-13, -12, -3, 4, -1, 1)
    mouth = (-3.5, 3.5, -1, 1)
    body.block(-12.25, mouth, -11.95, mouth, "socket")
    # the eyes: hollow sockets. A dark square recess in the side of the head with one small light deep in it, under a bony
    # brow that slants down to the front, covers the top of the socket and comes past it
    body.carve_pair(-12, -10, 5, 6, 0, 2)
    hollow = (4.45, 5.2, 0.0, 1.7)
    body.block(-12, hollow, -10, hollow, "socket", mirror=True)
    light = (5.1, 5.4, 0.4, 0.95)
    body.block(-11.3, light, -10.75, light, "teal", mirror=True)
    body.beam((-12.8, 4.7, 1.75), (-9.7, 4.7, 2.2), 1.0, 2.1, "ivory", mirror=True)
    # a small bone blade at the root of the tail, the first of the backbone's
    body.beam((10.3, 0, 1.2), (12.0, 0, 3.2), 1.5, 0.7, "ivory")
    # the seat on the ridge: a shallow slot either side for the rider's legs
    body.dent(-1, 1, 2, 3, 4, "hide-")

    for name, side in SIDES:
        # the horns: each a fin standing on edge at the corner of the mouth, three boxes that reach forward and curl in
        # and down toward the other one, bone at the tip
        horn = m.part("Horn" + name, (-12.5, 4.5 * side, 0.6), "Body")
        horn.beam((-12.2, 4.5 * side, 0.6), (-15.6, 4.9 * side, 0.2), 2.6, 1.2, "hide")
        horn.beam((-14.9, 4.85 * side, 0.25), (-17.6, 3.9 * side, -0.5), 2.1, 0.85, "hide")
        horn.beam((-17.0, 4.1 * side, -0.35), (-18.8, 2.7 * side, -1.3), 1.5, 0.5, "ivory")

        # the wing: three plates in a chain, each on its own joint. The first lies flat and starts inside the body; the
        # second and the third each start inside the one before, a step shorter and thinner, and rise toward the tip
        p1 = ((4.0, -10.0, 9.0, 0.0, 1.7), (14.6, -7.3, 5.4, 0.0, 1.7))
        p2 = ((13.4, -7.2, 5.2, 0.2, 1.4), (23.6, -2.5, 4.6, 1.4, 2.6))
        p3 = ((22.6, -2.5, 4.3, 1.5, 2.25), (30.0, 4.6, 6.0, 3.1, 3.85))
        one = m.part("Wing" + name + "1", (0, 6.0 * side, 0.6), "Body")
        wing_plate(one, side, p1[0], p1[1], 0.55)
        two = m.part("Wing" + name + "2", (0, 14.0 * side, 0.8), "Wing" + name + "1")
        wing_plate(two, side, p2[0], p2[1], 0.45)
        three = m.part("Wing" + name + "3", (0, 22.5 * side, 1.9), "Wing" + name + "2")
        wing_plate(three, side, p3[0], p3[1], 0.35, inset=0.25)
        # the spars. The first follows the leading edge to the tip, in three lengths that bend back at the joints
        spar(one, side, *p1, (6.7, -7.5, 1.3), (14.4, -6.0, 1.2))
        spar(two, side, *p2, (14.8, -5.8, 1.2), (23.4, -1.4, 1.0))
        spar(three, side, *p3, (23.9, -0.45, 1.0), (29.7, 5.1, 0.7))
        # the second crosses the first two plates to the trailing edge of the second, and comes out past it as a bare
        # bone point: a thinner piece that starts inside the plate, under the spar's end
        spar(one, side, *p1, (6.7, -4.5, 1.4), (14.4, 0.9, 1.2))
        spar(two, side, *p2, (14.8, 1.2, 1.2), (19.0, 4.14, 0.9))
        tab(two, side, *p2, (18.4, 3.22, 4.22), (22.2, 5.93, 6.83), inset=0.3, colour="ivory")
        # the third crosses the first plate and comes out past its trailing edge the same way
        spar(one, side, *p1, (6.7, -1.5, 1.5), (11.5, 5.3, 1.1))
        tab(one, side, *p1, (10.6, 3.43, 4.63), (13.3, 7.36, 8.36), inset=0.4, colour="ivory")
        # the ragged trailing edge: torn tabs of skin between the bone points, no two the same
        tab(one, side, *p1, (6.6, 6.8, 10.2), (8.6, 6.2, 8.4))
        tab(one, side, *p1, (9.4, 5.6, 8.0), (11.2, 5.2, 8.9))
        tab(two, side, *p2, (15.6, 3.6, 7.4), (17.8, 3.6, 6.0))
        tab(three, side, *p3, (24.4, 3.6, 6.2), (26.4, 4.0, 7.2), inset=0.2)

    # the tail: the bare backbone, in three lengths, each thinner than the last and starting inside it, each on its own
    # joint: a cord with vertebrae on it, smaller and smaller
    tail = m.part("Tail1", (15, 0, 0), "Body")
    vertebrae(tail, 14.6, None, (0.9, 0.8), ((16.0, 1.1, 0.8, 0.85), (17.8, 1.0, 0.75, 0.8), (19.5, 1.0, 0.7, 0.75), (21.0, 0.9, 0.65, 0.7)))
    tail = m.part("Tail2", (21.3, 0, 0), "Tail1")
    vertebrae(tail, 21.15, None, (0.65, 0.55), ((23.0, 0.9, 0.55, 0.6), (24.6, 0.9, 0.5, 0.56), (26.3, 0.8, 0.47, 0.53), (27.9, 0.8, 0.45, 0.5)),
              blades=False)
    tail = m.part("Tail3", (28.1, 0, 0), "Tail2")
    vertebrae(tail, 28.0, 35.0, (0.4, 0.35), ((29.6, 0.7, 0.38, 0.42), (31.0, 0.65, 0.36, 0.4), (32.4, 0.6, 0.34, 0.38), (33.7, 0.55, 0.33, 0.36)),
              blades=False)
