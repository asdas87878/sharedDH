"""The saddle's standing pieces (cantle, pommel, trimmings) against the fish, for every design on every kind at every size
(run fit.py first; fit.py itself checks the panels only):

    python tools/saddles/clash.py [kind ...]       work/saddles/clash.json, art/saddles/adjust.json and a summary

A piece is swallowed when a quarter of it or more stands deeper than 0.1 in the fish; `still` at rest, `moving` at the
worst of four moments of the swim at 2.3 times its swing. A group (can: the cantle, pom: the pommel, trim: what lies on
the panels) fails when more than one of its pieces, or more than a tenth of them, is swallowed at rest, or more than a
quarter of them moving. Where a group fails, the design gets the first of these that passes on that kind and size, and
it is written to adjust.json: a cantle 0.85 or 0.7 as big, one without its middle (split), smaller ones of both, none; a
pommel 0.8 or 0.65 as big, none; without the trimmings of one panel (hem, low, flap), of two, without any."""
import json
import multiprocessing
import os
import sys

import numpy as np

import fish as F
import fit as X
import saddles as S

WORK = os.path.join(F.ROOT, "work", "saddles")
TRY = {"can": [{"can": 0.85}, {"can": 0.7}, {"can": 1.0, "split": True}, {"can": 0.8, "split": True}, {"can": 0.55}, {"can": 0.6, "split": True}, {"can": 0}],
       "pom": [{"pom": 0.8}, {"pom": 0.65}, {"pom": 0}],
       "trim": [{"hem": 0}, {"low": 0}, {"flap": 0}, {"hem": 0, "low": 0}, {"flap": 0, "hem": 0}, {"flap": 0, "low": 0}, {"flap": 0, "low": 0, "hem": 0}]}
GROUP = {"can": "can", "pom": "pom", "flap": "trim", "low": "trim", "hem": "trim"}


LO, HI, CELL = np.array([-3.6, -1.6, -3.4]), np.array([3.6, 4.4, 3.6]), 0.08


def solid(T):
    """which cells round the seat are inside the fish: looking along each axis both ways, the first face met is a back face,
    in 4 of the 6 ways or more (the models leave out faces nothing can see, so no one way is enough)"""
    n = np.ceil((HI - LO) / CELL - 1e-6).astype(int)
    mids = [LO[i] + (np.arange(n[i]) + 0.5) * CELL for i in range(3)]
    votes = np.zeros(n, int)
    N = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
    for d in range(3):
        p, q = [k for k in range(3) if k != d]
        key, sign = [], []
        at = np.all(T[:, :, [p, q]].max(1) >= LO[[p, q]], 1) & np.all(T[:, :, [p, q]].min(1) <= HI[[p, q]], 1) & (np.abs(N[:, d]) > 1e-7)
        for tri, nn in zip(T[at], N[at]):
            a, b, c = tri
            i0, i1 = np.searchsorted(mids[p], [tri[:, p].min(), tri[:, p].max()])
            j0, j1 = np.searchsorted(mids[q], [tri[:, q].min(), tri[:, q].max()])
            if i0 == i1 or j0 == j1:
                continue
            A, B = mids[p][i0:i1, None], mids[q][None, j0:j1]
            det = (b[q] - c[q]) * (a[p] - c[p]) + (c[p] - b[p]) * (a[q] - c[q])
            u = ((b[q] - c[q]) * (A - c[p]) + (c[p] - b[p]) * (B - c[q])) / det
            v = ((c[q] - a[q]) * (A - c[p]) + (a[p] - c[p]) * (B - c[q])) / det
            w = 1 - u - v
            hit = (u >= 0) & (v >= 0) & (w >= 0)
            if hit.any():
                ii, jj = np.nonzero(hit)
                key.append(((ii + i0) * n[q] + jj + j0) * 1000.0 + 500 + np.clip((u * a[d] + v * b[d] + w * c[d])[hit], -400, 400))
                sign.append(np.full(len(ii), np.sign(nn[d])))
        if not key:
            continue
        key, sign = np.concatenate(key), np.concatenate(sign)
        o = np.argsort(key)
        key, sign = key[o], sign[o]
        col = (np.arange(n[p])[:, None] * n[q] + np.arange(n[q])[None]) * 1000.0 + 500
        cells = col[:, :, None] + mids[d]
        k = np.searchsorted(key, cells)
        up, dn = np.minimum(k, len(key) - 1), np.maximum(k - 1, 0)
        same = lambda i: np.abs(key[i] - col[:, :, None]) < 450  # noqa: E731  (the same column)
        got = ((k < len(key)) & same(up) & (sign[up] > 0)).astype(int) + ((k > 0) & same(dn) & (sign[dn] < 0)).astype(int)
        votes += np.moveaxis(got, [0, 1, 2], [p, q, d])
    return votes >= 4


