"""The Pufferfish, a trial of docs/style/09-early-remodels.md, for tools/blender/voxel_kit.py. It stands beside the game's
Pufferfish (art/creatures/Pufferfish) and replaces nothing. Designed from the real animal.
Its idea: the balloon. The ball IS the animal; everything else is too small for it on purpose.
- The body idea in numbers: about 29 cubes long, nose to tail tip. The ball alone is 23 long, 23 deep (0.8 of the
  length) and 25 wide (0.85). In all three views it is a plateau and two broad steps: a middle slab 11 long, a shoulder
  3 long in front and behind, a face and a rump 3 long.
- The fins are stubs: two small paddles on the sides set far back, a small back fin on the rump, a short tail fan on a
  stalk two cubes long.
- The face: an eye on each front corner of the ball, a round disc facing out along the 45-degree notch between the face
  and the shoulder, so it shows from the front and from the side and faces the 3/4 view: a cream ring 5 across with cut
  corners, half a cube proud, a 3 by 3 pupil standing out of it, a small cream glint. Between and below them a small round
  pout: a ring of peach lips (the lower one pushed out), a dark opening set back inside, two big white buck teeth.
  (Second pass, 2026-11-18: the first eyes were square cream slabs and the lips a green square.)
- Lime green over cream. The line sits at the ball's middle and is scalloped: three broad green lobes along each side,
  cream points between them, in steps of two cubes.
- The one mark: cream spines (small pyramids) in ordered rows over the green: five rows across the top, three down
  each side. None on the seat, none on the cream.
The rider sits on the plateau, in the middle of the ball."""
import math

NAME, ZONE, RARITY = "Pufferfish (trial)", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"green": "#A4CE3A", "cream": "#FBF3DC", "white": "#FFFFFF", "black": "#23262B", "mouth": "#5E2A24", "lips": "#F4A48C"}
SEAT = (-0.5, 12, 7.5)
FRAME, ORTHO = 1.35, 21.0  # it is as wide as it is long: the top view needs the room
SHADE = 0.9  # the made tones stay close: nothing is darkened to add interest
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["green"]}]

# the line between the green back and the cream belly: cream below this height at each x. Three broad green lobes (-1)
# along each side, cream points (3) between them, a step (1) either side of a point. The face and the rump end on a step.
LINE = dict(zip(range(-12, 11), (1, 1, -1, -1, -1, -1, 1, 3, 3, 1, -1, -1, -1, -1, 1, 3, 3, 1, -1, -1, -1, -1, 1)))


