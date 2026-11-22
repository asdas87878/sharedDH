"""The hub study's options, built and drawn (2026-11-20; docs/design/hub-layout.md). The user: "need to do a full study of
how we can make the dive in platform on the floor better placed and subsequently the walls around it. Additionally,
we will need more space between the back aquariums and the walls behind it. not too much".

Each option is a trial build of the map generator with HUB_TRY numbers (tools/map/greybox.py) into
art/map/hub_study/<option>/, then a plan from above: the generator's walls, floor and strip, with the hub's models as
they stand in the place now (art/map/hub_study/dump.csv, read from Studio) drawn on top, unmoved.

usage: python tools/map/hub_options.py [option ...]     (default: all) -> art/map/hub_study/plan_<option>.png + sheet

Built before W32 went in (2026-11-22): its numbers are offsets from the hub as it was then (FRONT -48, HUB_BACK -320),
and dump.csv is that place. W32 is now the generator's own default, so a new study needs its options and SHIFT
rewritten from the current numbers and a fresh dump."""
import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_plan  # noqa: E402

from PIL import Image, ImageDraw, ImageFont  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STUDY = os.path.join(ROOT, "art", "map", "hub_study")
BACK = {"HUB_BACK": -328, "PLOT_GAP": 15}  # 8 more behind the back row: the wall moves back, the tanks stay
OPTIONS = {
    "now": ({}, "Now: the strip inside the neck, 7 behind the back tanks"),
    "A": (dict(BACK, STRIP_IN=32), "A. The strip carried 32 out onto the floor; walls as now"),
    "B": (dict(BACK, STRIP_IN=32, STRIP_WIDE=16, GATE_TURN=17), "B. A landing 128 wide on the floor; the mouth's corners squarer"),
    "C": (dict(BACK, FRONT=-24, STRIP_IN=24, GATE_TURN=17), "C. A thinner front wall: the strip half in the gap, half on the floor"),
    # the user, 2026-11-20: "nah the strip is too long, we might need to move the water foward even to make it more
    # accurate". The water's edge comes in toward the hub: the cut through the front wall (and the strip in it) is
    # shorter, and the whole hub with everything in it moves the same way, so the floor keeps its size and the
    # user's placing keeps its distances (SHIFT: how far the hub's models move toward the water)
    "W24": (dict(HUB_BACK=-328 + 24, PLOT_GAP=15, FRONT=-24), "W24. Water 24 nearer: strip 24 deep, the hub moved 24 toward it"),
    "W32": (dict(HUB_BACK=-328 + 16, PLOT_GAP=15, FRONT=-32), "W32. Water 16 nearer: strip 32 deep, the hub moved 16 toward it"),
}
SHIFT = {"W24": 24.0, "W32": 16.0}


def build(name, numbers):
    out = os.path.join(STUDY, name)
    env = dict(os.environ, GREYBOX_OUT=out, HUB_TRY=json.dumps(numbers))
    env.pop("PROPS2", None)
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "map", "greybox.py")], env=env, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stderr[-2000:])
    return json.load(open(os.path.join(out, "parts.json")))["parts"]


def rows_of(parts):
    """the generator's parts in the hub's box as plan rows (Studio coordinates: x + 3000)"""
    rows = []
    for p in parts:
        x, y, z = p["p"]
        if abs(x) > 270 or not -440 < z < 140 or p["k"] in ("prop", "set", "setglow", "setsmoke", "barrier", "figure"):
            continue
        ax = p["x"]
        ry = math.degrees(math.atan2(-ax[2], ax[0]))
        top = y + abs(p["y"][1]) * p["s"][1] / 2
        if top < -1:
            continue
        rows.append({"x": x + 3000, "z": z, "sx": p["s"][0], "sz": p["s"][2], "ry": ry, "top": top, "bot": y - p["s"][1] / 2,
                     "c": "%02x%02x%02x" % tuple(int(v) for v in p["c"]), "path": p["k"] + "." + p["n"]})
    return rows


def measure(rows, numbers):
    """the numbers each option is judged on"""
    back = numbers.get("HUB_BACK", -320)
    front = numbers.get("FRONT", -48)
    strip_in = numbers.get("STRIP_IN", 0)
    tanks_back = -313.2 + (48 + front if front > -48 else 0)  # the back row's tanks, as the user placed them (moved with the hub)
    return {"behind the back tanks": tanks_back - (back - 0.5), "strip on the open floor": strip_in,
            "strip in the gap": -front, "strip width on the floor": 2 * (48 + numbers.get("STRIP_WIDE", 0)) if strip_in else 0,
            "hub floor depth": -back}


def main():
    names = [a for a in sys.argv[1:]] or list(OPTIONS)
    dock = [r for r in hub_plan.load(os.path.join(STUDY, "dump.csv")) if r["path"].startswith("Dock.") and r["path"] not in ("Dock.StartStrip", "Dock.HubFloor")]
    pics = []
    for name in names:
        numbers, title = OPTIONS[name]
        shift = SHIFT.get(name, 0.0)
        # the arch stays over the gate, at the water's edge; everything else of the hub moves with it
        rows = rows_of(build(name, numbers)) + [dict(r, z=r["z"] + (0.0 if r["path"].startswith("Dock.Gate") else shift)) for r in dock]
        m = measure(rows, numbers)
        notes = []
        back = numbers.get("HUB_BACK", -320)
        notes.append(("line", (3060, -313.2 + shift), (3060, back - 0.5), (255, 230, 60), "%.0f" % m["behind the back tanks"]))
        front = numbers.get("FRONT", -48)
        sin = numbers.get("STRIP_IN", 0)
        notes.append(("line", (3070 + numbers.get("STRIP_WIDE", 0) + 8, front - sin), (3070 + numbers.get("STRIP_WIDE", 0) + 8, 0), (255, 140, 60), "strip %.0f deep" % (sin - front)))
        out = os.path.join(STUDY, "plan_%s.png" % name)
        hub_plan.draw(rows, out, notes, title)
        pics.append((out, title, m))
        print(name, m)
    if len(pics) > 1:
        ims = [Image.open(p[0]) for p in pics]
        w, h = ims[0].size
        scale = 0.5
        sw, sh = int(w * scale), int(h * scale)
        sheet = Image.new("RGB", (sw * len(ims), sh), (30, 30, 30))
        for i, im in enumerate(ims):
            sheet.paste(im.resize((sw, sh), Image.LANCZOS), (i * sw, 0))
        sheet.save(os.path.join(STUDY, "plan_options.jpg"), quality=90)


if __name__ == "__main__":
    main()
