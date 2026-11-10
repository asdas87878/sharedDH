"""The Bobbit Worm (proposed for zone 8, the Vents: a Legendary) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed as a Legendary by docs/style/05-rarity-look.md. The first worm body. Designed from
the animal itself (Eunice aphroditois, and its giant prehistoric cousin Websteroprion), not from another creature's build.
Its idea: the ambush. A long ribbon of shimmering rings, and at the front of it a pair of scissor jaws held open.
- The jaws are the focal point: two dark hooks, each on its own joint, opening sideways, with pale teeth on the inner
  edge. They are modelled open; in the swim they snap shut.
- Five banded feelers fan back from the head (pale, dark, then a tip of soft light: the triggers of the trap). They are
  one part, so they trail.
- The body is 31 short rings in eleven parts and a tail tip. Each ring is two cubes: a dark groove, then the ring, with
  one small foot each side. It is a little flattened, wider than tall, and tapers one step at a time.
- Its colour is its shimmer, in paint: bronze at the head, through copper, rose and plum, to indigo at the tail. The back
  of every ring is painted in the hue that comes next, so the colour seems to slide along it.
- The tail ends in two pale feelers: the head's echo.
The rider sits on the second part, behind the feelers, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Bobbit Worm", "ZONE 8 / VENTS", "LEGENDARY"
U = 0.46
HUES = ["bronze", "copper", "rose", "plum", "violet", "indigo"]
PALETTE = {"bronze": "#B07A3C", "copper": "#B25A3E", "rose": "#A6466C", "plum": "#7B3F8F", "violet": "#56479F", "indigo": "#3B4C96",
           "belly": "#E3C8B6", "jaw": "#2E2622", "tooth": "#F3E9D2", "cream": "#EADBBE", "band": "#4A3326", "black": "#1F1B1C",
           "mouth": "#7A2230", "lume": "#8EF5C0"}
SEAT = (5, 4, 6.5)
GLOW = {"lume": 0.6}  # only the tips of the five feelers
FRAME, ORTHO, ORTHO_SWIM = 2.75, 41.0, 42.0
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(11)] + ["Tip"]
AMPLITUDES = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16]


def pose(parts, phase):
    """a ribbon's wave down the long chain; the jaws swing in and snap, then ease open; the feelers trail"""
    parts["Head"].rotation_euler.z = math.radians(3) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.55 * (k + 1))
    beat = math.sin(phase)
    # from the open pose they are modelled in: a quick snap until the tips meet (5 degrees), then a slow, wide opening
    swing = math.radians(5) * max(beat, 0.0) ** 3 - math.radians(14) * max(-beat, 0.0)
    parts["JawR"].rotation_euler.z = swing
    parts["JawL"].rotation_euler.z = -swing
    parts["Feelers"].rotation_euler.y = math.radians(7) * math.sin(phase - 0.8)
    parts["Feelers"].rotation_euler.z = math.radians(4) * math.sin(phase - 1.4)


def steps_for(n):
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def ring(p, x0, n, bot, top, hue, nxt, foot=True):
    """one ring of the body, two cubes long: on the flank the first cube is the groove (a tone darker), the second the
    ring. Pale underneath; the back is painted in the next hue along, a tone lighter: the shimmer. foot: a small foot
    each side, standing out of the groove"""
    st = steps_for(n)
    rows = max(len(st), 1)
    p.hull(x0, x0 + 2, n, bot, top, hue, st, st)
    p.paint_sym(x0, x0 + 1, n, bot + rows, top - rows, hue + "-")  # the groove, on the flat of the flank
    p.paint_sym(x0, x0 + 2, n, top - 1, top, nxt + "+")
    p.paint_sym(x0, x0 + 1, n, top - 1, top, nxt)  # the groove runs over the back too: the rider looks down on rings
    p.paint_sym(x0, x0 + 2, n, bot, bot + rows, "belly")
    if foot and n >= 2:
        p.pair(x0, x0 + 1, n + 1, n + 2, bot + rows, bot + rows + 1, hue + "-")  # on the first row that is full width


