"""Hugo's ten picks (2026-11-25), redrawn as one ladder: land 1 is the plain one, land 10 the biggest look. Same pieces
and anchors as saddles.py (read by it). What climbs, land by land: how high it stands behind the rider, how much of it
glows, how many layers it has, and how rich its side panels are; `ladder()` in saddles.py counts the first two and the parts, and stops if the ladder goes down.

The camera is behind and above, so the BACK of a raised piece (z up) is the side the player sees."""
import math

import numpy as np


def unit(v):
    v = np.array(v, float)
    return v / np.linalg.norm(v)


def angles(m):
    """a turn as Roblox's CFrame.Angles, degrees"""
    y = math.asin(max(-1, min(1, m[0, 2])))
    if abs(m[0, 2]) > 0.99999:
        return (math.degrees(math.atan2(m[1, 0], m[1, 1])), math.degrees(y), 0.0)
    return tuple(round(math.degrees(v), 2) for v in (math.atan2(-m[1, 2], m[2, 2]), y, math.atan2(-m[0, 1], m[0, 0])))


def stand(d, back=(0, 0, 1)):
    """axes whose y is d and whose z is as near `back` as can be"""
    y = unit(d)
    b = np.array(back, float)
    if abs(y @ unit(b)) > 0.98:
        b = np.array([0, 1.0, 0])
    z = unit(b - (b @ y) * y)
    return np.column_stack([np.cross(y, z), y, z])


