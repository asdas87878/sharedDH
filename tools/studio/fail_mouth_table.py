"""Where each eater's mouth really is, against where the fail's code puts it (offline: no Studio).

The eaters are the fish whose fail is Chomp or Gulp, worked out the way Config.failOf does: Fail.ByCreature first,
then Fail.ByArchetype by the fish's archetypes (Config.FishStats); Fail.LowTiers (Common, Uncommon) only ever throw.

For each it prints, in the fish's root frame (studs at the Normal size: creature units x Config.BaseScale; every
other size scales with Config.SizeScale):
  box     the mouth FailController used before (mouthOf: 0, -0.05 H, -0.47 L)
  rule    the mouth worked out from the model's own parts, as FailController does it now (Fail.MouthFromModel 1):
          with jaw parts (named *Jaw*): their union box, x and z its middle, y a quarter down from its top for a lower
          jaw (up from its bottom for an upper one), the middle for jaws at the sides (JawL/JawR: a worm's pincers,
          whose reach past the Head's front is left out of the measure: they close in front of the mouth); with none,
          the Head part: x its middle, y 0.3 up from its bottom, z 0.4 back from its front; with neither, the box.
          A fish in Config.Fail.MouthAt (a model the rule cannot read: horns or a tooth whorl inside the jaw's or the
          head's own part) has its mouth there instead, as shares of its box
  colour  the truth, from the paint: the middle of the box round the triangles painted mouth, gum, throat or tongue
          (tooth when there are none of those) on the Head, Body and *Jaw* parts ahead of the root
and the distances (box to colour, rule to colour) in studs and as a share of the fish's length, the gape (how far the
front of the jaw opens at FailController's 58 degrees: the chord its top front corner sweeps about its hinge; with no
jaw nothing opens) and the jaw's width, against the rider.
The rider is taken as an R15 body about 2 wide, 5 tall and 1 deep: taken head first it needs a gape of 1 and a width
of 2, taken across a gape of 2 and a width of 5, at every size (Config.SizeOrder: each kind's own scale for it,
Config.sizeScale: Tiny 0.7 for all, the bigger sizes a share of their growth by rarity (SizeGrow) and no more than
SizeLimit; BaseScale is one number per kind, so a size's scale is the only range there is).
Eaten or thrown (Config.Fail.EatSmall, EatMin): per kind, the length under which its jaw cannot take a rider head
first; failOf throws the rider off a fish of that kind shorter than its row. The table proposes a row only for a
jawed kind that comes at a size under its own length, and none for the jawless heads (their room is a guess).
The lure: the Lure part's bulb (its box's end away from its hinge, 0.35 of the way in) against the old lurePlace
(0, 0.62 H + 1.5, -0.64 L) and the painted lure.

  python tools/studio/fail_mouth_table.py            # every eater, saved to work/fail_eat/mouth_table.txt
  python tools/studio/fail_mouth_table.py Megalodon  # just these
"""

import json
import math
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG = os.path.join(ROOT, "src", "shared", "Config.luau")
CREATURES = os.path.join(ROOT, "src", "shared", "Creatures")
ART = os.path.join(ROOT, "art", "creatures")
OUT = os.path.join(ROOT, "work", "fail_eat", "mouth_table.txt")

JAW_OPEN = math.radians(58)  # FailController's poseRig: a jaw's widest
MOUTH_PAINT = ("mouth", "gum", "throat", "tongue")


