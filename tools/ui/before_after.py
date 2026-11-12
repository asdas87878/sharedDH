"""The dive's HUD before and after pieces 3 and 4, side by side, from captures of the game (docs/attachments).
    python tools/ui/before_after.py docs/attachments/ui4-before-after.jpg
Every capture is 1548 by 841 at the same HUD size, so the crops are to the same scale.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SHOTS = Path(__file__).resolve().parents[2] / "docs" / "attachments"
BG = (22, 24, 30)
CARD = (34, 37, 46)
RED = (255, 122, 122)
GREEN = (140, 232, 120)
BLUE = (140, 200, 255)
WHITE = (236, 238, 242)
GREY = (170, 174, 184)
W = 2000
PAD = 16


def font(size, bold=True):
    return ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf", size)


F_TITLE, F_HEAD, F_TAG, F_NOTE = font(30), font(19), font(15), font(15, False)
cache = {}


def crop(name, box, zoom):
    if name not in cache:
        cache[name] = Image.open(SHOTS / name).convert("RGB")
    im = cache[name].crop(box)
    return im.resize((round(im.width * zoom), round(im.height * zoom)), Image.LANCZOS)


def card(title, note, parts, zoom=2.0):
    """parts: (tag, colour, capture, box). Returns an image: the title, a line of what changed, the crops in a row."""
    ims = [(tag, colour, crop(name, box, zoom)) for tag, colour, name, box in parts]
    width = sum(im.width for _, _, im in ims) + 10 * (len(ims) - 1) + 24
    probe = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    width = max(width, round(probe.textlength(title, font=F_HEAD)) + 24, round(probe.textlength(note, font=F_NOTE)) + 24)
    height = 12 + 26 + 22 + 22 + max(im.height for _, _, im in ims) + 12
    out = Image.new("RGB", (width, height), CARD)
    d = ImageDraw.Draw(out)
    d.text((12, 10), title, font=F_HEAD, fill=WHITE)
    d.text((12, 36), note, font=F_NOTE, fill=GREY)
    x = 12
    for tag, colour, im in ims:
        d.text((x, 60), tag, font=F_TAG, fill=colour)
        out.paste(im, (x, 82))
        x += im.width + 10
    return out


def flow(cards):
    """Cards left to right, wrapping; returns the rows as (cards, height)."""
    rows, row, x = [], [], PAD
    for c in cards:
        if row and x + c.width > W - PAD:
            rows.append(row)
            row, x = [], PAD
        row.append(c)
        x += c.width + PAD
    if row:
        rows.append(row)
    return rows


def main():
    before, after, new = ("BEFORE", RED), ("AFTER", GREEN), ("NEW", BLUE)
    full = [
        ("BEFORE: riding in the Coral Reef, the HUD as first built", RED, "ui-game-reef-needs.jpg"),
        ("AFTER: riding in the Coral Reef (the world is black: Studio drew no 3D for these shots)", GREEN, "ui-game-p4-riding-best.jpg"),
    ]
    cards = [
        card("The ring beside the rider", "Thick with a clear hole, as Ride a Dino's. No number, no name. The tame ring sits beside it.", [
            (*before, "ui-game-reef-needs.jpg", (930, 345, 1075, 500)),
            (*after, "ui-game-p4-riding-best.jpg", (870, 385, 1065, 510)),
        ]),
        card("The hop button", "A clean arrow in place of the stepped one; a thinner key cap edge.", [
            (*before, "ui-game-reef-needs.jpg", (1335, 628, 1485, 778)),
            (*after, "ui-game-p4-riding-best.jpg", (1335, 628, 1485, 778)),
            ("AFTER, in the hop", GREEN, "ui-game-p4-hop-locked.jpg", (1335, 628, 1485, 778)),
        ]),
        card("Your Oxygen", "A sixth bigger, and level with the slots.", [
            (*before, "ui-game-reef-needs.jpg", (5, 750, 240, 836)),
            (*after, "ui-game-p4-riding-best.jpg", (5, 750, 240, 836)),
        ]),
        card("The strip of lands", "Bigger land names with a thinner outline; BEST stays inside the strip.", [
            (*before, "ui-game-great-dive.jpg", (545, 5, 1020, 95)),
            (*after, "ui-game-p4-riding-best.jpg", (545, 5, 1020, 95)),
        ], 1.8),
        card("A fish too strong, on its tag", "The red plate has a small corner, not a pill. The locked fish says TOO STRONG!", [
            (*before, "ui-game-reef-needs.jpg", (1250, 305, 1345, 355)),
            (*after, "ui-game-p4-new-land.jpg", (975, 272, 1090, 372)),
            ("AFTER, locked in the hop", GREEN, "ui-game-p4-hop.jpg", (895, 318, 1060, 425)),
        ]),
        card("A tag on a fish you can hold", "The rarity is the biggest line; thinner outlines on the small words.", [
            (*before, "ui-game-tamed.jpg", (1195, 316, 1300, 372)),
            ("AFTER (the locked fish, a quarter bigger)", GREEN, "ui-game-p4-hop-locked.jpg", (880, 352, 1025, 482)),
        ]),
        card("The tame ring and a caught fish's slot", "Pink and whole (it was green with a seam). The slot takes the rarity's colour; its picture is not drawn in these shots.", [
            (*before, "ui-game-tamed.jpg", (880, 350, 1060, 500)),
            (*after, "ui-game-p3-tamed-banner.jpg", (880, 395, 1060, 515)),
            (*before, "ui-game-tamed.jpg", (495, 728, 740, 834)),
            (*after, "ui-game-p4-hop-locked.jpg", (495, 718, 740, 824)),
        ], 1.7),
        card("Landing on a fish too strong", "Nothing marked it before. Now the ring is red and bigger, with why.", [
            ("NEW: on the fish", BLUE, "ui-game-p3-too-strong-ride.jpg", (935, 420, 1065, 565)),
            ("NEW: drowning after it", BLUE, "ui-game-p3-too-strong-drowning.jpg", (935, 325, 1065, 520)),
        ]),
        card("The catch banner", "It existed but was never seen: taming came into the game with piece 3.", [
            (*new, "ui-game-p4-riding-tamed.jpg", (20, 168, 360, 318)),
        ], 1.6),
        card("A new land's name", "Comes up for two seconds when you cross into a deeper land.", [
            (*new, "ui-game-p4-new-land.jpg", (545, 98, 1000, 180)),
        ], 1.6),
    ]

    fw = (W - PAD * 3) // 2
    fulls = []
    for label, colour, name in full:
        im = Image.open(SHOTS / name).convert("RGB")
        fulls.append((label, colour, im.resize((fw, round(im.height * fw / im.width)), Image.LANCZOS)))
    rows = flow(cards)
    height = PAD + 44 + 26 + fulls[0][2].height + PAD * 2
    for row in rows:
        height += max(c.height for c in row) + PAD
    sheet = Image.new("RGB", (W, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, PAD), "Ride a Fish: the dive's HUD, before and after (captures of the game)", font=F_TITLE, fill=(255, 220, 90))
    y = PAD + 44
    x = PAD
    for label, colour, im in fulls:
        d.text((x, y), label, font=F_TAG, fill=colour)
        sheet.paste(im, (x, y + 24))
        x += fw + PAD
    y += 26 + fulls[0][2].height + PAD
    for row in rows:
        x = PAD
        for c in row:
            sheet.paste(c, (x, y))
            x += c.width + PAD
        y += max(c.height for c in row) + PAD
    sheet.save(sys.argv[1], quality=90)
    print(sheet.size)


if __name__ == "__main__":
    main()
