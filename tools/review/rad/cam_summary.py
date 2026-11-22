# Task 3 summary: one-frame camera events relative to their neighbours, the pull-in's extra growth and the
# post-landing recovery, from moth_<k>.npy (homography at the screen centre: col 1; far band similarity: col 9;
# median track shift: cols 7, 8 (px, + = right / down)).
import json, numpy as np
FPS = 30.0
cyc = json.load(open("../data/cycle.json"))
def M(k):
    a = np.load(f"../data/moth_{k}.npy"); return {round(r[0] * FPS): r for r in a}
def v(m, i, col):
    r = m.get(i); return r[col] if r is not None and np.isfinite(r[col]) else np.nan
def med(m, idx, col):
    x = [v(m, i, col) for i in idx]; x = [y for y in x if np.isfinite(y)]; return float(np.median(x)) if x else np.nan
res = {}
for k in ["1504", "1639"]:
    m = M(k); hops = cyc[k]["hops"]; rows = []
    for n, h in enumerate(hops):
        J = round(h["jump"] * FPS); r = {"hop": n + 1}
        prev_land = hops[n - 1]["land"] if n > 0 else None
        r["ride_before"] = None if prev_land is None else round(h["jump"] - prev_land, 2)
        for col, nm in [(1, "c"), (9, "f")]:
            r[f"jump_rel_{nm}"] = round(v(m, J, col) / med(m, range(J - 3, J), col), 3)
            r[f"jump_next_{nm}"] = round(v(m, J + 1, col) / med(m, range(J - 3, J), col), 3)
        r["jump_dy_3f"] = round(sum(v(m, i, 8) for i in range(J, J + 3)), 1); r["jump_dx_3f"] = round(sum(v(m, i, 7) for i in range(J, J + 3)), 1)
        r["ride_dy_before"] = round(med(m, range(J - 6, J), 8), 1)
        if h["inair_presses"] and h["land"]:
            P = round(h["inair_presses"][0] * FPS); L = round(h["land"] * FPS)
            for col, nm in [(1, "c"), (9, "f")]:
                base = med(m, range(P - 6, P), col)
                r[f"press_rel_{nm}"] = round(v(m, P, col) / base, 3)
                # snap: the smallest scale at L-1..L+2
                cand = [(i, v(m, i, col)) for i in range(L - 1, L + 3) if np.isfinite(v(m, i, col))]
                if not cand: continue
                S, sv = min(cand, key=lambda z: z[1])
                after = med(m, range(S + 1, S + 4), col)
                r[f"snap_{nm}"] = round(sv, 3); r[f"snap_rel_{nm}"] = round(sv / after, 3); r[f"snap_at_{nm}"] = S - L
                # pull-in: extra growth over the glide baseline, from the press frame (inclusive) to the frame before the snap
                xs = [v(m, i, col) for i in range(P, S)]
                r[f"pullin_extra_{nm}"] = round(float(np.prod([x / base for x in xs if np.isfinite(x)])), 3)
                r[f"pullin_frames"] = S - P
                if nm == "c":
                    r["pullin_profile_c"] = [round(v(m, i, 1) / base, 3) for i in range(S - 10, S)]
            # vertical / sideways shift at the snap
            r["snap_dy"] = round(v(m, L, 8) + v(m, L + 1, 8), 1); r["snap_dx"] = round(v(m, L, 7) + v(m, L + 1, 7), 1)
        rows.append(r)
    res[k] = rows
json.dump(res, open("../data/cam_summary.json", "w"), indent=1)
for k, rows in res.items():
    print("=====", k)
    for r in rows: print({x: y for x, y in r.items() if x != "pullin_profile_c"})
    def col(name, filt=None):
        x = [r[name] for r in rows if name in r and r[name] is not None and np.isfinite(r[name]) and (filt is None or filt(r))]
        return np.array(x)
    for name in ["press_rel_c", "press_rel_f", "snap_c", "snap_f", "snap_rel_c", "snap_rel_f", "pullin_extra_c", "pullin_extra_f", "pullin_frames", "snap_dy", "jump_dy_3f"]:
        x = col(name)
        if len(x): print(f"  {name:16s} n={len(x):2d} median {np.median(x):.3f}  range {x.min():.3f} .. {x.max():.3f}")
    for lab, f in [("after rides <=0.37 s", lambda r: r["ride_before"] is not None and r["ride_before"] <= 0.37), ("after rides >0.37 s", lambda r: r["ride_before"] is None or r["ride_before"] > 0.37)]:
        for name in ["jump_rel_c", "jump_rel_f", "jump_next_c"]:
            x = col(name, f)
            if len(x): print(f"  {name} {lab:22s} n={len(x):2d} median {np.median(x):.3f} range {x.min():.3f} .. {x.max():.3f}")
    prof = np.array([r["pullin_profile_c"] for r in rows if "pullin_profile_c" in r and len(r["pullin_profile_c"]) == 10])
    print("  pull-in profile (extra per-frame growth vs glide, frames -10..-1 before the snap): median", np.round(np.nanmedian(prof, axis=0), 3))
