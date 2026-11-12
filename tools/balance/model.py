"""The balance model for Ride a Fish: what today's numbers mean for a dive, land by land.

usage:  python tools/balance/model.py                  the tables (plain text)
        python tools/balance/model.py --md             the same tables as markdown, for docs/design/progression.md
        python tools/balance/model.py --sim 8          also play 8 dives per rider through the herd (takes a minute or so)
        python tools/balance/model.py --sim 40 --dives only the dives' table ("How far a max Oxygen gets")
        python tools/balance/model.py --set RarityDrain.Legendary=15 --set Tiers.Rare=56 --set ZoneDrain.3=640 --set ZoneMix.1.Rare=5
                                                       try numbers without editing Config (any of the above with it)
        python tools/balance/model.py --max 1280       the "your Oxygen" tables for a player with this max, not the start's

Nothing is copied here: every number is read from src/shared/Config.luau (the rarities' speeds, Oxygen, ZoneDrain,
RarityDrain, ZoneMix, ReachWeight, Spawn, Herd, Jump, Props, Crash, Camera, Ride and the hand-written fish table), the
creatures from src/shared/Creatures/*.json (rarity, home land), and the lands' lengths from the map's path,
art/map/greybox/path.json (measured along the winding centreline, as the game does: the map's own "s" runs about a
quarter short of it).

The unit is SECONDS ON A FISH (the user, 2026-11-11): what your max Oxygen buys on a fish of this land and rarity,
max / (ZoneDrain[land] x RarityDrain[rarity]). A landing on another fish gives back Oxygen.Refill of max; at 1 every
fish starts with the whole meter, as the reference's ring does.

HOLD OR NOT (the user, 2026-11-12): a fish that needs more than your max Oxygen (Config.required, the number on its
tag: Oxygen.KeepUp seconds on it, by the land you land on it in) is too strong for you. The landing is never refused:
the whole meter empties in Oxygen.StrainTime seconds and you are thrown off. So every fish is either held (KeepUp
seconds or more) or not, and a land is a bar, not a slope. A fish you hold makes itself yours after Tame.Time seconds
on it (Config.Tame), up to Tame.Carry a dive.

What it works out
  per land     its length and the seconds to cross it, the seconds a new player has on each rarity there, the max
               Oxygen the land stands for, how many wild fish it holds by rarity, which creatures turn up
  per rarity   speed, the herd's pace, the hop's speeds, the drain, where it appears
  hopping      the pace of a rider who hops every few seconds (most of a dive is hop), and what it closes on
  the bar      the max Oxygen each fish needs, the share of a land's fish a player can hold, and the rarest fish a
               player can tame in each land
  --sim        a rider played through the game's own stocking rules (FishService: slices, top-ups, parking beyond
               Spawn.StreamRadius, the cull), to count the fish of each rarity that really come within reach, how
               far a given max Oxygen gets, and what a dive brings home

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

# Guesses, not decisions (change with --home, --scrape, --ride, --plan). The rider's own numbers (RIDE to LOCK_AHEAD)
# were set after the first played dive of 2026-11-11: 1.2 s on each fish, hops of 2.4 s and 180 studs, the dive over on
# the first Coral Reef fish, 15.6 s in. The first model's rider hopped 0.3 s after every landing in the Reef, which no
# player at ease does, and its hop was 20 studs short.
HOME = 2.5  # seconds on a land's commonest fish that count as being at home there (a new player's on a Shallows Common)
SCRAPE = 1.0  # seconds on it that just get you through, hopping all the time
RIDE = 1.8  # seconds a rider at ease spends on each fish before hopping (0.7 s left on a fish that gives 2.5)
REACT = 0.7  # a rider at ease can't hop sooner than this after landing: on a fish that gives less they are thrown off
LEAVE = 0.7  # and hops when this many seconds are left on the fish, if that comes first
TAGS = 1.0  # a rider who reads the tags doesn't choose a fish that gives less than this (only with Oxygen.StrainTime 0: with it on they choose the fish they can hold)
MIN_SIT = 0.4  # with Space held: doesn't choose a fish that gives less than this (the hop's cooldown is 0.3)
LOCK_AHEAD = 60  # the lock gives the fish nearest the view's aim, about this far ahead (played 2026-11-11: hops of 180 studs)
# minutes of play at which a player should first be at home in each land; only used for the training table
PLAN_MINUTES = [0, 5, 15, 30, 55, 90, 150, 240, 360, 540]


# ---------------------------------------------------------------- reading Config.luau

def strip_comments(src):
    return "\n".join(re.sub(r"--.*$", "", line) for line in src.split("\n"))


def block(src, opener, must=True):
    """The text inside the braces that follow `opener` (a regex ending just before the opening brace)."""
    m = re.search(opener + r"\s*\{", src)
    if not m:
        if must:
            raise SystemExit(f"model.py: can't find {opener!r} in Config.luau")
        return None
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
    # how many times a Common's Oxygen each rarity takes (until 2026-11-11 a straight line, Oxygen.TierDrain a step)
    rarity = block(src, r"Config\.RarityDrain\s*=", must=False)
    if rarity is not None:
        cfg["RarityDrain"] = numbers_in(rarity)
    else:
        step = cfg["Oxygen"].get("TierDrain", 0)
        cfg["RarityDrain"] = {t: 1 + step * i for i, t in enumerate(cfg["TierOrder"])}
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
        # (a creature that isn't in Config's own table takes Reach 2, or 1 if it is a Common: Config's rule)
        f = fish.setdefault(fid, {"Id": fid, "Reach": 1 if j["Tier"] == "Common" else 2, "RiddenSpeed": None})
        f.update(Name=j["Name"], Tier=j["Tier"], Home=int(j["Zone"]), Modelled=True)
    # a creature Config keeps out of the herd (NO_SPAWN: Reach -1, so no land takes it)
    kept_out = block(src, r"local NO_SPAWN[^=]*=", must=False)
    for fid in re.findall(r"(\w+)\s*=\s*true", kept_out or ""):
        if fid in fish:
            fish[fid]["Reach"] = -1
    cfg["Fish"] = list(fish.values())
    train = block(src, r"Config\.Train\s*=", must=False)
    cfg["Train"] = numbers_in(train) if train is not None else {}
    tame = block(src, r"Config\.Tame\s*=", must=False)
    cfg["Tame"] = numbers_in(tame) if tame is not None else {}
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


def tier_mult(cfg, tier):
    """Config.RarityDrain: how many times a Common's Oxygen this rarity takes a second."""
    return cfg["RarityDrain"].get(tier, 1)


