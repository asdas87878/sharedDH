"""Grey-box 9 of the map (docs/design/map-method.md, docs/design/map-structure.md): the reference's build, shaped for a
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
face (a wall's side), grass (a wall's top slab), core (hidden filling), barrier (unseen, solid), far (the backdrop),
glass, prop, trim, station, figure, water. Everything is a plain box. Nothing here is tuned yet."""
import json
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "map", "greybox")

# ---------------------------------------------------------------- the numbers
PINCH = 60.0  # how close a side comes to the lane's line where it pinches in, at the start of the dive
BULGE_BIG, BULGE_SMALL = (120.0, 180.0), (60.0, 100.0)  # how far a side swells between two of its pinches
BULGE_FIRST = (30.0, 55.0)  # and in the first land: a plain, easy run
WIDER = 2.0  # the lane is 1 + WIDER times as wide at the very end of the dive as at its start
ROOM = (420.0, 700.0)  # the distance between one side's pinches
OFFSET = (0.24, 0.42)  # the other side pinches this share of a room further on (or back)
MOUTH = 64.0  # the lane leaves the hub through a mouth that rounds outward: a quarter circle this big on each side.
# It has to be bigger than a wall is deep (56), so the hub's wall can turn the corner into the lane in one run
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
GROUND = [(242, 214, 128), (244, 148, 152), (120, 172, 92), (160, 148, 124), (90, 124, 176),  # one colour per land
          (104, 96, 170), (62, 66, 120), (120, 72, 64), (150, 150, 168), (110, 44, 60)]  # (the last five are first guesses)
ASSET_SET = [0, 1, 2, 3, 0, 1, 2, 3, 4, 4]  # which of props.LANDS each land borrows: five lands have no set of their own yet
HUB_GROUND = (242, 214, 128)
# a wall is up to three tiers going away from the lane, the same distances everywhere so a wall never breaks its line
TIER_BACK, TIER_DEEP = (0.0, 24.0, 56.0), (24.0, 32.0, 24.0)  # whole squares: 3, 4 and 3 deep
KIND = {  # each tier's height in squares under its grass; 0 = that tier isn't there
    "wall": (2, 7, 0),  # the reference's hub wall: a low terrace, then the tall wall
    "hill": (2, 4, 7),  # broad steps climbing away
    "rim": (1, 0, 0),  # a low rim with the ground falling away behind it: the view out
}
HUB_TIERS = (2, 9, 0)  # the hub's wall, in squares over the water: a low terrace and the tall wall (the reference's)
JOIN = 420.0  # over this much lane the hub's wall steps down to the lane's own heights


HAZE = (120, 175, 195)  # the water's colour far off: the backdrop is drawn half way to it, so it sits back


def face_of(ground, pale=0.0):
    """a wall's side: the land's colour pulled toward a mid grey, as the reference's faces are. `pale` (0 to 1) is for
    the backdrop: the same colour fading into the water's haze (pale slabs read as white blocks in Studio)"""
    near = [0.4 * g + 0.6 * 158 for g in ground]
    return tuple(int(n + (h - n) * 0.6 * pale) for n, h in zip(near, HAZE))


parts = []
count = {"ground": 0, "face": 0, "prop": 0, "big": 0, "ends": 0}


def add(name, kind, p, size, colour, ax=(1, 0, 0), ay=(0, 1, 0), az=(0, 0, 1), solid=True, t=0.0, v=0.0):
    parts.append({"n": name, "k": kind, "p": [round(c, 2) for c in p], "x": [round(c, 4) for c in ax], "y": [round(c, 4) for c in ay],
                  "z": [round(c, 4) for c in az], "s": [round(abs(c), 2) for c in size], "c": list(colour), "solid": solid})
    if t:
        parts[-1]["t"] = t  # how see-through it is
    if v:
        parts[-1]["v"] = round(v, 2)  # how far the picture is slid up a side face, so rows of squares line up


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
    right_p.append(room["s1"] + way * r.uniform(*OFFSET) * reach)
