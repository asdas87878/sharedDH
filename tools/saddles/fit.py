"""The saddle's fit on every kind of fish at all six sizes, from the creature models alone (no Studio).

    python tools/saddles/fit.py             fits and checks all: art/saddles/fit.json, work/saddles/check.json, the table
    python tools/saddles/fit.py Clownfish   one kind, printed

The saddle hangs on the seat point (the back's top under the rider), on the very joint the rider is locked to
(AnimController.seatOf). Its pocket is the rider's size at every fish size, because the rider never grows and the seat
is always 1.4 studs over the back; the rest grows with the fish (`grow`). The blanket is draped: a centre pad as wide
as the back is level, then two panels a side that swing down on their hinges until they touch, as far as they reach
without lying on a fin. Each panel's underside is sunk to the fish, so no gap shows.

A fit (studs, degrees, at that size; x across, y up, z back, from the seat point):
  joint          the part it is welded to
  grow           how much bigger than the rider's own the trimmings are
  front, back    how far the pad runs ahead of the seat point and behind it
  half           the pad's half width;  slot: the half width left open down its middle for a ridge (0: none)
  top, base      the pad's top, and what its underside stands at;  pad: [how deep its underside goes into the fish]
  flaps          up to two panels a side, from the pad outward: [length, droop, sink, rise, z0, z1]
  strap          the same row or null: the girth's end below the flaps
  shelf          [z0, z1, y, half width] or null: the roll on a plate of the fish's own ahead of the rider
  pommel         true, or false where the fish's own head or fin stands there;  yf, yb: what the pommel and the cantle stand on
  cantle         "full"; "split" (a thin fin stands in its middle: the middle pieces are left out); "none"
  style          drape (hangs on both sides), flat (a wide pad: rays, shells, giants), tray (walls or spikes beside),
                 slot (a ridge under the rider), step (a plate ahead), ledge (a short front)"""
import json
import math
import multiprocessing
import os
import sys

import numpy as np

import fish as F

OUT = os.path.join(F.ROOT, "art", "saddles")
STEP = 0.08
THICK = 0.16  # a panel's thickness over the fish
POCKET_FRONT, POCKET_BACK = 0.95, 0.72  # the rider's room, from the seat point
SEAT_TOP = 0.38  # the cushion's top: the rider's hips are 0.4 over the back


def grow(f, s):
    return min(2.0, max(0.85, (f.size[2] * s / 16) ** 0.4))


def limbs(f):
    """the joints that are not the back: side fins, wings, legs, arms, jaws, and everything hung on them"""
    out = set()
    c = 0.05 * f.rig["Size"][0] * f.k + 0.05
    first = f.rig["Parts"][0][0]
    for name, (parent, pivot) in f.joint.items():
        side = abs(pivot[0]) > c and name != first
        if side or "Jaw" in name or parent in out:
            out.add(name)
    out -= set(f.chain(f.seat_part()))
    return out


def heights(T, at, reach, zr):
    """the highest surface over each cell of a grid round `at`: H[x, z] relative to at's height (nan: nothing)"""
    xs = np.arange(-reach, reach + STEP / 2, STEP) + 0.0137
    zs = np.arange(-zr, zr + STEP / 2, STEP) + 0.0173
    H = np.full((len(xs), len(zs)), -np.inf)
    P = T - at
    lo, hi = P.min(1), P.max(1)
    for tri in P[(hi[:, 0] > -reach) & (lo[:, 0] < reach) & (hi[:, 2] > -zr) & (lo[:, 2] < zr)]:
        a, b, c = tri
        d = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
        if abs(d) < 1e-9:
            continue
        i0, i1 = np.searchsorted(xs, tri[:, 0].min()), np.searchsorted(xs, tri[:, 0].max())
        j0, j1 = np.searchsorted(zs, tri[:, 2].min()), np.searchsorted(zs, tri[:, 2].max())
        if i0 == i1 or j0 == j1:
            continue
        X, Z = np.meshgrid(xs[i0:i1], zs[j0:j1], indexing="ij")
        u = ((b[2] - c[2]) * (X - c[0]) + (c[0] - b[0]) * (Z - c[2])) / d
        v = ((c[2] - a[2]) * (X - c[0]) + (a[0] - c[0]) * (Z - c[2])) / d
        w = 1 - u - v
        y = np.where((u >= 0) & (v >= 0) & (w >= 0), u * a[1] + v * b[1] + w * c[1], -np.inf)
        H[i0:i1, j0:j1] = np.maximum(H[i0:i1, j0:j1], y)
    return xs, zs, H


