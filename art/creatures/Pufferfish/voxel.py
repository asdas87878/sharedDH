"""The Pufferfish (zone 1's Common: a puffed-up puffer) for tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: a ball with a face. A round golden body, a pale belly, big friendly eyes, a little beak, short spines.
- The body is one rigid ball made of five slabs: a wide middle (the plateau the rider sits on), a broad step down to a
  shoulder in front and behind, and another to the face and the rump. Its corners are cut in broad steps too.
- The pale belly's edge is one level line round the whole animal.
- Short white spines (small pyramids) stand on the steps of the back and on the sides, pointing the way their face
  points. None on the middle of the plateau: that is the seat.
- The eyes are big: a cream square on the side of the front shoulder with a dark pupil, set forward. No brow.
- The mouth is a small muzzle with a two-piece white beak.
- Small fins: two side paddles, a dorsal and an anal fin far back, a small forked tail on a short stalk. Each is on its
  own joint, because a puffer swims by fluttering them, not by bending."""
import math

NAME, ZONE, RARITY = "Pufferfish", "ZONE 1 / SHALLOWS", "COMMON"
U = 0.35
PALETTE = {"back": "#E8B63A", "belly": "#FBF3DC", "white": "#FFFDF2", "black": "#23262B", "mouth": "#7A3B2E"}
SEAT = (0, 8, 6.5)
FRAME, ORTHO = 1.2, 17.0  # it is nearly as wide as it is long: the top view needs the room
SHADE = 0.86  # the darker tones stay soft: the belly's underside is in shadow anyway
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["back"]}]
BELLY = -1  # the height of the pale belly's edge, the same on every slab


