"""The economy, draft 2 (2026-11-22): Ride a Dino's progression, on our fish.

usage:  python tools/balance/rad_economy.py               the tables and a free player's play-through
        python tools/balance/rad_economy.py --md          the same as markdown (docs/design/progression.md)
        python tools/balance/rad_economy.py --sit 0.25    a player who sits on the seahorse less
        python tools/balance/rad_economy.py --step 7.3    the need ladder: times a land (default 7.3)
        python tools/balance/rad_economy.py --no-index    the same player with no Index rewards
        python tools/balance/rad_economy.py --prices      one table: the auras beside the seahorse, the subs and the tank
                                                          (when each is bought, and how long it is saved for), 5 seeds

The user, 2026-11-22: "We need to pretty much replicate ride a dinos progression ... The upper tier dinos in ride a dino
are in the billions, possibly higher ... we need that huge cap whilst making the progression possible."

How it is anchored (every reference number is from docs/reference/ride-a-dino-deep.md; seen/said/fit marked there and
in the tables below):
  - OUR OXYGEN = THEIR STAMINA x 8. Their first wild dino needs 10, our Clownfish 80. So their Cosmic zone's 700M to
    1.6B is our land 10 at about 5B to 13B.
  - OUR COINS = THEIR DOLLARS. A fish earns need x Aquarium.PerRequired (0.025), unchanged: our Clownfish earns $2 a
    second like their Pachycephalosaur, and a tank earns about what their pen does at the same stage (their user's
    account: 1.9K Stamina, a pen of $2.2K to $5K a second; ours at 15K Oxygen about $3.3K). So their price ladders,
    in dollars, are our price ladders in coins.
  - Nothing here is in Config. It reads the fish (kinds, rarity, home land, spawn mix) from the game and the model.
"""
import argparse
import json
import math
import os
import random
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model as M  # noqa: E402

# ---------------------------------------------------------------- the proposal (draft 2)
STEP = 7.3  # a land's commonest fish needs this many times the land before's (theirs: "about five times a zone",
            # 10 to about 700M over nine zones is x7.5)
FIRST = 80  # land 1's commonest (a Normal plain Clownfish), as today

# The seahorse: 12 levels (Hugo's names, trainer.md). Oxygen a second (a fixed whole number; the aura multiplies it).
# Theirs, seen: +2, +5, +15, +36, +95 for levels 1 to 5, and the cash $300, $15K, ?, $4M, $80M, ?, $75B, $3T for 1 to 8.
# Ours: their rate x 8 (as Oxygen), then x2.5 a level where theirs is unknown; their cash where seen, a fit between.
SEAHORSE = [  # (name, Oxygen a second, price, where the price comes from)
    ("Toy", 16, 300, "theirs costs $300 (seen); ours is free (Hugo)"),
    ("Painted", 40, 15_000, "theirs, seen ($15K)"),
    ("Saddled", 120, 250_000, "fit"),
    ("Racer", 290, 4_000_000, "theirs, seen ($4M)"),
    ("Iron", 760, 80_000_000, "theirs, seen ($80M)"),
    ("Spiked", 1_900, 2_500_000_000, "fit"),
    ("Knight", 4_800, 75_000_000_000, "theirs, said ($75B)"),
    ("Royal", 12_000, 3_000_000_000_000, "theirs, seen ($3T)"),
    ("Golden", 30_000, 60e12, "fit, x20"),
    ("Abyssal", 75_000, 1.2e15, "fit, x20"),
    ("Starfire", 190_000, 25e15, "fit, x20"),
    ("Prismatic", 470_000, 500e15, "fit, x20"),
]
# Hugo's twelve auras (src/shared/Auras.luau). Prices: the game's own, Config.Aura.Prices (2026-11-24: $100, then x20 a
# tier). Draft 2's, theirs ($100 to $5Qa seen for 1 to 11, the 12th a fit), are kept for comparing: --draft2-auras.
AURA_NAMES = [("Bubble", 1.5), ("Shell", 2), ("Tide", 2.5), ("Current", 3), ("Reef", 3.5), ("Storm", 4), ("Moon", 5),
              ("Lantern", 6), ("Ember", 7), ("Urchin", 8), ("Abyss", 10), ("Leviathan", 12)]
AURA_DRAFT2 = [100, 5e3, 75e3, 1.5e6, 30e6, 750e6, 20e9, 500e9, 12.5e12, 300e12, 5e15, 100e15]
AURAS = []  # (name, times, price), filled by set_auras


def set_auras(prices):
    AURAS[:] = [(n, m, pr) for (n, m), pr in zip(AURA_NAMES, prices)]


