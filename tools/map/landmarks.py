"""Drafts of far landmarks for the later lands, seen from the spawn (2026-11-18, the user: "make the silhouette of them
from the spawn look imposing, ice crystals slanted, cool galactic rubble or large spiky things and structures that
have a visible silhouette"). Not in the game: writes a copy of the grey-box's hub and first stretch of lane with the
landmarks added, for tools/blender/map_greybox_view.py, into art/map/landmark_drafts/<variant>/.

usage: python tools/map/landmarks.py
       for v in ...: GREYBOX_OUT=art/map/landmark_drafts/$v blender --background --python tools/blender/map_greybox_view.py -- spawn
(the view "spawn" is added by this draft to path.json's copy; see the README in that folder)

Each landmark is a few huge boxes, the same build rule as the props (loose pieces, two or three tones, light at the
tips), so a land's small props can echo its landmark. They stand on fake ground far out where the sea's surface is,
so they rise out of the water past the gate and over the hub's walls."""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "map", "greybox")
OUT = os.path.join(ROOT, "art", "map", "landmark_drafts")


def prism_axes(spin, pitch, roll, yaw):
    """a box's axes: first spun about its own long axis (so a square prism shows an edge, a crystal's look), then
    leaned, then turned"""
    base = [props.turn(v, yaw=spin) for v in ((1, 0, 0), (0, 1, 0), (0, 0, 1))]
    return tuple(props.turn(v, pitch, yaw, roll) for v in base)


class K:
    def __init__(self):
        self.b = []

    def piece(self, centre, size, colour, ax, kind="prop"):
        self.b.append((centre, size, colour, ax, kind))

    def beam(self, foot, w, length, colour, spin=45, pitch=0.0, roll=0.0, yaw=0.0, kind="prop"):
        ax = prism_axes(spin, pitch, roll, yaw)
        up = ax[1]
        self.piece(tuple(foot[i] + up[i] * length / 2 for i in range(3)), (w, length, w), colour, ax, kind)
        return tuple(foot[i] + up[i] * length for i in range(3))


def crystal(k, foot, w, h, lean, yaw, tones):
    """a slanted crystal: a dark root, a body, a light upper segment and a tapering tip, each a loose piece"""
    t = k.beam(foot, w, h * 0.45, tones[0], pitch=lean, yaw=yaw)
    t = k.beam(t, w * 0.92, h * 0.35, tones[1], pitch=lean, yaw=yaw)
    t = k.beam(t, w * 0.7, h * 0.14, tones[2], pitch=lean, yaw=yaw)
    k.beam(t, w * 0.38, h * 0.08, tones[3], pitch=lean, yaw=yaw, kind="glow")


def ice_field(k, x0, z0, s, r):
    """the hero: one tall crystal leaning out, two seconds, a skirt of small ones, all leaning one way (a grain)"""
    tones = [(70, 78, 150), (118, 140, 214), (186, 214, 250), (240, 252, 255)]
    lean, yaw = 24, -20
    for dx, dz, w, h, dl in ((0, 0, 70, 640, 0), (-120, 40, 52, 430, -6), (110, -30, 46, 380, 5), (-60, -90, 34, 250, 8), (190, 60, 30, 210, -4),
                             (-200, -20, 28, 170, 10), (60, 110, 26, 160, 3), (-150, 120, 22, 120, -8), (240, -80, 22, 110, 6)):
        crystal(k, (x0 + dx * s, -20, z0 + dz * s), w * s, h * s, lean + dl + r.uniform(-3, 3), yaw + r.uniform(-8, 8), tones)


def vent_spires(k, x0, z0, s, r):
    """three leaning black chimneys of stacked blocks, glowing seams, a smoke column"""
    rock, seam, smoke = (58, 40, 48), (255, 120, 60), (150, 120, 120)
    for dx, h, lean in ((0, 520, 8), (-140, 380, -10), (130, 300, 14)):
        foot, w = (x0 + dx * s, -20, z0), 64 * s
        for i in range(int(h / 60)):
            foot = k.beam(foot, w * (1 - 0.06 * i), 60 * s, rock if i % 3 else props.lighten(rock, 1.2, 6), spin=r.uniform(-15, 15), roll=lean + r.uniform(-4, 4))
            if i % 2:
                k.piece(foot, (w * 1.02, 4 * s, w * 1.02), seam, prism_axes(r.uniform(-15, 15), 0, lean, 0), "glow")
        for j in range(7):  # smoke: big pale blocks drifting up and to one side
            k.piece((foot[0] + j * 30 * s, foot[1] + 60 * s + j * 70 * s, foot[2]), (60 * s * (1 + j * 0.15),) * 3, props.lighten(smoke, 1.0, j * 10), prism_axes(r.uniform(0, 90), r.uniform(-20, 20), r.uniform(-20, 20), 0))


