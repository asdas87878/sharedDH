"""The saddles: two designs for each of the ten lands, as data, and the builder that puts one on a fish by its fit (fit.py).

    python tools/saddles/saddles.py     checks every design, counts parts and triangles, writes art/saddles/saddles.json

A design is a blanket (two colours and a trim), a cushion and a list of pieces, each hung on an anchor of the fit:
  pom   the pommel, ahead of the rider: origin (0, yf, -0.95), x right, y up, z back; sizes times min(grow, 1.15)
  can   the cantle, behind the rider: origin (0, yb, 0.74 to 0.95 where the pad has room), times min(grow, 1.2):
        the rider does not grow, so neither does what could hide them
  flap  the upper side panel: x down the panel as a share of its length, y out of it, z back as a share of its back half
  low   the lower side panel, the same;  hem: the side's free lower edge, x on down from it
A piece: (anchor, shape, (x, y, z), (size x, y, z), colour, options): `r` turn in degrees (Roblox's CFrame.Angles order),
`n` neon, `both` the mirror image too, `mid` it stands in the middle of the cantle (left out where a fin stands there).
Nothing here moves the seat: the rider's pocket (fit.POCKET_*, SEAT_TOP) is kept clear at every size."""
import json
import math
import os
import sys

import numpy as np

import fish as F
import fit as X

M = np.diag([-1.0, 1, 1, 1])
TRIS = {"box": 12, "wedge": 8, "cylinder": 72, "ball": 224}  # (Roblox's own low-detail meshes, about)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------- the builder (s2 ports this to Luau)

def build(design, fit, with_blanket=True):
    """the saddle's parts for a fit: [{shape, size, m (4x4 from the seat point), colour, neon, what}]"""
    out = []
    g, k = fit["grow"], min(fit["grow"], 1.4)
    main, flapc, trim, trimneon = design["main"], design.get("flap", design["main"]), design["trim"], design.get("trimneon", False)

    def put(what, shape, size, m, colour, neon=False):
        if min(size) > 0.015:
            out.append({"what": what, "shape": shape, "size": [float(v) for v in size], "m": np.array(m, float), "colour": rgb(colour), "neon": neon})

    def panel(fr):
        name, side, o, u, n, length, sink, rise, z0, z1 = fr
        m = np.eye(4)
        m[:3, 0], m[:3, 1], m[:3, 2] = u, n, np.cross(u, n)
        return m, o
    frs = X.frames(fit)
    last = {}
    for fr in frs:
        name, side, o, u, n, length, sink, rise, z0, z1 = fr
        m, _ = panel(fr)
        flip = 1.0 if m[2, 2] > 0 else -1.0
        c = o + u * length / 2 + n * (rise - sink) / 2 + np.array([0, 0, (z0 + z1) / 2])
        mm = m.copy()
        if flip < 0:
            mm[:3, 2] *= -1
            mm[:3, 0] *= -1
        mm[:3, 3] = c
        long = length + (0.06 if name != "pad" and name != "shelf" else 0)  # (a hinge's small overlap)
        colour = design.get("strap", trim) if name == "strap" else (main if name in ("pad", "shelf") else flapc)
        put(name, "box", (long, rise + sink, z1 - z0), mm, colour)
        if name in ("flap1", "flap2"):
            last[side] = (fr, mm)
        if name in ("pad", "shelf", "flap1", "flap2"):  # the hem along its front and back ends
            t = 0.16 * k
            for z in (z0 + t / 2 - 0.03, z1 - t / 2 + 0.03):
                e = mm.copy()
                e[:3, 3] = o + u * length / 2 + n * (rise + 0.045 - (rise + sink) / 2 + (rise + sink) / 2 - 0.12) + np.array([0, 0, z])
                put("trim", "box", (long + (0.04 if name == "pad" else 0.02), 0.24, t), e, trim, trimneon)
    for side, (fr, mm) in last.items():  # and along the lowest edge
        name, sd, o, u, n, length, sink, rise, z0, z1 = fr
        e = mm.copy()
        t = 0.16 * k
        e[:3, 3] = o + u * (length - t / 2 + 0.05) + n * (rise - 0.07) + np.array([0, 0, (z0 + z1) / 2])
        put("trim", "box", (t, 0.25, z1 - z0 + 0.08), e, trim, trimneon)
    if not last:  # no flaps: the hem runs along the pad's own sides
        for side in (-1, 1):
            t = 0.16 * k
            put("trim", "box", (t, 0.24, fit["front"] + fit["back"] + 0.06), F.move(side * (fit["half"] - t / 2 + 0.03), fit["top"] - 0.075, (fit["back"] - fit["front"]) / 2), trim, trimneon)
    # the cushion: the rider's own size, whatever the fish's
    if not fit["slot"] and SEAT(fit) - fit["top"] > 0.02:
        h = SEAT(fit) - fit["top"]
        z1 = min(0.7, fit["back"] - 0.06)
        z0 = max(-0.15, -fit["front"] + 0.04)
        w = min(1.5, 2 * fit["half"] - 0.08)
        put("cushion", "box", (w, h + 0.06, z1 - z0), F.move(0, fit["top"] + h / 2 - 0.03, (z0 + z1) / 2), design["cushion"])
        zf = max(-0.88, -fit["front"] + 0.08)
        if z0 - zf > 0.15:
            put("cushion", "box", (min(0.76, w), h + 0.03, z0 - zf + 0.05), F.move(0, fit["top"] + h / 2 - 0.03, (z0 + zf) / 2 + 0.025), design.get("cushion2", design["cushion"]))

    half = fit["half"]

    def anchor(a, side):
        if a == "pom":
            return F.move(0, fit["yf"], -X.POCKET_FRONT) if fit["pommel"] else None
        if a == "can":
            return F.move(0, fit["yb"], max(X.POCKET_BACK + 0.02, min(fit["back"] - 0.42, 0.95))) if fit["cantle"] != "none" else None
        return None

    for a, shape, p, size, colour, *opt in design["pieces"]:
        o = opt[0] if opt else {}
        for side in (1, -1) if o.get("both") or a in ("flap", "low", "hem") else (1,):
            turn = F.rot(*o.get("r", (0, 0, 0)))
            if a in ("pom", "can"):
                base = anchor(a, side)
                if base is None or (a == "can" and fit["cantle"] == "split" and o.get("mid")):
                    continue
                kk = min(k, 1.15) if a == "pom" else min(k, 1.2, max(0.64, fit["half"] + 0.25))
                local = F.move(*[v * kk for v in p]) @ turn
                sz = [v * kk for v in size]
                if side < 0:
                    local = M @ local @ M
                put(a, shape, sz, base @ local, colour, o.get("n", False))
                continue
            # on the side: the panel asked for; the upper one may fall back on a wide pad's own side
            fr = next((q for q in frs if q[1] == 1 and q[0] == ("flap1" if a == "flap" else "flap2")), None)
            if a == "hem":
                fr = next((q for q in reversed(frs) if q[1] == 1 and q[0] in ("flap2", "flap1")), None)
            if fr is None and a in ("flap", "hem") and half > 1.45 and not fit["slot"]:
                fr = ("pad", 1, np.array([max(1.0, half * 0.55), fit["base"], 0.0]), np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), half - max(1.0, half * 0.55), 0, fit["top"] - fit["base"], -fit["front"], fit["back"])
            if fr is None or fr[5] < 0.4:
                continue
            name, _, oo, u, n, length, sink, rise, z0, z1 = fr
            ks = min(k, length / 0.8, max(z1, 0.5) / 0.9)
            m = np.eye(4)
            m[:3, 0], m[:3, 1], m[:3, 2] = u, n, (0, 0, 1)
            along = length * p[0] if a != "hem" else length + p[0] * ks
            m[:3, 3] = oo + u * along + n * (rise + p[1] * ks) + np.array([0, 0, (z1 if p[2] >= 0 else -z0) * p[2]])
            local = m @ turn
            if side < 0:
                local = M @ local @ M
            put(a, shape, [v * ks for v in size], local, colour, o.get("n", False))
    return out


