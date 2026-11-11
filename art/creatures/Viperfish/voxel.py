"""The Viperfish (zone 6's Rare: Sloane's viperfish of the twilight zone) for tools/blender/voxel_kit.py
(docs/style/creature-brief.md). Designed from the real animal.
Its idea: a mouth that cannot shut. A slender near-black fish whose fangs are too long for its jaws, so they pass
outside them, and a fishing line of its own: one long ray from the back fin, bent forward over the head, a small light
at its tip.
- The head is the biggest thing on it, as on the real fish: a tall skull, a forehead that slopes down in two blocks
  tilted nose-down, and a lower jaw on its own hinge, longer than the snout, hanging open and curving up at the tip.
- Needle fangs: the lower ones stand on the jaw's rim and rise outside the snout, the front pair to above it; one long
  upper pair hangs outside the lower jaw, to below the chin. A thin dark gum line inside each lip.
- The body is eight slices on joints, long in front and short at the tail. The skull stands a step above the back, which
  steps down to the tail; the belly steps up; never both in one slice. It ends in a thin stalk and a small forked tail.
- A faint silver line along the flank, and under it a single row of small lights on the belly's edge, which follows the
  belly up to the tail.
- A pale eye under a slanting brow that comes past it.
The rider sits behind the back fin, legs in a slot either side; the light hangs in front of them."""
import math

NAME, ZONE, RARITY = "Viperfish", "ZONE 6 / TWILIGHT", "RARE"
U = 0.4
PALETTE = {"ink": "#262F4C", "silver": "#6F7E9C", "eye": "#C3CEDD", "light": "#8FF4E2", "tooth": "#F4F6F2", "mouth": "#4E1C2C",
           "gum": "#8A4256", "black": "#0D0F15"}
SEAT = (-3.8, 4, 2.5)
GLOW = {"light": 0.9}  # the lure's tip and the row of spots on the belly's edge
LIGHTS = [("RayTip", (-16.5, 0, 12.05), "#8FF4E2", 40, 0.5)]
FRAME, ORTHO = 1.6, 22.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["ink"]}]

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice
# (long slices in front, short ones at the tail, so the outline is a curve and not a wedge)
SLICES = ((4, 2, -4, 4), (5, 2, -3, 4), (4, 2, -3, 3), (4, 2, -2, 3), (3, 2, -2, 2), (2, 1, -2, 2), (2, 1, -1, 2), (2, 1, -1, 1))
BODY_FROM = -10
SKULL = (3, -4, 5)
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [2, 3, 4, 6, 8, 10, 13, 16, 20]


def pose(parts, phase):
    """a slender fish's swim: the wave runs down the chain side to side, growing to the tail. The jaw works a little, and
    the long ray sways and nods after the body, its tip last"""
    parts["Head"].rotation_euler.z = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.65 * (k + 1))
    parts["Jaw"].rotation_euler.y = -math.radians(8) * (0.5 + 0.5 * math.sin(phase))
    parts["Ray"].rotation_euler.x = math.radians(5) * math.sin(phase - 1.4)
    parts["Ray"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.0)
    parts["RayTip"].rotation_euler.x = math.radians(9) * math.sin(phase - 2.4)
    parts["RayTip"].rotation_euler.y = math.radians(6) * math.sin(phase - 2.0)


def steps_of(n):
    return [(1, 1)] if n >= 2 else []


