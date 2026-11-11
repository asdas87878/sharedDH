"""The Sea Scorpion (zone 8's Epic: a eurypterid, the armoured sea scorpion of the old seas) for
tools/blender/voxel_kit.py (docs/style/creature-brief.md). Designed from the real animal.
Its idea: a flat suit of armour that swims. A low shield of a head with two claws held out in front, a broad plated
body that narrows to a scorpion's tail, and two paddles that row it along.
- The body is fourteen slices, wide and low: a broad brim, one broad step, and a narrow raised ridge down the middle
  (the rider sits astride it, feet on the step). One number changes from slice to slice. The back arches up to the seat
  and falls to the tail; the belly dips under the middle; in plan it widens behind the head and tapers to the tail.
- Each slice is an armour segment: its last row is a tone darker, so the plates read as overlapping. One thin pale line runs
  down the ridge from the head to the last segment.
- The head is a shield lower than the body and wider than the first segment behind it: a brim, a low dome that carries the two dark compound eyes under slanting
  brows, and a front that steps down and in, in two tilted blocks.
- The claws are each an arm, a palm and two fingers that meet at the tip, held forward and a little up, on their own joints.
- The paddles come out from under the back of the head: an arm, a broad blade, a darker tip, on their own joints.
- The tail ends in a flat spike that lifts a little: two flat blocks and a point.
It swims by rowing its paddles while a wave runs up and down the tail."""
import math

NAME, ZONE, RARITY = "Sea Scorpion", "ZONE 8 / VENTS", "EPIC"
U = 0.4
PALETTE = {"rust": "#C6642E", "edge": "#8C4126", "pale": "#EBDAB8", "black": "#2B2530", "stripe": "#F4C56E"}
SEAT = (2, 5, 2.5)
FRAME, ORTHO = 1.8, 26.0
TEXTURES = [{"tile": "stud", "on": "top+sides", "colours": ["rust", "edge"]}]

# the body: (length, cubes out, bottom, top, starts a new part). One number changes from slice to slice, never two.
# The segments are stiff in pairs, but for the last two of the tail
SLICES = ((2, 5, -2, 3, True), (2, 6, -2, 3, False), (3, 6, -2, 4, True), (3, 6, -3, 4, False), (3, 6, -3, 5, True),
          (3, 5, -3, 5, False), (2, 5, -3, 4, True), (2, 4, -3, 4, False), (2, 4, -3, 3, True), (2, 4, -2, 3, False),
          (2, 3, -2, 3, True), (2, 3, -2, 2, False), (2, 2, -2, 2, True), (2, 2, -1, 2, True))
BODY_FROM = -11
HEAD = (6, -2, 2)  # the head's shield: cubes out, bottom, top
AMPLITUDES = [1, 2, 3, 4, 6, 8, 9, 10, 12]


def chain():
    return [f"S{k + 1}" for k in range(sum(1 for s in SLICES if s[4]))] + ["Tail"]


def pose(parts, phase):
    """the paddles row; a wave runs up and down the body, small in the broad plates and big in the tail; the claws
    open and shut a little"""
    parts["Head"].rotation_euler.y = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(chain()):
        parts[name].rotation_euler.y = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.6 * (k + 1))
    for name, side in (("PaddleR", 1), ("PaddleL", -1)):
        parts[name].rotation_euler.x = side * math.radians(16) * math.sin(phase - 0.6)
        parts[name].rotation_euler.z = side * math.radians(12) * math.sin(phase - 1.7)
    for name, side in (("ClawR", 1), ("ClawL", -1)):
        parts[name].rotation_euler.z = side * math.radians(5) * math.sin(phase)
        parts[name].rotation_euler.y = math.radians(3) * math.sin(phase + 1.0)


def top_steps(n, top):
    """the back: a narrow ridge, one broad step (two cubes tall where the back is highest), the brim"""
    tall = 2 if top >= 5 else 1
    return [(4, 1), (2, tall)] if n >= 6 else ([(3, 1), (1, tall)] if n == 5 else ([(2, 1)] if n == 4 else ([(1, 1)] if n == 3 else [])))


def bottom_steps(n, bot):
    if n >= 5:
        return [(4, 1), (2, 1)] if bot <= -3 else [(2, 1)]
    if n == 4:
        return [(3, 1), (1, 1)] if bot <= -3 else [(1, 1)]
    return [(1, 1)]


def rows(steps):
    return sum(tall for _, tall in steps)


def belly(bot):
    """how high the pale underside comes: one level line under the brim, rising with the tail"""
    return max(-1, bot + 1)


