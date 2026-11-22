# Task 3: camera motion per hop, aligned on the jump, the in-air press and the landing (cycle.json + mot_<k>.npy).
import json, numpy as np, sys
FPS = 30.0
cyc = json.load(open("../data/cycle.json"))
def load(k):
    a = np.load(f"../data/mot_{k}.npy")
    return {round(r[0] * FPS): r for r in a}
def get(m, t):
    return m.get(round(t * FPS))
def prod(m, t0, t1):  # product of per-frame scales for frames in (t0, t1]
    v = [get(m, (i) / FPS) for i in range(round(t0 * FPS) + 1, round(t1 * FPS) + 1)]
    v = [r[1] for r in v if r is not None and np.isfinite(r[1])]
    return float(np.prod(v)) if v else float("nan"), len(v)
def series(m, t0, t1, col=1):
    return [(i / FPS, get(m, i / FPS)[col] if get(m, i / FPS) is not None else np.nan) for i in range(round(t0 * FPS), round(t1 * FPS) + 1)]
out = {}
for k in sys.argv[1:]:
    m = load(k); hops = cyc[k]["hops"]; rows = []
    for n, h in enumerate(hops):
        tj = h["jump"]; tl = h["land"]; tp = h["inair_presses"][0] if h["inair_presses"] else None
        r = {"hop": n + 1, "jump": tj, "press": tp, "land": tl}
        s0 = [get(m, tj + d / FPS) for d in range(-1, 4)]
        r["jump_s"] = [None if x is None else round(x[1], 3) for x in s0]
        r["jump_ty"] = [None if x is None else round(x[4], 1) for x in s0]
        r["jump_zoom_0.2"] = round(prod(m, tj - 1 / FPS, tj + 0.2)[0], 3)
        r["jump_zoom_0.5"] = round(prod(m, tj - 1 / FPS, tj + 0.5)[0], 3)
        if tp is not None:
            g0, g1 = tj + 0.3, tp - 1 / FPS
            if g1 > g0:
                z, nf = prod(m, g0, g1); r["glide_zoom"] = round(z, 3); r["glide_per_s"] = round(z ** (FPS / max(nf, 1)), 3)
            r["press_s"] = [None if get(m, tp + d / FPS) is None else round(get(m, tp + d / FPS)[1], 3) for d in range(0, 3)]
        if tl is not None:
            # the snap: smallest per-frame scale near the landing
            cand = [(d, get(m, tl + d / FPS)) for d in range(-1, 3)]
            cand = [(d, x[1]) for d, x in cand if x is not None]
            d, smin = min(cand, key=lambda z: z[1]); tsnap = tl + d / FPS
            r["snap_s"] = round(smin, 3); r["snap_frame_vs_land"] = d
            if tp is not None:
                z, nf = prod(m, tp, tsnap - 1 / FPS); r["pullin_zoom"] = round(z, 3)
                ss = series(m, tp + 1 / FPS, tsnap - 1 / FPS)
                fast = [t for t, s in ss if s > 1.02]
                r["pullin_fast_from"] = round(min(fast) - tsnap, 3) if fast else None
                r["pullin_max_s"] = round(max(s for t, s in ss), 3) if ss else None
            # settle: zoom over the next 0.5 / 1.0 s while still riding
            nxt = [x["jump"] for x in hops if x["jump"] > tl]; end = min(nxt) if nxt else tl + 1.0
            for w in (0.33, 0.5, 1.0):
                if tsnap + w <= end: r[f"settle_{w}"] = round(prod(m, tsnap, tsnap + w)[0], 3)
            r["ride_s_after"] = [round(get(m, tsnap + d / FPS)[1], 3) for d in range(1, 8) if get(m, tsnap + d / FPS) is not None and tsnap + d / FPS < end]
        rows.append(r)
    out[k] = rows
    for r in rows:
        print(k, json.dumps(r))
json.dump(out, open("../data/cam_hops.json", "w"), indent=1)
