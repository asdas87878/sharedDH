"""The results tables of docs/design/saddles.md, from work/saddles/check.json and rider.json (run fit.py and rider.py first):

    python tools/saddles/table.py       rewrites what stands between the note's "results" marks"""
import json
import os

import numpy as np

import fish as F
import fit as X
import saddles as S

NOTE = os.path.join(F.ROOT, "docs", "design", "saddles.md")
WORK = os.path.join(F.ROOT, "work", "saddles")
SHORT = {"Tiny": "T", "Normal": "N", "Big": "B", "Giant": "G", "Huge": "H", "Colossal": "C"}


def sizes(rows, of):
    """what `of` gives at each size, said once where it is the same: `drape`, or `drape, G-C flat`"""
    v = [(t, of(rows[t])) for t in F.TIERS]
    runs = []
    for t, x in v:
        if runs and runs[-1][2] == x:
            runs[-1][1] = t
        else:
            runs.append([t, t, x])
    if len(runs) == 1:
        return str(runs[0][2])
    return ", ".join(f"{SHORT[a]}{'-' + SHORT[b] if a != b else ''} {x}" for a, b, x in runs)


def main():
    res = json.load(open(os.path.join(WORK, "check.json")))
    rid = json.load(open(os.path.join(WORK, "rider.json")))
    out = []
    flagged = sum(bool(X.faults(q["check"])) for r in res.values() for q in r.values())
    out += ["### Every kind", "",
            f"{len(res)} kinds x 6 sizes = {sum(len(r) for r in res.values())} fits, **{flagged} outside the limits**. Sizes: T Tiny, N Normal, B Big, G Giant, H Huge, C Colossal. Width: the pad's, in studs, at Tiny / Normal / Colossal. "
            "Worst: over all six sizes; still = not moving, moving = through the swim at 2.3 times its swing and a 5 degree turn. gap: the 95th share of the gaps under a panel's edge, studs. off: the share of the edge with no fish under it. "
            "in: how far the back comes up through a panel, studs (limits .05 still, .12 moving). fin: the share of the saddle a fin or limb stands in (limits .06, .1).", "",
            "| Kind | Land | Joint | Style | Width | Panels a side | Pommel | Cantle | Still: gap / off / in / fin | Moving: gap / off / in / fin |",
            "|---|---|---|---|---|---|---|---|---|---|"]
    for id in sorted(res, key=lambda i: (F.load(i).zone, i)):
        f, r = F.load(id), res[id]
        w = lambda kinds: " / ".join(f"{max(q['check'][k][m] for q in r.values() for k in kinds if k in q['check']):.2f}".lstrip("0") for m in ("gap", "off", "poke", "fin"))  # noqa: E731
        fit = {t: r[t]["fit"] for t in F.TIERS}
        half = " / ".join(f"{2 * fit[t]['half']:.1f}" for t in ("Tiny", "Normal", "Colossal"))
        out.append(f"| {f.name} | {f.zone} | {fit['Normal']['joint']} | {sizes(fit, lambda x: x['style'])} | {half} | {sizes(fit, lambda x: len(x['flaps']) + bool(x['strap']))} | "
                   f"{sizes(fit, lambda x: 'yes' if x['pommel'] else 'no')} | {sizes(fit, lambda x: x['cantle'])} | {w(('rest',))} | {w(('swim', 'hard', 'turn'))} |")
    joints = [id for id in res if len({res[id][t]["fit"]["joint"] for t in F.TIERS}) > 1]
    out += ["", f"Joint the same at all six sizes: {'every kind' if not joints else 'all but ' + ', '.join(joints)}.", "",
            "### Every design, on all kinds and sizes", "",
            "Rider, riding pose and leaning 20 degrees further: how deep the saddle goes into torso, arms or head (studs). Seen: the share of the rider the chase camera still sees past it, least / mean. "
            "Overhang: the furthest a pommel or cantle stands out past a narrow pad with nothing within a stud under it (studs), and on how many of the 468.", "",
            "| Design | Parts | Triangles | Riding | Leaning 20 | Worst on | Seen | Overhang | on |", "|---|---|---|---|---|---|---|---|---|"]
    for key in S.DESIGNS:
        r = [(id, k.split(" ")[0], v) for id in rid for k, v in rid[id].items() if k.split(" ")[1] == key]
        worst = max(r, key=lambda q: q[2]["clear"])
        seen = [v["seen"] for *_, v in r if "seen" in v]
        star = " **recommended**" if S.RECOMMENDED[int(key[:-1])] == key[-1] else ""
        out.append(f"| {key} {S.DESIGNS[key][0]}{star} | {min(v['parts'] for *_, v in r)} to {max(v['parts'] for *_, v in r)} | {min(v['tris'] for *_, v in r)} to {max(v['tris'] for *_, v in r)} | "
                   f"{max(v['rest'] for *_, v in r):.2f} | {worst[2]['clear']:.2f} | {F.load(worst[0]).name} {worst[1]} | {min(seen):.2f} / {np.mean(seen):.2f} | {max(v['over'] for *_, v in r):.2f} | {sum(v['over'] > 0 for *_, v in r)} |")
    txt = open(NOTE).read()
    a, b = txt.index("<!-- results -->") + len("<!-- results -->"), txt.index("<!-- /results -->")
    open(NOTE, "w").write(txt[:a] + "\n\n" + "\n".join(out) + "\n\n" + txt[b:])
    print(len(out), "lines;", flagged, "flagged;", {s: sorted({i for i in res for t in F.TIERS if res[i][t]["fit"]["style"] == s}) for s in ("slot", "step", "ledge", "tray")})
    print({c: [f"{i} {sizes({t: res[i][t]['fit'] for t in F.TIERS}, lambda x: x['cantle'])}" for i in res if any(res[i][t]["fit"]["cantle"] == c for t in F.TIERS)] for c in ("split", "none")})
    print("no pommel:", [f"{i} {sizes({t: res[i][t]['fit'] for t in F.TIERS}, lambda x: x['pommel'])}" for i in res if any(not res[i][t]["fit"]["pommel"] for t in F.TIERS)])


if __name__ == "__main__":
    main()
