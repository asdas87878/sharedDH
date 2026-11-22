# Repeated frames: mean absolute difference to the previous frame over the world area (HUD masked) ~0 means the
# game showed no new picture for that recorded frame (a hitch or a deliberate freeze).
import cv2, numpy as np, sys
src, maskp, out = sys.argv[1], sys.argv[2], sys.argv[3]
t0 = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0; t1 = float(sys.argv[5]) if len(sys.argv) > 5 else 1e9
mask = cv2.imread(maskp, 0) > 0
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS)
c.set(cv2.CAP_PROP_POS_FRAMES, int(round(t0 * fps))); i = int(round(t0 * fps))
ok, f = c.read(); prev = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY).astype(np.int16)
rows = []
while i / fps < t1:
    ok, f = c.read()
    if not ok: break
    g = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY).astype(np.int16); i += 1
    d = np.abs(g - prev)[mask]
    rows.append((i / fps, float(d.mean()), float(np.percentile(d, 99))))
    prev = g
a = np.array(rows); np.save(out, a)
dup = a[a[:, 1] < 0.6]
print(out, len(a), "frames; repeated:", len(dup)); print(" ".join(f"{t:.3f}({m:.2f})" for t, m, p in dup))
