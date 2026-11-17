"""The sheet and GIF of the new land strip, style A (task l1), from strip_capture.py's shots (work/land_icons/strip/).
    python tools/ui/land_icons/strip_sheet.py
writes docs/attachments/land-strip-A-options-1.png and docs/attachments/land-strip-A-1.gif.
Every strip on the sheet is a capture of the game's own code (Client.UI.LandStrip, style 1) in a Studio playtest:
the 3x ones through a UIScale, the real-size ones at 1 GUI pixel to 1 screen pixel.
"""
from pathlib import Path

from PIL import Image, ImageDraw

import icons

ROOT = icons.ROOT
SH = ROOT / "work/land_icons/strip"
ATT = ROOT / "docs/attachments"
BG = (22, 24, 30)
CARD = (34, 37, 46)
WHITE = (236, 238, 242)
GREY = (165, 170, 182)
GOLD = (255, 220, 90)
BIG = (500, 40, 1530, 320)  # the 3x strip in a preview shot
SMALL = (800, 355, 1210, 450)  # the real-size one
W = 2000
F = icons.font


def im(name):
    return Image.open(SH / f"{name}.png").convert("RGB")


def card(img, y, h):
    ImageDraw.Draw(img).rounded_rectangle((16, y, W - 16, y + h), 14, fill=CARD)