def droop(xp, P, x0, y0, length, least=0.0):
    """the steepest a panel from (x0, y0) can hang without entering the profile P(xp), degrees"""
    for a in np.arange(84, least - 1e-6, -1.5):
        r = math.radians(a)
        end = x0 + length * math.cos(r)
        m = (xp > x0 + 0.02) & (xp < end)
        if not m.any() or np.all(y0 - (xp[m] - x0) * math.tan(r) >= P[m] - 0.02):
            return float(a)
    return float(least)


def hang(xp, P, x0, y0, most, least, deep):
    """the length and droop of a panel that lies closest along the profile: (length, degrees)"""
    ok = P > -50
    line = np.stack([xp[ok], P[ok]], 1)
    if len(line) == 0:
        return 0.0, least
    out = line[-1]
    side = np.stack([np.full(40, out[0]), np.linspace(out[1], -deep, 40)], 1) if out[1] > -deep else line[-1:]
    path = np.concatenate([line, side])
    best = (-9.0, 0.0, least)
    for share in (1.0, 0.85, 0.7, 0.55, 0.42, 0.3):
        ln = most * share
        a = droop(xp, P, x0, y0, ln, least)
        r = math.radians(a)
        u = np.linspace(0.1, 1, 8) * ln
        pts = np.stack([x0 + u * math.cos(r), y0 - u * math.sin(r)], 1)
        d = np.sqrt(((pts[:, None] - path[None]) ** 2).sum(2)).min(1)
        score = ln / most - 1.6 * float(np.mean(np.maximum(d - 0.15, 0))) / math.sqrt(most) - 0.8 * float(max(0, d[-1] - 0.3))
        if score > best[0]:
            best = (score, ln, a)
    return best[1], best[2]


def hits(O, D, T, far):
    """distance along each ray (one direction D) to the first triangle, inf for none. O (n, 3), T (m, 3, 3)"""
    if len(T) == 0:
        return np.full(len(O), np.inf)
    lo, hi = O.min(0), O.max(0)
    ends = np.stack([lo, hi, lo + D * far, hi + D * far])
    lo, hi = ends.min(0) - 0.01, ends.max(0) + 0.01
    T = T[np.all(T.max(1) >= lo, 1) & np.all(T.min(1) <= hi, 1)]
    if len(T) == 0:
        return np.full(len(O), np.inf)
    a, e1, e2 = T[:, 0], T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
    h = np.cross(np.broadcast_to(D, e2.shape), e2)
    det = (e1 * h).sum(1)
    ok = np.abs(det) > 1e-9
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    sv = O[:, None] - a[None]
    u = (sv * h[None]).sum(2) * inv
    q = np.cross(sv, np.broadcast_to(e1[None], sv.shape))
    v = (q @ D) * inv
    t = (q * e2[None]).sum(2) * inv
    t = np.where(ok[None] & (u >= -1e-5) & (v >= -1e-5) & (u + v <= 1 + 1e-5) & (t > 0) & (t < far), t, np.inf)
    return t.min(1)


def frames(fit):
    """the panels as frames in saddle space: (name, side, origin (the hinge), u axis, normal, length, sink, rise, z0, z1).
    A panel is a box from `sink` under its plane to `rise` over it."""
    p = fit["pad"]
    up, x = np.array([0, 1.0, 0]), np.array([1.0, 0, 0])
    if fit["slot"]:  # a ridge of the fish's own comes up through the middle: the pad is two halves beside it
        out = [("pad", sd, np.array([sd * fit["slot"], fit["base"], 0.0]), sd * x, up, fit["half"] - fit["slot"], p[0], fit["top"] - fit["base"], -fit["front"], fit["back"]) for sd in (-1, 1)]
    else:
        out = [("pad", 0, np.array([-fit["half"], fit["base"], 0.0]), x, up, 2 * fit["half"], p[0], fit["top"] - fit["base"], -fit["front"], fit["back"])]
    if fit["shelf"]:
        z0, z1, y, hw = fit["shelf"]
        out.append(("shelf", 0, np.array([-hw, y, 0.0]), x, up, 2 * hw, 0.08, THICK, z0, z1))
    for side in (-1, 1):
        at = np.array([side * fit["half"], fit["base"], 0.0])
        for name, row in zip(("flap1", "flap2", "strap"), fit["flaps"] + ([fit["strap"]] if fit["strap"] else [])):
            length, ang, sink, rise, z0, z1 = row
            r = math.radians(ang)
            u = np.array([side * math.cos(r), -math.sin(r), 0])
            n = np.array([side * math.sin(r), math.cos(r), 0])
            out.append((name, side, at.copy(), u, n, length, sink, rise, z0, z1))
            at = at + u * length
    return out


