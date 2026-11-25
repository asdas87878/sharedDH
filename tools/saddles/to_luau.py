"""The saddles' data as Luau, for the game (NULLROOM task s2): src/shared/Saddles/Fits.luau and Designs.luau.

    python tools/saddles/to_luau.py           writes both from art/saddles/{fit,adjust,saddles}.json
    python tools/saddles/to_luau.py check     says whether they are up to date (exit 1 if not)
    python tools/saddles/to_luau.py parts F   writes every saddle saddles.py builds (83 kinds x 6 sizes x 20 designs, and
                                              each alone) to F, for tools/saddles/saddle_parity.luau to compare

Rows are packed in strings: as tables they would be ten times the lines (stylua opens them up) and near the size a
script can have. Never edit the two files by hand."""
import json
import os
import sys

import fish as F
import fit as X
import saddles as S

HEAD = "--!strict\n-- Written by tools/saddles/to_luau.py from art/saddles; don't edit it by hand. Read by the module above it.\n"
SIZES = ("Tiny", "Normal", "Big", "Giant", "Huge", "Colossal")


def num(v):
    s = f"{float(v):.4f}".rstrip("0").rstrip(".")
    return "0" if s == "-0" else s


def nums(row):
    return ",".join(num(v) for v in row)


def load(name):
    with open(os.path.join(X.OUT, name + ".json")) as f:
        return json.load(f)


def fit_row(f):
    cantle = {"full": "f", "split": "s", "none": "n"}[f["cantle"]]
    return "|".join((f["joint"], nums([f[k] for k in ("grow", "front", "back", "half", "slot", "top", "base")] + [f["pad"][0], f["yf"], f["yb"]]),
                     "1" if f["pommel"] else "0", cantle, "/".join(nums(r) for r in f["flaps"]), nums(f["strap"] or ()), nums(f["shelf"] or ())))


def adjust_row(rows):
    out = []
    for size in SIZES:
        for key, what in sorted(rows.get(size, {}).items()):
            out.append(f"{size} {key} " + ",".join(f"{k}={1 if v is True else num(v)}" for k, v in sorted(what.items())))
    return ";".join(out)


def fits():
    fit, adj = load("fit"), load("adjust")
    out = [HEAD, "-- Fits: kind -> its six sizes (Tiny to Colossal), ';' between: joint|grow,front,back,half,slot,top,base,pad,yf,yb|pommel|\n"
                 "-- cantle (f full, s split, n none)|flaps (length,angle,sink,rise,z0,z1, '/' between)|strap|shelf\n"
                 "-- Adjust: kind -> what a design changes on it, ';' between: size design anchor=factor (0: left out), split=1\n"
                 "return {\n\tFits = {\n"]
    for kind in sorted(fit):
        assert all("|" not in f["joint"] and ";" not in f["joint"] for f in fit[kind].values())
        out.append(f'\t\t{kind} = "{";".join(fit_row(fit[kind][s]) for s in SIZES)}",\n')
    out.append("\t},\n\tAdjust = {\n")
    for kind in sorted(adj):
        row = adjust_row(adj[kind])
        if row:
            out.append(f'\t\t{kind} = "{row}",\n')
    out.append("\t},\n}\n")
    return "".join(out)


def piece_row(p):
    s = f'{p["a"]} {p["s"]} {nums(p["p"])} {nums(p["z"])} {p["c"]}'
    if p.get("r"):
        s += " r=" + nums(p["r"])
    return s + "".join(" " + k for k in ("neon", "both", "mid") if p.get(k))


def designs():
    out = [HEAD, "-- Each design: its land, its name, the blanket's colours, and its pieces: anchor shape x,y,z sizeX,sizeY,sizeZ colour\n"
                 "-- [r=turn] [neon] [both: the mirror image too] [mid: it stands in the middle of the cantle]\n"
                 "return {\n"]
    for key, d in load("saddles").items():
        # (the table's keys in order; an absent colour is nil)
        out.append(f'\t["{key}"] = {{\n\t\tLand = {d["land"]},\n\t\tName = "{d["name"]}",\n\t\tMain = "{d["main"]}",\n\t\tFlap = "{d.get("flap", d["main"])}",\n'
                   f'\t\tTrim = "{d["trim"]}",\n\t\tTrimNeon = {"true" if d.get("trimneon") else "false"},\n\t\tCushion = "{d["cushion"]}",\n'
                   f'\t\tCushion2 = "{d.get("cushion2", d["cushion"])}",\n\t\tStrap = "{d.get("strap", d["trim"])}",\n\t\tPieces = {{\n')
        out += [f'\t\t\t"{piece_row(p)}",\n' for p in d["pieces"]]
        out.append("\t\t},\n\t},\n")
    out.append("}\n")
    return "".join(out)


def as_design(d):
    """a design of saddles.json, as build() takes it"""
    pieces = []
    for p in d["pieces"]:
        o = {"r": p.get("r", (0, 0, 0)), "n": p.get("neon", False), "both": p.get("both", False), "mid": p.get("mid", False)}
        pieces.append((p["a"], p["s"], p["p"], p["z"], p["c"], o))
    return {**d, "pieces": pieces}


def parts(path):
    fit, sad = load("fit"), {k: as_design(d) for k, d in load("saddles").items()}

    def flat(built):
        rows = []
        for p in built:
            m = p["m"]
            rows.append([p["what"], p["shape"], 1 if p["neon"] else 0, *p["colour"], *(round(v, 4) for v in p["size"]), *(round(float(m[i, 3]), 4) for i in range(3)),
                         *(round(float(m[i, j]), 4) for i in range(3) for j in range(3))])
        return rows
    n = 0
    with open(path, "w") as out:
        for key, d in sad.items():
            out.write(json.dumps(["plain", "", key, flat(S.build(d, S.plain()))]) + "\n")
        for kind in sorted(fit):
            for size in SIZES:
                for key, d in sad.items():
                    out.write(json.dumps([kind, size, key, flat(S.build(d, fit[kind][size], S.adjust(kind, size, key)))]) + "\n")
                    n += 1
    print(n, "saddles written to", path)


if __name__ == "__main__":
    if sys.argv[1:2] == ["parts"]:
        parts(sys.argv[2])
        sys.exit()
    late = []
    for name, text in (("Fits", fits()), ("Designs", designs())):
        path = os.path.join(F.ROOT, "src", "shared", "Saddles", name + ".luau")
        if sys.argv[1:2] == ["check"]:
            if not os.path.exists(path) or open(path).read() != text:
                late.append(name)
        else:
            with open(path, "w") as f:
                f.write(text)
            print(name, len(text), "characters")
    if late:
        sys.exit("not up to date: " + ", ".join(late))
