"""The rarity ladder (docs/style/05-rarity-look.md): ONE invented reef fish dressed at each of the six tiers, for
tools/blender/voxel_kit.py. Set TIER (1 Common to 6 Mythic) and, at tier 6, MYTHIC; tools/art/rarity_ladder.py builds them
all and lays them out.

The base body is the same cubes every time. The rules every tier keeps (the user's notes, 2026-11-10):
- One idea per creature, and every feature serves it.
- A tier adds few kinds of feature (a repeated motif counts once). Patterns never cross: stripes or a ribbon on the flank,
  never both. Half the flank stays plain. One focal point at the head, one echo at the tail.
- Glow needs a reason, and there is a balance: it may be on any kind of Mythic, as thin lines and small points, not as
  the whole design. Below Mythic one or two things glow.
- From Epic up the fins get richer: more boxes in a taper, spars standing proud of them, claws, hems.
The top was enriched after the first clean pass read a notch too plain; the Hellmaw is the measure of how rich.

  1 Common     a plain reef fish: two colours, body and fins.
  2 Uncommon   a crest: one tall back fin with a coloured tip, and two pale bands.
  3 Rare       a sail: the crest becomes three plates along the back; the tail's tips are coloured; the jaw has a joint.
  4 Epic       a hunter, a sailfish: darker; a bill; three uneven stripes over the shoulder and two at the tail; a glowing
               eye under a brow. Its fins are a hunter's: spars on the sail, long sickle side fins, finlets at the tail.
  5 Legendary  a lantern-bearer in old armour. Bone is its motif: a horned helmet, cheek guards, spars on every fin, claws
               on the side fins, scutes under the belly, a ring at the tail. A lure glows, and so, faintly, does the one
               amber ribbon along its flank.
  6 Mythic     four different ways to feel mythic, on the same fish (MYTHIC):
     light     a fish of the deep that is its own lantern: one line of violet light from the eye to the ends of its tail,
               a row of small lights under it, a lure. The calm one.
     regal     a king: gold on royal blue. A crown, three jewelled rings, a mantle hanging down each flank with gold hems,
               gold spars, a beard, a train behind the tail. Only its rubies glow, softly.
     crystal   a fish that crystal has grown through: shards for its fins and tail, clusters through its shoulders, cracks
               in its flank with light in them, and shards that float free. The crystal is deep at the root, pale at the tip.
     ancient   so old that the reef has grown on it: coral trees and a table coral on its back, a crust on its head,
               anemones that glow a little, weed, and a ship's anchor still hanging from a chain round it.
It grows with its tier through U, the size of a cube."""
TIER = 6
MYTHIC = "regal"

MYTHICS = {"light": ("The lantern", "Light with a source, and proportion: one line of violet light from the eye to the ends of a very long tail, a row of small lights under it."),
           "regal": ("The reef king", "Regalia: gold on royal blue. A crown, jewelled rings, a mantle with gold hems, a train. Only its rubies glow, softly."),
           "crystal": ("The shard", "Material, and floating parts: crystal has grown through it, deep at the root and pale at the tip, with light in its cracks."),
           "ancient": ("The old one", "Age, and size: a reef has grown on it, and an anchor still hangs from it. Its anemones, the ends of its coral and a few specks in its algae glow, a little.")}
T = TIER - 1
KIND = MYTHIC if TIER == 6 else ""
RARITY = ("COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC")[T]
NAME, ZONE = "Ladder fish", "RARITY LADDER"
# what this fish has
HAS = {1: set(), 2: {"crest", "sailtips", "bands"}, 3: {"sail", "sailtips", "tailtips", "bands", "jaw"},
       4: {"sail", "sailtips", "tailtips", "jaw", "bill", "stripes", "stare", "fins", "spars", "sickle", "finlets"},
       5: {"sail", "sailtips", "tailtips", "jaw", "bill", "ribbon", "armour", "lure", "stare", "fins", "spars", "sickle", "claws", "horns",
           "cheeks", "scutes", "tailspars", "tusks", "studs"}}.get(TIER) or {
    "light": {"sail", "tailtips", "jaw", "ribbon", "lure", "streamers", "stare", "fins", "spars", "sickle", "filaments", "photophores", "barbel", "rays"},
    "regal": {"sail", "sailtips", "tailtips", "jaw", "crown", "rings", "mantle", "stare", "fins", "spars", "tailspars", "jewels", "train", "beard", "fintips"},
    "crystal": {"jaw", "shards", "fins", "blades", "cracks"},
    "ancient": {"jaw", "coral", "crust", "weed", "lid", "fins", "reef", "anemones", "anchor", "sponges", "wreck", "algae"}}.get(KIND, set())

# a Mythic is the biggest: about 31 studs, the old one 34 (the lantern and the king are long by what trails, so their
# cubes are smaller)
U = (0.36, 0.425, 0.455, 0.47, 0.585, {"light": 0.74, "regal": 0.84, "crystal": 0.94, "ancient": 1.02}.get(KIND, 1.0))[T]
LENGTH = (11, 13, 15, 19, 25, {"light": 32, "regal": 32, "crystal": 31, "ancient": 34}.get(KIND, 0))[T]  # studs, nose to tail
FRAME, ORTHO = LENGTH / 12 * 1.12, LENGTH * 1.3
PALETTE = {"body": ("#6FA8C8", "#62A0C8", "#4A8CBC", "#2C5F93", "#1E3E6B", "#17122E")[T],
           "belly": ("#EAF0F2", "#EAF0F2", "#E6EEF1", "#DDE7EC", "#CBD7DE", "#2B2550")[T],
           "white": "#FFFFFF", "black": "#2B2D33"}
