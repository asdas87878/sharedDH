"""The Ember Serpent (zone 8's Secret: a serpent of fire from the vents) for tools/blender/voxel_kit.py
(docs/style/04-voxel-style.md), dressed above a Mythic by docs/style/05-rarity-look.md.
Its idea, which is its name: a serpent made of banked fire. Thick plates of cooled lava ride on a body that is still
burning, and the fire shows in the gap between every plate: white-hot behind the head, cooling plate by plate to deep
red at the tail, where it breaks out again as flame.
How it differs from the Brimstone Eel (a thin burnt eel with cracks and a flank line): this one is thick and armoured.
It has no flank line and no cracks; its light is whole rings between big plates, a furnace of a mouth, and real flame.
- The body is twenty-one slices on joints, each one step different from the last (width, or back, or belly). Two slices
  make one plate: a ring of fire runs round the front of every plate, and the joint inside a plate shows fire only when
  it bends. The first ring is a white-hot collar right behind the skull; the body swells behind it.
- The back and the belly are a wide plateau and one broad step; the back arches to the rider and falls to the tail.
- The head: a short skull, a snout of two heavy blocks that ends in an upturned nose plate, a heavy lower jaw (its own
  part) that juts past the snout with two tall fangs, ember teeth in a thin dark gum line, a furnace inside the mouth.
  The eye is white-hot with a slit, under a brow that comes past it and sweeps back into a horn of rock.
- The flame crest: stepped blocks blown back, tallest on the neck and falling to nothing before the rider; then from
  the last third of the body growing to the tail, which ends in three tongues of flame. A few sparks float off it.
- Smoke-dark fins: a big pair behind the head on joints of their own, a small pair far back.
The rider sits on the highest plate, legs in a shallow slot either side; nothing stands on the back there."""
import math

NAME, ZONE, RARITY = "Ember Serpent", "ZONE 8 / VENTS", "SECRET"
U = 0.45
PALETTE = {"plate": "#33343E", "crust": "#6B3F3A", "smoke": "#5B5764", "white": "#FFF1C4", "yellow": "#FFCC3A",
           "orange": "#FF8A1E", "blaze": "#EE4F1A", "red": "#C2261A", "deep": "#8C1612", "fang": "#FFD96A",
           "furnace": "#FF9A2A", "gum": "#2A1418", "black": "#17131A"}
SEAT = (20.5, 10, 6.5)
GLOW = {"white": 0.9, "yellow": 0.85, "orange": 0.8, "blaze": 0.7, "red": 0.6, "deep": 0.45, "fang": 0.6, "furnace": 0.75}
TEXTURES = [{"tile": "stud", "on": "top", "colours": ["plate"]}]
FLOATING = ["Sparks", "Embers"]
FRAME, ORTHO, ORTHO_SWIM = 3.3, 50.0, 56.0

# the body: each slice is (length, cubes out, bottom, top). One number changes from slice to slice, never two
SLICES = ((3, 5, -5, 6), (3, 5, -5, 7), (4, 5, -6, 7), (4, 6, -6, 7), (4, 6, -6, 8), (4, 6, -6, 9), (4, 6, -7, 9), (5, 6, -7, 10),
          (4, 6, -7, 9), (4, 6, -6, 9), (4, 6, -6, 8), (4, 5, -6, 8), (4, 5, -5, 8), (3, 5, -5, 7), (3, 5, -4, 7), (3, 4, -4, 7),
          (3, 4, -4, 6), (3, 4, -4, 5), (3, 4, -3, 5), (3, 3, -3, 5), (3, 3, -3, 4))
BODY_FROM = -8
SKULL = (5, -5, 6)
SKULL_TOP, SKULL_BOTTOM = [(2, 1), (1, 1)], [(1, 1)]
FIRE = ("white", "white", "yellow", "yellow", "orange", "orange", "blaze", "blaze", "red", "red", "red")  # one colour to a plate
CHAIN = ["Head"] + [f"S{i + 1}" for i in range(len(SLICES))] + ["Tail"]
AMPLITUDES = [1.5, 1.5, 2, 2, 2, 2.5, 2.5, 3, 3, 3.5, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9.5]
STEP = 0.4


