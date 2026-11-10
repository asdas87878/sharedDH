"""Elasmosaurus (zone 5's Legendary: the prehistoric sea reptile whose neck is longer than its body) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md).
Its idea: the neck. A small needle-toothed head on thirteen short slices, each on its own joint, so the neck snakes
while the barrel body stays stiff and rows itself along on four long flippers.
- The neck grows from three cubes across at the head to seven at the shoulders, one step at a time: width, or back, or
  belly, never two at once. Every second slice wears one raised gold ring, so the rings count the neck out and grow
  with it (the echo of the eye).
- The body is one stiff barrel (a plesiosaur's trunk did not bend), far wider than the neck: short slices climb to it
  over the shoulders, one step at a time; a wide flat back and two broad steps.
- Four long flippers, each on its own joint: an arm that goes out, a paddle that turns back, a darker tip.
- A short tail in three jointed pieces.
- The head: a small skull, a snout of two tilted blocks, a jaw that hangs open, long needle teeth that lean forward and
  cross. The eye is a dark pupil in a thin halo of soft light, under a brow that slants down to the front.
Extras (three kinds): the eye's halo, the gold rings, the dark flipper tips.
The rider sits on the body where it is biggest, on the wide flat of its back; never on the neck."""
import math

NAME, ZONE, RARITY = "Elasmosaurus", "ZONE 5 / OPEN BLUE", "LEGENDARY"
U = 0.45
PALETTE = {"sea": "#1F8A7A", "belly": "#F0E4C4", "gold": "#E8A93C", "soft": "#F6CF7A", "black": "#1E2226", "tooth": "#FFFFFF",
           "mouth": "#6A2630", "gum": "#9A4F58"}
SEAT = (11.5, 6, 7.5)
GLOW = {"soft": 0.4}  # only the thin halo of the eye
FRAME, ORTHO, ORTHO_SWIM = 3.3, 48.0, 54.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["sea"]}]

# each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
NECK = ((3, 1, -1, 2),) * 4 + ((3, 1, -2, 2),) * 3 + ((3, 2, -2, 2),) * 2 + ((4, 2, -2, 3), (3, 2, -2, 3), (4, 2, -3, 3), (3, 3, -3, 3))
# the barrel: short slices climb to it from the neck (the shoulders) and fall from it to the tail; it is stiff, one part
BODY = ((2, 4, -3, 3), (2, 4, -3, 4), (2, 5, -3, 4), (2, 5, -4, 4), (2, 6, -4, 4), (2, 6, -4, 5), (2, 6, -5, 5), (2, 7, -5, 5),
        (3, 7, -5, 6), (2, 7, -5, 5), (2, 6, -5, 5), (2, 6, -4, 5), (2, 6, -4, 4), (2, 5, -4, 4))
TAIL = ((2, 5, -3, 4), (2, 4, -3, 4), (2, 4, -3, 3), (2, 3, -3, 3), (2, 3, -2, 3), (2, 2, -2, 3), (2, 2, -2, 2), (2, 2, -1, 2),
        (1, 1, -1, 2))
TAIL_PARTS = ((0, 1, 2), (3, 4, 5), (6, 7, 8))  # which tail slices share a joint
NECK_FROM = -47
SKULL = (2, -2, 2)
RINGED = (1, 3, 5, 7, 9, 11)  # the neck slices that wear a gold ring
NECK_CHAIN = [f"N{i}" for i in range(len(NECK), 0, -1)]  # from the shoulders to the head


def pose(parts, phase):
    """a plesiosaur's swim: the barrel stays stiff and the four flippers fly it along, front pair and hind pair in turn.
    A slow wave runs up the neck from the shoulders to the head, side to side with a little rise and fall, and the head
    turns back against it, so it keeps looking where it is going. The tail trails"""
    total = 0.0
    for k, name in enumerate(NECK_CHAIN):
        turn = math.radians(2.5 + 0.3 * k) * math.sin(phase - 0.55 * k)
        parts[name].rotation_euler.z = turn
        parts[name].rotation_euler.y = math.radians(0.8) * math.sin(phase - 0.55 * k + 1.3)
        total += turn
    parts["Head"].rotation_euler.z = -0.7 * total
    for name, side, lag in (("FlipperFR", 1, 0.0), ("FlipperFL", -1, 0.0), ("FlipperHR", 1, 2.2), ("FlipperHL", -1, 2.2)):
        parts[name].rotation_euler.x = side * math.radians(17) * math.sin(phase - lag)
        parts[name].rotation_euler.z = side * math.radians(8) * math.sin(phase - lag - 1.2)
    for k, name in enumerate(("Tail1", "Tail2", "Tail3")):
        parts[name].rotation_euler.z = math.radians(3 + 2 * k) * math.sin(phase + 2.0 - 0.7 * k)