def pose(parts, phase):
    """a puffer's swim: the ball hardly bends. It wobbles a little, the tail wags, and the small fins flutter twice a beat"""
    parts["Body"].rotation_euler.z = math.radians(3) * math.sin(phase + math.pi)
    parts["Tail"].rotation_euler.z = math.radians(26) * math.sin(phase - 0.9)
    parts["Dorsal"].rotation_euler.x = math.radians(16) * math.sin(2 * phase)
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(16) * math.sin(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(6) * math.sin(2 * phase - 1.2)


def slab(p, x0, x1, n, bot, top, steps):
    """a slab of the ball: broad stepped corners, a lighter top step, cream below the scalloped line (the belly is not darkened)"""
    p.hull(x0, x1, n, bot, top, "green", steps, steps)
    rows = steps[0][1]
    p.paint_sym(x0, x1, n, top - rows, top, "green+")
    for x in range(x0, x1):
        p.paint_sym(x, x + 1, n, bot, LINE[x], "cream")


def spine(p, at, way, size=1.4, tall=1.4):
    """a short spine: a small pyramid standing on the surface at `at` (the middle of its base), its base sunk in.
    way: "z" up, "y" out to the side. Mirrored unless it stands on the middle line"""
    x, y, z = at
    h, s = size / 2, 0.2
    if way == "z":
        base, apex = [(x - h, y - h, z - s), (x + h, y - h, z - s), (x + h, y + h, z - s), (x - h, y + h, z - s)], (x, y, z + tall)
    else:
        base, apex = [(x - h, y - s, z - h), (x + h, y - s, z - h), (x + h, y - s, z + h), (x - h, y - s, z + h)], (x, y + tall, z)
    p.spike(base, apex, "cream", y != 0)


def column(p, outline, z0, z1, colour):
    """a shape drawn in the top view (x, y corners) and given height from z0 to z1, and its mirror on the left"""
    n = len(outline)
    verts = [(x, y, z0) for x, y in outline] + [(x, y, z1) for x, y in outline]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    p.solid(verts, faces, colour, mirror=True)


def disc(p, centre, at, half, cut, back, front, colour):
    """a round disc on the right front corner, facing forward and out at 45 degrees (and its mirror): a square `half` out
    from its middle with its corners cut by `cut`, from `back` to `front` cubes along the way it faces. `at` moves its
    middle along the corner (toward the tail) and up"""
    r = math.sqrt(0.5)
    face, along = (-r, r), (r, r)  # the way it faces; along the corner, toward the tail
    cx, cy, cz = centre
    cx, cy, cz = cx + along[0] * at[0], cy + along[1] * at[0], cz + at[1]
    h, c = half, cut
    shape = [(-h + c, -h), (h - c, -h), (h, -h + c), (h, h - c), (h - c, h), (-h + c, h), (-h, h - c), (-h, -h + c)]
    if c == 0:
        shape = [(-h, -h), (h, -h), (h, h), (-h, h)]
    n = len(shape)
    verts = [(cx + along[0] * a + face[0] * d, cy + along[1] * a + face[1] * d, cz + b) for d in (back, front) for a, b in shape]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    p.solid(verts, faces, colour, mirror=True)


def build(m):
    body = m.part("Body", (0, 0, 0))
    # THE BALL: a plateau and two broad steps in every view
    # (the first step drops two cubes and the second three, as a ball's does; the flat flank and face are 13 tall)
    slab(body, -6, 5, 12, -11, 12, [(5, 2), (2, 3)])  # the middle: 25 wide, 23 deep; its top is the seat's plateau
    slab(body, -9, -6, 10, -9, 10, [(3, 3)])  # the front shoulder: its top is level with the middle's first shelf
    slab(body, 5, 8, 10, -9, 10, [(3, 3)])  # the rear shoulder
    slab(body, -12, -9, 7, -6, 7, [(2, 2)])  # the face: its top is level with the second shelf
    slab(body, 8, 11, 7, -6, 7, [(2, 2)])  # the rump

    # THE FACE. The eyes: one on each front corner of the ball. The notch between the face and the shoulder runs at 45
    # degrees, so each eye is a round disc facing out along that corner (forward and out), its back buried in the notch:
    # a cream ring 5 across with its corners cut (round, not a slab), a 3 by 3 pupil standing proud of it, a cream glint
    for shape, half, cut, back, front, colour, (a, b) in (
        ("ring", 2.5, 1.0, -2.3, 0.5, "cream", (0.0, 0.0)),
        ("pupil", 1.5, 0.45, 0.0, 0.85, "black", (-0.35, -0.1)),
        ("glint", 0.45, 0.0, 0.5, 1.1, "cream", (-0.85, 0.7)),
    ):
        disc(body, (-10.5, 9.0, 4.0), (a, b), half, cut, back, front, colour)
    # the pout, between and below them: a round ring of soft lips (upper, lower and two sides, the corners left open so it
    # reads round), the lower lip pushed out furthest; a dark opening set back inside it; two big white buck teeth hanging
    # from the upper lip
    body.block(-13.3, (-2.0, 2.0, -0.7, 0.6), -11.5, (-2.0, 2.0, -0.7, 0.6), "lips")  # upper lip
    body.block(-13.7, (-2.0, 2.0, -4.2, -2.8), -11.5, (-2.0, 2.0, -4.2, -2.8), "lips")  # lower lip
    body.block(-13.0, (1.8, 3.1, -3.3, -0.2), -11.5, (1.8, 3.1, -3.3, -0.2), "lips", mirror=True)  # the sides
    body.block(-12.7, (-2.1, 2.1, -3.0, -0.4), -11.6, (-2.1, 2.1, -3.0, -0.4), "mouth")  # the opening
    body.block(-13.5, (0.15, 1.45, -2.1, -0.5), -12.4, (0.15, 1.45, -2.1, -0.5), "white", mirror=True)  # buck teeth

    # THE MARK: cream spines in ordered rows over the green, each row set half a step from the next. Five rows across the
    # top (the middle line, 3.25 and 6.5 out), three down each side (the two shelves and the flank). None on the seat.
    for x in (-4.5, -0.5, 3.5):
        spine(body, (x, 6.5, 12), "z")  # the plateau's edges
        spine(body, (x, 11.5, 7), "z")  # the lower shelf
    for y in (0, 3.25):
        spine(body, (3.5, y, 12), "z")  # behind the rider
    for x in (-2.5, 1.5):
        spine(body, (x, 9, 10), "z")  # the upper shelf
        spine(body, (x, 12.5, 4.5), "y")  # the flank, over the middle lobe
    for x in (-7.5, 6.5):  # the shoulders
        for y in (0, 3.25, 6.5):
            spine(body, (x, y, 10), "z")
        spine(body, (x, 9, 7), "z")
    spine(body, (6.5, 10.5, 4.5), "y")
    for y in (0, 3.25):
        spine(body, (-10.5, y, 7), "z")  # the brow
    spine(body, (9.5, 3.25, 7), "z")  # the rump, either side of the back fin

    # THE STUBS. The side paddles, set far back, each on its own joint: an upright paddle of two boxes that sweeps back
    # and out, the second smaller and thinner, starting inside the first
    for name, s in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (5, 11.5 * s, 0.5), "Body")
        fin.beam((4.2, 11.0 * s, 0.6), (7.4, 13.5 * s, 0.3), 3.2, 0.9, "green-")
        fin.beam((6.7, 12.95 * s, 0.37), (8.5, 14.35 * s, 0.2), 2.3, 0.5, "green-")
    # the back fin, on the rump, leaning back: two boxes
    dorsal = m.part("Dorsal", (9, 0, 6.5), "Body")
    dorsal.beam((8.7, 0, 6.2), (10.8, 0, 8.5), 2.8, 0.9, "green-")
    dorsal.beam((10.25, 0, 7.9), (11.5, 0, 9.3), 2.0, 0.5, "green-")
    # the tail, on its own joint: a stalk two cubes long and a small fan of two lobes with a notch between, each a box
    # and a smaller tip
    tail = m.part("Tail", (11, 0, 0.5), "Body")
    tail.sym(11, 13, 1, -1, 2, "green")
    tail.paint_sym(11, 13, 1, -1, 1, "cream")
    tail.sym(10, 11, 0, 0, 1, "green-")  # the sleeve, inside the rump
    tail.beam((12.2, 0, 1.0), (14.3, 0, 2.2), 2.6, 1.2, "green-")
    tail.beam((13.6, 0, 1.8), (14.7, 0, 2.43), 2.0, 0.5, "green-")
    tail.beam((12.2, 0, 0.0), (14.3, 0, -1.2), 2.6, 0.8, "green-")
    tail.beam((13.6, 0, -0.8), (14.7, 0, -1.43), 2.0, 0.5, "green-")
