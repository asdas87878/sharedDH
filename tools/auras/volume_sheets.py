#!/usr/bin/env python3
"""Draws the 3D auras' pictures (look 2, Shared/AuraVolume; docs/design/auras.md): our own, white on clear, drawn by sums.

    python tools/auras/volume_sheets.py            (needs numpy and Pillow) -> art/ui/aura_volume/*.png
    python tools/auras/volume_sheets.py Flame Arc  (only those)
    python tools/auras/volume_sheets.py --local    copies them into Studio's content folder, for the preview

Flipbook sheets are read left to right, top to bottom: 8x8 of 128 px, or 4x4 of 256 (Mote 4x4 of 128). Each frame keeps a
clear border, or the next frame's edge would show. Ribbon is the Beams' one: it runs up the picture and repeats.
A picture that has changed needs a new Auras.SheetSet (Studio keeps the old one under its name)."""
import glob
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "ui", "aura_volume")
TAU = 2 * np.pi


def smooth(a, b, x):
    k = np.clip((x - a) / (b - a), 0, 1)
    return k * k * (3 - 2 * k)


class Noise:
    """Smooth noise on a grid that wraps, so it can loop and tile."""

    def __init__(self, seed, w, h):
        self.g = np.random.default_rng(seed).random((h, w))
        self.w, self.h = w, h

    def __call__(self, x, y):
        x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        g, w, h = self.g, self.w, self.h
        a = g[y0 % h, x0 % w] * (1 - fx) + g[y0 % h, (x0 + 1) % w] * fx
        b = g[(y0 + 1) % h, x0 % w] * (1 - fx) + g[(y0 + 1) % h, (x0 + 1) % w] * fx
        return a * (1 - fy) + b * fy


def grid(n):
    c = (np.arange(n) + 0.5) / n * 2 - 1
    return np.meshgrid(c, -c)  # y up


def stroke(X, Y, pts, wid, edge=0.02, bristle=None):
    """One tapered brush stroke along pts: 0 to 1. bristle: (Noise, how many across, strength)."""
    best = np.full(X.shape, -9.0)
    U = np.zeros(X.shape)
    V = np.zeros(X.shape)
    n = len(pts) - 1
    size = X.shape[0]
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[i + 1]
        dx, dy = bx - ax, by - ay
        ll = dx * dx + dy * dy + 1e-12
        # only the cells near this piece
        m = max(wid[i], wid[i + 1]) + edge
        c0 = int(max((min(ax, bx) - m + 1) / 2 * size, 0))
        c1 = int(min((max(ax, bx) + m + 1) / 2 * size + 2, size))
        r0 = int(max((1 - max(ay, by) - m) / 2 * size, 0))
        r1 = int(min((1 - min(ay, by) + m) / 2 * size + 2, size))
        if c0 >= c1 or r0 >= r1:
            continue
        box = (slice(r0, r1), slice(c0, c1))
        x, y = X[box], Y[box]
        t = np.clip(((x - ax) * dx + (y - ay) * dy) / ll, 0, 1)
        px, py = x - (ax + dx * t), y - (ay + dy * t)
        d = np.hypot(px, py)
        w = wid[i] + (wid[i + 1] - wid[i]) * t
        f = w - d
        more = f > best[box]
        best[box] = np.where(more, f, best[box])
        U[box] = np.where(more, (i + t) / n, U[box])
        V[box] = np.where(more, np.sign(dx * py - dy * px) * d / np.maximum(w, 1e-4), V[box])
    a = smooth(-edge * 0.5, edge, best) * smooth(0, 0.02, np.interp(U, np.linspace(0, 1, len(wid)), wid) + 0.005)
    if bristle is not None:
        noise, across, much = bristle
        b = noise(V * across + 40, U * 5 + V * 0.6)
        a = a * (1 - much * smooth(0.5, 0.75, b))
    return a


def over(a, b):
    return a + b - a * b


def frame_edges(a, n, pad=0.06):
    """A clear border round a frame."""
    X, Y = grid(n)
    m = smooth(1.0, 1 - pad, np.abs(X)) * smooth(1.0, 1 - pad, np.abs(Y))
    return a * m


def sheet(cells, px, draw, ss=2, pad=0.06):
    out = np.zeros((cells * px, cells * px))
    n = px * ss
    total = cells * cells
    for i in range(total):
        a = np.clip(draw(i, total, n), 0, 1)
        a = frame_edges(a, n, pad)
        a = a.reshape(px, ss, px, ss).mean(axis=(1, 3))
        r, c = divmod(i, cells)
        out[r * px:(r + 1) * px, c * px:(c + 1) * px] = a
    return out


