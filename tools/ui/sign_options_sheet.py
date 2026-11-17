"""The hub's signs: today and three options, side by side, from captures of Studio (docs/attachments/ui7-signs-*.jpg;
the options are stand-ins built by tools/ui/hub_sign_options.luau and taken away again).
    python tools/ui/sign_options_sheet.py docs/attachments/ui7-sign-options.jpg
"""
import sys
from PIL import Image, ImageDraw
from before_after import BG, PAD, W, card, flow, font

RED, GREEN, GREY = (255, 122, 122), (140, 232, 120), (200, 204, 214)
ST = (630, 262, 930, 482)
TK = (540, 215, 1548, 440)


def main():
    cards = [
        card("The stations, from the spawn", "Today's pale names pile up. Each option names a station over its own stall, in its own colour.", [
            ("TODAY", RED, "ui7-hub-right.jpg", (545, 290, 835, 480)),
            ("B, my pick: the gate's sign everywhere", GREEN, "ui7-signs-b-stations.jpg", ST),
            ("A: the HUD's dark panel", GREY, "ui7-signs-a-stations.jpg", ST),
            ("C: words like the fish tags", GREY, "ui7-signs-c-stations.jpg", ST),
        ], 1.55),
        card("Your tank and its trainer: today", "Thin words cut by the model; nothing says the tank is yours.", [
            ("TODAY", RED, "ui7-hub-tank-fish.jpg", (360, 215, 1370, 470)),
        ], 0.95),
        card("B, my pick", "The gate's blue board and letters. YOUR TANK on yours only; the trainer named once, over the model.", [
            ("", GREEN, "ui7-signs-b-tank.jpg", TK),
        ], 0.95),
        card("A", "The HUD's dark panel: a coloured header with studs, white round letters.", [
            ("", GREY, "ui7-signs-a-tank.jpg", TK),
        ], 0.95),
        card("C", "Today's tank board with a gold YOUR TANK; bare words over the trainer (its big word did not draw in this test).", [
            ("", GREY, "ui7-signs-c-tank.jpg", TK),
        ], 0.95),
    ]
    rows = flow(cards)
    height = PAD + 48
    for row in rows:
        height += max(c.height for c in row) + PAD
    sheet = Image.new("RGB", (W, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, PAD), "Ride a Fish: the hub's signs, today and three options (captures of Studio, stand-in words)", font=font(26), fill=(255, 220, 90))
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
