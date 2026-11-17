"""The camera spots for the land-icon captures: for each land two close views of its signature big assets (a, b) and
one view down the lane (c) and a close-up of the first asset (d). Reads the props list from Studio (props_list.luau, as JSON) and the lane's line.
    python tools/ui/land_icons/plan.py <props.json> > plan.json
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
path = json.loads((ROOT / "art/map/greybox/path.json").read_text())
P = path["Path"]  # s, x, floor y, z, w
S0 = [l["S0"] for l in path["Lands"]] + [path["BuiltTo"]]
OX = 3000  # the map's x offset (src/shared/Zones.luau ORIGIN)
# the signature assets each land shows (tools/map/greybox.py ASSET_SET: lands 5 to 8 borrow the first four sets)
WANT = {
    1: ["pillar_coral", "brain_coral", "giant_clam", "anemone", "fan_coral"],
    2: ["coral_tree", "reef_wall", "brain_coral", "tube_cluster", "anemone"],
    3: ["kelp_giant", "kelp_grove", "mossy_boulder"],
    4: ["hull", "mast", "anchor"],
    5: ["sea_stack", "pillar_coral", "brain_coral", "giant_clam"],
    6: ["coral_tree", "reef_wall", "tube_cluster", "anemone"],
    7: ["kelp_giant", "kelp_grove", "mossy_boulder"],
    8: ["hull", "mast", "anchor"],
    9: ["skull", "ribs", "bone_pillar"],
    10: ["skull", "ribs", "bone_pillar"],
}


def nearest(x, z):
    best, bi = 1e18, 0
    for i, q in enumerate(P):
        d = (q[1] + OX - x) ** 2 + (q[3] - z) ** 2
        if d < best:
            best, bi = d, i
    return bi


def land_of(s):
    for i in range(10):
        if S0[i] <= s < S0[i + 1]:
            return i + 1
    return 10


def tangent(i):
    a, b = P[max(i - 1, 0)], P[min(i + 1, len(P) - 1)]
    dx, dz = b[1] - a[1], b[3] - a[3]
    n = math.hypot(dx, dz) or 1
    return dx / n, dz / n


props = json.loads(Path(sys.argv[1]).read_text())
shots = []
for land in range(1, 11):
    found = []
    for pr in props:
        if pr["n"] not in WANT[land]:
            continue
        i = nearest(pr["p"][0], pr["p"][2])
        s = P[i][0]
        if land_of(s) != land or s > path["BuiltTo"] - 50:
            continue
        found.append((WANT[land].index(pr["n"]), -max(pr["s"]), pr, i))
    found.sort(key=lambda t: (t[0], t[1]))
    picked, kinds = [], set()
    for f in found:  # the best of the first kind, then the best of another kind
        if f[2]["n"] not in kinds:
            picked.append(f)
            kinds.add(f[2]["n"])
        if len(picked) == 3:
            break
    # a, b: the first two kinds; d, e: the same two close up; f: a third kind close up (from the second round)
    order = [(picked[0], "a", 1.7, 0.15)] + ([(picked[1], "b", 2.3, 0.45)] if len(picked) > 1 else [])
    order += [(picked[0], "d", 0.9, 0.3)] + ([(picked[1], "e", 0.8, 0.25)] if len(picked) > 1 else [])
    order += [(picked[2], "f", 0.8, 0.25)] if len(picked) > 2 else []
    for (rank, _, pr, i), letter, far, lift in order:
        px, py, pz = pr["p"]
        size = max(pr["s"])
        cx, cz = P[i][1] + OX, P[i][3]
        tx, tz = tangent(i)
        ox, oz = cx - px, cz - pz
        n = math.hypot(ox, oz) or 1
        ox, oz = ox / n, oz / n
        dx, dz = ox * 0.75 - tx * 0.65, oz * 0.75 - tz * 0.65
        n = math.hypot(dx, dz)
        dx, dz = dx / n, dz / n
        dist = size * far + 18
        eye = [px + dx * dist, min(py + size * lift + 6, -8), pz + dz * dist]  # always under the surface
        shots.append({"name": f"land{land:02d}{letter}", "what": pr["n"], "cam": eye + [px, py, pz]})
    # c: down the lane, from a little above, in the land's middle
    mid = (S0[land - 1] + S0[land]) / 2 - 200
    i = min(range(len(P)), key=lambda k: abs(P[k][0] - mid))
    j = min(range(len(P)), key=lambda k: abs(P[k][0] - (mid + 260)))
    eye = [P[i][1] + OX, P[i][2] + 45, P[i][3]]
    at = [P[j][1] + OX, P[j][2] + 8, P[j][3]]
    shots.append({"name": f"land{land:02d}c", "what": "the lane", "cam": eye + at})
print(json.dumps(shots, indent=1))
