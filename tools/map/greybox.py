"""Grey-box 15 of the map (docs/design/map-method.md, docs/design/map-structure.md): the reference's build, shaped for a
game where you fly through water.

The lane goes narrow, wide, narrow, wide, its two sides waving against each other, and it gets wider the further you
go. The first land runs straight and plain; the bends begin after it. The floor is one smooth surface: no steps and no
drops, the slope easing a little steeper land by land, with a longer steep stretch where a big drop used to be. Every
edge has a wall of some kind, because a swimmer can go anywhere a walker can't: a low terrace under a tall wall, broad
steps climbing away, or a low rim with the ground falling away behind it for a view; and over all of them an unseen
barrier up to the surface. Walls are built the reference's way: pieces a whole number of squares long, so the picture's
squares follow every curve; grass a square thick; heights in whole squares. Big assets stand in the lane
(tools/map/props.py). The hub is a closed bowl level with the water.

usage: python tools/map/greybox.py            writes art/map/greybox/parts.json (every box), path.json (for the game
                                               code) and docs/attachments/map-greybox-plan.png (from above)
Pictures: blender --background --python tools/blender/map_greybox_view.py; into Studio: tools/map/greybox_luau.py

Axes are Roblox's: y up, the sea surface at y = 0, the hub behind z = 0, the lane leaving along +z. A part is
{n: name, k: kind, p: centre, x/y/z: its three axes (unit vectors), s: size along them, c: colour, solid: bool}.
Kinds: ground (the floor's tiles), plain (ground turned with the lane: the fall behind a rim), hub (the hub's floor),
face (a wall's side), grass (a wall's top slab), fill (the filling behind a hollow curve, its top grass), core (hidden), barrier (unseen, solid), far (the backdrop),
glass, prop, trim, station, figure, water. Everything is a plain box. Nothing here is tuned yet."""
import json
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402
import props2  # noqa: E402
import setpieces  # noqa: E402
import water_zones  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("GREYBOX_OUT") or os.path.join(ROOT, "art", "map", "greybox")  # a trial build can go elsewhere
# PROPS2=1: stage 2 of docs/design/before-the-push.md, a trial: every land's rebuilt props (tools/map/props2.py) spread in
# clusters, the walls dressed (lip rows, first-layer tall pieces, shelves on the faces), set pieces for the later lands
# (tools/map/setpieces.py), sagging bunting on posts and wavy land borders. Off, nothing changes.
PROPS2 = os.environ.get("PROPS2") == "1"

# ---------------------------------------------------------------- the numbers
PINCH = 60.0  # how close a side comes to the lane's line where it pinches in, at the start of the dive
BULGE_BIG, BULGE_SMALL = (120.0, 180.0), (60.0, 100.0)  # how far a side swells between two of its pinches
BULGE_FIRST = (30.0, 55.0)  # and in the first land: a plain, easy run
WIDER = 2.0  # the lane is 1 + WIDER times as wide at the very end of the dive as at its start
ROOM = (420.0, 700.0)  # the distance between one side's pinches
OFFSET = (0.24, 0.42)  # the other side pinches this share of a room further on (or back)
# The way out of the hub, as the reference has it: a narrow gate in the hub's wall, and the lane's walls curving away
# just behind it. From the hub you see a narrow, easy-to-read opening; a few strides in, the lane has opened out.
GATE = 48.0  # half the gate's width: the gap in the hub's wall, and the start strip that lies in it. 72 until
# 2026-11-17, when the user asked for it narrower and "more blocked off but not entirely", as the reference's is
WIDEN = 42.0  # how much wider each side is, on top of the lane's own shape, just inside the gate,
WIDEN_BY = 110.0  # reached this far in,
WIDEN_TO = 330.0  # and given back by here (the first neck)
GATE_TURN = 17.0  # (24 until S, 2026-11-23) the wall turns from the hub's front into the gate round a corner this big (the tall wall behind
# it turns on a corner HUB_LEDGE_GATE smaller, so this has to be over that for that one to be round too). 48 until
# 2026-11-17: the user wanted the cliffs either side of the gate to "curve in less"
FRONT_TURN = 8.0  # (40 until S, 2026-11-23) and the hub's front corners are this round (80 until 2026-11-17: the front wall bent toward the
# gate like a funnel; now it runs straight across, as the reference's does)
FILLET = 34.0  # a set-back tier's sharp corner near the gate is rounded over this much of its line each way
START_DEPTH = 46.0  # under the start: a jump needs 38 studs of water over the floor (riding chat)
EASE = 300.0  # a change of slope is spread over this much lane
PLINTH = 60.0  # how thick the lane's body is
BUILD_TO = 23500.0  # how much to build: all ten lands (2026-11-11: the user wants the feel of the whole)
FINE_TO = 23500.0  # up to here walls are in pieces PIECE long; past it, twice that (now the whole dive is fine)
SEG = 24.0  # shoulders, barriers and the backdrop are cut into pieces this long
TILE = 64.0  # the floor's biggest tile: eight squares each way. Where the floor bends it is cut in four, and again
SQUARE = 8.0  # a square of the pattern. 5 (a player tall, as measured) read too small in Studio: the user, 2026-11-11
PIECE = 16.0  # a piece of wall: two squares, one tile of the picture, so the squares follow the curve
GRASS = 8.0  # the grass slab: a square thick
PROUD = 1.5  # how far it stands out past the wall's face
WAVE = 5  # pieces between changes of a wall's height
CAP = 4.0  # the backdrop's top slab
# name, length, slope in degrees
LANDS = [("Shallows", 1000, 2.0), ("Coral Reef", 2500, 2.5), ("Kelp Forest", 2500, 3.0), ("Shipwrecks", 2500, 4.0),
         ("Open Blue", 2500, 4.5), ("Twilight", 2500, 5.0), ("Midnight", 2500, 6.0), ("Vents", 2500, 6.5),
         ("Bone Graveyard", 2500, 7.0), ("The Underworld", 2500, 8.0)]
STEEPER = {4: (12.0, 700.0), 7: (14.0, 900.0)}  # at the start of these lands (counted from 0): a stretch easing up to
# this slope and back over this length. They stand where the big drops were: a long steeper slope, never a drop.
GROUND = water_zones.GROUND  # one colour per land (kept with the lands' water, so the two are chosen together)
FACES = water_zones.FACES  # each land's wall side (2026-11-19, the colour proposal; before: the floor's colour pulled toward grey, face_of)
if os.environ.get("PALETTE"):  # a trial palette (art/map/palettes/*.json; docs/design/colour.md): floors and wall sides per land
    _pal = json.load(open(os.environ["PALETTE"]))["lands"]
    _rgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))  # noqa: E731
    GROUND = [_rgb(l["floor"]) for l in _pal]
    FACES = [_rgb(l["face"]) for l in _pal]
ASSET_SET = [0, 1, 2, 3, 0, 1, 2, 3, 4, 4]  # which of props.LANDS each land borrows: five lands have no set of their own yet
# the hub's colours: its floor, its walls' faces and tops, the start strip, the aquariums' frames. HUB_LOOK picks one
# (an environment variable, for trying them side by side: tools/map/hub_looks.py); "Dino" is what is built
HUB_LOOKS = {
    # Ride a Dino's own hub colours, one to one (the user, 2026-11-11: "for now for the hub"). Sampled from sunlit
    # places in the recordings: the green floor, the paler yellow-green grass, the pale grey-green wall face, the sand
    # start strip, the pens' sand and their wooden fences (our aquariums' frames)
    # Those are the colours as they look on screen there (floor 83, 214, 100; grass 136, 220, 67; wall 199, 207, 179;
    # strip 222, 217, 174; pen sand 206, 190, 124; fence 166, 128, 68). The game's light lifts and deepens a part's colour,
    # so the parts are a little darker and less blue: found with swatches in Studio (2026-11-12) for the floor and grass,
    # reckoned for the rest
    "Dino": {"floor": (105, 185, 85), "face": (178, 185, 160), "top": (135, 200, 62), "strip": (198, 194, 155), "frame": (150, 116, 62), "pad": (184, 170, 110)},
    "Beach": {"floor": (242, 214, 128), "face": None, "top": (242, 214, 128), "strip": (250, 246, 230), "frame": (58, 66, 88)},
    "Lagoon": {"floor": (240, 218, 152), "face": (236, 232, 220), "top": (112, 190, 96), "strip": (255, 255, 255), "frame": (40, 70, 120)},
    "Coral": {"floor": (248, 222, 192), "face": (236, 150, 140), "top": (130, 214, 190), "strip": (255, 244, 226), "frame": (30, 90, 100)},
    "Pool": {"floor": (190, 232, 236), "face": (240, 244, 248), "top": (60, 190, 200), "strip": (252, 214, 90), "frame": (36, 60, 110)},
    "Boardwalk": {"floor": (198, 152, 104), "face": (70, 96, 140), "top": (244, 236, 214), "strip": (240, 90, 80), "frame": (90, 62, 44)},
    # variations on Coral (the user, 2026-11-11: coral walls and seafoam tops work; the ground should blend in more,
    # the accent should show, and maybe a bit more brown)
    "CoralSand": {"floor": (238, 204, 176), "face": (232, 140, 128), "top": (130, 214, 190), "strip": (40, 150, 150), "frame": (30, 110, 120)},
    "CoralBlush": {"floor": (240, 190, 170), "face": (228, 128, 120), "top": (130, 214, 190), "strip": (255, 244, 226), "frame": (30, 110, 120)},
    "CoralClay": {"floor": (206, 160, 128), "face": (226, 132, 116), "top": (130, 214, 190), "strip": (255, 240, 220), "frame": (92, 60, 50)},
    "Terracotta": {"floor": (226, 186, 150), "face": (198, 116, 92), "top": (120, 206, 184), "strip": (40, 150, 150), "frame": (92, 60, 50)},
    "Driftwood": {"floor": (184, 146, 116), "face": (212, 128, 108), "top": (96, 192, 172), "strip": (250, 236, 214), "frame": (78, 54, 46)},
}
HUB_LOOK = HUB_LOOKS[os.environ.get("HUB_LOOK", "Dino")]
HUB_GROUND = HUB_LOOK["floor"]
# a wall is up to three tiers going away from the lane, the same distances everywhere so a wall never breaks its line
TIER_BACK, TIER_DEEP = (0.0, 24.0, 56.0), (24.0, 32.0, 24.0)  # whole squares: 3, 4 and 3 deep
KIND = {  # each tier's height in squares under its grass; 0 = that tier isn't there
    "wall": (2, 9, 0),  # the reference's hub wall: a low terrace, then the tall wall
    "hill": (2, 5, 9),  # broad steps climbing away
    "rim": (1, 0, 0),  # a low shelf: the view out to the cliffs behind
}
# Behind every wall, two layers of cliff, and behind those nothing needs to be seen: the lane is a canyon in the sea's
# floor. Each: how far behind the wall's face; how round its line is made (no nose sharper); its height in squares over
# the lane's floor and how many squares it steps up or down; its height over the water round the hub; the highest it
# may stand over the water anywhere; how far its colour has gone toward the water's haze.
CLIFFS = [
    {"back": 96.0, "round": 260.0, "squares": 15, "step": 2, "hub": 112.0, "cap": 120.0, "pale": 0.35},
    {"back": 192.0, "round": 360.0, "squares": 27, "step": 3, "hub": 184.0, "cap": 200.0, "pale": 0.7},
]
CLIFF_PIECE = 64.0  # a piece of cliff: four tiles of the picture
CLIFF_WAVE = 4  # pieces between changes of a cliff's height
HUB_TIERS = (2, 9, 0)  # the hub's wall, in squares over the water: a low terrace and the tall wall (the reference's)
JOIN = 420.0  # over this much lane the hub's wall steps down to the lane's own heights


HAZE = (120, 175, 195)  # the water's colour far off: the backdrop is drawn half way to it, so it sits back


def face_of(ground, pale=0.0, haze=HAZE):
    """a wall's side: the land's colour pulled toward a mid grey, as the reference's faces are. `pale` (0 to 1) is for
    the cliffs behind: the same colour fading into that land's water"""
    near = [0.4 * g + 0.6 * 158 for g in ground]
    return tuple(int(n + (h - n) * 0.6 * pale) for n, h in zip(near, haze))


parts = []
count = {"ground": 0, "face": 0, "prop": 0, "big": 0, "ends": 0}


def add(name, kind, p, size, colour, ax=(1, 0, 0), ay=(0, 1, 0), az=(0, 0, 1), solid=True, t=0.0, v=0.0, tex=None):
    parts.append({"n": name, "k": kind, "p": [round(c, 2) for c in p], "x": [round(c, 4) for c in ax], "y": [round(c, 4) for c in ay],
                  "z": [round(c, 4) for c in az], "s": [round(abs(c), 2) for c in size], "c": list(colour), "solid": solid})
    if t:
        parts[-1]["t"] = t  # how see-through it is
    if v:
        parts[-1]["v"] = round(v, 2)  # how far the picture is slid up a side face, so rows of squares line up
    if tex:  # how the picture lies on its top and its side: studs to a tile and the slide, each way (see `cell`)
        parts[-1]["tex"] = {k: [round(c, 3) for c in vals] for k, vals in tex.items()}


def yawed(deg):
    a = math.radians(deg)
    return (math.cos(a), 0, -math.sin(a)), (0, 1, 0), (math.sin(a), 0, math.cos(a))


def frac(i, salt):
    """a steady pseudo-random number 0 to 1 for a whole number and a salt"""
    v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return v - math.floor(v)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def unit(v):
    m = math.sqrt(sum(c * c for c in v)) or 1.0
    return (v[0] / m, v[1] / m, v[2] / m)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- the descent: one smooth floor
starts, at = [], 0.0
for name, length, slope in LANDS:
    starts.append(at)
    at += length
TOTAL = at


def land_at(at):
    k = 0
    for i, st in enumerate(starts):
        if at >= st:
            k = i
    return k


def slope_at(at):
    """degrees down at a place along the lane: each land a little steeper, the change spread over EASE; and a longer
    steep stretch at the start of the lands in STEEPER"""
    deg = LANDS[0][2]
    for i in range(1, len(LANDS)):
        deg += (LANDS[i][2] - LANDS[i - 1][2]) * smooth((at - starts[i] + EASE / 2) / EASE)
    for i, (peak, long) in STEEPER.items():
        u = (at - starts[i]) / long
        if 0.0 < u < 1.0:
            deg += (peak - deg) * math.sin(math.pi * u) ** 2
    return deg