def SEAT(fit):
    return X.SEAT_TOP


def plain():
    """a fit with nothing in its way, for the pictures of a saddle alone"""
    return {"joint": "-", "grow": 1.25, "front": 1.6, "back": 1.45, "half": 0.95, "slot": 0.0, "top": 0.16, "base": 0.0, "pad": [0.12],
            "flaps": [[1.0, 42.0, 0.1, 0.16, -1.5, 1.35], [0.95, 74.0, 0.1, 0.16, -1.4, 1.25]], "strap": [0.85, 80.0, 0.06, 0.12, -0.25, 0.45],
            "cantle": "full", "style": "drape", "pommel": True, "yf": 0.16, "yb": 0.16, "shelf": None}


# ---------------------------------------------------------------- the designs

B = {"both": True}


def R(x=0, y=0, z=0, **kw):
    return {"r": (x, y, z), **kw}


def RB(x=0, y=0, z=0, **kw):
    return {"r": (x, y, z), "both": True, **kw}


def scallop():
    coral, pale, sand = "#f4835f", "#ffd9b8", "#f6e6bd"
    p = [("can", "box", (0, 0.1, 0.16), (1.1, 0.26, 0.36), "#d9674c"), ("can", "box", (0.72, 0.16, 0.16), (0.42, 0.34, 0.26), coral, RB(0, 0, 12))]
    for i, (a, ln, w, c) in enumerate(((0, 0.86, 0.34, coral), (21, 0.98, 0.38, pale), (42, 1.16, 0.44, coral), (63, 1.24, 0.46, pale))):
        o = R(0, 0, 0, mid=True) if a == 0 else RB(0, 0, -a)
        r = math.radians(a)
        z = 0.22 + 0.05 * (c == coral)
        at = lambda s: (math.sin(r) * ln * s, 0.04 + math.cos(r) * ln * s)  # noqa: E731
        p += [("can", "box", (*at(0.3), z), (w * 0.62, ln * 0.6, 0.2), c, o), ("can", "box", (*at(0.72), z + 0.03), (w, ln * 0.5, 0.26), c, o)]
        if a:
            p.append(("can", "box", (*at(1.0), z + 0.03), (w * 0.66, 0.16, 0.22), c, o))
    p += [("pom", "box", (0, 0.1, -0.3), (0.9, 0.22, 0.46), coral), ("pom", "wedge", (0, 0.28, -0.42), (0.78, 0.2, 0.26), pale, R(0, 180, 0)),
          ("pom", "ball", (0, 0.46, -0.24), (0.42, 0.42, 0.42), "#fff7f0")]
    p += [("flap", "box", (0.5, 0.04, 0.62), (0.66, 0.14, 0.2), coral, R(0, a, 0)) for a in (0, 60, -60)] + [("flap", "box", (0.5, 0.1, 0.62), (0.22, 0.16, 0.22), pale, R(0, 30, 0))]
    return {"main": sand, "flap": "#efd79b", "trim": coral, "cushion": "#3f9a7c", "cushion2": "#55b394", "strap": "#3f9a7c", "pieces": p}


def clam():
    out, lip, inn = "#c99a6c", "#37c0b0", "#f7ead0"
    p = [("can", "box", (0, 0.12, 0.16), (1.3, 0.3, 0.32), "#a87850"), ("can", "ball", (0, 0.42, 0.2), (0.5, 0.5, 0.5), "#fff6f2", {"mid": True})]
    for x, y, h, t in ((0.55, 0.36, 0.5, 10), (0.88, 0.56, 0.82, 22), (1.22, 0.72, 1.0, 36), (1.56, 0.74, 0.9, 52)):
        p += [("can", "box", (x, y, 0.2), (0.38, h, 0.34), out, RB(8, 0, -t)), ("can", "box", (x - 0.02, y, 0.06), (0.26, h * 0.8, 0.12), inn, RB(8, 0, -t))]
        r = math.radians(t)
        p.append(("can", "box", (x + math.sin(r) * h / 2, y + math.cos(r) * h / 2, 0.22 + 0.06 * (int(x * 10) % 2)), (0.36, 0.18, 0.4), lip, RB(8, 0, -t)))
    p += [("pom", "box", (0, 0.08, -0.3), (1.0, 0.2, 0.56), out), ("pom", "box", (0, 0.34, -0.5), (0.96, 0.5, 0.16), out, R(-28)), ("pom", "box", (0, 0.5, -0.56), (1.0, 0.14, 0.24), lip, R(-28)),
          ("pom", "box", (0, 0.2, -0.06), (0.9, 0.12, 0.16), lip), ("pom", "ball", (0, 0.36, -0.26), (0.36, 0.36, 0.36), "#fff6f2")]
    for i in range(3):
        p.append(("flap", "box", (0.3 + 0.26 * i, 0.05 + 0.02 * (i % 2), 0.55), (0.24, 0.14, 0.95 - 0.12 * i), (out, inn, lip)[i]))
    return {"main": "#f2c48a", "flap": "#e0a96e", "trim": "#37c0b0", "cushion": "#8f5f43", "cushion2": "#a87850", "strap": "#8f5f43", "pieces": p}


def twigs():
    pk, gold, teal, pur, org = "#ef6f86", "#ffd27a", "#22a89f", "#7a5ad6", "#ff8a4c"
    p = [("can", "box", (0, 0.16, 0.16), (2.0, 0.36, 0.3), pk), ("can", "box", (0, 0.4, 0.16), (1.1, 0.18, 0.24), "#f79aa9", {"mid": True})]
    for x, h, c, t in ((0.95, 1.15, org, 14), (1.35, 0.8, pur, 30), (0.55, 0.55, teal, 4)):
        r = math.radians(t)
        tip = lambda s: (x + math.sin(r) * h * s, 0.2 + math.cos(r) * h * s)  # noqa: E731
        p.append(("can", "box", (*tip(0.5), 0.2), (0.24, h, 0.24), c, RB(0, 0, -t)))
        a, b = tip(0.6), tip(1.0)
        p.append(("can", "box", (a[0] + 0.14, a[1] + 0.1, 0.2), (0.18, 0.42, 0.18), c, RB(0, 0, -t - 48)))
        if h > 0.6:
            p.append(("can", "box", (a[0] - 0.12, a[1] + 0.02, 0.26), (0.16, 0.36, 0.16), c, RB(20, 0, -t + 46)))
        p.append(("can", "box", (b[0], b[1], 0.2), (0.3, 0.2, 0.3), gold, RB(0, 0, -t)))
    p += [("pom", "box", (0, 0.12, -0.3), (0.8, 0.26, 0.44), pk), ("pom", "box", (0, 0.4, -0.32), (0.22, 0.5, 0.22), org), ("pom", "box", (0.2, 0.42, -0.32), (0.16, 0.4, 0.16), org, RB(0, 0, -40)),
          ("pom", "box", (0, 0.66, -0.32), (0.3, 0.16, 0.3), gold)]
    p += [("flap", "box", (0.35, 0.1, 0.62), (0.3, 0.24, 0.3), teal, R(0, 45)), ("flap", "box", (0.62, 0.1, 0.42), (0.24, 0.2, 0.24), pur, R(0, 45)), ("flap", "box", (0.68, 0.1, 0.8), (0.26, 0.22, 0.26), org, R(0, 45))]
    return {"main": "#ffd9a0", "flap": "#f9a2ad", "trim": teal, "cushion": "#7a5ad6", "cushion2": "#9479e6", "strap": teal, "pieces": p}


