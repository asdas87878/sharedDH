"""The Lantern Leviathan (zone 6's Mythic: a gulper eel grown to the size of a whale) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md, docs/style/creature-brief.md). Designed from the real gulper: all jaw, then all tail.
Its idea: a mouth with a lantern hung in front of it, and a long dark serpent behind that the lantern's light runs down.
- The head is its own shape and the tallest thing on it: a short domed skull, a forehead block turned nose-down, a flat
  upper jaw of three blocks in a chain, and a jaw hinge that flares out wider than the skull (a gulper's does). From above the head is a spade: neck, skull, hinge, then a taper to the snout.
- The lower jaw is its own part, hung open from the hinge: three blocks in a chain, wider than the upper jaw and a little
  longer (a ladle), with a paler pouch underneath. Needle teeth on a thin gum line set inside both jaws' edges.
- A rod from the forehead, in two parts, and a lantern on a line before the mouth: a dark roof, foot and corner posts round a gold light.
- The body is sixteen slices on joints. One number changes from slice to slice: the back falls away from the head in
  broad steps, the belly sags behind the neck (a gulper's stomach) and rises again, the width tapers to a three-cube tail.
- Two thin lines run the whole animal: a lilac line along each flank, which goes on as the upper lip to the snout, with
  one lantern-gold spot on it per slice; and a thin raised stripe down the middle of the back and the snout.
- A whip tail in three thin boxes, each on its joint, ending in a small gold light: the lantern's echo.
- The eye is small, far forward: a dark pupil in a thin halo, under a brow that comes past it.
It swims as an eel does, side to side, the wave growing down the body to the whip. The jaw gulps; the lantern swings."""
import math

NAME, ZONE, RARITY = "Lantern Leviathan", "ZONE 6 / TWILIGHT", "MYTHIC"
U = 0.45
PALETTE = {"plum": "#33253B", "belly": "#5B4563", "line": "#8A6CA6", "gold": "#FFC247", "soft": "#F4B860", "mouth": "#5A1E33",
           "gum": "#8E4A5C", "tooth": "#FFF6E0", "black": "#151218"}
SEAT = (10.5, 6, 5.5)
GLOW = {"gold": 1.0, "soft": 0.4}  # the lantern, the spots down the flanks, the tail's tip; the eye's thin halo
LIGHTS = [("Lure", (-27.5, 0, -3.8), "#FFC247", 60, 0.6), ("Tail3", (72.8, 0, 0.5), "#FFC247", 20, 0.4)]
FRAME, ORTHO, ORTHO_SWIM = 3.6, 52.0, 58.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["plum"]}]

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((4, 5, -4, 6), (4, 5, -5, 6), (5, 5, -6, 6), (5, 5, -6, 5), (5, 5, -5, 5), (4, 4, -5, 5), (4, 4, -4, 5), (4, 4, -4, 4),
          (4, 4, -3, 4), (4, 3, -3, 4), (3, 3, -3, 3), (3, 3, -2, 3), (3, 2, -2, 3), (3, 2, -2, 2), (3, 2, -1, 2), (2, 1, -1, 2))
SKULL = (6, -4, 7)
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail1", "Tail2", "Tail3"]
AMPLITUDES = [2, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 9, 10, 12, 16, 20]


