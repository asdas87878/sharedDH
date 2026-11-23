"""The breakable props, rebuilt (2026-11-18, the user picked "something close to B ... they get simplified" when broken;
docs/design/props-and-landmarks.md, 3b). Lands 1 and 2 first (Shallows, Coral Reef); the rest still borrow
tools/map/props.py's first-pass boxes.

Rules (from the reference, frame by frame):
- bricks about a third of a breaking fish (6 to 9 studs); a tier is several blocks, each a little turned and smaller
  going up; long things are rows of segments;
- three tones by height (dark foot, main, light tips) from palette slots, so one build takes any colourway;
- studs by material: coral, rock, shell studded; stems and trunks plain (`studs` on each brick);
- every brick carries its GROUP (a tier, a branch, a blade): when the prop breaks, the game swaps each group for one
  simple chunk (the game-code chat's PropService/PropController, on the user's word they'll do it there).
A brick is (name, centre, size, colour, axes, studs, group). Foot at y = 0, front +z, studs as everywhere.

usage: python tools/map/props2.py            writes art/map/props2/kit.json (shots for tools/blender/prop_drafts_view.py)
       DRAFTS=../props2/kit blender --background --python tools/blender/prop_drafts_view.py
       python tools/map/props2.py --sheet    docs/attachments/map-props2-kit.jpg"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop_drafts as d1  # noqa: E402
import prop_drafts2 as d2  # noqa: E402
import props  # noqa: E402

ROOT = d1.ROOT
OUT = os.path.join(ROOT, "art", "map", "props2")


def tone(pal, slot, k):
    return d1.tone(pal, slot, k)


# ---------------------------------------------------------------- the palettes: three colourways a land
# 2026-11-23, "a bit less random" (docs/design/colour.md): a land's stone is of its wall face's family (it was one
# blue-grey everywhere), one accent a land, and the Reef's pink 20 of lightness off its pink floor. Which colourway stands
# where is greybox.py's `tint_at`: a room has one it leads with
SAND_STONE = [(168, 132, 94), (190, 156, 116)]
ROSE_STONE = [(184, 143, 160), (203, 166, 180)]
SHELL = (255, 246, 232)
PALETTES = {
    0: [  # Shallows: warm corals on sand; caps the sand, pops white
        {"Main": [(214, 110, 60), (246, 146, 82), (255, 194, 126)], "Stone": SAND_STONE, "Cap": (242, 214, 128), "Pop": (255, 250, 236)},
        {"Main": [(214, 168, 40), (238, 186, 66), (255, 232, 140)], "Stone": SAND_STONE, "Cap": (242, 214, 128), "Pop": (255, 250, 236)},
        {"Main": [(206, 92, 120), (240, 128, 150), (255, 182, 196)], "Stone": SAND_STONE, "Cap": (242, 214, 128), "Pop": (255, 250, 236)},
    ],
    1: [  # Coral Reef: pink, teal and violet corals; caps seafoam, pops yellow
        {"Main": [(150, 40, 90), (196, 68, 124), (255, 172, 190)], "Stone": ROSE_STONE, "Cap": (130, 214, 190), "Pop": (255, 210, 122)},
        {"Main": [(36, 140, 150), (47, 158, 154), (140, 230, 214)], "Stone": ROSE_STONE, "Cap": (248, 222, 192), "Pop": (255, 210, 122)},
        {"Main": [(120, 80, 190), (156, 116, 226), (200, 170, 250)], "Stone": ROSE_STONE, "Cap": (130, 214, 190), "Pop": (255, 210, 122)},
    ],
}


class Kit(d2.Kit):
    pass


# ---------------------------------------------------------------- Shallows
def pillar_coral(k, r, pal):
    """five or six pillars of stacked segments, each pillar a group, a light cap on each"""
    for j, (x, z, h) in enumerate(((0, 0, 46), (10, 3, 34), (-9, 5, 28), (4, -10, 40), (-7, -8, 22), (13, -7, 18))):
        k.group = f"pillar{j}"
        foot, w = (x, 0, z), 8.5 - j * 0.4
        n = max(2, round(h / 8))
        for i in range(n):
            foot = k.beam(foot, w * (1 - 0.05 * i), h / n, w * (1 - 0.05 * i), tone(pal, "Deep" if i == 0 else "Main", 1), pitch=r.uniform(-3, 3), roll=r.uniform(-3, 3))
        k.box(foot[0], foot[1] - 0.5, foot[2], w + 2, 2.5, w + 2, tone(pal, "Main", 2))


def sea_stack(k, r, pal):
    d2.rock_stack(k, r, pal)


BLADE = ((("Main", 1), ("Main", 1), ("Main", 1), ("Soft", 0)), (("Main", 1), ("Main", 1), ("Soft", 0), ("Main", 2)))


def fan_coral(k, r, pal):
    """a rock foot and five blades fanning out, each blade a row of flat segments widening upward"""
    k.group = "foot"
    for x in (-5, 3):
        k.box(x, 0, 0, 8, 6, 8, tone(pal, "Stone", 0), yaw=r.uniform(-15, 15))
    for j, roll in enumerate((0, 24, -24, 46, -46)):
        k.group = f"blade{j}"
        foot = (0, 5, 0)
        for i in range(4):
            foot = k.beam(foot, 5 + i * 1.6, 7, 2.4, tone(pal, *BLADE[j % 2][i]), roll=roll * (1 + 0.06 * i))


def brain_coral(k, r, pal):
    """a low dome of tiers of blocks, checkered in two tones, each tier a group"""
    y = 0.0
    for i, (n, size, h) in enumerate(((4, 8, 6), (4, 7, 6), (3, 7, 5), (2, 7, 5))):
        k.group = f"tier{i}"
        off = (n - 1) * size / 2
        for a in range(n):
            for b in range(n):
                if n == 4 and a in (0, 3) and b in (0, 3):
                    continue  # the corners off: a rounder dome
                k.box(a * size - off, y, b * size - off, size, h, size, tone(pal, "Main" if i == 3 or (a + b) % 2 else "Soft", 2 if i == 3 else 1), yaw=r.uniform(-4, 4))
        y += h


def giant_clam(k, r, pal):
    """two shells of ribbed slabs, the top one lifted open, and a pearl"""
    deep, main, soft = pal["Deep"], tone(pal, "Main", 1), pal["Soft"]
    k.group = "lower"
    for i in range(5):
        k.box(-12 + i * 6, 0, 0, 5.6, 7 if i % 2 else 8, 18, deep if i % 2 else main)
    k.group = "upper"
    for i in range(5):
        k.beam((-12 + i * 6, 6, -8), 5.6, 16, 3, soft if i % 2 == 0 else main, pitch=-28)
    k.group = "pearl"
    k.box(0, 7, 2, 6, 6, 6, pal["Pop"])


def anemone(k, r, pal):
    """a stem of blocks and ten tentacles, each a row of segments with a light tip"""
    k.group = "stem"
    for i in range(3):
        k.box(0, i * 6, 0, 14 - i, 6, 14 - i, tone(pal, "Main", 0), yaw=r.uniform(-8, 8))
    for j in range(10):
        k.group = f"tentacle{j}"
        a = j * 36 + r.uniform(-6, 6)
        foot = props.turn((0, 17, 5), yaw=a)
        foot = d1.chain(k, foot, 4.2, 3, 6.5, r.uniform(38, 52), 0, a, [tone(pal, "Main", 1)], bend=-8)
        k.box(foot[0], foot[1] - 1, foot[2], 4.5, 3, 4.5, tone(pal, "Main", 2))


# ---------------------------------------------------------------- Coral Reef
def staghorn(k, r, pal):
    d2.staghorn(k, r, pal)


def tube_cluster(k, r, pal):
    """seven tubes, each a stack of segments with a dark mouth, each tube a group"""
    for j in range(7):
        k.group = f"tube{j}"
        a, rad = j * 51.0, 0 if j == 0 else 8 + 3 * (j % 3)
        x, z = rad * math.cos(math.radians(a)), rad * math.sin(math.radians(a))
        h = 40 if j == 0 else r.uniform(16, 34)
        n, w = max(2, round(h / 8)), r.uniform(6.5, 8)
        y = 0.0
        for i in range(n):
            k.box(x, y, z, w, h / n, w, tone(pal, "Deep" if i == 0 else ("Main" if i < n - 1 else "Soft"), 1), yaw=r.uniform(0, 30))
            y += h / n
        k.box(x, y, z, w - 3, 0.6, w - 3, (40, 44, 60), n="Mouth", studs=False)


def reef_wall(k, r, pal):
    """a long low ridge of rock columns, each column a group, with coral tufts on some"""
    for j in range(6):
        k.group = f"col{j}"
        x, h = -25 + j * 10, r.choice((14, 18, 22, 26))
        y = 0.0
        for i in range(max(2, round(h / 8))):
            k.box(x + r.uniform(-0.6, 0.6), y, r.uniform(-1, 1), 9.6, h / max(2, round(h / 8)), 12, tone(pal, "Stone", i % 2), yaw=r.uniform(-4, 4))
            y += h / max(2, round(h / 8))
        k.box(x, y, 0, 10, 2, 12, pal["Cap"])
        if j % 2:
            foot = (x, y + 1.5, 0)
            d1.chain(k, foot, 4.5, 2, 6, 0, r.uniform(-20, 20), 0, [tone(pal, "Main", 1), tone(pal, "Main", 2)])


def table_coral(k, r, pal):
    """a stem of segments and a plate of slabs with a dropped fringe"""
    k.group = "stem"
    tip = (0, 0, 0)
    for i in range(3):
        tip = k.beam(tip, 6 - i * 0.7, 6, 6 - i * 0.7, tone(pal, "Main", 0), studs=False)
    for qx in (-1, 1):
        for qz in (-1, 1):
            k.group = f"plate{qx}{qz}"
            for a in range(2):
                for b in range(2):
                    x, z = qx * (3.5 + a * 7), qz * (3.5 + b * 7)
                    k.box(x, tip[1], z, 7, 3.5, 7, tone(pal, "Main" if (a + b) % 2 else "Soft", 1))
                    if a == 1 or b == 1:
                        k.box(x * 1.06, tip[1] - 3, z * 1.06, 5.5, 3, 5.5, tone(pal, "Main", 1))


# ---------------------------------------------------------------- small dressing (never breaks, nothing collides)
def shells(k, r, pal):
    k.group = "dressing"
    for i in range(r.randint(2, 3)):
        k.box(r.uniform(-3, 3), 0, r.uniform(-3, 3), 2.2, 1.0, 1.8, pal.get("Shell", pal["Pop"]) if i == 0 else tone(pal, "Main", 2), yaw=r.uniform(0, 90))


def pebbles(k, r, pal):
    k.group = "dressing"
    for i in range(r.randint(2, 4)):
        s = r.uniform(1.2, 2.6)
        k.box(r.uniform(-4, 4), 0, r.uniform(-4, 4), s, s * 0.7, s * 0.9, tone(pal, "Stone", i % 2), yaw=r.uniform(0, 90))


def starfish(k, r, pal):
    k.group = "dressing"
    c = tone(pal, "Main", 1)
    k.box(0, 0, 0, 1.6, 0.6, 1.6, c)
    for j in range(5):
        a = j * 72 + r.uniform(-5, 5)
        p = props.turn((0, 0, 1.6), yaw=a)
        k.box(p[0], 0, p[2], 0.9, 0.5, 1.8, c, yaw=a)


def grass_tuft(k, r, pal):
    k.group = "dressing"
    for x, z, h in ((-1.2, 0, 5), (0, 0.8, 7), (1.3, -0.4, 4)):
        k.beam((x, 0, z), 1.0, h, 1.0, (63, 154, 124) if h < 6 else (98, 178, 144), roll=r.uniform(-10, 10), studs=False)


def crumbs(k, r, pal):
    """the reference's floor is sprinkled with tiny cubes where things have broken: a few, in the land's prop colours"""
    k.group = "dressing"
    for i in range(r.randint(3, 6)):
        s = r.uniform(0.7, 1.3)
        k.box(r.uniform(-8, 8), 0, r.uniform(-8, 8), s, s, s, (pal["Deep"], tone(pal, "Main", 1), pal["Soft"])[r.randint(0, 2)] if i % 3 else tone(pal, "Stone", 0), yaw=r.uniform(0, 90))


ASSETS = {  # name: (builder, size class, what it is)
    "pillar_coral": (pillar_coral, "big", "pillar coral"), "sea_stack": (sea_stack, "big", "rock stack"),
    "fan_coral": (fan_coral, "big", "sea fan"), "brain_coral": (brain_coral, "mid", "brain coral"),
    "giant_clam": (giant_clam, "mid", "giant clam"), "anemone": (anemone, "big", "anemone"),
    "pagoda_coral": (d2.pagoda, "big", "pagoda coral"),
    "staghorn": (staghorn, "big", "staghorn coral"), "tube_cluster": (tube_cluster, "big", "tube coral"),
    "reef_wall": (reef_wall, "big", "reef ridge"), "table_coral": (table_coral, "mid", "table coral"),
    "shells": (shells, "small", "shells"), "pebbles": (pebbles, "small", "pebbles"), "starfish": (starfish, "small", "starfish"),
    "grass_tuft": (grass_tuft, "small", "sea grass"), "crumbs": (crumbs, "small", "crumbs"),
}
LANDS = {
    0: ["pillar_coral", "sea_stack", "fan_coral", "brain_coral", "giant_clam", "pagoda_coral"],
    1: ["tube_cluster", "reef_wall", "table_coral", "pagoda_coral", "brain_coral"],  # staghorn and anemone out (the user, 2026-11-19: "Both")
}
DRESSING = {0: ["shells", "pebbles", "starfish", "grass_tuft", "crumbs"], 1: ["shells", "pebbles", "starfish", "crumbs", "crumbs"]}


# ================================================================ every land (stage 1 of docs/design/before-the-push.md)
# Palettes from docs/design/colour.md (art/map/palettes/proposal.json): each land's props keep one main pair far apart in
# lightness and one accent of another hue; Cap is the land's floor colour (the wall tops wear it); Glow from Open Blue on.
def _h(x):
    return tuple(int(x[i:i + 2], 16) for i in (1, 3, 5))


def _pal(dark, main, light, stone, cap, pop, glow=None):
    return {"Main": [_h(dark), _h(main), _h(light)], "Stone": [_h(stone[0]), _h(stone[1])], "Cap": _h(cap), "Pop": _h(pop), "Glow": _h(glow) if glow else None}


for _p in PALETTES[0]:
    _p["Cap"] = _h("#ded5a9")  # the proposal's Shallows floor
for _p in PALETTES[1]:
    _p["Cap"] = _h("#ef8a9a")
PALETTES.update({
    2: [_pal("#3f7a2c", "#7fc957", "#b8e88a", ("#88aaa0", "#9dbcb0"), "#359d55", "#e2c35a"),  # Kelp Forest: Forest's values
        _pal("#2f6a3a", "#5aa860", "#a6dc8c", ("#88aaa0", "#9dbcb0"), "#359d55", "#e2c35a")],
    3: [_pal("#6e5636", "#b89a6e", "#e0c89c", ("#94a283", "#a9b697"), "#88805c", "#e0b23c"),  # Shipwrecks: Extinction's
        _pal("#5a4a3a", "#9a8064", "#cbb08a", ("#94a283", "#a9b697"), "#88805c", "#e0b23c")],
    4: [_pal("#163a5e", "#2e6aa0", "#6fa8d8", ("#1d4551", "#327a88"), "#8fbfe0", "#6ff0e0", "#a3f8ec"),  # Open Blue: Ocean's
        _pal("#1d4551", "#327a88", "#7ac0c8", ("#163a5e", "#2e6aa0"), "#8fbfe0", "#ffd27a", "#a3f8ec")],
    5: [_pal("#55538f", "#9a94da", "#dcd6f6", ("#55538f", "#7a74c6"), "#cbc8e8", "#7cf2e6", "#a3f8ec"),  # Twilight: Snow's, violet
        _pal("#4a5a8a", "#8aa0d2", "#d2e2f6", ("#55538f", "#7a74c6"), "#cbc8e8", "#f2a6e0", "#a3f8ec")],
    6: [_pal("#141c4a", "#3a4aa8", "#7a8ae0", ("#141c4a", "#25306e"), "#9aa6d2", "#64fffd", "#64fffd"),  # Midnight
        _pal("#1c1440", "#4a3aa8", "#9a8ae8", ("#141c4a", "#25306e"), "#9aa6d2", "#ff9af0", "#64fffd")],
    7: [_pal("#0c1218", "#3a2a2e", "#6a4a44", ("#0c1218", "#2a2128"), "#2a2128", "#f9e40e", "#f9e40e"),  # Vents: Volcano's
        _pal("#2a1410", "#953122", "#c8583a", ("#0c1218", "#2a2128"), "#2a2128", "#ffb030", "#f9e40e")],
    8: [_pal("#9a9070", "#d8d0b8", "#f2ecdc", ("#5a6048", "#8a8a66"), "#8a8a66", "#7fe0b0", "#c8ffd8"),  # Bone Graveyard
        _pal("#6a6a50", "#a5a394", "#d6d4c4", ("#1e2f2e", "#45514a"), "#8a8a66", "#e0b23c", "#c8ffd8")],
    9: [_pal("#1c1270", "#271b9f", "#615fd6", ("#220979", "#3734c1"), "#8181d6", "#64fffd", "#64fffd"),  # the Underworld: Cosmic
        _pal("#2a0f6a", "#4a2aa8", "#9a7af0", ("#220979", "#3734c1"), "#8181d6", "#ff7af0", "#64fffd")],
})


def glow(pal):
    return pal.get("Glow") or pal["Pop"]


# ---------------------------------------------------------------- Kelp Forest
def kelp_stalk(k, r, pal, height=None, x=0.0, z=0.0, g="stalk"):
    """a kelp stalk: a row of segments swaying, a blade on alternate sides (each blade its own chunk), a light tip"""
    h = height or r.uniform(44, 60)
    foot, side = (x, 0, z), r.choice((-1, 1))
    n = max(4, round(h / 9))
    for i in range(n):
        k.group = g
        foot = k.beam(foot, 4.6 - i * 0.15, h / n, 4.6 - i * 0.15, tone(pal, "Main", 0), pitch=r.uniform(-6, 6), roll=r.uniform(-6, 6), studs=False)
        if i:
            k.group = f"{g}_blade{i}"
            k.beam((foot[0], foot[1] - 2, foot[2]), 6.5, 12, 2.2, tone(pal, "Main" if i % 2 else "Soft", 1), roll=side * r.uniform(52, 70), yaw=r.uniform(-30, 30))
            side = -side
    k.group = g
    k.box(foot[0], foot[1] - 1, foot[2], 6, 4, 6, tone(pal, "Main", 2))


def kelp_grove(k, r, pal):
    k.group = "rock"
    k.box(0, 0, 0, 14, 6, 12, tone(pal, "Stone", 0), yaw=r.uniform(0, 40))
    for j, (x, z, h) in enumerate(((0, 4, 58), (9, -4, 44), (-10, -2, 50))):
        kelp_stalk(k, r, pal, h, x, z, f"stalk{j}")


def giant_kelp(k, r, pal):  # the land's tall piece, for the first layer
    k.group = "foot"
    k.box(0, 0, 0, 10, 4, 10, tone(pal, "Stone", 0))
    kelp_stalk(k, r, pal, 72, 0, 0, "stalk")


def mossy_rock(k, r, pal):
    """a rock pile of tiers with moss caps in the land's green"""
    y = 0.0
    for i, (n, size, h) in enumerate(((3, 9, 8), (2, 9, 8), (1, 9, 7))):
        k.group = f"tier{i}"
        off = (n - 1) * size / 2
        for a in range(n):
            for b in range(n):
                k.box(a * size - off + r.uniform(-1, 1), y, b * size - off + r.uniform(-1, 1), size, h, size, tone(pal, "Stone", i % 2), yaw=r.uniform(-8, 8))
                if r.random() < 0.6:
                    k.box(a * size - off, y + h, b * size - off, size * 0.85, 2, size * 0.85, tone(pal, "Main", 1), yaw=r.uniform(-8, 8))
        y += h


