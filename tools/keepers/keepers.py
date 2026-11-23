"""The shopkeepers' tables, read from the game's own file (src/shared/Keepers.luau, between its two marks), and the same
sums the game does with them (Controllers/KeeperController): where a stand's space is, how a keeper is posed, where its
props stand. For the design sheet (tools/keepers/sheet.py, drawn by tools/blender/keeper_view.py) and for the checks
(tools/keepers/check.py). Plain Python, no Blender, no numpy.

Roblox's own frame everywhere: y up, a matrix is 4 rows of 4, a point is a column."""
import json
import math
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LUAU = os.path.join(ROOT, "src", "shared", "Keepers.luau")
HUB = os.path.join(ROOT, "art", "map", "greybox", "hub.json")


# ---------------------------------------------------------------- reading the Luau tables
def _tokens(text):
    text = re.sub(r"--[^\n]*", "", text)
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"|(-?\d+\.?\d*(?:e-?\d+)?)|([A-Za-z_][A-Za-z_0-9.]*)|([{}=,;])', text):
        if m.group(1) is not None:
            yield ("s", m.group(1))
        elif m.group(2) is not None:
            yield ("n", float(m.group(2)) if re.search(r"[.e]", m.group(2)) else int(m.group(2)))
        elif m.group(3) is not None:
            yield ("i", m.group(3))
        else:
            yield ("p", m.group(4))


def _value(toks, i):
    kind, v = toks[i]
    if kind == "p" and v == "{":
        rows, named = [], {}
        i += 1
        while toks[i] != ("p", "}"):
            if toks[i][0] == "i" and toks[i + 1] == ("p", "="):
                named[toks[i][1]], i = _value(toks, i + 2)
            else:
                item, i = _value(toks, i)
                rows.append(item)
            if toks[i][0] == "p" and toks[i][1] in ",;":
                i += 1
        assert not (rows and named), "a table with both a list and names: keep them apart"
        return (named if named else rows), i + 1
    if kind == "i":
        return {"true": True, "false": False, "nil": None}[v], i + 1
    return v, i + 1


def read(path=LUAU):
    """{"Look": ..., "Colours": ..., "List": [...]}: every `Keepers.X = {...}` between the marks"""
    text = open(path, encoding="utf-8").read()
    block = text[text.index("--<<DATA"):text.index("-->>DATA")]
    toks = list(_tokens(block))
    out, i = {}, 0
    while i < len(toks):
        kind, v = toks[i]
        assert kind == "i" and v.startswith("Keepers.") and toks[i + 1] == ("p", "="), toks[i:i + 3]
        out[v[len("Keepers."):]], i = _value(toks, i + 2)
    return out


# ---------------------------------------------------------------- small matrix sums
def mul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def ident():
    return [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]


def move(x, y, z):
    m = ident()
    m[0][3], m[1][3], m[2][3] = x, y, z
    return m


def angles(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz), in degrees: about x, then y, then z, each in the turned frame"""
    out = ident()
    for axis, deg in ((0, rx), (1, ry), (2, rz)):
        c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        m = ident()
        a, b = [(1, 2), (2, 0), (0, 1)][axis]
        m[a][a], m[a][b], m[b][a], m[b][b] = c, -s, s, c
        out = mul(out, m)
    return out


def point(m, v):
    return [m[r][0] * v[0] + m[r][1] * v[1] + m[r][2] * v[2] + m[r][3] for r in range(3)]


def from_axes(pos, x, y, z):
    """CFrame.fromMatrix(pos, x, y, z)"""
    m = ident()
    for r in range(3):
        m[r][0], m[r][1], m[r][2], m[r][3] = x[r], y[r], z[r], pos[r]
    return m


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


# ---------------------------------------------------------------- the engine's sums (keep alike: KeeperController)
def ease(k):
    return k * k * (3 - 2 * k)


def track_at(track, t):
    """a track's six numbers at t (0 to 1): rest at both ends, eased between its keys"""
    keys = [[0.0] * 7] + [list(k) + [0.0] * (7 - len(k)) for k in track[1:]] + [[1.0] + [0.0] * 6]
    for a, b in zip(keys, keys[1:]):
        if t <= b[0]:
            k = ease((t - a[0]) / (b[0] - a[0])) if b[0] > a[0] else 1.0
            return [a[i] + (b[i] - a[i]) * k for i in range(1, 7)]
    return [0.0] * 6


