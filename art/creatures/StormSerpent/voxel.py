"""The Storm Serpent (zone 5's Secret: an invented sea serpent made of storm) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed by docs/style/05-rarity-look.md.
Its idea, which is its name: a storm cloud drawn out into a serpent, with the lightning still in it.
Its ways (workout 5): light with a source (the lightning), parts with no business being there (spines, horns and a tail
shaped like bolts), and length.
- The body is seventeen slices on joints, slate blue over a pale cloud belly. The back is nearly level; the belly is a
  keel that sweeps down from the throat to a wide chest and up again to the tail, so head and tail are carried high.
  Each outline (back, belly, width) steps one cube at a time.
- One jagged line of light runs down each flank: one straight stroke to a slice, up and down in turn, so the bolt is
  whole when the body is straight and breaks at the joints as it swims. Under the rider it runs low and level.
- A crest of bolt spines: each a dark root leaning back and a thinner blade of light set forward on it and kinked back.
  The biggest stands on the skull with a fan behind it; none at the seat; then one to every other slice, shrinking to
  the tail. Past the first spine, each horn and each end of the tail a loose chip of light floats: the bolt jumps a gap.
- The head is a viper's wedge: a skull wider than the neck, a snout of three blocks stepping down and in, two horns
  swept back and out like bolts (so it is an arrowhead from above), a scowling brow on a white eye, two long fangs.
- The tail forks like a bolt: two lobes, each steep, then flat, then steep again, ending in light.
It swims side to side, as a sea snake does. The rider sits on the shoulders, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Storm Serpent", "ZONE 5 / OPEN BLUE", "SECRET"
U = 0.45
PALETTE = {"slate": "#4C5C7E", "cloud": "#B7C1D2", "bolt": "#FFF1A0", "eye": "#FFFFFF", "black": "#1B1E2C", "mouth": "#35284A",
           "tooth": "#FFFFFF"}
SEAT = (-15.5, 5, 4.6)
GLOW = {"bolt": 0.7}  # the lightning: the flank lines, the blades of the spines, the ends of the horns and of the tail
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["slate"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.2, 46.0, 52.0

# the body: each slice is (length, cubes out, bottom, top, how high the pale belly comes). The back is nearly level and
# steps down from the head; the belly is a keel: it sweeps down from the throat to the chest and up again to the tail,
# so the head and the tail are carried high and the middle hangs
SLICES = ((3, 3, 0, 6, 2), (4, 3, -1, 6, 1), (4, 4, -2, 6, 0), (4, 4, -3, 5, -1), (5, 4, -4, 5, -1), (5, 5, -5, 5, -2),
          (5, 5, -5, 5, -2), (5, 4, -4, 5, -1), (4, 4, -4, 4, -1), (4, 4, -3, 4, -1), (4, 3, -3, 4, -1), (4, 3, -2, 4, 0),
          (3, 3, -1, 4, 0), (3, 2, -1, 4, 0), (3, 2, 0, 4, 1), (3, 2, 1, 5, 2), (3, 1, 2, 5, 3))
HZ, TZ = 3, 3  # how high the head and the tail are carried
BODY_FROM = -33
SEAT_SLICE = 4
# the crest: the size of the spine on each slice (0: none). A fan of them behind the head, shrinking to a small one in
# front of the rider like a pommel; none under the rider; then one to every other slice, big, shrinking to the tail
SPINES = (1.2, 1.0, 0.8, 0.6, 0, 1.3, 0, 1.2, 0, 1.1, 0, 1.0, 0, 0.85, 0, 0.7, 0)
# the flank line: at each joint it is high (H) or low (L); it stays low right through the seat
ZIG = "LHLHLLHLHLHLHLHLHL"
STROKE = 0.35  # half the line's height
FLOATING = ["Sparks", "TailSparks"]  # the bolts jump a gap: one loose chip of light past each horn, the first spine, the tail's ends
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 12]


def pose(parts, phase):
    """a sea snake's swim: the wave runs down the chain from side to side, small at the shoulders where the rider sits,
    wide at the tail. The head turns a little against it"""
    parts["Head"].rotation_euler.z = math.radians(3) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))


def top_steps(n):
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n >= 3 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def wall(n, bot, top):
    """the flat side of a slice, between its corner steps"""
    return bot + len(bottom_steps(n)), top - len(top_steps(n))


def slab(p, x0, x1, n, bot, top, edge):
    """a slice of body: stepped corners, slate (lighter on the top row), a pale belly up to `edge`"""
    p.hull(x0, x1, n, bot, top, "slate", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "slate+")
    p.paint_sym(x0, x1, n, bot, edge, "cloud")
    if bottom_steps(n):
        p.paint_sym(x0, x1, n, bot, bot + 1, "cloud-")


def bolt_spine(p, x, top, s):
    """a spine like a bolt: a dark root leaning back, and a thinner blade of light that starts inside it, set forward,
    and leans back further"""
    thick = 1.3 if s >= 1.2 else (1.1 if s >= 0.8 else 0.9)
    p.beam((x, 0, top - 0.7), (x + 1.3 * s, 0, top + 2.0 * s), 1.9 * s, thick, "slate-")
    p.beam((x + 0.75 * s, 0, top + 1.5 * s), (x + 2.6 * s, 0, top + 3.6 * s), 1.0 * s, thick - 0.5, "bolt")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, HZ))
    # the skull: wider than the neck behind it, pale under the jaw line
    skull = (4, HZ - 3, HZ + 4)
    head.hull(-40, BODY_FROM, 4, HZ - 3, HZ + 4, "slate", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-40, BODY_FROM, 4, HZ + 3, HZ + 4, "slate+")
    head.paint_sym(-40, BODY_FROM, 4, HZ - 3, HZ - 1, "cloud")
    head.paint_sym(-40, BODY_FROM, 4, HZ - 3, HZ - 2, "cloud-")
    # the snout: three blocks in a chain, each tilted nose-down, a step lower and narrower than the last, each with a
    # pale lip plate underneath; the first two have a lighter plate on top, which starts past the end of the block before
    blocks = ((-39.5, -43.0, 1.1, 0.7, 7.4, 3.4, 4.4, -39.5), (-42.4, -45.4, 0.75, 0.35, 5.6, 2.7, 3.0, -43.8),
              (-44.8, -47.0, 0.4, 0.15, 3.8, 2.0, 0.0, 0.0))
    blocks = tuple((b[0], b[1], b[2] + HZ, b[3] + HZ) + b[4:] for b in blocks)

    def lip_bottom(k, x):
        x0, x1, z0, z1, _, thick = blocks[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) - thick / 2 - 0.8

    for x0, x1, z0, z1, wide, thick, plate, plate_from in blocks:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "slate", flat="z")
        lip = thick / 2 + 0.4
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.8, "cloud", flat="z")
        if plate:
            def top(x):
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2 + 0.2

            head.beam((plate_from, 0, top(plate_from)), (x1 + 0.7, 0, top(x1 + 0.7)), plate, 0.5, "slate+", flat="z")
    # the mouth: a thin dark line that opens a little toward the front. Its dark inside is two blocks that end inside the
    # lips and the jaw. The lower jaw is two boxes, the smaller in front
    mouth = (-2.8, 2.8, HZ - 2.4, HZ - 1.1)
    head.block(-43.0, mouth, -38.5, mouth, "mouth")
    mouth = (-1.5, 1.5, HZ - 2.6, HZ - 1.3)
    head.block(-45.4, mouth, -42.8, mouth, "mouth")
    head.beam((-38.8, 0, HZ - 2.3), (-43.2, 0, HZ - 2.56), 6.4, 1.1, "cloud", flat="z")
    head.beam((-42.6, 0, HZ - 2.5), (-45.8, 0, HZ - 2.72), 4.2, 0.7, "cloud", flat="z")
    # two long fangs from the upper lip, leaning out past the jaw
    head.tooth(-44.6, 2.1, lip_bottom(1, -44.6) + 0.15, 0.8, 1.7, "tooth", lean=(0.2, 0.3))
    # the eye: white, a dark pupil at its front, under a brow box that slants down to the front and comes past it
    eye = (4.2, 5.0, HZ + 0.1, HZ + 1.9)
    head.block(-39.3, eye, -37.3, eye, "eye", mirror=True)
    pupil = (4.8, 5.3, HZ + 0.3, HZ + 1.1)
    head.block(-39.0, pupil, -38.2, pupil, "black", mirror=True)
    head.beam((-40.5, 4.5, HZ + 1.45), (-36.4, 4.5, HZ + 2.45), 1.2, 2.2, "slate-", mirror=True)
    # the horns: swept back and out, each a dark root and a kinked end of light, like the spines
    head.beam((-36.8, 2.4, HZ + 2.0), (-32.2, 4.4, HZ + 5.5), 1.7, 1.2, "slate-", mirror=True)
    head.beam((-33.6, 3.8, HZ + 4.4), (-28.8, 5.7, HZ + 6.0), 1.1, 0.7, "bolt", mirror=True)
    bolt_spine(head, -37.6, HZ + 4, 1.5)  # the first and biggest spine of the crest
    # the bolts jump a gap: a loose chip of light past the end of each horn and of the first spine, turned a little
    sparks = m.part("Sparks", (BODY_FROM, 0, HZ), "Head")
    sparks.beam((-27.9, 6.15, HZ + 6.7), (-26.8, 6.7, HZ + 7.9), 0.8, 0.5, "bolt", mirror=True)
    sparks.beam((-33.0, 0, HZ + 10.2), (-32.1, 0, HZ + 11.7), 0.7, 0.45, "bolt")

    # the body: seventeen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top, edge) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top, edge))
        x += length
    end = x

    # where the flank line may run on each slice (clear of the belly and of the corner steps), and its height at each joint
    room = []
    for x0, x1, n, bot, top, edge in spans:
        lo, hi = edge + STROKE + 0.15, wall(n, bot, top)[1] - STROKE - 0.15
        room.append((lo, hi) if hi > lo else ((lo + hi) / 2, (lo + hi) / 2))
    joints = []
    for k, kind in enumerate(ZIG):
        near = [room[i] for i in (k - 1, k) if 0 <= i < len(room)]
        joints.append(min(r[1] for r in near) if kind == "H" else max(r[0] for r in near))

    for i, (seg, (x0, x1, n, bot, top, edge)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top, edge)
        # a sleeve into the piece in front, so a bending joint shows body: one cube inside the flat sides both pieces
        # share, or, where there is no such room, a core clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else skull
        small = min(n, fn)
        low = max(wall(n, bot, top)[0], wall(fn, fbot, ftop)[0] if i else fbot + 1) + 1
        high = min(wall(n, bot, top)[1], wall(fn, fbot, ftop)[1]) - 1
        if high > low and small >= 2:
            seg.sym(x0 - 1, x0, small - 1, low, high, "slate-")
        else:
            down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if i else 1)
            up = max(len(top_steps(n)), len(top_steps(fn)) if i else 2)
            seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "slate-")
        # the lightning: one straight stroke of light on each flank, from this joint's height to the next one's
        lo, hi = room[i]
        za, zb = min(max(joints[i], lo), hi), min(max(joints[i + 1], lo), hi)
        xa, xb = x0 + 0.2, x1 - 0.2
        seg.prism([(xa, za - STROKE), (xb, zb - STROKE), (xb, zb + STROKE), (xa, za + STROKE)], n + 0.2, n + 0.8, "bolt", mirror=True)
        if SPINES[i]:
            bolt_spine(seg, x0 + SPINES[i] + 0.2, top, SPINES[i])
    # the seat: on the shoulders, a shallow slot either side for the rider's legs, above the line of light
    segs[SEAT_SLICE].dent(-17, -14, 4, 0, 3, "slate-")

    # the tail, on its own joint: a root block and two lobes that fork like a bolt, each steep, then flat, then steep
    # again, every box smaller and thinner than the one before and starting inside it; the last of each is light
    tail = m.part("Tail", (end, 0, TZ), f"S{len(SLICES)}")
    tail.beam((end - 0.5, 0, TZ), (end + 2.5, 0, TZ), 1.6, 1.5, "slate")
    tail.beam((end + 1.2, 0, TZ), (end + 5.0, 0, TZ + 4.6), 2.0, 1.2, "slate")
    tail.beam((end + 4.1, 0, TZ + 3.7), (end + 9.0, 0, TZ + 5.2), 1.5, 0.7, "slate-")
    tail.beam((end + 8.0, 0, TZ + 4.85), (end + 11.4, 0, TZ + 9.2), 1.1, 0.45, "bolt")
    tail.beam((end + 1.2, 0, TZ), (end + 4.2, 0, TZ - 3.8), 1.8, 0.9, "slate")
    tail.beam((end + 3.4, 0, TZ - 3.0), (end + 7.4, 0, TZ - 4.2), 1.3, 0.6, "slate-")
    tail.beam((end + 6.5, 0, TZ - 3.9), (end + 9.0, 0, TZ - 7.2), 1.0, 0.3, "bolt")
    sparks = m.part("TailSparks", (end, 0, TZ), "Tail")
    sparks.beam((end + 11.9, 0, TZ + 9.9), (end + 12.8, 0, TZ + 11.3), 0.7, 0.3, "bolt")
    sparks.beam((end + 9.4, 0, TZ - 7.9), (end + 10.1, 0, TZ - 9.1), 0.6, 0.25, "bolt")