# ---- the pictures -----------------------------------------------------------------------------------------------


def wisp():
    """8x8, once: long thin ribbons leave the ground, wind up and thin away."""
    nb = Noise(3, 64, 64)

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / (total - 1)
        a = np.zeros((n, n))
        for (off, amp, w0, late, phase) in ((-0.06, 0.26, 0.085, 0.0, 0.3), (0.3, 0.17, 0.045, 0.1, 2.1),
                                            (-0.42, 0.15, 0.034, 0.18, 4.0)):
            k = np.clip((t - late) / (1 - late), 0, 1)
            head = -0.94 + 1.86 * (1 - (1 - np.clip(k * 1.25, 0, 1)) ** 1.8)
            tail = -0.94 + 1.7 * smooth(0.35, 1.1, k) ** 1.2
            if head - tail < 0.12:
                continue
            y = np.linspace(tail, head, 40)
            q = (y + 0.94) / 1.88
            x = off + amp * np.sin(q * 5.6 - t * 4.5 + phase) * (0.3 + 0.9 * q) + 0.07 * np.sin(q * 11 + t * 4 + phase)
            u = np.linspace(0, 1, 40)
            wid = w0 * np.sin(np.pi * u ** 0.8) ** 0.8 * (0.75 + 0.25 * np.sin(u * 9 + t * 5 + phase)) * (1 - 0.5 * k)
            a = over(a, stroke(X, Y, np.stack([x * 0.92, y], 1), wid, 0.03, (nb, 3.2, 0.4)) * (1 if w0 > 0.06 else 0.8))
        return a * smooth(1.0, 0.8, t)

    return sheet(8, 128, draw)


def flame():
    """8x8, once: licks of flame stand up from the ground, whip over at their tips and tear off upward."""
    nb = Noise(7, 64, 64)
    # where each stands, how it leans, how tall, how wide, how late it comes, its sway
    licks = [(0.0, 0.10, 1.0, 0.25, 0.0, 0.0), (-0.2, -0.22, 0.72, 0.16, 0.04, 1.4), (0.21, 0.26, 0.64, 0.15, 0.1, 2.9),
             (-0.07, 0.2, 0.86, 0.12, 0.2, 4.2), (0.1, -0.16, 0.9, 0.12, 0.28, 5.3)]

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / (total - 1)
        a = np.zeros((n, n))
        inner = np.zeros((n, n))
        for (x0, lean, tall, wide, late, ph) in licks:
            k = np.clip((t - late) / (1 - late), 0, 1)
            head = tall * (1 - (1 - np.clip(k * 1.5, 0, 1)) ** 2) + 0.08 * k
            tail = smooth(0.38, 1.02, k) * 0.92 * tall
            if head - tail < 0.06:
                continue
            q = np.linspace(tail, min(head, 1.0), 32)
            y = -0.9 + 1.8 * q
            sway = 0.16 * np.sin(q * 4.2 - t * 8 + ph) + 0.07 * np.sin(q * 9 - t * 13 + ph * 2)
            x = x0 * (1 - 0.35 * q) + lean * q ** 1.5 + sway * np.clip(q * 1.5, 0, 1)
            u = np.linspace(0, 1, 32)
            # fat low down, drawn out to a point: a tear while it stands, a sliver once its foot is off
            off = smooth(0.0, 0.25, tail)
            w = wide * ((1 - u) ** 0.85) * (0.3 * (1 - off) + (0.7 + 0.3 * off) * smooth(0, 0.3, u)) * (1 - 0.5 * k)
            pts = np.stack([x, y], 1)
            a = over(a, stroke(X, Y, pts, w, 0.03, (nb, 3.0, 0.45)))
            inner = over(inner, stroke(X, Y, pts, w * 0.5, 0.05))
        # (its foot fades out: it has no floor to stand on round a fish)
        return (a * 0.72 + a * inner * 0.28) * smooth(-0.92, -0.4, Y + 0.12 * np.abs(X)) * smooth(1.02, 0.85, t)

    return sheet(8, 128, draw)


