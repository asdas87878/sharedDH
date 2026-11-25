"""The last step of tools/boards/picture.py: all of it on one sheet."""
from PIL import Image, ImageDraw

INK, PAPER, SEA = (16, 36, 63), (236, 246, 252), (30, 120, 190)
GAP = 24


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
    total = 2400
    full = total - GAP * 2
    front = sky(work / "shot-front.png")
    front = front.resize((full, round(front.height * full / front.width)), Image.LANCZOS)
    sign = sky(work / "shot-sign.png")
    sign = sign.resize((full, round(sign.height * full / sign.width)), Image.LANCZOS)
    half = (full - GAP) // 2
    sides = [sky(work / f"shot-{n}.png") for n in ("gate", "pen")]
    sides = [s.resize((half, round(s.height * half / s.width)), Image.LANCZOS) for s in sides]
    # (a phone of 844 x 390 points has two or three pixels to each: the part with the boards, two to a point)
    phone = sky(work / "shot-phone.png").crop((430, 120, 430 + 960, 120 + 480))
    spawn = sky(work / "shot-spawn.png")
    panel = [Image.open(work / f"panel-{n}.png").convert("RGB") for n in
             ("Oxygen-all", "Collectors-all", "Earners-here")]
    low = 860
    panel = [p.resize((round(p.width * low / p.height), low), Image.LANCZOS) for p in panel]
    room = total - GAP * 5 - sum(p.width for p in panel)
    phone = phone.resize((room, round(phone.height * room / phone.width)), Image.LANCZOS)
    y0 = 100
    y1 = y0 + front.height + GAP
    ys = y1 + sign.height + 24
    y2 = ys + 46 + sides[0].height + 24
    sheet = Image.new("RGB", (total, y2 + 46 + low + 64), PAPER)
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 24), "Leaderboards: one straight wall, one post where two boards meet", font=font(44), fill=INK)
    sheet.paste(front, (GAP, y0))
    sheet.paste(sign, (GAP, y1))
    for i, (name, side) in enumerate(zip(("From the gate's side, 45 degrees", "From Plot 6's side, 45 degrees"), sides)):
        d.text((GAP + i * (half + GAP), ys), name, font=font(30), fill=INK)
        sheet.paste(side, (GAP + i * (half + GAP), ys + 46))
    d.text((GAP, y2), "The list (the third one as it is while saving is off)", font=font(30), fill=INK)
    x = GAP
    for p in panel:
        sheet.paste(p, (x, y2 + 46))
        x += p.width + GAP
    d.text((x, y2), "From 60 studs on a phone, 2 pixels to a point", font=font(30), fill=INK)
    sheet.paste(phone, (x, y2 + 46))
    # the spawn's view: the same scale, as much of it as there is room for
    left = low - phone.height - GAP
    cut = 960
    high = round(cut * left / room)
    at = (max(0, min(spawn.width - cut, 900 - cut // 2)), 150)
    view = spawn.crop((at[0], at[1], at[0] + cut, min(spawn.height, at[1] + high)))
    sheet.paste(view.resize((room, left), Image.LANCZOS), (x, y2 + 46 + phone.height + GAP))
    d.text((x + 14, y2 + 46 + phone.height + GAP + 10), "from the spawn", font=font(26), fill=INK)
    d.text((GAP, sheet.height - 42), "Offline: the game's own panel code and part tables, drawn in Chromium and Blender. Made-up names, faces and "
           "numbers. Top four views: Plot 6 left out; its seahorse is in no view. Not seen in Studio.", font=font(24), fill=INK)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print(out, sheet.size)