def slab(p, x0, x1, n, bot, top):
    """one armour segment: rust, pale underneath, its last row a tone darker, the thin pale line down the ridge"""
    p.hull(x0, x1, n, bot, top, "rust", top_steps(n, top), bottom_steps(n, bot))
    p.paint_sym(x1 - 1, x1, n, belly(bot), top, "rust-")
    p.paint_sym(x0, x1, n, bot, belly(bot), "pale")
    p.paint(x0, x1, 0, 1, top - 1, top, "stripe")


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the shield: a wide brim, a low dome on it, pale underneath; its back edge is darker, like a segment's. It is a
    # cube wider than the first segment behind it, so it reads as a hood
    head.hull(-16, BODY_FROM, 6, -2, 2, "rust", [(3, 1)], [(2, 1)])
    head.paint_sym(BODY_FROM - 1, BODY_FROM, 6, -1, 2, "rust-")
    head.paint_sym(-16, BODY_FROM, 6, -2, -1, "pale")
    head.paint(-16, BODY_FROM, 0, 1, 1, 2, "stripe")
    # the front of the shield: two big blocks in a chain, each tilted nose-down, lower and narrower than the last, and a
    # plate that carries the dome's slope down onto them
    head.beam((-15.4, 0, 0.0), (-18.3, 0, -0.45), 10.6, 1.7, "rust", flat="z")
    head.beam((-17.8, 0, -0.45), (-20.0, 0, -0.85), 6.4, 1.2, "rust", flat="z")
    head.beam((-15.0, 0, 1.25), (-17.3, 0, 0.55), 5.0, 1.0, "rust", flat="z")
    # the compound eyes: a broad dark block on the brim against the dome, under a brow that slants down to the front,
    # stands above the eye and comes past it
    head.pair(-15, -13, 4, 6, 1, 2, "black")
    head.beam((-14.8, 3.45, 1.9), (-13.2, 3.45, 2.15), 1.0, 0.9, "rust", mirror=True)
    head.beam((-14.3, 3.45, 1.9), (-15.8, 3.45, 1.6), 0.6, 0.55, "rust", mirror=True)  # the part in front of the eye, slimmer
    # two pairs of short walking legs under the brim
    head.beam((-15.0, 3.6, -1.4), (-15.9, 8.3, -2.5), 0.8, 0.7, "edge", flat="z", mirror=True)
    head.beam((-13.7, 3.6, -1.4), (-13.9, 8.6, -2.5), 0.8, 0.7, "edge", flat="z", mirror=True)

    # the claws, each on its own joint: an arm from under the shield, a palm, and two fingers that meet at the tip. They
    # are held forward and rise a little
    for name, s in (("ClawR", 1), ("ClawL", -1)):
        claw = m.part(name, (-15.0, 2.8 * s, -1.3), "Head")
        claw.beam((-14.6, 2.8 * s, -1.3), (-21.0, 5.0 * s, -0.4), 1.7, 1.3, "edge", flat="z")
        claw.beam((-20.2, 4.75 * s, -0.5), (-23.0, 5.0 * s, 0.1), 3.2, 1.8, "rust", flat="z")
        claw.beam((-22.2, 5.75 * s, -0.05), (-25.6, 5.35 * s, 0.75), 1.1, 1.1, "edge", flat="z")
        claw.beam((-22.2, 4.2 * s, -0.05), (-25.6, 4.4 * s, 0.75), 1.0, 0.7, "edge", flat="z")

    # the paddles, each on its own joint, from under the back of the shield: an arm, a broad blade, a darker tip
    for name, s in (("PaddleR", 1), ("PaddleL", -1)):
        pad = m.part(name, (-12.2, 3.8 * s, -1.3), "Head")
        pad.beam((-12.2, 3.6 * s, -1.2), (-10.6, 8.4 * s, -2.0), 1.5, 1.2, "edge", flat="z")
        pad.beam((-10.9, 7.7 * s, -1.9), (-6.2, 10.6 * s, -2.25), 3.6, 0.8, "rust", flat="z")
        pad.beam((-7.1, 10.0 * s, -2.18), (-4.6, 11.5 * s, -2.4), 2.5, 0.4, "edge", flat="z")

    # the body
    part, k, x, before = None, 0, BODY_FROM, None
    for length, n, bot, top, joint in SLICES:
        if joint:
            k += 1
            part = m.part(f"S{k}", (x, 0, 0), "Head" if k == 1 else f"S{k - 1}")
            # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces
            # and kept clear of both pieces' steps (and a cube under the top of the piece in front)
            if before is None:
                fn, fbot, ftop = HEAD
                fup = fdown = 1
            else:
                fn, fbot, ftop = before
                fup, fdown = max(rows(top_steps(fn, ftop)), 1), rows(bottom_steps(fn, fbot))
            low = max(bot + rows(bottom_steps(n, bot)), fbot + fdown)
            high = min(top - rows(top_steps(n, top)), ftop - fup)
            part.sym(x - 1, x, max(min(n, fn) - 2, 0), low, high, "edge")
        slab(part, x, x + length, n, bot, top)
        before = (n, bot, top)
        x += length

    # the tail spike, on its own joint: flat, lifting, two blocks and a point
    tail = m.part("Tail", (x, 0, 1.0), f"S{k}")
    tail.beam((x - 0.7, 0, 0.9), (x + 2.4, 0, 1.15), 4.0, 0.9, "rust", flat="z")
    tail.beam((x + 1.7, 0, 1.1), (x + 4.6, 0, 1.6), 2.6, 0.6, "rust", flat="z")
    base = x + 4.1
    tail.spike([(base, -0.85, 1.38), (base, 0.85, 1.38), (base, 0.85, 1.65), (base, -0.85, 1.65)], (x + 6.2, 0, 2.0), "edge")
