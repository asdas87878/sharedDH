"""Draws the Index's window offline, from the tree the real game code built (NULLROOM task h2).

tools/index/panel_test.luau builds the real UI.IndexPanel in Lune and, given a folder, writes each state's tree there
as JSON (every instance, its class and properties). This turns a tree into a web page that lays it out by Roblox's
rules (UDim2 sizes and places, anchor points, UIScale, UIPadding, UIListLayout, UIGridLayout, UICorner, UIStroke,
UIGradient, ZIndex, clipping) and photographs it with headless Chromium. So the picture is of what the code made, not a
drawing of what it should make. What it is NOT: Roblox's own renderer. Letters are a hair different in width, the fish
pictures are the partner's renders cut from docs/attachments/fish-icons (in the live game, until those pages are
uploaded, they are the live models), and the open spring and the shines do not show. Studio has the last word.

    rojo build -o /tmp/idx/place.rbxl
    lune run tools/index/panel_test.luau /tmp/idx/place.rbxl /tmp/idx/dump
    python tools/index/panel_picture.py /tmp/idx/dump docs/attachments
"""
import html
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(tempfile.gettempdir()) / "rideafish_index_picture"
CHROME = next((p for p in ("chromium", "chromium-browser", "google-chrome", "chrome") if shutil.which(p)), None)
FONTS = sorted(Path.home().glob(".var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content/fonts"))
FONTS += sorted(Path.home().glob("AppData/Local/Roblox/Versions/*/content/fonts"))

# The uploaded pictures the window uses, by their asset id, as the files they were uploaded from
LOCAL = {
    "133981557523389": ROOT / "art/ui/icons/oxygen.png",
    "119031387165673": ROOT / "art/ui/icons/cash.png",
    "136062585112653": ROOT / "art/ui/icons/index.png",
    "139519009824812": ROOT / "art/ui/icons/shop.png",
    "74391096180253": ROOT / "art/ui/tiles/emboss_square.png",
}
GUI = {"Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame", "ViewportFrame",
       "CanvasGroup"}


def fish_icons():
    """each fish's render cut out of the icon pages (UI/FishIcons.luau says where), as its own file"""
    out = WORK / "fish"
    out.mkdir(parents=True, exist_ok=True)
    source = (ROOT / "src/client/UI/FishIcons.luau").read_text()
    pages = {}
    found = {}
    for name, page, x, y, w, h in re.findall(
            r"(\w+) = \{ Page = (\d+), X = (\d+), Y = (\d+), W = (\d+), H = (\d+)", source):
        file = out / f"{name}.png"
        if not file.exists():
            if page not in pages:
                pages[page] = Image.open(ROOT / f"docs/attachments/fish-icons/fish_icons_{page}.png").convert("RGBA")
            x, y, w, h = int(x), int(y), int(w), int(h)
            pages[page].crop((x, y, x + w, y + h)).save(file)
        found[name] = file
    return found


def rgba(colour, alpha=1.0):
    return f"rgba({colour[0]},{colour[1]},{colour[2]},{max(0.0, min(1.0, alpha)):.3f})"


def child(node, cls):
    return next((c for c in node["Children"] if c["Class"] == cls), None)


def gradient(g, tint=(255, 255, 255), alpha=1.0):
    """a UIGradient as CSS: its colours (times the face's own) and its see-through, along its turn"""
    p = g["Props"]
    colours = p.get("Color") or [[0, [255, 255, 255]], [1, [255, 255, 255]]]
    clear = p.get("Transparency") or [[0, 0], [1, 0]]

    def at(points, t, lerp):
        for (t0, v0), (t1, v1) in zip(points, points[1:]):
            if t0 <= t <= t1:
                f = 0 if t1 == t0 else (t - t0) / (t1 - t0)
                return lerp(v0, v1, f)
        return points[-1][1]

    times = sorted({t for t, _ in colours} | {t for t, _ in clear})
    stops = []
    for t in times:
        c = at(colours, t, lambda a, b, f: [a[i] + (b[i] - a[i]) * f for i in range(3)])
        a = at(clear, t, lambda a, b, f: a + (b - a) * f)
        c = [round(c[i] * tint[i] / 255) for i in range(3)]
        stops.append(f"{rgba(c, alpha * (1 - a))} {t * 100:.1f}%")
    return f"linear-gradient({p.get('Rotation', 0) + 90}deg, {', '.join(stops)})"


