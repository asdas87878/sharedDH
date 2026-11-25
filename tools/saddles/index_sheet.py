"""The saddles in the Index, and one of them worn on very different fish, as one picture (NULLROOM task s2).

    python tools/saddles/index_sheet.py [draw]    docs/attachments/saddles-index.png; "draw": the Blender pictures and the
                                                  dumps of the last run are used again

The windows are the game's own code (tools/index/panel_test.luau's dumps), drawn as tools/index/look_picture.py draws
them. The saddles in them are the game's own parts (tools/saddles/saddle_parity.luau), drawn by Blender from where
UI.SaddlePicture's camera looks: in the game they are ViewportFrames, so their light is a little different there.
Needs numpy and Pillow (work/.venv), Blender, Chrome, and fit.py's work/saddles/check.json.
"""
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(HERE), str(ROOT / "tools/index")]
import draw as D  # noqa: E402
import fish as F  # noqa: E402
import look_picture as LP  # noqa: E402
import saddles as S  # noqa: E402
import sheet as SH  # noqa: E402

OUT = ROOT / "docs/attachments/saddles-index.png"
WORK = Path(D.WORK)
WORN = "2B"
# kind, size, what to say, from where
FISH = [("Clownfish", "Tiny", "smallest fish", None), ("SeaTurtle", "Big", "shell", None), ("MantaRay", "Normal", "ray", None),
        ("MorayEel", "Giant", "eel", None), ("Octopus", "Normal", "octopus", None), ("BlueWhale", "Colossal", "biggest fish", None)]
W, H = 560, 470


class Page(LP.Page):
    def picture(self, image):
        if image.startswith("saddle:"):
            return WORK / f"ui_{image[7:]}.png"
        return super().picture(image)

    def node(self, n, k, layout=None):
        key = n["Attributes"].get("Saddle") if n["Class"] == "ViewportFrame" else None
        if key:
            n = dict(n, Class="ImageLabel", Children=[], Props=dict(n["Props"], Image="saddle:" + key, ScaleType="Fit"))
        return super().node(n, k, layout)


def alone():
    """each design by itself, seen as UI.SaddlePicture sees it, cut to its edges"""
    scenes, shots = {}, []
    for key in S.PICKS:
        scenes["u" + key] = {"fish": [], "parts": D.place(S.build(S.design(key), S.plain()), (0, 0, 0))}
        eye = np.array([5.2, 4.6, 8.2]) / np.linalg.norm([5.2, 4.6, 8.2]) * 26
        shots.append(D.shot("u" + key, "u_" + key, eye + [0, 1.5, 0], (0, 1.5, 0), 960, 960, fov=30))
    D.render(scenes, shots, "uis")
    for key in S.PICKS:
        im = Image.open(WORK / f"u_{key}.png")
        box = im.getchannel("A").point(lambda a: 255 * (a > 8)).getbbox()
        assert box[0] > 0 and box[1] > 0 and box[2] < 960 and box[3] < 960, key
        im.crop(box).save(WORK / f"ui_{key}.png")


def on_fish():
    scenes, shots = {}, []
    for id, tier, _, view in FISH:
        sc, at, fit, f, s = SH.on_fish(WORN, id, tier)
        far = 1.0 + 0.2 * (fit["grow"] - 1)
        scenes["w" + id] = sc
        shots.append(D.shot("w" + id, "w_" + id, at + np.array(view or [7.4, 5.2, 10.2]) * far, at + np.array([0, 1.0, 0.2]), W * 3 // 2, H * 3 // 2, fov=36))
        r = float(np.linalg.norm(f.size * s))
        shots.append(D.shot("w" + id, "w_far_" + id, np.array([0.62, 0.42, 0.75]) * r * 1.4, (0, 0, 0), 420, 300, fov=33))
    D.render(scenes, shots, "wrn")


def main():
    if "draw" not in sys.argv[1:]:
        os.environ.setdefault("SADDLE_BLENDERS", "1")
        alone()
        on_fish()
        LP.build()
    LP.Page = Page
    s = LP.Sheet()
    pc = (1440, 912)

    def tag(text, size=22):
        return f'<div style="font:600 {size}px DejaVu Sans;color:#dfe8fa;margin:0 0 8px">{text}</div>'

    def block(text, inner):
        return f"<div>{tag(text)}{inner}</div>"

    def small(state, width):
        z = width / pc[0]
        return (f'<div style="width:{width}px;height:{pc[1] * z:.0f}px;overflow:hidden">'
                f'<div style="zoom:{z:.4f}">{s.scene(state, pc)}</div></div>')

    def phone(state, z):
        return f'<div style="zoom:{z}">{s.scene(state)}</div>'

    def fish(id, tier, note):
        f = F.load(id)
        return (f'<div style="position:relative;width:366px"><div style="height:308px;border-radius:10px;overflow:hidden;background:{SH.WATER[f.zone - 1]}">'
                f'<img src="{(WORK / f"w_{id}.png").as_uri()}" style="width:366px;height:308px;display:block"></div>'
                f'<img src="{(WORK / f"w_far_{id}.png").as_uri()}" style="position:absolute;right:6px;top:6px;width:112px;height:80px;background:#fff;border-radius:8px">'
                f'<div style="font:600 17px DejaVu Sans;color:#dfe8fa;margin-top:6px">{f.name}, {tier} ({note})</div></div>')

    html = f"""<div style="width:2300px;padding:24px;display:flex;flex-direction:column;gap:26px">
{tag("Saddles in the Index: claim a whole land, wear its saddle on every fish you ride. Drawn offline from our own code", 23)}
<div style="display:flex;gap:26px">{block("1. The land's reward, on its banner: here the Reef, claimed, its saddle worn. A press on it opens the Saddles page", small("look_saddle_pc_worn", 1440))}
<div style="display:flex;flex-direction:column;gap:26px">
{block("2. Not claimed yet: locked, with what it is", small("look_saddle_pc_locked", 800))}
{block("3. Claimed: the saddle is theirs", small("look_saddle_pc_claimed", 800))}</div></div>
<div style="display:flex;gap:26px">{block("4. The Saddles page: one worn, two more theirs, one to claim, six locked", small("look_saddle_pc_page", 1300))}
<div style="display:flex;flex-direction:column;gap:26px">
{block("5. Phone sideways, 667 x 375", phone("look_saddle_wide_worn", 1.4))}
{block("6. Its Saddles page", phone("look_saddle_wide_page", 1.4))}</div></div>
<div style="display:flex;gap:26px">
{block("7. Phone upright, 375 x 812", phone("look_saddle_tall_locked", 1.2))}
{block("8. Its Saddles page", phone("look_saddle_tall_page", 1.2))}
<div style="width:1250px">{tag(f"9. One worn saddle ({WORN}) on six very different fish, whole fish in the corner")}
<div style="display:flex;flex-wrap:wrap;gap:20px 26px">{"".join(fish(*x[:3]) for x in FISH)}</div></div></div></div>"""
    wide, high = 2348, 4200
    s.shoot(html, OUT, wide, high)
    im = Image.open(OUT).convert("RGB")
    bg = im.getpixel((2, high - 2))
    foot = next(y for y in range(high - 1, 0, -1) if any(im.getpixel((x, y)) != bg for x in range(0, wide, 8)))
    im.crop((0, 0, wide, foot + 24)).save(OUT, optimize=True)
    print(OUT, im.size, foot, f"{OUT.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
