"""The solid boxes round the lip of the start strip, for the offline dive check (tools/dive/fish_dive_check.luau).

Read from the map generator's own lists (art/map/greybox/parts.json and hub.json: tools/map/greybox.py and hub_kit.py),
NOT from the saved place: a thing placed or moved by hand in Studio is not in them. In the generator's own space: the
lip is the line z = 0, the hub is at z < 0, the water at z > 0, the gate is 96 wide about x = 0 (in the place the map
may stand somewhere else; the dive finds the lip by rays, so only the shapes matter).

usage: python tools/dive/lip_boxes.py <repo> <out.json>
"""
import json
import os
import sys

REACH_X = 340.0  # either side of the gate's middle
Z_FROM, Z_TO = -170.0, 460.0  # from inside the hub to well down the first room


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def main():
    repo, out = sys.argv[1], sys.argv[2]
    folder = os.path.join(repo, "art", "map", "greybox")
    boxes = []
    for p in json.load(open(os.path.join(folder, "parts.json")))["parts"]:
        if not p.get("solid") or p["k"] in ("prop", "far", "water"):
            continue  # (the lane's props are left out: fish break them or swim through, and the camera ignores them)
        boxes.append({"n": p["n"], "k": p["k"], "p": p["p"], "x": p["x"], "y": p["y"], "z": p["z"], "s": p["s"]})
    for p in json.load(open(os.path.join(folder, "hub.json")))["parts"]:
        if not p.get("f", 0) & 1:
            continue
        boxes.append({"n": p["m"] + "/" + p["n"], "k": "hubkit", "p": p["p"], "x": p["x"], "y": p["y"], "z": cross(p["x"], p["y"]), "s": p["s"]})
    near = []
    for b in boxes:
        reach = 0.5 * (b["s"][0] ** 2 + b["s"][1] ** 2 + b["s"][2] ** 2) ** 0.5
        x, _, z = b["p"]
        if abs(x) - reach < REACH_X and z + reach > Z_FROM and z - reach < Z_TO:
            near.append(b)
    hub_in = json.load(open(os.path.join(folder, "hub_in.json")))
    json.dump({"boxes": near, "gate": hub_in["Gate"], "front": hub_in["Front"], "startDepth": hub_in["StartDepth"]}, open(out, "w"))
    print("%d solid boxes round the lip (of %d solid in the map), gate half %s" % (len(near), len(boxes), hub_in["Gate"]))


if __name__ == "__main__":
    main()