def look_split(look, yaw, pitch):
    """the whole turn towards a player (degrees; yaw to the keeper's own left is positive x) -> body yaw, head yaw,
    head pitch, each held to its most"""
    yaw = max(-(look["Body"] + look["Head"]), min(look["Body"] + look["Head"], yaw))
    body = max(-look["Body"], min(look["Body"], yaw * look["BodyShare"]))
    head = max(-look["Head"], min(look["Head"], yaw - body))
    return body, head, max(-look["Up"], min(look["Down"], pitch))


def aim(look, local):
    """the turn that points a head at `local` (a point in the keeper's space, measured from the head's joint): yaw and
    pitch in degrees. Looking up is a NEGATIVE pitch (a turn about x takes z towards -y)"""
    flat = math.hypot(local[0], local[2])
    return math.degrees(math.atan2(local[0], local[2])), -math.degrees(math.atan2(local[1], flat))


def pose(keeper, action_t=None, yaw=0.0, pitch=0.0, sway_t=None, look=None, scale=1.0):
    """every part of a keeper in its own space: [(row, matrix)]. action_t: 0 to 1 through its action (None: not in
    it); yaw, pitch: the look (needs `look`, Keepers.Look); sway_t: seconds into the idle (None: none of it)"""
    anim = {}

    def add(joint, six):
        cur = anim.setdefault(joint, [0.0] * 6)
        for i in range(6):
            cur[i] += six[i]

    if sway_t is not None:
        amp, seconds = keeper["Bob"]
        add("Body", [0, 0, 0, 0, amp * math.sin(2 * math.pi * sway_t / seconds), 0])
        for joint, seconds, phase, *six in keeper["Sway"]:
            k = math.sin(2 * math.pi * (sway_t / seconds + phase))
            add(joint, [v * k for v in six])
    if action_t is not None:
        for track in keeper["Action"]["Tracks"]:
            add(track[0], track_at(track, action_t))
    looks = {}
    if look and (yaw or pitch):
        body, head, tip = look_split(look, yaw, pitch)
        looks["Body"] = angles(0, body, 0)
        looks["Head"] = mul(angles(0, head, 0), angles(tip, 0, 0))
    pivots = {"Root": (0.0, 0.0, 0.0)}
    world = {"Root": ident()}
    for name, parent, x, y, z, rx, ry, rz in keeper["Joints"]:
        px, py, pz = pivots[parent]
        a = anim.get(name, [0.0] * 6)
        m = mul(world[parent], move((x - px) * scale, (y - py) * scale, (z - pz) * scale))
        m = mul(m, angles(rx, ry, rz))
        if name in looks:
            m = mul(m, looks[name])
        m = mul(mul(m, move(a[3] * scale, a[4] * scale, a[5] * scale)), angles(a[0], a[1], a[2]))
        pivots[name], world[name] = (x, y, z), m
    out = []
    for row in keeper["Parts"]:
        joint, _shape, _sx, _sy, _sz, x, y, z, rx, ry, rz = row[:11]
        px, py, pz = pivots[joint]
        out.append((row, mul(mul(world[joint], move((x - px) * scale, (y - py) * scale, (z - pz) * scale)), angles(rx, ry, rz))))
    return out


# ---------------------------------------------------------------- the stands, from the hub's own file
def station(name, hub=None, shift=(0.0, 0.0, 0.0)):
    """a station's parts as the hub kit draws them (hub.json), each moved by `shift` (the Fuse machine was moved by
    hand in the place)"""
    hub = hub or json.load(open(HUB))
    out = []
    for p in hub["parts"]:
        if p["m"] == "Stations/" + name:
            out.append(dict(p, p=[p["p"][i] + shift[i] for i in range(3)]))
    return out


def part_matrix(p):
    x, y = p["x"], p["y"]
    return from_axes(p["p"], x, y, cross(x, y))


def stand_space(parts, stand, look):
    """the stand's space as KeeperController reads it from the live parts: (matrix, scale). From the Ring and the
    part named `stand` ("CounterTop" or "Core")"""
    ring = next(p for p in parts if p["n"] == "Ring")
    anchor = next(p for p in parts if p["n"] == stand)
    floor = ring["p"][1] - ring["s"][1] / 2
    f = [ring["p"][0] - anchor["p"][0], 0.0, ring["p"][2] - anchor["p"][2]]
    far = math.hypot(f[0], f[2])
    f = [f[0] / far, 0.0, f[2] / far]
    up = [0.0, 1.0, 0.0]
    x = cross(up, f)
    if stand == "CounterTop":
        ax = [anchor["x"], anchor["y"], cross(anchor["x"], anchor["y"])]
        top = anchor["p"][1] + sum(abs(ax[i][1]) * anchor["s"][i] for i in range(3)) / 2
        scale = (top - floor) / look["CounterTall"]
    else:
        scale = far / look["CoreAhead"]
    scale = max(look["Least"], min(look["Most"], scale))
    return from_axes([anchor["p"][0], floor, anchor["p"][2]], x, up, f), scale


