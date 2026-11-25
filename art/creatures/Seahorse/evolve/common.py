"""What the twelve evolved seahorse rockers share (docs/style/13-seahorse-evolution.md): the frame, the size table, each
level's colours (Hugo's palettes of 2026-11-19, kept), and the stand with its draft coil. Each level is its own model,
T01 to T12/voxel.py beside this file, which starts:

    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    import common as c
    LEVEL = 7
    GAME = c.GAME  # on for the game's mesh (ROCKER_GAME=1, build_evolve.py): no draft coil, the game bends its own
    NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES = c.head(LEVEL)   # add your own colours to PALETTE with .update()
    globals().update(c.VARIANTS.get(LEVEL, {}))  # level 9 is gold, 12 the rainbow: VARIANT, ACCENT, RAINBOW
    GLOW, LIGHTS = {...}, [...]
    FLOATING = ["Coil"]  # the draft coil is for pictures: its pieces need no buried roots

The frame (cubes): the floor is z 0, the stand and its spring stand on x 0, y 0. The creature points to -X. The spring
meets the middle of the body's underside at (0, 0, belly). 1 cube is 0.34 studs in the game (U 0.4, shown at 0.85); a
rider is about 15 cubes tall.
"""
import math
import os

GAME = os.environ.get("ROCKER_GAME") == "1"
U, SHOWN = 0.4, 0.85
NAMES = {1: "Toy", 2: "Painted", 3: "Saddled", 4: "Racer", 5: "Iron", 6: "Spiked", 7: "Knight", 8: "Royal",
         9: "Golden", 10: "Abyssal", 11: "Starfire", 12: "Prismatic"}
