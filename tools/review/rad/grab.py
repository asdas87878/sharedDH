import cv2, sys, numpy as np
src = sys.argv[1]; out = sys.argv[2]; times = [float(x) for x in sys.argv[3].split(",")]
crop = [int(x) for x in sys.argv[4].split(",")] if len(sys.argv) > 4 else None  # x0,y0,x1,y1 in 1280x720
cols = int(sys.argv[5]) if len(sys.argv) > 5 else 2
c = cv2.VideoCapture(src); fps = c.get(cv2.CAP_PROP_FPS)
tiles = []
for t in times:
    c.set(cv2.CAP_PROP_POS_FRAMES, round(t * fps)); ok, f = c.read()
    if crop: f = f[crop[1]:crop[3], crop[0]:crop[2]]
    cv2.putText(f, f"{t:.2f}", (8, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 0), 4); cv2.putText(f, f"{t:.2f}", (8, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    tiles.append(f)
rows = []
for i in range(0, len(tiles), cols):
    r = tiles[i:i + cols]
    while len(r) < cols: r.append(np.zeros_like(tiles[0]))
    rows.append(np.hstack(r))
cv2.imwrite(out, np.vstack(rows), [cv2.IMWRITE_JPEG_QUALITY, 88]); print(out)
