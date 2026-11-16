"""The look pass's bench (2026-11-16): test pieces for the user to pick from, on a floor of their own away from the hub
(docs/reference/look-assets.md, section 5: tests 3, 1, 15 and 13). Nothing here goes onto the plots: the hub keeps
`hub_kit.py`'s tank and stall until the user picks.
  python tools/map/hub_bench.py                    -> art/map/greybox/hub_bench.json
  HUB_BENCH=1 python tools/map/hub_luau.py         -> tools/studio/hub_bench/NN_bench.luau (run each, in order)
The rows (z is each row's line; every piece faces +z, toward the camera):
  Plots      test 3: one plot five ways (A the deep slim tank as it is, B a low open pool, C an open pen round a pool,
             D the tank with clear water, E a fence and the fish in the air), the same five fish in each
  Studs      test 1: studs three ways on a stall and on a short tank (top only; every showing face; a stud material)
  Palette    test 15: the sell stall and the clam as they are; the stall louder; the clam louder; AURAS as the stall
  Thick      test 13: the stall with posts 1, 1.5, 2 and 3 studs thick; the short tank with a frame of 2 and of 3
"""
import colorsys
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_kit as K  # noqa: E402
from hub_kit import Kit, dark, lane_prop, light, ring, title, tones  # noqa: E402

FLOOR_Y = K.FLOOR_Y
ORIGIN_Z = -1100.0  # the bench's middle, in the map's own numbers (the hub's back wall is at -368)
TIER = {"Common": (200, 200, 200), "Uncommon": (90, 220, 90), "Rare": (70, 150, 255)}
# the same five fish in every plot: name in FishModels, its words, rarity, its own length and height, a made-up
# earning, x and z in the tank, how far over the middle height, its turn. The Rare is the one to find
FISH = [
    ("Seahorse", "Seahorse", "Rare", 12.564, 14.216, 8, -8.0, 20.0, 0.5, 90),
    ("Clownfish", "Clownfish", "Common", 10.115, 7.643, 2, 13.0, 28.0, -0.5, -80),
    ("BlueChromis", "Blue Chromis", "Common", 9.803, 3.975, 2, -15.0, -4.0, 1.0, 75),
    ("YellowTang", "Yellow Tang", "Common", 9.763, 7.814, 2, 12.0, 2.0, -1.0, -100),
    ("Stingray", "Stingray", "Uncommon", 23.44, 2.12, 4, 0.0, -24.0, 0.0, 90),
]


def fishes(k, y, lift=1.0):
    """the five fish with a name over each, their middles about y (the game shows a tank's fish at 0.7 of their own
    length, between 7 and 28 studs: Config.Aquarium)"""
    for name, words, tier, length, tall, earns, x, z, up, yaw in FISH:
        shown = min(max(length * 0.7, 7.0), 28.0)
        scale = shown / length
        fy = y + up * lift
        k.fish(name, x, fy, z, round(scale, 3), yaw=yaw)
        k.box(x, fy + tall * scale / 2 + 1.0, z, 1, 1, 1, TIER[tier], n="FishLabel", solid=False, shadow=False, t=1,
              bill={"text": "%s\n$%d/s" % (words, earns), "size": [11, 4.4], "colour": list(TIER[tier])})


def studded(mode, o=None):
    """the options that put studs on a piece of a studded material (base, awning, counter), by the test's way"""
    o = dict(o or {})
    if mode == "top":
        o["tex"] = "stud"
    elif mode == "faces":
        o["tex"] = "studs"
    elif mode == "mat":
        o["mat"] = "Stud"
    return o