if TIER >= 2:
    PALETTE["accent"] = ("", "#F4B24A", "#F4B24A", "#FF9A2E", "#FFB21E", "#B26BFF")[T]  # the tips
if TIER == 4:
    PALETTE.update(eye="#FFD23E", spar="#5B92C8")
    GLOW = {"eye": 1.0}
if TIER == 5:
    PALETTE.update(eye="#FFB21E", sig="#FFB21E", bone="#D9CDB0", lamp="#FFD25A", spar="#D9CDB0")
    GLOW = {"lamp": 1.0, "sig": 0.45}
    LIGHTS = [("Head", (-9.5, 0, 9.0), "#FFB21E", 60, 0.6)]
if KIND == "light":
    PALETTE.update(body="#17122E", belly="#2B2550", accent="#8E4DF5", sig="#8E4DF5", eye="#C48CFF", lamp="#EBD9FF", spar="#3B3470")
    GLOW = {"sig": 0.45, "accent": 0.45, "eye": 0.9, "lamp": 1.2}
    LIGHTS = [("Head", (-9.5, 0, 9.0), "#B26BFF", 110, 0.7), ("S2", (3, 7.5, 0.5), "#B26BFF", 40, 0.6)]
if KIND == "regal":
    PALETTE.update(body="#1E3F9A", belly="#EFE7D2", accent="#E0B23A", eye="#D02A44", spar="#E0B23A")
    GLOW = {"eye": 0.6}
if KIND == "crystal":
    PALETTE.update(body="#3C4468", belly="#9096B8", crystal="#DC52AC", pale="#FF9FDC", eye="#DC52AC")
    PALETTE["crystal-"] = "#8E2A7E"
    GLOW = {"pale": 0.6, "crystal": 0.2}
    LIGHTS = [("S2", (4.0, 0, 10.0), "#FF7AD0", 150, 0.8)]
    FLOATING = ["Drift"]
if KIND == "ancient":
    PALETTE.update(body="#4A6670", belly="#B9C4BF", coral="#E86F5C", crust="#D8CDB4", weed="#5F8F58", lume="#7FF0D8", iron="#3B3F46", sponge="#E2B84A", wood="#7A5A3C")
    GLOW = {"lume": 0.7}
    LIGHTS = [("S2", (1.8, 4.0, 8.2), "#7FF0D8", 45, 0.5), ("S2", (6.6, 0.9, 18.0), "#7FF0D8", 60, 0.6)]
SEAT = (-0.5, 7, 5.6)
SWIM = {"chain": ["Head", "S1", "S2", "S3", "S4", "Tail"], "amplitudes": [3, 6, 9, 12, 18], "phaseStep": 0.9, "headCounter": 2}
PROUD = 0.3  # how far a band, a stripe or a ribbon stands off the body, in cubes


def steps(n):
    """the corner steps of a body slab n cubes out: (top, bottom)"""
    if n >= 5:
        return [(3, 1), (1, 1)], [(3, 1), (1, 2)]
    if n >= 4:
        return [(2, 1), (1, 1)], [(2, 1), (1, 1)]
    if n >= 3:
        return [(1, 1)], [(1, 1)]
    return [], []


def slab(p, x0, x1, n, bot, top):
    """a length of body with stepped corners: lighter on the top row, a pale belly, its steps darker"""
    steps_top, steps_bottom = steps(n)
    p.hull(x0, x1, n, bot, top, "body", steps_top, steps_bottom)
    p.paint_sym(x0, x1, n, bot, bot + max(1, round((top - bot) * 0.3)), "belly")
    p.paint_sym(x0, x1, n, bot, bot + sum(t for _, t in steps_bottom), "belly-")
    if steps_top:
        p.paint_sym(x0, x1, n, top - 1, top, "body+")


def stripe(p, x0, x1, n, bot, top, stop, colour="belly"):
    """a band of colour over the back from x0 to x1, a third of a cube proud, stopping at height `stop` (None: all round)"""
    steps_top, steps_bottom = steps(n)
    p.band(x0, x1, n, bot, top, colour, steps_top, steps_bottom, PROUD, stop=stop)


def axes(a, b, flat="y"):
    """the directions of a box from a to b, as voxel_kit's beam() works them out: along it, across its width, through it"""
    d = [q - p for p, q in zip(a, b)]
    length = sum(v * v for v in d) ** 0.5
    along = [v / length for v in d]
    ref = (0.0, 1.0, 0.0) if flat == "y" else (0.0, 0.0, 1.0)
    dot = sum(x * r for x, r in zip(along, ref))
    thin = [r - dot * x for x, r in zip(along, ref)]
    size = sum(v * v for v in thin) ** 0.5
    thin = [v / size for v in thin]
    wide = [along[1] * thin[2] - along[2] * thin[1], along[2] * thin[0] - along[0] * thin[2], along[0] * thin[1] - along[1] * thin[0]]
    return along, wide, thin, length