def drain(cfg, land, tier):
    """Config.drain: Oxygen a second on a fish of this rarity in land number `land` (0-based here)."""
    per = cfg["ZoneDrain"]
    return per[min(max(land, 0), len(per) - 1)] * tier_mult(cfg, tier)


def required(cfg, land, tier="Common"):
    """Config.required: what the HUD and a fish's tag show. drain x KeepUp / Refill: with Refill 1, the max Oxygen
    that gives KeepUp seconds on that fish."""
    o = cfg["Oxygen"]
    return math.ceil(drain(cfg, land, tier) * o["KeepUp"] / max(o["Refill"], 0.01))


def holds(cfg, land, tier, max_oxygen):
    """Whether this max Oxygen is at least the number on that fish's tag (Config.required)."""
    return max_oxygen >= required(cfg, land, tier)


def strained(cfg, land, tier, max_oxygen):
    """Config.strained: a fish that needs more than your max Oxygen is too strong for you. Landing on it empties the
    whole meter in Oxygen.StrainTime seconds, whatever the fish. StrainTime 0 turns the rule off."""
    return cfg["Oxygen"].get("StrainTime", 0) > 0 and not holds(cfg, land, tier, max_oxygen)


def seconds_on(cfg, land, tier, max_oxygen):
    """Config.secondsOn: how long a full meter lasts on that fish."""
    if strained(cfg, land, tier, max_oxygen):
        return cfg["Oxygen"]["StrainTime"]
    return max_oxygen / drain(cfg, land, tier)


def held_share(cfg, mix, land, max_oxygen):
    """The share of a land's fish that this max Oxygen holds."""
    return sum(share for t, share in mix.items() if holds(cfg, land, t, max_oxygen))


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


def commonest(cfg, mix):
    """The rarity most of a land's fish are (the commoner of two that tie)."""
    if not mix:
        return "Common"
    return max(mix, key=lambda t: (mix[t], -tier_step(cfg, t)))


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


def stand_time(cfg, have, want):
    """Seconds standing on the training spot to take max Oxygen from `have` to `want`: Train.Rate a second, plus
    Train.Share of your max a second (--set Train.Share=0 for the steady rate alone)."""
    rate, share = cfg["Train"].get("Rate", 0), cfg["Train"].get("Share", 0)
    if want <= have:
        return 0.0
    if share > 0:
        return math.log((want + rate / share) / (have + rate / share)) / share
    return (want - have) / rate if rate > 0 else float("inf")


def clock(seconds):
    if seconds == float("inf"):
        return "never"
    if seconds < 120:
        return f"{seconds:.0f} s"
    if seconds < 7200:
        return f"{seconds / 60:.0f} min"
    if seconds < 172800:
        return f"{seconds / 3600:.0f} h"
    return f"{seconds / 86400:.0f} days"


def hop(cfg, speed, air=None):
    """The hop off a fish ridden at `speed`: its top speed, the glide's, how far it carries you in `air` seconds (by
    default until the pull-in begins by itself, Jump.LaunchTime + FloatTime after the press), and that time."""
    j = cfg["Jump"]
    pop = j["Launch"] * speed
    glide = j["AirShare"] * speed if j.get("AirShare", 0) > 0 else j["AirSpeed"]
    if air is None:
        air = j["LaunchTime"] + j["FloatTime"]
    far, t, dt = 0.0, 0.0, 0.01
    while t < air - 1e-9:
        far += hop_speed(cfg, pop, glide, t + dt / 2) * min(dt, air - t)
        t += dt
    return pop, glide, far, air


def hop_speed(cfg, pop, glide, t):
    """The speed `t` seconds into a hop, as JumpController runs it: the pop holds for half of Jump.BoostTime, then
    eases to the glide by BoostTime + 0.3."""
    b = cfg["Jump"]["BoostTime"]
    lo, hi = b * 0.5, b + 0.3
    x = min(max((t - lo) / (hi - lo), 0), 1) if hi > lo else 1
    return pop + (glide - pop) * x * x * (3 - 2 * x)


def ride_distance(cfg, speed, seconds):
    """How far a fish carries you in `seconds` from the landing: it comes up from the herd's pace to its ridden speed
    over Ride.RampTime, with the burst on mount (Ease.rideSpeed)."""
    r, start = cfg["Ride"], speed * cfg["Herd"]["SpeedShare"]
    far, t, dt = 0.0, 0.0, 0.02
    while t < seconds:
        u = min(t / r["RampTime"], 1) if r["RampTime"] > 0 else 1
        base = start + (speed - start) * (1 - (1 - u) ** 2)
        lo, hi = r["SurgeTime"] * 0.6, r["SurgeTime"] * 1.4
        x = min(max((t - lo) / (hi - lo), 0), 1) if hi > lo else 1
        far += base * (1 + (r["Surge"] - 1) * (1 - x * x * (3 - 2 * x))) * min(dt, seconds - t)
        t += dt
    return far


