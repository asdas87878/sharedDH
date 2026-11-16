"""The survey of 2026-11-16: every piece of UI in the game as it is, what looks wrong, worst first. One sheet of
crops from captures of a Studio playtest (docs/attachments/ui7-*.jpg, all 1370 by 801).
    python tools/ui/survey_sheet.py docs/attachments/ui7-survey.jpg
"""
import sys
from PIL import Image, ImageDraw
from before_after import BG, PAD, W, card, flow, font

BAD, OK = (255, 122, 122), (140, 232, 120)


def main():
    cards = [
        card("1. The end of a dive: two banners at once", "GREAT DIVE! and OUT OF AIR! say opposite things, stacked, while the black lifts.", [
            ("", BAD, "ui7-dock-two-banners.jpg", (360, 150, 1010, 450)),
        ], 1.5),
        card("2. Station names run into each other", "Pale letters with a thin edge, no plate, on a pale wall. Seen from the spawn.", [
            ("to the right", BAD, "ui7-hub-right.jpg", (560, 290, 830, 480)),
            ("to the left", BAD, "ui7-hub-left.jpg", (590, 300, 860, 480)),
        ], 1.8),
        card("3. TRAIN OXYGEN / stand here", "Thin white words, the same on every plot, cut by the model in front of them.", [
            ("from the spawn", BAD, "ui7-hub-plots.jpg", (190, 340, 1110, 450)),
            ("at your own tank", BAD, "ui7-hub-tank-fish.jpg", (880, 330, 1110, 470)),
        ], 1.5),
        card("4. Four sign styles and three fonts in one hub", "Each was made by a different hand at a different time.", [
            ("the gate", BAD, "ui7-hub-gate.jpg", (420, 225, 950, 320)),
            ("a tank", BAD, "ui7-hub-tank-fish.jpg", (490, 225, 880, 315)),
            ("the earners", BAD, "ui7-hub-earners.jpg", (575, 250, 745, 500)),
            ("a station", BAD, "ui7-hub-earners.jpg", (1130, 200, 1340, 300)),
        ], 1.25),
        card("5. The bottom left corner", "A gold plate and a glass box, two builds, touching. Drowning, the box nearly goes.", [
            ("riding", BAD, "ui7-dive-riding.jpg", (0, 670, 190, 801)),
            ("drowning", BAD, "ui7-dive-drowning.jpg", (0, 670, 190, 801)),
        ], 2.0),
        card("6. In the hop, the aim sits on the tag", "The ring covers what the locked fish needs, and the tag covers the rider.", [
            ("", BAD, "ui7-dive-hop.jpg", (540, 235, 830, 445)),
        ], 1.8),
        card("7. Seven empty slots, in the hub too", "The heaviest thing on the screen when empty, and on the dock they mean nothing.", [
            ("at the spawn", BAD, "ui7-hub-spawn.jpg", (410, 700, 960, 795)),
        ], 1.5),
        card("8. The strip of lands", "Names too small to read. It covers the gate's sign from the spawn; BEST sits on a name.", [
            ("over the gate's sign", BAD, "ui7-hub-spawn.jpg", (455, 0, 915, 100)),
            ("BEST on Kelp", BAD, "ui7-dock-two-banners.jpg", (455, 0, 915, 100)),
        ], 1.5),
        card("9. Your tank says little", "No name on a fish, nothing on the green pad that pays you. From the spawn the signs are black bars.", [
            ("fish, no labels", BAD, "ui7-hub-tank-fish.jpg", (640, 360, 860, 500)),
            ("signs from the spawn", BAD, "ui7-hub-plots.jpg", (480, 240, 1370, 360)),
        ], 1.35),
        card("What reads well, and stays", "The gate's sign, a tank's sign up close, the fish tags, the rings, the hop button.", [
            ("tags (Hugo's)", OK, "ui7-dive-reef.jpg", (560, 170, 780, 310)),
            ("far tags", OK, "ui7-dive-crowd.jpg", (420, 190, 830, 330)),
            ("the rings", OK, "ui7-dive-riding.jpg", (780, 370, 960, 500)),
            ("the button", OK, "ui7-dive-riding.jpg", (1165, 595, 1310, 745)),
            ("in the hop", OK, "ui7-dive-hop.jpg", (1165, 595, 1310, 745)),
        ], 1.35),
    ]
    rows = flow(cards)
    height = PAD + 48
    for row in rows:
        height += max(c.height for c in row) + PAD
    sheet = Image.new("RGB", (W, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, PAD), "Ride a Fish: every piece of UI today, what looks wrong, worst first (captures of the game, 2026-11-16)", font=font(26), fill=(255, 220, 90))
    y = PAD + 48
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
