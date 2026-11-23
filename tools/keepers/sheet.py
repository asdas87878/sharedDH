"""The shopkeepers' design sheet, drawn from the game's own tables (src/shared/Keepers.luau) with the stands as the hub
kit draws them (art/map/greybox/hub.json), each keeper and its props put where the game puts them.

    python tools/keepers/sheet.py             docs/attachments/hub-keepers-1.png: for every stand its keeper from the
                                              front and three-quarter, and the stand as a player sees it, front and side
    python tools/keepers/sheet.py poses       work/keepers/poses.png: each keeper's action at its peak, the look held
                                              at its two ends and up and down (a check, not for the vault)
    python tools/keepers/sheet.py <Id> ...    only these keepers (a quick look while one is being drawn)

Needs Blender (tools/blender/keeper_view.py) and Pillow."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import keepers as K  # noqa: E402

WORK = os.path.join(K.ROOT, "work", "keepers")
OUT = os.path.join(K.ROOT, "docs", "attachments", "hub-keepers-1.png")
SIZE = 560
GRASS = (96, 190, 92)
NAMES = {"Sell": "SELL", "Auras": "AURAS", "Sub": "SUBMARINE", "Fuse": "FUSE"}


def font(size):
    for path in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def render(scenes, shots):
    os.makedirs(WORK, exist_ok=True)
    job = os.path.join(WORK, "job.json")
    json.dump({"scenes": scenes, "shots": shots}, open(job, "w"))
    run = subprocess.run(["blender", "--background", "--python", os.path.join(K.ROOT, "tools", "blender", "keeper_view.py"), "--", job],
                         capture_output=True, text=True)
    if run.returncode or "Traceback" in run.stderr:
        print(run.stdout[-3000:], run.stderr[-3000:])
        raise SystemExit("Blender failed")


def shot(scene, name, eye, at, fov, w=SIZE, h=SIZE):
    return {"scene": scene, "eye": eye, "at": at, "fov": fov, "w": w, "h": h, "out": os.path.join(WORK, name + ".png")}


def lay(rows, titles, heads, out, note):
    """a grid of the pictures in `rows` (lists of file names), a title over each column, a word before each row"""
    pad, top, left = 10, 64, 150
    cols = len(rows[0])
    w, h = left + cols * (SIZE + pad) + pad, top + len(rows) * (SIZE + pad) + 44
    sheet = Image.new("RGB", (w, h), (24, 30, 46))
    d = ImageDraw.Draw(sheet)
    for c, title in enumerate(titles):
        d.text((left + c * (SIZE + pad) + SIZE / 2, top / 2), title, font=font(30), fill=(255, 255, 255), anchor="mm")
    for r, row in enumerate(rows):
        y = top + r * (SIZE + pad)
        d.multiline_text((left / 2, y + SIZE / 2), heads[r], font=font(17), fill=(200, 212, 235), anchor="mm", align="center")
        for c, name in enumerate(row):
            sheet.paste(Image.open(os.path.join(WORK, name + ".png")).convert("RGB"), (left + c * (SIZE + pad), y))
    d.text((left, h - 30), note, font=font(16), fill=(170, 182, 205))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print("wrote", out)


def main():
    data = K.read()
    args = [a for a in sys.argv[1:]]
    poses = "poses" in args
    only = [a for a in args if a != "poses"]
    keepers = [k for k in data["List"] if not only or k["Id"] in only]
    hub = json.load(open(K.HUB))
    look = data["Look"]
    scenes, shots, rows = {}, [], [[], [], [], []]
    pose_rows = [[], [], [], [], []]
    for k in keepers:
        kid = k["Id"]
        parts = K.station(k["Station"], hub)
        space, scale = K.stand_space(parts, k["Stand"], look)
        lift = K.stand_lift(parts, space, scale, k, look)
        kspace = K.keeper_space(space, scale, k, lift)
        floor = space[1][3]
        here = lambda v, m=space: K.point(m, v)  # noqa: E731
        kat = lambda v, m=kspace: K.point(m, v)  # noqa: E731
        alone = K.keeper_boxes(data, k, kspace, scale)
        scenes[kid] = {"boxes": alone, "ground": None}
        scenes[kid + "Stand"] = {"boxes": alone + K.prop_boxes(data, k, space, scale) + K.station_boxes(parts), "ground": GRASS, "floor": floor}
        if not poses:
            tall = max(c[1] for b in alone for c in K.corners(b["m"], b["size"])) - kspace[1][3]
            back = max(1.0, tall / 5.9)  # a taller keeper is seen from further off, so its hat is in the picture
            shots.append(shot(kid, kid + "_front", kat([0, tall / 2 + 0.4, 11.5 * back]), kat([0, tall / 2 + 0.2, 0]), 34))
            shots.append(shot(kid, kid + "_three", kat([7.2 * back, tall / 2 + 1.7, 8.6 * back]), kat([0, tall / 2 + 0.1, 0]), 34))
            # as a player sees it: stood on the far side of the ring, the camera behind and above them
            if k["Stand"] == "Core":  # the machine is far bigger than a stall, and its ring further out
                shots.append(shot(kid + "Stand", kid + "_player", here([3, 12, 40]), here([2, 5.5, 0]), 30))
                shots.append(shot(kid + "Stand", kid + "_side", here([21, 9, 15]), here([4.5, 4.2, -0.5]), 38))
            else:
                shots.append(shot(kid + "Stand", kid + "_player", here([0, 9.5, 30]), here([0, 3.6, -1]), 30))
                shots.append(shot(kid + "Stand", kid + "_side", here([15, 7, 13]), here([0, 3.0, -1.5]), 44))
            for r, tag in enumerate(("_front", "_three", "_player", "_side")):
                rows[r].append(kid + tag)
        else:
            most = look["Body"] + look["Head"]
            for r, (tag, how) in enumerate((("_act", {"action_t": 0.5}), ("_left", {"yaw": most}), ("_right", {"yaw": -most}),
                                            ("_up", {"pitch": -look["Up"]}), ("_down", {"pitch": look["Down"], "yaw": 30}))):
                name = kid + tag
                scenes[name] = {"boxes": K.keeper_boxes(data, k, kspace, scale, **how) + K.prop_boxes(data, k, space, scale) + K.station_boxes(parts),
                                "ground": GRASS, "floor": floor}
                shots.append(shot(name, name, kat([4.5, 5.6, 12.5]), kat([0, 3.7, 0.4]), 30))
                pose_rows[r].append(name)
    render(scenes, shots)
    titles = [NAMES[k["Station"]] + ": " + k["Id"] for k in keepers]
    if poses:
        lay(pose_rows, titles, ["the action\nat its middle", "looking\nfull left", "looking\nfull right", "looking\nup", "looking down\nand aside"],
            os.path.join(WORK, "poses.png"), "A check of the engine's sums, drawn by the same tables.")
    else:
        lay(rows, titles, ["the keeper\nfront", "the keeper\nthree-quarter", "the stand\nas a player\nsees it", "the stand\nfrom its side"],
            OUT if not only else os.path.join(WORK, "try.png"),
            "Drawn in Blender from src/shared/Keepers.luau and the hub kit's stalls: no studs, a stand-in light. Plain Roblox parts in the game.")


if __name__ == "__main__":
    main()