def anemone():
    base, tip, gold = "#ff6f91", "#ffe08a", "#ffd27a"
    p = [("can", "cylinder", (0, 0.16, 0.2), (1.9, 0.46, 0.46), "#7a5ad6")]
    for i, (x, h, t) in enumerate(((0, 0.52, 0), (0.36, 0.62, 10), (0.72, 0.82, 22), (1.06, 1.02, 36), (1.34, 0.9, 56), (1.5, 0.7, 80))):
        o = R(16, 0, 0, mid=True) if x == 0 else RB(16, 0, -t)
        r = math.radians(t)
        c = base if i % 2 == 0 else "#ff9ab0"
        p.append(("can", "box", (x * 0.62 + math.sin(r) * h * 0.5, 0.2 + math.cos(r) * h * 0.5, 0.26 + 0.1 * (i % 2)), (0.24, h, 0.24), c, o))
        p.append(("can", "ball", (x * 0.62 + math.sin(r) * h, 0.2 + math.cos(r) * h, 0.34 + 0.1 * (i % 2)), (0.36, 0.36, 0.36), tip, o))
    p += [("pom", "cylinder", (0, 0.16, -0.32), (0.34, 0.62, 0.62), "#7a5ad6", R(0, 0, 90)), ("pom", "ball", (0, 0.56, -0.32), (0.3, 0.3, 0.3), tip), ("pom", "box", (0, 0.4, -0.32), (0.18, 0.34, 0.18), base),
          ("pom", "box", (0.24, 0.36, -0.32), (0.16, 0.4, 0.16), base, RB(0, 0, -34)), ("pom", "ball", (0.36, 0.52, -0.32), (0.26, 0.26, 0.26), tip, B)]
    p += [("flap", "cylinder", (0.5, 0.05, 0.6), (0.18, 0.66, 0.66), "#7a5ad6", R(0, 0, 90)), ("flap", "ball", (0.5, 0.2, 0.6), (0.36, 0.36, 0.36), gold), ("low", "cylinder", (0.45, 0.05, 0.4), (0.18, 0.5, 0.5), "#ff6f91", R(0, 0, 90))]
    return {"main": "#45c4ba", "flap": "#2f9e9a", "trim": "#ffd27a", "cushion": "#ef6f86", "cushion2": "#f48da0", "strap": "#7a5ad6", "pieces": p}


def kelp():
    g, lime, dk, yel = "#359d55", "#8fd65f", "#1f5f38", "#e2c35a"
    p = [("can", "box", (0, 0.14, 0.16), (1.7, 0.32, 0.28), dk)]
    for x, y, h, t, c in ((0, 0.46, 0.66, 0, lime), (0.42, 0.5, 0.82, 18, g), (0.84, 0.56, 1.0, 38, lime), (1.16, 0.4, 0.92, 64, g)):
        o = R(16, 0, 0, mid=True) if x == 0 else RB(16, 0, -t)
        r = math.radians(t)
        p += [("can", "box", (x, y, 0.22 + 0.04 * (c == lime)), (0.4, h, 0.14), c, o), ("can", "box", (x, y, 0.3 + 0.04 * (c == lime)), (0.1, h * 0.9, 0.06), dk, o)]
        p.append(("can", "wedge", (x + math.sin(r) * (h / 2 + 0.1), y + math.cos(r) * (h / 2 + 0.1), 0.28 + 0.04 * (c == lime)), (0.4, 0.24, 0.14), c, o))
    p += [("pom", "box", (0, 0.1, -0.3), (0.86, 0.2, 0.44), dk), ("pom", "ball", (0, 0.42, -0.3), (0.5, 0.5, 0.5), yel), ("pom", "box", (0.34, 0.24, -0.34), (0.5, 0.12, 0.26), lime, RB(0, 18, 28)), ("pom", "box", (0, 0.7, -0.3), (0.12, 0.14, 0.12), dk)]
    p += [("flap", "box", (0.5, 0.05, 0.32), (0.9, 0.12, 0.3), lime), ("flap", "box", (0.55, 0.04, 0.8), (0.95, 0.1, 0.3), lime), ("flap", "ball", (0.12, 0.1, 0.56), (0.3, 0.3, 0.3), yel), ("low", "box", (0.5, 0.05, 0.32), (0.85, 0.12, 0.26), lime), ("low", "box", (0.4, 0.04, 0.8), (0.7, 0.1, 0.26), lime)]
    return {"main": g, "flap": "#2c8448", "trim": "#1f5f38", "cushion": "#c9a94a", "cushion2": "#e2c35a", "strap": "#8fd65f", "pieces": p}


def crown():
    g, lime, dk, yel = "#2f8f4c", "#7fc957", "#292b1c", "#f0cf5e"
    p = [("can", "cylinder", (0, 0.2, 0.2), (2.2, 0.34, 0.34), "#b98f3c"), ("can", "box", (0, 0.2, 0.2), (0.22, 0.4, 0.4), "#8a6a2a", {"mid": True}), ("can", "box", (0.5, 0.2, 0.2), (0.2, 0.4, 0.4), "#8a6a2a", B), ("can", "box", (1.0, 0.2, 0.2), (0.2, 0.4, 0.4), "#8a6a2a", B)]
    for x, h, t in ((1.3, 1.3, 22), (0.8, 0.62, 10)):
        r = math.radians(t)
        at = lambda s: (x + math.sin(r) * h * s, 0.2 + math.cos(r) * h * s)  # noqa: E731
        p.append(("can", "box", (*at(0.5), 0.22), (0.16, h, 0.16), dk, RB(0, 0, -t)))
        for s, sd in ((0.35, 1), (0.6, -1), (0.85, 1)) if h > 1 else ((0.55, 1), (0.85, -1)):
            a = at(s)
            p += [("can", "box", (a[0] + 0.24 * sd, a[1] + 0.1, 0.24), (0.46, 0.2, 0.1), lime if sd > 0 else g, RB(0, 0, 34 * sd)), ("can", "ball", (a[0], a[1], 0.22), (0.26, 0.26, 0.26), yel, B)]
        e = at(1.0)
        p.append(("can", "box", (e[0], e[1] + 0.14, 0.22), (0.26, 0.4, 0.1), lime, RB(0, 0, -t)))
    p += [("pom", "cylinder", (0, 0.18, -0.3), (0.8, 0.32, 0.32), "#b98f3c"), ("pom", "box", (0, 0.5, -0.32), (0.16, 0.5, 0.16), dk), ("pom", "ball", (0, 0.76, -0.32), (0.3, 0.3, 0.3), yel), ("pom", "box", (0.2, 0.56, -0.32), (0.36, 0.16, 0.1), lime, RB(0, 0, 34))]
    p += [("flap", "box", (0.45, 0.06, 0.5), (0.8, 0.14, 0.24), lime, R(0, 14)), ("flap", "box", (0.45, 0.05, 0.75), (0.8, 0.12, 0.24), g, R(0, -10)), ("flap", "ball", (0.25, 0.14, 0.62), (0.28, 0.28, 0.28), yel), ("low", "box", (0.4, 0.05, 0.55), (0.8, 0.12, 0.26), lime, R(0, -8)), ("low", "ball", (0.2, 0.12, 0.8), (0.24, 0.24, 0.24), yel)]
    return {"main": "#1f6b3a", "flap": "#1b5731", "trim": yel, "cushion": "#8a6a2a", "cushion2": "#b98f3c", "strap": "#b98f3c", "pieces": p}