def sea_bush(k, r, pal):
    """a round bush of leafy slabs in two greens, on a short stem (the reference's bush, for the sea)"""
    k.group = "stem"
    k.beam((0, 0, 0), 3.5, 5, 3.5, tone(pal, "Main", 0), studs=False)
    for i, (n, s, y) in enumerate(((3, 6, 4), (3, 5.5, 9), (2, 5, 14))):
        k.group = f"leaves{i}"
        off = (n - 1) * s / 2
        for a in range(n):
            for b in range(n):
                k.box(a * s - off, y, b * s - off, s, 5, s, tone(pal, "Main" if (a + b + i) % 2 else "Soft", 1), yaw=r.uniform(-10, 10))


def lip_grass(k, r, pal):  # the lip-row piece: a sea-grass tuft in the land's green
    k.group = "dressing"
    for x, z, h in ((-1.2, 0, 4), (0, 0.8, 6), (1.3, -0.4, 3.5)):
        k.beam((x, 0, z), 1.0, h, 1.0, tone(pal, "Main", 1 if h < 5 else 2), roll=r.uniform(-12, 12), studs=False)


# ---------------------------------------------------------------- Shipwrecks
def iron(pal, k):
    """the wrecks' iron, which is not the land's stone"""
    return tone(pal, "Iron" if "Iron" in pal else "Stone", k)


