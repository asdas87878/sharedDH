"""The two pictures for the user, from the fits (run fit.py first):
    python tools/saddles/sheet.py options   docs/attachments/saddles-options-1.png
    python tools/saddles/sheet.py fit       docs/attachments/saddles-fit-1.png"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import draw as D
import fish as F
import saddles as S

OUT = os.path.join(F.ROOT, "docs", "attachments")
FITS = json.load(open(os.path.join(D.WORK, "check.json")))
WATER = ["#8fd6de", "#f3c3cc", "#a9d3a0", "#b9c4b0", "#8fc4ea", "#c3c2ea", "#93a3d8", "#c7a39a", "#c3cdb4", "#aaa4e6"]
TYPICAL = [("SeaTurtle", "Normal"), ("HumpheadWrasse", "Normal"), ("KelpWyrm", "Normal"), ("Xiphactinus", "Normal"), ("Elasmosaurus", "Normal"),
           ("GoblinShark", "Normal"), ("FrilledShark", "Big"), ("EmberSerpent", "Normal"), ("SkullAngler", "Normal"), ("InfernalAngler", "Normal")]


def font(n, bold=True):
    for p in ("/usr/share/fonts/TTF/DejaVuSans%s.ttf" % ("-Bold" if bold else ""), "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if bold else "")):
        if os.path.exists(p):
            return ImageFont.truetype(p, n)
    return ImageFont.load_default(n)


def on_fish(key, id, tier):
    f = F.load(id)
    s = f.scale(tier)
    at = f.seat * s
    fit = FITS[id][tier]["fit"]
    return {"fish": [{"npz": D.fish_npz(f, s)}], "parts": D.place(S.build(S.design(key), fit), at) + D.rider_parts(at)}, at, fit, f, s


def words(d, xy, text, size, fill=(20, 26, 40), bold=True, plate=None):
    f = font(size, bold)
    if plate:
        b = d.textbbox(xy, text, font=f)
        d.rounded_rectangle((b[0] - 12, b[1] - 8, b[2] + 12, b[3] + 8), 10, fill=plate)
    d.text(xy, text, font=f, fill=fill)


def options():
    W1, W2, H, HEAD = 640, 980, 700, 70
    scenes, shots = {}, []
    for key in S.DESIGNS:
        land = int(key[:-1])
        id, tier = TYPICAL[land - 1]
        scenes["a" + key] = {"fish": [], "parts": D.place(S.build(S.design(key), S.plain()), (0, 0, 0))}
        shots.append(D.shot("a" + key, "o_a" + key, (5.2, 4.6, 8.2), (0, 0.15 + (0.45 if key in ("10B", "3B") else 0), 0.0), W1 * 3 // 2, H * 3 // 2, fov=40 if key != "10B" else 43))
        sc, at, fit, f, s = on_fish(key, id, tier)
        scenes["f" + key] = sc
        far = 1.0 + 0.16 * (fit["grow"] - 1)
        r = float(np.linalg.norm(f.size * s))
        shots.append(D.shot("f" + key, "o_w" + key, np.array([0.62, 0.42, 0.75]) * r * 1.4, (0, 0, 0), 480, 360, fov=33))
        shots.append(D.shot("f" + key, "o_f" + key, at + np.array([7.4, 5.2, 10.2]) * far, at + np.array([0, 1.0, 0.2]), W2 * 3 // 2, H * 3 // 2, fov=35))
    D.render(scenes, shots, "opt")
    W = 2 * (W1 + W2) + 5 * 20
    top = 130
    im = Image.new("RGB", (W, top + 10 * (H + HEAD + 24) + 20), (247, 248, 250))
    d = ImageDraw.Draw(im)
    words(d, (30, 26), "Saddles: two for each land (A and B), alone and on a fish of that land with a rider", 48)
    for land in range(1, 11):
        y = top + (land - 1) * (H + HEAD + 24)
        id, tier = TYPICAL[land - 1]
        words(d, (30, y + 8), f"{land}  {F.LANDS[land - 1]}", 44)
        words(d, (620, y + 18), f"on: {F.load(id).name} ({tier})", 30, (90, 96, 110), False)
        for j, o in enumerate("AB"):
            key = f"{land}{o}"
            x = 20 + j * (W1 + W2 + 40)
            rec = S.RECOMMENDED.get(land) == o
            d.rounded_rectangle((x, y + HEAD, x + W1 + W2 + 20, y + HEAD + H), 22, fill=WATER[land - 1], outline=(255, 190, 0) if rec else None, width=12)
            n, tris = S.count(S.build(S.design(key), S.plain()))
            for tag, w, xx in (("a", W1, x), ("f", W2, x + W1 + 20)):
                p = Image.open(os.path.join(D.WORK, f"o_{tag}{key}.png")).resize((w, H), Image.LANCZOS)
                im.paste(p, (xx, y + HEAD), p)
            xx = x + W1 + 20 + W2 - 250
            d.rounded_rectangle((xx, y + HEAD + 24, xx + 226, y + HEAD + 192), 14, fill=(255, 255, 255))
            p = Image.open(os.path.join(D.WORK, f"o_w{key}.png")).resize((220, 165), Image.LANCZOS)
            im.paste(p, (xx + 3, y + HEAD + 26), p)
            if rec:
                d.rounded_rectangle((x, y + HEAD, x + W1 + W2 + 20, y + HEAD + H), 22, outline=(255, 190, 0), width=12)
            words(d, (x + 34, y + HEAD + 26), key, 78, plate=(255, 255, 255))
            tx = x + (250 if land > 9 else 190)
            words(d, (tx, y + HEAD + 36), S.DESIGNS[key][0] + ("   recommended" if rec else ""), 36, (20, 26, 40))
            words(d, (tx, y + HEAD + 84), f"{n} parts, about {tris} triangles", 26, (50, 56, 70), False)
    im.save(os.path.join(OUT, "saddles-options-1.png"), optimize=True)
    print(im.size)


# 12 very different bodies: (kind, size, note)
BODIES = [("Clownfish", "Tiny", "smallest fish"), ("BlueWhale", "Colossal", "biggest fish"), ("MantaRay", "Normal", "ray"), ("MorayEel", "Normal", "eel"),
          ("Octopus", "Normal", "octopus"), ("GiantIsopod", "Big", "crawler"), ("Seahorse", "Big", "seahorse"), ("AuroraJelly", "Normal", "jelly"),
          ("Archelon", "Normal", "shell with a ridge"), ("Pufferfish", "Normal", "round"), ("Hellmaw", "Normal", "cracked back, bridged; from the front"), ("VoidWhale", "Giant", "glowing ridge down the back")]


VIEW = {"Hellmaw": [-5.6, 9.4, -7.6]}  # (its tall back fin hides the saddle from behind)


def fit_sheet():
    W, H, HEAD = 1040, 800, 84
    scenes, shots = {}, []
    for id, tier, note in BODIES:
        f = F.load(id)
        land = f.zone
        key = f"{land}{S.RECOMMENDED[land]}"
        sc, at, fit, f, s = on_fish(key, id, tier)
        n = "b" + id
        scenes[n] = sc
        far = 1.0 + 0.2 * (fit["grow"] - 1)
        shots.append(D.shot(n, "b_c" + id, at + np.array(VIEW.get(id, [7.0, 5.4, 9.2])) * far, at + np.array([0, 0.8, 0.2]), W * 3 // 2, H * 3 // 2, fov=35))
        r = float(np.linalg.norm(f.size * s))
        shots.append(D.shot(n, "b_w" + id, np.array([0.62, 0.42, 0.75]) * r * 1.4, (0, 0, 0), 480, 360, fov={"Clownfish": 44, "AuroraJelly": 38}.get(id, 33)))
    D.render(scenes, shots, "fit")
    top = 130
    im = Image.new("RGB", (3 * (W + 20) + 20, top + 4 * (H + HEAD + 20) + 20), (247, 248, 250))
    d = ImageDraw.Draw(im)
    words(d, (30, 26), "The recommended saddle on 12 very different bodies (whole fish in the corner)", 48)
    for i, (id, tier, note) in enumerate(BODIES):
        x, y = 20 + (i % 3) * (W + 20), top + (i // 3) * (H + HEAD + 20)
        f = F.load(id)
        key = f"{f.zone}{S.RECOMMENDED[f.zone]}"
        words(d, (x + 8, y + 4), f"{f.name} ({tier})", 40)
        words(d, (x + 8, y + 50), f"{note}: saddle {key} {S.DESIGNS[key][0]}", 26, (80, 86, 100), False)
        d.rounded_rectangle((x, y + HEAD, x + W, y + HEAD + H), 22, fill=WATER[f.zone - 1])
        p = Image.open(os.path.join(D.WORK, f"b_c{id}.png")).resize((W, H), Image.LANCZOS)
        im.paste(p, (x, y + HEAD), p)
        d.rounded_rectangle((x + W - 330, y + HEAD + 14, x + W - 14, y + HEAD + 254), 14, fill=(255, 255, 255))
        p = Image.open(os.path.join(D.WORK, f"b_w{id}.png")).resize((312, 234), Image.LANCZOS)
        im.paste(p, (x + W - 328, y + HEAD + 17), p)
    im.save(os.path.join(OUT, "saddles-fit-1.png"), optimize=True)
    print(im.size)


if __name__ == "__main__":
    {"options": options, "fit": fit_sheet}[sys.argv[1]]()
