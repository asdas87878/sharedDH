"""The rider's part of the fit check, for every design on every kind at every size (run fit.py first; about 8 minutes):

    python tools/saddles/rider.py [kind ...]       work/saddles/rider.json and a summary

clear   how deep the saddle goes into the rider's torso, head and arms, studs: the worst of the riding pose and of leaning
        20 degrees further either way; `rest` is the riding pose alone. The legs lie on the blanket and are left out.
cushion how deep the cushion goes into the hips
seen    the share of the rider's torso, arms and head the chase camera still sees past the saddle (17 studs behind, 12 degrees up)
float   the share of the pommel's or cantle's underside that stands on neither the pad nor the fish (1 stud down);
        over: how far past the pad's edge such a piece reaches, studs"""
import json
import multiprocessing
import os
import sys

import numpy as np

import fish as F
import fit as X
import saddles as S

WORK = os.path.join(F.ROOT, "work", "saddles")


def points(size, m, n=5):
    g = np.linspace(-0.5, 0.5, n)
    P = np.array([(x, y, z) for x in g for y in g for z in g if max(abs(x), abs(y), abs(z)) == 0.5]) * size
    return P @ m[:3, :3].T + m[:3, 3]


def depth(P, size, m):
    """how deep points are inside a box (0: outside)"""
    q = (P - m[:3, 3]) @ m[:3, :3]
    d = (np.array(size) / 2 - np.abs(q)).min(1)
    return float(max(0, d.max()))


def body(lean):
    out = []
    pivot = F.move(0, X.SEAT_TOP + 0.2, 0) @ F.rot(lean, 0, 0) @ F.move(0, -X.SEAT_TOP - 0.2, 0)
    for name, size, m, kind in F.rider():
        if "Leg" in name or "Foot" in name:
            continue
        out.append((name, np.array(size), (m if name == "LowerTorso" else pivot @ m)))
    return out


BODY = {a: body(a) for a in (-20, 0, 20)}
EYE = np.array([0, 1.4 + 1.5 + 17 * np.sin(np.radians(12)), 17 * np.cos(np.radians(12))])


def box_tris(size, m):
    v = np.array([(x, y, z) for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)]) * size
    v = v @ m[:3, :3].T + m[:3, 3]
    return v[[(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]]


def seen(parts):
    T = np.concatenate([box_tris(p["size"], p["m"]) for p in parts])
    tot = hid = 0
    for name, size, m in BODY[0]:
        P = points(size, m, 5)
        P = P[P[:, 2] >= m[2, 3] - 0.01]  # (the side the camera sees)
        for p in P:
            d = EYE - p
            L = np.linalg.norm(d)
            t = X.hits(p[None] + d / L * 0.02, d / L, T, L)[0]
            tot += 1
            hid += np.isfinite(t)
    return 1 - hid / tot


def one(id):
    f = F.load(id)
    out = {}
    res = json.load(open(os.path.join(WORK, "check.json")))[id]
    for tier in F.TIERS:
        fit = res[tier]["fit"]
        s = f.scale(tier)
        at = f.seat * s
        T, who = f.tris(s)
        T = T - at
        near = np.all(T.max(1) > [-6, -3, -6], 1) & np.all(T.min(1) < [6, 7, 6], 1)
        T = T[near]
        for key in S.DESIGNS:
            parts = S.build(S.design(key), fit)
            clear = cush = rest = 0.0
            for lean, boxes in BODY.items():
                for p in parts:
                    P = points(np.array(p["size"]), p["m"], 4)
                    for name, size, m in boxes:
                        if name in ("LeftHand", "LeftLowerArm") and p["what"] == "pom":
                            continue  # (the hand on the horn)
                        a = depth(P, size, m)
                        if p["what"] in ("cushion", "pad"):
                            cush = max(cush, a if lean == 0 else 0)
                        else:
                            clear = max(clear, a)
                            if lean == 0:
                                rest = max(rest, a)
            # a pommel or cantle on nothing: the lowest of its parts stands off the fish
            fl = over = 0.0
            for what in ("pom", "can"):
                q = [p for p in parts if p["what"] == what]
                if q:
                    P = np.concatenate([points(np.array(p["size"]), p["m"], 3) for p in q[:2]])
                    low = P[P[:, 1] < P[:, 1].min() + 0.1]
                    base = [p for p in parts if p["what"] in ("pad", "shelf")]
                    # (on the pad, or on the fish)
                    on = np.zeros(len(low), bool)
                    for b in base:
                        qz = (low - b["m"][:3, 3]) @ b["m"][:3, :3]
                        on |= (np.abs(qz[:, 0]) < b["size"][0] / 2 + 0.2) & (np.abs(qz[:, 2]) < b["size"][2] / 2 + 0.35)
                    d = X.hits(low + [0, 0.6, 0], np.array([0, -1.0, 0]), T, 1.6)
                    on |= np.isfinite(d)
                    fl = max(fl, float(1 - on.mean()))
                    if not on.all():
                        over = max(over, float((np.abs(low[~on][:, 0]) - fit["half"]).max()))
            row = {"clear": clear, "rest": rest, "cushion": cush, "float": fl, "over": over, "parts": len(parts), "tris": S.count(parts)[1]}
            if tier in ("Tiny", "Normal", "Colossal"):
                row["seen"] = seen([p for p in parts if p["what"] in ("can", "flap", "trim")])
            out[f"{tier} {key}"] = row
    return id, out


if __name__ == "__main__":
    with multiprocessing.Pool(8) as pool:
        res = dict(pool.imap_unordered(one, sys.argv[1:] or F.ids()))
    json.dump(res, open(os.path.join(WORK, "rider.json"), "w"), default=float)
    print("design  clear(max)  cushion  seen(min/mean)  float(max share)  parts min-max  triangles max")
    for key in S.DESIGNS:
        r = [v for id in res for k, v in res[id].items() if k.split(" ")[1] == key]
        worst = max(((v["clear"], id, k) for id in res for k, v in res[id].items() if k.split(" ")[1] == key))
        sn = [v["seen"] for v in r if "seen" in v]
        print(f"{key:4} {S.DESIGNS[key][0]:16} {worst[0]:.2f} ({worst[1]} {worst[2]}) rest {max(v['rest'] for v in r):.2f} {max(v['cushion'] for v in r):.2f}  {min(sn):.2f}/{np.mean(sn):.2f}  {max(v['float'] for v in r):.2f} over {max(v['over'] for v in r):.2f}  {min(v['parts'] for v in r)}-{max(v['parts'] for v in r)} {max(v['tris'] for v in r)}")
