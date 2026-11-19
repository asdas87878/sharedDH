"""DRAFT (m1, 2026-11-19): the seahorse trainer at its 12 upgrade levels, for Hugo's pick. Not in the game.
One model, the game's Seahorse (art/creatures/Seahorse/voxel.py) on its toy stand (a pad, a base, a coil spring and a
plate, as tools/map/hub_kit.py builds it), dressed by TIER = 1 to 12 with tools/blender/voxel_kit.py.
build_tiers.py builds all twelve and lays out docs/attachments/seahorse-tiers-draft-1.png.

The ladder follows docs/style/05-rarity-look.md: every level adds something, and the steps are spent in order:
  1-2   colour only (the toy, then painted)               7-8   a glowing eye, a crown
  3-4   a saddle and bridle, then bigger fins              9     gold (yellow gold, violet light)
  5-6   armour plates, then a spiked mane                  10    dark body, glowing ribbon, wings, halo eye
                                                           11    two glow colours, a floating crown, big wings
                                                           12    the rainbow, dithered, white light
The stand climbs with it: iron coil, chrome, a stepped base, corner posts, gold caps, glowing seams, crystals, shards."""
import math

TIER = 1
# GAME = True (build_tiers.py --export): the game's mesh. The draft's coil and the plate on it are left out (Hugo,
# 2026-11-19: no plate, seahorse, spring, ground): the game draws its own coil (RideStyles.coil, bent as the toy
# rocks) from the stand's top straight into the body's underside, a little ahead of the tail's curl (SPRING_AT)
GAME = False
SPRING_AT = (-1, 0, -3)  # (cubes) where the game's coil meets the body: its underside, clear of the tail's curl

NAMES = {1: "Toy", 2: "Painted", 3: "Saddled", 4: "Racer", 5: "Iron", 6: "Spiked", 7: "Knight", 8: "Royal",
         9: "Golden", 10: "Abyssal", 11: "Starfire", 12: "Prismatic"}
NAME, ZONE, RARITY = "Seahorse", "TRAINER", f"LEVEL {TIER}: {NAMES[TIER].upper()}"
if GAME:
    NAME = f"SeahorseTrainer{TIER}"  # the export's file names
U = 0.4
FRAME, ORTHO = 3.0, 40.0

