# When could the player dive? The down button is greyed (about half contrast) while no dino is under the landing ring
# and normal while one is targeted. Per hop: the greyed and active spans in the air, and the press's delay after the
# button last became active (a reaction time when it had been greyed).
import json, numpy as np
FPS = 30.0
THR = {"1504": 13.0, "1639": 13.0, "1934": 20.0}
cyc = json.load(open("../data/cycle.json")); out = {}
for k, thr in THR.items():
    rows = json.load(open(f"../data/lab_{k}.json")); lab = [r[1] for r in rows]; A = [r[4] for r in rows]
    res = []
    for n, h in enumerate(cyc[k]["hops"]):
        J = round(h["jump"] * FPS); E = round(h["land"] * FPS) if h["land"] else J + round(h["air_until_gone"] * FPS)
        P = round(h["inair_presses"][0] * FPS) if h["inair_presses"] else None
        st = []
        for i in range(J, (P if P else E)):
            if lab[i] == "D": st.append("g" if A[i] < thr else "a")
            elif lab[i] == "pD": st.append("p")
            else: st.append("?")
        # smooth single-frame flips
        s = "".join(st)
        spans = []
        for i, c in enumerate(s):
            if spans and spans[-1][0] == c: spans[-1][2] = i
            else: spans.append([c, i, i])
        spans = [x for x in spans if x[0] != "?" and (x[2] - x[1] >= 1 or x[0] == "p")]
        greyed = [(round((J + a) / FPS - h["jump"], 2), round((J + b + 1) / FPS - h["jump"], 2)) for c, a, b in spans if c == "g"]
        last_active = None
        for c, a, b in spans:
            if c == "a": last_active = a
            elif c == "g": last_active = None
        r = {"hop": n + 1, "air": h["air"], "press_after_jump": h["jump_to_press"], "greyed_spans_after_jump": greyed,
             "active_since": None if last_active is None else round(last_active / FPS, 2)}
        if P and greyed:
            r["press_after_active"] = round((P - J) / FPS - r["active_since"], 2) if r["active_since"] is not None else None
        res.append(r); print(k, r)
    out[k] = res
json.dump(out, open("../data/target_window.json", "w"), indent=1)
