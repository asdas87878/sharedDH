"""The map's big assets (docs/design/map-method.md, "The assets"): things large and tall enough that a ridden fish has
to steer round them, a set per land. Each is built the way the creatures are: a few big boxes, each a part of the
thing, leaning where it leans, nothing fused, listed foot first. So each can come apart when a big fish hits it.

usage: python tools/map/props.py            writes art/map/props/kit.json: every asset stood in a row per land, with a
                                             rider on a 13-stud fish for scale, and the cameras for the sheet
       blender --background --python tools/blender/map_greybox_view.py -- --kit
       python tools/map/props.py --sheet    lays the renders out as docs/attachments/map-props-kit.jpg
tools/map/greybox.py places them along the lane.

Axes: y up; an asset's foot is at y = 0 and its front faces +z. A fish swims 5 to 16 studs over the floor and a jump
rises 21 more, so an obstacle is 20 to 110 tall, and nothing wide hangs over where fish swim."""
import json
import math
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "map", "props")

PINK, ORANGE, PURPLE, TEAL, YELLOW = (244, 120, 150), (255, 150, 80), (170, 120, 230), (70, 190, 190), (250, 205, 90)
ROCK, KELP, KELP_DARK, WOOD, WOOD_DARK, IRON = (150, 152, 166), (84, 168, 92), (52, 116, 74), (146, 104, 72), (100, 72, 54), (72, 76, 92)
BONE, BONE_SHADE, DARK, WHITE = (236, 228, 205), (204, 195, 170), (40, 44, 60), (250, 250, 245)


def lighten(c, k=1.1, add=12):
    return tuple(min(255, int(v * k + add)) for v in c)


def darken(c, k=0.8):
    return tuple(int(v * k) for v in c)


def turn(v, pitch=0.0, yaw=0.0, roll=0.0):
    """a vector turned by roll (about z: + leans the top to -x), then pitch (about x: + leans the top to +z), then
    yaw (about y), in degrees"""
    x, y, z = v
    a = math.radians(roll)
    x, y = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
    a = math.radians(pitch)
    y, z = y * math.cos(a) - z * math.sin(a), y * math.sin(a) + z * math.cos(a)
    a = math.radians(yaw)
    x, z = x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)
    return (x, y, z)


def axes(pitch=0.0, yaw=0.0, roll=0.0):
    return tuple(turn(v, pitch, yaw, roll) for v in ((1, 0, 0), (0, 1, 0), (0, 0, 1)))


class Kit:
    """collects an asset's bricks: (name, centre, size, colour, axes)"""

    def __init__(self):
        self.b = []

    def box(self, x, y0, z, w, h, d, c, yaw=0.0, n="Brick"):
        """a box standing level with its foot at y0"""
        self.b.append((n, (x, y0 + h / 2, z), (w, h, d), c, axes(0, yaw, 0)))

    def beam(self, foot, w, length, d, c, pitch=0.0, roll=0.0, yaw=0.0, n="Brick"):
        """a box standing on `foot` and leaning; returns its tip, for the next piece of a chain"""
        ax = axes(pitch, yaw, roll)
        up = ax[1]
        self.b.append((n, (foot[0] + up[0] * length / 2, foot[1] + up[1] * length / 2, foot[2] + up[2] * length / 2), (w, length, d), c, ax))
        return (foot[0] + up[0] * length, foot[1] + up[1] * length, foot[2] + up[2] * length)


# ---------------------------------------------------------------- corals (Shallows, Coral Reef)
def pillar_coral(k, r, g):
    c = r.choice((ORANGE, PINK, YELLOW))
    for i, (x, z) in enumerate(((0, 0), (10, 3), (-9, 5), (4, -10), (-7, -8), (14, -7))):
        h, w = (52, 38, 30, 44, 24, 18)[i] * r.uniform(0.9, 1.1), (11, 9, 9, 10, 8, 8)[i]
        tip = k.beam((x, 0, z), w, h, w, c if i % 2 == 0 else lighten(c), pitch=r.uniform(-4, 4), roll=r.uniform(-4, 4))
        k.box(tip[0], tip[1] - 0.6, tip[2], w + 2.4, 3, w + 2.4, lighten(c, 1.15, 26))