def ring():
    """4x4, loops: broken brush arcs going round at three distances, and a faint light under them."""
    nb = Noise(21, 64, 64)
    specs = []
    rng = np.random.default_rng(5)
    # (as many arcs alike as steps of a turn, so it loops: n-fold, each loop turns it by one place)
    for (fold, rad, wid, arc, way) in ((3, 0.80, 0.030, 1.55, 1), (4, 0.70, 0.016, 0.95, -1), (5, 0.87, 0.011, 0.8, 1),
                                       (2, 0.61, 0.012, 1.5, 1)):
        specs.append((fold, rad, wid, arc, way, rng.random() * TAU))

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / total
        r = np.hypot(X, Y)
        a = 0.2 * np.exp(-((r - 0.76) / 0.09) ** 2)
        for (fold, rad, wid, arc, way, ph) in specs:
            for j in range(fold):
                s = ph + (j + way * t) * TAU / fold
                u = np.linspace(0, 1, 26)
                ang = s + way * u * arc
                rr = rad + 0.035 * (u - 0.5)
                w = wid * np.sin(np.pi * u ** 1.5) ** 0.8
                a = over(a, stroke(X, Y, np.stack([rr * np.cos(ang), rr * np.sin(ang)], 1), w, 0.014, (nb, 2, 0.35)))
        return a

    return sheet(4, 256, draw, pad=0.04)


def sweep():
    """4x4, once: thin curved strokes whip outward over the ground and thin away (seen from above)."""
    nb = Noise(31, 64, 64)
    arms = [(0.2, 0.26, 0.94, 1.7, 0.055, 0.0), (1.6, 0.4, 0.9, 1.1, 0.03, 0.05), (2.5, 0.34, 0.92, 1.5, 0.045, 0.1),
            (4.3, 0.28, 0.86, 1.8, 0.038, 0.16)]

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / (total - 1)
        a = np.zeros((n, n))
        for (ang, r0, r1, turn, wid, late) in arms:
            k = np.clip((t - late + 0.06) / (1 - late), 0, 1)
            head = 1 - (1 - np.clip(k * 1.2, 0, 1)) ** 2
            tail = smooth(0.3, 1.1, k)
            if head - tail < 0.04:
                continue
            u = np.linspace(tail, head, 34)
            an = ang + turn * u
            rr = r0 + (r1 - r0) * u ** 1.3
            v = np.linspace(0, 1, 34)
            w = wid * np.sin(np.pi * v ** 1.5) ** 0.9 * (1 - 0.45 * k)
            a = over(a, stroke(X, Y, np.stack([rr * np.cos(an), rr * np.sin(an)], 1), w, 0.016, (nb, 2.5, 0.35)))
        return a

    return sheet(4, 256, draw, pad=0.04)


def shock():
    """4x4, once: a ring of torn strokes runs outward over the ground."""
    nb = Noise(41, 64, 64)
    n1 = Noise(43, 24, 24)

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / (total - 1)
        r = np.hypot(X, Y)
        th = np.arctan2(Y, X) / TAU
        rad = 0.16 + 0.72 * (1 - (1 - t) ** 2)
        band = 0.12 * (1 - t) ** 0.7 + 0.012
        tear = n1(th * 24 + 30, r * 4 + 5) * 0.6 + n1(th * 72 + 7, r * 3) * 0.4
        out = (r - rad) / band
        f = np.where(out > 0, np.exp(-(out / 0.35) ** 2), np.exp(-(out / 1.0) ** 2))
        a = f * smooth(0.25 + 0.5 * t, 0.5 + 0.4 * t, tear)
        # a few spokes flung out
        for j in range(9):
            g = j * 2.399 + 0.5
            r0, r1 = rad * 0.82, rad * (0.98 + 0.14 * ((j * 7) % 5) / 4)
            u = np.linspace(0, 1, 6)
            rr = r0 + (r1 - r0) * u
            an = g + 0.18 * u
            w = 0.018 * np.sin(np.pi * u) * (1 - t)
            a = over(a, stroke(X, Y, np.stack([rr * np.cos(an), rr * np.sin(an)], 1), w, 0.012, (nb, 2, 0.4)))
        return a * smooth(1.05, 0.8, t)

    return sheet(4, 256, draw, pad=0.04)