def grid(frame, nu=7, nz=7, inset=0.05):
    name, side, at, u, n, length, sink, rise, z0, z1 = frame
    return np.array([at + u * a + np.array([0, 0, z]) for a in np.linspace(min(inset, length / 2), max(length - inset, length / 2), nu) for z in np.linspace(z0 + inset, z1 - inset, nz)])


SINK = {"pad": 0.42, "flap1": 0.55, "flap2": 0.45, "strap": 0.35}  # x grow^0.5: the most a panel's underside goes down
RISE = 0.3  # the most a panel stands over its plane, to clear a knob on the back


def span(zs, poke, gap, least, dims):
    """the biggest rectangle [0, k) x [j0, j1) of a panel that lies well: nothing pokes through it (poke), and its three
    free edges are on the fish (gap; a hole under the middle does not show). `dims`: it must reach over z -least..least"""
    nu, nz = poke.shape
    cum = lambda b: np.pad(b.astype(float).cumsum(0).cumsum(1), ((1, 0), (1, 0)))  # noqa: E731
    S, G = cum(poke), cum(gap)
    part = lambda C, k, j0, j1: C[k, j1] - C[0, j1] - C[k, j0] + C[0, j0]  # noqa: E731
    best = None
    for j0 in range(0, nz - 1):
        if zs[j0] > -least[0] + 0.12 and j0 > 0:
            break
        for j1 in range(nz, j0, -1):
            if zs[j1 - 1] < least[1] - 0.12 and j1 < nz:
                break
            for k in range(nu, 0, -1):
                area = k * (j1 - j0)
                if best and area <= best[0]:
                    break
                if part(S, k, j0, j1) > 0.03 * area or part(G, k, j0, j1) > 0.4 * area:
                    continue
                if max(gap[:k, j0].mean(), gap[:k, j1 - 1].mean(), gap[k - 1, j0:j1].mean()) > dims:
                    continue
                best = (area, k, j0, j1)
    return best


def lie(f, frame, body, lims, g, least=(0.2, 0.2), edge=0.13, deep=0.0):
    """the part of a panel that lies well on the fish: (length, z0, z1, sink, rise) or None. Both sides must do."""
    name, side, at, u, n, length, _, rise0, z0, z1 = frame[:10]
    nu, nz = max(4, int(round(length / 0.1))), max(6, int(round((z1 - z0) / 0.12)))
    us = (np.arange(nu) + 0.5) / nu * length
    zs = z0 + (np.arange(nz) + 0.5) / nz * (z1 - z0)
    deep = max(deep, SINK[name] * math.sqrt(g))
    most = rise0 if name == "pad" else RISE
    D = np.full((2, nu, nz), np.inf)
    Lb = np.zeros((2, nu, nz), bool)
    for i, sd in enumerate((-1, 1)):
        m = np.array([sd * side, 1, 1])
        pts = np.array([at + u * a + np.array([0, 0, z]) for a in us for z in zs]) * m
        N = n * m
        D[i] = (hits(pts + N * 1.4, -N, body, 4.4) - 1.4).reshape(nu, nz)
        Lb[i] = (hits(pts + N * 1.4, -N, lims, 1.36) < 1.36).reshape(nu, nz) if len(lims) else False
    poke = ((D < -most + 0.01) | Lb).any(0)
    if fitcut := frame[10] if len(frame) > 10 else None:  # (a thin fin the cantle straddles: not under the pad's count)
        poke[np.ix_(us < fitcut[0], zs > fitcut[1])] = False
    best = span(zs, poke, (D > deep).any(0), least, edge)
    if not best:
        return None
    _, k, j0, j1 = best
    sub = D[:, :k, j0:j1]
    sub = sub[(sub <= deep) & (sub >= -most)]
    sink = float(np.clip(np.quantile(sub, 0.97) + 0.08, 0.08, deep + 0.08)) if len(sub) else 0.1
    rise = float(np.clip(-sub.min() + 0.05, 0.12, RISE + 0.05)) if len(sub) else 0.12
    dz = (z1 - z0) / nz
    return [k * length / nu, z0 + j0 * dz, z0 + j1 * dz, round(sink, 3), round(rise, 3)]


