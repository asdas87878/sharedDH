"""The Garibaldi (zone 3's Uncommon: the bright orange damselfish of the kelp forest) for tools/blender/voxel_kit.py
(docs/style/creature-brief.md).
Its idea: one solid, friendly lump of orange. A deep oval body, a blunt face with a steep forehead, and a heart for a tail.
- The body is short slices of cubes. The back, the belly and the width each make their own staircase: from one slice to
  the next one of them moves by one cube.
- The face is four blocks: a steep forehead block lying along its own slope, a muzzle and a small pale jaw (both tilted a
  little nose-down, so the chin tucks back under the lip), and a dark mouth set inside the lips. Cheeks of cubes join them to the head.
- A friendly eye: a cream ring with a dark pupil standing out of it. No brow.
- The back fin and the fin under the tail are each two boxes swept back, their tips free over the stalk, as on the real fish.
  The front of the back is left clear for the rider.
- The tail is two fat blocks turned apart with a rounding block on each end: a heart with its point at the stalk.
- The pattern (an Uncommon has one): a thin paler stripe from cheek to tail, and four small electric-blue spots under the
  back fin, as a young garibaldi has.
The rider sits on the highest part of the back, in front of the fin, legs in a slot either side."""
NAME, ZONE, RARITY = "Garibaldi", "ZONE 3 / KELP FOREST", "UNCOMMON"
U = 0.4
PALETTE = {"orange": "#FF7A1C", "belly": "#FF9E4A", "stripe": "#FFC987", "blue": "#2FA8FF", "cream": "#FFF0CF", "black": "#1F1F24",
           "mouth": "#8A3312"}
SEAT = (-2, 6, 3.6)
FRAME, ORTHO = 1.15, 16.0
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["orange"]}]
SWIM = {"chain": ["Head", "S1", "S2", "S3", "Tail"], "amplitudes": [2, 4, 8, 17], "phaseStep": 0.9, "headCounter": 2}

STRIPE = -1  # the row the flank stripe runs along
BELLY = -3  # everything below this is the paler belly

# the body, head first: (part, x from, x to, cubes out, bottom, top). One number changes from slice to slice where it can
SLICES = (("Head", -13, -11, 3, -4, 5), ("Head", -11, -9, 3, -5, 5),
          ("S1", -9, -7, 3, -6, 5), ("S1", -7, -4, 3, -6, 6),
          ("S2", -4, 0, 3, -6, 6),
          ("S3", 0, 2, 3, -5, 6), ("S3", 2, 3, 3, -5, 5), ("S3", 3, 4, 3, -4, 5), ("S3", 4, 5, 2, -4, 4), ("S3", 5, 6, 2, -3, 4), ("S3", 6, 7, 2, -3, 3),
          ("Tail", 7, 8, 1, -2, 3), ("Tail", 8, 10, 1, -2, 2))
PIVOTS = {"Head": -9, "S1": -9, "S2": -4, "S3": 0, "Tail": 7}


def top_steps(n, top):
    """the corners of the back: two broad steps where the back is highest, one elsewhere, none on the thin stalk"""
    return [] if n < 2 else ([(2, 1), (1, 1)] if n == 3 and top == 6 else [(1, 1)])


def bottom_steps(n, bot):
    return [] if n < 2 else ([(2, 1), (1, 1)] if n == 3 and bot == -6 else [(1, 1)])


def slab(p, x0, x1, n, bot, top, light=True):
    """a slice of body: stepped corners, a lighter top row, the paler belly, the flank stripe"""
    p.hull(x0, x1, n, bot, top, "orange", top_steps(n, top), bottom_steps(n, bot))
    if light:
        p.paint_sym(x0, x1, n, top - 1, top, "orange+")
    p.paint_sym(x0, x1, n, bot, BELLY, "belly")
    p.paint_sym(x0, x1, n, STRIPE, STRIPE + 1, "stripe")