def crate_stack(k, r, pal):
    """crates stacked off centre, each crate its own chunk, a dark band round some"""
    spots = [(0, 0, 0), (9, 0, 2), (-8, 0, -3), (4, 0, -10), (3, 8.5, 0), (-4, 8.5, -4), (1, 17, -2)]
    for j, (x, y, z) in enumerate(spots[: r.randint(5, 7)]):
        k.group = f"crate{j}"
        c = tone(pal, "Main", 2) if j == 4 else tone(pal, "Main" if j % 2 else "Soft", 1)  # one pale crate a pile
        yaw = r.uniform(-15, 15)
        k.box(x, y, z, 8.5, 8.5, 8.5, c, yaw=yaw)
        if j % 3 == 0:
            k.box(x, y + 3.6, z, 8.9, 1.2, 8.9, iron(pal, 0), yaw=yaw, studs=False)


def barrel_pile(k, r, pal):
    for j, (x, y, z) in enumerate(((0, 0, 0), (7, 0, 1), (3.5, 8, 0.5), (-6, 0, -4))):
        k.group = f"barrel{j}"
        k.box(x, y, z, 6, 8, 6, pal["Deep"], yaw=r.uniform(0, 45))
        for yy in (1.5, 5.5):
            k.box(x, y + yy, z, 6.4, 1, 6.4, iron(pal, 0), yaw=r.uniform(0, 45), studs=False)


