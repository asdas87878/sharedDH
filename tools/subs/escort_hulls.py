"""Checks SubTrip.Hulls (src/shared/SubTrip.luau) against the subs' own models: the box each hull takes up round the
model's middle, studs: half its width, up, down, nose, tail (front = -Z), read from art/subs/<Id>/<Id>.glb. The rider's
fish keeps clear of that box (docs/design/submarine.md, "From the fish onto the sub"), so run it after a model changes.

usage: python3 tools/subs/escort_hulls.py [cells.json]     (prints the rows; exits 1 if a row is smaller than its model)
With a path it also writes the models as little cells (the ones their surfaces go through, CELL studs, and the rider on
the seat), for escort_check.luau's readings of how much of the fish the sub hides.
"""
import json
import math
import os
import re
import sys

import card_fit

IDS = ["Bathtub", "ReefRunner", "KelpCruiser", "WreckDiver", "BlueStreak", "TwilightRay", "MidnightHunter",
       "VentCrawler", "AbyssKing"]

CELL = 1.0
SEAT = (0, 7.4, 5)  # (SubTrip.Seat)


def cells_of(path):
    """the cells a model's triangles go through, each sampled closer than a cell, as "x,y,z" of whole cells"""
    out = set()
    for p in card_fit.glb_meshes.parts(path):
        pts = [[v[i] + p["origin"][i] for i in range(3)] for v in p["positions"]]
        for tri in p["triangles"]:
            a, b, c = (pts[i] for i in tri)
            n = max(1, math.ceil(max(math.dist(a, b), math.dist(a, c), math.dist(b, c)) / (CELL * 0.6)))
            for i in range(n + 1):
                for k in range(n + 1 - i):
                    u, v = i / n, k / n
                    out.add(tuple(math.floor((a[q] + (b[q] - a[q]) * u + (c[q] - a[q]) * v) / CELL) for q in range(3)))
    for x in range(-2, 2):
        for y in range(-3, 4):
            for z in range(-1, 1):
                out.add((x, math.floor(SEAT[1]) + y, SEAT[2] + z))
    return sorted(out)


def main():
    text = open(os.path.join(card_fit.ROOT, "src", "shared", "SubTrip.luau"), encoding="utf-8").read()
    block = re.search(r"SubTrip\.Hulls = \{\n(.*?)\n\}", text, re.S).group(1)
    rows = [[float(v) for v in re.findall(r"[-\d.]+", line)] for line in block.splitlines()]
    assert len(rows) == len(IDS), "%d rows for %d subs" % (len(rows), len(IDS))
    bad = 0
    cells = []
    for tier, (sub, row) in enumerate(zip(IDS, rows), 1):
        pts = card_fit.points_of(os.path.join(card_fit.ROOT, "art", "subs", sub, sub + ".glb"))
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        real = [max(-lo[0], hi[0]), hi[1], -lo[1], -lo[2], hi[2]]
        fits = all(have >= want - 0.1 for have, want in zip(row, real))
        bad += not fits
        print("%-5s %d %-15s model %s  row %s" % ("ok" if fits else "SMALL", tier, sub,
                                                  " ".join("%5.1f" % v for v in real), row))
        if len(sys.argv) > 1:
            cells.append(["%d,%d,%d" % c for c in cells_of(os.path.join(card_fit.ROOT, "art", "subs", sub, sub + ".glb"))])
    if len(sys.argv) > 1:
        open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"Cell": CELL, "Subs": cells}))
        print("cells:", [len(c) for c in cells])
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