# ---------------------------------------------------------------- the look of each level
# body, belly, ring (the armour rings), fin, finTip, eye ring, saddle, blanket, armour; then the stand's
LOOKS = {
    1: dict(body="#F07A3E", belly="#FBDDA6", ring="#C9502A", fin="#FFF0CC", tip="#FFF0CC"),
    2: dict(body="#FF7F3A", belly="#FFE2A8", ring="#1FA7A4", fin="#FFF0CC", tip="#28C2BE"),
    3: dict(body="#2EB9B0", belly="#FFE9B8", ring="#F28A2E", fin="#FFF4D6", tip="#F28A2E", saddle="#8A4B2A",
            blanket="#E0403A"),
    4: dict(body="#1E9FD6", belly="#FFF1C4", ring="#FFC93C", fin="#E9FBFF", tip="#FFC93C", saddle="#7A3F22",
            blanket="#FFC93C"),
    5: dict(body="#3F78B8", belly="#E8EEF3", ring="#C9D3DC", fin="#DDE8F0", tip="#9FB0C0", saddle="#5A3420",
            blanket="#2B4E7E", armour="#C9D3DC"),
    6: dict(body="#2F5E9A", belly="#DCE6EE", ring="#D6DEE6", fin="#CFE2F0", tip="#FF5A3C", saddle="#3E2B22",
            blanket="#FF5A3C", armour="#D6DEE6", spike="#E9EEF3"),
    7: dict(body="#24406E", belly="#CFDCE8", ring="#DCE3EA", fin="#BFE6F2", tip="#3FE0D8", saddle="#2A2F3A",
            blanket="#1C8C88", armour="#DCE3EA", spike="#EEF2F6", eye="#3FF0E6"),
    8: dict(body="#5B2E91", belly="#F1E4FF", ring="#FFCF2E", fin="#E7D4FF", tip="#FFCF2E", saddle="#B0182E",
            blanket="#FFCF2E", armour="#FFCF2E", spike="#FFE58A", eye="#FF4FD8", crown="#FFCF2E", gem="#FF3B6B"),
    9: dict(body="#E9B530", belly="#FFE89A", ring="#FFD23A", fin="#FFE680", tip="#FFF1A8", saddle="#C98F10",
            blanket="#FFD23A", armour="#FFE066", spike="#FFF0A0", halo="#B25CFF", crown="#FFDA3A", gem="#B25CFF",
            ribbon="#B25CFF"),
    10: dict(body="#14233F", belly="#2A4A6E", ring="#4A6E96", fin="#1B3558", tip="#2FE6FF", saddle="#0E1626",
             blanket="#2FE6FF", armour="#3A5A80", spike="#6FA6CC", halo="#2FE6FF", crown="#2FE6FF", gem="#2FE6FF",
             ribbon="#2FE6FF", wing="#1B3558"),
    11: dict(body="#1A0F2E", belly="#3A1F5C", ring="#FF6A2A", fin="#2A1748", tip="#FF8A2A", saddle="#120A20",
             blanket="#FF6A2A", armour="#4A2D72", spike="#FFB050", eye="#56E8FF", crown="#56E8FF", gem="#56E8FF",
             ribbon="#FF6A2A", wing="#2A1748"),
    12: dict(body="#E85A9A", belly="#FFE6F4", ring="#FFFFFF", fin="#FFD6F0", tip="#FFFFFF", saddle="#F5F0FF",
             blanket="#FFFFFF", armour="#FFFFFF", spike="#FFFFFF", halo="#FFFFFF", crown="#FFFFFF", gem="#FFFFFF",
             ribbon="#FFFFFF", wing="#B8E8FF"),
}
# the stand: pad, its rim, base, base trim, coil, plate, post, post cap
STANDS = {
    1: dict(pad="#E1463F", rim="#E1463F", base="#F6C431", trim="#F6C431", coil="#9AA2AE", plate="#F07A3E"),
    2: dict(pad="#E1463F", rim="#E1463F", base="#F6C431", trim="#FFFFFF", coil="#B9C2CF", plate="#1FA7A4"),
    3: dict(pad="#E1463F", rim="#A92E2A", base="#F6C431", trim="#FFFFFF", coil="#C4CCD8", plate="#F28A2E"),
    4: dict(pad="#3C8FE0", rim="#245EA8", base="#FFFFFF", trim="#FFC93C", coil="#D2DAE4", plate="#FFC93C"),
    5: dict(pad="#4A5664", rim="#2E3742", base="#8E9BA8", trim="#C9D3DC", coil="#E3E9EF", plate="#C9D3DC"),
    6: dict(pad="#3A4654", rim="#222A33", base="#7F8D9B", trim="#FF5A3C", coil="#E8EDF2", plate="#D6DEE6",
            post="#5E6B78"),
    7: dict(pad="#1F2A3C", rim="#121A26", base="#5A6A80", trim="#3FE0D8", coil="#E8EDF2", plate="#DCE3EA",
            post="#3E4C60", cap="#DCE3EA", coilGlow="#3FE0D8"),
    8: dict(pad="#B0182E", rim="#7A0F20", base="#F4EEF8", trim="#FFCF2E", coil="#FFCF2E", plate="#FFCF2E",
            post="#F4EEF8", cap="#FFCF2E", coilGlow="#FF4FD8"),
    9: dict(pad="#FFFFFF", rim="#E6E1F0", base="#FFD23A", trim="#FFE680", coil="#FFDA3A", plate="#FFD23A",
            post="#FFD23A", cap="#FFF1A8", coilGlow="#B25CFF"),
    10: dict(pad="#0A1222", rim="#2FE6FF", base="#17233A", trim="#2FE6FF", coil="#2A3B55", plate="#2A4A6E",
             post="#22324E", cap="#2FE6FF", coilGlow="#2FE6FF", crystal="#7FF4FF"),
    11: dict(pad="#0E0818", rim="#FF6A2A", base="#24153C", trim="#56E8FF", coil="#3A2560", plate="#3A1F5C",
             post="#2E1C4C", cap="#FF8A2A", coilGlow="#FF6A2A", crystal="#56E8FF", shard="#56E8FF"),
    12: dict(pad="#221A3A", rim="#FFFFFF", base="#2E2550", trim="#FFFFFF", coil="#3A3060", plate="#2E2550",
             post="#3A3060", cap="#FFFFFF", coilGlow="#FFFFFF", crystal="#FFFFFF", shard="#FFFFFF"),
}
L, S = LOOKS[TIER], STANDS[TIER]