# The tank's five stages (+2 fish each, Config.PlotUpgrades): theirs $1M for pen 1 to 2, $500B for 6 to 7, $25T for
# 8 to 9 (seen). Ours has five steps where theirs has eight or more: $1M, then about x30.
STAGES = [1e6, 30e6, 1e9, 30e9, 1e12]
# The Index (not built; Findings 2026-11-16 "Bring the Index forward: yes"; Refinement: "paying Oxygen and coins for
# each new one"). Theirs: a first catch pays about a tenth of what the dino needs (a Raptor +20 for 160, an Eternal
# +110M for about a billion) but never less than the start (Dodo +20 with 20 to start), and cash of about 100 s of what
# it earns (Dodo $100 at $1/s, Barosaurus Fossil $6B at $60M/s). A finished zone pays about its commonest dino's need
# again (Plains +120, Extinction +148M) and cash.
INDEX_FIRST = 0.2  # Oxygen: this share of the kind's Normal plain need,
INDEX_LEAST = 100  # and at least this (our start)
INDEX_COIN_SECONDS = 100  # coins: this many seconds of what the kind earns
INDEX_SET = 0.5  # a land's every kind caught: this many times the land's commonest need, in Oxygen
INDEX_SET_COIN_SECONDS = 600  # and this many seconds of that fish's earnings, in coins
# (draft 2's two. The play takes the game's own, Config.Index, where it has them: 5 and 2500 since 2026-11-24)
INDEX_AURA = False  # theirs: an aura multiplies the machine only ("It does not multiply the Stamina you have")

# The player (guesses, the reference's habits)
SIT = 0.35  # share of play time on the seahorse (the user, 2026-11-22: "about correct")
CATCH_EVERY = 25.0  # seconds of diving per fish brought home (theirs: 2 to 8 a run of one to two minutes)
DEEP_SHARE = 0.7  # a catch is in the deepest land the player can work (the rest: the land above, filling the Index)
WORK = 0.3  # a land can be worked once this share of its spawns can be held


def scaled(cfg, step):
    """cfg with OxygenBase scaled land by land from task e1's bases (frozen in e1_bases.json, so running this again
    once Config holds draft 2 gives the same numbers) so each land's commonest Normal plain fish (the median kind)
    needs FIRST x step^(land-1). Land 1 is left as it was (Config.GrowFrom and the $2 Clownfish rest on its 80). The
    within-land spread (Hugo's hand bases) is kept."""
    lane = M.read_lane()
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "e1_bases.json")) as f:
        e1 = json.load(f)
    old = dict(cfg, OxygenBase=e1)
    w = M.world(old, lane)
    c = dict(cfg, OxygenBase=dict(e1))
    scale = {z + 1: (FIRST * step ** z / M.required(old, z, w["usual"][z]) if z else 1) for z in range(w["lands"])}
    # bases rounded to two figures (land 1 not at all), then nudged up a step at a time until no two kinds share a
    # base or a need (e1's rule), smallest first so Hugo's order inside a land holds
    needs, bases = set(), set()
    for f in sorted(cfg["Fish"], key=lambda f: e1[f["Id"]] * scale[f["Home"]]):
        b = e1[f["Id"]] * scale[f["Home"]]
        unit = 1 if f["Home"] == 1 else 10 ** max(math.floor(math.log10(b)) - 1, 0)
        b = max(round(b / unit) * unit, 1)
        c["OxygenBase"][f["Id"]] = float(b)
        while b in bases or M.need_of(c, f) in needs:
            b += unit
            c["OxygenBase"][f["Id"]] = float(b)
        bases.add(b)
        needs.add(M.need_of(c, f))
    return c, w, lane, scale


def income(cfg, fish, size="Normal", colour=""):
    return M.need_of(cfg, fish, size, colour) * cfg["Aquarium"]["PerRequired"] * cfg["VariantIncome"].get(colour, 1)