def yaw(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


class Kit:
    def __init__(self):
        self.p = []

    def put(self, a, shape, p, size, c, m=None, r=None, **o):
        if m is not None:
            r = angles(m)
        if r is not None:
            o["r"] = r
        self.p.append((a, shape, tuple(float(v) for v in p), tuple(float(v) for v in size), c, {k: v for k, v in o.items() if v is not False}))

    def box(self, a, p, size, c, r=None, **o):
        self.put(a, "box", p, size, c, r=r, **o)

    def rod(self, a, p0, p1, w, c, d=None, over=0.0, turn=0, back=(0, 0, 1), **o):
        """a bar from p0 to p1, w wide, d deep"""
        p0, p1 = np.array(p0, float), np.array(p1, float)
        m = stand(p1 - p0, back) @ yaw(turn)
        self.put(a, "box", (p0 + p1) / 2, (w, np.linalg.norm(p1 - p0) + over, d or w), c, m=m, **o)

    def chain(self, a, pts, ws, cs, d=None, back=(0, 0, 1), over=None, **o):
        """bars end to end along points, each with its own width and colour; their joints overlap"""
        n = len(pts) - 1
        for i in range(n):
            w = ws[min(i, len(ws) - 1)]
            self.rod(a, pts[i], pts[i + 1], w, cs[min(i, len(cs) - 1)], d=(d[min(i, len(d) - 1)] if isinstance(d, (list, tuple)) else d), over=w * 0.3 if over is None else over, back=back, **o)

    def spike(self, a, p0, p1, w, c, d=None, back=(0, 0, 1), **o):
        """a pointed blade: two wedges, broad at p0, a point at p1"""
        p0, p1 = np.array(p0, float), np.array(p1, float)
        f, ln = stand(p1 - p0, back), float(np.linalg.norm(p1 - p0))
        d = d or w
        for s in (1, -1):
            x, y, z = f[:, 0], f[:, 1], f[:, 2]
            m = np.column_stack([z * s, y, -x * s])
            self.put(a, "wedge", (p0 + p1) / 2 + x * s * w / 4, (d, ln, w / 2), c, m=m, **o)

    def leaf(self, a, p0, p1, w, c, d=0.1, belly=0.45, vein=None, back=(0, 0, 1), **o):
        """a blade that swells and comes to a point"""
        p0, p1 = np.array(p0, float), np.array(p1, float)
        mid = p0 + (p1 - p0) * belly
        self.rod(a, p0, mid + (p1 - p0) * 0.03, w, c, d=d, back=back, **o)
        self.spike(a, mid, p1, w, c, d=d, back=back, **o)
        if vein:
            z = stand(p1 - p0, back)[:, 2]
            self.rod(a, p0 + z * d * 0.5, p0 + (p1 - p0) * 0.75 + z * d * 0.5, w * 0.2, vein, d=d * 0.5, back=back, **o)

    def crystal(self, a, p0, p1, w, c, cap=None, turn=45, tip=0.3, n=False, capn=False, **o):
        """a square column on its edge with a pointed end"""
        p0, p1 = np.array(p0, float), np.array(p1, float)
        q = p1 - (p1 - p0) * tip
        self.rod(a, p0, q, w, c, turn=turn, n=n, **o)
        m = stand(p1 - p0) @ yaw(turn)
        self.spike(a, q - unit(p1 - p0) * 0.01, p1, w * 0.98, cap or c, back=m[:, 2], n=capn or n, **o)

    def rock(self, a, p, w, h, c, dr=(0, 1, 0), turn=0, **o):
        """an eight-cornered block: two boxes crossed"""
        m = stand(dr)
        p = np.array(p, float)
        self.put(a, "box", p, (w, h, w * 0.72), c, m=m @ yaw(turn), **o)
        self.put(a, "box", p, (w * 0.72, h * 0.96, w), c, m=m @ yaw(turn), **o)

    def star(self, a, u, y, z, s, c, rays=3, h=0.12, w=0.22, **o):
        """a flat star on a side panel"""
        for i in range(rays):
            self.box(a, (u, y + 0.004 * i, z), (s, h, s * w), c, (0, 180 / rays * i, 0), **o)


B = {"both": True}
MID = {"mid": True}


def scallop():
    """1: the plain one. A low shell, flat colours, nothing glows."""
    k = Kit()
    coral, pale, dk, sand, hem = "#f08a68", "#ffdcc0", "#d8735a", "#f3e2b8", "#e3b98c"
    k.box("can", (0, 0.09, 0.14), (0.72, 0.22, 0.34), dk, **MID)
    k.box("can", (0.52, 0.09, 0.14), (0.36, 0.22, 0.33), dk, **B)  # (the halves stand alone where a fin comes between)
    k.box("can", (0.62, 0.2, 0.15), (0.28, 0.2, 0.26), coral, **B)
    for i, t in enumerate((0, 24, 48, 72)):
        r = math.radians(t)
        c, ln = (coral, pale)[i % 2], (0.66, 0.7, 0.76, 0.74)[i]
        o = MID if i == 0 else dict(B, mid=i == 1)
        at = lambda s: (math.sin(r) * ln * s + 0.06 * (i > 1), 0.08 + math.cos(r) * ln * s, 0.16 + 0.16 * s * math.cos(r) + 0.035 * (i % 2))  # noqa: E731
        k.rod("can", at(0.12 if i < 2 else 0.42), at(0.78), 0.28, c, d=0.18, **o)
        k.rod("can", at(0.7), at(1.02), 0.34, c, d=0.2, **o)
    k.box("pom", (0, 0.08, -0.26), (0.8, 0.2, 0.36), dk)
    k.box("pom", (0, 0.2, -0.28), (0.56, 0.14, 0.26), coral)
    k.star("flap", 0.5, 0.03, 0.55, 0.5, coral, 3, 0.12, 0.3)
    k.box("flap", (0.5, 0.08, 0.55), (0.2, 0.12, 0.2), pale, (0, 30, 0))
    return {"main": sand, "flap": "#e9d3a0", "trim": hem, "cushion": "#4c9c80", "cushion2": "#5fae92", "strap": "#4c9c80", "pieces": k.p}


def anemone():
    """2: a soft row of arms, two pinks and a yellow."""
    k = Kit()
    base, light, tip, pur, dpur = "#f2708f", "#ff9db2", "#ffe08a", "#8063c9", "#664bb0"
    k.put("can", "cylinder", (0, 0.16, 0.16), (1.9, 0.4, 0.4), pur)
    k.put("can", "cylinder", (0.8, 0.16, 0.16), (0.14, 0.48, 0.48), dpur, **B)
    for i, (x, t, ln) in enumerate(((0, 0, 0.5), (0.27, 9, 0.56), (0.53, 19, 0.66), (0.76, 33, 0.78), (0.9, 54, 0.78), (0.94, 80, 0.64))):
        a, b = math.radians(t), math.radians(t + 12)
        p0 = np.array([x, 0.24, 0.2])
        p1 = p0 + np.array([math.sin(a), math.cos(a), 0.2]) * ln * 0.6
        p2 = p1 + np.array([math.sin(b), math.cos(b), 0.34]) * ln * 0.3
        o = MID if x == 0 else B
        c = (base, light)[i % 2]
        k.rod("can", p0, p1, 0.22, c, over=0.06, **o)
        k.rod("can", p1, p2, 0.19, c, over=0.06, **o)
        k.rod("can", p2, p2 + unit(p2 - p1) * 0.2, 0.28, tip, over=0.04, **o)
    for x, t in ((0.62, 24),):  # a short arm behind each side
        a = math.radians(t)
        p = np.array([x, 0.22, 0.36])
        q = p + np.array([math.sin(a), math.cos(a), 0.7]) * 0.26
        k.rod("can", p, q, 0.17, light, **B)
        k.rod("can", q, q + unit(q - p) * 0.14, 0.22, tip, **B)
    k.put("pom", "cylinder", (0, 0.12, -0.3), (0.28, 0.6, 0.6), pur, r=(0, 0, 90))
    for x, h in ((0, 0.5), (0.17, 0.42)):
        o = {} if x == 0 else B
        k.rod("pom", (x, 0.2, -0.3), (x * 1.7, h, -0.35), 0.17, base if x == 0 else light, **o)
        k.rod("pom", (x * 1.7, h - 0.02, -0.35), (x * 1.95, h + 0.13, -0.37), 0.22, tip, **o)
    k.star("flap", 0.48, 0.03, 0.55, 0.62, base, 4, 0.12, 0.24)
    k.star("flap", 0.48, 0.08, 0.55, 0.36, light, 2, 0.12, 0.3)
    k.box("flap", (0.48, 0.15, 0.55), (0.18, 0.12, 0.18), tip, (0, 45, 0))
    return {"main": "#5cc4bb", "flap": "#43a9a3", "trim": "#f3cf8a", "cushion": "#e87d94", "cushion2": "#f097aa", "strap": "#8063c9", "pieces": k.p}


def crown():
    """3: the first tall one: two kelp stalks either side, a fan of leaves between."""
    k = Kit()
    g, lime, dk, stem, yel, wood, rope = "#2f9450", "#86cf5b", "#1c6038", "#39502a", "#f0cf5e", "#a37d3c", "#d9bd7a"
    k.put("can", "cylinder", (0, 0.2, 0.18), (2.1, 0.38, 0.38), wood)
    k.put("can", "cylinder", (1.06, 0.2, 0.18), (0.06, 0.28, 0.28), "#e0c48a", **B)
    for x in (0.34, 0.86):
        k.put("can", "cylinder", (x, 0.2, 0.18), (0.16, 0.44, 0.44), rope, **B)
    path = [(0.98, 0.3, 0.2), (1.18, 0.58, 0.22), (1.3, 0.86, 0.26), (1.32, 1.14, 0.34)]  # the stalks
    k.chain("can", path, (0.2, 0.17, 0.14), (stem, stem, stem), **B)
    for i, s in enumerate((0.5, 1.4, 2.3)):
        j = int(s)
        q = np.array(path[j]) + (np.array(path[j + 1]) - np.array(path[j])) * (s - j)
        out = 1 if i % 2 else -1
        ln = (0.44, 0.7, 0.5)[i]
        k.leaf("can", q, q + np.array([0.82 * out, 0.56, 0.12]) * ln, 0.3 - 0.02 * i, (g, lime)[i % 2], d=0.1, **B)
        if i != 1:
            k.box("can", q + np.array([0.13 * -out, 0.0, 0.08]), (0.22, 0.22, 0.22), yel, (0, 45, 0), **B)
    k.leaf("can", path[-1], np.array(path[-1]) + [0.04, 0.54, 0.12], 0.3, lime, d=0.1, vein=g, **B)
    for i, (x, t, ln) in enumerate(((0, 0, 0.56), (0.3, 18, 0.6), (0.62, 40, 0.62))):  # the fan between them
        r = math.radians(t)
        p = np.array([x, 0.24, 0.24 + 0.06 * (i % 2)])
        k.leaf("can", p, p + np.array([math.sin(r), math.cos(r), 0.34]) * ln, 0.36, (lime, g)[i % 2], d=0.1, vein=(g, dk)[i % 2], **(MID if x == 0 else B))
    k.put("pom", "cylinder", (0, 0.16, -0.28), (0.78, 0.3, 0.3), wood)
    k.put("pom", "ball", (0, 0.48, -0.3), (0.42, 0.42, 0.42), yel)
    for t in (0, 120, 240):
        a = math.radians(t)
        k.spike("pom", (0.14 * math.sin(a), 0.24, -0.3 - 0.14 * math.cos(a)), (0.42 * math.sin(a), 0.56, -0.3 - 0.36 * math.cos(a)), 0.24, lime, d=0.08)
    for z, c, y in ((0.34, lime, 8), (0.72, g, -8)):
        k.box("flap", (0.5, 0.04, z), (0.94, 0.12, 0.24), c, (0, y, 0))
        k.box("flap", (0.5, 0.09, z), (0.74, 0.08, 0.06), dk, (0, y, 0))
    k.box("flap", (0.16, 0.12, 0.54), (0.24, 0.2, 0.24), yel, (0, 45, 0))
    k.box("low", (0.42, 0.04, 0.5), (0.8, 0.1, 0.22), lime, (0, -6, 0))
    return {"main": "#2a7d45", "flap": "#226a3b", "trim": "#d7b552", "cushion": "#8a6a2a", "cushion2": "#a37d3c", "strap": rope, "pieces": k.p}


def wheel():
    """4: the first that shines: a ship's wheel on a carved board, two lit lamps."""
    k = Kit()
    wood, light, dark, gold, iron, rope, lamp = "#9c6a3a", "#b98450", "#63401f", "#e6b840", "#37414d", "#dcc794", "#ffd75a"
    k.box("can", (0, 0.1, 0.12), (2.0, 0.22, 0.34), dark)
    k.box("can", (0, 0.24, 0.14), (1.7, 0.12, 0.28), wood)
    k.box("can", (0, 0.1, 0.31), (2.04, 0.08, 0.06), gold)
    cy, rad, z = 0.8, 0.62, 0.3
    for i in range(8):  # the rim
        a = math.radians(i * 45 + 22.5)
        k.box("can", (math.sin(a) * rad, cy + math.cos(a) * rad, z), (0.56, 0.17, 0.2), wood, (0, 0, -i * 45 - 22.5), **MID)
        k.box("can", (math.sin(a) * (rad - 0.01), cy + math.cos(a) * (rad - 0.01), z + 0.1), (0.4, 0.07, 0.05), gold, (0, 0, -i * 45 - 22.5), **MID)
    for i in range(8):  # the spokes and their handles
        a = math.radians(i * 45)
        s, c = math.sin(a), math.cos(a)
        if i < 4:
            k.box("can", (0, cy, z), (0.11, 1.24, 0.11), light, (0, 0, -i * 45), **MID)
        k.rod("can", (s * 0.7, cy + c * 0.7, z), (s * 0.82, cy + c * 0.82, z), 0.1, dark, **MID)
        k.rod("can", (s * 0.8, cy + c * 0.8, z), (s * 0.98, cy + c * 0.98, z), 0.16, gold if i % 2 == 0 else light, **MID)
    k.put("can", "cylinder", (0, cy, z + 0.04), (0.2, 0.4, 0.4), dark, r=(0, 90, 0), **MID)
    k.put("can", "cylinder", (0, cy, z + 0.1), (0.2, 0.24, 0.24), gold, r=(0, 90, 0), **MID)
    # the lamps: a post, a cage, a light
    x = 1.22
    k.box("can", (x - 0.14, 0.16, 0.24), (0.5, 0.2, 0.5), dark, **B)
    k.box("can", (x, 0.55, 0.34), (0.18, 0.7, 0.18), wood, **B)
    k.box("can", (x, 0.42, 0.34), (0.26, 0.08, 0.26), gold, **B)
    k.box("can", (x, 0.92, 0.34), (0.5, 0.1, 0.5), iron, **B)
    k.box("can", (x, 1.15, 0.34), (0.3, 0.38, 0.3), lamp, n=True, **B)
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.box("can", (x + 0.2 * sx, 1.15, 0.34 + 0.2 * sz), (0.07, 0.4, 0.07), iron, **B)
    k.box("can", (x, 1.39, 0.34), (0.54, 0.1, 0.54), iron, **B)
    k.box("can", (x, 1.49, 0.34), (0.34, 0.12, 0.34), gold, **B)
    k.box("can", (x, 1.62, 0.34), (0.14, 0.16, 0.34), gold, (0, 45, 0), **B)
    # the horn: a coil of rope with a compass in it
    k.box("pom", (0, 0.08, -0.3), (0.9, 0.18, 0.5), dark)
    for y, w, c in ((0.22, 0.62, rope), (0.33, 0.58, "#c4ab72"), (0.44, 0.62, rope)):
        k.put("pom", "cylinder", (0, y, -0.3), (0.11, w, w), c, r=(0, 0, 90))
    k.put("pom", "cylinder", (0, 0.52, -0.3), (0.08, 0.46, 0.46), gold, r=(0, 0, 90))
    k.put("pom", "cylinder", (0, 0.56, -0.3), (0.06, 0.34, 0.34), "#f4efe0", r=(0, 0, 90))
    k.box("pom", (0, 0.6, -0.3), (0.06, 0.04, 0.28), "#b3382f", (0, 25, 0))
    # an anchor on each side
    k.box("flap", (0.46, 0.05, 0.55), (0.78, 0.12, 0.13), gold)
    k.box("flap", (0.22, 0.05, 0.55), (0.12, 0.12, 0.46), gold)
    k.box("flap", (0.07, 0.05, 0.55), (0.22, 0.12, 0.22), gold, (0, 45, 0))
    k.box("flap", (0.07, 0.09, 0.55), (0.1, 0.1, 0.1), "#1e3f50", (0, 45, 0))
    k.box("flap", (0.8, 0.05, 0.71), (0.14, 0.12, 0.42), gold, (0, 38, 0))
    k.box("flap", (0.8, 0.05, 0.39), (0.14, 0.12, 0.42), gold, (0, -38, 0))
    k.box("low", (0.3, 0.04, 0.5), (0.12, 0.12, 0.9), rope)
    k.box("low", (0.46, 0.04, 0.5), (0.12, 0.12, 0.9), "#c4ab72")
    return {"main": "#1f4f63", "flap": "#1e3f50", "trim": gold, "cushion": "#8a2c36", "cushion2": "#a33c46", "strap": dark, "pieces": k.p}


def wave():
    """5: one wave from end to end: a low swell behind the rider that rises and curls over at both sides. Four blues
    and the foam lie in the same order everywhere: deep in the middle, foam on the crest; the horn and the panels too."""
    k = Kit()
    deep, mid_, light, pale, foam = "#174f96", "#2277bd", "#47a9df", "#8fe9ff", "#f4fbff"
    crest = [(0, 0.5), (0.34, 0.5), (0.66, 0.6), (0.92, 0.84), (1.08, 1.18), (1.3, 1.5), (1.64, 1.66), (1.98, 1.54), (2.14, 1.24), (2.02, 0.98), (1.78, 0.96)]
    P = [np.array(q, float) for q in crest]
    n = []
    for i in range(len(P)):  # the side the water is on
        d = unit(P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)])
        n.append(np.array([d[1], -d[0]]))
    thick = [0.2, 0.2, 0.22, 0.26, 0.3, 0.32, 0.3, 0.25, 0.19, 0.14, 0.1]  # (each band, thinner round the curl)
    lean = lambda q: np.array([q[0], q[1] + 0.06, 0.14 + 0.16 * q[1]])  # noqa: E731
    for band, (c, d, last) in enumerate(((foam, 0.46, 10), (pale, 0.4, 9), (light, 0.35, 8), (mid_, 0.3, 6))):
        for i in range(last):
            a = P[i] + n[i] * thick[i] * (band * 0.62)
            b = P[i + 1] + n[i + 1] * thick[i + 1] * (band * 0.62)
            if a[1] < 0.06 and b[1] < 0.06:
                continue
            w = (thick[i] + thick[i + 1]) / 2 * 0.74
            k.rod("can", lean(a), lean(b), w, c, d=d, over=0.1, n=band == 1 and i > 2, both=True, mid=i == 0)
    k.box("can", (0, 0.13, 0.16), (2.0, 0.28, 0.36), deep)
    k.box("can", (1.0, 0.42, 0.2), (0.42, 0.6, 0.3), deep, (0, 0, -14), **B)
    k.box("can", (1.16, 0.74, 0.25), (0.34, 0.5, 0.27), deep, (0, 0, -20), **B)
    for x, y, s in ((2.34, 1.62, 0.2), (2.16, 1.86, 0.14)):  # spray off the curl
        k.box("can", (x, y, 0.42), (s, s, s), foam, (0, 0, 20), **B)
    k.box("pom", (0, 0.1, -0.24), (0.9, 0.22, 0.42), deep)
    prof = [(-0.12, 0.2), (-0.18, 0.48), (-0.34, 0.68), (-0.56, 0.68), (-0.66, 0.5)]
    for band, (c, w, last) in enumerate(((foam, 0.84, 4), (light, 0.78, 3), (mid_, 0.72, 2))):
        for i in range(last):
            z0, y0 = prof[i]
            z1, y1 = prof[i + 1]
            o = band * 0.1
            k.rod("pom", (0, y0 - o * (i > 0), z0 - o), (0, y1 - o, z1 - o * (i < 2)), w, c, d=0.13, over=0.08)
    for i, (u, c) in enumerate(zip((0.2, 0.4, 0.6, 0.8), (deep, light, pale, foam))):
        k.box("flap", (u, 0.03, 0.52), (0.2, 0.12 + 0.03 * i, 0.94), c, (0, 8, 0))
    k.box("flap", (0.7, 0.04, 0.3), (0.16, 0.17, 0.16), foam, (0, 45, 0))
    k.box("flap", (0.7, 0.04, 0.76), (0.16, 0.17, 0.16), foam, (0, 45, 0))
    for u, c in ((0.28, light), (0.5, pale)):
        k.box("low", (u, 0.03, 0.52), (0.18, 0.12, 0.9), c, (0, 8, 0))
    return {"main": mid_, "flap": "#1c66aa", "trim": foam, "cushion": "#123f78", "cushion2": deep, "strap": pale, "pieces": k.p}


