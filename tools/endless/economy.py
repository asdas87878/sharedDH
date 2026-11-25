"""The endless study's economy: rad_economy's free player, with endless layers under land 10 (docs/design/endless.md).

  python tools/endless/economy.py [hours] [out.json] [only cases whose name has this]

A layer's fish are the Underworld's own kinds with a "Deep N" mark that multiplies the fish's own need (Hugo's rule: a
fish's Oxygen is the fish's, never the place's; Config.SpecialOxygen is the door for it): need x G^N, and its coins go
with its need as every fish's do (Aquarium.PerRequired). `pay`: how much of that growth the coins get (1: all of it).
A Deep fish is no new kind for the Index, so it pays nothing there. Milestones: the first time a layer is reached."""
import inspect
import os
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "balance"))
os.chdir(ROOT)
import model as M  # noqa: E402
import rad_economy as R  # noqa: E402

N = 60  # layers modelled


def extended(c, w, g):
    e = dict(w)
    e["mixes"], e["pools"], e["usual"], e["name"] = list(w["mixes"]), list(w["pools"]), list(w["usual"]), list(w["name"])
    for k in range(1, N + 1):
        e["mixes"].append(w["mixes"][9])
        e["pools"].append({t: [(dict(f, Deep=g ** k), wt) for f, wt in fs] for t, fs in w["pools"][9].items()})
        e["usual"].append(w["usual"][9])
        e["name"].append(f"Deep {k}")
    e["lands"] = 10 + N
    return e


def run(cfg, c, w, g, pay, mile_o, mile_s, hours, seed, collect=False):
    src = inspect.getsource(R.play)
    src = src.replace("def play(", "def play2(")
    src = src.replace("goal = [M.required(cfg, z, w[\"usual\"][z]) for z in range(lands)]",
                      "goal = [M.required(cfg, min(z, 9), w[\"usual\"][min(z, 9)]) * (G ** max(0, z - 9)) for z in range(lands)]")
    src = src.replace("if index and f[\"Id\"] not in caught:", "if z >= 10 and z not in deep:\n                    for q in range(10, z + 1):\n                        if q not in deep:\n                            deep[q] = t\n                            mx += MILE_O * goal[q]\n                            coins += goal[q] * cfg[\"Aquarium\"][\"PerRequired\"] * MILE_S\n                if index and f[\"Id\"] not in caught:")
    if collect:  # the 30% of catches not in the deepest go to a land whose Index page still misses a fish they can hold
        src = src.replace("else deepest - 1\n", "else max([q for q in range(min(deepest, 10)) if any(f[\"Id\"] not in caught and M.need_of(cfg, f) <= mx for f, _ in kinds[q])] or [deepest - 1])\n")
        assert "page" not in src and "any(f[" in src
    src = src.replace("home = {z:", "deep = DEEP\n    home = {z:")
    src = src.replace("gain = max(INDEX_LEAST, INDEX_FIRST * M.need_of(cfg, f))", "gain = max(R.INDEX_LEAST, R.INDEX_FIRST * NEED0(cfg, f))")
    for nm in ("INDEX_AURA", "INDEX_COIN_SECONDS", "INDEX_SET_COIN_SECONDS", "SEAHORSE", "AURAS", "STAGES", "CATCH_EVERY", "DEEP_SHARE"):
        src = src.replace(nm, "R." + nm).replace("R.R.", "R.")
    src = src.replace("INDEX_SET)", "R.INDEX_SET)").replace("R.INDEX_SET_COIN_SECONDS", "R.INDEX_SET_COIN_SECONDS")
    src = src.replace(">= WORK]", ">= R.WORK]").replace("sit=SIT", "sit=R.SIT")
    src = src.replace("coins += income(cfg, f) * R.INDEX_COIN_SECONDS", "coins += NEED0(cfg, f) * cfg[\"Aquarium\"][\"PerRequired\"] * R.INDEX_COIN_SECONDS")
    src = src.replace("marks = [0.25, 0.5, 1, 2, 3, 5, 8, 12, 20, 30, 45, 60]", "marks = [20, 25, 30, 45, 60, 80, 100, 150]")
    src = src.replace("log.append((marks.pop(0), mx,", "log.append((marks.pop(0), mx,").replace("len(sets_done)))", "len(sets_done), max([q - 9 for q in deep] or [0]), max([q - 9 for q in reached] or [0])))")
    need0 = M.need_of

    class MM:
        def __getattr__(self, k):
            return getattr(M, k)

        def need_of(self, cfg_, f, size="Normal", colour=""):
            v = need0(cfg_, f, size, colour)
            return v * f.get("Deep", 1)

    def income(cfg_, f, size="Normal", colour=""):
        v = need0(cfg_, f, size, colour) * f.get("Deep", 1) ** pay
        return v * cfg_["Aquarium"]["PerRequired"] * cfg_["VariantIncome"].get(colour, 1)

    import random
    ns = {"M": MM(), "R": R, "random": random, "income": income, "NEED0": lambda a, b: need0(a, b), "G": g, "MILE_O": mile_o, "MILE_S": mile_s, "DEEP": {}}
    exec(src, ns)
    reached, bought, log, goal = ns["play2"](c, w, hours, seed=seed)
    return reached, bought, log, goal


