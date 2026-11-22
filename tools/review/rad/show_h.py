import json, numpy as np, sys
FPS = 30.0
cyc = json.load(open("../data/cycle.json"))
k = sys.argv[1]; col = int(sys.argv[2]) if len(sys.argv) > 2 else 1
a = np.load(f"../data/moth_{k}.npy"); m = {round(r[0] * FPS): r for r in a}
d = np.load(f"../data/dup_{k}.npy"); dup = {round(r[0] * FPS) for r in d if r[1] < 0.6}
print(k, "col", col)
for n, h in enumerate(cyc[k]["hops"]):
    tj = h["jump"]; tl = h["land"]; tp = h["inair_presses"][0] if h["inair_presses"] else None
    def line(i0, i1):
        s = []
        for i in range(i0, i1 + 1):
            r = m.get(i)
            tag = ("J" if i == round(tj * FPS) else "") + ("P" if tp and i == round(tp * FPS) else "") + ("L" if tl and i == round(tl * FPS) else "") + ("*" if i in dup else "")
            v = r[col] if r is not None else np.nan
            s.append(f"{tag}{v:.3f}" if col in (1, 9) else f"{tag}{v:+.1f}")
        return " ".join(s)
    print(f"hop {n+1:2d} jump: " + line(round(tj * FPS) - 2, round(tj * FPS) + 9))
    if tp and tl: print(f"        press..land: " + line(round(tp * FPS) - 2, round(tl * FPS) + 9))
