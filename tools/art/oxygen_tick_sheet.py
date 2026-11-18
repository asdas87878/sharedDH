"""Oxygen ring tick sizes sheet (task s1, 2026-11-18).

Draws the live ring look (Kit.RingStyle 1: flat band, pure black hairline, the used part Kit.Deep half see-through,
the piece just lost white, the one before it fading) at several tick counts, and labels each row with the gap
between ticks. Numbers come from `--nums` (JSON from Config.secondsOn / Config.tickOf run in Lune, see the task
report), or the defaults below (the same numbers, 2026-11-18).

    python tools/art/oxygen_tick_sheet.py <out.png> [--nums nums.json]
"""

import json
import math
import sys

from PIL import Image, ImageDraw, ImageFont

SS = 4  # supersampling
AQUA = (51, 214, 240)
CORAL = (255, 90, 95)
DEEP = (10, 24, 44)
WATER = (28, 122, 178)
WHITE = (255, 255, 255)
INK = (24, 28, 40)
PAPER = (246, 247, 249)
BIG, THICK = 50, 16  # Rings.luau: BIG, BIG_THICK (HUD units = pixels on a 1080p desktop)
FLOOR = 0.2
FADE, FADE_SHARE = 0.3, 0.8  # Kit.RingLook.TickFade, TickFadeShare

