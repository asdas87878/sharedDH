"""Livyatan (zone 7's Legendary: the prehistoric sperm whale with teeth like tusks) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md.
Designed from the real animal: a sperm whale's outline with a killer's mouth.
Its idea: a battering ram with tusks. A third of it is one blunt box of a head, and under that box hangs a narrow pale
jaw full of ivory teeth; the teeth are the one bright thing on a charcoal animal.

- The head is a third of the length: a forehead cap one cube smaller all round and undercut at the bottom, the long
  high case of the forehead, and a deeper cheek behind it that the jaw hinges in. Its underside climbs to the front in
  two broad steps.
- Under the forehead lies a pale upper lip, a whole block tilted nose-up, with a thin dark gum line inside its edge and a
  row of tusks hanging from it, beside the jaw. The lower jaw is its own part: two slim pale boxes in a chain, tilted
  nose-down, so the mouth stands open in a wedge. Its teeth stand inside the upper row.
- The eye is low and far back, just above the corner of the mouth: a dark pupil in a thin halo of soft light, under a
  brow that slants down to the front and comes past it.
- The body is sixteen slices on joints. Behind the head the back dips a little, then it is one long high plateau to the
  hump and steps down to the tail; the belly is deepest under the shoulders and rises to the tail; from above it is
  widest behind the flippers. Three-step corners where it is thick, two, then one.
- One thin paler line runs the whole length, from the lip of the forehead through the eye to the tail.
- No back fin: a low hump two thirds of the way back (a whole block, tilted), then one knuckle on every slice down to the
  flukes, each smaller than the last. Small paddle flippers low behind the head. Broad flat flukes on their own joint.
- Paler scars: three rake marks on the left of the forehead, two on the right flank (thin slanted bars, a little proud).
The rider sits on the widest slice, on a saddle of back between two wells for the legs."""
import math

NAME, ZONE, RARITY = "Livyatan", "ZONE 7 / MIDNIGHT", "LEGENDARY"
U = 0.5
PALETTE = {"hide": "#474C56", "belly": "#7B818B", "jaw": "#DAD3BF", "line": "#9AA1AA", "scar": "#BCC0C4", "tooth": "#F5EACB",
           "mouth": "#5E2530", "gum": "#8C4A54", "black": "#17191C", "soft": "#F2C46A"}
SEAT = (10.5, 8, 1.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["hide"]}]
FRAME, ORTHO, ORTHO_SWIM = 3.2, 46.0, 52.0

# the body: each slice is (length, cubes out, bottom, top). In the thick front half one number changes from slice to
# slice; down the tail two may, never one of them by more than a cube
SLICES = ((3, 7, -7, 7), (3, 7, -8, 7), (4, 7, -8, 8), (4, 8, -8, 8), (3, 8, -8, 8), (3, 7, -8, 8), (3, 7, -7, 8), (4, 6, -7, 8),
          (3, 6, -6, 7), (3, 5, -6, 7), (3, 5, -5, 6), (2, 4, -5, 5), (2, 3, -4, 5), (2, 3, -4, 4), (2, 2, -3, 4), (2, 2, -3, 3))
BODY_FROM = -2
LINE = -2  # the height of the thin paler line
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail", "Fluke"]
AMPLITUDES = [0.4, 0.5, 0.6, 0.8, 1.0, 1.2, 1.5, 1.8, 2.2, 2.6, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.5, 11.0]
KNUCKLES = ((1.1, 1.0, 1.2), (1.0, 0.9, 1.1), (0.9, 0.8, 1.0), (0.8, 0.7, 0.75), (0.7, 0.6, 0.7), (0.6, 0.55, 0.65), (0.5, 0.5, 0.6),
            (0.45, 0.45, 0.55))  # half width, height, half length: one for each slice behind the hump


def pose(parts, phase):
    """a whale's swim: the front half is stiff, the wave grows down the tail stock, up and down, and the flukes beat at
    the end of it. The jaw opens and shuts once a beat; the flippers row a little"""
    parts["Head"].rotation_euler.y = math.radians(1.0) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.26 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(12) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(7) * math.sin(phase - 1.8)


