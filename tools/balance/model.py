"""The balance model for Ride a Fish: what today's numbers mean for a dive, land by land, and what things should cost.

usage:  python tools/balance/model.py                  the tables (plain text)
        python tools/balance/model.py --md             the same tables as markdown, for docs/design/progression.md
        python tools/balance/model.py --sim 40         also play 40 dives per rider through the herd (some minutes)
        python tools/balance/model.py --sim 40 --dives only the dives' tables
        python tools/balance/model.py --prices         only the trainer, aura and tank tables
        python tools/balance/model.py --set Oxygen.StrainTime=0.25 --set RarityOxygen.Rare=3 --set ZoneMix.1.Rare=5
                                                       try numbers without editing Config (any of the above with it)
        python tools/balance/model.py --max 3000       the "seconds on a fish" table for a player with this max

Nothing is copied here: every number is read from src/shared/Config.luau, the creatures from
src/shared/Creatures/*.json (name, rarity, home land, size), and the lands' lengths from the map's path,
art/map/greybox/path.json (measured along the winding centreline, as the game does).

THE RULES IT KNOWS (rewritten 2026-11-16 for the game as it is that day)
  Oxygen      a fish needs its own whole number (OxygenBase x RarityOxygen x SizeOxygen x VariantOxygen, task e1);
              a land's row is the median of the kinds that live there. A Tank drains 0.65 of that.
              A landing on another fish gives back Oxygen.Refill of max (1: the whole meter), on a red fish too.
  The bar     a fish needs Config.requiredOf (its own: kind, rarity, size, colour; never the land). With less it is
              too strong (red): the whole meter empties in Oxygen.StrainTime (1 s since 2026-11-16) and it can be
              hopped off (Jump.StrainLock). It is never tamed.
  Taming      Tame.Time seconds on a fish you hold makes it yours, up to Tame.Carry a dive.
  The tank    the best Aquarium.Earning fish earn coins: what the fish needs x PerRequired (size and colour in it).
  Speed       every fish has its own ridden speed (Config.FishStats). A wild fish swims at a share of its LAND's
              pace (Config.LandPace x Herd.SpeedShare; plodders Pace.Plod, the fast ones Pace.Zoom; hunters at
              Pace.Hunt of their own speed, high over the herd).
  The hop     leaves at the fish's speed x Jump.Launch + HopBoost and runs down one curve to a stop (Config.hopKept);
              the locked fish pulls you in by itself from the glide's end (LaunchTime + FloatTime + the air a fast
              fish adds), within a reach that shrinks with your speed (GrabNear to GrabRange).
  The herd    Spawn.PerThousand fish to 1,000 studs, fewer where the water is narrow; no fish made or taken away
              within Spawn.SightClear of the rider; three layers by height (Config.Layer).

What the dives leave out: walls, props, the lock's cone before the last chance, predators eating, other players and
lag. The rider turns each hop toward a fish (up to STEER degrees off the lane) and otherwise rides straight, easing
back toward the middle of the herd. A hop that finds no other fish is pulled back onto the fish it left when that is
still in reach (the lock's last chance), with no Oxygen back. They never press late unless told to (`late`: the
chance of being too slow off a red fish). A model, not a measurement.
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

# Guesses, not decisions (change with --home, --ride, --sit, --plan).
HOME = 2.5  # seconds on a land's commonest fish that count as being at home there (a new player's on a Shallows Common)
RIDE = 1.8  # seconds a rider at ease spends on a fish they hold before hopping
REACT = 0.7  # a rider at ease can't hop sooner than this after landing
LEAVE = 0.7  # and hops when this many seconds are left on the fish, if that comes first
ANGRY_KEEP = 0.65  # the share of its speed an angry fish keeps at its worst: about the middle of Shared/AngryStyles
STEER = 45  # degrees either side of straight down the lane that a rider turns a hop toward a fish
DRIFT = 12  # studs a second a rider at ease lets their fish come back toward the middle of the herd's band
SIT_SHARE = 0.35  # the share of play time spent sitting on the trainer (the prices' biggest guess)
TANK_LUCK = 1.3  # a tank's sizes and colours, times: seven fish picked from a few dozen catches earn about this much more
PLAN_MINUTES = [0, 5, 15, 30, 55, 90, 150, 240, 360, 540]  # minutes of play to be at home in each land (the old plan)
AURAS = [(4, 1.5), (6, 2), (8, 2.5), (10, 3)]  # the aura a player on the plan has from this land on, and what it multiplies (the reference's four)
TRAINER_SHARE = 1.15  # a trainer level costs this many times what the tank earns over the stretch before the one it is for (set so the play-through lands on the plan)
AURA_SHARE = 0.25  # an aura costs this share of it, and the level bought with it that much less
TANK_FILL = 120  # seconds of play before a new player's tank has its seven fish


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
    if not text or not re.fullmatch(r"[-\d.\s/*+()]+", text):
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


def pairs_in(body):
    """`Key = 1.5` pairs anywhere in a flat table, on one line or many."""
    out = {}
    for key, value in re.findall(r"(\w+)\s*=\s*([-\d.\s/*]+?)\s*(?:,|$)", body, re.M):
        if number(value) is not None:
            out[key] = number(value)
    return out


def list_in(body):
    return [number(v) for v in body.split(",") if v.strip() and number(v) is not None]


def read_config():
    src = strip_comments(open(CONFIG, encoding="utf-8").read())
    cfg = {}
    cfg["TierOrder"] = re.findall(r'"(\w+)"', block(src, r"Config\.TierOrder\s*="))
    for group in ("Oxygen", "Spawn", "Herd", "Jump", "Ride", "Pace", "Speed", "Angry", "Grand"):
        cfg[group] = numbers_in(block(src, rf"Config\.{group}\s*="))
    for group in ("Train", "Tame", "Aquarium"):
        body = block(src, rf"Config\.{group}\s*=", must=False)
        cfg[group] = numbers_in(body) if body is not None else {}
    for group in ("RarityOxygen", "SizeOxygen", "VariantOxygen", "OxygenBase", "SizeChance", "SizeLarge", "SizeSmall",
                  "Variant", "BaseScale"):
        cfg[group] = pairs_in(block(src, rf"Config\.{group}\s*="))
    cfg["LandPace"] = list_in(block(src, r"Config\.LandPace\s*="))
    cfg["ReachWeight"] = list_in(block(src, r"Config\.ReachWeight\s*="))
    cfg["ZoneMix"] = []
    for row in re.findall(r"\{([^{}]*)\}", block(src, r"Config\.ZoneMix\s*=")):
        cfg["ZoneMix"].append({k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", row)})
    cfg["Layer"] = {k: (float(a), float(b)) for k, a, b in
                    re.findall(r"(\w+)\s*=\s*\{\s*([\d.]+)\s*,\s*([\d.]+)\s*\}", block(src, r"Config\.Layer\s*="))}
    arch = block(src, r"Config\.Archetype\s*=")
    cfg["Arch"] = {name: numbers_in(block(arch, rf"\b{name}\s*=")) for name in ("Fast", "Predator", "Breaker", "Tank", "Leaper")}
    stats = {fid: (float(speed), [a for a in kinds.split(",") if a]) for fid, speed, kinds in
             re.findall(r'(\w+)\s*=\s*\{\s*Speed\s*=\s*([\d.]+)\s*,\s*Archetype\s*=\s*"([^"]*)"', block(src, r"Config\.FishStats\s*="))}
    pace = dict(re.findall(r'(\w+)\s*=\s*"(\w+)"', block(src, r"Config\.FishPace\s*=")))
    # the hand table only matters for a fish's Reach now; the creature files bring name, rarity, land and size
    reach = {}
    for row in re.findall(r"\{\s*Id\s*=[^\n]*\}", block(src, r"local FISH[^=]*=")):
        m = re.search(r"\bReach\s*=\s*(\d+)", row)
        reach[re.search(r'Id\s*=\s*"(\w+)"', row).group(1)] = int(m.group(1)) if m else 2
    kept_out = set(re.findall(r"(\w+)\s*=\s*true", block(src, r"local NO_SPAWN[^=]*=", must=False) or ""))
    fish = []
    for path in sorted(glob.glob(os.path.join(CREATURES, "*.json"))):
        j = json.load(open(path, encoding="utf-8"))
        fid = os.path.splitext(os.path.basename(path))[0]
        if j.get("Tier") not in cfg["TierOrder"]:
            continue
        speed, kinds = stats.get(fid, (cfg["Speed"].get("Base", 45), []))
        scale = cfg["BaseScale"].get(fid, 1)
        fish.append({"Id": fid, "Name": j["Name"], "Tier": j["Tier"], "Home": int(j["Zone"]),
                     "Reach": -1 if fid in kept_out else reach.get(fid, 1 if j["Tier"] == "Common" else 2),
                     "Speed": speed, "Arch": kinds, "Pace": pace.get(fid, "Cruise"), "Length": j["Size"][2] * scale,
                     "Listed": fid in stats})
    cfg["Fish"] = fish
    return cfg


def apply_sets(cfg, sets):
    for item in sets:
        path, _, value = item.partition("=")
        keys, v = path.split("."), float(value)
        if keys[0] in ("LandPace", "ReachWeight") and len(keys) == 2:
            cfg[keys[0]][int(keys[1]) - 1] = v
        elif keys[0] == "ZoneMix" and len(keys) == 3:
            cfg["ZoneMix"][int(keys[1]) - 1][keys[2]] = v
        elif keys[0] == "Fish" and len(keys) == 3:  # Fish.ReefShark.Speed=80
            next(f for f in cfg["Fish"] if f["Id"] == keys[1])[keys[2]] = v
        elif keys[0] == "Arch" and len(keys) == 3:  # Arch.Tank.Drain=0.8
            cfg["Arch"][keys[1]][keys[2]] = v
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
                "W": [200, 200], "Source": "no path.json: 30,163 studs shared out by the map's plan"}
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
            "Length": true[-1], "S": true, "W": [p[4] for p in pts], "Source": os.path.relpath(PATH, ROOT).replace("\\", "/")}


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


def band_at(cfg, lane, s):
    """The herd's band: the open water inside Herd.EdgeGap, times Spawn.LaneFill, never wider than Spawn.BandMax."""
    sp = cfg["Spawn"]
    return max(20.0, min((width_at(lane, s) - 2 * cfg["Herd"].get("EdgeGap", 0)) * sp.get("LaneFill", 1), sp.get("BandMax", 400)))


# ---------------------------------------------------------------- the rules

def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def tier_step(cfg, tier):
    return cfg["TierOrder"].index(tier) if tier in cfg["TierOrder"] else 0


def need_of(cfg, fish, size="Normal", colour=""):
    """Config.requiredOf (task e1): what one fish needs, by its kind, rarity, size and colour; never by land."""
    need = (cfg["OxygenBase"].get(fish["Id"], 1) * cfg["RarityOxygen"].get(fish["Tier"], 1)
            * cfg["SizeOxygen"].get(size, 1) * (cfg["VariantOxygen"].get(colour, 1) if colour else 1))
    return max(1, math.ceil(need - 1e-6))