depths = [START_DEPTH]  # the floor's depth every stud along the lane
for k in range(int(TOTAL) + 400):
    depths.append(depths[-1] + math.tan(math.radians(slope_at(k + 0.5))))
profile = [(float(k), depths[k]) for k in range(0, int(TOTAL) + 1, 100)]

# ---------------------------------------------------------------- the rooms (by the left side's pinches)
rooms = []  # s0, s1, turn (degrees, taken at its far end), seed, land
rng = random.Random(20261110)
at = 0.0
for li, (name, length, _slope) in enumerate(LANDS):
    end = starts[li] + length
    here = at
    if li == 0:  # the Shallows: a short first room, then a long one
        rooms.append({"s0": at, "s1": at + 330.0, "land": 0})
        here = at + 330.0
    while end - here > ROOM[1]:
        step = rng.uniform(*ROOM)
        if end - (here + step) < ROOM[0] * 0.8:
            step = (end - here) / 2
        rooms.append({"s0": here, "s1": here + step, "land": li})
        here += step
    rooms.append({"s0": here, "s1": end, "land": li})
    at = end
    if at > BUILD_TO + 900:
        break
swing = 0.0
for i, room in enumerate(rooms):
    r = random.Random(1000 + i)
    turn = r.uniform(9, 22) * (-1 if swing > 0 else 1)
    if abs(swing) < 8:
        turn = r.uniform(9, 22) * r.choice((-1, 1))
    if room["land"] == 0:
        turn = 0.0  # the first land runs straight: the bends begin after it
    swing += turn
    room["turn"], room["seed"] = turn, i

# each side's own spans, pinch to pinch. The left pinches where the rooms end; the right a part of a room away.
spans = {-1: [], 1: []}
left_p = [0.0] + [room["s1"] for room in rooms]
right_p = [0.0]
for i, room in enumerate(rooms[:-1]):
    nxt = rooms[i + 1]
    r = random.Random(3000 + i)
    way = 1 if (i == 0 or r.random() < 0.6) else -1
    reach = (nxt["s1"] - nxt["s0"]) if way > 0 else (room["s1"] - room["s0"])
    # the first room is the same on both sides (the user, 2026-11-12: what is seen through the gate should stand in
    # symmetry); the two sides go out of step from the second room on
    right_p.append(room["s1"] if i == 0 else room["s1"] + way * r.uniform(*OFFSET) * reach)
right_p.append(rooms[-1]["s1"] + 200.0)
for side, pinches in ((-1, left_p), (1, right_p)):
    for i, (a, b) in enumerate(zip(pinches, pinches[1:])):
        r = random.Random(5000 + i * 2 + (side > 0 and i > 0))  # the first span swells the same on both sides
        big = (i % 2 == 0) if side < 0 else (i % 2 == 1)  # the fat spans take turns, and the two sides are out of step
        first = (a + b) / 2 < starts[1]
        spans[side].append({"s0": a, "s1": b, "bulge": r.uniform(*(BULGE_FIRST if first else BULGE_BIG if big else BULGE_SMALL)),
                            "kind": "wall" if first else r.choice(("hill", "hill", "wall", "wall", "rim")), "seed": i * 2 + (side > 0)})
for sp in spans[1]:  # never a rim on both sides at once
    if sp["kind"] == "rim" and any(o["kind"] == "rim" and o["s0"] < sp["s1"] and o["s1"] > sp["s0"] for o in spans[-1]):
        sp["kind"] = "hill"


def by_stud(things):
    """which of a run of things (each with s0 and s1) holds each stud along the lane"""
    out, k = [], 0
    for stud in range(int(BUILD_TO) + 420):
        while k + 1 < len(things) and stud > things[k]["s1"]:
            k += 1
        out.append(things[k])
    return out


room_of = by_stud(rooms)
span_of = {side: by_stud(spans[side]) for side in (-1, 1)}


def room_at(at):
    return room_of[min(len(room_of) - 1, max(0, int(at)))]


def span_at(side, at):
    return span_of[side][min(len(span_of[side]) - 1, max(0, int(at)))]


def grow(at):
    """how much wider the lane is here than at the start: wider and wider as you go"""
    return 1.0 + WIDER * max(0.0, at) / TOTAL


def half(side, at):
    """how far this side's edge is from the lane's line: PINCH at its pinches, swelling between them"""
    sp = span_at(side, at)
    t = min(1.0, max(0.0, (at - sp["s0"] - 10.0) / (sp["s1"] - sp["s0"] - 20.0)))
    flare = 0.0
    if at < WIDEN_TO:  # the gate: GATE wide at the hub, opening out fast behind the wall, easing back to the lane's own
        flare = ((GATE - PINCH) + (WIDEN - (GATE - PINCH)) * smooth(at / WIDEN_BY)) * (1.0 - smooth((at - WIDEN_BY - 10.0) / (WIDEN_TO - WIDEN_BY - 10.0)))
    return (PINCH + sp["bulge"] * math.sin(math.pi * t) ** 1.25) * grow(at) + flare  # level at the pinch: a smooth neck


def width(at):
    return half(-1, at) + half(1, at)


def floor_y(at):
    at = min(max(0.0, at), len(depths) - 2.0)
    k = int(at)
    y = -(depths[k] + (depths[k + 1] - depths[k]) * (at - k))
    room = room_at(at)
    if room["land"] == 0:
        return y  # the first land is plain
    t = min(1.0, max(0.0, (at - room["s0"]) / (room["s1"] - room["s0"])))
    return y + 4.0 * math.sin(math.pi * t) ** 2  # after it each room is a low dome: the ground rolls


def heading_slow(at):
    h = 0.0
    for room in rooms:
        # a bend is spread over more lane where the lane is wider, so its inside never folds: the bend's radius stays
        # well over the lane's half width (at one fixed length the wide deep lands folded, and the floor tore there)
        long = 220.0 * grow(room["s1"])
        h += math.radians(room["turn"]) * smooth((at - room["s1"] + long / 2) / long)
    return h


headings = [heading_slow(float(k)) for k in range(int(BUILD_TO) + 420)]


def heading(at):
    at = min(max(0.0, at), len(headings) - 2.0)
    k = int(at)
    return headings[k] + (headings[k + 1] - headings[k]) * (at - k)


STEP = 4.0
line = [(0.0, 0.0)]
for k in range(int((BUILD_TO + 200) / STEP) + 10):
    h = heading((k + 0.5) * STEP)
    line.append((line[-1][0] + math.sin(h) * STEP, line[-1][1] + math.cos(h) * STEP))


def centre(at):
    """a point on the lane's line (the line the sides are measured from; the lane's true middle wanders off it)"""
    at = max(0.0, at)
    k = min(int(at / STEP), len(line) - 2)
    f = at / STEP - k
    return (line[k][0] + (line[k + 1][0] - line[k][0]) * f, floor_y(at), line[k][1] + (line[k + 1][1] - line[k][1]) * f)


def right(at):
    h = heading(at)
    return (math.cos(h), 0.0, -math.sin(h))


def ahead(at):
    h = heading(at)
    return (math.sin(h), 0.0, math.cos(h))


def across(at, x):
    """the point x studs to the right of the lane's line at `at`, on the floor"""
    c, rt = centre(at), right(at)
    return (c[0] + rt[0] * x, c[1], c[2] + rt[2] * x)


def edge_point(side, at):
    return across(at, side * half(side, at))


# a neck: the narrowest place near each pair of pinches. That is where the flags hang.
necks = [0.0]
for lp, rp in zip(left_p[1:], right_p[1:]):
    lo, hi = min(lp, rp) - 30.0, max(lp, rp) + 30.0
    if lo > BUILD_TO:
        break
    necks.append(min((lo + k * 4.0 for k in range(int((hi - lo) / 4.0) + 1)), key=width))

nodes = [0.0]
while nodes[-1] < BUILD_TO:
    nodes.append(nodes[-1] + SEG)

edges, normals = {}, {}
for side in (-1, 1):
    pts = [edge_point(side, v) for v in nodes]
    edges[side] = pts
    normals[side] = []
    for i, v in enumerate(nodes):
        pa_, pb_ = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        dx, dz = pb_[0] - pa_[0], pb_[2] - pa_[2]
        m = math.hypot(dx, dz) or 1.0
        n = (dz / m, 0.0, -dx / m)
        rt_ = right(v)
        if (n[0] * rt_[0] + n[2] * rt_[2]) * side < 0:
            n = (-n[0], 0.0, -n[2])
        normals[side].append(n)


def strip(side, i, back, deep):
    """a box lying along the lane's edge between nodes i and i + 1, from `back` to `back + deep` outside it:
    its centre (x, z), its outward and along axes, and its length"""
    ea, eb, na, nb = edges[side][i], edges[side][i + 1], normals[side][i], normals[side][i + 1]
    ia, ib = (ea[0] + na[0] * back, ea[2] + na[2] * back), (eb[0] + nb[0] * back, eb[2] + nb[2] * back)
    oa, ob = (ea[0] + na[0] * (back + deep), ea[2] + na[2] * (back + deep)), (eb[0] + nb[0] * (back + deep), eb[2] + nb[2] * (back + deep))
    ma, mb = ((ia[0] + oa[0]) / 2, (ia[1] + oa[1]) / 2), ((ib[0] + ob[0]) / 2, (ib[1] + ob[1]) / 2)
    m = math.hypot(mb[0] - ma[0], mb[1] - ma[1]) or 1.0
    al = ((mb[0] - ma[0]) / m, 0.0, (mb[1] - ma[1]) / m)
    o = (al[2], 0.0, -al[0])
    if o[0] * (na[0] + nb[0]) + o[2] * (na[2] + nb[2]) < 0:
        o = (-o[0], 0.0, -o[2])
    long = max(math.hypot(ib[0] - ia[0], ib[1] - ia[1]), math.hypot(ob[0] - oa[0], ob[1] - oa[1])) + 1.6
    return ((ma[0] + mb[0]) / 2, (ma[1] + mb[1]) / 2), o, al, long


# ---------------------------------------------------------------- walls, the reference's way (map-structure.md)
terrace_spots = []  # (s, x, top y, z) of grass wide enough to stand something on


def march(pts, chord_at):
    """points along a fine line, each exactly a chord from the last: the corners of the wall's pieces. chord_at(s)
    gives the chord's length there: a whole number of tiles of the picture"""
    out = [tuple(pts[0][:5])]
    i = 0
    while True:
        cx, cz = out[-1][0], out[-1][1]
        chord = chord_at(out[-1][4])
        cut = False
        while i + 1 < len(pts) and math.hypot(pts[i + 1][0] - cx, pts[i + 1][1] - cz) < chord:
            i += 1
            if len(pts[i]) > 5 and pts[i][5]:
                # a sharp corner in the line (unfold marks them): a piece ends exactly on it, and the next begins
                # there, so no piece ever lies across a corner. The corner is given twice: once facing the way the
                # wall faced before it, once the way it faces after (the piece between the two has no length)
                out.append((pts[i][0], pts[i][1], pts[i - 1][2], pts[i - 1][3], pts[i][4]))
                out.append(tuple(pts[i][:5]))
                cut = True
                break
        if cut:
            continue
        if i + 1 >= len(pts):
            return out
        a, b = pts[i], pts[i + 1]
        lo, hi = 0.0, 1.0
        for _ in range(24):  # the point between a and b that is exactly a chord away
            mid = (lo + hi) / 2
            q = (a[0] + (b[0] - a[0]) * mid, a[1] + (b[1] - a[1]) * mid)
            if math.hypot(q[0] - cx, q[1] - cz) < chord:
                lo = mid
            else:
                hi = mid
        out.append(tuple(a[k] + (b[k] - a[k]) * lo for k in range(5)))


def lay(verts, tops, deep, colours, spots, closed=None):
    """One tier of a wall along `verts` (corners PIECE apart: x, z, nx, nz, s; n points away from the lane). tops[k]
    is the height of piece k's top under its grass, or None where the tier isn't there. A piece is a face (a thin slab,
    or a whole block where its end shows), a grass slab a square thick and a stud proud, and on a hollow curve a core
    behind that fills the thin wedges that open toward the back. Faces meet exactly at every corner."""
    n = len(verts) - 1
    for k in range(n):
        top = tops[k]
        if top is None:
            continue
        a, b = verts[k], verts[k + 1]
        ground, face = colours(a[4])
        al = unit((b[0] - a[0], 0.0, b[1] - a[1]))
        out = (al[2], 0.0, -al[0])
        if out[0] * (a[2] + b[2]) + out[2] * (a[3] + b[3]) < 0:
            out = (-out[0], 0.0, -out[2])
        if math.hypot(b[0] - a[0], b[1] - a[1]) < 0.05:
            continue  # the turn at a sharp corner: nothing to build
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        long = math.hypot(b[0] - a[0], b[1] - a[1])  # this piece's length: one tile of the picture, or less at a corner
        foot = top - 60.0 if top - 60.0 < floor_low(a[4]) else floor_low(a[4])
        before = tops[k - 1] if k > 0 and tops[k - 1] is not None else -1e9
        after = tops[k + 1] if k + 1 < n and tops[k + 1] is not None else -1e9
        shows = before < top or after < top  # an end of this piece stands clear of its neighbour
        count["ends"] += (before < -1e8) + (after < -1e8)
        fd = deep if shows else 1.0
        add("Wall", "face", (mx + out[0] * fd / 2, (foot + top) / 2, mz + out[2] * fd / 2), (fd, top - foot, long + 0.02), face, out, (0, 1, 0), al, v=top % PIECE)
        lift = 0.04 if k % 2 else 0.0  # neighbours a hair apart in height, so tops that overlap on a bulge don't flicker
        gd = deep + PROUD + 0.6
        add("Grass", "grass", (mx + out[0] * (gd / 2 - PROUD), top + (GRASS + lift) / 2, mz + out[2] * (gd / 2 - PROUD)), (gd, GRASS + lift, long + 0.02),
            ground, out, (0, 1, 0), al, v=(top + GRASS + lift) % PIECE)
        count["face"] += 1
        bx_, bz_ = b[0] + b[2] * deep - a[0] - a[2] * deep, b[1] + b[3] * deep - a[1] - a[3] * deep
        # the back's length, with its sign: on a sharp outside corner the two ends' backs cross over, and the length
        # then comes out long though there is no room behind at all (a filler put there stuck out through the wall)
        long_back = bx_ * al[0] + bz_ * al[2]
        if long_back > long + 0.08:  # a hollow curve: the back is longer than the front, so wedges open there
            left = long / 2 - 0.05 if before < top else long_back / 2 + 0.1  # toward the piece before
            right_ = long / 2 - 0.05 if after < top else long_back / 2 + 0.1
            shift = (right_ - left) / 2
            # the filling: its top lies a hair (0.02) under the grass slab's and carries the same picture, so a wedge
            # between two slabs shows as more grass. (It was 0.1 lower and plain, and every wedge read as a crack.)
            fill_top = top + GRASS + lift - 0.02
            add("Fill", "fill", (mx + out[0] * (deep + 0.9) / 2 + al[0] * shift, (foot + fill_top) / 2, mz + out[2] * (deep + 0.9) / 2 + al[2] * shift),
                (deep + 0.3, fill_top - foot, left + right_), ground, out, (0, 1, 0), al)
        if closed and closed[k] and long_back > 1.0:  # the outermost tier where its back can be seen: a slab across the back
            add("Back", "core", (mx + out[0] * (deep - 0.5), (foot + top) / 2, mz + out[2] * (deep - 0.5)), (1.0, top - foot, max(long, long_back) + 0.1), face, out, (0, 1, 0), al)
        if spots and deep >= 15 and top + GRASS < -10.0:  # nothing stands on a terrace that is out of the water
            terrace_spots.append((a[4], mx + out[0] * deep * 0.5, top + GRASS + lift, mz + out[2] * deep * 0.5))


