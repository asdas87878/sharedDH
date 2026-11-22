import os
import numpy as np, json, pickle, sys, time
from collections import Counter
from ocr2 import *
H = os.environ.get("RAD_REVIEW", "review") + "/hook"
b1504 = np.load(H + "/data/band_1504.npy"); i1504 = np.load(H + "/data/band_1504_idx.npy")
mt = m_template(grey(b1504[int(np.where(i1504 == 645)[0][0])]))
T = pickle.load(open(H + "/data/t2.pkl", "rb")); m = json.load(open(H + "/data/t2.json")); TL, TW = m["TL"], m["TW"]
for key in sys.argv[1:]:
    t0 = time.time()
    B = np.load(f"{H}/data/band_{key}.npy"); I = np.load(f"{H}/data/band_{key}_idx.npy")
    out = []
    for k in range(len(B)):
        r = read_frame(grey(B[k]), mt, T, TL, TW); r["i"] = int(I[k]); out.append(r)
    json.dump(out, open(f"{H}/data/reads2_{key}.json", "w"))
    old = json.load(open(f"{H}/data/reads_{key}.json"))
    diff = [(o["i"], o["v"], n.get("v")) for o, n in zip(old, out) if o["v"] != n.get("v")]
    print(key, len(out), "frames", f"{time.time()-t0:.1f}s", "errors", Counter(r.get("err") for r in out if "err" in r), "cost p50/p95/max",
          np.percentile([r["cost"] for r in out if "cost" in r], [50, 95, 100]).round(1), "changed vs v1:", len(diff))
    print("  ", diff[:60])