def jet():
    """4x4, once: a splayed brush stroke flung up the picture (it lies along its own way)."""
    nb = Noise(51, 64, 64)
    blades = [(0.0, 0.0, 0.15, 0.0), (-0.16, -0.34, 0.06, 0.04), (0.15, 0.36, 0.065, 0.07), (0.07, 0.17, 0.05, 0.12),
              (-0.09, -0.15, 0.045, 0.15), (-0.2, -0.55, 0.035, 0.1), (0.2, 0.58, 0.03, 0.14)]

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / (total - 1)
        a = np.zeros((n, n))
        for (x0, lean, wid, late) in blades:
            k = np.clip((t - late + 0.12) / (1 - late + 0.12), 0, 1)
            head = -0.9 + 1.8 * (1 - (1 - k) ** 2.2)
            tail = -0.9 + 1.7 * smooth(0.22, 1.1, k)
            if head - tail < 0.1:
                continue
            y = np.linspace(tail, head, 24)
            q = (y + 0.9) / 1.8
            x = x0 * 0.5 + lean * q ** 1.4 + 0.03 * np.sin(q * 7 + t * 3)
            v = np.linspace(0, 1, 24)
            w = wid * np.sin(np.pi * v ** 0.75) ** 1.2 * np.clip((head - tail) / 0.8, 0.25, 1) * (1 - 0.45 * k)
            a = over(a, stroke(X, Y, np.stack([x, y], 1), w, 0.022, (nb, 4.5, 0.6)))
        return a

    return sheet(4, 256, draw)


def haze():
    """4x4, loops: a soft drifting cloud."""
    n1, n2 = Noise(61, 16, 16), Noise(63, 16, 16)

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / total * TAU
        cx, sy = np.cos(t), np.sin(t)
        f = n1(X * 1.6 + 5 + 0.6 * cx, Y * 1.6 + 5 + 0.6 * sy) * 0.6 + n2(X * 3.4 + 9 + 0.5 * sy, Y * 3.4 + 9 - 0.5 * cx) * 0.4
        r = np.hypot(X, Y)
        return smooth(0.95, 0.1, r) * (0.35 + 0.65 * smooth(0.25, 0.8, f)) * 0.9

    return sheet(4, 128, draw, pad=0.04)


def shaft():
    """4x4, loops: an upright shaft of light with thinner ones in it that shimmer across."""
    rng = np.random.default_rng(71)
    bars = [(rng.uniform(-0.3, 0.3), rng.uniform(0.012, 0.05), rng.integers(1, 3), rng.random() * TAU,
             rng.uniform(0.25, 0.8)) for _ in range(7)]

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / total * TAU
        q = (Y + 1) / 2
        a = 0.28 * np.exp(-(X / 0.24) ** 2)
        for (x, w, sp, ph, hi) in bars:
            s = 0.5 + 0.5 * np.sin(sp * t + ph)
            xx = x + 0.03 * np.sin(t + ph)
            a = over(a, 0.6 * s * np.exp(-((X - xx) / w) ** 2) * smooth(hi + 0.3, hi - 0.2, q))
        # clear at the top, strong just over the ground
        return a * smooth(0.02, 0.16, q) * smooth(1.0, 0.25, q)

    return sheet(4, 256, draw)


def mote():
    """4x4, loops: a sliver of light that flickers (it lies along its way)."""

    def draw(i, total, n):
        X, Y = grid(n)
        t = i / total * TAU
        s = 0.75 + 0.25 * np.sin(t)
        y = np.linspace(-0.8 * s, 0.8 * s, 14)
        x = 0.1 * np.sin(y * 3 + t)
        v = np.linspace(0, 1, 14)
        w = 0.15 * s * np.sin(np.pi * v ** 1.4) ** 1.2
        core = stroke(X, Y, np.stack([x, y], 1), w, 0.06)
        glow = 0.32 * np.exp(-((X / 0.3) ** 2 + (Y / 0.6) ** 2) * 1.6)
        return over(core, glow)

    return sheet(4, 128, draw, ss=3)