def top_steps(n):
    """the corners of the back: a wide flat plateau and one or two broad steps; the thin neck is a plain box"""
    return [(3, 1), (1, 1)] if n >= 6 else ([(2, 1), (1, 1)] if n == 5 else ([(1, 1)] if n >= 2 else []))


def belly_edge(bot):
    """how high the pale belly comes: one line from the neck to the tail, a step higher where the animal is thinnest"""
    return -1 if bot <= -2 else 0


def slab(p, x0, x1, n, bot, top):
    """a slice: stepped corners, the back colour with a lighter top row, a pale belly"""
    steps = top_steps(n)
    p.hull(x0, x1, n, bot, top, "sea", steps, steps)
    p.paint_sym(x0, x1, n, top - 1, top, "sea+")
    edge = belly_edge(bot)
    p.paint_sym(x0, x1, n, bot, edge, "belly")
    if steps and edge - bot >= 2:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def sleeve(p, x0, piece, front):
    """a sleeve one cube into the piece in front, so a bending joint shows body: sized from the smaller of the two and
    kept clear of both pieces' corner steps"""
    (n, bot, top), (fn, fbot, ftop) = piece, front
    clear = max(len(top_steps(n)), len(top_steps(fn)), 1)
    p.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + clear, min(top, ftop) - clear, "sea-")


def spans(slices, start):
    out, x = [], start
    for length, n, bot, top in slices:
        out.append((x, x + length, n, bot, top))
        x += length
    return out


