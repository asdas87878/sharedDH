# Motion statistics per phase: median per-frame shift (px) and jitter (RMS of the shift minus a 5-frame moving
# average), image turn (deg/frame), from moth_<k>.npy and cycle.json.
import json, numpy as np
FPS = 30.0
cyc = json.load(open("../data/cycle.json"))
def ma(x, n=5):
    k = np.ones(n) / n; xp = np.pad(x, (n // 2, n // 2), mode="edge"); return np.convolve(xp, k, mode="valid")
for k in ["1504", "1639"]:
    a = np.load(f"../data/moth_{k}.npy"); t = a[:, 0]
    hp = {}
    for col, nm in [(7, "dx"), (8, "dy"), (2, "turn")]:
        x = a[:, col].copy(); x[~np.isfinite(x)] = 0; hp[nm] = (x, x - ma(x))
    phases = {"ride": [], "jump0.3": [], "glide": [], "pullin": [], "land0.3": []}
    hops = cyc[k]["hops"]
    for n, h in enumerate(hops):
        tj, tl = h["jump"], h["land"]; tp = h["inair_presses"][0] if h["inair_presses"] else None
        if n > 0 and hops[n - 1]["land"]: phases["ride"].append((hops[n - 1]["land"] + 0.3, tj - 0.01))
        phases["jump0.3"].append((tj, tj + 0.3))
        if tp: phases["glide"].append((tj + 0.3, tp - 0.01))
        if tp and tl: phases["pullin"].append((tp, tl - 0.01))
        if tl: phases["land0.3"].append((tl, tl + 0.3)); phases.setdefault("postland", []).append((tl + 0.1, tl + 0.4))
    print("=====", k)
    for ph, wins in phases.items():
        sel = np.zeros(len(t), bool)
        for w0, w1 in wins: sel |= (t >= w0) & (t <= w1)
        if sel.sum() < 3: print(f"  {ph:8s} n/a"); continue
        out = [f"  {ph:8s} frames {sel.sum():4d}"]
        for nm in ["dx", "dy", "turn"]:
            x, r = hp[nm]
            out.append(f"{nm}: med {np.median(x[sel]):+6.2f} |med| {np.median(np.abs(x[sel])):5.2f} jit {np.sqrt(np.mean(r[sel] ** 2)):5.2f}")
        print("  ".join(out))