def floor_low(at):
    """well under the floor here: where a wall's foot goes"""
    return -depths[min(len(depths) - 1, int(max(0.0, at)) + 40)] - 30.0


def build_wall(line_, tiers, ground, face, level_at, salt, spots=True):
    """a wall of fixed tiers along a line (the hub's ring): tiers are (set back, depth, height in squares)"""
    for j, (back, deep, base) in enumerate(tiers):
        verts = march([(x + nx * back, z + nz * back, nx, nz, s_) for x, z, nx, nz, s_ in line_], lambda at: PIECE)
        tops = []
        for k in range(len(verts) - 1):
            block = k // WAVE
            tops.append(round(level_at(verts[k][4]) / SQUARE) * SQUARE + (base + int(frac(block, salt + j * 7) * 3) - 1) * SQUARE)
        lay(verts, tops, deep, lambda at: (ground, face), spots)


def lane_line(side, s0, s1):
    """fine samples of one side's edge between two places along the lane: (x, z, nx, nz, s)"""
    out = []
    at = s0
    while at <= s1 + 1e-6:
        e0, e1, e = edge_point(side, max(0.0, at - 1.0)), edge_point(side, at + 1.0), edge_point(side, at)
        dx, dz = e1[0] - e0[0], e1[2] - e0[2]
        m = math.hypot(dx, dz) or 1.0
        nx, nz = dz / m, -dx / m
        rt_ = right(at)
        if (nx * rt_[0] + nz * rt_[2]) * side < 0:
            nx, nz = -nx, -nz
        out.append((e[0], e[2], nx, nz, at))
        at += 0.5 if at < WIDEN_BY + 20.0 else 1.0
    return out


def want(side, tier, at):
    """how many squares high this tier wants to be here, from the kind of side this is"""
    kind = span_at(side, min(max(0.0, at), BUILD_TO))["kind"]
    return KIND[kind][tier]


def eased(side, tier, at):
    """the same, averaged along the wall, so a wall climbs to a taller neighbour in whole squares and never ends in a cliff"""
    return sum(want(side, tier, at + d) for d in (-80, -40, 0, 40, 80)) / 5.0


def lane_colours(at):
    hub = (HUB_LOOK["top"], HUB_LOOK["face"] or face_of(HUB_LOOK["top"]))
    if at < 0.0:  # round the hub: the hub's own colours
        return hub
    g = GROUND[min(land_at(at), len(GROUND) - 1)]
    land = (g, FACES[min(land_at(at), len(FACES) - 1)] if FACES else face_of(g))
    if at < JOIN:  # out of the mouth the hub's colours fade into the first land's, as its wall steps down
        f = smooth(at / JOIN)
        return tuple(tuple(int(h + (l - h) * f) for h, l in zip(hc, lc)) for hc, lc in zip(hub, land))
    return land


HUB_HALF, HUB_BACK, CORNER, FRONT = 172.0, -244.0, 32.0, -32.0  # S (2026-11-23, the user: "thats good, add the map back
# in now", "w the new hub"): 344 wide and 212 deep, the reference's own size (docs/design/hub-review-2.md, section 3; the
# places of everything in it: hub_scale_plan.py). Before it, W32: 400 wide and 280 from the back wall to the front
# wall's face: -312, half 200. W32 (the user, 2026-11-22, "Do the old chat's pick"; docs/design/hub-layout.md, "The water nearer"): the
# water comes 16 nearer the hub, so the cut through the front wall and the strip in it are 32 deep (48 before), and the
# whole hub with everything the user placed in it moves 16 toward the water (HUB_SHIFT); the back wall then went 8
# further back for room behind the back tanks (15 there, 7 before). Before W32: -320 and -48, 272 from back to front.
HUB_SHIFT = 16.0  # how far the hub's hand-placed models (all but the arch, which stays at the water's edge) moved toward
# the water on 2026-11-22: their numbers below and in hub_kit.py are the user's placing plus this
# Until 2026-11-22 the next lines read: 400 wide and 272 from the back wall to the front
# wall's face. Until 2026-11-17 it was 480 by 320. The user then placed the tanks and stalls by hand and asked: the
# space behind the back row "should be reduced and the gap should be almost closed", and "a base scale reduction of
# the hub, by about 15-20% to be more akin to ride a dino". So the walls stand 7 studs behind the tanks, round the
# user's own placing: 17% narrower and 15% shallower. The front wall's face is FRONT back from the water, so the start
# strip lies in the gap of the wall itself, in line with it, as the reference's does
# The low terrace in front of the hub's tall wall (the user, 2026-11-17: "id like the first layer to be more flush
# with the wall in most places but not all ... more pushed in so it looks like an extrusion of a cliff almost"): how
# far the tall wall stands behind the terrace's face, by stretch of the ring (TIER_BACK's 24 everywhere else)
HUB_LEDGE = 8.0  # most of the ring: the terrace is one square deep
HUB_LEDGE_WIDE = 24.0  # one stretch of each side keeps the old deep ledge
HUB_LEDGE_GATE = 16.0  # round the gate and along the front wall: two squares, for the arch's piers to stand on
WIDE_BLOCK = -5  # which stretch of the ring (counted back from the gate, WAVE pieces each) keeps the deep ledge
# Trial hub numbers (the hub study, 2026-11-20, tools/map/hub_options.py; docs/design/hub-layout.md): HUB_TRY='{"GATE_TURN":
# 17, "STRIP_IN": 32, ...}' changes these for a trial build only (always with GREYBOX_OUT). Unset, nothing changes.
HUB_TRY = json.loads(os.environ.get("HUB_TRY") or "{}")
for _k, _v in HUB_TRY.items():
    if _k in ("GATE", "GATE_TURN", "FRONT_TURN", "HUB_HALF", "HUB_BACK", "FRONT", "HUB_LEDGE", "HUB_LEDGE_GATE", "CORNER"):
        globals()[_k] = float(_v)
STRIP_IN = float(HUB_TRY.get("STRIP_IN", 0.0))  # how far the start strip reaches onto the hub's floor past the front wall
STRIP_WIDE = float(HUB_TRY.get("STRIP_WIDE", 0.0))  # and how much wider each side that part is than the gap


def tier_span(j, block, at):
    """how far tier j's face stands behind the wall's line, and how deep it is. Round the hub the terrace (0) and the
    tall wall (1) share one line between them that moves by stretch; the tall wall's back stays where it was"""
    if at >= 0.0 or j > 1:
        return TIER_BACK[j], TIER_DEEP[j]
    ledge = HUB_LEDGE_GATE if block >= -3 else (HUB_LEDGE_WIDE if block == WIDE_BLOCK else HUB_LEDGE)
    if j == 0:
        return 0.0, ledge
    return ledge, TIER_BACK[1] + TIER_DEEP[1] - ledge


def hub_half_ring(side):
    """the hub's wall line for one side, from the middle of its back round to where the lane's mouth begins, as fine
    samples (x, z, s): s is negative, the distance still to go to the mouth"""
    pts = [(0.0, HUB_BACK)]
    for k in range(0, 91, 5):  # the back corner
        a_ = math.radians(270 - k)
        pts.append((-(HUB_HALF - CORNER) + CORNER * math.cos(a_), HUB_BACK + CORNER + CORNER * math.sin(a_)))
    for k in range(0, 91, 5):  # the front corner
        a_ = math.radians(180 - k)
        pts.append((-(HUB_HALF - FRONT_TURN) + FRONT_TURN * math.cos(a_), FRONT - FRONT_TURN + FRONT_TURN * math.sin(a_)))
    turn = GATE_TURN
    for k in range(0, 90, 5):
        a_ = math.radians(270 + k)
        pts.append((-(GATE + turn) + turn * math.cos(a_), FRONT + turn + turn * math.sin(a_)))
    pts.append((-GATE, 0.0))  # then straight through the wall's thickness to where the lane begins
    fine = []
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        span = math.hypot(xb - xa, zb - za)
        for j in range(max(1, int(span / 0.5))):
            f = j / max(1, int(span / 0.5))
            fine.append((xa + (xb - xa) * f, za + (zb - za) * f))
    total = sum(math.hypot(b_[0] - a_[0], b_[1] - a_[1]) for a_, b_ in zip(fine, fine[1:] + [pts[-1]]))
    out, gone = [], 0.0
    for i, q in enumerate(fine):
        out.append((q[0] if side < 0 else -q[0], q[1], gone - total))
        nxt = fine[i + 1] if i + 1 < len(fine) else pts[-1]
        gone += math.hypot(nxt[0] - q[0], nxt[1] - q[1])
    return out


def wall_line(side):
    """one side's whole wall line: the hub's half ring, then the lane's edge from the mouth to the end. Normals point
    away from the hub and the lane, taken from the line itself so they turn smoothly through every corner"""
    pts = hub_half_ring(side) + [(x, z, at) for x, z, _nx, _nz, at in lane_line(side, 0.0, BUILD_TO)]
    out = []
    for i, (x, z, at) in enumerate(pts):
        j0, j1 = i, i
        while j0 > 0 and math.hypot(pts[j0][0] - x, pts[j0][1] - z) < 3.0:
            j0 -= 1
        while j1 < len(pts) - 1 and math.hypot(pts[j1][0] - x, pts[j1][1] - z) < 3.0:
            j1 += 1
        dx, dz = pts[j1][0] - pts[j0][0], pts[j1][1] - pts[j0][1]
        m = math.hypot(dx, dz) or 1.0
        nx, nz = (-dz / m, dx / m) if side < 0 else (dz / m, -dx / m)
        out.append((x, z, nx, nz, at))
    return out


def unfold(fine, back):
    """the line `back` studs behind a wall's face. Where the face turns tighter than that (the tooth of a sharp pinch)
    a line set back from it loops over itself, and wall pieces laid along the loop crossed each other in shards. So
    only the points that really are `back` from the whole face are kept: the loop is cut off and the two sides meet
    in a clean corner behind the tooth"""
    if not back:
        return list(fine)
    face = np.array([(q[0], q[1]) for q in fine])
    line = face + back * np.array([(q[2], q[3]) for q in fine])
    arc = np.concatenate(([0.0], np.cumsum(np.hypot(*(face[1:] - face[:-1]).T))))
    reach = back * 3.0 + 20.0
    lo, hi = np.searchsorted(arc, arc - reach), np.searchsorted(arc, arc + reach)
    out, dropped = [], False
    for i, q in enumerate(fine):
        near = face[lo[i]:hi[i]] - line[i]
        if np.hypot(near[:, 0], near[:, 1]).min() >= back - 0.6:
            out.append((line[i][0], line[i][1], q[2], q[3], q[4], 1 if dropped and out else 0))  # 1: a corner here
            dropped = False
        else:
            dropped = True
    return rounded(out)


def rounded(pts):
    """the sharp corners of a set-back tier near the gate, rounded off: the line FILLET before a corner to FILLET
    after it is replaced by a smooth curve through the corner's inside. Round the hub's entrance the tall walls then
    turn as softly as the low wall in front of them (elsewhere a corner stays sharp, behind a tooth of the wall)"""
    out, i = [], 0
    while i < len(pts):
        q = pts[i]
        if not (q[5] and abs(q[4]) < 200.0):
            out.append(q)
            i += 1
            continue
        # walk back and forward along the line by FILLET
        a = len(out) - 1
        gone = 0.0
        while a > 0 and gone < FILLET:
            gone += math.hypot(out[a][0] - out[a - 1][0], out[a][1] - out[a - 1][1])
            a -= 1
        b, gone = i, 0.0
        while b + 1 < len(pts) and gone < FILLET and not pts[b + 1][5]:
            gone += math.hypot(pts[b + 1][0] - pts[b][0], pts[b + 1][1] - pts[b][1])
            b += 1
        p0, p1, p2 = out[a], q, pts[b]
        del out[a + 1:]
        steps = max(8, int(FILLET * 4))
        for k in range(1, steps + 1):
            t = k / steps
            x = (1 - t) ** 2 * p0[0] + 2 * t * (1 - t) * p1[0] + t * t * p2[0]
            z = (1 - t) ** 2 * p0[1] + 2 * t * (1 - t) * p1[1] + t * t * p2[1]
            tx = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
            tz = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
            m = math.hypot(tx, tz) or 1.0
            nx, nz = -tz / m, tx / m
            if nx * (p0[2] + p2[2]) + nz * (p0[3] + p2[3]) < 0:
                nx, nz = -nx, -nz
            out.append((x, z, nx, nz, p0[4] + (p2[4] - p0[4]) * t, 0))
        i = b + 1
    return out


def tier_top(side, j, block):
    """the height of tier j's top (under its grass) for one stretch of wall, or None where the tier isn't there"""
    mid = (block + 0.5) * WAVE * PIECE
    if mid < 0.0:  # round the hub: whole squares over the water, a square up or down now and then
        if not HUB_TIERS[j]:
            return None
        # the hub's walls are the same on both sides, and the tall wall steps at even intervals: a square up on every
        # other stretch, level beside the gate (the user, 2026-11-12: the tall walls build the feeling of symmetry)
        calm = mid > -2.5 * WAVE * PIECE
        return (HUB_TIERS[j] + (1 if j == 1 and not calm and block % 2 == 0 else 0)) * SQUARE
    high = eased(side, j, mid)
    lower = eased(side, j - 1, mid) if j else -9.0
    if high < 0.5 or high < lower + 2.0:
        return None  # no tier here: it would stand no higher than the one in front of it
    plain = land_at(mid) == 0  # the first land's walls keep one height: a calm start
    jitter = 0 if plain else (int(frac(block, 31 + j * 7 + (side > 0)) * 2) - (1 if j == 0 and high >= 2.5 else 0))
    squares = round(floor_y(mid) / SQUARE) + round(high) + jitter
    if mid < JOIN and HUB_TIERS[j]:  # leaving the hub, its wall steps down to this
        squares = round(HUB_TIERS[j] + (squares - HUB_TIERS[j]) * smooth(mid / JOIN))
    return squares * SQUARE