def broken_mast(k, r, pal):  # the land's tall piece
    k.group = "foot"
    k.box(0, 0, 0, 10, 5, 10, tone(pal, "Main", 0))
    lean = r.uniform(6, 14)
    tip = (0, 5, 0)
    for i in range(6):
        k.group = f"mast{i // 2}"
        tip = k.beam(tip, 5, 10, 5, tone(pal, "Deep" if i < 2 else ("Main" if i < 5 else "Soft"), 1), roll=lean, studs=False)
    k.group = "yard"
    k.beam((tip[0] + 12, tip[1] - 14, tip[2]), 3, 26, 3, pal["Deep"], roll=lean + 90, studs=False)


def hull_ribs(k, r, pal):
    """a broken hull's ribs: pairs of curved segments along a keel of blocks"""
    for j in range(5):
        z = -16 + j * 8
        k.group = f"keel{j}"
        k.box(0, 0, z, 6, 4, 7.5, tone(pal, "Main", 0))
        for side in (-1, 1):
            if r.random() < 0.15:
                continue
            k.group = f"rib{j}{side}"
            t = k.beam((side * 3, 3, z), 3.5, 12, 3.5, tone(pal, "Main", 1), roll=-side * 55, studs=False)
            k.beam((t[0], t[1] - 1, t[2]), 3.2, 14 - abs(j - 2) * 2, 3.2, pal["Soft"], roll=-side * 8, studs=False)


def anchor2(k, r, pal):
    lean = r.uniform(10, 20)
    k.group = "shank"
    tip = (0, 0, 0)
    for i in range(4):
        tip = k.beam(tip, 4, 8, 4, iron(pal, 0), roll=lean, studs=False)
    k.group = "ring"
    k.box(tip[0], tip[1], tip[2], 7, 7, 2.5, iron(pal, 1), studs=False)
    for side in (-1, 1):
        k.group = f"fluke{side}"
        t = k.beam((0, 1, 0), 4, 10, 4, iron(pal, 0), roll=lean - side * 60, studs=False)
        k.box(t[0], t[1] - 2, t[2], 6, 4, 4, iron(pal, 1), studs=False)


def lip_crate(k, r, pal):  # the lip-row piece: a small crate or a coil of rope
    k.group = "dressing"
    if r.random() < 0.6:
        k.box(0, 0, 0, 3.5, 3.5, 3.5, (tone(pal, "Main", 1), pal["Soft"])[r.randint(1, 2) - 1], yaw=r.uniform(0, 45))
    else:
        for i in range(3):
            k.box(0, i * 0.8, 0, 3.6 - i * 0.6, 0.8, 3.6 - i * 0.6, pal["Soft"], yaw=i * 20, studs=False)


def coins(k, r, pal):  # dressing: a scatter of gold coins (the land's accent)
    k.group = "dressing"
    for i in range(r.randint(3, 6)):
        k.box(r.uniform(-4, 4), 0, r.uniform(-4, 4), 1.4, 0.4, 1.4, pal["Pop"], yaw=r.uniform(0, 90), studs=False)


# ---------------------------------------------------------------- Open Blue
def step_stack(k, r, pal):
    """the reference's Ocean blocks: slabs stacked in steps, each smaller and set back, dark tops"""
    y, x = 0.0, 0.0
    for i, (w, h) in enumerate(((26, 7), (20, 7), (14, 7), (8, 6))):
        k.group = f"step{i}"
        x += r.uniform(-1.5, 1.5)
        for j in range(max(1, round(w / 9))):
            k.box(x - w / 2 + 4.5 + j * 9, y, 0, 9, h, w * 0.7, tone(pal, "Main", 1), yaw=r.uniform(-3, 3))
        k.box(x, y + h, 0, w, 1.4, w * 0.7, tone(pal, "Stone", 0))
        y += h + 1.4


def sponge_tubes(k, r, pal):
    for j in range(5):
        k.group = f"tube{j}"
        a = j * 72 + r.uniform(-15, 15)
        rad = 0 if j == 0 else 7
        x, z = rad * math.cos(math.radians(a)), rad * math.sin(math.radians(a))
        h = 36 if j == 0 else r.uniform(16, 28)
        n, w, y = max(2, round(h / 8)), r.uniform(6, 7.5), 0.0
        for i in range(n):
            k.box(x, y, z, w, h / n, w, tone(pal, "Main", 0 if i == 0 else 1), yaw=r.uniform(0, 30))
            y += h / n
        k.box(x, y, z, w - 2.5, 0.6, w - 2.5, glow(pal), n="Glow", studs=False)