def arc():
    """4x4, any frame: crackling bolts, each a jagged curve that bows outward, with a fork or two."""
    rng = np.random.default_rng(81)

    def bolt(p, q, rough, levels):
        pts = [np.array(p, float), np.array(q, float)]
        for _ in range(levels):
            out = [pts[0]]
            for a, b in zip(pts[:-1], pts[1:]):
                d = b - a
                m = (a + b) / 2 + np.array([-d[1], d[0]]) * rng.uniform(-rough, rough)
                out += [m, b]
            pts = out
        return np.array(pts)

    made = []
    for _ in range(16):
        g = rng.random() * TAU
        p = 0.75 * np.array([np.cos(g), np.sin(g)])
        h = g + np.pi + rng.uniform(-0.7, 0.7)
        q = 0.75 * np.array([np.cos(h), np.sin(h)])
        main = bolt(p, q, 0.28, 4)
        forks = []
        for _ in range(rng.integers(1, 3)):
            k = rng.integers(4, 12)
            d = main[k + 2] - main[k]
            an = np.arctan2(d[1], d[0]) + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0)
            forks.append(bolt(main[k], main[k] + rng.uniform(0.25, 0.45) * np.array([np.cos(an), np.sin(an)]), 0.25, 3))
        made.append((main, forks))

    def draw(i, total, n):
        X, Y = grid(n)
        main, forks = made[i]
        u = np.linspace(0, 1, len(main))
        w = 0.03 * np.sin(np.pi * u) ** 0.5
        a = stroke(X, Y, main, w, 0.018)
        glow = 0.28 * stroke(X, Y, main, w + 0.05, 0.12)
        for f in forks:
            v = np.linspace(1, 0, len(f))
            a = over(a, stroke(X, Y, f, 0.02 * v, 0.016))
        return over(a, glow)

    return sheet(4, 256, draw, pad=0.04)


def ribbon():
    """The Beams': brush strands running up it, torn at both sides; it repeats up the picture (256 x 512)."""
    W, H = 256, 512
    x = (np.arange(W) + 0.5) / W * 2 - 1
    y = (np.arange(H) + 0.5) / H
    X, Y = np.meshgrid(x, y)
    rng = np.random.default_rng(91)
    n1 = Noise(95, 64, 6)
    n2 = Noise(97, 64, 4)
    mid = 0.05 * np.sin(Y * TAU + 0.5)
    # its edge wavers and tears along the bristles
    fine = n2(X * 24 + 30, Y * 4)
    wide = n1(X * 7 + 12, Y * 6)
    half = 0.5 + 0.08 * np.sin(Y * TAU + 1) + 0.3 * (fine * 0.6 + wide * 0.4 - 0.5)
    d = half - np.abs(X - mid)
    body = smooth(0.0, 0.1, d)
    streak = fine * 0.6 + wide * 0.4
    a = body * (0.4 + 0.6 * smooth(0.3, 0.62, streak))
    # solid down its middle
    a = over(a, 0.55 * np.exp(-((X - mid) / 0.17) ** 2))
    # thin strands that leave it and come back
    for j in range(4):
        ph = rng.random() * TAU
        c = mid + 0.62 * np.sin(Y * TAU + ph) + 0.08 * np.sin(Y * TAU * 2 + ph * 3)
        w = 0.03 + 0.02 * np.sin(Y * TAU * 2 + ph * 2)
        a = over(a, 0.7 * smooth(w, w * 0.2, np.abs(X - c)))
    return np.clip(a, 0, 1) * smooth(1.0, 0.8, np.abs(X))


def glow():
    """A still: a soft round light."""
    X, Y = grid(256)
    r = np.hypot(X, Y)
    return smooth(1.0, 0.0, r) ** 1.6


SHEETS = {"Wisp": wisp, "Flame": flame, "Ring": ring, "Sweep": sweep, "Shock": shock, "Jet": jet, "Haze": haze,
          "Shaft": shaft, "Mote": mote, "Arc": arc, "Ribbon": ribbon, "Glow": glow}


def save(name, a):
    img = np.full(a.shape + (4,), 255, np.uint8)
    img[..., 3] = np.round(np.clip(a, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name.lower() + ".png"), optimize=True)


def local():
    """Copies them to where rbxasset://textures/ridefish is on this PC (Windows, or Vinegar)."""
    text = open(os.path.join(ROOT, "src", "shared", "Auras.luau")).read()
    s = re.search(r'SheetSet = "(\w+)"', text).group(1)
    homes = glob.glob(os.path.expanduser("~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content/textures"))
    homes += glob.glob(os.path.expanduser("~/AppData/Local/Roblox/Versions/*/content/textures"))
    if not homes:
        sys.exit("no Studio on this PC")
    for h in homes:
        to = os.path.join(h, "ridefish")
        os.makedirs(to, exist_ok=True)
        for name in SHEETS:
            shutil.copyfile(os.path.join(OUT, name.lower() + ".png"), os.path.join(to, f"aura3_{name.lower()}_{s}.png"))
        print(f"{len(SHEETS)} pictures -> {to}")


if __name__ == "__main__":
    if "--local" in sys.argv:
        local()
    else:
        os.makedirs(OUT, exist_ok=True)
        for name in sys.argv[1:] or SHEETS:
            save(name, SHEETS[name]())
            print(name)
