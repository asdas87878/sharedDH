"""The results tables of docs/design/saddles.md, from work/saddles/check.json, clash.json and rider.json (run fit.py, clash.py and rider.py first):

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


def words(a):
    w = []
    if a.get("can") == 0:
        w.append("no cantle")
    elif "can" in a:
        w.append(("split cantle" if a.get("split") else "cantle") + (f" x{a['can']}" if a["can"] != 1 else ""))
    if "pom" in a:
        w.append(f"pommel x{a['pom']}" if a["pom"] else "no pommel")
    off = [k for k in ("flap", "low", "hem") if a.get(k) == 0]
    if off:
        w.append("no " + " or ".join(off) + " trimmings")
    return ", ".join(w)


def changed(fixes, key):
    r = [v[key] for x in fixes.values() for v in x.values() if key in v]
    return " / ".join(str(n) for n in (sum(bool(a.get("can")) for a in r), sum(a.get("can") == 0 for a in r), sum("pom" in a for a in r), sum(any(k in a for k in ("flap", "low", "hem")) for a in r)))


def main():
    res = json.load(open(os.path.join(WORK, "check.json")))
    rid = json.load(open(os.path.join(WORK, "rider.json")))
    cl = json.load(open(os.path.join(WORK, "clash.json")))
    import clash as C
    out = []
    flagged = sum(bool(X.faults(q["check"])) for r in res.values() for q in r.values())
    out += ["### Every kind", "",
            f"{len(res)} kinds x 6 sizes = {sum(len(r) for r in res.values())} fits, **{flagged} outside the limits**. Sizes: T Tiny, N Normal, B Big, G Giant, H Huge, C Colossal. Width: the pad's, in studs, at Tiny / Normal / Colossal. "
            "Worst: over all six sizes; still = not moving, moving = through the swim at 2.3 times its swing and a 5 degree turn. gap: the 95th share of the gaps under a panel's edge, studs. off: the share of the edge with no fish under it. "
            "in: how far the back comes up through a panel, studs (limits .05 still, .12 moving; over them is let through where under .05 of the panel, .08 moving, is poked: one thin point). fin: the share of the saddle a fin or limb stands in (limits .06, .1).", "",
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
            "Hidden: of the 234 at Tiny, Normal and Colossal, on how many the fish itself hides half or more of the cantle's pieces from the game's camera / zoomed out to 27 studs. "
            "Changed: on how many of the 468 a piece stood in the fish, so the design is changed there (cantle smaller or split / cantle none / pommel / trimmings).", "",
            "| Design | Parts | Triangles | Riding | Leaning 20 | Worst on | Seen | Overhang | on | Hidden | Changed |", "|---|---|---|---|---|---|---|---|---|---|---|"]
    fixes = json.load(open(os.path.join(F.ROOT, "art", "saddles", "adjust.json")))
    for key in S.DESIGNS:
        r = [(id, k.split(" ")[0], v) for id in rid for k, v in rid[id].items() if k.split(" ")[1] == key]
        worst = max(r, key=lambda q: q[2]["clear"])
        seen = [v["seen"] for *_, v in r if "seen" in v]
        star = " **picked**" if S.PICKED[int(key[:-1])] == key[-1] else ""
        out.append(f"| {key} {S.DESIGNS[key][0]}{star} | {min(v['parts'] for *_, v in r)} to {max(v['parts'] for *_, v in r)} | {min(v['tris'] for *_, v in r)} to {max(v['tris'] for *_, v in r)} | "
                   f"{max(v['rest'] for *_, v in r):.2f} | {worst[2]['clear']:.2f} | {F.load(worst[0]).name} {worst[1]} | {min(seen):.2f} / {np.mean(seen):.2f} | {max(v['over'] for *_, v in r):.2f} | {sum(v['over'] > 0 for *_, v in r)} | "
                   f"{sum(v.get('hid', 0) >= 0.5 for *_, v in r)} / {sum(v.get('hidfar', 0) >= 0.5 for *_, v in r)} | {changed(fixes, key)} |")
    # the recommended saddle of each kind's own land: what hides it, what was changed
    rec = lambda id: f"{F.load(id).zone}{S.PICKED[F.load(id).zone]}"  # noqa: E731
    order = sorted(res, key=lambda i: (F.load(i).zone, i))
    out += ["", "### Where the fish hides the raised back (its own land's picked saddle)", ""]
    for n, what in (("hid", "from the game's camera (17 studs)"), ("hidfar", "zoomed out to 27 studs")):
        rows = {id: [(t, rid[id][f"{t} {rec(id)}"].get(n)) for t in ("Tiny", "Normal", "Colossal")] for id in order}
        hid = {id: [(t, v) for t, v in r if v is not None and v >= 0.5] for id, r in rows.items()}
        has = sum(v is not None for r in rows.values() for _, v in r)
        out += [f"**{sum(len(v) for v in hid.values())} of {has}** (78 kinds at Tiny, Normal and Colossal, less those with no cantle) {what}. The number is the share of the cantle's pieces hidden:", "",
                "; ".join(f"{F.load(id).name} {rec(id)} (" + ", ".join(f"{SHORT[t]} {v:.2f}".replace("1.00", "all") for t, v in r) + ")" for id, r in hid.items() if r) + ".", ""]
    ch = [f"{F.load(id).name} {t} {rec(id)}: {words(fixes[id][t][rec(id)])}" for id in order for t in F.TIERS if rec(id) in fixes.get(id, {}).get(t, {})]
    tot = sum(len(v) for r in fixes.values() for v in r.values())
    fail = lambda n, g: sum(g in v[n] and C.fails(v[n][g]) for r in cl.values() for v in r.values() if n in v)  # noqa: E731
    out += ["### Pieces standing in the fish", "",
            f"`clash.py`, all 20 designs on all 468 ({sum(len(r) for r in cl.values())} cases): the cantle, pommel and trimmings against the fish, at rest and at four moments of the swim at 2.3 times its swing. "
            "A piece counts when a quarter of it stands more than 0.1 studs inside the fish; a group fails on more than one such piece, or more than a tenth of it, at rest (more than two, or a quarter, moving). "
            f"Failing as designed: {fail('first', 'can')} cantles, {fail('first', 'pom')} pommels, {fail('first', 'trim')} sets of trimmings. **{tot} cases are changed** "
            f"(`art/saddles/adjust.json`: a smaller cantle, one without its middle, none; a smaller pommel; the trimmings of a panel left off), after which {fail('after', 'can') + fail('after', 'pom') + fail('after', 'trim')} fail. "
            f"Of the picked saddles on their own land's fish, {len(ch)} are changed:", "", "; ".join(ch) + "."]
    txt = open(NOTE).read()
    a, b = txt.index("<!-- results -->") + len("<!-- results -->"), txt.index("<!-- /results -->")
    open(NOTE, "w").write(txt[:a] + "\n\n" + "\n".join(out) + "\n\n" + txt[b:])
    print(len(out), "lines;", flagged, "flagged;", {s: sorted({i for i in res for t in F.TIERS if res[i][t]["fit"]["style"] == s}) for s in ("slot", "step", "ledge", "tray")})
    print({c: [f"{i} {sizes({t: res[i][t]['fit'] for t in F.TIERS}, lambda x: x['cantle'])}" for i in res if any(res[i][t]["fit"]["cantle"] == c for t in F.TIERS)] for c in ("split", "none")})
    print("no pommel:", [f"{i} {sizes({t: res[i][t]['fit'] for t in F.TIERS}, lambda x: x['pommel'])}" for i in res if any(not res[i][t]["fit"]["pommel"] for t in F.TIERS)])


if __name__ == "__main__":
    main()
