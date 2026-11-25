"""The endless Underworld's sheet: python tools/endless/sheet2.py <pictures folder> <out.png>  (draw_under.py's pictures)"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

P, OUT = sys.argv[1], sys.argv[2]
W = 2400
BG, CARD, INK, SOFT, MUTE, LINE = (14, 20, 34), (20, 29, 48), (255, 255, 255), (206, 214, 230), (150, 162, 186), (52, 64, 92)
GOLD = (255, 205, 70)
F = lambda n, b=False: ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)  # noqa: E731
im = Image.new("RGB", (W, 5000), BG)
d = ImageDraw.Draw(im)


def text(x, y, s, f, fill=SOFT, wide=W - 100, gap=8):
    for para in s.split("\n"):
        line = ""
        for w in para.split(" ") + [None]:
            t = (line + " " + (w or "")).strip()
            if w is None or (d.textlength(t, f) > wide and line):
                d.text((x, y), line, font=f, fill=fill)
                y += f.size + gap
                line = w or ""
            else:
                line = t
    return y


def card(x, y, w, h, edge=LINE, wide=2):
    d.rounded_rectangle((x, y, x + w, y + h), 18, fill=CARD, outline=edge, width=wide)


def pic(name, x, y, w, h, cover=True):
    a = Image.open(os.path.join(P, name)).convert("RGB")
    k = (max if cover else min)(w / a.width, h / a.height)
    a = a.resize((int(a.width * k), int(a.height * k)), Image.LANCZOS)
    if cover:
        l, t = (a.width - w) // 2, (a.height - h) // 2
        a = a.crop((l, t, l + w, t + h))
    im.paste(a, (x + (w - a.width) // 2, y + (h - a.height) // 2))


y = 40
d.text((50, y), "THE ENDLESS UNDERWORLD", font=F(64, True), fill=INK)
y = text(50, y + 88, "Past the end of the Underworld it simply goes on: only Underworld pieces, in a random order, for as long as you can ride. Same fish, same Oxygen. Sizes and colours get very slightly better the further you are. Not built yet; drawn from our own map boxes, not in Roblox's light.", F(29))
y += 20
cw = 758
for k, n in enumerate(("u-eye-4.png", "u-far-2.png", "u-eye-7.png")):
    pic(n, 50 + k * (cw + 13), y, cw, 427)
y += 440
y = text(50, y, "What you would ride through: three places in one run. Each is a joint between two random pieces.", F(25), MUTE) + 24
card(50, y, 1140, 780)
pic("u-top-1.png", 70, y + 20, 1100, 740, False)
d.text((74, y + 22), "From above: 34 pieces, 4 minutes", font=F(26, True), fill=INK)
card(1210, y, 1140, 780)
pic("u-side-1.png", 1230, y + 70, 1100, 330, False)
d.text((1234, y + 22), "From the side: it winds down under itself", font=F(26, True), fill=INK)
rows = [("Pieces", "18 Underworld pieces x 2 (mirrored), made by our own map generator. 7 s each. A piece comes back after 2 min on average, never sooner than 1."),
        ("It never ends", "At 10 / 30 / 60 minutes x and z stay under 29,000 and y is -6,700 / -15,900 / -29,700: positions are as exact as at today's far end."),
        ("Parts", "15,400 near each player (16,800 at most), the server holds none. Today's whole map is 106,000."),
        ("Slope", "2.5 degrees (the Underworld now is 8). At 6 it would be -68,000 in an hour.")]
yy = y + 420
for a, b in rows:
    d.text((1234, yy), a, font=F(24, True), fill=MUTE)
    yy = text(1234, yy + 30, b, F(23), SOFT, 1090, 5) + 8
assert yy < y + 785, yy - y
y += 806
d.text((50, y), "THE ODDS: VERY SLIGHTLY BETTER WITH DISTANCE", font=F(44, True), fill=INK)
y = text(50, y + 60, "The PLACE has the odds, so two riders always see the same fish. Our pick: +1% every minute of riding (10,500 studs), up to +10%, then flat.", F(27)) + 14
card(50, y, W - 100, 470)
cols = [40, 490, 660, 820, 1010, 1180, 1350, 1600]
for h, c in zip(["", "Big", "Huge", "Colossal", "Silver", "Gold", "Rainbow", "The average fish"], cols):
    d.text((50 + c, y + 24), h, font=F(24, True), fill=MUTE)
rows = [("Underworld today", "16.8%", "1.17%", "0.205%", "5.0%", "1.01%", "1 in 608", "as now"),
        ("+5% (5 min)", "17.6%", "1.23%", "0.215%", "5.26%", "1.06%", "1 in 579", "needs +0.3%, earns +0.5%"),
        ("+10% (10 min on, OUR PICK)", "18.4%", "1.30%", "0.226%", "5.5%", "1.11%", "1 in 551", "needs +0.6%, earns +1.0%"),
        ("+25%", "20.9%", "1.47%", "0.259%", "6.25%", "1.27%", "1 in 480", "needs +1.5%, earns +2.6%"),
        ("+50% (too much)", "25.1%", "1.76%", "0.31%", "7.54%", "1.51%", "1 in 402", "needs +3.1%, earns +5.2%")]
yy = y + 74
for r in rows:
    best = "PICK" in r[0]
    d.line((74, yy - 8, W - 74, yy - 8), fill=LINE)
    for v, c in zip(r, cols):
        d.text((50 + c, yy), v, font=F(25, best), fill=GOLD if best else INK)
    yy += 56
yy = text(90, yy + 6, "Simulated with the game's own rules: 400,000 spawned fish a row, so a row's Rainbow is good to about 4%. Giants fall a little as Huge rises: the game makes one grand fish in every 800 studs and that rule stays. The fish themselves do not change. A Colossal or a Rainbow has always needed more Oxygen than a plain one; with more of them about, the average fish needs 0.6% more.", F(23), MUTE, W - 200, 5)
y += 490
card(50, y, W - 100, 210, GOLD, 4)
d.text((80, y + 20), "STILL TO SETTLE", font=F(34, True), fill=GOLD)
text(80, y + 72, "1.  Go ahead and build it? A guess: 4 to 5 days. The first half day is a Studio test: how fast a phone builds the pieces (750 boxes a second) and how fish look at y -20,000 and past.\n2.  Is +10% right, or more or less? It is one number.", F(27), INK, W - 170)
y += 230
y = text(50, y, "Not known: anything in Roblox. The eight boxes that close the gaps beside the joints are a sketch. Full text: docs/design/endless.md", F(24), MUTE) + 20
im.crop((0, 0, W, y)).save(OUT, optimize=True)
print(W, y)