# A crack in a flat back that the saddle's mat goes straight across, the way a board lies over a gap: (x0, x1, z0, z1) in
# studs from the seat at Normal. The fit and the check count it as closed; nothing in the game's model changes.
CRACKS = {"Hellmaw": (-2.75, -0.5, -2.5, -0.02)}


def lidded(f, s, T, who, joint):
    """the fish with the cracks a saddle bridges closed, seat-relative"""
    if f.id not in CRACKS:
        return T, who
    x0, x1, z0, z1 = (v * s for v in CRACKS[f.id])
    a, b, c, d = [x0, 0, z0], [x1, 0, z0], [x1, 0, z1], [x0, 0, z1]
    return np.concatenate([T, np.array([[a, c, b], [a, d, c]], float)]), np.concatenate([who, [joint, joint]])


def make(f, tier, s=None):
    s = s if s is not None else f.scale(tier)
    at = f.seat * s
    g = grow(f, s)
    lim = limbs(f)
    T, who = f.tris(s)
    T, who = lidded(f, s, T - at, who, f.seat_part(s))
    T = T + at
    isl = np.isin(who, list(lim))
    reach, zr = 5.2 * g, 3.4 * g
    near = np.all(T.max(1) > at - [reach, 60, zr], 1) & np.all(T.min(1) < at + [reach, 60, zr], 1)
    body, lims = T[near & ~isl] - at, T[near & isl] - at
    xs, zs, H = heights(T[near & ~isl], at, reach, zr)
    _, _, L = heights(T[near & isl], at, reach, zr)
    mid = np.abs(xs) <= 0.42
    wide = np.abs(xs) <= 0.9
    # a line along the back that runs under the rider: the pad's top goes over it, or it comes up through a slot
    under = H[np.ix_(mid, (zs > -0.1) & (zs < 0.6))]
    ridge = 0.0
    if np.isfinite(under).any():  # (along the whole seat: a step or a plate ahead is not a ridge)
        ridge = max(0.0, float(np.quantile(np.where(np.isfinite(under), under, 0).max(0), 0.25)))
    slot = 0.0
    if ridge + 0.04 > SEAT_TOP:
        row = H[:, (zs > -0.3) & (zs < 0.6)].max(1)
        slot = float(np.abs(xs[row > 0.3 * ridge]).max()) + STEP / 2 + 0.06
        if slot > 1.6 * g:
            slot = 0.0
    top = THICK if slot else min(max(THICK, ridge + 0.04), SEAT_TOP)
    low = min(0.0, float(np.median(under[np.isfinite(under)]))) if np.isfinite(under).any() else 0.0
    wall = top + 0.05
    inner = slot + 0.3 if slot else 0.0

    def clear(sign, cols):
        """how far from the seat along z until something stands over the pad, in these columns"""
        for k in (np.argsort(zs) if sign > 0 else np.argsort(-zs)):
            if zs[k] * sign > 0.12 and (np.any(H[cols, k] > wall) or np.any(L[cols, k] > wall)):
                return abs(float(zs[k])) - STEP / 2
        return zr
    if slot:
        mid = np.abs(xs) <= slot + 0.3
        wide = (np.abs(xs) >= slot) & (np.abs(xs) <= slot + 0.8)
    cf, cb = clear(-1, mid), clear(1, mid)
    cbs, cfs = clear(1, (np.abs(xs) >= 0.3) & wide), clear(-1, (np.abs(xs) >= 0.3) & wide)
    if slot:
        cf, cb = cfs, cbs
    part = f.seat_part(s)
    v = f.parts[part][0] * s - at
    seg0, seg1 = float(v[:, 2].min()), float(v[:, 2].max())
    # no longer than the segment it sits on plus a little, and never into something standing (a thin fin is straddled)
    front = min(1.5 * min(g, 1.5), max(1.2, -seg0 + 0.5 * g), max(0.15, min(cf, cfs) - 0.05))
    back = min(1.3 * min(g, 1.5), max(1.0, seg1 + 0.5 * g), max(0.5, cbs - 0.05))
    rows = (zs >= -front * 0.8) & (zs <= back * 0.8)
    n = min((xs > 0).sum(), (xs < 0).sum())
    both = np.concatenate([H[xs > 0][:n][:, rows], H[xs < 0][::-1][:n][:, rows]], 1)
    xp = xs[xs > 0][:n]
    P = np.quantile(both, 0.9, axis=1, method="nearest")
    tall = both.max(1)
    P = np.where(np.isfinite(P), P, -99.0)
    walls = np.where((tall > wall) & (xp > max(0.34, slot)))[0]
    limit = float(xp[walls[0]]) - 0.1 if len(walls) else 99.0
    P = np.where(xp < slot, np.minimum(P, 0.0), P)
    level = np.where((P < low - 0.12 - 0.02 * g) & (xp > slot))[0]
    edge = float(xp[level[0]]) - STEP / 2 if len(level) else 99.0
    w = max(0.42, slot + 0.4 if slot else 0, min(edge, (slot + 0.8 * g) if slot else 1.2 * g, limit))
    style = "tray" if limit < 1.6 * g else ("flat" if edge >= 1.2 * g else "drape")
    shelf = None
    if front < 0.3 and not slot:  # a plate of the fish's own stands under the rider's front: the seat is behind it, a roll on it
        style = "step"
        front = -0.3
        h = H[np.ix_(np.abs(xs) < 0.8, (zs > -1.7) & (zs < -0.6))]
        if np.isfinite(h).all() and np.ptp(h) < 0.1 and h.max() < 1.6:
            shelf = [-1.6 * min(g, 1.3), -0.62, round(float(h.max()), 3), min(0.75, w)]
        w = max(0.42, min(1.2 * g, w))
    if slot:
        style = "slot"
    elif front < 0.7 and not (front < 0.3):
        style = "ledge"
    fit = {"joint": part, "grow": g, "front": front, "back": back, "half": w, "slot": slot, "top": top, "base": top - THICK, "pad": [0.1], "flaps": [], "strap": None,
           "cantle": "full", "style": style, "wall": wall, "shelf": shelf}
    # the pad: the widest and longest that lies well (its half from the middle out, the same both sides)
    inn = slot or 0.0
    pl = w - inn
    frame = ("pad", 1, np.array([inn, fit["base"], 0.0]), np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), pl, 0, THICK + 0.03, -front, back, (0.3, max(0.3, cb - 0.05)))
    far = 0.1 - low  # (a back that lies under the seat point: the pad is a thicker block down to it)
    got = lie(f, frame, body, lims, g, (min(0.7, front), min(0.62, back)), 0.13, far)
    if style == "step":
        pl = w = 1.2 * g
        frame = frame[:5] + (pl,) + frame[6:]
        got = lie(f, frame, body, lims, g, (front, 0.45), 0.13)
    if not got or got[0] < min(0.4, pl):
        got = lie(f, frame, body, lims, g, (min(0.4, front), min(0.45, back)), 0.3, far) or got
    if got:
        fit["half"] = w = inn + max(got[0], 0.42 if not slot else 0.3)
        fit["front"], fit["back"] = front, back = -got[1], got[2]
        fit["pad"] = [got[3]]
    else:
        fit["half"] = w = inn + 0.42
        fit["style"] = style = fit["style"] + "!"
    fit["pommel"] = bool(front >= 1.2 or shelf)
    fit["cantle"] = "none" if back < 0.98 else ("full" if cb >= back + 0.03 else "split")
    # what the pommel and the cantle stand on
    for key, rowz in (("yf", (zs > -front) & (zs < -POCKET_FRONT)), ("yb", (zs > POCKET_BACK) & (zs < back))):
        h = H[np.ix_((np.abs(xs) < max(0.6, slot)) & (np.abs(xs) > (0.3 if fit["cantle"] == "split" and key == "yb" else 0)), rowz)]
        h = h[np.isfinite(h)]
        if shelf and key == "yf":
            fit[key] = shelf[2] + THICK
            continue
        fit[key] = round(max(top, float(np.quantile(h, 0.9)) + 0.04) if len(h) else top, 3)
    # the panels, from the pad outward
    x0, y0, prev = w, fit["base"], 0.0
    size = f.size * s
    deepest = min(size[1], 6 * g)
    for i, (name, most) in enumerate((("flap1", 0.95 * g), ("flap2", 1.0 * g))):
        if x0 + 0.15 >= limit:
            break
        ln, a = hang(xp, P, x0, y0, most, prev, deepest)
        r = math.radians(a)
        if limit < 99 and math.cos(r) > 0.02:
            ln = min(ln, (limit - x0) / math.cos(r))
        if ln < 0.22:
            break
        k = 0.94 if i == 0 else 0.82
        zz = (-fit["front"] * k, fit["back"] * k) if i == 0 else (fit["flaps"][0][4] * 0.94, fit["flaps"][0][5] * 0.94)
        sd = 1
        frame = (name, sd, np.array([x0, y0, 0.0]), np.array([math.cos(r), -math.sin(r), 0]), np.array([math.sin(r), math.cos(r), 0]), ln, 0, 0, *zz)
        got = lie(f, frame, body, lims, g, (0.1, 0.1))
        if not got or got[0] < 0.2:
            break
        use, z0, z1, sink, rise = got
        fit["flaps"].append([round(use, 3), a, sink, rise, round(z0, 3), round(z1, 3)])
        if use < ln - 0.14:
            break
        x0, y0, prev = x0 + use * math.cos(r), y0 - use * math.sin(r), a
    # the girth's end: a band further down where the side is steep and the fish is right there
    if len(fit["flaps"]) == 2 and fit["flaps"][1][1] >= 48:
        a = max(fit["flaps"][1][1], 78.0)
        r = math.radians(a)
        hw = 0.3 * g
        frame = ("strap", 1, np.array([x0, y0, 0.0]), np.array([math.cos(r), -math.sin(r), 0]), np.array([math.sin(r), math.cos(r), 0]), 1.1 * g, 0, 0, 0.1 - hw, 0.1 + hw)
        got = lie(f, frame, body, lims, g, (0.0, 0.0))
        if got and got[0] > 0.5 * g and got[2] - got[1] > 1.6 * hw:
            fit["strap"] = [round(got[0], 3), a, got[3], got[4], round(got[1], 3), round(got[2], 3)]
    return fit, (at, s, part)