def pose(parts, phase):
    """a serpent's swim: a wave runs down the long chain side to side, growing toward the tail. The head turns against
    the body's mean heading, so the animal stays on its line. The jaw opens and shuts once a beat; the big fins row"""
    turns = [math.radians(a) * math.sin(phase - STEP * (k + 1)) for k, a in enumerate(AMPLITUDES)]
    heading, total = 0.0, 0.0
    for t in turns:
        heading += t
        total += heading
    parts["Head"].rotation_euler.z = -total / len(turns)
    for name, t in zip(CHAIN[1:], turns):
        parts[name].rotation_euler.z = t
    parts["Jaw"].rotation_euler.y = -math.radians(9) * (0.5 + 0.5 * math.sin(phase))
    for name, side in (("FinR", 1), ("FinL", -1)):
        parts[name].rotation_euler.x = side * math.radians(10) * math.sin(phase - 0.8)
        parts[name].rotation_euler.z = side * math.radians(6) * math.sin(phase - 1.8)


def top_steps(n):
    """the corners of the back: a wide plateau and one broad step where the body is thick, less as it thins"""
    return [(3, 1), (1, 2)] if n >= 5 else ([(2, 1), (1, 1)] if n == 4 else [(1, 1)])


def bottom_steps(n):
    return [(2, 1)] if n >= 4 else [(1, 1)]


def tall(steps):
    return sum(t for _, t in steps)


def belly_edge(bot):
    """how high the crust of the belly comes: it dips under the deep middle and rises to the tail"""
    return bot + (3 if bot <= -5 else (2 if bot <= -3 else 1))


def slab(p, x0, x1, n, bot, top, ring=None):
    """a slice of body: stepped corners, dark plate (lighter on the top row), a crusted belly; `ring`: the fire that
    shows round the front of a plate, one cube row all the way round"""
    p.hull(x0, x1, n, bot, top, "plate", top_steps(n), bottom_steps(n))
    p.paint_sym(x0, x1, n, top - 1, top, "plate+")
    p.paint_sym(x0, x1, n, bot, belly_edge(bot), "crust")
    if ring:
        p.paint_sym(x0, x0 + 1, n, bot, top, ring)


def flame(p, x, top, high, wide, thick, lean, colour, tip=None):
    """one tongue of the flame crest: a block standing on the back, blown tailward, its root a cube deep in the body;
    `tip`: a second, smaller block of a cooler colour that starts inside it and bends further back"""
    p0, p1 = (x, top - 1.1), (x + lean * (high + 1.1), top + high)
    p.beam((p0[0], 0, p0[1]), (p1[0], 0, p1[1]), wide, thick, colour)
    if tip:
        start = (p0[0] + 0.72 * (p1[0] - p0[0]), p0[1] + 0.72 * (p1[1] - p0[1]))
        end = (p1[0] + 0.55 * high * (lean + 0.25), p1[1] + 0.55 * high)
        p.beam((start[0], 0, start[1]), (end[0], 0, end[1]), 0.6 * wide, 0.55 * thick, tip)


def cube(p, x, y, z, size, colour):
    """a loose spark: one small cube"""
    h = size / 2
    p.block(x - h, (y - h, y + h, z - h, z + h), x + h, (y - h, y + h, z - h, z + h), colour)