def keeper_space(space, scale, keeper, lift=0.0):
    return mul(space, move(keeper["At"][0] * scale, lift, keeper["At"][1] * scale))


def stand_lift(parts, space, scale, keeper, look):
    """how far over the floor the keeper's feet are: the top of the highest solid piece of the station under its spot
    and within Look.Reach of the floor (KeeperController does the same sum on the live parts). 0 on a stall's floor; the Fuse
    machine's keeper stands on its base"""
    floor = space[1][3]
    spot = point(space, [keeper["At"][0] * scale, 0, keeper["At"][1] * scale])
    best = 0.0
    for p in parts:
        if not p.get("f", 0) & 1 or p.get("t") == 1:
            continue
        ax = [p["x"], p["y"], cross(p["x"], p["y"])]
        d = [spot[i] - p["p"][i] for i in range(3)]
        if abs(ax[1][1]) < 0.99:
            continue  # a leaning piece: none is solid where a keeper stands
        if all(abs(sum(d[i] * ax[a][i] for i in (0, 2))) <= p["s"][a] / 2 for a in (0, 2)):
            top = p["p"][1] + p["s"][1] / 2 - floor
            if best < top <= look["Reach"] * scale:
                best = top
    return best


def read_pivot(keeper, joint):
    """where a joint turns, keeper space, bind pose"""
    return next(list(j[2:5]) for j in keeper["Joints"] if j[0] == joint)


def corners(m, size):
    return [point(m, [sx * size[0] / 2, sy * size[1] / 2, sz * size[2] / 2]) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]


# ---------------------------------------------------------------- a scene for the Blender view
def box(shape, size, m, colour, opts=None):
    opts = opts or {}
    return {"shape": shape, "size": list(size), "m": m, "colour": list(colour), "see": opts.get("See", 0.0),
            "neon": opts.get("Mat") == "Neon", "stud": bool(opts.get("Stud"))}


def keeper_boxes(data, keeper, space, scale=1.0, **how):
    out = []
    for row, m in pose(keeper, look=data["Look"], scale=scale, **how):
        opts = row[12] if len(row) > 12 else None
        out.append(box(row[1], [v * scale for v in row[2:5]], mul(space, m), data["Colours"][row[11]], opts))
    return out


def prop_boxes(data, keeper, space, scale=1.0):
    out = []
    for row in keeper["Props"]:
        shape, sx, sy, sz, x, y, z, rx, ry, rz, colour = row[:11]
        opts = row[11] if len(row) > 11 else None
        m = mul(mul(space, move(x * scale, y * scale, z * scale)), angles(rx, ry, rz))
        out.append(box(shape, [sx * scale, sy * scale, sz * scale], m, data["Colours"][colour], opts))
    return out


def station_boxes(parts):
    out = []
    for p in parts:
        if p.get("t") == 1:
            continue
        out.append({"shape": p.get("sh") or "Block", "size": p["s"], "m": part_matrix(p), "colour": p["c"], "see": p.get("t", 0.0),
                    "neon": p.get("mat") == "Neon", "stud": bool(p.get("tex"))})
    return out


if __name__ == "__main__":
    d = read()
    for k in d["List"]:
        print(k["Id"], k["Station"], len(k["Parts"]), "parts,", len(k["Props"]), "props,", len(k["Joints"]), "joints")


# ---------------------------------------------------------------- what a player sees of a stand
CAMERA = {"zoom": 12.5, "tilt": 20.0, "head": 4.5, "fov": 70.0}  # the play camera: studs behind the player's head,
# degrees it looks down, the head over the floor, its field of view top to bottom (Roblox's own)


def play_camera(space, parts, where, side=0.0):
    """the camera of a player stood on the stand's ring, facing the stand: (eye, at) in the world. where: -1 the
    ring's edge nearest the counter, 0 its middle, 1 its far edge; side: -1 to 1 across the ring"""
    ring = next(p for p in parts if p["n"] == "Ring")
    inv_z = [space[r][2] for r in range(3)]
    d = [ring["p"][i] - space[i][3] for i in range(3)]
    ahead = sum(d[i] * inv_z[i] for i in range(3))
    inv_x = [space[r][0] for r in range(3)]
    across = sum(d[i] * inv_x[i] for i in range(3))
    half = ring["s"][0] / 2
    x, z = across + side * half, ahead + where * half
    tilt = math.radians(CAMERA["tilt"])
    at = [x, CAMERA["head"], z]
    eye = [x, CAMERA["head"] + CAMERA["zoom"] * math.sin(tilt), z + CAMERA["zoom"] * math.cos(tilt)]
    return point(space, eye), point(space, at)