right_p.append(rooms[-1]["s1"] + 200.0)
for side, pinches in ((-1, left_p), (1, right_p)):
    for i, (a, b) in enumerate(zip(pinches, pinches[1:])):
        r = random.Random(5000 + i * 2 + (side > 0))
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
    flare = MOUTH - math.sqrt(MOUTH * MOUTH - (MOUTH - at) ** 2) if at < MOUTH else 0.0  # the mouth, at the hub
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
    out = [pts[0]]
    i = 0
    while True:
        cx, cz = out[-1][0], out[-1][1]
        chord = chord_at(out[-1][4])
        while i + 1 < len(pts) and math.hypot(pts[i + 1][0] - cx, pts[i + 1][1] - cz) < chord:
            i += 1
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
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        long = math.hypot(b[0] - a[0], b[1] - a[1])  # this piece's length: one tile of the picture, or two
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
        long_back = math.hypot(b[0] + b[2] * deep - a[0] - a[2] * deep, b[1] + b[3] * deep - a[1] - a[3] * deep)
        if long_back > long + 0.08:  # a hollow curve: the back is longer than the front, so wedges open there
            left = long / 2 - 0.05 if before < top else long_back / 2 + 0.1  # toward the piece before
            right_ = long / 2 - 0.05 if after < top else long_back / 2 + 0.1
            shift = (right_ - left) / 2
            add("Core", "core", (mx + out[0] * (deep + 0.3) / 2 + al[0] * shift, (foot + top + GRASS - 0.1) / 2, mz + out[2] * (deep + 0.3) / 2 + al[2] * shift),
                (deep - 0.3, top + GRASS - 0.1 - foot, left + right_), ground, out, (0, 1, 0), al)
        if closed and closed[k]:  # the outermost tier where its back can be seen: a slab across the back
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
        at += 0.05 if at < 2.0 else 0.25 if at < MOUTH else 1.0  # the mouth turns fast at first
    return out


def want(side, tier, at):
    """how many squares high this tier wants to be here, from the kind of side this is"""
    kind = span_at(side, min(max(0.0, at), BUILD_TO))["kind"]
    return KIND[kind][tier]


def eased(side, tier, at):
    """the same, averaged along the wall, so a wall climbs to a taller neighbour in whole squares and never ends in a cliff"""
    return sum(want(side, tier, at + d) for d in (-80, -40, 0, 40, 80)) / 5.0


def lane_colours(at):
    g = GROUND[min(land_at(at), len(GROUND) - 1)]
    return g, face_of(g)


HUB_HALF, HUB_BACK, CORNER = 240.0, -256.0, 32.0  # 480 by 256 inside (whole tiles of the picture, so the squares
# end at the walls): about 165 studs of open floor from the start to the plots (the user, 2026-11-11: more open floor)


def hub_half_ring(side):
    """the hub's wall line for one side, from the middle of its back round to where the lane's mouth begins, as fine
    samples (x, z, s): s is negative, the distance still to go to the mouth"""
    pts = [(0.0, HUB_BACK)]
    for k in range(0, 91, 5):  # the back corner
        a_ = math.radians(270 - k)
        pts.append((-(HUB_HALF - CORNER) + CORNER * math.cos(a_), HUB_BACK + CORNER + CORNER * math.sin(a_)))
    for k in range(0, 91, 5):  # the front corner
        a_ = math.radians(180 - k)
        pts.append((-(HUB_HALF - CORNER) + CORNER * math.cos(a_), -CORNER + CORNER * math.sin(a_)))
    pts.append((-(PINCH + MOUTH), 0.0))
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
    out = []
    for i, q in enumerate(fine):
        near = face[lo[i]:hi[i]] - line[i]
        if np.hypot(near[:, 0], near[:, 1]).min() >= back - 0.6:
            out.append((line[i][0], line[i][1], q[2], q[3], q[4]))
    return out


def tier_top(side, j, block):
    """the height of tier j's top (under its grass) for one stretch of wall, or None where the tier isn't there"""
    mid = (block + 0.5) * WAVE * PIECE
    if mid < 0.0:  # round the hub: whole squares over the water, a square up or down now and then
        if not HUB_TIERS[j]:
            return None
        return (HUB_TIERS[j] + int(frac(block, 91 + j * 7 + (side > 0)) * 3) - 1) * SQUARE
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


for side in (-1, 1):  # each side's wall is one unbroken run of pieces per tier: round the hub, out of the mouth, to the end
    fine = wall_line(side)
    for j in range(3):
        verts = march(unfold(fine, TIER_BACK[j]), lambda at: PIECE if at < FINE_TO else PIECE * 2)
        blocks = [math.floor(verts[k][4] / (WAVE * PIECE)) for k in range(len(verts) - 1)]
        tops = [tier_top(side, j, b_) for b_ in blocks]
        # round the hub and out of its mouth the wall's back is seen too (from the lane, from above): close it
        closed = [verts[k][4] < JOIN and (j == 2 or tier_top(side, j + 1, blocks[k]) is None) for k in range(len(blocks))]
        lay(verts, tops, TIER_DEEP[j], lane_colours, True, closed)