def brain_coral(k, r, g):
    c = r.choice((PINK, PURPLE, TEAL))
    y = 0.0
    for i, (w, h, d) in enumerate(((40, 10, 36), (34, 9, 30), (25, 8, 22), (14, 6, 12))):
        k.box(r.uniform(-1, 1), y, r.uniform(-1, 1), w, h, d, c if i % 2 == 0 else lighten(c), yaw=r.uniform(-8, 8))
        y += h


def fan_coral(k, r, g):
    c = r.choice((PURPLE, PINK, ORANGE))
    k.box(0, 0, 0, 16, 7, 12, ROCK)
    for i, (x, roll, length, w) in enumerate(((0, 0, 38, 17), (-5, 27, 33, 14), (5, -27, 33, 14), (-9, 52, 24, 11), (9, -52, 24, 11))):
        k.beam((x, 6, 0), w, length, 3.6 - 0.1 * i, c if i % 2 == 0 else lighten(c), roll=roll)


def sea_stack(k, r, g):
    y, yaw = 0.0, r.uniform(0, 40)
    for i, (w, h, d) in enumerate(((30, 18, 26), (25, 16, 21), (19, 15, 17), (13, 12, 12))):
        k.box(r.uniform(-1.5, 1.5), y, r.uniform(-1.5, 1.5), w, h, d, ROCK if i % 2 == 0 else lighten(ROCK, 1.06, 8), yaw=yaw + r.uniform(-14, 14))
        y += h
    k.box(0, y, 0, 15, 3.5, 14, g, yaw=yaw)  # the land's own colour on top, as on the walls


def giant_clam(k, r, g):
    c = r.choice((PURPLE, TEAL))
    k.box(0, 0, 0, 34, 9, 26, darken(c, 0.7))
    k.box(0, 9, 1, 28, 2.5, 20, lighten(c, 1.2, 30))  # the mantle
    k.box(0, 11.5, 2, 7, 7, 7, WHITE)  # the pearl
    for i in range(5):
        k.box(-13.6 + i * 6.8, 9, 12, 6, 5 if i % 2 else 8, 5, darken(c, 0.7))
    tip = k.beam((0, 8, -11), 34, 26, 6, darken(c, 0.78), pitch=-24)
    for i in range(5):
        k.beam((-13.6 + i * 6.8, tip[1] - 1, tip[2] + 1), 6, 5 if i % 2 else 8, 5, darken(c, 0.7), pitch=-24)


def anemone(k, r, g):
    c = r.choice((PURPLE, PINK, TEAL))
    k.box(0, 0, 0, 24, 20, 24, darken(c, 0.82))
    k.box(0, 20, 0, 29, 4, 29, c)
    for i in range(10):
        a = i * 36 + r.uniform(-6, 6)
        foot = turn((0, 23, 10), yaw=a)
        tip = k.beam(foot, 5, r.uniform(20, 28), 5, lighten(c), pitch=r.uniform(20, 34), yaw=a)
        k.box(tip[0], tip[1] - 1, tip[2], 6, 3, 6, YELLOW)


def coral_tree(k, r, g):
    c = r.choice((ORANGE, PINK, TEAL))
    tip = k.beam((0, 0, 0), 11, 20, 11, darken(c, 0.85), roll=r.uniform(-4, 4))
    for pitch, roll in ((0, 36), (0, -34), (32, 4), (-30, -6)):
        t2 = k.beam((tip[0], tip[1] - 3, tip[2]), 7.5, r.uniform(20, 26), 7.5, c, pitch=pitch, roll=roll)
        for extra in (-24, 22):
            t3 = k.beam((t2[0], t2[1] - 2, t2[2]), 5, r.uniform(12, 17), 5, lighten(c), pitch=pitch * 0.5 + (extra if pitch else 0), roll=roll * 0.5 + (0 if pitch else extra))
            k.box(t3[0], t3[1] - 1, t3[2], 6, 3, 6, lighten(c, 1.2, 30))