def throne():
    """6: a throne of crystals in a fan, tallest at the sides, its hearts alight."""
    k = Kit()
    ice, pale, vio, dvio, dk, snow = "#6df0e6", "#d8fbff", "#a08ff2", "#7a66d6", "#4a4690", "#ffffff"
    k.box("can", (0, 0.12, 0.16), (1.0, 0.26, 0.42), dk, **MID)
    k.box("can", (0.75, 0.12, 0.16), (0.5, 0.26, 0.41), dk, **B)  # (the halves stand alone where a fin comes between)
    k.box("can", (0, 0.26, 0.16), (1.0, 0.12, 0.36), snow, **MID)
    k.box("can", (0.7, 0.26, 0.16), (0.42, 0.12, 0.35), snow, **B)
    fan = ((0, 0, 0.64, 0.36, pale, ice, False), (0.34, 8, 0.9, 0.34, vio, pale, False), (0.66, 15, 1.36, 0.38, ice, pale, True),
           (0.96, 21, 2.12, 0.46, vio, pale, False), (1.18, 38, 1.6, 0.38, ice, pale, True), (1.22, 58, 1.12, 0.32, dvio, pale, False))
    for x, t, ln, w, c, cap, n in fan:
        r = math.radians(t)
        p = np.array([x, 0.18, 0.2])
        d = np.array([math.sin(r), math.cos(r), 0.22])
        k.crystal("can", p, p + d * ln, w, c, cap, n=n, tip=0.32, **(MID if x == 0 else dict(B, mid=x < 0.5)))
        if not n and x:  # a bright edge down the dull ones
            k.rod("can", p + d * ln * 0.2 + [0, 0, w * 0.66], p + d * ln * 0.64 + [0, 0, w * 0.66], 0.07, ice, d=0.07, both=True, mid=x < 0.5)
    for x, t, ln, w, c in ((0.2, 8, 0.44, 0.24, dvio), (0.6, 22, 0.54, 0.26, dvio), (1.04, 50, 0.6, 0.26, dvio)):  # the short row behind
        r = math.radians(t)
        p = np.array([x, 0.14, 0.44])
        k.crystal("can", p, p + np.array([math.sin(r), math.cos(r), 0.5]) * ln, w, c, vio, tip=0.4, both=True, mid=x < 0.5)
    k.box("pom", (0, 0.1, -0.3), (0.9, 0.22, 0.5), dk)
    k.box("pom", (0, 0.22, -0.3), (0.74, 0.1, 0.4), snow)
    k.crystal("pom", (0, 0.2, -0.32), (0, 0.8, -0.46), 0.3, ice, pale, n=True)
    k.crystal("pom", (0.22, 0.2, -0.32), (0.44, 0.58, -0.42), 0.24, vio, pale, **B)
    k.crystal("pom", (0.1, 0.2, -0.46), (0.16, 0.44, -0.7), 0.18, pale, snow, **B)
    for u, z, s in ((0.42, 0.5, 1.0), (0.66, 0.82, 0.66), (0.24, 0.8, 0.5)):
        k.box("flap", (u, 0.03, z), (0.56 * s, 0.1, 0.56 * s), dvio, (0, 45, 0))
        k.box("flap", (u, 0.08, z), (0.4 * s, 0.14, 0.4 * s), vio, (0, 45, 0))
        k.box("flap", (u, 0.15, z), (0.24 * s, 0.16, 0.24 * s), ice, (0, 45, 0), n=True)
    k.box("low", (0.42, 0.03, 0.56), (0.42, 0.1, 0.42), dvio, (0, 45, 0))
    k.box("low", (0.42, 0.08, 0.56), (0.24, 0.14, 0.24), ice, (0, 45, 0), n=True)
    for u, z, s in ((0.8, 0.3, 0.4), (0.14, 0.24, 0.36)):
        k.box("flap", (u, 0.04, z), (0.56 * s, 0.12, 0.56 * s), vio, (0, 45, 0))
        k.box("flap", (u, 0.1, z), (0.3 * s, 0.14, 0.3 * s), ice, (0, 45, 0), n=True)
    return {"main": "#8f89d8", "flap": "#736cc4", "trim": pale, "cushion": "#34316a", "cushion2": "#474488", "strap": pale, "pieces": k.p}