# ---- Config, read as text ----------------------------------------------------------------------------------------
def block(text, start):
    """The text of the table that opens at `start` (the index of its "{"), braces balanced."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    raise ValueError("unbalanced table")


def read_config():
    text = open(CONFIG, encoding="utf-8").read()
    fail_at = text.index("Config.Fail = {")
    fail = block(text, text.index("{", fail_at))
    by_creature = dict(re.findall(r"(\w+)\s*=\s*\"(\w+)\"", block(fail, fail.index("{", fail.index("ByCreature")))))
    by_arch = dict(re.findall(r"(\w+)\s*=\s*\"(\w+)\"", block(fail, fail.index("{", fail.index("ByArchetype")))))
    low = set(re.findall(r"(\w+)\s*=\s*true", block(fail, fail.index("{", fail.index("LowTiers")))))
    stats_at = text.index("Config.FishStats = {")
    stats = block(text, text.index("{", stats_at))
    arche = {n: a for n, a in re.findall(r"(\w+)\s*=\s*\{\s*Speed\s*=\s*[\d.]+\s*,\s*Archetype\s*=\s*\"([^\"]*)\"", stats)}
    scale_at = text.index("Config.BaseScale = {")
    scales = {n: float(v) for n, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", block(text, text.index("{", scale_at)))}
    return by_creature, by_arch, low, arche, scales


def read_sizes():
    """Config.SizeOrder, SizeScale, SizeGrow, SizeLimit; Config.Fail.MouthAt and EatMin"""
    text = open(CONFIG, encoding="utf-8").read()

    def table(name):
        return block(text, text.index("{", text.index(name + " = {")))

    order = re.findall(r'"(\w+)"', table("Config.SizeOrder"))
    scale = {n: float(v) for n, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", table("Config.SizeScale"))}
    grow = {n: float(v) for n, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", table("Config.SizeGrow"))}
    limit = {n: float(v) for n, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", table("Config.SizeLimit"))}
    fail = block(text, text.index("{", text.index("Config.Fail = {")))
    at = {}
    if "MouthAt = {" in fail:
        body = block(fail, fail.index("{", fail.index("MouthAt = {")))
        for n, x, y, z in re.findall(r"(\w+)\s*=\s*\{\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\}", body):
            at[n] = (float(x), float(y), float(z))
    eat_min = {}
    if "EatMin = {" in fail:
        body = block(fail, fail.index("{", fail.index("EatMin = {")))
        eat_min = {n: float(v) for n, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", body)}
    return {"order": order, "scale": scale, "grow": grow, "limit": limit, "mouth_at": at, "eat_min": eat_min}


def size_scale(tier, rarity, size, sizes):
    """Config.sizeScale: what a size is times the kind's own size (`size`: its width, height, length at Normal)"""
    s = sizes["scale"].get(tier, 1.0)
    if s > 1:
        s = 1 + (s - 1) * sizes["grow"].get(rarity, 1.0)
        most = min(sizes["limit"]["Length"] / max(size[2], 1), sizes["limit"]["Width"] / max(size[0], 1))
        s = max(1.0, min(s, most))
    return s


def fail_of(fid, tier, by_creature, by_arch, low, arche):
    if tier in low:
        return "Throw"
    kind = by_creature.get(fid)
    if not kind:
        for name in re.findall(r"[^,\s]+", arche.get(fid, "")):
            if name in by_arch:
                kind = by_arch[name]
                break
    return kind


# ---- the model ---------------------------------------------------------------------------------------------------
def load_model(name):
    d = os.path.join(ART, name, "game")
    meta = json.load(open(os.path.join(d, name + ".mesh.json"), encoding="utf-8"))
    img = Image.open(os.path.join(d, meta["palette"])).convert("RGB")
    w, h = img.size
    cells = {v.upper(): k for k, v in meta["paletteCells"].items()}
    vs, vts, objs, cur = [], [], {}, None
    for line in open(os.path.join(d, meta["mesh"]), encoding="utf-8"):
        if line.startswith("v "):
            vs.append(tuple(map(float, line.split()[1:4])))
        elif line.startswith("vt "):
            vts.append(tuple(map(float, line.split()[1:3])))
        elif line.startswith("o "):
            cur = line.split()[1]
            objs[cur] = []
        elif line.startswith("f "):
            objs[cur].append([tuple(int(x) if x else 0 for x in p.split("/")) for p in line.split()[1:]])

    def paint(vt):
        u, v = vts[vt - 1]
        px = img.getpixel((min(w - 1, int(u * w)), min(h - 1, int((1 - v) * h))))
        return cells.get("#%02X%02X%02X" % px, "?").rstrip("+-")

    boxes, paints = {}, {}
    for o, faces in objs.items():
        pts = [vs[i[0] - 1] for f in faces for i in f]
        boxes[o] = ([min(p[k] for p in pts) for k in range(3)], [max(p[k] for p in pts) for k in range(3)])
        by = {}
        for f in faces:
            by.setdefault(paint(f[0][1]), []).extend(vs[i[0] - 1] for i in f)
        paints[o] = by
    return meta, boxes, paints


def mid(box):
    return [(box[0][k] + box[1][k]) / 2 for k in range(3)]


def union(bs):
    return ([min(b[0][k] for b in bs) for k in range(3)], [max(b[1][k] for b in bs) for k in range(3)])


def dist(a, b):
    return math.sqrt(sum((a[k] - b[k]) ** 2 for k in range(3)))