LIMITS = {"rest": (0.35, 0.15, 0.05, 0.05, 0.06), "hard": (0.5, 0.3, 0.12, 0.08, 0.1), "turn": (0.5, 0.3, 0.12, 0.08, 0.1)}
MEASURES = ("gap", "off", "poke", "pokeshare", "fin")


def faults(c):
    """what a check finds too much of: [(pose, measure, value, limit)]"""
    out = []
    for k, lim in LIMITS.items():
        if k in c:
            v = c[k]
            for m, x in zip(MEASURES, lim):
                if v[m] > x and not (m == "poke" and v["pokeshare"] <= lim[3]) and not (m == "pokeshare" and v["poke"] <= lim[2]):
                    out.append((k, m, v[m], x))
    return out


def worse(c):
    return sum(v / x - 1 for _, _, v, x in faults(c)) + 0.3 * len(faults(c))


def edits(fit):
    """smaller saddles, the least lost first"""
    def new(**kw):
        g = json.loads(json.dumps(fit, default=float))
        g.update(kw)
        return g
    fl = json.loads(json.dumps(fit["flaps"], default=float))
    if fit["strap"]:
        yield new(strap=None)
    if len(fl) == 2:
        yield new(flaps=fl[:1], strap=None)
        if fl[1][0] > 0.5:
            yield new(flaps=[fl[0], [fl[1][0] * 0.75] + fl[1][1:]], strap=None)
    if fl:
        yield new(flaps=[], strap=None)
        for a, b in ((0.8, 1), (1, 0.8), (0.8, 0.8)):
            yield new(flaps=[r[:4] + [r[4] * a, r[5] * b] for r in fl])
        for d in (0.12, 0.25):
            yield new(flaps=[r[:2] + [r[2] + d] + r[3:] for r in fl])
        if fl[0][0] > 0.5:
            yield new(flaps=[[fl[0][0] * 0.75] + fl[0][1:]], strap=None)
        yield new(flaps=[r[:3] + [min(r[3] + 0.1, 0.45)] + r[4:] for r in fl])
    cut = lambda fr, bk: [r[:4] + [max(r[4], -fr * 0.94), min(r[5], bk * 0.94)] for r in fl]  # noqa: E731
    for a, b in ((0.85, 1), (1, 0.85), (0.85, 0.85)):
        fr, bk = fit["front"] * a, fit["back"] * b
        if (fr >= 0.6 or a == 1) and (bk >= 0.55 or b == 1):
            yield new(front=fr, back=bk, flaps=cut(fr, bk))
    yield new(pad=[fit["pad"][0] + 0.15])
    if fit["half"] - fit["slot"] > 0.6:
        w = fit["slot"] + max(0.42, (fit["half"] - fit["slot"]) * 0.8)
        yield new(half=w, flaps=[], strap=None)


