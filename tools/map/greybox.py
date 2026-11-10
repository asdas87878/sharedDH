"""Grey-box 3 of the new map (docs/design/map-method.md): the reference's build (docs/reference/ride-a-dino-map.md).
The lane goes narrow, wide, narrow, wide, and its two sides wave AGAINST each other: each side pinches in at its own
places, a part of a room apart from the other side's, so one side is going out while the other comes in and the lane
bleeds from side to side. The ground rolls and rises at a side into the walls, which are the ground itself stepping
up: broad terraces whose tops are the floor's own colour, or a tall plain wall with shelves, or nothing (an open edge
that rolls off, with big shapes far out). One colour per land. Big assets stand in the lane (tools/map/props.py), each
of loose boxes, tall enough that a ridden fish steers round them. The hub is a closed bowl level with the water.

usage: python tools/map/greybox.py            writes art/map/greybox/parts.json (every box), path.json (for the game
                                               code) and docs/attachments/map-greybox-plan.png (from above)
Pictures: blender --background --python tools/blender/map_greybox_view.py

Axes are Roblox's: y up, the sea surface at y = 0, the hub behind z = 0, the lane leaving along +z. A part is
{n: name, k: kind, p: centre, x/y/z: its three axes (unit vectors), s: size along them, c: colour, solid: bool}.
Kinds: ground (floor and every terrace top: gets the checker), face (the side of a wall), far (the backdrop), prop,
trim, station, figure, water. Everything is a plain box. Nothing here is tuned yet."""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "map", "greybox")

# ---------------------------------------------------------------- the numbers
PINCH = 44.0  # how close a side comes to the lane's line where it pinches in
BULGE_BIG, BULGE_SMALL = (100.0, 150.0), (40.0, 80.0)  # how far a side swells between two of its pinches
ROOM = (380.0, 640.0)  # the distance between one side's pinches
OFFSET = (0.24, 0.42)  # the other side pinches this share of a room further on (or back)
START_DEPTH = 46.0  # under the start; a room's dome may rise 8, and a jump needs 38 (riding chat)
STEEP = 18.0  # degrees: the slope of a "big drop"
PLINTH = 60.0  # how thick the lane's body is
BUILD_TO = 4500.0  # how much to build for now: the Shallows, the Coral Reef, the start of the Kelp Forest
SEG = 24.0  # the lane is cut into pieces this long
# name, length, slope in degrees, what ends it: ("step", studs) or ("slope", studs of drop, at the next land's start)
LANDS = [("Shallows", 1000, 2, ("step", 8)), ("Coral Reef", 2500, 2, ("step", 10)), ("Kelp Forest", 2500, 3, ("step", 12)),
         ("Shipwrecks", 2500, 4, ("slope", 150)), ("Open Blue", 2500, 4, ("step", 14)), ("Twilight", 2500, 5, ("step", 16)),
         ("Midnight", 2500, 6, ("slope", 250)), ("Vents", 2500, 6, ("step", 18)), ("Bone Graveyard", 2500, 7, ("step", 20)),
         ("The Underworld", 2500, 8, ("end", 0))]
GROUND = [(242, 214, 128), (244, 148, 152), (120, 172, 92), (160, 148, 124), (90, 124, 176)]  # one colour per land
HUB_GROUND = (242, 214, 128)
CAP = 4.0  # a terrace top's slab


def face_of(ground, pale=0.0):
    """a wall's side: the land's colour, greyed and light (paler still for the backdrop)"""
    return tuple(min(255, int(0.3 * g + 0.7 * 226 + 16 * pale)) for g in ground)


parts = []


def add(name, kind, p, size, colour, ax=(1, 0, 0), ay=(0, 1, 0), az=(0, 0, 1), solid=True):
    parts.append({"n": name, "k": kind, "p": [round(v, 2) for v in p], "x": [round(v, 4) for v in ax], "y": [round(v, 4) for v in ay],
                  "z": [round(v, 4) for v in az], "s": [round(abs(v), 2) for v in size], "c": list(colour), "solid": solid})


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


# ---------------------------------------------------------------- the descent: (s, depth) corners, straight between
starts = []
profile = [(0.0, START_DEPTH)]
s, depth, pending = 0.0, START_DEPTH, 0.0
for name, length, slope, end in LANDS:
    starts.append(s)
    run = length
    if pending:
        ramp = pending / math.tan(math.radians(STEEP))
        s, depth, run = s + ramp, depth + pending, run - ramp
        profile.append((s, depth))
        pending = 0.0
    s, depth = s + run, depth + run * math.tan(math.radians(slope))
    profile.append((s, depth))
    if end[0] == "step":
        depth += end[1]
        profile.append((s + 1.0, depth))
    elif end[0] == "slope":
        pending = end[1]


