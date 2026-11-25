"""Sizes and colours a little better the further one is (the endless Underworld), what that does: python tools/endless/odds.py

FishService's own rules in plain sums: Config.rollSize by rarity, Config.Grand (one made grand for each 800 studs; with one
near, a grand roll is a Big), Config.Variant. `m` times the chances of Big and up, of Silver, Gold and Rainbow, and of Huge
and Colossal among the made-grand. Nothing else changes: the kinds, their speed, and what each of them needs (but a Big or
a Rainbow needs what a Big or a Rainbow always did, so the AVERAGE fish needs a hair more: printed)."""
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "balance"))
os.chdir(ROOT)
import model as M  # noqa: E402
import rad_economy as R  # noqa: E402

PER_800 = 20  # wild fish in 800 studs of lane (578 in 23,500)


def spawn(cfg, kinds, rng, m, near):
    f = rng.choices([k[0] for k in kinds], [k[1] for k in kinds])[0]
    large, small = cfg["SizeLarge"][f["Tier"]] * m, cfg["SizeSmall"][f["Tier"]]
    r, tier = rng.random(), "Normal"
    for t in ("Colossal", "Huge", "Giant", "Big", "Tiny"):
        r -= cfg["SizeChance"][t] * (small if t == "Tiny" else large)
        if r < 0:
            tier = t
            break
    g = cfg["Grand"]
    if near < g["Least"] and (f["Tier"] != "Common" or rng.random() < g["Common"]):
        h, c = g["Huge"] * m, g["Colossal"] * m
        q = rng.random()
        tier = "Colossal" if q < c else "Huge" if q < c + h else "Giant"
    elif near >= g["Most"] and tier in ("Giant", "Huge", "Colossal"):
        tier = "Big"
    v, colour = cfg["Variant"], ""
    r = rng.random()
    for n in ("Rainbow", "Gold", "Silver"):
        r -= v[n] * m
        if r < 0:
            colour = n
            break
    return f, tier, colour


def main(n=400_000):
    cfg = M.read_config()
    c, w, _lane, _ = R.scaled(cfg, R.STEP)
    kinds = [(f, s * wt / sum(x for _, x in w["pools"][9][t])) for t, s in w["mixes"][9].items() for f, wt in w["pools"][9][t]]
    base = None
    for m in (1.0, 1.05, 1.1, 1.25, 1.5, 2.0):
        rng, live = random.Random(7), []
        count, need, pay = {}, 0.0, 0.0
        for i in range(n):
            # the lane kept full: a fish leaves, a new one takes its place among the PER_800 of its stretch
            if len(live) >= PER_800:
                live.pop(rng.randrange(len(live)))
            near = sum(t in ("Giant", "Huge", "Colossal") for t in live)
            f, t, col = spawn(c, kinds, rng, m, near)
            live.append(t)
            count[t] = count.get(t, 0) + 1
            count[col or "plain"] = count.get(col or "plain", 0) + 1
            q = M.need_of(c, f, t, col)
            need += q
            pay += q * c["Aquarium"]["PerRequired"] * c["VariantIncome"].get(col, 1)
        base = base or (need, pay)
        print(f"m {m:<5g}", "| ".join(f"{k} {count.get(k, 0) / n * 100:.3g}%" for k in ("Big", "Giant", "Huge", "Colossal", "Silver", "Gold", "Rainbow")),
              f"| 1 Rainbow in {n / max(1, count.get('Rainbow', 1)):.0f} | average need {need / base[0]:.4f}x  average coins {pay / base[1]:.4f}x", flush=True)


if __name__ == "__main__":
    main()