def rule_mouth(rig, boxes, at=None):
    """FailController's mouthFromModel, in creature units (the same rule on the same boxes). `at`: the fish's
    Config.Fail.MouthAt row (shares of its box), which wins."""
    rows = {r[0]: r for r in rig["Parts"]}
    jaws = [n for n in rows if "Jaw" in n and n in boxes]
    if at:
        return [at[k] * rig["Size"][k] for k in range(3)], "MouthAt", jaws
    if jaws:
        j = union([boxes[n] for n in jaws])
        c = mid(j)
        hgt = j[1][1] - j[0][1]
        side = all(abs(rows[n][2]) > 0.05 * rig["Size"][0] + 0.05 for n in jaws)
        if side:
            # (pincers close in front of the mouth: their reach past the head's front is not the mouth)
            if "Head" in boxes and j[0][2] < boxes["Head"][0][2] < j[1][2]:
                c[2] = (boxes["Head"][0][2] + j[1][2]) / 2
            return c, "side jaws", jaws
        # a lower jaw hangs below what it hinges on (as readRig works it out)
        parent = rows[jaws[0]][1]
        below = parent in boxes and mid(boxes[jaws[0]])[1] < mid(boxes[parent])[1] or parent == ""
        y = j[1][1] - 0.25 * hgt if below else j[0][1] + 0.25 * hgt
        return [c[0], y, c[2]], "lower jaw" if below else "upper jaw", jaws
    if "Head" in boxes and "Head" in rows:
        b = boxes["Head"]
        return [mid(b)[0], b[0][1] + 0.3 * (b[1][1] - b[0][1]), b[0][2] + 0.4 * (b[1][2] - b[0][2])], "head only", []
    return None, "none", []


def paint_mouth(boxes, paints):
    for names in (MOUTH_PAINT, ("tooth",)):
        pts = []
        for o, by in paints.items():
            # (the head's own parts only: an angler's tail and the half-bone shark's open side are painted with the
            # mouth's red too)
            if not (o in ("Head", "Body") or "Jaw" in o) or o.endswith("_Glow") or mid(boxes[o])[2] >= 0:
                continue
            for n in names:
                pts.extend(by.get(n, []))
        if pts:
            lo = [min(p[k] for p in pts) for k in range(3)]
            hi = [max(p[k] for p in pts) for k in range(3)]
            return mid((lo, hi)), hi[1] - lo[1], "+".join(names)
    return None, 0.0, ""


def gape_of(rig, boxes, jaws):
    """The chord the jaw's top front corner sweeps about its hinge at 58 degrees, and the jaw's width. With no jaw:
    the Head's share FailController gives its mouth's room (0.3 of its height, 0.6 of its width)."""
    if not jaws:
        if "Head" in boxes:
            b = boxes["Head"]
            return 0.3 * (b[1][1] - b[0][1]), 0.6 * (b[1][0] - b[0][0])
        return None, None
    rows = {r[0]: r for r in rig["Parts"]}
    j = union([boxes[n] for n in jaws])
    pivot = rows[jaws[0]][2:5]
    corner = (j[1][1], j[0][2])  # (y, z): its top, its front
    r = math.hypot(corner[0] - pivot[1], corner[1] - pivot[2])
    return 2 * r * math.sin(JAW_OPEN / 2), j[1][0] - j[0][0]


def lure_of(rig, boxes, paints):
    rows = {r[0]: r for r in rig["Parts"]}
    lures = [n for n in rows if "Lure" in n and n in boxes and not n.endswith("_Glow")]
    if not lures:
        return None, None
    b = boxes[lures[0]]
    c = mid(b)
    pivot = rows[lures[0]][2:5]
    axis = max(range(3), key=lambda k: abs(c[k] - pivot[k]))
    far = list(c)
    far[axis] = b[0][axis] if pivot[axis] > c[axis] else b[1][axis]
    rule = [far[k] + (c[k] - far[k]) * 0.35 for k in range(3)]
    pts = []
    for n in ("lure", "glow", "ember", "spark", "lava"):
        pts.extend(paints[lures[0]].get(n, []))
    truth = mid(([min(p[k] for p in pts) for k in range(3)], [max(p[k] for p in pts) for k in range(3)])) if pts else None
    return rule, truth


def fmt(v):
    return "(" + ", ".join("%6.2f" % x for x in v) + ")" if v else "      n/a       "


def fits(gape, width):
    """How the rider goes in: across, head (first) or NO"""
    return "across" if gape >= 2 and width >= 5 else "head" if gape >= 1 and width >= 2 else "NO"


