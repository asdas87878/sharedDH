"""The shopkeepers' design sheet, drawn from the game's own tables (src/shared/Keepers.luau) with the stands as the hub
kit draws them (art/map/greybox/hub.json), each keeper and its props put where the game puts them.

    python tools/keepers/sheet.py             docs/attachments/hub-keepers-1.png: for every stand its keeper from the
                                              front and three-quarter, and as a player's camera sees it from the
                                              ring's middle and from the counter, idle and at the action's peak
    python tools/keepers/sheet.py poses       work/keepers/poses.png: each keeper's action at its peak, the look held
                                              at its two ends and up and down (a check, not for the vault)
    python tools/keepers/sheet.py <Id> ...    only these keepers (a quick look while one is being drawn)

Needs Blender (tools/blender/keeper_view.py) and Pillow."""
import json
import math
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


SCREEN = (1920, 1080)
SIDE = 0.42  # how far to one side of the ring's middle line the player stands in the play views (a share of its half)
PEAK = 0.5  # the moment of the action the play views show


def on_screen(eye, at, spot):
    """where `spot` is on the screen of a camera at `eye` looking at `at`: pixels from its top left"""
    f = [at[i] - eye[i] for i in range(3)]
    n = sum(v * v for v in f) ** 0.5
    f = [v / n for v in f]
    r = K.cross(f, [0.0, 1.0, 0.0])
    n = sum(v * v for v in r) ** 0.5
    r = [v / n for v in r]
    u = K.cross(r, f)
    d = [spot[i] - eye[i] for i in range(3)]
    deep = sum(d[i] * f[i] for i in range(3))
    focal = SCREEN[1] / 2 / math.tan(math.radians(K.CAMERA["fov"]) / 2)
    return (SCREEN[0] / 2 + focal * sum(d[i] * r[i] for i in range(3)) / deep,
            SCREEN[1] / 2 - focal * sum(d[i] * u[i] for i in range(3)) / deep)


def player(space, parts, where, side):
    """a plain grey figure where the player stands (two legs, a body, a head: 5 studs), facing the stand"""
    _eye, at = K.play_camera(space, parts, where, side)
    floor = space[1][3]
    turn = [[space[r][c] for c in range(3)] + [0.0] for r in range(3)] + [[0.0, 0.0, 0.0, 1.0]]
    grey, out = (150, 156, 168), []
    for size, x, y in (([0.9, 2, 1], 0.5, 1), ([0.9, 2, 1], -0.5, 1), ([2, 2, 1], 0, 3), ([1.2, 1.2, 1.2], 0, 4.6)):
        m = K.mul(K.move(at[0], floor, at[2]), K.mul(turn, K.move(x, y, 0)))
        out.append(K.box("Block", size, m, grey))
    return out


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
    scenes, shots, rows, cuts = {}, [], [[], [], [], [], [], []], {}
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
            # as a player sees it: the play camera itself (keepers.py: CAMERA), a whole 1920 x 1080 screen of which the
            # sheet shows the cut round the keeper at its true size. The player (the grey figure) stands a step to
            # one side of the ring's middle line, as their own character would otherwise cover the keeper
            head = K.point(kspace, [0, K.read_pivot(k, "Head")[1] * scale + 0.3, 0.3])
            for where, wtag in ((0, "mid"), (-1, "near")):
                eye, at = K.play_camera(space, parts, where, SIDE)
                for how, htag in (({"sway_t": k["Bob"][1] / 4}, "idle"), ({"sway_t": k["Bob"][1] / 4, "action_t": PEAK}, "act")):
                    name = f"{kid}_{wtag}_{htag}"
                    scenes[name] = {"boxes": K.keeper_boxes(data, k, kspace, scale, **how) + K.prop_boxes(data, k, space, scale)
                                    + K.station_boxes(parts) + player(space, parts, where, SIDE), "ground": GRASS, "floor": floor}
                    shots.append(shot(name, name, eye, at, K.CAMERA["fov"], SCREEN[0], SCREEN[1]))
                    cuts[name] = on_screen(eye, at, head)
            for r, tag in enumerate(("_front", "_three", "_mid_idle", "_mid_act", "_near_idle", "_near_act")):
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
    for name, (px, py) in cuts.items():  # the cut round the keeper, at the screen's own size
        path = os.path.join(WORK, name + ".png")
        screen = Image.open(path)
        left = min(max(0, int(px - SIZE / 2)), SCREEN[0] - SIZE)
        top = min(max(0, int(py - SIZE * 0.42)), SCREEN[1] - SIZE)
        screen.crop((left, top, left + SIZE, top + SIZE)).save(path)
    titles = [NAMES[k["Station"]] + ": " + k["Id"] for k in keepers]
    if poses:
        lay(pose_rows, titles, ["the action\nat its middle", "looking\nfull left", "looking\nfull right", "looking\nup", "looking down\nand aside"],
            os.path.join(WORK, "poses.png"), "A check of the engine's sums, drawn by the same tables.")
    else:
        lay(rows, titles, ["the keeper\nfront", "the keeper\nthree-quarter", "in play:\non the ring's\nmiddle, idle",
                           "in play:\nthe ring's\nmiddle, the\naction's peak", "in play:\nat the counter\n(the ring's\nnear edge), idle",
                           "in play:\nat the counter,\nthe action's\npeak"],
            OUT if not only else os.path.join(WORK, "try.png"),
            "Drawn in Blender from src/shared/Keepers.luau and the hub kit's stalls: no studs, a stand-in light. In play: the game's camera "
            "(12.5 studs behind the player's head, 20 degrees down, 70 degrees of view), a cut of a 1920 x 1080 screen at its true size.")


if __name__ == "__main__":
    main()