def repair(f, fit, at, s):
    """the fit, made smaller or deeper until the check passes; and its check"""
    c = check(f, fit, at, s)
    tries = 0
    while faults(c) and tries < 7:
        tries += 1
        best = None
        for g in edits(fit):
            q = check(f, g, at, s, "some")
            w = worse(q)
            if best is None or w < best[0] - 0.02:
                best = (w, g)
            if w == 0:
                break
        if best is None or best[0] >= worse({k: c[k] for k in LIMITS}) - 0.01:
            break
        fit = best[1]
        c = check(f, fit, at, s)
    fit["pommel"] = bool(fit["front"] >= 1.2 or fit["shelf"])
    if fit["back"] < 0.98:
        fit["cantle"] = "none"
    fit["tries"] = tries
    return fit, c


def check(f, fit, at, s, poses=True):
    """gap and poke, in studs: at rest and through the swim. gap: a panel's underside off the fish (its edge, where it
    would show); poke: the fish's back through a panel's outer face; fin: the share of a panel that a fin stands in."""
    lim = limbs(f)
    out = {}
    list_ = [("rest", None, 1.0, 0.0)]
    if poses:
        for sw, name in ((2.3, "hard"),) if poses == "some" else ((1.0, "swim"), (2.3, "hard")):
            for m in range(0, 8, 2 if poses == "some" else 1):
                list_.append((name, m / 8, sw, 0.0))
        for b in (-5, 5):
            list_.append(("turn", 0.0, 1.0, b))
    frs = frames(fit)
    for kind, u, sw, b in list_:
        pose = f.pose(u, sw, b, s)
        T, who = f.tris(s, pose)
        inv = np.linalg.inv(pose[fit["joint"]])
        T = T @ inv[:3, :3].T + inv[:3, 3] - at
        T, who = lidded(f, s, T, who, fit["joint"])
        near = np.all(T.max(1) > [-12, -14, -8], 1) & np.all(T.min(1) < [12, 8, 8], 1)
        T, who = T[near], who[near]
        isl = np.isin(who, list(lim))
        body, lims = T[~isl], T[isl]
        gaps, pokes, fins, off = [], [], [], []
        for fr in frs:
            name, side, o, uax, n, length, sink, rise, z0, z1 = fr
            pts = grid(fr, 7, 7)
            d = hits(pts + n * 1.6, -n, body, 4.6) - 1.6
            up = np.where(np.isfinite(d), -d - rise, 0)
            isfin = up > 0.4  # (a thing standing well over the panel is a fin or a spike through it, not the back)
            ll = hits(pts + n * 1.6, -n, lims, 1.6 + sink) - 1.6
            fins += list(isfin | (np.isfinite(ll) & (-ll > rise + 0.03)))
            pokes += list(np.where(isfin, 0, np.maximum(up, 0)))
            ed = np.concatenate([grid(fr, 7, 2, 0.03), grid(fr, 2, 7, 0.03)])
            de = hits(ed + n * 1.0, -n, body, 4.0) - 1.0 - sink
            far = ~(de < 0.5)
            off += list(far)
            gaps += list(np.maximum(de[~far], 0))
        r = out.setdefault(kind, {"gap": 0.0, "off": 0.0, "poke": 0.0, "pokeshare": 0.0, "fin": 0.0})
        gaps = gaps or [9.0]
        pk = np.array(pokes)
        r["gap"] = max(r["gap"], float(np.quantile(gaps, 0.95)))
        r["off"] = max(r["off"], float(np.mean(off)))
        r["poke"] = max(r["poke"], float(np.quantile(pk, 0.98)))
        r["pokeshare"] = max(r["pokeshare"], float((pk > 0.03).mean()))
        r["fin"] = max(r["fin"], float(np.mean(fins)))
    return out


