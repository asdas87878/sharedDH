# Counter reader v2.  Band = frame rows 44-72, cols 360-800.  Digits rows 55-61 (band 11-17), comma tail row 62 (band 18).
import numpy as np, cv2
TOP = 11; INK = 170

def grey(b): return cv2.cvtColor(b, cv2.COLOR_BGR2GRAY)

def m_template(g645): return g645[10:19, 147:160].astype(np.float32)

def find_m(g, mt, dy=2):
    r0 = 10 - dy; r1 = 19 + dy
    res = cv2.matchTemplate(g[r0:r1].astype(np.float32), mt, cv2.TM_CCOEFF_NORMED)
    y, x = np.unravel_index(np.argmax(res), res.shape)
    return float(res[y, x]), int(x + 2), int(y + r0 - 10)

def find_comma(g, mx, oy, thr=140, ext=100):
    t = TOP + oy
    row = g[t + 7].astype(int); up = g[t:t + 4].astype(int).max(axis=0)
    for x in range(mx - 33, mx - 12):
        if row[x] >= thr and up[x] < 150:
            s = x
            while row[s - 1] >= ext: s -= 1
            e = x
            while row[e + 1] >= ext: e += 1
            if e - s + 1 <= 4 and row[s - 2:s].max() < ext and row[e + 1:e + 3].max() < ext and up[s:e + 1].max() < 150:
                return (s, e)
    return None

def region(g, mx, oy, comma):
    t = TOP + oy
    ink = (g[t:t + 7].astype(int) >= INK).any(axis=0)
    if comma:
        ink[comma[0]:comma[1] + 1] = True
    # rightmost ink column within 7 px left of the 'm'
    b = None
    for x in range(mx - 2, mx - 9, -1):
        if ink[x]: b = x; break
    if b is None: return None
    x = b; gap = 0; a = b
    while x > mx - 55:
        x -= 1
        if ink[x]:
            a = x; gap = 0
        else:
            gap += 1
            if gap >= 3: break
    return a, b

def gapcost(col):
    return float((np.maximum(col.astype(np.float32) - 110.0, 0) ** 2).sum())

def parse(g, oy, a, b, n_allowed, T, TL, TW):
    """DP: explain columns a..b (incl.) as glyphs (template j at its width) and gap columns.
    Returns (cost, [(class, x0, w, j), ...]) with the glyph count in n_allowed."""
    t = TOP + oy
    P = g[t:t + 8].astype(np.float32)          # rows 55-62
    L = b - a + 1
    INF = 1e18
    nmax = max(n_allowed)
    f = np.full((nmax + 1, L + 1), INF); bp = {}
    f[0, 0] = 0.0
    gc = [gapcost(P[:, a + i]) for i in range(L)]
    # glyph costs
    gcost = {}
    for j in range(len(T)):
        w = TW[j]
        for i in range(0, L - w + 1):
            patch = P[:, a + i:a + i + w]
            gcost[(j, i)] = float(((patch - T[j]) ** 2).sum())
    for i in range(L):
        for k in range(nmax + 1):
            if f[k, i] >= INF: continue
            # gap
            c = f[k, i] + gc[i]
            if c < f[k, i + 1]: f[k, i + 1] = c; bp[(k, i + 1)] = (k, i, None)
            if k < nmax:
                for j in range(len(T)):
                    w = TW[j]
                    if i + w <= L:
                        c = f[k, i] + gcost[(j, i)]
                        if c < f[k + 1, i + w]: f[k + 1, i + w] = c; bp[(k + 1, i + w)] = (k, i, j)
    best = None
    for k in n_allowed:
        if f[k, L] < INF and (best is None or f[k, L] < best[0]): best = (f[k, L], k)
    if best is None: return None
    out = []; k, i = best[1], L
    while i > 0:
        pk, pi, j = bp[(k, i)]
        if j is not None: out.append((TL[j], a + pi, TW[j], j))
        k, i = pk, pi
    return best[0], out[::-1]

def read_frame(g, mt, T, TL, TW):
    sc, mx, oy = find_m(g, mt)
    if sc < 0.6: return {"err": "no m", "m": round(sc, 2)}
    comma = find_comma(g, mx, oy)
    reg = region(g, mx, oy, comma)
    if reg is None: return {"err": "no ink", "m": round(sc, 2)}
    a, b = reg
    if comma:
        if not (a < comma[0] and comma[1] < b): return {"err": "comma outside", "m": round(sc, 2)}
        left = parse(g, oy, a, comma[0] - 1, [1, 2], T, TL, TW)
        right = parse(g, oy, comma[1] + 1, b, [3], T, TL, TW)
        if left is None or right is None: return {"err": "no parse", "m": round(sc, 2)}
        cost = left[0] + right[0]; gl = left[1] + right[1]
        ncols = b - a + 1 - (comma[1] - comma[0] + 1)
    else:
        r = parse(g, oy, a, b, [1, 2, 3], T, TL, TW)
        if r is None: return {"err": "no parse", "m": round(sc, 2)}
        cost, gl = r; ncols = b - a + 1
    s = "".join(c for c, _, _, _ in gl)
    return {"v": int(s), "s": s, "cost": round(cost / ncols / 8, 1), "m": round(sc, 2), "mx": mx, "a": int(a), "b": int(b),
            "comma": list(comma) if comma else None, "gl": [(c, int(x), int(w), int(j)) for c, x, w, j in gl]}
