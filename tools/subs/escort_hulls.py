"""Checks SubTrip.Hulls (src/shared/SubTrip.luau) against the subs' own models: the box each hull takes up round the
model's middle, studs: half its width, up, down, nose, tail (front = -Z), read from art/subs/<Id>/<Id>.glb. The rider's
fish keeps clear of that box (docs/design/submarine.md, "From the fish onto the sub"), so run it after a model changes.

usage: python3 tools/subs/escort_hulls.py      (prints the rows; exits 1 if a row is smaller than its model)
"""
import os
import re
import sys

import card_fit

IDS = ["Bathtub", "ReefRunner", "KelpCruiser", "WreckDiver", "BlueStreak", "TwilightRay", "MidnightHunter",
       "VentCrawler", "AbyssKing"]


def main():
    text = open(os.path.join(card_fit.ROOT, "src", "shared", "SubTrip.luau"), encoding="utf-8").read()
    block = re.search(r"SubTrip\.Hulls = \{\n(.*?)\n\}", text, re.S).group(1)
    rows = [[float(v) for v in re.findall(r"[-\d.]+", line)] for line in block.splitlines()]
    assert len(rows) == len(IDS), "%d rows for %d subs" % (len(rows), len(IDS))
    bad = 0
    for tier, (sub, row) in enumerate(zip(IDS, rows), 1):
        pts = card_fit.points_of(os.path.join(card_fit.ROOT, "art", "subs", sub, sub + ".glb"))
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        real = [max(-lo[0], hi[0]), hi[1], -lo[1], -lo[2], hi[2]]
        fits = all(have >= want - 0.1 for have, want in zip(row, real))
        bad += not fits
        print("%-5s %d %-15s model %s  row %s" % ("ok" if fits else "SMALL", tier, sub,
                                                  " ".join("%5.1f" % v for v in real), row))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
