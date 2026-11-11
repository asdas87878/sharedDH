"""The Cinder Ray (zone 10's Legendary: a manta of the underworld) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. A variant of the Manta Ray
(art/creatures/MantaRay/voxel.py): the same animal, the same size and seat, the same three-plate wings and their flap.
Its idea: a kite of cooling slag, still lit at the edges. The hide is charcoal-plum above and ash below, and the fire
inside shows only where the hide is thinnest:
- The focal point is one thin ember line all the way round each wing: a glowing seam between the dark top and the ash
  underside, along the leading edge, round the tip and back along the trailing edge to the body.
- Its echo is a few lava cracks that follow the wing's spars: one from the shoulder out along the front spar, over the
  wing's first joint and on toward the tip, and one fanning back along a rear spar. Each narrows to nothing.
- The whip tail ends in a glowing coal, held in a dark collar.
- Ember eyes in sooty sockets (its idea is fire, so the eye itself is the light), under a brow that slants down to the
  front and comes past the eye.
- The head fins are short horns: three boxes that turn up and in, ash at the tip.
Ash underneath, with the five gill slits a side a tone darker.
The rider sits on the ridge, legs in a shallow slot either side; nothing glows or stands up near the seat."""
import math

NAME, ZONE, RARITY = "Cinder Ray", "ZONE 10 / THE UNDERWORLD", "LEGENDARY"
U = 0.4
PALETTE = {"back": "#3A2C3B", "belly": "#9A898F", "ember": "#FF7C16", "lava": "#FF4E14", "soot": "#1C161E"}
SEAT = (0, 5, 2.58)
GLOW = {"ember": 1.0, "lava": 0.85}  # the rim line, the eyes and the coal; the cracks along the spars
# round studs on the charcoal top only (the third wing plate is tilted past the kit's "square" limit, so it is named)
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"], "parts": ["WingR3", "WingL3"], "turned": True},
            {"tile": "stud", "on": "top", "colours": ["back"]}]
FRAME, ORTHO, ORTHO_SWIM = 2.1, 54.0, 56.0
SIDES = (("R", 1), ("L", -1))


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


def wing_plate(part, side, inner, outer, under, inset=0.3):
    """a dark wing plate with its ash underside: a thinner plate set in from the edges, its top just inside the dark one"""
    plate(part, side, inner, outer, "back")
    (ya, la, ta, za, _), (yb, lb, tb, zb, _) = inner, outer
    plate(part, side, (ya + 0.2, la + inset, ta - inset, za - under, za + 0.05), (yb - 0.2, lb + inset, tb - inset, zb - under, zb + 0.05), "belly")


def at(inner, outer, y):
    """a wing plate's (leading x, trailing x, underside z, top z) at y, on the straight lines between its two sections"""
    f = (y - inner[0]) / (outer[0] - inner[0])
    return [a + (b - a) * f for a, b in zip(inner[1:], outer[1:])]


def rim(part, side, inner, outer, ya, yb, edge, proud=0.6, bite=0.5, share=0.3):
    """the ember line along one edge of a wing plate, from ya to yb: a thin strip in the middle of the plate's thickness
    that stands `proud` of the edge, its back `bite` inside the plate. edge: "lead" or "trail" """
    ends = []
    for y in (ya, yb):
        lead, trail, low, high = at(inner, outer, y)
        mid, half = (low + high) / 2, (high - low) * share / 2
        x0, x1 = (lead - proud, lead + bite) if edge == "lead" else (trail - bite, trail + proud)
        ends.append((y, x0, x1, mid - half, mid + half))
    plate(part, side, ends[0], ends[1], "ember")


def crack(part, side, inner, outer, *points, proud=0.25, sunk=0.3):
    """a lava crack along a spar of a wing plate: a thin line a little proud of the top, through the points, each
    (y, the middle x, how wide). It follows the spar but kinks a little from length to length, as a crack does"""
    ends = []
    for y, x, wide in points:
        high = at(inner, outer, y)[3]
        ends.append((y, x - wide / 2, x + wide / 2, high - sunk, high + proud))
    for a, b in zip(ends, ends[1:]):
        plate(part, side, a, b, "lava")