def play(cfg, w, hours=60, sit=SIT, index=True, seed=3, dt=5.0, earned=None):
    """A free player: sits SIT of the time, dives the rest, brings a fish home every CATCH_EVERY s of diving, buys the
    cheapest thing not yet owned (seahorse level, aura, tank stage) as soon as the coins are there."""
    rng = random.Random(seed)
    lands = w["lands"]
    kinds = [[(f, wt) for t, share in w["mixes"][z].items() for f, wt in
              [(f, share * wt / sum(x for _, x in w["pools"][z][t])) for f, wt in w["pools"][z][t]]] for z in range(lands)]
    sizes = {t: M.size_odds(cfg, t) for t in cfg["TierOrder"]}
    colours = M.colour_odds(cfg)
    # a land's set: its kinds that spawn there (Secrets have no spawn share yet, so they are left out of the set)
    home = {z: [f for f in cfg["Fish"] if f["Home"] == z + 1 and f["Reach"] >= 0 and f["Tier"] != "Secret"]
            for z in range(lands)}
    goal = [M.required(cfg, z, w["usual"][z]) for z in range(lands)]
    set_oxygen = cfg["Index"].get("SetOxygen", INDEX_SET)
    set_seconds = cfg["Index"].get("SetCoinSeconds", INDEX_SET_COIN_SECONDS)
    subs, tier = cfg["SubPrices"], 0  # bought once the land it goes to is held (it is a cost here; the dives assume it)
    mx, coins, t = float(cfg["Oxygen"]["StartMax"]), 0.0, 0.0
    level, aura, stage = 0, 0, 0  # seahorse level index (0 = Toy, owned; free), auras owned, stages owned
    owned_level = 0
    tank, caught, sets_done = [], set(), set()
    reached, bought, log = {0: 0.0}, [], []
    marks = [0.25, 0.5, 1, 2, 3, 5, 8, 12, 20, 30, 45, 60]
    next_catch = CATCH_EVERY / (1 - sit)
    from_index = 0.0
    while t < hours * 3600:
        mult = AURAS[aura - 1][1] if aura else 1
        mx += SEAHORSE[owned_level][1] * mult * sit * dt
        earn = sum(sorted(tank, reverse=True)[:7 + 2 * stage])
        coins += earn * dt
        t += dt
        if t >= next_catch:
            next_catch += CATCH_EVERY / (1 - sit)
            deepest = max([z for z in range(lands)
                           if sum(wt for f, wt in kinds[z] if M.need_of(cfg, f) <= mx) >= WORK] or [0])
            z = deepest if rng.random() < DEEP_SHARE or deepest == 0 else deepest - 1
            ok = [(f, wt) for f, wt in kinds[z] if M.need_of(cfg, f) <= mx]
            if ok:
                f = rng.choices([f for f, _ in ok], [wt for _, wt in ok])[0]
                s = rng.choices(list(sizes[f["Tier"]]), list(sizes[f["Tier"]].values()))[0]
                c = rng.choices(list(colours), list(colours.values()))[0]
                if M.need_of(cfg, f, s, c) > mx:
                    s, c = "Normal", ""
                tank.append(income(cfg, f, s, c))
                if len(tank) > 60:
                    tank = sorted(tank, reverse=True)[:30]
                if index and f["Id"] not in caught:
                    caught.add(f["Id"])
                    gain = max(INDEX_LEAST, INDEX_FIRST * M.need_of(cfg, f))
                    mx += gain * (mult if INDEX_AURA else 1)
                    from_index += gain * (mult if INDEX_AURA else 1)
                    coins += income(cfg, f) * INDEX_COIN_SECONDS
                    hz = f["Home"] - 1
                    if hz not in sets_done and all(k["Id"] in caught for k in home[hz]):
                        sets_done.add(hz)
                        mx += set_oxygen * goal[hz] * (mult if INDEX_AURA else 1)
                        from_index += set_oxygen * goal[hz] * (mult if INDEX_AURA else 1)
                        coins += goal[hz] * cfg["Aquarium"]["PerRequired"] * set_seconds
        # buy the cheapest next thing
        while True:
            opts = []
            if owned_level + 1 < len(SEAHORSE):
                opts.append((SEAHORSE[owned_level + 1][2], "level"))
            if aura < len(AURAS):
                opts.append((AURAS[aura][2], "aura"))
            if stage < len(STAGES):
                opts.append((STAGES[stage], "stage"))
            if tier < min(len(subs), lands - 1) and mx >= goal[tier + 1]:
                opts.append((subs[tier], "sub"))
            if not opts:
                break
            price, what = min(opts)
            if coins < price:
                break
            coins -= price
            if earned is not None:  # what the tank made a second as it was bought
                earned.append((t, price, earn))
            if what == "level":
                owned_level += 1
                bought.append((t, f"seahorse {owned_level + 1} {SEAHORSE[owned_level][0]}"))
            elif what == "aura":
                aura += 1
                bought.append((t, f"aura {AURAS[aura - 1][0]} x{AURAS[aura - 1][1]:g}"))
            elif what == "sub":
                tier += 1
                bought.append((t, f"sub {tier}"))
            else:
                stage += 1
                bought.append((t, f"tank stage {stage}"))
        for z in range(lands):
            if z not in reached and mx >= goal[z]:
                reached[z] = t
        while marks and t >= marks[0] * 3600:
            log.append((marks.pop(0), mx, coins, earn, owned_level + 1, aura, stage, len(caught), from_index, len(sets_done)))
    return reached, bought, log, goal


