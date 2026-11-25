"""The endless study's economy: rad_economy's free player, with endless layers under land 10 (docs/design/endless.md).

  python tools/endless/economy.py [hours]

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


def run(cfg, c, w, g, pay, mile_o, mile_s, hours, seed, per_layer=1.0):
    src = inspect.getsource(R.play)
    src = src.replace("def play(", "def play2(")
    src = src.replace("goal = [M.required(cfg, z, w[\"usual\"][z]) for z in range(lands)]",
                      "goal = [M.required(cfg, min(z, 9), w[\"usual\"][min(z, 9)]) * (G ** max(0, z - 9)) for z in range(lands)]")
    src = src.replace("if index and f[\"Id\"] not in caught:", "if z >= 10 and z not in deep:\n                    for q in range(10, z + 1):\n                        if q not in deep:\n                            deep[q] = t\n                            mx += MILE_O * goal[q]\n                            coins += goal[q] * cfg[\"Aquarium\"][\"PerRequired\"] * MILE_S\n                if index and f[\"Id\"] not in caught:")
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


def main(hours=100.0):
    cfg = M.read_config()
    R.set_auras(cfg["AuraPrices"])
    c, w, lane, _ = R.scaled(cfg, R.STEP)
    rows = []
    cases = [("no endless (today)", None, 1, 0, 0), ("G 1.25", 1.25, 1, 0.02, 60), ("G 1.35", 1.35, 1, 0.02, 60), ("G 1.5", 1.5, 1, 0.02, 60),
             ("G 1.35, coins half the growth", 1.35, 0.5, 0.02, 60), ("G 1.35, no milestones", 1.35, 1, 0, 0), ("G 1.35, milestones x10", 1.35, 1, 0.2, 600)]
    for name, g, pay, mo, ms in cases:
        runs = [run(cfg, c, extended(c, w, g) if g else w, g or 1, pay, mo, ms, hours, seed) for seed in range(1, 6)]
        for i in range(len(runs[0][2])):
            col = [r[2][i] for r in runs]
            med = lambda k: statistics.median(x[k] for x in col)
            rows.append((name, col[0][0], med(1), med(2), med(3), med(4), med(5), med(10), med(11)))
            print(f"{name:32s} {col[0][0]:>4g} h  max {R.big(med(1)):>7s}  tank {R.big(med(3)):>7s}/s  coins {R.big(med(2)):>7s}  seahorse {med(4):g} aura {med(5):g}  layer caught in {med(10):g}  strong enough for {med(11):g}", flush=True)
    return rows


if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 100.0)