# ---------------------------------------------------------------- the wall, built on ribs (map-structure.md, grey-box 13)
# One line of corners is marched along the wall's face, exactly a piece apart. Every tier behind it uses the same
# corners, stepped back along the bisector of the turn there: a rib. So all the tiers' joints lie on the same ribs,
# from the lane's edge to the back of the wall, and the ground between two walls is a fan of cells that fit each other.
#
# The picture: every piece of every tier carries exactly one tile of it (two squares) along the wall, stretched to the
# piece's length and slid a quarter of a tile, so a square straddles every joint and one sits whole in the middle. A
# joint is then never an edge of the grid: where two tops overlap on a bend, both show the same shade there. Rows run
# in whole squares from each wall's face, so they end exactly at the next wall's face.
#
# How Roblox lays a Texture, found on a test in Studio (2026-11-12). On a part's Top: U runs along the part's X from
# its +X edge, V along its Z from its +Z edge. On its Left side: U runs along Z from the -Z edge, V down from the top.
# A grid line falls where (distance from that edge + the offset) is a whole number of squares; the square at the
# edge is the dark one.
R_OPEN = 100.0  # no nose of the wall is sharper than this: a tier behind a sharper one would fold over itself
SHORT, LONG = PIECE / math.sqrt(2), PIECE * math.sqrt(2)  # a piece shorter than SHORT joins the next; longer than LONG is two
BACK = 1.0  # a top runs this far in under the wall behind it


def opened(fine, radius):
    """the wall's face line with every nose rounded to `radius`: where the line stepped back by `radius` would fold
    over itself, the face there is replaced by an arc of that radius. Only in the lane: the hub and its gate keep
    their own, tighter corners"""
    face = np.array([(q[0], q[1]) for q in fine])
    nrm = np.array([(q[2], q[3]) for q in fine])
    line = face + radius * nrm
    arc = np.concatenate(([0.0], np.cumsum(np.hypot(*(face[1:] - face[:-1]).T))))
    reach = radius * 3.0 + 20.0
    lo, hi = np.searchsorted(arc, arc - reach), np.searchsorted(arc, arc + reach)
    out, last = [], None
    for i, q in enumerate(fine):
        if q[4] > 150.0:
            near = face[lo[i]:hi[i]] - line[i]
            if np.hypot(near[:, 0], near[:, 1]).min() < radius - 0.6:
                continue
        if last is not None and i - last > 1:  # a nose was cut out: an arc round the point both sides step back to
            c = (line[last] + line[i]) / 2
            a0, a1 = math.atan2(nrm[last][1], nrm[last][0]), math.atan2(nrm[i][1], nrm[i][0])
            da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
            steps = max(2, int(abs(da) * radius))
            for k in range(1, steps):
                a_ = a0 + da * k / steps
                out.append((c[0] - radius * math.cos(a_), c[1] - radius * math.sin(a_), math.cos(a_), math.sin(a_),
                            fine[last][4] + (q[4] - fine[last][4]) * k / steps))
        out.append(tuple(q[:5]))
        last = i
    return out


def wrap(v, period):
    return v % period if period > 1e-6 else 0.0


caps = []  # every grass slab `cell` lays, for `trim_caps`


def cell(af, bf, ab, bb, out_hint, top, deep, at, odd, before, after, colours, close, spots, tiles=1):
    """One piece of one tier: its face from af to bf, and the ground on top of it, which reaches back to ab and bb on
    the same two ribs. `before` and `after` are the tops of the pieces either side (or far below, if none)."""
    lx, lz = bf[0] - af[0], bf[1] - af[1]
    lf = math.hypot(lx, lz)
    if lf < 0.5:
        return
    al = (lx / lf, 0.0, lz / lf)
    out = (al[2], 0.0, -al[0])
    if out[0] * out_hint[0] + out[2] * out_hint[2] < 0:
        out = (-out[0], 0.0, -out[2])
    ground, face = colours(at)
    mx, mz = (af[0] + bf[0]) / 2, (af[1] + bf[1]) / 2
    foot = top - 60.0 if top - 60.0 < floor_low(at) else floor_low(at)
    shows = before < top or after < top  # an end of this piece stands clear of its neighbour
    count["ends"] += (before < -1e8) + (after < -1e8)
    fd = deep if shows else 1.0
    sq = lf / tiles / 2  # a square's width on the face; half a square is slid in, so one straddles each end
    add("Wall", "face", (mx + out[0] * fd / 2, (foot + top) / 2, mz + out[2] * fd / 2), (fd, top - foot, lf + 0.02), face, out, (0, 1, 0), al,
        tex={"side": [lf / tiles, PIECE, wrap(sq / 2 - 0.01, sq), top % PIECE]})
    count["face"] += 1
    # the ground on top: from the lip in front of the face back to under the next wall, as wide as its widest end
    lift = 0.04 if odd else 0.0  # neighbours a hair apart in height, so tops that overlap on a bend don't flicker
    def on_rib(f, b_, d):  # the point on a rib at d behind the face
        return (f[0] + (b_[0] - f[0]) * d / deep, f[1] + (b_[1] - f[1]) * d / deep)
    # How far the slab reaches past each end of its face (2026-11-16: the user saw tops standing out of line with
    # their walls). It was as wide as its widest corner, both ways: where one end fanned out toward the back (a
    # hollow bend) the slab grew by as much at its other end too, and there, if the wall turned away, its front
    # corner hung out past the next piece's face (up to 20 studs on a cliff, which is 136 deep). So each end now
    # reaches only as far as its own rib does; and an end that stands clear of a lower neighbour (or of nothing) is
    # cut flush with the face under it, as the fan would hang in the air there: the lower piece's own top fills it.
    def along(q):
        return (q[0] - mx) * al[0] + (q[1] - mz) * al[2]
    lo = min(-lf / 2, along(on_rib(af, ab, -PROUD)), along(on_rib(af, ab, deep + BACK))) if before >= top else -lf / 2
    hi = max(lf / 2, along(on_rib(bf, bb, -PROUD)), along(on_rib(bf, bb, deep + BACK))) if after >= top else lf / 2
    lo, hi = lo - 0.025, hi + 0.025
    if hi - lo < 2.0:
        lo, hi = (lo + hi) / 2 - 1.0, (lo + hi) / 2 + 1.0
    wide, shift = hi - lo, (lo + hi) / 2
    lb = (bb[0] - ab[0]) * al[0] + (bb[1] - ab[1]) * al[2]  # the back's length, with its sign
    mid = max(lf / 2, (lf + lb) / 2)  # the squares' width on top: the cell's width half way back
    gd = deep + BACK + PROUD
    add("Grass", "grass", (mx + out[0] * (gd / 2 - PROUD) + al[0] * shift, top + (GRASS + lift) / 2, mz + out[2] * (gd / 2 - PROUD) + al[2] * shift),
        (gd, GRASS + lift, wide), ground, out, (0, 1, 0), al,
        tex={"top": [PIECE, mid / tiles, wrap(-(deep + BACK), SQUARE), wrap(mid / tiles / 4 - hi + mid / 2, mid / tiles / 2)],
             "side": [lf / tiles, PIECE, wrap(sq / 2 - (-lf / 2 - lo), sq), (top + GRASS) % PIECE]})
    caps.append({"part": parts[-1], "m": (mx, mz), "al": al, "out": out, "lf": lf, "lo": lo, "hi": hi, "gd": gd, "mid": mid, "tiles": tiles, "sq": sq})
    if close and lb > 1.0:  # the outermost tier where its back can be seen: a slab across the back
        add("Back", "core", (mx + out[0] * (deep - 0.5), (foot + top) / 2, mz + out[2] * (deep - 0.5)), (1.0, top - foot, max(lf, lb) + 0.1), face, out, (0, 1, 0), al)
    if spots and deep >= 15 and top + GRASS < -10.0:  # nothing stands on a terrace that is out of the water
        terrace_spots.append((at, mx + out[0] * deep * 0.5, top + GRASS + lift, mz + out[2] * deep * 0.5))


wall_pieces = []  # every lane wall piece: (side, tier, front a, front b, out, top, s, depth, set back), for stage 2's dressing
wall_corners = {}  # by side: the face's corners, for the barrier
for side in (-1, 1):
    V = march(opened(wall_line(side), R_OPEN), lambda at: PIECE)
    n = len(V) - 1
    outs = []
    for k in range(n):
        d = unit((V[k + 1][0] - V[k][0], 0.0, V[k + 1][1] - V[k][1]))
        o = (d[2], 0.0, -d[0])
        if o[0] * (V[k][2] + V[k + 1][2]) + o[2] * (V[k][3] + V[k + 1][3]) < 0:
            o = (-o[0], 0.0, -o[2])
        outs.append(o)
    ribs = []  # at each corner: the way back along the bisector, stretched so a step of d is d behind both faces
    for k in range(n + 1):
        o0, o1 = outs[max(0, k - 1)], outs[min(n - 1, k)]
        bx, bz = o0[0] + o1[0], o0[2] + o1[2]
        m = math.hypot(bx, bz) or 1.0
        c = max(0.5, (bx * o1[0] + bz * o1[2]) / m)
        ribs.append((bx / m / c, bz / m / c))
    wall_corners[side] = V

    def at_rib(k, d):
        return (V[k][0] + ribs[k][0] * d, V[k][1] + ribs[k][1] * d)

    blocks = [math.floor(V[k][4] / (WAVE * PIECE)) for k in range(n)]
    for j in range(3):
        spans_ = [tier_span(j, blocks[k_], V[k_][4]) for k_ in range(n)]
        tops = [tier_top(side, j, b_) for b_ in blocks]
        outer = [j == 2 or tier_top(side, j + 1, b_) is None for b_ in blocks]
        # this tier's pieces: one to a stretch between two ribs; two where that stretch is long (a hollow bend), and
        # one across two or three stretches where they are short (a nose)
        pieces = []  # (front a, front b, back a, back b, where it starts and ends counted in ribs, its stretch)
        k = 0
        while k < n:
            if tops[k] is None:
                k += 1
                continue
            e = k + 1
            df, deep = spans_[k]
            fa, fb = at_rib(k, df), at_rib(e, df)
            while math.hypot(fb[0] - fa[0], fb[1] - fa[1]) < SHORT and e < n and tops[e] == tops[k] and spans_[e] == spans_[k] and e - k < 3:
                e += 1
                fb = at_rib(e, df)
            ba, bb = at_rib(k, df + deep), at_rib(e, df + deep)
            long = math.hypot(fb[0] - fa[0], fb[1] - fa[1])
            cuts = 2 if e == k + 1 and long >= LONG else 1
            for c_ in range(cuts):
                t0, t1 = c_ / cuts, (c_ + 1) / cuts
                pieces.append(((fa[0] + (fb[0] - fa[0]) * t0, fa[1] + (fb[1] - fa[1]) * t0), (fa[0] + (fb[0] - fa[0]) * t1, fa[1] + (fb[1] - fa[1]) * t1),
                               (ba[0] + (bb[0] - ba[0]) * t0, ba[1] + (bb[1] - ba[1]) * t0), (ba[0] + (bb[0] - ba[0]) * t1, ba[1] + (bb[1] - ba[1]) * t1),
                               k + (e - k) * t0, k + (e - k) * t1, k))
            k = e
        for i, (fa, fb, ba, bb, k0, k1, k) in enumerate(pieces):
            top = tops[k]
            before = tops[pieces[i - 1][6]] if i > 0 and pieces[i - 1][5] == k0 else -1e9  # the piece it follows on from
            after = tops[pieces[i + 1][6]] if i + 1 < len(pieces) and pieces[i + 1][4] == k1 else -1e9
            cell(fa, fb, ba, bb, outs[k], top, spans_[k][1], V[k][4], i % 2 == 1, before, after, lane_colours,
                 V[k][4] < JOIN and outer[k], True)
            wall_pieces.append((side, j, fa, fb, outs[k], top, V[k][4], spans_[k][1], spans_[k][0]))
            glow = water_zones.ZONES[min(land_at(max(0.0, V[k][4])), len(water_zones.ZONES) - 1)]["glow"] if V[k][4] > 0 else None
            if j == 0 and glow:  # the deep lands' ledges glow: two lines of light that show the lane's shape and its way
                lf = math.hypot(fb[0] - fa[0], fb[1] - fa[1])
                if lf > 0.5:
                    al = ((fb[0] - fa[0]) / lf, 0.0, (fb[1] - fa[1]) / lf)
                    o = outs[k]
                    add("Glow", "glow", ((fa[0] + fb[0]) / 2 - o[0] * (PROUD + 0.2), top + GRASS + 0.25, (fa[1] + fb[1]) / 2 - o[2] * (PROUD + 0.2)),
                        (1.0, 1.0, lf + 0.1), glow, o, (0, 1, 0), al, solid=False)

# ---------------------------------------------------------------- the canyon: shelves and cliffs behind the walls
# A swimmer can rise over any wall and look behind it. So the last near tier's ground carries on back, as a shelf, to
# the first cliff, and that cliff's ground to the second: there is no empty water behind a wall. A shelf is one long
# slab to four pieces of wall, a hair lower than the tops in front of it, at the lowest of their heights.
#
# A shelf never crosses a wall (2026-11-16: the user saw two slabs hanging out over the hub, either side of the gate).
# Where the land behind a wall is thin (the wedge between the hub's front wall and the lane's first walls) a shelf
# 130 deep ran straight through it and out over the open water on the other side. So every shelf is tested against
# both sides' wall lines; one that would come nearer than SHELF_CLEAR to the open side of any wall is laid as strips
# instead, each stopping where it would cross.
SHELF_CLEAR = 26.0  # a shelf keeps this far behind every wall's face: under the tall wall's own grass
SHELF_STRIP, SHELF_ROW = 16.0, 4.0  # a strip's width, and how finely its length is tried
count["shelf strips"] = 0
_seg = {}