# level: the pad's half width (today's seahorse, level 1, stands on 11.5, and no level's pad is smaller), the base's, the stand's top, the belly (where the spring meets the body), the spring's radius (to the
# middle of its wire) and wire, and the most triangles; then the size to aim at: length, width, the top of it
SIZES = {
    1: dict(pad=7, top=4, belly=19, ring=2.6, wire=1.2, tris=1600, size=(28, 15, 48)),
    2: dict(pad=12, base=7, top=4, belly=19, ring=2.8, wire=1.2, tris=1600, size=(36, 21, 55)),
    3: dict(pad=12, base=7, top=5, belly=20, ring=3.0, wire=1.3, tris=1800, size=(38, 21, 60)),
    4: dict(pad=12, base=7, top=5, belly=20, ring=3.0, wire=1.3, tris=2200, size=(70, 27, 50)),
    5: dict(pad=13, base=7, top=6, belly=22, ring=3.4, wire=1.5, tris=2200, size=(56, 31, 58)),
    6: dict(pad=13, base=7, top=6, belly=22, ring=3.6, wire=1.5, tris=2400, size=(70, 39, 66)),
    7: dict(pad=14, base=8, top=7, belly=24, ring=4.0, wire=1.7, tris=3000, size=(72, 41, 78)),
    8: dict(pad=15, base=9, top=8, belly=25, ring=4.4, wire=1.8, tris=3200, size=(74, 55, 81)),
    9: dict(pad=15, base=10, top=8, belly=26, ring=4.8, wire=2.0, tris=3600, size=(86, 69, 90)),
    10: dict(pad=16, base=11, top=9, belly=27, ring=5.2, wire=2.2, tris=3800, size=(100, 65, 84)),
    11: dict(pad=17, base=13, top=10, belly=28, ring=5.5, wire=2.4, tris=5400, size=(108, 87, 99)),
    12: dict(pad=18, base=15, top=12, belly=30, ring=6.6, wire=2.8, tris=6500, size=(132, 109, 114)),
}
LOOKS = {
    1: dict(body="#F07A3E", belly="#FBDDA6", ring="#C9502A", fin="#FFF0CC", tip="#FFF0CC"),
    2: dict(body="#FF7F3A", belly="#FFE2A8", ring="#1FA7A4", fin="#FFF0CC", tip="#28C2BE"),
    3: dict(body="#2EB9B0", belly="#FFE9B8", ring="#F28A2E", fin="#FFF4D6", tip="#F28A2E", saddle="#8A4B2A", blanket="#E0403A"),
    4: dict(body="#1E9FD6", belly="#FFF1C4", ring="#FFC93C", fin="#E9FBFF", tip="#FFC93C", saddle="#7A3F22", blanket="#FFC93C"),
    5: dict(body="#3F78B8", belly="#E8EEF3", ring="#C9D3DC", fin="#DDE8F0", tip="#9FB0C0", saddle="#5A3420", blanket="#2B4E7E",
            armour="#C9D3DC"),
    6: dict(body="#2F5E9A", belly="#DCE6EE", ring="#D6DEE6", fin="#CFE2F0", tip="#FF5A3C", saddle="#3E2B22", blanket="#FF5A3C",
            armour="#D6DEE6", spike="#E9EEF3"),
    7: dict(body="#24406E", belly="#CFDCE8", ring="#DCE3EA", fin="#BFE6F2", tip="#3FE0D8", saddle="#2A2F3A", blanket="#1C8C88",
            armour="#DCE3EA", spike="#EEF2F6", eye="#3FF0E6"),
    8: dict(body="#5B2E91", belly="#F1E4FF", ring="#FFCF2E", fin="#E7D4FF", tip="#FFCF2E", saddle="#B0182E", blanket="#FFCF2E",
            armour="#FFCF2E", spike="#FFE58A", eye="#FF4FD8", crown="#FFCF2E", gem="#FF3B6B"),
    9: dict(body="#E9B530", belly="#FFE89A", ring="#FFD23A", fin="#FFE680", tip="#FFF1A8", saddle="#C98F10", blanket="#FFD23A",
            armour="#FFE066", spike="#FFF0A0", halo="#B25CFF", crown="#FFDA3A", gem="#B25CFF", ribbon="#B25CFF"),
    10: dict(body="#14233F", belly="#2A4A6E", ring="#4A6E96", fin="#1B3558", tip="#2FE6FF", saddle="#0E1626", blanket="#2FE6FF",
             armour="#3A5A80", spike="#6FA6CC", halo="#2FE6FF", crown="#2FE6FF", gem="#2FE6FF", ribbon="#2FE6FF", wing="#1B3558"),
    11: dict(body="#1A0F2E", belly="#3A1F5C", ring="#FF6A2A", fin="#2A1748", tip="#FF8A2A", saddle="#120A20", blanket="#FF6A2A",
             armour="#4A2D72", spike="#FFB050", eye="#56E8FF", crown="#56E8FF", gem="#56E8FF", ribbon="#FF6A2A", wing="#2A1748"),
    12: dict(body="#E85A9A", belly="#FFE6F4", ring="#FFFFFF", fin="#FFD6F0", tip="#FFFFFF", saddle="#F5F0FF", blanket="#FFFFFF",
             armour="#FFFFFF", spike="#FFFFFF", halo="#FFFFFF", crown="#FFFFFF", gem="#FFFFFF", ribbon="#FFFFFF", wing="#B8E8FF",
             core="#1C1440"),
}
STANDS = {
    1: dict(pad="#E1463F", rim="#E1463F", base="#F6C431", trim="#F6C431", coil="#9AA2AE"),
    2: dict(pad="#E1463F", rim="#E1463F", base="#F6C431", trim="#FFFFFF", coil="#B9C2CF"),
    3: dict(pad="#E1463F", rim="#A92E2A", base="#F6C431", trim="#FFFFFF", coil="#C4CCD8"),
    4: dict(pad="#3C8FE0", rim="#245EA8", base="#FFFFFF", trim="#FFC93C", coil="#D2DAE4"),
    5: dict(pad="#4A5664", rim="#2E3742", base="#8E9BA8", trim="#C9D3DC", coil="#E3E9EF"),
    6: dict(pad="#3A4654", rim="#222A33", base="#7F8D9B", trim="#FF5A3C", coil="#E8EDF2", post="#5E6B78"),
    7: dict(pad="#1F2A3C", rim="#121A26", base="#5A6A80", trim="#3FE0D8", coil="#E8EDF2", post="#3E4C60", cap="#DCE3EA"),
    8: dict(pad="#B0182E", rim="#7A0F20", base="#F4EEF8", trim="#FFCF2E", coil="#FFCF2E", post="#F4EEF8", cap="#FFCF2E"),
    9: dict(pad="#FFFFFF", rim="#E6E1F0", base="#FFD23A", trim="#FFE680", coil="#FFDA3A", post="#FFD23A", cap="#FFF1A8"),
    10: dict(pad="#0A1222", rim="#17233A", base="#17233A", trim="#2FE6FF", coil="#2A3B55", post="#22324E", cap="#2A4A6E",
             crystal="#2FE6FF"),
    11: dict(pad="#0E0818", rim="#24153C", base="#24153C", trim="#FF6A2A", coil="#3A2560", post="#2E1C4C", cap="#4A2D72",
             crystal="#56E8FF"),
    12: dict(pad="#221A3A", rim="#2E2550", base="#2E2550", trim="#FFFFFF", coil="#8C82C8", post="#3A3060", cap="#F5F0FF",
             crystal="#B8E8FF"),
}