def reel_time(cfg, gap):
    j = cfg["Jump"]
    return min(max(j["ReelTime"] + gap / j["GrabSpeed"], j["ReelMin"]), j["ReelMax"])


def hop_pace(cfg, speed, target_pace, sit, gap, air=None):
    """Studs a second, all told, of a rider who sits `sit` seconds on each fish, hops, and is pulled onto a fish `gap`
    studs ahead of where the glide ends (that fish swimming on at `target_pace`)."""
    _, _, far, air = hop(cfg, speed, air)
    reel = reel_time(cfg, gap)
    return (ride_distance(cfg, speed, sit) + far + gap + target_pace * reel) / (sit + air + reel)


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
            print("  ".join(c.rjust(w) if re.fullmatch(r"[-+x]?[\d,.]+[%sKMB]?", c) else c.ljust(w) for c, w in zip(row, widths)).rstrip())


def n(v, places=0):
    if v is None:
        return ""
    if abs(v) >= 1000:
        return f"{v:,.0f}"
    return f"{v:.{places}f}"


def big(v):
    """A big number the way a player would read it: 1,280 then 20K, 2.5M, 1.2B."""
    for cut, unit, mark in ((1e9, 1e9, "B"), (1e6, 1e6, "M"), (1e4, 1e3, "K")):
        if abs(v) >= cut:
            return f"{v / unit:.3g}{mark}"
    return f"{v:,.0f}"


def secs(v):
    """Seconds on a fish, as a rider would feel them."""
    if v >= 600:
        return f"{v / 60:.0f} min"
    if v >= 10:
        return f"{v:.0f}"
    if v >= 1:
        return f"{v:.1f}"
    return f"{v:.2f}"


def pct(share):
    if share <= 0:
        return ""
    return f"{share * 100:.1f}%" if share < 0.1 else f"{share * 100:.0f}%"


