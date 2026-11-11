"""The Coral Dragon (zone 2's Secret: a sea dragon grown out of the reef) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed by docs/style/05-rarity-look.md.
Its idea: the reef got up and swam away. A long warm-cream dragon whose every extra is a coral: staghorn antlers,
brain-coral on its back, sea fans for a crest, fins and a tail.
Its ways to be more than a Mythic: material (it is made of coral), scale (antlers taller than its head, fins like
wings) and light (the polyps at the ends of the antlers, echoed once at the tail).
- The body is sixteen slices on joints. The head is carried high on a slim neck that dips behind the skull; the back
  then climbs to a hump over a deep chest, where the rider sits, and falls a cube at a time to a thin tail, while the
  belly makes one broad arc under it. Two-step corners where it is thick, one at the ends.
- One thin teal line runs from the brow to the tail, on the step under the back, so it follows the back's own line; the
  belly is paler.
- The head is a dragon's: a tall skull, a snout of three blocks stepping down, an overbite with fangs, a jowl where the
  jaw hinges, a heavy coral brow on a dark eye. The jaw is its own part.
- The antlers are staghorn coral in big blocks: a trunk in a collar, a tine forward, a tine out, a beam up and back,
  each ending in a soft glowing polyp.
- Along the back: three sea fans on the neck (the tallest by the head), nothing where the rider sits, three brain-corals
  behind the rider (two lobes and a groove each), then six sea fans down the tail.
- The front fins are sea fans as wide as wings, each on a joint; the tail is a fan of three rays on a joint of its own.
The rider sits on the chest, in front of the brain-corals, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Coral Dragon", "ZONE 2 / CORAL REEF", "SECRET"
U = 0.45
PALETTE = {"cream": "#F2E2C4", "belly": "#FBF4E4", "pink": "#EE7F98", "orange": "#F39A4A", "teal": "#2FB3A6", "polyp": "#FFD3DC",
           "black": "#2A2430", "mouth": "#7A2E3F", "gum": "#B5566A", "tooth": "#FFFFFF"}
SEAT = (-6.5, 10, 5.5)
GLOW = {"polyp": 0.6}  # the polyps at the ends of the antlers and of the tail's two lobes
HZ = 5  # how high the head is carried above the body's line, in cubes
LIGHTS = [("Head", (-21.0, 7.4, 17.2 + HZ), "#FFA9BC", 60, 0.6)]
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["cream"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.0, 44.0, 50.0

# the body: each slice is (length, cubes out, bottom, top). The neck is slim and dips behind the skull; the back climbs
# to a hump over the chest and falls to the tail a cube at a time; the belly is one broad arc
SLICES = ((3, 3, 1, 7), (3, 3, 0, 7), (4, 4, -1, 7), (4, 4, -2, 8), (4, 5, -3, 9), (5, 5, -4, 10), (5, 5, -4, 10), (4, 5, -4, 9),
          (4, 4, -3, 9), (4, 4, -3, 8), (4, 4, -2, 7), (4, 3, -2, 6), (3, 3, -1, 5), (3, 3, -1, 4), (3, 2, -1, 4), (3, 2, -1, 3))
BELLY = (3, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1)  # how high the pale belly comes on each slice: one level line
BODY_FROM = -27
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [1.5, 1.5, 2, 2, 2.5, 2.5, 3, 3, 3.5, 4, 4.5, 5, 5.5, 6, 7, 8, 11]


def pose(parts, phase):
    """a serpent's swim: the wave runs down the chain from side to side and grows toward the tail. The head turns a
    little against it, the jaw opens and shuts once a beat, the fins beat slowly like wings"""
    parts["Head"].rotation_euler.z = math.radians(2.0) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.42 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(7) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.x = side * math.radians(13) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.8)


def top_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 5 else [(1, 1)]


def slab(p, x0, x1, n, bot, top, belly):
    """a slice of body: stepped corners, warm cream (lighter on the top row), a pale belly, the teal line"""
    p.hull(x0, x1, n, bot, top, "cream", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "cream+")
    p.paint_sym(x0, x1, n, top - 2, top - 1, "teal")  # the line: on the step under the back, so it follows the back
    p.paint_sym(x0, x1, n, bot, belly, "belly")
    p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def lift(part, dz):
    """move a finished part up by dz cubes (the head is drawn level with the body's line, then carried high)"""
    part.cells = {(i, j, k + dz): c for (i, j, k), c in part.cells.items()}
    part.shapes = [([(x, y, z + dz) for x, y, z in verts], faces, colour) for verts, faces, colour in part.shapes]


def lerp(p0, p1, t):
    return tuple(a + (b - a) * t for a, b in zip(p0, p1))


def bulb(p, p0, p1, wide, thick, colour, flat="y", mirror=False):
    """a polyp: a short block a little bigger than the end of the piece from p0 to p1, capping it"""
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(v * v for v in d))
    a = tuple(e - v / length * 0.6 for e, v in zip(p1, d))
    b = tuple(e + v / length * 1.0 for e, v in zip(p1, d))
    p.beam(a, b, wide + 0.5, thick + 0.5, colour, flat=flat, mirror=mirror)