def wall_segments():
    """both sides' wall faces as arrays: each piece's ends, its way out, and the way out at each end (the bisector)"""
    if not _seg:
        A, B, N, NA, NB = [], [], [], [], []
        for sd in (-1, 1):
            W = wall_corners[sd]
            m = len(W) - 1
            o_ = []
            for k in range(m):
                d = unit((W[k + 1][0] - W[k][0], 0.0, W[k + 1][1] - W[k][1]))
                o = (d[2], -d[0])
                if o[0] * (W[k][2] + W[k + 1][2]) + o[1] * (W[k][3] + W[k + 1][3]) < 0:
                    o = (-o[0], -o[1])
                o_.append(o)
            for k in range(m):
                a0, a1 = o_[max(0, k - 1)], o_[min(m - 1, k + 1)]
                A.append((W[k][0], W[k][1]))
                B.append((W[k + 1][0], W[k + 1][1]))
                N.append(o_[k])
                NA.append((a0[0] + o_[k][0], a0[1] + o_[k][1]))
                NB.append((a1[0] + o_[k][0], a1[1] + o_[k][1]))
        _seg.update(A=np.array(A), B=np.array(B), N=np.array(N), NA=np.array(NA), NB=np.array(NB))
        _seg["M"] = (_seg["A"] + _seg["B"]) / 2
    return _seg


def behind_walls(P, centre, reach):
    """for each point (x, z): how far behind the nearest wall face it is; below zero on the open side"""
    S = wall_segments()
    near = np.hypot(S["M"][:, 0] - centre[0], S["M"][:, 1] - centre[1]) < reach
    if not near.any():
        return np.full(len(P), 1e9)
    A, B, N, NA, NB = S["A"][near], S["B"][near], S["N"][near], S["NA"][near], S["NB"][near]
    D = B - A
    L2 = np.maximum(1e-9, (D * D).sum(1))
    T = np.clip(((P[:, None, :] - A[None]) * D[None]).sum(2) / L2[None], 0.0, 1.0)
    C = A[None] + T[:, :, None] * D[None]
    diff = P[:, None, :] - C
    dist = np.hypot(diff[:, :, 0], diff[:, :, 1])
    i = dist.argmin(1)
    rows = np.arange(len(P))
    t_, df = T[rows, i], diff[rows, i]
    nrm = np.where((t_ <= 0.0)[:, None], NA[i], np.where((t_ >= 1.0)[:, None], NB[i], N[i]))
    return np.where((df * nrm).sum(1) >= 0, 1.0, -1.0) * dist[rows, i]


def shelf(front, o, al, deep, wide, top, ground, d0, sq, lf, back):
    """one shelf: a slab from `front` (the middle of its front edge) `deep` back along o and `wide` along al; cut into
    strips that stop short of any wall it would cross"""
    clear = min(d0, SHELF_CLEAR + 4.0) - 4.0
    off_u, off_v = wrap(-(back - (d0 - (d0 % SQUARE))), SQUARE), wrap(sq / 2 - wide / 2 + lf / 2, sq)
    y = top + GRASS / 2 - 0.05

    def lay(w0, w1, t0, t1):
        cx, cz = front[0] + al[0] * ((w0 + w1) / 2 - wide / 2) + o[0] * (t0 + t1) / 2, front[1] + al[2] * ((w0 + w1) / 2 - wide / 2) + o[2] * (t0 + t1) / 2
        add("Shelf", "grass", (cx, y, cz), (t1 - t0, GRASS - 0.1, w1 - w0), ground, o, (0, 1, 0), al,
            tex={"top": [PIECE, sq * 2, (off_u + deep - t1) % PIECE, (off_v + wide - w1) % (sq * 2)],
                 "side": [sq * 2, PIECE, 0.0, (top + GRASS) % PIECE]})

    def grid(ws, ts):
        P = np.array([(front[0] + al[0] * (w - wide / 2) + o[0] * t_, front[1] + al[2] * (w - wide / 2) + o[2] * t_) for t_ in ts for w in ws])
        centre = (front[0] + o[0] * deep / 2, front[1] + o[2] * deep / 2)
        return behind_walls(P, centre, math.hypot(deep, wide) / 2 + 260.0).reshape(len(ts), len(ws))

    # a quick look first: nearly every shelf is clear of every wall, and is laid whole as it always was
    quick = grid(np.linspace(0.0, wide, max(2, int(wide / 8) + 1)), np.linspace(0.0, deep, max(2, int(deep / 8) + 1)))
    if quick[1:].min() >= clear:
        lay(0.0, wide, 0.0, deep)
        return
    strips = max(1, round(wide / SHELF_STRIP))
    ts = np.linspace(0.0, deep, int(round(deep / SHELF_ROW)) + 1)
    runs = []  # (w0, w1, t0, t1) of each strip that has room
    for s_ in range(strips):
        w0, w1 = wide * s_ / strips, wide * (s_ + 1) / strips
        ok = (grid(np.linspace(w0, w1, 5), ts) >= clear).all(1)
        a = 0
        while a < len(ts) and not ok[a] and ts[a] <= 40.0:  # a hollow bend: its front may begin a little further back
            a += 1
        if a >= len(ts) or not ok[a]:
            continue
        b = a
        while b + 1 < len(ts) and ok[b + 1]:
            b += 1
        t0, t1 = float(ts[a]), float(ts[b])
        if t1 - t0 < 8.0:
            continue
        if runs and abs(runs[-1][1] - w0) < 1e-6 and runs[-1][2] == t0 and runs[-1][3] == t1:
            runs[-1] = (runs[-1][0], w1, t0, t1)
        else:
            runs.append((w0, w1, t0, t1))
    for w0, w1, t0, t1 in runs:
        lay(w0, w1, t0, t1)
    count["shelf strips"] += len(runs)


def hazed(colour, share, haze=HAZE):
    return tuple(int(c + (h_ - c) * share) for c, h_ in zip(colour, haze))


def water_at(at):
    """the colour of the water in the land here: what its cliffs fade into"""
    return water_zones.ZONES[min(land_at(max(0.0, at)), len(water_zones.ZONES) - 1)]["water"]


for side in (-1, 1):
    V = wall_corners[side]
    n = len(V) - 1
    outs = []
    for k in range(n):
        d = unit((V[k + 1][0] - V[k][0], 0.0, V[k + 1][1] - V[k][1]))
        o = (d[2], 0.0, -d[0])
        if o[0] * (V[k][2] + V[k + 1][2]) + o[2] * (V[k][3] + V[k + 1][3]) < 0:
            o = (-o[0], 0.0, -o[2])
        outs.append(o)
    ribs = []
    for k in range(n + 1):
        o0, o1 = outs[max(0, k - 1)], outs[min(n - 1, k)]
        bx, bz = o0[0] + o1[0], o0[2] + o1[2]
        m = math.hypot(bx, bz) or 1.0
        c = max(0.5, (bx * o1[0] + bz * o1[2]) / m)
        ribs.append((bx / m / c, bz / m / c))
    blocks = [math.floor(V[k][4] / (WAVE * PIECE)) for k in range(n)]
    k = 0
    while k < n:
        e = min(n, k + 4)
        best = None  # the lowest outermost top over these pieces, and how far back that tier ends
        for i in range(k, e):
            for j in (2, 1, 0):
                t = tier_top(side, j, blocks[i])
                if t is not None:
                    if best is None or t < best[0]:
                        best = (t, TIER_BACK[j] + TIER_DEEP[j])
                    break
        if best is not None:
            top, d0 = best
            d1 = CLIFFS[0]["back"] + 90.0
            fa, fb = (V[k][0] + ribs[k][0] * d0, V[k][1] + ribs[k][1] * d0), (V[e][0] + ribs[e][0] * d0, V[e][1] + ribs[e][1] * d0)
            ba, bb = (V[k][0] + ribs[k][0] * d1, V[k][1] + ribs[k][1] * d1), (V[e][0] + ribs[e][0] * d1, V[e][1] + ribs[e][1] * d1)
            lf = math.hypot(fb[0] - fa[0], fb[1] - fa[1])
            if lf > 0.5:
                al = ((fb[0] - fa[0]) / lf, 0.0, (fb[1] - fa[1]) / lf)
                o = (al[2], 0.0, -al[0])
                if o[0] * outs[k][0] + o[2] * outs[k][2] < 0:
                    o = (-o[0], 0.0, -o[2])
                mx, mz = (fa[0] + fb[0]) / 2, (fa[1] + fb[1]) / 2
                wide = 2 * max(abs((q[0] - mx) * al[0] + (q[1] - mz) * al[2]) for q in (fa, fb, ba, bb)) + 0.5
                deep = d1 - d0
                ground, _face = lane_colours(V[k][4])
                sq = lf / 8  # four tiles to its length at the front
                shelf((mx, mz), o, al, deep, wide, top, ground, d0, sq, lf, d1)
        k = e

for side in (-1, 1):
    for ci, cl in enumerate(CLIFFS):
        deep = (CLIFFS[ci + 1]["back"] - cl["back"] + 40.0) if ci + 1 < len(CLIFFS) else 110.0
        C = march(unfold(opened(wall_line(side), cl["round"]), cl["back"]), lambda at: CLIFF_PIECE)
        n = len(C) - 1
        outs, lens = [], []
        for k in range(n):
            dx, dz = C[k + 1][0] - C[k][0], C[k + 1][1] - C[k][1]
            lens.append(math.hypot(dx, dz))
            d = unit((dx, 0.0, dz)) if lens[-1] > 0.05 else (0.0, 0.0, 0.0)
            o = (d[2], 0.0, -d[0])
            if o[0] * (C[k][2] + C[k + 1][2]) + o[2] * (C[k][3] + C[k + 1][3]) < 0:
                o = (-o[0], 0.0, -o[2])
            outs.append(o)
        real = [k for k in range(n) if lens[k] > 0.05]

        def rib(k):
            """the way back from corner k: the bisector of the real pieces either side of it"""
            before = max((i for i in real if i < k), default=None)
            after = min((i for i in real if i >= k), default=None)
            o0 = outs[before] if before is not None else outs[after]
            o1 = outs[after] if after is not None else outs[before]
            if abs(o0[0] * o1[0] + o0[2] * o1[2]) < 0.2:  # a sharp corner: straight back from this piece's own face
                return None
            bx, bz = o0[0] + o1[0], o0[2] + o1[2]
            m = math.hypot(bx, bz) or 1.0
            c = max(0.5, (bx * o1[0] + bz * o1[2]) / m)
            return (bx / m / c, bz / m / c)

        def cliff_top(at, k):
            block = math.floor(at / (CLIFF_WAVE * CLIFF_PIECE))
            step = (int(frac(block, 71 + ci * 5 + (side > 0 and at > 0)) * 3) - 1) * cl["step"]
            hub = cl["hub"] + step * SQUARE
            if at <= 0.0:
                return hub
            lane = round(floor_y(at) / SQUARE) * SQUARE + round((cl["squares"] + step) * grow(at) ** 0.6) * SQUARE
            return min(cl["cap"] + step * SQUARE, round((hub + (lane - hub) * smooth(at / 500.0)) / SQUARE) * SQUARE)

        tops = [cliff_top(C[k][4], k) if lens[k] > 0.05 else None for k in range(n)]
        for i, k in enumerate(real):
            ra, rb = rib(k), rib(k + 1)
            o = outs[k]
            af, bf = (C[k][0], C[k][1]), (C[k + 1][0], C[k + 1][1])
            ab = (af[0] + (ra[0] if ra else o[0]) * deep, af[1] + (ra[1] if ra else o[2]) * deep)
            bb = (bf[0] + (rb[0] if rb else o[0]) * deep, bf[1] + (rb[1] if rb else o[2]) * deep)
            before = tops[real[i - 1]] if i > 0 else -1e9
            after = tops[real[i + 1]] if i + 1 < len(real) else -1e9
            cell(af, bf, ab, bb, o, tops[k], deep, C[k][4], i % 2 == 1, before, after,
                 lambda at, pale=cl["pale"]: (hazed(lane_colours(at)[0], pale * 0.6, water_at(at)), face_of(lane_colours(at)[0], pale, water_at(at))),
                 False, False, tiles=max(1, round(lens[k] / PIECE)))

# No grass slab stands out of line (2026-11-16, the user: "anything that's out of line and not flush with the slight
# extrusion it's supposed to have"). A slab's front stands PROUD of its own face; past the ends of that face it may
# reach on only while it stays as far behind the wall's line as its own front does. Where the wall folds tightly (a
# tooth, a pinch) a reach that is hidden behind the next piece on an easy bend came out the other side: here every
# reach is walked a stud at a time and cut just short of where it would.
def trim_caps():
    cut, most = 0, 0.0
    for c in caps:
        (mx, mz), al, out, lf, lo, hi = c["m"], c["al"], c["out"], c["lf"], c["lo"], c["hi"]
        if hi - lf / 2 < 0.6 and -lf / 2 - lo < 0.6:
            continue

        def behind(ls):
            P = np.array([(mx + al[0] * l_ + out[0] * (d_ - PROUD), mz + al[2] * l_ + out[2] * (d_ - PROUD)) for l_ in ls for d_ in (0.0, 4.0)])
            return behind_walls(P, (mx, mz), 300.0 + hi - lo).reshape(len(ls), 2).min(1)

        own = behind(np.linspace(-lf / 2 + 0.4, lf / 2 - 0.4, 5)).min() - 1.0
        new_lo, new_hi = lo, hi
        if hi - lf / 2 >= 0.6:
            ls = np.append(np.arange(lf / 2 + 0.5, hi, 1.0), hi)
            bad = np.nonzero(behind(ls) < own)[0]
            if len(bad):
                new_hi = max(lf / 2 + 0.025, float(ls[bad[0]]) - 1.0)
        if -lf / 2 - lo >= 0.6:
            ls = np.append(np.arange(-lf / 2 - 0.5, lo, -1.0), lo)
            bad = np.nonzero(behind(ls) < own)[0]
            if len(bad):
                new_lo = min(-lf / 2 - 0.025, float(ls[bad[0]]) + 1.0)
        if new_lo == lo and new_hi == hi:
            continue
        cut += 1
        most = max(most, hi - new_hi, new_lo - lo)
        part, gd, mid, tiles, sq = c["part"], c["gd"], c["mid"], c["tiles"], c["sq"]
        wide, shift = new_hi - new_lo, (new_lo + new_hi) / 2
        part["p"][0] = round(mx + out[0] * (gd / 2 - PROUD) + al[0] * shift, 2)
        part["p"][2] = round(mz + out[2] * (gd / 2 - PROUD) + al[2] * shift, 2)
        part["s"][2] = round(wide, 2)
        part["tex"]["top"][3] = round(wrap(mid / tiles / 4 - new_hi + mid / 2, mid / tiles / 2), 3)
        part["tex"]["side"][2] = round(wrap(sq / 2 - (-lf / 2 - new_lo), sq), 3)
    count["caps cut"] = cut
    print(f"grass slabs cut back to their walls: {cut} of {len(caps)} (the most, {most:.1f} studs)")