def top_steps(n):
    """the corners of the back: three steps where the body is thick, fewer as it thins"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 5 else [(1, 1)]


def belly_edge(bot):
    """how high the paler belly comes: deepest under the shoulders, rising to the tail in one line"""
    return bot + (3 if bot <= -7 else (2 if bot <= -5 else 1))


def slab(p, x0, x1, n, bot, top, belly=True):
    """a slice of body: stepped corners, charcoal hide (lighter on the top row), a paler belly, the thin paler line"""
    steps = top_steps(n)
    p.hull(x0, x1, n, bot, top, "hide", steps, bottom_steps(n))
    if len(steps) > 1:  # a darker line on the lowest step of the back
        p.paint_sym(x0, x1, n, top - len(steps), top - len(steps) + 1, "hide-")
    p.paint_sym(x0, x1, n, top - 1, top, "hide+")
    if belly:
        p.paint_sym(x0, x1, n, bot, belly_edge(bot), "belly")
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    p.paint_sym(x0, x1, n, LINE, LINE + 1, "line")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the head, a third of the animal: the forehead cap (one cube smaller all round), the long high case of the forehead,
    # and the cheek behind it, deeper in two broad steps, which holds the eye and the jaw's hinge
    three, two = [(3, 1), (2, 1), (1, 1)], [(2, 1), (1, 1)]
    head.hull(-28, -26, 5, -2, 7, "hide", three, two)
    head.paint_sym(-28, -26, 5, 4, 5, "hide-")
    head.paint_sym(-28, -26, 5, 6, 7, "hide+")
    head.carve(-28, -27, -5, 6, -2, 0)  # the forehead is undercut: its lower front corner steps back to the lip
    head.paint_sym(-28, -26, 5, LINE, LINE + 1, "line")
    slab(head, -26, -13, 6, -3, 8, belly=False)
    slab(head, -13, -8, 6, -5, 8)
    slab(head, -8, BODY_FROM, 6, -7, 7)
    skull = (6, -7, 7)
    # the blowhole: one small dark slot at the front of the forehead, left of the middle, as a sperm whale's is
    hole = (-2.5, -1.2, 7.85, 8.14)
    head.block(-25.3, hole, -23.7, hole, "hide-")

    # the upper lip: one pale block under the forehead, tilted nose-up, narrower than the head. A thin dark gum line lies
    # under it, inside its edge, and the tusks hang from that, outside the lower jaw
    lx0, lx1, lz0, lz1, lthick = -11.5, -26.9, -3.8, -2.73, 1.6

    def lip_bottom(x):
        return lz0 + (lz1 - lz0) * (x - lx0) / (lx1 - lx0) - lthick / 2

    head.beam((lx0, 0, lz0), (lx1, 0, lz1), 8.0, lthick, "jaw", flat="z")
    head.beam((-12.6, 0, lip_bottom(-12.6) - 0.05), (-26.5, 0, lip_bottom(-26.5) - 0.05), 7.0, 0.3, "gum", flat="z")
    for x, long in ((-25.5, 2.7), (-22.9, 2.6), (-20.3, 2.4), (-17.7, 2.2), (-15.1, 1.9)):
        head.tooth(x, 2.8, lip_bottom(x) - 0.05, 1.3, long, "tooth")
    head.tooth(-25.8, 1.0, lip_bottom(-25.8) - 0.05, 1.1, 2.3, "tooth")
    # the dark inside of the mouth, at its back, behind the teeth: it ends inside the lip and the jaw
    mouth = (-1.6, 1.6, -5.9, -3.9)
    head.block(-15.6, mouth, -11.8, mouth, "mouth")

    # the eye, low and far back: a dark socket in the cheek, a thin halo of soft light, a dark pupil standing out of it. The
    # brow sits on it, slants down to the front and comes past it in front and behind
    ring = (6.38, 6.97, -3.0, 0.0)
    head.block(-8.0, ring, -4.4, ring, "hide-", mirror=True)
    halo = (6.85, 7.15, -2.6, -0.4)
    head.block(-7.5, halo, -4.9, halo, "soft", mirror=True)
    pupil = (6.97, 7.33, -2.15, -0.85)
    head.block(-7.0, pupil, -5.4, pupil, "black", mirror=True)
    head.beam((-9.6, 6.81, -1.0), (-3.6, 6.81, -0.1), 1.5, 1.34, "hide", mirror=True)

    # old scars on the left of the forehead: three rake marks, thin slanted bars a little proud of the hide
    for dx, up in ((0.0, 3.6), (1.7, 4.3), (3.4, 3.6)):
        head.beam((-23.6 + dx, -6.5, up), (-20.8 + dx, -6.5, 0.3), 0.45, 0.4, "scar")

    # the lower jaw, on its own joint: two slim pale boxes in a chain, tilted nose-down so the mouth stands open, with
    # its own gum line and teeth that stand inside the upper row
    jaw = m.part("Jaw", (-8, 0, -5.8), "Head")
    jaws = ((-7.4, -16.0, -5.9, -6.5, 5.0, 1.6), (-15.2, -24.6, -6.45, -7.2, 3.6, 1.2))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for x0, x1, z0, z1, wide, thick in jaws:
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "jaw", flat="z")
    jaw.beam((-16.2, 0, jaw_top(1, -16.2) + 0.05), (-24.3, 0, jaw_top(1, -24.3) + 0.05), 3.0, 0.3, "gum", flat="z")
    for x in (-23.8, -21.6, -19.0, -16.9):
        jaw.tooth(x, 1.0, jaw_top(1, x) + 0.05, 1.0, -1.7, "tooth", lean=(0.0, 0.2))

    # the body: sixteen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    first = len(SLICES) - len(KNUCKLES)
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else skull
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)))
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)))
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "hide-")
        # the knuckles: behind the hump, one on the back of each slice, smaller as the stock thins
        if i >= first:
            half, tall, long = KNUCKLES[i - first]
            mid = (x0 + x1) / 2
            knuckle = (-half, half, top - 0.12, top + tall)
            seg.block(mid - long, knuckle, mid + long, knuckle, "hide")

    # the seat: on the widest slice. The back is far too wide to sit astride, so the rider gets a saddle of back three
    # cubes wide between two wells for the legs
    segs[3].carve_pair(9, 12, 2, 4, 6, 8)

    # the hump, in place of a back fin: one low block tilted up to the rear, its front buried in the back
    segs[7].beam((20.9, 0, 7.3), (24.6, 0, 8.5), 4.2, 1.6, "hide", flat="z")

    # old scars on the right flank: two rake marks
    for dx in (0.0, 1.2):
        segs[3].beam((8.4 + dx, 8.5, 3.6), (10.6 + dx, 8.5, 0.4), 0.45, 0.4, "scar")

    # the flippers: small paddles low behind the head, each on its own joint, in two boxes swept back
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (0.5, 6.8 * side, -4.5), "S1")
        part.beam((-0.2, 6.3 * side, -4.3), (3.0, 10.0 * side, -5.6), 3.4, 1.1, "hide", flat="z")
        part.beam((2.2, 9.1 * side, -5.3), (5.6, 11.6 * side, -6.4), 2.6, 0.6, "hide-", flat="z")

    # the tail: a short stock, tall and narrow, with the last knuckle, then broad flat flukes on a joint of their own: a
    # hub and two lobes that go out more than back, each ending in a darker tip
    tail = m.part("Tail", (end, 0, 0), f"S{len(SLICES)}")
    tail.beam((end - 0.6, 0, 0), (end + 3.2, 0, 0), 2.4, 3.8, "hide", flat="z")
    knuckle = (-0.42, 0.42, 1.78, 2.25)
    tail.block(end + 0.9, knuckle, end + 2.2, knuckle, "hide")
    fluke = m.part("Fluke", (end + 2.4, 0, 0), "Tail")
    fluke.beam((end + 1.4, 0, 0), (end + 5.8, 0, 0), 8.4, 1.5, "hide", flat="z")
    fluke.beam((end + 3.5, 2.2, 0), (end + 6.6, 9.4, 0), 4.2, 1.0, "hide", flat="z", mirror=True)
    fluke.beam((end + 6.0, 8.2, 0), (end + 7.4, 11.4, 0), 2.8, 0.55, "hide-", flat="z", mirror=True)
