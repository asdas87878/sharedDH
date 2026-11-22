# Task 1: the riding / air cycle per recording, from events.py. Prints tables, writes ../data/cycle.json.
import json, sys, numpy as np
sys.path.insert(0, ".")
from events import events, FPS
EXCLUDE_RIDES = {"0230": [(148.0, 164.5)]}   # the 0230 ride during which the Esc menu was opened (Brachiosaurus tame + menu)
START_RIDES = {"0230": [99.53, 199.13], "1504": [1.97], "1639": [2.67], "1934": [18.0]}
def pct(x, q): return float(np.percentile(x, q)) if len(x) else float("nan")
out = {}
for k in ["1504", "1639", "1934", "0230"]:
    allhops, rides, runs = [], [], []
    for seq, presses in events(k):
        hops = []
        for j, (ph, a, b, g) in enumerate(seq):
            if ph != "A": continue
            prev = seq[j - 1] if j > 0 else None; nxt = seq[j + 1] if j + 1 < len(seq) else None
            if prev is None or prev[0] != "R": continue   # an air phase that does not start from riding (airline flight, run end oddity)
            tj = a / FPS; jgap = g / FPS
            land = (nxt[1] / FPS) if (nxt is not None and nxt[0] == "R") else None
            lgap = (nxt[3] / FPS) if land is not None else 0.0
            end_air = (b + 1) / FPS
            ps = [p for p in presses if tj - 0.05 <= p[0] < (land if land else end_air + 0.1)]
            jump_press = ps[0][0] if ps and abs(ps[0][0] - tj) <= 0.07 else None
            inair = [p[0] for p in ps if jump_press is None or p[0] > jump_press + 0.07]
            h = {"jump": round(tj, 3), "jump_gap": round(jgap, 3), "jump_press_seen": jump_press is not None,
                 "land": None if land is None else round(land, 3), "land_gap": round(lgap, 3),
                 "air": None if land is None else round(land - tj, 3), "air_until_gone": round(end_air - tj, 3),
                 "inair_presses": [round(x, 3) for x in inair],
                 "press_to_land": None if (land is None or not inair) else round(land - inair[-1], 3),
                 "first_press_to_land": None if (land is None or not inair) else round(land - inair[0], 3),
                 "jump_to_press": None if not inair else round(inair[0] - tj, 3)}
            hops.append(h)
        # rides: landing -> next jump (only between hops of this window)
        for x, y in zip(hops[:-1], hops[1:]):
            if x["land"] is None: continue
            ex = any(lo <= x["land"] <= hi for lo, hi in EXCLUDE_RIDES.get(k, []))
            rides.append({"from": x["land"], "to": y["jump"], "ride": round(y["jump"] - x["land"], 3), "excluded": ex})
        # start ride
        for s in START_RIDES.get(k, []):
            nj = [h["jump"] for h in hops if h["jump"] > s]
            if nj and (not hops or abs(min(nj) - s) < 30): runs.append({"start_ride_from": s, "first_jump": min(nj), "start_ride": round(min(nj) - s, 3)})
        allhops += hops
    out[k] = {"hops": allhops, "rides": rides, "start_rides": runs}
json.dump(out, open("../data/cycle.json", "w"), indent=1)
for k, v in out.items():
    print(f"\n=== {k}")
    for i, h in enumerate(v["hops"]):
        flag = "MISS" if h["land"] is None else ("early" if h["air"] < 1.6 else "")
        print(f"{i+1:2d} jump {h['jump']:7.2f}{'*' if not h['jump_press_seen'] else ' '} land {('%7.2f' % h['land']) if h['land'] else '   -   '} air {('%5.2f' % h['air']) if h['air'] else ('(%4.2f+)' % h['air_until_gone'])}"
              f"  in-air presses {','.join('%.2f' % p for p in h['inair_presses']) or '-':24s} jump->press {('%.2f' % h['jump_to_press']) if h['jump_to_press'] is not None else '  - '}"
              f"  press->land {('%.2f' % h['press_to_land']) if h['press_to_land'] is not None else '  - '} {flag}"
              + (f"  [land gap {h['land_gap']:.2f}]" if h['land_gap'] else "") + (f"  [jump gap {h['jump_gap']:.2f}]" if h['jump_gap'] else ""))
    r = [x["ride"] for x in v["rides"] if not x["excluded"]]
    print("rides:", " ".join(f"{x['ride']:.2f}{'(x)' if x['excluded'] else ''}" for x in v["rides"]))
    if r: print(f"ride n={len(r)} median {np.median(r):.2f} mean {np.mean(r):.2f} p10 {pct(r,10):.2f} p90 {pct(r,90):.2f} min {min(r):.2f} max {max(r):.2f}")
    print("start rides:", v["start_rides"])