def ridge(p, a, b, offset, width, thick, colour, flat="y", short=0.4, lead=0.0):
    """a spar or a hem on a fin that runs from a to b: a narrow box along it, thicker than the fin so it stands proud of
    both its faces, `offset` across the fin from its middle, ending `short` of the fin's end. lead: it starts this far
    before the fin's root, deeper in the body (for a fin on its own joint, whose root face is not hidden by its own part)"""
    along, wide, _, _ = axes(a, b, flat)
    start = tuple(a[k] + offset * wide[k] - lead * along[k] for k in range(3))
    end = tuple(b[k] + offset * wide[k] - short * along[k] for k in range(3))
    p.beam(start, end, width, thick, colour, flat=flat)


def trailing(a, b, flat, reach):
    """`reach` across a fin from its middle, toward the edge that faces the tail"""
    _, wide, _, _ = axes(a, b, flat)
    return reach if wide[0] > 0 else -reach


def low_edge(a, b, reach, flat="y"):
    """`reach` across a fin from its middle, toward its lower edge"""
    _, wide, _, _ = axes(a, b, flat)
    return reach if wide[2] < 0 else -reach


def shard(p, foot, tip, wide, thick, colour="crystal", point="pale", part=0.62, deep=None):
    """a crystal, a horn or a claw: a box from its foot most of the way to its tip, then a pyramid to the point, in a paler
    tone. deep: a darker colour for its root, with the box above it a step thinner, so it shifts from deep to pale"""
    along, across, thin, length = axes(foot, tip)
    d = [t - f for f, t in zip(foot, tip)]
    if deep:
        p.beam(foot, tuple(f + 0.5 * part * v for f, v in zip(foot, d)), wide, thick, deep)
        foot = tuple(f + 0.36 * part * v for f, v in zip(foot, d))
        d = [t - f for f, t in zip(foot, tip)]
        length = sum(v * v for v in d) ** 0.5
        part = (part - 0.36 * part) / (1 - 0.36 * part)
        wide, thick = wide - 0.3, thick - 0.3
    end = tuple(f + part * v for f, v in zip(foot, d))
    p.beam(foot, end, wide, thick, colour)
    mid = [f + (part - min(0.12, 0.4 / length)) * v for f, v in zip(foot, d)]
    hw, ht = wide / 2 - 0.15, thick / 2 - 0.15
    base = [tuple(mid[k] + a * across[k] * hw + b * thin[k] * ht for k in range(3)) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    p.spike(base, tuple(tip), point)


def build(m):
    head = m.part("Head", (-5, 0, 0))
    slab(head, -9, -5, 4, -5, 6)
    # the face: a muzzle box, a lighter slab leaning down it for the forehead, a pale lip block, a jaw box (on its own
    # joint from Rare)
    muzzle = (-3.2, 3.2, -2.8, 2.7)
    head.block(-11.0, muzzle, -8.8, muzzle, "body")
    head.beam((-8.397, 0, 4.216), (-10.95, 0, 2.074), 6.7, 1.7, "body+", flat="z")
    lip = (-1.5, 1.5, -1.3, -0.1)
    head.block(-11.9, lip, -10.9, lip, "belly")
    jaw_part = m.part("Jaw", (-8.9, 0, -3.3), "Head") if "jaw" in HAS else head
    jaw = (-2.3, 2.3, -3.9, -2.7)
    jaw_part.block(-10.4, jaw, -8.9, jaw, "belly-")
    if "tusks" in HAS:  # two bone tusks up from the jaw
        jaw_part.tooth(-10.0, 1.6, -2.78, 0.7, -1.7, "bone")
    if "beard" in HAS:  # a king's beard: two short gold barbels under the chin
        for s in (1, -1):
            jaw_part.beam((-9.9, s * 1.3, -3.3), (-9.3, s * 1.7, -6.6), 0.6, 0.6, "accent")
    if "barbel" in HAS:  # a barbel under the chin with a small light on its end, as dragonfish have
        jaw_part.beam((-9.6, 0, -3.4), (-8.6, 0, -6.6), 0.5, 0.5, "body-")
        bulb = (-0.5, 0.5, -7.3, -6.3)
        jaw_part.block(-9.1, bulb, -8.1, bulb, "lamp")
    # the eye: a white frame one cube proud, a pupil low and forward
    head.pair(-9, -6, 5, 6, 1, 4, "white")
    head.paint_pair(-9, -7, 5, 6, 1, 3, "eye" if "eye" in PALETTE else "black")
    if "stare" in HAS:  # a brow box slanting over it: a hunter's stare
        head.beam((-8.9, 4.95, 3.2), (-6.2, 4.95, 3.45), 1.0, 1.5, "body", mirror=True)
    if "lid" in HAS:  # a heavy lid over half of it: old and slow
        head.beam((-8.85, 4.95, 2.5), (-6.1, 4.95, 2.8), 1.7, 1.5, "body-", mirror=True)
    if "bill" in HAS:  # the weapon: a bill out of the muzzle, two boxes and a point
        head.beam((-10.4, 0, 0.9), (-14.6, 0, 0.5), 2.6, 1.4, "body", flat="z")
        head.beam((-14.0, 0, 0.56), (-17.6, 0, 0.25), 1.8, 1.0, "belly", flat="z")
        head.spike([(-17.2, -0.7, -0.05), (-17.2, 0.7, -0.05), (-17.2, 0.7, 0.6), (-17.2, -0.7, 0.6)], (-19.8, 0.0, 0.15), "belly+")
    if "armour" in HAS or "crust" in HAS:  # a helmet over the top of the head: bone armour, or a crust of barnacles
        stripe(head, -8.6, -5.4, 4, -5, 6, 4.3, "bone" if "armour" in HAS else "crust")
    if "horns" in HAS:  # two short horns sweeping back off the helmet
        for s in (1, -1):
            shard(head, (-7.3, s * 3.0, 4.6), (-4.0, s * 4.5, 10.4), 1.1, 0.9, "bone", "bone+", part=0.55)
    if "cheeks" in HAS:  # a bone guard on each cheek, under the eye
        guard = (4.45, 4.85, -2.4, 0.4)
        head.block(-8.4, guard, -5.6, guard, "bone", mirror=True)
    if "crust" in HAS:  # big barnacles on it, on each cheek, and on along the back in front of the rider
        for x0, x1, ya, yb in ((-8.3, -7.2, -1.9, -0.6), (-6.9, -5.8, 0.4, 1.7)):
            knob = (ya, yb, 6.2, 7.0)
            head.block(x0, knob, x1, knob, "crust+")
        knob = (4.4, 5.2, -1.9, -0.6)
        head.block(-7.9, knob, -6.6, knob, "crust", mirror=True)
    if "lure" in HAS:  # a rod off the top of the head with a glowing bulb: the one source of its light
        head.beam((-7.4, 0, 5.4), (-9.4, 0, 8.8), 0.8, 0.8, "body-")
        bulb = (-0.65, 0.65, 8.3, 9.6)
        head.block(-10.1, bulb, -8.9, bulb, "lamp")
    if "crown" in HAS:  # a gold crown on the head: a low band, five tall points, a ruby at the front
        band = (-2.2, 2.2, 5.85, 6.75)
        head.block(-8.4, band, -5.6, band, "accent")
        head.tooth(-7.85, 0.0, 6.65, 0.9, -3.3, "accent+", mirror=False)
        head.tooth(-7.25, 1.55, 6.65, 0.8, -2.5, "accent+")
        head.tooth(-6.15, 1.55, 6.65, 0.8, -2.0, "accent+")
        head.tooth(-5.95, 0.0, 6.65, 0.8, -2.4, "accent+", mirror=False)
        ruby = (-0.5, 0.5, 5.95, 6.65)
        head.block(-8.7, ruby, -8.3, ruby, "eye")
    if "shards" in HAS:  # two shards on the brow, one big, one small
        shard(head, (-7.6, 0.5, 5.0), (-9.8, 0.9, 10.4), 1.4, 1.1, deep="crystal-")
        shard(head, (-6.4, -0.9, 5.0), (-6.0, -1.5, 8.2), 1.0, 0.7)
        for s in (1, -1):  # and one out of each cheek
            shard(head, (-6.6, s * 4.0, -1.0), (-5.0, s * 7.8, -3.6), 1.0, 0.7)

    cuts = [-5, 1, 6, 10, 12]
    segs = [m.part(f"S{i + 1}", (cuts[i], 0, 0), "Head" if i == 0 else f"S{i}") for i in range(4)]
    slab(segs[0], -5, 1, 5, -6, 7)
    slab(segs[1], 1, 6, 5, -6, 7)
    slab(segs[2], 6, 7, 5, -6, 7)
    slab(segs[2], 7, 9, 4, -4, 5)
    slab(segs[2], 9, 10, 3, -3, 4)
    slab(segs[3], 10, 12, 2, -2, 3)
    segs[0].sym(-6, -5, 3, -3, 4, "body-")  # sleeves, one cube into the piece in front
    segs[1].sym(0, 1, 3, -4, 5, "body-")
    segs[2].sym(5, 6, 3, -4, 5, "body-")
    segs[3].sym(9, 10, 2, -2, 3, "body-")
    segs[0].dent(-2, 1, 5, 1, 4, "body-")  # the seat: a shallow slot either side for the rider's legs

    # the flank's pattern: one of bands, stripes or a ribbon, never two
    if "bands" in HAS:  # two pale bands
        stripe(segs[0], -3.9, -2.55, 5, -6, 7, -1.7)
        stripe(segs[1], 2.55, 3.9, 5, -6, 7, -1.7)
    if "stripes" in HAS:  # three uneven stripes over the shoulder, two at the tail; the middle stays plain
        for x, stop in ((-4.1, -1.7), (-3.35, 1.8), (-2.6, 0.2)):
            stripe(segs[0], x, x + 0.4, 5, -6, 7, stop)
        for x, stop in ((7.4, -0.6), (8.2, 1.3)):
            stripe(segs[2], x, x + 0.4, 4, -4, 5, stop)
    if "ribbon" in HAS:  # one line of the signature colour along each side
        runs = [(segs[0], -4.85, 0.85, 5.5), (segs[1], 1.15, 5.85, 5.5), (segs[2], 6.15, 6.85, 5.5), (segs[2], 7.15, 8.85, 4.5),
                (segs[2], 9.15, 9.85, 3.5)]
        if "armour" not in HAS:
            runs.append((segs[3], 10.15, 11.85, 2.5))
        for p, x0, x1, half in runs:
            ribbon = (half - 0.05, half + PROUD, 0.2, 0.8)
            p.block(x0, ribbon, x1, ribbon, "sig", mirror=True)
    if "photophores" in HAS:  # a row of small lights under the line, as deep-sea fish have, smaller toward the tail
        for p, x, half, z, size in ((segs[0], -4.2, 5.5, -2.6, 0.7), (segs[0], -2.7, 5.5, -2.6, 0.7), (segs[0], -1.2, 5.5, -2.6, 0.65),
                                    (segs[0], 0.2, 5.5, -2.6, 0.65), (segs[1], 1.7, 5.5, -2.6, 0.6), (segs[1], 3.2, 5.5, -2.6, 0.6),
                                    (segs[1], 4.7, 5.5, -2.6, 0.55), (segs[2], 6.2, 5.5, -2.6, 0.5), (segs[2], 7.7, 4.5, -1.8, 0.45)):
            dot = (half - 0.05, half + PROUD, z, z + size)
            p.block(x, dot, x + size, dot, "sig", mirror=True)
    if "cracks" in HAS:  # cracks in the flank where the crystal shows through, with light in them: shallow, uneven
        segs[0].dent(-4, -3, 5, 2, 5, "pale")
        segs[1].dent(2, 3, 5, 1, 5, "pale")
        segs[1].dent(5, 6, 5, -1, 3, "pale")
    if "armour" in HAS:  # the helmet's echo: a bone ring round the tail stock, with a darker rim
        stripe(segs[3], 10.35, 11.3, 2, -2, 3, None, "bone")
        stripe(segs[3], 11.3, 11.65, 2, -2, 3, None, "bone-")
    if "studs" in HAS:  # bone studs along the spine between the sail's plates
        for part, x, top in ((segs[1], 5.25, 7), (segs[2], 9.15, 4)):
            stud = (-0.85, 0.85, top - 0.1, top + 0.5)
            part.block(x, stud, x + 0.7, stud, "bone")
    if "algae" in HAS:  # algae in patches on its back and its left flank: paint only
        segs[0].paint(-5, -3, -2, 1, 6, 7, "weed-")
        segs[1].paint(4, 6, 0, 3, 6, 7, "weed-")
        segs[1].paint(2, 4, -5, -4, 2, 5, "weed-")
        segs[2].paint(7, 9, -4, -3, 0, 3, "weed-")
        for part, x, j, z in ((segs[0], -4, 0, 6), (segs[1], 5, 1, 6), (segs[1], 3, -5, 3), (segs[2], 8, -4, 1)):
            part.paint(x, x + 1, j, j + 1, z, z + 1, "lume")  # one speck of living light in each patch
    if "sponges" in HAS:  # tube sponges: three yellow tubes of uneven height on the left shoulder, two by the tail
        for part, x, y, z, tall in ((segs[0], -4.9, -3.9, 5.9, 3.0), (segs[0], -3.8, -3.3, 5.9, 2.0), (segs[0], -4.6, -2.3, 6.9, 1.2),
                                    (segs[2], 9.05, 0.9, 3.9, 2.2), (segs[2], 9.05, -1.6, 3.9, 1.4)):
            tube = (y, y + 0.9, z, z + tall)
            part.block(x, tube, x + 0.9, tube, "sponge")
    if "wreck" in HAS:  # a piece of a ship's hull grown onto its right flank: three planks and two ribs
        for x0, x1, z in ((1.9, 5.9, -2.7), (2.3, 5.6, -1.6), (1.9, 5.2, -0.5)):
            plank = (5.45, 5.95, z, z + 0.8)
            segs[1].block(x0, plank, x1, plank, "wood")
        for x in (2.8, 4.5):
            rib = (5.45, 6.2, -2.85, 0.45)
            segs[1].block(x, rib, x + 0.5, rib, "wood-")
    if "scutes" in HAS:  # three bone scutes under the belly
        for part, x in ((segs[0], -3.6), (segs[0], -1.2), (segs[1], 1.6)):
            part.spike([(x, -0.6, -5.9), (x + 1.4, -0.6, -5.9), (x + 1.4, 0.6, -5.9), (x, 0.6, -5.9)], (x + 2.0, 0.0, -7.7), "bone")
    if "rings" in HAS:  # a gold ring behind the head, a girdle behind the mantle, and a ring round the tail stock
        stripe(segs[0], -3.9, -3.0, 5, -6, 7, None, "accent")
        stripe(segs[1], 4.9, 5.6, 5, -6, 7, None, "accent")
        stripe(segs[3], 10.35, 11.3, 2, -2, 3, None, "accent")
        stripe(segs[3], 11.3, 11.65, 2, -2, 3, None, "accent-")
    if "jewels" in HAS:  # rubies set in the rings: one each side and one on top of the neck ring, one each side of the tail's
        jewel = (5.7, 6.15, 0.4, 1.5)
        segs[0].block(-3.8, jewel, -3.1, jewel, "eye", mirror=True)
        jewel = (-0.55, 0.55, 7.2, 7.7)
        segs[0].block(-3.8, jewel, -3.1, jewel, "eye")
        jewel = (2.7, 3.15, 0.1, 1.0)
        segs[3].block(10.5, jewel, 11.15, jewel, "eye", mirror=True)
        jewel = (5.7, 6.2, 0.3, 1.7)
        segs[1].block(5.0, jewel, 5.5, jewel, "eye", mirror=True)
    if "finlets" in HAS:  # a hunter's finlets: small points along the tail stock, above and below
        for part, x, top, bottom in ((segs[2], 9.1, 4, -3), (segs[3], 10.5, 3, -2)):
            part.spike([(x, -0.4, top - 0.1), (x + 0.8, -0.4, top - 0.1), (x + 0.8, 0.4, top - 0.1), (x, 0.4, top - 0.1)], (x + 1.3, 0.0, top + 1.6), "body-")
            part.spike([(x, -0.4, bottom + 0.1), (x + 0.8, -0.4, bottom + 0.1), (x + 0.8, 0.4, bottom + 0.1), (x, 0.4, bottom + 0.1)], (x + 1.3, 0.0, bottom - 1.6),
                       "body-")

    # the back fin: a low lobe (Common); a tall crest with a coloured tip (Uncommon); a sail of three plates (Rare up),
    # with spars standing proud of them from Epic
    tips = "sailtips" in HAS
    plates = []
    if "crest" in HAS or "sail" in HAS:
        plates.append((segs[1], (3.2, 0, 6.3), (4.6, 0, 11.4), 3.6, (-0.95, 0.95), 1.4))
        segs[1].beam((4.2, 0, 10.2), (5.0, 0, 13.2), 2.6, 0.9, "accent" if tips else "body-")
    elif not HAS & {"shards", "coral"}:
        segs[1].beam((3.2, 0, 6.3), (4.2, 0, 9.6), 3.6, 1.2, "body-")
    if "sail" in HAS:
        plates.append((segs[0], (-3.7, 0, 6.3), (-2.7, 0, 9.8), 2.6, (0.0,), 1.3))
        segs[0].beam((-3.1, 0, 8.7), (-2.5, 0, 10.9), 1.9, 0.9, "accent" if tips else "body-")
        plates.append((segs[2], (7.6, 0, 4.3), (8.8, 0, 8.6), 2.4, (0.0,), 1.5))
        segs[2].beam((8.4, 0, 7.3), (9.0, 0, 9.8), 1.7, 0.9, "accent" if tips else "body-")
    if "rays" in HAS:  # a thread of light off the tip of each plate of the sail
        segs[1].beam((4.87, 0, 12.7), (6.3, 0, 16.6), 0.5, 0.3, "sig")
        segs[0].beam((-2.6, 0, 10.5), (-1.7, 0, 13.4), 0.4, 0.3, "sig")
        segs[2].beam((8.9, 0, 9.4), (10.0, 0, 12.2), 0.4, 0.3, "sig")
    for part, a, b, wide, spars, short in plates:  # a spar stops short of the plate's coloured tip
        part.beam(a, b, wide, 1.2, "body-")
        if "spars" in HAS:
            for offset in spars:
                ridge(part, a, b, offset, 0.5, 1.6, "spar", short=short)
    if "shards" in HAS:  # crystal where the fin was: one big shard, two leaning off it, a small one behind
        shard(segs[1], (3.0, 0.0, 5.4), (4.8, 0.0, 15.6), 3.0, 1.9, deep="crystal-")
        shard(segs[1], (4.6, 0.9, 5.4), (7.4, 1.6, 11.6), 2.1, 1.4, deep="crystal-")
        shard(segs[1], (1.9, -0.9, 5.6), (1.3, -1.7, 10.8), 1.7, 1.1, deep="crystal-")
        shard(segs[2], (7.6, -0.4, 3.6), (9.4, -0.6, 7.8), 1.4, 0.9, deep="crystal-")
        # a cluster through each shoulder, and one under the belly
        for s in (1, -1):
            shard(segs[0], (-3.9, s * 4.4, 3.0), (-5.6, s * 8.8, 7.0), 1.6, 1.1, deep="crystal-")
            shard(segs[0], (-3.0, s * 4.6, 3.6), (-2.4, s * 7.4, 7.6), 1.1, 0.7)
        shard(segs[1], (2.2, 0.6, -5.2), (1.4, 1.2, -9.4), 1.3, 0.9, deep="crystal-")
        shard(segs[0], (-2.6, -0.7, -5.2), (-3.6, -1.3, -8.6), 1.1, 0.8, deep="crystal-")
        for s in (1, -1):  # a small pair on the tail stock
            shard(segs[3], (10.6, s * 2.0, 1.2), (12.4, s * 4.8, 3.6), 0.9, 0.6)
        # and five that float free above the tail
        drift = m.part("Drift", (11.5, 0, 9), "S3")
        shard(drift, (10.2, 0.6, 8.4), (11.2, 0.9, 12.2), 1.4, 1.0, deep="crystal-")
        shard(drift, (12.8, -0.8, 6.6), (14.0, -1.1, 9.6), 1.1, 0.7)
        shard(drift, (14.8, 0.3, 9.8), (16.2, 0.4, 12.4), 0.9, 0.6)
        shard(drift, (12.0, 1.4, 12.6), (12.6, 1.8, 14.8), 0.8, 0.6)
        shard(drift, (17.0, -0.5, 6.4), (18.4, -0.8, 8.2), 0.7, 0.5)
    if "coral" in HAS:  # coral where the fin was: a big tree (a trunk, three branches whose ends glow a little, a spur each side),
        # a smaller one behind the head, a small one at the tail
        segs[1].beam((2.6, 0, 5.4), (3.2, 0, 11.4), 3.0, 2.3, "coral")
        segs[1].beam((3.2, 0.2, 10.2), (6.2, 0.8, 16.6), 2.0, 1.6, "coral")
        segs[1].beam((5.645, 0.689, 15.416), (7.0, 0.95, 18.4), 1.4, 1.0, "lume")
        segs[1].beam((3.1, -0.2, 10.0), (0.2, -1.0, 14.8), 1.7, 1.2, "coral")
        segs[1].beam((0.751, -0.848, 13.888), (-0.6, -1.2, 16.4), 1.1, 0.6, "lume")
        segs[1].beam((3.15, 0.0, 10.6), (3.7, 0.0, 14.4), 1.2, 0.8, "coral")
        segs[1].beam((3.0, 0.6, 9.0), (3.9, 5.0, 12.2), 1.4, 0.9, "coral", flat="z")
        segs[1].beam((3.0, -0.6, 8.2), (2.4, -4.0, 10.6), 1.2, 0.7, "coral", flat="z")
        segs[0].beam((-3.4, 0, 5.4), (-3.0, 0, 9.4), 2.0, 1.6, "coral")
        segs[0].beam((-3.0, 0.2, 8.6), (-1.6, 0.6, 12.2), 1.4, 1.1, "coral")
        segs[0].beam((-1.95, 0.5, 11.3), (-1.2, 0.7, 13.4), 1.0, 0.7, "lume")
        segs[0].beam((-3.1, -0.2, 8.4), (-4.9, -0.8, 11.4), 1.2, 0.9, "coral")
        segs[3].beam((10.8, 0, 1.6), (11.3, 0, 5.4), 1.2, 1.0, "coral")
        segs[3].beam((11.15, 0, 4.6), (11.9, 0, 6.6), 0.8, 0.6, "lume")
    if "reef" in HAS:  # a table coral behind the tree: two plates on stems; barnacles along the back; a strap of iron
        stem = (-0.5, 0.5, 4.6, 6.7)
        segs[2].block(7.9, stem, 8.8, stem, "coral-")
        plate = (-2.0, 2.0, 6.5, 7.0)
        segs[2].block(7.1, plate, 9.9, plate, "crust")
        stem = (-0.4, 0.4, 6.9, 7.8)
        segs[2].block(8.0, stem, 8.7, stem, "coral-")
        plate = (-1.4, 1.4, 7.6, 8.0)
        segs[2].block(7.5, plate, 9.4, plate, "crust+")
        for x0, x1, ya, yb in ((-0.9, 0.2, 0.9, 2.1), (0.1, 1.0, -2.0, -0.9)):
            knob = (ya, yb, 6.9, 7.7)
            segs[0].block(x0, knob, x1, knob, "crust+")
    if "anemones" in HAS:  # anemones on its shoulders, behind the rider: a stalk and a crown that glows a little
        for part, x, tall, big in ((segs[1], 1.4, 1.5, 0.3), (segs[1], 3.5, 0.8, 0.0), (segs[2], 6.05, 1.1, 0.15)):
            stalk = (3.0, 3.9, 5.9, 5.9 + tall)
            part.block(x + 0.15, stalk, x + 0.75, stalk, "coral-", mirror=True)
            crown = (2.75 - big, 4.15 + big, 5.7 + tall, 6.3 + tall + big)
            part.block(x - 0.15 - big, crown, x + 1.05 + big, crown, "lume", mirror=True)
    if "anchor" in HAS:  # an old chain round it, and a ship's anchor still hanging from the chain on its left side
        stripe(segs[1], 4.6, 5.2, 5, -6, 7, 1.8, "iron")
        segs[1].beam((4.9, -4.6, 2.0), (6.0, -8.4, -5.2), 0.9, 0.9, "iron")
        shard(segs[1], (5.9, -8.05, -4.55), (3.4, -8.9, -6.8), 0.7, 0.6, "iron", "iron+", part=0.6)
        shard(segs[1], (5.9, -8.05, -4.55), (8.6, -8.7, -6.4), 0.7, 0.6, "iron", "iron+", part=0.6)
    # the fin underneath, and the small belly fins
    under_a, under_b = (4.2, 0, -5.4), (5.2, 0, -8.4)
    segs[1].beam(under_a, under_b, 2.8, 1.2, "body-")
    if "spars" in HAS:
        ridge(segs[1], under_a, under_b, 0.0, 0.5, 1.6, "spar")
    segs[0].beam((-3.0, 2.0, -5.3), (-1.6, 2.4, -8.0), 1.6, 0.8, "body-", mirror=True)
    if "fintips" in HAS:
        segs[1].beam((4.87, 0, -7.4), (5.5, 0, -9.6), 2.0, 0.9, "accent")
        segs[0].beam((-2.05, 2.27, -7.13), (-1.3, 2.49, -8.8), 1.2, 0.5, "accent", mirror=True)
    if "weed" in HAS:  # weed hanging from the belly
        segs[0].beam((-2.4, 1.2, -5.2), (-0.6, 1.6, -10.4), 0.7, 0.5, "weed")
        segs[1].beam((2.6, -1.0, -5.2), (4.8, -1.4, -11.6), 0.8, 0.5, "weed")
        segs[1].beam((4.4, 0.8, -5.2), (6.0, 1.1, -9.4), 0.6, 0.4, "weed-")
        segs[0].beam((-4.2, -1.3, -5.2), (-2.8, -1.7, -9.0), 0.6, 0.4, "weed-")
        segs[2].beam((6.4, 0.9, -5.2), (8.2, 1.2, -8.8), 0.6, 0.4, "weed")
    # the side fins: a paddle each, on their own joints from Epic. A sickle of two boxes with a spar for the hunters, with
    # bone claws on the Legendary and a thread of light on the lantern; a mantle with gold hems on the king; blades of
    # crystal on the shard
    for sign, name in ((1, "FinR"), (-1, "FinL")):
        fin = m.part(name, (-1.2, sign * 5.0, -1.2), "S1") if "fins" in HAS else segs[0]
        if "mantle" in HAS:  # a cape: two broad panels hanging back and down along the flank, each with a gold hem along its
            # lower edge, and a gold end
            a, b = (-1.9, sign * 4.9, 0.4), (4.4, sign * 7.4, -2.4)
            fin.beam(a, b, 5.6, 0.9, "body-")
            ridge(fin, a, b, low_edge(a, b, 2.65), 0.6, 1.3, "accent", lead=0.9)
            ridge(fin, a, b, -low_edge(a, b, 2.65), 0.6, 1.3, "accent", lead=0.9)
            a, b = (2.8, sign * 6.765, -1.689), (8.6, sign * 8.6, -4.8)
            fin.beam(a, b, 4.4, 0.6, "body-")
            ridge(fin, a, b, low_edge(a, b, 2.05), 0.6, 0.75, "accent")
            ridge(fin, a, b, -low_edge(a, b, 2.05), 0.6, 0.75, "accent")
            fin.beam((7.4, sign * 8.22, -4.157), (10.4, sign * 9.0, -5.9), 3.0, 0.3, "accent")
        elif "blades" in HAS:
            shard(fin, (-1.0, sign * 4.6, -1.2), (4.6, sign * 10.8, -3.0), 2.4, 1.0, deep="crystal-")
            shard(fin, (0.0, sign * 4.8, -1.6), (2.4, sign * 8.4, -5.4), 1.5, 0.8, deep="crystal-")
        elif "sickle" in HAS:
            a, b = (-1.2, sign * 5.0, -1.2), (2.2, sign * 8.0, -2.4)
            fin.beam(a, b, 3.0, 1.0, "body-")
            fin.beam((1.4, sign * 7.3, -2.1), (4.6, sign * 9.6, -3.4), 2.0, 0.7, "body-")
            if "spars" in HAS:
                ridge(fin, a, b, 0.0, 0.5, 1.4, "spar", lead=0.25)
            if "claws" in HAS:
                for tip in ((6.9, sign * 10.3, -4.5), (6.3, sign * 11.3, -3.5), (7.0, sign * 9.2, -5.3)):
                    shard(fin, (3.8, sign * 9.025, -3.075), tip, 0.7, 0.45, "bone", "bone+", part=0.35)
            if "filaments" in HAS:
                fin.beam((3.896, sign * 9.094, -3.114), (8.6, sign * 11.5, -5.8), 0.5, 0.25, "sig")
        else:
            fin.beam((-1.2, sign * 5.0, -1.2), (1.8, sign * 7.4, -2.2), 2.8, 0.9, "body-")

    # the tail, on its own joint: a stock that starts inside the body, then two lobes (coloured tips from Rare), or shards
    tail = m.part("Tail", (12, 0, 0), "S4")
    tail.beam((11.6, 0, 0.5), (15.2, 0, 0.5), 4.5, 2.0, "body")
    if "shards" in HAS:
        shard(tail, (13.6, 0, 1.2), (20.8, 0, 8.8), 3.0, 1.4, deep="crystal-")
        shard(tail, (13.6, 0, -0.2), (20.0, 0, -6.8), 2.6, 1.1, deep="crystal-")
        shard(tail, (14.4, 0, 0.5), (19.2, 0, 0.9), 1.6, 0.7)
    else:
        lobes = (((13.3, 0, 1.1), (17.3, 0, 5.1), 1.2), ((13.3, 0, -0.1), (17.3, 0, -4.1), 0.9))
        for a, b, thick in lobes:
            tail.beam(a, b, 4.0, thick, "body-")
            if "tailspars" in HAS:
                ridge(tail, a, b, 0.0, 0.5, thick + 0.4, "spar")
    if "tailtips" in HAS:
        tail.beam((16.4, 0, 4.2), (19.4, 0, 7.6), 3.0, 0.9, "accent")
        tail.beam((16.4, 0, -3.2), (19.4, 0, -6.6), 3.0, 0.6, "accent")
    if "weed" in HAS:
        tail.beam((15.6, 0, -2.6), (17.4, 0, -8.2), 0.7, 0.5, "weed")
    if "train" in HAS:  # a king's train: a long pennant from each tip of the tail, blue with a gold end
        tail.beam((18.6, 0, 6.7), (24.2, 0, 9.4), 2.0, 0.6, "body-")
        tail.beam((23.4, 0, 9.01), (25.6, 0, 10.1), 1.4, 0.3, "accent")
        tail.beam((18.6, 0, -5.7), (23.8, 0, -8.8), 2.0, 0.3, "body-")
        tail.beam((23.0, 0, -8.32), (25.0, 0, -9.5), 1.4, 0.15, "accent")
    if "streamers" in HAS:  # the line of light runs on past the tail: a long streamer from each tip, in two lengths, on
        # joints of their own
        upper = m.part("StreamU", (18.8, 0, 6.9), "Tail")
        upper.beam((18.8, 0, 6.9), (25.6, 0, 10.6), 1.4, 0.6, "sig")
        far = m.part("StreamU2", (25.0, 0, 10.3), "StreamU")
        far.beam((24.8, 0, 10.17), (30.6, 0, 12.4), 0.9, 0.3, "sig")
        lower = m.part("StreamL", (18.8, 0, -5.9), "Tail")
        lower.beam((18.8, 0, -5.9), (25.4, 0, -9.4), 1.4, 0.3, "sig")
        far = m.part("StreamL2", (24.9, 0, -9.1), "StreamL")
        far.beam((24.7, 0, -9.03), (29.6, 0, -11.0), 0.9, 0.15, "sig")
