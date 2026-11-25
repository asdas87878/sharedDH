"""The endless Underworld's loop, worked out on the saved place's own parts (NULLROOM e1, 2026-11-25).

    python tools/endless/loop.py <census folder> [joint|counts]

The census folder is what census.luau writes (parts.tsv). Nothing is read from or written to the place.
The loop: the stretch of the map from z FROM to z TO is shown again and again, SHIFT further each time (shared/Endless and
EndlessController do it in the game; the numbers here must be Config.Endless's, tests/loop_check says so).
  joint    draws the place where the stretch's end meets its own start, from above, and counts holes and steps there
  counts   how many parts the stretch has, how many need a second copy, how many are moved a second"""
import os
import sys

import numpy as np

FROM, TO, SHIFT = 20628.0, 23068.0, np.array([-224.0, -354.1, 2440.0])
OVER = {"Seabed": (48.0, 32.0), "Ground": (64.0, 64.0), "Walls": (8.0, 8.0), "Barrier": (8.0, 8.0)}
LONG = 32.0
FLAGS = {"Flag", "FlagLine", "FlagPost"}
GATE = 60.0  # the land's own gate of flags stands across FROM: flags before FROM + GATE are not shown again


class Part:
    __slots__ = ("folder", "model", "name", "c", "R", "h", "e", "colour", "unit")

    def __init__(self, r):
        self.folder = r[0].split("/")[2]
        self.model, self.name = r[1], r[2]
        self.c = np.array([float(v) for v in r[4].split(",")])
        self.R = np.array([float(v) for v in r[5].split(",")]).reshape(3, 3)
        self.h = np.array([float(v) for v in r[6].split(",")]) / 2
        self.e = np.abs(self.R) @ self.h
        self.colour = tuple(int(v) for v in r[7].split(","))
        self.unit = None


def load(folder, z0=19000.0):
    out = []
    for line in open(os.path.join(folder, "parts.tsv")):
        r = line.rstrip("\n").split("\t")
        if r[0].startswith("CB/Lane/") and float(r[4].split(",")[2]) > z0:
            out.append(Part(r))
    units = {}
    for p in out:
        key = (p.folder, p.model) if p.folder in ("Props", "Set") and p.model else id(p)
        units.setdefault(key, []).append(p)
    for parts in units.values():
        lo = min(p.c[2] - p.e[2] for p in parts)
        hi = max(p.c[2] + p.e[2] for p in parts)
        for p in parts:
            p.unit = ((lo + hi) / 2, (hi - lo) / 2)  # the unit's middle and half length, down z
    return out


def inloop(p):
    a, b = (-GATE, 0.0) if p.name in FLAGS else OVER.get(p.folder, (0.0, 0.0))
    return FROM - a <= p.unit[0] < TO + b


def tail(p):
    """past the stretch: put away while the loop is on"""
    return p.unit[0] >= TO + OVER.get(p.folder, (0.0, 0.0))[1]


def tops(parts, shifts, x0, x1, z0, z1, cell, folders=("Seabed", "Ground", "Walls")):
    """the highest thing at each cell seen from above, and which folder it is"""
    nx, nz = int((x1 - x0) / cell), int((z1 - z0) / cell)
    H = np.full((nz, nx), -1e9)
    W = np.full((nz, nx), -1, int)
    for p, s in zip(parts, shifts):
        if p.folder not in folders:
            continue
        c = p.c + s
        i0, i1 = int(max(0, (c[0] - p.e[0] - x0) / cell)), int(min(nx - 1, (c[0] + p.e[0] - x0) / cell + 1))
        j0, j1 = int(max(0, (c[2] - p.e[2] - z0) / cell)), int(min(nz - 1, (c[2] + p.e[2] - z0) / cell + 1))
        if c[0] + p.e[0] < x0 or c[2] + p.e[2] < z0 or i1 < i0 or j1 < j0:
            continue
        X, Z = np.meshgrid(x0 + (np.arange(i0, i1 + 1) + 0.5) * cell, z0 + (np.arange(j0, j1 + 1) + 0.5) * cell)
        lo, hi = np.full(X.shape, -1e9), np.full(X.shape, 1e9)
        for k in range(3):
            a = p.R[0, k] * (X - c[0]) + p.R[2, k] * (Z - c[2])
            b = p.R[1, k]
            if abs(b) < 1e-6:
                lo[np.abs(a) > p.h[k]] = 1e9
            else:
                t1, t2 = (-p.h[k] - a) / b, (p.h[k] - a) / b
                lo, hi = np.maximum(lo, np.minimum(t1, t2)), np.minimum(hi, np.maximum(t1, t2))
        y = np.where(hi >= lo, c[1] + hi, -1e9)
        sub = H[j0 : j1 + 1, i0 : i1 + 1]
        up = y > sub
        sub[up] = y[up]
        W[j0 : j1 + 1, i0 : i1 + 1][up] = folders.index(p.folder)
    H[H < -1e8] = np.nan
    return H, W


