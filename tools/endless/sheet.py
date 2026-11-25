"""The endless study's options sheet: python tools/endless/sheet.py <pictures folder> <out.png>  (draw.py's pictures)"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

P, OUT = sys.argv[1], sys.argv[2]
W = 2600
BG, CARD, INK, SOFT, MUTE, LINE = (14, 20, 34), (20, 29, 48), (255, 255, 255), (206, 214, 230), (150, 162, 186), (52, 64, 92)
GOLD, GOOD, WARN, BAD = (255, 205, 70), (80, 200, 120), (250, 190, 70), (240, 110, 100)
F = lambda n, b=False: ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans%s.ttf" % ("-Bold" if b else ""), n)  # noqa: E731
im = Image.new("RGB", (W, 7800), BG)
d = ImageDraw.Draw(im)


def text(x, y, s, f, fill=INK, wide=None, gap=8):
    """wrapped text; gives the y under it"""
    for para in s.split("\n"):
        words, line = para.split(" "), ""
        rows = []
        for w in words:
            t = (line + " " + w).strip()
            if wide and d.textlength(t, f) > wide and line:
                rows.append(line)
                line = w
            else:
                line = t
        rows.append(line)
        for r in rows:
            d.text((x, y), r, font=f, fill=fill)
            y += f.size + gap
    return y


def card(x, y, w, h, edge=LINE, wide=2):
    d.rounded_rectangle((x, y, x + w, y + h), 18, fill=CARD, outline=edge, width=wide)


def pic(name, x, y, w, h, fit="cover"):
    a = Image.open(os.path.join(P, name)).convert("RGB")
    k = max(w / a.width, h / a.height) if fit == "cover" else min(w / a.width, h / a.height)
    a = a.resize((int(a.width * k), int(a.height * k)), Image.LANCZOS)
    if fit == "cover":
        l, t = (a.width - w) // 2, (a.height - h) // 2
        a = a.crop((l, t, l + w, t + h))
        im.paste(a, (x, y))
    else:
        d.rectangle((x, y, x + w, y + h), fill=BG)
        im.paste(a, (x + (w - a.width) // 2, y + (h - a.height) // 2))


def badge(x, y, s, fill=GOLD, ink=(20, 20, 20), n=40):
    f = F(n, True)
    w = max(d.textlength(s, f) + n * 0.6, n * 1.5)
    d.rounded_rectangle((x, y, x + w, y + n * 1.5), 12, fill=fill)
    d.text((x + w / 2, y + n * 0.75), s, font=f, fill=ink, anchor="mm")
    return x + w


def head(y, s, sub=None):
    d.text((50, y), s, font=F(46, True), fill=INK)
    y += 62
    if sub:
        y = text(50, y, sub, F(27), SOFT, W - 100)
    return y + 16


y = 40
d.text((50, y), "ENDLESS: WHAT COMES AFTER THE UNDERWORLD", font=F(66, True), fill=INK)
y = text(50, y + 92, "Five ways to make the map go on (A to E), four ways to play it (1 to 4). Nothing is built in the game. Every picture is drawn from our own map boxes; every number is counted or modelled (the days of work are guesses). A plain drawing, not Roblox's light.", F(30), SOFT, W - 100)
y += 10
card(50, y, W - 100, 158, GOLD, 5)
d.text((80, y + 22), "RECOMMENDED:  D + 1", font=F(44, True), fill=GOLD)
text(80, y + 80, "D, the Spiral: random chunks from our own map generator, winding down round a column, each player's machine building only the part round them. With 1, the Deep Run: fish 1.35 times stronger a layer, an Oxygen milestone a layer, a landmark every 5, the DEEPEST DIVERS board.", F(28), INK, W - 160)
y += 186

# ------------------------------------------------------------------ the five
y = head(y, "THE MAP: FIVE WAYS", "The lane today: 23,500 studs, 106,000 parts. At land 10's riding speed (about 175 studs a second) 10 minutes is 105,000 studs: four and a half times the whole map.")
opts = [
    ("A", "Random stack, built once", "jt-raw.png", [
        ("Look", "Pieces cut from the lands, or made in our generator (see SEAMS). Straight on."),
        ("10 / 30 / 60 min", "Not endless: 36 chunks is 4 minutes and then a wall."),
        ("Parts", "+225,000 (the map is 106,000). Every player gets all of it: streaming is off in the saved place.", BAD),
        ("Far from zero", "Only as far as it is long: fine.", GOOD),
        ("Riders apart", "No problem, it is one lane.", GOOD),
        ("Code", "Least: the lane and the zones get longer."),
        ("Work / risk", "2 to 3 days / low, but it does not do what you asked")]),
    ("B", "The ten lands again, deeper", "b-1.png", [
        ("Look", "Same lands, new light and paint, stronger fish."),
        ("10 / 30 / 60 min", "The whole order comes back every 2.2 min: 4, 13, 27 times the same lap.", BAD),
        ("Parts", "Shared pieces: 0 new. Built out for real: +106,000 a lap.", WARN),
        ("Far from zero", "Straight on: about 120,000 studs at 10 min. Fish and riders start to shake.", BAD),
        ("Riders apart", "Two laps need two sets of fish."),
        ("Code", "Zones, looks and fish by lap."),
        ("Work / risk", "3 to 4 days / medium, gets old fastest")]),
    ("C", "Treadmill: the server moves chunks", "jt-made.png", [
        ("Look", "As D, straight on."),
        ("10 / 30 / 60 min", "Pieces as in D, but the lane runs straight: z 121,000 / 316,000 / 606,000.", BAD),
        ("Parts", "19,000 near one rider; 8 riders apart: 150,000 on the server, all sent to everyone.", BAD),
        ("Far from zero", "Same as B unless the whole world slides back, which 8 riders at 8 depths cannot share.", BAD),
        ("Riders apart", "The weak point.", BAD),
        ("Code", "Server moves 900 parts a second."),
        ("Work / risk", "5 to 6 days / high")]),
    ("D", "THE SPIRAL", "top-1.png", [
        ("Look", "Random chunks, ten looks, mirrored, winding down round a column."),
        ("10 / 30 / 60 min", "A shape comes back every 2 min, never sooner than 1; same shape, hand and look: 15% / 39% / 59% seen before.", GOOD),
        ("Parts", "Server: 0. Each player: about 19,000 round them, 24,000 at most.", GOOD),
        ("Far from zero", "x and z stay under 29,000 (100 seeds; today 23,100). Only y grows: -13,000 / -35,000 / -68,000.", GOOD),
        ("Riders apart", "Nothing shared to break: one seed, one lane.", GOOD),
        ("Code", "Lane grows as it is needed; fish only near riders."),
        ("Work / risk", "5 to 6 days in stages / medium")]),
    ("E", "Whirlpools: trenches near the hub", "made-same.png", [
        ("Look", "As D in runs of 6 chunks, then a 1 s bubble cut to the next trench."),
        ("10 / 30 / 60 min", "As D, but a cut every 41 s: 15 / 44 / 87 of them.", WARN),
        ("Parts", "As D for each player.", GOOD),
        ("Far from zero", "Never grows: good for hours.", GOOD),
        ("Riders apart", "Up to 8 trenches at once: 8 lanes, 8 herds.", WARN),
        ("Code", "The most: today all code knows ONE lane.", BAD),
        ("Work / risk", "7 to 9 days / high")]),
]
cw, gx = 488, 15
ch_ = 1120
for i, (let, name, p, rows) in enumerate(opts):
    x = 50 + i * (cw + gx)
    best = let == "D"
    card(x, y, cw, ch_, GOLD if best else LINE, 6 if best else 2)
    pic(p, x + 12, y + 12, cw - 24, 270, "fit" if best else "cover")
    badge(x + 24, y + 24, let, GOLD if best else INK)
    yy = text(x + 24, y + 298, name, F(29, True), INK, cw - 48)
    yy += 6
    for r in rows:
        col = r[2] if len(r) > 2 else MUTE
        d.ellipse((x + 24, yy + 7, x + 38, yy + 21), fill=col if len(r) > 2 else LINE)
        d.text((x + 48, yy), r[0], font=F(22, True), fill=MUTE)
        yy = text(x + 48, yy + 29, r[1], F(23), SOFT, cw - 72, 5) + 8
    assert yy < y + ch_ + 4, (let, yy - y)
y += ch_ + 16
for k, (c, s) in enumerate(((GOOD, "good"), (WARN, "so-so"), (BAD, "a problem"))):
    d.ellipse((60 + k * 170, y + 6, 76 + k * 170, y + 22), fill=c)
    d.text((86 + k * 170, y), s, font=F(23), fill=MUTE)
y += 56

# ------------------------------------------------------------------ three seeds
y = head(y, "D, THE SPIRAL: THREE SEEDS, 30 CHUNKS EACH (from above, and from the side)", "36,000 studs, 3.4 minutes, 3,800 m down. Green dot: the way in. Gold dot: a landmark. One look lasts a layer of 3 chunks (21 s). The same seed always gives the same run; 20 seeds x 100 chunks checked: no coil touches another; 100 seeds: never nearer than 1,890 studs in height to today's lane.")
cw = 825
for k in range(3):
    x = 50 + k * (cw + 12)
    card(x, y, cw, 1220)
    d.text((x + 24, y + 16), f"seed {k + 1}", font=F(30, True), fill=INK)
    pic(f"top-{k + 1}.png", x + 14, y + 62, cw - 28, 690, "fit")
    pic(f"side-{k + 1}.png", x + 14, y + 765, cw - 28, 440, "fit")
y += 1246

# ------------------------------------------------------------------ seams
y = head(y, "SEAMS: WHAT A JOINT LOOKS LIKE", "Cut from today's lands, only 1 pair in 20 fits; the sides jump 129 studs at a typical joint, and 2 of 76 ends fit nothing. Made in our own generator with the same neck at both ends (40 to 60 s, offline), every pair meets in the lane: side step 0, floor step 0.28 studs at most. BUT beside the neck the ground is open at 9 joints in 10 (1,224 measured: a median of 600 square studs with no floor or wall, 7,575 at worst; chunks that were built as neighbours: 0 to 50). Eight plain boxes at each joint close them all. 18 chunks x 2 hands x 10 looks.")
cw = 822
for k, (p, s, c) in enumerate((("jt-raw2.png", "Cut from today's lands: a bad pair, 423 studs (the worst of all is 479; a typical one 129). The walls miss each other.", BAD),
                               ("jt-made.png", "Made as chunks, as they come. The lane's edges meet, but there is a hole beside the neck (black, left) and a sawtooth where the looks change.", WARN),
                               ("jt-fix.png", "The same joint with 8 boxes more (a first sketch: a slab, a sill, three blocks a side). No hole at any of the 1,224 joints.", GOOD))):
    x = 50 + k * (cw + 16)
    card(x, y, cw, 510)
    pic(p, x + 14, y + 14, cw - 28, 380)
    d.ellipse((x + 24, y + 412, x + 40, y + 428), fill=c)
    text(x + 52, y + 404, s, F(24), SOFT, cw - 80, 4)
y += 526
for k, (p, s) in enumerate((("made-same.png", "Joint, same look both sides"), ("eye-3.png", "Joint, a look change (at the flags)"), ("eye-5.png", "What you ride toward: next layer's cliffs"), ("b-1.png", "One chunk painted as the Vents"))):
    cw2 = 613
    x = 50 + k * (cw2 + 16)
    card(x, y, cw2, 400)
    pic(p, x + 10, y + 10, cw2 - 20, 334)
    d.text((x + 20, y + 354), s, font=F(24), fill=SOFT)
y += 430

# ------------------------------------------------------------------ loops
y = head(y, "THE GAME: FOUR WAYS TO PLAY IT", "Layers are 3 chunks, about 380 m. Depth is the gauge we have: 1 m a stud.")
loops = [
    ("1", "Deep Run", GOLD, "Fish carry a Deep mark of their own (kept in your tank, so your rule holds): need x1.35 a layer, coins with it. You go as deep as your Oxygen holds, then the red fish end it.\n\nFirst time at a layer: 10% of its need in Oxygen, no coins (see the money below). Every 5 layers a landmark with a chest. 1 layer in 6 is a rich one (gold, giants, a shoal).\n\nEnds: you drown or miss, as today, with a depth card and your best.\n\nBoard: DEEPEST DIVERS. l1 has it ready, off because it is the easiest to cheat: first the server must check the speed."),
    ("2", "The Chase", LINE, "Fish stay as they are. A dark cloud comes up behind you and speeds up: fall back and it takes you. Skill, not strength, so it never ends by itself.\n\nPays a score and small chests, no big fish.\n\nOpen to a new player too (a gate in the hub).\n\nRisk: a side game; in the one we studied, the creator seen played it once and went back."),
    ("3", "Daily Trench", LINE, "One seed for the whole world each day (the date is the seed). Everybody rides the same layers, the board is today's, three goals a day.\n\nGoes with 1 or 2. Almost free once D is there.\n\nWith saving off, the board is this server's only, as the other boards are now."),
    ("4", "Rebirth (an option only)", LINE, "At layer 10: give back Oxygen and coins, keep the Index and the fish, gain +x% for good.\n\nNot needed yet: after 100 hours the player in our model has 10 of 12 seahorse levels and 11 of 12 auras, and layer 9 of the Deep Run.\n\nCome back to it when somebody has bought all 12."),
]
cw = 613
for k, (n, name, edge, body) in enumerate(loops):
    x = 50 + k * (cw + 16)
    card(x, y, cw, 640, edge, 6 if edge == GOLD else 2)
    e = badge(x + 22, y + 20, n, GOLD if edge == GOLD else INK)
    d.text((e + 18, y + 30), name, font=F(32, True), fill=INK)
    text(x + 24, y + 102, body, F(24), SOFT, cw - 48, 6)
y += 670

# ------------------------------------------------------------------ economy
y = head(y, "DOES IT BREAK THE MONEY?  NO, but the milestone has to be the right size", "Our own economy model (free player, 5 seeds, median). A fish earns by what it needs, and you can only tame what your Oxygen holds, so the tank cannot run ahead of you. Too small a milestone (2%) leaves the diver with 40% less Oxygen at 100 h than a player who never goes down; too big (20%) and everything runs away.")
hours = [20, 25, 30, 45, 60, 80, 100]
BLUE, AMBER, GREEN = (57, 135, 229), (201, 133, 0), (25, 158, 112)
names = [("Deep Run 10%, and fills the Index", BLUE), ("Deep Run 10%, only dives", GREEN), ("no endless (today)", AMBER)]
charts = [("Max Oxygen, billions", [[2.07, 14.5, 17.6, 80.9, 92, 124, 160], [2.1, 14.5, 17.7, 25.1, 34, 50.2, 85.4], [2.1, 10.3, 10.9, 15.4, 50.3, 58.6, 77.5]], ("160B", "85.4B", "77.5B"), (0, -12, 14)),
          ("What the tank earns a second, billions of coins", [[.543, 5.66, 7.32, 32, 44.7, 64.5, 83.1], [.545, 6.32, 7.85, 11.5, 15.5, 24.2, 38.9], [.545, 3.09, 5.33, 7.35, 14.9, 19.9, 22.2]], ("83.1B", "38.9B", "22.2B"), (0, 0, 0))]
cw = 1242
for k, (title, rows, ends, shift) in enumerate(charts):
    x = 50 + k * (cw + 16)
    card(x, y, cw, 560)
    d.text((x + 30, y + 22), title, font=F(27, True), fill=INK)
    X0, X1, Y0, Y1 = x + 110, x + cw - 120, y + 130, y + 460
    top = 160 if k == 0 else 100
    for v in range(0, top + 1, 40 if k == 0 else 25):
        yy = Y1 - (Y1 - Y0) * v / top
        d.line((X0, yy, X1, yy), fill=LINE, width=1)
        d.text((X0 - 14, yy), f"{v}B", font=F(22), fill=MUTE, anchor="rm")
    for h in (20, 40, 60, 80, 100):
        d.text((X0 + (X1 - X0) * (h - 20) / 80, Y1 + 14), f"{h} h", font=F(22), fill=MUTE, anchor="ma")
    d.text((X0, Y1 + 50), "hours played", font=F(22), fill=MUTE)
    lx = x + 30
    for name, col in names:
        d.line((lx, y + 84, lx + 36, y + 84), fill=col, width=5)
        d.text((lx + 46, y + 84), name, font=F(22), fill=SOFT, anchor="lm")
        lx += 72 + d.textlength(name, F(22))
    for (name, col), vals, e, sh in zip(names, rows, ends, shift):
        q = [(X0 + (X1 - X0) * (h - 20) / 80, Y1 - (Y1 - Y0) * v / top) for h, v in zip(hours, vals)]
        d.line(q, fill=col, width=4, joint="curve")
        for a, b in q:
            d.ellipse((a - 6, b - 6, a + 6, b + 6), fill=col, outline=CARD, width=2)
        d.text((X1 + 16, q[-1][1] + sh), e, font=F(23, True), fill=SOFT, anchor="lm")
y += 576
card(50, y, 1500, 720)
d.text((80, y + 22), "The milestone: what a first time at a layer pays (x1.35 a layer)", font=F(27, True), fill=INK)
cols = [30, 480, 690, 910, 1150]
for h, c in zip(["Oxygen, share of the layer's need", "Oxygen, 60 h", "Oxygen, 100 h", "Tank /s, 100 h", "Oxygen 100 h, fills Index"], cols):
    d.text((80 + c - 30, y + 78), h, font=F(22, True), fill=MUTE)
rows = [("no endless (today)", "50.3B", "77.5B", "22.2B", "77.5B"), ("nothing", "20.2B", "41.1B", "19.2B", "81.9B"), ("2% and 60 s of coins", "22.1B", "46.7B", "20.9B", "91.9B"), ("4% and 60 s", "24.0B", "54.5B", "24.1B", "106B"),
        ("6% and 60 s", "25.9B", "61.9B", "27.5B", "118B"), ("8% and 60 s", "28.1B", "68.8B", "33.1B", "145B"), ("10%, with or without coins", "34.0B", "85.4B", "38.9B", "160B"), ("20% and 600 s", "123B", "303B", "159B", "-")]
yy = y + 120
for r in rows:
    d.line((70, yy - 8, 1526, yy - 8), fill=LINE)
    best = r[0].startswith("10%")
    for v, c in zip(r, cols):
        d.text((80 + c - 30, yy), v, font=F(25, best), fill=GOLD if best else INK)
    yy += 46
text(80, yy + 10, "Why 10%: it is the least we tried where a player who does nothing but dive ends (100 h) ahead of today. At 60 and 80 h they are still behind (34B against 50B, 50B against 59B), and partly that is the model's own rule, not the game's: 70% of its catches are in the deepest layer and 30% in the one above, so it never goes back to finish land 9 and 10's Index pages (one pays 5 times its land's commonest fish). Let the 30% go to the Index's missing fish instead (last column) and at 60 and 100 h the Deep Run is ahead of today at every milestone, even none. 60 s of coins on top changed nothing at 10%.", F(23), SOFT, 1440, 5)
x = 1570
card(x, y, 980, 720)
d.text((x + 28, y + 22), "The Deep Run in numbers (x1.35 a layer)", font=F(27, True), fill=INK)
heads, cols = ["Layer", "Depth", "Needs", "Earns /s", "Held after"], [28, 150, 320, 510, 710]
for h, c in zip(heads, cols):
    d.text((x + c, y + 78), h, font=F(23, True), fill=MUTE)
rows = [("Land 10", "1,900 m", "4.65B", "$116M", "21 h"), ("1", "2,230 m", "6.28B", "$157M", "under 25 h"), ("3", "2,980 m", "11.4B", "$286M", "25 h"), ("5", "3,740 m", "20.9B", "$521M", "45 h"),
        ("7", "4,500 m", "38.0B", "$950M", "80 h"), ("9", "5,250 m", "69.3B", "$1.73B", "100 h"), ("10", "5,630 m", "93.5B", "$2.34B", "over 100 h"), ("15", "7,520 m", "419B", "$10.5B", "-"), ("20", "9,410 m", "1.88T", "$47B", "-")]
yy = y + 122
for r in rows:
    d.line((x + 24, yy - 8, x + 956, yy - 8), fill=LINE)
    for v, c in zip(r, cols):
        d.text((x + c, yy), v, font=F(25), fill=INK)
    yy += 46
text(x + 28, yy + 10, "Held by the player who only dives, 10%. So the wall is your own Oxygen, and it moves: a longer run needs a stronger diver. A run is today's 3 to 5 minutes plus about 20 s a layer. The cost to see: the Index-filling diver's tank earns 83B a second at 100 h against 22B, so the last seahorse and aura come in sooner.", F(23), SOFT, 920, 5)
y += 750

# ------------------------------------------------------------------ questions
y = head(y, "FOUR QUESTIONS FOR HUGO")
qs = [("Which map?", "A, B, C, D or E.   We would take D."),
      ("Which game on it?", "1, 2, 3, 4 or a mix.   We would take 1, with 3 after it. No rebirth yet."),
      ("What may the layers look like?", "(a) all ten lands mixed, as drawn above, or (b) only deep, dark looks, a new set made for it.   We would take (a) first: it costs nothing."),
      ("Who gets in?", "(a) only past land 10 (about 21 hours in for a free player), or (b) also a gate in the hub for everybody, with fish by your own strength.   We would take (a).")]
for k, (q, a) in enumerate(qs):
    card(50, y, W - 100, 116)
    badge(74, y + 26, str(k + 1), INK)
    d.text((170, y + 18), q, font=F(32, True), fill=INK)
    text(170, y + 66, a, F(26), SOFT, W - 250, 4)
    y += 130
y = text(50, y + 10, "Not known yet, needs one Studio test before any build: how fast a phone makes 900 boxes a second, and how a fish shakes at y -35,000. Full text and sources: docs/design/endless.md", F(25), MUTE, W - 100)
im.crop((0, 0, W, y + 40)).save(OUT, optimize=True)
print(OUT, W, y + 40)
