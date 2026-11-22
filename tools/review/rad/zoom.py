import cv2, numpy as np, json, sys
path = sys.argv[1]; rows_file = sys.argv[2]
rows = json.load(open(rows_file))
# hops: a D run of at least 0.5 s ending in U
iv = []; cur = None
for t, s, u, d in rows:
    if cur is None or s != cur[0]:
        if cur: iv.append(cur)
        cur = [s, t, t]
    else:
        cur[2] = t
if cur: iv.append(cur)
hops = []
for k in range(len(iv) - 1):
    s, a, b = iv[k]
    if s == "D" and b - a >= 0.5 and iv[k + 1][0] == "U":
        hops.append((a, iv[k + 1][1]))  # press (first frame in the air), landing (first frame back on)
cap = cv2.VideoCapture(path); fps = cap.get(cv2.CAP_PROP_FPS)
W, H = 1280, 720
mask = np.zeros((H, W), np.uint8)
mask[90:620, 60:1040] = 255  # the play area, away from the top bar, the slots and the button
orb = cv2.ORB_create(1500)
bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
def frame(i):
    cap.set(cv2.CAP_PROP_POS_FRAMES, i); ok, f = cap.read(); return f
out = []
for (tp, tl) in hops:
    i0 = int(round((tl - 1.3) * fps)); i1 = int(round(tl * fps)) + 2
    scales = []
    prev = frame(i0); pg = cv2.cvtColor(prev, cv2.COLOR_BGR2GRAY); pk, pd = orb.detectAndCompute(pg, mask)
    for i in range(i0 + 1, i1 + 1):
        f = frame(i); g = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY); k, d = orb.detectAndCompute(g, mask)
        s = float("nan")
        if pd is not None and d is not None and len(pk) > 20 and len(k) > 20:
            m = bf.match(pd, d)
            if len(m) > 20:
                a = np.float32([pk[x.queryIdx].pt for x in m]); b = np.float32([k[x.trainIdx].pt for x in m])
                M, inl = cv2.estimateAffinePartial2D(a, b, method=cv2.RANSAC, ransacReprojThreshold=3)
                if M is not None:
                    s = float(np.sqrt(M[0, 0] ** 2 + M[0, 1] ** 2))
        scales.append((i / fps, s))
        pk, pd = k, d
    # the zoom-in before the landing: the run of frames growing over 2% that ends at the landing's snap
    land_i = int(round(tl * fps))
    seq = [(t, s) for t, s in scales if t <= tl + 0.001]
    start = None
    j = len(seq) - 1
    # step back over the landing frame's own snap (shrink) if it is in
    while j >= 0 and not (seq[j][1] == seq[j][1] and seq[j][1] > 1.02):
        j -= 1
    while j >= 0 and seq[j][1] == seq[j][1] and seq[j][1] > 1.015:
        start = seq[j][0]; j -= 1
    out.append({"press": round(tp, 3), "land": round(tl, 3), "air": round(tl - tp, 3),
                "zoomFrom": None if start is None else round(start - 1 / fps, 3),
                "scales": [(round(t, 3), round(s, 3)) for t, s in scales[-14:]]})
for o in out:
    zf = o["zoomFrom"]
    print(f"press {o['press']:.2f}  land {o['land']:.2f}  air {o['air']:.2f}  zoom from {zf if zf is None else round(zf,2)}  (press to zoom {None if zf is None else round(zf - o['press'], 2)}, zoom {None if zf is None else round(o['land'] - zf, 2)} s)")
    print("    ", " ".join(f"{s:.3f}" for t, s in o["scales"]))
json.dump(out, open(rows_file.replace("rows_", "zoom_"), "w"))