def tables(cfg, lane, out, your_max):
    order = cfg["TierOrder"]
    lands = len(lane["Start"])
    pool_list = pools(cfg, lands)
    mixes = [effective_mix(cfg, pool_list[z], z) for z in range(lands)]
    sl = slices(cfg, lane, pool_list)
    fish_in = [sum(s["Want"] for s in sl if s["Zone"] == z) for z in range(lands)]
    lengths = [lane["End"][z] - lane["Start"][z] for z in range(lands)]
    o, j = cfg["Oxygen"], cfg["Jump"]
    share = cfg["Herd"]["SpeedShare"]
    usual = [commonest(cfg, mixes[z]) for z in range(lands)]
    name = [f"{z + 1} {lane['Names'][z]}" for z in range(lands)]

    out.title("The lane", f"{lane['Length']:,.0f} studs to ride over {lands} lands ({lane['Source']}); "
              f"{sum(fish_in)} wild fish in all (Spawn.PerThousand {cfg['Spawn']['PerThousand']:g}, MaxTotal {cfg['Spawn']['MaxTotal']:g}). "
              f"\"Hopping\" is a rider on the land's commonest fish who sits {RIDE:g} s on each and hops to one about {LOCK_AHEAD} studs ahead.")
    head = ["Land", "Studs", "Width", "Fish", "Commonest fish", "s riding it", "s hopping"] + [f"s at {t} ({cfg['Tiers'][t]:g})" for t in order]
    rows = []
    total_hop = 0.0
    for z in range(lands):
        ws = [width_at(lane, lane["Start"][z] + lengths[z] * k / 20) for k in range(21)]
        v = cfg["Tiers"][usual[z]]
        pace = hop_pace(cfg, v, v * share, RIDE, LOCK_AHEAD)
        total_hop += lengths[z] / pace
        rows.append([name[z], n(lengths[z]), f"{min(ws):.0f} to {max(ws):.0f}", fish_in[z], usual[z], n(lengths[z] / v), n(lengths[z] / pace)]
                    + [n(lengths[z] / cfg["Tiers"][t]) for t in order])
    rows.append(["All ten", n(lane["Length"]), "", sum(fish_in), "", n(sum(lengths[z] / cfg["Tiers"][usual[z]] for z in range(lands))),
                 n(total_hop)] + [n(lane["Length"] / cfg["Tiers"][t]) for t in order])
    out.table(head, rows)

    refill = "the whole meter" if o["Refill"] >= 1 else f"{o['Refill']:g} of the meter"
    strain = o.get("StrainTime", 0)
    if strain > 0:
        rule = (f"\"Too strong\": the fish needs more max Oxygen than this (the number on its tag: {o['KeepUp']:g} s on it), so a "
                f"landing on it empties the whole meter in Oxygen.StrainTime {strain:g} s and throws you off. The hop's cooldown is "
                f"{j['Cooldown']:g} s, " + ("so it can't be hopped off." if strain < j["Cooldown"] else
                                            "SO IT CAN BE HOPPED OFF, and the next landing gives the whole meter back."))
    else:
        rule = (f"The game's \"enough\" is Oxygen.KeepUp {o['KeepUp']:g} s; under the hop's cooldown ({j['Cooldown']:g} s) you are "
                "thrown off before you can hop.")

    def cell(z, t, m):
        if t not in mixes[z]:
            return ""
        return "too strong" if strained(cfg, z, t, m) else secs(m / drain(cfg, z, t))

    out.title(f"Seconds on a fish with {your_max:,.0f} max Oxygen" + (" (a new player)" if your_max == o["StartMax"] else ""),
              f"Max Oxygen / (ZoneDrain x RarityDrain): how long a full meter lasts on a fish of that rarity, landed on in that land. "
              f"A landing on another fish gives back {refill}. Blank: that rarity doesn't spawn there. {rule} The last column: the "
              "share of the land's fish this player can hold.")
    head = ["Land", "Oxygen a second (Common)"] + order + ["Fish they can hold"]
    rows = []
    for z in range(lands):
        rows.append([name[z], big(drain(cfg, z, "Common"))] + [cell(z, t, your_max) for t in order]
                    + [pct(held_share(cfg, mixes[z], z, your_max)) or "none"])
    out.table(head, rows)

    out.title("The bar: the max Oxygen that holds a fish", f"Config.required, the number on a fish's tag: {o['KeepUp']:g} s on it, by "
              "the land you land on it in. In brackets: the share of the land's fish you hold with exactly that much (that rarity "
              "and every commoner one)." + (" With less, the fish is too strong for you; with it, the fish can be tamed." if strain > 0 else ""))
    head = ["Land"] + order
    rows = []
    for z in range(lands):
        rows.append([name[z]] + [f"{big(required(cfg, z, t))} ({pct(held_share(cfg, mixes[z], z, required(cfg, z, t)))})"
                                 if t in mixes[z] else "" for t in order])
    out.table(head, rows)

    cheapest = [min(mixes[z], key=lambda t: tier_mult(cfg, t)) if mixes[z] else "Common" for z in range(lands)]
    out.title("What max Oxygen means, land by land", f"\"The door\": the max Oxygen that holds the land's cheapest fish, and the share "
              f"of its fish that is. \"Holds its commonest\": the number on the commonest fish's tag ({o['KeepUp']:g} s on it). "
              f"\"At home\": {HOME:g} s on the commonest fish (a new player's time on a Shallows Common; a guess), and the share of the "
              "land's fish held then. \"HUD\" is what the game shows as the land's need: the tag of a Common there. The last two: "
              "the max Oxygen that holds (and so tames) the land's Legendary and Mythic.")
    head = ["Land", "Commonest fish", "It takes /s", "The door", "Holds its commonest", f"At home ({HOME:g} s on it)",
            "x the land before", "Fish held at home", "HUD", "Its Legendary", "Its Mythic"]
    rows, home_max, last = [], [], None
    for z in range(lands):
        d = drain(cfg, z, usual[z])
        home_max.append(d * HOME)
        door = required(cfg, z, cheapest[z])
        rows.append([name[z], usual[z], big(d), f"{big(door)} ({cheapest[z]}, {pct(held_share(cfg, mixes[z], z, door))})",
                     big(required(cfg, z, usual[z])), big(d * HOME), f"x{d / last:.1f}" if last else "",
                     pct(held_share(cfg, mixes[z], z, d * HOME)), big(required(cfg, z)),
                     big(required(cfg, z, "Legendary")) if "Legendary" in mixes[z] else "",
                     big(required(cfg, z, "Mythic")) if "Mythic" in mixes[z] else ""])
        last = d
    out.table(head, rows)

    out.title("Seconds on a fish for a player at home in each land", f"A player whose max Oxygen gives {HOME:g} s on that land's commonest "
              "fish: their time on each rarity there, the share of the fish they hold in the land before and the land after, and "
              "their time on the fish they rode in on once it is over the next land's border (a fish you hold is not judged again "
              "at a border: it only costs the new land's drain).")
    head = ["At home in", "Max Oxygen"] + order + ["Held in the land before", "Held in the land after", "Over the border on their commonest (s)"]
    rows = []
    for z in range(lands):
        m = home_max[z]
        rows.append([name[z], big(m)] + [cell(z, t, m) for t in order]
                    + [pct(held_share(cfg, mixes[z - 1], z - 1, m)) if z else "",
                       (pct(held_share(cfg, mixes[z + 1], z + 1, m)) or "none") if z + 1 < lands else "",
                       secs(m / drain(cfg, z + 1, usual[z])) if z + 1 < lands else ""])
    out.table(head, rows)

    tm = cfg["Tame"]
    if tm and tm.get("On", 0) != 0:
        spare = o["KeepUp"] - tm["Time"]
        out.title("Taming: the rarest fish a player can make theirs, land by land", f"Tame.Time {tm['Time']:g} s on a fish you hold "
                  f"makes it yours, up to Tame.Carry {tm['Carry']:g} a dive; a fish too strong for you is never tamed. A fish right "
                  f"at your bar gives {o['KeepUp']:g} s, so the tame leaves {spare:g} s to hop off it"
                  + (" (none: it is tamed as you are thrown off, if at all)." if spare <= 0 else ".")
                  + " Each line is a player at home in a land; each cell the rarest rarity they hold in that land, and so can tame.")
        head = ["At home in", "Max Oxygen"] + [str(z + 1) for z in range(lands)]
        rows = []
        for z in range(lands):
            row = [name[z], big(home_max[z])]
            for y in range(lands):
                held = [t for t in order if t in mixes[y] and holds(cfg, y, t, home_max[z])]
                row.append(held[-1] if held else "none")
            rows.append(row)
        out.table(head, rows)

    out.title("By rarity", f"A wild fish swims at Herd.SpeedShare {share:g} of its ridden speed. The hop off a fish: the pop at Jump.Launch "
              f"{j['Launch']:g} times the ridden speed, the glide at AirShare {j.get('AirShare', 0):g} of it, and the pull-in begins "
              f"{j['LaunchTime'] + j['FloatTime']:g} s after the press.")
    cam = cfg["Camera"]
    head = ["Rarity", "Ridden", "Step up", "Wild (herd)", "Pop", "Glide", "Hop carries (studs)", "and gains on its own herd", "Drain x",
            "View widens (deg)", "Turn circle (studs across)", "Lands"]
    rows = []
    for i, t in enumerate(order):
        v = cfg["Tiers"][t]
        pop, glide, far, air = hop(cfg, v)
        fov = cam["SpeedFov"] * min(max((v - cam["SpeedFovFrom"]) / (cam["SpeedFovTo"] - cam["SpeedFovFrom"]), 0), 1)
        where = [str(z + 1) for z in range(lands) if t in mixes[z]]
        planned = [str(z + 1) for z in range(min(lands, len(cfg["ZoneMix"]))) if t in cfg["ZoneMix"][z]]
        rows.append([t, n(v), f"+{(v / cfg['Tiers'][order[i - 1]] - 1) * 100:.0f}%" if i else "", n(v * share, 1), n(pop), n(glide, 1), n(far),
                     n(far - v * share * air), f"{tier_mult(cfg, t):g}", n(fov, 1), n(2 * v / math.radians(cfg["Ride"]["YawRate"])),
                     (", ".join(where) or "nowhere") + ("" if where == planned else f" (the mix asks for {', '.join(planned) or 'none'})")])
    out.table(head, rows)

    out.title("A rider who hops all the time: the pace", f"Studs a second all told, sitting {RIDE:g} s on each fish. \"Near\": pulled onto "
              f"a fish {LOCK_AHEAD} studs ahead when the glide ends (what the lock gives); \"far\": 110 studs ahead (reach is Jump.GrabRange {j['GrabRange']:g}). "
              f"\"Space held\": {j['Cooldown']:g} s on each fish and a grab {j['MinFlight']:g} s into the hop, onto a fish 110 ahead. "
              "The target is a fish of the same rarity.")
    head = ["Riding", "Ridden speed", "Hopping, near", "Hopping, far", "x riding", "Space held, far", "x riding", "Share of the time on a fish"]
    rows = []
    paces = {}
    for t in order:
        v = cfg["Tiers"][t]
        near, far = hop_pace(cfg, v, v * share, RIDE, LOCK_AHEAD), hop_pace(cfg, v, v * share, RIDE, 110)
        mash = hop_pace(cfg, v, v * share, j["Cooldown"], 110, air=j["MinFlight"])
        paces[t] = (near, far)
        on = RIDE / (RIDE + j["LaunchTime"] + j["FloatTime"] + reel_time(cfg, LOCK_AHEAD))
        rows.append([t, n(v), n(near), n(far), f"x{far / v:.2f}", n(mash), f"x{mash / v:.2f}", f"{on * 100:.0f}%"])
    out.table(head, rows)

    out.title("The ladder for a hopping rider: closing speed", "Studs a second gained on a wild fish ahead. First number: hopping to "
              "near fish; second: to far ones. Negative: the wild fish pulls away, and can only be caught if it starts within reach "
              "or comes up from behind. (Only riding, never hopping: the ridden speed minus the wild pace, which is +1 or +2 on "
              "the next rarity up and negative beyond.)")
    head = ["Riding a \\ wild"] + order
    rows = []
    for t in order:
        rows.append([t] + [f"{paces[t][0] - cfg['Tiers'][u] * share:+.0f} / {paces[t][1] - cfg['Tiers'][u] * share:+.0f}" for u in order])
    out.table(head, rows)

    out.title("Wild fish by land and rarity", "The share each rarity really gets (a rarity with no creature in the land is skipped and "
              "the others share it out), and the fish of it standing in the land at once. \"1 in\" is how many crossings of the land "
              "it takes to have one of that rarity in it.")
    head = ["Land", "Fish"] + order
    rows = []
    for z in range(lands):
        asked = cfg["ZoneMix"][z] if z < len(cfg["ZoneMix"]) else {}
        row = [name[z], fish_in[z]]
        for t in order:
            if t in mixes[z]:
                count = mixes[z][t] * fish_in[z]
                row.append(f"{pct(mixes[z][t])}, {count:.1f}" + (f" (1 in {1 / count:.0f})" if count < 0.5 else ""))
            elif t in asked:
                row.append(f"asks {asked[t]:g}%: no creature")
            else:
                row.append("")
        rows.append(row)
    out.table(head, rows)

    out.title("Which creatures turn up", "By land: each creature that can spawn there and its share of all spawns in that land. "
              "A star marks a creature with no model in the place yet (it spawns as a placeholder body).")
    head = ["Land", "Creatures (share of the land's spawns)"]
    rows = []
    for z in range(lands):
        parts = []
        for t in order:
            if t not in mixes[z]:
                continue
            total = sum(w for _, w in pool_list[z][t])
            names = sorted(pool_list[z][t], key=lambda fw: -fw[1])
            parts.append(f"{t}: " + ", ".join(f"{f['Name']}{'' if f['Modelled'] else '*'} {pct(mixes[z][t] * w / total)}" for f, w in names))
        rows.append([name[z], "; ".join(parts) or "nothing can spawn here: the land stays empty"])
    out.table(head, rows)

    tr = cfg["Train"]
    spot = (f"Train.Rate {tr.get('Rate', 0):g} a second" + (f" plus Train.Share {tr['Share']:g} of your max a second" if tr.get("Share") else "")) if tr else "no training spot in Config"
    out.title("What training would have to give", f"The plan is a guess (PLAN_MINUTES in the model, --plan to change it): the minutes "
              f"of play at which a player should first be at home in each land ({HOME:g} s on its commonest fish). From it, the max "
              "Oxygen wanted by then and the gain a second of ALL play time between two lands that gets there. The last two columns are "
              f"the training spot as it is ({spot}): seconds standing on it from the land before, and from the start.")
    head = ["Land", "At home by (min)", "Max Oxygen then", "Gain over the stretch", "A second of play", "x the stretch before",
            "Standing, from the land before", "Standing, from the start"]
    rows, have, last_rate, last_t = [], o["StartMax"], None, 0
    for z in range(lands):
        need = home_max[z]
        t = PLAN_MINUTES[z] if z < len(PLAN_MINUTES) else PLAN_MINUTES[-1]
        gain = max(0, need - have)
        rate = gain / ((t - last_t) * 60) if t > last_t and gain > 0 else None
        rows.append([name[z], n(t), big(need), big(gain) if gain else "none", (big(rate) if rate >= 100 else n(rate, 1)) if rate else "",
                     f"x{rate / last_rate:.1f}" if rate and last_rate else "",
                     clock(stand_time(cfg, have, need)) if tr else "", clock(stand_time(cfg, o["StartMax"], need)) if tr else ""])
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