# name, G, the coins' share of the growth, milestone's Oxygen (of the layer's own need), its seconds of the layer's coins,
# "collect": the 30% of catches not made in the deepest land go to the Index's missing fish (None: rad_economy's own rule,
# the land just above the deepest one, so a diver in the layers never fills the last lands' pages)
CASES = [("no endless (today)", None, 1, 0, 0, None)]
CASES += [(f"G 1.35, {round(o * 100)}% and {s} s", 1.35, 1, o, s, None) for o, s in
          ((0, 0), (0.02, 60), (0.04, 60), (0.06, 60), (0.08, 60), (0.10, 60), (0.10, 0), (0.2, 600))]
CASES += [("G 1.35, 2% and 60 s, coins half the growth", 1.35, 0.5, 0.02, 60, None)]
CASES += [(f"G {g}, 2% and 60 s", g, 1, 0.02, 60, None) for g in (1.25, 1.5)]
CASES += [(f"G {g}, 10% and 0 s", g, 1, 0.1, 0, None) for g in (1.25, 1.5)]
CASES += [("no endless, filling the Index", None, 1, 0, 0, "collect")]
CASES += [(f"G 1.35, {round(o * 100)}% and {s} s, filling the Index", 1.35, 1, o, s, "collect") for o, s in ((0, 0), (0.02, 60), (0.04, 60), (0.06, 60), (0.08, 60), (0.1, 0))]


def case(args):
    (name, g, pay, mo, ms, share), hours = args
    cfg = M.read_config()
    R.set_auras(cfg["AuraPrices"])
    c, w, _lane, _ = R.scaled(cfg, R.STEP)
    runs = [run(cfg, c, extended(c, w, g) if g else w, g or 1, pay, mo, ms, hours, seed, bool(share)) for seed in range(1, 6)]
    rows = []
    for i in range(len(runs[0][2])):
        col = [r[2][i] for r in runs]
        rows.append([name, col[0][0]] + [statistics.median(x[k] for x in col) for k in (1, 2, 3, 4, 5, 9, 10, 11)])
    return rows


def main(hours=100.0, out=None, only=""):
    import json
    from multiprocessing import Pool
    all_rows = []
    with Pool(4) as pool:
        for rows in pool.imap(case, [(c, hours) for c in CASES if only in c[0]]):
            all_rows += rows
            for name, t, mx, coins, tank, sea, aura, sets, caught, strong in rows:
                print(f"{name:42s} {t:>4g} h  max {R.big(mx):>7s}  tank {R.big(tank):>7s}/s  coins {R.big(coins):>7s}  seahorse {sea:g} aura {aura:g}  sets {sets:g}  "
                      f"layer caught in {caught:g}  strong enough for {strong:g}", flush=True)
    if out:
        json.dump(all_rows, open(out, "w"))
    return all_rows


if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 100.0, *sys.argv[2:])
