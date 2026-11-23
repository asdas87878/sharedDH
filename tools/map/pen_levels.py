"""Pens that grow: the fence and the aquarium merged, at three stages of the plot's upgrades (2026-11-23, the user: "we
need a way to like merge these with like an aquarium style and the fence style, so that I want the player to be able to
upgrade their aquarium so it gets taller, like much taller, so it can house more fish and so it isn't as crowded"). Every
one is 50 x 60 on a plate with the low crooked fence round it (tools/map/pen_bench.py); the row is stage 0 with the
Shallows' seven, stage 2 with eleven middle fish, stage 5 with fourteen late ones, at their real size, laid out in layers
(tools/map/pen_crowd.py). The water is 14, 38 and 74 high (12 a stage; today it is 3 a stage).

  A  storeys      a pen on a pen: every storey is a deck with its own crooked fence and its own block of water
  B  tall fence   one undivided column of water; the fence itself climbs it, post on post, a crooked pair of rails a storey
  C  steps        storeys that step in a little, a fence round every step
  D  (cut: a sand yard in front and a tower behind it; its 38-deep tower holds none of the big fish at any height)
  E  tank in pen  the slim tank of today standing inside the low fence; only the tank grows. THE PICK (the user,
                  2026-11-23: "lets go for E but without the barrier on the top, similar to to the top of C"): no rim and no
                  stripe, four posts that end just over the water and the foam line

Built of few pieces, skinny, nothing on top. Only pictures and the Studio bench: not in the game.
usage: python tools/map/pen_levels.py      writes art/map/greybox/hub_pens_<letter>.json (model Pens/<letter>)"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hub_kit  # noqa: E402
import pen_bench as pb  # noqa: E402
import pen_crowd  # noqa: E402
from hub_kit import Kit, WOOD, WOOD_D, SAND, WHITE, GOLD, NAVY  # noqa: E402

W, D, PLATE = pb.W, pb.D, pb.PLATE
HIGH = {0: 14, 1: 26, 2: 38, 3: 50, 4: 62, 5: 74}
STAGES = (0, 2, 5)
LATE_FIT = [n for n in pen_crowd.LATE if n not in ("BlueWhale", "Kraken", "Megalodon")]
FISH_AT = {0: pen_crowd.START, 1: pen_crowd.START + ["ReefShark", "Barracuda"], 2: pen_crowd.MID, 3: pen_crowd.MID + ["Orca", "ReefShark"],
           4: pen_crowd.MID + ["Orca", "Orca", "Dunkleosteus", "ReefShark"], 5: LATE_FIT}
CLEAR = (196, 236, 246)  # the game's own water (hub_kit.tank)
FOAM = (235, 250, 252)
CREAM = (244, 236, 214)
# the fence and the posts get a little finer with the stage: bare wood, then cream, then white with a gold upper rail
POST_C = {0: WOOD_D, 1: WOOD_D, 2: WOOD_D, 3: WOOD_D, 4: (112, 80, 46), 5: (112, 80, 46)}
RAIL_C = {0: WOOD, 1: WOOD, 2: CREAM, 3: CREAM, 4: CREAM, 5: CREAM}
TOP_C = {0: WOOD, 1: WOOD, 2: CREAM, 3: CREAM, 4: CREAM, 5: GOLD}
FRAME_C = {0: WOOD_D, 1: WOOD, 2: CREAM, 3: CREAM, 4: WHITE, 5: WHITE}  # E's tank posts
GATE_AT = 0.0  # how far the gate stands off the middle of the front (the back pens in S)
rng = random.Random(11)


def water(k, x0, x1, y0, y1, z0, z1):
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    k.box(cx, y0, cz, x1 - x0, y1 - y0, z1 - z0, CLEAR, n="TankWater", t=0.9, solid=False, shadow=False)
    # a pale line round the top: where the water ends
    for s, x in ((1, x0), (-1, x1)):  # (a tenth inside the water's faces: flush, the two flickered)
        k.box(x + s * 0.7, y1 - 0.2, cz, 1.2, 0.25, z1 - z0 - 0.2, FOAM, n="TankSurface", t=0.25, solid=False, shadow=False)
    for s, z in ((1, z0), (-1, z1)):
        k.box(cx, y1 - 0.2, z + s * 0.7, x1 - x0 - 2.6, 0.25, 1.2, FOAM, n="TankSurface", t=0.25, solid=False, shadow=False)


def ring(k, stage, x0, x1, z0, z1, y=PLATE, gate=True, top=False):
    """the low crooked fence round a floor at y"""
    sub = k.sub((0, y - PLATE, 0))
    pb.WOOD, pb.WOOD_D = (TOP_C if top else RAIL_C)[stage], POST_C[stage]
    pb.along(sub, (x0, z0), (x1, z0))
    pb.along(sub, (x0, z0), (x0, z1))
    pb.along(sub, (x1, z0), (x1, z1))
    w = x1 - x0
    pb.along(sub, (x0, z1), (x1, z1), gate=((w - pb.GATE) / 2 + GATE_AT, (w + pb.GATE) / 2 + GATE_AT) if gate else None)
    pb.WOOD, pb.WOOD_D = WOOD, WOOD_D


def climb(k, stage, x0, x1, z0, z1, y0, top, storey=18.0):
    """the fence climbing: four corner posts in lengths of a storey, each length standing a little off the one under
    it, and a crooked pair of rails at the head of every storey"""
    feet = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    n = max(1, round((top - y0) / storey))
    step = (top - y0) / n
    for i in range(n):
        heads = []
        last = i == n - 1
        for x, z in feet:
            ox, oz = rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4)
            tip = k.beam((x + ox, y0 + i * step - 0.3, z + oz), 1.2, step + 0.6 + (rng.uniform(0.4, 1.1) if last else 0), 1.2, POST_C[stage],
                         pitch=rng.uniform(-1.6, 1.6), roll=rng.uniform(-1.6, 1.6), yaw=rng.uniform(-10, 10), n="FencePost")
            heads.append((tip[0], tip[2]))
        for a, b in zip(heads, heads[1:] + heads[:1]):
            for dy in (-0.9, -2.7):
                y = y0 + (i + 1) * step + dy
                c = TOP_C[stage] if last and dy == -0.9 else RAIL_C[stage]
                k.rod((a[0], y + rng.uniform(-0.35, 0.35), a[1]), (b[0], y + rng.uniform(-0.35, 0.35), b[1]), 0.5, 0.9, c, n="FenceRail")


def sign(k, stage, cx, z, y=PLATE):
    """the owner's board hung between the gate's two posts"""
    cx += GATE_AT
    for s in (-1, 1):
        k.beam((cx + s * 6.4, y, z), 1.2, 9.2 + rng.uniform(-0.3, 0.3), 1.2, POST_C[stage], roll=rng.uniform(-3, 3), n="SignPost")
    k.box(cx, y + 6.0, z, 12.4, 3.0, 0.6, NAVY, roll=rng.uniform(-1.5, 1.5), n="SignBoard", solid=False)


def shoal(k, stage, w, d, cx, cz, floor, top, names=None):
    """the fish in their layers, the tallest at the bottom, each layer spread over the height there is"""
    ls, big = pen_crowd.layers(names or FISH_AT[stage], w, d)
    need = sum(a for a, _ in ls)
    spare = max(0.0, (top - floor - need) / (len(ls) + 1))
    squeeze = min(1.0, (top - floor) / need) if need else 1
    y = floor + spare
    for tall, row in ls:
        mx = (min(r[0] for r in row) + max(r[1] for r in row)) / 2
        mz = (min(r[2] for r in row) + max(r[3] for r in row)) / 2
        for x0, x1, z0, z1, name, yaw in row:
            _, h, _, s = pb.sized(name)
            lift = rng.uniform(0, max(0, tall - h - 1))
            k.fish(name, cx + (x0 + x1) / 2 - mx, y + lift + h / 2, cz + (z0 + z1) / 2 - mz, s, yaw=yaw)
        y += tall * squeeze + spare
    print("   stage", stage, "%g x %g, %g high:" % (w, d, top - floor), len(ls), "layers need", round(need, 1),
          "SQUEEZED" if squeeze < 1 else "", "| no room on the floor:", big or "none")


def storeys(stage):
    return {0: 1, 2: 2, 5: 3}[stage]


def pen_a(k, x0, x1, stage):
    z0, z1, cx = -D / 2, D / 2, (x0 + x1) / 2
    n = storeys(stage)
    step = HIGH[stage] / n
    for i in range(n):
        y = PLATE + i * (step + 1.2)
        if i:  # the deck: a frame, open in the middle so a tall fish can stand through it
            for s in (-1, 1):
                k.box(cx, y - 1.2, s * (D / 2 - 1.5), W, 1.2, 3, WOOD, n="Deck")
                k.box(cx + s * (W / 2 - 1.5), y - 1.2, 0, 3, 1.2, D - 6, WOOD, n="Deck")
        water(k, x0 + 1, x1 - 1, y, y + step, z0 + 1, z1 - 1)
        pb.POST_EVERY = 25.0 if i else 10.0  # the upper fences: half the pieces
        ring(k, stage, x0, x1, z0, z1, y, gate=i == 0, top=i == n - 1)
    pb.POST_EVERY = 10.0
    top = PLATE + HIGH[stage] + (n - 1) * 1.2
    for x in (x0, x1):
        for z in (z0, z1):
            k.beam((x, PLATE, z), 1.4, top - PLATE + 0.4, 1.4, POST_C[stage], roll=rng.uniform(-0.5, 0.5), n="Post")
    shoal(k, stage, W - 1, D - 1, cx, 0, PLATE + 0.6, top)
    sign(k, stage, cx, z1 + 0.2)


def pen_b(k, x0, x1, stage):
    z0, z1, cx = -D / 2, D / 2, (x0 + x1) / 2
    top = PLATE + HIGH[stage]
    water(k, x0 + 0.7, x1 - 0.7, PLATE, top, z0 + 0.7, z1 - 0.7)
    ring(k, stage, x0, x1, z0, z1)
    climb(k, stage, x0, x1, z0, z1, PLATE, top)
    shoal(k, stage, W - 1, D - 1, cx, 0, PLATE + 0.6, top)
    sign(k, stage, cx, z1 + 0.2)


def pen_c(k, x0, x1, stage):
    cx, z1 = (x0 + x1) / 2, D / 2
    n = storeys(stage)
    step = HIGH[stage] / n
    left = sorted(FISH_AT[stage], key=lambda m: -pb.sized(m)[0] * pb.sized(m)[2])
    y = PLATE
    for i in range(n):  # stepped in from the front and the two sides; the back stays in one plane
        w, d = W - 6 * i, D - 7 * i
        za, zb = -D / 2, -D / 2 + d
        if i:
            for q in (-1, 1):  # the deck: a frame, as A's
                k.box(cx, y - 1, (za + zb) / 2 + q * (d / 2 - 0.8), w + 6, 1, 4, WOOD, n="Deck")
                k.box(cx + q * (w / 2 + 1), y - 1, (za + zb) / 2, 4, 1, d - 5.6, WOOD, n="Deck")
        water(k, cx - w / 2 + 0.7, cx + w / 2 - 0.7, y, y + step, za + 0.7, zb - 0.7)
        for x in (cx - w / 2, cx + w / 2):  # each step's own posts, under the corners of the one above
            for z in (za, zb):
                k.beam((x, y, z), 1.2, step + 0.3, 1.2, POST_C[stage], roll=rng.uniform(-0.8, 0.8), n="Post")
        ring(k, stage, cx - w / 2, cx + w / 2, za, zb, y, gate=i == 0, top=i == n - 1)
        # the fish: each storey what it holds, the biggest on the ground
        ls, _ = pen_crowd.layers(left, w - 1, d - 1)
        use, room = [], step
        for tall, row in ls:
            if tall <= room + 1.5:
                room -= tall
                use += [r[4] for r in row]
        if use:
            shoal(k, stage, w - 1, d - 1, cx, (za + zb) / 2, y + 0.6, y + step, use)
        for m in use:
            left.remove(m)
        y += step + 1
    print("   C stage", stage, "no room for:", left or "none")
    sign(k, stage, cx, z1 + 0.2)


def pen_e(k, x0, x1, stage, fish=True):
    z0, z1, cx = -D / 2, D / 2, (x0 + x1) / 2
    top = PLATE + HIGH[stage]
    g = 1.6  # the glass stands just inside the fence
    before = len(k.out)
    ring(k, stage, x0, x1, z0, z1)
    if stage == 5:  # the last stage's one bit of gold, at eye height: the fence's upper rail
        rails = [p for p in k.out[before:] if p["n"] == "FenceRail"]
        for p in rails[1::2]:  # (pen_bench.along lays each pair lower, then upper)
            p["c"] = list(GOLD)
    water(k, x0 + g, x1 - g, PLATE + 0.08, top, z0 + g, z1 - g)
    for x in (x0 + g, x1 - g):
        for z in (z0 + g, z1 - g):
            k.box(x, PLATE, z, 1.6, top - PLATE + 0.3, 1.6, FRAME_C[stage], n="Post")
    if fish:  # (the game's own pens have none: theirs are the player's)
        shoal(k, stage, W - 2 * g, D - 2 * g, cx, 0, PLATE + 0.6, top)
    sign(k, stage, cx, z1 + 0.2)


PENS = {"A": pen_a, "B": pen_b, "C": pen_c, "E": pen_e}


def build(letter, gap=6.0):
    out = []
    k = Kit(out, "Pens/" + letter, (0, hub_kit.FLOOR_Y, 0))
    print(letter)
    stages = range(6) if letter == "E" else STAGES
    for i, stage in enumerate(stages):
        cx = (i - (len(stages) - 1) / 2) * (W + gap)
        pb.plate(k, cx - W / 2, cx + W / 2, -D / 2, D / 2, SAND)
        PENS[letter](k, cx - W / 2, cx + W / 2, stage)
    return out, k.foot()


def main():
    for letter in (sys.argv[1:] or PENS):
        out, foot = build(letter)
        json.dump({"parts": out, "feet": {"Pens/" + letter: foot}}, open(os.path.join(hub_kit.BOX, "hub_pens_%s.json" % letter), "w"))
        print("  ", len([p for p in out if "fish" not in p]), "parts,", len([p for p in out if "fish" in p]), "fish")


if __name__ == "__main__":
    main()
