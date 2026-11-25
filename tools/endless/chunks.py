"""Cut a built lane (tools/endless/build_lane.py) into chunks, and measure the joints between them.

A chunk is every box of the lane between two cuts, in the frame of its own entrance: x to the right, y up from the floor,
z ahead. A set of boxes that is one thing (a coral, a wreck, a gate) goes whole to the chunk its middle is in."""
import json
import math
import os

import numpy as np

KINDS = ["face", "grass", "glow", "core", "barrier", "ground", "trim", "set", "setglow", "setsmoke", "prop"]
WALLISH = [KINDS.index(k) for k in ("face", "grass", "core")]
GROUND = KINDS.index("ground")
PROP = KINDS.index("prop")
LAP = 48.0


def load(folder):
    """a built lane: its boxes as arrays, with each box's place along the lane (s) and across it (u), and its line"""
    d = json.load(open(os.path.join(folder, "parts.json")))["parts"]
    meta = json.load(open(os.path.join(folder, "line.json")))
    line = np.array(meta["Line"])
    d = [p for p in d if p["k"] in KINDS]
    P = np.array([p["p"] for p in d], float)
    A = np.array([p["x"] + p["y"] + p["z"] for p in d], float).reshape(-1, 3, 3)
    S = np.array([p["s"] for p in d], float)
    C = np.array([p["c"] for p in d], np.uint8)
    K = np.array([KINDS.index(p["k"]) for p in d])
    T = np.array([p.get("t", 0.0) for p in d], float)
    X = np.array([len(p.get("tex", {})) for p in d])
    names = [p["n"] for p in d]
    # whole things: a prop's boxes share "kind_number" in their name, a set piece's too
    group, ids = np.full(len(d), -1), {}
    for i, n in enumerate(names):
        if K[i] in (PROP, 7, 8, 9):
            bits = n.split("_")
            key = "_".join(bits[:2]) if bits[0] == "Set" else "_".join(bits[:-1]) or n
            group[i] = ids.setdefault(key, len(ids))
    mid = P.copy()
    if ids:
        n = len(ids)
        cnt = np.bincount(group[group >= 0], minlength=n)
        for a in range(3):
            m = np.bincount(group[group >= 0], weights=P[group >= 0, a], minlength=n) / np.maximum(cnt, 1)
            mid[group >= 0, a] = m[group[group >= 0]]
    s = np.zeros(len(d))
    Lx, Lz = line[:, 1], line[:, 3]
    for a in range(0, len(d), 2000):
        q = mid[a:a + 2000]
        dd = (q[:, 0, None] - Lx[None]) ** 2 + (q[:, 2, None] - Lz[None]) ** 2
        s[a:a + 2000] = line[dd.argmin(1), 0]
    # the hub's own boxes lie behind the start
    keep = ~((s < 1.0) & (mid[:, 2] < 2.0))
    return {"P": P[keep], "A": A[keep], "S": S[keep], "C": C[keep], "K": K[keep], "T": T[keep], "X": X[keep], "G": group[keep],
            "s": s[keep], "line": line, "meta": meta, "names": [n for n, k in zip(names, keep) if k]}


def at(line, s):
    """x, y, z, heading, half left, half right at a place along the lane"""
    return np.array([np.interp(s, line[:, 0], line[:, c]) for c in range(1, 7)])


def basis(h):
    return np.array([[math.cos(h), 0, -math.sin(h)], [0, 1, 0], [math.sin(h), 0, math.cos(h)]])  # rows: right, up, ahead


