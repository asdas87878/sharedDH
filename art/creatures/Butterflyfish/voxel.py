"""The Butterflyfish (zone 1's Common: a small reef butterflyfish) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md).
Its idea: a tall, thin disc with a little pointed snout, and a black line through the eye.
- The body is four short slabs, fourteen cubes tall in the middle and only five wide: face, shoulder, the disc's
  plateau, and a lower, narrower slab behind it. A thin stalk carries the tail.
- The forehead is one long block tilted steeply, from the snout right up to the top of the back; the snout is two small
  blocks in a chain that start inside it. So the face is one steep line, as the real fish's is.
- The back fin and the belly fin are two angled boxes each, on the rear slab only: the first carries the plateau's line
  on, the second turns in to the stalk. They round off the disc and leave the seat clear.
- Yellow back and fins, white belly. A thin black band runs down through the eye and over the forehead; one thin dark
  stripe goes round the tail stalk.
The rider sits on the plateau in front of the back fin, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Butterflyfish", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"yellow": "#F6C92B", "white": "#F4F1E6", "black": "#2B2A30"}
SEAT = (-1.5, 7, 2.6)
FRAME, ORTHO = 0.95, 12.5
SWIM = {"chain": ["Head", "Rear", "Stalk", "Tail"], "amplitudes": [7, 10, 18], "phaseStep": 0.9, "headCounter": 2}
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["yellow"]}]

STEP = [(1, 1)]
BELLY = -1  # the white belly comes up to here, in one level line from the chin to the stalk


def slab(p, x0, x1, n, bot, top, steps=STEP):
    """a slice of the disc: one-step corners, yellow with a lighter top row, white below the belly line"""
    p.hull(x0, x1, n, bot, top, "yellow", steps, steps)
    if steps:
        p.paint_sym(x0, x1, n, top - 1, top, "yellow+")
    p.paint_sym(x0, x1, n, bot, BELLY, "white")
    p.paint_sym(x0, x1, n, bot, bot + 1, "white-")


def build(m):
    head = m.part("Head", (2, 0, 0))
    head.hull(-9, -7, 1, -3, 2, "yellow", (), STEP)  # the face: small and narrow, the eye on its side
    head.paint_sym(-9, -7, 1, -3, BELLY, "white")
    head.paint_sym(-9, -7, 1, -3, -2, "white-")
    slab(head, -7, -5, 2, -5, 4)  # the shoulder
    head.paint_sym(-7, -5, 2, 3, 4, "yellow")  # its top is no plateau: the forehead runs over it
    slab(head, -5, 2, 2, -7, 7)  # the plateau: the fish is tallest here, and the rider sits on it
    # the forehead: one long block tilted steeply from the snout up to the top of the back. Its top runs from
    # (-10.5, 0.3) to (-4.9, 6.8), and the block ends inside the plateau
    slope = 6.5 / 5.6

    def brow(x):
        return 0.3 + (x + 10.5) * slope

    head.beam((-9.667, 0, -0.418), (-4.067, 0, 6.082), 2.0, 2.2, "yellow", flat="z")
    # the snout: two small blocks in a chain, each a little nose-down, smaller than the last and starting inside it
    head.beam((-8.6, 0, -0.5), (-11.8, 0, -0.9), 1.6, 1.8, "yellow", flat="z")
    head.beam((-11.2, 0, -0.85), (-13.2, 0, -1.1), 1.0, 1.0, "yellow-", flat="z")
    # the black band: thin, down through the eye, and over the forehead in one line. It stops above the chin
    head.band(-8.4, -7.6, 1, -3, 2, "black", bottom=STEP, stop=-1.7)
    head.prism([(-8.4, 2.3), (-7.6, 2.3), (-7.6, brow(-7.6) + 0.3), (-8.4, brow(-8.4) + 0.3)], -1.3, 1.3, "black")
    # the eye: a pale ring standing out of the band, a dark pupil standing out of the ring
    ring = (1.2, 2.0, -0.3, 1.7)
    head.block(-8.8, ring, -7.2, ring, "white", mirror=True)
    pupil = (1.2, 2.2, 0.0, 1.4)
    head.block(-8.6, pupil, -7.4, pupil, "black", mirror=True)
    # the side fins: one small paddle each, swept back from the shoulder
    head.beam((-5.8, 1.9, -1.6), (-3.4, 3.6, -2.2), 2.2, 0.5, "yellow", mirror=True)
    head.dent(-3, -1, 2, 3, 6, "yellow-")  # the rider's leg slots

    # the rear slab: lower and narrower, a plain box, because the fins cover its top and its underside
    rear = m.part("Rear", (2, 0, 0), "Head")
    slab(rear, 2, 6, 1, -5, 5, ())
    rear.sym(1, 2, 1, -4, 4, "yellow-")  # the sleeve into the plateau
    # the back fin: two angled boxes. The first lies along the slab and carries the plateau's line on, dipping a little;
    # the second is smaller and thinner, starts inside it and turns down towards the stalk, so the disc's outline is an arc
    rear.beam((2.45, 0, 5.3), (5.4, 0, 4.9), 3.2, 1.4, "yellow")
    rear.beam((4.3, 0, 5.3), (6.9, 0, 3.7), 2.4, 0.8, "yellow-")
    # the belly fin: the same, a little smaller
    rear.beam((2.45, 0, -5.3), (5.2, 0, -4.95), 3.0, 1.4, "yellow")
    rear.beam((4.2, 0, -5.2), (6.6, 0, -3.7), 2.2, 0.8, "yellow-")

    # the tail stalk, with the one thin dark stripe round it
    stalk = m.part("Stalk", (6, 0, 0), "Rear")
    stalk.hull(6, 8, 1, -2, 2, "yellow", STEP, STEP)
    stalk.paint_sym(6, 8, 1, 1, 2, "yellow+")
    stalk.paint_sym(6, 8, 1, -2, -1, "yellow-")
    stalk.sym(5, 6, 0, -1, 1, "yellow-")
    stalk.band(6.6, 7.4, 1, -2, 2, "black", top=STEP, bottom=STEP)

    # the tail: a root block and two short lobes that open a little, like a fan
    tail = m.part("Tail", (8, 0, 0), "Stalk")
    tail.beam((7.5, 0, 0), (10.2, 0, 0), 3.4, 1.4, "yellow")
    tail.beam((9.0, 0, 0.4), (13.4, 0, 1.6), 2.6, 1.0, "yellow")
    tail.beam((9.0, 0, -0.4), (13.4, 0, -1.6), 2.6, 0.6, "yellow")