PALETTE = {"body": L["body"], "belly": L["belly"], "ring": L["ring"], "fin": L["fin"], "tip": L["tip"],
           "cream": "#FFF0CC", "black": "#22262B"}
for key in ("saddle", "blanket", "armour", "spike", "eye", "halo", "crown", "gem", "ribbon", "wing"):
    if key in L:
        PALETTE[key] = L[key]
for key, value in S.items():
    PALETTE["s_" + key] = value

# what glows: from level 7 the eye; from 10 the ribbon, the rings, the halo; level 11 two colours
GLOW = {}
if "eye" in L and TIER in (7, 8, 11):
    GLOW["eye"] = 0.9
if TIER >= 9:
    GLOW.update({"halo": 0.8} if "halo" in L else {})
if TIER >= 10:
    GLOW.update({"ribbon": 1.0, "tip": 0.8, "gem": 1.0, "crown": 0.9})
    if TIER >= 11:  # Mythic: the rings glow too
        GLOW["ring"] = 0.7
if TIER == 9:
    GLOW.update({"gem": 0.8, "ribbon": 0.7})
if TIER == 8:
    GLOW["gem"] = 0.7
if "coilGlow" in S:
    GLOW["s_coilGlow"] = 0.9
if TIER >= 10:
    GLOW.update({"s_trim": 0.9, "s_cap": 0.9, "s_crystal": 1.0})
    if TIER >= 11:
        GLOW["s_shard"] = 1.0
    GLOW["s_rim"] = 0.8

LIGHTS = []
if TIER >= 7:
    LIGHTS.append(("Stand", (4.5, 0, -18), S.get("coilGlow", "#FFFFFF"), 30 + 10 * (TIER - 7), 6))
if TIER >= 10:
    LIGHTS.append(("Head", (-6.8, 3.6, 17.4), L.get("halo", L.get("eye", "#FFFFFF")), 6, 2))
    LIGHTS.append(("Body", (1, 6, 3), L["ribbon"], 25, 5))

SEAT = (1, 9 if TIER >= 3 else 8, 4.6)
STAND_COLOURS = [n for n in PALETTE if n.startswith("s_")]
KEEP = ["black", "cream"] + (STAND_COLOURS if TIER == 12 else ["s_pad", "s_rim"])
if TIER == 9:
    VARIANT = "gold"
    ACCENT = "#B25CFF"
if TIER == 12:
    VARIANT = "rainbow"
    ACCENT = "#FFFFFF"
    RAINBOW = {"steps": 14, "pixels": 9, "pastel": 0.12, "dither": 1, "wobble": 0}
TEXTURES = [{"tile": "stud", "on": "all", "colours": ["belly"]},
            {"tile": "stud", "on": "top", "colours": ["s_pad", "s_base", "s_plate"]}]
FLOATING = [p for p, t in (("Crown", 11), ("Orbit", 11)) if TIER >= t]

# the trunk: (from, to, cubes out, bottom, top, the pale belly comes up to here, where its ring is)
SLICES = ((-9, -6, 3, 0, 8, 6, -7.8), (-6, -2, 4, -2, 10, 4, -4.3), (-2, 4, 4, -3, 8, 1, 3.0), (4, 8, 3, -2, 7, 0, 6.6),
          (8, 11, 2, 0, 5, 0, 9.2))
TAIL = (((9.0, 2.5), (13.0, -1.5), 4.2), ((11.9, -0.3), (12.5, -6.4), 3.6), ((12.4, -5.4), (9.8, -10.4), 3.0),
        ((10.6, -9.7), (5.4, -11.5), 2.4), ((6.5, -11.2), (3.6, -8.4), 1.8), ((4.2, -9.0), (5.6, -6.9), 1.2))
_rest = {}


def pose(parts, phase):
    """the trainer rocks on its spring: the seahorse bobs and rocks, the head nods, the fins flutter"""
    body = parts["Body"]
    if "z" not in _rest:
        _rest["z"] = body.location.z
    body.location.z = _rest["z"] + 0.9 * U * math.sin(phase)
    body.rotation_euler.y = math.radians(2.5) * math.sin(phase - 1.2)
    parts["Head"].rotation_euler.y = math.radians(4) * math.sin(phase - 1.2 + math.pi)
    parts["Fin"].rotation_euler.x = math.radians(16) * math.sin(3 * phase)
    if "Wings" in parts:
        parts["Wings"].rotation_euler.x = math.radians(6) * math.sin(2 * phase)
    for k, amp in enumerate((2, 3, 4, 6, 8, 10)):
        parts[f"T{k + 1}"].rotation_euler.y = math.radians(amp) * math.sin(phase - 0.6 * (k + 1))