def pose(parts, phase):
    """an eel's swim: a wave runs down the long chain side to side and grows toward the whip of the tail. The jaw gulps
    once a beat; the rod nods and the lantern swings late behind it"""
    s = math.sin
    parts["Head"].rotation_euler.z = math.radians(2) * s(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * s(phase - 0.38 * (k + 1))
    parts["Jaw"].rotation_euler.y = math.radians(2) - math.radians(8) * (0.5 + 0.5 * s(phase))
    # the rod and the lantern swing mostly side to side: fore and aft only a little, so the lantern stays clear of the teeth
    parts["Rod1"].rotation_euler.y = math.radians(1.5) * s(phase - 0.8)
    parts["Rod2"].rotation_euler.y = math.radians(2) * s(phase - 1.5)
    parts["Rod2"].rotation_euler.x = math.radians(4) * s(phase - 1.2)
    parts["Lure"].rotation_euler.x = math.radians(10) * s(phase - 2.4)
    parts["Lure"].rotation_euler.y = math.radians(4) * s(phase - 2.0)


def top_steps(n):
    """the corners of the back: three steps where the body is thick, fewer as it thins, none on the last"""
    return [(3, 1), (2, 1), (1, 1)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else ([(1, 1)] if n >= 2 else []))


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def line_row(bot):
    """the flank line's height: one level row the whole way, a step up only on the last thin slices"""
    return -1 if bot <= -2 else 0


def slab(p, x0, x1, n, bot, top):
    """a slice of body: stepped corners, near-black plum (a tone lighter on the top row), a duller belly, and between
    them the thin lilac flank line"""
    p.hull(x0, x1, n, bot, top, "plum", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "plum+")
    row = line_row(bot)
    p.paint_sym(x0, x1, n, bot, row, "belly")
    if row - bot >= 2:
        p.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
    p.paint_sym(x0, x1, n, row, row + 1, "line")


def run(block, t0, t1, off):
    """two points on a jaw block's middle line (block = x0, x1, z0, z1, ...), at fractions t0 and t1 of its length, moved
    `off` along its upward normal: where a plate on its top (off > 0) or its underside (off < 0) lies"""
    x0, x1, z0, z1 = block[:4]
    dx, dz = x1 - x0, z1 - z0
    length = math.hypot(dx, dz)
    nx, nz = dz / length, -dx / length
    return (x0 + dx * t0 + nx * off, 0, z0 + dz * t0 + nz * off), (x0 + dx * t1 + nx * off, 0, z0 + dz * t1 + nz * off)


def surface(block, x, off):
    """the height, at x, of a plane `off` above a block's middle line (negative: below)"""
    x0, x1, z0, z1 = block[:4]
    dx, dz = x1 - x0, z1 - z0
    return z0 + dz * (x - x0) / dx + off * math.hypot(dx, dz) / abs(dx)


def build(m):
    head = m.part("Head", (0, 0, 0))
    # the skull: short and tall, with two-step corners. The flank line runs through it under the eye
    n, bot, top = SKULL
    head.hull(-9, 0, n, bot, top, "plum", [(2, 1), (1, 1)], [(1, 1)])
    head.paint_sym(-9, 0, n, top - 1, top, "plum+")
    head.paint_sym(-9, 0, n, bot, -1, "belly")
    head.paint_sym(-9, 0, n, bot, bot + 1, "belly-")
    head.paint_sym(-9, 0, n, -1, 0, "line")
    # the jaw's hinge: a dark block low on the head, wider than the skull, that the lower jaw hangs from
    head.sym(-8, -3, 7, -5, -1, "plum")
    head.paint(-9, -8, -5, 6, -4, -1, "mouth")  # the throat, seen between the jaws
    # the stripe down the back starts on the skull
    stripe = (-0.35, 0.35, top - 0.15, top + 0.3)
    head.block(-8.85, stripe, -0.15, stripe, "line")
    # the forehead: one block turned nose-down, from the top of the skull onto the upper jaw, with the stripe on it
    fore = (-6.5, -12.5, 5.3, 3.4)
    head.beam(*run(fore, 0, 1, 0), 8.4, 2.6, "plum", flat="z")
    head.beam(*run(fore, 0.35, 0.89, 1.3 + 0.175), 0.7, 0.45, "line", flat="z")

    # the upper jaw: three flat blocks in a chain, each tilted a little nose-down, lower and narrower than the last and
    # starting inside it. Under each: a lilac lip (the flank line goes on along it), a thin gum set in from the lip's
    # edge, and the dark roof of the mouth inside the teeth. On each: the back's thin stripe
    uppers = ((-8.6, -15.0, 1.9, 1.2, 12.4, 3.4, 0.0, 0.7), (-14.2, -20.0, 1.15, 0.45, 9.6, 2.6, 0.172, 0.19),
              (-19.2, -24.0, 0.4, -0.05, 6.6, 1.8, 0.229, 0.229))
    for b in uppers:
        wide, thick, gum_from, stripe_from = b[4:]
        length = math.hypot(b[1] - b[0], b[3] - b[2])
        head.beam(*run(b, 0, 1, 0), wide, thick, "plum", flat="z")
        head.beam(*run(b, 0, 1, -(thick / 2 + 0.3)), wide - 0.4, 0.6, "line", flat="z")
        head.beam(*run(b, gum_from, 1 - 0.3 / length, -(thick / 2 + 0.65)), wide - 1.0, 0.2, "gum", flat="z")
        head.beam(*run(b, gum_from + 0.3 / length, 1 - 0.6 / length, -(thick / 2 + 0.75)), wide - 2.6, 0.5, "mouth", flat="z")
        head.beam(*run(b, stripe_from, 1 - 0.7 / length, thick / 2 + 0.175), 0.7, 0.45, "line", flat="z")

    def lip_bottom(k, x):
        return surface(uppers[k], x, -(uppers[k][5] / 2 + 0.6))

    # needle teeth, bases sunk in the gum: down each side, longest at the front
    for k, x, y, long in ((0, -9.9, 5.35, 1.5), (0, -11.4, 5.35, 1.7), (0, -12.9, 5.35, 1.5), (0, -14.3, 5.35, 1.7),
                          (1, -15.9, 3.95, 1.6), (1, -17.3, 3.95, 1.9), (1, -18.7, 3.95, 1.6),
                          (2, -21.0, 2.45, 1.8), (2, -22.3, 2.45, 2.1), (2, -23.15, 1.3, 2.3)):
        head.tooth(x, y, lip_bottom(k, x) - 0.05, 0.55, long, "tooth")
    head.tooth(-23.15, 0.0, lip_bottom(2, -23.15) - 0.05, 0.55, 2.0, "tooth", mirror=False)

    # the eye, far forward on the skull's side: a dark socket, a thin halo of soft light, a dark pupil standing out of it.
    # The brow sits on the eye, slants down to the front and comes past it onto the jaw
    ring = (6.38, 6.97, 0.2, 2.6)
    head.block(-8.3, ring, -5.7, ring, "plum-", mirror=True)
    halo = (6.85, 7.15, 0.5, 2.3)
    head.block(-7.95, halo, -6.05, halo, "soft", mirror=True)
    pupil = (6.97, 7.33, 0.85, 1.95)
    head.block(-7.6, pupil, -6.4, pupil, "black", mirror=True)
    head.beam((-9.7, 6.81, 1.9), (-5.0, 6.81, 2.9), 1.2, 1.32, "plum", mirror=True)

    # the lower jaw, on its own joint at the hinge and hanging open: three blocks in a chain, wider than the upper jaw
    # and a little longer. On each: the gum line inside its edge, the mouth's dark floor inside the teeth. Under the
    # first two: a paler pouch
    jaw = m.part("Jaw", (-5.0, 0, -3.5), "Head")
    lowers = ((-5.0, -14.0, -3.5, -6.875, 13.6, 3.0, 0.4, 1.0), (-13.0, -20.0, -6.6, -9.225, 10.6, 2.3, 0.186, 0.7),
              (-19.0, -25.0, -9.0, -11.25, 7.4, 1.6, 0.217, 0.0))
    for b in lowers:
        wide, thick, gum_from, pouch = b[4:]
        length = math.hypot(b[1] - b[0], b[3] - b[2])
        jaw.beam(*run(b, 0, 1, 0), wide, thick, "plum", flat="z")
        jaw.beam(*run(b, gum_from, 1 - 0.3 / length, thick / 2 + 0.05), wide - 1.0, 0.2, "gum", flat="z")
        jaw.beam(*run(b, gum_from + 0.3 / length, 1 - 0.7 / length, thick / 2 + 0.15), wide - 3.0, 0.5, "mouth", flat="z")
        if pouch:
            jaw.beam(*run(b, 0.25, 0.93, -(thick / 2 + pouch / 2 - 0.1)), wide - 2.2, pouch, "belly", flat="z")

    def jaw_top(k, x):
        return surface(lowers[k], x, lowers[k][5] / 2)

    for k, x, y, long in ((0, -10.2, 6.0, 1.4), (0, -11.7, 6.0, 1.6), (0, -13.2, 6.0, 1.4),
                          (1, -15.0, 4.5, 1.7), (1, -16.7, 4.5, 1.5), (1, -18.4, 4.5, 1.7),
                          (2, -20.8, 2.9, 1.6), (2, -22.3, 2.9, 1.9), (2, -23.8, 2.9, 1.6), (2, -24.35, 1.4, 2.1)):
        jaw.tooth(x, y, jaw_top(k, x) - 0.05, 0.55, -long, "tooth", lean=(-0.3 * long, 0.0))
    jaw.tooth(-24.35, 0.0, jaw_top(2, -24.35) - 0.05, 0.55, -1.8, "tooth", mirror=False, lean=(-0.55, 0.0))

    # the lantern: a rod from the forehead in two boxes, each on its own joint, then a line and the lantern on a third,
    # hung before the mouth: a dark roof and foot, four corner posts, a gold light inside
    rod1 = m.part("Rod1", (-6.4, 0, 6.2), "Head")
    rod1.beam((-6.4, 0, 6.2), (-14.5, 0, 9.6), 1.2, 1.1, "plum")
    rod2 = m.part("Rod2", (-14.2, 0, 9.45), "Rod1")
    rod2.beam((-14.0, 0, 9.4), (-27.8, 0, 6.2), 0.8, 0.7, "plum")
    lure = m.part("Lure", (-27.4, 0, 6.3), "Rod2")
    lure.beam((-27.4, 0, 6.3), (-27.5, 0, -1.5), 0.4, 0.4, "plum")
    knob = (-0.9, 0.9, -1.8, -1.2)
    lure.block(-28.4, knob, -26.6, knob, "plum")
    roof = (-1.95, 1.95, -2.35, -1.65)  # a roof and a foot wider than the light, and a post at each corner between them
    lure.block(-29.45, roof, -25.55, roof, "plum")
    light = (-1.6, 1.6, -5.4, -2.2)
    lure.block(-29.1, light, -25.9, light, "gold")
    post = (1.25, 1.8, -5.45, -2.15)
    lure.block(-29.3, post, -28.75, post, "plum", mirror=True)
    lure.block(-26.25, post, -25.7, post, "plum", mirror=True)
    foot = (-1.95, 1.95, -5.95, -5.3)
    lure.block(-29.45, foot, -25.55, foot, "plum")

    # the body: sixteen slices, each on its own joint
    segs, spans, x = [], [], 0
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' corner steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        small = min(n, fn)
        up = max(len(top_steps(n)), len(top_steps(fn)) if i else 2, 1)
        down = max(len(bottom_steps(n)), len(bottom_steps(fn)) if i else 1, 1)
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "plum-")
        # one lantern-gold spot on the flank line, in the middle of the slice
        row, mid = line_row(bot), (x0 + x1) // 2
        seg.paint_pair(mid - (1 if x1 - x0 >= 4 else 0), mid + 1, n, n + 1, row, row + 1, "gold")
        # the thin stripe down the middle of the back, a little proud, stopping short of each joint
        stripe = (-0.35, 0.35, top - 0.15, top + 0.3)
        seg.block(x0 + 0.15, stripe, x1 - 0.15, stripe, "line")
    # the seat: on the high back behind the neck, a shallow slot either side for the rider's legs
    segs[2].dent(9, 12, 5, 0, 3, "plum-")

    # the whip of the tail: three thin boxes, each on its own joint, each thinner than the last and starting inside it.
    # At its end a small gold light
    tail1 = m.part("Tail1", (end, 0, 0.5), f"S{len(SLICES)}")
    tail1.beam((end - 0.8, 0, 0.5), (end + 4.8, 0, 0.5), 1.7, 1.5, "plum")
    tail2 = m.part("Tail2", (end + 4.4, 0, 0.5), "Tail1")
    tail2.beam((end + 4.2, 0, 0.5), (end + 9.4, 0, 0.5), 1.2, 1.0, "plum")
    tail3 = m.part("Tail3", (end + 9.0, 0, 0.5), "Tail2")
    tail3.beam((end + 8.8, 0, 0.5), (end + 12.4, 0, 0.5), 0.8, 0.6, "plum")
    tip = (-0.75, 0.75, -0.25, 1.25)
    tail3.block(end + 12.0, tip, end + 13.6, tip, "gold")