def cut(lane, s0, s1, name):
    e, x = at(lane["line"], s0), at(lane["line"], s1)
    B = basis(e[3])
    m = (lane["s"] >= s0) & (lane["s"] < s1)
    # the floor is tiles on one world grid, so a cut across them is jagged: a chunk also carries the tiles up to LAP
    # studs past its ends, a hair lower, and they lie under the next chunk's own
    lap = ~m & (lane["K"] == GROUND) & (lane["s"] >= s0 - LAP) & (lane["s"] < s1 + LAP)
    m = m | lap
    P = (lane["P"][m] - e[:3] - np.array([0, 0.2, 0]) * lap[m][:, None]) @ B.T
    A = lane["A"][m] @ B.T
    ex = B @ (x[:3] - e[:3])
    line = lane["line"]
    lm = (line[:, 0] >= s0) & (line[:, 0] <= s1)
    way = (line[lm][:, 1:4] - e[:3]) @ B.T
    return {"name": name, "s0": s0, "s1": s1, "P": P, "A": A, "S": lane["S"][m], "C": lane["C"][m], "K": lane["K"][m],
            "T": lane["T"][m], "X": lane["X"][m], "G": lane["G"][m], "exit": ex, "turn": x[3] - e[3], "long": s1 - s0,
            "w0": (e[4], e[5]), "w1": (x[4], x[5]), "way": way, "half": line[lm][:, 5:7],
            "slope0": slope(line, s0), "slope1": slope(line, s1)}


def slope(line, s):
    a, b = at(line, s - 12), at(line, s + 12)
    return math.degrees(math.atan2(a[1] - b[1], 24))


def flip(c):
    """the same chunk, the other hand"""
    f = dict(c)
    f["name"] = c["name"] + "m"
    m = np.array([-1.0, 1, 1])
    f["P"], f["A"], f["exit"], f["way"] = c["P"] * m, c["A"] * m, c["exit"] * m, c["way"] * m
    f["turn"] = -c["turn"]
    f["w0"], f["w1"] = c["w0"][::-1], c["w1"][::-1]
    f["half"] = c["half"][:, ::-1]
    return f


def profile(c, end, us):
    """the height of the ground and walls across the chunk's end, at us (studs right of the middle), against the floor
    there: rays dropped just inside the cut (12 studs in), through the chunk's own boxes. NaN where nothing is"""
    h = c["turn"] if end else 0.0
    o = c["exit"] if end else np.zeros(3)
    B = basis(h)
    q = o - 12 * B[2] if end else o + 12 * B[2]
    pts = q + us[:, None] * B[0]
    m = np.isin(c["K"], WALLISH + [GROUND])
    d = np.abs((c["P"][m] - q) @ B[2]) < 120
    P, A, S = c["P"][m][d], c["A"][m][d], c["S"][m][d]
    out = np.full(len(us), np.nan)
    for i, p in enumerate(pts):
        # a ray straight down: in a box's own frame
        org = np.array([p[0], 600.0 + q[1], p[2]])
        r = np.einsum("nij,nj->ni", A, org - P)  # along its axes
        v = A @ np.array([0, -1.0, 0])
        with np.errstate(divide="ignore", invalid="ignore"):
            t1 = (-S / 2 - r) / v
            t2 = (S / 2 - r) / v
        lo = np.where(np.abs(v) < 1e-6, np.where(np.abs(r) <= S / 2, -np.inf, np.inf), np.minimum(t1, t2)).max(1)
        hi = np.where(np.abs(v) < 1e-6, np.where(np.abs(r) <= S / 2, np.inf, -np.inf), np.maximum(t1, t2)).min(1)
        hit = (lo <= hi) & (lo > 0) & (lo < 1200)
        if hit.any():
            out[i] = 600.0 - lo[hit].min()
    return out


def purpose(folder):
    lane = load(folder)
    out = []
    for li in range(1, 10):
        base = lane["meta"]["Starts"][li]
        for k in range(2):
            s0 = base + 300 + 1200 * k
            c = cut(lane, s0, s0 + 1200, f"{li + 1}{'ab'[k]}")
            c["land"] = li
            out.append(c)
    return out


def today(folder, first=3000.0, last=23400.0):
    lane = load(folder)
    necks = [n for n in lane["meta"]["Necks"] if first <= n <= last]
    out = []
    for a, b in zip(necks, necks[1:]):
        c = cut(lane, a, b, f"n{len(out)}")
        c["land"] = sum(1 for st in lane["meta"]["Starts"] if st <= a + 1) - 1
        out.append(c)
    return out, lane