def fan(p, x, top, h, colour):
    """a sea fan standing on the back: a plate leaning back and a smaller, thinner, lighter one out of its top"""
    wide = 0.6 * h + 0.8
    p.beam((x, 0, top - 1.3), (x + 0.3 * h, 0, top + 0.72 * h), wide, 0.9, colour)
    p.beam((x + 0.19 * h, 0, top + 0.45 * h), (x + 0.5 * h, 0, top + h + 0.3), 0.7 * wide, 0.55, colour + "+")


def brain(p, x0, x1, n, top, tall):
    """a brain-coral: a low dome of cubes in two lobes, a smaller cap on it, and the groove between the lobes"""
    p.sym(x0, x1, n, top, top + tall, "pink")
    p.sym(x0 + 1, x1 - 1, n - 1, top + tall, top + tall + 1, "pink+")
    p.paint(x0, x1, 0, 1, top + tall - 1, top + tall + 1, "pink-")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, HZ))
    # the skull: a tall box with two-step corners, pale under the jaw line; a jowl under its back half, where the jaw
    # hinges. The neck behind it is a size smaller all round, so the head stands out from it
    head.hull(-34, BODY_FROM, 4, -4, 5, "cream", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-34, BODY_FROM, 4, 4, 5, "cream+")
    head.paint_sym(-34, BODY_FROM, 4, -4, -2, "belly")
    head.sym(-34, -31, 3, -5, -4, "belly-")
    head.paint_sym(-29, BODY_FROM, 4, 0, 1, "teal")  # the teal line starts behind the brow, level with the neck's
    # the snout: three blocks in a chain, each tilted a little nose-down, lower and narrower than the last, so the
    # forehead steps down to the nose while the lip stays level. A pale lip plate under each, a thin gum line inside
    # its edge; the first two have a lighter plate on top (the bridge of the nose)
    blocks = ((-33.0, -37.0, 1.3, 0.9, 7.6, 4.2, 4.0, -33.0, -33.0), (-36.2, -40.0, 0.8, 0.5, 5.4, 3.2, 2.8, -37.2, -37.3),
              (-39.3, -42.2, 0.4, 0.3, 3.8, 2.4, 2.2, -40.4, -40.3))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.8

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "cream", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "belly", flat="z")
        if plate:
            rise = thick / 2 + 0.2
            head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.5, "cream+",
                      flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                  flat="z")
    nostril = (1.6, 2.05, 0.5, 1.0)
    head.block(-41.6, nostril, -40.9, nostril, "black", mirror=True)
    # the dark inside of the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    inside = (-1.85, 1.85, -3.4, -1.2)
    head.block(-36.5, inside, -33.5, inside, "mouth")
    inside = (-1.4, 1.4, -3.15, -1.45)
    head.block(-39.2, inside, -36.3, inside, "mouth")
    # the upper teeth, bases sunk into the gum: the second pair are the fangs
    for k, x, y, long in ((0, -34.3, 2.85, 0.85), (0, -35.8, 2.85, 1.3), (1, -37.8, 1.8, 0.85), (1, -39.2, 1.8, 0.8), (2, -41.3, 1.0, 0.8)):
        head.tooth(x, y, lip_bottom(k, x) - 0.05, 0.7, long, "tooth")
    # the eye: a teal socket on the skull's side, a dark pupil standing out of it, and a heavy coral brow that sits on
    # the eye, level, and covers the top of its square
    socket = (4.38, 4.9, 0.15, 2.55)
    head.block(-32.9, socket, -29.9, socket, "teal", mirror=True)
    pupil = (4.78, 5.25, 0.45, 1.8)
    head.block(-32.2, pupil, -30.6, pupil, "black", mirror=True)
    head.beam((-33.5, 4.7, 2.2), (-29.2, 4.7, 2.48), 0.9, 1.7, "pink", mirror=True)

    # the antlers: staghorn coral in big blocks. A trunk in a darker collar, a tine forward, a tine outward, and a beam
    # that goes on up and back; every end carries a polyp
    root, fork = (-30.5, 2.2, 2.0), (-26.5, 5.4, 11.0)
    head.beam(root, lerp(root, fork, 0.42), 3.4, 3.0, "pink-", mirror=True)
    head.beam(root, fork, 2.8, 2.4, "pink", mirror=True)
    for at, end, wide, thick in ((0.55, (-34.0, 6.6, 13.2), 1.7, 1.5), (0.7, (-28.5, 10.5, 13.0), 1.6, 1.4), (0.85, (-21.0, 7.4, 17.0), 1.8, 1.5)):
        start = lerp(root, fork, at)
        head.beam(start, end, wide, thick, "pink+" if at < 0.8 else "pink", mirror=True)
        bulb(head, start, end, wide, thick, "polyp", mirror=True)

    # the lower jaw, on its own joint: two boxes, the smaller in front, narrower than the lip above (an overbite)
    jaw = m.part("Jaw", (-32.5, 0, -3.5 + HZ), "Head")
    jaw.beam((-32.8, 0, -3.7), (-37.0, 0, -3.75), 6.0, 1.4, "belly", flat="z")
    jaw.beam((-36.4, 0, -3.75), (-40.4, 0, -3.6), 4.2, 1.0, "belly", flat="z")
    jaw.tooth(-35.0, 2.3, -3.1, 0.6, -0.6, "tooth")
    jaw.tooth(-38.4, 1.5, -3.25, 0.6, -0.6, "tooth")
    lift(head, HZ)
    lift(jaw, HZ)
    skull = (4, -4 + HZ, 5 + HZ)

    # the body: sixteen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top, BELLY[i])
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else skull
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)) if i else 2)
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if i else 1)
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "cream-")

    # the seat: on the chest, a shallow slot either side for the rider's legs, under the teal line
    segs[5].dent(-8, -5, 5, 6, 8, "cream-")

    # along the back. Sea fans on the neck, the tallest by the head; nothing at the seat; three brain-corals behind the
    # rider, the middle one the biggest; then sea fans down the tail, each smaller than the last
    for i, h in ((1, 4.6), (2, 4.0), (3, 3.2), (9, 3.8), (10, 3.4), (11, 3.0), (12, 2.6), (13, 2.2), (14, 1.8)):
        x0, x1, n, bot, top = spans[i]
        fan(segs[i], (x0 + x1) / 2 - 0.25 * h, top, h, "orange")
    brain(segs[6], -3, 0, 2, 10, 1)
    brain(segs[7], 1, 5, 3, 9, 2)
    brain(segs[8], 6, 9, 2, 9, 1)

    # the front fins: sea fans as wide as wings, each on its own joint. A plate out and back from the shoulder in a
    # darker collar, a second out of its end, a thin pale tip
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-10.4, 5.0 * side, -0.9), "S5")

        def at(p):
            return (p[0], p[1] * side, p[2])

        a, b = (-10.4, 2.8, -0.6), (-6.2, 9.8, -1.8)
        fin.beam(at(lerp(a, b, -0.05)), at(lerp(a, b, 0.5)), 5.2, 1.6, "teal-", flat="z")
        fin.beam(at(a), at(b), 4.6, 1.2, "teal", flat="z")
        c = (-1.6, 14.0, -2.6)
        fin.beam(at(lerp(a, b, 0.82)), at(c), 3.4, 0.8, "teal", flat="z")
        fin.beam(at(lerp(lerp(a, b, 0.82), c, 0.8)), at((1.9, 16.5, -3.1)), 2.2, 0.45, "teal+", flat="z")

    # the tail, on its own joint: a short cream stock, then a fan of three rays: a long upper lobe and a shorter lower
    # one, each in two boxes and ending in a polyp (the antlers' echo), and a plain ray between them
    tail = m.part("Tail", (end, 0, 1), f"S{len(SLICES)}")
    tail.beam((end - 0.7, 0, 1), (end + 3.0, 0, 1), 3.6, 2.0, "cream")
    tail.beam((end + 1.8, 0, 1), (end + 8.0, 0, 1), 2.6, 0.6, "teal-")
    for a, b, c, w, thick in (((end + 1.6, 0, 1.5), (end + 6.8, 0, 7.2), (end + 9.4, 0, 10.2), 3.4, 1.2),
                              ((end + 1.6, 0, 0.5), (end + 6.0, 0, -4.0), (end + 8.2, 0, -6.4), 3.0, 0.9)):
        tail.beam(a, b, w, thick, "teal")
        start = lerp(a, b, 0.82)
        tail.beam(start, c, w - 1.0, thick - 0.35, "teal+")
        bulb(tail, start, c, w - 1.0, thick - 0.35, "polyp")