# On a variant every colour becomes gold or rainbow except KEEP's, and every GLOW colour becomes ACCENT. So: level 9's teeth
# are "ivory" (kept), its pearl, eyes and ribbon are GLOW colours (violet). Level 12's bones, belly and mouth depths are "core",
# its plates and horns "pearl" (both kept, plain, never Neon), its skin "body", "fin", "wing" (the rainbow); its few GLOW colours
# come out pale aqua, never white
VARIANTS = {9: dict(VARIANT="gold", ACCENT="#B25CFF"),
            12: dict(VARIANT="rainbow", ACCENT="#8FF2FF", RAINBOW={"steps": 14, "pixels": 9, "pastel": 0.1, "dither": 1, "wobble": 0})}


def head(level):
    """the sheet's words and the level's colours: NAME, ZONE, RARITY, U, PALETTE, KEEP, TEXTURES"""
    palette = {"cream": "#FFF0CC", "black": "#22262B", "ivory": "#FFF6E0"}
    palette.update(LOOKS[level])
    palette.update({"s_" + k: v for k, v in STANDS[level].items()})
    keep = ["black", "cream", "ivory"] + [k for k in palette if k.startswith("s_")]
    if level == 12:
        palette["pearl"] = "#F3EEFF"
        keep += ["core", "pearl", "saddle"]
    textures = [{"tile": "stud", "on": "top", "colours": ["s_pad", "s_base"]}]
    return f"SeahorseRocker{level}", "TRAINER", f"LEVEL {level}: {NAMES[level].upper()}", U, palette, keep, textures


def glow_of(level):
    """the stand's glow: a lit seam from level 7, the crystals from 10. Small on purpose: the old levels 10 to 12 bloomed
    until the creature was lost"""
    out = {}
    if level >= 10:
        out["s_crystal"] = 0.8
        out["s_trim"] = 0.5
    elif level >= 7:
        out["s_trim"] = 0.5
    return out


