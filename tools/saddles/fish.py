"""Every kind of fish as the game has it, read offline: its mesh (art/creatures/<Id>/game/<Name>.glb), its joints and
seat (src/shared/Creatures/<Id>.json) and its sizes (src/shared/Config.luau), all in the game's own axes (studs, +Y up,
the head toward -Z, the fish's Root at the origin). Plain numpy; nothing here needs Studio or Blender.

  load(id) -> Fish      .scale(tier), .parts (name -> verts, colours, tris at Normal), .seat, .seat_part(tier)
  Fish.pose(u, ...)     each part's 4x4 at a moment of the swim, as AnimController turns the joints
  rider()               the block rider's boxes, astride, at the seat (AnimController.astride on R15's own joints)"""
import glob
import json
import math
import os
import re
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "creatures"))
import glb_meshes  # noqa: E402

CFG = open(os.path.join(ROOT, "src", "shared", "Config.luau"), encoding="utf-8").read()


def table(name):
    at = CFG.index(f"Config.{name} = {{")
    body = CFG[at : CFG.index("}", at)]
    return {k: float(v) for k, v in re.findall(r"(\w+) = (-?[\d.]+)", re.sub(r"--[^\n]*", "", body))}


BASE, SIZES, GROW, LIMIT = table("BaseScale"), table("SizeScale"), table("SizeGrow"), table("SizeLimit")
SEAT_HEIGHT = float(re.search(r"SeatHeight = ([\d.]+)", CFG).group(1))
TIERS = ["Tiny", "Normal", "Big", "Giant", "Huge", "Colossal"]
LANDS = ["Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue", "Twilight", "Midnight", "Vents",
         "Bone Graveyard", "The Underworld"]


def ids():
    return sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(ROOT, "src", "shared", "Creatures", "*.json")))