def crate():
    wood, dark, iron, gold, rope = "#b98a55", "#8a6238", "#3d4753", "#e0b23c", "#dcc794"
    p = [("can", "box", (0, 0.2, 0.14), (2.0, 0.3, 0.2), wood), ("can", "box", (0, 0.52, 0.18), (1.9, 0.28, 0.2), dark, {"mid": True}), ("can", "box", (0, 0.8, 0.22), (1.7, 0.22, 0.2), wood, {"mid": True}),
         ("can", "box", (0.92, 0.56, 0.2), (0.28, 0.98, 0.34), iron, B), ("can", "box", (0.92, 1.08, 0.2), (0.36, 0.14, 0.4), gold, B), ("can", "box", (0.92, 0.3, 0.38), (0.14, 0.14, 0.06), gold, B), ("can", "box", (0.92, 0.76, 0.38), (0.14, 0.14, 0.06), gold, B),
         ("can", "box", (0, 0.52, 0.3), (1.5, 0.16, 0.06), dark, R(0, 0, 18, mid=True))]
    p += [("pom", "box", (0, 0.1, -0.3), (0.9, 0.22, 0.5), dark), ("pom", "cylinder", (0, 0.3, -0.3), (0.2, 0.6, 0.6), rope, R(0, 0, 90)), ("pom", "cylinder", (0, 0.46, -0.3), (0.16, 0.48, 0.48), "#c4ab72", R(0, 0, 90)), ("pom", "cylinder", (0, 0.58, -0.3), (0.14, 0.6, 0.6), rope, R(0, 0, 90)), ("pom", "cylinder", (0, 0.68, -0.3), (0.12, 0.3, 0.3), iron, R(0, 0, 90))]
    p += [("flap", "box", (0.5, 0.04, 0.22), (0.96, 0.1, 0.3), wood), ("flap", "box", (0.5, 0.04, 0.54), (0.96, 0.1, 0.3), dark), ("flap", "box", (0.5, 0.04, 0.84), (0.96, 0.1, 0.28), wood), ("flap", "box", (0.5, 0.1, 0.54), (0.2, 0.08, 0.98), iron), ("flap", "box", (0.5, 0.16, 0.3), (0.12, 0.06, 0.12), gold), ("flap", "box", (0.5, 0.16, 0.78), (0.12, 0.06, 0.12), gold)]
    return {"main": "#a47a4a", "flap": "#7c5833", "trim": iron, "cushion": "#8f2f2f", "cushion2": "#a94141", "strap": rope, "pieces": p}


def wheel():
    wood, dark, gold, iron = "#9c6a3a", "#6e4726", "#e0b23c", "#3d4753"
    p = [("can", "box", (0, 0.1, 0.14), (1.7, 0.24, 0.3), dark)]
    cy, rad = 0.46, 0.5
    for i in range(8):
        a = math.radians(i * 45)
        p.append(("can", "box", (math.sin(a) * rad, cy + math.cos(a) * rad, 0.26), (0.46, 0.18, 0.2), wood, R(0, 0, -i * 45, **({"mid": True}))))
        if i in (1, 2, 3, 5, 6, 7):
            p.append(("can", "box", (math.sin(a) * 0.74, cy + math.cos(a) * 0.74, 0.26), (0.16, 0.36, 0.16), gold, R(0, 0, -i * 45, mid=True)))
    p += [("can", "box", (0, cy, 0.26), (0.9, 0.12, 0.12), dark, R(0, 0, 45, mid=True)), ("can", "box", (0, cy, 0.26), (0.9, 0.12, 0.12), dark, R(0, 0, -45, mid=True)), ("can", "cylinder", (0, cy, 0.3), (0.26, 0.34, 0.34), gold, R(0, 90, 0, mid=True))]
    p += [("can", "box", (1.12, 0.5, 0.16), (0.2, 0.9, 0.2), dark, B), ("can", "box", (1.12, 1.1, 0.16), (0.34, 0.4, 0.34), "#ffd95a", {"both": True, "n": True}), ("can", "box", (1.12, 1.36, 0.16), (0.44, 0.12, 0.44), iron, B), ("can", "box", (1.12, 0.88, 0.16), (0.44, 0.1, 0.44), iron, B)]
    p += [("pom", "box", (0, 0.12, -0.3), (0.84, 0.26, 0.46), wood), ("pom", "box", (0, 0.34, -0.3), (0.3, 0.2, 0.3), dark), ("pom", "box", (0, 0.5, -0.3), (0.6, 0.16, 0.2), gold), ("pom", "box", (0, 0.28, -0.54), (0.5, 0.1, 0.06), gold)]
    p += [("flap", "box", (0.5, 0.05, 0.55), (0.72, 0.1, 0.14), iron), ("flap", "box", (0.12, 0.05, 0.55), (0.12, 0.1, 0.44), iron), ("flap", "box", (0.8, 0.05, 0.74), (0.14, 0.1, 0.42), iron, R(0, 40, 0)), ("flap", "box", (0.8, 0.05, 0.36), (0.14, 0.1, 0.42), iron, R(0, -40, 0))]
    return {"main": "#1f4f63", "flap": "#1e3f50", "trim": gold, "cushion": "#7a2630", "cushion2": "#93343f", "strap": dark, "pieces": p}


def wave():
    deep, mid, light, foam = "#1f62a8", "#2b8fd0", "#8fd3f2", "#f4fbff"
    p = [("can", "box", (0, 0.18, 0.18), (1.9, 0.4, 0.34), deep), ("can", "box", (0, 0.46, 0.24), (1.3, 0.3, 0.3), mid, {"mid": True}), ("can", "box", (0, 0.66, 0.3), (1.1, 0.18, 0.4), light, {"mid": True}), ("can", "box", (0, 0.8, 0.36), (0.96, 0.14, 0.42), foam, {"mid": True})]
    for x, y, w, h, tt, c in ((0.9, 0.38, 0.5, 0.6, -12, mid), (1.14, 0.72, 0.48, 0.5, -32, mid), (1.44, 1.0, 0.42, 0.42, -60, light), (1.8, 1.06, 0.38, 0.36, -92, light), (2.04, 0.9, 0.32, 0.3, -130, foam), (2.06, 0.68, 0.2, 0.2, -150, foam)):
        p.append(("can", "box", (x, y, 0.26), (w, h, 0.34), c, RB(0, 0, tt)))
    p += [("can", "box", (0.98, 0.98, 0.28), (0.18, 0.32, 0.4), foam, RB(0, 0, -30)), ("can", "box", (1.36, 1.26, 0.28), (0.4, 0.16, 0.42), foam, RB(0, 0, -20))]
    p += [("pom", "box", (0, 0.16, -0.22), (0.9, 0.34, 0.4), deep), ("pom", "box", (0, 0.44, -0.3), (0.84, 0.4, 0.32), mid, R(-12)), ("pom", "box", (0, 0.72, -0.22), (0.78, 0.26, 0.34), light, R(28)), ("pom", "box", (0, 0.8, 0.02), (0.82, 0.18, 0.28), foam, R(8)), ("pom", "box", (0, 0.66, 0.14), (0.6, 0.16, 0.12), foam)]
    p += [("flap", "box", (0.28, 0.06, 0.55), (0.2, 0.14, 0.9), light, R(0, 10)), ("flap", "box", (0.58, 0.06, 0.55), (0.2, 0.14, 0.9), foam, R(0, 10)), ("low", "box", (0.3, 0.06, 0.55), (0.18, 0.12, 0.8), light, R(0, 10))]
    return {"main": "#2b7fc2", "flap": "#2370b2", "trim": foam, "cushion": "#163a5e", "cushion2": "#245482", "strap": "#8fd3f2", "pieces": p}