def fence(k, hx, hz, y0, wood, tall=6.0, gap=14.0, post=2.0):
    """posts and two rails round a box (half sizes hx, hz, the posts' middles on its edge), standing on y0, with a gap
    in the middle of the front. The posts stand over the rails, as every pen in the reference's kind of game"""
    dk = dark(wood, 0.12)

    def run(a, b, fixed, along_x):
        n = max(1, round((b - a) / 14.0))
        for i in range(n + 1):
            v = a + (b - a) * i / n
            x, z = (v, fixed) if along_x else (fixed, v)
            if (round(x, 2), round(z, 2)) not in seen:
                seen.add((round(x, 2), round(z, 2)))
                k.box(x, y0, z, post, tall, post, wood, n="FencePost")
        for h in (tall * 0.36, tall * 0.74):
            length = (b - a) - post + 0.6
            mid = (a + b) / 2
            if along_x:
                k.box(mid, y0 + h, fixed, length, 0.9, post * 0.45, dk, n="FenceRail", solid=False, shadow=False)
            else:
                k.box(fixed, y0 + h, mid, post * 0.45, 0.9, length, dk, n="FenceRail", solid=False, shadow=False)

    seen = set()
    run(-hx, hx, -hz, True)
    run(-hz, hz, -hx, False)
    run(-hz, hz, hx, False)
    run(-hx, -gap / 2, hz, True)
    run(gap / 2, hx, hz, True)


def tank_v(k, colour, hub, kind="glass", w=56.0, d=88.0, tall=14.0, post=2.0, studs="top", fish=True, trim=None):
    """a level 1 tank, or one of the other ways to show the same fish (test 3). The base is the same in all five: a
    dark toe, one course of the plot's colour, a lighter line, the sand."""
    p_l, p, p_d = tones(colour)
    wood = tuple(hub["Look"]["frame"])
    hx, hz = w / 2 - 2, d / 2 - 2
    px, pz = hx + 0.5 - post / 2, hz + 0.5 - post / 2  # the posts' outer faces stay half a stud in from the base's edge
    rim_t = post * 0.75
    rx, rz = hx + 0.25 - rim_t / 2, hz + 0.25 - rim_t / 2
    floor = 3.5
    if kind == "low":
        tall = 3.0
    top = floor + tall
    rim = top + (0.5 if kind == "low" else 1.0)
    k.box(0, 0.4, 0, w - 3, 0.6, d - 3, p_d, n="TankToe", **studded(studs if studs != "top" else ""))
    k.box(0, 1, 0, w - 2, 2, d - 2, p, n="TankBase", **studded(studs))
    k.box(0, 2.2, 0, w - 1.6, 0.5, d - 1.6, trim or p_l, n="BaseLine", solid=False, shadow=False)
    if kind == "air":
        k.box(0, 3, 0, hx * 2, 0.5, hz * 2, K.SAND, n="TankSand", tex="stud")
    else:
        k.box(0, 3, 0, hx * 2, 0.5, hz * 2, K.SAND, n="TankSand")
    front_sign = True
    if kind in ("glass", "clear", "low"):
        if kind == "glass":
            k.box(0, floor, 0, hx * 2, tall, hz * 2, (90, 190, 225), n="TankWater", t=0.7, solid=False, shadow=False)
            k.box(0, top - 0.4, 0, hx * 2 - 0.4, 0.3, hz * 2 - 0.4, (170, 232, 244), n="TankSurface", t=0.3, solid=False, shadow=False,
                  tex="ripple", light={"range": 40 + tall, "bright": 0.5, "colour": [235, 250, 255]})
        elif kind == "clear":
            k.box(0, floor, 0, hx * 2, tall, hz * 2, (196, 236, 246), n="TankWater", t=0.9, solid=False, shadow=False)
            for sx in (-1, 1):  # the moving picture only as a band round the water's edge
                k.box(sx * (hx - 2), top - 0.4, 0, 3.6, 0.3, hz * 2 - 0.4, (170, 232, 244), n="TankSurface", t=0.3, solid=False, shadow=False, tex="ripple")
            for sz in (-1, 1):
                k.box(0, top - 0.4, sz * (hz - 2), hx * 2 - 7.8, 0.3, 3.6, (170, 232, 244), n="TankSurface", t=0.3, solid=False, shadow=False, tex="ripple")
        else:
            k.box(0, floor, 0, hx * 2, tall, hz * 2, (110, 204, 236), n="TankWater", t=0.55, solid=False, shadow=False)
        for sx in (-1, 1):
            for sz in (-1, 1):
                k.box(sx * px, 2.9, sz * pz, post, rim + 0.5 - 2.9, post, wood, n="Post")
            k.box(sx * rx, rim - (1.5 if kind == "low" else 2), 0, rim_t, 1.5 if kind == "low" else 2, pz * 2 - post + 0.6, wood, n="RimSide")
        for sz in (-1, 1):
            k.box(0, rim - (1.5 if kind == "low" else 2), sz * rz, px * 2 - post + 0.6, 1.5 if kind == "low" else 2, rim_t, wood, n="RimEnd")
        if kind == "low":
            front_sign = False
    else:  # a pen: a fence on the base, a step up to its gap; under the fish a shallow pool, or only the sand
        fence(k, px, pz, 2.9, wood, tall=6.0, post=post)
        k.box(0, 0, d / 2 + 0.5, 12, 1.6, 4, p, n="Step", **studded(studs))
        if kind == "pen":
            k.box(0, floor, 0, hx * 2 - 4, 1.0, hz * 2 - 4, (120, 208, 238), n="TankWater", t=0.5, solid=False, shadow=False)
        front_sign = False
    if front_sign:
        k.box(0, rim - 3.5, pz + post / 2 - 0.1, 25, 5, 0.6, p, n="SignBack", solid=False, shadow=False)
        k.box(0, rim - 3, pz + post / 2 + 0.45, 24, 4, 0.5, K.NAVY, n="SignBoard", solid=False, shadow=False)
    else:  # no tall rim to hang it on: a slab on the front, right of the middle
        sy = 3.6 if kind == "low" else 4.2
        k.box(16, sy, pz + post / 2 - 0.1, 17, 5, 0.6, p, n="SignBack", solid=False, shadow=False)
        k.box(16, sy + 0.5, pz + post / 2 + 0.45, 16, 4, 0.5, K.NAVY, n="SignBoard", solid=False, shadow=False)
    inside = k.sub((0, floor, 0), solid=False)
    if kind in ("glass", "clear"):
        lane_prop(inside, "brain_coral", 1, 0.15, -15, -hz + 4.6)
        lane_prop(inside, "fan_coral", 1, 0.2, 1, -hz + 2.6)
        lane_prop(inside, "sea_stack", 1, 0.14, 15.5, -hz + 4.2)
    else:
        lane_prop(inside, "brain_coral", 1, 0.12, -15, -hz + 5.5)
        lane_prop(inside, "sea_stack", 1, 0.09, 15.5, -hz + 5.5)
    if fish:
        if kind in ("glass", "clear"):
            fishes(k, floor + tall / 2, 1.2)
        elif kind == "low":
            fishes(k, top + 0.6, 0.4)  # at the water's top, half out of it
        else:
            fishes(k, floor + 6.0, 1.4)  # in the air over the pool or the sand, as the reference's creatures stand


