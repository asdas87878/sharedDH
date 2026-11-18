"""The land strip as Hugo picked it (task l1), from real Studio captures of the game's own strip code:
    python tools/ui/land_icons/l1_sheets.py strip fonts locks intro
strip: the strip in four moments of a dive at 3x, at real size, over the game and at a phone's size
(docs/attachments/land-strip-l1-1.png); fonts: the metres in six fonts (land-strip-l1-fonts-1.png); locks: a lock
breaking, frame by frame, and as a GIF (land-strip-l1-locks-1.png, .gif); intro: the five land intros
(land-strip-l1-intro-1.png, and land-strip-l1-intro-<n>.gif).
Needs a playtest with l1_client.luau installed (l1_capture.py install, then play, then l1_capture.py listen).
"""
import sys
import time

from PIL import Image, ImageDraw

import l1_capture as cap
from options_sheets import BG, GREY, SUN, WHITE, header, save, text

AHEAD = {"land": 6, "along": 0.5, "metres": 600, "best": 7.4, "bestMetres": 1300}
AT = {"land": 7, "along": 0.42, "metres": 1290, "best": 6.42, "bestMetres": 1290}
EARLY = {"land": 2, "along": 0.6, "metres": 42, "best": 4.4, "bestMetres": 108}
LATE = {"land": 10, "along": 0.3, "metres": 9620, "best": 9.7, "bestMetres": 10240}
FIRST = {"land": 1, "along": 0.3, "metres": 4, "best": 0.3, "bestMetres": 4}
STATES = [
    (AHEAD, "mid-dive, best ahead (Twilight, 600 m; best 1,300 m)"),
    (AT, "setting a new best (Midnight, 1,290 m)"),
    (EARLY, "early in a dive (Coral Reef, 42 m; best 108 m)"),
    (LATE, "deep (The Underworld, 9,620 m; best 10,240 m)"),
]
CW, CH = 310, 100  # a cell before its scale
GAME_SCALE = 1065 / 560  # the HUD's own scale in Studio's view (HudController: height / 560)


def paste_label(im, xy, s, px=19, fill=GREY):
    text(ImageDraw.Draw(im), xy, s, px, fill)


