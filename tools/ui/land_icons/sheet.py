"""The options sheets for the land strip's icons (task u1; options only, nothing in the game changes).
    python tools/ui/land_icons/sheet.py
writes docs/attachments/land-icons-options-1.png (every treatment A to F and today's strip as "Now", each in place over
a capture of the game and zoomed) and docs/attachments/land-icons-framings.jpg (every capture per land, 1a, 1c, ...,
with the crop the options use marked).
The game capture (land-icons/game_nostrip.jpg) has the HUD at about 1.94 screen pixels to one GUI pixel: the strip
there was 560 pixels for its 289 GUI pixels. The options are drawn at that scale in place, and at 1 (real GUI pixels).
"""
from pathlib import Path

from PIL import Image, ImageDraw

import icons

ROOT = icons.ROOT
ATT = ROOT / "docs" / "attachments"
LI = ATT / "land-icons"
GUI = 1.94  # screen pixels per GUI pixel in the game capture
STRIP_CX, STRIP_TOP = 990, 18  # the old strip's middle and its tiles' top, in the cropped capture
CURRENT = 3  # the capture is in the Kelp Forest: lands 1 and 2 done, 3 the one you're in, 4 to 10 not reached
BG = (22, 24, 30)
CARD = (34, 37, 46)
WHITE = (236, 238, 242)
GREY = (170, 174, 184)
GOLD = (255, 220, 90)
W = 2000
F_BIG, F_HEAD, F_NOTE, F_TAG = icons.font(56), icons.font(26), icons.font(19), icons.font(17)

NOTES = {
    "A": "28 px, same footprint as today. Reads best of all at real size: one strong frame, the picture big inside it.",
    "B": "30 px round. Friendly; the circle cuts the picture's corners, so a picture needs its subject in the middle.",
    "C": "28 x 34 px, taller than today. The name is only legible from about 2x up; on a phone it would show numbers.",
    "D": "30 x 32 px, the hexes nest. Ties the strip to the stud bricks of the map and the HUD; picture area is the smallest.",
    "E": "44 x 24 px: the strip grows to about 460 GUI px (today 289), over half a phone's width. The wide picture reads best.",
    "F": "30 px. The name band eats a third of the picture; on a phone the band would carry the number instead.",
}


def text(d, xy, s, f, fill=WHITE, **k):
    d.text(xy, s, font=f, fill=fill, **k)


def badge(img, x, y, s):
    """Today's marker under the land you are in: the blue badge and the metres pill (drawn plainly, for context)."""
    d = ImageDraw.Draw(img)
    r = 7 * s
    d.ellipse((x - r, y - r, x + r, y + r), fill=(61, 139, 240), outline=(141, 240, 106), width=round(2.5 * s))
    f = icons.font(10 * s)
    t = "51 m"
    tw = d.textlength(t, font=f)
    d.rounded_rectangle((x - tw / 2 - 7 * s, y + 10 * s, x + tw / 2 + 7 * s, y + 24 * s), 7 * s, fill=(30, 52, 40), outline=icons.INK, width=round(2 * s))
    d.text((x, y + 17 * s), t, font=f, fill=WHITE, anchor="mm")


def in_place(code):
    """The game capture with option `code`'s strip where today's is; returns the top band of it."""
    game = Image.open(LI / "game_nostrip.jpg").convert("RGBA")
    strip = icons.strip(code, CURRENT, GUI)
    w, h = icons.SIZES[code]
    x0 = STRIP_CX - strip.width // 2
    game.alpha_composite(strip, (x0, STRIP_TOP - round((strip.height - h * GUI) / 2) + 4))
    # the badge under the current tile
    step = (w + icons.GAPS[code]) * GUI
    tiles_w = 10 * w * GUI + 9 * icons.GAPS[code] * GUI
    cx = STRIP_CX - tiles_w / 2 + (CURRENT - 1) * step + w * GUI * 0.5
    badge(game, cx, STRIP_TOP + h * GUI + 6, GUI)
    return game.convert("RGB")


def band(img, h=210, w=1180):
    x = STRIP_CX - w // 2
    return img.crop((x, 0, x + w, h))