def rib_arch(k, x0, z0, s, r):
    """a giant's ribs arching out of the sea: a spine of blocks, six rib pairs of three segments"""
    bone, shade = (236, 228, 205), (196, 186, 160)
    for i in range(7):
        z = z0 + (i - 3) * 70 * s
        k.piece((x0, 30 * s, z), (40 * s, 40 * s, 44 * s), shade, prism_axes(0, 0, 0, 0))
        if 0 < i < 7:
            f = 1 - 0.12 * abs(i - 3)
            for side in (-1, 1):
                t = k.beam((x0 + side * 20 * s, 40 * s, z), 26 * s, 180 * s * f, bone, spin=0, roll=-side * 28)
                t = k.beam(t, 22 * s, 170 * s * f, bone, spin=0, roll=side * 18)
                k.beam(t, 18 * s, 110 * s * f, shade, spin=0, roll=side * 62)


def rubble_streak(k, x0, z0, s, r):
    """galactic rubble: a cracked star-rock high in the sky, its broken pieces strung out in a falling line toward
    the far end of the dive, the nearer ones bigger; violet cores glow through the cracks"""
    rock, rim, core = (70, 56, 110), (130, 110, 190), (255, 120, 255)
    big = (x0, 900 * s, z0)
    for dx, dy, dz, w in ((0, 0, 0, 260), (150, 60, 20, 140), (-120, -80, 40, 120), (60, -170, -30, 100)):
        k.piece((big[0] + dx * s, big[1] + dy * s, big[2] + dz * s), (w * s, w * s * 0.8, w * s * 0.9), rock if w > 200 else rim, prism_axes(r.uniform(0, 90), r.uniform(-30, 30), r.uniform(-30, 30), 0))
    k.piece(big, (150 * s, 150 * s, 150 * s), core, prism_axes(30, 20, 10, 0), "glow")
    for j in range(16):  # the trail: falling away down to the horizon, smaller as it goes
        f = j / 15
        w = (110 - 80 * f) * s * r.uniform(0.7, 1.2)
        p = (x0 - (300 + 1400 * f) * s + r.uniform(-60, 60) * s, (760 - 640 * f) * s + r.uniform(-50, 50) * s, z0 + (200 + 1500 * f) * s)
        k.piece(p, (w, w * 0.7, w * 0.85), rock if j % 3 else rim, prism_axes(r.uniform(0, 90), r.uniform(-40, 40), r.uniform(-40, 40), 0))
        if j % 4 == 1:
            k.piece(p, (w * 0.5,) * 3, core, prism_axes(10, 20, 30, 0), "glow")


VARIANTS = {  # name: [(builder, x, z, scale)] in the hub's frame (the gate at z = -48, the lane along +z)
    "ice": [(ice_field, -260, 1800, 1.0)],
    "spires": [(vent_spires, 300, 1600, 1.0)],
    "string": [(ice_field, -150, 1400, 1.3), (vent_spires, 260, 2300, 1.9), (rib_arch, 520, 3000, 2.6), (rubble_streak, -420, 2600, 3.0)],
    "rubble": [(rubble_streak, 500, 2400, 1.0)],
}


def main():
    parts = json.load(open(os.path.join(SRC, "parts.json")))["parts"]
    path = json.load(open(os.path.join(SRC, "path.json")))
    keep = [p for p in parts if -500 < p["p"][2] < 2600 and abs(p["p"][0]) < 1600]
    for name, items in VARIANTS.items():
        k = K()
        for i, (fn, x, z, s) in enumerate(items):
            fn(k, x, z, s, random.Random(7 + i))
        add = [{"n": "Landmark", "k": kind, "p": [round(v, 2) for v in c], "x": list(ax[0]), "y": list(ax[1]), "z": list(ax[2]), "s": [round(v, 2) for v in sz],
                "c": list(col), "solid": False} for c, sz, col, ax, kind in k.b]
        # the sea past the lane's walls, to where the landmarks stand: a flat surface at y = 0
        add.append({"n": "FarSea", "k": "water", "p": [0, -1, 3000], "x": [1, 0, 0], "y": [0, 1, 0], "z": [0, 0, 1], "s": [12000, 2, 6000], "c": [64, 190, 210], "solid": False})
        out = os.path.join(OUT, name)
        os.makedirs(out, exist_ok=True)
        json.dump({"parts": keep + add}, open(os.path.join(out, "parts.json"), "w"))
        json.dump(path, open(os.path.join(out, "path.json"), "w"))
        print(name, len(add), "landmark pieces")


if __name__ == "__main__":
    main()