class Page:
    def __init__(self, icons):
        self.icons = icons

    def picture(self, image):
        if image.startswith("fish:"):
            return self.icons.get(image[5:])
        match = re.search(r"(\d+)$", image)
        return LOCAL.get(match.group(1)) if match else None

    def node(self, n, k, layout=None):
        """one GuiObject and all under it; k is how many pixels a point is here (the UIScales above)"""
        p = n["Props"]
        if n["Class"] not in GUI or not p.get("Visible", True):
            return ""
        scale = child(n, "UIScale")
        own = scale["Props"].get("Scale", 1) if scale else 1
        kk = k * own
        size, place, anchor = p["Size"], p["Position"], p["AnchorPoint"]
        auto = p.get("AutomaticSize", "None")
        wide = f"calc(({size[0] * 100}% + {size[1] * k}px) * {own})"
        high = f"calc(({size[2] * 100}% + {size[3] * k}px) * {own})"
        style = [f"z-index:{p.get('ZIndex', 1)}"]
        if layout == "grid":
            style += ["position:relative"]
        elif layout == "flex":
            style += ["position:relative", "flex:none", f"order:{p.get('LayoutOrder', 0)}"]
        else:
            style += ["position:absolute", f"left:calc({place[0] * 100}% + {place[1] * k}px)",
                      f"top:calc({place[2] * 100}% + {place[3] * k}px)"]
        if layout != "grid":
            style.append(f"min-width:{wide};width:max-content" if auto in ("X", "XY") else f"width:{wide}")
            style.append(f"min-height:{high};height:max-content" if auto in ("Y", "XY") else f"height:{high}")
        moves = []
        if not layout and (anchor[0] or anchor[1]):
            moves.append(f"translate({-anchor[0] * 100}%, {-anchor[1] * 100}%)")
        if p.get("Rotation"):
            moves.append(f"rotate({p['Rotation']}deg)")
        if moves:
            style.append("transform:" + " ".join(moves))

        corner = child(n, "UICorner")
        radius = "0px"
        if corner:
            r = corner["Props"]["CornerRadius"]
            radius = "9999px" if r[0] >= 0.5 else f"{r[1] * kk}px"
            style.append(f"border-radius:{radius}")
        text = n["Class"] in ("TextLabel", "TextButton")
        fill = child(n, "UIGradient")
        if fill and not fill["Props"].get("Enabled", True):
            fill = None
        see = 1 - p.get("BackgroundTransparency", 0)
        if see > 0:
            colour = p.get("BackgroundColor3", [255, 255, 255])
            if fill:
                style.append(f"background:{gradient(fill, colour, see)}")
            else:
                style.append(f"background:{rgba(colour, see)}")

        inner = []
        stroke = child(n, "UIStroke")
        if stroke and not (text and stroke["Props"].get("ApplyStrokeMode", "Contextual") == "Contextual"):
            s = stroke["Props"]
            t = s.get("Thickness", 1) * kk
            line = child(stroke, "UIGradient")
            ink = gradient(line, s["Color"], 1 - s.get("Transparency", 0)) if line else rgba(
                s["Color"], 1 - s.get("Transparency", 0))
            inner.append(
                f'<div class="s" style="inset:{-t}px;padding:{t}px;background:{ink};'
                f'border-radius:calc({radius} + {t}px)"></div>')

        if n["Class"] in ("ImageLabel", "ImageButton") and p.get("Image"):
            inner.append(self.image(n, kk, fill))
        if text and p.get("Text"):
            inner.append(self.text(n, kk, fill, stroke))

        pad = child(n, "UIPadding")
        inset = "0"
        if pad:
            q = pad["Props"]
            inset = " ".join(f"{q[side][1] * kk}px" for side in ("PaddingTop", "PaddingRight", "PaddingBottom",
                                                                 "PaddingLeft"))
        rows = child(n, "UIListLayout")
        grid = child(n, "UIGridLayout")
        how, kind = "", None
        if rows:
            q = rows["Props"]
            across = q.get("FillDirection") == "Horizontal"
            ends = {"Left": "flex-start", "Top": "flex-start", "Center": "center", "Right": "flex-end",
                    "Bottom": "flex-end"}
            h, v = ends[q.get("HorizontalAlignment", "Left")], ends[q.get("VerticalAlignment", "Top")]
            how = (f"display:flex;flex-direction:{'row' if across else 'column'};gap:{q['Padding'][1] * kk}px;"
                   f"justify-content:{h if across else v};align-items:{v if across else h}")
            kind = "flex"
        elif grid:
            q = grid["Props"]
            cell, gap = q["CellSize"], q["CellPadding"]
            most = q.get("FillDirectionMaxCells", 0) or 99
            how = (f"display:grid;grid-template-columns:repeat({most}, {cell[1] * kk}px);"
                   f"grid-auto-rows:{cell[3] * kk}px;gap:{gap[3] * kk}px {gap[1] * kk}px;align-content:start")
            kind = "grid"
        kids = n["Children"]
        if kind:
            kids = sorted(kids, key=lambda c: c["Props"].get("LayoutOrder", 0))
        body = "".join(self.node(c, kk, kind) for c in kids)
        clip = "overflow:hidden;" if p.get("ClipsDescendants") or n["Class"] == "ScrollingFrame" else ""
        fits = "position:relative;" if auto != "None" and kind else "position:absolute;inset:0;"
        if body:
            inner.append(f'<div style="{fits}{clip}border-radius:inherit">'
                         f'<div style="{"position:relative;" if auto != "None" and kind else "position:absolute;"}'
                         f'inset:{inset};{how}">{body}</div></div>')
        name = html.escape(p.get("Name", ""))
        return f'<div data-n="{name}" style="{";".join(style)}">{"".join(inner)}</div>'

    def image(self, n, k, fill):
        p = n["Props"]
        file = self.picture(p["Image"])
        if not file:
            return ""
        url = file.as_uri()
        see = 1 - p.get("ImageTransparency", 0)
        style = [f"opacity:{see:.3f}"]
        if fill:
            style.append(f"-webkit-mask-image:{gradient(fill)}")
        colour = p.get("ImageColor3", [255, 255, 255])
        if p.get("ScaleType") == "Tile":
            tile = p["TileSize"]
            style.append(f"background:url({url}) 0 0/{tile[1] * k}px {tile[3] * k}px repeat")
        elif colour != [255, 255, 255]:
            # painted one colour: the picture's shape in that colour
            style.append(f"background:{rgba(colour)};-webkit-mask:url({url}) center/contain no-repeat")
        else:
            style.append(f"background:url({url}) center/contain no-repeat")
        return f'<div class="i" style="{";".join(style)}"></div>'

    def text(self, n, k, fill, stroke):
        p = n["Props"]
        ends = {"Left": "flex-start", "Top": "flex-start", "Center": "center", "Right": "flex-end",
                "Bottom": "flex-end"}
        style = [f"font-size:{p.get('TextSize', 14) * k}px",
                 f"justify-content:{ends[p.get('TextXAlignment', 'Center')]}",
                 f"align-items:{ends[p.get('TextYAlignment', 'Center')]}",
                 f"text-align:{p.get('TextXAlignment', 'Center').lower()}",
                 f"white-space:{'pre-wrap' if p.get('TextWrapped') else 'pre'}"]
        if n["Props"].get("AutomaticSize", "None") == "None":
            style.append("position:absolute;inset:0")
        words = html.escape(p["Text"])
        colour = rgba(p.get("TextColor3", [255, 255, 255]), 1 - p.get("TextTransparency", 0))
        under = ""
        if stroke:
            s = stroke["Props"]
            under = (f'<span style="-webkit-text-stroke:{s.get("Thickness", 1) * k * 2}px {rgba(s["Color"])};'
                     f'color:{rgba(s["Color"])}">{words}</span>')
        if fill:
            over = (f'<span style="background:{gradient(fill, p.get("TextColor3", [255, 255, 255]))};'
                    f'-webkit-background-clip:text;-webkit-text-fill-color:transparent">{words}</span>')
        else:
            over = f'<span style="color:{colour}">{words}</span>'
        return f'<div class="t" style="{";".join(style)}"><span class="w">{under}{over}</span></div>'