def big(v):
    """M.big, with Qa (1e15) and Qi (1e18) past T."""
    for at, tag in ((1e18, "Qi"), (1e15, "Qa")):
        if v >= at:
            x = v / at
            return f"{x:.3g}{tag}"
    return M.big(v)


def clock(seconds):
    m = seconds / 60
    return f"{m:.0f} min" if m < 90 else f"{m / 60:.1f} h"


def prices(out, cfg, c, w, a):
    """Every ladder on one scale. Minutes of income: the price over what the tank makes as it is bought (how long it is
    saved for if nothing else is bought). Share: those minutes over the minutes played so far, so a thing at hour 30 can
    be set beside one at minute 30."""
    got, lands = {}, {}
    for seed in range(1, 6):
        earned = []
        reached, bought, _, _ = play(c, w, a.hours, a.sit, not a.no_index, seed=seed, earned=earned)
        for (t, what), (_, price, earn) in zip(bought, earned):
            kind = " ".join(what.split()[:3 if what.startswith("tank") else 2])
            if kind.startswith("aura"):
                kind = f"aura {[n for n, _ in AURA_NAMES].index(what.split()[1]) + 1}"
            got.setdefault(kind, []).append((t, price / max(earn, 1) / 60))
        for z, t in reached.items():
            lands.setdefault(z, []).append(t)

    def cell(key, price):
        v = got.get(key)
        if price is None:
            return ["", "", "", ""]
        if not v or len(v) < 3:
            return ["$" + big(price), "later", "", ""]
        t, m = statistics.median(x[0] for x in v), statistics.median(x[1] for x in v)
        return ["$" + big(price), clock(t), f"{m:.1f}" if m < 10 else f"{m:,.0f}", f"{100 * m * 60 / t:.0f}%"]

    subs = cfg["SubPrices"]
    out.title(f"R6. The auras beside the rest (5 seeds, {a.hours:g} h)",
              "Bought at; minutes of the tank's income it costs then; those minutes as a share of the time played.")
    rows = []
    for i, (n, m, pr) in enumerate(AURAS):
        horse = SEAHORSE[i][2] if i else None
        last = AURAS[i - 1][2] if i else None
        sub = subs[i] if i < len(subs) else None
        rows.append([f"{i + 1} {n} x{m:g}", *cell(f"aura {i + 1}", pr), f"x{pr / last:.1f}" if last else "",
                     *cell(f"seahorse {i + 1}", horse), f"{pr / horse:.2f}" if horse else "",
                     *cell(f"sub {i + 1}", sub), f"{pr / sub:.3f}" if sub else ""])
    out.table(["Aura", "Price", "At", "Min", "Share", "Step", "Seahorse, same number", "At", "Min", "Share", "Aura / it",
               "Sub, same number", "At", "Min", "Share", "Aura / it"], rows)
    out.table(["Tank stage", "Price", "At", "Min", "Share"],
              [[str(i + 1), *cell(f"tank stage {i + 1}", pr)] for i, pr in enumerate(STAGES)])
    out.line("Lands held at: " + ", ".join(clock(statistics.median(lands[z])) if z in lands else "later" for z in range(w["lands"])))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--md", action="store_true")
    p.add_argument("--sit", type=float, default=SIT)
    p.add_argument("--step", type=float, default=STEP)
    p.add_argument("--no-index", action="store_true")
    p.add_argument("--hours", type=float, default=60)
    p.add_argument("--prices", action="store_true")
    p.add_argument("--draft2-auras", action="store_true")
    a = p.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    cfg = M.read_config()
    set_auras(AURA_DRAFT2 if a.draft2_auras or not cfg["AuraPrices"] else cfg["AuraPrices"])
    c, w, lane, scale = scaled(cfg, a.step)
    out = M.Out(a.md)
    if a.prices:
        return prices(out, cfg, c, w, a)

    out.title("R1. What a fish needs, by land (draft 2)",
              f"Each land's commonest fish needs x{a.step:g} the land before's (theirs about x5 to x8 a zone). Every kind's "
              "base is today's times its land's factor, so Hugo's spread inside a land is kept. A Normal plain fish; "
              "sizes (x0.8 to x3) and colours (x1.25 to x2) multiply it as today.")
    rows = []
    for z in range(w["lands"]):
        own = [f for f in c["Fish"] if f["Home"] == z + 1]
        needs = sorted(M.need_of(c, f) for f in own)
        top = max(own, key=lambda f: M.need_of(c, f))
        rows.append([w["name"][z], w["usual"][z], big(M.required(cfg, z, w["usual"][z])), big(M.required(c, z, w["usual"][z])),
                     big(needs[0]), big(needs[-1]) + f" ({top['Name']}, {top['Tier']})",
                     big(M.need_of(c, top, "Colossal", "Rainbow")), f"x{scale[z + 1]:,.0f}"])
    out.table(["Land", "Commonest", "Needs today", "Needs, draft 2", "Least", "Most (Normal plain)", "Most, Colossal Rainbow",
               "Bases times"], rows)
    ref = [("1 Plains", "10", "80"), ("2 Forest", "50 to 160", "400 to 1,300"), ("5 Snow", "32K to 87K", "256K to 700K"),
           ("6 Giant Forest", "70K to under 1M", "560K to 8M"), ("7 Abyss Ocean", "about 1.2M (a Huge)", "about 10M"),
           ("8 Volcano", "2.9M (a Mythic)", "23M"), ("9 Extinction", "18M to 80M", "144M to 640M"),
           ("10 Cosmic", "700M to 1.6B, one 2.1B", "5.6B to 13B, 17B")]
    out.title("R1b. Theirs, for the same lands (seen on tags)", "Their Stamina, and x8 as our Oxygen.")
    out.table(["Their zone", "Needs (theirs)", "x8 (ours)"], [list(r) for r in ref])

    out.title("R2. The seahorse (draft 2)", "A fixed whole number a second, times the aura. Their machine ticks five "
              "times a second; ours once. Prices in coins = their dollars.")
    rows = []
    for i, (name, rate, price, src) in enumerate(SEAHORSE):
        rows.append([f"{i + 1} {name}", f"+{rate:,}", "free" if i == 0 else "$" + big(price), src])
    out.table(["Level", "Oxygen a second", "Price", "Price from"], rows)

    out.title("R3. The auras (Hugo's twelve; the game's prices)", "An aura multiplies the seahorse's Oxygen only, as theirs "
              "multiplies the machine only (Hugo's Auras.luau says all Oxygen gained: his call). Their multipliers on 9 November: x1.5, 2, 2.5, 3 for the first four, like Hugo's.")
    out.table(["Aura", "Times", "Price", "Theirs (draft 2)"], [[f"{i + 1} {n}", f"x{m:g}", "$" + big(pr), "$" + big(AURA_DRAFT2[i])]
                                                                for i, (n, m, pr) in enumerate(AURAS)])

    out.title("R4. The tank", f"A fish earns its need x {cfg['Aquarium']['PerRequired']:g} a second (as today). Stages "
              "+2 fish each (as built), at their pen's prices.")
    out.table(["Stage", "Fish earning", "Price"], [[str(i + 1), str(9 + 2 * i), "$" + big(pr)] for i, pr in enumerate(STAGES)])

    reached, bought, log, goal = play(c, w, a.hours, a.sit, not a.no_index)
    out.title("R5. A free player, played through" + (" (no Index)" if a.no_index else ""),
              f"Sits on the seahorse {a.sit * 100:.0f}% of the time, brings a fish home every {CATCH_EVERY:g} s of diving "
              f"from the deepest land where they hold {WORK * 100:.0f}% of the spawns ({DEEP_SHARE * 100:.0f}% of catches; "
              "the rest one land up), buys the cheapest next thing at once. When they can first tame each land's "
              "commonest fish:")
    out.table(["Land", "Needs", "Reached at"], [[w["name"][z], big(goal[z]), clock(reached[z]) if z in reached else "later"]
                                                for z in range(w["lands"])])
    out.table(["Hours in", "Max Oxygen", "Coins", "Tank /s", "Seahorse", "Aura", "Stage", "Kinds caught", "From the Index", "Sets"],
              [[f"{h:g}", big(mx), "$" + big(co), "$" + big(e), str(lv), str(au), str(st), str(k), big(fi), str(ns)]
               for h, mx, co, e, lv, au, st, k, fi, ns in log])
    out.line("Bought: " + "; ".join(f"{what} at {clock(t)}" for t, what in bought))
    out.line("Theirs, for the same hours (free players, seen): 2.5 min the lesson; '2 hours': 37M Stamina, $1.2T "
             "(x8: 300M); '30 hours': 971M Stamina, $20T, 55 of 61 kinds, an Eternal earning $250M a second (x8: 7.8B). "
             "Top pens $324B a second (Robux).")


if __name__ == "__main__":
    main()