def wings():
    deep, cy, light, foam = "#1b5c9c", "#4fe0d4", "#a9ecf7", "#f4fbff"
    p = [("can", "box", (0, 0.2, 0.18), (1.8, 0.42, 0.34), deep), ("can", "box", (0, 0.48, 0.24), (1.0, 0.2, 0.26), foam, {"mid": True})]
    for i, (t, ln, c) in enumerate(((22, 1.15, light), (44, 1.35, cy), (66, 1.25, light), (88, 1.0, foam))):
        r = math.radians(t)
        x, y = 0.62 + math.sin(r) * ln / 2, 0.22 + math.cos(r) * ln / 2
        p += [("can", "box", (x, y, 0.28 + 0.09 * i), (0.34, ln, 0.16), c, RB(26, 0, -t)), ("can", "box", (0.62 + math.sin(r) * ln, 0.22 + math.cos(r) * ln, 0.5 + 0.09 * i + 0.02 * ln), (0.26, 0.22, 0.2), foam if c != foam else cy, RB(26, 0, -t))]
    p += [("pom", "box", (0, 0.14, -0.3), (0.86, 0.3, 0.46), deep), ("pom", "box", (0, 0.4, -0.36), (0.3, 0.4, 0.3), cy, R(-20)), ("pom", "box", (0.26, 0.38, -0.34), (0.22, 0.46, 0.22), light, RB(-10, 0, -30)), ("pom", "ball", (0, 0.68, -0.42), (0.26, 0.26, 0.26), foam), ("pom", "ball", (0.42, 0.62, -0.36), (0.22, 0.22, 0.22), foam, B)]
    p += [("flap", "box", (0.5, 0.06, 0.4), (0.8, 0.14, 0.24), cy, R(0, -28)), ("flap", "box", (0.5, 0.06, 0.75), (0.7, 0.14, 0.22), light, R(0, -28)), ("flap", "ball", (0.14, 0.1, 0.8), (0.24, 0.24, 0.24), foam), ("low", "box", (0.4, 0.06, 0.6), (0.6, 0.12, 0.22), cy, R(0, -28))]
    return {"main": "#3fa7de", "flap": "#2b7fc2", "trim": cy, "cushion": "#f4fbff", "cushion2": "#d5eef8", "strap": deep, "pieces": p}


def gem(a, x, y, z, w, h, c, t=0, lean=0, both=True, n=False, mid=False, cap=None):
    """a crystal: a square column turned to its corner, with a smaller block for its point"""
    r = math.radians(t)
    o = {"r": (lean, 0, -t), "both": both, "n": n, "mid": mid}
    tx, ty = x + math.sin(r) * h / 2, y + math.cos(r) * h / 2
    tz = z + math.sin(math.radians(lean)) * h * 0.5
    return [(a, "box", (x, y, z), (w, h, w), c, o), (a, "box", (tx + math.sin(r) * w * 0.1, ty + math.cos(r) * w * 0.1, tz), (w * 0.62, w * 0.62, w * 0.62), cap or c, {"r": (lean, 45, -t), "both": both, "n": n, "mid": mid})]


def frost():
    ice, pale, snow, vio = "#7fdff0", "#c8f4fb", "#ffffff", "#7a74c6"
    p = [("can", "box", (0, 0.14, 0.18), (1.9, 0.34, 0.36), snow), ("can", "box", (0.6, 0.32, 0.18), (0.5, 0.2, 0.34), snow, B)]
    p += gem("can", 0, 0.5, 0.24, 0.34, 0.6, ice, 0, 12, False, True, True, pale)
    p += gem("can", 0.42, 0.52, 0.26, 0.3, 0.72, pale, 14, 12)
    p += gem("can", 0.88, 0.64, 0.24, 0.38, 1.05, ice, 24, 10, True, True, False, pale)
    p += gem("can", 1.22, 0.42, 0.22, 0.28, 0.66, pale, 48, 10)
    p += [("pom", "box", (0, 0.12, -0.3), (0.88, 0.26, 0.46), snow)] + gem("pom", 0, 0.44, -0.32, 0.28, 0.5, ice, 0, -10, False, True, False, pale) + gem("pom", 0.26, 0.36, -0.3, 0.22, 0.42, pale, 30, -10)
    p += [("flap", "box", (0.08, 0.08, 0.5), (0.22, 0.22, 0.9), snow), ("flap", "box", (0.5, 0.1, 0.6), (0.36, 0.2, 0.36), ice, R(0, 45, 0, n=True)), ("flap", "box", (0.5, 0.17, 0.6), (0.2, 0.12, 0.2), snow, R(0, 45)), ("hem", "wedge", (0.05, -0.1, 0.35), (0.34, 0.16, 0.22), pale, R(0, 0, -8)), ("hem", "wedge", (0.05, -0.1, 0.75), (0.34, 0.16, 0.22), pale, R(0, 0, -8))]
    return {"main": "#cbc8e8", "flap": "#b3aee0", "trim": snow, "cushion": "#55538f", "cushion2": "#6f6cb0", "strap": vio, "pieces": p}


def throne():
    ice, pale, vio, dk = "#7cf2e6", "#d8fbff", "#a79cf0", "#55538f"
    p = [("can", "box", (0, 0.18, 0.2), (1.7, 0.4, 0.4), dk)]
    p += gem("can", 0, 0.52, 0.3, 0.4, 0.56, pale, 0, 18, False, False, True)
    for x, y, w, h, t, c, n in ((0.5, 0.46, 0.38, 0.58, 16, vio, False), (0.98, 0.66, 0.44, 1.05, 34, ice, True), (1.4, 0.56, 0.38, 1.1, 58, vio, False), (1.56, 0.3, 0.3, 0.8, 80, pale, False)):
        p += gem("can", x, y, 0.3, w, h, c, t, 16, True, n, False, pale if c != pale else ice)
    p += [("pom", "box", (0, 0.14, -0.3), (0.86, 0.3, 0.46), dk)] + gem("pom", 0, 0.5, -0.36, 0.34, 0.6, ice, 0, -22, False, True, False, pale) + gem("pom", 0.3, 0.42, -0.32, 0.24, 0.5, vio, 36, -16)
    p += [("flap", "box", (0.4, 0.14, 0.5), (0.4, 0.34, 0.4), vio, R(24, 45, 0)), ("flap", "box", (0.6, 0.12, 0.82), (0.3, 0.28, 0.3), ice, R(0, 45, 18, n=True))]
    p += [("hem", "wedge", (0.1, -0.1, z), (s, 0.18, 0.24), pale, R(0, 0, -6)) for z, s in ((0.2, 0.5), (0.5, 0.4), (0.82, 0.55))]
    return {"main": "#9d98da", "flap": "#7a74c6", "trim": "#d8fbff", "cushion": "#3b3970", "cushion2": "#4d4b8a", "strap": "#d8fbff", "pieces": p}


