"""The parts' boxes of the two creatures with a new eating move, for tools/eat/eat_check.luau (a model's MeshParts are
made from the same meshes): python tools/eat/boxes.py > work/eat/boxes.json"""
import json
import sys

NAMES = sys.argv[1:] or ["Kronosaurus", "Octopus"]
out = {}
for name in NAMES:
    vs, boxes, cur = [], {}, None
    for line in open(f"art/creatures/{name}/game/{name}.obj"):
        if line.startswith("v "):
            vs.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("o "):
            cur = line.split()[1]
            boxes[cur] = [[1e9] * 3, [-1e9] * 3]
        elif line.startswith("f "):
            for p in line.split()[1:]:
                v = vs[int(p.split("/")[0]) - 1]
                lo, hi = boxes[cur]
                for k in range(3):
                    lo[k], hi[k] = min(lo[k], v[k]), max(hi[k], v[k])
    out[name] = boxes
json.dump(out, sys.stdout)
