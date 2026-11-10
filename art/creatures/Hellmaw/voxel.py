"""The Hellmaw (zone 10's Mythic: the demon fish with horns, lava under its scales, soul-fire eyes and burning fins) for
tools/blender/voxel_kit.py (docs/style/04-voxel-style.md), dressed as a Mythic by docs/style/05-rarity-look.md.
- The biggest of all: about 31 studs.
- Impossible parts: a broken crown of rock that floats over its head and turns; a lower jaw split in two, each half on its
  own joint, that opens down and apart; flame fins as wide as wings.
- A charcoal body with uneven ribs of lava cut across the back: its stripes. The lava shifts along the body, white-hot in
  the skull, yellow, orange, then deep red at the tail.
- Two glowing colours: the hot one above, and a cold soul-fire blue in the eyes, the throat, the crown, the snapped horn
  and the very tips of the whiskers and the tail.
- Trailing parts that follow late: a whisker each side of the snout, and the tail's two tips on their own joints.
- Horns as chains of boxes curling forward, the right one ending in a point, the left snapped off (its flaw).
The rider sits between the horns, under the crown, with a shallow slot either side for the legs."""
import math

NAME, ZONE, RARITY = "Hellmaw", "ZONE 10 / THE UNDERWORLD", "MYTHIC"
U = 0.58
SHADE = 0.72
PALETTE = {"char": "#3A3438", "white": "#FFF0B4", "ember": "#FFD23E", "lava": "#FF7B1C", "red": "#C7301C", "deep": "#8A1E14",
           "soul": "#62E4FF", "bone": "#E9DFC8", "mouth": "#5A1418", "lava-": "#E65A10", "ember-": "#FFB52E"}
SEAT = (-8, 7, 6.45)
GLOW = {"white": 1.0, "ember": 1.0, "lava": 0.85, "red": 0.5, "deep": 0.35, "soul": 1.3}
LIGHTS = [("Head", (-14, 0, -3.2), "#FF6A14", 300, 1.0),  # fire in the mouth
          ("Head", (-13, 9.0, 1.5), "#62E4FF", 70, 0.6),  # the eyes
          ("Crown", (-9.5, 0, 15.5), "#62E4FF", 160, 1.0),  # the crown
          ("S1", (-3, 8.0, 1.5), "#FFC030", 70, 0.6), ("S2", (4, 7.0, 1.5), "#FF7A1C", 60, 0.6),  # the ribs
          ("S2", (4, 0, 14), "#FFB030", 180, 1.0)]  # the fin on the back
FLOATING = ["Crown"]
FRAME, ORTHO, ORTHO_SWIM = 2.6, 40.0, 48.0
RIDE_FOG = "#3A1420"
CHAIN = ["Head", "S1", "S2", "S3", "S4", "S5", "Tail"]
AMPLITUDES = [2, 4, 7, 10, 13, 17]


def pose(parts, phase):
    """the fish swim down the chain; the jaw's two halves open down and apart once a beat; the tail's tips whip late; the
    whiskers trail; the crown turns a third of the way round each beat (it is the same every third, so the loop joins)"""
    parts["Head"].rotation_euler.z = math.radians(1.5) * math.sin(phase + math.pi)
    for k, name in enumerate(CHAIN[1:]):
        parts[name].rotation_euler.z = math.radians(AMPLITUDES[k]) * math.sin(phase - 0.8 * (k + 1))
    gape = 0.5 + 0.5 * math.sin(phase)
    for name, side in (("JawR", 1), ("JawL", -1)):
        parts[name].rotation_euler.y = -math.radians(10) * gape
        parts[name].rotation_euler.z = side * math.radians(7) * gape
    parts["TailTipU"].rotation_euler.z = math.radians(24) * math.sin(phase - 0.8 * 7.3)
    parts["TailTipL"].rotation_euler.z = math.radians(28) * math.sin(phase - 0.8 * 7.8)
    parts["Whiskers"].rotation_euler.z = math.radians(5) * math.sin(phase - 0.9)
    parts["Whiskers"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.6)
    parts["Crown"].rotation_euler.z = phase / 3


def steps_for(n):
    return [(3, 1), (1, 2)] if n >= 6 else ([(2, 1), (1, 1)] if n >= 4 else ([(1, 1)] if n >= 2 else []))