def lantern():
    navy, blue, glow, dk = "#25306e", "#3a4aa8", "#64fffd", "#141c4a"
    p = [("can", "box", (0, 0.2, 0.18), (1.8, 0.44, 0.34), dk), ("can", "box", (0, 0.54, 0.24), (1.3, 0.3, 0.28), blue, {"mid": True}), ("can", "box", (0.84, 0.56, 0.2), (0.44, 0.56, 0.32), blue, RB(0, 0, -16)), ("can", "box", (1.12, 0.9, 0.2), (0.3, 0.5, 0.28), dk, RB(0, 0, -30)),
         ("can", "ball", (1.28, 1.18, 0.2), (0.34, 0.34, 0.34), glow, {"both": True, "n": True}), ("can", "ball", (0, 0.54, 0.4), (0.28, 0.28, 0.28), glow, {"n": True, "mid": True}), ("can", "ball", (0.4, 0.46, 0.38), (0.22, 0.22, 0.22), glow, {"both": True, "n": True, "mid": True})]
    p += [("pom", "box", (0, 0.14, -0.26), (0.86, 0.3, 0.44), dk), ("pom", "box", (0, 0.44, -0.32), (0.2, 0.46, 0.2), blue, R(-14)), ("pom", "box", (0, 0.72, -0.46), (0.18, 0.4, 0.18), blue, R(-56)), ("pom", "ball", (0, 0.76, -0.72), (0.4, 0.4, 0.4), glow, {"n": True})]
    p += [("flap", "ball", (0.28, 0.02, 0.3), (0.2, 0.2, 0.2), glow, {"n": True}), ("flap", "ball", (0.42, 0.02, 0.58), (0.26, 0.26, 0.26), glow, {"n": True}), ("flap", "ball", (0.62, 0.02, 0.84), (0.3, 0.3, 0.3), glow, {"n": True}), ("low", "ball", (0.3, 0.02, 0.6), (0.22, 0.22, 0.22), glow, {"n": True})]
    return {"main": navy, "flap": "#1f2960", "trim": blue, "cushion": "#4a5cc4", "cushion2": "#3a4aa8", "strap": glow, "pieces": p}


def jelly():
    bell, pale, glow, dk, pink = "#7f8cf5", "#c3cbff", "#64fffd", "#141c4a", "#ff9de0"
    p = [("can", "box", (0, 0.2, 0.18), (1.9, 0.44, 0.34), dk), ("can", "box", (0, 0.5, 0.22), (0.9, 0.24, 0.26), bell, {"mid": True})]
    p += [("can", "cylinder", (1.05, 0.86, 0.24), (0.26, 0.92, 0.92), bell, RB(0, 0, 90 - 12)), ("can", "cylinder", (1.1, 1.08, 0.24), (0.24, 0.68, 0.68), pale, RB(0, 0, 90 - 12)), ("can", "cylinder", (1.14, 1.24, 0.24), (0.16, 0.4, 0.4), bell, RB(0, 0, 90 - 12)), ("can", "cylinder", (1.02, 0.7, 0.24), (0.1, 0.8, 0.8), glow, RB(0, 0, 90 - 12, n=True))]
    for x, z, ln in ((0.8, 0.3, 0.7), (1.05, 0.5, 1.0), (1.28, 0.3, 0.8)):
        p.append(("can", "box", (x, 0.44, z + 0.06 + ln * 0.2), (0.12, ln * 0.8, 0.12), pink, RB(-42, 0, 0)))
    p += [("pom", "box", (0, 0.12, -0.3), (0.8, 0.26, 0.44), dk), ("pom", "cylinder", (0, 0.36, -0.3), (0.3, 0.16, 0.16), pale, R(0, 0, 90)), ("pom", "cylinder", (0, 0.54, -0.3), (0.18, 0.66, 0.66), bell, R(0, 0, 90)), ("pom", "cylinder", (0, 0.68, -0.3), (0.16, 0.4, 0.4), pale, R(0, 0, 90)), ("pom", "cylinder", (0, 0.44, -0.3), (0.06, 0.56, 0.56), glow, R(0, 0, 90, n=True))]
    for u, z, s in ((0.35, 0.42, 1.0), (0.6, 0.78, 0.8)):
        p += [("flap", "box", (u, 0.12 * s, z), (0.16 * s, 0.26 * s, 0.16 * s), pale), ("flap", "box", (u, 0.28 * s, z), (0.46 * s, 0.16 * s, 0.46 * s), glow, {"n": True}), ("flap", "box", (u, 0.38 * s, z), (0.26 * s, 0.1 * s, 0.26 * s), pale)]
    return {"main": "#3a4aa8", "flap": "#2c3888", "trim": pink, "cushion": "#141c4a", "cushion2": "#202a66", "strap": "#7f8cf5", "pieces": p}


def ember():
    rock, dk, red, lava, hot = "#3a2f38", "#1d161c", "#953122", "#ff7a1a", "#ffd23a"
    p = [("can", "box", (0, 0.16, 0.2), (2.1, 0.36, 0.4), dk), ("can", "box", (0, 0.36, 0.2), (1.9, 0.08, 0.36), lava, {"n": True})]
    for x, h, c in ((0, 0.3, rock), (0.4, 0.4, dk), (0.78, 0.5, rock), (1.16, 0.78, dk), (1.5, 0.4, rock)):
        o = {"mid": True} if x == 0 else dict(B)
        p.append(("can", "box", (x, 0.36 + h / 2, 0.24 - 0.02 * (c == dk)), (0.4, h, 0.4), c, dict(o, r=(0, 45 if c == dk else 0, 0))))
        p.append(("can", "box", (x, 0.38 + h, 0.24), (0.24, 0.1, 0.24), hot if c == dk else lava, dict(o, n=True, r=(0, 45 if c == dk else 0, 0))))
    p += [("pom", "box", (0, 0.2, -0.3), (0.86, 0.42, 0.46), rock), ("pom", "box", (0.02, 0.5, -0.32), (0.5, 0.24, 0.36), dk, R(0, 20)), ("pom", "box", (0, 0.64, -0.32), (0.26, 0.1, 0.22), hot, R(0, 20, 0, n=True)), ("pom", "box", (0, 0.24, -0.55), (0.6, 0.1, 0.06), lava, R(0, 0, 16, n=True))]
    p += [("flap", "box", (0.3, 0.06, 0.55), (0.1, 0.08, 0.9), lava, R(0, 24, 0, n=True)), ("flap", "box", (0.62, 0.06, 0.5), (0.1, 0.08, 0.8), hot, R(0, -18, 0, n=True)), ("flap", "box", (0.46, 0.08, 0.84), (0.34, 0.2, 0.34), rock, R(0, 20)), ("low", "box", (0.4, 0.06, 0.5), (0.1, 0.08, 0.7), lava, R(0, 24, 0, n=True))]
    return {"main": "#2a2128", "flap": "#231b22", "trim": red, "cushion": red, "cushion2": "#b84430", "strap": lava, "pieces": p}