def land_at(at):
    k = 0
    for i, st in enumerate(starts):
        if at >= st:
            k = i
    return k


# ---------------------------------------------------------------- the rooms (by the left side's pinches)
rooms = []  # s0, s1, turn (degrees, taken at its far end), seed
rng = random.Random(20261110)
at = 0.0
for li, (name, length, *_rest) in enumerate(LANDS):
    end = starts[li] + length
    here = at
    if li == 0:  # the Shallows: a short first room, then a long one
        rooms.append({"s0": at, "s1": at + 330.0})
        here = at + 330.0
    while end - here > ROOM[1]:
        step = rng.uniform(*ROOM)
        if end - (here + step) < ROOM[0] * 0.8:
            step = (end - here) / 2
        rooms.append({"s0": here, "s1": here + step})
        here += step
    rooms.append({"s0": here, "s1": end})
    at = end
    if at > BUILD_TO + 900:
        break
swing = 0.0
for i, room in enumerate(rooms):
    r = random.Random(1000 + i)
    turn = r.uniform(9, 22) * (-1 if swing > 0 else 1)
    if abs(swing) < 8:
        turn = r.uniform(9, 22) * r.choice((-1, 1))
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
        spans[side].append({"s0": a, "s1": b, "bulge": r.uniform(*(BULGE_BIG if big else BULGE_SMALL)),
                            "kind": r.choice(("hill", "hill", "wall", "wall", "open")), "seed": i * 2 + (side > 0)})
spans[-1][0].update(kind="wall", bulge=70.0)  # by the hub both sides stand tall, well out of the water
spans[1][0].update(kind="hill", bulge=110.0)
for sp in spans[1]:  # never open on both sides at once
    if sp["kind"] == "open" and any(o["kind"] == "open" and o["s0"] < sp["s1"] and o["s1"] > sp["s0"] for o in spans[-1]):
        sp["kind"] = "hill"


def room_at(at):
    for room in rooms:
        if at <= room["s1"]:
            return room
    return rooms[-1]


def span_at(side, at):
    for sp in spans[side]:
        if at <= sp["s1"]:
            return sp
    return spans[side][-1]


def half(side, at):
    """how far this side's edge is from the lane's line: PINCH at its pinches, swelling between them"""
    sp = span_at(side, at)
    t = min(1.0, max(0.0, (at - sp["s0"] - 10.0) / (sp["s1"] - sp["s0"] - 20.0)))
    return PINCH + sp["bulge"] * math.sin(math.pi * t) ** 1.25  # level at the pinch: a smooth neck


def width(at):
    return half(-1, at) + half(1, at)


def floor_y(at):
    y = -profile[-1][1]
    for (s0, d0), (s1, d1) in zip(profile, profile[1:]):
        if at <= s1:
            y = -(d0 + (d1 - d0) * (at - s0) / max(s1 - s0, 1e-6))
            break
    room = room_at(at)
    length = room["s1"] - room["s0"]
    t = min(1.0, max(0.0, (at - room["s0"]) / length))
    return y + min(8.0, 0.016 * length) * math.sin(math.pi * t) ** 2  # the room's low dome


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def heading(at):
    h = 0.0
    for room in rooms:
        h += math.radians(room["turn"]) * smooth((at - room["s1"] + 110.0) / 220.0)
    return h


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
corners = [c for c, _ in profile if 0 < c < BUILD_TO]
nodes = sorted(set([round(v, 2) for v in nodes] + [round(c, 2) for c in corners]))
keep = [nodes[0]]
for v in nodes[1:]:
    is_corner = any(abs(v - c) < 0.02 for c in corners)
    if v - keep[-1] > 5.0 or is_corner:
        if is_corner and v - keep[-1] <= 5.0 and len(keep) > 1 and not any(abs(keep[-1] - c) < 0.02 for c in corners):
            keep.pop()
        keep.append(v)
nodes = keep


# ---------------------------------------------------------------- a side: what stands on the lane's edge
def side_kind(side, at):
    sp = span_at(side, at)
    near_pinch = min(at - sp["s0"], sp["s1"] - at) < 30.0
    return "wall" if (sp["kind"] == "open" and near_pinch) else sp["kind"]  # a pinch always has something solid


