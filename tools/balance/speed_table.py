"""The speed of every creature, land by land, as a picture: python tools/balance/speed_table.py <out.png>

Reads src/shared/Config.luau (Speed, TierMult, SpeciesSpeed) and src/shared/Creatures/*.json, and works the speed out as
Config.speedOf does: Speed.Base x the species' base x the rarity's (TierMult) x the area's (the fish's home land,
Config.areaSpeed: Speed.AreaStep, Speed.AreaGrow) x the variant's (Gold, Rainbow). There is no size roll.

The picture: on top, what a fish of species base 1 does in each land, rarity by rarity (the area's step alone); under
it every creature under its home land, with its speed before the area's factor, its speed now, and Gold and Rainbow.
"""
import glob
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
COLOURS = {"Common": (200, 200, 200), "Uncommon": (90, 220, 90), "Rare": (70, 150, 255), "Epic": (180, 90, 255),
           "Legendary": (255, 190, 40), "Mythic": (255, 70, 90), "Secret": (150, 150, 160)}
LANDS = 10
SOFT = (170, 190, 210)


def table(src, name):
    body = re.search(r"Config\." + name + r"\s*=\s*\{(.*?)\n\}", src, re.S).group(1)
    return {k: float(v) for k, v in re.findall(r"^\t(\w+)\s*=\s*(-?[\d.]+)", body, re.M)}


def area(speed, land):
    """Config.areaSpeed: x1 in land 1, each land's step bigger than the last"""
    n = max(land, 1) - 1
    return 1 + speed.get("AreaStep", 0) * n + speed.get("AreaGrow", 0) * n * (n - 1) / 2


def load():
    src = open(os.path.join(ROOT, "src/shared/Config.luau"), encoding="utf-8").read()
    speed, mult, species = (table(src, n) for n in ("Speed", "TierMult", "SpeciesSpeed"))
    rows = []
    for path in glob.glob(os.path.join(ROOT, "src/shared/Creatures/*.json")):
        d = json.load(open(path, encoding="utf-8"))
        fid = os.path.basename(path)[:-5]
        base = species.get(fid, 1.0)
        before = speed["Base"] * mult[d["Tier"]] * base
        rows.append({"id": fid, "name": d["Name"], "tier": d["Tier"], "land": d["Zone"], "base": base,
                     "before": before, "now": before * area(speed, d["Zone"])})
    rows.sort(key=lambda r: (r["land"], TIERS.index(r["tier"]), -r["base"], r["name"]))
    return speed, mult, species, rows