trim_caps()

# the barrier: unseen and solid, just behind the wall's face, from under the floor to over the surface. A swimmer can go
# over any wall and a fish can get behind a thin one; this is what keeps them in the lane. One panel to two pieces.
for side in (-1, 1):
    V = wall_corners[side]
    k = next(i for i, q in enumerate(V) if q[4] >= 0.0)
    while k + 1 < len(V):
        a, b = V[k], V[min(k + 2, len(V) - 1)]
        long = math.hypot(b[0] - a[0], b[1] - a[1])
        if long > 0.5:
            al = ((b[0] - a[0]) / long, 0.0, (b[1] - a[1]) / long)
            o = (al[2], 0.0, -al[0])
            if o[0] * (a[2] + b[2]) + o[2] * (a[3] + b[3]) < 0:
                o = (-o[0], 0.0, -o[2])
            bx, bz = (a[0] + b[0]) / 2 + o[0] * 2.5, (a[1] + b[1]) / 2 + o[2] * 2.5
            y0 = min(floor_y(a[4]), floor_y(b[4])) - 12.0
            while y0 < 14.0:  # a part can be 2,048 studs at most, and the deep lands are deeper than that
                y1 = min(14.0, y0 + 2000.0)
                add("Barrier", "barrier", (bx, (y0 + y1) / 2, bz), (1.0, y1 - y0, long + 1.0), (255, 255, 255), o, (0, 1, 0), al, t=1.0)
                y0 = y1
        k += 2

# ---------------------------------------------------------------- the floor: square tiles on one world grid
def locate(x, z, hint):
    """where a point is against the lane: s along it, and how far to the right of its line"""
    at = hint
    for _ in range(6):
        c, d = centre(at), ahead(at)
        at = min(BUILD_TO + 60.0, max(0.0, at + (x - c[0]) * d[0] + (z - c[2]) * d[2]))
    c, rt_ = centre(at), right(at)
    return at, (x - c[0]) * rt_[0] + (z - c[2]) * rt_[2]


CELL = TILE / 4  # the floor's smallest tile: one tile of the picture
cells = {}
at = 0.0
while at <= BUILD_TO:
    x_ = -half(-1, at) - 12.0
    while x_ <= half(1, at) + 12.0:
        q = across(at, x_)
        cells.setdefault((math.floor(q[0] / TILE), math.floor(q[2] / TILE)), at)
        x_ += 6.0
    at += 6.0
corner_y = {}


def corner(ix, iz, hint):
    """the floor's height at a corner of the small grid: every tile that meets there reads the same number"""
    if (ix, iz) not in corner_y:
        corner_y[(ix, iz)] = floor_y(locate(ix * CELL, iz * CELL, hint)[0])
    return corner_y[(ix, iz)]


tiles = {}  # by small-grid cell: the tile that covers it: (x0, z0, size, height at its middle, slope along x, along z)


def fit(ix, iz, n, hint):
    """a flat tile n small cells on a side, the best fit to the floor at its four corners, and how far the floor is
    from it at the worst of the small grid's corners on or inside it"""
    size = n * CELL
    h00, h10, h01, h11 = corner(ix, iz, hint), corner(ix + n, iz, hint), corner(ix, iz + n, hint), corner(ix + n, iz + n, hint)
    h = (h00 + h10 + h01 + h11) / 4
    sx, sz = ((h10 + h11) - (h00 + h01)) / 2 / size, ((h01 + h11) - (h00 + h10)) / 2 / size
    off = max(abs(corner(ix + dx, iz + dz, hint) - (h + sx * (dx - n / 2) * CELL + sz * (dz - n / 2) * CELL))
              for dx in range(n + 1) for dz in range(n + 1))
    return (ix * CELL, iz * CELL, size, h, sx, sz), off


