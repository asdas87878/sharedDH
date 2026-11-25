"""The endless study's pictures, drawn from the real boxes (numpy and Pillow only; no Blender, no Studio).

  python tools/endless/draw.py <chunks.pkl> <out folder>

top and side of three seeds (the spiral), a straight stack beside it, an unrolled strip of six chunks, and what a rider
sees at a joint: the purpose-made one, and one cut straight from today's lands."""
import json
import math
import os
import pickle
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import chunks as ch
import stack as st

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "map"))
import water_zones as wz  # noqa: E402

PAL = json.load(open(os.path.join(ROOT, "art/map/palettes/proposal.json")))["lands"]
GROUND = [np.array([int(v) for v in (l["floor"] if not isinstance(l["floor"], str) else [int(l["floor"].lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)])]) for l in PAL]
FACE = [np.array([int(v) for v in (l["face"] if not isinstance(l["face"], str) else [int(l["face"].lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)])]) for l in PAL]
WATER = [np.array(z["water"]) for z in wz.ZONES]
GLOW = [np.array(z["glow"] or (235, 235, 220)) for z in wz.ZONES]
F = lambda n, b=True: ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)  # noqa: E731
START, H0 = (2989.0, -2227.0, 23100.0), 0.0


def paint(c, look):
    """the chunk's colours, painted as another land: walls, floor and ledges by their part in the map; props keep theirs"""
    if look is None:
        return c["C"].astype(float)
    C, li = c["C"].astype(float).copy(), c["land"]
    for name in ("face", "core", "grass", "ground", "trim"):
        m = c["K"] == ch.KINDS.index(name)
        dg, df = np.abs(C[m] - GROUND[li]).sum(1), np.abs(C[m] - FACE[li]).sum(1)
        near = np.minimum(dg, df) < 260
        new = np.where((dg <= df)[:, None], C[m] - GROUND[li] + GROUND[look], C[m] - FACE[li] + FACE[look])
        C[m] = np.where(near[:, None], new, C[m])
    m = c["K"] == ch.KINDS.index("glow")
    C[m] = GLOW[look]
    return np.clip(C, 0, 255)


def boxes(shapes, run, repaint=True, skip=("barrier", "setsmoke")):
    P, A, S, C, K, I = [], [], [], [], [], []
    bad = [ch.KINDS.index(k) for k in skip]
    for p in run:
        c = shapes[p["shape"]]
        m = ~np.isin(c["K"], bad)
        B, hand = ch.basis(p["h"]), np.array([p["hand"], 1, 1])
        P.append(p["at"] + (c["P"][m] * hand) @ B)
        A.append((c["A"][m] * hand) @ B)
        S.append(c["S"][m])
        C.append(paint(c, p["look"] if repaint else None)[m])
        K.append(c["K"][m])
        I.append(np.full(m.sum(), p["i"]))
    return [np.concatenate(v) for v in (P, A, S, C, K, I)]


