# Final per-hop measures (counter, by-eye rope connect) -> data/hops2.json and data/table.md
import os
import json, numpy as np
REV = os.environ.get("RAD_REVIEW", "review")
H = REV + "/hook"
cyc = json.load(open(REV + "/rad/data/cycle.json"))
FIX = {("0230", 3278): 456, ("0230", 3592): 1136}       # read by eye (the reader returned nothing)
NAME = {"1504": "35 s ride", "1639": "side-on", "0230": "5-min"}
# rope connects, frames after the throw press, by eye (sheets t1504_*, t1639_*, t0230_a); '?' = likely, not clear
CONNECT = {("1504", 1): 3, ("1504", 2): 2, ("1504", 3): 3, ("1504", 4): 2, ("1504", 5): 3, ("1504", 6): 2, ("1504", 9): 3,
           ("1639", 2): 3, ("1639", 3): 3, ("1639", 4): 3, ("1639", 5): 3, ("1639", 6): 3, ("1639", 8): 4, ("1639", 9): 3,
           ("0230", 2): 2, ("0230", 4): 2, ("0230", 5): 3}
CONNECT_LIKELY = {("1639", 7): 3, ("1639", 10): 3, ("1639", 11): 3}
NOTES = {("1639", 12): "press start partly covered; rope already seen 1 frame after the marked press, so the throw was 1-2 frames earlier",
         ("0230", 23): "press start covered; pull-in time unknown (left out of the stats)",
         ("0230", 8): "two in-air presses (122.13, 122.60); the second is used",
         ("0230", 6): "no throw seen (reward burst covered the button)",
         ("1639", 1): "rope not readable (labels)", ("1504", 7): "rope not readable (labels)", ("1504", 8): "rope not readable (rider in front of the dino)"}
rows = []
for key in ["1504", "1639", "0230"]:
    R = {r["i"]: r.get("v") for r in json.load(open(f"{H}/data/reads2_{key}.json"))}
    for (k, i), v in FIX.items():
        if k == key: R[i] = v
    I = np.load(f"{H}/data/band_{key}_idx.npy"); D = np.load(f"{H}/data/band_{key}_diff.npy")
    dup = {int(i) for i, d in zip(I, D) if 0 <= d < 0.1}
    hops = cyc[key]["hops"]
    for n, h in enumerate(hops):
        if h["land"] is None: continue
        hop = n + 1
        j = round(h["jump"] * 30); l = round(h["land"] * 30)
        prev = hops[n - 1] if n > 0 else None
        prev_l = round(prev["land"] * 30) if prev is not None and prev["land"] is not None else None
        next_j = round(hops[n + 1]["jump"] * 30) if n + 1 < len(hops) else None
        V = R.get
        def speed(a, b):
            if b - a < 6 or V(a) is None or V(b) is None: return None
            return (V(b) - V(a)) * 30.0 / (b - a)
        a = j - 16
        if prev_l is not None and prev_l + 2 > a and prev["land"] > h["jump"] - 3: a = prev_l + 2
        rb = speed(a, j - 1); rb_win = (j - 1 - a) / 30
        b = l + 17 if next_j is None else min(l + 17, next_j - 1)
        ra = speed(l + 2, b); ra_win = (b - l - 2) / 30
        rec = {"rec": key, "name": NAME[key], "hop": hop, "jump": h["jump"], "land": h["land"], "ride_before": rb, "rb_win": rb_win,
               "ride_after": ra, "ra_win": ra_win, "note": NOTES.get((key, hop), "")}
        pr = h["inair_presses"]
        if not pr: rows.append(rec); continue
        p = round(pr[-1] * 30); rec["throw"] = pr[-1]
        c = CONNECT.get((key, hop)); cl = CONNECT_LIKELY.get((key, hop))
        rec["connect_f"] = c if c is not None else cl; rec["connect_sure"] = c is not None
        g0 = max(j + 9, p - 10)
        herd = speed(g0, p - 1); rec["herd"] = herd; rec["herd_win"] = (p - 1 - g0) / 30
        if any(V(i) is None for i in range(p, l + 1)): rec["note"] += " counter missing"; rows.append(rec); continue
        T = (l - p) / 30; m = V(l) - V(p)
        rec.update({"T": T, "m": m, "avg": m / T})
        pk = [(V(k + 3) - V(k)) * 10.0 for k in range(p, l - 2)]
        rec["peak"] = max(pk) if pk else None
        rec["peak_end_before_land"] = (l - (p + int(np.argmax(pk)) + 3)) / 30 if pk else None
        rec["v_first"] = (V(p + 3) - V(p)) * 10.0 if l - p >= 3 else None
        rec["v_last"] = (V(l) - V(l - 3)) * 10.0 if l - p >= 3 else None
        mid = (p + l) / 2
        vm = V(int(mid)) if mid == int(mid) else (V(int(mid)) + V(int(mid) + 1)) / 2
        rec["first_half"] = (vm - V(p)) / m if m > 0 else None
        ride = rb if (rb is not None and rb >= 20) else (ra if (ra is not None and ra >= 20) else None)
        rec["ride"] = ride; rec["ride_src"] = "" if ride is None else ("before" if ride == rb else "after")
        if ride is not None and ride > 10:
            rec["avg_r"] = m / T / ride; rec["peak_r"] = rec["peak"] / ride if rec["peak"] is not None else None
        if herd is not None:
            rec["gap"] = m - herd * T
            if ride is not None and ride > 10: rec["gap_ride_s"] = rec["gap"] / ride
        rec["dups"] = [i - p for i in range(p, l + 1) if i in dup]
        rec["series"] = [V(i) for i in range(p - 6, l + 4)]; rec["series_from_rel_throw"] = -6
        rows.append(rec)
json.dump(rows, open(H + "/data/hops2.json", "w"), indent=1)
# recording medians of riding speed
med = {}
for key in ["1504", "1639", "0230"]:
    vals = [r["ride_before"] for r in rows if r["rec"] == key and r["ride_before"] is not None] + \
           [r["ride_after"] for r in rows if r["rec"] == key and r["ride_after"] is not None and r["ride_before"] is None]
    med[key] = float(np.median(vals)); print(key, "median riding", med[key], "from", len(vals), sorted(round(v) for v in vals))
for r in rows:
    if "avg" in r: r["avg_rmed"] = r["avg"] / med[r["rec"]]; r["peak_rmed"] = r["peak"] / med[r["rec"]] if r["peak"] else None
json.dump({"rows": rows, "median_ride": med}, open(H + "/data/hops2.json", "w"), indent=1)
def f(x, d=0):
    return "-" if x is None else (f"{x:.{d}f}")
for r in rows:
    print(r["rec"], r["hop"], f(r.get("T"), 3), "m", r.get("m"), "ride", f(r.get("ride")), r.get("ride_src"), "herd", f(r.get("herd")), "gap", f(r.get("gap"), 1),
          "first", f(r.get("v_first")), "last", f(r.get("v_last")), "pk", f(r.get("peak")), "r", f(r.get("avg_r"), 2), f(r.get("peak_r"), 2), "half", f(r.get("first_half"), 2), "dups", r.get("dups"))
