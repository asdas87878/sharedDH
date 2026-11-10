"""The Manta Ray (zone 5's Epic) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed as an Epic by
docs/style/05-rarity-look.md. The first flat, winged creature: designed from the real manta, not from the fish.
Its idea: a living kite. Nearly all of it is wing; the body is a low rise in the middle of one wide black diamond, and
everything else is small and sits at the two ends: the mouth and its two horns in front, a whip of a tail behind.
- The body is a flat lens: a wide low slab with a narrow ridge down the middle, thickest between the wings.
- Each wing is three flat plates in a chain, each a step shorter and thinner than the last and starting inside it, on
  joints of their own, so the wing flaps in a wave from root to tip. The leading edge sweeps back to a pointed tip, the
  trailing edge is hollow, and the outer plates rise a little, so the tips curl up even at rest.
- Black above, white below: each plate carries a thinner white plate underneath, set in from its edge. The belly has
  five gill slits a side and a few dark blotches, as every manta's does.
- Its mark is the pair of horns: two fins that reach forward either side of a wide mouth at the very front and curl in
  toward each other, pale at the tips. A pale bar across each shoulder answers them.
- Small eyes on the sides of the head, a dark pupil in a white ring. Nothing glows.
- A thin tail in three lengths, each on its own joint, with a small fin at its root.
The rider sits on the ridge, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Manta Ray", "ZONE 5 / OPEN BLUE", "EPIC"
U = 0.4
PALETTE = {"back": "#262B33", "belly": "#EEF0EE", "pale": "#B9C8D4", "black": "#101216", "mouth": "#14161A", "gill": "#69717C",
           "blotch": "#4A525E"}
SEAT = (0, 5, 2.58)
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


def wing_plate(part, side, inner, outer, white, inset=0.3):
    """a black wing plate with its white underside: a thinner plate set in from the edges, its top just inside the black"""
    plate(part, side, inner, outer, "back")
    (ya, la, ta, za, _), (yb, lb, tb, zb, _) = inner, outer
    plate(part, side, (ya + 0.2, la + inset, ta - inset, za - white, za + 0.05), (yb - 0.2, lb + inset, tb - inset, zb - white, zb + 0.05), "belly")


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
    body.paint(-13, 15, -8, 9, -2, 0, "belly")  # white below the middle line
    body.paint_sym(-13, -10, 3, 2, 3, "back+")  # the top rows a tone lighter
    body.paint_sym(-10, 5, 2, 3, 4, "back+")
    body.paint_sym(5, 10, 2, 2, 3, "back+")
    body.paint_sym(10, 12, 2, 1, 2, "back+")
    # a pale bar across each shoulder, from the ridge to the edge of the body (it runs on along the wing)
    body.paint_pair(-9, -6, 3, 5, 2, 3, "pale")
    body.paint_pair(-9, -6, 5, 7, 1, 2, "pale")
    # the belly: five gill slits a side, and a few dark blotches, no two mantas the same
    for x in (-9, -7, -5, -3, -1):
        body.paint_pair(x, x + 1, 1, 4, -2, -1, "gill")
    for x0, x1, y0, y1 in ((1, 3, -1, 2), (3, 4, 2, 4), (4, 5, -3, -1), (6, 7, 0, 2)):
        body.paint(x0, x1, y0, y1, -2, -1, "blotch")
    # the mouth: a wide dark slot across the very front, between the black upper lip and the white lower one
    body.carve(-13, -12, -3, 4, -1, 1)
    mouth = (-3.5, 3.5, -1, 1)
    body.block(-12.25, mouth, -11.95, mouth, "mouth")
    # the eyes, on the sides of the head: a white ring, a dark pupil standing a little out of it
    ring = (5.45, 5.8, 0.25, 1.55)
    body.block(-12.5, ring, -11.1, ring, "belly", mirror=True)
    pupil = (5.7, 6.0, 0.55, 1.25)
    body.block(-12.15, pupil, -11.45, pupil, "black", mirror=True)
    # a small fin at the root of the tail
    body.beam((10.3, 0, 1.2), (12.0, 0, 3.2), 1.5, 0.7, "back")
    # the seat on the ridge: a shallow slot either side for the rider's legs
    body.dent(-1, 1, 2, 3, 4, "back-")

    for name, side in SIDES:
        # the horns: each a fin standing on edge at the corner of the mouth, three boxes that reach forward and curl in
        # and down toward the other one, pale at the tip
        horn = m.part("Horn" + name, (-12.5, 4.5 * side, 0.6), "Body")
        horn.beam((-12.2, 4.5 * side, 0.6), (-15.6, 4.9 * side, 0.2), 2.6, 1.2, "back")
        horn.beam((-14.9, 4.85 * side, 0.25), (-17.6, 3.9 * side, -0.5), 2.1, 0.85, "back")
        horn.beam((-17.0, 4.1 * side, -0.35), (-18.8, 2.7 * side, -1.3), 1.5, 0.5, "pale")

        # the wing: three plates in a chain, each on its own joint. The first lies flat and starts inside the body; the
        # second and the third each start inside the one before, a step shorter and thinner, and rise toward the tip
        one = m.part("Wing" + name + "1", (0, 6.0 * side, 0.6), "Body")
        wing_plate(one, side, (4.0, -10.0, 9.0, 0.0, 1.7), (14.6, -7.3, 5.4, 0.0, 1.7), 0.55)
        # the shoulder bar runs on along the wing: a thin pale plate a little proud of the black
        plate(one, side, (6.6, -8.4, -5.4, 1.55, 1.95), (12.6, -6.4, -4.4, 1.55, 1.95), "pale")
        two = m.part("Wing" + name + "2", (0, 14.0 * side, 0.8), "Wing" + name + "1")
        wing_plate(two, side, (13.4, -7.2, 5.2, 0.2, 1.4), (23.6, -2.5, 4.6, 1.4, 2.6), 0.45)
        three = m.part("Wing" + name + "3", (0, 22.5 * side, 1.9), "Wing" + name + "2")
        wing_plate(three, side, (22.6, -2.5, 4.3, 1.5, 2.25), (30.0, 4.6, 6.0, 3.1, 3.85), 0.35, inset=0.25)

    # the tail: a thin whip in three lengths, each thinner than the last and starting inside it, each on its own joint
    tail = m.part("Tail1", (15, 0, 0), "Body")
    tail.beam((14.6, 0, 0), (22.0, 0, 0), 1.4, 1.2, "back")
    tail = m.part("Tail2", (21.6, 0, 0), "Tail1")
    tail.beam((21.2, 0, 0), (29.0, 0, 0), 1.0, 0.85, "back")
    tail = m.part("Tail3", (28.6, 0, 0), "Tail2")
    tail.beam((28.2, 0, 0), (35.0, 0, 0), 0.6, 0.5, "back")