def vents():
    rock, dk, lava, hot, ash = "#4a3a42", "#17121a", "#ff6a1a", "#f9e40e", "#6d5a60"
    p = [("can", "box", (0, 0.18, 0.2), (1.8, 0.42, 0.38), dk), ("can", "box", (0, 0.5, 0.26), (0.8, 0.26, 0.3), rock, {"mid": True}), ("can", "box", (0, 0.5, 0.42), (0.5, 0.12, 0.06), lava, {"n": True, "mid": True})]
    for x, y, w, h, c in ((1.0, 0.34, 0.72, 0.42, rock), (1.11, 0.7, 0.58, 0.4, ash), (1.22, 1.04, 0.46, 0.36, rock)):
        p.append(("can", "cylinder", (x, y, 0.24), (h, w, w), c, RB(0, 0, 90 - 16)))
    p += [("can", "cylinder", (1.29, 1.25, 0.24), (0.1, 0.36, 0.36), hot, RB(0, 0, 90 - 16, n=True)), ("can", "box", (1.06, 0.53, 0.24), (0.66, 0.1, 0.66), lava, RB(0, 0, -16, n=True)), ("can", "cylinder", (1.17, 0.88, 0.24), (0.1, 0.56, 0.56), lava, RB(0, 0, 90 - 16, n=True))]
    p += [("pom", "box", (0, 0.16, -0.3), (0.8, 0.34, 0.46), dk), ("pom", "box", (0.3, 0.46, -0.36), (0.22, 0.5, 0.22), dk, RB(-14, 0, -20)), ("pom", "box", (0.42, 0.76, -0.46), (0.14, 0.3, 0.14), lava, RB(-24, 0, -6, n=True)), ("pom", "box", (0, 0.36, -0.3), (0.3, 0.1, 0.3), hot, {"n": True})]
    p += [("flap", "box", (0.45, 0.06, 0.45), (0.5, 0.1, 0.5), lava, R(0, 20, 0, n=True)), ("flap", "box", (0.45, 0.1, 0.45), (0.28, 0.08, 0.28), hot, R(0, 50, 0, n=True)), ("flap", "box", (0.6, 0.06, 0.84), (0.34, 0.1, 0.34), lava, R(0, -15, 0, n=True)), ("low", "box", (0.4, 0.06, 0.6), (0.4, 0.1, 0.4), lava, R(0, 30, 0, n=True))]
    return {"main": "#3a2a2e", "flap": "#2c2024", "trim": "#953122", "cushion": "#17121a", "cushion2": "#2a2128", "strap": "#953122", "pieces": p}


def ribs():
    bone, pale, old, moss, glow = "#e9e0c6", "#f8f3e4", "#b8ab86", "#6f7a52", "#7fe0b0"
    p = [("can", "box", (0, 0.16, 0.18), (1.2, 0.34, 0.34), old), ("can", "box", (0, 0.46, 0.22), (0.44, 0.44, 0.34), bone, {"mid": True}), ("can", "box", (0, 0.74, 0.24), (0.26, 0.2, 0.26), pale, {"mid": True}), ("can", "box", (0.34, 0.46, 0.22), (0.36, 0.18, 0.2), bone, RB(0, 0, 14, mid=True))]
    for x, y, t, ln in ((0.72, 0.52, 20, 0.6), (0.98, 0.94, 2, 0.5), (0.92, 1.3, -30, 0.4)):
        p.append(("can", "box", (x, y, 0.22), (0.24 - 0.04 * (ln < 0.45), ln, 0.26), bone if ln > 0.45 else pale, RB(0, 0, -t)))
    p += [("can", "box", (1.1, 0.4, 0.22), (0.5, 0.22, 0.24), bone, RB(0, 0, 10)), ("can", "box", (1.42, 0.62, 0.22), (0.22, 0.46, 0.22), bone, RB(0, 0, -12)), ("can", "box", (1.42, 0.92, 0.22), (0.16, 0.3, 0.16), pale, RB(0, 0, 20))]
    p += [("pom", "box", (0, 0.14, -0.3), (0.8, 0.3, 0.42), old), ("pom", "box", (0, 0.42, -0.32), (0.34, 0.36, 0.34), bone), ("pom", "box", (0.28, 0.46, -0.32), (0.34, 0.16, 0.2), bone, RB(0, 0, 24)), ("pom", "box", (0, 0.66, -0.32), (0.2, 0.16, 0.2), pale), ("pom", "box", (0, 0.42, -0.51), (0.16, 0.16, 0.06), glow, {"n": True})]
    for z in (0.16, 0.52, 0.86):
        p += [("flap", "box", (0.5, 0.06, z), (0.98, 0.16, 0.18), bone), ("low", "box", (0.4, 0.05, z), (0.78, 0.14, 0.16), bone), ("flap", "box", (0.06, 0.09, z), (0.22, 0.2, 0.26), pale)]
    return {"main": moss, "flap": "#5c6644", "trim": old, "cushion": "#4a5138", "cushion2": "#5c6644", "strap": old, "pieces": p}


def skull():
    bone, pale, old, dk, glow = "#e6dcc0", "#f6f0de", "#b8ab86", "#2a3327", "#8dffc6"
    p = [("can", "box", (0, 0.12, 0.2), (1.5, 0.26, 0.36), old), ("can", "box", (0, 0.56, 0.36), (1.02, 0.6, 0.5), bone, {"mid": True}), ("can", "box", (0, 0.82, 0.34), (0.78, 0.16, 0.44), pale, {"mid": True}), ("can", "box", (0.26, 0.6, 0.6), (0.26, 0.24, 0.08), dk, RB(0, 0, 0, mid=True)), ("can", "box", (0.26, 0.6, 0.63), (0.15, 0.14, 0.08), glow, RB(0, 0, 0, n=True, mid=True)),
         ("can", "box", (0, 0.42, 0.61), (0.14, 0.12, 0.06), dk, R(0, 0, 45, mid=True)), ("can", "box", (0, 0.24, 0.5), (0.7, 0.2, 0.3), pale, {"mid": True}), ("can", "box", (0.14, 0.2, 0.66), (0.07, 0.16, 0.04), dk, RB(0, 0, 0, mid=True)),
         ("can", "box", (0.86, 0.36, 0.28), (0.5, 0.26, 0.28), old, RB(0, 0, 16)), ("can", "box", (1.2, 0.62, 0.3), (0.26, 0.56, 0.26), bone, RB(0, 0, -22)), ("can", "box", (1.3, 1.02, 0.3), (0.22, 0.5, 0.22), bone, RB(0, 0, 8)), ("can", "box", (1.2, 1.36, 0.3), (0.16, 0.38, 0.16), pale, RB(0, 0, 32)),
         ("can", "box", (0.98, 0.62, 0.3), (0.24, 0.24, 0.24), glow, RB(0, 45, 20, n=True))]
    p += [("pom", "box", (0, 0.16, -0.3), (0.78, 0.34, 0.44), old), ("pom", "box", (0, 0.46, -0.36), (0.3, 0.4, 0.3), bone, R(-14)), ("pom", "box", (0, 0.74, -0.46), (0.2, 0.34, 0.2), pale, R(-30)), ("pom", "box", (0.3, 0.36, -0.46), (0.14, 0.14, 0.14), glow, RB(0, 45, 0, n=True))]
    p += [("flap", "box", (0.4, 0.1, 0.55), (0.44, 0.24, 0.5), bone), ("flap", "box", (0.42, 0.22, 0.42), (0.14, 0.06, 0.12), glow, {"n": True}), ("flap", "box", (0.42, 0.22, 0.68), (0.14, 0.06, 0.12), glow, {"n": True}), ("flap", "box", (0.74, 0.08, 0.55), (0.2, 0.16, 0.34), pale)]
    return {"main": "#3d4a39", "flap": "#33402f", "trim": bone, "cushion": "#7fbf9a", "cushion2": "#5f9a7a", "strap": glow, "pieces": p}


