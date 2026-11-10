"""Grey-box 2 of the new map (docs/design/map-method.md), after a harder look at the reference's flight recording
(docs/reference/ride-a-dino-map.md). The lane is a CHAIN OF ROOMS: each wide and rounded, joined to the next by a narrow
gate with a line of flags. The ground rolls in a low dome per room and rises at its sides into the walls, which are the
ground itself stepping up: broad terraces whose tops are the floor's own colour, or a tall plain wall with a shelf, or
nothing at all (an open edge that rolls off, with big shapes far out). One colour per land. Props are big, clustered and
made of loose bricks. The hub is a closed bowl whose floor is level with the water.

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

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "map", "greybox")

# ---------------------------------------------------------------- the numbers
GATE = 92.0  # a gate's width
BULGE = (55.0, 125.0)  # how far a room swells past the gate's width, each side on its own
ROOM = (380.0, 640.0)  # a room's length
START_DEPTH = 46.0  # under the start; a room's dome may rise 8, and a jump needs 38 (riding chat)
STEEP = 18.0  # degrees: the slope of a "big drop"
PLINTH = 60.0  # how thick the lane's body is
BUILD_TO = 3600.0  # how much to build for now: the Shallows, the Coral Reef, a start on the Kelp Forest
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
    """a wall's side: the land's colour greyed and a little lighter (paler still for the backdrop)"""
    return tuple(int((0.38 * g + 0.62 * 206) * (0.9 + 0.1 * pale) + 20 * pale) for g in ground)


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


# ---------------------------------------------------------------- the rooms
rooms = []  # s0, s1, bulge {-1, 1}, edge {-1, 1}: "hill" | "wall" | "open", turn (degrees, at its far gate), seed
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
    if at > BUILD_TO + 700:
        break
swing, lean = 0.0, 1
for i, room in enumerate(rooms):
    r = random.Random(1000 + i)
    big, small = r.uniform(BULGE[0] + 30, BULGE[1]), r.uniform(BULGE[0], BULGE[0] + 35)
    room["bulge"] = {lean: big, -lean: small}  # each room swells mostly to one side, and the sides take turns
    kinds = r.choice((("hill", "wall"), ("wall", "hill"), ("hill", "open"), ("open", "wall"), ("wall", "open"), ("open", "hill"), ("hill", "hill")))
    room["edge"] = {lean: kinds[0], -lean: kinds[1]}
    turn = r.uniform(9, 22) * (-1 if swing > 0 else 1)
    if abs(swing) < 8:
        turn = r.uniform(9, 22) * r.choice((-1, 1))
    swing += turn
    room["turn"] = turn
    room["seed"] = i
    lean = -lean
rooms[0]["edge"] = {-1: "wall", 1: "hill"}  # by the hub both sides stand tall, well out of the water
rooms[0]["bulge"] = {-1: 70.0, 1: 105.0}
gates = [r["s1"] for r in rooms]


def room_at(at):
    for room in rooms:
        if at <= room["s1"]:
            return room
    return rooms[-1]


def half(side, at):
    """how far the lane's edge is from its centre line, on one side: the gate's half width, swelling inside a room"""
    room = room_at(at)
    t = min(1.0, max(0.0, (at - room["s0"] - 18.0) / (room["s1"] - room["s0"] - 36.0)))
    return GATE / 2 + room["bulge"][side] * math.sin(math.pi * t) ** 1.25  # level at the gates: a smooth neck


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
        h += math.radians(room["turn"]) * smooth((at - room["s1"] + 90.0) / 180.0)  # the lane turns at the gates
    return h


STEP = 4.0
line = [(0.0, 0.0)]
for k in range(int((BUILD_TO + 200) / STEP) + 10):
    h = heading((k + 0.5) * STEP)
    line.append((line[-1][0] + math.sin(h) * STEP, line[-1][1] + math.cos(h) * STEP))


def centre(at):
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


def edge_point(side, at):
    c, rt, hw = centre(at), right(at), half(side, at)
    return (c[0] + rt[0] * side * hw, c[1], c[2] + rt[2] * side * hw)


nodes = [0.0]
while nodes[-1] < BUILD_TO:
    nodes.append(nodes[-1] + SEG)
corners = [c for c, _ in profile if 0 < c < BUILD_TO] + [g for g in gates if g < BUILD_TO]
nodes = sorted(set([round(v, 2) for v in nodes] + [round(c, 2) for c in corners]))
keep = [nodes[0]]
for v in nodes[1:]:
    is_corner = any(abs(v - c) < 0.02 for c in corners)
    if v - keep[-1] > 5.0 or is_corner:
        if is_corner and v - keep[-1] <= 5.0 and len(keep) > 1 and not any(abs(keep[-1] - c) < 0.02 for c in corners):
            keep.pop()
        keep.append(v)
nodes = keep


# ---------------------------------------------------------------- a side of a room: what stands on the lane's edge
def near_gate(at):
    return min(abs(at - g) for g in [0.0] + gates) < 30.0


def side_kind(side, at):
    kind = room_at(at)["edge"][side]
    return "wall" if (kind == "open" and near_gate(at)) else kind  # a gate always has something solid either side


def tiers_at(side, at):
    """the terraces on this side here, innermost first: [(set back from the edge, depth, top above the room's floor)].
    A hill is three or four broad terraces, each its own length; a wall is one tall block. Heights and set-backs hold
    for a stretch (a block), then step: the wavy steps."""
    room = room_at(at)
    kind = side_kind(side, at)
    salt = room["seed"] * 7 + (3 if side > 0 else 11)
    length = room["s1"] - room["s0"]
    t = (at - room["s0"]) / length
    tall = at < rooms[0]["s1"]  # the first room's sides rise out of the water, to close the hub's view
    if kind == "open":
        return []
    if kind == "wall":
        block = math.floor(at / 132.0)
        height = 40.0 + 6.0 * round(3 * frac(block, salt))
        if room["edge"][side] == "open":
            height = 32.0
        if tall:
            height = 78.0 + 8.0 * round(2 * frac(block, salt))
        return [(0.0, 46.0, height)]
    out, back, top = [], 0.0, 0.0
    count_tiers = 3 if frac(room["seed"], salt) > 0.45 else 2
    if tall:
        count_tiers = 4
    for k in range(count_tiers):
        block = math.floor(at / (96.0 + 24.0 * k))
        deep = 30.0 + 24.0 * frac(room["seed"] * 5 + k, salt)
        rise = (8.0 if k == 0 else 12.0 + 6.0 * frac(room["seed"] * 3 + k, salt + 1)) + 2.0 * round(2 * frac(block, salt + k) - 1)
        if tall:
            rise = (16.0, 20.0, 24.0, 26.0)[k]
        reach = 0.5 - 0.11 * k  # the higher a terrace, the shorter it is along the room
        mid = 0.5 + 0.12 * (frac(room["seed"] + k, salt + 2) - 0.5) * k
        if k > 0 and not tall and abs(t - mid) > reach:
            break
        jog = 5.0 * (frac(block, salt + 20 + k) - 0.5) if k > 0 else 0.0
        top += rise
        out.append((back + jog, deep + (40.0 if k == count_tiers - 1 else 6.0), top))
        back += deep
    return out


def level(at, span=96.0):
    """the room's floor height a terrace is measured from: held over a stretch, so tops are level and step down"""
    q = (math.floor(at / span) + 0.5) * span
    room = room_at(at)
    return floor_y(min(max(q, room["s0"]), room["s1"]))


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


count = {"ground": 0, "face": 0, "prop": 0}
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
    # the floor: a box as wide as the lane is at its narrower end here; edge strips below fill out to the true edge
    inner = {side: max(half(side, a), half(side, b)) + 1.0 for side in (-1, 1)}
    width = inner[-1] + inner[1]
    shift = (inner[1] - inner[-1]) / 2
    body = (mid[0] + rt[0] * shift - up[0] * PLINTH / 2, mid[1] - up[1] * PLINTH / 2, mid[2] + rt[2] * shift - up[2] * PLINTH / 2)
    add("Seabed", "ground", body, (width, PLINTH, length + width / 2 * turn + 0.4), ground, rt, up, cross(rt, up))
    count["ground"] += 1
    for side in (-1, 1):
        ea, eb = edge_point(side, a), edge_point(side, b)
        run = math.hypot(eb[0] - ea[0], eb[2] - ea[2])
        along = ((eb[0] - ea[0]) / run, 0.0, (eb[2] - ea[2]) / run)
        out = (along[2], 0.0, -along[0])  # level, away from the lane
        if out[0] * rt[0] * side + out[2] * rt[2] * side < 0:
            out = (-out[0], 0.0, -out[2])
        em = ((ea[0] + eb[0]) / 2, max(pa[1], pb[1]), (ea[2] + eb[2]) / 2)
        kind = side_kind(side, mid_s)
        if kind == "open":  # the ground rolls off: two slabs, each tilted further down
            start = (em[0], em[1], em[2])
            for tilt, wide in ((16.0, 24.0), (42.0, 30.0)):
                ca, sa = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
                ax = (out[0] * ca, -sa, out[2] * ca)
                ay = (out[0] * sa, ca, out[2] * sa)
                c = (start[0] + ax[0] * wide / 2 - ay[0] * 5, start[1] + ax[1] * wide / 2 - ay[1] * 5, start[2] + ax[2] * wide / 2 - ay[2] * 5)
                add("Shoulder", "ground", c, (wide + 1.0, 10.0, run + 1.5), ground, ax, ay, along)
                start = (start[0] + ax[0] * wide, start[1] + ax[1] * wide, start[2] + ax[2] * wide)
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
            if kind == "wall":  # a shelf on the face, for a stretch
                block = math.floor(mid_s / 132.0)
                if frac(block, room_at(mid_s)["seed"] + side) > 0.42:
                    shelf_y = base + top * (0.3 + 0.12 * frac(block, 5))
                    if top > 60:
                        (hx_, hz_), o2, al2, long2 = strip(side, i, -8.0, 9.0)
                        add("Shelf", "ground", (hx_, base + top * 0.66, hz_), (9.0, CAP, long2), ground, o2, (0, 1, 0), al2)
                    (sx_, sz_), o, al, long = strip(side, i, -10.0, 11.0)
                    add("Shelf", "ground", (sx_, shelf_y, sz_), (11.0, CAP, long), ground, o, (0, 1, 0), al)
        block = math.floor(mid_s / 190.0)  # behind it, now and then, something taller and paler
        if frac(block, 40 + side) > 0.35:
            tall = base + 95.0 + 60.0 * frac(block, 41 + side)
            back = set_back + 24.0 + 40.0 * frac(block, 42 + side)
            (cx, cz), o, al, long = strip(side, i, back, 90.0)
            add("Far", "far", (cx, (foot + tall) / 2, cz), (90, tall - foot, long), face_of(ground, 0.5), o, (0, 1, 0), al)
            add("FarTop", "far", (cx, tall + CAP / 2, cz), (92, CAP, long + 0.6), tuple(int(g * 0.9 + 22) for g in ground), o, (0, 1, 0), al)

for room in rooms:  # out past an open edge: big flat-topped shapes in the blue
    for side in (-1, 1):
        if room["edge"][side] != "open" or room["s0"] > BUILD_TO:
            continue
        ground = GROUND[min(land_at(room["s0"] + 5), len(GROUND) - 1)]
        for j in range(3):
            at = min(BUILD_TO, room["s0"] + (room["s1"] - room["s0"]) * (0.2 + 0.3 * j))
            c, rt = centre(at), right(at)
            far = 360.0 + 240.0 * frac(room["seed"] * 3 + j, 61)
            w, d, top = 150 + 130 * frac(room["seed"] + j, 62), 130 + 110 * frac(room["seed"] + j, 63), c[1] + 30 + 110 * frac(room["seed"] + j, 64)
            p = (c[0] + rt[0] * side * far, 0, c[2] + rt[2] * side * far)
            ax, ay, az = yawed(360 * frac(room["seed"] + j, 65))
            add("Mesa", "far", (p[0], top - 160, p[2]), (w, 320, d), face_of(ground, 0.7), ax, ay, az)
            add("MesaTop", "far", (p[0], top + CAP / 2, p[2]), (w + 2, CAP, d + 2), tuple(int(g * 0.85 + 34) for g in ground), ax, ay, az)

for g in [0.0] + gates:  # a line of flags across every gate
    if g > BUILD_TO:
        continue
    c, rt = centre(g), right(g)
    wide = half(-1, g) + half(1, g) + 12
    add("FlagLine", "trim", (c[0], c[1] + 30, c[2]), (wide, 0.6, 0.6), (250, 250, 250), rt, (0, 1, 0), ahead(g), solid=False)
    for j in range(13):
        off = -wide / 2 + 6 + j * (wide - 12) / 12
        add("Flag", "trim", (c[0] + rt[0] * off, c[1] + 27.3, c[2] + rt[2] * off), (4.6, 5, 0.4), ((250, 200, 80), (240, 110, 130), (110, 190, 240), (140, 220, 150), (250, 250, 250))[j % 5], rt, (0, 1, 0), ahead(g), solid=False)


# ---------------------------------------------------------------- props: big, in clusters, each a few loose bricks
def prop(kind, base, scale, turn_deg, land):
    ax, ay, az = yawed(turn_deg)
    leaf = ((240, 120, 150), (255, 150, 90), (120, 200, 210), (130, 200, 120), (170, 140, 230))[(land * 2 + count["prop"]) % 5]
    light = tuple(min(255, int(v * 1.08 + 12)) for v in leaf)
    stone = (150, 150, 162)
    bricks = {  # (dx, y of the brick's foot, dz, width, height, depth, colour)
        "tree": [(0, 0, 0, 3.2, 5, 3.2, (120, 92, 76)), (0.3, 5, 0, 3, 5, 3, (132, 102, 84)), (0, 10, 0.2, 2.8, 4, 2.8, (120, 92, 76)),
                 (0, 14, 0, 13, 2.6, 11, leaf), (2.5, 16.6, 1, 8, 2.4, 7, light), (-3, 16.6, -2, 6, 2.2, 5, leaf)],
        "stack": [(0, 0, 0, 3, 3, 3, (120, 92, 76)), (0, 3, 0, 12, 3.4, 12, leaf), (0, 6.4, 0, 9.5, 3.4, 9.5, light), (0, 9.8, 0, 7, 3.2, 7, leaf), (0, 13, 0, 4.2, 3, 4.2, light)],
        "rocks": [(0, 0, 0, 10, 5, 8, stone), (1.4, 5, -0.6, 7.5, 4, 6.5, (166, 166, 178)), (-0.8, 9, 0.5, 5, 3.4, 5, (180, 180, 192))],
        "grass": [(-1.4, 0, 0, 1.1, 5, 1.1, (96, 186, 116)), (0, 0, 0.7, 1.1, 7, 1.1, (116, 204, 130)), (1.5, 0, -0.5, 1.1, 4, 1.1, (96, 186, 116))],
        "tiles": [(0, 0, 0, 2.2, 0.5, 2.2, light), (2.2, 0, 0, 2.2, 0.5, 2.2, leaf), (-2.2, 0, 0, 2.2, 0.5, 2.2, leaf), (0, 0, 2.2, 2.2, 0.5, 2.2, leaf), (0, 0, -2.2, 2.2, 0.5, 2.2, leaf)],
        "stone": [(0, 0, 0, 2.6, 2, 2.2, stone)],
    }[kind]
    for j, (dx, y, dz, w, hgt, d, col) in enumerate(bricks):
        p = (base[0] + (ax[0] * dx + az[0] * dz) * scale, base[1] + (y + hgt / 2) * scale, base[2] + (ax[2] * dx + az[2] * dz) * scale)
        add(f"{kind}_{count['prop']}_{j}", "prop", p, (w * scale, hgt * scale, d * scale), col, ax, ay, az)
    count["prop"] += 1


prng = random.Random(77)
for room in rooms:
    if room["s0"] > BUILD_TO - 80:
        break
    stop = min(room["s1"], BUILD_TO)
    length = stop - room["s0"]
    land = min(land_at(room["s0"] + 5), len(GROUND) - 1)
    for _ in range(int(length / 38)):  # clusters on the floor, the middle included
        at = prng.uniform(room["s0"] + 34, stop - 34)
        across = prng.uniform(-half(-1, at) + 16, half(1, at) - 16)
        for _ in range(prng.randint(2, 5)):
            kind = prng.choice(("tree", "stack", "rocks", "grass", "grass", "tiles", "tiles", "stone"))
            s2, a2 = at + prng.uniform(-20, 20), across + prng.uniform(-20, 20)
            a2 = max(-half(-1, s2) + 9, min(half(1, s2) - 9, a2))
            c, rt = centre(s2), right(s2)
            big = prng.uniform(0.95, 1.35) if kind in ("tree", "stack") else prng.uniform(0.9, 1.5)
            prop(kind, (c[0] + rt[0] * a2, c[1], c[2] + rt[2] * a2), big, prng.uniform(0, 360), land)
    for side in (-1, 1):  # and standing on the terraces and the wall tops
        for _ in range(int(length / 80)):
            at = prng.uniform(room["s0"] + 40, stop - 40)
            steps = tiers_at(side, at)
            if not steps:
                continue
            back, deep, top = prng.choice(steps)
            e, rt = edge_point(side, at), right(at)
            base_y = (level(at) if side_kind(side, at) == "hill" else level(at, 132.0)) + top + CAP
            off = back + deep * prng.uniform(0.35, 0.6)
            prop(prng.choice(("tree", "stack", "rocks")), (e[0] + rt[0] * side * off, base_y, e[2] + rt[2] * side * off), prng.uniform(0.9, 1.3), prng.uniform(0, 360), land)

# ---------------------------------------------------------------- the hub: a closed bowl, its floor level with the water
HUB_HALF, HUB_BACK, CORNER = 230.0, -340.0, 120.0
hub_face = face_of(HUB_GROUND)
add("HubFloor", "ground", (0, 0.5 - 60, HUB_BACK / 2), (HUB_HALF * 2, 120, -HUB_BACK), HUB_GROUND)
add("StartStrip", "trim", (0, 0.75, -18), (GATE, 0.5, 36), (250, 246, 230), solid=False)
ring = [(-GATE / 2, 0.0)]  # the wall's line round the hub, from the gate's left post round the back to its right post
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
    far_block = math.floor(run_along / 170.0)
    tall = height + 46.0 + 30.0 * frac(far_block, 93)
    add("HubFar", "far", (mx + out[0] * 100, (tall - 40) / 2, mz + out[2] * 100), (90, tall + 40, span + 30), face_of(HUB_GROUND, 0.5), out, (0, 1, 0), fw)
    add("HubFarTop", "far", (mx + out[0] * 100, tall + CAP / 2, mz + out[2] * 100), (92, CAP, span + 31), tuple(int(g * 0.9 + 22) for g in HUB_GROUND), out, (0, 1, 0), fw)
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
fish = centre(200)
add("Figure", "figure", (fish[0] + 10, fish[1] + 14, fish[2]), (4, 3, 9), (245, 130, 42))

for gx in range(-3, 4):  # the sea's surface, in tiles
    for gz in range(0, 4):
        add("SeaTile", "water", (gx * 1600.0, -0.25, gz * 1600.0 + 800), (1600, 0.5, 1600), (70, 190, 215), solid=False)

# ---------------------------------------------------------------- what the game code reads: the path
path = []
for v in nodes:
    c = centre(v)
    path.append([round(v, 1), round(c[0], 1), round(floor_y(v), 1), round(c[2], 1), round(half(-1, v) + half(1, v), 1), 0])

os.makedirs(OUT, exist_ok=True)
json.dump({"parts": parts}, open(os.path.join(OUT, "parts.json"), "w"))
json.dump({"PathFields": "s, x, y, z, w (wall to wall: it narrows to a gate and swells in a room), c (always 0)", "Path": path, "Gate": GATE, "BuiltTo": BUILD_TO,
           "Gates": [round(g, 1) for g in gates if g <= BUILD_TO],
           "Rooms": [{"S0": round(r["s0"], 1), "S1": round(r["s1"], 1), "Left": r["edge"][-1], "Right": r["edge"][1], "Widest": round(GATE + r["bulge"][-1] + r["bulge"][1])} for r in rooms if r["s0"] < BUILD_TO],
           "Lands": [{"Name": l[0], "S0": st} for l, st in zip(LANDS, starts)], "Profile": [[round(a, 1), round(-b, 1)] for a, b in profile]},
          open(os.path.join(OUT, "path.json"), "w"), indent=1)
kinds = {}
for p in parts:
    kinds[p["k"]] = kinds.get(p["k"], 0) + 1
print(len(parts), "parts:", kinds, "| props:", count["prop"], "| rooms built:", sum(1 for r in rooms if r["s0"] < BUILD_TO))

# ---------------------------------------------------------------- the plan, from above
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    raise SystemExit
shown = [p for p in parts if p["k"] != "water" and p["n"] not in ("Mesa", "MesaTop")]
xs = [p["p"][0] for p in shown]
zs = [p["p"][2] for p in shown]
pad = 200
x0, x1, z0, z1 = min(xs) - pad, max(xs) + pad, min(zs) - pad, max(zs) + pad
W = 2600
sc = W / (z1 - z0)
H = int((x1 - x0) * sc)
im = Image.new("RGB", (W, H), (58, 118, 168))
d = ImageDraw.Draw(im)
order = {"far": 0, "ground": 1, "face": 1, "prop": 3, "station": 3, "trim": 4, "figure": 5}
base_y = -START_DEPTH
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
d.text((20, 14), f"Grey-box 2 from above: the hub (left), then rooms and gates for the first {BUILD_TO:,.0f} studs. Terrace tops are drawn a shade darker.", font=font, fill=(255, 255, 255))
im.save(os.path.join(ROOT, "docs", "attachments", "map-greybox-plan.png"))
print("plan drawn")
