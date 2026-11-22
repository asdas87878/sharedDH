"""Which fish to keep, recolour or cut, by the reference's rule for how creatures sit in their land (2026-11-19; the
study: research/ride-a-dino/dinos/notes.md, private; ours: art/creatures/values.csv from tools/art/fish_values.py).

Their rule, measured on 62 dinos with their rarity tags:
- the bottom tiers wear the land: Commons 1 to 6 L* off the floor and in its colour family, Uncommons about 17;
- from Rare up they stand out, by lightness (a median gap of 26 to 41), by an opposite hue, or both;
- Mythic and above go to the lightness extreme opposite the floor, and only they glow.
So, ours by tier: a Common should be within 10 of the floor and in its family; an Uncommon within 20; a Rare or Epic
20 or more off, or of an opposite hue (90 degrees or more, saturation 0.4 or more); a Legendary 25 or more off; a Mythic
or Secret 30 or more off, toward the far end from the floor, and glowing.

usage: python tools/art/fish_verdict.py     writes art/creatures/verdict.csv and docs/attachments/fish-verdict.jpg"""
import csv
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]

# the first land has 15 kinds, about twice any other (the user: "some will have to go entirely due to too much fish
# (mainly and namely in the first zone, make sure you keep the turtle"). Cut: the two of the four near-identical yellow
# commons that add the least (Boxfish and Butterflyfish beside Yellow Tang and Pufferfish), the Blue Chromis (a common
# that breaks the land instead of wearing it) and the Flying Fish (a second blue that does the same as an Uncommon).
CUT = {"Boxfish": "the third and fourth of four yellow commons the sand's own lightness; Yellow Tang and Pufferfish keep the role",
       "Butterflyfish": "the same as the Boxfish",
       "BlueChromis": "a Common that contrasts strongly (blue on sand): the bottom tier should wear the land",
       "FlyingFish": "a second strong blue in the first land, as an Uncommon; the Shallows keep ten kinds"}
KEEP_ALWAYS = {"SeaTurtle"}
# each land's one fish that wears it, where no Common or Uncommon does (the reference: every land has fish that blend).
# A wearer is judged as one (within 15 of the floor), whatever its rarity. Twilight, the Vents and the Bone Graveyard's
# wearers are the fish that already blended there before the recolours (2026-11-19: the first list told them to stand
# out, and those lands were left with no fish that wears them)
# judged by eye where the median misleads: a fish split into very dark and very light halves stands out though its
# median sits near the floor (2026-11-19, the map chat, from the creature chat's sheet)
BY_EYE = {"HalfboneMegalodon": "split black front and bone back: stands out by eye though its median is near the floor"}
WEARERS = {"Dolphin": 5, "GoblinShark": 6, "FrilledShark": 7, "Megalodon": 8, "GraveRay": 9, "BrimstoneEel": 10}


def target(tier):
    """(lowest gap, highest gap) in L* from the floor"""
    return {"Common": (0, 10), "Uncommon": (0, 20), "Rare": (20, 99), "Epic": (20, 99), "Legendary": (25, 99), "Mythic": (30, 99), "Secret": (30, 99)}[tier]


def judge(r):
    tier, gap, hue, sat = r["tier"], float(r["gap_floor"]), float(r["hue_gap"]), float(r["main_sat"])
    lo, hi = target(tier)
    floor_L = float(r["floor_L"])
    if r["id"] in CUT:
        return "cut", CUT[r["id"]], ""
    if r["id"] in BY_EYE:
        return "keep", BY_EYE[r["id"]], ""
    if r["id"] in WEARERS:
        if abs(gap) <= 15:
            return "keep", "its land's wearer: blends in", ""
        return "recolour", f"its land's wearer, but {abs(gap):.0f} off the floor (back to its colours in the game, git HEAD, where it blended)", f"lightness toward {float(r['floor_L']) - 8 * (1 if gap < 0 else -1):.0f} (now {float(r['median_L']):.0f}), in the land's family"
    ok_value = lo <= abs(gap) <= hi
    ok_hue = hue >= 90 and sat >= 0.4
    if tier in ("Common", "Uncommon"):
        if ok_value:
            return "keep", "wears the land" if abs(gap) <= 10 else "close to the land", ""
        # too loud for its tier: toward the floor
        want = (floor_L - (8 if tier == "Common" else 15) * (1 if gap < 0 else -1))
        return "recolour", f"too loud for a {tier}: {abs(gap):.0f} off the floor", f"lightness toward {want:.0f} (now {float(r['median_L']):.0f}), in the land's family"
    if tier in ("Rare", "Epic"):
        if ok_value or ok_hue:
            return "keep", "stands out by " + ("lightness" if ok_value else "an opposite hue"), ""
        go = "darker" if floor_L >= 60 else ("lighter" if floor_L <= 40 else ("darker" if gap <= 0 else "lighter"))
        want = floor_L - 24 if go == "darker" else floor_L + 24
        return "recolour", f"blends: {abs(gap):.0f} off the floor, hue {hue:.0f} degrees off", f"{go}, toward {want:.0f}, or an opposite hue"
    # Legendary and up
    if not ok_value:
        # keep the side it is already on when the far end there is reachable; else the other side
        if gap > 0 and floor_L + lo + 4 <= 95:
            go = "lighter"
        elif gap < 0 and floor_L - lo - 4 >= 8:
            go = "darker"
        else:
            go = "darker" if floor_L >= 55 else "lighter"
        want = max(8, floor_L - lo - 4) if go == "darker" else min(95, floor_L + lo + 4)
        extra = ", glowing" if tier in ("Mythic", "Secret") and r["glow"] != "True" else ""
        return "recolour", f"blends for a {tier}: {abs(gap):.0f} off the floor", f"{go}, toward {want:.0f}{extra}"
    if tier in ("Mythic", "Secret") and r["glow"] != "True":
        return "recolour", "no glow", "add glow"
    return "keep", f"{abs(gap):.0f} off the floor" + (", glowing" if r["glow"] == "True" else ""), ""