def build(m):
    head = m.part("Head", (BODY_FROM, 0, 0))
    # the skull: a short box, the size of the neck. Crust under the jaw line; its bottom row is wider
    # (the jowl: the heavy jaw's root is buried in it). The skull stays dark, so the eye is the one light on it
    n, bot, top = SKULL
    head.hull(-15, BODY_FROM, n, bot, top, "plate", SKULL_TOP, SKULL_BOTTOM)
    head.paint_sym(-15, BODY_FROM, n, top - 1, top, "plate+")
    head.paint_sym(-15, BODY_FROM, n, bot, -2, "crust")
    head.sym(-15, -10, 4, -6, -5, "crust")
    head.paint(-15, -14, -3, 4, -3, -1, "furnace")  # the back of the mouth, seen between the lips
    # the snout: two heavy blocks in a chain, each tilted nose-down, lower and narrower than the last. Each has a crust
    # lip plate underneath with a thin dark gum line set inside its edge, and a lighter plate on top
    blocks = ((-13.5, -18.5, 2.0, 1.3, 8.4, 5.4, 6.0, -13.5, -14.6), (-17.7, -22.4, 1.1, 0.6, 5.8, 4.0, 3.8, -18.7, -18.8))

    def middle(k, x):
        x0, x1, z0, z1 = blocks[k][:4]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0)

    def lip_bottom(k, x):
        return middle(k, x) - blocks[k][5] / 2 - 0.6

    for k, (x0, x1, z0, z1, wide, thick, plate, plate_from, gum_from) in enumerate(blocks):
        head.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "plate", flat="z")
        lip = thick / 2 + 0.3
        head.beam((x0, 0, z0 - lip), (x1, 0, z1 - lip), wide - 0.4, 0.6, "crust", flat="z")
        rise = thick / 2 + 0.2
        head.beam((plate_from, 0, middle(k, plate_from) + rise), (x1 + 0.7, 0, middle(k, x1 + 0.7) + rise), plate, 0.5, "plate+", flat="z")
        head.beam((gum_from, 0, lip_bottom(k, gum_from) - 0.05), (x1 + 0.3, 0, lip_bottom(k, x1 + 0.3) - 0.05), wide - 1.0, 0.2, "gum",
                  flat="z")
    # the nose plate: a slab of rock that starts inside the snout's tip and turns up past it
    head.beam((-20.2, 0, 2.0), (-23.3, 0, 3.6), 2.8, 1.4, "plate", flat="z")
    nostril = (2.7, 3.05, 1.1, 1.55)
    head.block(-21.9, nostril, -21.2, nostril, "orange", mirror=True)  # the nostrils: two small slits that burn
    # the furnace inside the mouth: two blocks that stay behind the teeth and end inside the lips and the jaw
    head.block(-18.0, (-2.3, 2.3, -3.4, -1.3), -14.9, (-2.3, 2.3, -3.4, -1.3), "furnace")
    head.block(-21.6, (-1.5, 1.5, -3.5, -1.2), -18.0, (-1.5, 1.5, -3.5, -1.2), "furnace")
    # the upper teeth: embers, each with its base sunk into the gum
    for k, x, length in ((0, -15.6, 0.9), (0, -16.7, 1.0), (0, -17.8, 0.9), (1, -19.2, 1.0), (1, -20.4, 0.9), (1, -21.6, 1.0)):
        head.tooth(x, (3.325, 2.025)[k], lip_bottom(k, x) - 0.05, 0.7, length, "fang")
    # the eye: a dark socket on the skull's side, a white-hot eye, a slit of a pupil standing out of it. The brow sits on
    # the eye, slanting down to the front, covers the top of its square and comes past it in front
    ring = (5.38, 5.97, 1.1, 3.5)
    head.block(-13.6, ring, -11.0, ring, "plate-", mirror=True)
    eye = (5.85, 6.15, 1.4, 3.2)
    head.block(-13.3, eye, -11.4, eye, "white", mirror=True)
    pupil = (5.97, 6.33, 1.55, 3.05)
    head.block(-12.65, pupil, -12.1, pupil, "black", mirror=True)
    head.beam((-15.6, 5.81, 2.75), (-10.4, 5.81, 3.75), 1.3, 1.35, "plate", mirror=True)
    # the horn: the brow sweeps back and up into a horn of rock, in two boxes, the second smaller and starting inside
    head.beam((-11.2, 4.9, 3.3), (-7.6, 6.0, 7.2), 2.1, 1.5, "plate", mirror=True)
    head.beam((-8.4, 5.7, 6.4), (-4.8, 7.4, 10.0), 1.4, 1.0, "plate+", mirror=True)
    flame(head, -11.0, top, 2.2, 2.2, 1.3, 0.3, "white")  # the crest starts between the horns

    # the lower jaw, on its own joint: heavy, three boxes in a chain rising to the chin, which juts past the snout. Its
    # own gum line and ember teeth; two tall fangs stand up in front of the snout
    jaw = m.part("Jaw", (-13, 0, -3.6), "Head")
    jaws = ((-12.6, -18.6, -4.5, -4.3, 8.0, 2.8, -14.6), (-17.8, -22.6, -4.4, -4.1, 6.2, 2.2, -18.9), (-21.9, -24.6, -3.9, -3.4, 4.6, 1.7, -22.9))

    def jaw_top(k, x):
        x0, x1, z0, z1, _, thick = jaws[k][:6]
        return z0 + (z1 - z0) * (x - x0) / (x1 - x0) + thick / 2

    for k, (x0, x1, z0, z1, wide, thick, gum_from) in enumerate(jaws):
        jaw.beam((x0, 0, z0), (x1, 0, z1), wide, thick, "crust", flat="z")
        jaw.beam((gum_from, 0, jaw_top(k, gum_from) + 0.05), (x1 + 0.3, 0, jaw_top(k, x1 + 0.3) + 0.05), wide - 0.6, 0.2, "gum", flat="z")
    for k, x, length, size in ((0, -16.1, 0.8, 0.6), (0, -17.3, 0.8, 0.6), (1, -19.8, 0.85, 0.6), (1, -20.9, 0.85, 0.6), (1, -21.9, 0.85, 0.6),
                               (2, -23.75, 1.9, 0.8)):
        jaw.tooth(x, (3.35, 2.45, 1.65)[k] - (0.1 if size > 0.6 else 0.0), jaw_top(k, x) + 0.05, size, -length, "fang")

    # the body: twenty-one slices, each on its own joint. Two slices make a plate; the fire rings the front of each plate
    segs, spans, x = [], [], BODY_FROM
    for i, (length, n, bot, top) in enumerate(SLICES):
        segs.append(m.part(f"S{i + 1}", (x, 0, 0), "Head" if i == 0 else f"S{i}"))
        spans.append((x, x + length, n, bot, top))
        x += length
    end = x
    for i, (seg, (x0, x1, n, bot, top)) in enumerate(zip(segs, spans)):
        fire = FIRE[i // 2]
        slab(seg, x0, x1, n, bot, top, None if i % 2 else fire)
        # a glowing sleeve into the piece in front, so a bending joint shows fire. It is sized from the smaller of the two
        # pieces and stays clear of both pieces' steps
        fn, fbot, ftop = spans[i - 1][2:5] if i else SKULL
        small = min(n, fn)
        up = max(tall(top_steps(n)), tall(top_steps(fn)) if i else tall(SKULL_TOP))
        down = max(tall(bottom_steps(n)), tall(bottom_steps(fn)) if i else tall(SKULL_BOTTOM))
        seg.sym(x0 - 1, x0, max(small - 2, 0), max(bot, fbot) + down, min(top, ftop) - up, fire)
        # the crest on the tail: one tongue to a slice from the last third on, each taller than the one before
        if i >= 13:
            k = i - 13
            mid = x0 + (x1 - x0) / 2 - 0.5
            flame(seg, mid, top, 1.0 + 0.5 * k, 1.6 + 0.1 * k, 1.1 if n >= 4 else 0.9, 0.5, fire, ("red" if fire == "blaze" else "deep") if k >= 3 else None)
    # the crest behind the head: tallest on the neck, falling in steps to nothing before the rider
    flame(segs[0], -7.0, spans[0][4], 4.6, 2.8, 1.7, 0.32, "white", "yellow")
    flame(segs[1], -3.9, spans[1][4], 3.6, 2.6, 1.4, 0.34, "yellow", "orange")
    flame(segs[2], -1.1, spans[2][4], 2.4, 2.2, 1.1, 0.36, "orange")
    flame(segs[2], 0.9, spans[2][4], 1.2, 1.4, 0.7, 0.36, "orange")
    # the seat: on the highest plate, a shallow slot either side for the rider's legs
    segs[7].dent(19, 22, 6, 3, 6, "plate-")

    # the big fins, each on its own joint: three boxes swept back, each smaller and thinner than the last
    for name, side in (("FinR", 1), ("FinL", -1)):
        fin = m.part(name, (-3, 5 * side, -2.5), "S2")
        for (ax, ay, az), (bx, by, bz), wide, thick, colour in (((-3.2, 3.6, -2.5), (0.8, 9.4, -3.5), 5.4, 1.5, "smoke"),
                                                                ((-0.1, 8.2, -3.3), (4.4, 12.6, -4.2), 3.8, 1.0, "smoke"),
                                                                ((3.4, 11.4, -4.0), (6.8, 14.2, -4.7), 2.5, 0.55, "smoke-")):
            fin.beam((ax, ay * side, az), (bx, by * side, bz), wide, thick, colour, flat="z")
    # the small fins far back
    segs[14].beam((46.4, 3.6, -1.8), (49.8, 8.0, -2.8), 3.2, 1.0, "smoke", flat="z", mirror=True)
    segs[14].beam((49.0, 7.1, -2.6), (51.8, 9.6, -3.2), 2.0, 0.55, "smoke-", flat="z", mirror=True)

    # the tail, on its own joint: a last small plate, then three tongues of flame
    tail = m.part("Tail", (end, 0, 0.5), f"S{len(SLICES)}")
    tail.hull(end, end + 3, 2, -2, 3, "plate", [(1, 1)], [(1, 1)])
    tail.paint_sym(end, end + 3, 2, 2, 3, "plate+")
    tail.paint_sym(end, end + 3, 2, -2, -1, "crust")
    tail.paint_sym(end, end + 1, 2, -2, 3, "red")
    tail.sym(end - 1, end, 0, -1, 2, "red")
    tail.beam((end + 1.6, 0, 1.2), (end + 6.2, 0, 5.6), 3.2, 1.9, "red")
    tail.beam((end + 5.0, 0, 4.5), (end + 7.8, 0, 7.8), 2.0, 0.8, "deep")
    tail.beam((end + 1.8, 0, 0.4), (end + 7.6, 0, 0.2), 2.4, 1.5, "blaze")
    tail.beam((end + 6.6, 0, 0.25), (end + 8.2, 0, 0.1), 1.4, 0.5, "red")
    tail.beam((end + 1.6, 0, -0.2), (end + 5.4, 0, -3.6), 2.6, 1.1, "red")
    tail.beam((end + 4.5, 0, -2.8), (end + 6.8, 0, -5.2), 1.6, 0.6, "deep")

    # sparks: small cubes that have come loose from the flame, over the neck and over the tail
    sparks = m.part("Sparks", (-4, 0, 14), "S1")
    cube(sparks, -2.4, 0.5, 15.2, 0.9, "yellow")
    cube(sparks, -0.6, -0.5, 17.0, 0.6, "orange")
    cube(sparks, 1.6, 0.3, 13.8, 0.7, "orange")
    embers = m.part("Embers", (end + 7, 0, 9), "Tail")
    cube(embers, end + 6.6, 0.5, 9.9, 0.9, "red")
    cube(embers, end + 7.8, -0.5, 11.7, 0.6, "deep")
