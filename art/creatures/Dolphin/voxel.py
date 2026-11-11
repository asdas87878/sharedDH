"""The Dolphin (zone 5's Rare: a friendly grey bottlenose) for tools/blender/voxel_kit.py (docs/style/creature-brief.md).
Its idea: the friendly one. A rounded forehead over a short beak, a smile, a bright eye, and one thin pale line from the
corner of the mouth to the tail where the grey back meets the pale belly.
- The body is ten slices, each on its own joint. From one to the next one thing changes by one cube: the back rises to
  the fin and falls to the tail, the belly drops under the chest and rises, the sides narrow last (a dolphin's tail
  stock is thin from side to side and tall).
- The corners are cut in two steps where the body is thick, one where it is thin.
- The head is not a box: the forehead (the melon) is three turned blocks in a chain, each steeper, over a beak of two
  slim blocks with a dark mouth line between them. The line turns up on the cheek toward the eye: the smile.
- The eye is a dark pupil on a pale ring, with a small glint.
- The back fin is three boxes, each leaning further back, so it curves. Flippers of two boxes. Flat flukes on their own
  joint: a hub and two lobes swept back.
It swims by bending up and down, as dolphins do. The rider sits in front of the back fin, legs in a slot either side."""
import math

NAME, ZONE, RARITY = "Dolphin", "ZONE 5 / OPEN BLUE", "RARE"
U = 0.4
PALETTE = {"grey": "#7E8FA0", "belly": "#EEF0EC", "line": "#B9C7D3", "dark": "#46525F", "black": "#22262B"}
SEAT = (-5.5, 5, 3.6)
FRAME, ORTHO = 1.45, 21.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["grey"]}]

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice
SKULL = (3, -3, 3)
SLICES = ((3, 3, -3, 4), (3, 3, -3, 5), (5, 3, -4, 5), (2, 3, -4, 4), (2, 3, -3, 4), (2, 2, -3, 4), (2, 2, -3, 3), (2, 2, -2, 3),
          (2, 1, -2, 3), (2, 1, -2, 2))
BODY_FROM = -10
LINE = -1  # the row where the grey meets the belly: one level line from the mouth to the tail
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Fluke"]
AMPLITUDES = [1.5, 2, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 16]


def pose(parts, phase):
    """a dolphin's swim: the wave runs down the body up and down and grows toward the tail; the flukes beat at its end"""
    parts["Head"].rotation_euler.y = math.radians(2) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.5 * (k + 1))


def top_steps(n, bot, top):
    return [(2, 1), (1, 1)] if n >= 3 and top >= 4 else [(1, 1)]


def bottom_steps(n, bot, top):
    return [(2, 1), (1, 1)] if n >= 3 and bot <= -4 else [(1, 1)]


def colour(p, x0, x1, n, bot, top, lit=True):
    """grey above, the thin line, the pale belly below it"""
    if lit:
        p.paint_sym(x0, x1, n, top - 1, top, "grey+")
    p.paint_sym(x0, x1, n, LINE, LINE + 1, "line")
    p.paint_sym(x0, x1, n, bot, LINE, "belly")
    if bot <= -3:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")


