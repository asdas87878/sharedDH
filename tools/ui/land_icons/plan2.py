"""Second round of camera spots for the land pictures (task l1): six new candidates a land, letters h to m, chosen to
differ from round one (a to g, plan.py):
  h  the land's first signature asset, another instance than round one's, from the lane's other side
  i  the second signature asset close up, from low (the lit water above it)
  j  a third kind close up (round one had at most one third kind)
  k  from above, looking down on the land's busiest cluster of big assets
  l  hero shot: low on the floor looking up at the biggest asset, the surface behind it
  m  across the lane from near a wall: the land's floor, a wall and an asset in one frame
    python tools/ui/land_icons/plan2.py <props.json> > plan2.json
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
path = json.loads((ROOT / "art/map/greybox/path.json").read_text())
P = path["Path"]  # s, x, floor y, z, w
S0 = [l["S0"] for l in path["Lands"]] + [path["BuiltTo"]]
OX = 3000
WANT = {
    1: ["pillar_coral", "brain_coral", "table_coral", "fan_coral", "giant_clam", "anemone"],
    2: ["coral_tree", "reef_wall", "tube_cluster", "fan_coral", "brain_coral", "anemone"],
    3: ["kelp_giant", "kelp_grove", "mossy_boulder", "sea_stack"],
    4: ["hull", "mast", "crates", "anchor"],
    5: ["sea_stack", "pillar_coral", "table_coral", "brain_coral", "giant_clam"],
    6: ["coral_tree", "tube_cluster", "reef_wall", "fan_coral", "anemone"],
    7: ["kelp_grove", "kelp_giant", "mossy_boulder", "sea_stack"],
    8: ["mast", "hull", "crates", "anchor", "sea_stack"],
    9: ["ribs", "skull", "bone_pillar", "sea_stack"],
    10: ["ribs", "bone_pillar", "skull", "sea_stack"],
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


def unit(x, z):
    n = math.hypot(x, z) or 1
    return x / n, z / n


props = json.loads(Path(sys.argv[1]).read_text())
by_land = {l: [] for l in range(1, 11)}
for pr in props:
    i = nearest(pr["p"][0], pr["p"][2])
    s = P[i][0]
    if s > path["BuiltTo"] - 50:
        continue
    by_land[land_of(s)].append((pr, i))

shots = []


def add(name, what, eye, at):
    eye = list(eye)
    eye[1] = min(eye[1], -14)  # always under the surface
    shots.append({"name": name, "what": what, "cam": [round(v, 1) for v in eye + list(at)]})


def lane(i, lateral, up):
    """A point in the lane: index i on its line, lateral as a share of the half width (+ the normal's side), up off the floor."""
    i = min(max(i, 0), len(P) - 1)
    _, x, y, z, w = P[i][:5]
    tx, tz = tangent(i)
    nx, nz = -tz, tx
    return x + OX + nx * w * 0.5 * lateral, y + up, z + nz * w * 0.5 * lateral


def side_of(pr, i):
    _, x, _, z, w = P[i][:5]
    tx, tz = tangent(i)
    return ((pr["p"][0] - x - OX) * -tz + (pr["p"][2] - z) * tx) / (w * 0.5)


def view(pr, i, far, lift, side, aim_up=0.0):
    """A camera inside the lane looking at the prop: back up the lane (side +1) or ahead of it looking back (-1), by
    `far` times its size, held to the lane's middle 70 %, `lift` times its size above the floor."""
    size = max(pr["s"])
    steps = max(1, round((size * far + 20) / 24))
    lat = max(-0.7, min(0.7, side_of(pr, i) * 0.25 - 0.35 * side * (1 if side_of(pr, i) > 0 else -1)))
    eye = lane(i - steps * side, lat, size * lift + 6)
    at = (pr["p"][0], pr["p"][1] + size * aim_up, pr["p"][2])
    return eye, at


for land in range(1, 11):
    items = by_land[land]
    kinds = {}
    for pr, i in items:
        if pr["n"] in WANT[land]:
            kinds.setdefault(pr["n"], []).append((pr, i))
    for k in kinds:
        kinds[k].sort(key=lambda t: -max(t[0]["s"]))
    order = [k for k in WANT[land] if k in kinds]
    k1 = order[0]
    k2 = order[1] if len(order) > 1 else k1
    k3 = order[2] if len(order) > 2 else k2
    # h: second-biggest instance of the first kind, from the other side
    pr, i = kinds[k1][min(1, len(kinds[k1]) - 1)]
    add(f"land{land:02d}h", k1, *view(pr, i, 1.2, 0.25, -1, 0.3))
    # i: the second kind close and low, aimed up a little
    pr, i = kinds[k2][0]
    add(f"land{land:02d}i", k2, *view(pr, i, 0.9, -0.05, 1, 0.45))
    # j: a third kind close
    pr, i = kinds[k3][min(1, len(kinds[k3]) - 1)] if k3 == k2 else kinds[k3][0]
    add(f"land{land:02d}j", k3, *view(pr, i, 0.8, 0.3, 1, 0.2))
    # k: above the busiest cluster of big assets
    big = [(pr, i) for pr, i in items if pr["n"] in WANT[land]]
    best, bc = None, -1
    for pr, i in big:
        c = sum(1 for q, _ in big if math.dist(q["p"], pr["p"]) < 90)
        if c > bc:
            best, bc = (pr, i), c
    pr, i = best
    tx, tz = tangent(i)
    px, py, pz = pr["p"]
    add(f"land{land:02d}k", f"cluster of {bc}", (px - tx * 70, py + 70, pz - tz * 70), (px + tx * 15, py, pz + tz * 15))
    # l: hero, from the floor looking up at the biggest asset of any wanted kind
    pr, i = max(big, key=lambda t: max(t[0]["s"]))
    fy = P[i][2]
    eye, at = view(pr, i, 1.0, 0, 1)
    add(f"land{land:02d}l", pr["n"] + " from below", (eye[0], fy + 3, eye[2]), (pr["p"][0], pr["p"][1] + max(pr["s"]) * 0.6, pr["p"][2]))
    # m: across the lane, from near the wall at the land's middle, looking at the far wall and down the lane a bit
    mid = (S0[land - 1] + S0[land]) / 2 + 150
    j = min(range(len(P)), key=lambda k: abs(P[k][0] - mid))
    s, x, y, z, w = P[j][:5]
    tx, tz = tangent(j)
    nx, nz = -tz, tx
    eye = (x + OX + nx * (w * 0.36), y + 22, z + nz * (w * 0.36))
    at = (x + OX - nx * (w * 0.3) + tx * 120, y + 6, z - nz * (w * 0.3) + tz * 120)
    add(f"land{land:02d}m", "across the lane", eye, at)
print(json.dumps(shots, indent=1))