def quat(x, y, z, w):
    m = np.eye(4)
    m[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                 [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                 [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return m


def move(x, y, z):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def rot(x, y, z):
    """Roblox's CFrame.Angles, degrees: turned about X, then its own Y, then its own Z"""
    x, y, z = (math.radians(v) for v in (x, y, z))
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    m = np.eye(4)
    m[:3, :3] = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]]) @ np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]) @ np.array(
        [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return m


def axis_scaled(m, k):
    """the same turn, k times as far (AnimController's swing)"""
    if abs(k - 1) < 0.03:
        return m
    r = m[:3, :3]
    ang = math.acos(max(-1, min(1, (np.trace(r) - 1) / 2)))
    if ang < 1e-6:
        return m
    ax = np.array([r[2, 1] - r[1, 2], r[0, 2] - r[2, 0], r[1, 0] - r[0, 1]]) / (2 * math.sin(ang))
    s = math.sin(ang * k / 2)
    return quat(*(ax * s), math.cos(ang * k / 2))


class Fish:
    def __init__(self, id):
        self.id = id
        j = json.load(open(os.path.join(ROOT, "src", "shared", "Creatures", id + ".json"), encoding="utf-8"))
        self.rig = j
        self.name, self.tier, self.zone = j["Name"], j["Tier"], j["Zone"]
        k = self.k = BASE.get(id, 1.0)
        self.size = np.array(j["Size"]) * k
        self.seat = np.array(j["Seat"]) * k
        glb = glob.glob(os.path.join(ROOT, "art", "creatures", id, "game", "*.glb"))[0]
        mj = json.load(open(glob.glob(os.path.join(ROOT, "art", "creatures", id, "game", "*.mesh.json"))[0], encoding="utf-8"))
        self.seat_hw = (mj.get("seatHalfWidth") or 0) * k
        self.joint = {}  # part -> (parent, pivot)
        for name, parent, x, y, z in j["Parts"]:
            self.joint[name] = (parent, np.array([x, y, z]) * k)
        self.parts = {}  # mesh part -> verts (rest, Normal), colours, tris; glow parts keep their own name
        self.owner = {}
        first = j["Parts"][0][0]
        for p in glb_meshes.parts(glb):
            v = (np.array(p["positions"]) + np.array(p["origin"])) * k
            self.parts[p["name"]] = (v, np.array(p["colours"])[:, :3] if len(p["colours"]) else None, np.array(p["triangles"]), np.array(p["normals"]))
            base = re.sub(r"_Glow$", "", p["name"])
            self.owner[p["name"]] = p["name"] if p["name"] in self.joint else (base if base in self.joint else first)
        # (FishModel centres the Root on the parts' box)
        lo = np.min([v.min(0) for v, *_ in self.parts.values()], 0)
        hi = np.max([v.max(0) for v, *_ in self.parts.values()], 0)
        self.box = (lo, hi)

    def scale(self, tier):
        s = SIZES[tier]
        if s > 1:
            s = 1 + (s - 1) * GROW.get(self.tier, 1)
            s = max(1, min(s, LIMIT["Length"] / max(self.size[2], 1), LIMIT["Width"] / max(self.size[0], 1)))
        return s

    def chain(self, part):
        out = []
        while part:
            out.insert(0, part)
            part = self.joint[part][0]
        return out

    def seat_part(self, s=1.0):
        """AnimController.seatOf: the joint whose part's box is nearest the point 0.3 under the back's seat point"""
        under = self.seat * s - np.array([0, 0.3, 0])
        best, gap_best = None, 1e9
        for name in self.joint:
            if name not in self.parts:
                continue
            v = self.parts[name][0] * s
            lo, hi = v.min(0), v.max(0)
            gap = np.linalg.norm(under - np.clip(under, lo, hi)) + len(self.chain(name)) * 0.01
            if gap < gap_best:
                best, gap_best = name, gap
        return best

    def pose(self, u=None, swing=1.0, bend=0.0, s=1.0):
        """each joint's 4x4 (from its rest place) at u (0 to 1) of the swim, swung `swing` times as far, the tail chain
        bent `bend` degrees a joint more (the turn layer and the whip). u None: at rest."""
        n = self.rig["Moments"]
        out = {}
        spine = self.spine() if bend else {}
        for name in self.joint:  # parents come first
            parent, pivot = self.joint[name]
            t = np.eye(4)
            q = self.rig["Keys"].get(name)
            if q and u is not None and n > 1:
                at = (u % 1) * n
                i = int(at) % n
                a, b = np.array(q[i * 4 : i * 4 + 4]), np.array(q[((i + 1) % n) * 4 : ((i + 1) % n) * 4 + 4])
                if np.dot(a, b) < 0:
                    b = -b
                c = a + (b - a) * (at - int(at))
                t = quat(*(c / np.linalg.norm(c)))
                if "Jaw" not in name:
                    t = axis_scaled(t, swing)
            if name in spine:
                t = rot(0, bend * spine[name], 0) @ t
            m = move(*(pivot * s)) @ t @ move(*(-pivot * s))
            out[name] = out[parent] @ m if parent else m
        return out

    def spine(self):
        first = self.rig["Parts"][0][0]
        c = 0.05 * self.rig["Size"][0] + 0.05
        mid = [r for r in self.rig["Parts"] if r[0] != first and abs(r[2]) < c and "Jaw" not in r[0]]
        out = {}
        if not mid:
            return out
        z0 = self.rig["Parts"][0][4]
        for row, sign in ((max(mid, key=lambda r: r[4]), -1), (min(mid, key=lambda r: r[4]), 1)):
            if (row[4] - z0) * sign < 0:
                name = row[0]
                while name and name != first:
                    out.setdefault(name, sign)
                    name = self.joint[name][0]
        return out

    def tris(self, s=1.0, pose=None, skip=()):
        """(n, 3, 3) triangles of the whole fish and the joint each belongs to"""
        T, who = [], []
        for name, (v, _c, t, _n) in self.parts.items():
            own = self.owner[name]
            if own in skip:
                continue
            w = v * s
            if pose is not None:
                w = w @ pose[own][:3, :3].T + pose[own][:3, 3]
            T.append(w[t])
            who += [own] * len(t)
        return np.concatenate(T), np.array(who)


_cache = {}


def load(id):
    if id not in _cache:
        _cache[id] = Fish(id)
    return _cache[id]


# the astride pose at a middling riding speed (AnimController.astride, the rodeo arm up), R15's block rig: each limb
# (name, size, parent, the joint in the parent, the joint in the limb, the turn)
def rider(rodeo=True, pace=0.6):
    crouch = min(1, max(0, (pace - 0.55) / 0.75)) ** 2 * 1.0
    torso = 12 * (1 - crouch) - 26 * crouch
    arm, elbow, knee = 52 + 20 * crouch, 30, -85 - 10 * crouch
    limbs = [("LowerTorso", (2, 0.4, 1), None, (0, -1, 0), (0, -0.2, 0), (0, 0, 0), "pants"),
             ("UpperTorso", (2, 1.6, 1), "LowerTorso", (0, 0.2, 0), (0, -0.8, 0), (torso, 0, 0), "shirt"),
             ("Head", (1.2, 1.2, 1.2), "UpperTorso", (0, 0.8, 0), (0, -0.6, 0), (-torso * 0.8, 0, 0), "skin")]
    for side, s in (("Left", -1), ("Right", 1)):
        a = (165, 0, 18 * s) if (rodeo and s > 0) else (arm, 0, -10 * s)
        limbs += [(side + "UpperLeg", (1, 1.217, 1), "LowerTorso", (0.5 * s, -0.2, 0), (0, 0.421, 0), (72, 0, 30 * s), "pants"),
                  (side + "LowerLeg", (1, 1.193, 1), side + "UpperLeg", (0, -0.401, 0), (0, 0.379, 0), (knee, 0, 0), "pants"),
                  (side + "Foot", (1, 0.3, 1), side + "LowerLeg", (0, -0.547, 0), (0, 0.102, 0), (0, 0, 0), "shoe"),
                  (side + "UpperArm", (1, 1.169, 1), "UpperTorso", (1.0 * s, 0.563, 0), (-0.5 * s, 0.394, 0), a, "shirt"),
                  (side + "LowerArm", (1, 1.052, 1), side + "UpperArm", (0, -0.334, 0), (0, 0.259, 0), (elbow if s < 0 or not rodeo else 24, 0, 0), "skin"),
                  (side + "Hand", (1, 0.3, 1), side + "LowerArm", (0, -0.501, 0), (0, 0.125, 0), (0, 0, 0), "skin")]
    at, out = {None: np.eye(4)}, []
    for name, size, parent, j0, j1, turn, kind in limbs:
        m = at[parent] @ move(*j0) @ rot(*turn) @ move(*[-v for v in j1])
        at[name] = m
        out.append((name, size, move(0, SEAT_HEIGHT, 0) @ m, kind))
    return out  # each box's 4x4 from the SEAT POINT (the back's top), the fish's axes
