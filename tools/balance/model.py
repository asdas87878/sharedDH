"""The balance model for Ride a Fish: what today's numbers mean for a dive, land by land.

usage:  python tools/balance/model.py                  the tables (plain text)
        python tools/balance/model.py --md             the same tables as markdown, for docs/design/progression.md
        python tools/balance/model.py --sim 6          also play 6 dives per rider through the herd (takes a minute or so)
        python tools/balance/model.py --set Oxygen.TierDrain=1 --set Tiers.Rare=56 --set ZoneDrain.3=10 --set ZoneMix.1.Rare=5
                                                       try numbers without editing Config (any of the above with it)
        python tools/balance/model.py --tier-mult 1,1.8,3.3,6,11,20,36
                                                       try a drain for each rarity that isn't the straight line Config has

Nothing is copied here: every number is read from src/shared/Config.luau (the rarities' speeds, Oxygen, ZoneDrain,
ZoneMix, ReachWeight, Spawn, Herd, Jump, Props, Crash, Camera, Ride and the hand-written fish table), the creatures from
src/shared/Creatures/*.json (rarity, home land), and the lands' lengths from the map's path, art/map/greybox/path.json
(measured along the winding centreline, as the game does: the map's own "s" runs about a quarter short of it).

What it works out
  per land     its length, the seconds to cross it at each rarity's speed, the Oxygen a second and the max Oxygen it
               needs, how many wild fish it holds and how they split by rarity, which creatures turn up and how often
  per rarity   speed, the herd's pace, the hop's speeds, the drain, Oxygen per 1,000 studs, where it appears
  the ladder   how fast a rider on one rarity closes on wild fish of another (a wild fish swims at Herd.SpeedShare of
               its own ridden speed, so rarer wild fish are faster than a rider on a common one)
  --sim        a rider played through the game's own stocking rules (FishService: slices, top-ups, parking beyond
               Spawn.StreamRadius, the cull), to count the fish of each rarity that really come within reach

What the sim leaves out: steering, walls, props and big assets, the height of fish, other players, lag. It is a model,
not a measurement: where it matters, have it checked in play.
"""
import argparse
import glob
import json
import math
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG = os.path.join(ROOT, "src", "shared", "Config.luau")
CREATURES = os.path.join(ROOT, "src", "shared", "Creatures")
PATH = os.path.join(ROOT, "art", "map", "greybox", "path.json")

# A guess, not a decision: minutes of play at which a player should first be able to ride each land. Only used for the
# "what training would have to give" table; change it with --plan.
PLAN_MINUTES = [0, 0, 10, 25, 50, 90, 150, 240, 360, 540]


# ---------------------------------------------------------------- reading Config.luau

def strip_comments(src):
    return "\n".join(re.sub(r"--.*$", "", line) for line in src.split("\n"))


def block(src, opener):
    """The text inside the braces that follow `opener` (a regex ending just before the opening brace)."""
    m = re.search(opener + r"\s*\{", src)
    if not m:
        raise SystemExit(f"model.py: can't find {opener!r} in Config.luau")
    depth, i = 1, m.end()
    while depth:
        c = src[i]
        depth += (c == "{") - (c == "}")
        i += 1
    return src[m.end():i - 1]


def number(text):
    text = text.strip()
    if not re.fullmatch(r"[-\d.\s/*+()]+", text):
        return None
    try:
        return float(eval(text, {"__builtins__": {}}))  # only digits and arithmetic get this far
    except Exception:
        return None


def numbers_in(body):
    """`Key = 1.5,` lines of a group, top level only."""
    out, depth = {}, 0
    for line in body.split("\n"):
        if depth == 0:
            m = re.match(r"\s*(\w+)\s*=\s*([^,{]+),?\s*$", line)
            if m and number(m.group(2)) is not None:
                out[m.group(1)] = number(m.group(2))
        depth += line.count("{") - line.count("}")
    return out