def joined(parts, lap=0):
    """the parts round the joint as a rider sees them: the stretch's end (as lap `lap` has it) and the next image's start"""
    out, shifts = [], []
    for p in parts:
        if not tail(p) and (lap == 0 or inloop(p)):
            out.append(p)
            shifts.append(SHIFT * lap)
        if inloop(p):
            out.append(p)
            shifts.append(SHIFT * (lap + 1))
    return out, shifts


def shade(H, lo, hi):
    g = np.nan_to_num(np.clip((H - lo) / (hi - lo), 0, 1))
    gy, gx = np.gradient(np.nan_to_num(H, nan=lo), 3)
    s = np.clip(0.78 + 0.22 * (gx - gy), 0.3, 1.1)
    rgb = np.stack([60 + 190 * g, 90 + 120 * g, 150 - 60 * g], -1) * s[..., None]
    rgb[np.isnan(H)] = (255, 0, 255)
    return np.clip(rgb, 0, 255).astype("uint8")


def holes(H, cols):
    """cells of a band of columns with nothing under them"""
    return int(np.isnan(H[:, cols]).sum())


if __name__ == "__main__":
    parts = load(sys.argv[1])
    what = sys.argv[2] if len(sys.argv) > 2 else "counts"
    if what == "counts":
        body = [p for p in parts if inloop(p)]
        longs = [p for p in body if p.unit[1] > LONG]
        print("loop parts", len(body), "long (second copy)", len(longs), "put away at the end", sum(tail(p) for p in parts))
        import collections
        print(" by folder", collections.Counter(p.folder for p in body), "long", collections.Counter(p.folder for p in longs))
        print(" tail", collections.Counter((p.folder, p.name) for p in parts if tail(p)))
        per = len(body) / SHIFT[2]
        print(" parts a stud %.2f: moved a second at 175 studs/s %.0f" % (per, per * 175))
        worst = max(p.unit[1] for p in body if p.unit[1] <= LONG)
        print(" a flip is at least", SHIFT[2] / 2 - 8 - worst, "studs from the eye down the lane (unit half length up to %.1f)" % worst)
    if what == "joint":
        from PIL import Image
        x0, x1, z0, z1 = 2100, 3800, TO - 260, TO + 420
        for lap in (0,):
            q, s = joined(parts, lap)
            H, W = tops(q, s, x0, x1, z0, z1, 3)
            im = shade(H, -2270, -1950)
            im[int((TO - z0) / 3), ::8] = (255, 255, 0)
            Image.fromarray(im[::-1]).resize((im.shape[1] * 2, im.shape[0] * 2)).save(sys.argv[3])
            # holes within the two walls' reach, by 60-stud band down z
            nan = np.isnan(H)
            for k in range(0, H.shape[0], 20):
                row = nan[k : k + 20]
                print("z %+5d" % (z0 + k * 3 - TO), "holes (cells of 9 sq studs) x2300-3600:", int(row[:, 67:500].sum()))
