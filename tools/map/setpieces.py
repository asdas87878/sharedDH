"""Set pieces for the later lands (2026-11-19, the user: "we need some stuff to light up the later lands to make them
really look cool, maybe some lava mounds with smoke coming out or something, or later as you go there is like super
natural stuff that looks sci fi esque and frames the lands nicely to add some real wow factor").

Beside the breakable props (tools/map/props2.py), each later land gets:
- a GATE at the neck where you enter it: it spans the neck and frames the land, so you swim through it;
- HEROES: big lit pieces at the sides of its rooms, two to a room, sides alternating;
They don't break (landmarks, not props). Bricks named "Glow" are lit (Neon in the game, a PointLight on the biggest);
"Smoke" bricks stand for a particle emitter (smoke, bubbles, embers) in the game.
The feel climbs land by land: natural glow (Open Blue), crystal (Twilight), living light (Midnight), fire (Vents),
spectral (Bone Graveyard), then sci-fi cosmic (the Underworld).

usage: python tools/map/setpieces.py <trial folder with parts.json and path.json> <out folder>
       writes the trial's parts with the set pieces added, and views.json for tools/blender/map_greybox_view.py
       (EXTRA_VIEWS), one at each gate and one in a room per land"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402
import props2  # noqa: E402


class K(props2.Kit):
    pass


def P(land):
    return props2.PALETTES[land][0]


def G(land):
    return props2.glow(P(land))


def tone(pal, slot, i):
    return props2.tone(pal, slot, i)


SMOKE = None  # set by the placing: (x, z) the way smoke drifts in the piece's own frame (None: as each piece says)


def smoke(k, x, y, z, n, size, colour, drift=(6, 0, 2)):
    """a column of soft blocks rising and drifting (a particle emitter in the game). The way it drifts comes from the
    placing (the user, 2026-11-19: "on the right side it goes right and on the left side it goes left, with a random
    stray going a diff direction sometimes. Order with hints of chaos"), and each column bends a little as it rises"""
    r = random.Random(int(x * 13 + z * 7 + y))
    dx, dz = SMOKE if SMOKE is not None else (drift[0], drift[2])
    bend = r.uniform(-0.25, 0.25)
    for j in range(n):
        s = size * (1 + 0.18 * j) * r.uniform(0.85, 1.15)
        f = j * (1 + bend * j / max(1, n))
        k.box(x + dx * f + r.uniform(-0.6, 0.6), y + j * size * 0.9, z + dz * f + r.uniform(-0.6, 0.6), s, s, s,
              tuple(min(255, c + 8 * j) for c in colour), yaw=r.uniform(0, 90), n="Smoke", studs=False)


def arc(k, span, rise, n, thick, colour, glow_every=0, glow_c=None, z=0.0, outward=0.0):
    """blocks along a half-ellipse over the neck, from one side's floor to the other's: (span wide, rise high); each
    block turned along the curve; every glow_every-th one lit; returns the points"""
    pts = []
    for j in range(n):
        a = math.pi * (j + 0.5) / n
        x, y = -span / 2 * math.cos(a), rise * math.sin(a)
        tang = math.degrees(math.atan2(rise * math.cos(a), span / 2 * math.sin(a)))
        lit = glow_every and j % glow_every == 0
        k.box(x, y - thick / 2, z, thick * 1.4, thick, thick, glow_c if lit else colour(j), n="Glow" if lit else "Brick", studs=not lit,
              yaw=0)
        k.b[-1] = (k.b[-1][0], k.b[-1][1], k.b[-1][2], k.b[-1][3], props.axes(0, 0, -tang), k.b[-1][5], k.b[-1][6])
        pts.append((x, y, a))
    return pts


# ---------------------------------------------------------------- 5 Open Blue: natural light
def glass_tower(k, r, land=4):
    """a tall glass-sponge tower: a lattice of pale segments round a lit core, glowing rings up its height"""
    pal = P(land)
    h = 0.0
    for i in range(8):
        w = 22 - i * 1.6
        k.box(0, h, 0, w * 0.5, 9, w * 0.5, G(land), n="Glow", studs=False)  # the core
        for a in range(4):
            p = props.turn((w / 2, 0, 0), yaw=a * 90 + i * 12)
            k.box(p[0], h, p[2], 3, 9, 3, tone(pal, "Main", 2), yaw=a * 90 + i * 12)
        if i % 2:
            k.box(0, h + 8, 0, w + 2, 1.2, w + 2, tone(pal, "Main", 1), yaw=i * 12)
        h += 9
    smoke(k, 0, h + 4, 0, 5, 4, (220, 250, 255), (0, 0, 0))  # rising bubbles


def lit_arch(k, r, span, land=4):
    """an arch of sponge blocks over the neck, lamps of light hung under it, glowing bands along it"""
    pal = P(land)
    for z, rise in ((-8, 90), (8, 84)):
        pts = arc(k, span, rise, 24, 9, lambda j: tone(pal, "Main", j % 2), glow_every=4, glow_c=G(land), z=z)
    for x, y, a in pts[3:-3:3]:
        k.box(x, y - 22, 0, 2, 12, 2, tone(pal, "Main", 0), studs=False)
        k.box(x, y - 30, 0, 5, 5, 5, G(land), n="Glow", studs=False)


# ---------------------------------------------------------------- 6 Twilight: crystal
def crystal_arch(k, r, span, land=5):
    """an arch of crystals over the neck: crystals growing outward all along a curve, glowing tips, shards floating"""
    pal = P(land)
    pts = arc(k, span, 96, 20, 10, lambda j: tone(pal, "Main", 1 + j % 2))
    for x, y, a in pts[::2]:
        out = math.degrees(a) - 90
        t = k.beam((x, y, 0), 6, r.uniform(14, 26), 6, tone(pal, "Main", 2), roll=out, studs=False)
        k.beam(t, 3.5, 7, 3.5, G(land), roll=out, n="Glow", studs=False)
    for j in range(9):
        k.box(r.uniform(-span / 4, span / 4), r.uniform(40, 80), r.uniform(-12, 12), 3, 8, 3, G(land), yaw=r.uniform(0, 90), n="Glow", studs=False)


def aurora(k, r, land=5):
    """a curtain of light hanging high over a room's side: thin glowing ribbons in a wave"""
    pal = P(land)
    k.box(0, 0, 0, 16, 6, 16, tone(pal, "Stone", 0))
    for i in range(14):
        x = -42 + i * 6.5
        top = 120 + 14 * math.sin(i * 0.7)
        k.box(x, top - 40, 6 * math.sin(i * 0.9), 5, 60, 1.2, G(land) if i % 3 else (240, 160, 250), n="Glow", studs=False)
    tip = (0, 6, 0)
    for i in range(6):
        tip = k.beam(tip, 6 - i * 0.6, 12, 6 - i * 0.6, tone(pal, "Main", min(2, i // 2)), roll=r.uniform(-4, 4))


# ---------------------------------------------------------------- 7 Midnight: living light
def giant_jelly(k, r, land=6):
    """a huge jellyfish hanging in the water over a room's side: a glowing bell, tentacles of lit segments"""
    pal = P(land)
    y0 = 70.0
    for i, (w, h) in enumerate(((44, 6), (38, 7), (28, 7), (16, 6))):
        k.box(0, y0 + sum((6, 7, 7, 6)[:i]), 0, w, h, w, G(land) if i % 2 else tone(pal, "Main", 2), n="Glow" if i % 2 else "Brick", studs=False)
    for j in range(9):
        a = j * 40
        p = props.turn((14, 0, 0), yaw=a)
        foot = (p[0], y0, p[2])
        for i in range(5):
            foot = (foot[0], foot[1] - 9, foot[2])
            k.box(foot[0] + math.sin(i + j) * 2, foot[1], foot[2], 2.2, 8, 2.2, G(land) if (i + j) % 2 else tone(pal, "Main", 1), n="Glow", studs=False)


def lure_gate(k, r, span, land=6):
    """an arch of dark coral over the neck with a row of glowing lures hanging from it on threads, like a chandelier"""
    pal = P(land)
    for z in (-7, 7):
        arc(k, span, 92, 22, 11, lambda j: tone(pal, "Main", j % 2), glow_every=5, glow_c=G(land), z=z)
    for j in range(7):
        x = -span * 0.3 + j * span * 0.1
        top = 92 * math.sqrt(max(0.0, 1 - (2 * x / span) ** 2))
        drop = 18 + (j % 3) * 10
        k.box(x, top - drop / 2 - 6, 0, 1.2, drop, 1.2, tone(pal, "Main", 2), studs=False)
        k.box(x, top - drop - 10, 0, 7, 7, 7, G(land), n="Glow", yaw=45, studs=False)
        k.box(x, top - drop - 10, 0, 10, 1.5, 10, (255, 255, 255), n="Glow", yaw=45, studs=False)


# ---------------------------------------------------------------- 8 Vents: fire (the user's lava mounds with smoke)
def lava_mound(k, r, land=7):
    """a mound of dark stepped blocks with glowing lava cracks down its sides, a lava pool in its crater, a smoke
    column and embers rising"""
    pal = P(land)
    lava, dark = G(land), tone(pal, "Main", 0)
    y = 0.0
    for i, (w, h) in enumerate(((56, 9), (44, 9), (32, 8), (22, 7))):
        for a in range(4):  # each step four blocks round, turned, so the mound is rough
            p = props.turn((w * 0.18, 0, 0), yaw=a * 90 + i * 20)
            k.box(p[0], y, p[2], w * 0.7, h, w * 0.7, dark if (a + i) % 2 else tone(pal, "Main", 1), yaw=a * 90 + i * 20)
        y += h
    for j in range(6):  # cracks of lava running down the sides
        a = j * 60 + r.uniform(-10, 10)
        for i in range(4):
            p = props.turn((10 + i * 6, 0, 0), yaw=a)
            k.box(p[0], 31 - i * 8, p[2], 2.2, 7, 2.2, lava, yaw=a, n="Glow", studs=False)
    k.box(0, y, 0, 15, 1.2, 15, lava, n="Glow", studs=False)  # the crater's pool
    smoke(k, 0, y + 6, 0, 9, 9, (70, 60, 64), (4, 0, 2))
    for j in range(8):  # embers
        k.box(r.uniform(-10, 10), y + r.uniform(8, 60), r.uniform(-10, 10), 1.2, 1.2, 1.2, (255, 170, 60), n="Glow", studs=False)


def magma_gate(k, r, span, land=7):
    """two basalt columns with glowing seams and a jagged lintel dripping lava"""
    pal = P(land)
    for side in (-1, 1):
        for i in range(8):
            k.box(side * span / 2, i * 10, 0, 16 - i * 0.5, 10, 16 - i * 0.5, tone(pal, "Main", i % 2), yaw=r.uniform(-10, 10))
            if i % 2:
                k.box(side * span / 2, i * 10 + 9.5, 0, 16.5 - i * 0.5, 1, 16.5 - i * 0.5, G(land), n="Glow", studs=False)
        smoke(k, side * span / 2, 84, 0, 5, 8, (70, 60, 64), (side * 3, 0, 1))
    for j in range(int(span / 12)):
        x = -span / 2 + 6 + j * 12
        k.box(x, 80 + r.uniform(-2, 3), 0, 12, r.uniform(7, 11), 14, tone(pal, "Main", j % 2), yaw=r.uniform(-8, 8))
        if j % 3 == 1:
            k.box(x, 72, 0, 2, 6, 2, G(land), n="Glow", studs=False)


# ---------------------------------------------------------------- 9 Bone Graveyard: spectral
def rib_gate(k, r, span, land=8):
    """a giant's ribcage arching over the neck: three thick ribs one behind another and a spine along the top, ghost
    light in the joints"""
    pal = P(land)
    for j, z in enumerate((-20, 0, 20)):
        rise = 104 - abs(j - 1) * 10
        arc(k, span * (1 - abs(j - 1) * 0.08), rise, 16, 10, lambda i: tone(pal, "Main", 2), glow_every=5, glow_c=G(land), z=z)
    for j in range(5):
        k.box(0, 104 - abs(j - 2) * 3, (j - 2) * 10, 14, 12, 9, tone(pal, "Main", 1))


def skull_brazier(k, r, land=8):
    """a giant skull half sunk in the floor, ghost fire in its eyes and rising from its crown, teeth along its jaw"""
    pal = P(land)
    bone, shade = tone(pal, "Main", 2), tone(pal, "Main", 1)
    k.box(0, 0, 10, 40, 8, 34, shade)  # the jaw
    for i in range(6):
        k.box(-15 + i * 6, 8, 25, 4, 6 if i % 2 else 8, 4, bone, studs=False)  # teeth
    k.box(0, 8, -6, 48, 30, 40, bone)  # the cranium
    k.box(0, 14, 18, 34, 18, 18, bone)  # the snout
    k.box(0, 38, -8, 40, 6, 32, bone)  # the brow
    for side in (-1, 1):
        k.box(side * 12, 26, 14.2, 11, 10, 1.5, (24, 34, 30), studs=False)  # sockets
        k.box(side * 12, 26, 14.9, 6, 5, 1, G(land), n="Glow", studs=False)
        k.box(side * 4, 22, 27.2, 4, 6, 1, (24, 34, 30), studs=False)  # nostrils
    for j in range(8):
        k.box(r.uniform(-8, 8), 46 + j * 6, r.uniform(-8, 4), 7 - j * 0.6, 6, 7 - j * 0.6, G(land) if j % 2 else (220, 255, 230), n="Glow", yaw=r.uniform(0, 45), studs=False)


# ---------------------------------------------------------------- 10 The Underworld: sci-fi cosmic
def portal_gate(k, r, span, land=9):
    """a ring of dark blocks round the neck with a glowing inner edge, rubble orbiting it and a beam rising"""
    pal = P(land)
    R = span / 2
    for j in range(28):
        a = math.pi * j / 27
        x, y = -R * math.cos(a), R * math.sin(a) * 0.8
        k.box(x, y, 0, 14, 14, 14, tone(pal, "Main", j % 2), yaw=0, n="Brick")
        k.box(x * 0.93, y * 0.93 + 2, 0, 5, 5, 15, G(land), n="Glow", studs=False)
    for j in range(12):
        a = j / 12 * math.tau
        k.box(math.cos(a) * (R + 20), R * 0.8 * 0.5 + math.sin(a) * 30, math.sin(a) * 20, r.uniform(5, 10), r.uniform(5, 9), r.uniform(5, 9), tone(pal, "Main", 2), yaw=r.uniform(0, 90))
    k.box(0, R * 0.8 + 200, 0, 6, 400, 6, G(land), n="Glow", studs=False)


def pylon(k, r, land=9):
    """an obelisk with glowing bands and a floating crystal held over its top by light"""
    pal = P(land)
    k.box(0, 0, 0, 20, 6, 20, tone(pal, "Stone", 0), yaw=45)
    y = 6.0
    for i in range(6):
        w = 12 - i * 1.2
        k.box(0, y, 0, w, 14, w, tone(pal, "Main", i % 2), yaw=45)
        k.box(0, y + 13, 0, w + 1, 1.2, w + 1, G(land), yaw=45, n="Glow", studs=False)
        y += 14
    k.box(0, y + 14, 0, 7, 16, 7, G(land), yaw=r.uniform(0, 90), n="Glow", studs=False)  # the floating crystal
    for j in range(5):
        a = j / 5 * math.tau
        k.box(math.cos(a) * 12, y + 12 + math.sin(a * 2) * 3, math.sin(a) * 12, 3, 3, 3, tone(pal, "Main", 2), n="Glow", studs=False)


def monolith_ring(k, r, land=9):
    """six monoliths floating in a ring round a glowing core"""
    pal = P(land)
    k.box(0, 0, 0, 30, 3, 30, tone(pal, "Stone", 0))
    k.box(0, 20, 0, 12, 12, 12, G(land), yaw=45, n="Glow", studs=False)
    for j in range(6):
        a = j / 6 * math.tau
        k.beam((math.cos(a) * 24, 8 + (j % 2) * 6, math.sin(a) * 24), 6, 26, 9, tone(pal, "Main", j % 2), pitch=8 * math.sin(a), roll=-8 * math.cos(a), yaw=math.degrees(-a))


# ---------------------------------------------------------------- gates that aren't arches (the user, 2026-11-19: "we
# shouldnt have 5 arches with a similar shape, i like the square one and maybe another arch but we need some more
# differentials from arches"): the square magma gate and the portal ring stay; the other four frame the neck otherwise
def twin_towers(k, r, span, land=4):
    """Open Blue: two separate towers either side of the neck, leaning a little outward, lit rings up them and a lamp
    on each top: a pair of lighthouses, not joined"""
    pal = P(land)
    for side in (-1, 1):
        tip = (side * span / 2, 0, 0)
        for i in range(9):
            tip = k.beam(tip, 14 - i * 0.7, 11, 14 - i * 0.7, tone(pal, "Main", i % 2), roll=-side * 4)
            if i % 2:
                k.box(tip[0], tip[1] - 1, tip[2], 15.5 - i * 0.7, 1.4, 15.5 - i * 0.7, G(land), n="Glow", studs=False)
        k.box(tip[0], tip[1] + 3, tip[2], 9, 9, 9, G(land), n="Glow", yaw=45, studs=False)
        k.box(tip[0], tip[1] + 9, tip[2], 12, 2, 12, tone(pal, "Main", 0), yaw=45)
        smoke(k, tip[0], tip[1] + 14, tip[2], 4, 4, (220, 250, 255), (0, 0, 0))


def crystal_v(k, r, span, land=5):
    """Twilight: two huge crystal clusters at the neck's sides leaning OUTWARD, so the neck opens like a V into the land"""
    pal = P(land)
    for side in (-1, 1):
        for j in range(5):
            h = (110, 86, 70, 54, 40)[j]
            foot = (side * (span / 2 - 6 + j * 9 * (1 if j % 2 else -0.4)), 0, (j - 2) * 11)
            lean = -side * (16 + j * 5)
            t = k.beam(foot, 13 - j * 1.2, h * 0.6, 13 - j * 1.2, tone(pal, "Main", 1), roll=lean)
            t = k.beam(t, 9 - j, h * 0.3, 9 - j, tone(pal, "Main", 2), roll=lean)
            k.beam(t, 5 - j * 0.5, h * 0.14, 5 - j * 0.5, G(land), roll=lean, n="Glow", studs=False)


def glow_avenue(k, r, span, land=6):
    """Midnight: an avenue: two rows of tall glowing stalks along the neck's sides, each topped by a lit bulb, so you
    swim down a lit corridor into the land"""
    pal = P(land)
    for side in (-1, 1):
        for j in range(5):
            z = (j - 2) * 22
            h = 70 - abs(j - 2) * 8
            tip = (side * span / 2, 0, z)
            for i in range(int(h / 10)):
                tip = k.beam(tip, 4.5, 10, 4.5, tone(pal, "Main", 0), roll=-side * (2 + i * 2.5), studs=False)
            k.box(tip[0], tip[1] + 2, tip[2], 8, 8, 8, G(land), n="Glow", yaw=45, studs=False)
            k.box(tip[0], tip[1] + 2, tip[2], 12, 1.4, 12, (255, 255, 255), n="Glow", yaw=45, studs=False)


def crossed_tusks(k, r, span, land=8):
    """Bone Graveyard: two giant tusks rising from either side of the neck and crossing high over it, an X, with a ghost
    light where they cross"""
    pal = P(land)
    for side in (-1, 1):
        tip = (side * span / 2, 0, 0)
        z = side * 7  # one tusk a little in front of the other, so they pass each other
        tip = (side * span / 2, 0, z)
        for i in range(18):
            w = 13 - i * 0.5
            tip = k.beam(tip, w, 12, w, tone(pal, "Main", 2 if i % 3 else 1), roll=side * (16 + i * 2.4), studs=False)
    k.box(0, 137, 0, 12, 12, 12, G(land), n="Glow", yaw=45, studs=False)  # the ghost light where they cross
    smoke(k, 0, 149, 0, 4, 5, (210, 255, 225), (0, 0, 0))


HERO_SCALE = 1.8  # the room pieces, a first try at 1, were too small to impress from a rider's height
HEROES = {4: [glass_tower], 5: [aurora], 6: [giant_jelly], 7: [lava_mound], 8: [skull_brazier], 9: [pylon, monolith_ring]}
def pylon_pair(k, r, span, land=9):
    """the Underworld: two pylons flanking the neck, their floating crystals lit (the user, 2026-11-19: "get rid of the
    curved arch for now"; the portal ring is kept above as an option)"""
    for side in (-1, 1):
        sub = K()
        pylon(sub, r, land)
        for n, p, size, col, ax, st, g in sub.b:
            k.b.append((n, (p[0] * 1.3 + side * span / 2, p[1] * 1.3, p[2] * 1.3), tuple(v * 1.3 for v in size), col, ax, st, g))


GATES = {4: twin_towers, 5: crystal_v, 6: glow_avenue, 7: magma_gate, 8: crossed_tusks, 9: pylon_pair}  # arches kept above as options


def bricks_of(fn, *a, seed=7):
    """a set piece's bricks; each copy placed with its own seed, so no two come out the same (2026-11-19: every copy
    was built from seed 7 and they were all identical)"""
    k = K()
    fn(k, random.Random(seed), *a)
    return k.b


def main():
    src, out = sys.argv[1], sys.argv[2]
    parts = json.load(open(os.path.join(src, "parts.json")))["parts"]
    path = json.load(open(os.path.join(src, "path.json")))
    rows = path["Path"]
    lands = path["Lands"]

    def at(s):
        for a, b in zip(rows, rows[1:]):
            if a[0] <= s <= b[0]:
                f = (s - a[0]) / max(1e-6, b[0] - a[0])
                p = [a[i] + (b[i] - a[i]) * f for i in range(1, 5)]
                d = (b[1] - a[1], b[3] - a[3])
                n = math.hypot(*d) or 1
                return p, (d[0] / n, d[1] / n)
        return rows[-1][1:5], (0, 1)

    def put(bs, s, x_off, turn, kindglow=True, scale=1.0):
        (cx, cy, cz, w), (dx, dz) = at(s)
        rt = (dz, -dx)
        yaw = math.degrees(math.atan2(dx, dz)) + turn
        base = (cx + rt[0] * x_off, cy, cz + rt[1] * x_off)
        for n, p, size, col, ax, st, g in bs:
            q = props.turn(tuple(v * scale for v in p), yaw=yaw)
            size = tuple(v * scale for v in size)
            axes = [props.turn(a, yaw=yaw) for a in ax]
            kind = "vglow" if n == "Glow" else ("vsmoke" if n == "Smoke" else "prop")
            parts.append({"n": "SetPiece", "k": kind if kindglow else "prop", "p": [round(base[0] + q[0], 2), round(base[1] + q[1], 2), round(base[2] + q[2], 2)],
                          "x": [round(v, 4) for v in axes[0]], "y": [round(v, 4) for v in axes[1]], "z": [round(v, 4) for v in axes[2]],
                          "s": [round(v, 2) for v in size], "c": list(col), "solid": False})

    views = {}
    necks = path["Necks"]
    for li in range(4, 10):
        s0 = lands[li]["S0"]
        s1 = lands[li + 1]["S0"] if li + 1 < len(lands) else rows[-1][0]
        gate_s = min(necks, key=lambda n: abs(n - s0))
        (_, gy, _, gw), _ = at(gate_s)
        put(bricks_of(GATES[li], gw * 0.95, li) if GATES[li] not in (None,) else [], gate_s, 0, 0)
        inside = [n for n in necks if s0 + 50 < n < s1 - 50] + [s1]
        prev, side, k = gate_s, 1, 0
        for n in inside:
            for f in (0.3, 0.7):
                s = prev + (n - prev) * f
                (_, _, _, w), _ = at(s)
                hero = HEROES[li][k % len(HEROES[li])]
                put(bricks_of(hero, li), s, side * w * 0.3, 0, scale=HERO_SCALE)
                if k == 0:
                    first = (s, side * w * 0.3)
                side, k = -side, k + 1
            prev = n
        (ex, ey, ez, _), (dx, dz) = at(gate_s - 230)
        (tx, ty, tz, _), _ = at(gate_s + 40)
        views[f"gate{li + 1:02d}"] = [[ex, ey + 34, ez], [tx, ty + 46, tz]]
        hs, hx = first  # the room view: from 220 back along the lane, looking at the room's first big piece
        (ex, ey, ez, _), (dx, dz) = at(hs - 220)
        (tx, ty, tz, _), (tdx, tdz) = at(hs)
        views[f"room{li + 1:02d}"] = [[ex + dz * hx * 0.3, ey + 30, ez - dx * hx * 0.3], [tx + tdz * hx, ty + 45 * HERO_SCALE, tz - tdx * hx]]
    os.makedirs(out, exist_ok=True)
    json.dump({"parts": parts}, open(os.path.join(out, "parts.json"), "w"))
    json.dump(path, open(os.path.join(out, "path.json"), "w"))
    json.dump(views, open(os.path.join(out, "views.json"), "w"))
    print(sum(1 for p in parts if p["n"] == "SetPiece"), "set-piece bricks;", len(views), "views")


if __name__ == "__main__":
    main()
