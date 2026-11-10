"""The Boxfish (zone 1's Common: a yellow boxfish) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a fish that is a box. Here boxy is right, so the body is one big block with a shorter, narrower slice at each end.
- The box: flat underneath with sharp bottom edges (a boxfish's keel ridges), one step on the top corners, a pale belly
  that runs level from the chin to the rump. The forehead steps down to the face; the rump steps in all round.
- Dark spots are single painted cubes, few and scattered, on the sides and the back.
- The face is a steep wall; low on it a short snout block with pouting lips.
- Big friendly eyes high on the front corners of the box: a cream ring and a dark pupil, each a little proud.
- A thin tail stalk on a joint, and a small fan of a tail on another: a root, two rays and a web between them.
- Tiny fins, each on its own joint so it can flutter: a dorsal and an anal fin far back, a paddle on each side.
It swims as a boxfish does: the box stays stiff, the tail wags and the little fins beat fast.
The rider sits on the middle of the back, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Boxfish", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"yellow": "#F4C81E", "cream": "#FFF1C9", "spot": "#4B3A2E", "black": "#22262B", "lip": "#F08A6C"}
SEAT = (-2, 5, 4.6)
FRAME, ORTHO = 0.8, 11.5
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["yellow"]}]

# the spots: single cubes. On the sides (x, z), the same both sides; on the back (x, column)
SIDE_SPOTS = ((-7, -2), (-1, -2), (1, 2), (2, -1))
TOP_SPOTS = ((-7, 1), (-5, -2), (0, 2), (1, -1))


def pose(parts, phase):
    """a boxfish's swim: the box hardly turns, the stalk and the tail wag, and the small fins beat twice as fast"""
    parts["Body"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    parts["Stalk"].rotation_euler.z = math.radians(10) * math.sin(phase - 0.6)
    parts["Tail"].rotation_euler.z = math.radians(18) * math.sin(phase - 1.4)
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(16) * math.sin(2 * phase)
    parts["Dorsal"].rotation_euler.x = math.radians(14) * math.sin(2 * phase + 0.5)
    parts["Anal"].rotation_euler.x = -math.radians(14) * math.sin(2 * phase + 0.5)


def build(m):
    body = m.part("Body", (-2, 0, 0))
    # the box, and a shorter, narrower slice at each end: the face and the rump
    body.hull(-9, 3, 4, -5, 5, "yellow", [(1, 1)])
    body.hull(-11, -9, 3, -5, 4, "yellow", [(1, 1)])  # the face: the forehead steps down, the flat belly runs on to the chin
    body.hull(3, 5, 3, -4, 4, "yellow", [(1, 1)])
    body.paint_sym(-9, 3, 4, 4, 5, "yellow+")
    body.paint_sym(-11, -9, 3, 3, 4, "yellow+")
    body.paint_sym(3, 5, 3, 3, 4, "yellow+")
    body.paint_sym(-11, 5, 4, -5, -3, "cream")  # the pale belly: one level line from face to rump
    for x, z in SIDE_SPOTS:
        body.paint_pair(x, x + 1, 4, 5, z, z + 1, "spot")
    body.paint_pair(3, 4, 3, 4, 0, 1, "spot")  # one on the rump
    for x, j in TOP_SPOTS:
        body.paint(x, x + 1, j, j + 1, 4, 5, "spot")
    body.dent(-3, -1, 4, 0, 3, "yellow-")  # the rider's leg slots

    # the snout: a short block low on the face, tilted a little nose-down, and pouting lips: a smaller block starting
    # inside it, with a small dark mouth
    body.beam((-10.4, 0, -1.3), (-12.3, 0, -1.7), 3.0, 2.6, "yellow", flat="z")
    body.beam((-11.9, 0, -1.65), (-13.0, 0, -1.9), 2.2, 1.7, "lip", flat="z")
    body.beam((-12.6, 0, -1.82), (-13.2, 0, -1.95), 1.0, 0.5, "spot", flat="z")

    # the eyes: big, high on the front corners of the box. A cream ring a little proud of the side, a dark pupil a little
    # proud of that, sitting forward in it
    ring = (4.4, 4.8, 0.1, 2.9)
    body.block(-8.7, ring, -5.9, ring, "cream", mirror=True)
    pupil = (4.7, 5.1, 0.6, 2.4)
    body.block(-8.1, pupil, -6.4, pupil, "black", mirror=True)
    glint = (5.0, 5.3, 1.6, 2.2)  # a small light in the pupil: it makes the eye friendly
    body.block(-7.9, glint, -7.3, glint, "cream", mirror=True)

    # the tail stalk, on its own joint, with a sleeve into the rump
    stalk = m.part("Stalk", (5, 0, 0), "Body")
    stalk.sym(5, 8, 1, -2, 2, "yellow")
    stalk.sym(4, 5, 0, -1, 1, "yellow-")
    # the tail: a root block in the stalk's end, two rays that spread from inside it, and a thin web between them
    tail = m.part("Tail", (8, 0, 0), "Stalk")
    tail.beam((7.3, 0, 0), (9.5, 0, 0), 3.6, 1.0, "yellow")
    for side in (1, -1):
        tail.beam((8.3, 0, 0.95 * side), (11.6, 0, 2.7 * side), 1.8, 0.7, "yellow")
    tail.block(8.6, (-0.15, 0.15, -1.5, 1.5), 11.9, (-0.15, 0.15, -2.05, 2.05), "yellow-")  # the web fans out with the rays

    # the tiny fins, each on its own joint: two boxes, the second smaller and thinner and starting inside the first
    dorsal = m.part("Dorsal", (1.2, 0, 5), "Body")
    dorsal.beam((0.6, 0, 4.3), (2.2, 0, 6.6), 2.2, 0.8, "yellow-")
    dorsal.beam((1.7, 0, 5.9), (2.9, 0, 7.6), 1.5, 0.5, "yellow-")
    anal = m.part("Anal", (1.2, 0, -5), "Body")
    anal.beam((0.6, 0, -4.3), (2.1, 0, -6.4), 2.0, 0.8, "yellow-")
    anal.beam((1.6, 0, -5.7), (2.7, 0, -7.2), 1.4, 0.5, "yellow-")
    for name, side in (("FinR", 1), ("FinL", -1)):  # the side fins: small upright paddles that stand out and back
        fin = m.part(name, (-5.0, 4.5 * side, -1.5), "Body")
        fin.beam((-5.4, 3.8 * side, -1.5), (-3.6, 6.0 * side, -1.5), 2.4, 0.8, "yellow-")
        fin.beam((-4.23, 5.23 * side, -1.5), (-2.88, 6.88 * side, -1.5), 1.6, 0.4, "yellow-")