def build(m):
    body = m.part("Body", (0, 0, 0))
    # the body: a flat lens. A wide slab three cubes thick, a narrower step on top of it and underneath, a ridge down the
    # middle. From the shoulders back it narrows one step at a time to the root of the tail
    body.hull(-13, -10, 5, -2, 3, "back", [(2, 1)], [(2, 1)])  # the head
    body.hull(-10, 5, 6, -2, 4, "back", [(4, 1), (2, 1)], [(2, 1)])  # between the wings
    body.sym(-4, 3, 2, 4, 5, "back+")  # the ridge: the highest part, where the rider sits
    body.sym(-6, -4, 1, 4, 5, "back+")  # it narrows a step at each end, so it reads as a rise, not a box
    body.sym(3, 5, 1, 4, 5, "back+")
    body.hull(5, 8, 5, -2, 3, "back", [(3, 1)], [(2, 1)])
    body.hull(8, 10, 4, -2, 3, "back", [(2, 1)], [(2, 1)])
    body.hull(10, 12, 3, -1, 2, "back", [(1, 1)])
    body.sym(12, 14, 2, -1, 1, "back")
    body.sym(14, 15, 1, -1, 1, "back")
    body.paint(-13, 15, -8, 9, -2, 0, "belly")  # ash below the middle line
    body.paint_sym(-13, -10, 3, 2, 3, "back+")  # the top rows a tone lighter
    body.paint_sym(-10, 5, 2, 3, 4, "back+")
    body.paint_sym(5, 10, 2, 2, 3, "back+")
    body.paint_sym(10, 12, 2, 1, 2, "back+")
    # the belly: five gill slits a side, a tone darker
    for x in (-9, -7, -5, -3, -1):
        body.paint_pair(x, x + 1, 1, 4, -2, -1, "belly-")
    # the mouth: a wide dark slot across the very front, between the dark upper lip and the ash lower one
    body.carve(-13, -12, -3, 4, -1, 1)
    mouth = (-3.5, 3.5, -1, 1)
    body.block(-12.25, mouth, -11.95, mouth, "soot")
    # the eyes, on the sides of the head: a sooty socket and an ember standing a little out of it (fire is its idea, so
    # the eye is the light). The brow sits on the eye, cuts the top of its square and comes past it in front
    ring = (5.45, 5.8, 0.15, 1.45)
    body.block(-12.5, ring, -11.1, ring, "soot", mirror=True)
    pupil = (5.7, 6.0, 0.35, 0.95)
    body.block(-12.2, pupil, -11.4, pupil, "ember", mirror=True)
    body.beam((-10.3, 5.7, 1.5), (-13.4, 5.7, 1.05), 0.8, 1.0, "back", mirror=True)
    # a small fin at the root of the tail
    body.beam((10.3, 0, 1.2), (12.0, 0, 3.2), 1.5, 0.7, "back")
    # the seat on the ridge: a shallow slot either side for the rider's legs
    body.dent(-1, 1, 2, 3, 4, "back-")
    # the front crack starts on the shoulder: it comes out from under the back's top step and runs on along the wing
    shoulder = (4.4, 6.2, 1.7, 2.25)
    body.block(-8.3, shoulder, -7.6, shoulder, "lava", mirror=True)

    for name, side in SIDES:
        # the horns: the head fins, short and turned up. Three boxes at the corner of the mouth, each smaller and thinner
        # than the last and starting inside it, that reach forward, then up and in; ash at the tip
        horn = m.part("Horn" + name, (-12.5, 4.5 * side, 0.6), "Body")
        horn.beam((-12.2, 4.5 * side, 0.6), (-14.6, 4.7 * side, 0.8), 2.4, 1.3, "back")
        horn.beam((-14.0, 4.65 * side, 0.9), (-16.0, 4.2 * side, 1.9), 1.7, 0.95, "back")
        horn.beam((-15.5, 4.31 * side, 1.65), (-17.5, 3.65 * side, 3.2), 1.1, 0.6, "belly")

        # the wing: three plates in a chain, each on its own joint. The first lies flat and starts inside the body; the
        # second and the third each start inside the one before, a step shorter and thinner, and rise toward the tip.
        # Round each runs the ember line; along the spars run the cracks
        inner, outer = (4.0, -10.0, 9.0, 0.0, 1.7), (14.6, -7.3, 5.4, 0.0, 1.7)
        one = m.part("Wing" + name + "1", (0, 6.0 * side, 0.6), "Body")
        wing_plate(one, side, inner, outer, 0.55)
        rim(one, side, inner, outer, 6.6, 14.3, "lead")
        rim(one, side, inner, outer, 4.3, 14.3, "trail")
        crack(one, side, inner, outer, (6.6, -7.85, 0.7), (9.2, -6.6, 0.65), (11.6, -6.6, 0.6), (14.3, -5.4, 0.5))  # the front spar
        crack(one, side, inner, outer, (6.6, 1.6, 0.6), (9.4, 1.9, 0.5), (11.4, 3.2, 0.4), (13.5, 3.5, 0.25))  # a rear spar, fanning back
        inner, outer = (13.4, -7.2, 5.2, 0.2, 1.4), (23.6, -2.5, 4.6, 1.4, 2.6)
        two = m.part("Wing" + name + "2", (0, 14.0 * side, 0.8), "Wing" + name + "1")
        wing_plate(two, side, inner, outer, 0.45)
        rim(two, side, inner, outer, 14.7, 23.3, "lead")
        rim(two, side, inner, outer, 14.7, 23.3, "trail")
        crack(two, side, inner, outer, (14.75, -5.3, 0.5), (17.2, -3.9, 0.4), (19.4, -3.3, 0.35), (21.5, -1.9, 0.2))  # the front spar runs on
        inner, outer = (22.6, -2.5, 4.3, 1.5, 2.25), (30.0, 4.6, 6.0, 3.1, 3.85)
        three = m.part("Wing" + name + "3", (0, 22.5 * side, 1.9), "Wing" + name + "2")
        wing_plate(three, side, inner, outer, 0.35, inset=0.25)
        rim(three, side, inner, outer, 23.7, 29.7, "lead")
        rim(three, side, inner, outer, 23.7, 29.7, "trail")
        # the line turns round the tip: a cap from where the two strips end, past the end of the plate
        lead, trail, low, high = at(inner, outer, 29.7)
        mid, half = (low + high) / 2, (high - low) * 0.15
        _, _, low, high = at(inner, outer, 30.6)
        end = (low + high) / 2
        plate(three, side, (29.7, lead - 0.6, trail + 0.6, mid - half, mid + half), (30.6, 4.5, 6.1, end - half, end + half), "ember")

    # the tail: a thin whip in three lengths, each thinner than the last and starting inside it, each on its own joint.
    # It ends in a glowing coal held in a dark collar
    tail = m.part("Tail1", (15, 0, 0), "Body")
    tail.beam((14.6, 0, 0), (22.0, 0, 0), 1.4, 1.2, "back")
    tail = m.part("Tail2", (21.6, 0, 0), "Tail1")
    tail.beam((21.2, 0, 0), (29.0, 0, 0), 1.0, 0.85, "back")
    tail = m.part("Tail3", (28.6, 0, 0), "Tail2")
    tail.beam((28.2, 0, 0), (34.0, 0, 0), 0.6, 0.5, "back")
    tail.beam((33.4, 0, 0), (34.7, 0, 0), 1.0, 0.9, "back")
    tail.beam((34.3, 0, 0), (36.0, 0, 0), 1.6, 1.4, "ember")