def need_length(L, gape, width):
    """The shortest the fish can be and still take a rider head first (gape and width grow with its length)"""
    return L * max(1 / gape, 2 / width)


def eat_min(rows, sizes):
    """Config.Fail.EatMin proposed: for each jawed kind that comes at a size whose jaw cannot take a rider head first,
    the length at which it would (its need), up to the next half stud. None for the jawless heads."""
    out = {}
    for r in rows:
        if r.get("missing") or not r.get("need") or not r["jaws"]:
            continue
        if any(fits(r["gape"] * r["scales"][t], r["width"] * r["scales"][t]) == "NO" for t in sizes["order"]):
            out[r["id"]] = math.ceil(r["need"] * 2) / 2
    return out


def table_rows(wanted=()):
    by_creature, by_arch, low, arche, scales = read_config()
    sizes = read_sizes()
    rows = []
    for fn in sorted(os.listdir(CREATURES)):
        if not fn.endswith(".json"):
            continue
        fid = fn[:-5]
        rig = json.load(open(os.path.join(CREATURES, fn), encoding="utf-8"))
        kind = fail_of(fid, rig.get("Tier"), by_creature, by_arch, low, arche)
        if kind not in ("Chomp", "Gulp") or (wanted and fid not in wanted):
            continue
        k = scales.get(fid, 1.0)
        size = rig["Size"]
        W, H, L = size[0] * k, size[1] * k, size[2] * k
        try:
            meta, boxes, paints = load_model(fid)
        except FileNotFoundError:
            rows.append({"id": fid, "kind": kind, "missing": True})
            continue
        box = [0.0, -H * 0.05, -L * 0.47]
        at = sizes["mouth_at"].get(fid)
        rule, how, jaws = rule_mouth(rig, boxes, at)
        model_rule = rule_mouth(rig, boxes)[0] if at else None
        colour, paint_h, paint_name = paint_mouth(boxes, paints)
        rule_s = [x * k for x in rule] if rule else None
        colour_s = [x * k for x in colour] if colour else None
        gape, width = gape_of(rig, boxes, jaws)
        lure_rule, lure_truth = lure_of(rig, boxes, paints)
        old_lure = [0.0, H * 0.62 + 1.5, -L * 0.64]
        scaled = {t: size_scale(t, rig.get("Tier"), (W, H, L), sizes) for t in sizes["order"]}
        rows.append(
            {
                "id": fid,
                "kind": kind,
                "tier": rig.get("Tier"),
                "L": L,
                "H": H,
                "how": how,
                "jaws": jaws,
                "box": box,
                "rule": rule_s,
                "model_rule_err": dist([x * k for x in model_rule], colour_s) if model_rule and colour_s else None,
                "colour": colour_s,
                "paint": paint_name,
                "box_err": dist(box, colour_s) if colour_s else None,
                "rule_err": dist(rule_s, colour_s) if colour_s and rule_s else None,
                "box_rule": dist(box, rule_s) if rule_s else None,
                "gape": gape * k if gape is not None else None,
                "width": width * k if width else None,
                "need": need_length(L, gape * k, width * k) if gape and width else None,
                "scales": scaled,
                "lure_rule": [x * k for x in lure_rule] if lure_rule else None,
                "lure_truth": [x * k for x in lure_truth] if lure_truth else None,
                "old_lure": old_lure,
            }
        )
    return rows, sizes


def thrown(rows, sizes, mins):
    """The (kind, size, length) the rows `mins` turn from eaten into thrown"""
    out = []
    for r in rows:
        least = mins.get(r["id"])
        if r.get("missing") or not least:
            continue
        for t in sizes["order"]:
            if r["L"] * r["scales"][t] < least:
                out.append((r["id"], t, r["L"] * r["scales"][t]))
    return out


