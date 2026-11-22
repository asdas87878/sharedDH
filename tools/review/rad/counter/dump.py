# One sequential pass per video: the counter band (rows 44-72, cols 360-800) for every frame in each hop's window
# [jump - 1.5 s, land + 1.0 s], a frame-difference value (to find repeated frames), and full frames as JPEG
# from the throw - 0.35 s to the landing + 0.35 s.  Frame index i <-> time i/30 (same as cycle.json).
import cv2, numpy as np, json, sys, os, time
VID = {"1504": "D:/program files for me/videos/2026-11-10 15-04-48.mkv",
       "1639": "D:/program files for me/videos/2026-11-10 16-39-27.mkv",
       "0230": "D:/program files for me/videos/2026-11-09 02-30-32.mkv"}
REV = os.environ.get("RAD_REVIEW", "review")
OUT = REV + "/hook"
BY0, BY1, BX0, BX1 = 44, 72, 360, 800
key = sys.argv[1]
cyc = json.load(open(REV + "/rad/data/cycle.json"))[key]["hops"]
fps = 30.0
band_idx = set(); full_idx = set()
for h in cyc:
    if h["land"] is None: continue
    a = int(round((h["jump"] - 1.5) * fps)); b = int(round((h["land"] + 1.0) * fps))
    band_idx.update(range(max(a, 0), b + 1))
    pr = h["inair_presses"]
    t0 = (pr[0] if pr else h["land"] - 0.6) - 0.35
    a = int(round(t0 * fps)); b = int(round((h["land"] + 0.35) * fps))
    full_idx.update(range(a, b + 1))
last = max(band_idx | full_idx)
os.makedirs(f"{OUT}/crops/{key}", exist_ok=True)
c = cv2.VideoCapture(VID[key])
bands, idxs, diffs = [], [], []
prev = None; i = 0; t = time.time()
while i <= last:
    ok, f = c.read()
    if not ok: break
    if i in band_idx or i in full_idx or (i + 1) in band_idx:
        g = cv2.resize(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY), (320, 180), interpolation=cv2.INTER_AREA).astype(np.int16)
        d = float(np.abs(g - prev).mean()) if prev is not None else -1.0
        prev = g
        if i in band_idx:
            bands.append(f[BY0:BY1, BX0:BX1].copy()); idxs.append(i); diffs.append(d)
        if i in full_idx:
            cv2.imwrite(f"{OUT}/crops/{key}/f_{i:05d}.jpg", f, [cv2.IMWRITE_JPEG_QUALITY, 93])
    else:
        prev = None
    i += 1
np.save(f"{OUT}/data/band_{key}.npy", np.stack(bands))
np.save(f"{OUT}/data/band_{key}_idx.npy", np.array(idxs))
np.save(f"{OUT}/data/band_{key}_diff.npy", np.array(diffs))
print(key, len(bands), "band frames,", len(full_idx), "full frames,", f"{time.time()-t:.1f}s")