def read_config():
    src = strip_comments(open(CONFIG, encoding="utf-8").read())
    cfg = {}
    cfg["TierOrder"] = re.findall(r'"(\w+)"', block(src, r"Config\.TierOrder\s*="))
    cfg["Tiers"] = {}
    for name, ridden in re.findall(r"(\w+)\s*=\s*\{\s*Idle\s*=\s*[\d.]+,\s*Ridden\s*=\s*([\d.]+)", block(src, r"Config\.Tiers\s*=")):
        cfg["Tiers"][name] = float(ridden)
    for group in ("Oxygen", "Spawn", "Herd", "Jump", "Props", "Crash", "Camera", "Ride"):
        cfg[group] = numbers_in(block(src, rf"Config\.{group}\s*="))
    cfg["ZoneDrain"] = [number(v) for v in block(src, r"Config\.ZoneDrain\s*=").split(",") if v.strip()]
    cfg["ZoneMix"] = []
    for row in re.findall(r"\{([^{}]*)\}", block(src, r"Config\.ZoneMix\s*=")):
        cfg["ZoneMix"].append({k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", row)})
    cfg["ReachWeight"] = [number(v) for v in block(src, r"Config\.ReachWeight\s*=").split(",") if v.strip()]
    fish = {}
    for row in re.findall(r"\{\s*Id\s*=[^\n]*\}", block(src, r"local FISH[^=]*=")):
        f = {"Id": re.search(r'Id\s*=\s*"(\w+)"', row).group(1), "Name": re.search(r'Name\s*=\s*"([^"]+)"', row).group(1),
             "Tier": re.search(r'Tier\s*=\s*"(\w+)"', row).group(1), "Home": int(re.search(r"Home\s*=\s*(\d+)", row).group(1)),
             "Reach": 2, "Modelled": False, "RiddenSpeed": None}
        m = re.search(r"\bReach\s*=\s*(\d+)", row)
        if m:
            f["Reach"] = int(m.group(1))
        m = re.search(r"RiddenSpeed\s*=\s*([\d.]+)", row)
        if m:
            f["RiddenSpeed"] = float(m.group(1))
        fish[f["Id"]] = f
    # the modelled creatures bring their own name, rarity and land, as Config.luau's own loop does
    for path in sorted(glob.glob(os.path.join(CREATURES, "*.json"))):
        j = json.load(open(path, encoding="utf-8"))
        fid = os.path.splitext(os.path.basename(path))[0]
        f = fish.setdefault(fid, {"Id": fid, "Reach": 2, "RiddenSpeed": None})
        f.update(Name=j["Name"], Tier=j["Tier"], Home=int(j["Zone"]), Modelled=True)
    cfg["Fish"] = list(fish.values())
    return cfg


def apply_sets(cfg, sets):
    for item in sets:
        path, _, value = item.partition("=")
        keys, v = path.split("."), float(value)
        if keys[0] == "Tiers" and len(keys) == 2:
            cfg["Tiers"][keys[1]] = v
        elif keys[0] == "ZoneDrain" and len(keys) == 2:
            cfg["ZoneDrain"][int(keys[1]) - 1] = v
        elif keys[0] == "ZoneMix" and len(keys) == 3:
            cfg["ZoneMix"][int(keys[1]) - 1][keys[2]] = v
        elif keys[0] == "ReachWeight" and len(keys) == 2:
            cfg["ReachWeight"][int(keys[1]) - 1] = v
        elif keys[0] == "Fish" and len(keys) == 3:  # Fish.ReefShark.RiddenSpeed=70
            next(f for f in cfg["Fish"] if f["Id"] == keys[1])[keys[2]] = v
        elif len(keys) == 2 and keys[0] in cfg and isinstance(cfg[keys[0]], dict):
            cfg[keys[0]][keys[1]] = v
        else:
            raise SystemExit(f"model.py: don't know how to set {path}")


# ---------------------------------------------------------------- the lane

def read_lane():
    """The lands from the map's path: name, where each starts and ends in true studs along the centreline, and the
    lane's width along it. Without the file: 30,163 studs shared out as the map's lands are (1,000 then nine of 2,500)."""
    if not os.path.exists(PATH):
        names = ["Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue", "Twilight", "Midnight", "Vents",
                 "Bone Graveyard", "The Underworld"]
        shares = [1000] + [2500] * 9
        starts, at = [], 0.0
        for share in shares:
            starts.append(at)
            at += 30163 * share / sum(shares)
        return {"Names": names, "Start": starts, "End": starts[1:] + [30163.0], "Length": 30163.0, "S": [0, 30163.0],
                "W": [200, 200], "Y": [0, -2225], "Source": "no path.json: 30,163 studs shared out by the map's plan"}
    j = json.load(open(PATH, encoding="utf-8"))
    pts = j["Path"]
    true = [0.0]
    for a, b in zip(pts, pts[1:]):
        true.append(true[-1] + math.dist(a[1:4], b[1:4]))

    def at_map_s(s):
        for i in range(len(pts) - 1):
            if pts[i][0] <= s <= pts[i + 1][0]:
                u = (s - pts[i][0]) / max(pts[i + 1][0] - pts[i][0], 1e-9)
                return true[i] + (true[i + 1] - true[i]) * u
        return true[-1]

    starts = [at_map_s(land["S0"]) for land in j["Lands"]]
    return {"Names": [land["Name"] for land in j["Lands"]], "Start": starts, "End": starts[1:] + [true[-1]],
            "Length": true[-1], "S": true, "W": [p[4] for p in pts], "Y": [p[2] for p in pts],
            "Source": os.path.relpath(PATH, ROOT).replace("\\", "/")}


def width_at(lane, s):
    S, W = lane["S"], lane["W"]
    if s <= S[0]:
        return W[0]
    if s >= S[-1]:
        return W[-1]
    lo, hi = 0, len(S) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if S[mid] <= s:
            lo = mid
        else:
            hi = mid
    u = (s - S[lo]) / max(S[hi] - S[lo], 1e-9)
    return W[lo] + (W[hi] - W[lo]) * u


def land_at(lane, s):
    for i in range(len(lane["Start"]) - 1, -1, -1):
        if s >= lane["Start"][i]:
            return i
    return 0


# ---------------------------------------------------------------- the game's own sums

def tier_step(cfg, tier):
    return cfg["TierOrder"].index(tier) if tier in cfg["TierOrder"] else 0


def drain(cfg, land, tier):
    """Config.drain: Oxygen a second on a fish of this rarity in land number `land` (0-based here)."""
    per = cfg["ZoneDrain"]
    return per[min(max(land, 0), len(per) - 1)] * tier_mult(cfg, tier)


def tier_mult(cfg, tier):
    """How many times a Common's drain this rarity takes: Config's 1 + TierDrain for each step up, or --tier-mult's
    own list (a what-if: Config has no such table today)."""
    if cfg.get("TierMult"):
        return cfg["TierMult"][min(tier_step(cfg, tier), len(cfg["TierMult"]) - 1)]
    return 1 + cfg["Oxygen"]["TierDrain"] * tier_step(cfg, tier)


def required(cfg, land, tier="Common", every=None):
    """Config.required: the max Oxygen that just keeps up, landing a hop every `every` seconds (Oxygen.KeepUp)."""
    o = cfg["Oxygen"]
    return math.ceil(drain(cfg, land, tier) * (o["KeepUp"] if every is None else every) / max(o["Refill"], 0.01))


def ridden(cfg, fish):
    return fish.get("RiddenSpeed") or cfg["Tiers"][fish["Tier"]]


def pools(cfg, lands):
    """FishService.pool: for each land, by rarity, the fish that can turn up there with their weights."""
    out = []
    for z in range(lands):
        by = {}
        for f in cfg["Fish"]:
            away = z + 1 - f["Home"]
            if 0 <= away <= f["Reach"] and away < len(cfg["ReachWeight"]) and cfg["ReachWeight"][away] > 0:
                by.setdefault(f["Tier"], []).append((f, cfg["ReachWeight"][away]))
        out.append(by)
    return out


def effective_mix(cfg, pool, z):
    """The land's mix as FishService.pick uses it: a rarity with no fish there is skipped and the rest share it out."""
    mix = cfg["ZoneMix"][z] if z < len(cfg["ZoneMix"]) else {}
    live = {t: share for t, share in mix.items() if t in pool}
    total = sum(live.values())
    return {t: share / total for t, share in live.items()} if total > 0 else {}


def slices(cfg, lane, pool_list):
    """FishService.newSlices: the lane cut into slices, each with the fish it should hold."""
    sp, out, total = cfg["Spawn"], [], 0
    for z in range(len(lane["Start"])):
        s0, s1 = lane["Start"][z], lane["End"][z]
        length = s1 - s0
        if length > 1 and effective_mix(cfg, pool_list[z], z):
            n = max(1, math.floor(length / sp["Slice"] + 0.5))
            want = max(n, min(max(math.floor(length / 1000 * sp["PerThousand"]), sp["Min"]), sp["Max"]))
            for k in range(1, n + 1):
                share = max(1, math.floor(want * k / n) - math.floor(want * (k - 1) / n))
                out.append({"Start": s0 + length * (k - 1) / n, "End": s0 + length * k / n, "Zone": z, "Want": share})
                total += share
    if out:
        out[0]["Want"] = max(out[0]["Want"], int(sp["BoardSlice"]))
    while total > sp["MaxTotal"]:
        fullest = max((s for s in out if s["Want"] > 1), key=lambda s: s["Want"], default=None)
        if not fullest:
            break
        fullest["Want"] -= 1
        total -= 1
    return out


def hop(cfg, speed):
    """The hop off a fish ridden at `speed`: its top speed, the glide's, and how far the pop and glide carry you
    before the pull-in begins (Jump.LaunchTime + FloatTime after the press)."""
    j = cfg["Jump"]
    pop = j["Launch"] * speed
    glide = j["AirShare"] * speed if j.get("AirShare", 0) > 0 else j["AirSpeed"]
    air = j["LaunchTime"] + j["FloatTime"]
    boost = min(j["BoostTime"], air)
    # the pop's extra speed runs out over BoostTime: taken as a straight ease from pop to glide
    far = boost * (pop + glide) / 2 + (air - boost) * glide
    return pop, glide, far, air


# ---------------------------------------------------------------- the tables

class Out:
    def __init__(self, md):
        self.md = md

    def title(self, text, note=""):
        print(("\n### " if self.md else "\n== ") + text + ("" if self.md else " =="))
        if note:
            print(note)
        if self.md:
            print()

    def table(self, head, rows):
        rows = [[str(c) for c in row] for row in rows]
        if self.md:
            print("| " + " | ".join(head) + " |")
            print("|" + "|".join("---" for _ in head) + "|")
            for row in rows:
                print("| " + " | ".join(row) + " |")
            return
        widths = [max(len(head[i]), *(len(r[i]) for r in rows)) if rows else len(head[i]) for i in range(len(head))]
        print("  ".join(h.ljust(w) for h, w in zip(head, widths)))
        for row in rows:
            print("  ".join(c.rjust(w) if re.fullmatch(r"[-+x]?[\d,.]+%?", c) else c.ljust(w) for c, w in zip(row, widths)).rstrip())


def n(v, places=0):
    if v is None:
        return ""
    if abs(v) >= 1000:
        return f"{v:,.0f}"
    return f"{v:.{places}f}"


def pct(share):
    if share <= 0:
        return ""
    return f"{share * 100:.1f}%" if share < 0.1 else f"{share * 100:.0f}%"


def tables(cfg, lane, out):
    order = cfg["TierOrder"]
    lands = len(lane["Start"])
    pool_list = pools(cfg, lands)
    sl = slices(cfg, lane, pool_list)
    fish_in = [sum(s["Want"] for s in sl if s["Zone"] == z) for z in range(lands)]
    lengths = [lane["End"][z] - lane["Start"][z] for z in range(lands)]
    o, j = cfg["Oxygen"], cfg["Jump"]
    share = cfg["Herd"]["SpeedShare"]

    out.title("The lane", f"{lane['Length']:,.0f} studs to ride over {lands} lands ({lane['Source']}); "
              f"{sum(fish_in)} wild fish in all (Spawn.PerThousand {cfg['Spawn']['PerThousand']:g}, MaxTotal {cfg['Spawn']['MaxTotal']:g}).")
    head = ["Land", "Studs", "Width", "Fish", "Studs between"] + [f"s at {t} ({cfg['Tiers'][t]:g})" for t in order]
    rows = []
    for z in range(lands):
        ws = [width_at(lane, lane["Start"][z] + lengths[z] * k / 20) for k in range(21)]
        rows.append([f"{z + 1} {lane['Names'][z]}", n(lengths[z]), f"{min(ws):.0f} to {max(ws):.0f}", fish_in[z],
                     n(lengths[z] / fish_in[z]) if fish_in[z] else "none"] + [n(lengths[z] / cfg["Tiers"][t]) for t in order])
    rows.append(["All ten", n(lane["Length"]), "", sum(fish_in), ""] + [n(lane["Length"] / cfg["Tiers"][t]) for t in order])
    out.table(head, rows)

    out.title("Oxygen by land", f"Drain a second on a Common, and the max Oxygen that keeps up (drain x KeepUp {o['KeepUp']:g} / Refill "
              f"{o['Refill']:g}). \"Usual fish\" is the land's own mix, weighted. Hop-hop is a rider who hops again the moment the "
              f"cooldown ends ({j['Cooldown']:g} s on each fish): the hop itself drains nothing. Start max is {o['StartMax']:g}.")
    head = ["Land", "Drain /s", "x the land before", "Needs (Common)", "Needs (usual fish)", "Needs (rarest there)",
            "Needs hopping every 3 s", "Needs hop-hop", f"Seconds a full {o['StartMax']:g} lasts, no hops"]
    rows = []
    for z in range(lands):
        mix = effective_mix(cfg, pool_list[z], z)
        usual = sum(s * tier_mult(cfg, t) for t, s in mix.items()) if mix else 1
        rarest = max(mix, key=lambda t: tier_step(cfg, t)) if mix else "Common"
        d = drain(cfg, z, "Common")
        rows.append([f"{z + 1} {lane['Names'][z]}", n(d, 1 if d < 10 else 0), f"x{d / drain(cfg, z - 1, 'Common'):.1f}" if z else "",
                     n(required(cfg, z)), n(math.ceil(required(cfg, z) * usual)), f"{n(required(cfg, z, rarest))} ({rarest})",
                     n(required(cfg, z, every=3)), n(required(cfg, z, every=j["Cooldown"])), n(o["StartMax"] / d, 1)])
    out.table(head, rows)

    out.title("By rarity", f"A wild fish swims at Herd.SpeedShare {share:g} of its ridden speed. The hop off a fish: the pop at Jump.Launch "
              f"{j['Launch']:g} times the ridden speed, the glide at AirShare {j.get('AirShare', 0):g} of it, and the pull-in begins "
              f"{j['LaunchTime'] + j['FloatTime']:g} s after the press.")
    cam = cfg["Camera"]
    head = ["Rarity", "Ridden", "Step up", "Wild (herd)", "Pop", "Glide", "Hop carries (studs)", "Drain x", "Oxygen per 1,000 studs (Common = 1)",
            "View widens (deg)", "Turn circle (studs across)", "Lands"]
    rows, base = [], None
    for i, t in enumerate(order):
        v = cfg["Tiers"][t]
        pop, glide, far, _ = hop(cfg, v)
        mult = tier_mult(cfg, t)
        per_stud = mult / v
        base = base or per_stud
        fov = cam["SpeedFov"] * min(max((v - cam["SpeedFovFrom"]) / (cam["SpeedFovTo"] - cam["SpeedFovFrom"]), 0), 1)
        where = [str(z + 1) for z in range(lands) if t in effective_mix(cfg, pool_list[z], z)]
        planned = [str(z + 1) for z in range(min(lands, len(cfg["ZoneMix"]))) if t in cfg["ZoneMix"][z]]
        rows.append([t, n(v), f"+{(v / cfg['Tiers'][order[i - 1]] - 1) * 100:.0f}%" if i else "", n(v * share, 1), n(pop), n(glide, 1), n(far),
                     f"{mult:.2f}", f"{per_stud / base:.2f}", n(fov, 1), n(2 * v / math.radians(cfg["Ride"]["YawRate"])),
                     (", ".join(where) or "nowhere") + ("" if where == planned else f" (the mix asks for {', '.join(planned) or 'none'})")])
    out.table(head, rows)

    out.title("The ladder: closing speed", "Studs a second a rider gains on a wild fish ahead (ridden speed minus the wild fish's pace). "
              "Negative: the wild fish pulls away, and can only be caught if it starts within reach or comes up from behind. "
              f"Reach is Jump.GrabRange {j['GrabRange']:g} studs.")
    head = ["Riding a \\ wild"] + order
    rows = []
    for t in order:
        rows.append([t] + [f"{cfg['Tiers'][t] - cfg['Tiers'][u] * share:+.0f}" for u in order])
    out.table(head, rows)

    out.title("Wild fish by land and rarity", "The share each rarity really gets (a rarity with no creature in the land is skipped and "
              "the others share it out), and the fish of it standing in the land at once. \"1 in\" is how many crossings of the land "
              "it takes to have one of that rarity in it.")
    head = ["Land", "Fish"] + order
    rows = []
    for z in range(lands):
        mix = effective_mix(cfg, pool_list[z], z)
        asked = cfg["ZoneMix"][z] if z < len(cfg["ZoneMix"]) else {}
        row = [f"{z + 1} {lane['Names'][z]}", fish_in[z]]
        for t in order:
            if t in mix:
                count = mix[t] * fish_in[z]
                row.append(f"{pct(mix[t])}, {count:.1f}" + (f" (1 in {1 / count:.0f})" if count < 0.5 else ""))
            elif t in asked:
                row.append(f"asks {asked[t]:g}%: no creature")
            else:
                row.append("")
        rows.append(row)
    out.table(head, rows)

    out.title("Fish passed a minute, the simple sum", "Riding the land's usual fish through a herd standing at its spawn density: "
              "density x (your speed minus that rarity's pace). Only rarities slower than you are passed; the rest keep ahead. "
              "The --sim tables say what the game's stocking rules make of this.")
    head = ["Land", "Usual ride (studs/s)"] + order
    rows = []
    for z in range(lands):
        mix = effective_mix(cfg, pool_list[z], z)
        if not mix or not fish_in[z]:
            rows.append([f"{z + 1} {lane['Names'][z]}", ""] + ["" for _ in order])
            continue
        mine = sum(s * cfg["Tiers"][t] for t, s in mix.items())
        row = [f"{z + 1} {lane['Names'][z]}", n(mine)]
        for t in order:
            if t not in mix:
                row.append("")
                continue
            close = mine - cfg["Tiers"][t] * share
            row.append(n(mix[t] * fish_in[z] / lengths[z] * close * 60, 1) if close > 0 else "keeps ahead")
        rows.append(row)
    out.table(head, rows)

    out.title("Which creatures turn up", "By land: each creature that can spawn there and its share of all spawns in that land. "
              "A star marks a creature with no model in the place yet (it spawns as a placeholder body).")
    head = ["Land", "Creatures (share of the land's spawns)"]
    rows = []
    for z in range(lands):
        mix = effective_mix(cfg, pool_list[z], z)
        parts = []
        for t in order:
            if t not in mix:
                continue
            total = sum(w for _, w in pool_list[z][t])
            names = sorted(pool_list[z][t], key=lambda fw: -fw[1])
            parts.append(f"{t}: " + ", ".join(f"{f['Name']}{'' if f['Modelled'] else '*'} {pct(mix[t] * w / total)}" for f, w in names))
        rows.append([f"{z + 1} {lane['Names'][z]}", "; ".join(parts) or "nothing can spawn here: the land stays empty"])
    out.table(head, rows)

    out.title("What training would have to give", "The plan is a guess (PLAN_MINUTES in the model, --plan to change it): the minutes "
              "of play at which a player should first be able to ride each land on its usual fish. From it, the max Oxygen "
              "wanted by then and the gain a second of ALL play time between two lands that gets there.")
    head = ["Land", "Wanted by (min)", "Max Oxygen needed", "Gain needed over the stretch", "A second of play", "x the stretch before"]
    rows, have, last_rate, last_t = [], o["StartMax"], None, 0
    for z in range(lands):
        mix = effective_mix(cfg, pool_list[z], z)
        usual = sum(s * tier_mult(cfg, t) for t, s in mix.items()) if mix else 1
        need = math.ceil(required(cfg, z) * usual)
        t = PLAN_MINUTES[z] if z < len(PLAN_MINUTES) else PLAN_MINUTES[-1]
        gain = max(0, need - have)
        rate = gain / ((t - last_t) * 60) if t > last_t else None
        rows.append([f"{z + 1} {lane['Names'][z]}", t, n(need), n(gain) if gain else "none", n(rate, 2) if rate else "",
                     f"x{rate / last_rate:.1f}" if rate and last_rate else ""])
        if rate:
            last_rate = rate
        have, last_t = max(have, need), t
    out.table(head, rows)


# ---------------------------------------------------------------- the dive, played through the herd

class Herd:
    """FishService's stocking, in one line along the lane with a place across it."""

    def __init__(self, cfg, lane, rng):
        self.cfg, self.lane, self.rng = cfg, lane, rng
        self.pools = pools(cfg, len(lane["Start"]))
        self.slices = slices(cfg, lane, self.pools)
        self.fish = []
        self.mixes = [effective_mix(cfg, self.pools[z], z) for z in range(len(lane["Start"]))]
        self.share = cfg["Herd"]["SpeedShare"]

    def band(self, s):
        sp = self.cfg["Spawn"]
        return min(width_at(self.lane, s) / 2 * sp["LaneFill"], sp["BandMax"] / 2)

    def slice_at(self, s):
        lo, hi = 0, len(self.slices) - 1
        while lo <= hi:
            mid = (lo + hi) // 2
            sl = self.slices[mid]
            if s < sl["Start"]:
                hi = mid - 1
            elif s >= sl["End"]:
                lo = mid + 1
            else:
                return mid
        return None

    def pick(self, z):
        mix = self.mixes[z]
        if not mix:
            return None
        roll, tier = self.rng.random(), None
        for t in self.cfg["TierOrder"]:
            if t in mix:
                tier = t
                roll -= mix[t]
                if roll <= 0:
                    break
        options = self.pools[z][tier]
        r = self.rng.random() * sum(w for _, w in options)
        for f, w in options:
            r -= w
            if r <= 0:
                return f
        return options[-1][0]

    def spawn(self, index, rider):
        sl = self.slices[index]
        kind = self.pick(sl["Zone"])
        if not kind:
            return None
        s = self.rng.uniform(sl["Start"], sl["End"])
        f = {"s": s, "x": self.rng.uniform(-1, 1) * self.band(s), "kind": kind, "tier": kind["Tier"],
             "speed": ridden(self.cfg, kind) * self.share, "slice": index, "ridden": False, "parked": True, "seen": False}
        f["parked"] = not self.near(f, rider, self.cfg["Spawn"]["StreamRadius"])
        self.fish.append(f)
        return f

    @staticmethod
    def near(f, rider, radius):
        return rider is not None and math.hypot(f["s"] - rider["s"], f["x"] - rider["x"]) < radius

    def top_up(self, limit, rider):
        sp = self.cfg["Spawn"]
        per = [0] * len(self.slices)
        for f in self.fish:
            if f["slice"] is not None and not f["ridden"]:
                per[f["slice"]] += 1
        total, made = len(self.fish), 0
        while made < limit and total < sp["MaxTotal"]:
            best, best_score = None, 0
            for i, sl in enumerate(self.slices):
                if per[i] < sl["Want"]:
                    score = (sl["Want"] - per[i]) / sl["Want"] + self.rng.random() * 0.01
                    if score > best_score:
                        best, best_score = i, score
            if best is None or not self.spawn(best, rider):
                break
            per[best] += 1
            total += 1
            made += 1
        keep = []
        for f in self.fish:
            if f["ridden"]:
                keep.append(f)
                continue
            old, now = f["slice"], self.slice_at(f["s"])
            if now != old:
                if old is not None:
                    per[old] -= 1
                if now is not None:
                    per[now] += 1
                f["slice"] = now
            zone = land_at(self.lane, f["s"]) + 1
            strayed = zone > f["kind"]["Home"] + f["kind"]["Reach"]
            over = now is None or strayed or per[now] > self.slices[now]["Want"] + 1
            if over and not self.near(f, rider, 250):
                if now is not None:
                    per[now] -= 1
                continue
            f["parked"] = not self.near(f, rider, sp["StreamRadius"])
            keep.append(f)
        self.fish = keep

    def step(self, dt):
        for f in self.fish:
            if not f["parked"] and not f["ridden"]:
                f["s"] += f["speed"] * dt


def dive(cfg, lane, rng, policy, ride_time, start_max, props_every=0.0, dt=0.1, endless=False):
    """One dive. policy "nearest": hop to the nearest free fish ahead; "rarest": to the rarest in reach, the nearest of
    those. The rider rides `ride_time` seconds on each fish, then hops. Returns what happened."""
    o, j, sp = cfg["Oxygen"], cfg["Jump"], cfg["Spawn"]
    order = cfg["TierOrder"]
    herd = Herd(cfg, lane, rng)
    rider = {"s": 30.0, "x": 0.0}
    herd.top_up(10 ** 9, rider)
    free = [f for f in herd.fish if not f["ridden"]]
    mount = min(free, key=lambda f: math.hypot(f["s"] - rider["s"], f["x"])) if free else None
    if not mount:
        return None
    mount["ridden"] = True
    rider["s"], rider["x"] = mount["s"], mount["x"]
    lands = len(lane["Start"])
    res = {"met": [dict.fromkeys(order, 0) for _ in range(lands)], "time": [0.0] * lands, "first": {}, "end": "the lane's end",
           "rode": dict.fromkeys(order, 0.0), "hops": 0, "props": 0}
    oxygen = start_max
    t, since_top, since_hop, since_prop = 0.0, 0.0, 0.0, 0.0
    state, air_left, target = "ride", 0.0, None
    air_speed = 0.0
    reach = j["GrabRange"]
    while rider["s"] < lane["Length"] - 5 and t < 3600:
        z = land_at(lane, rider["s"])
        res["time"][z] += dt
        herd.step(dt)
        if state == "ride":
            v = ridden(cfg, mount["kind"])
            rider["s"] += v * dt
            mount["s"], rider["x"] = rider["s"], mount["x"]
            res["rode"][mount["tier"]] += dt
            if not endless:
                oxygen -= drain(cfg, z, mount["tier"]) * dt
                if props_every > 0:
                    since_prop += dt
                    if since_prop >= props_every:
                        since_prop = 0.0
                        res["props"] += 1
                        oxygen = max(min(oxygen, cfg["Crash"]["Floor"]), oxygen - start_max * cfg["Props"]["Cost"])
                if oxygen <= 0:
                    res["end"] = "out of Oxygen"
                    break
            since_hop += dt
            pop, glide, far, air = hop(cfg, v)
            # a rider looks before hopping (the lock shows while riding): they go only when a fish will be ahead and in
            # reach as the glide ends; until then they ride on, and pay for it
            if since_hop >= ride_time and any(
                    not f["parked"] and f is not mount and -5 <= f["s"] + f["speed"] * air - rider["s"] - far <= reach
                    and math.hypot(f["s"] + f["speed"] * air - rider["s"] - far, f["x"] - rider["x"]) <= reach * 0.9
                    for f in herd.fish):
                state, air_left, since_hop = "air", j["Window"], 0.0
                mount["ridden"] = False
                left, mount = mount, None
                air_at = 0.0
        else:
            # the hop: the pop easing to the glide; the pull-in may begin once the glide has ended
            boost = j["BoostTime"]
            air_speed = pop + (glide - pop) * min(air_at / boost, 1) if boost > 0 else glide
            rider["s"] += air_speed * dt
            air_at += dt
            air_left -= dt
            if air_at >= j["LaunchTime"] + j["FloatTime"]:
                options = [f for f in herd.fish if not f["parked"] and f is not left and f["s"] >= rider["s"] - 5
                           and math.hypot(f["s"] - rider["s"], f["x"] - rider["x"]) <= reach]
                if options:
                    if policy == "rarest":
                        target = min(options, key=lambda f: (-order.index(f["tier"]), math.hypot(f["s"] - rider["s"], f["x"] - rider["x"])))
                    else:
                        target = min(options, key=lambda f: math.hypot(f["s"] - rider["s"], f["x"] - rider["x"]))
                    far = math.hypot(target["s"] - rider["s"], target["x"] - rider["x"])
                    reel = min(max(j["ReelTime"] + far / j["GrabSpeed"], j["ReelMin"]), j["ReelMax"])
                    herd.step(reel)
                    t += reel
                    res["time"][z] += reel
                    mount, state = target, "ride"
                    mount["ridden"] = True
                    rider["s"], rider["x"] = mount["s"], mount["x"]
                    res["hops"] += 1
                    oxygen = min(start_max, oxygen + start_max * o["Refill"])
                elif air_left <= 0:
                    res["end"] = "missed every fish"
                    break
        # who is within reach now
        for f in herd.fish:
            if not f["seen"] and not f["parked"] and not f["ridden"] and abs(f["s"] - rider["s"]) <= reach \
                    and math.hypot(f["s"] - rider["s"], f["x"] - rider["x"]) <= reach:
                f["seen"] = True
                res["met"][z][f["tier"]] += 1
                res["first"].setdefault(f["tier"], t)
        t += dt
        since_top += dt
        if since_top >= sp["TopUpEvery"]:
            since_top = 0.0
            herd.top_up(int(sp["PerTopUp"]), rider)
    res["seconds"], res["reached"], res["s"] = t, land_at(lane, rider["s"]), rider["s"]
    res["left"] = oxygen
    return res


def sim(cfg, lane, out, runs, seed):
    order = cfg["TierOrder"]
    lands = len(lane["Start"])
    o = cfg["Oxygen"]
    riders = [("nearest fish, a hop every %g s" % o["KeepUp"], "nearest", o["KeepUp"]),
              ("rarest fish in reach, a hop every %g s" % o["KeepUp"], "rarest", o["KeepUp"]),
              ("rarest fish in reach, a hop every 2 s", "rarest", 2.0)]
    for label, policy, ride_time in riders:
        rng = random.Random(seed)
        all_runs = [dive(cfg, lane, rng, policy, ride_time, o["StartMax"], endless=True) for _ in range(runs)]
        all_runs = [r for r in all_runs if r]
        out.title(f"Played through the herd, endless air: {label}", f"{len(all_runs)} dives. Fish of each rarity that came within reach "
                  f"(Jump.GrabRange) a minute, by land; then the seconds into the dive at which the first of each rarity did.")
        head = ["Land", "Seconds in it"] + order + ["All"]
        rows = []
        for z in range(lands):
            secs = sum(r["time"][z] for r in all_runs)
            if secs <= 0:
                continue
            per = [sum(r["met"][z][t] for r in all_runs) / secs * 60 for t in order]
            rows.append([f"{z + 1} {lane['Names'][z]}", n(secs / len(all_runs))] + [n(v, 1) if v > 0 else "" for v in per] + [n(sum(per), 1)])
        out.table(head, rows)
        firsts = []
        for tier in order:
            times = sorted(r["first"][tier] for r in all_runs if tier in r["first"])
            if times:
                firsts.append(f"{tier} {times[len(times) // 2]:.0f} s ({len(times)} of {len(all_runs)} dives)")
        rode = {tier: sum(r["rode"][tier] for r in all_runs) for tier in order}
        total = sum(rode.values()) or 1
        ends = {}
        for r in all_runs:
            ends[r["end"]] = ends.get(r["end"], 0) + 1
        if out.md:
            print()
        print("First within reach (the middle dive): " + "; ".join(firsts) + ".")
        print("Time ridden by rarity: " + ", ".join(f"{tier} {rode[tier] / total * 100:.0f}%" for tier in order if rode[tier] > 0)
              + f". The dive took {sum(r['seconds'] for r in all_runs) / len(all_runs) / 60:.1f} minutes on average; ended: "
              + ", ".join(f"{k} {v}" for k, v in ends.items()) + ".")

    out.title("A new player's dive: how far the starting Oxygen goes", f"Start max {o['StartMax']:g}, Endless air off. Each line is a rider "
              f"and how often small props are hit (each takes Props.Cost {cfg['Props']['Cost']:g} of max). {runs} dives each. "
              "The last columns: fish of that rarity that came within reach in one dive, on average.")
    head = ["Rider", "Props", "Lasts (s)", "Studs", "Ends in land", "Hops landed", "How it ended"] + [f"{t} in reach" for t in order[2:6]]
    rows = []
    for label, policy, ride_time in riders + [("nearest fish, hop-hop (0.3 s on each fish)", "nearest", cfg["Jump"]["Cooldown"])]:
        for props_every in (0.0, 2.5):
            rng = random.Random(seed)
            rs = [dive(cfg, lane, rng, policy, ride_time, o["StartMax"], props_every=props_every) for _ in range(runs)]
            rs = [r for r in rs if r]
            lands_hit = sorted(r["reached"] + 1 for r in rs)
            ends = {}
            for r in rs:
                ends[r["end"]] = ends.get(r["end"], 0) + 1
            rows.append([label, "none" if not props_every else f"one every {props_every:g} s", n(sum(r["seconds"] for r in rs) / len(rs)),
                         n(sum(r["s"] for r in rs) / len(rs)), f"{lands_hit[0]} to {lands_hit[-1]}" if lands_hit[0] != lands_hit[-1] else lands_hit[0],
                         n(sum(r["hops"] for r in rs) / len(rs)), ", ".join(f"{k} {v}" for k, v in ends.items())]
                        + [n(sum(sum(land[t] for land in r["met"]) for r in rs) / len(rs), 1) for t in order[2:6]])
    out.table(head, rows)


def main():
    global PLAN_MINUTES
    p = argparse.ArgumentParser(description="Ride a Fish balance model")
    p.add_argument("--md", action="store_true", help="markdown tables")
    p.add_argument("--sim", type=int, default=0, metavar="N", help="play N dives per rider through the herd")
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--set", action="append", default=[], metavar="Group.Key=value", help="try a number without editing Config")
    p.add_argument("--plan", default="", help="minutes of play by which each land should be ridable, ten numbers with commas")
    p.add_argument("--tier-mult", default="", help="a what-if: each rarity's drain as times a Common's, seven numbers with commas")
    a = p.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    cfg = read_config()
    apply_sets(cfg, a.set)
    if a.tier_mult:
        cfg["TierMult"] = [float(v) for v in a.tier_mult.split(",")]
        a.set.append("the rarities' drain x" + a.tier_mult)
    if a.plan:
        PLAN_MINUTES = [float(v) for v in a.plan.split(",")]
    lane = read_lane()
    out = Out(a.md)
    if a.set:
        print("With: " + ", ".join(a.set))
    tables(cfg, lane, out)
    if a.sim > 0:
        sim(cfg, lane, out, a.sim, a.seed)


if __name__ == "__main__":
    main()