def jelly():
    """7: two lit jellyfish swim beside the rider on their own arms."""
    k = Kit()
    bell, deep, pale, glow, dk, pink, hot = "#7482f2", "#4b57cf", "#cfd6ff", "#64fffd", "#131a48", "#ff8fdc", "#ffc4f0"
    k.box("can", (0, 0.12, 0.16), (2.0, 0.26, 0.4), dk)
    k.box("can", (0, 0.28, 0.18), (1.7, 0.12, 0.32), deep)
    for x in (0, 0.34, 0.68):
        k.box("can", (x, 0.28, 0.36), (0.16, 0.16, 0.1), glow, (0, 0, 45), n=True, **(MID if x == 0 else B))
    # the bells: a rim, a glowing skirt, a stepped dome, a heart inside
    cx, cy, cz = 1.62, 1.7, 0.66
    up = unit((0.2, 1, 0.06))
    at = lambda h: np.array([cx, cy, cz]) + up * h  # noqa: E731
    ax = np.column_stack([up, unit(np.cross((0, 0, 1), up)), np.cross(up, unit(np.cross((0, 0, 1), up)))])
    for h, t, w, c, n in ((-0.02, 0.14, 1.0, deep, False), (0.02, 0.14, 1.12, glow, True), (0.14, 0.18, 0.95, bell, False), (0.3, 0.18, 0.8, bell, False), (0.45, 0.14, 0.58, "#97a2fa", False), (0.55, 0.14, 0.4, glow, True), (-0.13, 0.14, 0.7, pink, True)):
        k.put("can", "cylinder", at(h), (t, w, w), c, m=ax, n=n, **B)
    for t in range(0, 360, 90):  # spots round the dome
        a = math.radians(t + 30)
        o = ax[:, 1] * math.cos(a) + ax[:, 2] * math.sin(a)
        k.rod("can", at(0.16) + o * 0.43, at(0.16) + o * 0.52, 0.16, pale, back=up, **B)
    # its arms: two long ones that root in the saddle, four that trail
    for i, (dx, dz, ln) in enumerate(((-0.28, 0.0, 0), (0.1, 0.08, 0), (0.36, 0.1, 1.0), (0.0, 0.4, 1.15), (0.28, 0.4, 0.95), (-0.28, 0.32, 0.8))):
        top = np.array([cx + dx, cy - 0.12, cz + dz * 0.6])
        if ln == 0:
            foot = np.array([0.96 + dx * 0.3, 0.26, 0.24 + dz])
            m0, m1 = foot + (top - foot) * 0.34 + np.array([0.16, -0.04, 0.0]), foot + (top - foot) * 0.68 + np.array([-0.04, 0.0, 0.08])
            k.chain("can", [foot, m0, m1, top], (0.2, 0.17, 0.14), (dk, deep, bell), **B)
        else:
            pts = [top, top + np.array([0.1, -0.34 * ln, 0.14]), top + np.array([-0.02, -0.66 * ln, 0.38]), top + np.array([0.1, -0.86 * ln, 0.66])]
            k.chain("can", pts[:3], (0.14, 0.11), (pink, pink), **B)
            k.rod("can", pts[2], pts[3], 0.1, hot, over=0.03, n=True, **B)
            k.box("can", pts[-1], (0.17, 0.17, 0.17), glow, (45, 35, 0), n=True, **B)
    # the horn: a small one
    k.box("pom", (0, 0.1, -0.3), (0.86, 0.22, 0.46), dk)
    k.rod("pom", (0, 0.18, -0.3), (0, 0.5, -0.34), 0.16, deep)
    for h, t, w, c, n in ((0.5, 0.08, 0.7, glow, True), (0.58, 0.14, 0.64, bell, False), (0.7, 0.12, 0.44, "#97a2fa", False), (0.78, 0.08, 0.22, pale, False)):
        k.put("pom", "cylinder", (0, h, -0.34), (t, w, w), c, r=(0, 0, 90), n=n)
    for x, z in ((0.22, -0.2), (0.2, -0.5)):
        k.chain("pom", [(x, 0.46, z - 0.02), (x + 0.06, 0.32, z), (x, 0.2, z)], (0.1, 0.09), (pink, pink), **B)
    # a jelly and its bubbles on each panel
    k.box("flap", (0.34, 0.04, 0.5), (0.34, 0.12, 0.62), bell)
    k.box("flap", (0.22, 0.04, 0.5), (0.3, 0.14, 0.42), "#97a2fa")
    k.box("flap", (0.5, 0.06, 0.5), (0.08, 0.14, 0.7), glow, n=True)
    for z in (0.34, 0.5, 0.66):
        k.box("flap", (0.72, 0.03, z), (0.4, 0.1, 0.08), pink, (0, (z - 0.5) * 60, 0))
    for u, z, s in ((0.2, 0.86, 0.18), (0.45, 0.92, 0.12), (0.7, 0.86, 0.15), (0.3, 0.12, 0.14)):
        k.box("flap", (u, 0.05, z), (s, 0.12, s), glow, (0, 45, 0), n=True)
    k.box("low", (0.3, 0.04, 0.5), (0.12, 0.1, 0.8), bell)
    k.box("low", (0.44, 0.04, 0.5), (0.06, 0.1, 0.8), glow, n=True)
    return {"main": "#34429e", "flap": "#27327e", "trim": pink, "cushion": "#131a48", "cushion2": "#202a66", "strap": bell, "pieces": k.p}