def strip():
    # 3x: four at once, one under another
    big = []
    for pair in (STATES[:2], STATES[2:]):
        items = [{"x": 20, "y": 70 + k * 330, "s": 3, "o": {"Intro": 0}, "st": st} for k, (st, _) in enumerate(pair)]
        cap.cells(items)
        view = cap.shot("strip3x", 3)
        big += [cap.crop(view, it, CW, 100) for it in items]
    # real size on the dark, and at a phone's (HUD scale 1)
    items1 = [{"x": 20 + k * 330, "y": 80, "s": 1, "o": {"Intro": 0}, "st": st} for k, (st, _) in enumerate(STATES)]
    items1 += [{"x": 60 + k * 480, "y": 300, "s": 1, "o": {"Intro": 0}, "st": dict(st, touch=True)} for k, (st, _) in enumerate(STATES)]
    cap.cells(items1)
    view = cap.shot("strip1x", 2.5)
    real = [cap.crop(view, it, CW, 100) for it in items1[:4]]
    # a phone's strip is Kit.LandPhoneScale (1.25) bigger, round its top centre
    phones = [view.crop((it["x"] + 155 - 200, it["y"], it["x"] + 155 + 200, it["y"] + 125)) for it in items1[4:]]
    # over the game: the game's own HUD (its strip is this code), ridden
    cap.attrs(Show=False, HideHud=False)
    cap.attrs(Ride=time.time())
    time.sleep(6)
    game = cap.shot("game", 1)
    # phone: the strip at HUD scale 1 over the game, in a phone's 844 by 390
    cap.cells([{"x": 1983 / 2 - 155, "y": 6, "s": 1, "o": {"Intro": 0}, "st": dict(AHEAD, touch=True)}], back=1, hide=True)
    phone_view = cap.shot("phone", 2.5)
    phone = phone_view.crop((int(1983 / 2 - 422), 0, int(1983 / 2 + 422), 390))

    W = 1960
    lines = [
        "Hugo's picks built in (the game's own code in a Studio playtest): G4 pictures, one even border, no tray;",
        "Mix 3's gold diamond with BEST in gold; a thin bar, white to you then on to gold at your best; your face",
        "in a black ring over a flat black oval (0.3 see-through) with the metres; every word built as a rarity word.",
    ]
    H = 140 + 4 * 340 + 60 + 120 + 40 + game.height // 2 + 60
    im = Image.new("RGB", (W, H), BG)
    im.paste(header(W, "Land strip, Hugo's picks (task l1)", lines), (0, 0))
    y = 150
    for k, (st, name) in enumerate(STATES):
        paste_label(im, (30, y), f"3x: {name}", 19, WHITE)
        im.paste(big[k], (30, y + 28))
        im.paste(real[k], (30 + big[k].width + 40, y + 28 + 30))
        paste_label(im, (30 + big[k].width + 40, y + 28), "real size (1:1, HUD scale 1, keyboard)", 17)
        im.paste(phones[k], (30 + big[k].width + 40, y + 28 + 170))
        paste_label(im, (30 + big[k].width + 40, y + 28 + 140), "a phone, 1:1 (HUD scale 1, the strip 1.25)", 17)
        y += 340
    paste_label(im, (30, y), "In the game, Studio's view at its real size (HUD scale 1.9):", 19, WHITE)
    half = game.resize((game.width // 2, game.height // 2), Image.LANCZOS)
    top = game.crop((int(1983 / 2 - 450), 0, int(1983 / 2 + 450), 230))
    im.paste(top, (30, y + 30))
    paste_label(im, (30 + top.width + 30, y + 30), "the whole frame, half size:", 17)
    im.paste(half.resize((W - top.width - 90, int(half.height * (W - top.width - 90) / half.width))), (30 + top.width + 30, y + 56))
    y += 30 + top.height + 40
    paste_label(im, (30, y), "At a phone's size (844 by 390 GUI px, HUD scale 1, the strip 1.25), 1:1:", 19, WHITE)
    im.paste(phone, (30, y + 30))
    im = im.crop((0, 0, W, max(y + 30 + phone.height + 30, 200)))
    save(im, "land-strip-l1-1.png")


FONTS = ["LuckiestGuy", "FredokaOne", "Bangers", "DenkOne", "Cartoon", "GothamBlack"]


def fonts():
    st = {"land": 6, "along": 0.5, "metres": 1240, "best": 7.4, "bestMetres": 1300}
    items = [{"x": 20 + (k % 2) * 980, "y": 70 + (k // 2) * 330, "s": 3, "o": {"Intro": 0, "Font": f}, "st": st} for k, f in enumerate(FONTS)]
    cap.cells(items)
    view = cap.shot("fonts3x", 3)
    # the marker's part of the strip: land 6 is from 150 to 178 GUI px
    big = [view.crop((it["x"] + 110 * 3, it["y"] + 20 * 3, it["x"] + 280 * 3, it["y"] + 82 * 3)) for it in items]
    items1 = [{"x": 20 + k * 320, "y": 80, "s": 1, "o": {"Intro": 0, "Font": f}, "st": st} for k, f in enumerate(FONTS)]
    cap.cells(items1)
    view = cap.shot("fonts1x", 2.5)
    real = [view.crop((it["x"] + 110, it["y"] + 20, it["x"] + 280, it["y"] + 82)) for it in items1]
    W = 1560
    im = Image.new("RGB", (W, 140 + 3 * 300), BG)
    im.paste(header(W, "The metres' font (task l1)", [
        "Six fonts Roblox ships, each built as a rarity word in the land's colour; 3x, and real size beside.",
        "Picked: Luckiest Guy (Kit.LandMetresFont): the chunkiest at real size, its round letters hold the edge.",
    ]), (0, 0))
    for k, f in enumerate(FONTS):
        x = 30 + (k % 2) * 760
        y = 140 + (k // 2) * 300
        paste_label(im, (x, y), f + (" (picked)" if f == "LuckiestGuy" else ""), 20, SUN if f == "LuckiestGuy" else WHITE)
        im.paste(big[k], (x, y + 30))
        im.paste(real[k], (x + big[k].width + 20, y + 30 + 60))
    save(im, "land-strip-l1-fonts-1.png")


def locks():
    slow = 16
    before = {"land": 3, "along": 0.95, "metres": 296, "best": 2.97, "bestMetres": 296}
    after = {"land": 4, "along": 0.04, "metres": 305, "best": 3.04, "bestMetres": 305}
    item = {"x": 20, "y": 80, "s": 4, "o": {"Intro": 0}, "st": before}
    cap.cells([item], slow=slow)
    time.sleep(2.5)
    frames = [(0.0, cap.crop(cap.shot("lock_0", 0.2), item, 160, 70))]
    cap.states([after])
    t0 = time.time()
    while time.time() - t0 < 0.5 * slow + 1.2:
        im = cap.shot(f"lock_{len(frames)}", 0, fresh=False)
        frames.append(((time.time() - t0) / slow, cap.crop(im, item, 160, 70)))
    # the sheet: a row of frames
    # close on land 4's tile (strip x 90 to 118 in a holder 310 wide: + 6), 4x, full size
    frames = [(t, fr.crop((70 * 4, 0, 150 * 4, 62 * 4))) for t, fr in frames]
    pick = [frames[0]] + frames[1::max(1, (len(frames) - 1) // 7)][:7] + [frames[-1]]
    fw, fh = pick[0][1].size
    W = 60 + len(pick) * (fw + 12)
    im = Image.new("RGB", (max(W, 1200), 140 + fh + 70), BG)
    im.paste(header(im.width, "A lock breaking (task l1)", [
        "The first time your best gets into a land: a white burst and a crack, the halves tip apart, fall and fade",
        f"in 0.5 s, and it never comes back. Captured at 1/{slow} speed, times are the game's; 4x.",
    ]), (0, 0))
    for k, (t, fr) in enumerate(pick):
        x = 30 + k * (fw + 12)
        im.paste(fr, (x, 140))
        paste_label(im, (x, 140 + fh + 8), f"{t:.2f} s", 17)
    save(im, "land-strip-l1-locks-1.png")
    gif = [fr for _, fr in frames]
    durs = [600] + [max(40, int((frames[k + 1][0] - frames[k][0]) * 1000)) for k in range(1, len(frames) - 1)] + [900]
    gif[0].save(cap.ROOT / "docs/attachments/land-strip-l1-locks-1.gif", save_all=True, append_images=gif[1:], duration=durs, loop=0)
    print("wrote gif", len(gif))


INTROS = ["Punch", "Banner", "Fly", "Subtitle", "Flash"]


def intro():
    slow = 6
    s = GAME_SCALE
    w, h = 1983 / s, 1065 / s
    shots = []
    # underwater: on a fish down the lane (endless air, no fail), the game's HUD hidden, only the test strip
    cap.attrs(Show=False, HideHud=False)
    cap.attrs(Ride=time.time())
    time.sleep(14)
    for look in range(1, 6):
        item = {"x": 0, "y": 0, "s": s, "w": w, "h": h, "o": {"Intro": look}, "st": AHEAD}
        cap.cells([item], back=1, hide=True, slow=slow)
        time.sleep(1.5)
        cap.intro(1, 6, 600, new=look in (1, 3))
        t0 = time.time()
        frames = []
        while time.time() - t0 < 2.4 * slow:
            frames.append(((time.time() - t0) / slow, cap.shot(f"intro{look}_{len(frames)}", 0, fresh=False)))
        # the peak: about 0.6 s in
        peak = min(frames, key=lambda f: abs(f[0] - 0.7))
        shots.append(peak[1])
        gif = [f.resize((f.width // 3, f.height // 3), Image.LANCZOS) for _, f in frames]
        durs = [max(40, int((frames[k + 1][0] - frames[k][0]) * 1000)) for k in range(len(frames) - 1)] + [600]
        gif[0].save(cap.ROOT / f"docs/attachments/land-strip-l1-intro-{look}.gif", save_all=True, append_images=gif[1:], duration=durs, loop=0)
    W = 1960
    tw, th = (W - 90) // 2, int(1065 * ((W - 90) // 2) / 1983)
    im = Image.new("RGB", (W, 150 + 3 * (th + 50)), BG)
    im.paste(header(W, "Land intros (task l1): Kit.LandIntroLook, 0 off", [
        "Plays when you enter a land deeper than any yet this dive (not the one a dive starts in; going back up and down",
        "again does not replay it). The first time ever it also says NEW (1 and 3 shown so) while the lock breaks.",
    ]), (0, 0))
    for k, shot in enumerate(shots):
        x = 30 + (k % 2) * (tw + 30)
        y = 150 + (k // 2) * (th + 50)
        name = f"{k + 1} {INTROS[k]}" + ("  (the default)" if k == 0 else "")
        paste_label(im, (x, y), name, 20, SUN if k == 0 else WHITE)
        im.paste(shot.resize((tw, th), Image.LANCZOS), (x, y + 30))
    save(im, "land-strip-l1-intro-1.png")


if __name__ == "__main__":
    for what in sys.argv[1:]:
        {"strip": strip, "fonts": fonts, "locks": locks, "intro": intro}[what]()
        print(cap.log()[-400:])