def tiers_at(side, at):
    """the terraces on this side here, innermost first: [(set back from the edge, depth, top above the floor)].
    A hill is two or three broad terraces, each its own length; a wall is one tall block. Heights and set-backs hold
    for a stretch (a block), then step: the wavy steps."""
    sp = span_at(side, at)
    kind = side_kind(side, at)
    salt = sp["seed"] * 7 + (3 if side > 0 else 11)
    t = (at - sp["s0"]) / (sp["s1"] - sp["s0"])
    tall = at < 330.0  # by the hub the sides rise out of the water, to close the hub's view
    if kind == "open":
        return []
    if kind == "wall":
        block = math.floor(at / 132.0)
        height = 44.0 + 6.0 * round(3 * frac(block, salt))
        if sp["kind"] == "open":
            height = 34.0
        if tall:
            height = 80.0 + 8.0 * round(2 * frac(block, salt))
        return [(0.0, 48.0, height)]
    out, back, top = [], 0.0, 0.0
    count_tiers = 3 if frac(sp["seed"], salt) > 0.45 else 2
    if tall:
        count_tiers = 4
    for k in range(count_tiers):
        block = math.floor(at / (96.0 + 24.0 * k))
        deep = 30.0 + 24.0 * frac(sp["seed"] * 5 + k, salt)
        rise = (13.0 if k == 0 else 17.0 + 8.0 * frac(sp["seed"] * 3 + k, salt + 1)) + 2.0 * round(2 * frac(block, salt + k) - 1)
        if tall:
            rise = (18.0, 22.0, 24.0, 26.0)[k]
        reach = 0.5 - 0.11 * k  # the higher a terrace, the shorter it is along the span
        mid = 0.5 + 0.12 * (frac(sp["seed"] + k, salt + 2) - 0.5) * k
        if k > 0 and not tall and abs(t - mid) > reach:
            break
        jog = 5.0 * (frac(block, salt + 20 + k) - 0.5) if k > 0 else 0.0
        top += rise
        out.append((back + jog, deep + (40.0 if k == count_tiers - 1 else 6.0), top))
        back += deep
    return out


def level(at, span=96.0):
    """the floor height a terrace is measured from: held over a stretch, so tops are level and step down the lane"""
    return floor_y(max(0.0, (math.floor(at / span) + 0.5) * span))


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