def slab(p, x0, x1, n, bot, top):
    p.hull(x0, x1, n, bot, top, "grey", top_steps(n, bot, top), bottom_steps(n, bot, top))
    colour(p, x0, x1, n, bot, top)


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the back of the head, where the eye sits, and a narrower, lower block in front of it that the forehead stands on
    head.hull(-13, BODY_FROM, 3, -3, 3, "grey", [(1, 1)], [(1, 1)])
    colour(head, -13, BODY_FROM, 3, -3, 3)
    head.hull(-15, -13, 2, -3, 1, "grey", [], [(1, 1)])
    colour(head, -15, -13, 2, -3, 1, lit=False)
    # the forehead: three turned blocks in a chain, each steeper and narrower than the last (12, 37 and 64 degrees), from
    # the top of the head round to the beak. Each one's upper edge starts on the front edge of the one before, so the
    # faces meet in a bend and no end face shows
    head.beam((-12.553, 0, 1.776), (-14.453, 0, 1.376), 4.4, 2.4, "grey+", flat="z")
    head.beam((-14.045, 0, 1.704), (-15.295, 0, 0.754), 4.0, 2.0, "grey", flat="z")
    head.beam((-15.109, 0, 1.193), (-15.779, 0, -0.197), 3.6, 1.6, "grey", flat="z")
    # the beak: an upper block, a dark mouth line set in from the lips, a pale lower jaw a little longer than the upper
    head.beam((-14.8, 0, -0.30), (-19.2, 0, -0.45), 2.8, 1.1, "grey", flat="z")
    head.beam((-14.8, 0, -1.10), (-19.0, 0, -1.15), 2.0, 0.6, "dark", flat="z")
    head.beam((-14.8, 0, -1.90), (-19.5, 0, -1.85), 2.4, 1.1, "belly", flat="z")
    # the smile: the mouth line turns up on the cheek, toward the eye
    head.beam((-14.95, 2.5, -1.1), (-13.85, 2.5, -0.35), 0.3, 0.3, "dark", mirror=True)
    # the eye: a pale ring, a dark pupil standing out of it, a small glint
    ring = (3.3, 3.75, 0.2, 1.7)
    head.block(-12.6, ring, -11.1, ring, "belly", mirror=True)
    pupil = (3.6, 4.05, 0.45, 1.45)
    head.block(-12.35, pupil, -11.35, pupil, "black", mirror=True)
    glint = (3.9, 4.25, 1.0, 1.3)
    head.block(-12.2, glint, -11.9, glint, "belly", mirror=True)

    # the body: ten slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body: as wide as the narrower top row of the two, and
        # clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        mine_top, mine_bot = top_steps(n, bot, top), bottom_steps(n, bot, top)
        its_top, its_bot = (top_steps(fn, fbot, ftop), bottom_steps(fn, fbot, ftop)) if i else ([(1, 1)], [(1, 1)])
        half = min(n - mine_top[0][0], fn - its_top[0][0], n - mine_bot[0][0], fn - its_bot[0][0])
        seg.sym(x0 - 1, x0, max(half, 0), max(bot, fbot) + max(len(mine_bot), len(its_bot)),
                min(top, ftop) - max(len(mine_top), len(its_top)), "grey-")
    # the seat: in front of the back fin, a shallow slot either side for the rider's legs
    segs[1].dent(-6, -4, 3, 0, 3, "grey-")

    # the back fin: three boxes, each smaller and thinner and leaning further back than the last, so it curves
    segs[2].beam((-2.55, 0, 3.0), (0.2, 0, 6.85), 3.3, 1.1, "grey")
    segs[2].beam((-0.5, 0, 6.0), (1.5, 0, 8.0), 2.2, 0.8, "grey")
    segs[2].beam((0.9, 0, 7.4), (2.5, 0, 8.3), 1.4, 0.5, "grey-")
    # the flippers: two boxes, out and back from low on the chest
    segs[0].beam((-8.7, 1.6, -2.1), (-6.0, 5.4, -3.4), 2.6, 0.9, "grey", flat="z", mirror=True)
    segs[0].beam((-6.6, 4.6, -3.15), (-4.6, 6.6, -3.9), 1.8, 0.6, "grey-", flat="z", mirror=True)

    # the tail: a short stock, tall and thin, then the flukes on a joint of their own: a hub and two lobes swept back,
    # each ending in a darker tip. They lie flat
    segs[-1].beam((end - 0.6, 0, 0), (end + 1.4, 0, 0), 1.3, 1.7, "grey", flat="z")
    fluke = m.part("Fluke", (end + 0.6, 0, 0), f"S{len(SLICES)}")
    fluke.beam((end + 0.4, 0, 0), (end + 2.9, 0, 0), 4.8, 1.2, "grey", flat="z")
    fluke.beam((end + 1.65, 1.3, 0), (end + 3.63, 3.94, 0), 3.0, 0.8, "grey", flat="z", mirror=True)
    fluke.beam((end + 2.9, 3.2, 0), (end + 4.3, 4.9, 0), 1.9, 0.4, "grey-", flat="z", mirror=True)
