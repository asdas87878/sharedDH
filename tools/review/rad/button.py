import cv2, numpy as np, sys, json
REF = r"D:/program files for me/videos/2026-11-10 15-04-48.mkv"
X0, X1, Y0, Y1 = 1095, 1155, 505, 575

def feat(frame):
    g = cv2.cvtColor(frame[Y0:Y1, X0:X1], cv2.COLOR_BGR2GRAY).astype(np.float32)
    gx = cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3); gy = cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3)
    m = np.sqrt(gx * gx + gy * gy)
    m -= m.mean(); n = np.linalg.norm(m)
    return m / n if n > 1e-6 else m

def frame_at(cap, t, fps):
    cap.set(cv2.CAP_PROP_POS_FRAMES, round(t * fps)); ok, f = cap.read(); return f

c = cv2.VideoCapture(REF); fps = c.get(cv2.CAP_PROP_FPS)
UP = feat(frame_at(c, 3.0, fps)); DOWN = feat(frame_at(c, 6.0, fps))

def run(path, t0=0.0, t1=None):
    cap = cv2.VideoCapture(path); fps = cap.get(cv2.CAP_PROP_FPS); n = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    start = int(t0 * fps); end = n if t1 is None else min(n, int(t1 * fps))
    cap.set(cv2.CAP_PROP_POS_FRAMES, start)
    rows = []
    for i in range(start, end):
        ok, f = cap.read()
        if not ok: break
        q = feat(f)
        u, d = float((q * UP).sum()), float((q * DOWN).sum())
        s = "U" if u > d + 0.05 and u > 0.25 else ("D" if d > u + 0.05 and d > 0.25 else "?")
        rows.append((i / fps, s, u, d))
    return rows

def intervals(rows):
    out = []; cur = None
    for t, s, u, d in rows:
        if cur is None or s != cur[0]:
            if cur: out.append(cur)
            cur = [s, t, t]
        else:
            cur[2] = t
    if cur: out.append(cur)
    return out

if __name__ == "__main__":
    path = sys.argv[1]; t0 = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0; t1 = float(sys.argv[3]) if len(sys.argv) > 3 else None
    rows = run(path, t0, t1)
    iv = intervals(rows)
    # print states, merging very short unknown flickers for reading
    print(" ".join(f"{s}{a:.2f}-{b:.2f}" for s, a, b in iv))
    json.dump(rows, open(sys.argv[4] if len(sys.argv) > 4 else "rows.json", "w"))
