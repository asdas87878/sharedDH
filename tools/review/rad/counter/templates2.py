# Build tight glyph templates (rows 55-62, exact width) from frames whose v1 read agrees with its neighbours.
import os
import numpy as np, json
from collections import defaultdict, Counter
from ocr2 import *
H = os.environ.get("RAD_REVIEW", "review") + "/hook"
b1504 = np.load(H + "/data/band_1504.npy"); i1504 = np.load(H + "/data/band_1504_idx.npy")
mt = m_template(grey(b1504[int(np.where(i1504 == 645)[0][0])]))
groups = defaultdict(list)
for key in ["1504", "1639", "0230"]:
    B = np.load(f"{H}/data/band_{key}.npy"); I = np.load(f"{H}/data/band_{key}_idx.npy")
    R = json.load(open(f"{H}/data/reads_{key}.json"))
    vals = [r["v"] for r in R]
    for k in range(len(B)):
        v = vals[k]
        if v is None: continue
        nb = [vals[j] for j in range(max(0, k - 3), min(len(vals), k + 4)) if j != k and vals[j] is not None and abs(int(I[j]) - int(I[k])) <= 3]
        if len(nb) < 4: continue
        med = float(np.median(nb))
        if abs(v - med) > 3 or len(str(v)) != len(str(int(med))): continue
        g = grey(B[k]); sc, mx, oy = find_m(g, mt)
        if sc < 0.8 or oy != 0: continue
        comma = find_comma(g, mx, oy)
        reg = region(g, mx, oy, comma)
        if reg is None: continue
        a, b = reg; t = TOP + oy
        ink = (g[t:t + 7].astype(int) >= INK).any(axis=0)
        if comma: ink[comma[0]:comma[1] + 1] = False
        segs = []; x = a
        while x <= b:
            if ink[x]:
                s = x
                while x <= b and ink[x]: x += 1
                segs.append((s, x - 1))
            else: x += 1
        s = str(v)
        if len(segs) != len(s) or min(e - b0 + 1 for b0, e in segs) < 3: continue
        if (v >= 1000) != (comma is not None): continue
        for (x0, x1), d in zip(segs, s):
            w = x1 - x0 + 1
            if w > 7: continue
            groups[(d, w)].append(g[t:t + 8, x0:x1 + 1].astype(np.float32))
T, TL, TW = [], [], []
for (d, w), L in sorted(groups.items()):
    if len(L) >= 12:
        T.append(np.mean(L, axis=0)); TL.append(d); TW.append(w)
    print(d, w, len(L))
import pickle; pickle.dump(T, open(H + "/data/t2.pkl", "wb"))
json.dump({"TL": TL, "TW": TW}, open(H + "/data/t2.json", "w"))
print(len(T), "templates")