# ---------------------------------------------------------------- behind the walls: the fall behind a rim, the unseen
# barrier, the backdrop
for i, (a, b) in enumerate(zip(nodes, nodes[1:])):
    mid_s = (a + b) / 2
    ground = GROUND[min(land_at(mid_s), len(GROUND) - 1)]
    for side in (-1, 1):
        ea, eb = edges[side][i], edges[side][i + 1]
        low_y, high_y = min(ea[1], eb[1]), max(ea[1], eb[1])
        # the barrier: unseen and solid, just behind the wall's face, from under the floor to over the surface. A
        # swimmer can go over any wall and a fish can get behind a thin one; this is what keeps them in the lane.
        (bx, bz), o, al, long = strip(side, i, 1.5, 1.0)
        y0 = low_y - 12.0
        while y0 < 14.0:  # a part can be 2,048 studs at most, and the deep lands are deeper than that
            y1 = min(14.0, y0 + 2000.0)
            add("Barrier", "barrier", (bx, (y0 + y1) / 2, bz), (1.0, y1 - y0, long), (255, 255, 255), o, (0, 1, 0), al, t=1.0)
            y0 = y1
        if span_at(side, mid_s)["kind"] == "rim" and mid_s >= 330.0:  # behind a rim the ground rolls away
            run = math.hypot(eb[0] - ea[0], eb[2] - ea[2])
            along = ((eb[0] - ea[0]) / run, 0.0, (eb[2] - ea[2]) / run)
            out = normals[side][i]
            start = ((ea[0] + eb[0]) / 2 + out[0] * TIER_DEEP[0], high_y + KIND["rim"][0] * SQUARE + GRASS - 4.5, (ea[2] + eb[2]) / 2 + out[2] * TIER_DEEP[0])
            for tilt, slab in ((14.0, 26.0), (40.0, 34.0)):
                ca, sa = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
                ax = (out[0] * ca, -sa, out[2] * ca)
                ay = (out[0] * sa, ca, out[2] * sa)
                c = (start[0] + ax[0] * slab / 2 - ay[0] * 5, start[1] + ax[1] * slab / 2 - ay[1] * 5, start[2] + ax[2] * slab / 2 - ay[2] * 5)
                add("Shoulder", "plain", c, (slab + 1.0, 10.0, run + (TIER_DEEP[0] + slab) * abs(heading(b) - heading(a)) + 3.0), ground, ax, ay, along)
                start = (start[0] + ax[0] * slab, start[1] + ax[1] * slab, start[2] + ax[2] * slab)
            continue
        block = math.floor(mid_s / 260.0)  # far behind a wall, now and then, something taller and paler
        if frac(block, 40 + side) > 0.5 and mid_s > 500.0:  # none beside the hub: a slab there cut through its corner
            tall = high_y + 110.0 + 80.0 * frac(block, 41 + side)
            (cx, cz), o, al, long = strip(side, i, 185.0 + 80.0 * frac(block, 42 + side), 110.0)
            add("Far", "far", (cx, (low_y - 30.0 + tall) / 2, cz), (110, tall - low_y + 30.0, long), face_of(ground, 1.0), o, (0, 1, 0), al)
            add("FarTop", "far", (cx, tall + CAP / 2, cz), (112, CAP, long + 0.6), tuple(int(g + (h_ - g) * 0.6) for g, h_ in zip(ground, HAZE)), o, (0, 1, 0), al)


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
    add("Seabed", "ground", (mx_ - ay[0] * PLINTH / 2, h - ay[1] * PLINTH / 2, mz_ - ay[2] * PLINTH / 2), (size + 0.1, PLINTH, size + 0.1),
        GROUND[min(land_at(hint), len(GROUND) - 1)], ax, ay, az)
    count["ground"] += 1
    count["tile%d" % n] = count.get("tile%d" % n, 0) + 1


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

for side in (-1, 1):  # out past a rim: big flat-topped shapes in the blue
    for sp in spans[side]:
        if sp["kind"] != "rim" or sp["s0"] > BUILD_TO:
            continue
        ground = GROUND[min(land_at(sp["s0"] + 5), len(GROUND) - 1)]
        for j in range(3):
            at = min(BUILD_TO, sp["s0"] + (sp["s1"] - sp["s0"]) * (0.2 + 0.3 * j))
            far = half(side, at) + 300.0 + 260.0 * frac(sp["seed"] * 3 + j, 61)
            w, d = 150 + 130 * frac(sp["seed"] + j, 62), 130 + 110 * frac(sp["seed"] + j, 63)
            p = across(at, side * far)
            top = p[1] + 30 + 110 * frac(sp["seed"] + j, 64)
            ax, ay, az = yawed(360 * frac(sp["seed"] + j, 65))
            add("Mesa", "far", (p[0], top - 160, p[2]), (w, 320, d), face_of(ground, 1.0), ax, ay, az)
            add("MesaTop", "far", (p[0], top + CAP / 2, p[2]), (w + 2, CAP, d + 2), tuple(int(g + (h_ - g) * 0.6) for g, h_ in zip(ground, HAZE)), ax, ay, az)

