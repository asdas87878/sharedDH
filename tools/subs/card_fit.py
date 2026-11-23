"""Where the shop card's camera stands for each submarine (src/client/UI/SubPanel.luau, the SHOTS table).

usage: python tools/subs/card_fit.py            prints the nine rows and how each model sits in its card
       python tools/subs/card_fit.py --write    writes the rows into SubPanel.luau, between "-- SHOTS: begin" and "end"
       python tools/subs/card_fit.py --check    fails if SubPanel's rows are not these, or a model is cut off

Why a table: the game can see only a mesh part's box, and a box's corners stand well outside a rounded hull (framing
by them shows the subs 16 to 45% smaller than they need be). This reads the models' own points from
art/subs/<Id>/<Id>.glb and applies SubPanel's rule (its `shotBy` is the same, on boxes): the view's direction stays;
the camera moves sideways until the model sits in the middle of the box, and back until the whole of it is inside
SHOT_FILL of the box, never nearer than the first camera stood. The card's sizes and the camera's numbers are read
from SubPanel.luau, so change them there and run `--write`. Run it after a model is rebuilt
(tools/blender/sub_stages.py --export).
"""
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "creatures"))
import glb_meshes  # noqa: E402

PANEL = os.path.join(ROOT, "src", "client", "UI", "SubPanel.luau")
BEGIN, END = "-- SHOTS: begin\n", "-- SHOTS: end\n"


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def unit(a):
    n = math.sqrt(dot(a, a))
    return [v / n for v in a]


def panel_numbers(text):
    """the card's sizes and the camera's numbers, as SubPanel.luau has them"""
    def number(name):
        return float(re.search(r"^local %s = ([-\d.]+)" % name, text, re.M).group(1))

    def vector(name):
        m = re.search(r"^local %s = Vector3\.new\(([^)]*)\)" % name, text, re.M)
        return [float(v) for v in m.group(1).split(",")]

    card_w = float(re.search(r"^local CARD_W, CARD_H = (\d+), \d+", text, re.M).group(1))
    return {"wide": card_w - number("CARD_PAD"), "high": number("WELL_HIGH"), "from": vector("SHOT_FROM"),
            "at": vector("SHOT_AT"), "fov": number("SHOT_FOV"), "fill": number("SHOT_FILL")}


def points_of(path):
    pts = []
    for p in glb_meshes.parts(path):
        if p["triangles"]:
            pts += [[v[i] + p["origin"][i] for i in range(3)] for v in p["positions"]]
    return pts


class View:
    def __init__(self, n):
        self.look = unit(sub(n["at"], n["from"]))
        self.right = unit(cross(self.look, [0, 1, 0]))
        self.up = cross(self.right, self.look)
        self.far = math.sqrt(dot(sub(n["at"], n["from"]), sub(n["at"], n["from"])))
        self.half_y = math.tan(math.radians(n["fov"] / 2))
        self.half_x = self.half_y * n["wide"] / n["high"]
        self.fill = n["fill"]

    def eye(self, pts):
        """SubPanel's shotBy, on the model's real points"""
        cam = [(dot(p, self.right), dot(p, self.up), dot(p, self.look)) for p in pts]
        across, over, far = 0.0, 0.0, self.far
        for _ in range(40):
            xs = [(x - across) / (z + far) for x, y, z in cam]
            ys = [(y - over) / (z + far) for x, y, z in cam]
            across += (max(xs) + min(xs)) / 2 * far
            over += (max(ys) + min(ys)) / 2 * far
            far = max(self.far, far * max((max(xs) - min(xs)) / 2 / (self.half_x * self.fill),
                                          (max(ys) - min(ys)) / 2 / (self.half_y * self.fill)))
        return [self.right[i] * across + self.up[i] * over - self.look[i] * far for i in range(3)]

    def seen(self, pts, eye):
        """the model's reach from `eye`, as shares of the box's half width and half height (inside: all within 1)"""
        xs, ys = [], []
        for p in pts:
            r = sub(p, eye)
            z = dot(r, self.look)
            xs.append(dot(r, self.right) / z / self.half_x)
            ys.append(dot(r, self.up) / z / self.half_y)
        return min(xs), max(xs), min(ys), max(ys)


def rows():
    text = open(PANEL, encoding="utf-8").read()
    view = View(panel_numbers(text))
    out = []
    for path in glob.glob(os.path.join(ROOT, "art", "subs", "*", "*.glb")):
        cid = os.path.basename(os.path.dirname(path))
        tier = json.load(open(path[:-4] + ".mesh.json", encoding="utf-8"))["tier"]
        pts = points_of(path)
        eye = [round(v, 2) for v in view.eye(pts)]
        out.append((tier, cid, eye, view.seen(pts, eye), view.seen(pts, view_from(text))))
    return sorted(out), text


def view_from(text):
    return panel_numbers(text)["from"]


def block(found):
    lines = ["local SHOTS: { [string]: Vector3 } = {\n"]
    for _, cid, eye, _, _ in found:
        lines.append("\t%s = Vector3.new(%s),\n" % (cid, ", ".join("%.2f" % v for v in eye)))
    lines.append("}\n")
    return "".join(lines)


if __name__ == "__main__":
    found, text = rows()
    want = block(found)
    start, end = text.index(BEGIN) + len(BEGIN), text.index(END)
    bad = False
    for tier, cid, eye, now, was in found:
        worst = max(-now[0], now[1], -now[2], now[3])
        far = math.sqrt(dot(eye, eye))
        print("%d %-15s eye %7.2f %6.2f %7.2f (%.1f studs off)  across %.2f..%.2f up %.2f..%.2f %s   from the old fixed "
              "spot: across %.2f..%.2f up %.2f..%.2f" % (tier, cid, *eye, far, *now, "inside" if worst <= 1 else "CUT",
                                                         *was))
        bad = bad or worst > 1
    if "--write" in sys.argv:
        open(PANEL, "w", encoding="utf-8").write(text[:start] + want + text[end:])
        print("written to " + os.path.relpath(PANEL, ROOT))
    elif "--check" in sys.argv:
        if text[start:end] != want:
            print("! SubPanel.luau's SHOTS are not these rows: run --write")
            bad = True
        sys.exit(1 if bad else 0)