def plot_v(out, path, x, z, hub, kind, colour, **o):
    w, d = o.get("w", 56.0), o.get("d", 88.0)
    k = Kit(out, path, (x, FLOOR_Y, z))
    pad = tuple(hub["Look"]["pad"])
    k.box(0, 0, 6, w, 0.4, d + 12, pad, n="Pad", solid=False, shadow=False, tex="stud")
    tank_v(k, colour, hub, kind, **o)
    return k


def stall(k, colour=K.RED, name="SELL", studs="top", post=3.0, wood=K.WOOD, show="fish", foot=(226, 208, 156)):
    """hub_kit.sell with the test's dials: how the studs are laid, how thick the posts are, its colours, what is on the
    counter. With every dial left alone it is the stall that stands in the hub."""
    _c_l, c, c_d = tones(colour)
    wood_l, wood, wood_d = tones(wood)
    white_d = (226, 224, 214)
    beam = min(2.0, max(1.0, post * 0.67))
    k.box(0, 0, 0, 36, 0.6, 26, foot, n="Foot", shadow=False, **studded(studs))
    k.beam((-15, 0.3, 9), post, 13.0, post, wood, pitch=2, roll=3, n="Post")
    k.beam((15, 0.3, 9), post, 13.0, post, wood, pitch=2, roll=-3, n="Post")
    k.beam((-15, 0.3, -8), post, 20.6, post, wood, pitch=-2, roll=2, n="Post")
    k.beam((15, 0.3, -8), post, 20.6, post, wood, pitch=-2, roll=-2, n="Post")
    k.box(0, 19.2, -8.3, 33, beam, beam, wood_d, n="Beam", solid=False)
    k.box(0, 12.2, 9.3, 33, beam, beam, wood_d, n="Beam", solid=False)
    k.box(0, 0.3, -9.5, 28, 9, 2, wood, n="Back")
    k.box(0, 9.3, -9.5, 30, 1, 3, wood_l, n="BackCap", solid=False, **studded(studs))
    z, y = -10.0, 22.0
    for pitch in (8.0, 20.0, 34.0):
        a = math.radians(pitch)
        dz, dy = math.cos(a), -math.sin(a)
        mz, my = z + dz * 4, y + dy * 4
        for j in range(5):
            thick, back = (1.6, 0.0) if j % 2 == 0 else (1.2, 0.3)
            off = back + thick / 2
            k.box(-14 + j * 7, my - math.cos(a) * off - thick / 2, mz - math.sin(a) * off, 7, thick, 8, c if j % 2 == 0 else K.WHITE,
                  pitch=pitch, n="Awning", solid=False, **studded(studs))
        z, y = z + dz * 8, y + dy * 8
    for j in range(5):
        tall = 3.0 if j % 2 == 0 else 2.2
        k.box(-14 + j * 7, y - 0.5 - tall, z - 0.3, 6.8, tall, 1.2, c_d if j % 2 == 0 else white_d, n="Valance", solid=False, shadow=False)
    k.box(0, 0.3, 7, 27, 1, 5, wood_d, n="CounterToe")
    k.box(0, 1.3, 7, 28, 3.7, 6, wood, n="Counter", **studded(studs if studs != "top" else ""))
    k.box(0, 5, 7, 30, 1, 8, wood_l, n="CounterTop", **studded(studs))
    k.box(0, 2.2, 10.25, 24, 2, 0.5, c, n="CounterBand", solid=False, shadow=False)
    k.wheel(0, 3.2, 10.6, 3, 0.5, K.GOLD, n="CounterCoin", solid=False, shadow=False)
    if show == "fish":
        k.box(0, 6, 7, 14, 1.6, 6, wood_d, n="Tray", solid=False)
        k.box(0, 7.6, 7, 13, 1, 5, K.ICE, n="Ice", solid=False, shadow=False)
        k.fish("Clownfish", -3.4, 9.95, 7.2, 0.55, yaw=15, roll=90)
        k.fish("BlueChromis", 2.6, 9.75, 6.8, 0.6, yaw=-20, roll=90)
    elif show == "orbs":  # AURAS as a stall: three plain orbs on stands, the three kinds of aura
        for x, orb in ((-8, (255, 206, 70)), (0, (80, 220, 255)), (8, (255, 96, 190))):
            k.box(x, 6, 7, 3, 1.2, 3, wood_d, n="Stand", solid=False, shadow=False)
            k.ball(x, 9.0, 7, 1.8, orb, n="Orb", solid=False, shadow=False)
    title(k, name, 30, colour, 20 if len(name) < 5 else 26)
    ring(k, 23, colour)