def dive(cfg, lane, rng, policy, sit, max_oxygen, props_every=0.0, dt=0.1, endless=False, air=None, react=None, screen=0.0,
         tame=False):
    """One dive. The rider sits `sit` seconds on each fish, or until LEAVE seconds are left on it, but never hops
    sooner than `react` seconds after landing (on a fish that gives less, they are thrown off). They hop when a fish
    will be ahead and in reach, and are pulled onto one `air` seconds into the hop (by default when the glide ends).
    policy "lock": the fish the lock gives, nearest a point LOCK_AHEAD studs ahead; "rarest": the rarest in reach;
    "far": the furthest. `screen`: the rider only chooses fish that give at least this many seconds (Config.secondsOn:
    a fish too strong gives Oxygen.StrainTime), and waits on their fish for one. `tame`: they stay on a fish they hold
    until it is theirs (Tame.Time), while they have a slot free (Tame.Carry)."""
    o, j, sp = cfg["Oxygen"], cfg["Jump"], cfg["Spawn"]
    tm = cfg["Tame"]
    tame_on = bool(tm) and tm.get("On", 0) != 0 and not endless
    tame_len, carry = max(tm.get("Time", 0), 0.05), tm.get("Carry", 0)
    order = cfg["TierOrder"]
    herd = Herd(cfg, lane, rng)
    rider = {"s": 30.0, "x": 0.0}
    herd.top_up(10 ** 9, rider)
    free = [f for f in herd.fish if not f["ridden"] and f["tier"] == "Common"] or [f for f in herd.fish if not f["ridden"]]
    mount = min(free, key=lambda f: math.hypot(f["s"] - rider["s"], f["x"])) if free else None
    if not mount:
        return None
    mount["ridden"] = True
    start_s = mount["s"]
    rider["s"], rider["x"] = mount["s"], mount["x"]
    lands = len(lane["Start"])
    res = {"met": [dict.fromkeys(order, 0) for _ in range(lands)], "time": [0.0] * lands, "first": {}, "end": "the lane's end",
           "rode": dict.fromkeys(order, 0.0), "hops": 0, "props": 0, "caught": [], "tames": 0, "full_at": None}

    def ok(f, at_s=None):
        """Whether a rider who screens would choose this fish (judged by the land it will be in)."""
        if endless or screen <= 0:
            return True
        return seconds_on(cfg, land_at(lane, f["s"] if at_s is None else at_s), f["tier"], max_oxygen) >= screen

    # too strong for us? Judged once, at the mount, by the land the fish is in (RideService.mount)
    mount_land = land_at(lane, mount["s"])
    strain_now = not endless and strained(cfg, mount_land, mount["tier"], max_oxygen)
    tame_t, stayed = 0.0, False  # stayed: the rider stayed on this fish to make it theirs
    oxygen = max_oxygen
    t, since_top, since_hop, since_prop = 0.0, 0.0, 0.0, 0.0
    state, air_left, air_at = "ride", 0.0, 0.0
    left, pop, glide = None, 0.0, 0.0
    reach = j["GrabRange"]
    grab_at = j["LaunchTime"] + j["FloatTime"] if air is None else air

    def gap(f):
        return math.hypot(f["s"] - rider["s"], f["x"] - rider["x"])

    while rider["s"] < lane["Length"] - 5 and t < 3600:
        z = land_at(lane, rider["s"])
        res["time"][z] += dt
        herd.step(dt)
        if state == "ride":
            v = ridden(cfg, mount["kind"])
            # the fish comes up from the herd's pace to its ridden speed over Ride.RampTime
            ramp = min(since_hop / cfg["Ride"]["RampTime"], 1) if cfg["Ride"]["RampTime"] > 0 else 1
            now = v * herd.share + (v - v * herd.share) * (1 - (1 - ramp) ** 2)
            rider["s"] += now * dt
            mount["s"], rider["x"] = rider["s"], mount["x"]
            res["rode"][mount["tier"]] += dt
            cost = drain(cfg, z, mount["tier"])
            if strain_now:
                cost = max_oxygen / o["StrainTime"]  # the whole meter in StrainTime, whatever the fish
            if not endless:
                oxygen -= cost * dt
                if props_every > 0:
                    since_prop += dt
                    if since_prop >= props_every:
                        since_prop = 0.0
                        res["props"] += 1
                        oxygen = max(min(oxygen, cfg["Crash"]["Floor"]), oxygen - max_oxygen * cfg["Props"]["Cost"])
                # the game's order: the drain, then the tame, then the throw (a tame that fills on the last tick counts)
                if tame_on and not strain_now and not mount.get("tamed"):
                    tame_t += dt
                    if tame_t >= tame_len - 1e-9:
                        mount["tamed"] = True
                        res["tames"] += 1
                        if len(res["caught"]) < carry:
                            res["caught"].append(mount["tier"])
                            if len(res["caught"]) >= carry:
                                res["full_at"] = t
                if oxygen <= 0:
                    # thrown off: a fish too strong, a fish ridden on over a border, a fish that never gave time to hop,
                    # or a fish that did and no other (that the rider would choose) came in reach
                    short = max_oxygen / cost < max(j["Cooldown"], react or 0) + 0.05
                    if strain_now:
                        res["end"] = "landed on a fish too strong for them"
                    elif stayed and mount.get("tamed") and z == mount_land:
                        res["end"] = "thrown off the fish they had just made theirs"
                    elif z != mount_land:
                        res["end"] = "rode over the next land's border and ran out there"
                    elif short:
                        res["end"] = "thrown off a fish that gave no time to hop"
                    else:
                        res["end"] = "no fish in reach before the time ran out"
                    break
            since_hop += dt
            pop, glide, far, _ = hop(cfg, v, grab_at)
            # a rider looks before hopping (the lock shows while riding): they go when their time is up, or their Oxygen
            # nearly is, and a fish will be ahead and in reach when the pull-in can begin; until then they ride on
            due = since_hop >= sit or (not endless and oxygen <= cost * LEAVE)
            if tame and tame_on and not strain_now and not mount.get("tamed") and len(res["caught"]) < carry:
                due, stayed = False, True  # staying on until it is theirs
            if due and since_hop >= max(j["Cooldown"], react or 0) and any(
                    not f["parked"] and f is not mount and -5 <= f["s"] + f["speed"] * grab_at - rider["s"] - far <= reach
                    and math.hypot(f["s"] + f["speed"] * grab_at - rider["s"] - far, f["x"] - rider["x"]) <= reach * 0.9
                    and ok(f, f["s"] + f["speed"] * grab_at)
                    for f in herd.fish):
                state, air_left, air_at, since_hop = "air", j["Window"], 0.0, 0.0
                mount["ridden"] = False
                left, mount = mount, None
        else:
            # the hop: the pop easing to the glide; the pull-in begins `grab_at` seconds in if a fish is in reach
            rider["s"] += hop_speed(cfg, pop, glide, air_at + dt / 2) * dt
            air_at += dt
            air_left -= dt
            if air_at >= grab_at:
                options = [f for f in herd.fish if not f["parked"] and f is not left and f["s"] >= rider["s"] - 5 and gap(f) <= reach]
                if options:
                    fits = [f for f in options if ok(f)] or options
                    if policy == "rarest":
                        target = min(fits, key=lambda f: (-order.index(f["tier"]), gap(f)))
                    elif policy == "far":
                        target = max(fits, key=lambda f: f["s"])
                    else:
                        target = min(fits, key=lambda f: abs(f["s"] - rider["s"] - LOCK_AHEAD) + abs(f["x"] - rider["x"]))
                    reel = reel_time(cfg, gap(target))
                    herd.step(reel)
                    t += reel
                    res["time"][z] += reel
                    mount, state = target, "ride"
                    mount["ridden"] = True
                    rider["s"], rider["x"] = mount["s"], mount["x"]
                    res["hops"] += 1
                    oxygen = min(max_oxygen, oxygen + max_oxygen * o["Refill"])
                    mount_land = land_at(lane, mount["s"])
                    strain_now = not endless and strained(cfg, mount_land, mount["tier"], max_oxygen)
                    tame_t, stayed = (tame_len if mount.get("tamed") else 0.0), False
                elif air_left <= 0:
                    res["end"] = "missed every fish"
                    break
        # who is within reach now
        for f in herd.fish:
            if not f["seen"] and not f["parked"] and not f["ridden"] and abs(f["s"] - rider["s"]) <= reach and gap(f) <= reach:
                f["seen"] = True
                res["met"][z][f["tier"]] += 1
                res["first"].setdefault(f["tier"], t)
        t += dt
        since_top += dt
        if since_top >= sp["TopUpEvery"]:
            since_top = 0.0
            herd.top_up(int(sp["PerTopUp"]), rider)
    res["seconds"], res["reached"], res["s"] = t, land_at(lane, rider["s"]), rider["s"]
    res["pace"] = (rider["s"] - start_s) / t if t > 0 else 0
    return res


