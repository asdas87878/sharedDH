"""The endless study's seeded stacker: from one whole number, the same endless run of chunks on every machine.

  python tools/endless/stack.py <chunks.pkl> [out.json] [today's line.json]     the checks and the numbers (docs/design/endless.md)

The rules: a chunk's shape never comes back within KEEP chunks (either hand); a look (the land it is painted and lit as)
lasts one layer and never comes back within LOOKS_KEEP layers; every BOSS layers the layer ends in a landmark; the way
turns round a column (lay "spiral", RADIUS studs across from its middle) or runs on (lay "straight").
The random numbers are a plain 32-bit mix (mulberry32): the same in Luau with bit32, so a client and the server agree."""
import json
import math
import pickle
import sys

import numpy as np

import chunks as ch

KEEP, LAYER, LOOKS_KEEP, BOSS, RADIUS = 8, 3, 3, 5, 3200.0
SEEDS = 100
# where today's lane ends in the place: the generator's own line at s 23,500 (its x -110.6, moved by the place's +3,000)
START, H0 = (2889.4, -2224.5, 23076.5), -0.0128
PACE = 175.0  # studs a second: land 10's ridden mean (109.9) x Config.Speed.Ride (1.6)


class Dice:
    def __init__(self, seed):
        self.a = seed & 0xFFFFFFFF

    def next(self):
        self.a = (self.a + 0x6D2B79F5) & 0xFFFFFFFF
        t = self.a
        t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
        t = (t ^ ((t + ((t ^ (t >> 7)) * (t | 61))) & 0xFFFFFFFF)) & 0xFFFFFFFF
        return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

    def pick(self, n):
        return min(n - 1, int(self.next() * n))


def stack(shapes, seed, count, lay="spiral", start=(0.0, 0.0, 0.0), h0=0.0, keep=KEEP):
    """shapes: the chunk library. -> a list of {shape, hand, look, layer, boss, at, heading, s}"""
    dice = Dice(seed)
    way = 1 if dice.next() < 0.5 else -1  # which way round the column
    pos, h, s = np.array(start, float), h0, 0.0
    B = ch.basis(h)
    col = pos + way * RADIUS * B[0]
    out, recent, looks = [], [], []
    for i in range(count):
        layer = i // LAYER
        if i % LAYER == 0:
            free = [k for k in range(10) if k not in looks[-LOOKS_KEEP:]]
            looks.append(free[dice.pick(len(free))])
        cands = []
        for k, c in enumerate(shapes):
            if k in recent[-keep:]:
                continue
            for hand in (1, -1):
                ex = c["exit"] * (np.array([hand, 1, 1]))
                p = pos + ch.basis(h).T @ ex
                g = h + c["turn"] * hand
                if lay == "spiral":
                    r = p - col
                    rr = math.hypot(r[0], r[2])
                    # round the column: the heading that keeps it on one's own side
                    t = math.atan2(-way * r[2], way * r[0]) + math.pi  # tangent
                    t = math.atan2(*( -way * np.array([-r[2], r[0]]) )) if False else math.atan2(way * r[2], -way * r[0])
                    off = (g - t + math.pi) % (2 * math.pi) - math.pi
                    cost = ((rr - RADIUS) / 350.0) ** 2 + (math.degrees(off) / 16.0) ** 2
                else:
                    cost = (math.degrees(g - h0) / 30.0) ** 2
                cands.append((cost, k, hand))
        low = min(c[0] for c in cands)
        w = [math.exp(-(c[0] - low) / 2.0) for c in cands]
        roll, pick = dice.next() * sum(w), cands[-1]
        for c, ww in zip(cands, w):
            roll -= ww
            if roll <= 0:
                pick = c
                break
        _cost, k, hand = pick
        c = shapes[k]
        out.append({"i": i, "shape": k, "hand": hand, "look": looks[-1], "layer": layer, "s": s, "at": pos.copy(), "h": h,
                    "boss": i % (LAYER * BOSS) == LAYER * BOSS - 1})
        pos = pos + ch.basis(h).T @ (c["exit"] * np.array([hand, 1, 1]))
        h += c["turn"] * hand
        s += c["long"]
        recent.append(k)
    return out


def way_of(shapes, p):
    c = shapes[p["shape"]]
    return p["at"] + (c["way"] * np.array([p["hand"], 1, 1])) @ ch.basis(p["h"])