def louder(parts, start, keep=()):
    """pushes every colour of parts[start:] toward its loud flat self (the stations are pastel on a loud floor): more
    saturated, a little deeper. Greys and whites are left"""
    for p in parts[start:]:
        if "c" not in p or p["n"] in keep:
            continue
        r, g, b = (v / 255 for v in p["c"])
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s < 0.1:
            continue
        s2 = min(1.0, s * 1.55 + 0.22)
        v2 = min(1.0, v * 0.97 + 0.02)
        p["c"] = [round(c * 255) for c in colorsys.hsv_to_rgb(h, s2, v2)]


def figure(out, path, x, z, yaw=0):
    out.append({"m": path, "figure": yaw, "p": [x, FLOOR_Y, z]})


def build(hub):
    out = []
    plot_colour = tuple(hub["PlotColours"][6])  # one plot's colour for all five, so only the way of showing differs
    # ---- test 3: one plot five ways
    z = ORIGIN_Z - 250
    for i, (kind, letter) in enumerate((("glass", "A"), ("clear", "D"), ("low", "B"), ("pen", "C"), ("air", "E"))):
        x = (i - 2) * 84.0
        k = plot_v(out, "Plots/Plot" + letter, x, z, hub, kind, plot_colour)
        figure(out, "Plots/Plot" + letter, x - 20, z + 52, 180)
    # ---- test 1: studs three ways
    # (the third way, a stud material, came out black: the map's stud picture is see-through shading, and a material
    # needs a solid picture. It waits for the user's yes to one upload; `studded("mat")` and the loader keep the way)
    z = ORIGIN_Z + 40
    for i, mode in enumerate(("top", "faces")):
        x = -150 + i * 60.0
        stall(Kit(out, "Studs/Stall_" + mode, (x, FLOOR_Y, z)), studs=mode)
        figure(out, "Studs/Stall_" + mode, x + 21, z + 14, 180)
        x = 0 + i * 76.0
        plot_v(out, "Studs/Tank_" + mode, x, z - 4, hub, "glass", plot_colour, d=40.0, studs=mode, fish=False)
        figure(out, "Studs/Tank_" + mode, x + 31, z + 24, 180)
    # ---- test 15: the palette
    z = ORIGIN_Z + 300
    x = -110.0
    stall(Kit(out, "Palette/Sell_now", (x, FLOOR_Y, z)))
    x += 52
    stall(Kit(out, "Palette/Sell_loud", (x, FLOOR_Y, z)), colour=(240, 44, 52), wood=(132, 84, 44), foot=(246, 202, 84))
    x += 58
    K.auras(Kit(out, "Palette/Clam_now", (x, FLOOR_Y, z)))
    x += 52
    start = len(out)
    K.auras(Kit(out, "Palette/Clam_loud", (x, FLOOR_Y, z)))
    louder(out, start, keep=("Ring", "RingInside", "Title"))
    x += 58
    stall(Kit(out, "Palette/Auras_stall", (x, FLOOR_Y, z)), colour=(160, 70, 255), name="AURAS", wood=(132, 84, 44), show="orbs", foot=(246, 202, 84))
    # ---- test 13: how thick
    z = ORIGIN_Z + 560
    for i, post in enumerate((1.0, 1.5, 2.0, 3.0)):
        x = -78 + i * 52.0
        name = "Thick/Stall_post_%s" % str(post).replace(".", "_")
        stall(Kit(out, name, (x, FLOOR_Y, z)), post=post)
        figure(out, name, x + 21, z + 14, 180)
    z = ORIGIN_Z + 40
    plot_v(out, "Thick/Tank_frame_3", 152.0, z - 4, hub, "glass", plot_colour, d=40.0, post=3.0, fish=False)
    figure(out, "Thick/Tank_frame_3", 183, z + 24, 180)
    # the whole bench is turned half round, so every piece's front faces -z: the sun stands that way (it comes from
    # -x, -z), and a front in shade would be judged as a different thing from the side plots' lit fronts in the hub
    for p in out:
        p["p"] = [round(-p["p"][0], 2), p["p"][1], round(2 * ORIGIN_Z - p["p"][2], 2)]
        for key in ("x", "y"):
            if key in p:
                p[key] = [-p[key][0], p[key][1], -p[key][2]]
        if "figure" in p:
            p["figure"] += 180
    return out


def main():
    hub = json.load(open(os.path.join(K.BOX, "hub_in.json")))
    out = build(hub)
    models = sorted({p["m"] for p in out})
    faults = []
    for model in models:
        if model.startswith("Palette/Clam"):
            continue  # the first two passes' clam, as it stands in the hub: not built to the gate
        faults += K.gate([p for p in out if "figure" not in p], model)
    print("\n".join(faults[:40]))
    xs = [p["p"][0] for p in out]
    zs = [p["p"][2] for p in out]
    floor = [round((min(xs) + max(xs)) / 2), 0, round((min(zs) + max(zs)) / 2), round(max(xs) - min(xs) + 120), round(max(zs) - min(zs) + 140)]
    json.dump({"parts": out, "feet": {}, "floor": floor}, open(os.path.join(K.BOX, "hub_bench.json"), "w"))
    print(len(out), "bench parts in", len(models), "models;", len(faults), "faults; floor", floor)


if __name__ == "__main__":
    main()
