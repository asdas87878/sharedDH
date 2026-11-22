# The rider's on-screen size and position: the avatar's blue shirt (HSV hue 90-104, sat >140, val >130), largest blob
# in a central window. sqrt(area) tracks the camera framing (distance / field of view) while the pose holds.
# usage: python rider_size.py <video> <out.npy> <x0,y0,x1,y1 window> [t0 t1]
import cv2, numpy as np, sys
src, out = sys.argv[1], sys.argv[2]; x0, y0, x1, y1 = [int(v) for v in sys.argv[3].split(",")]
t0 = float(sys.argv[4]) if len(sys.argv) > 4 else 0; t1 = float(sys.argv[5]) if len(sys.argv) > 5 else 1e9
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS); c.set(cv2.CAP_PROP_POS_FRAMES, int(round(t0 * fps))); i = int(round(t0 * fps))
rows = []
cx0, cy0 = (x0 + x1) / 2, (y0 + y1) / 2
while i / fps <= t1:
    ok, f = c.read()
    if not ok: break
    hsv = cv2.cvtColor(f[y0:y1, x0:x1], cv2.COLOR_BGR2HSV)
    m = cv2.inRange(hsv, (90, 140, 130), (104, 255, 255))
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    n, lab, st, cen = cv2.connectedComponentsWithStats(m)
    best = None
    for j in range(1, n):
        a = st[j, cv2.CC_STAT_AREA]
        if a < 25: continue
        d = np.hypot(cen[j][0] + x0 - cx0, cen[j][1] + y0 - cy0)
        score = a - 0.5 * d
        if best is None or score > best[0]: best = (score, j)
    if best:
        j = best[1]; rows.append((i / fps, st[j, cv2.CC_STAT_AREA], cen[j][0] + x0, cen[j][1] + y0, st[j, cv2.CC_STAT_HEIGHT], st[j, cv2.CC_STAT_WIDTH]))
    else:
        rows.append((i / fps, 0, np.nan, np.nan, 0, 0))
    i += 1
a = np.array(rows, float); np.save(out, a); print(out, a.shape, "frames with a blob", int((a[:, 1] > 0).sum()))
