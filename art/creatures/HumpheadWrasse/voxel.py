"""The Humphead Wrasse (zone 2's Epic: the Napoleon wrasse, the giant of the reef) for tools/blender/voxel_kit.py.
Its idea: a huge, heavy, gentle reef fish with a bulging hump on its forehead and thick pale lips.
- The body is deep and heavy: one long full slice under the rider, then eleven short slices to the tail stock, each one
  step smaller than the last in width, back or belly, never two at once.
- The head is not a brick: a snout of two blocks tilted nose-down, a pale lower jaw rising to meet it, and two thick lip
  blocks wider than the snout with a dark line between. The hump is one big block tilted up to the front, so its face
  leans back like a forehead and its top stands well above the back, with one smaller plate on top.
- Small friendly eyes: a pale ring and a dark pupil, under the hump.
- Two kinds of extra (an Epic): thin wavy lines over the face and gill covers in a dark blue, and one thin lime stripe
  down the whole body, echoed on the edge of the tail.
- A long low back fin in a chain of boxes that rises to a point at the back, the same below, paddle side fins on their
  own joints (a wrasse rows with them), and a broad square tail.
The rider sits behind the hump, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Humphead Wrasse", "ZONE 2 / CORAL REEF", "EPIC"
U = 0.45
PALETTE = {"body": "#2F9FA6", "belly": "#9ED9C3", "lip": "#EFE3C2", "line": "#1D5878", "accent": "#D6E26B", "mouth": "#4A2738",
           "black": "#1C2026", "eye": "#F6EFD6"}
SEAT = (-5, 8, 5.5)
FRAME, ORTHO = 1.95, 27.0
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["body"]}]

# the body behind the head: (from, to, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((-10, -2, 5, -8, 8), (-2, 1, 5, -8, 7), (1, 3, 5, -7, 7), (3, 5, 4, -7, 7), (5, 7, 4, -7, 6), (7, 9, 4, -6, 6),
          (9, 10, 3, -6, 6), (10, 11, 3, -6, 5), (11, 12, 3, -5, 5), (12, 13, 2, -5, 5), (13, 14, 2, -5, 4), (14, 16, 2, -4, 4))
PARTS = (("B1", 0, 3), ("B2", 3, 6), ("B3", 6, 12))  # which slices each piece of the body holds
STRIPE = 0  # the height of the lime stripe


def pose(parts, phase):
    """a heavy fish's swim: a slow wave down the body to the tail, and the side fins rowing, as a wrasse's do"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, (name, amp) in enumerate((("B1", 2), ("B2", 5), ("B3", 8), ("Tail", 15))):
        parts[name].rotation_euler.z = math.radians(amp) * math.sin(phase - 0.8 * (k + 1))
    for name, side in (("PecR", 1), ("PecL", -1)):
        parts[name].rotation_euler.z = side * math.radians(15) * math.sin(2 * phase)
        parts[name].rotation_euler.x = side * math.radians(9) * math.sin(2 * phase - 1.2)


def steps(n):
    """the corners: two steps where the body is thick, one where it is thin"""
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def slab(p, x0, x1, n, bot, top, stripe=True):
    """a slice of body: stepped corners, a lighter top row, a pale belly, the thin stripe"""
    p.hull(x0, x1, n, bot, top, "body", steps(n), steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "body+")
    p.paint_sym(x0, x1, n, bot, max(bot + 2, -5), "belly")
    if stripe:
        p.paint_sym(x0, x1, n, STRIPE, STRIPE + 1, "accent")