def draw(dump, out, icons, dpr):
    data = json.loads(dump.read_text())
    wide, high = data["View"]
    font = next((f / "FredokaOne-Regular.ttf" for f in reversed(FONTS) if (f / "FredokaOne-Regular.ttf").exists()),
                None)
    face = f"@font-face{{font-family:F;src:url({font.as_uri()})}}" if font else ""
    page = Page(icons)
    body = "".join(page.node(c, 1) for c in data["Tree"]["Children"])
    doc = f"""<!doctype html><meta charset="utf-8"><style>{face}
html,body{{margin:0;width:{wide}px;height:{high}px;overflow:hidden}}
body{{position:relative;font-family:F,'Fredoka One',sans-serif;line-height:1.12;
background:linear-gradient(180deg,#58c4f4 0%,#2f8fdc 55%,#1c5fb4 100%)}}
div{{box-sizing:border-box}}
.s{{position:absolute;pointer-events:none;-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);
-webkit-mask-composite:xor;mask-composite:exclude}}
.i{{position:absolute;inset:0}}
.t{{display:flex;position:relative;width:100%;height:100%}}
.w{{display:inline-grid}}
.w>span{{grid-area:1/1}}
</style>{body}"""
    WORK.mkdir(parents=True, exist_ok=True)
    file = WORK / (dump.stem + ".html")
    file.write_text(doc)
    png = out / f"index-panel-offline-{dump.stem}.png"
    subprocess.run([CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", f"--force-device-scale-factor={dpr}",
                    f"--window-size={wide},{high}", f"--screenshot={png}", file.as_uri()],
                   check=True, capture_output=True, timeout=120)
    return png


def main():
    if not CHROME:
        sys.exit("no Chromium or Chrome found")
    dumps = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else WORK
    out.mkdir(parents=True, exist_ok=True)
    icons = fish_icons()
    for dump in sorted(dumps.glob("*.json")):
        view = json.loads(dump.read_text())["View"]
        print(draw(dump, out, icons, 2 if view[1] < 600 else 1))


if __name__ == "__main__":
    main()
