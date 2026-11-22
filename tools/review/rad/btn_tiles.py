# Crop the jump-button region at given times and tile them (scaled up) for checking by eye.
# usage: python btn_tiles.py <video> <out.jpg> <t,t,t...> [x0,y0,x1,y1] [scale] [cols]
import cv2, sys, numpy as np
src, out = sys.argv[1], sys.argv[2]
times = [float(x) for x in sys.argv[3].split(",")]
x0, y0, x1, y1 = [int(v) for v in sys.argv[4].split(",")] if len(sys.argv) > 4 else (1075, 485, 1175, 595)
sc = int(sys.argv[5]) if len(sys.argv) > 5 else 3
cols = int(sys.argv[6]) if len(sys.argv) > 6 else 8
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS)
tiles = []
for t in times:
    c.set(cv2.CAP_PROP_POS_FRAMES, round(t * fps)); ok, f = c.read()
    if not ok: f = np.zeros((720, 1280, 3), np.uint8)
    f = cv2.resize(f[y0:y1, x0:x1], None, fx=sc, fy=sc, interpolation=cv2.INTER_NEAREST)
    cv2.putText(f, f"{t:.2f}", (4, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 0, 0), 3)
    cv2.putText(f, f"{t:.2f}", (4, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)
    tiles.append(f)
rows = []
for i in range(0, len(tiles), cols):
    r = tiles[i:i + cols]
    while len(r) < cols: r.append(np.zeros_like(tiles[0]))
    rows.append(np.hstack(r))
cv2.imwrite(out, np.vstack(rows), [cv2.IMWRITE_JPEG_QUALITY, 90]); print(out, len(tiles))
