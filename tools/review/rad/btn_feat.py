# Shared feature for the jump button: grey arrow area, minus a blurred copy (drops smooth background), unit norm.
import numpy as np, cv2
AX0, AX1, AY0, AY1 = 20, 70, 24, 76   # arrow area inside the dumped crop (crop origin x 1080, y 490)
def feats(crops, sigma=5.0):
    out = np.empty((len(crops), AY1 - AY0, AX1 - AX0), np.float32)
    for i, c in enumerate(crops):
        g = cv2.cvtColor(c, cv2.COLOR_BGR2GRAY).astype(np.float32)
        hp = g - cv2.GaussianBlur(g, (0, 0), sigma)
        f = hp[AY0:AY1, AX0:AX1]
        f = f - f.mean(); n = np.linalg.norm(f)
        out[i] = f / n if n > 1e-6 else f
    return out
def unit(t):
    t = t - t.mean(); return t / (np.linalg.norm(t) + 1e-9)
