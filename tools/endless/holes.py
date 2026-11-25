"""What is missing beside a joint: python tools/endless/holes.py <chunks.pkl>

Every chunk's end against every other chunk's start (both hands), looked at from above on a grid: REACH studs either side of
the neck's edge and ALONG studs either way of the cut. A cell is a hole when no floor, wall, grass or shelf of either
chunk covers it. The two chunks that were neighbours where they were made are the control. Then the same with the joint's
own boxes (chunks.joint) in place."""
import pickle
import sys

import numpy as np

import chunks as ch

REACH, ALONG, CELL, NECK = 300.0, 72.0, 5.0, 168.0
US = np.arange(-NECK - REACH + CELL / 2, NECK + REACH, CELL)
VS = np.arange(-ALONG + CELL / 2, ALONG, CELL)
SOLID = [ch.KINDS.index(k) for k in ("face", "grass", "core", "ground")]
CORNERS = np.array([[x, y, z] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float)
FALL = np.tan(np.radians(6.0))
EYE = 40.0  # a rider's height over the floor, for the sight lines


def covered(P, A, S, o, B, over=None):
    """which cells of the joint's grid (u to the right, v ahead of the cut) a set of boxes covers, seen from above; over:
    only the boxes that stand across that height over the floor"""
    out = np.zeros((len(VS), len(US)), bool)
    d = P - o
    near = (np.abs(d @ B[2]) < ALONG + 160) & (np.abs(d @ B[0]) < NECK + REACH + 160)
    for p, a, s in zip(d[near], A[near], S[near]):
        c = (CORNERS * s / 2) @ a + p
        q = np.stack([c @ B[0], c @ B[2]], 1)
        if over is not None:
            h = c @ B[1] + q[:, 1] * FALL  # over the floor, which falls as it goes
            if not (h.min() < over < h.max()):
                continue
        if q[:, 0].max() < US[0] or q[:, 0].min() > US[-1] or q[:, 1].max() < VS[0] or q[:, 1].min() > VS[-1]:
            continue
        # the box's outline from above: the convex hull of its corners
        pts = q[np.lexsort((q[:, 1], q[:, 0]))]
        hull = []
        for half in (pts, pts[::-1]):
            h = []
            for t in half:
                while len(h) > 1 and (h[-1][0] - h[-2][0]) * (t[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (t[0] - h[-2][0]) <= 0:
                    h.pop()
                h.append(t)
            hull += h[:-1]
        i0, i1 = np.searchsorted(US, q[:, 0].min()), np.searchsorted(US, q[:, 0].max())
        j0, j1 = np.searchsorted(VS, q[:, 1].min()), np.searchsorted(VS, q[:, 1].max())
        if i1 <= i0 or j1 <= j0:
            continue
        X, Y = np.meshgrid(US[i0:i1], VS[j0:j1])
        m = np.ones(X.shape, bool)
        for (ax, ay), (bx, by) in zip(hull, hull[1:] + hull[:1]):
            m &= (bx - ax) * (Y - ay) - (by - ay) * (X - ax) >= -1e-6
        out[j0:j1, i0:i1] |= m
    return out


def end(c, last, over=None):
    m = np.isin(c["K"], SOLID)
    o = c["exit"] if last else np.zeros(3)
    return covered(c["P"][m], c["A"][m], c["S"][m], o, ch.basis(c["turn"] if last else 0.0), over)


def open_rows(wall):
    """rows across the joint with no wall at all on a side, at a rider's height: the share one sees straight out through"""
    return np.mean([~wall[:, US < -NECK + 6].any(1), ~wall[:, US > NECK - 6].any(1)])


def main(pkl):
    made, _ = pickle.load(open(pkl, "rb"))
    lib = [(k, h, c if h > 0 else ch.flip(c)) for k, c in enumerate(made) for h in (1, -1)]
    E, I = [end(c, True) for _, _, c in lib], [end(c, False) for _, _, c in lib]
    EW, IW = [end(c, True, EYE) for _, _, c in lib], [end(c, False, EYE) for _, _, c in lib]
    JW = covered(*ch.joint()[:3], np.zeros(3), ch.basis(0.0), EYE)
    J = covered(*ch.joint()[:3], np.zeros(3), ch.basis(0.0))
    lane = np.abs(US) < NECK - 6
    area, inside, after, natural, sight, sight2, natsight, where = [], 0, [], [], [], [], [], np.zeros((len(VS), len(US)))
    for a, (ka, ha, _) in enumerate(lib):
        for b, (kb, hb, _) in enumerate(lib):
            if ka == kb:
                continue
            hole = ~(E[a] | I[b])
            if ha == hb and made[ka]["land"] == made[kb]["land"] and kb == ka + 1 and ha == 1:
                natural.append(hole.sum() * CELL ** 2)
                natsight.append(open_rows(EW[a] | IW[b]))
            sight.append(open_rows(EW[a] | IW[b]))
            sight2.append(open_rows(EW[a] | IW[b] | JW))
            area.append(hole.sum() * CELL ** 2)
            inside += hole[:, lane].any()
            after.append((hole & ~J).sum() * CELL ** 2)
            where += hole
    area, after = np.array(area), np.array(after)
    print("joints", len(area), "| holes in the lane:", int(inside), "| beside it, square studs: median", np.median(area), "p90", np.percentile(area, 90), "max", area.max(),
          "| none at all:", round((area == 0).mean(), 3), "| 1,000 or more:", round((area >= 1000).mean(), 3))
    print("natural neighbours:", [float(n) for n in natural])
    print("open straight sideways at a rider's height, share of the rows: mean", round(float(np.mean(sight)), 4), "max", max(sight), "| joints with any:", round(float(np.mean(np.array(sight) > 0)), 3),
          "| natural", max(natsight), "| with the joint's boxes", max(sight2))
    u = np.where(where > 0)
    w = where / len(area)
    print("where: nearest hole to the middle", np.abs(US[u[1]]).min(), "| share of hole area within 100 studs of the neck's edge", round(w[:, np.abs(US) < NECK + 100].sum() / w.sum(), 3),
          "| within 24 studs of the cut", round(w[np.abs(VS) < 24].sum() / w.sum(), 3))
    print("with the joint's own boxes: median", np.median(after), "max", after.max(), "| holes left at", int((after > 0).sum()), "joints")


if __name__ == "__main__":
    main(sys.argv[1])
