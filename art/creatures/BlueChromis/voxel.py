"""The Blue Chromis (zone 1's Common: a small electric-blue reef fish with a deeply forked tail) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: one plain bright-blue oval and a big forked tail with dark tips. A Common, so nothing else.
- The body is four slabs: the head, the biggest slab a cube taller and deeper, then two more each a cube smaller all
  round, so the side view is an oval. A paler belly whose edge is one level line. The biggest slab's flat top is the seat.
- The face is two blocks in a chain on the head's middle line, coming to a blunt point; a pale chin plate, a small dark mouth.
- A big round eye: a cream ring and a dark pupil. No brow: it is a friendly fish.
- The dark back of the real fish is its dorsal fin, low and long with a taller point behind, and the tips of the tail.
- The tail is a root block and two long lobes, each in two boxes, on a joint of its own.
The rider sits on the biggest slab, behind the side fins, legs in a shallow slot either side."""
NAME, ZONE, RARITY = "Blue Chromis", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"blue": "#2488F2", "sky": "#74C6FA", "navy": "#1A2A55", "white": "#F4F1E4", "black": "#1E2024"}
SEAT = (-3, 5, 3.5)
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["blue"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "Tail"], "amplitudes": [4, 8, 13, 22], "phaseStep": 0.9, "headCounter": 2}
BELLY = -1  # the pale belly's edge: one level line down the whole fish


def slab(p, x0, x1, n, bot, top):
    """a length of body: one step cut from each corner, a lighter top row, pale from the belly line down"""
    steps = [(1, 1)] if n >= 2 else []
    p.hull(x0, x1, n, bot, top, "blue", steps, steps)
    p.paint_sym(x0, x1, n, top - 1, top, "blue+")
    p.paint_sym(x0, x1, n, bot, BELLY, "sky")


def build(m):
    head = m.part("Head", (-8, 0, 0.5))
    slab(head, -12, -8, 3, -3, 4)
    # the face: two blocks in a chain on the head's middle line, each tilted a little nose-down, the second smaller and
    # starting inside the first, and both taller than they are wide, so the face comes to a blunt point as a damselfish's does. A pale chin plate under the
    # first carries the belly forward; the mouth is a small dark line at the very front
    head.beam((-11.0, 0, 0.9), (-13.3, 0, 0.5), 4.2, 4.8, "blue", flat="z")
    head.beam((-11.0, 0, -1.85), (-13.3, 0, -2.25), 3.6, 0.7, "sky", flat="z")
    head.beam((-12.6, 0, 0.55), (-14.2, 0, 0.25), 2.4, 3.0, "blue", flat="z")
    mouth = (-0.75, 0.75, -0.35, -0.05)
    head.block(-14.33, mouth, -13.6, mouth, "navy")
    # the eye: big and round, a cream ring and a dark pupil, each a little proud of the last
    ring = (3.3, 3.8, 0.1, 2.3)
    head.block(-11.3, ring, -9.1, ring, "white", mirror=True)
    pupil = (3.65, 4.1, 0.55, 1.85)
    head.block(-10.85, pupil, -9.55, pupil, "black", mirror=True)

    s1 = m.part("S1", (-8, 0, 0.5), "Head")
    slab(s1, -8, -1, 3, -4, 5)  # the biggest slab: a cube taller and a cube deeper than the head
    s1.sym(-9, -8, 1, -2, 3, "blue-")  # sleeves: a cube into the piece in front, clear of both pieces' corner steps
    s1.dent(-4, -2, 3, 0, 3, "blue-")  # the seat's leg slots
    # the side fins: two boxes swept back and a little down, the first rooted deep in the side
    s1.beam((-6.9, 2.6, -1.3), (-4.9, 4.9, -2.0), 2.2, 0.85, "blue", flat="z", mirror=True)
    s1.beam((-5.5, 4.3, -1.82), (-4.1, 5.8, -2.3), 1.5, 0.35, "blue-", flat="z", mirror=True)

    s2 = m.part("S2", (-1, 0, 0.5), "S1")
    slab(s2, -1, 4, 2, -3, 4)
    s2.sym(-2, -1, 0, -2, 3, "blue-")
    # the dorsal fin, behind the rider: a long low box sunk in the back, and a taller point behind it. Dark, like the
    # real fish's back
    s2.beam((-0.4, 0, 4.15), (3.6, 0, 4.95), 2.2, 1.0, "navy")
    s2.beam((1.9, 0, 4.6), (4.6, 0, 5.8), 1.6, 0.6, "navy")
    s2.beam((1.2, 0, -2.1), (4.0, 0, -3.7), 1.8, 0.7, "blue-")  # the anal fin

    s3 = m.part("S3", (4, 0, 0.5), "S2")
    slab(s3, 4, 7, 1, -2, 3)  # the tail stock
    s3.sym(3, 4, 0, -1, 2, "blue-")

    # the tail, on its own joint: a root block and two long lobes, each in two boxes, the second smaller, thinner and dark
    tail = m.part("Tail", (7, 0, 0.5), "S3")
    tail.beam((6.6, 0, 0.5), (8.7, 0, 0.5), 3.4, 1.7, "blue")
    tail.beam((7.8, 0, 1.1), (10.8, 0, 3.5), 2.6, 1.2, "blue")
    tail.beam((10.0, 0, 2.9), (13.0, 0, 5.1), 1.8, 0.7, "navy")
    tail.beam((7.8, 0, -0.1), (10.8, 0, -2.5), 2.6, 0.8, "blue")
    tail.beam((10.0, 0, -1.9), (13.0, 0, -4.1), 1.8, 0.4, "navy")