# Config.secondsOn: a new player (100 max) on a Shallows Common, a land-10 Common at exactly its need
SHALLOWS, LAND10 = 5.287, 16.553


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    for d in ("/usr/share/fonts/TTF/", "/usr/share/fonts/truetype/dejavu/", "/usr/share/fonts/dejavu/"):
        try:
            return ImageFont.truetype(d + name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def blend(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ring(scale, left, held_from, broke_from, broke_fade, colour):
    """One ring on water, `scale` x game size. Fractions of the meter; the part left runs clockwise from the top."""
    size = int((BIG + 8) * scale)
    big = Image.new("RGB", (size * SS, size * SS), WATER)
    d = ImageDraw.Draw(big)
    c = size * SS / 2
    r_out = BIG / 2 * scale * SS
    r_in = (BIG / 2 - THICK) * scale * SS
    line = max(1.0, 0.6 * scale) * SS  # Kit.RingLook.Outline 0.6, never under a pixel

    def arc(a0, a1, fill):
        if a1 - a0 <= 1e-6:
            return
        box = (c - r_out, c - r_out, c + r_out, c + r_out)
        d.pieslice(box, -90 + 360 * a0, -90 + 360 * a1, fill=fill)

    arc(0, 1, blend(WATER, DEEP, 0.5))  # the used part, half see-through
    if broke_from > held_from:
        arc(held_from, broke_from, blend(WHITE, blend(WATER, DEEP, 0.5), broke_fade))
    if held_from > left:
        arc(left, held_from, WHITE)
    arc(0, left, colour)
    # the hole
    d.ellipse((c - r_in, c - r_in, c + r_in, c + r_in), fill=WATER)
    # black hairlines round the outside and the hole
    d.ellipse((c - r_out, c - r_out, c + r_out, c + r_out), outline=(0, 0, 0), width=round(line))
    d.ellipse((c - r_in - line, c - r_in - line, c + r_in + line, c + r_in + line), outline=(0, 0, 0), width=round(line))
    # the clockwise mirror: PIL's angles already run clockwise on screen (y down), start at the top
    return big.resize((size, size), Image.LANCZOS)


def states(ticks, piece):
    """full, mid-drain (white piece + breaking off), near-empty (red, white piece) as ring() arguments"""
    k_mid = round(0.6 / piece)
    mid = (k_mid * piece, (k_mid + 1) * piece, (k_mid + 2) * piece, 0.5)
    k_low = max(1, round(0.08 / piece))
    low = (k_low * piece, (k_low + 1) * piece, (k_low + 2) * piece, 0.75)
    return [(1, 0, 0, 1, AQUA), (*mid, AQUA), (*low, CORAL)]


def main():
    out = sys.argv[1]
    rows_in = None
    if "--nums" in sys.argv:
        rows_in = json.load(open(sys.argv[sys.argv.index("--nums") + 1]))
    options = [10, 20, 30, 40, 60, 80, 100]
    rows = []
    for n in options:
        floor = 0.5 if n == 10 else FLOOR
        row = {"ticks": n, "floor": floor}
        for key, secs in (("sh", SHALLOWS), ("l10", LAND10)):
            raw = secs / n
            gap = max(raw, floor)
            row[key] = {"raw": raw, "gap": gap, "share": gap / secs}
        if rows_in:
            for r in rows_in:
                if r["ticks"] == n:
                    for key in ("sh", "l10"):
                        row[key]["gap"] = r[key]["gap"]
                        row[key]["share"] = r[key]["share"]
        rows.append(row)

    verdict = {
        10: "LIVE now. Each tick a tenth: big, slow steps.",
        20: "Clean: every gap over the floor. A piece is 8 px on the edge at game size.",
        30: "Shallows hits the floor: a new player's fish ticks 26 times, not 30.",
        40: "Shallows merged to 26; deep fish 0.41 s. Piece 4 px: still reads.",
        60: "Piece 2.6 px: the white piece is a thin sliver. Deep fish 0.28 s.",
        80: "Piece 2 px: the white piece is a line. Reads close to a smooth drain.",
        100: "Piece 1.6 px: no white piece to see; deep Common at the floor too.",
    }

    S = 2.4  # rows drawn at 2.4 x game size
    ring_w = int((BIG + 8) * S)
    label_w, num_w, small_w = 300, 400, 150
    pad = 16
    head_h, row_h = 160, ring_w + 2 * pad
    width = label_w + 3 * (ring_w + pad) + small_w + num_w + pad
    height = head_h + row_h * len(rows) + 200
    sheet = Image.new("RGB", (width, height), PAPER)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 14), "Oxygen ring: tick sizes (s1, 2026-11-18)", font=font(30, True), fill=INK)
    d.multiline_text(
        (pad, 54),
        "The live look, drawn (not a Studio render). Rings at 2.4x game size, the game-size column 1x; each drawn\n"
        "with 1 / ticks pieces. Gap = seconds on the fish / ticks, so more ticks = faster ticks.",
        font=font(15),
        fill=INK,
    )
    x0 = label_w
    cols = ["full", "mid-drain: white\npiece + the one\nbefore, breaking off", "near-empty\n(red zone)", "game size\n(1x)"]
    xs = [x0, x0 + ring_w + pad, x0 + 2 * (ring_w + pad), x0 + 3 * (ring_w + pad)]
    for x, t in zip(xs, cols):
        d.multiline_text((x + 4, 100), t, font=font(14, True), fill=INK, spacing=2)
    d.multiline_text(
        (xs[3] + small_w + 4, 100),
        "gap between ticks:\nShallows Common (new player, 5.3 s)\nland-10 Common at its need (16.6 s)",
        font=font(14, True),
        fill=INK,
        spacing=2,
    )
    for i, row in enumerate(rows):
        y = head_h + i * row_h
        n = row["ticks"]
        if n == 10:
            d.rectangle((0, y, label_w - 1, y + row_h - 1), fill=(255, 240, 190))
        d.rectangle((x0 - 8, y, xs[3] + small_w - 8, y + row_h - 1), fill=WATER)
        d.text((pad, y + pad + 6), f"{n} ticks", font=font(26, True), fill=INK)
        d.text((pad, y + pad + 42), f"TickSize = {i + 1}", font=font(16), fill=INK)
        d.text((pad, y + pad + 66), f"each tick {360 / n:.1f}°, {math.pi * BIG / n:.1f} px", font=font(14), fill=INK)
        d.text((pad, y + pad + 86), "on the ring's edge at game size", font=font(14), fill=INK)
        st = states(n, 1 / n)
        for j, args in enumerate(st):
            sheet.paste(ring(S, *args), (xs[j], y + pad))
        # game size: mid-drain and near-empty
        sm = ring(1, *st[1])
        sheet.paste(sm, (xs[3] + 4, y + pad + 10))
        sm = ring(1, *st[2])
        sheet.paste(sm, (xs[3] + 4 + sm.width + 8, y + pad + 10))
        # numbers
        tx = xs[3] + small_w + 4
        ty = y + pad + 4
        for key, name in (("sh", "Shallows"), ("l10", "land 10")):
            v = row[key]
            gap = v["gap"]
            short = v["raw"] < row["floor"] - 1e-6
            colour = (190, 40, 40) if short else INK
            txt = f"{name}: {gap:.2f} s"
            if short:
                txt += f" floor\n   (wants {v['raw']:.2f} s: {round(1 / v['share'])} pieces)"
            d.multiline_text((tx, ty), txt, font=font(17, True), fill=colour, spacing=2)
            ty += 52 if short else 30
        fade = min(FADE, FADE_SHARE * row["l10"]["gap"])
        d.text((tx, ty + 2), f"fade on land 10: {fade:.2f} s", font=font(13), fill=INK)
        d.multiline_text((tx, ty + 24), wrap(verdict[n], 40), font=font(13), fill=INK, spacing=2)
    y = head_h + len(rows) * row_h + 14
    notes = [
        "Floor (proposed): 0.2 s between ticks (Oxygen.Tick, in every option past 10). Under it the white piece is",
        "on screen for fewer than 12 frames and reads as a flicker. A fish whose gap would be shorter takes bigger",
        "pieces instead (Config.tickOf), so its seconds never change. The fade after a break-off is at most 0.8 of the",
        "gap (Kit.RingLook.TickFadeShare), so one piece is gone before the next breaks off.",
        "Claude's pick: 20 (or 40 if Hugo wants it finer): every piece still has a white piece you can see.",
        "Past 60 the white piece is thinner than the black line round the ring.",
    ]
    for k, t in enumerate(notes):
        d.text((pad, y + k * 24), t, font=font(16, k == 4), fill=INK)
    sheet.save(out)
    print(out, sheet.size)


def wrap(text, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > width:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    lines.append(cur)
    return "\n".join(lines)


if __name__ == "__main__":
    main()