def sim(cfg, lane, out, runs, seed, your_max, dives_only=False):
    order = cfg["TierOrder"]
    lands = len(lane["Start"])
    o, j = cfg["Oxygen"], cfg["Jump"]
    riders = [] if dives_only else [
        (f"the fish the lock gives, {RIDE:g} s on each", "lock", RIDE, None),
        (f"rarest fish in reach, {RIDE:g} s on each", "rarest", RIDE, None),
        (f"furthest fish in reach, {RIDE:g} s on each", "far", RIDE, None)]
    for label, policy, sit, air in riders:
        rng = random.Random(seed)
        all_runs = [r for r in (dive(cfg, lane, rng, policy, sit, your_max, endless=True, air=air) for _ in range(runs)) if r]
        out.title(f"Played through the herd, endless air: {label}", f"{len(all_runs)} dives. Fish of each rarity that came within reach "
                  f"(Jump.GrabRange) a minute, by land; then the seconds into the dive at which the first of each rarity did.")
        head = ["Land", "Seconds in it"] + order + ["All"]
        rows = []
        for z in range(lands):
            total = sum(r["time"][z] for r in all_runs)
            if total <= 0:
                continue
            per = [sum(r["met"][z][t] for r in all_runs) / total * 60 for t in order]
            rows.append([f"{z + 1} {lane['Names'][z]}", n(total / len(all_runs))] + [n(v, 1) if v > 0 else "" for v in per] + [n(sum(per), 1)])
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
              + f". The dive took {sum(r['seconds'] for r in all_runs) / len(all_runs) / 60:.1f} minutes on average, at "
              + f"{sum(r['pace'] for r in all_runs) / len(all_runs):.0f} studs a second; ended: " + ", ".join(f"{k} {v}" for k, v in ends.items()) + ".")

    pool_list = pools(cfg, lands)
    usual = [commonest(cfg, effective_mix(cfg, pool_list[z], z)) for z in range(lands)]
    players = [("a new player", o["StartMax"], 0)] + [(f"at home in land {z + 1}", drain(cfg, z, usual[z]) * HOME, z) for z in (1, 2, 4)]
    if your_max != o["StartMax"]:
        players = [(f"{your_max:,.0f} max Oxygen", your_max, max(z for z in range(lands) if drain(cfg, z, usual[z]) * HOME <= your_max or z == 0))]
    strain = o.get("StrainTime", 0)
    tm = cfg["Tame"]
    reads = (f"only fish they can hold (the green tags), waiting on their fish for one" if strain > 0
             else f"only fish that give {TAGS:g} s or more, when one is in reach")
    out.title("How far a max Oxygen gets", f"Endless air off. Each line is a player and a way of riding. \"At ease\": on each fish "
              f"until {LEAVE:g} s are left ({RIDE:g} s at most), never hopping sooner than {REACT:g} s after a landing, onto the fish "
              f"the lock gives (about {LOCK_AHEAD} studs ahead). \"Reads the tags\": {reads}. \"And tames\": stays on each fish "
              f"they hold until it is theirs (Tame.Time {tm.get('Time', 0):g} s), while a slot is free (Tame.Carry {tm.get('Carry', 0):g}). "
              f"\"Space held\": a hop the moment the cooldown ends and a grab at once, only fish that give {MIN_SIT:g} s or more. "
              f"{runs} dives each. \"On a fish too strong\": dives that ended by landing on one, and how many of those were "
              "before the next land's door (in the lands the player can hold). \"Caught\": fish brought home a "
              "dive, and the rarest of them in any dive. \"Slots full\": dives that filled every slot, and the seconds into the dive "
              "when they did.")
    head = ["Player", "Max Oxygen", "Rider", "Lasts (s)", "Studs", "Ends in land", "On a fish too strong", "Hops landed",
            "Caught", "Slots full", "How it ended"]
    rows = []
    screen_tags = o["KeepUp"] if strain > 0 else TAGS
    ways = [("at ease", "lock", RIDE, None, REACT, 0.0, False), ("at ease, reads the tags", "lock", RIDE, None, REACT, screen_tags, False),
            ("reads the tags and tames", "lock", RIDE, None, REACT, screen_tags, True),
            ("Space held", "lock", j["Cooldown"], j["MinFlight"], None, MIN_SIT, False)]
    for who, max_oxygen, home in players:
        for label, policy, sit, air, react, screen, tame in ways:
            rng = random.Random(seed)
            rs = [r for r in (dive(cfg, lane, rng, policy, sit, max_oxygen, air=air, react=react, screen=screen, tame=tame)
                              for _ in range(runs)) if r]
            lands_hit = sorted(r["reached"] + 1 for r in rs)
            ends = {}
            for r in rs:
                ends[r["end"]] = ends.get(r["end"], 0) + 1
            caught = [t for r in rs for t in r["caught"]]
            best = max(caught, key=order.index) if caught else ""
            full = [r["full_at"] for r in rs if r["full_at"] is not None]
            rows.append([who, big(max_oxygen), label, n(sum(r["seconds"] for r in rs) / len(rs)), n(sum(r["s"] for r in rs) / len(rs)),
                         f"{lands_hit[0]} to {lands_hit[-1]}" if lands_hit[0] != lands_hit[-1] else lands_hit[0],
                         f"{sum(1 for r in rs if r['end'].startswith('landed on a fish too strong'))} of {len(rs)}, "
                         f"{sum(1 for r in rs if r['end'].startswith('landed on a fish too strong') and r['reached'] <= home)} before the door",
                         n(sum(r["hops"] for r in rs) / len(rs)),
                         f"{len(caught) / len(rs):.1f}" + (f" (to {best})" if best else ""),
                         f"{len(full)} of {len(rs)}" + (f", {sum(full) / len(full):.0f} s in" if full else ""),
                         ", ".join(f"{k} {v}" for k, v in sorted(ends.items(), key=lambda kv: -kv[1]))])
    out.table(head, rows)