def build(m):
    head = m.part("Head", (-10, 0, 0))
    slab(head, -18, -14, 4, -7, 8, stripe=False)
    slab(head, -14, -10, 5, -7, 8, stripe=False)
    # the snout: two big blocks in a chain, each tilted nose-down, lower and narrower than the last. The top of the first
    # is the steep forehead
    head.beam((-14.5, 0, 3.5), (-20.5, 0, -0.5), 6.6, 8.0, "body", flat="z")
    head.beam((-19.5, 0, -0.3), (-22.6, 0, -1.5), 5.6, 5.0, "body", flat="z")
    # the lower jaw: one pale block rising a little to the front
    head.beam((-15.0, 0, -3.9), (-21.0, 0, -3.3), 5.0, 4.0, "belly", flat="z")
    # the thick lips: two pale blocks wider than the snout, the upper one further out, a dark line between
    upper, lower, mouth = (-3.45, 3.45, -1.3, 1.5), (-3.25, 3.25, -4.3, -1.9), (-3.05, 3.05, -2.2, -1.0)
    head.block(-24.4, upper, -22.0, upper, "lip")
    head.block(-24.0, lower, -20.7, lower, "lip")
    head.block(-23.7, mouth, -22.2, mouth, "mouth")
    # the hump: one big block over the eyes, tilted up a little to the front. It breaks out of the sloping forehead with
    # a face that is nearly upright, and its top stands well above the back; one smaller plate on top rounds it
    head.beam((-13.2, 0, 6.2), (-19.4, 0, 7.5), 5.9, 6.4, "body", flat="z")
    head.beam((-14.0, 0, 9.6), (-18.2, 0, 10.5), 4.2, 2.0, "body+", flat="z")
    # the eye: small and friendly, a pale ring and a dark pupil
    ring, pupil = (4.3, 4.75, 2.1, 4.0), (4.6, 5.0, 2.55, 3.6)
    head.block(-16.9, ring, -15.0, ring, "eye", mirror=True)
    head.block(-16.45, pupil, -15.4, pupil, "black", mirror=True)
    # the lines of the face and the gill cover: thin, wavy, a dark blue, each one cube thick in long runs with one-cube
    # steps. One over the eye, one behind it, two across the cheek; the upper cheek line runs into the body's stripe
    lines = (((-17, -14, 5), (-14, -12, 4), (-12, -10, 5)), ((-14, -12, 2), (-12, -10, 3)),
             ((-18, -16, 0), (-16, -13, -1), (-13, -10, 0)), ((-18, -16, -3), (-16, -13, -4), (-13, -10, -3)))
    for line in lines:
        for x0, x1, z in line:
            head.paint_pair(x0, x1, 4, 6, z, z + 1, "line")

    # the body
    segs, front = {}, (5, -7, 8)
    for name, a, b in PARTS:
        x0 = SLICES[a][0]
        seg = segs[name] = m.part(name, (x0, 0, 0), "Head" if name == "B1" else f"B{int(name[1]) - 1}")
        for x_from, x_to, n, bot, top in SLICES[a:b]:
            slab(seg, x_from, x_to, n, bot, top)
        # a sleeve into the piece in front, sized from the smaller of the two and clear of both pieces' steps
        n, bot, top = SLICES[a][2:]
        small = min(n, front[0])
        deep = max(len(steps(n)), len(steps(front[0])))
        seg.sym(x0 - 1, x0, small - 2, max(bot, front[1]) + deep, min(top, front[2]) - deep, "body-")
        front = SLICES[b - 1][2:]
    b1, b2, b3 = segs["B1"], segs["B2"], segs["B3"]
    b1.dent(-6, -4, 5, 3, 6, "body-")  # the rider's leg slot

    # the back fin: long and low, a chain of boxes that rises to a point at the back; it starts behind the rider
    b1.beam((-2.6, 0, 6.0), (4.6, 0, 6.9), 3.6, 1.8, "body")
    b2.beam((3.4, 0, 6.4), (10.6, 0, 7.4), 3.8, 1.5, "body")
    b3.beam((9.4, 0, 6.6), (15.0, 0, 8.6), 2.8, 1.2, "body")
    b3.beam((14.0, 0, 8.1), (17.2, 0, 9.4), 1.8, 0.9, "line")
    # the fin under the tail stock: the same, shorter
    b2.beam((4.4, 0, -5.2), (10.4, 0, -6.2), 3.4, 1.5, "body")
    b3.beam((9.6, 0, -6.0), (14.6, 0, -7.8), 2.8, 1.2, "body")
    b3.beam((13.6, 0, -7.4), (16.6, 0, -8.6), 1.8, 0.9, "line")
    # the belly fins: one small box each
    b1.beam((-7.6, 2.0, -6.7), (-4.6, 3.2, -9.2), 2.2, 0.6, "belly-", mirror=True)
    # the side fins, each on its own joint: a paddle of two boxes
    for name, s in (("PecR", 1), ("PecL", -1)):
        fin = m.part(name, (-9.0, 5.0 * s, -2.2), "B1")
        fin.beam((-9.3, 4.3 * s, -2.2), (-5.6, 6.9 * s, -2.9), 4.4, 1.1, "body")
        fin.beam((-6.4, 6.3 * s, -2.75), (-3.0, 8.6 * s, -3.4), 3.2, 0.7, "line")

    # the tail, on its own joint: broad and square. A root block, a plate, two lobes that open it out, a lime edge
    tail = m.part("Tail", (16, 0, 0), "B3")
    tail.beam((15.2, 0, 0), (18.4, 0, 0), 7.4, 2.4, "body")
    tail.beam((17.2, 0, 0), (22.8, 0, 0), 9.8, 1.8, "body")
    for s in (1, -1):
        tail.beam((18.4, 0, 2.6 * s), (23.6, 0, 4.6 * s), 4.8, 1.2, "body")
    tail.beam((22.6, 0, 0), (25.0, 0, 0), 13.2, 0.6, "accent")