def tube_cluster(k, r, g):
    c = r.choice((YELLOW, TEAL, PURPLE))
    for i in range(8):
        a, rad = i * 47.0, 0 if i == 0 else 9 + 4 * (i % 3)
        x, z = rad * math.cos(math.radians(a)), rad * math.sin(math.radians(a))
        w, h = r.uniform(8, 11), r.uniform(18, 48) if i else 50
        k.box(x, 0, z, w, h, w, c if i % 2 == 0 else lighten(c), yaw=r.uniform(0, 30))
        k.box(x, h, z, w - 3.5, 0.7, w - 3.5, DARK, n="Mouth")


def reef_wall(k, r, g):
    c = r.choice((PINK, ORANGE, PURPLE))
    for i, h in enumerate((22, 36, 28, 42, 20)):
        x = -34 + i * 17
        k.box(x, 0, r.uniform(-2, 2), 18, h, r.uniform(15, 20), ROCK if i % 2 else lighten(ROCK, 1.05, 8), yaw=r.uniform(-7, 7))
        k.box(x, h, 0, 19, 3.5, 18, g)
        if i in (1, 3):
            k.beam((x, h + 3, 0), 13, 18, 3.4, c, roll=r.uniform(-12, 12))
            k.beam((x - 5, h + 3, 0), 9, 13, 3.2, lighten(c), roll=30)


def table_coral(k, r, g):  # low and small: for the terraces, where nothing swims
    c = r.choice((TEAL, ORANGE, PINK))
    k.box(0, 0, 0, 6, 10, 6, darken(c, 0.8))
    k.box(0, 10, 0, 26, 4, 22, c, yaw=r.uniform(0, 30))
    k.box(3, 14, 2, 16, 3.5, 13, lighten(c), yaw=r.uniform(0, 30))


# ---------------------------------------------------------------- sea plants (Kelp Forest, and anywhere)
def stalk(k, r, x, z, height, thick=4.6, blade=16):
    foot, side = (x, 0, z), r.choice((-1, 1))
    for i in range(max(3, int(height / 12))):
        foot = k.beam(foot, thick, 12.5, thick, KELP_DARK if i % 2 else darken(KELP, 0.86), pitch=r.uniform(-7, 7), roll=r.uniform(-7, 7))
        if i > 0:
            k.beam((foot[0], foot[1] - 2, foot[2]), blade * 0.44, blade, thick * 0.5, KELP if i % 2 else lighten(KELP), roll=side * r.uniform(55, 72), yaw=r.uniform(-30, 30), n="Blade")
            side = -side
    k.beam(foot, thick * 1.6, blade * 0.8, thick * 0.6, lighten(KELP, 1.15, 20), roll=r.uniform(-10, 10), n="Blade")


def kelp_grove(k, r, g):
    k.box(2, 0, -3, 20, 9, 16, ROCK, yaw=r.uniform(0, 40))
    for x, z, h in ((0, 4, 96), (11, -4, 72), (-12, -2, 84), (6, 12, 60), (-7, 11, 66)):
        stalk(k, r, x, z, h * r.uniform(0.9, 1.1))


def kelp_giant(k, r, g):
    k.box(0, 0, 0, 18, 6, 18, darken(KELP, 0.6))
    stalk(k, r, 0, 0, 112, thick=9.5, blade=28)


