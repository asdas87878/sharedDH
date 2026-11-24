"""Three fish's dives from the side, drawn from the numbers tools/dive/fish_dive_check.luau writes (its paths.json): the
game's own plan and steps, no Studio. Each body is its box's length and height as a plain oval, not the model.

usage: python3 tools/dive/dive_picture.py paths.json out.svg   (then rsvg-convert out.svg -o out.png)
"""
import json
import math
import sys

INK, SOFT, LINE = "#1d2a33", "#5c6b75", "#c9d3d9"
FISH, PATH, WATER, DOCK = "#2f7fb8", "#d9572b", "#e3f1f8", "#b9a58a"


def panel(p, floor, water, top, wide, tall):
    fr = p["frames"]
    back = min(f["mz"] for f in fr) - p["length"] * 0.55
    until = next((i for i, f in enumerate(fr) if f["t"] >= p["swap"]), len(fr) - 1)
    front = max(f["mz"] for f in fr[: until + 1]) + p["length"] * 0.6
    high = max(f["my"] for f in fr) + p["height"] * 0.6 + 6
    low = -max(14.0, p["height"] * 0.8 + 10)
    k = min((wide - 40) / (front - back), (tall - 60) / (high - low))
    x0 = (wide - k * (front - back)) / 2

    def X(z):
        return x0 + (z - back) * k

    def Y(y):
        return top + 44 + (high - y) * k

    out = [f'<text x="20" y="{top + 24}" font-size="18" font-weight="600" fill="{INK}">{p["name"]}, {p["tier"]}: '
           f'{p["length"]:.0f} studs long. In the water at {p["entry"]:.2f} s, the water fish takes over at {p["swap"]:.2f} s</text>']
    out.append(f'<rect x="{X(0):.1f}" y="{Y(0):.1f}" width="{wide - 20 - X(0):.1f}" height="{(0 - low) * k:.1f}" fill="{WATER}"/>')
    out.append(f'<rect x="20" y="{Y(floor):.1f}" width="{X(0) - 20:.1f}" height="{max(2, 4 * k):.1f}" fill="{DOCK}"/>')
    out.append(f'<line x1="{X(-2.4):.1f}" x2="{X(-2.4):.1f}" y1="{Y(floor) - 46:.1f}" y2="{Y(floor) + 6:.1f}" stroke="{INK}" stroke-width="1.5" stroke-dasharray="4 3"/>')
    out.append(f'<text x="{X(-2.4) - 6:.1f}" y="{Y(floor) - 36:.1f}" font-size="12" text-anchor="end" fill="{SOFT}">the line</text>')
    out.append(f'<line x1="{X(0):.1f}" x2="{wide - 20}" y1="{Y(water):.1f}" y2="{Y(water):.1f}" stroke="{LINE}" stroke-width="1.5"/>')
    shown = [0, until]
    for share in (0.22, 0.42, 0.62, 0.8):
        shown.append(int(until * share))
    for i in sorted(set(shown)):
        f = fr[i]
        a = -math.degrees(math.atan2(f["ly"], f["lz"]))
        rx, ry = p["length"] * k / 2, max(p["height"] * k / 2, 2)
        shade = 0.16 + 0.34 * i / max(until, 1)
        x, y = X(f["mz"]), Y(f["my"])
        out.append(f'<g transform="translate({x:.1f} {y:.1f}) rotate({a:.1f})"><ellipse rx="{rx:.1f}" ry="{ry:.1f}" fill="{FISH}" fill-opacity="{shade:.2f}" stroke="{FISH}" stroke-opacity="0.6"/>'
                   f'<line x1="{rx * 0.8:.1f}" x2="{rx:.1f}" y1="0" y2="0" stroke="{INK}" stroke-width="2"/></g>')
    pts = " ".join(f'{X(f["z"]):.1f},{Y(f["y"]):.1f}' for f in fr[: until + 1])
    out.append(f'<polyline points="{pts}" fill="none" stroke="{PATH}" stroke-width="2.5"/>')
    for i in sorted(set(shown)):
        out.append(f'<circle cx="{X(fr[i]["z"]):.1f}" cy="{Y(fr[i]["y"]):.1f}" r="3.5" fill="{PATH}"/>')
    return out


def main():
    d = json.load(open(sys.argv[1]))
    wide, tall = 1200, 360
    n = len(d["paths"])
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{wide}" height="{tall * n + 70}" font-family="sans-serif">',
           f'<rect width="100%" height="100%" fill="#ffffff"/>',
           f'<text x="20" y="32" font-size="22" font-weight="700" fill="{INK}">The fish\'s dive off the lip, from the side (from the game\'s own sums, not Studio)</text>',
           f'<text x="20" y="54" font-size="13" fill="{SOFT}">Orange: the rider. Blue: the fish\'s box as an oval, its dark end the nose. Each panel has its own scale. Grey line: where the server swaps the land fish for the water fish.</text>']
    for i, p in enumerate(d["paths"]):
        out += panel(p, d["floor"], d["waterY"], 62 + i * tall, wide, tall)
    out.append("</svg>")
    open(sys.argv[2], "w").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
