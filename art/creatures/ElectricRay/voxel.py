"""The Electric Ray (zone 4's Epic: a torpedo ray) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed
as an Epic by docs/style/05-rarity-look.md. Designed from the real animal: a round, fleshy disc, not a kite like the manta.
Its idea: a live battery. A plain round disc of dusky blue-grey, and lightning crawling round its edge.
- The disc is a stack of flat layers, each a stepped circle a few cubes inside the one below: a thin rim, the thick of
  the wings, the body's mound, and a short ridge where the rider sits. Underneath, two pale layers do the same, so the
  side view is a lens: the back arches, the belly curves, the edge is thin.
- The front of the disc is cut straight, as a torpedo ray's is; the small eyes sit on top, close together, near it.
- Its mark is the lightning: a thin zigzag of electric yellow that runs round the rim from the head to the tail on each
  side, and a shorter one inside it on each side of the back, bent the same way as the edge. Only these glow.
- The tail is short and thick, in two lengths on joints of their own, with two small fins on top and a paddle at the end
  (three boxes fanned out, on its own joint). Two flat belly fins lie either side of its root.
- It swims as the real one does: the disc stays stiff and the tail sculls from side to side.
The rider sits on the ridge, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Electric Ray", "ZONE 4 / SHIPWRECKS", "EPIC"
U = 0.45
PALETTE = {"back": "#5A6B82", "belly": "#E7E2D2", "spark": "#FFE838", "black": "#15181D", "mouth": "#3A4252"}
SEAT = (-6, 4, 2.5)
GLOW = {"spark": 0.9}  # the lightning, and nothing else
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"]}]
FRAME, ORTHO = 1.7, 30.0
SWIM = {"chain": ["Body", "Tail1", "Tail2", "Paddle"], "amplitudes": [7, 11, 16], "phaseStep": 0.9, "headCounter": 1.5}

# the disc, layer by layer: each is a list of (x from, x to, cubes out either side). Every outline is a stepped circle:
# a long straight side and two or three broad steps to the front and to the back
RIM = ((-20, -19, 7), (-19, -17, 10), (-17, -14, 12), (-14, -2, 14), (-2, 1, 12), (1, 3, 9), (3, 5, 5))  # z 0 to 1
WING = ((-17, -15, 7), (-15, -12, 9), (-12, -4, 11), (-4, -1, 9), (-1, 2, 6), (2, 5, 3))  # z 1 to 2
MOUND = ((-14, -11, 3), (-11, -3, 5), (-3, 2, 3))  # z 2 to 3
RIDGE = ((-11, -9, 1), (-9, -3, 2), (-3, -1, 1))  # z 3 to 4
UNDER = ((-18, -16, 8), (-16, -13, 10), (-13, -3, 12), (-3, 0, 10), (0, 3, 7), (3, 5, 4))  # z -1 to 0
KEEL = ((-15, -12, 5), (-12, -2, 8), (-2, 2, 5))  # z -2 to -1

# the lightning (right side; the left is its mirror): corners of a zigzag, each on the open top of its layer, turn by
# turn near the outer edge and near the next layer's foot
RIM_BOLT = ((-19.3, 1.0), (-17.7, 2.8), (-19.2, 4.9), (-17.7, 6.9), (-18.2, 9.4), (-16.3, 9.0), (-16.0, 11.6), (-14.4, 10.5),
            (-13.2, 13.6), (-11.3, 12.3), (-9.3, 13.8), (-7.3, 12.3), (-5.1, 13.8), (-3.3, 10.3), (-1.0, 11.8), (0.2, 8.4),
            (2.2, 8.8), (2.6, 5.0))
BACK_BOLT = ((-13.2, 6.4), (-11.3, 9.3), (-9.5, 7.6), (-7.6, 10.0), (-5.7, 7.6), (-4.4, 9.4), (-2.2, 6.4))


def layer(part, spans, z0, z1, colour):
    for x0, x1, n in spans:
        part.sym(x0, x1, n, z0, z1, colour)


def bolt(part, corners, z):
    """a zigzag lying on a flat top at height z: one thin box to a stroke, each running a little past its corners so the
    turns are closed. Every other stroke stands a little higher, so no two tops lie in one plane where they cross"""
    for k, ((ax, ay), (bx, by)) in enumerate(zip(corners, corners[1:])):
        length = ((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5
        ex, ey = 0.25 * (bx - ax) / length, 0.25 * (by - ay) / length
        thick = 0.9 if k % 2 else 0.6
        part.beam((ax - ex, ay - ey, z), (bx + ex, by + ey, z), 0.6, thick, "spark", flat="z", mirror=True)


def build(m):
    body = m.part("Body", (-7, 0, 0))
    layer(body, RIM, 0, 1, "back-")  # the thin edge, a tone darker, so the lightning stands out on it
    layer(body, WING, 1, 2, "back")
    layer(body, MOUND, 2, 3, "back")
    layer(body, RIDGE, 3, 4, "back+")  # the highest part, where the rider sits
    layer(body, UNDER, -1, 0, "belly")
    layer(body, KEEL, -2, -1, "belly-")
    # underneath: a small dark mouth near the front, five gill slits a side behind it
    body.paint(-14, -13, -2, 3, -2, -1, "mouth")
    for x in (-11, -9, -7, -5, -3):
        body.paint_pair(x, x + 1, 3, 6, -2, -1, "mouth")
    # the seat on the ridge: a shallow slot either side for the rider's legs
    # (cut by hand, not with dent(): the slot is open at the top, so its floor stops short of the ridge's top as well)
    body.carve_pair(-7, -5, 2, 3, 3, 4)
    slot = (1.45, 2.2, 3.0, 3.7)
    body.block(-7, slot, -5, slot, "back-", mirror=True)

    # the eyes: small, on top of the head, close together. A pale ring a little proud of the back, a dark pupil on it
    ring = (1.6, 3.1, 2.7, 3.3)
    body.block(-13.6, ring, -12.1, ring, "belly", mirror=True)
    pupil = (1.95, 2.75, 3.1, 3.6)
    body.block(-13.25, pupil, -12.45, pupil, "black", mirror=True)

    # the lightning: round the rim, and one stroke of it on each side of the back
    bolt(body, RIM_BOLT, 1.0)
    bolt(body, BACK_BOLT, 2.0)

    # the belly fins: flat, either side of the tail's root, each two boxes, the second smaller and thinner
    body.beam((2.6, 4.2, 0.0), (7.2, 7.4, -0.35), 3.2, 0.9, "back", flat="z", mirror=True)
    body.beam((6.14, 6.66, -0.27), (8.58, 8.36, -0.45), 2.0, 0.5, "back-", flat="z", mirror=True)

    # the tail: short and thick, two lengths, each on its own joint, pale underneath. It narrows a cube at a time
    one = m.part("Tail1", (5, 0, 0.5), "Body")
    one.hull(5, 9, 3, -1, 2, "back", [(1, 1)])
    one.paint_sym(5, 9, 3, -1, 0, "belly")
    one.sym(4, 5, 2, 0, 1, "back-")  # a sleeve into the disc
    # the first small fin: two boxes leaning back, the root deep in the tail
    one.beam((6.0, 0, 1.0), (7.9, 0, 3.5), 2.2, 0.9, "back")
    one.beam((7.4, 0, 3.0), (8.5, 0, 4.2), 1.4, 0.6, "back-")

    two = m.part("Tail2", (9, 0, 0.5), "Tail1")
    two.hull(9, 13, 2, -1, 2, "back", [(1, 1)])
    two.sym(13, 16, 1, -1, 2, "back")
    two.paint_sym(9, 16, 2, -1, 0, "belly")
    two.sym(8, 9, 1, 0, 1, "back-")  # a sleeve
    # the second fin, smaller
    two.beam((10.6, 0, 1.0), (12.0, 0, 3.0), 1.7, 0.8, "back")
    two.beam((11.6, 0, 2.6), (12.5, 0, 3.6), 1.1, 0.5, "back-")

    # the paddle, on its own joint: three boxes fanned out from one root inside the tail's end
    paddle = m.part("Paddle", (15.5, 0, 0.5), "Tail2")
    paddle.beam((15.2, 0, 0.5), (19.7, 0, 0.5), 2.2, 1.2, "back")
    paddle.beam((15.4, 0, 0.6), (19.6, 0, 2.5), 2.0, 0.9, "back")
    paddle.beam((15.4, 0, 0.4), (19.3, 0, -1.3), 1.8, 0.6, "back-")