def required(cfg, land, tier="Common"):
    """A typical Normal plain fish of this rarity among the kinds that LIVE in land `land` (0-based): the median of
    their own needs (Config.requiredOf). Since task e1 the land costs nothing itself: this is only the tables' way to
    say what a land's own fish ask. A rarity the land has none of: the land's median base x that rarity."""
    own = sorted(need_of(cfg, f) for f in cfg["Fish"] if f["Home"] == land + 1 and f["Tier"] == tier)
    if own:
        return own[len(own) // 2]
    bases = sorted(cfg["OxygenBase"].get(f["Id"], 1) for f in cfg["Fish"] if f["Home"] == min(land + 1, 10))
    base = bases[len(bases) // 2] if bases else 80
    return max(1, math.ceil(base * cfg["RarityOxygen"].get(tier, 1) - 1e-6))


def drain(cfg, land, tier):
    """Oxygen a second that `required` stands for (the old Config.drain's place): need x Refill / KeepUp."""
    o = cfg["Oxygen"]
    return required(cfg, land, tier) * max(o["Refill"], 0.01) / max(o["KeepUp"], 0.01)


def drain_of(cfg, land, fish):
    """Config.drainOf: this fish's own drain: less on a Tank."""
    return drain(cfg, land, fish["Tier"]) * (cfg["Arch"]["Tank"].get("Drain", 1) if "Tank" in fish["Arch"] else 1)


def holds(cfg, land, tier, max_oxygen):
    return max_oxygen >= required(cfg, land, tier)


def strained(cfg, land, tier, max_oxygen):
    """Config.strained: too strong for you (red): the whole meter in Oxygen.StrainTime, whatever the fish."""
    return cfg["Oxygen"].get("StrainTime", 0) > 0 and not holds(cfg, land, tier, max_oxygen)


def held_share(cfg, mix, land, max_oxygen):
    return sum(share for t, share in mix.items() if holds(cfg, land, t, max_oxygen))


def pools(cfg, lands):
    """FishService's roster: for each land, by rarity, the fish that can turn up there with their weights."""
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
    """The land's mix as the spawner uses it: a rarity with no fish there is skipped and the rest share it out."""
    mix = cfg["ZoneMix"][z] if z < len(cfg["ZoneMix"]) else {}
    live = {t: share for t, share in mix.items() if t in pool}
    total = sum(live.values())
    return {t: share / total for t, share in live.items()} if total > 0 else {}


def commonest(cfg, mix):
    if not mix:
        return "Common"
    return max(mix, key=lambda t: (mix[t], -tier_step(cfg, t)))


def kinds_in(pool, mix):
    """Every creature that spawns in a land with its share of the land's spawns."""
    out = []
    for t, share in mix.items():
        total = sum(w for _, w in pool[t])
        out.extend((f, share * w / total) for f, w in pool[t])
    return out


def slices(cfg, lane, pool_list):
    """FishService's stretches: the lane cut into slices of Spawn.Slice studs, each with the fish it should hold: a
    land's fish (PerThousand, fewer where the band is narrow: FullBand, ThinLeast; Min to Max a land) shared out by
    how wide each slice is, and the whole sea never over MaxTotal."""
    sp, out, total = cfg["Spawn"], [], 0
    for z in range(len(lane["Start"])):
        s0, s1 = lane["Start"][z], lane["End"][z]
        length = s1 - s0
        if length > 1 and effective_mix(cfg, pool_list[z], z):
            n = max(1, math.floor(length / sp["Slice"] + 0.5))
            full = [clamp(band_at(cfg, lane, s0 + length * (k + 0.5) / n) / max(sp.get("FullBand", 1), 1),
                          clamp(sp.get("ThinLeast", 1), 0.05, 1), 1) for k in range(n)]
            want = max(n, min(max(math.floor(length / 1000 * sp["PerThousand"] * sum(full) / n), sp["Min"]), sp["Max"]))
            dealt = 0.0
            for k in range(n):
                before = dealt
                dealt += full[k] / sum(full)
                share = math.floor(want * dealt + 1e-6) - math.floor(want * before + 1e-6)
                out.append({"Start": s0 + length * k / n, "End": s0 + length * (k + 1) / n, "Zone": z, "Want": share})
                total += share
    while total > sp["MaxTotal"]:
        fullest = max((s for s in out if s["Want"] > 1), key=lambda s: s["Want"], default=None)
        if not fullest:
            break
        fullest["Want"] -= 1
        total -= 1
    return out


def wild_speed(cfg, fish, land_pace):
    """FishService: a wild fish swims at a share of its LAND's pace; a hunter at a share of its own speed."""
    p = cfg["Pace"]
    if fish["Pace"] == "Hunt":
        return fish["Speed"] * p.get("Hunt", 0.75)
    share = p["Plod"] if fish["Pace"] == "Plod" else p["Zoom"] if fish["Pace"] == "Zoom" else cfg["Herd"]["SpeedShare"]
    return land_pace * share


def size_odds(cfg, tier):
    """Config.rollSize: a spawned fish's size chances by its rarity."""
    c = cfg["SizeChance"]
    large, small = cfg["SizeLarge"].get(tier, 1), cfg["SizeSmall"].get(tier, 1)
    odds = {"Tiny": c.get("Tiny", 0) * small}
    for name in ("Big", "Giant", "Huge", "Colossal"):
        odds[name] = c.get(name, 0) * large
    odds["Normal"] = max(0.0, 1 - sum(odds.values()))
    return odds


def colour_odds(cfg):
    v = cfg["Variant"]
    odds = {"Rainbow": v.get("Rainbow", 0), "Gold": v.get("Gold", 0), "Silver": v.get("Silver", 0)}
    odds[""] = max(0.0, 1 - sum(odds.values()))
    return odds


def worth_mean(cfg, tier):
    """What a fish of this rarity earns, times, on average, for its size and colour."""
    a = cfg["Aquarium"]
    size = sum(p * cfg["SizeOxygen"].get(name, 1) for name, p in size_odds(cfg, tier).items())
    colour = sum(p * (cfg["VariantOxygen"].get(name, 1) if name else 1) for name, p in colour_odds(cfg).items())
    return size * colour


def best_seven(cfg, tier, catches, rng, tries=400):
    """The same, for the best Aquarium.Earning fish of `catches` of that rarity: what picking the tank is worth."""
    a = cfg["Aquarium"]
    sizes, colours = size_odds(cfg, tier), colour_odds(cfg)
    keep = int(a.get("Earning", 7))
    total = 0.0
    for _ in range(tries):
        worths = sorted((cfg["SizeOxygen"].get(rng.choices(list(sizes), list(sizes.values()))[0], 1)
                         * (cfg["VariantOxygen"].get(c, 1) if (c := rng.choices(list(colours), list(colours.values()))[0])
                            else 1)
                         for _ in range(catches)), reverse=True)
        total += sum(worths[:keep]) / min(keep, catches)
    return total / tries


def income_of(cfg, home, tier, worth=1.0):
    """Config.incomeOf: coins a second in the tank, for a fish at home in land `home` (0-based)."""
    return required(cfg, home, tier) * cfg["Aquarium"].get("PerRequired", 0) * worth


# ---------------------------------------------------------------- the hop

def air_of(cfg, speed):
    """Config.airOf: the seconds a fish's speed adds to (or takes off) the glide and the window."""
    j = cfg["Jump"]
    u = clamp((speed - j["AirSlowSpeed"]) / max(j["AirFastSpeed"] - j["AirSlowSpeed"], 1))
    return max(j["AirSlow"] + (j["AirFast"] - j["AirSlow"]) * u, j["AirLeast"] - j["FloatTime"])


def hop_from(cfg, had, fish):
    """Config.hopFrom: the hop's leaving speed, its extra seconds, and what Jump.Apex is times."""
    j = cfg["Jump"]
    launch = max(had * j["Launch"] + j["HopBoost"], j["AirShare"] * fish["Speed"] + j["BoostFloor"])
    leap = cfg["Arch"]["Leaper"] if "Leaper" in fish["Arch"] else {}
    return launch * leap.get("Air", 1), air_of(cfg, had) + leap.get("FloatTime", 0), leap.get("Apex", 1)


def hop_kept(cfg, t, extra):
    """Config.hopKept: the share of the leaving speed still there t seconds on."""
    j = cfg["Jump"]
    stop = max(j["StopTime"] + extra, 0.2)
    rest = clamp(j.get("StopShare", 0))
    u = max(t, 0) / stop
    if u >= 1:
        return rest
    tail = max(j["SpeedTail"], 1)
    half = clamp(j["SpeedHalf"] / max(j["StopTime"], 0.2), 0.05, 0.95)
    a = max(1, math.log(1 - 0.5 ** (1 / tail)) / math.log(half))
    return rest + (1 - rest) * (1 - u ** a) ** tail


def reach_of(cfg, speed):
    """Config.reachOf: the hook's reach at a speed across the water."""
    j = cfg["Jump"]
    near = min(j["GrabNear"], j["GrabRange"])
    return near + (j["GrabRange"] - near) * clamp(speed / max(j["GrabFullSpeed"], 1))


def hop_profile(cfg, had, fish, dt=0.05):
    """One hop off `fish` going `had`: when the glide ends (the pull-in can begin by itself), when the window ends,
    and for each dt the distance gone, the speed, the height over where it left, and the reach."""
    j = cfg["Jump"]
    launch, extra, apex = hop_from(cfg, had, fish)
    glide_end = j["LaunchTime"] + j["FloatTime"] + extra
    window = j["Window"] + extra
    steps = int(math.ceil(window / dt)) + 1
    dist, sink, rows = 0.0, 0.0, []
    rest = clamp(j.get("StopShare", 0))
    for i in range(steps + 1):
        t = i * dt
        kept = hop_kept(cfg, t, extra)
        speed = launch * kept
        rise = j["Apex"] * apex * (1 - (1 - clamp(t / max(j["LaunchTime"], 0.01))) ** 2)
        rise += j.get("FloatRise", 0) * clamp((t - j["LaunchTime"]) / max(glide_end - j["LaunchTime"], 0.1))
        rows.append((dist, speed, rise - sink, reach_of(cfg, speed)))
        gone = clamp((1 - kept) / (1 - rest)) if rest < 1 else 1
        dist += speed * dt
        sink += max(j["FallSpeed"], 0) * gone ** max(j["SinkCurve"], 0.1) * dt
    return {"launch": launch, "extra": extra, "glide": glide_end, "window": window, "rows": rows, "dt": dt}


def reel_time(cfg, gap):
    j = cfg["Jump"]
    return min(max(j["ReelTime"] + gap / j["GrabSpeed"], j["ReelMin"]), j["ReelMax"])


def stand_time(cfg, have, want):
    """Seconds on today's training pad to take max Oxygen from `have` to `want` (Train.Rate + Train.Share of max)."""
    rate, share = cfg["Train"].get("Rate", 0), cfg["Train"].get("Share", 0)
    if want <= have:
        return 0.0
    if share > 0:
        return math.log((want + rate / share) / (have + rate / share)) / share
    return (want - have) / rate if rate > 0 else float("inf")


# ---------------------------------------------------------------- printing

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
            print("  ".join(c.rjust(w) if re.fullmatch(r"[-+x$]?[\d,.]+[%sKMBT]?", c) else c.ljust(w) for c, w in zip(row, widths)).rstrip())

    def line(self, text):
        if self.md:
            print()
        print(text)


def n(v, places=0):
    if v is None:
        return ""
    if abs(v) >= 1000:
        return f"{v:,.0f}"
    return f"{v:.{places}f}"


def big(v):
    """A big number the way a player would read it: 1,280 then 20K, 2.5M, 1.2B."""
    for cut, unit, mark in ((1e12, 1e12, "T"), (1e9, 1e9, "B"), (1e6, 1e6, "M"), (1e4, 1e3, "K")):
        if abs(v) >= cut:
            return f"{v / unit:.3g}{mark}"
    return f"{v:,.0f}"


def nice(v, leads=(1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10)):
    """A price rounded to a number a sign can carry: 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8 times ten to something."""
    if v <= 0:
        return 0
    exp = math.floor(math.log10(v))
    lead = v / 10 ** exp
    pick = min(leads, key=lambda c: abs(math.log(c / lead)))
    return pick * 10 ** exp


def secs(v):
    if v >= 600:
        return f"{v / 60:.0f} min"
    if v >= 10:
        return f"{v:.0f}"
    if v >= 1:
        return f"{v:.1f}"
    return f"{v:.2f}"


def clock(seconds):
    if seconds == float("inf"):
        return "never"
    if seconds < 120:
        return f"{seconds:.0f} s"
    if seconds < 7200:
        return f"{seconds / 60:.0f} min"
    if seconds < 172800:
        return f"{seconds / 3600:.1f} h"
    return f"{seconds / 86400:.0f} days"


def pct(share):
    if share <= 0:
        return ""
    return f"{share * 100:.1f}%" if share < 0.1 else f"{share * 100:.0f}%"


# ---------------------------------------------------------------- the tables

def world(cfg, lane):
    lands = len(lane["Start"])
    pool_list = pools(cfg, lands)
    mixes = [effective_mix(cfg, pool_list[z], z) for z in range(lands)]
    usual = [commonest(cfg, mixes[z]) for z in range(lands)]
    return {"lands": lands, "pools": pool_list, "mixes": mixes, "usual": usual,
            "name": [f"{z + 1} {lane['Names'][z]}" for z in range(lands)],
            "home": [drain(cfg, z, usual[z]) * HOME for z in range(lands)]}


def tables(cfg, lane, out, your_max):
    order = cfg["TierOrder"]
    w = world(cfg, lane)
    lands, pool_list, mixes, usual, name, home_max = w["lands"], w["pools"], w["mixes"], w["usual"], w["name"], w["home"]
    sl = slices(cfg, lane, pool_list)
    fish_in = [sum(s["Want"] for s in sl if s["Zone"] == z) for z in range(lands)]
    lengths = [lane["End"][z] - lane["Start"][z] for z in range(lands)]
    o, j, p = cfg["Oxygen"], cfg["Jump"], cfg["Pace"]
    share = cfg["Herd"]["SpeedShare"]
    pace = [cfg["LandPace"][min(z, len(cfg["LandPace"]) - 1)] for z in range(lands)]

    unlisted = [f["Id"] for f in cfg["Fish"] if not f["Listed"]]
    out.title("The lane", f"{lane['Length']:,.0f} studs to ride over {lands} lands ({lane['Source']}); {sum(fish_in)} wild fish "
              f"in all (Spawn.PerThousand {cfg['Spawn']['PerThousand']:g}, fewer where the water is narrow; Max "
              f"{cfg['Spawn']['Max']:g} a land, MaxTotal {cfg['Spawn']['MaxTotal']:g}). The land's pace is Config.LandPace; "
              f"the herd swims at {share:g} of it, plodders at {p['Plod']:g}, the fast ones at {p['Zoom']:g}. \"Ridden\": the "
              "ridden speeds of the land's fish (Config.FishStats), weighted by how often each spawns, and the slowest and "
              "fastest of them." + (f" NOT IN FishStats (they ride at Speed.Base): {', '.join(unlisted)}." if unlisted else ""))
    head = ["Land", "Studs", "Width", "Fish", "To 1,000 studs", "Land pace", "The herd", "Plodders", "The fast", "Ridden, mean",
            "Ridden, range", "Mean over pace", "s to cross at the mean"]
    rows = []
    for z in range(lands):
        ws = [width_at(lane, lane["Start"][z] + lengths[z] * k / 20) for k in range(21)]
        kinds = kinds_in(pool_list[z], mixes[z])
        mean = sum(f["Speed"] * s for f, s in kinds) / max(sum(s for _, s in kinds), 1e-9)
        speeds = [f["Speed"] for f, _ in kinds] or [0]
        rows.append([name[z], n(lengths[z]), f"{min(ws):.0f} to {max(ws):.0f}", fish_in[z], n(fish_in[z] / lengths[z] * 1000, 1),
                     n(pace[z]), n(pace[z] * share, 1), n(pace[z] * p["Plod"], 1), n(pace[z] * p["Zoom"], 1), n(mean, 1),
                     f"{min(speeds):g} to {max(speeds):g}", f"x{mean / pace[z]:.2f}", n(lengths[z] / mean)])
    out.table(head, rows)

    refill = "the whole meter" if o["Refill"] >= 1 else f"{o['Refill']:g} of the meter"
    strain = o.get("StrainTime", 0)
    rule = (f"\"Red\": the fish needs more max Oxygen than this (the number on its tag: {o['KeepUp']:g} s on it), so a landing on "
            f"it empties the whole meter in Oxygen.StrainTime {strain:g} s. It can be hopped off after Jump.StrainLock "
            f"{j['StrainLock']:g} s, the next landing gives the meter back, and it is never tamed.") if strain > 0 else (
            f"The game's \"enough\" is Oxygen.KeepUp {o['KeepUp']:g} s.")

    def cell(z, t, m):
        if t not in mixes[z]:
            return ""
        return f"red, {strain:g}" if strained(cfg, z, t, m) else secs(m / drain(cfg, z, t))

    out.title(f"Seconds on a fish with {your_max:,.0f} max Oxygen" + (" (a new player)" if your_max == o["StartMax"] else ""),
              f"Max Oxygen over what the land's own fish need (median, task e1): how long a full meter lasts on a fish of that rarity, landed on in that "
              f"land. A landing on another fish gives back {refill}. Blank: that rarity doesn't spawn there. {rule} The last "
              "column: the share of the land's fish this player can hold.")
    head = ["Land", "Oxygen a second (Common)"] + order + ["Fish they can hold"]
    out.table(head, [[name[z], big(drain(cfg, z, "Common"))] + [cell(z, t, your_max) for t in order]
                     + [pct(held_share(cfg, mixes[z], z, your_max)) or "none"] for z in range(lands)])

    out.title("The bar: the max Oxygen that holds a fish", f"Config.required, the number on a fish's tag: {o['KeepUp']:g} s on it, "
              "by the land you land on it in. In brackets: the share of the land's fish you hold with exactly that much (that "
              "rarity and every commoner one). With it, the fish can be tamed; with less, it is red.")
    out.table(["Land"] + order, [[name[z]] + [f"{big(required(cfg, z, t))} ({pct(held_share(cfg, mixes[z], z, required(cfg, z, t)))})"
                                             if t in mixes[z] else "" for t in order] for z in range(lands)])

    cheapest = [min(mixes[z], key=lambda t: cfg["RarityOxygen"].get(t, 1)) if mixes[z] else "Common" for z in range(lands)]
    out.title("What max Oxygen means, land by land", f"\"The door\": the max Oxygen that holds the land's cheapest fish, and the "
              f"share of its fish that is. \"Holds its commonest\": the number on the commonest fish's tag. \"At home\": {HOME:g} s "
              "on the commonest fish (a guess), and the share of the land's fish held then, and of the next land's. The last two: "
              "the max Oxygen that holds (and so tames) the land's Legendary and Mythic.")
    head = ["Land", "Commonest fish", "It takes /s", "The door", "Holds its commonest", f"At home ({HOME:g} s on it)",
            "x the land before", "Held at home", "Held in the next land", "Its Legendary", "Its Mythic"]
    rows, last = [], None
    for z in range(lands):
        d = drain(cfg, z, usual[z])
        door = required(cfg, z, cheapest[z])
        rows.append([name[z], usual[z], big(d), f"{big(door)} ({cheapest[z]}, {pct(held_share(cfg, mixes[z], z, door))})",
                     big(required(cfg, z, usual[z])), big(d * HOME), f"x{d / last:.1f}" if last else "",
                     pct(held_share(cfg, mixes[z], z, d * HOME)),
                     (pct(held_share(cfg, mixes[z + 1], z + 1, d * HOME)) or "none") if z + 1 < lands else "",
                     big(required(cfg, z, "Legendary")) if "Legendary" in mixes[z] else "",
                     big(required(cfg, z, "Mythic")) if "Mythic" in mixes[z] else ""])
        last = d
    out.table(head, rows)

    tm = cfg["Tame"]
    if tm and tm.get("On", 0) != 0:
        out.title("Taming: the rarest fish a player can make theirs, land by land", f"Tame.Time {tm['Time']:g} s on a fish you hold "
                  f"makes it yours, up to Tame.Carry {tm['Carry']:g} a dive; a red fish is never tamed. Each line is a player at "
                  "home in a land; each cell the rarest rarity they hold in that land.")
        rows = []
        for z in range(lands):
            row = [name[z], big(home_max[z])]
            for y in range(lands):
                held = [t for t in order if t in mixes[y] and holds(cfg, y, t, home_max[z])]
                row.append(held[-1] if held else "none")
            rows.append(row)
        out.table(["At home in", "Max Oxygen"] + [str(z + 1) for z in range(lands)], rows)

    out.title("The hop today", f"Off a fish at its ridden speed: it leaves at speed x Jump.Launch {j['Launch']:g} + HopBoost "
              f"{j['HopBoost']:g}; the locked fish pulls you in by itself when the glide ends (LaunchTime {j['LaunchTime']:g} + "
              f"FloatTime {j['FloatTime']:g} + the air its speed adds); the window is Jump.Window {j['Window']:g} s + the same. The "
              f"reach runs from GrabRange {j['GrabRange']:g} at {j['GrabFullSpeed']:g} studs a second down to GrabNear "
              f"{j['GrabNear']:g}. \"Gains on the herd\": the studs it has made on a fish of the herd in a land of that pace when "
              f"the glide ends. The last line of each pair: the same fish angry (red, or the meter low), at {ANGRY_KEEP:g} of its speed.")
    head = ["Fish going", "Leaves at", "Glide ends (s)", "Studs by then", "Speed then", "Reach then", "Gains on the herd",
            "Window (s)", "Studs at the window's end", "Reach then"]
    rows = []
    plain = {"Speed": 0, "Arch": []}
    for v in (40, 46, 60, 82, 100, 116):
        for label, had in ((f"{v:g}", v), (f"{v:g}, angry", v * ANGRY_KEEP)):
            hp = hop_profile(cfg, had, dict(plain, Speed=v))
            at = hp["rows"][int(round(hp["glide"] / hp["dt"]))]
            end = hp["rows"][int(hp["window"] / hp["dt"])]
            rows.append([label, n(hp["launch"]), n(hp["glide"], 2), n(at[0]), n(at[1]), n(at[3]),
                         n(at[0] - v * share * hp["glide"]), n(hp["window"], 2), n(end[0]), n(end[3])])
    out.table(head, rows)

    out.title("Wild fish by land and rarity", "The share each rarity gets and the fish of it standing in the land at once.")
    rows = []
    for z in range(lands):
        row = [name[z], fish_in[z]]
        for t in order:
            count = mixes[z].get(t, 0) * fish_in[z]
            row.append(f"{pct(mixes[z][t])}, {count:.1f}" if t in mixes[z] else "")
        rows.append(row)
    out.table(["Land", "Fish"] + order, rows)

    out.title("Which characters swim where", "The share of each land's fish by how it swims wild (Config.FishPace): the herd "
              "(Cruise and Dart), plodders low and slow, the fast ones high, hunters over the herd; and the share that has an "
              "archetype (Config.FishStats).")
    head = ["Land", "The herd", "Plodders", "The fast", "Hunters", "Tank", "Predator", "Leaper", "Fast", "Breaker"]
    rows = []
    for z in range(lands):
        kinds = kinds_in(pool_list[z], mixes[z])
        by = lambda test: pct(sum(s for f, s in kinds if test(f))) or "0%"
        rows.append([name[z], by(lambda f: f["Pace"] in ("Cruise", "Dart")), by(lambda f: f["Pace"] == "Plod"),
                     by(lambda f: f["Pace"] == "Zoom"), by(lambda f: f["Pace"] == "Hunt")]
                    + [by(lambda f, a=a: a in f["Arch"]) for a in ("Tank", "Predator", "Leaper", "Fast", "Breaker")])
    out.table(head, rows)

    tr = cfg["Train"]
    if tr:
        out.title("The training pad as it is today", f"Train.Rate {tr.get('Rate', 0):g} a second plus Train.Share "
                  f"{tr.get('Share', 0):g} of your max a second while you stand on it. Seconds standing to be at home in each land.")
        rows, have = [], o["StartMax"]
        for z in range(lands):
            rows.append([name[z], big(home_max[z]), clock(stand_time(cfg, have, home_max[z])), clock(stand_time(cfg, o["StartMax"], home_max[z]))])
            have = max(have, home_max[z])
        out.table(["Land", "At home", "Standing, from the land before", "Standing, from the start"], rows)


# ---------------------------------------------------------------- prices: the trainer, auras and the tank

def tank_income(cfg, w, max_oxygen, luck=TANK_LUCK):
    """A plausible tank for a player with this max Oxygen: Aquarium.Earning fish of the dearest kind they hold that is
    at least a tenth of the fish of a land they are at home in (so it really is caught in numbers), times `luck` for
    sizes and colours. Returns coins a second and what the fish is."""
    best, what = 0, "nothing"
    for z in range(w["lands"]):
        if w["home"][z] > max_oxygen and z > 0:
            break
        for t, share in w["mixes"][z].items():
            if share >= 0.1 and holds(cfg, z, t, max_oxygen) and required(cfg, z, t) > best:
                best, what = required(cfg, z, t), f"{t}s of land {z + 1}"
    return cfg["Aquarium"].get("Earning", 7) * best * cfg["Aquarium"].get("PerRequired", 0) * luck, what


def prices(cfg, lane, out, plan, label, sit=SIT_SHARE):
    w = world(cfg, lane)
    lands, name = w["lands"], w["name"]
    o = cfg["Oxygen"]
    # the targets: at home in each land, and then one more, for the last land's Mythics
    goals = list(w["home"]) + [drain(cfg, lands - 1, "Mythic") * HOME]
    plan = list(plan) + [plan[-1] + (plan[-1] - plan[-2])]
    names = [f"{name[z]} to {lane['Names'][z + 1]}" for z in range(lands - 1)] + [f"{name[-1]} to its Mythics"]
    aura_at = dict(AURAS)
    aura, auras_now = 1.0, []
    for z in range(lands):
        aura = aura_at.get(z + 1, aura)
        auras_now.append(aura)
    out.title(f"The trainer and the auras: {label}", f"At home in each land by {', '.join(f'{m:g}' for m in plan[:lands])} minutes "
              f"of play. A player sits on the trainer for {sit * 100:.0f}% of that (the biggest guess here: every rate is in "
              "proportion to one over it). \"Needed, seated\": the Oxygen a seated second has to give over the stretch. "
              f"\"Aura\": the one a player on the plan has by then ({', '.join(f'x{m:g} from land {z}' for z, m in AURAS)}). "
              "\"The tank\": a plausible one for a player just at home in that land: seven of the dearest fish they hold in "
              f"numbers, times {TANK_LUCK:g} for sizes and colours. \"Coins over the stretch\": what it earns from one land to "
              f"the next, the max Oxygen rising in a straight line. A trainer level costs {TRAINER_SHARE * 100:.0f}% of the coins "
              f"of the stretch before the one it is for; where an aura comes with it, the aura costs {AURA_SHARE * 100:.0f}% "
              "and the level that much less. So each is bought as that stretch ends. Nothing is gated by land: the price is "
              "the gate.")
    head = ["Stretch", "Minutes", "Seated (min)", "Max Oxygen", "Needed, seated /s", "Trainer", "Its rate /s", "x the level before", "Aura",
            "Seated /s with it", "The tank at its start", "Coins /s then", "Coins over the stretch", "The level's price",
            "In minutes of the tank then", "The aura's price"]
    rows, earned_before, last_rate, levels = [], 0.0, None, []
    for z in range(lands):
        t0, t1 = plan[z], plan[z + 1]
        m0, m1 = goals[z], goals[z + 1]
        seated = (t1 - t0) * 60 * sit
        need = (m1 - m0) / seated
        rate = nice(need / auras_now[z], (1, 1.2, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7, 8, 10))
        income0, what = tank_income(cfg, w, m0)
        steps, coins = 200, 0.0
        for q in range(steps):
            at = (t0 + (t1 - t0) * (q + 0.5) / steps) * 60
            coins += tank_income(cfg, w, m0 + (m1 - m0) * (q + 0.5) / steps)[0] * min(at / TANK_FILL, 1) * (t1 - t0) * 60 / steps
        new_aura = z > 0 and auras_now[z] != auras_now[z - 1]
        price = nice(earned_before * (TRAINER_SHARE - (AURA_SHARE if new_aura else 0))) if z > 0 else 0
        aura_price = nice(earned_before * AURA_SHARE) if new_aura else None
        levels.append({"level": z + 1, "rate": rate, "price": price, "aura": auras_now[z] if new_aura else None, "aura_price": aura_price})
        show = lambda v: big(v) if v >= 100 else f"{v:.3g}"
        rows.append([names[z], f"{t0:g} to {t1:g}", n((t1 - t0) * sit, 1), f"{big(m0)} to {big(m1)}", show(need), f"Level {z + 1}",
                     show(rate), f"x{rate / last_rate:.1f}" if last_rate else "", f"x{auras_now[z]:g}", show(rate * auras_now[z]),
                     what, show(income0), big(coins), "free" if z == 0 else "$" + big(price),
                     n(price / income0 / 60, 1) if z > 0 and income0 > 0 else "", ("$" + big(aura_price)) if aura_price else ""])
        earned_before, last_rate = coins, rate
    out.table(head, rows)
    # does it add up: play it through, buying the cheapest thing not yet owned as soon as the coins are there
    m, coins, t, level, own_aura, reached, bought = o["StartMax"], 0.0, 0.0, 0, 1.0, {0: 0.0}, {}
    todo = sorted([(lv["price"], "level", lv["level"]) for lv in levels[1:]]
                  + [(lv["aura_price"], "aura", lv["aura"]) for lv in levels if lv["aura_price"]])
    step = 2.0
    while t < plan[-1] * 60 * 3 and len(reached) <= lands:
        while todo and coins >= todo[0][0]:
            cost, kind, value = todo.pop(0)
            coins -= cost
            if kind == "level":
                level = value - 1
                bought[value] = t
            else:
                own_aura = value
        m += levels[level]["rate"] * own_aura * sit * step
        coins += tank_income(cfg, w, m)[0] * min(t / TANK_FILL, 1) * step
        t += step
        for z in range(lands + 1):
            if z not in reached and m >= goals[z]:
                reached[z] = t
    out.line("Played through, buying the cheapest thing not yet owned as soon as the coins are there: at home in "
             + ", ".join(f"land {z + 1} at {reached[z] / 60:.0f} min" for z in range(1, lands) if z in reached)
             + (f"; its Mythics at {reached[lands] / 60:.0f} min" if lands in reached else "")
             + ". Level bought at (min): " + ", ".join(f"{lv} at {bought[lv] / 60:.0f}" for lv in sorted(bought)) + ".")
    return levels


# ---------------------------------------------------------------- the economy draft (task b1, 2026-11-19)
# Hugo, 2026-11-19: "seahorse oxygen generator, why does it go up in decimals? it should always give the same amount
# then be upgradeable ... seahorse always same oxygen amount only going up on upgrades or multipliers". A DRAFT: the
# numbers below are not in Config. Twelve seahorse levels, each a fixed whole number of Oxygen a tick (a tick is a
# second; no share of max), twelve auras with Hugo's multipliers, a fish's size and colour scaling both its need and
# its coins, taming slower the more a fish needs. docs/design/progression.md, "D. The economy, draft 1".

SEAHORSES = ["Pip", "Sprout", "Coral Colt", "Kelp Runner", "Wreck Racer", "Blue Charger", "Twilight Mare",
             "Midnight Steed", "Vent Stallion", "Bone Destrier", "Hellhorse", "Abyss King"]
AURA_LADDER = [("Bubble", 1.5), ("Foam", 2), ("Tide", 2.5), ("Current", 3), ("Reef", 3.5), ("Storm", 4), ("Moon", 5),
               ("Lantern", 6), ("Ember", 7), ("Phantom", 8), ("Abyss", 10), ("Leviathan", 12)]
# minutes of play by which a player can tame their land's commonest fish (lands 1 to 10)
PACES = {"A": ("Quick", [0, 2.5, 7.5, 15, 27.5, 45, 75, 120, 180, 270]),  # the 2026-11-16 "twice as fast"
         "B": ("Steady", [0, 5, 15, 30, 55, 90, 150, 240, 360, 540]),  # the 2026-11-16 "old plan"
         "C": ("Quick start, long tail", [0, 2.5, 7.5, 15, 30, 55, 90, 150, 240, 360])}
# what a colour multiplies a fish's NEED by (its coins are Aquarium.Silver/Gold/Rainbow either way)
COLOUR_NEED = {"A": {"Silver": 1.5, "Gold": 3, "Rainbow": 10}, "B": {"Silver": 1.25, "Gold": 2, "Rainbow": 4}}
ECON_LEVEL_SHARE = 0.85  # a level costs this share of what the tank earned over the stretch before the one it is for
ECON_AURA_SHARE = 0.3  # and the aura bought beside it this share
ECON_CATCHES = 30  # the tank's seven are the best of this many catches of its fish
WHOLE_LEADS = (1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10)


def whole(v):
    """A seahorse rate: a whole number, and a round one once it is big."""
    return max(1, round(v)) if v < 10 else int(nice(v, WHOLE_LEADS))


def econ_goals(cfg, w):
    """The max Oxygen each stretch ends at: tame the land's commonest fish (a Normal) in lands 2 to 10, then its
    Mythics, a Secret, and a Rainbow (or Colossal) Mythic. Returns (goals, what each is)."""
    lands = w["lands"]
    goals = [cfg["Oxygen"]["StartMax"]] + [required(cfg, z, w["usual"][z]) for z in range(1, lands)]
    plural = lambda t: t[:-1] + "ies" if t.endswith("y") else t + "s"
    what = ["the start"] + [f"{plural(w['usual'][z])} of land {z + 1}" for z in range(1, lands)]
    myth = required(cfg, lands - 1, "Mythic")
    goals += [myth, required(cfg, lands - 1, "Secret"), myth * 10]
    what += [f"Mythics of land {lands}", f"a Secret of land {lands}", "a Rainbow Mythic"]
    return goals, what


def econ_minutes(plan):
    """The minutes each goal is reached at on a plan of ten lands: the Mythics, the Secret and the trophy after."""
    gap = plan[-1] - plan[-2]
    return list(plan) + [plan[-1] + gap, plan[-1] + 2 * gap, plan[-1] + 3.5 * gap]


_LUCK = {}


def econ_luck(cfg, tier, headroom, need_col):
    """The mean coins-worth (size x colour) of the best Aquarium.Earning of ECON_CATCHES catches of a rarity, when
    only fish whose NEED (size x colour need) is at most `headroom` x the plain fish's can be tamed."""
    key = (tier, round(math.log(max(headroom, 1)), 1), tuple(sorted(need_col.items())))
    if key in _LUCK:
        return _LUCK[key]
    a, rng = cfg["Aquarium"], random.Random(11)
    sizes, colours = size_odds(cfg, tier), colour_odds(cfg)
    keep, total = int(a.get("Earning", 7)), 0.0
    room = math.exp(key[1])
    for _ in range(300):
        got = []
        for _ in range(ECON_CATCHES):
            s = rng.choices(list(sizes), list(sizes.values()))[0]
            c = rng.choices(list(colours), list(colours.values()))[0]
            sw = cfg["SizeOxygen"].get(s, 1)
            if sw * (need_col.get(c, 1) if c else 1) <= room * 1.0001:
                got.append(sw * (a.get(c, 1) if c else 1))
        got.sort(reverse=True)
        total += sum(got[:keep]) / keep
    _LUCK[key] = total / 300
    return _LUCK[key]


def econ_tank(cfg, w, max_oxygen, need_col):
    """Coins a second from a tank of the best seven of the dearest fish a player with this max can tame in numbers
    (a tenth of a land's fish or more), sizes and colours as they come and as far as the max allows."""
    best, tier = 0, "Common"
    for z in range(w["lands"]):
        for t, share in w["mixes"][z].items():
            r = required(cfg, z, t)
            if share >= 0.1 and r <= max_oxygen and r > best:
                best, tier = r, t
    if best == 0:
        return 0.0, best, tier
    luck = econ_luck(cfg, tier, max_oxygen / best, need_col)
    return cfg["Aquarium"].get("Earning", 7) * best * cfg["Aquarium"].get("PerRequired", 0) * luck, best, tier


def econ_ladder(cfg, w, plan, need_col, sit):
    """The seahorse levels and the auras for one pace: each level's rate is what a seated second must give over its
    stretch with the aura a player on the plan has then; each price a share of the tank's coins over the stretch
    before. Returns the stretches."""
    goals, what = econ_goals(cfg, w)
    mins = econ_minutes(plan)
    stretches, earned_before = [], 0.0
    for s in range(1, len(goals)):  # stretch s: goals[s-1] to goals[s], on level s with aura s-1
        t0, t1 = mins[s - 1], mins[s]
        aura = AURA_LADDER[s - 2][1] if s >= 2 else 1
        seated = (t1 - t0) * 60 * sit
        need = (goals[s] - goals[s - 1]) / seated
        rate = whole(need / aura)
        coins, steps = 0.0, 200
        for q in range(steps):
            at = (t0 + (t1 - t0) * (q + 0.5) / steps) * 60
            m = goals[s - 1] + (goals[s] - goals[s - 1]) * (q + 0.5) / steps
            coins += econ_tank(cfg, w, m, need_col)[0] * min(at / TANK_FILL, 1) * (t1 - t0) * 60 / steps
        income0 = econ_tank(cfg, w, goals[s - 1], need_col)[0]
        stretches.append({"s": s, "t0": t0, "t1": t1, "m0": goals[s - 1], "m1": goals[s], "what": what[s],
                          "seated": seated, "need": need, "rate": rate, "aura": aura,
                          "price": nice(earned_before * ECON_LEVEL_SHARE) if s >= 2 else 0,
                          "aura_price": nice(earned_before * ECON_AURA_SHARE) if s >= 2 else 0,
                          "coins": coins, "income0": income0})
        earned_before = coins
    # the last aura (x12) is the trophy: a share of the last stretch's coins
    stretches.append({"s": len(goals), "aura": AURA_LADDER[-1][1], "aura_price": nice(earned_before * ECON_AURA_SHARE)})
    return stretches


def econ_play(cfg, w, ladder, need_col, sit, step=2.0):
    """Play it through: buy the cheapest thing not yet owned as soon as the coins are there. Returns the minute each
    goal is reached and each thing bought."""
    goals, _ = econ_goals(cfg, w)
    levels = [st for st in ladder if "rate" in st]
    todo = sorted([(st["price"], "level", st["s"]) for st in levels[1:]]
                  + [(st["aura_price"], "aura", st["s"] - 1) for st in ladder if st["s"] >= 2])
    m, coins, t, level, aura = goals[0], 0.0, 0.0, 1, 1.0
    reached, bought, end = {0: 0.0}, {}, (ladder[-2]["t1"]) * 60 * 2.5
    while t < end and len(reached) < len(goals):
        while todo and coins >= todo[0][0]:
            cost, kind, value = todo.pop(0)
            coins -= cost
            if kind == "level":
                level = max(level, value)
            else:
                aura = max(aura, AURA_LADDER[value - 1][1])
            bought[(kind, value)] = t
        m += levels[level - 1]["rate"] * aura * sit * step
        coins += econ_tank(cfg, w, m, need_col)[0] * min(t / TANK_FILL, 1) * step
        t += step
        for g in range(len(goals)):
            if g not in reached and m >= goals[g]:
                reached[g] = t
    return reached, bought


def ride_at_need(cfg, req, grow=None, grow_most=None):
    """Seconds a full meter lasts on a fish for a rider with exactly its need (Config.secondsOn, `more` 1)."""
    o = cfg["Oxygen"]
    base = required(cfg, 0, "Common")
    g = min(max(req / base, 1) ** (grow or o["Grow"]), grow_most or o["GrowMost"])
    return o["KeepUp"] * g * o["RideTime"]


def tame_today(cfg, req, max_oxygen):
    o, t = cfg["Oxygen"], cfg["Tame"]
    base = required(cfg, 0, "Common")
    g = min(max(req / base, 1) ** o["Grow"], o["GrowMost"])
    return t["Time"] * g * (t.get("CapSlow", 1) if max_oxygen >= o["Cap"] > 0 else 1)


# Taming, two versions. Both: the tame is a share of the seconds on the fish for a rider with just its need, growing
# from a Shallows Common to an Underworld Mythic (by the log of the need), so a fish is always tameable at its need;
# Tame.CapSlow goes (it is folded into the curve).
TAME = {"A": {"share": (0.4, 0.85), "grow": None, "most": None},  # the rides as they are
        "B": {"share": (0.4, 0.65), "grow": 0.13, "most": 10}}  # Oxygen.Grow 0.13, GrowMost 10: deep rides longer


def tame_v(cfg, req, w, v):
    t = TAME[v]
    base, top = required(cfg, 0, "Common"), required(cfg, w["lands"] - 1, "Mythic")
    u = clamp(math.log(max(req, base) / base) / math.log(top / base))
    return (t["share"][0] + (t["share"][1] - t["share"][0]) * u) * ride_at_need(cfg, req, t["grow"], t["most"])


def economy(cfg, lane, out, sit=SIT_SHARE, colour="A"):
    """The economy draft's tables. Returns everything the sheet needs."""
    w = world(cfg, lane)
    lands, name, order = w["lands"], w["name"], cfg["TierOrder"]
    a = cfg["Aquarium"]
    need_col = COLOUR_NEED[colour]
    data = {"lands": lands, "name": name, "paces": {}}

    # 1. what a fish needs: its land and rarity (Config.required, today), times its size and colour
    out.title("D1. What a fish needs, by land and rarity (Config.required, as today)",
              "The number on a plain Normal fish's tag. A blank: the rarity does not swim there. The land's commonest "
              "rarity is in bold: taming it is what \"at home\" means here.")
    tiers = [t for t in order if any(t in w["mixes"][z] for z in range(lands))] + ["Secret"]
    rows = []
    for z in range(lands):
        row = [name[z]]
        for t in tiers:
            if t in w["mixes"][z] or (t == "Secret" and z == lands - 1):
                v = big(required(cfg, z, t))
                row.append(f"**{v}**" if (t == w["usual"][z] and out.md) else v)
            else:
                row.append("")
        rows.append(row)
    out.table(["Land"] + tiers, rows)
    data["need"] = {"tiers": tiers, "rows": rows}

    sizes = ["Tiny", "Normal", "Big", "Giant", "Huge", "Colossal"]
    out.title("D2. Size and colour: times the need and times the coins",
              "Sizes: Config.SizeOxygen as it is (0.8 to 3), now read for the need as well as the coins. Colours: the "
              "coins are Aquarium.Silver/Gold/Rainbow as they are; the need is version A (the same numbers) or B "
              "(gentler). A Gold Big fish needs 1.2 x the colour's number. Chances: a Common's.")
    so, co = size_odds(cfg, "Common"), colour_odds(cfg)
    rows = [[s, f"x{cfg['SizeOxygen'].get(s, 1):g}", f"x{cfg['SizeOxygen'].get(s, 1):g}", "", pct(so[s])] for s in sizes]
    for c in ("Silver", "Gold", "Rainbow"):
        rows.append([c, f"x{COLOUR_NEED['A'][c]:g} (A) / x{COLOUR_NEED['B'][c]:g} (B)", f"x{a.get(c, 1):g}", "", f"1 in {1 / co[c]:.0f}"])
    out.table(["Size or colour", "Need, times", "Coins, times", "", "Chance"], rows)
    ex = [("Shallows Common", 0, "Common"), ("Kelp Forest Rare", 2, "Rare"), ("Underworld Legendary", lands - 1, "Legendary")]
    rows = []
    for label, z, t in ex:
        r = required(cfg, z, t)
        rows.append([label] + [big(r * cfg["SizeOxygen"][s]) for s in sizes]
                    + [big(r * COLOUR_NEED["A"]["Gold"]), big(r * COLOUR_NEED["B"]["Gold"]),
                       big(r * COLOUR_NEED["A"]["Rainbow"] * cfg["SizeOxygen"]["Colossal"]),
                       big(r * COLOUR_NEED["B"]["Rainbow"] * cfg["SizeOxygen"]["Colossal"])])
    out.table(["Fish"] + sizes + ["Gold (A)", "Gold (B)", "Rainbow Colossal (A)", "Rainbow Colossal (B)"], rows)
    data["sizes"] = rows

    # 3. fish income: tag / 40
    per = a.get("PerRequired", 0)
    out.title("D3. What a fish earns: its tag x Aquarium.PerRequired (one fortieth of it a second)",
              f"Coins a second for one Normal plain fish of the land's commonest rarity, and for a tank of seven of "
              f"the best of {ECON_CATCHES} catches by a player who just tames them (sizes and colours as far as their "
              f"max allows; colour need {colour}). One coin a second for every {1 / per:g} Oxygen on the tag.")
    rows = []
    for z in range(lands):
        r = required(cfg, z, w["usual"][z])
        inc, _, _ = econ_tank(cfg, w, r if z else cfg["Oxygen"]["StartMax"], need_col)
        rows.append([name[z], w["usual"][z], big(r), n(r * per, 0 if r * per >= 10 else 1), big(inc), big(inc * 60)])
    out.table(["Land", "Commonest", "Its need", "One fish /s", "A tank of 7 /s", "A tank, a minute"], rows)
    data["income"] = rows

    # 4. the ladders and the play-through, per pace
    for key, (label, plan) in PACES.items():
        ladder = econ_ladder(cfg, w, plan, need_col, sit)
        reached, bought = econ_play(cfg, w, ladder, need_col, sit)
        data["paces"][key] = {"label": label, "plan": plan, "ladder": ladder, "reached": reached, "bought": bought}
        mins = econ_minutes(plan)
        out.title(f"D4{key}. Pace {key}, {label.lower()}: the seahorse and the auras",
                  f"Able to tame each land's commonest fish by {', '.join(f'{m:g}' for m in plan[1:])} minutes (lands 2 "
                  f"to 10), then its Mythics, a Secret and a Rainbow Mythic. Sitting on the seahorse {sit * 100:.0f}% "
                  "of the time. \"Per tick\": a tick is a second, a fixed whole number. \"With the aura\": the level x "
                  "the aura a player on this pace has then. A level costs "
                  f"{ECON_LEVEL_SHARE * 100:.0f}% of the tank's coins over the stretch before it, the aura bought beside "
                  f"it {ECON_AURA_SHARE * 100:.0f}%.")
        rows = []
        for st in ladder:
            if "rate" not in st:
                rows.append(["", "", "", "", "", "", f"{AURA_LADDER[-1][0]} x{AURA_LADDER[-1][1]:g}", "", "", "", "$" + big(st["aura_price"]), ""])
                continue
            s = st["s"]
            prev = ladder[s - 2]["rate"] if s >= 2 else None
            aname = f"{AURA_LADDER[s - 2][0]} x{st['aura']:g}" if s >= 2 else "none"
            rows.append([f"{s} {SEAHORSES[s - 1]}", f"{st['t0']:g} to {st['t1']:g}", f"{big(st['m0'])} to {big(st['m1'])}",
                         st["what"], f"{st['rate']:,}", f"x{st['rate'] / prev:.1f}" if prev else "", aname,
                         f"{st['rate'] * st['aura']:,.0f}", "free" if s == 1 else "$" + big(st["price"]),
                         n(st["price"] / st["income0"] / 60, 1) if s >= 2 and st["income0"] else "",
                         ("$" + big(st["aura_price"])) if s >= 2 else "",
                         f"{reached[s] / 60:.0f}" if s in reached else "later"])
        out.table(["Level", "Minutes", "Max Oxygen", "Then tames", "Per tick", "x before", "Aura with it", "With the aura /s",
                   "Level's price", "In minutes of the tank", "Aura's price", "Played through (min)"], rows)
        lv = [f"{v} at {t / 60:.0f}" for (k, v), t in sorted(bought.items(), key=lambda kv: kv[1]) if k == "level"]
        au = [f"x{AURA_LADDER[v - 1][1]:g} at {t / 60:.0f}" for (k, v), t in sorted(bought.items(), key=lambda kv: kv[1]) if k == "aura"]
        out.line(f"Played through (buying the cheapest thing not yet owned as soon as the coins are there): levels "
                 f"{', '.join(lv)}; auras {', '.join(au)} (minutes).")

    # 5. taming
    out.title("D5. Taming: seconds on a fish to make it yours",
              "Today: Tame.Time 2 x the ride's grow (at most 4, so 8 s), and 1.5 times that once your max is past "
              "500K (Tame.CapSlow). A and B: the tame is a growing share of the seconds on the fish for a rider with "
              f"just its need (Tame.CapSlow folded in): A {TAME['A']['share'][0]:g} on a Shallows Common to "
              f"{TAME['A']['share'][1]:g} on an Underworld Mythic, the rides as they are; B {TAME['B']['share'][0]:g} to "
              f"{TAME['B']['share'][1]:g}, with Oxygen.Grow {TAME['B']['grow']:g} and GrowMost {TAME['B']['most']} so "
              "deep rides are longer too. \"Ride\": seconds on the fish with just its need.")
    picks = [(0, "Common"), (1, "Uncommon"), (2, "Rare"), (3, "Rare"), (4, "Epic"), (5, "Epic"), (6, "Legendary"),
             (7, "Legendary"), (8, "Legendary"), (9, "Legendary"), (9, "Mythic")]
    rows = []
    for z, t in picks:
        r = required(cfg, z, t)
        rows.append([f"{name[z]} {t}", big(r), n(ride_at_need(cfg, r), 1), n(tame_today(cfg, r, r), 1),
                     n(tame_v(cfg, r, w, "A"), 1),
                     n(ride_at_need(cfg, r, TAME["B"]["grow"], TAME["B"]["most"]), 1), n(tame_v(cfg, r, w, "B"), 1)])
    out.table(["Fish", "Need", "Ride today", "Tame today", "Tame A", "Ride with B", "Tame B"], rows)
    data["tame"] = rows
    return data


def econ_sheet(data, path):
    """One page of the draft's tables, as a PNG (an HTML page shot by headless Chromium)."""
    import html
    import shutil
    import subprocess
    import tempfile

    def table(head, rows, cls=""):
        h = "".join(f"<th>{html.escape(str(c))}</th>" for c in head)
        b = "".join("<tr>" + "".join(f"<td>{html.escape(str(c)).replace('**', '')}</td>" for c in r) + "</tr>" for r in rows)
        return f"<table class='{cls}'><tr>{h}</tr>{b}</table>"

    rec = "C"
    blocks = []
    p = data["paces"][rec]
    rows = []
    for st in p["ladder"]:
        if "rate" not in st:
            continue
        s = st["s"]
        rows.append([f"{s}", SEAHORSES[s - 1], f"{st['rate']:,}", "free" if s == 1 else "$" + big(st["price"]),
                     f"{AURA_LADDER[s - 1][0]}", f"x{AURA_LADDER[s - 1][1]:g}",
                     "$" + big(p["ladder"][s]["aura_price"]), st["what"]])
    blocks.append(("Seahorse levels and auras (pace C, the pick)", table(
        ["Lvl", "Seahorse", "Oxygen a tick", "Price", "Aura", "x", "Aura price", "The level is for"], rows, "big")))
    paces = []
    for key, pp in data["paces"].items():
        mins = econ_minutes(pp["plan"])
        r = pp["reached"]
        paces.append([f"{key} {pp['label']}"] + [f"{mins[g]:g} / {r[g] / 60:.0f}" if g in r else f"{mins[g]:g} / -" for g in range(1, 11)])
    blocks.append(("The paces: minutes planned / played through, to tame each land's commonest fish (10 = Mythics)",
                   table(["Pace"] + [f"L{g + 1}" if g < 10 else "Myth" for g in range(1, 11)], paces)))
    for key in ("A", "B"):
        pp = data["paces"][key]
        rows = [[f"{st['s']}", f"{st['rate']:,}", "free" if st["s"] == 1 else "$" + big(st["price"]),
                 "$" + big(pp["ladder"][st["s"]]["aura_price"])] for st in pp["ladder"] if "rate" in st]
        blocks.append((f"Pace {key}, {pp['label'].lower()}", table(["Lvl", "Oxy/tick", "Price", "Aura price"], rows, "small")))
    blocks.append(("What a fish needs (Config.required, unchanged)", table(["Land"] + data["need"]["tiers"], data["need"]["rows"])))
    blocks.append(("Size and colour scale the need and the coins", table(
        ["Fish", "Tiny", "Normal", "Big", "Giant", "Huge", "Colossal", "Gold A", "Gold B", "Rbw Col. A", "Rbw Col. B"], data["sizes"])))
    blocks.append(("What a fish earns (tag / 40 a second)", table(
        ["Land", "Commonest", "Need", "1 fish /s", "Tank of 7 /s", "Tank /min"], data["income"])))
    blocks.append(("Taming, seconds on the fish (B, much slower deep down, is the pick)", table(
        ["Fish", "Need", "Ride", "Today", "A", "Ride B", "B"], data["tame"])))

    body = "".join(f"<div class='blk {'wide' if i < 2 else ''}'><h2>{html.escape(t)}</h2>{tb}</div>" for i, (t, tb) in enumerate(blocks))
    page = f"""<html><head><meta charset='utf-8'><style>
    body {{ margin:0; background:#0f1b33; font-family:'DejaVu Sans',sans-serif; color:#e8eefc; width:2000px; }}
    h1 {{ margin:0; padding:22px 30px 4px; font-size:34px; color:#ffd34d; }}
    .sub {{ padding:0 30px 14px; color:#a9bce6; font-size:16px; }}
    .grid {{ display:flex; flex-wrap:wrap; gap:16px; padding:0 30px 30px; }}
    .blk {{ background:#172748; border-radius:12px; padding:12px 16px; }}
    .blk.wide {{ flex:1 1 100%; }}
    h2 {{ font-size:18px; margin:2px 0 8px; color:#7fd3ff; }}
    table {{ border-collapse:collapse; font-size:14px; }}
    th {{ text-align:left; color:#ffd34d; padding:3px 9px; border-bottom:1px solid #2f4677; }}
    td {{ padding:3px 9px; border-bottom:1px solid #22355e; white-space:nowrap; }}
    table.big td {{ font-size:16px; }}
    </style></head><body><h1>Ride a Fish: the economy, draft 1 (2026-11-19)</h1>
    <div class='sub'>A draft for Hugo's pick: nothing here is in the game. The seahorse gives a fixed whole number of
    Oxygen every tick (a second); only a new level or an aura changes it. Auras multiply Oxygen gained (they replace
    each other). Size and colour scale a fish's need and its coins. Made by tools/balance/model.py --economy.</div>
    <div class='grid'>{body}</div></body></html>"""
    tmp = tempfile.mkdtemp()
    page_path = os.path.join(tmp, "sheet.html")
    open(page_path, "w", encoding="utf-8").write(page)
    browser = shutil.which("chromium") or shutil.which("chromium-browser") or shutil.which("google-chrome")
    if not browser:
        raise SystemExit("model.py: --sheet needs Chromium; the page is at " + page_path)
    subprocess.run([browser, "--headless", "--disable-gpu", "--hide-scrollbars", f"--screenshot={path}",
                    "--window-size=2000,1760", "file://" + page_path], check=True, capture_output=True)
    return page_path


# ---------------------------------------------------------------- the dive, played through the herd

class Herd:
    """The stocking, in one line along the lane with a place across it and a height: FishService as of 2026-11-16."""

    def __init__(self, cfg, lane, rng):
        self.cfg, self.lane, self.rng = cfg, lane, rng
        self.lands = len(lane["Start"])
        self.pools = pools(cfg, self.lands)
        self.mixes = [effective_mix(cfg, self.pools[z], z) for z in range(self.lands)]
        self.slices = slices(cfg, lane, self.pools)
        self.fish, self.near, self.grid = [], [], {}
        for i, sl in enumerate(self.slices):
            for _ in range(sl["Want"]):
                self.spawn(i)

    def pace(self, s):
        return self.cfg["LandPace"][min(land_at(self.lane, s), len(self.cfg["LandPace"]) - 1)]

    def pick(self, z):
        mix = self.mixes[z]
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

    def spawn(self, index, at_start=False):
        sl = self.slices[index]
        sp = self.cfg["Spawn"]
        kind = self.pick(sl["Zone"])
        room = sp.get("Space", 0)
        for _ in range(max(1, int(sp.get("Tries", 1)))):
            s = self.rng.uniform(0, sp.get("EntryAt", 30)) if at_start else self.rng.uniform(sl["Start"], sl["End"])
            x = self.rng.uniform(-0.5, 0.5) * band_at(self.cfg, self.lane, s)
            cell = int(s // 100)
            if all(math.hypot(g["s"] - s, g["x"] - x) >= room for c in (cell - 1, cell, cell + 1) for g in self.grid.get(c, ())):
                break
        lo, hi = self.cfg["Layer"].get(kind["Pace"], (14, 26))
        y = self.rng.uniform(lo, hi) + (self.cfg["Pace"].get("HuntHigh", 46) if kind["Pace"] == "Hunt" else 0)
        f = {"s": s, "x": x, "y": y, "kind": kind, "tier": kind["Tier"],
             "v": wild_speed(self.cfg, kind, self.pace(s)), "tamed": False}
        self.fish.append(f)
        self.grid.setdefault(int(s // 100), []).append(f)
        return f

    def refresh(self, rider_s, dt_since):
        """Every Spawn.TopUpEvery: the far fish swim on as numbers, the stock is put right out of sight, and the list of
        fish near the rider is made again."""
        sp = self.cfg["Spawn"]
        lane = self.lane
        live = [lane["Start"][z] - sp.get("LiveReach", 1500) <= rider_s <= lane["End"][z] + sp.get("LiveReach", 1500) for z in range(self.lands)]
        clear = sp.get("SightClear", 500)
        near_ids = {id(f) for f in self.near}
        count = [0] * len(self.slices)
        keep = []
        starts = [sl["Start"] for sl in self.slices]
        for f in self.fish:
            z = land_at(lane, f["s"])
            if id(f) not in near_ids and live[z]:
                f["s"] += f["v"] * dt_since
            if f["s"] >= lane["Length"]:
                continue
            z = land_at(lane, f["s"])
            f["v"] = wild_speed(self.cfg, f["kind"], self.pace(f["s"]))
            far = abs(f["s"] - rider_s) >= clear
            if far and live[z] and z + 1 > f["kind"]["Home"] + max(f["kind"]["Reach"], 0):
                continue  # swum out of its lands, out of sight
            lo, hi = 0, len(starts) - 1
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if starts[mid] <= f["s"]:
                    lo = mid
                else:
                    hi = mid - 1
            f["slice"] = lo
            count[lo] += 1
            keep.append(f)
        self.fish = keep
        self.grid = {}
        for f in keep:
            self.grid.setdefault(int(f["s"] // 100), []).append(f)
        span = int(sp.get("Window", 2))
        made = 0
        order = list(range(len(self.slices)))
        self.rng.shuffle(order)
        for i in order:
            sl = self.slices[i]
            if not live[sl["Zone"]]:
                continue
            a, b = max(0, i - span), min(len(self.slices), i + span + 1)
            have, want = sum(count[a:b]), sum(s["Want"] for s in self.slices[a:b])
            middle = (sl["Start"] + sl["End"]) / 2
            far = abs(middle - rider_s) >= clear + sp["Slice"] / 2
            if (have < want and count[i] < sl["Want"] and made < sp.get("PerTopUp", 6) and (far or i == 0)
                    and len(self.fish) < sp["MaxTotal"]):
                self.spawn(i, at_start=(i == 0 and not far))
                count[i] += 1
                made += 1
            elif far and have > want * (1 + sp.get("OverBy", 0.3)) and have - want >= 2 and count[i] > sl["Want"]:
                victim = next((f for f in self.fish if f.get("slice") == i and abs(f["s"] - rider_s) >= clear), None)
                if victim:
                    self.fish.remove(victim)
                    count[i] -= 1
        self.near = [f for f in self.fish if -700 <= f["s"] - rider_s <= 1400]

    def step(self, dt):
        for f in self.near:
            f["s"] += f["v"] * dt


def dive(cfg, lane, rng, max_oxygen, sit=RIDE, react=REACT, green=False, tame=False, mash=False, endless=False, dt=0.05,
         limit=1500.0, late=0.0, best=False):
    """One dive. The rider sits `sit` seconds on a fish they hold (or until LEAVE seconds are left), never hopping
    sooner than `react` after a landing; on a red fish they hop as soon as they can. They turn the hop toward a fish
    that will be in reach (up to STEER degrees off the lane). The pull-in takes a fish in reach from the glide's end
    (`mash`: from Jump.MinFlight, Space held). `green`: they choose a fish they hold when one is in reach, and take a
    red one only when the hop is about to run out. `tame`: they stay on a fish they hold until it is theirs. `best`:
    a full bag keeps the best Tame.Carry (not built: today a tame past them is not kept). `late`: the chance, on each
    red fish, that they are too slow and it throws them off. Oxygen.RedRefill (not in Config: try it with --set) is
    what a landing on a red fish gives back; without it, Oxygen.Refill."""
    o, j, sp, tm = cfg["Oxygen"], cfg["Jump"], cfg["Spawn"], cfg["Tame"]
    order = cfg["TierOrder"]
    herd = Herd(cfg, lane, rng)
    lands = herd.lands
    tame_on = bool(tm) and tm.get("On", 0) != 0 and not endless
    tame_len, carry = max(tm.get("Time", 0), 0.05), tm.get("Carry", 0)
    ramp = max(cfg["Ride"].get("RampTime", 0.4), 0.01)
    angry_at, angry_in = o.get("AngryAt", 0), max(cfg["Angry"].get("EaseIn", 0.5), 0.01)
    heat_from = cfg["Angry"].get("HeatFrom", 0.75)
    herd.refresh(30.0, 0.0)
    first = [f for f in herd.near if f["s"] < 250 and f["kind"]["Pace"] != "Hunt" and holds(cfg, 0, f["tier"], max_oxygen)] \
        or [f for f in herd.near if f["kind"]["Pace"] != "Hunt"]
    mount = min(first, key=lambda f: abs(f["s"] - 30))
    rider = {"s": mount["s"], "x": mount["x"], "y": mount["y"]}
    start_s = rider["s"]
    res = {"end": "the lane's end", "hops": 0, "red": 0, "caught": [], "earn": 0.0, "full_at": None, "time": [0.0] * lands,
           "first_red": None, "red_run": 0, "red_best": 0}
    oxygen = max_oxygen
    t, since_top, since_land, angry_t = 0.0, 0.0, 0.0, 0.0
    state = "ride"
    mount_land = land_at(lane, mount["s"])
    red = not endless and strained(cfg, mount_land, mount["tier"], max_oxygen)
    tame_t, stayed, from_v = 0.0, False, mount["v"]
    hp, air_t, left, speed_now = None, 0.0, None, mount["v"]
    turn_c, turn_s, slow = 1.0, 0.0, False
    steer = math.radians(STEER)
    red_refill = o.get("RedRefill", o["Refill"])
    profiles = {}
    worth = {tier: worth_mean(cfg, tier) for tier in order}

    def ok(f, at_s):
        return holds(cfg, land_at(lane, at_s), f["tier"], max_oxygen)

    def gap(f, rs, rx, ry, ahead=0.0):
        return math.sqrt((f["s"] + f["v"] * ahead - rs) ** 2 + (f["x"] - rx) ** 2 + (f["y"] - ry) ** 2)

    while rider["s"] < lane["Length"] - 5 and t < limit:
        z = land_at(lane, rider["s"])
        res["time"][z] += dt
        herd.step(dt)
        if state == "ride":
            kind = mount["kind"]
            v = kind["Speed"]
            cost = drain_of(cfg, z, kind)
            if red:
                # Oxygen.RedShrink / RedFloor (model only, the user's rule of 2026-11-22): each red landing in a row
                # gives RedShrink times the red time of the one before, never under RedFloor seconds
                strain = o["StrainTime"] * o.get("RedShrink", 1) ** max(res["red_run"] - 1, 0)
                cost = max_oxygen / max(strain, o.get("RedFloor", 0), 0.05)
            low = red or (not endless and oxygen <= max_oxygen * angry_at * (cfg["Arch"]["Tank"].get("AngryAt", 1) if "Tank" in kind["Arch"] else 1))
            angry_t = min(angry_t + dt, angry_in) if low else max(angry_t - dt, 0.0)
            heat = 1.0 if red else clamp(1 - oxygen / max(max_oxygen * angry_at, 1e-9))
            keep = 1 - (1 - ANGRY_KEEP) * (heat_from + (1 - heat_from) * heat) * (angry_t / angry_in) if angry_t > 0 else 1
            up = 1 - (1 - min(since_land / ramp, 1)) ** 2
            speed_now = (from_v + (v - from_v) * up) * keep
            rider["s"] += speed_now * dt
            mount["x"] -= max(-DRIFT * dt, min(DRIFT * dt, mount["x"]))
            mount["s"], rider["x"], rider["y"] = rider["s"], mount["x"], mount["y"]
            if not endless:
                oxygen -= cost * dt
                if tame_on and not red and not mount["tamed"]:
                    tame_t += dt
                    if tame_t >= tame_len - 1e-9:
                        mount["tamed"] = True
                        gain = income_of(cfg, kind["Home"] - 1, kind["Tier"], worth[kind["Tier"]])
                        if len(res["caught"]) < carry:
                            res["caught"].append((gain, mount["tier"]))
                            if len(res["caught"]) >= carry:
                                res["full_at"] = t
                        elif best and gain > min(res["caught"])[0]:
                            res["caught"].remove(min(res["caught"]))
                            res["caught"].append((gain, mount["tier"]))
                if oxygen <= 0:
                    res["end"] = ("too slow off a red fish" if red and slow else "ran out on a red fish" if red
                                  else "ran out on the fish just made theirs" if stayed and mount["tamed"]
                                  else "rode over the next land's border and ran out" if z != mount_land else "ran out waiting for a fish in reach")
                    break
            since_land += dt
            left_s = oxygen / cost if not endless else 99.0
            if red:
                due = not slow
            else:
                due = since_land >= sit or left_s <= LEAVE
                worth_it = (len(res["caught"]) < carry
                            or best and income_of(cfg, kind["Home"] - 1, kind["Tier"], worth[kind["Tier"]]) > min(res["caught"])[0])
                if tame and tame_on and not mount["tamed"] and worth_it and left_s > 0.12:
                    due, stayed = False, True
            lock = j.get("StrainLock", 0) if red else j.get("Cooldown", 0) / 2
            if due and since_land >= max(lock, react):
                key = (round(speed_now), kind["Id"])
                hp = profiles.get(key)
                if hp is None:
                    hp = profiles[key] = hop_profile(cfg, speed_now, kind, dt)
                # turn the hop toward a fish that will be in reach as the glide ends or in the drop (with Space held: at
                # once, the furthest); or go straight and blind, when the time is nearly up
                pick, pick_score = None, None
                times = (j.get("MinFlight", 0.15) + dt,) if mash else (hp["glide"], (hp["glide"] + hp["window"]) / 2)
                for at in times:
                    row = hp["rows"][int(at / dt)]
                    for f in herd.near:
                        if f is mount:
                            continue
                        ds, dx = f["s"] + f["v"] * at - rider["s"], f["x"] - rider["x"]
                        if ds <= 0:
                            continue
                        angle = math.atan2(dx, ds)
                        if abs(angle) > steer:
                            continue
                        flat = math.hypot(ds, dx) - row[0]
                        if math.sqrt(flat * flat + (f["y"] - rider["y"] - row[2]) ** 2) > row[3]:
                            continue
                        held = red or not green or ok(f, f["s"] + f["v"] * at)
                        score = (0 if held else 1, -ds if mash else abs(angle))
                        if pick_score is None or score < pick_score:
                            pick, pick_score = angle, score
                    if pick is not None and pick_score[0] == 0:
                        break
                go = pick is not None and (pick_score[0] == 0 or left_s <= 0.5)
                if not go and (left_s <= 0.2 or endless and since_land >= sit + 2):
                    go, pick = True, (pick or 0.0)
                if go:
                    state, air_t, left = "air", 0.0, mount
                    base_s, base_x, base_y = rider["s"], rider["x"], rider["y"]
                    turn_c, turn_s = math.cos(pick), math.sin(pick)
                    mount = None
        else:
            air_t += dt
            row = hp["rows"][min(int(air_t / dt), len(hp["rows"]) - 1)]
            rider["s"] = base_s + row[0] * turn_c
            rider["x"] = base_x + row[0] * turn_s
            rider["y"] = max(base_y + row[2], j.get("FloorClearance", 4))
            if air_t >= (j.get("MinFlight", 0.15) if mash else hp["glide"]):
                reach = row[3]
                cands = [f for f in herd.near if f is not left and gap(f, rider["s"], rider["x"], rider["y"]) <= reach]
                if green and not endless:
                    held = [f for f in cands if ok(f, f["s"])]
                    cands = held or (cands if air_t >= hp["window"] - 0.3 else [])
                back = False
                if not cands and not mash and gap(left, rider["s"], rider["x"], rider["y"]) <= reach and (
                        not green or endless or air_t >= hp["window"] - 0.3):
                    cands, back = [left], True
                if cands:
                    def aim(f):
                        ds = f["s"] - rider["s"]
                        off = math.atan2(math.hypot(f["x"] - rider["x"], f["y"] - rider["y"]), max(ds, 1.0))
                        return off + (math.pi if ds < -5 else 0)
                    target = cands[0] if back else min(cands, key=aim)
                    reel = reel_time(cfg, gap(target, rider["s"], rider["x"], rider["y"]))
                    herd.step(reel)
                    t += reel
                    res["time"][z] += reel
                    mount, state = target, "ride"
                    rider["s"], rider["x"], rider["y"] = mount["s"], mount["x"], mount["y"]
                    res["hops"] += 1
                    mount_land = land_at(lane, mount["s"])
                    red = not endless and strained(cfg, mount_land, mount["tier"], max_oxygen)
                    if back:
                        res["back"] = res.get("back", 0) + 1  # onto the fish we left: nothing back
                    else:
                        oxygen = min(max_oxygen, oxygen + max_oxygen * (red_refill if red else o["Refill"]))
                    slow = red and late > 0 and rng.random() < late
                    if red:
                        res["red"] += 1
                        res["red_run"] += 1
                        res["red_best"] = max(res["red_best"], res["red_run"])
                        if res["first_red"] is None:
                            res["first_red"] = (t, rider["s"])
                    else:
                        res["red_run"] = 0
                    tame_t, stayed = (tame_len if mount["tamed"] else 0.0), False
                    since_land, angry_t, from_v = 0.0, 0.0, mount["v"]
                elif air_t >= hp["window"]:
                    res["end"] = "missed every fish in a hop"
                    break
        t += dt
        since_top += dt
        if since_top >= sp["TopUpEvery"]:
            herd.refresh(rider["s"], since_top)
            since_top = 0.0
    res["earn"] = sum(g for g, _ in res["caught"])
    res["caught"] = [tier for _, tier in res["caught"]]
    res["seconds"], res["reached"], res["s"] = t, land_at(lane, rider["s"]), rider["s"]
    res["pace"] = (rider["s"] - start_s) / t if t > 0 else 0
    return res


def spread(values):
    v = sorted(values)
    return v[len(v) // 2], v[max(int(len(v) * 0.9) - 1, 0)], v[-1]


def ends_of(rs):
    ends = {}
    for r in rs:
        ends[r["end"]] = ends.get(r["end"], 0) + 1
    return ", ".join(f"{k} {v}" for k, v in sorted(ends.items(), key=lambda kv: -kv[1]))


def sim(cfg, lane, out, runs, seed):
    w = world(cfg, lane)
    lands, home = w["lands"], w["home"]
    o, j, tm = cfg["Oxygen"], cfg["Jump"], cfg["Tame"]
    order = cfg["TierOrder"]

    rng = random.Random(seed)
    free = [dive(cfg, lane, rng, 1.0, endless=True) for _ in range(max(4, runs // 4))]
    out.title("A ride down the whole lane with endless air", f"{len(free)} rides, {RIDE:g} s on each fish. Seconds in each land "
              "and the ground made a second (riding and hopping together), against the land's pace. Only rides that crossed "
              "the whole land are counted in its line.")
    rows, total = [], 0.0
    for z in range(lands):
        through = [r for r in free if r["reached"] > z or r["end"] == "the lane's end"]
        secs_in = sum(r["time"][z] for r in through) / len(through) if through else 0
        total += secs_in
        length = lane["End"][z] - lane["Start"][z]
        rows.append([w["name"][z], n(secs_in), n(length / secs_in) if secs_in else "",
                     n(cfg["LandPace"][min(z, len(cfg["LandPace"]) - 1)]), f"{len(through)} of {len(free)}"])
    rows.append(["All ten", n(total), n(lane["Length"] / total) if total else "", "", ""])
    out.table(["Land", "Seconds in it", "Studs a second", "The land's pace", "Rides that crossed it"], rows)
    out.line(f"Hops landed a ride: {sum(r['hops'] for r in free) / len(free):.0f}. Ended: {ends_of(free)}.")

    ways = [("at ease, takes what the lock gives", dict()),
            ("chooses green fish and tames", dict(green=True, tame=True)),
            ("the same, with a bag that keeps its best seven", dict(green=True, tame=True, best=True)),
            ("Space held", dict(sit=j.get("Cooldown", 0.08), react=0.0, mash=True))]
    players = [("a new player", o["StartMax"], 0)] + [(f"at home in land {z + 1}", home[z], z) for z in (1, 2, 3, 4)]
    out.title("How a dive goes today", f"Endless air off. \"At ease\": on each fish they hold until {LEAVE:g} s are left ({RIDE:g} s "
              f"at most), never hopping sooner than {REACT:g} s after a landing; off a red fish at {REACT:g} s. \"Chooses green "
              "fish and tames\": turns the hop to a fish they hold when one will be in reach, takes a red one only when none is, "
              f"and stays on each fish they hold until it is theirs (Tame.Time {tm.get('Time', 0):g} s) while a slot is free "
              f"(Tame.Carry {tm.get('Carry', 0):g}). \"A bag that keeps its best seven\": not built; they go on taming whatever "
              f"beats the cheapest fish carried. \"Space held\": a hop the moment it is allowed and a grab {j.get('MinFlight', 0):g} "
              f"s in. {runs} dives each. The model's rider never presses late and never misses an aim, so a dive here ends only "
              "for want of a fish. \"Studs\" and \"Ends in land\": the middle dive, the best of ten, the best. \"Red landings\": "
              "on a fish too strong, a dive. \"Catch earns\": the coins a second the dive's catch adds to a tank, sizes and "
              "colours averaged.")
    head = ["Player", "Max Oxygen", "Rider", "Lasts (s)", "Studs", "Ends in land", "Past their own land", "Hops landed", "Red landings",
            "Caught", "Catch earns /s", "Slots full", "How it ended"]
    rows, kept = [], {}
    for who, max_oxygen, own in players:
        for label, kw in ways:
            rng = random.Random(seed)
            rs = [dive(cfg, lane, rng, max_oxygen, **kw) for _ in range(runs)]
            kept[(who, label)] = rs
            caught = [t for r in rs for t in r["caught"]]
            top = max(caught, key=order.index) if caught else ""
            full = [r["full_at"] for r in rs if r["full_at"] is not None]
            earn = sum(r["earn"] for r in rs) / len(rs)
            rows.append([who, big(max_oxygen), label, n(sorted(r["seconds"] for r in rs)[len(rs) // 2]),
                         " / ".join(n(v) for v in spread([r["s"] for r in rs])),
                         " / ".join(str(v) for v in spread([r["reached"] + 1 for r in rs])),
                         f"{sum(1 for r in rs if r['reached'] > own)} of {len(rs)}", n(sum(r["hops"] for r in rs) / len(rs)),
                         n(sum(r["red"] for r in rs) / len(rs), 1),
                         f"{len(caught) / len(rs):.1f}" + (f" (to {top})" if top else ""),
                         big(earn) if earn >= 100 else n(earn, 1),
                         f"{len(full)} of {len(rs)}" + (f", {sum(full) / len(full):.0f} s in" if full else ""), ends_of(rs)])
    out.table(head, rows)

    start = o["StartMax"]
    no_refill = dict(cfg, Oxygen=dict(o, RedRefill=0))
    half_refill = dict(cfg, Oxygen=dict(o, RedRefill=0.5))
    mash = dict(sit=j.get("Cooldown", 0.08), react=0.0, mash=True)
    cases = [("Today: at ease", cfg, dict()), ("Today: at ease, too slow off one red fish in ten", cfg, dict(late=0.1)),
             ("Today: at ease, too slow off one in four", cfg, dict(late=0.25)), ("Today: Space held", cfg, mash),
             ("If a red landing gave half the meter back: at ease", half_refill, dict()),
             ("If a red landing gave half the meter back: Space held", half_refill, mash),
             ("If a red landing gave nothing back: at ease", no_refill, dict()),
             ("If a red landing gave nothing back: Space held", no_refill, mash)]
    out.title("How far down a new player gets by chaining red fish", f"{start:g} max Oxygen: every fish past the Shallows is red, "
              f"gives {o.get('StrainTime', 0):g} s, and today the landing gives the whole meter back. The share of {runs} dives "
              "that got into each land. Nothing is caught past the Shallows. The last lines try a rule that is not in the game: "
              "a landing on a red fish gives back less (Oxygen.RedRefill in the model).")
    rows = []
    for label, c, kw in cases:
        rng = random.Random(seed)
        rs = [dive(c, lane, rng, start, **kw) for _ in range(runs)]
        rows.append([label] + [pct(sum(1 for r in rs if r["reached"] >= z) / len(rs)) or "0%" for z in range(1, lands)]
                    + [pct(sum(1 for r in rs if r["end"] == "the lane's end") / len(rs)) or "0%",
                       n(spread([r["s"] for r in rs])[0]), n(sum(r["red"] for r in rs) / len(rs), 1),
                       n(sum(r["seconds"] for r in rs) / len(rs)), ends_of(rs)])
    out.table(["Rider"] + [f"Land {z + 1}" for z in range(1, lands)] + ["The lane's end", "Studs, the middle dive", "Red landings",
                                                                       "Lasts (s), mean", "How it ended"], rows)


def red_chain(cfg, lane, out, runs, seed, shrinks=(1.0, 0.75, 0.6, 0.5), floor=0.3):
    """The user's red rule (2026-11-22): a landing back on a red fish stays red, and each one in a row gives less
    time, RedShrink times the one before (never under RedFloor). How far a new player gets by chaining red fish."""
    w = world(cfg, lane)
    lands, o, j = w["lands"], cfg["Oxygen"], cfg["Jump"]
    start = o["StartMax"]
    mash = dict(sit=j.get("Cooldown", 0.08), react=0.0, mash=True)
    out.title("Red fish in a row: each gives less time (Oxygen.RedShrink, model only)",
              f"{start:g} max Oxygen, so every fish past the Shallows is red. The first red fish gives StrainTime "
              f"{o['StrainTime']:g} s; each one after it in a row x RedShrink, never under {floor:g} s; a fish you hold "
              f"ends the run of reds. The share of {runs} dives that got into each land, and the longest run of reds.")
    rows = []
    for k in shrinks:
        c = dict(cfg, Oxygen=dict(o, RedShrink=k, RedFloor=floor))
        times = ", ".join(f"{max(o['StrainTime'] * k ** i, floor):.2g}" for i in range(6))
        for label, kw in (("at ease", dict()), ("Space held", mash)):
            rng = random.Random(seed)
            rs = [dive(c, lane, rng, start, **kw) for _ in range(runs)]
            rows.append([f"x{k:g} ({times} s)", label]
                        + [pct(sum(1 for r in rs if r["reached"] >= z) / len(rs)) or "0%" for z in range(1, lands)]
                        + [n(sum(r["red"] for r in rs) / len(rs), 1), str(max(r["red_best"] for r in rs)),
                           n(sum(r["seconds"] for r in rs) / len(rs)), ends_of(rs)])
    out.table(["RedShrink (red seconds 1st to 6th)", "Rider"] + [f"Land {z + 1}" for z in range(1, lands)]
              + ["Red landings", "Longest red run", "Lasts (s), mean", "How it ended"], rows)


def main():
    global PLAN_MINUTES, HOME, RIDE, SIT_SHARE
    p = argparse.ArgumentParser(description="Ride a Fish balance model")
    p.add_argument("--md", action="store_true", help="markdown tables")
    p.add_argument("--redchain", type=int, default=0, metavar="N", help="only the red-in-a-row table, N dives a line")
    p.add_argument("--sim", type=int, default=0, metavar="N", help="play N dives per rider through the herd")
    p.add_argument("--dives", action="store_true", help="with --sim: only the dives' tables")
    p.add_argument("--prices", action="store_true", help="only the trainer, aura and tank tables")
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--set", action="append", default=[], metavar="Group.Key=value", help="try a number without editing Config")
    p.add_argument("--max", type=float, default=0, help="the max Oxygen the \"seconds on a fish\" table is for (default: Oxygen.StartMax)")
    p.add_argument("--home", type=float, default=HOME, help="seconds on a land's commonest fish that count as at home there")
    p.add_argument("--ride", type=float, default=RIDE, help="seconds a rider at ease sits on each fish")
    p.add_argument("--sit", type=float, default=SIT_SHARE, help="the share of play time spent on the trainer")
    p.add_argument("--plan", default="", help="minutes of play by which a player should be at home in each land, ten numbers with commas")
    p.add_argument("--economy", action="store_true", help="only the economy draft (task b1): seahorse levels, auras, needs, income, taming")
    p.add_argument("--colour", default="A", choices=["A", "B"], help="with --economy: what a colour multiplies the need by (A as the coins, B gentler)")
    p.add_argument("--sheet", default="", metavar="PNG", help="with --economy: also draw the draft's one-page sheet")
    a = p.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    cfg = read_config()
    apply_sets(cfg, a.set)
    HOME, RIDE, SIT_SHARE = a.home, a.ride, a.sit
    if a.plan:
        PLAN_MINUTES = [float(v) for v in a.plan.split(",")]
    lane = read_lane()
    out = Out(a.md)
    if a.set:
        print("With: " + ", ".join(a.set))
    if a.redchain > 0:
        red_chain(cfg, lane, out, a.redchain, a.seed)
        return
    if a.economy:
        data = economy(cfg, lane, out, SIT_SHARE, a.colour)
        if a.sheet:
            econ_sheet(data, os.path.abspath(a.sheet))
            print("\nsheet: " + os.path.abspath(a.sheet))
        return
    only =a.prices or (a.dives and a.sim > 0)
    if not only:
        tables(cfg, lane, out, a.max or cfg["Oxygen"]["StartMax"])
    if a.prices or not only:
        prices(cfg, lane, out, PLAN_MINUTES, "the old plan", SIT_SHARE)
        prices(cfg, lane, out, [m / 2 for m in PLAN_MINUTES], "twice as fast", SIT_SHARE)
    if a.sim > 0:
        sim(cfg, lane, out, a.sim, a.seed)


if __name__ == "__main__":
    main()
