"""The speed of every creature as a picture: python tools/balance/speed_table.py <out.png>

Reads src/shared/Config.luau (Speed, TierMult, SpeciesSpeed, Size) and src/shared/Creatures/*.json. For each creature:
its species base, its ridden speed at size 1, and the range from the smallest plain fish to the biggest Rainbow.
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


def table(src, name):
    body = re.search(r"Config\." + name + r"\s*=\s*\{(.*?)\n\}", src, re.S).group(1)
    return {k: float(v) for k, v in re.findall(r"^\t(\w+)\s*=\s*(-?[\d.]+)", body, re.M)}


def main(out):
    src = open(os.path.join(ROOT, "src/shared/Config.luau"), encoding="utf-8").read()
    speed, mult, species, size = (table(src, n) for n in ("Speed", "TierMult", "SpeciesSpeed", "Size"))
    rows = []
    for path in glob.glob(os.path.join(ROOT, "src/shared/Creatures/*.json")):
        d = json.load(open(path, encoding="utf-8"))
        fid = os.path.basename(path)[:-5]
        base = species.get(fid, 1.0)
        at1 = speed["Base"] * mult[d["Tier"]] * base
        low = at1 * (1 + speed["SizeGain"] * (size["Min"] - 1))
        high = at1 * (1 + speed["SizeGain"] * (size["Max"] - 1)) * speed["Rainbow"]
        rows.append((TIERS.index(d["Tier"]), -base, d["Name"], d["Tier"], d["Zone"], base, at1, low, high))
    rows.sort()
    missing = [r[2] for r in rows if r[5] == 1.0 and r[2].replace(" ", "") not in species]

    font = ImageFont.truetype("DejaVuSans.ttf", 15)
    bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
    big = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    half = (len(rows) + 1) // 2
    row_h, col_w, top = 22, 660, 96
    img = Image.new("RGB", (col_w * 2 + 40, top + half * row_h + 30), (18, 24, 34))
    draw = ImageDraw.Draw(img)
    draw.text((20, 14), "Ride a Fish: speed of every creature (studs a second, ridden)", font=big, fill="white")
    draw.text((20, 46), "speed = %g x species x rarity x (1 + %g x (size - 1)) x variant (Gold %g, Rainbow %g); size %g to %g;"
              " the herd swims at 0.85 of it" % (speed["Base"], speed["SizeGain"], speed["Gold"], speed["Rainbow"],
                                                size["Min"], size["Max"]), font=font, fill=(170, 190, 210))
    top_speed = max(r[8] for r in rows)
    for i, (_, _, name, tier, zone, base, at1, low, high) in enumerate(rows):
        x = 20 + (i // half) * col_w
        y = top + (i % half) * row_h
        if i % half == 0:
            for dx, head in ((0, "creature"), (190, "rarity"), (275, "land"), (320, "base"), (372, "x1"), (420, "smallest to big Rainbow")):
                draw.text((x + dx, y - 24), head, font=bold, fill=(170, 190, 210))
        colour = COLOURS[tier]
        draw.text((x, y), name, font=font, fill="white")
        draw.text((x + 190, y), tier, font=font, fill=colour)
        draw.text((x + 280, y), str(zone), font=font, fill=(170, 190, 210))
        draw.text((x + 320, y), "%.2f" % base, font=font, fill=(120, 230, 140) if base > 1 else (240, 140, 120) if base < 1 else "white")
        draw.text((x + 372, y), "%.0f" % at1, font=bold, fill="white")
        bar_x, bar_w = x + 420, 150
        draw.rectangle((bar_x, y + 5, bar_x + bar_w, y + 13), fill=(40, 50, 66))
        draw.rectangle((bar_x + bar_w * low / top_speed, y + 5, bar_x + bar_w * high / top_speed, y + 13), fill=colour)
        mark = bar_x + bar_w * at1 / top_speed
        draw.rectangle((mark - 1, y + 2, mark + 1, y + 16), fill="white")
        draw.text((bar_x + bar_w + 8, y), "%.0f-%.0f" % (low, high), font=font, fill=(170, 190, 210))
    img.save(out)
    print("%d creatures; %d with no species base of their own%s" % (len(rows), len(missing), ": " + ", ".join(missing) if missing else ""))
    for t in TIERS:
        at = [r[6] for r in rows if r[3] == t]
        print("  %-10s x%.2f  %5.1f to %5.1f at size 1 (mean %.1f, %d creatures)" % (t, mult[t], min(at), max(at), sum(at) / len(at), len(at)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "speed_table.png")