def main():
    global PLAN_MINUTES, HOME, SCRAPE, RIDE
    p = argparse.ArgumentParser(description="Ride a Fish balance model")
    p.add_argument("--md", action="store_true", help="markdown tables")
    p.add_argument("--sim", type=int, default=0, metavar="N", help="play N dives per rider through the herd")
    p.add_argument("--dives", action="store_true", help="with --sim: only the \"How far a max Oxygen gets\" table")
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--set", action="append", default=[], metavar="Group.Key=value", help="try a number without editing Config")
    p.add_argument("--max", type=float, default=0, help="the max Oxygen the \"seconds on a fish\" table is for (default: Oxygen.StartMax)")
    p.add_argument("--home", type=float, default=HOME, help="seconds on a land's commonest fish that count as at home there")
    p.add_argument("--scrape", type=float, default=SCRAPE, help="seconds on it that just get you through")
    p.add_argument("--ride", type=float, default=RIDE, help="seconds a rider at ease sits on each fish")
    p.add_argument("--plan", default="", help="minutes of play by which a player should be at home in each land, ten numbers with commas")
    a = p.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    cfg = read_config()
    apply_sets(cfg, a.set)
    HOME, SCRAPE, RIDE = a.home, a.scrape, a.ride
    if a.plan:
        PLAN_MINUTES = [float(v) for v in a.plan.split(",")]
    lane = read_lane()
    out = Out(a.md)
    if a.set:
        print("With: " + ", ".join(a.set))
    your_max = a.max or cfg["Oxygen"]["StartMax"]
    if not (a.dives and a.sim > 0):
        tables(cfg, lane, out, your_max)
    if a.sim > 0:
        sim(cfg, lane, out, a.sim, a.seed, your_max, a.dives)


if __name__ == "__main__":
    main()