def ribbed(p, x0, x1, n, bot, top, core, ribs):
    """a length of body: charcoal, with ribs of lava cut across the back. Each rib is one cube wide and one deep, and runs
    from the top down both sides to its own height, so the ribs are uneven: the Hellmaw's stripes. core: the lava's colour
    here. ribs: (x, the height it stops at)"""
    st = steps_for(n)
    p.hull(x0, x1, n, bot, top, "char", st, st)
    p.paint_sym(x0, x1, n, bot, bot + sum(t for _, t in st), "char-")
    p.paint_sym(x0, x1, n, top - 1, top, "char+")
    for x, stop in ribs:
        inner = type(p)("core", (0, 0, 0), None)
        inner.hull(x, x + 1, n - 1, bot + 1, top - 1, core, steps_for(n - 1), steps_for(n - 1))
        for c in [c for c in p.cells if c[0] == x and c[2] >= stop]:
            if c in inner.cells:
                p.cells[c] = core
            else:
                del p.cells[c]


def tongue(p, x, z, height, lean=0.25, wide=2.4, down=False, slim=False):
    """a tongue of flame standing on the body at x, its root 1.7 cubes under the surface z: three boxes in a chain, each
    smaller and thinner than the last and starting inside it: red, orange, then a yellow tip. It leans back by `lean` of
    its height. down: it hangs under the body. slim: a thinner set of boxes, for every other tongue, so that where two
    neighbours overlap no two of their sides lie in one plane"""
    s = -1 if down else 1

    def at(f):
        return (x + lean * height * f, 0, z + s * (height * f - 1.7 * (1 - f)))

    thick = (1.47, 1.03, 0.57) if slim else (1.7, 1.25, 0.8)
    p.beam(at(0.0), at(0.5), wide, thick[0], "red")
    p.beam(at(0.36), at(0.8), wide * 0.72, thick[1], "lava")
    p.beam(at(0.68), at(1.0), wide * 0.46, thick[2], "ember")


