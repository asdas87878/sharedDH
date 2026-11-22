# Hop events from the per-frame button labels (classify.py -> lab_<k>.json).
# Phases: riding (U) and air (D / pD). '?' gaps are bridged when both sides are the same phase; across a change the
# change is put at the first frame of the new phase and the gap is reported as the uncertainty.
# A press = the start of a pD run (the button's pressed look). jump = first air frame, landing = first U frame.
import json, sys, numpy as np
FPS = 30.0
WINDOWS = {"1504": [(0, 36)], "1639": [(0, 31)], "1934": [(18, 31)], "0230": [(99.0, 167.0), (198.0, 242.0)]}

def runs_of(lab):
    out = []
    for i, l in enumerate(lab):
        if out and out[-1][0] == l and out[-1][2] == i - 1: out[-1][2] = i
        else: out.append([l, i, i])
    return out

def events(k, gap_max=0.6):
    rows = json.load(open(f"../data/lab_{k}.json"))
    lab = [r[1] for r in rows]
    res = []
    for (w0, w1) in WINDOWS[k]:
        i0, i1 = int(w0 * FPS), min(len(lab), int(w1 * FPS))
        seg = lab[i0:i1]
        ph = ["R" if l == "U" else ("A" if l in ("D", "pD") else "?") for l in seg]
        # presses: pD run starts (allow a 1-2 frame '?' inside a pD run to count as one press)
        presses = []; last_end = None
        for l, a, b in runs_of(seg):
            if l == "pD":
                t = (i0 + a) / FPS
                between = seg[last_end + 1:a] if last_end is not None else ["x"]
                if presses and len(between) <= 3 and all(x == "?" for x in between):  # same press look, briefly covered
                    presses[-1][1] = (i0 + b) / FPS
                else:
                    presses.append([t, (i0 + b) / FPS])
                last_end = b
        pr = runs_of(ph)
        # bridge short ? gaps between equal phases
        merged = []
        for p in pr:
            if merged and p[0] == "?" and (p[2] - p[1] + 1) / FPS <= gap_max:
                merged.append(p); continue
            merged.append(p)
        # build a phase sequence of known phases with gaps noted
        seq = []  # [phase, first_frame, last_frame, gap_before_frames]
        gap = 0
        for p in merged:
            if p[0] == "?":
                if (p[2] - p[1] + 1) / FPS > gap_max:
                    seq.append(["X", p[1], p[2], 0]); gap = 0  # a real absence of the button
                else:
                    gap += p[2] - p[1] + 1
                continue
            if seq and seq[-1][0] == p[0]:
                seq[-1][2] = p[2]
            else:
                seq.append([p[0], p[1], p[2], gap])
            gap = 0
        for s in seq:
            s[1] += i0; s[2] += i0
        res.append((seq, presses))
    return res

if __name__ == "__main__":
    for k in sys.argv[1:]:
        for seq, presses in events(k):
            print(k, " ".join(f"{p}{a/FPS:.2f}-{b/FPS:.2f}" + (f"(gap{g})" if g else "") for p, a, b, g in seq))
            print("   presses:", " ".join(f"{a:.2f}" + (f"+{b-a+1/FPS:.2f}") for a, b in presses))