def vents():
    """8: two chimneys of rock, split by lava, fire out of their tops."""
    k = Kit()
    rock, mid, dk, lava, hot = "#4c3a40", "#5f4a50", "#1b1418", "#ff6a1a", "#ffd836"
    k.box("can", (0, 0.13, 0.18), (2.1, 0.28, 0.44), dk)
    k.box("can", (0, 0.28, 0.4), (1.5, 0.1, 0.06), lava, n=True)
    # broken columns between the chimneys
    for i, (x, h) in enumerate(((0, 0.28), (0.3, 0.4), (0.6, 0.34), (0.86, 0.5))):
        o = MID if x == 0 else B
        k.box("can", (x, 0.3 + h / 2, 0.2 + 0.06 * (i % 2)), (0.34, h, 0.34), (rock, dk, mid, rock)[i], (0, 45 * (i % 2), 0), **o)
        k.box("can", (x, 0.32 + h, 0.2 + 0.06 * (i % 2)), (0.2, 0.08, 0.2), (lava, hot)[i % 2], (0, 45 * (i % 2), 0), n=True, **o)
    # the chimneys
    foot, dr = np.array([1.26, 0.1, 0.46]), unit((0.28, 1, 0.08))
    at = lambda h: foot + dr * h  # noqa: E731
    for h, t, w, c, tw in ((0.2, 0.4, 0.94, dk, 10), (0.56, 0.34, 0.8, rock, 30), (0.94, 0.34, 0.68, mid, 0), (1.3, 0.34, 0.56, rock, 22), (1.62, 0.28, 0.64, dk, 5)):
        k.rock("can", at(h), w, t, c, dr, tw, **B)
    for h, w, c in ((0.75, 0.68, lava), (1.12, 0.57, lava), (1.47, 0.48, hot)):
        k.rock("can", at(h), w, 0.1, c, dr, 15, n=True, **B)
    k.rock("can", at(1.78), 0.46, 0.08, hot, dr, 5, n=True, **B)
    # lava down each chimney's back, and a pool at its foot
    b = np.array([0, 0, 1.0])
    k.chain("can", [at(1.7) + b * 0.33, at(1.2) + b * 0.32, at(0.7) + b * 0.4 + [0.06, 0, 0], at(0.12) + b * 0.48], (0.16, 0.2, 0.26), (hot, lava, lava), d=0.1, n=True, **B)
    k.box("can", at(0.04) + b * 0.5, (0.46, 0.12, 0.2), lava, n=True, **B)
    # fire out of each, and sparks
    m = at(1.76)
    k.spike("can", m + [0, -0.02, 0], m + [0.22, 0.98, 0.16], 0.4, lava, d=0.3, n=True, **B)
    k.spike("can", m + [0.04, 0, 0.12], m + [0.1, 0.66, 0.26], 0.26, hot, d=0.16, n=True, **B)
    k.spike("can", m + [0.12, 0, 0.0], m + [0.52, 0.6, 0.1], 0.24, lava, d=0.2, n=True, **B)
    k.spike("can", m + [-0.1, 0, 0.02], m + [-0.12, 0.54, 0.1], 0.22, lava, d=0.2, n=True, **B)
    for p, s in (((1.56, 2.56, 0.6), 0.13), ((2.3, 2.2, 0.6), 0.14)):
        k.box("can", p, (s, s, s), hot, (45, 35, 0), n=True, **B)
    # spikes of rock outside each chimney
    k.spike("can", (1.66, 0.14, 0.46), (2.16, 0.72, 0.58), 0.36, dk, **B)

    # the horn: three claws of rock round a hot heart
    k.box("pom", (0, 0.12, -0.3), (0.9, 0.26, 0.5), dk)
    k.box("pom", (0, 0.4, -0.34), (0.3, 0.3, 0.3), hot, (45, 35, 0), n=True)
    k.box("pom", (0, 0.24, -0.34), (0.5, 0.08, 0.4), lava, n=True)
    k.chain("pom", [(0.34, 0.2, -0.3), (0.4, 0.48, -0.36)], (0.2,), (rock,), **B)
    k.spike("pom", (0.4, 0.46, -0.36), (0.2, 0.8, -0.46), 0.2, dk, **B)
    k.spike("pom", (0, 0.2, -0.56), (0, 0.72, -0.56), 0.24, rock)
    # cracks of lava on each panel, plates of rock between
    for u, z, s, t in ((0.26, 0.3, 0.42, 15), (0.3, 0.78, 0.46, -20), (0.72, 0.52, 0.5, 35)):
        k.box("flap", (u, 0.05, z), (s, 0.16, s), rock, (0, t, 0))
        k.box("flap", (u, 0.11, z), (s * 0.6, 0.12, s * 0.6), dk, (0, t + 20, 0))
    k.box("flap", (0.3, 0.04, 0.54), (0.7, 0.1, 0.09), lava, (0, 20, 0), n=True)
    k.box("flap", (0.66, 0.04, 0.84), (0.6, 0.1, 0.08), hot, (0, -35, 0), n=True)
    k.box("flap", (0.66, 0.04, 0.22), (0.5, 0.1, 0.08), lava, (0, 40, 0), n=True)
    k.box("low", (0.42, 0.05, 0.4), (0.4, 0.14, 0.4), rock, (0, 25, 0))
    k.box("low", (0.42, 0.04, 0.72), (0.6, 0.1, 0.08), lava, (0, -20, 0), n=True)
    return {"main": "#33262b", "flap": "#281d22", "trim": "#c2401f", "cushion": "#17121a", "cushion2": "#2a2128", "strap": "#c2401f", "pieces": k.p}