count = {"ground": 0, "face": 0, "prop": 0, "big": 0}
for i, (a, b) in enumerate(zip(nodes, nodes[1:])):
    if b - a < 1.5:
        continue
    mid_s = (a + b) / 2
    land = min(land_at(mid_s), len(GROUND) - 1)
    ground = GROUND[land]
    face = face_of(ground)
    pa, pb = centre(a + 0.01), centre(b - 0.01)
    fwd = unit(sub(pb, pa))
    rt = right(mid_s)
    up = unit(cross(fwd, rt))
    if up[1] < 0:
        up = (-up[0], -up[1], -up[2])
    length = math.sqrt(sum(c * c for c in sub(pb, pa)))
    turn = abs(heading(b) - heading(a))
    mid = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2, (pa[2] + pb[2]) / 2)
    # one clean floor: a single box, as wide as the lane's wider end here (walls and shoulders sit over the spare)
    reach = {side: max(half(side, a), half(side, b)) + 1.0 for side in (-1, 1)}
    wide = reach[-1] + reach[1]
    shift = (reach[1] - reach[-1]) / 2
    body = (mid[0] + rt[0] * shift - up[0] * PLINTH / 2, mid[1] - up[1] * PLINTH / 2, mid[2] + rt[2] * shift - up[2] * PLINTH / 2)
    add("Seabed", "ground", body, (wide, PLINTH, length + wide / 2 * turn + 0.4), ground, rt, up, cross(rt, up))
    count["ground"] += 1
    for side in (-1, 1):
        ea, eb = edges[side][i], edges[side][i + 1]
        run = math.hypot(eb[0] - ea[0], eb[2] - ea[2])
        along = ((eb[0] - ea[0]) / run, 0.0, (eb[2] - ea[2]) / run)
        out = (along[2], 0.0, -along[0])
        if out[0] * rt[0] * side + out[2] * rt[2] * side < 0:
            out = (-out[0], 0.0, -out[2])
        em = ((ea[0] + eb[0]) / 2, max(pa[1], pb[1]), (ea[2] + eb[2]) / 2)
        kind = side_kind(side, mid_s)
        if kind == "open":  # the ground rolls off: two slabs, each tilted further down
            start = (em[0], em[1], em[2])
            for tilt, slab in ((16.0, 24.0), (42.0, 30.0)):
                ca, sa = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
                ax = (out[0] * ca, -sa, out[2] * ca)
                ay = (out[0] * sa, ca, out[2] * sa)
                c = (start[0] + ax[0] * slab / 2 - ay[0] * 5, start[1] + ax[1] * slab / 2 - ay[1] * 5, start[2] + ax[2] * slab / 2 - ay[2] * 5)
                add("Shoulder", "ground", c, (slab + 1.0, 10.0, run + 3.0), ground, ax, ay, along)
                start = (start[0] + ax[0] * slab, start[1] + ax[1] * slab, start[2] + ax[2] * slab)
            continue
        base = level(mid_s) if kind == "hill" else level(mid_s, 132.0)
        foot = min(pa[1], pb[1]) - 30.0
        set_back = 0.0
        for back, deep, top in tiers_at(side, mid_s):
            top_y = base + top
            (cx, cz), o, al, long = strip(side, i, back, deep)
            add("Wall", "face", (cx, (foot + top_y) / 2, cz), (deep, top_y - foot, long), face, o, (0, 1, 0), al)
            (tx, tz), o, al, long = strip(side, i, back - 1.6, deep + 1.6)
            add("Top", "ground", (tx, top_y + CAP / 2, tz), (deep + 1.6, CAP, long + 0.6), ground, o, (0, 1, 0), al)
            count["face"] += 1
            set_back = back + deep
            if kind == "wall":  # shelves on the face, for a stretch
                block = math.floor(mid_s / 132.0)
                if frac(block, span_at(side, mid_s)["seed"] + side) > 0.42:
                    (sx_, sz_), o, al, long = strip(side, i, -10.0, 11.0)
                    add("Shelf", "ground", (sx_, base + top * (0.3 + 0.12 * frac(block, 5)), sz_), (11.0, CAP, long), ground, o, (0, 1, 0), al)
                    if top > 60:
                        (hx_, hz_), o, al, long = strip(side, i, -8.0, 9.0)
                        add("Shelf", "ground", (hx_, base + top * 0.66, hz_), (9.0, CAP, long), ground, o, (0, 1, 0), al)
        block = math.floor(mid_s / 260.0)  # far behind it, now and then, something taller and paler
        if frac(block, 40 + side) > 0.5:
            tall = base + 110.0 + 80.0 * frac(block, 41 + side)
            back = set_back + 110.0 + 80.0 * frac(block, 42 + side)
            (cx, cz), o, al, long = strip(side, i, back, 110.0)
            add("Far", "far", (cx, (foot + tall) / 2, cz), (110, tall - foot, long), face_of(ground, 1.0), o, (0, 1, 0), al)
            add("FarTop", "far", (cx, tall + CAP / 2, cz), (112, CAP, long + 0.6), tuple(int(g * 0.6 + 96) for g in ground), o, (0, 1, 0), al)

