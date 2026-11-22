# Frame-to-frame camera motion: corners tracked by pyramidal LK (forward-backward checked) on the world (static HUD
# masked out), then a similarity fit (RANSAC) in image-centred coordinates: scale s (zoom; >1 = the picture grows),
# roll (deg, + = picture turns counter-clockwise), tx / ty (px; + = the picture moves right / down).
# usage: python motion.py <video> <mask.png> <t0> <t1> <out.npy>
import cv2, numpy as np, sys, time
src, maskp, t0, t1, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
mask = (cv2.imread(maskp, 0) > 0).astype(np.uint8) * 255
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS)
c.set(cv2.CAP_PROP_POS_FRAMES, int(round(t0 * fps)))
i = int(round(t0 * fps)); n1 = int(round(t1 * fps))
ok, f = c.read(); prev = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY)
H, W = prev.shape; cx, cy = W / 2.0, H / 2.0
lk = dict(winSize=(21, 21), maxLevel=4, criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 30, 0.01))
rows = []
tt = time.time()
while i < n1:
    ok, f = c.read()
    if not ok: break
    g = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY)
    p0 = cv2.goodFeaturesToTrack(prev, maxCorners=900, qualityLevel=0.005, minDistance=12, mask=mask, blockSize=7)
    row = [(i + 1) / fps, np.nan, np.nan, np.nan, np.nan, 0, np.nan]
    if p0 is not None and len(p0) >= 25:
        p1, st, _ = cv2.calcOpticalFlowPyrLK(prev, g, p0, None, **lk)
        p0b, st2, _ = cv2.calcOpticalFlowPyrLK(g, prev, p1, None, **lk)
        fb = np.linalg.norm(p0 - p0b, axis=2).ravel()
        good = (st.ravel() == 1) & (st2.ravel() == 1) & (fb < 0.7)
        a = p0.reshape(-1, 2)[good] - (cx, cy); b = p1.reshape(-1, 2)[good] - (cx, cy)
        if len(a) >= 20:
            M, inl = cv2.estimateAffinePartial2D(a, b, method=cv2.RANSAC, ransacReprojThreshold=1.5, maxIters=3000, confidence=0.995)
            if M is not None:
                s = float(np.hypot(M[0, 0], M[1, 0])); th = float(np.degrees(np.arctan2(M[1, 0], M[0, 0])))
                m = inl.ravel() == 1
                res = (a[m] @ M[:, :2].T + M[:, 2]) - b[m]
                # image y points down: a positive atan2 here is a clockwise turn on screen; report + = counter-clockwise
                row = [(i + 1) / fps, s, -th, float(M[0, 2]), float(M[1, 2]), int(m.sum()), float(np.sqrt((res ** 2).sum(1).mean()))]
    rows.append(row)
    prev = g; i += 1
a = np.array(rows, np.float64); np.save(out, a)
print(out, a.shape, f"{time.time()-tt:.1f}s", "nan frames", int(np.isnan(a[:, 1]).sum()), "median inliers", float(np.nanmedian(a[:, 5])))