def mossy_boulder(k, r, g):
    yaw = r.uniform(0, 40)
    k.box(0, 0, 0, 34, 18, 28, ROCK, yaw=yaw)
    k.box(3, 18, -2, 24, 13, 21, lighten(ROCK, 1.06, 8), yaw=yaw + 16)
    k.box(3, 31, -2, 26, 3.5, 23, g, yaw=yaw + 16)
    k.box(-12, 18, 6, 9, 3, 9, g, yaw=yaw)
    stalk(k, r, 4, -3, 30, thick=3.4, blade=11)


def sea_grass(k, r, g):  # small dressing
    for x, z, h in ((-1.6, 0, 6), (0, 0.8, 9), (1.7, -0.5, 5)):
        k.beam((x, 0, z), 1.3, h, 1.3, KELP if h < 8 else lighten(KELP), roll=r.uniform(-8, 8))


def stones(k, r, g):  # small dressing
    k.box(0, 0, 0, 3.2, 2.4, 2.8, ROCK, yaw=r.uniform(0, 90))
    k.box(3.4, 0, 1.2, 2, 1.5, 2, lighten(ROCK), yaw=r.uniform(0, 90))


def floor_tiles(k, r, g):  # small dressing: a flat patch of colour
    c = r.choice((PINK, YELLOW, PURPLE, WHITE))
    for x, z in ((0, 0), (2.4, 0), (-2.4, 0), (0, 2.4), (0, -2.4)):
        k.box(x, 0, z, 2.4, 0.5, 2.4, c if (x or z) else lighten(c))


# ---------------------------------------------------------------- wrecks (Shipwrecks)
def hull(k, r, g):
    k.box(0, 0, 0, 9, 6, 112, WOOD_DARK, n="Keel")
    for z in range(-48, 49, 12):
        for side in (-1, 1):
            h = r.choice((36, 36, 32, 20, 9))
            tip = k.beam((side * 4, 4, z), 5, 15, 5, WOOD, roll=-side * 62, n="Rib")
            k.beam((tip[0], tip[1] - 1.5, tip[2]), 5, h, 5, WOOD if h > 20 else WOOD_DARK, roll=-side * 10, n="Rib")
    for side in (-1, 1):
        for z0 in (-42, -6, 30):
            if r.random() < 0.7:
                k.box(side * 18.5, 11, z0, 2.6, 10, 30, WOOD_DARK, n="Plank")
                k.box(side * 20.4, 22, z0 + 3, 2.6, 9, 24, WOOD, n="Plank")
    k.box(0, 4, -58, 30, 24, 12, WOOD_DARK, n="Stern")
    k.box(0, 28, -58, 24, 4, 14, WOOD, n="Stern")
    k.beam((0, 4, 54), 7, 44, 7, WOOD_DARK, pitch=28, n="Bow")
    tip = k.beam((0, 5, 8), 7.5, 74, 7.5, WOOD, pitch=-16, roll=9, n="Mast")
    k.beam((tip[0] + 21, tip[1] - 13, tip[2]), 4, 44, 4, WOOD_DARK, pitch=-16, roll=99, n="Yard")
    k.box(tip[0], tip[1] - 30, tip[2] - 8, 12, 5, 12, WOOD_DARK, n="Nest")


def anchor(k, r, g):
    lean = 16
    tip = k.beam((0, 0, 0), 6, 46, 6, IRON, roll=lean)
    k.box(tip[0], tip[1], tip[2], 10, 10, 3, darken(IRON, 0.8), n="Ring")
    cross = turn((0, 37, 0), roll=lean)
    k.beam((cross[0] + 13, cross[1] + 4, 0), 4, 28, 4, WOOD_DARK, roll=lean + 90, n="Stock")
    for side in (-1, 1):
        t = k.beam((0, 1, 0), 6, 20, 6, IRON, roll=lean - side * 62)
        k.beam((t[0], t[1] - 2, t[2]), 9, 9, 5, darken(IRON, 0.8), roll=lean - side * 20)