def glow_cubes(k, r, pal):  # the reference's floating glow cubes, from the Ocean on: a few, low over the floor
    k.group = "dressing"
    for i in range(r.randint(2, 4)):
        s = r.uniform(1.2, 2.2)
        k.box(r.uniform(-6, 6), r.uniform(3, 9), r.uniform(-6, 6), s, s, s, glow(pal), n="Glow", yaw=r.uniform(0, 45), studs=False)


def tall_pillar(k, r, pal):  # the land's tall piece: a leaning pillar (the reference's Ocean has one gold one)
    lean = r.uniform(5, 12)
    tip = (0, 0, 0)
    for i in range(7):
        k.group = f"seg{i // 2}"
        tip = k.beam(tip, 7 - i * 0.4, 10, 7 - i * 0.4, tone(pal, "Main", min(2, i // 3)), roll=lean)
    k.group = "cap"
    k.box(tip[0], tip[1] - 1, tip[2], 6, 3, 6, glow(pal), n="Glow", studs=False)


def lip_sponge(k, r, pal):
    k.group = "dressing"
    k.box(0, 0, 0, 3, r.uniform(3, 5), 3, tone(pal, "Main", 1), yaw=r.uniform(0, 45))
    k.box(0, 4.6, 0, 1.6, 0.4, 1.6, glow(pal), n="Glow", studs=False)


# ---------------------------------------------------------------- Twilight (the reference's Snow, in violet)
def crystal_cluster(k, r, pal):
    """pale prisms in a clump, leaning out, glowing tips; each crystal a chunk"""
    k.group = "base"
    k.box(0, 0, 0, 14, 4, 12, tone(pal, "Stone", 0), yaw=r.uniform(0, 40))
    for j in range(r.randint(4, 6)):
        k.group = f"crystal{j}"
        a = j * 70 + r.uniform(-20, 20)
        foot = props.turn((r.uniform(1, 5), 3, 0), yaw=a)
        h = r.uniform(14, 30) if j else 34
        tip = k.beam(foot, 5, h * 0.55, 5, tone(pal, "Main", 1), pitch=r.uniform(8, 22), yaw=a)
        tip = k.beam(tip, 4, h * 0.35, 4, tone(pal, "Main", 2), pitch=r.uniform(8, 22), yaw=a)
        k.beam(tip, 2.4, h * 0.12, 2.4, glow(pal), pitch=r.uniform(8, 22), yaw=a, n="Glow", studs=False)


def slab_pile(k, r, pal):
    """the reference's Snow pile: flat pale slabs lying in a heap, each its own chunk"""
    y = 0.0
    for j in range(r.randint(5, 7)):
        k.group = f"slab{j}"
        w = r.uniform(10, 16)
        k.box(r.uniform(-4, 4), y, r.uniform(-4, 4), w, 2.6, w * 0.7, tone(pal, "Main", 2 if j % 2 else 1), yaw=r.uniform(0, 90))
        y += r.uniform(1.6, 2.6)


def frost_pine(k, r, pal):  # the land's tall piece, and the reference's Snow pines in rows on the terrace lips
    d2.pagoda(k, r, pal)


def lip_crystal(k, r, pal):
    k.group = "dressing"
    for i in range(r.randint(1, 3)):
        a = r.uniform(0, 360)
        k.beam((r.uniform(-1.5, 1.5), 0, r.uniform(-1.5, 1.5)), 1.4, r.uniform(3, 6), 1.4, tone(pal, "Main", 2) if i else glow(pal), pitch=r.uniform(5, 20), yaw=a, n="Glow" if not i else "Brick", studs=False)


# ---------------------------------------------------------------- Midnight
def lantern_post(k, r, pal):
    """a dark post of segments with a glowing bulb hanging from a crook (an angler's lure, as a lamp)"""
    k.group = "post"
    tip = (0, 0, 0)
    for i in range(4):
        tip = k.beam(tip, 4.5 - i * 0.4, 9, 4.5 - i * 0.4, tone(pal, "Main", 0), roll=r.uniform(-3, 3), studs=False)
    k.group = "crook"
    tip = k.beam(tip, 3, 9, 3, tone(pal, "Main", 0), roll=65, studs=False)
    k.group = "bulb"
    k.box(tip[0], tip[1] - 6, tip[2], 5, 5, 5, glow(pal), n="Glow", studs=False)


def glow_mushroom(k, r, pal):
    for j, (x, z, h, w) in enumerate(((0, 0, 20, 18), (11, 4, 12, 11), (-9, 6, 9, 9))):
        k.group = f"stem{j}"
        k.beam((x, 0, z), w * 0.25, h, w * 0.25, tone(pal, "Main", 2), studs=False)
        k.group = f"cap{j}"
        k.box(x, h - 1, z, w, 3.5, w, tone(pal, "Main", 1), yaw=r.uniform(0, 30))
        k.box(x, h - 1.6, z, w * 0.8, 0.6, w * 0.8, glow(pal), n="Glow", yaw=r.uniform(0, 30), studs=False)


def dark_stack(k, r, pal):
    y = 0.0
    for i, (n, size, h) in enumerate(((3, 9, 9), (2, 9, 9), (1, 8, 8))):
        k.group = f"tier{i}"
        off = (n - 1) * size / 2
        for a in range(n):
            for b in range(n):
                k.box(a * size - off, y, b * size - off, size, h, size, tone(pal, "Stone", i % 2), yaw=r.uniform(-8, 8))
        k.box(r.uniform(-3, 3), y + h * 0.5, size * n / 2, size * 0.6, 0.8, 0.6, glow(pal), n="Glow", studs=False)  # a crack of light
        y += h


def glow_stalk(k, r, pal):  # the land's tall piece
    k.group = "foot"
    k.box(0, 0, 0, 9, 4, 9, tone(pal, "Stone", 0))
    tip = (0, 4, 0)
    for i in range(6):
        k.group = f"seg{i // 2}"
        tip = k.beam(tip, 4.5 - i * 0.4, 10, 4.5 - i * 0.4, tone(pal, "Main", min(2, i // 2)), roll=r.uniform(-5, 5), studs=False)
        if i % 2:
            k.box(tip[0], tip[1] - 1, tip[2], 3, 3, 3, glow(pal), n="Glow", studs=False)


def lip_bulb(k, r, pal):
    k.group = "dressing"
    k.beam((0, 0, 0), 0.8, r.uniform(3, 5), 0.8, tone(pal, "Main", 0), roll=r.uniform(-10, 10), studs=False)
    k.box(0, 4.5, 0, 1.6, 1.6, 1.6, glow(pal), n="Glow", studs=False)


# ---------------------------------------------------------------- Vents (the reference's Volcano)
def chimney(k, r, pal):
    """a black chimney of stacked blocks with glowing seams, a vent of light at the top"""
    k.group = "foot"
    k.box(0, 0, 0, 16, 5, 16, tone(pal, "Main", 0), yaw=r.uniform(0, 40))
    tip, lean = (0, 5, 0), r.uniform(-8, 8)
    for i in range(5):
        k.group = f"seg{i}"
        tip = k.beam(tip, 9 - i * 0.8, 8, 9 - i * 0.8, tone(pal, "Main", i % 2), roll=lean)
        if i % 2 == 0:
            k.box(tip[0], tip[1] - 0.4, tip[2], 9.4 - i * 0.8, 0.8, 9.4 - i * 0.8, glow(pal), n="Glow", studs=False)
    k.group = "top"
    k.box(tip[0], tip[1], tip[2], 5, 1, 5, glow(pal), n="Glow", studs=False)


def lava_slabs(k, r, pal):
    """the reference's lava pools: flat glowing slabs set into the floor, ringed by dark blocks"""
    for j in range(r.randint(2, 3)):
        k.group = f"pool{j}"
        w = r.uniform(10, 16)
        x, z = r.uniform(-8, 8), r.uniform(-8, 8)
        k.box(x, 0, z, w, 0.6, w * 0.7, glow(pal), n="Glow", yaw=r.uniform(0, 30), studs=False)
        for a in range(3):
            k.box(x + r.uniform(-w / 2, w / 2), 0, z + w * 0.4, 4, r.uniform(2, 4), 4, tone(pal, "Stone", 0), yaw=r.uniform(0, 45))


def black_posts(k, r, pal):
    for j in range(r.randint(3, 5)):
        k.group = f"post{j}"
        x, z = r.uniform(-10, 10), r.uniform(-10, 10)
        tip = (x, 0, z)
        for i in range(r.randint(2, 4)):
            tip = k.beam(tip, 4, 8, 4, tone(pal, "Main", 0), roll=r.uniform(-4, 4))
        k.box(tip[0], tip[1] - 0.5, tip[2], 4.4, 1, 4.4, glow(pal), n="Glow", studs=False)


def tall_chimney(k, r, pal):  # the land's tall piece
    chimney(k, r, pal)
    tip = max((b[1] for b in k.b), key=lambda p: p[1])
    for i in range(3):
        k.group = f"upper{i}"
        k.box(tip[0], tip[1] + 2 + i * 8, tip[2], 6, 8, 6, tone(pal, "Main", i % 2))


def lip_ember(k, r, pal):
    k.group = "dressing"
    k.box(0, 0, 0, 3, 2, 3, tone(pal, "Stone", 0), yaw=r.uniform(0, 45))
    k.box(0.6, 2, 0.4, 1.2, 0.8, 1.2, glow(pal), n="Glow", studs=False)


# ---------------------------------------------------------------- Bone Graveyard (the reference's Extinction)
def bone_post(k, r, pal):
    """the reference's bone posts: a column with a flared foot and top, standing or leaning"""
    lean = r.uniform(-12, 12)
    k.group = "foot"
    k.box(0, 0, 0, 8, 3, 8, tone(pal, "Main", 0))
    tip = (0, 3, 0)
    for i in range(3):
        k.group = f"shaft{i}"
        tip = k.beam(tip, 4.5, 9, 4.5, tone(pal, "Main", 2), roll=lean, studs=False)
    k.group = "top"
    k.box(tip[0], tip[1] - 1, tip[2], 8, 4, 7, tone(pal, "Main", 1))


def ribcage(k, r, pal):
    for j in range(6):
        z = -18 + j * 7
        k.group = f"vert{j}"
        k.box(0, 0, z, 6, 6, 6, tone(pal, "Main", 1))
        if 0 < j < 5:
            for side in (-1, 1):
                k.group = f"rib{j}{side}"
                t = k.beam((side * 3, 4, z), 3, 14, 3, tone(pal, "Main", 2), roll=-side * 50, studs=False)
                k.beam((t[0], t[1] - 1, t[2]), 2.8, 16 - abs(j - 2.5) * 3, 2.8, tone(pal, "Main", 2), roll=side * 10, studs=False)


def checker_boulder(k, r, pal):
    """the reference's Extinction boulders: a big block built of cube cells in four tones"""
    tones = [tone(pal, "Main", 0), tone(pal, "Main", 1), tone(pal, "Stone", 0), tone(pal, "Stone", 1)]
    for i, y in enumerate((0, 8, 16)):
        k.group = f"row{i}"
        n = 3 - (i == 2)
        off = (n - 1) * 8 / 2
        for a in range(n):
            for b in range(n):
                k.box(a * 8 - off, y, b * 8 - off, 8, 8, 8, tones[(a + 2 * b + i) % 4])


def skull_small(k, r, pal):
    k.group = "jaw"
    k.box(0, 0, 4, 12, 3, 16, tone(pal, "Main", 1))
    k.group = "cranium"
    k.box(0, 3, -2, 16, 11, 14, tone(pal, "Main", 2))
    k.box(0, 4, 8, 12, 7, 10, tone(pal, "Main", 2))
    for side in (-1, 1):
        k.box(side * 8.2, 8, 1, 0.6, 4, 4, (30, 30, 34), studs=False, n="Socket")


def lip_bone(k, r, pal):
    k.group = "dressing"
    a = r.uniform(0, 180)
    k.box(0, 0, 0, 1.4, 1.4, 5, tone(pal, "Main", 2), yaw=a, studs=False)
    for e in (-1, 1):
        p = props.turn((0, 0, e * 2.6), yaw=a)
        k.box(p[0], 0, p[2], 2.2, 1.8, 1.4, tone(pal, "Main", 2), yaw=a, studs=False)


# ---------------------------------------------------------------- The Underworld (the reference's Cosmic)
def faceted_rock(k, r, pal):
    """the reference's Cosmic rocks: dark blocks turned on their edges with a crystal on top"""
    for j in range(3):
        k.group = f"rock{j}"
        k.beam((r.uniform(-6, 6), 0, r.uniform(-6, 6)), r.uniform(10, 14), r.uniform(9, 13), r.uniform(9, 12), tone(pal, "Main", j % 2), pitch=r.uniform(-25, 25), roll=r.uniform(-25, 25), yaw=r.uniform(0, 90))
    k.group = "crystal"
    tip = k.beam((0, 10, 0), 4, 10, 4, tone(pal, "Main", 2), pitch=r.uniform(-10, 10))
    k.beam(tip, 2.4, 4, 2.4, glow(pal), n="Glow", studs=False)


def quartz_cluster(k, r, pal):
    crystal_cluster(k, r, pal)


def hex_pad(k, r, pal):  # dressing: a flat glowing hexagon set in the floor (three turned slabs)
    k.group = "dressing"
    for a in (0, 60, 120):
        k.box(0, 0, 0, 6, 0.4, 3.5, glow(pal), yaw=a, n="Glow", studs=False)


def crystal_spire(k, r, pal):  # the land's tall piece
    k.group = "foot"
    k.box(0, 0, 0, 12, 4, 12, tone(pal, "Stone", 0), yaw=r.uniform(0, 45))
    tip = (0, 4, 0)
    for i in range(5):
        k.group = f"seg{i // 2}"
        tip = k.beam(tip, 6 - i * 0.9, 11, 6 - i * 0.9, tone(pal, "Main", min(2, i // 2)), roll=r.uniform(-4, 4), yaw=45)
    k.group = "tip"
    k.beam(tip, 2, 6, 2, glow(pal), n="Glow", studs=False, yaw=45)


# ---------------------------------------------------------------- small things every land shares
def clump(k, r, pal):
    """flowers in a clump, never one alone (the reference's rule): 3 to 8 crosses of tiles in the land's accent and a paler
    one of it"""
    k.group = "dressing"
    for i in range(r.randint(3, 6)):  # each flower a cross of two crossed tiles (two bricks: 2026-11-19, five each made 32,000)
        x, z = r.uniform(-5, 5), r.uniform(-5, 5)
        c = pal["Pop"] if i % 3 else pal["PopSoft"]
        k.box(x, 0, z, 3.0, 0.4, 1.0, c, studs=False)
        k.box(x, 0, z, 1.0, 0.45, 3.0, c, studs=False)


ASSETS.update({
    "kelp_grove": (kelp_grove, "big", "kelp grove"), "giant_kelp": (giant_kelp, "big", "giant kelp"), "mossy_rock": (mossy_rock, "big", "mossy rock"),
    "sea_bush": (sea_bush, "mid", "sea bush"), "lip_grass": (lip_grass, "small", "sea-grass tuft"),
    "crate_stack": (crate_stack, "big", "crate stack"), "barrel_pile": (barrel_pile, "mid", "barrels"), "broken_mast": (broken_mast, "big", "broken mast"),
    "hull_ribs": (hull_ribs, "big", "hull ribs"), "anchor2": (anchor2, "big", "anchor"), "lip_crate": (lip_crate, "small", "small crate"), "coins": (coins, "small", "coins"),
    "step_stack": (step_stack, "big", "step stack"), "sponge_tubes": (sponge_tubes, "big", "sponge tubes"), "tall_pillar": (tall_pillar, "big", "leaning pillar"),
    "lip_sponge": (lip_sponge, "small", "small sponge"), "glow_cubes": (glow_cubes, "small", "glow cubes"),
    "crystal_cluster": (crystal_cluster, "big", "crystal cluster"), "slab_pile": (slab_pile, "mid", "slab pile"), "frost_pine": (frost_pine, "big", "frost pagoda"),
    "lip_crystal": (lip_crystal, "small", "small crystals"),
    "lantern_post": (lantern_post, "big", "lantern post"), "glow_mushroom": (glow_mushroom, "mid", "glow mushrooms"), "dark_stack": (dark_stack, "big", "dark stack"),
    "glow_stalk": (glow_stalk, "big", "glow stalk"), "lip_bulb": (lip_bulb, "small", "glow bulb"),
    "chimney": (chimney, "big", "chimney"), "lava_slabs": (lava_slabs, "mid", "lava pools"), "black_posts": (black_posts, "big", "black posts"),
    "tall_chimney": (tall_chimney, "big", "tall chimney"), "lip_ember": (lip_ember, "small", "ember stone"),
    "bone_post": (bone_post, "big", "bone post"), "ribcage": (ribcage, "big", "ribcage"), "checker_boulder": (checker_boulder, "big", "checker boulder"),
    "skull_small": (skull_small, "mid", "skull"), "lip_bone": (lip_bone, "small", "bone"),
    "faceted_rock": (faceted_rock, "big", "faceted rock"), "quartz_cluster": (quartz_cluster, "big", "quartz cluster"), "crystal_spire": (crystal_spire, "big", "crystal spire"),
    "hex_pad": (hex_pad, "small", "hex pad"), "clump": (clump, "small", "flower clump"),
})
LANDS.update({
    2: ["kelp_grove", "mossy_rock", "sea_bush", "giant_kelp", "brain_coral"],
    3: ["crate_stack", "barrel_pile", "hull_ribs", "anchor2", "broken_mast"],
    4: ["step_stack", "sponge_tubes", "giant_clam", "tall_pillar", "brain_coral"],
    5: ["crystal_cluster", "slab_pile", "frost_pine", "brain_coral"],
    6: ["lantern_post", "glow_mushroom", "dark_stack", "glow_stalk"],
    7: ["chimney", "lava_slabs", "black_posts", "tall_chimney"],
    8: ["bone_post", "ribcage", "checker_boulder", "skull_small"],
    9: ["faceted_rock", "quartz_cluster", "crystal_spire", "glow_mushroom"],
})
DRESSING[0] = DRESSING[0] + ["clump"]
DRESSING[1] = DRESSING[1] + ["clump", "clump"]
DRESSING.update({2: ["lip_grass", "pebbles", "crumbs", "clump", "shells"], 3: ["coins", "pebbles", "crumbs", "lip_crate", "shells"],
                 4: ["glow_cubes", "shells", "crumbs", "pebbles", "clump"], 5: ["lip_crystal", "pebbles", "crumbs", "clump"],
                 6: ["lip_bulb", "glow_cubes", "pebbles", "crumbs"], 7: ["lip_ember", "pebbles", "crumbs", "crumbs"],
                 8: ["lip_bone", "pebbles", "crumbs", "clump"], 9: ["hex_pad", "glow_cubes", "pebbles", "crumbs"]})
# each land's two placing roles (stage 2): the lip row's piece (the smallest, in an even row along every lip and wall
# top) and the first layer's tall piece (the reference puts its tall things on the lowest ledge, smaller ones higher)
LIP = {0: "shells", 1: "shells", 2: "lip_grass", 3: "lip_crate", 4: "lip_sponge", 5: "lip_crystal", 6: "lip_bulb", 7: "lip_ember", 8: "lip_bone", 9: "lip_crystal"}
TALL = {0: "pagoda_coral", 1: "pagoda_coral", 2: "giant_kelp", 3: "broken_mast", 4: "tall_pillar", 5: "frost_pine", 6: "glow_stalk", 7: "tall_chimney", 8: "bone_post", 9: "crystal_spire"}


# ---------------------------------------------------------------- values (2026-11-19, docs/design/colour.md, "Value")
# The reference's views always hold some near-black and near-white; ours sat in a narrow middle band. So every
# palette's dark tone is pushed down to about L* 20 and its light tone up to about L* 87, each keeping its hue, and the
# dark stone too. The glow and the accent are left alone.
def _lstar(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
    return 116 * y ** (1 / 3) - 16 if y > 0.008856 else 903.3 * y


def _to_l(c, target, toward_white=False):
    """the colour moved to lightness `target`: darker by scaling, lighter by mixing toward white (keeps the hue)"""
    lo, hi = 0.0, 1.0
    for _ in range(30):
        f = (lo + hi) / 2
        if toward_white:
            t = tuple(int(v + (255 - v) * f) for v in c)
        else:
            t = tuple(int(v * (1 - f)) for v in c)
        if (_lstar(t) < target) != toward_white:
            hi = f
        else:
            lo = f
    return t


# 2026-11-23 (docs/design/colour.md, "A bit less random"): the reference's L* 16 to 28 was read ON SCREEN. Through our
# water an authored 26 came out black on every shaded side, so the first four lands' dark is 34 and their light 84. And a
# dark is a stem, a seam or a band, a light a tip or a top: bodies are Main, with Soft (8 of lightness up) and Deep (13 down)
# beside it where a builder used to put the light or the dark half and half
for _p in PALETTES[3]:
    _p["Iron"] = [_h("#46555a"), _h("#5f6f73")]
for _land in range(4):
    for _p in PALETTES[_land]:
        _p["Shell"] = SHELL
EARLY = 4  # the lands the 2026-11-23 values are for
VALUE_DARK, VALUE_LIGHT = 26.0, 87.0


def _toward(a, b, target):
    """`a` moved toward `b` until it is `target` light (the orange's soft is a yellower orange, not a paler one)"""
    for _i in range(1, 41):
        t = tuple(int(a[_c] + (b[_c] - a[_c]) * _i / 40) for _c in range(3))
        if _lstar(t) >= target:
            return t
    return tuple(b)


VALUE_DARK_EARLY, VALUE_LIGHT_EARLY = 34.0, 84.0
for _land, _pals in PALETTES.items():
    _dark, _light = (VALUE_DARK_EARLY, VALUE_LIGHT_EARLY) if _land < EARLY else (VALUE_DARK, VALUE_LIGHT)
    for _p in _pals:
        if _lstar(_p["Main"][0]) > _dark:
            _p["Main"][0] = _to_l(_p["Main"][0], _dark)
        if _lstar(_p["Main"][2]) < _light:
            _p["Main"][2] = _to_l(_p["Main"][2], _light, toward_white=True)
        if _lstar(_p["Stone"][0]) > _dark + 6 and _land >= EARLY:  # (an early land's stone is its wall's, pale)
            _p["Stone"][0] = _to_l(_p["Stone"][0], _dark + 6)
        _m = _p["Main"][1]
        _p["Soft"] = _toward(_m, _p["Main"][2], _lstar(_m) + 8)
        _p["Deep"] = _to_l(_m, max(10.0, _lstar(_m) - 13))
        _p["PopSoft"] = tuple(int(_v + (255 - _v) * 0.45) for _v in _p["Pop"])


def bricks(name, seed=0, land=0, way=None, tint=None):
    """an asset's bricks, foot first: [(name, centre, size, colour, axes, studs, group)]; `way` picks the colourway.
    `tint` picks it too, after the dice are thrown: the shapes stay the same whichever colours they wear"""
    r = random.Random(seed * 131 + len(name))
    pals = PALETTES[land]
    pal = pals[way if way is not None else r.randrange(len(pals))]
    if tint is not None:
        pal = pals[tint % len(pals)]
    k = Kit()
    ASSETS[name][0](k, r, pal)
    return k.b


LAND_NAMES = ["Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue", "Twilight", "Midnight", "Vents", "Bone Graveyard", "The Underworld"]


def write():
    shots, rows = [], []
    for land, names in LANDS.items():
        layout, x, labels = [], -170.0, []
        for name in names:
            bs = bricks(name, 2, land, 0)
            hx, hy, hz = props.extent([b[:5] for b in bs])
            x += hx + 10
            layout.append([d2.js(bs), [x, 0, 0]])
            groups = len({b[6] for b in bs})
            labels.append(f"{ASSETS[name][2]}: {round(hy)} tall, {len(bs)} bricks, {groups} chunks")
            x += hx + 10
        dx = 0
        small = [LIP[land]] + [n for n in DRESSING[land] if n != LIP[land]][:3]
        for name in small:  # the lip-row piece and the small dressing in a row in front
            layout.append([d2.js(bricks(name, 3, land, 0)), [-120 + dx, 0, 40]])
            dx += 22
        floor = PALETTES[land][0]["Cap"]
        mid, span = (x - 170) / 2, x + 170
        shots.append({"name": f"land{land}", "layout": layout, "eye": [mid, 80, (span + 40) * 1.05], "target": [mid, 20, 0], "fov": 50, "res": [1800, 640], "figure": [-195, 0, 30], "floor": floor})
        ways = []
        for wi in range(len(PALETTES[land])):
            for ni, name in enumerate(names[:2]):
                ways.append([d2.js(bricks(name, 2, land, wi)), [-230 + wi * 170 + ni * 70, 0, 0]])
        shots.append({"name": f"ways{land}", "layout": ways, "eye": [-40, 70, 640], "target": [-40, 22, 0], "fov": 46, "res": [1800, 520], "figure": [-290, 0, 30], "floor": floor})
        rows.append({"land": LAND_NAMES[land], "labels": labels})
    os.makedirs(OUT, exist_ok=True)
    json.dump({"floor": [242, 214, 128], "shots": shots, "rows": rows}, open(os.path.join(OUT, "kit.json"), "w"))
    for r in rows:
        print(r["land"], "; ".join(r["labels"]))


def sheet():
    """two sheets, lands 1 to 5 and 6 to 10: each land's kit standing (with its lip-row piece and small dressing in
    front) and its first two props in each colourway"""
    from PIL import Image, ImageDraw, ImageFont
    data = json.load(open(os.path.join(OUT, "kit.json")))
    R = os.path.join(OUT, "renders")
    bold, plain = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 24), ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    w, pad = 1800, 14
    paths = []
    for part, (a, b) in enumerate(((0, 5), (5, 10))):
        rows = list(enumerate(data["rows"]))[a:b]
        out = Image.new("RGB", (w + 2 * pad, 60 + len(rows) * (640 + 260 + 110)), (254, 248, 241))
        dr = ImageDraw.Draw(out)
        dr.text((pad, 16), f"Breakable props (option B), lands {a + 1} to {b}: each land's kit in its palette; small things in front; the first two in each colourway below", font=bold, fill=(30, 30, 30))
        y = 56
        for land, row in rows:
            dr.text((pad, y), f"{land + 1}. {row['land']}", font=bold, fill=(40, 40, 40))
            out.paste(Image.open(os.path.join(R, f"land{land}.png")).convert("RGB"), (pad, y + 32))
            half = (len(row["labels"]) + 1) // 2
            dr.text((pad, y + 676), ";  ".join(row["labels"][:half]), font=plain, fill=(60, 60, 60))
            dr.text((pad, y + 700), ";  ".join(row["labels"][half:]), font=plain, fill=(60, 60, 60))
            ways = Image.open(os.path.join(R, f"ways{land}.png")).convert("RGB")
            out.paste(ways.resize((w, int(ways.height * w / ways.width) // 2)).crop((0, 0, w, 260)) if False else ways.resize((w // 2, ways.height // 2)), (pad, y + 728))
            y += 640 + 260 + 110
        path = os.path.join(ROOT, "docs", "attachments", f"map-props2-kit-{part + 1}.jpg")
        out.save(path, quality=86)
        paths.append(path)
    print(*paths)


if __name__ == "__main__":
    sheet() if "--sheet" in sys.argv else write()