def main():
    rows = []
    img = Image.new("RGB", (W, 5200), BG)
    d = ImageDraw.Draw(img)
    d.text((28, 20), "Ride a Fish: the land strip in style A (the new strip, in the game's own code)", font=F(40), fill=GOLD)
    d.text((28, 76), "Hugo: \"use first style, but remove the inner border, make the numbers more stylised to each map part ... a round icon of "
           "the player right below ... a meter bar right under ...", font=F(18), fill=GREY)
    d.text((28, 100), "... slowly reveal the fully color map icon over the locked grey icon ... a yellow striped line connected to a meter "
           "number saying best\".", font=F(18), fill=GREY)
    d.text((28, 124), "Every strip below is a Studio capture of LandStrip.luau's style 1 (off by default: Kit.LandStripStyle). The pictures are "
           "round one's picks until you choose from the selection sheets; they are not uploaded yet.", font=F(18), fill=GREY)
    y = 170

    # 1. the numbers
    top1 = y
    d.text((40, y + 16), "1. The numbers: pick N1, N2 or N3", font=F(32), fill=WHITE)
    d.text((40, y + 58), "Gotham Black, ink edge, still readable at real size. Left: in the Kelp Forest (lands 1-2 done, 3 half way, 4-10 locked, "
           "the number grey there). Right: every land reached, every number lit.", font=F(18), fill=GREY)
    notes = {
        1: "N1 Metal: each number in its land's colour as a gradient (light top, colour, darker foot).",
        2: "N2 Material: each land's own stuff: sun on sand, banded coral, kelp ribs, a plank seam, water, dusk, "
           "a glowing lure edge, lava with a glow, bone, embers.",
        3: "N3 Badge: a white number on a small sign of its land: sun, coral head, kelp leaf, porthole, bubble, star, "
           "lure, flame, bone, horns.",
    }
    yy = y + 96
    for n in (1, 2, 3):
        d.text((40, yy), f"N{n}", font=F(44), fill=GOLD)
        d.text((120, yy + 12), notes[n], font=F(19), fill=WHITE)
        a = im(f"num_N{n}").crop(BIG)
        b = im(f"num_N{n}_all").crop(BIG)
        a = a.resize((a.width * 9 // 10, a.height * 9 // 10), Image.LANCZOS)
        b = b.resize(a.size, Image.LANCZOS)
        img.paste(a, (40, yy + 46))
        img.paste(b, (40 + a.width + 30, yy + 46))
        s = im(f"num_N{n}").crop(SMALL)
        img.paste(s, (40, yy + 46 + a.height + 24))
        d.text((40, yy + 46 + a.height + 2), "real size (1 GUI px = 1 px)", font=F(15), fill=GREY)
        s = im(f"num_N{n}_all").crop(SMALL)
        img.paste(s, (40 + a.width + 30, yy + 46 + a.height + 24))
        yy += a.height + 180
    y = yy + 20
    # 2. the reveal
    card(img, y, 740)
    d.text((40, y + 16), "2. What colours the pictures in: Dive (the Boss's reading) or Best (the alternative)", font=F(32), fill=WHITE)
    d.text((40, y + 58), "Your best here: 108 m, four tenths into the Open Blue (land 5). Dive: the colour follows this dive, so every dive "
           "starts grey and fills in as you go;", font=F(18), fill=GREY)
    d.text((40, y + 80), "the best line shows how far you got before. Best: lands you have ever reached stay in colour.", font=F(18), fill=GREY)
    yy = y + 100
    for mode in ("Dive", "Best"):
        d.text((40, yy), mode, font=F(36), fill=GOLD)
        for k, (state, label) in enumerate((("start", "a dive's first metre"), ("past", "past the best, a third into Twilight"))):
            c = im(f"rev_{mode}_{state}").crop(BIG)
            c = c.resize((c.width * 85 // 100, c.height * 85 // 100), Image.LANCZOS)
            x = 150 + k * (c.width + 20)
            img.paste(c, (x, yy))
            d.text((x, yy + c.height + 2), label, font=F(16), fill=GREY)
        yy += 290
    y += 720 + 40

    # 3. in the game, desktop
    games = [SH / f"game_{k}.png" for k in (2, 3, 4)]
    card(img, y, 1420)
    d.text((40, y + 16), "3. In the game, desktop: a real ride down the lane (Studio, sandbox, endless air)", font=F(32), fill=WHITE)
    d.text((40, y + 58), "Your avatar slides along under the strip with the metres; the land you are in is a size up with a white rim; "
           "its picture colours in as you go; BEST is the server's furthest (BestService), pushed along by this ride.",
           font=F(18), fill=GREY)
    yy = y + 96
    for k, g in enumerate(games):
        c = Image.open(g).convert("RGB").resize((940, 505), Image.LANCZOS)
        img.paste(c, (40 + (k % 2) * 960, yy + (k // 2) * 520))
    z = Image.open(games[1]).convert("RGB").crop((690, 0, 1300, 160))
    z = z.resize((z.width * 3 // 2, z.height * 3 // 2), Image.LANCZOS)
    img.paste(z, (1000 + (940 - z.width) // 2, yy + 520 + 40))
    d.text((1000, yy + 528), "the strip in the frame on the right, 1.5x (Midnight, 1,000 m)", font=F(17), fill=GREY)
    y += 1440

    # 4. phone width
    card(img, y, 1000)
    d.text((40, y + 16), "4. Phone width (844 x 390, HUD scale 1): the top of the screen, each number style", font=F(32), fill=WHITE)
    d.text((40, y + 58), "On a phone the metres bar also names the land. The strip is 298 GUI px of the 844 (35 %). The rest of the HUD is "
           "hidden in these frames; the water is the game's, mid-ride.", font=F(18), fill=GREY)
    yy = y + 96
    for k, n in enumerate((1, 2, 3)):
        p = im(f"phone_N{n}")
        cx = 991
        c = p.crop((cx - 422, 150, cx + 422, 540))
        c = c.resize((c.width * 105 // 100, c.height * 105 // 100), Image.LANCZOS)
        x = 40 + (k % 2) * 960
        img.paste(c, (x, yy + (k // 2) * 450))
        d.text((x + 8, yy + (k // 2) * 450 + 8), f"N{n}", font=F(26), fill=GOLD)
    y += 1020

    img = img.crop((0, 0, W, y + 10))
    out = ATT / "land-strip-A-options-1.png"
    img.save(out)
    print("wrote", out)

    # the GIF: a whole dive, 0 to 10,935 m
    frames = []
    for p in sorted(SH.glob("gif_*.png")):
        c = Image.open(p).convert("RGB").crop(BIG)
        frames.append(c.resize((c.width * 7 // 10, c.height * 7 // 10), Image.LANCZOS))
    if frames:
        durations = [180] * len(frames)
        durations[-1] = 1500
        gif = ATT / "land-strip-A-1.gif"
        frames[0].save(gif, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)
        print("wrote", gif, len(frames), "frames")


if __name__ == "__main__":
    main()