def main():
    rows = list(csv.DictReader(open(os.path.join(ROOT, "art", "creatures", "values.csv"))))
    out = []
    for r in rows:
        v, why, todo = judge(r)
        if r["id"] in KEEP_ALWAYS and v == "cut":
            v = "keep"
        out.append({**r, "verdict": v, "why": why, "change": todo})
    # the reference's other half: in each land the bottom tiers blend. A land with no fish that wears it (the deep
    # lands: every fish dark on a light floor) has its lowest-tier fish marked to blend in.
    for z in range(1, 11):
        fish = sorted([o for o in out if int(o["zone"]) == z and o["verdict"] != "cut"], key=lambda o: TIERS.index(o["tier"]))
        if fish and not any(o["id"] in WEARERS for o in fish) and not any(abs(float(o["gap_floor"])) <= 15 for o in fish):
            low = [o for o in fish if o["tier"] == fish[0]["tier"]]
            o = min(low, key=lambda o: abs(float(o["gap_floor"])))  # the lowest tier's fish nearest the floor already
            o["verdict"] = "recolour"
            o["why"] = "no fish in this land wears it: the lowest tier should blend"
            o["change"] = f"lightness toward {float(o['floor_L']) - 8:.0f} (now {float(o['median_L']):.0f}), in the land's family"
    path = os.path.join(ROOT, "art", "creatures", "verdict.csv")
    keys = ["zone", "land", "tier", "name", "id", "verdict", "why", "change", "median_L", "floor_L", "gap_floor", "hue_gap", "main", "glow"]
    with open(path, "w", newline="") as fh:
        w = csv.DictWriter(fh, keys, extrasaction="ignore")
        w.writeheader()
        for o in sorted(out, key=lambda o: (int(o["zone"]), TIERS.index(o["tier"]), o["name"])):
            w.writerow(o)
    # the chart: per land, each fish a dot at its lightness, the floor a line; colour = verdict
    font, bold = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 12), ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15)
    W, ROW = 1500, 112
    im = Image.new("RGB", (W, 70 + 10 * ROW), (250, 246, 240))
    d = ImageDraw.Draw(im)
    d.text((10, 10), "Each fish's lightness against its land's floor (the black line), by rarity (left to right). Green keep, orange recolour (arrow: where to), red cut", font=bold, fill=(20, 20, 20))
    X0, XW = 170, (W - 200) / 7
    for t, tier in enumerate(TIERS):
        d.text((X0 + t * XW + 4, 36), tier, font=bold, fill=(60, 60, 60))
    col = {"keep": (40, 150, 70), "recolour": (230, 130, 20), "cut": (210, 40, 40)}
    for z in range(1, 11):
        y0 = 60 + (z - 1) * ROW
        fish = [o for o in out if int(o["zone"]) == z]
        d.text((10, y0 + 40), f"{z}. {fish[0]['land']}", font=bold, fill=(20, 20, 20))
        d.rectangle([X0, y0 + 4, W - 20, y0 + ROW - 8], outline=(210, 205, 195))

        def yy(L):
            return y0 + 4 + (100 - L) / 100 * (ROW - 12)

        fl = float(fish[0]["floor_L"])
        d.line([X0, yy(fl), W - 20, yy(fl)], fill=(20, 20, 20), width=2)
        per = {}
        for o in fish:
            t = TIERS.index(o["tier"])
            k = per.get(t, 0)
            per[t] = k + 1
            x = X0 + t * XW + 16 + k * 26
            L = float(o["median_L"])
            c = tuple(int(o["main"][i:i + 2], 16) for i in (1, 3, 5))
            d.ellipse([x - 7, yy(L) - 7, x + 7, yy(L) + 7], fill=c, outline=col[o["verdict"]], width=3)
            d.text((x - 10, yy(L) + 8), o["name"][:9], font=font, fill=col[o["verdict"]])
            if o["verdict"] == "recolour" and "toward" in o["change"]:
                try:
                    want = float(o["change"].split("toward ")[1].split()[0].strip(",)"))
                    d.line([x, yy(L), x, yy(want)], fill=col["recolour"], width=2)
                    d.polygon([(x - 4, yy(want) + (4 if want > L else -4)), (x + 4, yy(want) + (4 if want > L else -4)), (x, yy(want))], fill=col["recolour"])
                except (ValueError, IndexError):
                    pass
    im.save(os.path.join(ROOT, "docs", "attachments", "fish-verdict.jpg"), quality=90)
    from collections import Counter
    print(Counter(o["verdict"] for o in out), path)


if __name__ == "__main__":
    main()