def crates(k, r, g):
    for x, y, z, yaw in ((-7, 0, 0, 8), (6, 0, 2, -12), (0, 0, -12, 30), (-2, 12, -1, 20), (5, 12, -9, -8)):
        k.box(x, y, z, 12, 12, 12, WOOD if (x + y) % 2 else lighten(WOOD, 1.08, 6), yaw=yaw)
    k.box(16, 0, -8, 9, 13, 9, WOOD_DARK, yaw=20, n="Barrel")
    k.box(16, 4, -8, 10, 2, 10, IRON, yaw=20, n="Hoop")


def mast(k, r, g):
    k.box(0, 0, 0, 16, 8, 16, WOOD_DARK)
    tip = k.beam((0, 6, 0), 8, 92, 8, WOOD, pitch=r.uniform(8, 18), roll=r.uniform(-10, 10))
    k.beam((tip[0] + 24, tip[1] - 22, tip[2]), 4.5, 50, 4.5, WOOD_DARK, roll=90, n="Yard")
    k.box(tip[0], tip[1] - 38, tip[2] - 2, 14, 6, 14, WOOD_DARK, n="Nest")
    k.box(tip[0] + 10, tip[1] - 46, tip[2], 20, 22, 1.2, (226, 216, 196), n="Sail")


# ---------------------------------------------------------------- bones (Bone Graveyard)
def ribs(k, r, g):
    for i in range(9):
        z = -48 + i * 12
        k.box(0, 0, z, 10, 9, 9.5, BONE if i % 2 == 0 else BONE_SHADE, n="Vertebra")
        if 0 < i < 8:
            f = 1.0 - 0.1 * abs(i - 4)
            for side in (-1, 1):
                if r.random() < 0.12:
                    continue  # a rib long gone
                t = k.beam((side * 5, 5, z), 5.5, 22 * f, 5.5, BONE, roll=-side * 54, n="Rib")
                t = k.beam((t[0], t[1] - 1.5, t[2]), 5, 30 * f, 5, BONE, roll=-side * 6, n="Rib")
                k.beam((t[0], t[1] - 1.5, t[2]), 4.4, 16 * f, 4.4, BONE_SHADE, roll=side * 34, n="Rib")


def skull(k, r, g):
    k.box(0, 0, 18, 32, 7, 62, BONE_SHADE, n="Jaw")
    k.box(0, 7, -6, 46, 32, 50, BONE, n="Cranium")
    k.box(0, 12, 34, 36, 20, 34, BONE, n="Snout")
    k.box(0, 39, -8, 30, 4, 34, lighten(BONE, 1.04, 6), n="Crown")
    for side in (-1, 1):
        k.box(side * 23.2, 22, 6, 1.2, 11, 13, DARK, n="Socket")
        k.box(side * 8, 26, 51.2, 5, 5, 1.2, DARK, n="Nostril")
        for i in range(5):
            k.box(side * 14, 7, 22 + i * 6.4, 3.6, 6 if i % 2 else 8, 3.6, WHITE, n="Tooth")
        tip = k.beam((side * 16, 36, -22), 7, 20, 7, BONE_SHADE, pitch=-20, roll=-side * 42, n="Horn")
        k.beam((tip[0], tip[1] - 1.5, tip[2]), 5, 14, 5, BONE, pitch=-34, roll=-side * 12, n="Horn")


def bone_pillar(k, r, g):
    k.box(0, 0, 0, 19, 10, 15, BONE_SHADE)
    tip = k.beam((0, 6, 0), 11, 62, 11, BONE, pitch=r.uniform(-6, 6), roll=r.uniform(4, 10))
    k.box(tip[0] - 4.5, tip[1] - 4, tip[2], 10, 10, 13, BONE_SHADE)
    k.box(tip[0] + 4.5, tip[1] - 2, tip[2], 10, 10, 13, BONE)