def on_dark(im, pad=10, colour=(28, 64, 104)):
    out = Image.new("RGB", (im.width + 2 * pad, im.height + 2 * pad), colour)
    out.paste(im, (pad, pad), im)
    return out


def row_done(code, scale):
    """All ten as 'done' (every picture shown) in a row."""
    ims = [icons.icon(code, i, "done", scale) for i in range(1, 11)]
    gap = 6
    out = Image.new("RGBA", (sum(i.width for i in ims) + gap * 9, max(i.height for i in ims)), (0, 0, 0, 0))
    x = 0
    for i in ims:
        out.alpha_composite(i, (x, (out.height - i.height) // 2))
        x += i.width + gap
    return out


def states(code, land, scale):
    ims = [(s, icons.icon(code, land, s, scale)) for s in ("locked", "current", "done")]
    return ims


def option_card(code):
    shot = band(in_place(code))
    real = on_dark(icons.strip(code, CURRENT, 1))
    zoom = on_dark(icons.strip(code, CURRENT, 3))
    every = on_dark(row_done(code, 2.4))
    st = states(code, 4, 4 if icons.SIZES[code][0] <= 30 else 3)
    height = 3000  # laid out on a tall card, then cut to what was used
    card = Image.new("RGB", (W - 32, height), CARD)
    d = ImageDraw.Draw(card)
    text(d, (16, 8), code, F_BIG, GOLD)
    text(d, (72, 12), icons.TITLES[code], F_HEAD)
    text(d, (72, 44), NOTES[code], F_NOTE, GREY)
    y = 76
    card.paste(shot, (16, y))
    text(d, (16 + 6, y + shot.height - 26), "in place, over the game (desktop size)", F_TAG, WHITE, stroke_width=2, stroke_fill=(0, 0, 0))
    # right of the capture: real size, then the three states of one land, big
    rx = 16 + shot.width + 24
    text(d, (rx, y), "real size (1 GUI px = 1 px)", F_TAG, GREY)
    card.paste(real, (rx, y + 24))
    sy = y + 24 + real.height + 22
    text(d, (rx, sy), f"the three states, land 4, at {4 if icons.SIZES[code][0] <= 30 else 3}x", F_TAG, GREY)
    x = rx
    for name, im in st:
        bgc = on_dark(im, 8)
        card.paste(bgc, (x, sy + 26))
        text(d, (x + bgc.width // 2, sy + 30 + bgc.height + 4), name, F_TAG, WHITE, anchor="mt")
        x += bgc.width + 14
    states_end = sy + 30 + bgc.height + 28
    zoom_w = 16 + zoom.width
    y = (max(y + shot.height, states_end) if zoom_w > 16 + shot.width else y + shot.height) + 14
    text(d, (16, y), "3x: lands 1-2 done, 3 current (a size up), 4-10 not reached", F_TAG, GREY)
    card.paste(zoom, (16, y + 24))
    y += 24 + zoom.height + 12
    text(d, (16, y), "every land's picture (done state, 2.4x)", F_TAG, GREY)
    card.paste(every, (16, y + 24))
    return card.crop((0, 0, card.width, y + 24 + every.height + 14))


def now_card():
    game = Image.open(LI / "game_hud.jpg").convert("RGB")
    shot = game.resize((1180, round(game.height * 1180 / game.width)), Image.LANCZOS)  # the whole screen, for context
    card = Image.new("RGB", (W - 32, 76 + shot.height + 16), CARD)
    d = ImageDraw.Draw(card)
    text(d, (16, 8), "Now", F_BIG, GOLD)
    text(d, (150, 12), "Today's strip: a flat tile in each land's colour, its name (numbers on a phone)", F_HEAD)
    text(d, (150, 44), "The capture every option is laid over (Play in Studio, Kelp Forest, 51 m), shown whole and small here; the options show its top at full size.", F_NOTE, GREY)
    card.paste(shot, (16, 76))
    zoom = band(game).crop((590 - 290, 0, 590 + 290, 100))
    zoom = zoom.resize((zoom.width * 2 // 2 * 1, zoom.height), Image.LANCZOS)
    big = zoom.resize((round(zoom.width * 1.2), round(zoom.height * 1.2)), Image.LANCZOS)
    x = 16 + shot.width + 24
    text(d, (x, 76), "zoomed", F_TAG, GREY)
    card.paste(big.crop((0, 0, min(big.width, card.width - x - 16), big.height)), (x, 100))
    return card


def options_sheet():
    cards = [now_card()] + [option_card(c) for c in "ABCDEF"]
    head = 120
    H = head + sum(c.height + 16 for c in cards) + 16
    out = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(out)
    text(d, (16, 14), "Ride a Fish: the land strip with a picture of each land (options; pick a letter)", icons.font(34), GOLD)
    text(d, (16, 62), "Every picture is a capture of our own map in Play, with that land's water and fog. The pictures per land "
         "can be picked separately (land-icons-framings.jpg). Not in the game: Hugo picks first.", F_NOTE, GREY)
    y = head
    for c in cards:
        out.paste(c, (16, y))
        y += c.height + 16
    out.save(ATT / "land-icons-options-1.png", optimize=True)
    return out.size


DROPPED = {  # captures taken and thrown out, with why (shown in their place on the framings sheet)
    "1b": "dropped: the camera was at the surface (all white)",
    "9b": "dropped: a big rock filled the view",
    "7f": "dropped: a plain grey boulder",
    "10g": "dropped: too close to read",
}
LETTERS = "abcdefg"


def framings_sheet():
    picks = icons.picks()
    TW = 330
    rows = {}
    for land in range(1, 11):
        for letter in LETTERS:
            tag = f"{land}{letter}"
            p = LI / f"land{land:02d}{letter}.jpg"
            if p.exists():
                im = Image.open(p).convert("RGB")
                th = im.resize((TW, round(TW * im.height / im.width)), Image.LANCZOS)
                d = ImageDraw.Draw(th)
                k = th.width / im.width
                pick = picks.get(str(land))
                chosen = bool(pick and pick[0] == letter)
                if chosen:
                    _, cx, cy, side = pick
                    s = side * im.height * k
                    d.rectangle((cx * th.width - s / 2, cy * th.height - s / 2, cx * th.width + s / 2, cy * th.height + s / 2), outline=GOLD, width=3)
            elif tag in DROPPED:
                th = Image.new("RGB", (TW, round(TW * 755 / 1486)), (44, 46, 56))
                d = ImageDraw.Draw(th)
                words = DROPPED[tag].split(": ")
                d.text((TW / 2, th.height / 2 - 12), words[0], font=icons.font(20), fill=GREY, anchor="mm")
                d.text((TW / 2, th.height / 2 + 14), words[1], font=icons.font(15), fill=GREY, anchor="mm")
                chosen = False
            else:
                continue
            d.rounded_rectangle((6, 6, 62, 36), 6, fill=(0, 0, 0))
            d.text((34, 21), tag, font=icons.font(21), fill=GOLD if chosen else WHITE, anchor="mm")
            rows.setdefault(land, []).append(th)
    lw = 250
    th_h = round(TW * 755 / 1486)
    most = max(len(r) for r in rows.values())
    H = 100 + 10 * (th_h + 10)
    out = Image.new("RGB", (lw + most * (TW + 8) + 8, H), BG)
    d = ImageDraw.Draw(out)
    text(d, (16, 14), "Land icons: the pictures per land (answer e.g. \"3c\")", icons.font(30), GOLD)
    text(d, (16, 56), "a, b: two of the land's big assets; c: down the lane; d, e: a and b close up; f: a third asset close up; "
         "g: closer still. Gold frame: the crop the options use. Captured in Play, 2026-11-17.", F_NOTE, GREY)
    y = 100
    for land in range(1, 11):
        text(d, (16, y + 4), f"{land}", icons.font(36), icons.LANDS[land - 1])
        text(d, (60, y + 14), icons.NAMES[land - 1], F_NOTE, WHITE)
        tile = icons.icon("A", land, "done", 3)
        out.paste(tile, (16, y + 46), tile)
        x = lw
        for th in rows[land]:
            out.paste(th, (x, y))
            x += TW + 8
        y += th_h + 10
    out.save(ATT / "land-icons-framings.jpg", quality=88)
    return out.size


if __name__ == "__main__":
    print(options_sheet(), framings_sheet())
