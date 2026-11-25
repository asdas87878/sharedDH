"""The last step of tools/boards/picture.py: the options on one sheet."""
from PIL import Image, ImageDraw

INK, PAPER, SEA = (16, 36, 63), (236, 246, 252), (30, 120, 190)
GAP, WIDE = 24, 800


def sky(file):
    image = Image.open(file).convert("RGBA")
    back = Image.new("RGBA", image.size)
    d = ImageDraw.Draw(back)
    for y in range(image.height):
        t = y / image.height
        d.line((0, y, image.width, y), fill=(int(86 + 90 * t), int(176 + 45 * t), 250, 255))
    back.alpha_composite(image)
    return back.convert("RGB")


def make(work, out, font):
    names = ["1  Driftwood and rope", "2  Coral reef and shell", "3  Sunken brass (my pick)"]
    notes = ["glass floats for lamps, floats, starfish: the hub's own wood",
             "coral pillars, a scallop crown, pearls, lit anemones",
             "green copper, brass bands, caged lamps, portholes, a valve"]
    total = GAP + 3 * (WIDE + GAP)
    close = [sky(work / f"shot-close-{i}.png") for i in (1, 2, 3)]
    phone = [sky(work / f"shot-phone-{i}.png") for i in (1, 2, 3)]
    close = [c.resize((WIDE, round(c.height * WIDE / c.width)), Image.LANCZOS) for c in close]
    # (a phone of 844 x 390 points has two or three pixels to each: the part with the boards, two to a point)
    phone = [c.crop((420, 130, 420 + WIDE, 130 + 440)) for c in phone]
    panel = [Image.open(work / f"panel-{n}.png").convert("RGB") for n in
             ("Oxygen-all", "Collectors-all", "Earners-here")]
    low = 800
    panel = [p.resize((round(p.width * low / p.height), low), Image.LANCZOS) for p in panel]
    spawn = sky(work / "shot-spawn.png")
    room = total - GAP * 5 - sum(p.width for p in panel)
    # (the spawn's view cut to what is left of the row)
    part = spawn.crop((430, 60, 430 + 1000, 60 + 720))
    part = part.resize((room, round(part.height * room / part.width)), Image.LANCZOS)
    if part.height > low:
        part = part.crop((0, 0, room, low))
    y0 = 108
    y1 = y0 + 76 + close[0].height + 40
    y2 = y1 + 50 + phone[0].height + 40
    high = y2 + 50 + low + 70
    sheet = Image.new("RGB", (total, high), PAPER)
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 24), "Leaderboards: three frames to choose from (Config.Boards.Style 1 to 3)", font=font(50), fill=INK)
    for i in range(3):
        x = GAP + i * (WIDE + GAP)
        d.text((x, y0), names[i], font=font(38), fill=SEA)
        d.text((x, y0 + 42), notes[i], font=font(24), fill=INK)
        sheet.paste(close[i], (x, y0 + 76))
        sheet.paste(phone[i], (x, y1 + 46))
    d.text((GAP, y1), "From 60 studs on a phone (844 x 390 points, the part with the boards at 2 pixels to a point; the hub as saved, Plot 6 in front):", font=font(30), fill=INK)
    d.text((GAP, y2), "Close: the list, a tie (2, 2, 4), and the label while saving is off", font=font(30), fill=INK)
    d.text((GAP * 4 + sum(p.width for p in panel), y2), "From the spawn's side (style 3)", font=font(30), fill=INK)
    x = GAP
    for p in panel:
        sheet.paste(p, (x, y2 + 46))
        x += p.width + GAP
    sheet.paste(part, (x, y2 + 46))
    d.text((GAP, high - 44), "Offline: the game's own panel code and part tables, drawn in Chromium and Blender, day light. Made-up names, "
           "faces and numbers. Top row: Plot 6 left out; its seahorse is in no view. Not seen in Studio.", font=font(24), fill=INK)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print(out, sheet.size)