def export(res):
    """art/saddles/fit.json: what the game needs, one short row a kind and size, rounded to a hundredth"""
    os.makedirs(OUT, exist_ok=True)
    r = lambda v: round(float(v), 2)  # noqa: E731
    lines = []
    for id in sorted(res):
        rows = {}
        for tier in F.TIERS:
            f = res[id][tier]["fit"]
            rows[tier] = {"joint": f["joint"], "grow": r(f["grow"]), "front": r(f["front"]), "back": r(f["back"]), "half": r(f["half"]), "slot": r(f["slot"]), "top": r(f["top"]), "base": r(f["base"]),
                          "pad": [r(f["pad"][0])], "yf": r(f["yf"]), "yb": r(f["yb"]), "pommel": f["pommel"], "cantle": f["cantle"], "style": f["style"],
                          "flaps": [[r(v) for v in q] for q in f["flaps"]], "strap": [r(v) for v in f["strap"]] if f["strap"] else None, "shelf": [r(v) for v in f["shelf"]] if f["shelf"] else None}
        lines.append(json.dumps(id) + ": {\n" + ",\n".join(f"  {json.dumps(k)}: {json.dumps(v, separators=(',', ':'))}" for k, v in rows.items()) + "}")
    open(os.path.join(OUT, "fit.json"), "w").write("{\n" + ",\n".join(lines) + "\n}\n")


