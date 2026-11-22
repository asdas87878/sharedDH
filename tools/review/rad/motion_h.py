# Frame-to-frame camera motion v2: LK corner tracks (HUD masked, forward-backward checked) -> a ground-plane homography
# (RANSAC). From H at a reference point (the screen centre, where the rider and the target sit) we read the local
# picture scale (sqrt det of the Jacobian: >1 = the picture grows there), the local shift (px) and local turn (deg).
# Also a similarity fit on the far band (top of the world area) for telling a zoom (everything scales) from a move
# (only the near ground scales).
# usage: python motion_h.py <video> <mask.png> <t0> <t1> <out.npy> [refx refy] [farY0 farY1]
import cv2, numpy as np, sys, time
src, maskp, t0, t1, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
RX, RY = (float(sys.argv[6]), float(sys.argv[7])) if len(sys.argv) > 7 else (640.0, 400.0)
FY0, FY1 = (int(sys.argv[8]), int(sys.argv[9])) if len(sys.argv) > 9 else (110, 300)
mask = (cv2.imread(maskp, 0) > 0).astype(np.uint8) * 255
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS)
c.set(cv2.CAP_PROP_POS_FRAMES, int(round(t0 * fps))); i = int(round(t0 * fps)); n1 = int(round(t1 * fps))
ok, f = c.read(); prev = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY)
lk = dict(winSize=(21, 21), maxLevel=4, criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 30, 0.01))
def jac(H, x, y):
    w = H[2, 0] * x + H[2, 1] * y + H[2, 2]
    u = (H[0, 0] * x + H[0, 1] * y + H[0, 2]) / w; v = (H[1, 0] * x + H[1, 1] * y + H[1, 2]) / w
    J = np.array([[(H[0, 0] - u * H[2, 0]) / w, (H[0, 1] - u * H[2, 1]) / w], [(H[1, 0] - v * H[2, 0]) / w, (H[1, 1] - v * H[2, 1]) / w]])
    return u, v, J
rows = []; tt = time.time()
while i < n1:
    ok, f = c.read()
    if not ok: break
    g = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY)
    row = [(i + 1) / fps] + [np.nan] * 10
    p0 = cv2.goodFeaturesToTrack(prev, maxCorners=1500, qualityLevel=0.003, minDistance=8, mask=mask, blockSize=7)
    if p0 is not None and len(p0) >= 30:
        p1, st, _ = cv2.calcOpticalFlowPyrLK(prev, g, p0, None, **lk)
        p0b, st2, _ = cv2.calcOpticalFlowPyrLK(g, prev, p1, None, **lk)
        fb = np.linalg.norm(p0 - p0b, axis=2).ravel()
        good = (st.ravel() == 1) & (st2.ravel() == 1) & (fb < 0.8)
        a = p0.reshape(-1, 2)[good]; b = p1.reshape(-1, 2)[good]
        if len(a) >= 30:
            H, inl = cv2.findHomography(a, b, cv2.RANSAC, 2.0, maxIters=4000, confidence=0.995)
            if H is not None:
                u, v, J = jac(H, RX, RY)
                sc = float(np.sqrt(abs(np.linalg.det(J)))); rot = float(np.degrees(np.arctan2(J[1, 0] - J[0, 1], J[0, 0] + J[1, 1])))
                m = inl.ravel() == 1
                pr = cv2.perspectiveTransform(a[m].reshape(-1, 1, 2), H).reshape(-1, 2); res = float(np.sqrt(((pr - b[m]) ** 2).sum(1).mean()))
                # median shift of all good tracks (a pan / tilt indicator)
                med = np.median(b - a, axis=0)
                # far band similarity
                fm = (a[:, 1] >= FY0) & (a[:, 1] <= FY1)
                fs = np.nan
                if fm.sum() >= 15:
                    M, finl = cv2.estimateAffinePartial2D(a[fm] - (640, 360), b[fm] - (640, 360), method=cv2.RANSAC, ransacReprojThreshold=1.5)
                    if M is not None and finl.sum() >= 10: fs = float(np.hypot(M[0, 0], M[1, 0]))
                row = [(i + 1) / fps, sc, -rot, u - RX, v - RY, int(m.sum()), res, float(med[0]), float(med[1]), fs, int(len(a))]
    rows.append(row); prev = g; i += 1
A = np.array(rows, np.float64); np.save(out, A)
print(out, A.shape, f"{time.time()-tt:.1f}s", "nan", int(np.isnan(A[:, 1]).sum()), "median inliers", float(np.nanmedian(A[:, 5])), "of", float(np.nanmedian(A[:, 10])))
