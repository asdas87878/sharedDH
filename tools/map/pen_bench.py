"""Three open pens in a row, to judge against the glass tank (2026-11-22, the user: "I don't like the look of the
aquarium ... it diverges from the simplistic fence feel that is a staple of the genre ... the fence posts that, you
know, slightly offset with each other, slightly off kilter with a base plate"). The genre's plot (docs/Findings.md,
point 7; docs/reference/look-assets.md, test 3): a low fence of posts and two rails round a plate, a gap for a gate,
no roof, no glass. Each pen is the reference's size (50 wide, 60 deep, the fence about 4 high), side by side sharing
fences, as the reference's are. Only for pictures: not in the game yet.

  P1  a pool    the plate holds a pool sunk to its brim; the fish swim in it and over it
  P2  to the rail  the fence holds a block of clear water up to its top rail, a foam line round the top
  P3  a sand pen   sand inside, one small pool in a corner; the fish swim in the air over the sand, as the
                   reference's creatures stand in theirs

usage: python tools/map/pen_bench.py      writes art/map/greybox/hub_pens.json (model Pens/Row) for
       HUB_JSON=hub_pens.json blender --background --python tools/blender/hub_view.py -- Pens/Row <out> <shot>..."""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_kit  # noqa: E402
from hub_kit import Kit, WOOD, WOOD_D, WOOD_L, SAND, WHITE, KELP, PINK  # noqa: E402

W, D = 50.0, 60.0  # a pen: the reference's, measured (docs/reference/ride-a-dino-map.md)
POST_EVERY = 10.0  # studs between posts
RAILS = (1.7, 3.5)  # the rails' heights over the plate
TALL = 4.4  # a post's height over the plate
PLATE = 1.0  # the base plate's thickness
GATE = 12.0  # the gap in each pen's front
GRASS = (120, 200, 120)
POOL = (110, 205, 235)
POOL_BED = (60, 140, 190)
rng = random.Random(7)


def post(k, x, z):
    """a post a little off upright and off height: the top's point, for the rails"""
    lean_p, lean_r = rng.uniform(-8, 8), rng.uniform(-8, 8)
    tall = TALL + rng.uniform(-0.35, 0.35)
    k.beam((x, PLATE, z), 1.2, tall, 1.2, WOOD_D, pitch=lean_p, roll=lean_r, n="FencePost", yaw=rng.uniform(-8, 8))
    return lean_p, lean_r, tall


def along(k, a, b, gate=None):
    """a fence from a to b on the plate's top (x, z): posts every POST_EVERY, two rails between each pair, each
    rail a little off level. gate: (from, to) along the line, left open"""
    import math

    n = max(1, round(math.dist(a, b) / POST_EVERY))
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, t * math.dist(a, b)))
    tops = []
    for x, z, s in pts:
        if gate and gate[0] < s < gate[1]:
            tops.append(None)
            continue
        ox, oz = (b[1] - a[1]), -(b[0] - a[0])  # across the line
        n_ = math.hypot(ox, oz) or 1.0
        off = rng.uniform(-0.45, 0.45)
        x, z = x + ox / n_ * off, z + oz / n_ * off
        tops.append((x, z, post(k, x, z)))
    for i in range(len(tops) - 1):
        p, q = tops[i], tops[i + 1]
        if p is None or q is None:
            continue
        for h in RAILS:
            dy1, dy2 = rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25)
            k.rod((p[0], PLATE + h + dy1, p[1]), (q[0], PLATE + h + dy2, q[1]), 0.5, 0.9, WOOD, n="FenceRail")


def plate(k, x0, x1, z0, z1, colour):
    k.box((x0 + x1) / 2, 0, (z0 + z1) / 2, x1 - x0 + 2, PLATE, z1 - z0 + 2, colour, n="PenPlate", tex="studs")


