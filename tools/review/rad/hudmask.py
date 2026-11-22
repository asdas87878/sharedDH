# Static-HUD mask: pixels that barely change between consecutive frames in most sampled pairs are HUD.
import cv2, numpy as np, sys
src, out, t0, t1 = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS)
ts = np.linspace(t0, t1, 160)
cnt = None
for t in ts:
    c.set(cv2.CAP_PROP_POS_FRAMES, round(t * fps)); ok, a = c.read(); ok2, b = c.read()
    if not (ok and ok2): continue
    d = cv2.absdiff(cv2.cvtColor(a, cv2.COLOR_BGR2GRAY), cv2.cvtColor(b, cv2.COLOR_BGR2GRAY))
    s = (d <= 2).astype(np.float32)
    cnt = s if cnt is None else cnt + s
frac = cnt / len(ts)
static = (frac > 0.7).astype(np.uint8)
static = cv2.dilate(static, np.ones((9, 9), np.uint8))
mask = np.zeros_like(static); mask[40:660, 20:1260] = 1
mask[static > 0] = 0
mask[495:590, 1080:1170] = 0  # the jump button (semi-transparent, changes look)
cv2.imwrite(out, mask * 255); print(out, "kept", round(mask.mean(), 3))