def build(m):
    head = m.part("Head", (-6, 0, 0))
    head.hull(-18, -15, 4, -2, 4, "char", [(1, 1)])  # the snout
    head.hull(-15, -11, 6, -2, 7, "char", [(3, 1), (1, 2)])  # the skull, over the mouth
    head.hull(-11, -6, 6, -6, 7, "char", [(3, 1), (1, 2)], [(3, 1), (1, 2)])
    head.paint_sym(-11, -6, 6, -6, -3, "char-")
    head.paint_sym(-18, -15, 4, 3, 4, "char+")
    head.paint_sym(-15, -6, 6, 6, 7, "char+")
    # cracks across the skull: cubes cut out, white-hot lava showing in them
    for x, j in ((-15, 0), (-14, 0), (-14, 1), (-13, 1), (-12, 1), (-12, 2), (-11, 2), (-10, -1), (-9, -1), (-9, -2), (-13, -2)):
        head.carve(x, x + 1, j, j + 1, 6, 7)
        head.paint(x, x + 1, j, j + 1, 5, 6, "white")
    head.carve_pair(-9, -8, 6, 7, -5, -2)  # and one down each cheek
    head.paint_pair(-9, -8, 5, 6, -5, -2, "ember")
    # a glowing crack along the head, under the eye
    head.carve_pair(-15, -6, 6, 7, -1, 0)
    head.paint_pair(-15, -6, 5, 6, -1, 0, "ember")
    # the roof and back of the mouth, soul-fire in the throat, and the upper fangs, each with its base sunk into the head
    head.paint(-18, -11, -5, 6, -2, -1, "mouth")
    head.paint(-11, -10, -5, 6, -6, -2, "mouth")
    head.paint(-11, -10, -3, 4, -5, -2, "soul")
    for x, y, length in ((-17.4, 2.6, 2.2), (-15.6, 3.7, 1.8), (-13.4, 5.6, 2.9), (-11.9, 5.6, 1.7)):
        head.tooth(x, y, -1.85, 1.0, length, "bone")
    # the soul-fire eyes: a blue frame one cube proud, a white-hot square in it, under a brow box that slants down to the
    # front
    head.pair(-14, -11, 7, 8, 0, 3, "soul")
    head.paint_pair(-13, -12, 7, 8, 1, 2, "white")
    head.beam((-14.9, 7.0, 2.35), (-10.8, 7.0, 3.2), 1.3, 1.6, "char", mirror=True)
    # a bone spike on each cheek, pointing back and out
    head.spike([(-7.6, 6.35, -2.7), (-6.2, 6.35, -2.7), (-6.2, 6.35, -1.3), (-7.6, 6.35, -1.3)], (-4.4, 9.6, -2.4), "bone", mirror=True)
    # the horns: chains of boxes that rise and curl forward, each smaller than the last. The right one ends in a point
    head.beam((-8.6, 4.2, 5.2), (-9.4, 4.5, 9.6), 2.8, 2.4, "bone-")
    head.beam((-9.1, 4.4, 8.7), (-11.8, 4.7, 12.0), 2.2, 1.9, "bone")
    head.beam((-11.1, 4.6, 11.2), (-14.6, 4.9, 13.2), 1.7, 1.5, "bone")
    head.spike([(-14.2, 4.3, 12.4), (-14.2, 5.5, 12.4), (-14.2, 5.5, 13.6), (-14.2, 4.3, 13.6)], (-18.4, 5.1, 15.2), "bone+")
    # the left one is snapped off: a stump, soul-fire at the break
    head.beam((-8.6, -4.2, 5.2), (-9.4, -4.5, 9.6), 2.8, 2.4, "bone-")
    head.beam((-9.1, -4.4, 8.7), (-10.4, -4.55, 10.3), 2.2, 1.9, "bone")
    head.beam((-10.2, -4.52, 10.0), (-10.8, -4.6, 10.75), 1.7, 1.5, "soul")
    # the seat between the horns: a shallow slot either side for the rider's legs
    head.dent(-9, -7, 6, 1, 4, "char-")

    # the lower jaw, split down the middle: each half on its own joint, opening down and apart. An underbite: it juts
    # past the snout. A glowing gum line round each half's rim, and pointed fangs standing in it
    for name, s in (("JawR", 1), ("JawL", -1)):
        jaw = m.part(name, (-9, 3 * s, -4), "Head")
        a, b = (1, 6) if s > 0 else (-5, 0)  # the columns of this half: one cube is left out down the middle
        jaw.box(-19, -9, a, b, -7, -4, "char")
        jaw.box(-18, -10, a if s > 0 else a + 1, b - 1 if s > 0 else b, -8, -7, "char-")
        jaw.paint(-19, -9, a if s > 0 else a + 1, b - 1 if s > 0 else b, -5, -4, "mouth")
        side = (4.25, 5.3, -4.1, -3.7) if s > 0 else (-5.3, -4.25, -4.1, -3.7)
        jaw.block(-18.8, side, -11.4, side, "lava")
        front = (0.7, 4.25, -4.1, -3.7) if s > 0 else (-4.25, -0.7, -4.1, -3.7)
        jaw.block(-18.8, front, -17.8, front, "lava")
        for x, y, length in ((-18.3, 1.3, 3.3), (-18.3, 3.4, 2.3), (-16.6, 4.78, 2.1), (-14.4, 4.78, 2.0), (-12.3, 4.78, 1.4)):
            jaw.tooth(x, y * s, -3.82, 0.9, -length, "bone", mirror=False)

    # a whisker each side of the snout, trailing back: three thin boxes, charcoal, lava, then a soul-fire tip
    whiskers = m.part("Whiskers", (-16.5, 0, -0.6), "Head")
    whiskers.beam((-16.6, 3.9, -0.6), (-13.2, 7.4, -2.6), 0.9, 0.7, "char", flat="z", mirror=True)
    whiskers.beam((-13.9, 6.7, -2.2), (-10.0, 9.6, -4.6), 0.6, 0.45, "lava", flat="z", mirror=True)
    whiskers.beam((-10.7, 9.1, -4.2), (-8.0, 10.6, -6.2), 0.35, 0.2, "soul", flat="z", mirror=True)

    # the crown: six shards of rock in a broken ring, floating over the head and turning. Each has soul-fire under it.
    # Three big and three small, set unevenly, the same every third of a turn
    crown = m.part("Crown", (-9.5, 0, 16), "Head")
    for k in range(3):
        for angle, radius, tall, wide, thick in ((0, 4.8, 3.4, 1.9, 1.5), (52, 4.4, 2.2, 1.4, 1.1)):
            a = math.radians(angle + 120 * k + 20)
            c, s = math.cos(a), math.sin(a)
            foot = (-9.5 + radius * c, radius * s, 14.8)
            tip = (-9.5 + (radius + 0.9) * c, (radius + 0.9) * s, 14.8 + tall)
            crown.beam(foot, tip, wide, thick, "char")
            glow_from = tuple(f + 0.22 * (f - t) for f, t in zip(foot, tip))
            glow_to = tuple(f + 0.3 * (t - f) for f, t in zip(foot, tip))
            crown.beam(glow_from, glow_to, wide - 0.6, thick - 0.5, "soul")
            if tall > 3:  # the big shards end in a point, like a crown's
                length = math.sqrt(sum((t - f) ** 2 for f, t in zip(foot, tip)))
                along = [(t - f) / length for f, t in zip(foot, tip)]
                thin = [(1.0 if k == 1 else 0.0) - along[1] * along[k] for k in range(3)]
                size = math.sqrt(sum(v * v for v in thin))
                thin = [v / size for v in thin]
                across = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
                mid = [f + 0.82 * (t - f) for f, t in zip(foot, tip)]
                hw, ht = wide / 2 - 0.2, thick / 2 - 0.2
                base = [tuple(mid[k] + a * across[k] * hw + b * thin[k] * ht for k in range(3)) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                crown.spike(base, tuple(t + 1.9 * d for t, d in zip(tip, along)), "char+")

    cuts = [-6, 1, 8, 14, 19, 23]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(5)]
    # the body: the lava under it cools along its length, yellow behind the head to deep red at the tail
    ribbed(segs[0], -6, 1, 6, -6, 8, "ember", ((-5, 2), (-3, -2), (-1, 4)))
    ribbed(segs[1], 1, 8, 5, -5, 7, "lava", ((2, -1), (4, 3), (7, 0)))
    ribbed(segs[2], 8, 14, 4, -4, 6, "lava-", ((9, 1), (11, -1), (12, 4)))
    ribbed(segs[3], 14, 19, 3, -3, 5, "red", ((15, 0), (17, 2)))
    ribbed(segs[4], 19, 23, 2, -2, 3, "deep", ((20, 0), (22, 1)))
    segs[0].sym(-7, -6, 4, -4, 5, "lava-")  # sleeves, one cube into the piece in front
    segs[1].sym(0, 1, 4, -4, 5, "lava-")
    segs[2].sym(7, 8, 3, -3, 4, "lava-")
    segs[3].sym(13, 14, 2, -2, 3, "lava-")
    segs[4].sym(18, 19, 1, -1, 2, "lava-")

    # the burning fins: tongues of flame down the back, tallest in the middle, and two under the tail stock
    tongue(segs[0], -4.3, 8, 5.0)
    tongue(segs[0], -1.6, 8, 7.0, slim=True)
    tongue(segs[1], 2.4, 7, 8.5, wide=2.8)
    tongue(segs[1], 5.4, 7, 6.5, slim=True)
    tongue(segs[2], 9.4, 6, 6.0)
    tongue(segs[2], 12.0, 6, 4.6, slim=True)
    tongue(segs[3], 15.4, 5, 4.5)
    tongue(segs[3], 17.9, 5, 3.2, wide=2.0, slim=True)
    tongue(segs[4], 20.6, 3, 3.2, wide=1.8)
    tongue(segs[3], 15.6, -3, 3.6, wide=2.0, down=True)
    tongue(segs[3], 17.8, -3, 2.6, wide=1.8, down=True, slim=True)
    # the side fins: flames as wide as wings, three boxes swept back
    segs[0].beam((-5.1, 4.9, -1.2), (-0.6, 9.4, -1.9), 4.4, 1.1, "red", flat="z", mirror=True)
    segs[0].beam((-1.6, 8.4, -1.75), (2.4, 12.6, -2.4), 3.2, 0.8, "lava", flat="z", mirror=True)
    segs[0].beam((1.6, 11.8, -2.3), (4.6, 14.6, -2.8), 2.0, 0.5, "ember", flat="z", mirror=True)

    # the tail: a forked flame on its own joint: a red stock and two orange forks. Each fork's tip is on a joint of its
    # own, so it whips late: yellow, ending in soul-fire
    tail = m.part("Tail", (23, 0, 0), "S5")
    tail.beam((22.6, 0, 0.5), (26.4, 0, 0.9), 4.2, 1.6, "red")
    tail.beam((24.6, 0, 1.3), (29.4, 0, 7.2), 3.4, 1.2, "lava")
    tail.beam((24.6, 0, 0.0), (28.8, 0, -5.0), 3.0, 0.9, "lava")
    upper = m.part("TailTipU", (28.9, 0, 6.6), "Tail")
    upper.beam((28.4, 0, 6.0), (32.4, 0, 11.4), 2.4, 0.8, "ember")
    upper.beam((31.6, 0, 10.3), (34.0, 0, 14.2), 1.5, 0.5, "soul")
    lower = m.part("TailTipL", (28.3, 0, -4.4), "Tail")
    lower.beam((27.9, 0, -3.9), (31.2, 0, -8.4), 2.1, 0.6, "ember")
    lower.beam((30.5, 0, -7.5), (32.4, 0, -10.8), 1.3, 0.3, "soul")