ASSETS = {  # name: (builder, size class, what it is)
    "pillar_coral": (pillar_coral, "big", "pillar coral"), "brain_coral": (brain_coral, "big", "brain coral"),
    "fan_coral": (fan_coral, "big", "sea fan"), "sea_stack": (sea_stack, "big", "rock stack"),
    "giant_clam": (giant_clam, "big", "giant clam"), "anemone": (anemone, "big", "giant anemone"),
    "coral_tree": (coral_tree, "big", "staghorn tree"), "tube_cluster": (tube_cluster, "big", "tube coral"),
    "reef_wall": (reef_wall, "big", "reef ridge"), "table_coral": (table_coral, "mid", "table coral"),
    "kelp_grove": (kelp_grove, "big", "kelp grove"), "kelp_giant": (kelp_giant, "big", "giant kelp"),
    "mossy_boulder": (mossy_boulder, "big", "mossy boulder"),
    "hull": (hull, "huge", "broken hull"), "anchor": (anchor, "big", "anchor"), "crates": (crates, "mid", "cargo"), "mast": (mast, "big", "broken mast"),
    "ribs": (ribs, "huge", "ribcage"), "skull": (skull, "huge", "skull"), "bone_pillar": (bone_pillar, "big", "standing bone"),
    "sea_grass": (sea_grass, "small", "sea grass"), "stones": (stones, "small", "stones"), "floor_tiles": (floor_tiles, "small", "flat patch"),
}
LANDS = {  # which big things stand in which land (by the land's number, from 0); the last is used from there on
    0: ["pillar_coral", "sea_stack", "fan_coral", "brain_coral", "giant_clam", "anemone"],
    1: ["coral_tree", "tube_cluster", "reef_wall", "pillar_coral", "fan_coral", "anemone", "brain_coral"],
    2: ["kelp_grove", "kelp_giant", "mossy_boulder", "kelp_grove", "sea_stack"],
    3: ["hull", "mast", "anchor", "crates", "kelp_giant", "sea_stack"],
    4: ["ribs", "skull", "bone_pillar", "sea_stack"],
}
TERRACE = {0: ["table_coral", "sea_stack", "fan_coral"], 1: ["table_coral", "tube_cluster", "coral_tree"], 2: ["kelp_grove", "mossy_boulder"],
           3: ["crates", "mast", "kelp_giant"], 4: ["bone_pillar", "sea_stack"]}


def bricks(name, seed=0, ground=(242, 214, 128)):
    """an asset's bricks, foot first: [(name, centre, size, colour, axes)]"""
    k = Kit()
    ASSETS[name][0](k, random.Random(seed * 131 + len(name)), ground)
    return k.b


def extent(bs):
    """half width (x), height and half depth (z) of a list of bricks, counting how each leans"""
    hx = hy = hz = 0.0
    for _, p, s, _, ax in bs:
        rx = sum(abs(ax[i][0]) * s[i] / 2 for i in range(3))
        ry = sum(abs(ax[i][1]) * s[i] / 2 for i in range(3))
        rz = sum(abs(ax[i][2]) * s[i] / 2 for i in range(3))
        hx, hy, hz = max(hx, abs(p[0]) + rx), max(hy, p[1] + ry), max(hz, abs(p[2]) + rz)
    return hx, hy, hz


SHEET = [("Shallows", (242, 214, 128), ["pillar_coral", "sea_stack", "fan_coral", "brain_coral", "giant_clam", "anemone"]),
         ("Coral Reef", (244, 148, 152), ["coral_tree", "tube_cluster", "reef_wall", "table_coral"]),
         ("Kelp Forest", (120, 172, 92), ["kelp_grove", "kelp_giant", "mossy_boulder"]),
         ("Shipwrecks", (160, 148, 124), ["hull", "mast", "anchor", "crates"]),
         ("Bone Graveyard", (150, 150, 168), ["ribs", "skull", "bone_pillar"])]