def slab(p, x0, x1, n, bot, top, silver=True):
    """a slice of body: near-black, a lighter top row, a darker underside, the faint silver line on the flank, and a small
    light on every other cube of the belly's edge"""
    steps = steps_of(n)
    p.hull(x0, x1, n, bot, top, "ink", steps, steps)
    p.paint_sym(x0, x1, n, top - 1, top, "ink+")
    p.paint_sym(x0, x1, n, bot, bot + 1, "ink-")
    if silver:
        p.paint_pair(x0, x1, n, n + 1, 0, 1, "silver")
    edge = bot + 1 if steps else bot
    for x in range(x0, x1):
        if x % 2:
            p.paint_pair(x, x + 1, n, n + 1, edge, edge + 1, "light")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: tall, with the eye on its side, and behind the mouth a deep cheek the jaw hinges in
    head.hull(-15, -10, 3, -1, 5, "ink", [(1, 1)], ())
    head.sym(-12, -10, 3, -4, -1, "ink")
    head.paint_sym(-15, -10, 3, 4, 5, "ink+")
    head.paint_sym(-12, -10, 3, -4, -3, "ink-")
    # the forehead and snout: two blocks in a chain, each tilted nose-down, lower and narrower than the last, with a
    # lighter plate on the first and a thin gum line under each, set in from the lip's edge
    blocks = ((-13.5, -17.4, 1.9, 0.8, 5.6, 4.4), (-16.7, -19.5, 0.7, -0.3, 3.6, 2.8))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip(k, x):
        """the underside of block k at x (the block is tilted, so it is a little more than half its thickness down)"""
        x0, x1, z0, z1, _, thick = blocks[k]
        return middle(k, x) - thick / 2 * math.hypot(x1 - x0, z1 - z0) / abs(x1 - x0)

    for k, (x0, x1, z0, z1, wide, thick) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "ink", flat="z")
    rise = blocks[0][5] / 2 + 0.2
    head.beam((-14.6, 0, middle(0, -14.6) + rise), (-17.2, 0, middle(0, -17.2) + rise), 3.4, 0.5, "ink+", flat="z")
    for k, xa, xb, wide in ((0, -15.3, -16.4, 3.8), (1, -17.0, -18.7, 2.6)):
        head.beam((xa, 0, lip(k, xa) - 0.08), (xb, 0, lip(k, xb) - 0.08), wide, 0.25, "gum", flat="z")
    # the dark inside of the mouth: one block that stays behind the teeth and ends inside the skull, the snout and the jaw
    head.block(-18.6, (-1.2, 1.2, -3.6, -0.6), -11.5, (-2.1, 2.1, -3.6, -0.6), "mouth")
    # the upper teeth. One long pair hangs from the snout's edge in front of the wide part of the jaw, leaning out, and
    # passes outside the jaw to below the chin; the rest are short and stay in the mouth
    head.tooth(-16.2, 2.3, lip(0, -16.2) + 0.2, 0.6, 4.3, "tooth", lean=(-0.2, 0.6))
    head.tooth(-18.2, 1.25, lip(1, -18.2) + 0.1, 0.5, 1.5, "tooth")
    head.tooth(-15.3, 2.2, lip(0, -15.3) + 0.1, 0.5, 1.3, "tooth")
    head.tooth(-13.8, 2.2, -0.9, 0.5, 1.0, "tooth")
    # the eye: pale, half a cube proud, a dark pupil standing out of it, under a brow that slants down to the front and
    # comes past it
    eye = (3.4, 4.0, 1.0, 3.0)
    head.block(-14.0, eye, -12.0, eye, "eye", mirror=True)
    pupil = (3.9, 4.3, 1.25, 2.45)
    head.block(-13.55, pupil, -12.4, pupil, "black", mirror=True)
    head.beam((-14.8, 3.15, 2.55), (-11.4, 3.15, 3.35), 1.1, 2.7, "ink", mirror=True)

    # the lower jaw, on its own hinge: two boxes in a chain, the first wide and sloping down, the second narrower and
    # curving up to a tip in front of the snout. A gum line on each, and the fangs on its rim
    jaw = m.part("Jaw", (-11.2, 0, -2.8), "Head")
    jaws = ((-10.9, -15.0, -2.9, -4.1, 6.4, 1.8), (-14.2, -20.2, -4.0, -3.5, 4.8, 1.3))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "ink", flat="z")
    for k, xa, xb, wide in ((0, -12.4, -14.6, 5.0), (1, -15.6, -19.9, 3.8)):
        jaw.beam((xa, 0, jaw_top(k, xa) + 0.08), (xb, 0, jaw_top(k, xb) + 0.08), wide, 0.25, "gum", flat="z")
    # the lower fangs: the front pair rises outside the snout's tip to above it, leaning back; the next stands in front
    # of the forehead block; two short ones on the wide part of the jaw
    jaw.tooth(-19.6, 2.0, jaw_top(1, -19.6) - 0.15, 0.65, -5.1, "tooth", lean=(1.0, 0.05))
    jaw.tooth(-18.4, 2.0, jaw_top(1, -18.4) - 0.15, 0.6, -3.6, "tooth", lean=(0.4, 0.1))
    jaw.tooth(-14.4, 2.85, jaw_top(0, -14.4) - 0.15, 0.5, -1.7, "tooth")
    jaw.tooth(-13.2, 2.85, jaw_top(0, -13.2) - 0.15, 0.5, -1.2, "tooth")

    # the body: eight slices, each on its own joint, with a sleeve into the piece in front
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, (bot + top) / 2 if i >= 5 else 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top, silver=i < len(SLICES) - 1)
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        small, za, zb = min(n, fn) - 1, max(bot, fbot) + 1, min(top, ftop) - 1
        if zb > za:
            seg.sym(x0 - 1, x0, small, za, zb, "ink-")
    segs[0].dent(-9, -8, 2, 1, 3, "ink-")  # a gill slit
    segs[1].dent(-5, -3, 2, 1, 3, "ink-")  # the seat's leg slots

    # the back fin, just behind the skull: two boxes leaning back. Its first ray is the fishing line
    segs[0].beam((-8.8, 0, 3.3), (-7.4, 0, 6.2), 2.2, 1.1, "ink")
    segs[0].beam((-7.7, 0, 5.5), (-6.8, 0, 7.4), 1.5, 0.4, "ink-")
    # the long ray, on two joints: it rises from the fin, bends forward over the head and droops at the end, where the
    # small light hangs. Each length is thinner than the last
    ray = m.part("Ray", (-8.5, 0, 4.6), "S1")
    ray.beam((-8.5, 0, 4.4), (-9.6, 0, 10.5), 0.7, 0.8, "ink")
    ray.beam((-9.5, 0, 10.2), (-13.0, 0, 13.4), 0.5, 0.5, "ink")
    tip = m.part("RayTip", (-12.9, 0, 13.3), "Ray")
    tip.beam((-12.7, 0, 13.2), (-16.4, 0, 12.1), 0.35, 0.2, "ink")
    bulb = (-0.55, 0.55, 11.4, 12.7)
    tip.block(-17.1, bulb, -15.9, bulb, "light")

    # the other fins, all small: the side fins low behind the gill, the belly fins, and far back a fin under the tail's
    # stalk and a little one on top of it
    segs[0].beam((-8.7, 1.5, -1.8), (-5.8, 3.9, -3.2), 2.2, 0.5, "ink+", flat="z", mirror=True)
    segs[3].beam((4.3, 1.0, -0.8), (6.1, 2.4, -3.0), 1.2, 0.4, "ink+", flat="z", mirror=True)
    segs[6].beam((12.7, 0, -0.4), (14.5, 0, -2.6), 1.6, 0.6, "ink+")
    segs[6].beam((12.6, 0, 1.5), (13.9, 0, 2.8), 1.0, 0.5, "ink+")

    # the tail, on its own joint: small and forked, two lobes of two boxes each, darker at the tips
    tail = m.part("Tail", (end, 0, 0), f"S{len(SLICES)}")
    tail.beam((end - 0.8, 0, 0.3), (end + 2.0, 0, 3.0), 1.8, 1.0, "ink")
    tail.beam((end + 1.4, 0, 2.4), (end + 3.4, 0, 4.5), 1.2, 0.6, "ink-")
    tail.beam((end - 0.8, 0, -0.3), (end + 1.8, 0, -2.8), 1.6, 0.7, "ink")
    tail.beam((end + 1.3, 0, -2.3), (end + 3.0, 0, -4.1), 1.1, 0.4, "ink-")
