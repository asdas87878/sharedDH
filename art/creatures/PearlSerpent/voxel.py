"""The Pearl Serpent (zone 1's SECRET: an invented sea serpent that carries a pearl in its brow) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed above a Mythic by docs/style/05-rarity-look.md.
Its idea: a serpent grown round a pearl. One large round pearl sits in its brow and shines softly; the whole animal is
the pearl's colour, with the pearl's pink and pale-blue sheen running down it in thin lines to a fan tail.
Its ways: light (the pearl, and a small one where the fan springs from: the echo), material (it is made of pearl) and
proportion (a very long body carried high at the neck, ending in a fan taller than the body).
- The body is nineteen slices on joints. Each is one step bigger or smaller than the last, in width or in the back or in
  the belly, never two at once; where the line of the body climbs, a slice sits one cube higher than the last. So the side
  view is a long boat: the neck climbs to a head carried high, the belly dips under the rider, the tail lifts its fan.
- Thin lines run the whole length: a pink one down the spine (it ends in the pearl's setting), and a pale-blue one over a
  pink one along each flank, like the sheen on a pearl.
- The head is gentle: a tall skull, a blunt snout of two blocks, a closed mouth drawn as one thin rose line, a big
  dark eye under a pale-blue lid, no brow. Two small fin ears, and two whiskers that trail back from the nose.
- The pearl is three crossed blocks (a ball in cubes), set in a rose frame where the snout meets the forehead.
- The tail is a fan of three lobes, each in three boxes: pearl, then pink, then a pale-blue tip.
The rider sits where the back is broadest, behind the neck, legs in a shallow slot either side."""
import math

NAME, ZONE, RARITY = "Pearl Serpent", "ZONE 1 / SHALLOWS", "SECRET"
U = 0.45
PALETTE = {"pearl": "#E9E4E1", "pink": "#F3B4C6", "blue": "#B2D5F0", "moon": "#FFE6F0", "black": "#2B2E3D", "rose": "#D98FA6"}
SHADE = 0.9  # the belly's tone stays pearl, not grey
SEAT = (14.5, 5, 4.6)
GLOW = {"moon": 0.6}  # the pearl in the brow, and the small one at the tail
FRAME, ORTHO, ORTHO_SWIM = 2.6, 42.0, 48.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["pearl"]}]
PINK_LINE = True  # the second flank line, under the blue one

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, or the whole slice
# sits one cube higher or lower (the neck, the tail); only the shoulder, under the side fins, swells two ways at once
SLICES = ((2, 3, 2, 10), (3, 3, 1, 9), (3, 3, 0, 8), (3, 3, -1, 7), (3, 3, -2, 6), (3, 3, -3, 5), (3, 4, -4, 5), (5, 4, -5, 5),
          (3, 4, -4, 5), (3, 4, -4, 4), (3, 3, -4, 4), (3, 3, -3, 4), (3, 3, -3, 3), (3, 2, -3, 3), (3, 2, -2, 3), (3, 2, -1, 3),
          (3, 2, 0, 4), (2, 1, 0, 4), (2, 1, 1, 5))
BODY_FROM = -9
SKULL = (4, 2, 11)
CHAIN = [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 12]


def pose(parts, phase):
    """a serpent's swim: one slow wave runs down the long chain from side to side, growing toward the tail; the head
    turns a little against it, so it keeps looking where it goes; the fan follows the last slice"""
    parts["Head"].rotation_euler.z = math.radians(2.0) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.42 * (k + 1))


def top_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else [(1, 1)]