def clashes(shapes, run, wide=950.0, tall=750.0):
    """pairs of chunks, not neighbours, whose canyons would stand in each other: nearer than `wide` on the flat (each
    canyon's scenery reaches about that far from its middle line) and than `tall` in height"""
    ways = [way_of(shapes, p)[::12] for p in run]
    bad = []
    for a in range(len(run)):
        for b in range(a + 2, len(run)):
            if abs(ways[a][:, 1].mean() - ways[b][:, 1].mean()) > tall + 200:
                continue
            d = ways[a][:, None] - ways[b][None]
            flat = np.hypot(d[..., 0], d[..., 2])
            near = (flat < (wide if b > a + 2 else 0.0)) & (np.abs(d[..., 1]) < tall)
            if near.any():
                bad.append((a, b, float(flat[near].min())))
    return bad


def ulp(v):
    return float(np.spacing(np.float32(abs(v))))


def under_today(shapes, line, lay="spiral", wide=950.0):
    """how far under today's lane (build_lane.py today's line.json) the run is wherever it is within `wide` of it on the
    flat, from its third chunk on: the least over the seeds"""
    L = np.array(json.load(open(line))["Line"])[::4, 1:4] + np.array([3000.0, 0, 0])
    least = 1e9
    for seed in range(1, SEEDS + 1):
        for p in stack(shapes, seed, 60, lay, START, H0)[2:]:
            d = way_of(shapes, p)[::12][:, None] - L[None]
            near = np.hypot(d[..., 0], d[..., 2]) < wide
            if near.any():
                least = min(least, float(np.abs(d[..., 1])[near].min()))
    return least


def main(pkl, out=None, line=None):
    made, today = pickle.load(open(pkl, "rb"))
    res = {}
    if line:
        print("the spiral's least height from today's lane, where it is within 950 studs of it:", round(under_today(made, line)))
    print("same seed twice, the same run:", all(json.dumps([(p["shape"], p["hand"], p["look"]) for p in stack(made, s, 200)]) ==
          json.dumps([(p["shape"], p["hand"], p["look"]) for p in stack(made, s, 200)]) for s in (1, 2, 3)))
    for lay in ("spiral", "straight"):
        for mins in (10, 30, 60):
            n = int(mins * 60 * PACE / 1200)
            far, gaps, full, runs, clash = [], [], [], 0, 0
            for seed in range(1, SEEDS + 1):
                run = stack(made, seed, n, lay, START, H0)
                last = {}
                for p in run:
                    if p["shape"] in last:
                        gaps.append(p["i"] - last[p["shape"]])
                    last[p["shape"]] = p["i"]
                seen = {}
                for p in run:
                    key = (p["shape"], p["hand"], p["look"])
                    seen[key] = seen.get(key, 0) + 1
                full.append(len(seen) / n)
                # three in a row exactly as before (shapes and hands)
                tri, again = set(), 0
                for a, b, c in zip(run, run[1:], run[2:]):
                    t = tuple((q["shape"], q["hand"]) for q in (a, b, c))
                    again += t in tri
                    tri.add(t)
                runs += again
                P = np.array([p["at"] for p in run])
                far.append((np.abs(P[:, 0]).max(), P[:, 1].min(), np.abs(P[:, 2]).max(), P[:, 0].min(), P[:, 0].max(), P[:, 2].min(), P[:, 2].max()))
                if seed <= 20:
                    clash += len(clashes(made, run[:100]))
            f = np.array(far)
            row = {"mins": mins, "chunks": n, "x": f[:, 0].max(), "y": f[:, 1].min(), "z": f[:, 2].max(), "ulp": max(ulp(f[:, 0].max()), ulp(f[:, 2].max()), ulp(f[:, 1].min())),
                   "x_from": f[:, 3].min(), "x_to": f[:, 4].max(),
                   "z_from": f[:, 5].min(), "z_to": f[:, 6].max(), "z_over_27700": int((f[:, 2] > 27700).sum()), "gap_mean": float(np.mean(gaps)), "gap_min": int(min(gaps)), "new_share": float(np.mean(full)), "three_again": runs / SEEDS, "clash": clash}
            res[f"{lay}{mins}"] = row
            print(lay, {k: (round(v, 5) if isinstance(v, float) else v) for k, v in row.items()})
    if out:
        json.dump(res, open(out, "w"), indent=1, default=float)


if __name__ == "__main__":
    main(*sys.argv[1:])
