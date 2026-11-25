"""The share of each power step (src/shared/FishTrails.luau, Points) in each land's fish, from Config's own odds:
ZoneMix, SizeChance, SizeLarge, SizeSmall, SizeGrow, SizeScale and BaseScale. usage: python tools/trails/step_shares.py
(Config.Grand's made-grand fish are not counted: about one Giant or better in every 800 studs on top.)"""
import glob, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
t = open(os.path.join(ROOT, "src/shared/Config.luau"), encoding="utf-8").read()
n = open(os.path.join(ROOT, "src/shared/FishTrails.luau"), encoding="utf-8").read()


def tab(text, name):
    m = re.search(r"\b%s\s*=\s*\{([^}]*)\}" % name, text)
    return {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*(-?[\d.]+)", m.group(1))}


SC, SS, GR = tab(t, "Config.SizeChance"), tab(t, "Config.SizeScale"), tab(t, "Config.SizeGrow")
SL, SM, BS = tab(t, "Config.SizeLarge"), tab(t, "Config.SizeSmall"), tab(t, "Config.BaseScale")
SP, RP = tab(n, "SizePoints"), tab(n, "RarityPoints")
FROM = [float(x) for x in re.search(r"StepFrom\s*=\s*\{([^}]*)\}", n).group(1).split(",") if x.strip()]
LONG = [float(x) for x in re.findall(r"[\d.]+", re.search(r"LengthPoints\s*=\s*\{(.*)\}", n).group(1))]
mix = re.search(r"Config\.ZoneMix = \{(.*?)\n\}", t, re.S).group(1)
mix = [{k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)", l)} for l in mix.strip().split("\n")]
fish = []
for f in glob.glob(os.path.join(ROOT, "src/shared/Creatures/*.json")):
    d = json.load(open(f, encoding="utf-8"))
    fish.append((d["Tier"], d["Zone"], d["Size"][2] * BS.get(os.path.basename(f)[:-5], 1)))


def step(p):
    return max(i + 1 for i, f in enumerate(FROM) if p >= f)


for z, mx in enumerate(mix):
    out = [0.0] * 7
    for r, w in mx.items():
        c = {k: SC[k] * (SM[r] if k == "Tiny" else SL[r]) for k in SC}
        c["Normal"] = 1 - sum(c.values())
        Ls = [L for T, Z, L in fish if T == r and 0 <= z + 1 - Z <= (1 if r == "Common" else 2)] or [30]
        for s, ch in c.items():
            for L in Ls:
                g = SS[s]
                g = 1 + (g - 1) * GR[r] if g > 1 else g
                lp = 0
                for i in range(0, len(LONG), 2):
                    if L * g >= LONG[i]:
                        lp = LONG[i + 1]
                out[step(RP[r] + SP[s] + lp)] += w / sum(mx.values()) * ch / len(Ls)
    print("land", z + 1, " ".join(f"{100 * x:5.1f}" for x in out[1:]))