def build(m):
    neck, body_spans = spans(NECK, NECK_FROM), spans(BODY, NECK_FROM + sum(s[0] for s in NECK))
    tail_spans = spans(TAIL, body_spans[-1][1])

    # the body: one stiff barrel, the root of everything
    body = m.part("Body", (11.5, 0, 0))
    for x0, x1, n, bot, top in body_spans:
        slab(body, x0, x1, n, bot, top)
    sleeve(body, body_spans[0][0], body_spans[0][2:], neck[-1][2:])

    # the neck: thirteen short slices, each on its own joint at its back end, from the shoulders to the head
    for i in range(len(neck) - 1, -1, -1):
        x0, x1, n, bot, top = neck[i]
        seg = m.part(f"N{i + 1}", (x1, 0, (bot + top) / 2), "Body" if i == len(neck) - 1 else f"N{i + 2}")
        slab(seg, x0, x1, n, bot, top)
        sleeve(seg, x0, (n, bot, top), neck[i - 1][2:] if i else SKULL)
        if i in RINGED:  # one raised gold ring round the middle of the slice, down to the belly's edge
            mid = (x0 + x1) / 2
            low = belly_edge(bot) - 0.3  # off the grid's planes, so no face of the ring lies on a face of the cubes
            if top_steps(n):
                seg.band(mid - 0.5, mid + 0.5, n, bot, top, "gold", top_steps(n), top_steps(n), stop=low)
            else:  # a plain box has no steps for a band to sit on: a plate sunk into the back and one into each side
                plate = (-(n + 0.2), n + 0.2, top - 0.3, top + 0.3)
                seg.block(mid - 0.5, plate, mid + 0.5, plate, "gold+")
                side = (n + 0.2, n + 0.8, low, top + 0.3)
                seg.block(mid - 0.5, side, mid + 0.5, side, "gold", mirror=True)

    # the head: a small skull; the snout is two blocks in a chain, each tilted a little nose-down, lower and narrower than
    # the last, with a pale lip plate underneath and a thin dark gum line set inside the lip's edge
    head = m.part("Head", (NECK_FROM, 0, 0.5), "N1")
    head.hull(-51, NECK_FROM, 2, -2, 2, "sea", [(1, 1)], [])
    head.paint_sym(-51, NECK_FROM, 2, 1, 2, "sea+")
    head.paint_sym(-51, NECK_FROM, 2, -2, -1, "belly")
    blocks = ((-49.5, -53.2, 0.7, 0.45, 4.2, 2.0, -49.6), (-52.6, -55.6, 0.4, 0.2, 3.0, 1.4, -53.5))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.6

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "sea", flat="z")
        lip = thick / 2 + 0.3
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.6, "belly", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.075), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.075), wide - 1.0, 0.25,
                  "gum", flat="z")
    # the lower jaw hangs open: two slim boxes in a chain, hinged inside the skull, with its own gum line
    jaws = ((-48.8, -52.8, -1.5, -2.45, 3.4, 0.8, -49.6), (-52.2, -55.0, -2.31, -2.87, 2.2, 0.5, -53.0))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "belly", flat="z")
        head.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.2, 0, jaw_top(k, x1 + 0.2) + 0.05), wide - 0.6, 0.2, "gum",
                  flat="z")
    # the dark inside of the mouth: one block that widens as the mouth opens, its ends inside the skull, lips and jaw
    head.block(-50.3, (-1.2, 1.2, -1.8, -0.8), -54.5, (-0.5, 0.5, -2.7, -0.9), "mouth")
    # needle teeth, bases sunk into the gums: longer toward the front, leaning forward, upper and lower in turn
    for k, x, y, length, lean in ((0, -51.2, 1.35, 0.6, -0.1), (0, -52.3, 1.35, 0.8, -0.15), (1, -53.7, 0.75, 1.0, -0.25),
                                  (1, -54.35, 0.75, 1.2, -0.3), (1, -55.0, 0.75, 1.2, -0.4)):
        head.tooth(x, y, lip_bottom(k, x) - 0.1, 0.4, length, "tooth", lean=(lean, 0.0))
    for k, x, y, length in ((0, -51.75, 1.15, 0.5), (1, -53.3, 0.55, 0.8), (1, -54.02, 0.55, 1.0), (1, -54.55, 0.55, 1.0)):
        head.tooth(x, y, jaw_top(k, x) + 0.05, 0.4, -length, "tooth", lean=(-0.2, 0.0))
    # the eye: a dark socket on the skull's side, a thin halo of soft light, a dark pupil standing out of it. The brow sits
    # on the eye, slants down to the front and comes past it
    socket = (2.4, 2.75, -0.5, 0.8)
    head.block(-50.4, socket, -48.7, socket, "sea-", mirror=True)
    halo = (2.65, 2.95, -0.3, 0.6)
    head.block(-50.2, halo, -48.9, halo, "soft", mirror=True)
    pupil = (2.85, 3.15, -0.1, 0.4)
    head.block(-49.95, pupil, -49.15, pupil, "black", mirror=True)
    head.beam((-50.8, 2.7, 0.75), (-48.4, 2.7, 0.95), 0.8, 1.2, "sea", mirror=True)

    # the tail: short, three jointed pieces
    for t, group in enumerate(TAIL_PARTS):
        first = tail_spans[group[0]]
        part = m.part(f"Tail{t + 1}", (first[0], 0, 0), "Body" if t == 0 else f"Tail{t}")
        for i in group:
            slab(part, *tail_spans[i])
        sleeve(part, first[0], first[2:], (tail_spans[group[0] - 1] if t else body_spans[-1])[2:])

    # four long flippers, each on its own joint: an arm that goes out from low on the side, a paddle that turns back from
    # it, a darker tip. Each box is smaller and thinner than the one before and starts inside it; the arm's root is buried
    front = (((3.0, 2.5, -2.2), (5.8, 9.5, -3.3), 4.6, 1.3, "sea"), ((5.18, 7.96, -3.06), (12.5, 15.0, -4.6), 4.0, 0.85, "sea"),
             ((11.04, 13.59, -4.29), (15.5, 17.0, -5.1), 2.8, 0.45, "sea-"))
    hind = (((18.5, 2.5, -2.2), (20.8, 8.6, -3.2), 4.2, 1.2, "sea"), ((20.29, 7.26, -2.98), (26.5, 13.2, -4.4), 3.6, 0.8, "sea"),
            ((25.26, 12.01, -4.12), (29.0, 15.0, -4.9), 2.5, 0.42, "sea-"))
    for name, boxes, pivot_x, pivot_y in (("FlipperF", front, 3.5, 5.5), ("FlipperH", hind, 19.0, 6.0)):
        for tag, side in (("R", 1), ("L", -1)):
            part = m.part(name + tag, (pivot_x, pivot_y * side, -2.5), "Body")
            for (ax, ay, az), (bx, by, bz), wide, thick, colour in boxes:
                part.beam((ax, side * ay, az), (bx, side * by, bz), wide, thick, colour, flat="z")