def stand(m, level, game):
    """the stand (part Stand, pivot on the floor under the spring) and, for pictures only, the draft coil (part Coil)"""
    s = SIZES[level]
    st = m.part("Stand", (0, 0, 0))
    p, top = s["pad"], s["top"]
    st.sym(-p, p + 1, p, 0, 1, "s_rim")  # the pad: one course
    inset = 1 if level >= 3 else 0
    st.paint_sym(-p + inset, p + 1 - inset, p - inset, 0, 1, "s_pad")
    q = s["base"]
    base_top = top if level < 4 else top - (1 if level < 10 else 2)
    st.hull(-q, q + 1, q, 1, base_top, "s_base", [(1, 1)])
    if level >= 2:
        z = 1 + (base_top - 1) // 2
        st.paint_sym(-q, q + 1, q, z, z + 1, "s_trim")
    if level >= 4:  # a second step
        r = q - 2
        st.hull(-r, r + 1, r, base_top, top, "s_base", [(1, 1)] if top - base_top >= 2 else [])
    if "post" in STANDS[level]:  # a post on each corner, its foot in the base
        w = 3 if level < 10 else 4
        tall = 3 + (level - 6) // 2 + (2 if level >= 10 else 0)
        for x0 in (-q - 1, q + 2 - w):
            st.pair(x0, x0 + w, q + 2 - w, q + 2, 1, 1 + tall, "s_post")
            if "cap" in STANDS[level]:
                st.pair(x0, x0 + w, q + 2 - w, q + 2, 1 + tall, 2 + tall, "s_cap")
            if "crystal" in STANDS[level]:  # a crystal leaning out of each post: rooted, nothing floats
                lean = -1 if x0 < 0 else 1
                cx, cy, cz = x0 + w / 2, q + 1.5 - w / 2, 1.4 + tall
                big = 1.6 + 0.25 * (level - 10)
                st.beam((cx, cy, cz), (cx + 1.6 * lean, cy + 1.6, cz + 4 + 1.5 * (level - 9)), big, big, "s_crystal", mirror=True)
    if not game:
        coil(m, level)


def coil(m, level):
    """the draft's coil, so a picture shows the rocker whole: a real coil of short beams from the stand's top into the belly
    (the game draws its own, bent as it rocks)"""
    s = SIZES[level]
    c = m.part("Coil", (0, 0, s["top"]), "Stand")
    turns, per = 4, 10
    n = turns * per
    z0, z1 = s["top"] - 0.1, s["belly"] - 0.1

    def at(k):
        a = 2 * math.pi * k / per
        return (s["ring"] * math.cos(a), s["ring"] * math.sin(a), z0 + (z1 - z0) * k / n)

    for k in range(n):
        a, b = at(k), at(k + 1)
        d = [(j - i) * 0.12 for i, j in zip(a, b)]
        # a little different in thickness one piece to the next, so no two faces share a plane
        w = s["wire"] - 0.13 * (k % 2) - 0.02 * (k // per)
        c.beam(tuple(i - v for i, v in zip(a, d)), tuple(i + v for i, v in zip(b, d)), w, w, "s_coil", flat="z")


# ---------------------------------------------------------------- what a seahorse is made of, whatever its size
def collar(p, a, b, size, colour="ring", back=0.5, past=0.15, grow=0.5):
    """an armour ring at the foot of a neck or tail block running a to b (x, y, z)"""
    length = math.dist(a, b)
    d = [(j - i) / length for i, j in zip(a, b)]
    p.beam(tuple(i - back * v for i, v in zip(b, d)), tuple(i + past * v for i, v in zip(b, d)), size + grow, size + grow, colour)


def spike_at(p, base, apex, size, colour, mirror=False, face="x"):
    """a pyramid whose square base (`size` across, facing x or z) is buried at `base`"""
    x, y, z = base
    h = size / 2
    if face == "x":
        corners = [(x, y - h, z - h), (x, y + h, z - h), (x, y + h, z + h), (x, y - h, z + h)]
    else:
        corners = [(x - h, y - h, z), (x + h, y - h, z), (x + h, y + h, z), (x - h, y + h, z)]
    p.spike(corners, apex, colour, mirror)


def chain(m, names, points, sizes, colour, parent, ring=None, grow=0.6):
    """a tail (or neck, or tentacle) of square blocks on joints: points (x, y, z), one more than names; a size to each block.
    Each block runs a little into the next. Returns the parts"""
    out = []
    for k, name in enumerate(names):
        a, b = points[k], points[k + 1]
        length = math.dist(a, b)
        d = [(j - i) / length for i, j in zip(a, b)]
        size = sizes[k]
        part = m.part(name, a, parent if k == 0 else names[k - 1])
        sink = size * 0.42
        part.beam(tuple(i - sink * v for i, v in zip(a, d)), tuple(i + sink * 0.5 * v for i, v in zip(b, d)), size, size, colour)
        if ring and k < len(names) - 1:
            collar(part, a, b, size, ring, back=size * 0.2, past=0.1, grow=grow)
        out.append(part)
    return out