def star():
    vio, lil, dk, cy = "#3a22a8", "#8f8cf0", "#160a4e", "#64fffd"
    p = [("can", "box", (0, 0.16, 0.2), (1.9, 0.36, 0.38), dk), ("can", "box", (0, 0.36, 0.22), (1.7, 0.07, 0.4), cy, {"n": True}), ("can", "box", (0, 0.58, 0.24), (0.9, 0.38, 0.32), vio, {"mid": True}), ("can", "box", (0, 0.8, 0.24), (0.5, 0.1, 0.26), lil, {"mid": True}),
         ("can", "box", (0.76, 0.64, 0.24), (0.5, 0.5, 0.36), lil, RB(0, 0, -10)), ("can", "box", (1.14, 0.8, 0.24), (0.42, 0.7, 0.34), vio, RB(0, 0, -24)), ("can", "box", (1.36, 1.18, 0.24), (0.3, 0.16, 0.36), cy, RB(0, 0, -24, n=True)), ("can", "box", (1.46, 1.46, 0.24), (0.26, 0.26, 0.26), lil, RB(20, 30, -24)), ("can", "box", (0, 0.58, 0.42), (0.3, 0.3, 0.06), cy, R(0, 0, 45, mid=True, n=True))]
    p += [("pom", "box", (0, 0.16, -0.3), (0.86, 0.34, 0.46), dk)] + gem("pom", 0, 0.5, -0.34, 0.3, 0.6, lil, 0, -12, False, False, False, cy) + gem("pom", 0.28, 0.42, -0.32, 0.22, 0.46, cy, 30, -10, True, True)
    p += [("flap", "box", (0.45, 0.07, 0.4), (0.5, 0.16, 0.5), vio, R(0, 45)), ("flap", "box", (0.45, 0.15, 0.4), (0.24, 0.06, 0.24), cy, R(0, 45, 0, n=True)), ("flap", "box", (0.6, 0.07, 0.82), (0.34, 0.14, 0.34), lil, R(0, 45)), ("low", "box", (0.4, 0.07, 0.6), (0.4, 0.14, 0.4), vio, R(0, 45)), ("low", "box", (0.4, 0.13, 0.6), (0.18, 0.06, 0.18), cy, R(0, 45, 0, n=True))]
    return {"main": "#271b9f", "flap": "#1d1180", "trim": cy, "trimneon": True, "cushion": "#615fd6", "cushion2": "#7a78e8", "strap": "#615fd6", "pieces": p}


def portal():
    vio, lil, dk, cy = "#4a2fd0", "#a09bff", "#120838", "#64fffd"
    p = [("can", "box", (0, 0.14, 0.2), (2.0, 0.32, 0.4), dk)]
    rad, cy0 = 1.5, 1.34
    for i, a in enumerate((-158, -126, -94, -62, 62, 94, 126, 158)):
        r = math.radians(a)
        c = vio if i % 2 else dk
        p.append(("can", "box", (math.sin(r) * rad, cy0 + math.cos(r) * rad, 0.4), (0.82, 0.3, 0.34), c, R(0, 0, -a)))
        p.append(("can", "box", (math.sin(r) * (rad - 0.17), cy0 + math.cos(r) * (rad - 0.17), 0.4), (0.7, 0.09, 0.26), cy, R(0, 0, -a, n=True)))
    for x, y, z, s in ((0.92, 2.5, 0.4, 0.26), (0.5, 2.72, 0.5, 0.18), (1.75, 2.1, 0.5, 0.2)):
        p.append(("can", "box", (x, y, z), (s, s, s), lil, RB(30, 40, 20)))
    p += [("pom", "box", (0, 0.14, -0.3), (0.8, 0.3, 0.44), dk), ("pom", "box", (0, 0.5, -0.3), (0.44, 0.12, 0.2), cy, R(0, 0, 0, n=True)), ("pom", "box", (0, 0.72, -0.3), (0.3, 0.3, 0.3), lil, R(35, 45, 0)), ("pom", "box", (0.34, 0.4, -0.3), (0.16, 0.4, 0.22), vio, RB(0, 0, -14))]
    p += [("flap", "box", (0.45, 0.06, 0.6), (0.6, 0.12, 0.12), cy, R(0, 45, 0, n=True)), ("flap", "box", (0.45, 0.06, 0.6), (0.6, 0.12, 0.12), cy, R(0, -45, 0, n=True)), ("flap", "box", (0.45, 0.1, 0.6), (0.3, 0.16, 0.3), lil, R(0, 45)), ("low", "box", (0.4, 0.12, 0.5), (0.3, 0.24, 0.3), lil, R(30, 40, 0))]
    return {"main": "#220979", "flap": "#1a0660", "trim": cy, "trimneon": True, "cushion": "#8f8cf0", "cushion2": "#615fd6", "strap": vio, "pieces": p}


DESIGNS = {"1A": ("Scallop", scallop, "a scallop shell behind the rider, a pearl in front, teal seat"), "1B": ("Giant Clam", clam, "an open clam flaring out to both sides, its lips teal"),
           "2A": ("Coral Twigs", twigs, "coral branches with gold tips"), "2B": ("Anemone", anemone, "a fan of anemone arms with bulbs"),
           "3A": ("Kelp Wrap", kelp, "broad kelp blades, a float for a horn"), "3B": ("Kelp Crown", crown, "two tall kelp stalks with floats"),
           "4A": ("Crate", crate, "ship's planks, iron corners, a rope coil"), "4B": ("Captain's Wheel", wheel, "a ship's wheel between two lamps, anchors on the sides"),
           "5A": ("Wave", wave, "a wave curling over, white foam"), "5B": ("Splash Wings", wings, "swept wings of spray"),
           "6A": ("Frost", frost, "snow and a row of ice crystals, icicles on the hem"), "6B": ("Crystal Throne", throne, "big slanting crystals"),
           "7A": ("Lantern", lantern, "a glowing lure on a stalk, rows of lights"), "7B": ("Jelly Bells", jelly, "two jellyfish with trailing arms, glowing mushrooms"),
           "8A": ("Ember", ember, "basalt columns with lava between them"), "8B": ("Twin Vents", vents, "two smoking chimneys, lava on the sides"),
           "9A": ("Rib", ribs, "ribs round the fish, a backbone horn"), "9B": ("Ghost Skull", skull, "a skull looking back with ghost lights, tusks"),
           "10A": ("Star Rock", star, "space rock with cyan edges, a quartz horn"), "10B": ("Portal Ring", portal, "a broken portal ring round the rider")}
RECOMMENDED = {1: "A", 2: "A", 3: "A", 4: "B", 5: "B", 6: "A", 7: "A", 8: "A", 9: "B", 10: "B"}


def design(key):
    """the design; its small balls as blocks turned to a corner (a ball is eighteen times a block's triangles)"""
    d = DESIGNS[key][1]()
    d["pieces"] = [(a, "box", p, tuple(v * 0.84 for v in s), c, dict(o[0] if o else {}, r=(45, 35, 0) if a in ("can", "pom") else (0, 45, 0)))
                   if sh == "ball" and max(s) < 0.39 else (a, sh, p, s, c, *o) for a, sh, p, s, c, *o in d["pieces"]]
    return d


def count(parts):
    return len(parts), sum(TRIS[p["shape"]] for p in parts)


if __name__ == "__main__":
    for key in DESIGNS:
        parts = build(design(key), plain())
        print(key, DESIGNS[key][0], count(parts))
    out = {}
    for key, (name, _, what) in DESIGNS.items():
        d = design(key)
        d["pieces"] = [{"a": a, "s": sh, "p": [round(v, 3) for v in p], "z": [round(v, 3) for v in s], "c": c, **{{"r": "r", "n": "neon", "both": "both", "mid": "mid"}[q]: (list(v) if q == "r" else True)
                       for q, v in (o[0] if o else {}).items() if v and (q != "r" or any(v))}} for a, sh, p, s, c, *o in d["pieces"]]
        out[key] = {"land": int(key[:-1]), "name": name, "what": what, "recommended": RECOMMENDED[int(key[:-1])] == key[-1], **d}
    os.makedirs(X.OUT, exist_ok=True)
    txt = ",\n".join(json.dumps(k) + ": " + json.dumps(v, separators=(",", ":")).replace('{"a":', '\n  {"a":') for k, v in out.items())
    open(os.path.join(X.OUT, "saddles.json"), "w").write("{\n" + txt + "\n}\n")