def cover(ix, iz, n, hint):
    """one tile where it lies within 0.06 of a stud of the floor all over; four smaller ones where the floor bends
    more than that (bends, the steep stretches, the domes), down to the smallest"""
    t, off = fit(ix, iz, n, hint)
    if n > 1 and off > 0.06:
        for dx in (0, n // 2):
            for dz in (0, n // 2):
                cover(ix + dx, iz + dz, n // 2, hint)
        return
    x0, z0, size, h, sx, sz = t
    for dx in range(n):
        for dz in range(n):
            tiles[(ix + dx, iz + dz)] = t
    ax = unit((1.0, sx, 0.0))
    ay = unit(cross((0.0, sz, 1.0), ax))
    az = cross(ax, ay)
    mx_, mz_ = x0 + size / 2, z0 + size / 2
    # Sized to the slope (2026-11-15, Hugo: "the slope starts showing edges when at a steeper angle"). The tile's top
    # is the floor's plane over its square of ground: along X that is e1 = (size, sx size, 0), along Z e2 = (0, sz size,
    # size). A box sized `size` along its tilted axes covered only size x cos(slope) of ground, so on the steep stretches
    # tiles stood up to 1.3 studs apart and the next one's plain side showed as a line. Now the box is e1 long along X
    # (plus how far e2 leans along X, so the slanted square is covered), and e2's own length along Z; still 0.1 over.
    e2x = sz * size * ax[1]  # e2 . ax (ax has no z)
    e2z = sz * size * az[1] + size * az[2]  # e2 . az
    long_x = size * math.sqrt(1.0 + sx * sx) + abs(e2x) + 0.1
    long_z = e2z + 0.1
    # The picture (16 studs a tile) laid on the world's grid, as on flat ground: stretched by the slope so four tiles
    # of it span each 64 of ground, and slid so its lines fall where a flat tile's would (that tile's +X and +Z edges
    # 0.05 past the square). On a part's Top, U runs along X from the +X edge and V along Z from the +Z edge (`cell`).
    su, sv = 16.0 / ax[0], 16.0 / az[2]
    ou = wrap((size / 2 + 0.05) / ax[0] - long_x / 2, su)
    ov = wrap((size / 2 + 0.05) / az[2] - long_z / 2, sv)
    tilted = abs(sx) > 1e-6 or abs(sz) > 1e-6
    add("Seabed", "ground", (mx_ - ay[0] * PLINTH / 2, h - ay[1] * PLINTH / 2, mz_ - ay[2] * PLINTH / 2), (long_x, PLINTH, long_z),
        GROUND[min(land_at(hint + (border_wave(mx_, mz_) if PROPS2 else 0.0)), len(GROUND) - 1)], ax, ay, az, tex={"top": [su, sv, ou, ov]} if tilted else None)
    count["ground"] += 1
    count["tile%d" % n] = count.get("tile%d" % n, 0) + 1


def border_wave(x, z):
    """how far a land's border is pushed along the lane here: a wavy line, not a straight cut (the reference's borders,
    research/ride-a-dino/details: the floor's colour changes along a wavy line through the neck)"""
    return 34.0 * math.sin(x / 41.0 + z / 97.0) + 18.0 * math.sin(z / 23.0 - x / 61.0)


for (cx_, cz_), hint in sorted(cells.items()):
    cover(cx_ * 4, cz_ * 4, 4, hint)


def top_at(t, x, z):
    return t[3] + t[4] * (x - t[0] - t[2] / 2) + t[5] * (z - t[1] - t[2] / 2)


worst = 0.0  # how far two neighbouring tiles' tops are apart, along the edges they share
for (ix, iz), t in tiles.items():
    for dx, dz in ((1, 0), (0, 1)):
        other = tiles.get((ix + dx, iz + dz))
        if other and other is not t:
            for e in (0.0, 0.5, 1.0):  # along the small cell's side that the two share
                x = (ix + (1 if dx else e)) * CELL
                z = (iz + (1 if dz else e)) * CELL
                worst = max(worst, abs(top_at(t, x, z) - top_at(other, x, z)))

for g in necks:  # a line of flags across every neck
    c, rt = centre(g), right(g)
    lo, hi = -half(-1, g) - 6, half(1, g) + 6
    if PROPS2:  # the reference's bunting: a dark rope on two posts, sagging, pastel flags hanging from it
        posts = [across(g, lo + 4), across(g, hi - 4)]
        for q in posts:
            add("FlagPost", "trim", (q[0], q[1] + 19, q[2]), (2.4, 40, 2.4), (92, 70, 52), rt, (0, 1, 0), ahead(g), solid=False)
            add("FlagPost", "trim", (q[0], q[1] + 39.5, q[2]), (3.6, 1.6, 3.6), (250, 250, 250), rt, (0, 1, 0), ahead(g), solid=False)
        segs = max(8, int((hi - lo - 8) / 14))
        pts = []
        for j in range(segs + 1):
            t = j / segs
            q = across(g, lo + 4 + t * (hi - lo - 8))
            pts.append((q[0], q[1] + 38 - 9 * math.sin(math.pi * t), q[2]))
        for a_, b_ in zip(pts, pts[1:]):
            m_ = tuple((a_[i] + b_[i]) / 2 for i in range(3))
            d_ = tuple(b_[i] - a_[i] for i in range(3))
            ln = math.sqrt(sum(v * v for v in d_))
            ax_ = tuple(v / ln for v in d_)
            up_ = unit(cross(ax_, ahead(g)))
            if up_[1] < 0:
                up_ = tuple(-v for v in up_)
            add("FlagLine", "trim", m_, (ln + 0.2, 0.5, 0.5), (60, 50, 50), ax_, up_, unit(cross(ax_, up_)), solid=False)
        pastel = ((140, 220, 210), (250, 226, 140), (200, 180, 240), (160, 210, 250), (250, 180, 200), (250, 190, 140))
        for j in range(1, segs):
            if j % 1 == 0:
                q = pts[j]
                add("Flag", "trim", (q[0], q[1] - 3, q[2]), (4.2, 5.2, 0.4), pastel[(j * 7 + int(g)) % 6], rt, (0, 1, 0), ahead(g), solid=False)
        continue
    m = across(g, (lo + hi) / 2)
    add("FlagLine", "trim", (m[0], m[1] + 34, m[2]), (hi - lo, 0.6, 0.6), (250, 250, 250), rt, (0, 1, 0), ahead(g), solid=False)
    n = max(9, int((hi - lo) / 9))
    for j in range(n):
        q = across(g, lo + 5 + j * (hi - lo - 10) / (n - 1))
        add("Flag", "trim", (q[0], q[1] + 31.3, q[2]), (4.6, 5, 0.4), ((250, 200, 80), (240, 110, 130), (110, 190, 240), (140, 220, 150), (250, 250, 250))[j % 5], rt, (0, 1, 0), ahead(g), solid=False)


# ---------------------------------------------------------------- the assets (tools/map/props.py)
def place(name, base, scale, turn_deg, ground, seed):
    for n, p, size, col, ax in props.bricks(name, seed, ground):
        q = props.turn(p, yaw=turn_deg)
        axes = tuple(props.turn(a, yaw=turn_deg) for a in ax)
        add(f"{name}_{count['prop']}_{n}", "prop", (base[0] + q[0] * scale, base[1] + q[1] * scale, base[2] + q[2] * scale),
            tuple(v * scale for v in size), col, *axes)
    count["prop"] += 1


# PROPS2=1 (a trial, 2026-11-18): lands 1 and 2 get the rebuilt props (tools/map/props2.py: bricks a third of a fish,
# each carrying the group it breaks with) spread in clusters the way the reference spreads its own (docs/design/
# props-and-landmarks.md, "How they spread"); the other lands keep the first-pass kit. Off, nothing changes.


def colour_run(at, x, seed):
    """which colourway: neighbours mostly share one, in patches of the floor about 150 studs long, one side at a
    time, and one in four picks its own (order with hints of chaos: colour reads as patches, not confetti)"""
    r = random.Random(seed * 7 + 1)
    if r.random() < 0.25:
        return None
    return hash((int(at // 150), x > 0)) % 3


def tint_at(at, right, land, seed, big=False):
    """the colourway a thing wears in the first lands (2026-11-23, docs/design/colour.md, "A bit less random"). A room has one
    it leads with and a guest; a patch of about 150 studs on one side is all of one of them: the hero, its companions, the
    dressing round it and the lip above it. One big thing in ten strays. The later lands keep their own dice: None"""
    if land >= props2.EARLY:
        return None
    mine = [room for room in rooms if room["land"] == land]
    k_ = max([i_ for i_, room in enumerate(mine) if room["s0"] <= at], default=0)
    if land == 0:  # orange; gold as the guest, the Reef's pink only on the way to it
        lead, guest = 0, 2 if k_ >= len(mine) - 2 and len(mine) > 2 else 1
    elif land == 1:  # teal, violet, raspberry, room by room
        lead, guest = (1, 2, 0)[k_ % 3], (2, 0, 1)[k_ % 3]
    else:
        lead, guest = 0, 1
    tr = random.Random(land * 1009 + int(at // 150) * 31 + (1 if right else 0) * 7 + 5)
    t = guest if tr.random() < 0.22 else lead
    if big and random.Random(seed * 13 + 11).random() < 0.1:
        t = guest if t == lead else lead
    return t


def place2(name, base, scale, turn_deg, land, seed, way=None, aspect=None, broken=False, tint=None):
    """a rebuilt prop: each brick a part, with its break group ("g") and whether it is studded ("st"); the small
    dressing never collides. `aspect` stretches it taller and thinner (over 1) or shorter and wider (under 1), so one
    kind comes in several shapes; `broken` lays it as its chunks lying at its foot, as if a herd had been through"""
    ways = len(props2.PALETTES[land])
    bs = props2.bricks(name, seed, land, way % ways if way is not None else None, tint)
    if broken:
        import prop_drafts2
        _air, lying = prop_drafts2.frames(bs, seed)
        bs = [(n, (q[0] - 30, q[1], q[2] * 0.6), sz, c, ax, st, "dressing") for n, q, sz, c, ax, st in lying]
    if aspect and aspect != 1.0 and bs and bs[0][6] != "dressing":
        sy, sxz = aspect, 1 / math.sqrt(aspect)
        out_ = []
        for n, p, size, col, ax, studs, group in bs:
            k_ = (sxz, sy, sxz)
            size2 = tuple(size[i] * math.sqrt(sum((ax[i][j] * k_[j]) ** 2 for j in range(3))) for i in range(3))
            out_.append((n, (p[0] * sxz, p[1] * sy, p[2] * sxz), size2, col, ax, studs, group))
        bs = out_
    # a few degrees of tilt on the props that stand (not the flat dressing): order with hints of chaos
    tr = random.Random(seed * 17 + 3)
    tilt = (tr.uniform(-4, 4), tr.uniform(-4, 4)) if bs and bs[0][6] != "dressing" else (0.0, 0.0)
    for n, p, size, col, ax, studs, group in bs:
        q = props.turn(props.turn(p, pitch=tilt[0], roll=tilt[1]), yaw=turn_deg)
        axes = tuple(props.turn(props.turn(a, pitch=tilt[0], roll=tilt[1]), yaw=turn_deg) for a in ax)
        add(f"{name}_{count['prop']}_{n}", "prop", (base[0] + q[0] * scale, base[1] + q[1] * scale, base[2] + q[2] * scale),
            tuple(v * scale for v in size), col, *axes, solid=group != "dressing")
        parts[-1]["g"], parts[-1]["st"] = group, studs
    count["prop"] += 1


def radius2(name, scale, seed, land):
    hx, _hy, hz = props.extent([b[:5] for b in props2.bricks(name, seed, land)])
    return max(hx, hz) * scale


def spread2(room, li, stop, placed, big_world):
    """the reference's way, read off its frames: most of the floor empty; the big things in loose groups (a hero, one
    or two smaller companions, a ring of dressing and a sprinkle of crumbs) along the sides, filling the bays where a
    wall bows out; a few small things in the middle after the first land; dressing in patches everywhere, thicker
    near the walls and the groups; middling props standing in rows along the terrace lips"""
    length = stop - room["s0"]
    big = [n for n in props2.LANDS[li] if props2.ASSETS[n][1] == "big"]
    mid = [n for n in props2.LANDS[li] if props2.ASSETS[n][1] == "mid"] or big
    dress = props2.DRESSING[li]
    prng = random.Random(7700 + room["seed"])
    area = length * width(room["s0"] + length / 2)
    groups = max(1, round(area / (9000.0 if li == 0 else 7000.0)))
    side = prng.choice((-1, 1))
    for _g in range(groups):
        for _try in range(10):
            at = prng.uniform(max(room["s0"] + 40, 420.0), stop - 40)
            if at >= stop - 40:
                break
            hero = prng.choice(big)
            scale = prng.uniform(1.0, 1.35) * (1.7 if _g == 0 and groups > 1 else 1.0)  # one big one a room, small ones round it
            radius = radius2(hero, scale, count["prop"], li)
            hi = half(side, at) - radius - 8
            if hi < 0.45 * half(side, at) or width(at) < radius * 2 + 80:
                continue
            x = side * prng.uniform(0.62 * half(side, at), hi) if hi > 0.62 * half(side, at) else side * hi
            if any(math.hypot(at - ps, x - px) < radius + pr + 50 for ps, px, pr in placed):
                continue
            here = across(at, x)
            way = colour_run(at, x, count["prop"])
            tint = tint_at(at, x > 0, li, count["prop"], big=True)  # the whole group wears its hero's
            place2(hero, here, scale, prng.uniform(0, 360), li, count["prop"], way=way, aspect=prng.choice((0.75, 0.9, 1.0, 1.0, 1.15, 1.3)), tint=tint)
            if prng.random() < 0.15:  # now and then one already broken beside it, its chunks lying (the herds came through)
                place2(prng.choice(big + mid), across(at + radius + 12, x * 0.9), scale * 0.8, prng.uniform(0, 360), li, count["prop"], way=way, broken=True, tint=tint)
            placed.append((at, x, radius))
            big_world.append([round(here[0], 1), round(here[2], 1), round(radius, 1)])
            count["big"] += 1
            for _c in range(prng.randint(1, 2)):  # companions, nestled beside it, a little toward the wall or along
                a = prng.uniform(0, math.tau)
                cs, cx = at + math.cos(a) * (radius + 14), x + side * abs(math.sin(a)) * (radius * 0.4) + math.sin(a) * 6
                cx = max(-half(-1, cs) + 10, min(half(1, cs) - 10, cx))
                name = prng.choice(mid + big)
                sc = prng.uniform(0.6, 0.85)
                place2(name, across(cs, cx), sc, prng.uniform(0, 360), li, count["prop"], way=way if prng.random() < 0.7 else None,
                       aspect=prng.choice((0.8, 1.0, 1.2)), tint=tint)
                big_world.append([round(across(cs, cx)[0], 1), round(across(cs, cx)[2], 1), round(radius2(name, sc, count["prop"], li), 1)])
            for _d in range(prng.randint(4, 7)):  # a ring of dressing round the group
                a, dd = prng.uniform(0, math.tau), prng.uniform(radius + 6, radius + 34)
                ds, dx = at + math.cos(a) * dd, x + math.sin(a) * dd
                dx = max(-half(-1, ds) + 6, min(half(1, ds) - 6, dx))
                place2(prng.choice(dress), across(ds, dx), prng.uniform(1.0, 1.6), prng.uniform(0, 360), li, count["prop"], tint=tint)
            side = -side if prng.random() < 0.75 else side  # mostly alternating sides, now and then two on one side
            break
    if li > 0 and prng.random() < 0.45:  # now and then a small thing in the middle: the herd's road stays open
        at = prng.uniform(room["s0"] + 60, stop - 60)
        x = prng.uniform(-0.2, 0.2) * width(at) / 2
        name = prng.choice(mid)
        place2(name, across(at, x), prng.uniform(0.7, 0.9), prng.uniform(0, 360), li, count["prop"], tint=tint_at(at, x > 0, li, count["prop"]))
        placed.append((at, x, radius2(name, 0.8, count["prop"], li)))
    prng = random.Random(8800 + room["seed"])
    for _ in range(int(length / 55)):  # dressing in patches everywhere, more toward the walls
        at = prng.uniform(room["s0"] + 20, stop - 20)
        sd = prng.choice((-1, 1))
        x = sd * min(0.95, abs(prng.gauss(0.62, 0.28))) * half(sd, at)
        for _ in range(prng.randint(1, 3)):
            s2, x2 = at + prng.uniform(-10, 10), x + prng.uniform(-10, 10)
            x2 = max(-half(-1, s2) + 6, min(half(1, s2) - 6, x2))
            place2(prng.choice(dress), across(s2, x2), prng.uniform(1.0, 1.7), prng.uniform(0, 360), li, count["prop"], tint=tint_at(at, sd > 0, li, count["prop"]))


def place_set(bs, base, yaw_deg, scale=1.0):
    """a set piece's bricks (tools/map/setpieces.py): solid where they are stone, see-through where they glow or smoke"""
    for n, p, size, col, ax, studs, group in bs:
        q = props.turn(tuple(v * scale for v in p), yaw=yaw_deg)
        axes = tuple(props.turn(a, yaw=yaw_deg) for a in ax)
        kind = "setglow" if n == "Glow" else ("setsmoke" if n == "Smoke" else "set")
        add(f"Set_{count['prop']}_{n}", kind, (base[0] + q[0], base[1] + q[1], base[2] + q[2]), tuple(v * scale for v in size), col, *axes,
            solid=kind == "set", t=0.55 if kind == "setsmoke" else 0.0)
    count["prop"] += 1



prng = random.Random(77)
placed = []  # (s, x across, radius) of every big thing, so two never crowd the same water
big_world = []  # the same, as world x, z and radius
if PROPS2:
    count["lip"] = count["tall"] = count["shelf"] = count["mouth"] = count["set"] = 0
    # the later lands' set pieces: a gate at the neck where each begins, big lit pieces in its rooms, clear of the rest
    for li in range(4, 10):
        s0 = starts[li]
        s1 = starts[li + 1] if li + 1 < len(starts) else BUILD_TO
        if s0 >= BUILD_TO:
            break
        gate_s = min(necks, key=lambda n_: abs(n_ - s0))
        span = width(gate_s) * 0.92
        mid_x = (half(1, gate_s) - half(-1, gate_s)) / 2
        place_set(setpieces.bricks_of(setpieces.GATES[li], span, li, seed=li * 31), across(gate_s, mid_x), math.degrees(heading(gate_s)))
        count["set"] += 1
        inner = [n_ for n_ in necks if s0 + 80 < n_ < s1 - 80] + [s1]
        prev, sd, k_ = gate_s, 1, 0
        for n_ in inner:
            for f in (0.3, 0.7):
                at = prev + (n_ - prev) * f
                hero = setpieces.HEROES[li][k_ % len(setpieces.HEROES[li])]
                vr = random.Random(int(at))
                extra = vr.uniform(-35, 35)  # each copy turned its own way
                scale = setpieces.HERO_SCALE * vr.uniform(0.8, 1.2)  # and its own size
                # smoke drifts outward, toward the wall on its side, and one in six strays the other way
                out_ = sd if vr.random() > 1 / 6 else -sd
                lane_drift = (out_ * vr.uniform(3.5, 6.5), vr.uniform(-2.5, 3.0))
                a_ = math.radians(-extra)
                setpieces.SMOKE = (lane_drift[0] * math.cos(a_) + lane_drift[1] * math.sin(a_), -lane_drift[0] * math.sin(a_) + lane_drift[1] * math.cos(a_))
                bs = setpieces.bricks_of(hero, li, seed=int(at * 7) + li)
                setpieces.SMOKE = None
                hx, _hy, hz = props.extent([b[:5] for b in bs])
                rad = max(hx, hz) * scale
                x = sd * (half(sd, at) - rad - 24.0)
                if half(sd, at) - rad - 24.0 > 30.0 and all(math.hypot(at - ps, x - px) > rad + pr + 4 for ps, px, pr in placed):
                    place_set(bs, across(at, x), math.degrees(heading(at)) + extra, scale)
                    placed.append((at, x, rad))
                    big_world.append([round(across(at, x)[0], 1), round(across(at, x)[2], 1), round(rad, 1)])
                    count["set"] += 1
                sd, k_ = -sd, k_ + 1
            prev = n_

for room in rooms:
    if room["s0"] > BUILD_TO - 80:
        break
    stop = min(room["s1"], BUILD_TO)
    length = stop - room["s0"]
    li = land_at(room["s0"] + 5)
    if PROPS2:
        spread2(room, li, stop, placed, big_world)
        continue
    ground = GROUND[min(li, len(GROUND) - 1)]
    kit = props.LANDS[ASSET_SET[li]]
    # each room draws its own numbers, one stream for each kind of thing, so changing how one kind is placed never
    # moves another (grey-box 6 moved the big assets by accident when the terraces changed)
    prng = random.Random(7700 + room["seed"])
    # Big things stand toward the sides: the middle of the lane is the herd's road and the rider's, and a thing in it
    # stops both (the user, 2026-11-12: a few in the middle work, not many, and none at the start). So: none in the
    # first 420 studs; in the first land none in the middle at all; after it, now and then, one to a room.
    middle = 0 if li == 0 else (1 if prng.random() < (0.35 if li == 1 else 0.6) else 0)
    for number in range(int(length / (170 if li == 0 else 95)) + middle):
        in_middle = number < middle
        for _try in range(8):
            at = prng.uniform(max(room["s0"] + 30, 420.0), stop - 30)
            if at >= stop - 30:
                break
            name = prng.choice(kit)
            scale = prng.uniform(0.85, 1.2) if props.ASSETS[name][1] != "huge" else prng.uniform(0.9, 1.05)
            hx, _hy, hz = props.extent(props.bricks(name, count["prop"], ground))
            radius = max(hx, hz) * scale
            lo, hi = -half(-1, at) + radius * 0.6 + 6, half(1, at) - radius * 0.6 - 6
            if hi - lo < 20 or width(at) < radius * 2 + 70:  # never where it would plug a neck
                continue
            if in_middle:
                x = prng.uniform(0.3 * lo, 0.3 * hi)
            else:  # in the outer third of the lane, on one side or the other
                x = prng.uniform(0.68 * hi, hi) if prng.random() < 0.5 else prng.uniform(lo, 0.68 * lo)
            if all(math.hypot(at - ps, x - px) > radius + pr + 42 for ps, px, pr in placed):
                turn_deg = math.degrees(heading(at)) + (prng.uniform(-30, 30) if props.ASSETS[name][1] == "huge" else prng.uniform(0, 360))
                place(name, across(at, x), scale, turn_deg, ground, count["prop"])
                placed.append((at, x, radius))
                big_world.append([round(across(at, x)[0], 1), round(across(at, x)[2], 1), round(radius, 1)])
                count["big"] += 1
                break
    prng = random.Random(8800 + room["seed"])
    for _ in range(int(length / 60)):  # small dressing, in loose groups
        at = prng.uniform(room["s0"] + 20, stop - 20)
        x = prng.uniform(-half(-1, at) + 10, half(1, at) - 10)
        for _ in range(prng.randint(2, 5)):
            s2, x2 = at + prng.uniform(-14, 14), x + prng.uniform(-14, 14)
            x2 = max(-half(-1, s2) + 6, min(half(1, s2) - 6, x2))
            place(prng.choice(("sea_grass", "sea_grass", "stones", "floor_tiles")), across(s2, x2), prng.uniform(1.0, 1.8), prng.uniform(0, 360), ground, count["prop"])
    prng = random.Random(9900 + room["seed"])
    here = [q for q in terrace_spots if room["s0"] + 30 < q[0] < stop - 30]
    for _ in range(min(len(here), int(length / 55))):  # and standing on the terraces
        at, x, y, z = prng.choice(here)
        place(prng.choice(props.TERRACE[ASSET_SET[li]]), (x, y, z), prng.uniform(0.7, 1.0), prng.uniform(0, 360), ground, count["prop"])

# ---------------------------------------------------------------- stage 2: the walls and rooms dressed (PROPS2)
if PROPS2:
    tier_tops = {}  # (side, tier): [(s, top)], for a face's exposed height
    for side, j, fa, fb, o, top, at, deep, back in wall_pieces:
        tier_tops.setdefault((side, j), []).append((at, top))
    for key in tier_tops:
        tier_tops[key].sort()

    def tier_top_at(side, j, at):
        rows_ = tier_tops.get((side, j))
        if not rows_:
            return None
        lo_, hi_ = 0, len(rows_) - 1
        while lo_ < hi_:
            m_ = (lo_ + hi_) // 2
            if rows_[m_][0] < at:
                lo_ = m_ + 1
            else:
                hi_ = m_
        return rows_[lo_][1]

    drng = random.Random(4242)
    run = {}  # (side, tier): studs walked along since the last lip piece, tall piece and shelf
    for side, j, fa, fb, o, top, at, deep, back in wall_pieces:
        if at < 300.0 or at > BUILD_TO - 40 or top + GRASS > -10.0:  # not in the gate's mouth, nor out of the water
            continue
        li = min(land_at(at), 9)
        lf = math.hypot(fb[0] - fa[0], fb[1] - fa[1])
        if lf < 1.0:
            continue
        al = ((fb[0] - fa[0]) / lf, 0.0, (fb[1] - fa[1]) / lf)
        r_ = run.setdefault((side, j), {"lip": drng.uniform(0, 12), "tall": drng.uniform(0, 60), "shelf": drng.uniform(0, 40)})
        y_top = top + GRASS
        # the lip row: the land's smallest piece in an even row along every lip, set back a little (the reference:
        # one at a time, 1 or 2 studs back, every 12 to 25 studs; on the high tops further apart)
        gap = 22.0 if j < 2 else 36.0
        r_["lip"] += lf
        while r_["lip"] >= gap:
            r_["lip"] -= gap * drng.uniform(0.7, 1.3)  # the spacing even, give or take
            t = 1.0 - r_["lip"] / lf
            if 0.0 <= t <= 1.0 and drng.random() > 0.08:  # now and then one missing
                q = (fa[0] + (fb[0] - fa[0]) * t + o[0] * drng.uniform(1.5, 3.5), y_top, fa[1] + (fb[1] - fa[1]) * t + o[2] * drng.uniform(1.5, 3.5))
                name = props2.LIP[li] if drng.random() > 0.12 else drng.choice(props2.DRESSING[li])  # and now and then another small thing
                place2(name, q, drng.uniform(0.9, 1.5), drng.uniform(0, 360), li, count["prop"], tint=tint_at(at, side > 0, li, count["prop"]))
                count["lip"] += 1
        # the first layer's tall things, smaller higher up; the treads between stay bare
        if deep >= 14:
            r_["tall"] += lf
            every = 170.0 if j == 0 else 300.0
            if r_["tall"] >= every:
                r_["tall"] -= every * drng.uniform(0.7, 1.3)
                name = props2.TALL[li] if j == 0 else drng.choice([n for n in props2.LANDS[li] if props2.ASSETS[n][1] != "small"])
                sc = drng.uniform(0.75, 0.95) if j == 0 else drng.uniform(0.45, 0.6)
                q = ((fa[0] + fb[0]) / 2 + o[0] * deep * 0.55, y_top, (fa[1] + fb[1]) / 2 + o[2] * deep * 0.55)
                place2(name, q, sc, drng.uniform(0, 360), li, count["prop"], tint=tint_at(at, side > 0, li, count["prop"], big=True))
                count["tall"] += 1
        # shelves on the face: short slabs of the cap's colour, staggered, never in line (2 or 3 a stretch)
        lower = floor_y(at) if j == 0 else tier_top_at(side, j - 1, at)
        if lower is not None and top - lower >= 3 * SQUARE:
            r_["shelf"] += lf
            if r_["shelf"] >= 46.0:
                r_["shelf"] -= drng.uniform(30, 60)
                length, depth = drng.uniform(6, 15), drng.uniform(3, 4.5)
                steps = int((top - lower) / SQUARE) - 1
                y_ = lower + SQUARE * drng.randint(1, max(1, steps))
                t = drng.uniform(0.2, 0.8)
                mx_ = fa[0] + (fb[0] - fa[0]) * t - o[0] * depth / 2
                mz_ = fa[1] + (fb[1] - fa[1]) * t - o[2] * depth / 2
                ground_, _face = lane_colours(at)
                add("Shelf", "grass", (mx_, y_ + 1.5, mz_), (depth, 3.0, length), ground_, o, (0, 1, 0), al)
                count["shelf"] += 1
    # a tall piece at each room's mouth, sides alternating (the reference: one tall prop on one side)
    side_ = 1
    for g in necks[1:]:
        at = g + 60.0
        if at > BUILD_TO - 60:
            break
        li = min(land_at(at), 9)
        x = side_ * (half(side_, at) - 22.0)
        place2(props2.TALL[li], across(at, x), 1.0, drng.uniform(0, 360), li, count["prop"], tint=tint_at(at, side_ > 0, li, count["prop"]))
        count["mouth"] += 1
        side_ = -side_
    print("stage 2: %(lip)d lip pieces, %(tall)d tall pieces on the terraces, %(shelf)d shelves, %(mouth)d mouth markers, %(set)d set pieces" % count)


# ---------------------------------------------------------------- the hub: a closed bowl, its floor level with the water
# Sized from the reference's own hub (docs/reference/ride-a-dino-map.md, "The hub, measured"): a walk of a few seconds
# from the pens to the start, pens in a row along the far side and round the corners, stalls just inside the start.
add("HubFloor", "hub", (0, 0.5 - 60, HUB_BACK / 2), (HUB_HALF * 2, 120, -HUB_BACK), HUB_GROUND)
add("StartStrip", "trim", (0, 0.75, FRONT / 2), (GATE * 2, 0.5, -FRONT), HUB_LOOK["strip"], solid=False)
if STRIP_IN > 0:  # (a trial) the strip carried on out onto the hub's floor
    add("StartApron", "trim", (0, 0.75, FRONT - STRIP_IN / 2), ((GATE + STRIP_WIDE) * 2, 0.5, STRIP_IN), HUB_LOOK["strip"], solid=False)
for z_, line_half in ((FRONT - STRIP_IN + 1.0, GATE + (STRIP_WIDE if STRIP_IN > 0 else 0)), (-1.0, GATE)):  # a white line along each
    # edge of it, as the reference's start zone has
    add("StartLine", "trim", (0, 0.8, z_), (line_half * 2, 0.5, 2.0), (250, 250, 250), solid=False)
# (the line of flags over the start went when the gate got its arch: tools/map/hub_kit.py)


PLOT = (88.0, 56.0, 34.0)  # an aquarium (88 wide since 2026-11-12, so four fill the back between the side rows). The reference's pen is about 50 by 62 for dinos up to 40 long; our biggest
# creatures are nearly 50 long, so the tank is wider, and tall, because fish use the height
PLOT_COLOURS = [(240, 110, 130), (255, 170, 70), (250, 215, 90), (120, 200, 120), (90, 190, 220), (120, 140, 240), (180, 120, 230), (240, 140, 200)]


# The reference's pens stand in a U: a row along the far side from the start and a row down each side, sharing fences,
# open toward the start. Ours the same: four along the back, two down each side beginning where the back row's pads end.
# Since 2026-11-17 they stand where the user placed them by hand in Studio: the back row side by side 7 studs in front (15 since W32, 2026-11-22)
# of the back wall, two down each side, the left pair a little nearer the start than the right. The side rows are
# moved in with the walls, 7 studs from them too. A plot's middle is 27 in front of its tank's back (hub_kit.plot).
# S (2026-11-23): eight pens, 47 by 62 with 4 of grass between them, 21 and 25 of grass behind: hub_scale_plan.py
import hub_scale_plan  # noqa: E402

plots = [(i + 1, (a + b) / 2, (c + e) / 2, 0 if g[2] == 0 else (90 if g[2] > 0 else -90))
         for i, ((a, b, c, e), g) in enumerate(zip(hub_scale_plan.s_pens, hub_scale_plan.s_gates))]
# The hub's models (the tanks and their trainers, the stations, the gate's arch, the landmark, the small things) are
# tools/map/hub_kit.py's: richer than a plain box (round things, glows, words), so they go to their own file, hub.json,
# and into Studio by tools/map/hub_luau.py. Only the numbers they stand on are given from here.
import hub_kit  # noqa: E402

hub_in = {"Half": HUB_HALF, "Back": HUB_BACK, "Front": FRONT, "Gate": GATE, "GateTurn": GATE_TURN, "FrontTurn": FRONT_TURN,
          "StartDepth": START_DEPTH, "Look": HUB_LOOK, "Plot": PLOT, "PlotColours": PLOT_COLOURS, "Plots": sorted(plots),
          "GateLedge": HUB_LEDGE_GATE, "Shift": HUB_SHIFT,
          "Ledge": [{"Side": w[0], "A": w[2], "B": w[3], "Out": [w[4][0], w[4][2]], "Top": w[5] + GRASS, "Deep": w[7], "S": w[6]}
                    for w in wall_pieces if w[1] == 0 and w[6] < -48.0]}  # the first terrace, for what lies on it
os.makedirs(OUT, exist_ok=True)
json.dump(hub_in, open(os.path.join(OUT, "hub_in.json"), "w"), indent=1)
hub_parts = hub_kit.build(hub_in)
json.dump({"parts": hub_parts}, open(os.path.join(OUT, "hub.json"), "w"))
add("DockSpawn", "trim", (0.0, 1.0, -88.0), (14, 1, 14), (255, 255, 255), t=1.0)  # S: 56 studs in from the start, behind the two
# stalls (the user put it between them on 2026-11-17, at -115.2 in the older hub); see-through, as the user hid it under the floor
add("Figure", "figure", (10, 3.5, -84), (2, 5, 1), (90, 170, 230))

SEA = 2000.0  # the sea's surface, in tiles this big, over the hub and the whole lane
sea = set()
for k in range(0, len(line), 25):
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            sea.add((math.floor(line[k][0] / SEA) + dx, math.floor(line[k][1] / SEA) + dz))
for gx, gz in sorted(sea):
    add("SeaTile", "water", ((gx + 0.5) * SEA, -0.25, (gz + 0.5) * SEA), (SEA, 0.5, SEA), (70, 190, 215), solid=False)

# ---------------------------------------------------------------- what the game code reads: the path
path = []  # the lane's TRUE middle (half way between its two edges) and its whole width there
for v in nodes:
    m = across(v, (half(1, v) - half(-1, v)) / 2)
    path.append([round(v, 1), round(m[0], 1), round(floor_y(v), 1), round(m[2], 1), round(width(v), 1), 0])

os.makedirs(OUT, exist_ok=True)
json.dump({"parts": parts}, open(os.path.join(OUT, "parts.json"), "w"))
json.dump({"PathFields": "s, x, y, z, w, c. x and z are the lane's true middle; w is wall to wall there (it narrows at a neck); c is always 0",
           "Path": path, "BuiltTo": BUILD_TO, "Necks": [round(g, 1) for g in necks],
           "Sides": {name: [{"S0": round(sp["s0"], 1), "S1": round(sp["s1"], 1), "Kind": sp["kind"], "Out": round(PINCH + sp["bulge"])} for sp in spans[side] if sp["s0"] < BUILD_TO]
                     for name, side in (("Left", -1), ("Right", 1))},
           "Big": [[round(a_, 1), round(x_, 1), round(r_, 1)] for a_, x_, r_ in placed],
           "BigWorld": big_world,
           "Lands": [{"Name": l[0], "S0": st} for l, st in zip(LANDS, starts)], "Profile": [[round(a_, 1), round(-b_, 1)] for a_, b_ in profile]},
          open(os.path.join(OUT, "path.json"), "w"), indent=1)
kinds = {}
for p in parts:
    kinds[p["k"]] = kinds.get(p["k"], 0) + 1
widths = [width(v) for v in nodes]
print({k: v for k, v in count.items() if k.startswith("tile")})
print(len(parts), "parts:", kinds, "| assets:", count["prop"], "of them big:", count["big"], "| necks:", len(necks),
      "| width", round(min(widths)), "to", round(max(widths)))
print("flush check: neighbouring floor tiles are at most", round(worst, 3), "studs apart in height | steepest floor",
      round(max(slope_at(v) for v in nodes), 1), "degrees | wall ends standing clear:", count["ends"],
      "| depth at the end of what is built:", round(-floor_y(BUILD_TO)), "| whole dive:", round(depths[int(TOTAL)]))

# ---------------------------------------------------------------- the plan, from above
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    raise SystemExit
shown = [p for p in parts if p["k"] not in ("water", "far", "barrier")]
for q in hub_parts:  # the hub's models, as plain boxes
    if "s" in q and q.get("t", 0) < 1 and q["p"][1] > -1:
        zx = [q["x"][1] * q["y"][2] - q["x"][2] * q["y"][1], q["x"][2] * q["y"][0] - q["x"][0] * q["y"][2], q["x"][0] * q["y"][1] - q["x"][1] * q["y"][0]]
        shown.append({"k": "station", "p": q["p"], "s": q["s"], "x": q["x"], "y": q["y"], "z": zx, "c": q["c"]})
xs = [p["p"][0] for p in shown]
zs = [p["p"][2] for p in shown]
pad = 160
x0, x1, z0, z1 = min(xs) - pad, max(xs) + pad, min(zs) - pad, max(zs) + pad
W = 3000
sc = W / (z1 - z0)
H = int((x1 - x0) * sc)
im = Image.new("RGB", (W, H), (58, 118, 168))
d = ImageDraw.Draw(im)
order = {"glow": 4, "barrier": 0, "ground": 1, "plain": 1, "hub": 1, "face": 1, "grass": 1, "core": 1, "fill": 1, "prop": 3, "station": 3, "glass": 3, "trim": 4, "figure": 5, "set": 3, "setglow": 4, "setsmoke": 4}
for p in sorted(shown, key=lambda q: (order[q["k"]], q["p"][1] + q["s"][1] / 2)):
    hx, hz = p["s"][0] / 2, p["s"][2] / 2
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        wx = p["p"][0] + p["x"][0] * hx * sx + p["z"][0] * hz * sz
        wz = p["p"][2] + p["x"][2] * hx * sx + p["z"][2] * hz * sz
        pts.append(((wz - z0) * sc, (wx - x0) * sc))
    col = tuple(p["c"])
    if p["k"] in ("grass", "fill"):  # raised ground a shade darker, so the terraces show from above
        col = tuple(int(c * 0.86) for c in col)
    d.polygon(pts, fill=col)
try:
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
except OSError:  # not on Windows (Hugo's PC): any bold sans
    font = ImageFont.truetype("DejaVuSans-Bold.ttf", 26)
d.text((20, 14), f"Grey-box 15 from above: the hub (left) and all ten lands, {BUILD_TO:,.0f} studs. Straight at first, then bends, wider as it goes. Wall tops are a shade darker.", font=font, fill=(255, 255, 255))
if not os.environ.get("GREYBOX_OUT"):
    im.save(os.path.join(ROOT, "docs", "attachments", "map-greybox-plan.png"))
print("plan drawn")