def build(m):
    head = m.part("Head", (-4, 0, 0))
    # the head: a low flat block, bronze, a darker collar at the front with the red mouth set in it
    st = steps_for(5)
    head.hull(-8, -4, 5, -3, 4, "bronze", st, st)
    head.paint_sym(-8, -4, 5, 3, 4, "copper+")
    head.paint_sym(-8, -4, 5, -3, -1, "belly")
    head.hull(-9, -8, 4, -2, 3, "bronze-", [(1, 1)], [(1, 1)])
    mouth = (-2.8, 2.8, -1.5, 1.8)
    head.block(-9.3, mouth, -8.8, mouth, "mouth")
    # small eyes on top of the head, by the roots of the feelers: a pale ring, a dark bead in it. No light
    eye = (1.6, 2.9, 3.9, 4.12)
    head.block(-7.5, eye, -6.3, eye, "cream", mirror=True)
    bead = (1.9, 2.6, 4.0, 4.35)
    head.block(-7.25, bead, -6.55, bead, "black", mirror=True)

    # the jaws: two big dark hooks that open sideways, each on its own joint. Three boxes in a chain, each smaller,
    # turning inward to a point; pale teeth on the inner edge. Modelled open: the trap is set
    for name, s in (("JawR", 1), ("JawL", -1)):
        jaw = m.part(name, (-8.4, 3.4 * s, 0.2), "Head")
        # deep blades, and the outer two boxes dip a little: from the side it is a hooked fang, not a flat bar
        jaw.beam((-8.2, 3.4 * s, 0.2), (-13.0, 5.4 * s, 0.2), 2.2, 2.8, "jaw", flat="z")
        jaw.beam((-12.2, 5.1 * s, 0.2), (-16.0, 3.9 * s, -0.5), 1.8, 2.0, "jaw", flat="z")
        jaw.beam((-15.3, 4.12 * s, -0.37), (-17.9, 1.5 * s, -1.3), 1.3, 1.3, "jaw-", flat="z")
        for (xa, xb, y, za, zb, tip_x, tip_y) in ((-10.5, -9.5, 3.3, -0.4, 0.8, -10.2, 1.6), (-12.4, -11.4, 4.1, -0.4, 0.8, -12.1, 2.4),
                                                  (-14.6, -13.8, 3.85, -0.3, 0.7, -14.4, 2.3)):
            jaw.spike([(xa, y * s, za), (xb, y * s, za), (xb, y * s, zb), (xa, y * s, zb)], (tip_x, tip_y * s, 0.2), "tooth")

    # the five feelers, fanning back from the top of the head: one part, so they trail. Each is three boxes in a chain:
    # pale, a dark band, then a tip of soft light
    feelers = m.part("Feelers", (-5.6, 0, 3.6), "Head")
    for (y0, z0), (dx, dy, dz) in (((0.0, 3.3), (5.6, 0.0, 4.8)), ((1.9, 3.2), (4.6, 1.7, 3.4)), ((-1.9, 3.2), (4.6, -1.7, 3.4)),
                                   ((4.0, 1.2), (3.8, 3.0, 1.6)), ((-4.0, 1.2), (3.8, -3.0, 1.6))):
        def at(f):
            return (-5.9 + dx * f, y0 + dy * f, z0 + dz * f)

        feelers.beam(at(0.0), at(0.45), 1.0, 1.0, "cream")
        feelers.beam(at(0.36), at(0.78), 0.7, 0.7, "band")
        feelers.beam(at(0.7), at(1.0), 0.4, 0.4, "lume")

    # the body: eleven parts of three rings each, then of two; each part (from, rings, cubes out, bottom, top). It is one
    # step smaller at a time, in width or in height, never both
    parts = ((-4, 3, 6, -3, 4), (2, 3, 6, -4, 4), (8, 3, 6, -4, 4), (14, 3, 6, -4, 4), (20, 3, 6, -3, 4), (26, 3, 5, -3, 4),
             (32, 3, 5, -3, 3), (38, 2, 4, -3, 3), (42, 2, 4, -2, 3), (46, 2, 3, -2, 3), (50, 2, 3, -2, 2))
    total = sum(count for _, count, _, _, _ in parts) + 3
    segs = [m.part(f"S{i + 1}", (pt[0], 0, 0), "Head" if i == 0 else f"S{i}") for i, pt in enumerate(parts)]
    done = 0
    for i, (seg, (x0, count, n, bot, top)) in enumerate(zip(segs, parts)):
        for r in range(count):
            hue = HUES[min(len(HUES) - 1, done * len(HUES) // total)]
            nxt = HUES[min(len(HUES) - 1, HUES.index(hue) + 1)]
            ring(seg, x0 + 2 * r, n, bot, top, hue, nxt, foot=done % 2 == 0 and not (i == 1 and r == 1))  # a foot on every other ring
            done += 1
        # a sleeve into the piece in front, sized from the smaller of the two and clear of its steps
        fn, fbot, ftop = parts[i - 1][2:5] if i else (5, -3, 4)
        low, high = max(bot, fbot) + 2, min(top, ftop) - 2
        if high > low:
            seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), low, high, "belly-")
    # the seat: a shallow slot either side for the rider's legs
    segs[1].dent(4, 6, 6, 0, 2, "bronze-")

    # the tail tip: two last small rings and a nub, and two pale feelers trailing from it: the head's echo
    tip = m.part("Tip", (54, 0, 0), "S11")
    ring(tip, 54, 2, -2, 2, "indigo", "indigo", foot=False)
    ring(tip, 56, 2, -1, 2, "indigo", "indigo", foot=False)
    tip.hull(58, 60, 1, -1, 2, "indigo")
    tip.paint_sym(58, 60, 1, -1, 0, "belly")
    tip.beam((59.3, 0.6, 0.6), (62.2, 1.6, 1.0), 0.8, 0.8, "cream", mirror=True)
    tip.beam((61.6, 1.4, 0.92), (64.0, 2.4, 1.3), 0.5, 0.5, "band", mirror=True)