for side in (-1, 1):  # out past an open edge: big flat-topped shapes in the blue
    for sp in spans[side]:
        if sp["kind"] != "open" or sp["s0"] > BUILD_TO:
            continue
        ground = GROUND[min(land_at(sp["s0"] + 5), len(GROUND) - 1)]
        for j in range(3):
            at = min(BUILD_TO, sp["s0"] + (sp["s1"] - sp["s0"]) * (0.2 + 0.3 * j))
            far = 420.0 + 260.0 * frac(sp["seed"] * 3 + j, 61)
            w, d = 150 + 130 * frac(sp["seed"] + j, 62), 130 + 110 * frac(sp["seed"] + j, 63)
            p = across(at, side * far)
            top = p[1] + 30 + 110 * frac(sp["seed"] + j, 64)
            ax, ay, az = yawed(360 * frac(sp["seed"] + j, 65))
            add("Mesa", "far", (p[0], top - 160, p[2]), (w, 320, d), face_of(ground, 1.0), ax, ay, az)
            add("MesaTop", "far", (p[0], top + CAP / 2, p[2]), (w + 2, CAP, d + 2), tuple(int(g * 0.6 + 96) for g in ground), ax, ay, az)

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
    kit = props.LANDS[min(li, max(props.LANDS))]
    for _ in range(int(length / 70)):  # big things in the lane, the middle included, with water left to pass
        for _try in range(8):
            at = prng.uniform(max(room["s0"] + 30, 130.0), stop - 30)
            name = prng.choice(kit)
            scale = prng.uniform(0.85, 1.2) if props.ASSETS[name][1] != "huge" else prng.uniform(0.9, 1.05)
            hx, _hy, hz = props.extent(props.bricks(name, count["prop"], ground))
            radius = max(hx, hz) * scale
            lo, hi = -half(-1, at) + radius * 0.6 + 6, half(1, at) - radius * 0.6 - 6
            if hi - lo < 20 or width(at) < radius * 2 + 70:  # never where it would plug a neck
                continue
            x = prng.uniform(lo, hi)
            if all(math.hypot(at - ps, x - px) > radius + pr + 42 for ps, px, pr in placed):
                turn_deg = math.degrees(heading(at)) + (prng.uniform(-30, 30) if props.ASSETS[name][1] == "huge" else prng.uniform(0, 360))
                place(name, across(at, x), scale, turn_deg, ground, count["prop"])
                placed.append((at, x, radius))
                big_world.append([round(across(at, x)[0], 1), round(across(at, x)[2], 1), round(radius, 1)])
                count["big"] += 1
                break
    for _ in range(int(length / 60)):  # small dressing, in loose groups
        at = prng.uniform(room["s0"] + 20, stop - 20)
        x = prng.uniform(-half(-1, at) + 10, half(1, at) - 10)
        for _ in range(prng.randint(2, 5)):
            s2, x2 = at + prng.uniform(-14, 14), x + prng.uniform(-14, 14)
            x2 = max(-half(-1, s2) + 6, min(half(1, s2) - 6, x2))
            place(prng.choice(("sea_grass", "sea_grass", "stones", "floor_tiles")), across(s2, x2), prng.uniform(1.0, 1.8), prng.uniform(0, 360), ground, count["prop"])
    for side in (-1, 1):  # and standing on the terraces and the wall tops
        for _ in range(int(length / 110)):
            at = prng.uniform(room["s0"] + 40, stop - 40)
            steps = tiers_at(side, at)
            if not steps:
                continue
            back, deep, top = prng.choice(steps)
            base_y = (level(at) if side_kind(side, at) == "hill" else level(at, 132.0)) + top + CAP
            q = across(at, side * (half(side, at) + back + deep * prng.uniform(0.4, 0.6)))
            place(prng.choice(props.TERRACE[min(li, max(props.TERRACE))]), (q[0], base_y, q[2]), prng.uniform(0.7, 1.0), prng.uniform(0, 360), ground, count["prop"])

# ---------------------------------------------------------------- the hub: a closed bowl, its floor level with the water
HUB_HALF, HUB_BACK, CORNER = 230.0, -340.0, 120.0
hub_face = face_of(HUB_GROUND)
add("HubFloor", "ground", (0, 0.5 - 60, HUB_BACK / 2), (HUB_HALF * 2, 120, -HUB_BACK), HUB_GROUND)
add("StartStrip", "trim", (0, 0.75, -18), (PINCH * 2, 0.5, 36), (250, 246, 230), solid=False)
ring = [(-PINCH, 0.0)]  # the wall's line round the hub, from the start's left post round the back to its right post
for k in range(0, 91, 10):
    a = math.radians(90 + k)
    ring.append((-(HUB_HALF - CORNER) + CORNER * math.cos(a), -CORNER + CORNER * math.sin(a)))
for k in range(0, 91, 10):
    a = math.radians(180 + k)
    ring.append((-(HUB_HALF - CORNER) + CORNER * math.cos(a), HUB_BACK + CORNER + CORNER * math.sin(a)))
ring += [(-x, z) for x, z in reversed(ring)]
dense = []
for (xa, za), (xb, zb) in zip(ring, ring[1:]):
    span = math.hypot(xb - xa, zb - za)
    if span < 0.5:
        continue
    cuts = max(1, round(span / 30.0))
    for j in range(cuts):
        dense.append(((xa + (xb - xa) * j / cuts, za + (zb - za) * j / cuts), (xa + (xb - xa) * (j + 1) / cuts, za + (zb - za) * (j + 1) / cuts)))