SCREEN = (1920, 1080)  # the screen the play views are drawn and measured on
ASIDE = 0.42  # where the player stands in the play views: this share of the ring's half to one side of its middle line
# (from dead ahead their own character covers the keeper)


def on_screen(eye, at, spot):
    """where `spot` is on the screen of a camera at `eye` looking at `at`: pixels from its top left"""
    f = [at[i] - eye[i] for i in range(3)]
    n = sum(v * v for v in f) ** 0.5
    f = [v / n for v in f]
    r = cross(f, [0.0, 1.0, 0.0])
    n = sum(v * v for v in r) ** 0.5
    r = [v / n for v in r]
    u = cross(r, f)
    d = [spot[i] - eye[i] for i in range(3)]
    deep = sum(d[i] * f[i] for i in range(3))
    focal = SCREEN[1] / 2 / math.tan(math.radians(CAMERA["fov"]) / 2)
    return (SCREEN[0] / 2 + focal * sum(d[i] * r[i] for i in range(3)) / deep,
            SCREEN[1] / 2 - focal * sum(d[i] * u[i] for i in range(3)) / deep)


def look_at(keeper, kspace, scale, look, spot):
    """the look a keeper gives a player whose head is at `spot` (the world), as KeeperController sums it: (yaw, pitch)
    in degrees, from the head's joint at rest, held to the most a keeper turns. (0, 0) for a player out of
    Look.Near or round behind it (Look.RearIn)"""
    d = [spot[i] - kspace[i][3] for i in range(3)]
    local = [sum(d[i] * kspace[i][a] for i in range(3)) for a in range(3)]
    neck = read_pivot(keeper, "Head")
    local = [local[i] - neck[i] * scale for i in range(3)]
    far = math.sqrt(sum(v * v for v in local))
    if far > look["Near"] or abs(math.degrees(math.atan2(local[0], local[2]))) > look["RearIn"]:
        return 0.0, 0.0
    yaw, pitch = aim(look, local)
    most = look["Body"] + look["Head"]
    return max(-most, min(most, yaw)), max(-look["Up"], min(look["Down"], pitch))


def action_times(keeper):
    """the moments of a keeper's action worth looking at: every key of every track, half way between each two, and
    an even row of them besides"""
    out = {round(0.1 * i, 3) for i in range(1, 10)}
    for track in keeper["Action"]["Tracks"]:
        keys = [0.0] + [key[0] for key in track[1:]] + [1.0]
        for a, b in zip(keys, keys[1:]):
            out.add(round(b, 3))
            out.add(round((a + b) / 2, 3))
    return sorted(t for t in out if 0 < t < 1)


def shows(data, keeper, kspace, scale, eye, at, **how):
    """how much of a keeper's idle and action a camera sees, in pixels of the 1920 x 1080 screen: (the bob top to
    bottom, the furthest any corner of a part is carried by the action from where the idle has it, the moment of the
    action that is, the joint of that part). how: the look it holds meanwhile"""
    amp_t = keeper["Bob"][1] / 4

    def at_time(**more):
        boxes = keeper_boxes(data, keeper, kspace, scale, **dict(how, **more))
        return [[on_screen(eye, at, c) for c in corners(b["m"], b["size"])] for b in boxes]

    up, down = at_time(sway_t=amp_t), at_time(sway_t=3 * amp_t)
    bob = max(math.dist(a, b) for pa, pb in zip(up, down) for a, b in zip(pa, pb))
    best = (0.0, None, None)
    for t in action_times(keeper):
        now = at_time(sway_t=amp_t, action_t=t)
        for i, (pa, pb) in enumerate(zip(up, now)):
            far = max(math.dist(a, b) for a, b in zip(pa, pb))
            if far > best[0]:
                best = (far, t, keeper["Parts"][i][0])
    return bob, best[0], best[1], best[2]


def under(keeper, joint, top):
    """whether `joint` is `top` or hangs from it (top may be a start of a name: "Arm" is both arms)"""
    parent = {j[0]: j[1] for j in keeper["Joints"]}
    while joint and joint != "Root":
        if joint.startswith(top):
            return True
        joint = parent.get(joint)
    return False


