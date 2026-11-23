"""S, the hub at the reference's size (2026-11-23, docs/design/hub-review-2.md, section 3), tried on the real generator:
builds it with HUB_TRY into art/map/hub_study/S_<name>/ and checks every pen, station and pad of
tools/map/hub_scale_plan.py's S against the wall pieces the generator really made (its corners are round, which a
rectangle check misses). Nothing here goes into the game.

usage: python tools/map/hub_s.py [--keep]      (--keep: check what is built, don't build again)"""
import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_scale_plan as plan  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TRIES = {"f": plan.S_TRY}  # tried first and refused: 230 x 180 exactly (up to 15 studs into the corners), 238 x 184, 236 x 188 and 191


def build(name, numbers):
    out = os.path.join(ROOT, "art", "map", "hub_study", "S_" + name)
    if "--keep" not in sys.argv:
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "map", "greybox.py")],
                           env=dict(os.environ, GREYBOX_OUT=out, HUB_TRY=json.dumps(numbers)), capture_output=True, text=True)
        if r.returncode:
            return None, r.stderr.strip().splitlines()[-1]
    return json.load(open(os.path.join(out, "parts.json")))["parts"], ""


def corners(p):
    """a part's foot as four (x, z) corners, if it stands within a player's height of the floor"""
    (x, y, z), (sx, sy, sz), ax = p["p"], p["s"], p["x"]
    up = abs(p["y"][1]) * sy / 2 + (1 - abs(p["y"][1])) * max(sx, sz) / 2
    if y + up < 2.0 or y - up > 30:
        return None
    n = math.hypot(ax[0], ax[2]) or 1.0
    ux, uz = ax[0] / n, ax[2] / n
    return [(x + a * ux * sx / 2 - b * uz * sz / 2, z + a * uz * sx / 2 + b * ux * sz / 2) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def deep(quad, box):
    """how far a wall piece's foot reaches into a box (separating axes): 0 is clear"""
    a, b, c, e = box
    rect = [(a, c), (b, c), (b, e), (a, e)]
    least = 1e9
    for poly in (quad, rect):
        for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
            nx, nz = z1 - z0, x0 - x1
            n = math.hypot(nx, nz)
            if n < 1e-6:
                continue
            p = [(x * nx + z * nz) / n for x, z in quad]
            q = [(x * nx + z * nz) / n for x, z in rect]
            least = min(least, min(max(p), max(q)) - max(min(p), min(q)))
    return max(least, 0.0)


def check(parts):
    walls = []
    for p in parts:
        if p["k"] in ("face", "grass", "core") and abs(p["p"][0]) < 260 and -400 < p["p"][2] < 60:
            q = corners(p)
            if q:
                walls.append(q)
    boxes = {"pen%d" % (i + 1): box for i, box in enumerate(plan.s_pens)}
    for i, t in enumerate(plan.s_things):
        boxes[t[4] or ("board" if t[2] == 8 else "pad%d" % i)] = (t[0] - t[2] / 2, t[0] + t[2] / 2, t[1] - t[3] / 2, t[1] + t[3] / 2)
    bad = {}
    for name, box in boxes.items():
        worst = max((deep(q, box) for q in walls), default=0.0)
        if worst > 0.25:
            bad[name] = round(worst, 1)
    return len(walls), bad


if __name__ == "__main__":
    for name, numbers in TRIES.items():
        parts, err = build(name, numbers)
        print(name, numbers, err or check(parts))