for g in necks:  # a line of flags across every neck
    c, rt = centre(g), right(g)
    lo, hi = -half(-1, g) - 6, half(1, g) + 6
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


prng = random.Random(77)
placed = []  # (s, x across, radius) of every big thing, so two never crowd the same water
big_world = []  # the same, as world x, z and radius
for room in rooms:
    if room["s0"] > BUILD_TO - 80:
        break
    stop = min(room["s1"], BUILD_TO)
    length = stop - room["s0"]
    li = land_at(room["s0"] + 5)
    ground = GROUND[min(li, len(GROUND) - 1)]
    kit = props.LANDS[ASSET_SET[li]]
    # each room draws its own numbers, one stream for each kind of thing, so changing how one kind is placed never
    # moves another (grey-box 6 moved the big assets by accident when the terraces changed)
    prng = random.Random(7700 + room["seed"])
    for _ in range(int(length / (150 if li == 0 else 70))):  # big things in the lane, with water left to pass
        for _try in range(8):
            at = prng.uniform(max(room["s0"] + 30, 250.0 if li == 0 else 130.0), stop - 30)
            name = prng.choice(kit)
            scale = prng.uniform(0.85, 1.2) if props.ASSETS[name][1] != "huge" else prng.uniform(0.9, 1.05)
            hx, _hy, hz = props.extent(props.bricks(name, count["prop"], ground))
            radius = max(hx, hz) * scale
            lo, hi = -half(-1, at) + radius * 0.6 + 6, half(1, at) - radius * 0.6 - 6
            if hi - lo < 20 or width(at) < radius * 2 + 70:  # never where it would plug a neck
                continue
            x = prng.uniform(lo, hi)
            if li == 0:  # the first land keeps its middle clear: things stand toward the sides
                x = prng.uniform(0.4 * hi, hi) if prng.random() < 0.5 else prng.uniform(lo, 0.4 * lo)
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

# ---------------------------------------------------------------- the hub: a closed bowl, its floor level with the water
# Sized from the reference's own hub (docs/reference/ride-a-dino-map.md, "The hub, measured"): a walk of a few seconds
# from the pens to the start, pens in a row along the far side and round the corners, stalls just inside the start.
add("HubFloor", "hub", (0, 0.5 - 60, HUB_BACK / 2), (HUB_HALF * 2, 120, -HUB_BACK), HUB_GROUND)
add("StartStrip", "trim", (0, 0.75, -12), ((PINCH + MOUTH) * 2, 0.5, 24), (250, 246, 230), solid=False)


def stall(name, x, z, colour, turn=0):
    ax, ay, az = yawed(turn)
    add(name + "Counter", "station", (x, 3.5, z), (14, 6, 8), (190, 140, 90), ax, ay, az)
    add(name + "Roof", "station", (x, 13, z), (18, 2, 12), colour, ax, ay, az)
    for sx in (-7, 7):
        add(name + "Post", "station", (x + ax[0] * sx, 6.5, z + ax[2] * sx), (1.5, 12, 1.5), (160, 115, 75), ax, ay, az)


PLOT = (64.0, 56.0, 34.0)  # an aquarium. The reference's pen is about 50 by 62 for dinos up to 40 long; our biggest
# creatures are nearly 50 long, so the tank is wider, and tall, because fish use the height
PLOT_COLOURS = [(240, 110, 130), (255, 170, 70), (250, 215, 90), (120, 200, 120), (90, 190, 220), (120, 140, 240), (180, 120, 230), (240, 140, 200)]