def skull():
    """9: a horned sea beast's skull looks back over the saddle, ghost fire standing up on both sides of the rider."""
    k = Kit()
    bone, pale, old, dk, glow, ghost = "#e6dbbd", "#faf5e4", "#ab9c74", "#18211b", "#8dffc6", "#24d488"
    k.box("can", (0, 0.1, 0.16), (2.1, 0.22, 0.42), old)
    k.box("can", (0, 0.23, 0.16), (1.9, 0.08, 0.38), ghost, n=True)
    # the skull (it faces the camera): its face is at z 0.7
    k.box("can", (0, 0.99, 0.38), (1.14, 0.54, 0.6), bone, **MID)
    k.box("can", (0, 1.28, 0.34), (0.86, 0.12, 0.5), pale, **MID)
    k.box("can", (0, 0.62, 0.4), (0.92, 0.3, 0.54), bone, **MID)
    k.box("can", (0.31, 0.88, 0.66), (0.38, 0.32, 0.1), dk, (0, 0, -10), both=True, mid=True)
    k.box("can", (0.31, 0.87, 0.7), (0.24, 0.18, 0.08), glow, (0, 0, -10), n=True, both=True, mid=True)
    k.box("can", (0.33, 1.1, 0.7), (0.56, 0.15, 0.16), pale, (0, 0, -18), both=True, mid=True)
    k.box("can", (0, 0.98, 0.7), (0.15, 0.4, 0.12), bone, **MID)
    k.spike("can", (0, 0.58, 0.68), (0, 0.78, 0.68), 0.26, dk, d=0.1, **MID)
    k.box("can", (0.5, 0.64, 0.42), (0.22, 0.34, 0.5), old, (0, 0, 14), both=True, mid=True)
    k.box("can", (0, 0.45, 0.46), (0.84, 0.12, 0.54), dk, **MID)
    for x in (0.1, 0.28):
        k.spike("can", (x, 0.5, 0.66), (x, 0.28, 0.7), 0.16, pale, d=0.12, both=True, mid=True)
    k.box("can", (0, 0.28, 0.44), (0.76, 0.16, 0.5), bone, **MID)
    # the great horns, out and up past the shoulders, ringed, their points alight
    path = [(0.6, 1.1, 0.3), (1.06, 1.16, 0.28), (1.5, 1.42, 0.32), (1.8, 1.9, 0.4), (1.86, 2.46, 0.5)]
    k.chain("can", path, (0.44, 0.38, 0.31, 0.25), (old, bone, bone, bone), **B)
    k.spike("can", (1.86, 2.4, 0.48), (1.6, 3.3, 0.66), 0.27, glow, n=True, **B)
    for i in (1, 2, 3):
        a, b = np.array(path[i]), np.array(path[i + 1])
        k.rod("can", a, a + (b - a) * 0.24, (0.46, 0.39, 0.31)[i - 1], old, **B)
        k.rod("can", a + (b - a) * 0.5, a + (b - a) * 0.6, (0.42, 0.35, 0.28)[i - 1], ghost, n=True, **B)
    k.rod("can", (1.0, 0.18, 0.28), (0.86, 1.1, 0.34), 0.28, old, **B)  # (they stand on the saddle too)
    k.spike("can", (0.44, 1.3, 0.3), (0.66, 1.72, 0.4), 0.24, bone, both=True, mid=True)  # the small ones
    # ghost fire
    for p0, p1, w, c in (((1.06, 0.2, 0.34), (1.3, 1.12, 0.5), 0.38, ghost), ((1.3, 0.16, 0.3), (1.86, 1.02, 0.46), 0.36, ghost), ((1.42, 0.12, 0.34), (2.2, 0.56, 0.5), 0.3, ghost), ((1.36, 0.2, 0.26), (1.96, 1.5, 0.4), 0.36, ghost),
                         ((1.1, 0.2, 0.46), (1.28, 0.74, 0.58), 0.22, glow), ((1.34, 0.16, 0.42), (1.7, 0.66, 0.54), 0.2, glow)):
        k.spike("can", p0, p1, w, c, d=0.12, n=True, **B)
    k.spike("can", (0.2, 1.34, 0.22), (0.26, 1.6, 0.32), 0.24, ghost, d=0.12, n=True, both=True, mid=True)
    k.spike("can", (0, 1.36, 0.2), (0, 1.74, 0.32), 0.28, ghost, d=0.12, n=True, **MID)
    k.spike("can", (0, 1.36, 0.3), (0, 1.58, 0.4), 0.16, glow, d=0.1, n=True, **MID)
    for p, s in (((2.1, 1.3, 0.5), 0.18), ((2.2, 1.9, 0.4), 0.13), ((1.34, 2.1, 0.44), 0.15)):
        k.box("can", p, (s, s, s), glow, (45, 35, 0), n=True, **B)
    # the horn of the saddle: a hand of bone holding a ghost light
    k.box("pom", (0, 0.1, -0.3), (0.84, 0.22, 0.46), old)
    k.box("pom", (0, 0.5, -0.36), (0.32, 0.32, 0.32), glow, (45, 35, 0), n=True)
    k.box("pom", (0, 0.24, -0.34), (0.42, 0.14, 0.34), bone)
    for x, z in ((0.2, -0.5), (0.24, -0.22)):
        k.rod("pom", (x, 0.26, z), (x + 0.1, 0.5, z * 1.04), 0.13, bone, over=0.04, **B)
        k.spike("pom", (x + 0.1, 0.48, z * 1.04), (x - 0.04, 0.78, z), 0.13, pale, **B)
    # ribs down each side off a backbone, ghost light between
    for i, z in enumerate((0.2, 0.55, 0.9)):
        k.box("flap", (0.5, 0.06, z), (0.96, 0.18, 0.15), bone if i % 2 == 0 else pale)
        k.box("flap", (0.08, 0.1, z), (0.2, 0.24, 0.24), old)
        k.box("low", (0.36, 0.05, z), (0.66, 0.16, 0.12), bone if i % 2 == 0 else pale)
    for z in (0.38, 0.73):
        k.box("flap", (0.46, 0.03, z), (0.62, 0.1, 0.09), ghost, n=True)
    return {"main": "#34432f", "flap": "#293725", "trim": ghost, "trimneon": True, "cushion": "#1f2a22", "cushion2": "#2c3a2f", "strap": bone, "pieces": k.p}