def write_kit():
    parts, views, rows = [], {}, []

    def add(n, kind, p, s, c, ax=((1, 0, 0), (0, 1, 0), (0, 0, 1))):
        parts.append({"n": n, "k": kind, "p": [round(v, 2) for v in p], "x": [round(v, 4) for v in ax[0]], "y": [round(v, 4) for v in ax[1]],
                      "z": [round(v, 4) for v in ax[2]], "s": [round(v, 2) for v in s], "c": list(c), "solid": True})

    for row, (land, ground, names) in enumerate(SHEET):
        z0, x, labels, tallest = row * 9000.0, 30.0, [], 0.0  # rows far apart, so none shows behind another
        add("Fish", "figure", (10, 11, z0 + 20), (3.2, 3.6, 13), (245, 130, 42))  # a rider on a 13-stud fish, 10 off the floor
        add("Rider", "figure", (10, 15.3, z0 + 21), (2, 5, 1), (90, 170, 230))
        for name in names:
            turned = 90 if name in ("hull", "ribs") else (55 if name == "skull" else 0)  # long things shown side on
            bs = bricks(name, 1, ground)
            hx, hy, hz = extent(bs)
            half = hz if turned == 90 else max(hx, hz) if turned else hx
            tallest = max(tallest, hy)
            x += half + 14
            for n, p, s, c, ax in bs:
                q = turn(p, yaw=turned)
                add(n, "prop", (x + q[0], q[1], z0 + q[2]), s, c, tuple(turn(a, yaw=turned) for a in ax))
            labels.append(f"{ASSETS[name][2]}: {round(hy)} tall, {len(bs)} pieces")
            x += half + 14
        add("Ground", "ground", (x / 2, -2, z0), (x + 400, 4, 900), ground)
        dist = max((x + 30) * 1.02, tallest * 2.5)
        views[land] = {"eye": [x / 2, tallest * 0.5 + 16, z0 + dist], "target": [x / 2, tallest * 0.42, z0], "fov": 30}
        rows.append({"land": land, "labels": labels})
    os.makedirs(OUT, exist_ok=True)
    json.dump({"parts": parts, "views": views, "rows": rows}, open(os.path.join(OUT, "kit.json"), "w"))
    print(len(parts), "boxes in the kit sheet;", sum(len(r["labels"]) for r in rows), "assets")


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    kit = json.load(open(os.path.join(OUT, "kit.json")))
    bold, plain = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22), ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 17)
    w, h, pad, cap = 1280, 720, 14, 86
    out = Image.new("RGB", (w + 2 * pad, 54 + len(kit["rows"]) * (h + cap + pad)), (254, 248, 241))
    d = ImageDraw.Draw(out)
    d.text((pad, 12), "Map assets, first pass (2026-11-10): big things to steer round, a set per land. Loose boxes, Blender, not Roblox.", font=bold, fill=(30, 30, 30))
    for i, row in enumerate(kit["rows"]):
        y = 54 + i * (h + cap + pad)
        im = Image.open(os.path.join(OUT, "renders", row["land"] + ".png")).convert("RGB")
        out.paste(im, (pad, y))
        d.text((pad + 2, y + h + 6), row["land"] + "  (the orange block is a rider on a 13-stud fish)", font=bold, fill=(40, 40, 40))
        half = (len(row["labels"]) + 1) // 2 if len(row["labels"]) > 4 else len(row["labels"])
        d.text((pad + 2, y + h + 34), "Left to right: " + ";  ".join(row["labels"][:half]), font=plain, fill=(60, 60, 60))
        d.text((pad + 2, y + h + 56), ";  ".join(row["labels"][half:]), font=plain, fill=(60, 60, 60))
    path = os.path.join(ROOT, "docs", "attachments", "map-props-kit.jpg")
    out.save(path, quality=88)
    print(path)


if __name__ == "__main__":
    sheet() if "--sheet" in sys.argv else write_kit()
