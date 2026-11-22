import cv2, sys, numpy as np
src, t0, t1, step, out = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
cols = int(sys.argv[6]) if len(sys.argv) > 6 else 5
w = int(sys.argv[7]) if len(sys.argv) > 7 else 384
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS)
tiles = []
t = t0
while t <= t1 + 1e-6:
    c.set(cv2.CAP_PROP_POS_FRAMES, round(t * fps)); ok, f = c.read()
    if not ok: break
    h = int(f.shape[0] * w / f.shape[1]); f = cv2.resize(f, (w, h), interpolation=cv2.INTER_AREA)
    cv2.putText(f, f"{t:.2f}", (6, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 3); cv2.putText(f, f"{t:.2f}", (6, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
    tiles.append(f); t += step
rows = []
for i in range(0, len(tiles), cols):
    r = tiles[i:i + cols]
    while len(r) < cols: r.append(np.zeros_like(tiles[0]))
    rows.append(np.hstack(r))
cv2.imwrite(out, np.vstack(rows), [cv2.IMWRITE_JPEG_QUALITY, 85]); print(out, len(tiles))