run_along = 0.0
for (xa, za), (xb, zb) in dense:
    span = math.hypot(xb - xa, zb - za)
    fw = ((xb - xa) / span, 0, (zb - za) / span)
    out = (fw[2], 0, -fw[0])
    if out[0] * ((xa + xb) / 2) + out[2] * ((za + zb) / 2 - HUB_BACK / 2) < 0:
        out = (-out[0], 0, -out[2])
    block = math.floor(run_along / 110.0)
    height = 62.0 + 12.0 * round(2.4 * frac(block, 90))  # tall faces, the top going up and down in long steps
    mx, mz = (xa + xb) / 2, (za + zb) / 2
    add("HubWall", "face", (mx + out[0] * 24, (height - 40) / 2, mz + out[2] * 24), (48, height + 40, span + 8), hub_face, out, (0, 1, 0), fw)
    add("HubTop", "ground", (mx + out[0] * 23.2, height + CAP / 2, mz + out[2] * 23.2), (49.6, CAP, span + 8.8), HUB_GROUND, out, (0, 1, 0), fw)
    if frac(block, 91) > 0.4:
        add("HubShelf", "ground", (mx - out[0] * 5, height * (0.4 + 0.2 * frac(block, 92)), mz - out[2] * 5), (11, CAP, span + 1), HUB_GROUND, out, (0, 1, 0), fw)
    run_along += span


def stall(name, x, z, colour, turn=0):
    ax, ay, az = yawed(turn)
    add(name + "Counter", "station", (x, 3.5, z), (14, 6, 8), (190, 140, 90), ax, ay, az)
    add(name + "Roof", "station", (x, 13, z), (18, 2, 12), colour, ax, ay, az)
    for sx in (-7, 7):
        add(name + "Post", "station", (x + ax[0] * sx, 6.5, z + ax[2] * sx), (1.5, 12, 1.5), (160, 115, 75), ax, ay, az)


stall("Sell", -80, -95, (235, 80, 80))
stall("Auras", 80, -95, (170, 110, 240))
stall("Fuse", -150, -210, (250, 190, 70), 40)
stall("Index", 150, -210, (90, 170, 240), -40)
add("EarnersBoard", "station", (-78, 14, -14), (22, 26, 4), (40, 44, 60))
for k in range(4):
    add(f"Tank{k + 1}", "station", (-135 + k * 90, 7.5, -300), (60, 14, 30), (120, 200, 225))
add("DockSpawn", "trim", (0, 1.0, -240), (14, 1, 14), (255, 255, 255))
add("Figure", "figure", (16, 3.5, -30), (2, 5, 1), (90, 170, 230))

for gx in range(-3, 4):  # the sea's surface, in tiles
    for gz in range(0, 4):
        add("SeaTile", "water", (gx * 1600.0, -0.25, gz * 1600.0 + 800), (1600, 0.5, 1600), (70, 190, 215), solid=False)

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
print(len(parts), "parts:", kinds, "| assets:", count["prop"], "of them big:", count["big"], "| necks:", len(necks),
      "| width", round(min(widths)), "to", round(max(widths)))

# ---------------------------------------------------------------- the plan, from above
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    raise SystemExit
shown = [p for p in parts if p["k"] not in ("water", "far")]
xs = [p["p"][0] for p in shown]
zs = [p["p"][2] for p in shown]
pad = 160
x0, x1, z0, z1 = min(xs) - pad, max(xs) + pad, min(zs) - pad, max(zs) + pad
W = 3000
sc = W / (z1 - z0)
H = int((x1 - x0) * sc)
im = Image.new("RGB", (W, H), (58, 118, 168))
d = ImageDraw.Draw(im)
order = {"ground": 1, "face": 1, "prop": 3, "station": 3, "trim": 4, "figure": 5}
for p in sorted(shown, key=lambda q: (order[q["k"]], q["p"][1] + q["s"][1] / 2)):
    hx, hz = p["s"][0] / 2, p["s"][2] / 2
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        wx = p["p"][0] + p["x"][0] * hx * sx + p["z"][0] * hz * sz
        wz = p["p"][2] + p["x"][2] * hx * sx + p["z"][2] * hz * sz
        pts.append(((wz - z0) * sc, (wx - x0) * sc))
    col = tuple(p["c"])
    if p["n"] in ("Top", "HubTop", "Shelf", "HubShelf"):  # raised ground a shade darker, so the terraces show from above
        col = tuple(int(c * 0.86) for c in col)
    d.polygon(pts, fill=col)
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
d.text((20, 14), f"Grey-box 3 from above: the hub (left) and the first {BUILD_TO:,.0f} studs. The two sides wave against each other. Terrace tops are a shade darker.", font=font, fill=(255, 255, 255))
im.save(os.path.join(ROOT, "docs", "attachments", "map-greybox-plan.png"))
print("plan drawn")
