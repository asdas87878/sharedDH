"""The parts' boxes of the creatures with a new eating move, for tools/eat/eat_check.luau (a model's MeshParts are made
from the same meshes): each part's box in the fish's axes and, for an octopus's arms (A1a to A8c), the turned boxes its
mesh is really made of, and for a Kronosaurus's head its box cut in slices from the nose back (its snout tapers).
Creatures with no .obj are left out.
    python3 tools/eat/boxes.py > work/eat/boxes.json          (the two with a new move)
    python3 tools/eat/boxes.py all > work/eat/boxes_all.json  (every modelled creature, for eat_same.luau)"""
import glob
import json
import os
import re
import sys

NAMES = sys.argv[1:] or ["Kronosaurus", "Octopus"]
if NAMES == ["all"]:
    NAMES = sorted(os.path.basename(p)[:-4] for p in glob.glob("art/creatures/*/game/*.obj"))


def sub(a, b):
    return [x - y for x, y in zip(a, b)]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def turned(points):
    """the box eight corners make: its middle, three axes and half sizes"""
    a, rest = points[0], points[1:]
    far = max(rest, key=lambda p: dot(sub(p, a), sub(p, a)))
    best = None
    for i in range(len(rest)):
        for j in range(i):
            for k in range(j):
                e = [sub(rest[n], a) for n in (i, j, k)]
                long = [dot(v, v) ** 0.5 for v in e]
                skew = max(abs(dot(e[x], e[y])) / (long[x] * long[y]) for x, y in ((0, 1), (1, 2), (0, 2)))
                miss = sub([a[n] + e[0][n] + e[1][n] + e[2][n] for n in range(3)], far)
                bad = skew + dot(miss, miss) ** 0.5
                if best is None or bad < best[0]:
                    best = (bad, e, long)
    bad, e, long = best
    assert bad < 0.05, ("not a box", bad, points)
    return {
        "mid": [(x + y) / 2 for x, y in zip(a, far)],
        "axes": [[c / n for c in v] for v, n in zip(e, long)],
        "half": [n / 2 for n in long],
    }


out = {}
for name in NAMES:
    path = f"art/creatures/{name}/game/{name}.obj"
    if not os.path.exists(path):
        print("no mesh:", name, file=sys.stderr)
        continue
    vs, faces, cur = [], {}, None
    for line in open(path):
        if line.startswith("v "):
            vs.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("o "):
            cur = line.split()[1]
            faces[cur] = []
        elif line.startswith("f "):
            faces[cur].append([int(p.split("/")[0]) - 1 for p in line.split()[1:]])
    out[name] = {}
    for part, fs in faces.items():
        pts = [vs[i] for f in fs for i in f]
        box = [[min(p[k] for p in pts) for k in range(3)], [max(p[k] for p in pts) for k in range(3)]]
        out[name][part] = box
        if name == "Kronosaurus" and part == "Head":
            slices, n = [], 14
            for i in range(n):
                z0, z1 = (box[0][2] + (box[1][2] - box[0][2]) * (i + j) / n for j in (0, 1))
                # every face that comes into the slice, whole: never less than is there
                near = [
                    vs[i]
                    for f in fs
                    if min(vs[i][2] for i in f) < z1 - 1e-4 and max(vs[i][2] for i in f) > z0 + 1e-4
                    for i in f
                ]
                if near:
                    lo = [min(p[k] for p in near) for k in range(2)] + [z0]
                    slices.append([lo, [max(p[k] for p in near) for k in range(2)] + [z1]])
            box.append(slices)
        if name == "Octopus" and re.fullmatch(r"A\d[abc]", part):
            # the pieces: corners that share a face
            up = {}

            def top(x):
                while up.setdefault(x, x) != x:
                    x = up[x]
                return x

            for f in fs:
                ks = [tuple(round(c, 3) for c in vs[i]) for i in f]
                for k in ks[1:]:
                    up[top(k)] = top(ks[0])
            groups = {}
            for k in list(up):
                groups.setdefault(top(k), []).append(k)
            box.append([turned([list(p) for p in g]) for g in groups.values()])
json.dump(out, sys.stdout)