def rows_of(id):
    f = F.load(id)
    got = {}
    for tier in F.TIERS:
        fit, (at, s, part) = make(f, tier)
        fit, c = repair(f, fit, at, s)
        got[tier] = {"fit": fit, "s": s, "check": c}
    return id, got


if __name__ == "__main__":
    which = sys.argv[1:] or F.ids()
    with multiprocessing.Pool(8) as pool:
        res = dict(pool.imap_unordered(rows_of, which))
    os.makedirs(os.path.join(F.ROOT, "work", "saddles"), exist_ok=True)
    json.dump(res, open(os.path.join(F.ROOT, "work", "saddles", "check.json"), "w"), default=float)
    if not sys.argv[1:]:
        export(res)
    for id in sorted(res):
        f = F.load(id)
        n = res[id]["Normal"]
        fit = n["fit"]
        fl = " ".join(f"{r[0]:.1f}@{r[1]:.0f}/{r[2]:.2f}z{r[4]:.1f}:{r[5]:.1f}" for r in fit["flaps"])
        ms = ("gap", "off", "poke", "pokeshare", "fin")
        worst = {k: {m: max(res[id][t]["check"][k][m] for t in F.TIERS) for m in ms} for k in n["check"]}
        print(f"{id:18}{fit['style']:6}{'/'.join(sorted({res[id][t]['fit']['style'] for t in F.TIERS}))} g{fit['grow']:.2f} f{fit['front']:.2f} b{fit['back']:.2f} w{fit['half']:.2f} top{fit['top']:.2f} snk{fit['pad'][0]:.2f} [{fl}] "
              f"{'S' if fit['strap'] else '-'}{'P' if fit['pommel'] else '-'} can {','.join(res[id][t]['fit']['cantle'][0] for t in F.TIERS)}"
              f" | " + " ".join(f"{k}: g{v['gap']:.2f} o{v['off']:.2f} p{v['poke']:.2f}/{v['pokeshare']:.2f} f{v['fin']:.2f}" for k, v in worst.items()))
    print()
    bad = []
    for id in sorted(res):
        for tier in F.TIERS:
            c = res[id][tier]["check"]
            why = [f"{k} {m} {v:.2f}" for k, m, v, _ in faults(c)]
            if why:
                bad.append((id, tier))
                fit = res[id][tier]["fit"]
                print(f"!! {id} {tier} {fit['style']} f{fit['front']:.2f} b{fit['back']:.2f} w{fit['half']:.2f} slot{fit['slot']:.2f} {fit['cantle']} flaps {[(round(float(r[0]), 2), r[1]) for r in fit['flaps']]} tries {fit['tries']}: " + ", ".join(why))
    print(len(bad), "of", 6 * len(res), "flagged;", len({b[0] for b in bad}), "kinds")