def portal():
    """10: the gate itself, standing open round the rider."""
    k = Kit()
    vio, lil, dk, black, cy, star_, pinkish = "#4a2fd0", "#a79fff", "#1c0f5c", "#0e0630", "#64fffd", "#f1fdff", "#c25cff"
    k.box("can", (0, 0.12, 0.2), (2.1, 0.26, 0.5), black)
    k.box("can", (0, 0.28, 0.2), (1.8, 0.08, 0.4), cy, n=True)
    k.box("can", (0, 0.34, 0.2), (1.5, 0.1, 0.34), dk)
    cx, rad, z = 1.86, 1.96, 0.58  # (the ring's middle, its size)

    def on(t, r, dz=0.0):
        a = math.radians(t)
        return np.array([math.sin(a) * r, cx + math.cos(a) * r, z + dz])
    # the ring: twelve stones, a lit inner edge, a lit line on the side the camera sees; the stone at the top is the key
    for i in range(1, 6):
        t = i * 30
        big = i % 2 == 1
        c = vio if big else dk
        k.box("can", on(t, rad), (0.96, 0.38 if big else 0.3, 0.42 if big else 0.36), c, (0, 0, -t), **B)
        k.box("can", on(t, rad - 0.2), (0.92, 0.14, 0.3), cy, (0, 0, -t), n=True, **B)
        k.box("can", on(t, rad + 0.02, 0.2), (0.5, 0.12, 0.08), cy if big else pinkish, (0, 0, -t), n=True, **B)
        if big:  # a horn outward, a clamp across
            k.spike("can", on(t, rad + 0.14), on(t + (4 if t < 90 else -4 if t > 90 else 0), rad + (0.8 if t == 90 else 0.62)), 0.36, lil, d=0.26, back=(0, 0, 1), **B)
            k.box("can", on(t - 13, rad), (0.14, 0.5, 0.48), black, (0, 0, -t + 13), **B)
            k.box("can", on(t + 13, rad), (0.14, 0.5, 0.48), black, (0, 0, -t - 13), **B)
    k.box("can", on(0, rad), (0.9, 0.34, 0.4), dk)
    k.box("can", on(0, rad - 0.2), (0.86, 0.1, 0.28), cy, n=True)
    # the key: a star of crystal in a crown
    k.box("can", on(0, rad + 0.16), (0.66, 0.44, 0.5), black, (0, 0, 0))
    k.box("can", on(0, rad + 0.24, 0.12), (0.4, 0.4, 0.4), cy, (45, 35, 0), n=True)
    k.spike("can", on(0, rad + 0.34), on(0, rad + 1.15), 0.42, cy, d=0.3, n=True)
    k.spike("can", on(7, rad + 0.28), on(16, rad + 0.84), 0.3, pinkish, d=0.2, n=True, **B)
    # the second ring: thin, broken, floating outside the first
    for t in (50, 60, 70, 110, 120, 130):
        k.box("can", on(t, rad + 0.5), (0.44, 0.1, 0.16), pinkish, (0, 0, -t), n=True, **B)
    # the gate's two feet
    k.box("can", (0.92, 0.3, 0.3), (0.6, 0.4, 0.56), dk, (0, 0, 24), **B)
    k.box("can", (1.22, 0.56, 0.36), (0.5, 0.5, 0.5), black, (0, 0, 40), **B)
    k.box("can", (1.2, 0.56, 0.62), (0.2, 0.2, 0.06), cy, (0, 0, 45), n=True, **B)
    k.spike("can", (1.3, 0.36, 0.44), (1.98, 0.2, 0.7), 0.34, vio, d=0.28, **B)
    # shards adrift round it
    for t, r, dz, s, c, n in ((20, 2.8, 0.2, 0.2, lil, False), (42, 2.82, 0.3, 0.28, cy, True), (76, 2.9, 0.2, 0.2, cy, True), (104, 2.9, 0.3, 0.24, lil, False)):
        p = on(t, r, dz)
        k.box("can", p, (s, s * 1.5, s), c, (20, t, -t), n=n, **B)
    # the horn: a star held over a small gate
    k.box("pom", (0, 0.1, -0.3), (0.88, 0.22, 0.48), black)
    k.box("pom", (0, 0.22, -0.3), (0.7, 0.07, 0.36), cy, n=True)
    k.box("pom", (0, 0.66, -0.36), (0.3, 0.3, 0.3), star_, (45, 35, 0), n=True)
    for s in (1, -1):
        k.spike("pom", (0, 0.66, -0.36), (0, 0.66 + 0.4 * s, -0.36), 0.16, cy, d=0.16, n=True)
    k.spike("pom", (0, 0.66, -0.36), (0.36, 0.66, -0.36), 0.16, cy, d=0.16, n=True, **B)
    k.chain("pom", [(0.3, 0.2, -0.32), (0.46, 0.42, -0.34)], (0.2,), (dk,), **B)
    k.spike("pom", (0.45, 0.4, -0.34), (0.4, 0.76, -0.38), 0.2, vio, **B)
    # a star gate on each panel
    for t in (0, 45):
        k.box("flap", (0.46, 0.03, 0.54), (0.6, 0.1, 0.6), dk, (0, t, 0))
    k.star("flap", 0.46, 0.08, 0.54, 0.66, vio, 4, 0.1, 0.22)
    k.star("flap", 0.46, 0.13, 0.54, 0.62, cy, 2, 0.1, 0.14, n=True)
    k.box("flap", (0.46, 0.19, 0.54), (0.22, 0.16, 0.22), star_, (0, 45, 0), n=True)
    for u, z, s in ((0.14, 0.16, 0.16), (0.82, 0.94, 0.18)):
        k.box("flap", (u, 0.05, z), (s, 0.14, s), lil, (0, 45, 0))
    k.star("low", 0.42, 0.04, 0.54, 0.46, vio, 2, 0.1, 0.24)
    k.star("low", 0.42, 0.09, 0.54, 0.44, cy, 2, 0.1, 0.14, n=True)
    return {"main": "#22107a", "flap": "#180a5c", "trim": cy, "trimneon": True, "cushion": "#0e0630", "cushion2": "#1c0f5c", "strap": vio, "pieces": k.p}
