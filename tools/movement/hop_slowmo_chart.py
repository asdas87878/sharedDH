"""The faster, slow-mo hop (task h2, 2026-11-14): before/after chart from two Studio runs of the movement driver's `air`
command, with glide screenshots under it.

    python tools/movement/hop_slowmo_chart.py <before.log> <after.log> <out.png> [shot_before.png shot_after1.png ...]

The logs are the W1Log text (lines "AIR <label>#1 t,speed,height,...: t,speed,height,reach,in,in180 ..."). Speed across
the water, height above where the hop left and the hook's reach, every 0.1 s, off a slow (Boxfish 40), a normal
(Anglerfish 74) and a fast fish (Ember Serpent 138). Screenshots are cropped to the middle of the Studio window.
Needs rsvg-convert and Pillow.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FISH = [("slow", "Boxfish, 40 st/s"), ("normal", "Anglerfish, 74 st/s"), ("fast", "Ember Serpent, 138 st/s")]
ROWS = [("speed", 1, "speed across the water, studs/s", 200), ("height", 2, "height above where you left, studs", None),
        ("reach", 3, "the hook's reach, studs", 160)]
INK, INK2, GRID = "#1f1f1d", "#5d5c56", "#e4e2da"
C_BEFORE, C_AFTER = "#9a988f", "#2a78d6"
PW, PH, GX, GY, LEFT, TOP = 360, 190, 80, 70, 80, 185


def series(text, label):
    m = re.search(rf"AIR {re.escape(label)}#1 t,speed,height,reach,inreach,in180: ([^\n]+)", text)
    rows = []
    for item in m.group(1).split():
        t, sp, h, r, *_ = item.split(",")
        if float(r) >= 0:  # (-1: the hop has ended, no reach)
            rows.append((float(t), float(sp), float(h), float(r)))
    return rows


def chart(before, after, out_svg):
    b, a = before.read_text(), after.read_text()
    w = LEFT + 3 * PW + 2 * GX + 60
    h = TOP + 3 * PH + 2 * GY + 70
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" font-family="DejaVu Sans">',
         f'<rect width="{w}" height="{h}" fill="#ffffff"/>',
         f'<text x="{LEFT}" y="44" font-size="26" font-weight="bold" fill="{INK}">The hop: faster, the fall-off later (measured in Studio, 2026-11-14)</text>',
         f'<text x="{LEFT}" y="76" font-size="16" fill="{INK2}">Launch 0.85 to 1.15, HopBoost 15 to 24, SpeedHalf 1.5 to 2.1 s. Same window. Flown by script with no grab; one dot every 0.1 s.</text>',
         f'<line x1="{LEFT}" y1="104" x2="{LEFT + 40}" y2="104" stroke="{C_BEFORE}" stroke-width="4"/>',
         f'<text x="{LEFT + 50}" y="110" font-size="16" fill="{INK}">before</text>',
         f'<line x1="{LEFT + 140}" y1="104" x2="{LEFT + 180}" y2="104" stroke="{C_AFTER}" stroke-width="4"/>',
         f'<text x="{LEFT + 190}" y="110" font-size="16" fill="{INK}">after</text>']
    tmax = 3.8
    for ri, (name, col, title, fixed) in enumerate(ROWS):
        data = {}
        for key, _ in FISH:
            data[key] = (series(b, key), series(a, key))
        if fixed:
            lo, hi = 0, fixed
        else:
            vals = [r[col] for pair in data.values() for ser in pair for r in ser]
            lo, hi = (min(vals) // 10) * 10, (max(vals) // 10 + 1) * 10
        for ci, (key, label) in enumerate(FISH):
            x0 = LEFT + ci * (PW + GX)
            y0 = TOP + ri * (PH + GY)
            if ri == 0:
                s.append(f'<text x="{x0}" y="{y0 - 22}" font-size="18" font-weight="bold" fill="{INK}">off a {key} fish ({label})</text>')
            s.append(f'<text x="{x0}" y="{y0 - 4}" font-size="13" fill="{INK2}">{title}</text>')
            step = 50 if hi - lo > 120 else 10
            v = lo
            while v <= hi + 0.01:
                y = y0 + PH - (v - lo) / (hi - lo) * PH
                s.append(f'<line x1="{x0}" y1="{y:.1f}" x2="{x0 + PW}" y2="{y:.1f}" stroke="{GRID}"/>')
                s.append(f'<text x="{x0 - 8}" y="{y + 4:.1f}" font-size="12" text-anchor="end" fill="{INK2}">{v:.0f}</text>')
                v += step
            for t in range(0, 4):
                x = x0 + t / tmax * PW
                s.append(f'<line x1="{x:.1f}" y1="{y0}" x2="{x:.1f}" y2="{y0 + PH}" stroke="{GRID}"/>')
                s.append(f'<text x="{x:.1f}" y="{y0 + PH + 16}" font-size="12" text-anchor="middle" fill="{INK2}">{t} s</text>')
            for ser, colour in ((data[key][0], C_BEFORE), (data[key][1], C_AFTER)):
                pts = " ".join(f"{x0 + r[0] / tmax * PW:.1f},{y0 + PH - (r[col] - lo) / (hi - lo) * PH:.1f}" for r in ser)
                s.append(f'<polyline points="{pts}" fill="none" stroke="{colour}" stroke-width="3"/>')
                for r in ser:
                    s.append(f'<circle cx="{x0 + r[0] / tmax * PW:.1f}" cy="{y0 + PH - (r[col] - lo) / (hi - lo) * PH:.1f}" r="2.2" fill="{colour}"/>')
            if name == "speed":
                (sb, sa) = data[key]
                dist = lambda ser: sum(r[1] for r in ser) * 0.1
                s.append(f'<text x="{x0 + PW - 4}" y="{y0 + PH - 12}" font-size="13" text-anchor="end" fill="{INK}">leaves at {sb[0][1]:.0f} → {sa[0][1]:.0f}; along ≈{dist(sb):.0f} → {dist(sa):.0f} studs</text>')
    s.append("</svg>")
    out_svg.write_text("\n".join(s))


def main():
    before, after, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    shots = [Path(p) for p in sys.argv[4:]]
    with tempfile.TemporaryDirectory() as tmp:
        svg, png = Path(tmp) / "c.svg", Path(tmp) / "c.png"
        chart(before, after, svg)
        subprocess.run(["rsvg-convert", str(svg), "-o", str(png)], check=True)
        top = Image.open(png).convert("RGB")
    if not shots:
        top.save(out)
        return
    font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 18)
    cw = (top.width - 40 * (len(shots) + 1)) // len(shots)
    ch = int(cw * 0.6)
    sheet = Image.new("RGB", (top.width, top.height + ch + 90), "white")
    sheet.paste(top, (0, 0))
    d = ImageDraw.Draw(sheet)
    for i, p in enumerate(shots):
        im = Image.open(p).convert("RGB").crop((300, 200, 1800, 1100)).resize((cw, ch))
        x = 40 + i * (cw + 40)
        y = top.height + 50
        sheet.paste(im, (x, y))
        caption = "before: white balls along the glide" if i == 0 else f"after {i}: the glide, no balls"
        d.text((x, y - 32), caption, fill=INK, font=font)
    sheet.save(out)


if __name__ == "__main__":
    main()
