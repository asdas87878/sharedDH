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
FITS = []


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
    FITS[:] = game_fish(k, x0, x1, z0, z1, 0.5)


def p2_rail(k, x0, x1, z0, z1):
    plate(k, x0, x1, z0, z1, SAND)
    top = PLATE + RAILS[1] + 0.4
    k.box((x0 + x1) / 2, PLATE, (z0 + z1) / 2, x1 - x0 - 1.4, top - PLATE, z1 - z0 - 1.4, POOL, n="PenWater", t=0.55)
    k.box((x0 + x1) / 2, top - 0.1, (z0 + z1) / 2, x1 - x0 - 1.2, 0.15, z1 - z0 - 1.2, WHITE, n="FoamLine", t=0.35)
    FITS[:] = game_fish(k, x0, x1, z0, z1, 0.5)


def p3_sand(k, x0, x1, z0, z1):
    plate(k, x0, x1, z0, z1, SAND)
    k.box(x0 + 11, PLATE - 1.2, z0 + 11, 14, 1.25, 12, POOL, n="Puddle", t=0.4)
    k.box(x1 - 8, PLATE, z0 + 7, 4, 3, 4, (150, 152, 166), n="Rock")
    k.box(x1 - 9, PLATE + 3, z0 + 6, 2.4, 6, 0.8, PINK, roll=8, n="Coral")
    k.box(x0 + 6, PLATE, z1 - 10, 1.2, 7, 1.2, KELP, roll=-6, n="Kelp")
    FITS[:] = game_fish(k, x0, x1, z0, z1, 1.0)


# each model's true box (across, high, along; studs, the glb with its nodes' moves applied, as hub_view.py prints it)
# and the game's own scale (src/shared/Config.luau, BaseScale): a Normal one's size in the sea and, at ShowShare 1, in
# its tank. Sea Turtle 25 long and Stingray 27 match Config's own comment. A bigger size roll is bigger still
FISH = {"Clownfish": ((5.7, 7.6, 10.1), 1.05), "SergeantMajor": ((6.3, 8.5, 12.7), 1.05), "YellowTang": ((2.8, 7.8, 9.8), 1.4),
        "Pufferfish": ((9.0, 6.0, 10.0), 1.5), "Cuttlefish": ((6.2, 3.2, 13.0), 1.45), "SeaTurtle": ((15.8, 3.2, 14.3), 1.75),
        "Stingray": ((16.0, 2.1, 23.4), 1.15), "ReefShark": ((9.8, 7.6, 17.3), 2.1), "Archelon": ((32.9, 8.4, 29.9), 1.7),
        "Dunkleosteus": ((12.1, 8.5, 26.2), 2.0), "Barracuda": ((3.4, 4.8, 20.4), 1.4), "MantaRay": ((24.0, 2.8, 21.7), 2.1),
        "Orca": ((12.6, 11.4, 29.2), 1.9), "BlueWhale": ((20.1, 21.3, 46.0), 2.2), "Kraken": ((23.6, 21.3, 47.8), 1.9),
        "Megalodon": ((26.9, 18.6, 42.0), 1.9)}
SETS = {"the Shallows' seven": ["SeaTurtle", "Stingray", "Cuttlefish", "Pufferfish", "YellowTang", "SergeantMajor", "Clownfish"],
        "a middle seven": ["Archelon", "MantaRay", "Dunkleosteus", "Orca", "ReefShark", "Barracuda", "SeaTurtle"],
        "a late seven": ["BlueWhale", "Kraken", "Megalodon", "Archelon", "Orca", "Dunkleosteus", "MantaRay"]}


def sized(name):
    (w, h, l), k_ = FISH[name]
    return w * k_, h * k_, l * k_, k_


def game_fish(k, x0, x1, z0, z1, lift, names=SETS["the Shallows' seven"]):
    """the fish at their game length (Aquarium.ShowShare 1), resting just over the floor, biggest first from the back
    fence (z0), none overlapping, as many as fit: a fish that has no room is left out. Returns the names placed"""
    inset, gap, step = 1.5, 1.0, 1.0
    taken, placed = [], []
    for name in sorted(names, key=lambda n: -sized(n)[0] * sized(n)[2]):
        w, h, long, k_ = sized(name)
        spot = None
        z = z0 + inset
        while spot is None and z <= z1 - inset:
            x = x0 + inset
            while spot is None and x <= x1 - inset:
                for sx, sz, yaw in ((w, long, 0), (long, w, 90)):  # nose to the gate, or across
                    if x + sx > x1 - inset or z + sz > z1 - inset:
                        continue
                    if all(x + sx + gap <= a or a2 + gap <= x or z + sz + gap <= c or c2 + gap <= z for a, a2, c, c2 in taken):
                        spot = (x, z, sx, sz, yaw)
                        break
                x += step
            z += step
        if spot:
            x, z, sx, sz, yaw = spot
            taken.append((x, x + sx, z, z + sz))
            if k:
                k.fish(name, x + sx / 2, PLATE + lift + h / 2, z + sz / 2, k_, yaw=yaw)
            placed.append(name)
    return placed


def build():
    out = []
    k = Kit(out, "Pens/Row", (0, hub_kit.FLOOR_Y, 0))
    xs = [-1.5 * W, -0.5 * W, 0.5 * W, 1.5 * W]
    z0, z1 = -D / 2, D / 2
    for (fill, a, b) in ((p1_pool, xs[0], xs[1]), (p2_rail, xs[1], xs[2]), (p3_sand, xs[2], xs[3])):
        fill(k, a, b, z0, z1)
    for label, names in SETS.items():
        for w, d in ((W, D), (52, 84)):
            fits = game_fish(None, 0, w, 0, d, 0, names)
            print(label, "in %g x %g:" % (w, d), len(fits), "of", len(names), fits)
    for n in sorted(FISH, key=lambda n: sized(n)[2]):
        print("  %-14s %.1f across, %.1f long, %.1f high" % (n, sized(n)[0], sized(n)[2], sized(n)[1]))
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