SOFT = ("Tent", "Octo")  # joints on a head that are soft, hanging things: a hand may brush through them


def arms(keeper):
    """the numbers of a keeper's parts that are an arm, a hand or what a hand holds"""
    return [i for i, row in enumerate(keeper["Parts"]) if under(keeper, row[0], "Arm")]


def hands(keeper):
    """the same without the sleeves: the hands, the cuffs and what is held. The sleeve is the first part on each
    arm's own joint (Keepers.luau lists an arm as a sleeve, then the cuff and the hand)"""
    sleeves = set()
    for joint in {row[0] for row in keeper["Parts"] if row[0].startswith("Arm")}:
        sleeves.add(next(i for i, row in enumerate(keeper["Parts"]) if row[0] == joint))
    return [i for i in arms(keeper) if i not in sleeves]


def heads(keeper, soft=False):
    """the numbers of its parts that are the head and what is fixed on it (a hat, a helmet, goggles); soft: those
    that hang from it instead (tentacles, the octopus)"""
    return [i for i, row in enumerate(keeper["Parts"]) if under(keeper, row[0], "Head") and row[0].startswith(SOFT) == soft]


def acting(keeper):
    """the numbers of the arm, hand and held parts its action moves: those on a joint the action has a track for,
    or hanging from one"""
    tracks = [t[0] for t in keeper["Action"]["Tracks"] if under(keeper, t[0], "Arm")]
    return [i for i in hands(keeper) if any(under(keeper, keeper["Parts"][i][0], t) for t in tracks)]  # no sleeves


def acting_times(keeper):
    """the keys of the action's tracks for its arms and what they hold (not its start or its end)"""
    out = set()
    for track in keeper["Action"]["Tracks"]:
        if under(keeper, track[0], "Arm"):
            out.update(round(key[0], 3) for key in track[1:] if 0 < key[0] < 1)
    return sorted(out)


def seen_share(eye, boxes, group, others):
    """the share of what faces `eye` of the parts numbered `group` (of `boxes`) that it can see: a 3 by 3 of points
    on every face turned to it, each seen unless one of `others` ([(name, matrix, size)]) or a part of the keeper
    outside the group stands in the way. A ball counts as a box three quarters its size"""
    def sized(b):
        return [v * 0.75 for v in b["size"]] if b.get("shape") == "Ball" else b["size"]

    block = list(others) + [(str(i), b["m"], sized(b)) for i, b in enumerate(boxes) if i not in group]
    seen = total = 0
    for i in group:
        m, size = boxes[i]["m"], sized(boxes[i])
        mid = [m[r][3] for r in range(3)]
        for a in range(3):
            axis = [m[r][a] for r in range(3)]
            for sign in (-1, 1):
                face = [mid[r] + sign * axis[r] * (size[a] / 2 + 0.01) for r in range(3)]
                if sum(sign * axis[r] * (eye[r] - face[r]) for r in range(3)) <= 0:
                    continue
                b1, b2 = [x for x in range(3) if x != a]
                for u in (-0.6, 0.0, 0.6):
                    for v in (-0.6, 0.0, 0.6):
                        spot = [face[r] + u * m[r][b1] * size[b1] / 2 + v * m[r][b2] * size[b2] / 2 for r in range(3)]
                        total += 1
                        if not hidden_by(eye, spot, block):
                            seen += 1
    return seen / total if total else 1.0


def hidden_by(eye, spot, solids):
    """the name of the first of `solids` ([(name, matrix, size)]) that stands between `eye` and `spot`, or None"""
    for name, m, size in solids:
        o = [eye[i] - m[i][3] for i in range(3)]
        d = [spot[i] - eye[i] for i in range(3)]
        lo, hi = 0.0, 0.999
        for a in range(3):
            oa = sum(o[i] * m[i][a] for i in range(3))
            da = sum(d[i] * m[i][a] for i in range(3))
            h = size[a] / 2
            if abs(da) < 1e-9:
                if abs(oa) > h:
                    lo, hi = 1.0, 0.0
                    break
                continue
            t0, t1 = (-h - oa) / da, (h - oa) / da
            lo, hi = max(lo, min(t0, t1)), min(hi, max(t0, t1))
            if lo > hi:
                break
        if lo <= hi:
            return name
    return None


def solids_of(parts):
    return [(p["n"], part_matrix(p), p["s"]) for p in parts if p.get("t") != 1]