def main(out):
    speed, mult, species, rows = load()
    missing = [r["name"] for r in rows if r["id"] not in species]

    font = ImageFont.truetype("DejaVuSans.ttf", 15)
    bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
    big = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    row_h, col_w, left = 22, 730, 20
    # the creatures in two columns, a heading line before each land
    lines = []
    for land in range(1, LANDS + 1):
        lines.append(("land", land))
        lines.extend(("fish", r) for r in rows if r["land"] == land)
    half = next(i for i, line in enumerate(lines) if line[0] == "land" and i >= len(lines) / 2 - 4)
    columns = [lines[:half], lines[half:]]
    grid_top = 112
    list_top = grid_top + (len(TIERS) + 4) * row_h + 56
    height = list_top + max(len(c) for c in columns) * row_h + 30
    img = Image.new("RGB", (col_w * 2 + 40, height), (18, 24, 34))
    draw = ImageDraw.Draw(img)
    draw.text((left, 14), "Ride a Fish: speed of every creature by land (studs a second, ridden)", font=big, fill="white")
    draw.text((left, 46), "speed = %g x species x rarity x area x variant (Gold %g, Rainbow %g). No size roll. The herd swims"
              " at 0.85 of it." % (speed["Base"], speed["Gold"], speed["Rainbow"]), font=font, fill=SOFT)
    draw.text((left, 68), "area: a fish's home land n is x(1 + %g(n-1) + %g(n-1)(n-2)/2): the first step is +%g, each step"
              " after %g bigger (of the land 1 speed). White mark on a bar: the speed before." % (
                  speed["AreaStep"], speed["AreaGrow"], speed["AreaStep"], speed["AreaGrow"]),
              font=font, fill=SOFT)

    # the grid: a species of base 1, by rarity and land
    cell = 104
    draw.text((left, grid_top - 4), "A fish of species base 1, in each land", font=bold, fill="white")
    y = grid_top + row_h
    draw.text((left, y), "land", font=bold, fill=SOFT)
    draw.text((left, y + row_h), "area", font=bold, fill=SOFT)
    draw.text((left, y + 2 * row_h), "step", font=bold, fill=SOFT)
    for land in range(1, LANDS + 1):
        x = left + 130 + (land - 1) * cell
        k = area(speed, land)
        draw.text((x, y), str(land), font=bold, fill=SOFT)
        draw.text((x, y + row_h), "x%.2f" % k, font=font, fill=SOFT)
        if land > 1:
            draw.text((x, y + 2 * row_h), "+%.2f" % (k - area(speed, land - 1)), font=font, fill=SOFT)
    for i, tier in enumerate(TIERS):
        ty = y + (i + 3) * row_h
        draw.text((left, ty), tier, font=bold, fill=COLOURS[tier])
        for land in range(1, LANDS + 1):
            x = left + 130 + (land - 1) * cell
            has = any(r["tier"] == tier and r["land"] == land for r in rows)
            draw.text((x, ty), "%.0f" % (speed["Base"] * mult[tier] * area(speed, land)), font=bold if has else font,
                      fill=COLOURS[tier] if has else (90, 100, 116))
    draw.text((left, y + (len(TIERS) + 3) * row_h + 4), "(grey: no creature of that rarity has its home in that land)",
              font=font, fill=(110, 124, 142))

    top_speed = max(r["now"] for r in rows) * speed["Rainbow"]
    heads = ((0, "creature"), (190, "rarity"), (290, "base"), (340, "before"), (402, "now"), (600, "Gold"), (650, "Rainbow"))
    for c, column in enumerate(columns):
        x = left + c * col_w
        for i, (kind, item) in enumerate(column):
            y = list_top + i * row_h
            if kind == "land":
                draw.rectangle((x, y + 1, x + col_w - 30, y + row_h - 2), fill=(30, 40, 56))
                draw.text((x + 6, y + 1), "Land %d   area x%.2f" % (item, area(speed, item)), font=bold, fill="white")
                for dx, head in heads[2:]:
                    draw.text((x + dx, y + 1), head, font=font, fill=SOFT)
                continue
            r = item
            colour = COLOURS[r["tier"]]
            draw.text((x, y), r["name"], font=font, fill="white")
            draw.text((x + 190, y), r["tier"], font=font, fill=colour)
            draw.text((x + 290, y), "%.2f" % r["base"], font=font,
                      fill=(120, 230, 140) if r["base"] > 1 else (240, 140, 120) if r["base"] < 1 else "white")
            draw.text((x + 340, y), "%.0f" % r["before"], font=font, fill=SOFT)
            draw.text((x + 402, y), "%.0f" % r["now"], font=bold, fill="white")
            bar_x, bar_w = x + 446, 140
            draw.rectangle((bar_x, y + 5, bar_x + bar_w, y + 13), fill=(40, 50, 66))
            draw.rectangle((bar_x, y + 5, bar_x + bar_w * r["now"] / top_speed, y + 13), fill=colour)
            mark = bar_x + bar_w * r["before"] / top_speed
            draw.rectangle((mark - 1, y + 2, mark + 1, y + 16), fill="white")
            draw.text((x + 600, y), "%.0f" % (r["now"] * speed["Gold"]), font=font, fill=(240, 205, 90))
            draw.text((x + 650, y), "%.0f" % (r["now"] * speed["Rainbow"]), font=font, fill=(190, 170, 255))
    img.save(out)

    print("%d creatures; %d with no species base of their own%s" % (len(rows), len(missing), ": " + ", ".join(missing) if missing else ""))
    print("area by land: " + "  ".join("%d x%.2f" % (n, area(speed, n)) for n in range(1, LANDS + 1)))
    print("a species of base 1, land 1 to %d (before the area's factor: the first number in every land):" % LANDS)
    for t in TIERS:
        print("  %-10s " % t + " ".join("%5.0f" % (speed["Base"] * mult[t] * area(speed, n)) for n in range(1, LANDS + 1)))
    print("by home land, the creatures there (plain): slowest to fastest, before -> now")
    for n in range(1, LANDS + 1):
        here = [r for r in rows if r["land"] == n]
        print("  land %-2d %2d creatures  %5.1f to %5.1f  ->  %5.1f to %5.1f" % (
            n, len(here), min(r["before"] for r in here), max(r["before"] for r in here),
            min(r["now"] for r in here), max(r["now"] for r in here)))
    fastest = max(rows, key=lambda r: r["now"])
    print("fastest: %s %.0f plain, %.0f Gold, %.0f Rainbow" % (fastest["name"], fastest["now"],
                                                              fastest["now"] * speed["Gold"], fastest["now"] * speed["Rainbow"]))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "speed_table.png")