def p1_pool(k, x0, x1, z0, z1):
    # the plate as a frame 4 studs wide round the pool
    cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0 + 2, z1 - z0 + 2
    for sz in (-1, 1):
        k.box(cx, 0, cz + sz * (d / 2 - 2.5), w, PLATE, 5, SAND, n="PenPlate")
    for sx in (-1, 1):
        k.box(cx + sx * (w / 2 - 2.5), 0, cz, 5, PLATE, d - 10, SAND, n="PenPlate")
    # the pool: its brim the plate's top, a dark bed under clear water
    k.box((x0 + x1) / 2, PLATE - 2.2, (z0 + z1) / 2, x1 - x0 - 8, 0.4, z1 - z0 - 8, POOL_BED, n="PoolBed")
    k.box((x0 + x1) / 2, PLATE - 2.0, (z0 + z1) / 2, x1 - x0 - 8, 1.7, z1 - z0 - 8, POOL, n="PoolWater", t=0.45)
    game_fish(k, x0, x1, z0, z1, 0.5)


def p2_rail(k, x0, x1, z0, z1):
    plate(k, x0, x1, z0, z1, SAND)
    top = PLATE + RAILS[1] + 0.4
    k.box((x0 + x1) / 2, PLATE, (z0 + z1) / 2, x1 - x0 - 1.4, top - PLATE, z1 - z0 - 1.4, POOL, n="PenWater", t=0.55)
    k.box((x0 + x1) / 2, top - 0.1, (z0 + z1) / 2, x1 - x0 - 1.2, 0.15, z1 - z0 - 1.2, WHITE, n="FoamLine", t=0.35)
    game_fish(k, x0, x1, z0, z1, 0.5)


def p3_sand(k, x0, x1, z0, z1):
    plate(k, x0, x1, z0, z1, SAND)
    k.box(x0 + 11, PLATE - 1.2, z0 + 11, 14, 1.25, 12, POOL, n="Puddle", t=0.4)
    k.box(x1 - 8, PLATE, z0 + 7, 4, 3, 4, (150, 152, 166), n="Rock")
    k.box(x1 - 9, PLATE + 3, z0 + 6, 2.4, 6, 0.8, PINK, roll=8, n="Coral")
    k.box(x0 + 6, PLATE, z1 - 10, 1.2, 7, 1.2, KELP, roll=-6, n="Kelp")
    game_fish(k, x0, x1, z0, z1, 4.0)


GAME_FISH = [("Archelon", 50, 0.9), ("Barracuda", 30, 0.5), ("MantaRay", 24, 0.4), ("Dunkleosteus", 40, 0.6),
             ("Clownfish", 12, 0.3), ("Angelfish", 16, 0.35), ("Boxfish", 14, 0.3)]  # name, length, height share
GLB_LONG = {"Archelon": 20.7, "Barracuda": 9.0, "MantaRay": 11.2, "Dunkleosteus": 12.1, "Clownfish": 7.6, "Angelfish": 7.8, "Boxfish": 6.4}


def game_fish(k, x0, x1, z0, z1, lift):
    """seven fish at about the game's sizes (Aquarium.ShowShare 1: a tank's fish are drawn their real size)"""
    spots = [(0.3, 0.35), (0.7, 0.3), (0.25, 0.75), (0.65, 0.7), (0.15, 0.15), (0.85, 0.85), (0.5, 0.55)]
    for (name, long, high), (u, v) in zip(GAME_FISH, spots):
        k.fish(name, x0 + (x1 - x0) * u, PLATE + lift + long * high * 0.5, z0 + (z1 - z0) * v, long / GLB_LONG[name],
               yaw=rng.uniform(-180, 180))


def build():
    out = []
    k = Kit(out, "Pens/Row", (0, hub_kit.FLOOR_Y, 0))
    xs = [-1.5 * W, -0.5 * W, 0.5 * W, 1.5 * W]
    z0, z1 = -D / 2, D / 2
    for (fill, a, b) in ((p1_pool, xs[0], xs[1]), (p2_rail, xs[1], xs[2]), (p3_sand, xs[2], xs[3])):
        fill(k, a, b, z0, z1)
    # the fences: the back, the shared sides, each pen's front with its gate gap
    along(k, (xs[0], z0), (xs[3], z0))
    for x in xs:
        along(k, (x, z0), (x, z1))
    for a, b in zip(xs, xs[1:]):
        along(k, (a, z1), (b, z1), gate=((W - GATE) / 2, (W + GATE) / 2))
    return out, k.foot()


def main():
    out, foot = build()
    json.dump({"parts": out, "feet": {"Pens/Row": foot}}, open(os.path.join(hub_kit.BOX, "hub_pens.json"), "w"))
    print(len(out), "parts in Pens/Row")


if __name__ == "__main__":
    main()