def bottom_steps(n):
    return [(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else [])


def slab(p, x0, x1, n, bot, top, lines=True):
    """a slice of body: stepped corners, pearl with a lighter top row and a shaded belly, and the thin lines"""
    p.hull(x0, x1, n, bot, top, "pearl", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "pearl+")
    p.paint_sym(x0, x1, n, bot, bot + max(1, len(bottom_steps(n))), "pearl-")
    if lines:
        mid = (top + bot) // 2
        p.paint_sym(x0, x1, n, mid, mid + 1, "blue")
        if PINK_LINE:
            p.paint_sym(x0, x1, n, mid - 1, mid, "pink")
    p.paint(x0, x1, 0, 1, top - 1, top, "pink")  # the spine's line


def ball(p, centre, r, colour):
    """a ball in cubes: three crossed blocks, each long one way"""
    cx, cy, cz = centre
    a, b = round(r * 0.72, 2), round(r * 0.6, 2)  # no two of the three share a side, so no faces lie in one plane
    for rx, ry, rz in ((r, a, b), (b, r, a), (a, b, r)):
        section = (cy - ry, cy + ry, cz - rz, cz + rz)
        p.block(cx - rx, section, cx + rx, section, colour)


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 6))
    # the skull: a tall box with two-step corners, carried high above the body. Its front is deeper and wider underneath
    # (a cheek), so the jaw's root is buried
    slab(head, -15, BODY_FROM, 4, 2, 11, lines=False)
    head.sym(-15, -13, 3, 1, 3, "pearl-")
    # the snout: two blunt blocks in a chain, each tilted a little nose-down, lower and narrower than the last
    snout = ((-13.5, -19.5, 6.2, 5.5, 7.4, 4.4), (-18.5, -23.5, 5.35, 4.7, 5.6, 3.2))

    def under(k, x):
        """the underside of snout block k at x"""
        x0, x1, z0, z1, _, thick = snout[k]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) - thick / 2

    for x0, x1, z0, z1, wide, thick in snout:
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "pearl", flat="z")
    # the mouth: shut. One thin rose line under each snout block, set in from its edge; the lower jaw under that, set in
    # again and shorter than the snout, so the serpent smiles a little
    for k, (xa, xb, wide) in enumerate(((-14.9, -18.9, 6.7), (-18.6, -23.0, 5.2))):
        head.beam((xa, 0, under(k, xa) - 0.2), (xb, 0, under(k, xb) - 0.2), wide, 0.7, "rose", flat="z")
    for k, (xa, xb, wide, thick) in enumerate(((-14.6, -19.2, 6.4, 2.0), (-18.4, -22.5, 4.6, 1.5))):
        drop = 0.3 + thick / 2
        head.beam((xa, 0, under(k, xa) - drop), (xb, 0, under(k, xb) - drop), wide, thick, "pearl-", flat="z")
    nostril = (0.9, 1.5, 6.2, 6.75)
    head.block(-22.9, nostril, -22.3, nostril, "rose", mirror=True)
    # the eye: big and dark, low on the side of the skull, with a pale-blue lid over and behind it. No brow: it is gentle
    head.paint_pair(-14, -11, 4, 5, 5, 8, "blue")
    head.pair(-14, -12, 5, 6, 5, 7, "black")
    # the pearl in its brow: a ball where the snout meets the forehead, half sunk, in a rose frame on the skull's front
    frame = (-2.8, 2.8, 7.3, 9.7)
    head.block(-15.4, frame, -14.9, frame, "rose")
    ball(head, (-15.0, 0, 9.2), 2.2, "moon")
    # the fin ears: two boxes each, back, out and up from the skull's top corners, the second smaller and pink
    head.beam((-10.8, 2.6, 8.2), (-8.2, 5.4, 10.8), 2.6, 1.0, "pearl", mirror=True)
    head.beam((-8.9, 4.7, 10.1), (-6.6, 6.8, 12.2), 1.8, 0.6, "pink", mirror=True)
    # the whiskers: two thin rods each, out from the nose and trailing back beside the jaw
    head.beam((-21.4, 1.8, 4.4), (-19.2, 4.8, 3.0), 0.8, 0.8, "pink", flat="z", mirror=True)
    head.beam((-19.6, 4.3, 3.25), (-15.0, 6.0, 1.1), 0.5, 0.5, "pink", flat="z", mirror=True)

    # the body: nineteen slices, each on its own joint
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, (top + bot) / 2), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        slab(seg, x0, x1, n, bot, top)
        # a sleeve into the piece in front, so a bending joint shows body: sized from the smaller of the two pieces and
        # kept clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        up = max(1, len(top_steps(n)), len(top_steps(fn)))
        down = max(1, len(bottom_steps(n)), len(bottom_steps(fn)))
        seg.sym(x0 - 1, x0, max(min(n, fn) - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, "pearl-")
    # the seat: where the back is broadest, a shallow slot either side for the rider's legs (above the flank lines)
    segs[7].dent(13, 16, 4, 1, 3, "pearl-")

    # two small side fins on the shoulder, in front of the rider: the ears' echo. Two boxes, the second smaller and pink
    segs[6].beam((10.5, 3.2, -1.6), (13.1, 7.2, -3.3), 3.0, 0.9, "pearl", flat="z", mirror=True)
    segs[6].beam((12.3, 6.3, -2.9), (14.9, 9.0, -4.3), 2.0, 0.5, "pink", flat="z", mirror=True)

    # the tail, on its own joint: a short stock, a small pearl on each side of it where the fan springs from (the brow's
    # echo), and a fan of three lobes, each in three boxes: pearl, pink, a pale-blue tip. The lobes differ in thickness,
    # so where they cross at the root no two sides lie in one plane
    tz = 2.5
    tail = m.part("Tail", (end, 0, tz), f"S{len(SLICES)}")
    tail.beam((end - 0.5, 0, tz), (end + 2.5, 0, tz), 3.8, 2.0, "pearl")
    for x0, x1, y0, y1, half in ((0.2, 2.1, 0.7, 1.6, 1.2), (0.6, 1.7, 0.4, 1.9, 0.7)):  # a stepped stud a side
        tail.block(end + x0, (y0, y1, tz - half, tz + half), end + x1, (y0, y1, tz - half, tz + half), "moon", mirror=True)
    for points, wide, thick in ((((1.4, 3.0), (5.8, 6.7), (8.1, 8.6), (9.4, 9.7)), (4.0, 3.0, 2.0), 1.5),
                                (((1.8, 2.5), (6.8, 2.5), (9.2, 2.5), (10.6, 2.5)), (3.2, 2.4, 1.6), 0.9),
                                (((1.4, 2.0), (5.8, -1.7), (8.1, -3.6), (9.4, -4.7)), (4.0, 3.0, 2.0), 1.2)):
        (ax, az), (bx, bz) = points[:2]
        length = math.hypot(bx - ax, bz - az)

        def at(k, back=0.0):
            """point k of the lobe, moved `back` cubes toward its root"""
            return (end + points[k][0] - back * (bx - ax) / length, 0, points[k][1] - back * (bz - az) / length)

        tail.beam(at(0), at(1), wide[0], thick, "pearl")
        tail.beam(at(1, 1.2), at(2), wide[1], thick * 0.6, "pink")
        tail.beam(at(2, 1.0), at(3), wide[2], thick * 0.33, "blue")