def pose(parts, phase):
    """a puffer's swim: the ball hardly bends. It wobbles a little, the tail wags, and the small fins flutter twice a beat"""
    parts["Body"].rotation_euler.z = math.radians(3) * math.sin(phase + math.pi)
    parts["Tail"].rotation_euler.z = math.radians(24) * math.sin(phase - 0.9)
    parts["Dorsal"].rotation_euler.x = math.radians(16) * math.sin(2 * phase)
    parts["Anal"].rotation_euler.x = -math.radians(16) * math.sin(2 * phase)
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.z = side * math.radians(14) * math.sin(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(6) * math.sin(2 * phase - 1.2)


def slab(p, x0, x1, n, bot, top, steps):
    """a slab of the ball: stepped corners, a lighter top step, a pale belly with a darker bottom step"""
    p.hull(x0, x1, n, bot, top, "back", steps, steps)
    rows = steps[0][1]
    p.paint_sym(x0, x1, n, top - rows, top, "back+")
    p.paint_sym(x0, x1, n, bot, BELLY, "belly")
    p.paint_sym(x0, x1, n, bot, bot + rows, "belly-")


def spine(p, at, way, size=1.2, tall=1.2, mirror=True):
    """a short spine: a small pyramid standing on the surface at `at` (the middle of its base), its base sunk in.
    way: "z" up, "y" out to the side, "-x" forward, "x" back"""
    x, y, z = at
    h, s = size / 2, 0.2
    if way == "z":
        base, apex = [(x - h, y - h, z - s), (x + h, y - h, z - s), (x + h, y + h, z - s), (x - h, y + h, z - s)], (x, y, z + tall)
    elif way == "y":
        base, apex = [(x - h, y - s, z - h), (x + h, y - s, z - h), (x + h, y - s, z + h), (x - h, y - s, z + h)], (x, y + tall, z)
    else:
        d = -1 if way == "-x" else 1
        bx = x - d * s
        base, apex = [(bx, y - h, z - h), (bx, y + h, z - h), (bx, y + h, z + h), (bx, y - h, z + h)], (x + d * tall, y, z)
    p.spike(base, apex, "white", mirror and y != 0)


def build(m):
    body = m.part("Body", (0, 0, 0))
    slab(body, -5, 5, 10, -8, 8, [(4, 2), (2, 2)])  # the middle: the plateau of the back, 13 cubes wide
    slab(body, -9, -5, 8, -6, 6, [(2, 2)])  # the front shoulder: the eyes sit on its sides
    slab(body, 5, 8, 8, -6, 6, [(2, 2)])  # the rear shoulder
    slab(body, -11, -9, 6, -4, 4, [(1, 1)])  # the face
    slab(body, 8, 10, 5, -4, 4, [(1, 1)])  # the rump
    # the muzzle and the beak: two white plates, the upper one a little longer and wider, a dark gap between them
    body.sym(-12, -11, 2, -3, 1, "back")  # golden all round, so the white beak stands out from the pale chin
    upper, lower, gap = (-1.5, 1.5, -1.3, 0.1), (-1.3, 1.3, -2.6, -1.6), (-1.1, 1.1, -1.6, -1.3)
    body.block(-13.2, upper, -11.8, upper, "white")
    body.block(-12.9, lower, -11.8, lower, "white")
    body.block(-12.6, gap, -11.8, gap, "mouth")
    # the eyes: a big cream square on the shoulder's side, a dark pupil standing out of it, set forward
    ring, pupil = (8.3, 9.0, 0.1, 3.7), (8.8, 9.35, 0.8, 3.0)
    body.block(-8.7, ring, -5.3, ring, "white", mirror=True)
    body.block(-8.2, pupil, -6.3, pupil, "black", mirror=True)

    # the spines. On the middle: the two steps of the back, the side, the corners of the plateau (the seat stays clear)
    for x in (-3.5, 0.0, 3.5):
        spine(body, (x, 7.5, 6), "z")
    for x in (-1.75, 1.75):
        spine(body, (x, 9.5, 4), "z")
    for x, z in ((-3.5, 2.6), (0.3, 2.6), (4.0, 2.6), (2.6, 0.3)):
        spine(body, (x, 10.5, z), "y")
    for x in (-3.8, 3.8):
        spine(body, (x, 5.0, 8), "z")
    spine(body, (-5, 3.5, 7), "-x")  # on the plateau's front and rear walls
    spine(body, (5, 3.5, 7), "x")
    # the front shoulder and the face
    spine(body, (-7, 0, 6), "z")
    spine(body, (-7, 4.5, 6), "z")
    spine(body, (-9, 0, 5), "-x")
    spine(body, (-10, 3.0, 4), "z")
    # the rear shoulder and the rump
    spine(body, (6.5, 0, 6), "z")
    spine(body, (6.5, 4.5, 6), "z")
    spine(body, (6.5, 7.5, 4), "z")
    spine(body, (6.5, 8.5, 1), "y")
    spine(body, (9, 5.5, 1), "y")

    # the side fins, each on its own joint: an upright paddle of two boxes that sweeps back and out, the second smaller
    # and thinner, starting inside the first
    for name, s in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-3, 10.5 * s, -0.6), "Body")
        fin.beam((-4.0, 9.3 * s, -0.5), (-0.5, 11.8 * s, -0.8), 3.0, 0.9, "back-")
        fin.beam((-1.2, 11.3 * s, -0.75), (0.6, 12.6 * s, -0.9), 2.2, 0.5, "back-")

    # the dorsal and the anal fin, far back, leaning back: two boxes each
    dorsal = m.part("Dorsal", (8.6, 0, 4.5), "Body")
    dorsal.beam((8.3, 0, 4.2), (10.6, 0, 6.4), 2.8, 0.9, "back-")
    dorsal.beam((10.0, 0, 5.9), (11.4, 0, 7.2), 2.0, 0.5, "back-")
    anal = m.part("Anal", (8.6, 0, -4.5), "Body")
    anal.beam((8.3, 0, -4.2), (10.5, 0, -6.2), 2.6, 0.9, "belly-")
    anal.beam((9.9, 0, -5.7), (11.2, 0, -6.9), 1.8, 0.5, "belly-")

    # the tail, on its own joint: a short stalk and a small fan of two broad lobes with a notch between, each a box and a smaller tip
    tail = m.part("Tail", (10, 0, 0), "Body")
    tail.hull(10, 12, 2, -2, 2, "back", [(1, 1)], [(1, 1)])
    tail.paint_sym(10, 12, 2, -2, -1, "belly")
    tail.sym(9, 10, 1, -1, 1, "back-")  # the sleeve, inside the rump
    tail.beam((11.2, 0, 0.5), (14.2, 0, 1.9), 2.6, 1.2, "back-")
    tail.beam((13.5, 0, 1.57), (15.0, 0, 2.27), 2.0, 0.5, "back-")
    tail.beam((11.2, 0, -0.5), (14.2, 0, -1.9), 2.6, 0.8, "back-")
    tail.beam((13.5, 0, -1.57), (15.0, 0, -2.27), 2.0, 0.5, "back-")