def plot(index, cx, cz, turn_deg):
    """a player's plot: the tank at the back, and in front of it the owner's sign, the trainer and the collect pad"""
    ax, ay, az = yawed(turn_deg)
    w, d, h = PLOT
    colour = PLOT_COLOURS[(index - 1) % len(PLOT_COLOURS)]
    frame = (58, 66, 88)

    def put(name, x, y0, z, size, col, kind="station", **more):
        add(f"Plot{index}_{name}", kind, (cx + ax[0] * x + az[0] * z, y0 + size[1] / 2, cz + ax[2] * x + az[2] * z), size, col, ax, ay, az, **more)

    put("Pad", 0, 0.5, 12, (w, 0.4, d + 24), tuple(int(c * 0.35 + 160) for c in colour), solid=False)
    put("TankBase", 0, 0.5, 0, (w, 3, d), frame)
    put("TankSand", 0, 3.5, 0, (w - 2, 1, d - 2), (236, 222, 172))
    put("TankWater", 0, 4.5, 0, (w - 2, h - 2, d - 2), (90, 190, 225), kind="glass", solid=False, t=0.55)
    for sx in (-1, 1):
        for sz in (-1, 1):
            put("Post", sx * (w / 2 - 1), 3.5, sz * (d / 2 - 1), (2, h, 2), frame)
        put("RimSide", sx * (w / 2 - 1), 3.5 + h - 1.5, 0, (2, 1.5, d), frame)
    for sz in (-1, 1):
        put("RimEnd", 0, 3.5 + h - 1.5, sz * (d / 2 - 1), (w, 1.5, 2), frame)
    put("SignPost", -w / 2 + 4, 0.5, d / 2 + 4, (1.2, 9, 1.2), frame)
    put("SignBoard", -w / 2 + 4, 9.5, d / 2 + 4, (14, 5, 1), colour)
    put("TrainerSpot", 9, 0.5, d / 2 + 9, (10, 0.6, 10), (225, 70, 70))
    put("TrainerRide", 9, 1.1, d / 2 + 9, (3, 4, 7), (250, 150, 80))
    put("CollectPad", -8, 0.5, d / 2 + 9, (8, 0.6, 8), (110, 210, 120), solid=False)


for k in range(6):  # six along the far side from the start, side by side, as the reference's pens stand
    plot(k + 1, (k - 2.5) * PLOT[0], HUB_BACK + 8 + PLOT[1] / 2, 0)  # sharing their side frames, on the floor's squares
plot(7, -(HUB_HALF - 8 - PLOT[1] / 2), -112.0, 90)  # and one on each side, facing in
plot(8, HUB_HALF - 8 - PLOT[1] / 2, -112.0, -90)
stall("Sell", -24, -40, (235, 80, 80))  # the two you use most, just inside the start
stall("Auras", 24, -40, (170, 110, 240))
stall("Fuse", -104, -64, (250, 190, 70), 35)
stall("Index", 104, -64, (90, 170, 240), -35)
stall("Sub", PINCH + MOUTH + 34, -16, (70, 190, 190), -20)  # the ride to a later land, at the start's right end
add("EarnersBoard", "station", (-(PINCH + MOUTH + 34), 14, -3), (22, 26, 4), (40, 44, 60))  # on the wall at its left end
add("DockSpawn", "trim", (0, 1.0, -104), (14, 1, 14), (255, 255, 255))
add("Figure", "figure", (10, 3.5, -56), (2, 5, 1), (90, 170, 230))

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
xs = [p["p"][0] for p in shown]
zs = [p["p"][2] for p in shown]
pad = 160
x0, x1, z0, z1 = min(xs) - pad, max(xs) + pad, min(zs) - pad, max(zs) + pad
W = 3000
sc = W / (z1 - z0)
H = int((x1 - x0) * sc)
im = Image.new("RGB", (W, H), (58, 118, 168))
d = ImageDraw.Draw(im)
order = {"barrier": 0, "ground": 1, "plain": 1, "hub": 1, "face": 1, "grass": 1, "core": 1, "prop": 3, "station": 3, "glass": 3, "trim": 4, "figure": 5}
for p in sorted(shown, key=lambda q: (order[q["k"]], q["p"][1] + q["s"][1] / 2)):
    hx, hz = p["s"][0] / 2, p["s"][2] / 2
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        wx = p["p"][0] + p["x"][0] * hx * sx + p["z"][0] * hz * sz
        wz = p["p"][2] + p["x"][2] * hx * sx + p["z"][2] * hz * sz
        pts.append(((wz - z0) * sc, (wx - x0) * sc))
    col = tuple(p["c"])
    if p["k"] == "grass":  # raised ground a shade darker, so the terraces show from above
        col = tuple(int(c * 0.86) for c in col)
    d.polygon(pts, fill=col)
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
d.text((20, 14), f"Grey-box 9 from above: the hub (left) and all ten lands, {BUILD_TO:,.0f} studs. Straight at first, then bends, wider as it goes. Wall tops are a shade darker.", font=font, fill=(255, 255, 255))
im.save(os.path.join(ROOT, "docs", "attachments", "map-greybox-plan.png"))
print("plan drawn")
