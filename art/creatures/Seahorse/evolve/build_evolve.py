"""Exports the evolved rockers as game meshes (local files, nothing is uploaded) and measures what the game needs to place them.

usage: python art/creatures/Seahorse/evolve/build_evolve.py [7 8 ...]      (2 to 12 when none is named; level 1 stays the game's own)
Writes, beside this file:
  game/T<n>/SeahorseRocker<n>.glb and .mesh.json   voxel_kit.py --export with the draft coil left out (ROCKER_GAME=1)
  game/rockers.json   one row a level. Everything in the exported mesh's own space is in EXPORT studs (+Y up, head toward -Z,
      the origin the middle of the model's box); everything named game... is in the hub's studs (times 0.85), measured from the
      spring's axis on the floor: x to the creature's right, z toward its tail (so ahead is negative)
      name, title, lights, rainbow, keep       as tiers.json had them
      toyParts, standParts                      which part is which (the toy: Body and all under it)
      foot, standTop, springAt, bodyPivot, seat in the export's space
      coilRing, coilWire, springLength          the spring this level asks for, in the hub's studs
      swing                                     degrees each way
      pad                                       the stand's pad, half its side, in the hub's studs
      game: ahead, behind, left, right, top     how far the toy and stand reach
      game: seatTop                             the saddle's height
      game: lowest                              for each 3 studs out from the axis: the lowest toy point there, and the
                                                highest, at rest (a fence's height is what matters there)
      glow                                      share of the picture that glows (from the preview's 3/4 view, if rendered)
"""
import json
import math
import os
import runpy
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
sys.path.insert(0, os.path.join(ROOT, "tools", "creatures"))
sys.path.insert(0, HERE)
import common as c  # noqa: E402
import glb_meshes  # noqa: E402
from voxel_paths import BLENDER  # noqa: E402

KIT = os.path.join(ROOT, "tools", "blender", "voxel_kit.py")
GAME = os.path.join(HERE, "game")


def export(n):
    folder = os.path.join(GAME, f"T{n}")
    os.makedirs(folder, exist_ok=True)
    run = subprocess.run([BLENDER, "--background", "--python", KIT, "--", os.path.join(HERE, f"T{n:02d}", "voxel.py"), folder,
                          "--export", folder], capture_output=True, text=True, env=dict(os.environ, ROCKER_GAME="1"))
    log = [ln for ln in (run.stdout + run.stderr).splitlines()
           if any(w in ln for w in ("Error", "Traceback", "voxel kit: export")) or ln.startswith("  !")]
    print(f"level {n}:", " | ".join(log) or "no output", flush=True)
    return not any("Error" in ln or ln.startswith("  !") for ln in log) and bool(log)


def row(n):
    stem = os.path.join(GAME, f"T{n}", f"SeahorseRocker{n}")
    info = json.load(open(stem + ".mesh.json", encoding="utf-8"))
    os.environ["ROCKER_GAME"] = "1"
    model = runpy.run_path(os.path.join(HERE, f"T{n:02d}", "voxel.py"))
    parent = {p["name"]: p["parent"] for p in info["parts"]}
    pivot = {p["name"]: p["pivot"] for p in info["parts"]}

    def toy(name):
        name = name[:-5] if name.endswith("_Glow") else name
        while name and name != "Body":
            name = parent.get(name)
        return name == "Body"

    parts = [p for p in glb_meshes.parts(stem + ".glb") if p["triangles"]]
    foot, s, k = pivot["Stand"], c.SIZES[n], c.SHOWN
    up = lambda cubes: round(foot[1] + cubes * c.U, 4)  # noqa: E731
    pts = {True: [], False: []}
    for p in parts:
        for v in p["positions"]:
            pts[toy(p["name"])].append([(p["origin"][a] + v[a] - foot[a]) * k for a in range(3)])
    both = pts[True] + pts[False]
    lows = {}
    for x, y, z in pts[True]:
        ring = int(math.hypot(x, z) // 3) * 3
        lo, hi = lows.get(ring, (1e9, -1e9))
        lows[ring] = (min(lo, y), max(hi, y))
    seat = info["seat"]
    tri = sum(len(p["triangles"]) for p in parts)
    return {
        "name": f"SeahorseRocker{n}", "title": c.NAMES[n], "triangles": tri, "parts": len(parts),
        "lights": [[a, list(b), d, e, f] for a, b, d, e, f in model.get("LIGHTS", [])],
        "rainbow": model.get("VARIANT") == "rainbow", "accent": model.get("ACCENT"), "keep": sorted(model.get("KEEP", [])),
        "toyParts": [p["name"] for p in parts if toy(p["name"])], "standParts": [p["name"] for p in parts if not toy(p["name"])],
        "foot": foot, "standTop": up(s["top"]), "springAt": [foot[0], up(s["belly"]), foot[2]], "bodyPivot": pivot["Body"], "seat": seat,
        "coilRing": round(s["ring"] * c.U * k, 3), "coilWire": round(s["wire"] * c.U * k, 3),
        "springLength": round((s["belly"] - s["top"]) * c.U * k, 3), "swing": model.get("SWING"),
        "pad": round((s["pad"] + 0.5) * c.U * k, 2),
        "game": {"ahead": round(-min(p[2] for p in both), 1), "behind": round(max(p[2] for p in both), 1),
                 "left": round(-min(p[0] for p in both), 1), "right": round(max(p[0] for p in both), 1),
                 "top": round(max(p[1] for p in both), 1), "seatTop": round((seat[1] - foot[1]) * k, 1),
                 "seatBehind": round((seat[2] - foot[2]) * k, 1),
                 "lowest": {str(r): [round(a, 1), round(b, 1)] for r, (a, b) in sorted(lows.items())}},
    }


if __name__ == "__main__":
    levels = [int(a) for a in sys.argv[1:] if a.isdigit()] or [n for n in range(2, 13) if os.path.exists(os.path.join(HERE, f"T{n:02d}", "voxel.py"))]
    out = os.path.join(GAME, "rockers.json")
    rows = json.load(open(out, encoding="utf-8")) if os.path.exists(out) else {}
    bad = 0
    for n in levels:
        if not export(n):
            bad += 1
            continue
        rows[str(n)] = row(n)
        g = rows[str(n)]["game"]
        print(f"   ahead {g['ahead']}, behind {g['behind']}, sides {g['left']}/{g['right']}, top {g['top']}, seat {g['seatTop']}; "
              f"{rows[str(n)]['triangles']} triangles, {rows[str(n)]['parts']} meshes", flush=True)
    json.dump({k: rows[k] for k in sorted(rows, key=int)}, open(out, "w", encoding="utf-8", newline="\n"), indent=1)
    sys.exit(1 if bad else 0)
