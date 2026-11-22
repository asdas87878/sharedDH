# Task 1 numbers per recording / run from cycle.json.
import json, numpy as np
cyc = json.load(open("../data/cycle.json"))
def q(x):
    x = np.array(x, float)
    return f"n={len(x)} median {np.median(x):.2f}  p10-p90 {np.percentile(x,10):.2f}-{np.percentile(x,90):.2f}  range {x.min():.2f}-{x.max():.2f}" if len(x) else "n=0"
RUNS = {"1504": [(0, 40)], "1639": [(0, 40)], "1934": [(0, 40)], "0230": [(100, 150), (200, 245)]}
EXCL_HOPS = {"0230": [164.067]}  # run 1's end with the Esc menu open: not a normal hop
allstats = {}
for k, runs in RUNS.items():
    for (a, b) in runs:
        hops = [h for h in cyc[k]["hops"] if a <= h["jump"] < b and h["jump"] not in EXCL_HOPS.get(k, [])]
        rides = [r for r in cyc[k]["rides"] if a <= r["from"] < b and not r["excluded"] and r["to"] < b and r["to"] not in EXCL_HOPS.get(k, [])]
        if not hops: continue
        landed = [h for h in hops if h["land"] is not None]; miss = [h for h in hops if h["land"] is None]
        air = [h["air"] for h in landed]
        early = [h for h in landed if h["air"] < 1.6]
        jp = [h["jump_to_press"] for h in landed if h["jump_to_press"] is not None]
        pl = [h["press_to_land"] for h in landed if h["press_to_land"] is not None]
        t0 = hops[0]["jump"]; last = hops[-1]
        t1 = last["land"] if last["land"] is not None else last["jump"] + last["air_until_gone"]
        span = t1 - t0
        airsum = sum(air) + sum(h["air_until_gone"] for h in miss)
        jj = np.diff([h["jump"] for h in hops])
        name = f"{k} {a}-{b}" if k == "0230" else k
        print(f"\n=== {name}: hops {len(hops)} (landed {len(landed)}, missed {len(miss)}), span {span:.2f} s from the first jump to the last landing/fall")
        print(f"  air (landed): {q(air)}  | early (<1.6 s): {len(early)} of {len(landed)}")
        print(f"  air until the run ended (misses): {[h['air_until_gone'] for h in miss]}")
        print(f"  ride between hops: {q([r['ride'] for r in rides])}")
        print(f"  jump -> in-air press: {q(jp)}")
        print(f"  in-air press -> landing: {q(pl)}")
        print(f"  jump-to-jump interval: {q(jj)}")
        print(f"  hops per minute over the span: {len(hops) / span * 60:.1f}  (60/median jump-to-jump: {60/np.median(jj) if len(jj) else float('nan'):.1f})")
        print(f"  share of the span airborne: {airsum / span * 100:.0f}%")
        allstats[name] = dict(hops=len(hops), landed=len(landed), missed=len(miss), span=span, air=air, rides=[r['ride'] for r in rides], jp=jp, pl=pl)
json.dump(allstats, open("../data/cycle_stats.json", "w"), indent=1)
# pooled press->landing
pl = sum((v["pl"] for v in allstats.values()), [])
print("\npooled in-air press -> landing:", q(pl))
h, e = np.histogram(pl, bins=np.arange(0.0, 0.7, 0.05)); print("  histogram:", " ".join(f"{e[i]:.2f}:{h[i]}" for i in range(len(h))))
