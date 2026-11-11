"""The Sea Lion (zone 3's Uncommon: a sleek brown sea lion of the kelp forest) for tools/blender/voxel_kit.py
(docs/style/creature-brief.md). Designed from the real animal.
Its idea: a friendly dog of the sea. A rounded head with a pointed muzzle and big dark eyes on a neck as thick as the
head, a deep chest with a pale bib, and long wing flippers it rows with.
- The body is ten slices behind the head, each one step bigger or smaller than the last in width, back or belly (never two at once):
  the neck rises behind the head, the chest is the deepest part, and the body thins to narrow hips.
- The one pattern (an Uncommon has one): the paler chest, a bib that climbs from the jaw to the shoulders and ends
  behind the flippers.
- The head: a skull, a narrower face step, a muzzle of two blocks in a chain, each tilted nose-down, and a dark nose
  poking out of the tip. A thin dark mouth line over a pale chin. Three thin whiskers a side. Small ear flaps behind
  the eyes. The eye is a big dark block on a thin cream ring.
- The front flippers have their own joints: three boxes swept back and down, each smaller and thinner, a darker tip.
- The two rear flippers lie together at the end, on one joint, like a small fluke.
It swims by bending up and down. The rider sits on the chest's back, behind the flippers, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Sea Lion", "ZONE 3 / KELP FOREST", "UNCOMMON"
U = 0.4
PALETTE = {"fur": "#8B5E3C", "chest": "#D2A878", "dark": "#4A362B", "black": "#1F1B1A", "cream": "#F3EAD3"}
SEAT = (-1, 5, 4.6)
FRAME, ORTHO = 1.45, 21.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["fur"]}]

# the body behind the head: each joint's slices as (x from, x to, cubes out, bottom, top, how high the pale chest comes)
BODY = (("S1", ((-12, -10, 3, -3, 4, 0),)),  # the neck: as wide as the head and a cube taller
        ("S2", ((-10, -7, 4, -3, 4, 0),)),  # the shoulders
        ("S3", ((-7, -3, 4, -4, 4, -1),)),  # the chest deepens: the flippers
        ("S4", ((-3, 1, 4, -4, 5, -2),)),  # the back's highest stretch: the rider
        ("S5", ((1, 4, 4, -3, 5, -2),)),
        ("S6", ((4, 6, 3, -3, 5, -9),)),
        ("S7", ((6, 8, 3, -3, 4, -9), (8, 10, 3, -2, 4, -9))),
        ("S8", ((10, 12, 3, -2, 3, -9), (12, 14, 2, -2, 3, -9))))  # the hips
SKULL = (-17, -12, 3, -3, 3, -1)
CHAIN = ["S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "Rear"]
AMPLITUDES = [1.5, 2, 2, 3, 4, 5, 7, 9, 14]


def pose(parts, phase):
    """a sea lion's swim: the wave runs down the body up and down and grows to the hips; the rear flippers beat at the
    end of it, and the long front flippers row"""
    parts["Head"].rotation_euler.y = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.55 * (k + 1))
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        parts[name].rotation_euler.x = side * math.radians(16) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(9) * math.sin(phase - 1.8)


def top_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def slab(p, x0, x1, n, bot, top, chest):
    """a slice of body: stepped corners, brown fur (lighter on the top row, darker on the lowest), pale from `chest` down"""
    p.hull(x0, x1, n, bot, top, "fur", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "fur+")
    p.paint_sym(x0, x1, n, bot, bot + 1, "fur-")
    if chest > bot:
        p.paint_sym(x0, x1, n, bot, chest, "chest")
        if chest - bot > 1:
            p.paint_sym(x0, x1, n, bot, bot + 1, "chest-")


def build(m):
    head = m.part("Head", (-12, 0, 0))
    slab(head, *SKULL)
    # the face: one step narrower and lower than the skull, so the head rounds off toward the muzzle
    head.sym(-18, -17, 2, -3, 2, "fur")
    head.paint_sym(-18, -17, 2, -3, -1, "chest")
    head.paint_sym(-18, -17, 2, -3, -2, "chest-")

    # the muzzle: two blocks in a chain, each tilted nose-down, the second smaller and starting inside the first
    def c1(x):
        return -0.05 + 0.0968 * (x + 16.5)

    def c2(x):
        return -0.45 + 0.125 * (x + 19.0)

    head.beam((-16.5, 0, c1(-16.5)), (-19.6, 0, c1(-19.6)), 3.6, 2.7, "fur", flat="z")
    head.beam((-19.0, 0, c2(-19.0)), (-21.0, 0, c2(-21.0)), 2.4, 1.9, "fur", flat="z")
    # the mouth: a thin dark line set inside the lip's edge, over a pale chin
    head.beam((-16.5, 0, c1(-16.5) - 1.45), (-19.1, 0, c1(-19.1) - 1.45), 3.0, 0.3, "dark-", flat="z")
    head.beam((-16.5, 0, c1(-16.5) - 2.0), (-19.35, 0, c1(-19.35) - 2.0), 3.3, 0.9, "chest", flat="z")
    # the nose: a dark block poking out of the muzzle's tip, in its upper half
    head.beam((-20.5, 0, c2(-20.5) + 0.2), (-21.6, 0, c2(-21.6) + 0.2), 1.4, 1.2, "dark-", flat="z")
    # whiskers: three very thin short sticks a side, fanning back from the muzzle
    for p0, p1 in (((-18.9, 1.5, -0.6), (-17.6, 3.6, -0.45)), ((-18.9, 1.5, -0.9), (-17.9, 3.5, -1.5)),
                   ((-19.0, 1.5, -1.1), (-18.5, 3.0, -2.3))):
        head.beam(p0, p1, 0.2, 0.2, "cream", flat="z", mirror=True)
    # the eyes: big, dark and friendly, in the middle of the skull's side. A cream square in the skull and a dark block standing out of it,
    # a little smaller, so a thin cream ring shows round it
    head.pair(-16, -14, 3, 4, 0, 2, "cream")
    pupil = (3.4, 3.8, 0.22, 1.78)
    head.block(-15.78, pupil, -14.22, pupil, "black", mirror=True)
    # the ear flaps: small, behind the eyes, lying back
    head.beam((-13.6, 3.0, 1.2), (-12.2, 3.95, 0.5), 0.9, 0.5, "fur-", mirror=True)

    # the body: slices, one or two to a joint
    parts, before, last = {}, "Head", SKULL
    for name, slices in BODY:
        seg = m.part(name, (slices[0][0], 0, 0), before)
        for s in slices:
            slab(seg, *s)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        x0, _, n, bot, top, _ = slices[0]
        _, _, fn, fbot, ftop, _ = last
        up = max(len(top_steps(n)), len(top_steps(fn)))
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "fur-")
        parts[name], before, last = seg, name, slices[-1]
    # the seat: where the back is highest, behind the flippers, a shallow slot either side for the rider's legs
    parts["S4"].dent(-2, 0, 4, 0, 3, "fur-")

    # the front flippers, each on its own joint: three boxes swept back and down, each smaller and thinner than the
    # last and starting inside it, the first starting deep in the chest. A darker tip
    for name, side in (("FlipperR", 1), ("FlipperL", -1)):
        part = m.part(name, (-5.0, 4.0 * side, -1.5), "S3")
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in (((-5.0, 3.0, -1.2), (-3.4, 7.2, -2.4), 3.4, 1.2, "dark"),
                                                                ((-3.9, 6.2, -2.1), (-0.1, 10.4, -3.3), 2.8, 0.8, "dark"),
                                                                ((-1.0, 9.4, -3.0), (1.8, 12.0, -3.75), 1.9, 0.45, "dark-")):
            part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")

    # the rear flippers: together at the end, on one joint. A furred hub buried in the hips, then two dark paddles side
    # by side, each ending in a darker tip. They lie flat, and beat up and down
    rear = m.part("Rear", (14, 0, 0.5), "S8")
    rear.beam((13.3, 0, 0.5), (15.6, 0, 0.5), 4.4, 2.2, "fur-", flat="z")
    rear.beam((14.5, 1.15, 0.5), (17.0, 1.6, 0.5), 2.0, 1.2, "dark", flat="z", mirror=True)
    rear.beam((16.3, 1.47, 0.5), (18.4, 1.85, 0.5), 1.5, 0.55, "dark-", flat="z", mirror=True)
