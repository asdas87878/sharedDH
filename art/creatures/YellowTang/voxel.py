"""The Yellow Tang (zone 1's Common: a lemon-yellow surgeonfish) for tools/blender/voxel_kit.py.
Its idea: a tall, thin yellow disc with a pointed face. Designed from the real fish:
- The body is one tall slab, five cubes wide, and two broad steps down to a thin tail root. Thin from the front.
- The face is ONE big block turned on its corner: its upper side is the steep forehead, running in one line from the
  snout to the top of the back; its lower side is the chin. The snout is two small blocks in a chain out of that corner.
- The tall back and belly fins are two boxes each: the first leans back from behind the rider, the second lies down the
  rear slope to a point over the tail root. They are what makes the fish nearly as tall as it is long.
- The surgeonfish's mark: a small white spine on each side of the tail root. A white ring round a dark pupil echoes it.
A Common: yellow, white and black, no pattern. The rider sits on the back in front of the fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Yellow Tang", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"yellow": "#F7D417", "white": "#F6F3E6", "black": "#2A2622"}
SEAT = (-3, 8, 2.6)
FRAME, ORTHO = 1.1, 16.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["yellow"]}]
SWIM = {"chain": ["Body", "Rear", "Tail"], "amplitudes": [7, 16], "phaseStep": 0.9, "headCounter": 2}


def slab(p, x0, x1, n, bot, top):
    """a length of body: lighter on the top row, darker on the bottom row; stepped corners where it is thick"""
    steps = [(1, 1)] if n >= 2 else []
    p.hull(x0, x1, n, bot, top, "yellow", steps, steps)
    p.paint_sym(x0, x1, n, top - 1, top, "yellow+")
    p.paint_sym(x0, x1, n, bot, bot + 1, "yellow-")


def build(m):
    body = m.part("Body", (3, 0, 0))
    # the disc's middle: the tallest, widest slab. The rider sits on it. The belly is a step shallower at the front
    slab(body, -5, -2, 2, -6, 8)
    slab(body, -2, 3, 2, -8, 8)

    # the face: one big block on its corner. From the snout corner A the forehead runs up and back, steeply, to the top
    # front corner of the back; the chin runs down and back, square to it, to the bottom of the slab's front
    ax, az, lean = -10.5, -2.0, math.atan2(9.9, 5.43)
    ux, uz = math.cos(lean), math.sin(lean)  # along the forehead
    vx, vz = uz, -ux  # along the chin
    long, deep = (7.9 - az) / uz, 6.5
    body.beam((ax + vx * deep / 2, 0, az + vz * deep / 2), (ax + ux * long + vx * deep / 2, 0, az + uz * long + vz * deep / 2),
              2.6, deep, "yellow", flat="z")
    # the snout: two small blocks in a chain out of the corner, each a little nose-down, smaller, starting inside the last
    body.beam((-8.0, 0, -1.8), (-11.6, 0, -2.15), 2.0, 2.8, "yellow", flat="z")
    body.beam((-11.0, 0, -2.1), (-12.8, 0, -2.3), 1.3, 1.7, "yellow", flat="z")
    mouth = (-0.45, 0.45, -2.85, -2.45)  # the small mouth: a darker lip standing a little out of the tip
    body.block(-13.0, mouth, -12.2, mouth, "yellow-")
    # the eye, high on the face under the forehead: a white ring and a dark pupil standing a little out of it
    ring = (1.1, 1.6, 0.5, 2.7)
    body.block(-7.7, ring, -5.5, ring, "white", mirror=True)
    pupil = (1.4, 1.9, 1.0, 2.2)
    body.block(-7.25, pupil, -6.05, pupil, "black", mirror=True)

    # the seat: on the back in front of the fin, a shallow slot either side for the rider's legs
    body.dent(-4, -2, 2, 3, 6, "yellow-")

    # the back fin and the belly fin, the same shape: a first box leaning back out of the slab
    for s in (1, -1):
        body.beam((1.0, 0, 6.0 * s), (5.8, 0, 9.36 * s), 4.4, 1.3, "yellow")
    # the side fins: one small blade each, swept out and back; one small fin under the breast, lying down the belly's step
    body.beam((-4.2, 1.9, -1.6), (-1.4, 3.8, -2.6), 2.4, 0.5, "yellow-", mirror=True)
    body.beam((-4.0, 0, -5.0), (-1.4, 0, -8.2), 1.8, 0.6, "yellow-")

    # the rear: two broad steps down to a thin tail root, on a joint
    rear = m.part("Rear", (3, 0, 0), "Body")
    slab(rear, 3, 6, 1, -6, 6)
    slab(rear, 6, 8, 1, -4, 4)
    rear.sym(8, 10, 0, -1, 1, "yellow")
    rear.sym(2, 3, 0, -4, 4, "yellow-")  # the sleeve into the slab in front
    # the second box of each tall fin: smaller and thinner, lying down the rear slope to a point over the tail root
    for s in (1, -1):
        rear.beam((4.193, 0, 7.217 * s), (8.772, 0, 4.355 * s), 3.88, 0.9, "yellow-")
    # the surgeonfish's spine: a small white mark on each side of the tail's root
    spine = (0.3, 0.8, -0.4, 0.4)
    rear.block(8.2, spine, 9.8, spine, "white", mirror=True)

    # the tail, on its own joint: a short stem out of the tail root into a fan plate, and two short lobes out of the
    # plate, spreading a little, with a shallow notch between them
    tail = m.part("Tail", (10, 0, 0), "Rear")
    tail.beam((9.4, 0, 0), (10.9, 0, 0), 1.4, 0.4, "yellow")
    tail.beam((10.2, 0, 0), (12.4, 0, 0), 5.0, 0.7, "yellow")
    for s in (1, -1):
        tail.beam((11.4, 0, 1.35 * s), (14.6, 0, 2.2 * s), 2.3, 0.4, "yellow-")