def corners(P, A, S):
    sg = np.array([[x, y, z] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float) / 2
    return P[:, None] + np.einsum("ck,nk,nkj->ncj", sg, S, A)


FACES8 = [((1, 3, 7, 5), 2, 1), ((0, 4, 6, 2), 2, -1), ((4, 5, 7, 6), 0, 1), ((0, 2, 3, 1), 0, -1), ((2, 6, 7, 3), 1, 1), ((0, 1, 5, 4), 1, -1)]


def raster(bx, eye, look, size=(1280, 720), fov=70.0, water=(120, 130, 190), see=1200.0, thick=1.0, tint=(255, 255, 255), far=2400.0):
    """a small painter: every box's faces toward the eye, a depth buffer, flat light, the map's 8-stud squares, fog"""
    W, H = size
    P, A, S, C, K, _ = bx
    f = np.array(look, float) - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    R = np.stack([r, u, f])
    fl = W / 2 / math.tan(math.radians(fov) / 2)
    dist = (P - eye) @ f
    rad = np.linalg.norm(S, axis=1) / 2
    side = np.hypot((P - eye) @ r, (P - eye) @ u)
    ok = (dist > -rad) & (dist < far) & (side - rad < np.abs(dist + rad) * 1.1 + 40)
    P, A, S, C, K = P[ok], A[ok], S[ok], C[ok], K[ok]
    order = np.argsort(np.linalg.norm(P - eye, axis=1))
    V = corners(P, A, S)
    cam = (V - eye) @ R.T
    zb = np.full((H, W), 1e9, np.float32)
    img = np.zeros((H, W, 3), np.float32)
    img[:] = water
    sun = np.array([0.35, 0.86, -0.36])
    sun /= np.linalg.norm(sun)
    glowk = [ch.KINDS.index("glow"), ch.KINDS.index("setglow")]
    for n in order:
        for idx, ax, sgn in FACES8:
            nrm = A[n, ax] * sgn
            c0 = P[n] + nrm * S[n, ax] / 2
            if nrm @ (eye - c0) <= 0:
                continue
            poly = cam[n, list(idx)]
            if (poly[:, 2] < 1.0).all():
                continue
            if (poly[:, 2] < 1.0).any():
                out = []
                for a, b in zip(poly, np.roll(poly, -1, 0)):
                    if a[2] >= 1.0:
                        out.append(a)
                    if (a[2] >= 1.0) != (b[2] >= 1.0):
                        t = (1.0 - a[2]) / (b[2] - a[2])
                        out.append(a + (b - a) * t)
                poly = np.array(out)
                if len(poly) < 3:
                    continue
            sx, sy = W / 2 + poly[:, 0] / poly[:, 2] * fl, H / 2 - poly[:, 1] / poly[:, 2] * fl
            x0, x1 = max(0, int(sx.min())), min(W - 1, int(math.ceil(sx.max())))
            y0, y1 = max(0, int(sy.min())), min(H - 1, int(math.ceil(sy.max())))
            if x0 > x1 or y0 > y1:
                continue
            X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            m1 = np.ones(X.shape, bool)
            m2 = np.ones(X.shape, bool)
            q = np.stack([sx, sy], 1)
            for (ax_, ay_), (bx_, by_) in zip(q, np.roll(q, -1, 0)):
                e = (bx_ - ax_) * (Y - ay_) - (by_ - ay_) * (X - ax_)
                m1 &= e >= -0.01
                m2 &= e <= 0.01
            m = m1 | m2
            if not m.any():
                continue
            nc = R @ nrm  # the face's plane in the camera's frame
            d = nc @ (R @ (c0 - eye))
            den = nc[0] * (X - W / 2) / fl - nc[1] * (Y - H / 2) / fl + nc[2]
            with np.errstate(divide="ignore", invalid="ignore"):
                z = d / den
            zs = zb[y0:y1 + 1, x0:x1 + 1]
            m &= (z > 0.5) & (z < zs)
            if not m.any():
                continue
            zz = z[m]
            zs[m] = zz
            wp = eye + np.stack([(X[m] - W / 2) / fl * zz, -(Y[m] - H / 2) / fl * zz, zz], 1) @ R
            col = C[n] * (1.0 if K[n] in glowk else (0.62 + 0.42 * max(0.0, nrm @ sun) + 0.06 * nrm[1]))
            col = np.repeat(col[None], len(zz), 0)
            if K[n] in (0, 1, 5) and zz.min() < 900:  # the squares
                uv = (wp - P[n]) @ A[n].T
                a1, a2 = [k for k in range(3) if k != ax]
                if K[n] == 5 and ax == 1:
                    chk = (np.floor(wp[:, 0] / 8) + np.floor(wp[:, 2] / 8)) % 2
                else:
                    chk = (np.floor(uv[:, a1] / 8 + 0.25) + np.floor(uv[:, a2] / 8)) % 2
                col = col * (0.965 + 0.07 * chk)[:, None]
            fog = np.clip(thick * (zz / see), 0, 1)[:, None] if thick >= 1 else (1 - np.exp(np.log(1 - thick) * zz / see))[:, None]
            col = col * np.array(tint) / 255.0
            img[y0:y1 + 1, x0:x1 + 1][m] = col * (1 - fog) + np.array(water) * fog
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def rider_view(shapes, run, k, back=420.0, look=None, up=62.0, repaint=True, size=(1280, 720)):
    """from a rider's camera, `back` studs before chunk k's entrance, looking down the lane"""
    p = run[k]
    prev = run[k - 1]
    way = st.way_of(shapes, prev) if back > 0 else st.way_of(shapes, p)
    nxt = st.way_of(shapes, p)
    d = np.linalg.norm(way - p["at"], axis=1)
    eye = way[np.abs(d - back).argmin()] + np.array([0, up, 0])
    ahead = nxt[min(len(nxt) - 1, 40)] + np.array([0, up * 0.25, 0])
    z = wz.ZONES[p["look"] if repaint else look]
    bx = boxes(shapes, run[max(0, k - 1):k + 2], repaint)
    return raster(bx, eye, ahead, size, 70, z["water"], z["see"], z["thick"], z["tint"])


def plan(shapes, run, scale, bg=(14, 22, 40), shade=True, pad=60, box=None, label=True):
    """from above; deeper is darker and bluer, so the coils read"""
    P, A, S, C, K, I = boxes(shapes, run)
    big = (np.maximum(S[:, 0], S[:, 2]) > 10)
    P, A, S, C, K, I = [v[big] for v in (P, A, S, C, K, I)]
    V = corners(P, A, S)
    lo, hi = (V.min((0, 1)), V.max((0, 1))) if box is None else box
    W, H = int((hi[0] - lo[0]) * scale) + pad * 2, int((hi[2] - lo[2]) * scale) + pad * 2
    im = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(im)
    top = V[:, :, 1].max(1)
    ids = np.argsort(top)
    n = max(p["i"] for p in run) + 1
    for k in ids:
        c = V[k][[2, 3, 7, 6]]
        f = I[k] / n
        col = C[k] * (1 - 0.55 * f) + np.array([20, 40, 110]) * 0.55 * f
        d.polygon([(pad + (q[0] - lo[0]) * scale, H - pad - (q[2] - lo[2]) * scale) for q in c], fill=tuple(int(v) for v in col))
    for p in run:
        if p["boss"] and label:
            w = st.way_of(shapes, p)[-1]
            x, y = pad + (w[0] - lo[0]) * scale, H - pad - (w[2] - lo[2]) * scale
            d.ellipse((x - 13, y - 13, x + 13, y + 13), fill=(255, 205, 60), outline=(20, 20, 20), width=3)
    a = run[0]["at"]
    x, y = pad + (a[0] - lo[0]) * scale, H - pad - (a[2] - lo[2]) * scale
    d.ellipse((x - 11, y - 11, x + 11, y + 11), fill=(90, 255, 130), outline=(10, 10, 10), width=3)
    return im


def elevation(shapes, run, scale, bg=(14, 22, 40), pad=50):
    """from the side (looking along z): the corkscrew"""
    P, A, S, C, K, I = boxes(shapes, run, skip=("barrier", "setsmoke", "prop", "set", "setglow", "trim"))
    big = np.maximum(S[:, 0], S[:, 2]) > 10
    P, A, S, C, K, I = [v[big] for v in (P, A, S, C, K, I)]
    V = corners(P, A, S)
    lo, hi = V.min((0, 1)), V.max((0, 1))
    W, H = int((hi[0] - lo[0]) * scale) + pad * 2, int((hi[1] - lo[1]) * scale) + pad * 2
    im = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(im)
    zmid = (lo[2] + hi[2]) / 2
    for k in np.argsort(P[:, 2])[::-1]:
        v = V[k]
        far = (P[k, 2] - zmid) / (hi[2] - lo[2]) + 0.5  # 1 far
        col = C[k] * (1 - 0.6 * far) + np.array(bg) * 0.6 * far
        x0, x1, y0, y1 = v[:, 0].min(), v[:, 0].max(), v[:, 1].min(), v[:, 1].max()
        d.rectangle((pad + (x0 - lo[0]) * scale, pad + (hi[1] - y1) * scale, pad + (x1 - lo[0]) * scale, pad + (hi[1] - y0) * scale), fill=tuple(int(q) for q in col))
    return im


def strip(shapes, run, scale=0.16, height=150):
    """six chunks end to end, unrolled: from the side, cut down the lane's middle (what is right of it is seen)"""
    ims, x = [], 0.0
    total = sum(shapes[p["shape"]]["long"] for p in run)
    drop = 0.0
    W, H = int(total * scale) + 40, int((total * math.tan(math.radians(6)) + 560) * scale) + 40
    im = Image.new("RGB", (W, H), (14, 22, 40))
    d = ImageDraw.Draw(im)
    for p in run:
        c = shapes[p["shape"]]
        C = paint(c, p["look"])
        # along the chunk's own way
        way = c["way"]
        dd = ((c["P"][:, None, [0, 2]] - way[None, ::6][..., [0, 2]]) ** 2).sum(-1)
        s = dd.argmin(1) * 24.0
        h = np.interp(s, np.arange(len(way)) * 4.0, np.arctan2(np.gradient(way[:, 0]), np.gradient(way[:, 2])))
        rt = np.stack([np.cos(h), -np.sin(h)], 1)
        ctr = np.stack([np.interp(s, np.arange(len(way)) * 4.0, way[:, k]) for k in (0, 2)], 1)
        u = ((c["P"][:, [0, 2]] - ctr) * rt).sum(1)
        fwd = np.stack([np.sin(h), np.cos(h)], 1)
        s = s + ((c["P"][:, [0, 2]] - ctr) * fwd).sum(1)
        m = (u > -40) & (u < 700) & ~np.isin(c["K"], [4, 9])
        for k in np.where(m)[0][np.argsort(-u[m])]:
            half = max(c["S"][k][0], c["S"][k][2]) / 2
            y = c["P"][k][1] + drop
            hh = c["S"][k][1] / 2
            f = min(1, max(0, u[k] / 800))
            col = C[k] * (1 - 0.6 * f) + np.array([40, 60, 110]) * 0.6 * f
            x0 = 20 + (x + s[k] - half) * scale
            d.rectangle((x0, 20 + (470 - y - hh) * scale, x0 + 2 * half * scale, 20 + (470 - y + hh) * scale), fill=tuple(int(q) for q in col))
        x += c["long"]
        drop += c["exit"][1]
    return im


if __name__ == "__main__":
    pkl, out = sys.argv[1], sys.argv[2]
    what = sys.argv[3] if len(sys.argv) > 3 else "all"
    os.makedirs(out, exist_ok=True)
    made, today = pickle.load(open(pkl, "rb"))
    if what in ("all", "plans"):
        for seed in (1, 2, 3):
            run = st.stack(made, seed, 30, "spiral", START, H0)
            plan(made, run, 0.11).save(os.path.join(out, f"top-{seed}.png"))
            elevation(made, run, 0.11).save(os.path.join(out, f"side-{seed}.png"))
            print(seed, [f"{made[p['shape']]['name']}{'m' if p['hand'] < 0 else ''}/{p['look'] + 1}" for p in run])
        run = st.stack(made, 1, 6, "spiral", START, H0)
        strip(made, run).save(os.path.join(out, "strip-1.png"))
    if what in ("all", "eye"):
        run = st.stack(made, 1, 12, "spiral", START, H0)
        for k in (2, 3, 5, 6):
            rider_view(made, run, k).save(os.path.join(out, f"eye-{k}.png"))
            print("eye", k)