def steps(n):
    return ([(2, 1)], [(2, 1), (1, 1)]) if n >= 4 else ([(1, 1)], [(1, 1)])


def collar(p, a, b, size, colour="ring", back=0.5, past=0.15, grow=0.5):
    d = [q - r for q, r in zip(b, a)]
    length = math.sqrt(sum(v * v for v in d))
    d = [v / length for v in d]
    p.beam(tuple(q - back * v for q, v in zip(b, d)), tuple(q + past * v for q, v in zip(b, d)), size + grow, size + grow, colour)


def spike_at(p, base_centre, apex, size, colour):
    """a pyramid whose square base (size across, facing x) is buried at base_centre"""
    x, y, z = base_centre
    h = size / 2
    p.spike([(x, y - h, z - h), (x, y + h, z - h), (x, y + h, z + h), (x, y - h, z + h)], apex, colour)


def neck_x(z):
    """the middle of the neck at height z (the two neck blocks)"""
    if z <= 11.5:
        return -2.6 + (z - 6.5) / 5.5 * -1.2
    return -3.6 + (z - 11.0) / 5.2 * -2.0


def build(m):
    body = m.part("Body", (0, 0, 3), "Stand")
    for x0, x1, n, bot, top, belly, ring in SLICES:
        ts, bs = steps(n)
        body.hull(x0, x1, n, bot, top, "body", ts, bs)
        body.paint_sym(x0, x1, n, top - 1, top, "body+")
        if belly > bot:
            body.paint_sym(x0, x1, n, bot, belly, "belly")
            body.paint_sym(x0, x1, n, bot, bot + 1, "belly-")
        if TIER >= 10:  # the glowing ribbon along the flank, on the line where the belly meets the back
            body.paint_pair(x0, x1, n, n + 1, belly, belly + 1, "ribbon")
        if TIER >= 5:  # armour: the top of each slice is a plate
            body.paint_sym(x0, x1, n, top - 1, top, "armour")
        body.band(ring, ring + 0.6, n, bot, top, "ring", ts, bs)
    body.dent(0, 2, 4, 3, 6, "body-")  # the rider's leg slots
    if TIER >= 3:  # a saddle on a blanket
        body.paint_sym(-2, 5, 4, 6, 8, "blanket")
        body.box(-1, 4, -2, 3, 8, 9, "saddle")
        body.box(3, 4, -2, 3, 9, 10, "saddle")
        body.box(-1, 0, -1, 2, 9, 10, "saddle-")
        if TIER >= 8:  # a gold rim on the saddle's back
            body.box(3, 4, -1, 2, 10, 11, "crown" if "crown" in L else "saddle")
    if TIER >= 5:  # a chest plate, its back buried in the chest
        body.block(-9.35, (-2.4, 2.4, 1.0, 6.4), -8.5, (-2.4, 2.4, 1.0, 6.4), "armour")
    # the neck
    low = ((-2.6, 0, 6.5), (-3.8, 0, 12.0))
    body.beam(low[0], low[1], 4.6, 4.6, "body")
    collar(body, low[0], low[1], 4.6, grow=0.6)
    body.beam((-3.6, 0, 11.0), (-5.6, 0, 16.2), 4.0, 4.0, "body")
    if TIER >= 6:  # a mane of spikes down the back of the neck
        for z, size in ((8.6, 1.4), (13.2, 1.3), (15.4, 1.1)):
            cx = neck_x(z) + 1.2
            spike_at(body, (cx, 0, z), (cx + 2.0, 0, z + 2.2), size, "spike")

    head = m.part("Head", (-5, 0, 15), "Body")
    head.hull(-9, -3, 2, 14, 20, "body", [(1, 1)], [(1, 1)])
    head.paint_sym(-9, -3, 2, 19, 20, "armour" if TIER >= 5 else "body+")
    head.beam((-7.5, 0, 16.6), (-11.5, 0, 15.3), 3.4, 3.6, "body", flat="z")
    tube = ((-10.8, 0, 15.6), (-16.0, 0, 13.9))
    head.beam(tube[0], tube[1], 2.0, 2.0, "body", flat="z")
    collar(head, tube[0], tube[1], 2.0, back=0.7, past=0.25, grow=0.6)
    if TIER >= 3:  # a bridle round the muzzle
        head.paint_sym(-9, -8, 2, 14, 20, "saddle")  # the strap, on the face just behind the muzzle
    if TIER >= 7:  # a visor plate on the muzzle
        head.beam((-7.6, 0, 18.55), (-10.6, 0, 17.575), 2.8, 0.7, "armour", flat="z")
    # the eye
    ring = (2.3, 2.8, 16.2, 18.8)
    head.block(-8.0, ring, -5.4, ring, "cream", mirror=True)
    if "halo" in L:  # the halo eye (Legendary): a thin soft glow between the dark pupil and the cream
        halo = (2.6, 2.95, 16.45, 18.35)
        head.block(-7.75, halo, -5.85, halo, "halo", mirror=True)
    pupil = (2.7, 3.2, 16.7, 18.1)
    head.block(-7.5, pupil, -6.1, pupil, "eye" if "eye" in L else "black", mirror=True)
    if TIER >= 4:  # cheek fins behind the eye
        head.beam((-4.2, 2.0, 16.4), (-1.8, 4.0, 18.6), 1.8, 0.45, "fin", mirror=True)
        head.beam((-2.4, 3.4, 18.0), (-1.2, 4.4, 19.3), 1.0, 0.35, "tip", mirror=True)
    if TIER >= 8 and TIER not in (11, 12):  # a crown (a band and four points)
        head.box(-8, -3, -1, 2, 20, 21, "crown")
        for x in (-7.5, -3.5):
            for y in (-1.0, 1.0):
                head.spike([(x - 0.5, y - 0.5, 20.9), (x + 0.5, y - 0.5, 20.9), (x + 0.5, y + 0.5, 20.9),
                            (x - 0.5, y + 0.5, 20.9)], (x, y * 1.3, 22.6), "crown")
        head.block(-5.9, (-1.65, -1.35, 20.2, 20.8), -4.9, (-1.65, -1.35, 20.2, 20.8), "gem", mirror=True)
    elif TIER < 8:  # the crest, as on the game's seahorse
        head.beam((-5.0, 0, 19.5), (-4.4, 0, 21.2), 2.6, 2.0, "body")
        head.beam((-4.6, 0, 20.7), (-3.9, 0, 22.3), 1.6, 1.2, "tip" if TIER >= 2 else "ring")
        if TIER == 7:  # a knight's plume
            head.beam((-4.1, 0, 21.8), (-1.2, 0, 23.4), 1.4, 0.8, "tip")
    if TIER >= 6:  # spikes down the back of the head
        for z, size in ((17.0, 1.2), (19.0, 1.0)):
            spike_at(head, (-3.6, 0, z), (-1.6, 0, z + 1.4), size, "spike")
    if TIER >= 11:  # the floating crown: shards round the head
        crown = m.part("Crown", (-5.5, 0, 24), "Head")
        for k in range(7):
            a = 2 * math.pi * k / 7
            cx, cy = -5.5 + 2.8 * math.cos(a), 2.8 * math.sin(a)
            tall = 2.6 if k % 2 == 0 else 1.8
            crown.beam((cx, cy, 23.2), (cx + 0.6 * math.cos(a), cy + 0.6 * math.sin(a), 23.2 + tall), 0.9, 0.9, "crown")

    # the fan fin behind the seat
    fin = m.part("Fin", (5.8, 0, 7), "Body")
    # every ray and every tip is a different thickness, 0.3 cubes apart, so no two faces share a plane
    rays = ((8.2, 11.8, 2.2, 1.5), (5.2, 11.0, 1.9, 0.9), (10.4, 9.6, 1.9, 0.3))
    if TIER >= 4:
        rays = ((8.8, 13.4, 2.4, 1.8), (5.6, 12.4, 2.0, 1.2), (11.2, 11.2, 2.0, 0.6), (12.0, 8.4, 1.6, 0.3))
    for x, z, w, t in rays:
        fin.beam((5.8, 0, 6.0), (x, 0, z), w, t, "fin")
    if TIER >= 2:  # coloured tips: a short block on the end of each ray, its root inside the ray
        for x, z, w, t in rays[:3]:
            dx, dz = x - 5.8, z - 6.0
            length = math.hypot(dx, dz)
            ux, uz = dx / length, dz / length
            fin.beam((x - 1.2 * ux, 0, z - 1.2 * uz), (x + 0.3 * ux, 0, z + 0.3 * uz), w + 0.3, t + 0.3, "tip")

    if TIER >= 10:  # wings: wide fins either side of the chest
        wings = m.part("Wings", (0, 3.5, 5), "Body")
        big = TIER >= 11
        a, b = (-0.5, 1.5, 4.5), (3.0, 10.0 if big else 8.5, 14.0 if big else 11.5)
        on = lambda t: tuple(p + t * (q - p) for p, q in zip(a, b))  # noqa: E731
        wings.beam(a, on(0.8), 5.2 if big else 4.4, 0.9, "wing", flat="z", mirror=True)
        wings.beam(on(0.7), b, 4.6 if big else 3.8, 0.5, "tip", flat="z", mirror=True)  # the coloured end, its root inside the wing
        wings.beam((0.5, 1.5, 3.5), (5.5, 9.0 if big else 7.5, 8.5 if big else 7.0), 3.6, 0.4, "wing", flat="z", mirror=True)

    # the tail
    for k, ((ax, az), (bx, bz), size) in enumerate(TAIL):
        part = m.part(f"T{k + 1}", (ax, 0, az), f"T{k}" if k else "Body")
        part.beam((ax, 0, az), (bx, 0, bz), size, size, "body")
        if k < len(TAIL) - 2:
            collar(part, (ax, 0, az), (bx, 0, bz), size)
        if k == len(TAIL) - 1 and TIER >= 8:  # a gem at the curl's tip
            part.beam((5.3, 0, -7.4), (6.0, 0, -6.2), 1.6, 1.6, "gem")

    # ---------------------------------------------------------------- the stand
    st = m.part("Stand", (4.5, 0, -20))
    st.sym(-7, 16, 11, -27, -26, "s_rim")  # the pad
    if TIER >= 3:
        st.paint_sym(-5, 14, 9, -27, -26, "s_pad")
    else:
        st.paint_sym(-7, 16, 11, -27, -26, "s_pad")
    st.hull(-3, 12, 7, -26, -23, "s_base", [(1, 1)])  # the base
    if TIER >= 2:
        st.paint_sym(-3, 12, 7, -25, -24, "s_trim")
    top = -23
    if TIER >= 4:  # a second step
        st.hull(-1, 10, 5, -23, -22, "s_base", [(1, 1)])
        top = -22
    if not GAME:
        st.sym(3, 6, 1, top, -14, "s_coil")  # the spring: a core and rings
        for i, z in enumerate(range(top + 1, -14, 2)):
            glow = "coilGlow" in S and i % 2 == 1
            st.hull(1, 8, 3, z, z + 1, "s_coilGlow" if glow else "s_coil", [(1, 0)])
    if not GAME:  # the plate the seahorse stands on (the game has none: Hugo, 2026-11-19, the spring goes straight
        st.hull(-5, 14, 5, -14, -12, "s_plate", [(1, 1)])  # into the body's underside, as a playground spring rider)
    if TIER >= 6:  # corner posts
        for x0 in (-3, 10):
            st.pair(x0, x0 + 2, 5, 7, -23, -19, "s_post")
            if "cap" in S:
                st.pair(x0, x0 + 2, 5, 7, -19, -18, "s_cap")
    if TIER >= 10:  # crystals standing on the posts
        for x0 in (-3, 10):
            for y in (5.5, -5.5):
                lean = 1 if x0 > 0 else -1
                st.beam((x0 + 1, y, -18.6), (x0 + 1 + 0.8 * lean, y * 1.12, -15.0), 1.3, 1.3, "s_crystal")
    if TIER >= 11:  # shards that orbit the spring
        orbit = m.part("Orbit", (4.5, 0, -18), "Stand")
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.3
            cx, cy = 4.5 + 6.2 * math.cos(a), 6.2 * math.sin(a)
            z = -19.5 + 1.5 * (k % 2)
            orbit.beam((cx, cy, z), (cx + 0.3, cy, z + 1.8), 0.9, 0.9, "s_shard")