def main():
    wanted = sys.argv[1:]
    rows, sizes = table_rows(wanted)
    rows.sort(key=lambda r: -(r.get("box_err") or r.get("box_rule") or 0))
    order = sizes["order"]
    out = []
    out.append("Eaters' mouths (studs at the Normal size, the fish's root frame: x right, y up, -z ahead)")
    out.append("Rider taken as R15 about 2 wide x 5 tall x 1 deep: head first needs gape >= 1 and width >= 2, across gape >= 2 and width >= 5.")
    out.append("")
    head = "%-18s %-5s %6s  %-10s %-22s %-22s %-22s %13s %13s"
    out.append(head % ("fish", "kind", "L", "rule from", "box (old)", "rule (new)", "paint (truth)", "box err", "rule err"))
    worst = []
    for r in rows:
        if r.get("missing"):
            out.append("%-18s %-5s  no model in art/creatures" % (r["id"], r["kind"]))
            continue
        L = r["L"]
        be = "%5.1f %5.1f%%" % (r["box_err"], 100 * r["box_err"] / L) if r["box_err"] is not None else "   n/a       "
        re_ = "%5.1f %5.1f%%" % (r["rule_err"], 100 * r["rule_err"] / L) if r["rule_err"] is not None else "   n/a       "
        line = head % (r["id"], r["kind"], "%.1f" % L, r["how"], fmt(r["box"]), fmt(r["rule"]), fmt(r["colour"]), be, re_)
        if r["model_rule_err"] is not None:
            line += "  (MouthAt: the parts' rule was off by %.1f)" % r["model_rule_err"]
        out.append(line)
        if r["lure_rule"]:
            out.append(
                "%-18s       lure: old %s  rule %s  paint %s  old err %.1f  rule err %s"
                % (
                    "",
                    fmt(r["old_lure"]),
                    fmt(r["lure_rule"]),
                    fmt(r["lure_truth"]),
                    dist(r["old_lure"], r["lure_truth"] or r["lure_rule"]),
                    "%.1f" % dist(r["lure_rule"], r["lure_truth"]) if r["lure_truth"] else "n/a",
                )
            )
        worst.append(r)
    out.append("")
    out.append("The rider in the mouth at every size: length, gape/width (studs) and how it goes in (* no jaw: the Head's")
    out.append("share FailController gives the mouth's room, nothing opens). need: the shortest it can be and take a rider head first.")
    out.append("%-18s %6s  %s" % ("fish", "need", "  ".join("%-22s" % t for t in order)))
    for r in sorted(worst, key=lambda r: -(r["need"] or 0)):
        cells = []
        for t in order:
            if r["gape"] is None:
                cells.append("%-22s" % "--")
                continue
            s = r["scales"][t]
            g, w = r["gape"] * s, r["width"] * s
            cells.append("%-22s" % ("%5.1f %4.1f/%4.1f %s%s" % (r["L"] * s, g, w, fits(g, w), "" if r["jaws"] else "*")))
        out.append("%-18s %6s  %s" % (r["id"], "%.1f" % r["need"] if r["need"] else "--", "  ".join(cells)))
    proposed = eat_min(worst, sizes)
    out.append("")
    out.append("Config.Fail.EatMin proposed (studs; a row only for a jawed kind that comes at a size whose jaw cannot take a")
    out.append("rider head first; none for the jawless heads, whose room is a guess): "
               + (", ".join("%s = %g" % kv for kv in sorted(proposed.items())) or "none") + "; the file has: "
               + (", ".join("%s = %g" % kv for kv in sorted(sizes["eat_min"].items())) or "none"))
    out.append("They turn these from eaten into thrown off (length): "
               + (", ".join("%s %s (%.1f)" % x for x in thrown(worst, sizes, proposed)) or "none"))
    out.append("")
    over = [r for r in worst if r["rule_err"] is not None and r["rule_err"] > 1.5]
    out.append("Rule over 1.5 studs from the paint: " + (", ".join("%s %.1f" % (r["id"], r["rule_err"]) for r in over) or "none"))
    nojaw = [r["id"] for r in rows if not r.get("missing") and not r["jaws"]]
    out.append("No jaw part (nothing opens; the mouth is found from the Head part, the fallback): " + (", ".join(nojaw) or "none"))
    nopaint = [r["id"] for r in rows if not r.get("missing") and r["colour"] is None]
    out.append("No painted mouth (the truth unknown: rule against box only): " + (", ".join(nopaint) or "none"))
    out.append("")
    out.append("The ten worst (old box against the painted mouth, studs at Normal; x3 at Colossal):")
    for r in worst[:10]:
        e = r["box_err"] if r["box_err"] is not None else r["box_rule"]
        out.append("  %-18s %-5s box off by %5.1f studs (%4.1f%% of L %.0f), the rule by %s" % (
            r["id"], r["kind"], e, 100 * e / r["L"], r["L"], "%.1f" % r["rule_err"] if r["rule_err"] is not None else "n/a"))
    text = "\n".join(out)
    print(text)
    if not wanted:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        print("\nsaved", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