def inside(P, V):
    i = np.floor((P - LO) / CELL).astype(int)
    ok = np.all((i >= 0) & (i < V.shape), 1)
    out = np.zeros(len(P), bool)
    out[ok] = V[tuple(i[ok].T)]
    return out


G = np.linspace(-0.5, 0.5, 4)
CUBE = np.array([(x, y, z) for x in G for y in G for z in G if max(abs(x), abs(y), abs(z)) == 0.5])


def cores(parts):
    """each standing piece's points, a tenth of a stud in from its faces; and the piece and the group of each"""
    P, who, group = [], [], []
    for i, p in enumerate(parts):
        if p["what"] in GROUP:
            z = np.array(p["size"])
            P.append(CUBE * np.maximum(z - 0.2, z * 0.3) @ p["m"][:3, :3].T + p["m"][:3, 3])
            who += [len(group)] * len(CUBE)
            group.append(GROUP[p["what"]])
    return (np.concatenate(P) if P else np.zeros((0, 3))), np.array(who), group


def swallowed(parts, V):
    """for each group: (pieces, swallowed)"""
    P, who, group = cores(parts)
    if not len(P):
        return {}
    ins = inside(P, V)
    out = {}
    for g in set(group):
        ids = [i for i, q in enumerate(group) if q == g]
        out[g] = (len(ids), sum(ins[who == i].mean() >= 0.25 for i in ids))
    return out


def poses(f, fit, at, s):
    out = []
    for u in (None, 0.0, 0.25, 0.5, 0.75):
        pose = f.pose(u, 2.3, 0.0, s)
        T, _ = f.tris(s, pose)
        inv = np.linalg.inv(pose[fit["joint"]])
        T = T @ inv[:3, :3].T + inv[:3, 3] - at
        out.append(solid(T))
    return out


def measure(parts, PT, moving=True):
    out = {}
    for i, V in enumerate(PT if moving else PT[:1]):
        for g, (n, k) in swallowed(parts, V).items():
            r = out.setdefault(g, {"n": n, "still": 0, "moving": 0})
            r["still" if i == 0 else "moving"] = max(r["still" if i == 0 else "moving"], int(k))
    return out


def fails(r):
    return r["still"] > max(1, 0.1 * r["n"]) or r["moving"] > max(2, 0.25 * r["n"])


def one(id):
    f = F.load(id)
    res = json.load(open(os.path.join(WORK, "check.json")))[id]
    out, fix = {}, {}
    for tier in F.TIERS:
        fit = res[tier]["fit"]
        s = f.scale(tier)
        PT = poses(f, fit, f.seat * s, s)
        for key in S.DESIGNS:
            d = S.design(key)
            first = measure(S.build(d, fit, {}), PT)
            adj = {}
            for g in ("can", "pom", "trim"):
                if g in first and fails(first[g]):
                    for a in TRY[g]:
                        got = measure([p for p in S.build(d, fit, a) if GROUP.get(p["what"]) == g], PT)
                        if g not in got or not fails(got[g]):
                            break
                    adj.update(a)
            row = {"first": first}
            if adj:
                fix.setdefault(tier, {})[key] = adj
                row["after"] = measure(S.build(d, fit, adj), PT)
            out[f"{tier} {key}"] = row
    return id, out, fix


if __name__ == "__main__":
    which = sys.argv[1:] or F.ids()
    with multiprocessing.Pool(8) as pool:
        got = sorted(pool.imap_unordered(one, which))
    res, fix = {i: o for i, o, _ in got}, {i: x for i, _, x in got if x}
    json.dump(res, open(os.path.join(WORK, "clash.json"), "w"), default=float)
    if not sys.argv[1:]:
        rows = []
        for i, x in fix.items():
            rows.append(json.dumps(i) + ": {" + ", ".join(f"{json.dumps(t)}: {json.dumps(v)}" for t, v in x.items()) + "}")
        open(os.path.join(X.OUT, "adjust.json"), "w").write("{\n" + ",\n".join(rows) + "\n}\n")
    n = sum(len(v) for r in fix.values() for v in r.values())
    print("cases adjusted:", n, "of", sum(len(r) for r in res.values()))
    for g in ("can", "pom", "trim"):
        print(g, "failing:", sum(g in v["first"] and fails(v["first"][g]) for r in res.values() for v in r.values()),
              "after:", sum(g in v["after"] and fails(v["after"][g]) for r in res.values() for v in r.values() if "after" in v))
    for i in fix:
        for t, v in fix[i].items():
            print(i, t, " ".join(f"{k}{a}" for k, a in v.items()))
