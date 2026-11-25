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
    close = sky(work / "shot-close.png").resize((total - GAP * 2, round(1500 * (total - GAP * 2) / 2400)), Image.LANCZOS)
    sign = sky(work / "shot-sign.png")
    sign = sign.resize((total - GAP * 2, round(sign.height * (total - GAP * 2) / sign.width)), Image.LANCZOS)
    # (a phone of 844 x 390 points has two or three pixels to each: the part with the boards, two to a point)
    phone = sky(work / "shot-phone.png").crop((430, 120, 430 + 960, 120 + 480))
    panel = [Image.open(work / f"panel-{n}.png").convert("RGB") for n in
             ("Oxygen-all", "Collectors-all", "Earners-here")]
    low = 860
    panel = [p.resize((round(p.width * low / p.height), low), Image.LANCZOS) for p in panel]
    room = total - GAP * 5 - sum(p.width for p in panel)
    phone = phone.resize((room, round(phone.height * room / phone.width)), Image.LANCZOS)
    y0 = 100
    y1 = y0 + close.height + GAP
    y2 = y1 + sign.height + 24
    sheet = Image.new("RGB", (total, y2 + 46 + low + 64), PAPER)
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 24), "Leaderboards, sunken brass: valves and lamps back, a bar for a head, bare icons, lettered titles", font=font(44), fill=INK)
    sheet.paste(close, (GAP, y0))
    sheet.paste(sign, (GAP, y1))
    d.text((GAP, y2), "The list (the third one as it is while saving is off)", font=font(30), fill=INK)
    x = GAP
    for p in panel:
        sheet.paste(p, (x, y2 + 46))
        x += p.width + GAP
    d.text((x, y2), "From 60 studs on a phone, 2 pixels to a point, Plot 6 in front", font=font(30), fill=INK)
    sheet.paste(phone, (x, y2 + 46))
    border = sky(work / "shot-border.png")
    left = low - phone.height - GAP
    cut = round(border.width * left / room)
    border = border.crop((0, (border.height - cut) // 2, border.width, (border.height + cut) // 2))
    sheet.paste(border.resize((room, left), Image.LANCZOS), (x, y2 + 46 + phone.height + GAP))
    d.text((GAP, sheet.height - 42), "Offline: the game's own panel code and part tables, drawn in Chromium and Blender. Made-up names, faces and "
           "numbers. Top views: Plot 6 left out; its seahorse is in no view. Not seen in Studio.", font=font(24), fill=INK)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print(out, sheet.size)