def build(m):
    parts = {"Head": m.part("Head", (PIVOTS["Head"], 0, 0))}
    last = "Head"
    for name in ("S1", "S2", "S3", "Tail"):
        parts[name] = m.part(name, (PIVOTS[name], 0, 0), last)
        last = name
    for i, (name, x0, x1, n, bot, top) in enumerate(SLICES):
        p = parts[name]
        slab(p, x0, x1, n, bot, top)
        if i and SLICES[i - 1][0] != name:
            # a sleeve one cube into the piece in front, so a bending joint shows body. It is a cube narrower than the
            # smaller piece and a row clear of both pieces' corner steps
            _, _, _, fn, fbot, ftop = SLICES[i - 1]
            low = max(bot + len(bottom_steps(n, bot)), fbot + len(bottom_steps(fn, fbot))) + 1
            high = min(top - len(top_steps(n, top)), ftop - len(top_steps(fn, ftop))) - 1
            p.sym(x0 - 1, x0, min(n, fn) - 1, low, high, "orange-")
    head, s1, s2, s3, tail = (parts[k] for k in ("Head", "S1", "S2", "S3", "Tail"))

    # ---- the face. Cheeks: a smaller slice in front of the head, which the face blocks start inside
    head.hull(-14, -13, 2, -3, 2, "orange", [(1, 1)], [])
    head.paint_sym(-14, -13, 2, STRIPE, STRIPE + 1, "stripe")
    # the forehead: one big block lying along its own steep slope, from just behind the lip up to the top of the head
    head.beam((-13.87, 0, 0.41), (-11.72, 0, 4.21), 4.4, 2.6, "orange", flat="z")
    # the muzzle and the jaw, tilted a little nose-down so the chin tucks back; the jaw is pale, like the belly
    head.beam((-12.5, 0, -0.2), (-15.3, 0, -0.6), 3.8, 3.2, "orange", flat="z")
    head.beam((-12.5, 0, -3.15), (-14.8, 0, -3.25), 3.4, 1.2, "belly", flat="z")
    # the mouth: a dark block between the lips, set back from their edges
    mouth = (-1.3, 1.3, -2.7, -1.9)
    head.block(-14.65, mouth, -12.6, mouth, "mouth")
    # the eye: a cream ring a little proud of the head, a dark pupil standing out of it, toward the front
    ring = (3.3, 3.8, 0.5, 2.9)
    head.block(-12.7, ring, -10.3, ring, "cream", mirror=True)
    pupil = (3.6, 4.1, 1.05, 2.45)
    head.block(-12.4, pupil, -11.0, pupil, "black", mirror=True)

    # ---- the seat: on the highest part of the back, a shallow slot either side for the rider's legs
    s2.dent(-3, -1, 3, 1, 4, "orange-")

    # ---- the pattern: four small electric-blue spots on the flank under the back fin
    for part, x, j, z in ((s3, 0, 3, 3), (s3, 2, 2, 4), (s3, 3, 3, 2), (s3, 5, 2, 2)):
        part.paint_pair(x, x + 1, j, j + 1, z, z + 1, "blue")

    # ---- the fins: boxes at an angle, each smaller and thinner than the one before and starting inside it
    # the side fins: a paddle held out from the body, behind the head and under the stripe
    s1.beam((-7.6, 2.9, -2.3), (-4.6, 4.7, -2.9), 2.4, 0.6, "orange", mirror=True)
    # the belly fins: a small pair under the deepest part
    s1.beam((-6.4, 1.0, -5.0), (-4.4, 1.5, -7.0), 1.6, 0.6, "orange", mirror=True)
    # the back fin: swept back, then levelling into a round lobe whose tip is free over the stalk. It starts behind the rider
    s3.beam((1.0, 0, 4.1), (6.2, 0, 6.9), 4.0, 1.2, "orange")
    s3.beam((5.2, 0, 7.0), (8.2, 0, 7.5), 2.6, 0.8, "orange")
    # the fin under the tail: the same, a little smaller
    s3.beam((2.6, 0, -3.2), (6.4, 0, -6.3), 3.6, 1.2, "orange")
    s3.beam((5.4, 0, -6.3), (8.0, 0, -6.9), 2.4, 0.8, "orange")

    # ---- the tail: a heart with its point at the stalk, drawn the way a heart is: two fat blocks turned apart, crossing
    # at the point, each with a smaller block on its end to round it. A root block ties them to the stalk. The lower lobe
    # is a step thicker than the upper, so their sides never share a plane
    tail.beam((9.2, 0, 0), (12.4, 0, 0), 3.6, 1.6, "orange")
    for side, thick in ((1, 1.0), (-1, 1.3)):
        tail.beam((10.3, 0, 0.4 * side), (14.2, 0, 3.7 * side), 4.0, thick, "orange")
        tail.beam((13.43, 0, 3.05 * side), (14.88, 0, 4.28 * side), 2.6, 0.7, "orange")
