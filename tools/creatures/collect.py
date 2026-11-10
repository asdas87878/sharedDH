"""Gathers what the game needs to know about each exported creature into src/shared/Creatures/<Id>.json, which Rojo
turns into a module the server and the clients read (FishModel builds the joints from it, AnimController plays the swim).
usage: python tools/creatures/collect.py            (every art/creatures/<Folder>/game/<Name>.mesh.json)

The meshes themselves are not here: they are uploaded to Roblox and sit in ReplicatedStorage.FishModels.<Id> in the place.
What is kept, in the creature's own space (studs, +Y up, the head toward -Z, the bounding box's middle at the origin):
  Name, Tier ("Common" ... "Mythic"), Zone (the land it lives in, 1 = Shallows), Size [x, y, z], Seat [x, y, z], Parts [[name, parent or "", pivot x, y, z]...] (parents before children),
  Glow [part names that are Neon], Moments (keys in one swim cycle) and Keys {part: [x, y, z, w, ...]} (each moving
  part's turn about its pivot at each moment, quaternions end to end; rest pose is 0, 0, 0, 1).
The Id is the folder's name, which is also the Id in src/shared/Config.luau's fish table.
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "src", "shared", "Creatures")


def r(v, n=4):
    v = round(float(v), n)
    return 0.0 if v == 0 else v


def collect(path):
    j = json.load(open(path, encoding="utf-8"))
    folder = os.path.basename(os.path.dirname(os.path.dirname(path)))
    names = [p["name"] for p in j["parts"]]
    # parents before children, so the game can build joints in one pass
    done, parts = set(), []
    pending = list(j["parts"])
    while pending:
        rest = []
        for p in pending:
            if p["parent"] is None or p["parent"] in done:
                parts.append([p["name"], p["parent"] or "", r(p["pivot"][0]), r(p["pivot"][1]), r(p["pivot"][2])])
                done.add(p["name"])
            else:
                rest.append(p)
        assert len(rest) < len(pending), f"{folder}: a part's parent is missing: {[p['name'] for p in rest]}"
        pending = rest
    keys = {}
    swim = j.get("swimKeys") or {}
    moments = int(swim.get("moments", 0))
    for part, rows in (swim.get("parts") or {}).items():
        assert part in names, f"{folder}: swim keys for an unknown part {part}"
        assert len(rows) == moments, f"{folder}: {part} has {len(rows)} keys, not {moments}"
        if all(abs(q[0]) < 1e-5 and abs(q[1]) < 1e-5 and abs(q[2]) < 1e-5 for q in rows):
            continue  # never moves
        keys[part] = [r(v, 5) for q in rows for v in q]
    zone = re.search(r"(\d+)", j["zone"])
    assert zone, f"{folder}: no zone number in {j['zone']!r}"
    out = {
        "Name": re.sub(r"\s*\(.*\)\s*$", "", j["name"]),
        "Tier": j["rarity"].strip().capitalize(),
        "Zone": int(zone.group(1)),
        "Size": [r(v, 3) for v in j["size"]],
        "Seat": [r(v, 3) for v in j["seat"]],
        "Parts": parts,
        "Glow": list(j.get("glowParts") or []),
        "Moments": moments,
        "Keys": keys,
    }
    os.makedirs(OUT, exist_ok=True)
    text = json.dumps(out, separators=(",", ":"))
    assert len(text) < 190000, f"{folder}: {len(text)} characters is too long for one module"
    open(os.path.join(OUT, folder + ".json"), "w", encoding="utf-8").write(text)
    return folder, len(parts), len(keys), len(text)


if __name__ == "__main__":
    rows = [collect(p) for p in sorted(glob.glob(os.path.join(ROOT, "art", "creatures", "*", "game", "*.mesh.json")))]
    for folder, parts, moving, size in rows:
        print(f"{folder:18} {parts:3} parts, {moving:3} moving, {size:6} characters")
    print(len(rows), "creatures ->", os.path.relpath(OUT, ROOT))
