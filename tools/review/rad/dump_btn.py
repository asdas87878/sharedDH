# Read every frame's jump-button region (x 1080-1170, y 490-590) into one .npy per video.
import cv2, numpy as np, sys, time
src, out = sys.argv[1], sys.argv[2]
X0, X1, Y0, Y1 = 1080, 1170, 490, 590
c = cv2.VideoCapture(src); n = int(c.get(cv2.CAP_PROP_FRAME_COUNT))
crops = []
t = time.time()
while True:
    ok, f = c.read()
    if not ok: break
    crops.append(f[Y0:Y1, X0:X1].copy())
a = np.stack(crops); np.save(out, a); print(out, a.shape, f"{time.time()-t:.1f}s", "frame count prop", n)
