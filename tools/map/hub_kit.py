"""The hub's models (docs/Refinement.md, stream 1): the stations, the gate, the tanks, the trainers, the landmark and
the small dressing. Each is built the way the creatures and the lane's assets are: a few big boxes, each a part of the
thing, leaning where it leans. No meshes, no uploads.

usage: python tools/map/hub_kit.py        reads art/map/greybox/hub_in.json (the hub's numbers, written by
                                           tools/map/greybox.py), writes art/map/greybox/hub.json
       python tools/map/hub_luau.py       turns hub.json into tools/studio/greybox/9x_hub.luau (a few seconds to load)

Axes are the map's: y up, the hub's floor top at y = 0.5, the hub behind z = 0, the lane leaving along +z. A kit is
drawn facing +z with its foot at y = 0 and then stood somewhere, turned. A part is
{m: model path under Dock, n: name, p: centre, x/y: two of its axes, s: size, c: colour, f: 1 solid + 2 shadow} and
may carry sh (Ball, Cylinder), mat (Neon), t (see-through), gui, bill, light, tex, tag.

What the game code leans on is kept by name (docs/Sessions.md): Plots/PlotN with TankWater, Pad, SignBoard,
TrainerSpot, and TrainerRide (now a Model whose PrimaryPart is the part named TrainerRide)."""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props  # noqa: E402

turn, axes = props.turn, props.axes
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BOX = os.path.join(ROOT, "art", "map", "greybox")

WOOD, WOOD_D, WOOD_L = (172, 132, 76), (136, 100, 58), (206, 168, 112)
BRASS, IRON, DARK = (232, 184, 74), (72, 76, 92), (40, 44, 60)
STONE, STONE_D, SAND, WHITE = (190, 194, 200), (150, 152, 166), (236, 222, 172), (250, 248, 240)
KELP, KELP_D = (84, 168, 92), (52, 116, 74)
RED, PURPLE, YELLOW, BLUE, TEAL = (235, 80, 80), (170, 110, 240), (250, 190, 70), (90, 170, 240), (70, 190, 190)
ORANGE, PINK, LIME, CYAN = (255, 150, 80), (244, 120, 150), (120, 200, 120), (110, 225, 250)
WATER = (70, 190, 215)
GOLD, GOLD_L, GOLD_D = (250, 200, 60), (253, 226, 124), (212, 158, 40)
INK = (62, 70, 96)  # the dark tint: no pure black on anything big (the building brief, rule 7)
ICE, NAVY, CREAM = (214, 238, 250), (24, 32, 52), (250, 244, 226)
SUB = (40, 186, 160)  # the submarine's ring and name: greener than the Index's blue beside it
FLOOR_Y = 0.5
OLD = "--old" in sys.argv  # the first two passes' stall and tanks everywhere: for the before pictures


def mix(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


def light(c, k=0.25):
    return mix(c, (255, 255, 255), k)


def dark(c, k=0.25):
    return mix(c, (0, 0, 0), k)


def vadd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def unit(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


class Kit:
    """collects parts. A kit has a frame (where it stands and how it is turned); `sub` gives a kit inside it with its
    own frame, so a leaning thing made of several boxes (a fish, a lid, a book) is drawn upright and leant as one."""

    def __init__(self, out, model, at=(0.0, 0.0, 0.0), yaw=0.0, frames=None, solid=True):
        self.out, self.model, self.solid = out, model, solid
        self.frames = frames if frames is not None else [(at, 0.0, yaw, 0.0)]

    def sub(self, at=(0.0, 0.0, 0.0), pitch=0.0, yaw=0.0, roll=0.0, model=None, solid=None):
        return Kit(self.out, model or self.model, frames=self.frames + [(at, pitch, yaw, roll)], solid=self.solid if solid is None else solid)

    def _point(self, v):
        for at, p, y, r in reversed(self.frames):
            v = vadd(turn(v, p, y, r), at)
        return v

    def _dir(self, v):
        for _at, p, y, r in reversed(self.frames):
            v = turn(v, p, y, r)
        return v

    def _put(self, n, centre, size, c, ax, o):
        solid = o.pop("solid", self.solid)
        glow = o.pop("glow", False)
        shadow = o.pop("shadow", not glow and not o.get("t") and max(size) >= 3)
        part = {"m": self.model, "n": n, "p": [round(v, 2) for v in self._point(centre)], "x": [round(v, 4) for v in self._dir(ax[0])],
                "y": [round(v, 4) for v in self._dir(ax[1])], "s": [round(max(0.05, abs(v)), 2) for v in size], "c": list(c),
                "f": (1 if solid else 0) + (2 if shadow else 0)}
        if glow:
            part["mat"] = "Neon"
        part.update(o)
        self.out.append(part)
        return part

    def box(self, x, y0, z, w, h, d, c, pitch=0.0, yaw=0.0, roll=0.0, n="Brick", **o):
        """a box whose foot is at y0 (turned about its own middle)"""
        return self._put(n, (x, y0 + h / 2, z), (w, h, d), c, axes(pitch, yaw, roll), o)

    def beam(self, foot, w, length, d, c, pitch=0.0, roll=0.0, yaw=0.0, n="Brick", **o):
        """a box standing on `foot` and leaning; returns its tip"""
        ax = axes(pitch, yaw, roll)
        up = ax[1]
        self._put(n, (foot[0] + up[0] * length / 2, foot[1] + up[1] * length / 2, foot[2] + up[2] * length / 2), (w, length, d), c, ax, o)
        return (foot[0] + up[0] * length, foot[1] + up[1] * length, foot[2] + up[2] * length)

    def rod(self, a, b, w, d, c, n="Brick", **o):
        """a box from a to b, its width kept level"""
        up = unit((b[0] - a[0], b[1] - a[1], b[2] - a[2]))
        side = cross((0, 1, 0), up)
        side = unit(side) if math.sqrt(sum(v * v for v in side)) > 1e-3 else (1.0, 0.0, 0.0)
        length = math.dist(a, b)
        return self._put(n, tuple((a[i] + b[i]) / 2 for i in range(3)), (w, length, d), c, (side, up, cross(side, up)), o)

    def ball(self, x, y, z, r, c, n="Brick", **o):
        return self._put(n, (x, y, z), (r * 2, r * 2, r * 2), c, axes(), dict(o, sh="Ball"))

    def wheel(self, x, y, z, across, thick, c, roll=0.0, n="Brick", **o):
        """a round slab standing on its edge, its flat faces to the kit's front and back (z); (x, y, z) is its middle"""
        ax = axes(0, 0, roll)
        return self._put(n, (x, y, z), (thick, across, across), c, (ax[2], ax[1], tuple(-v for v in ax[0])), dict(o, sh="Cylinder"))

    def fish(self, name, x, y, z, scale=1.0, pitch=0.0, yaw=0.0, roll=0.0, n=None):
        """one of the game's own creatures (ReplicatedStorage.FishModels), cloned when the hub is built: the middle
        of its box at (x, y, z), its nose toward the kit's +z before the turns. No upload: the place already has them"""
        ax = axes(pitch, yaw, roll)
        self.out.append({"m": self.model, "n": n or name, "fish": name, "k": scale, "p": [round(v, 2) for v in self._point((x, y, z))],
                         "x": [round(v, 4) for v in self._dir(ax[0])], "y": [round(v, 4) for v in self._dir(ax[1])]})

    def foot(self):
        """where the kit stands: the middle of its foot, and its x and y axes"""
        return [[round(v, 3) for v in self._point((0, 0, 0))], [round(v, 4) for v in self._dir((1, 0, 0))], [round(v, 4) for v in self._dir((0, 1, 0))]]

    def disc(self, x, y0, z, across, thick, c, n="Brick", **o):
        """a flat round slab (a Roblox cylinder lying on its side: its X axis is the round one)"""
        return self._put(n, (x, y0 + thick / 2, z), (thick, across, across), c, ((0, 1, 0), (-1, 0, 0), (0, 0, 1)), dict(o, sh="Cylinder"))


# The stations' names, style C (the user, 2026-11-16: "for stations, C"; the UI chat's option C in
# tools/ui/hub_sign_options.luau): bare words like the fish tags, in the station's colour, lighter at the top, with a
# dark edge and one small line under them. The name's colour and its line, by station; the UI chat's own numbers
NAMES = {
    "SELL": ((232, 62, 62), "fish for coins"),
    "FUSE": ((58, 112, 224), "two fish into one"),
    "AURAS": ((186, 72, 232), "ride for longer"),
    "SUBMARINE": ((34, 168, 196), "skip to a deeper land"),
    "INDEX": ((240, 164, 36), "every fish you have met"),
}


def title(k, text, y, colour, w=30.0, h=7.0):
    """the name floating over a station: an unseen part carrying a BillboardGui. A station in NAMES gets style C (30
    by 11 studs, its middle at y, seen from 420 studs); anything else the old plain name"""
    if text in NAMES and not OLD:
        c, line = NAMES[text]
        k.box(0, y, 0, 1, 1, 1, c, n="Title", solid=False, shadow=False, t=1,
              bill={"text": text, "sub": line, "size": [30, 11], "colour": list(c), "far": 420})
        return
    k.box(0, y, 0, 1, 1, 1, colour, n="Title", solid=False, shadow=False, t=1, bill={"text": text, "size": [w, h], "colour": list(colour)})


def ring(k, z, colour, across=16.0):
    """the mark on the floor in front of a station, where a player stands to use it: just a circle, see-through
    inside, and the inside fills in while you stand on it (the user, 2026-11-17: "ride a dino is just a circle with a
    transluscent thing inside which gains opacity when you step on it"). One unseen flat part named Ring, the
    station Model's PrimaryPart, carrying the circle as a picture on its top (the loader draws it; Dock.HubLife
    fills it in on each player's own machine). No second part: RingInside is gone"""
    k.box(0, 0.02, z, across, 0.1, across, colour, n="Ring", solid=False, shadow=False, t=1, circle={"colour": list(colour), "edge": 0.7})


def tones(c, k=0.2):
    """three tones of a colour, by one rule (docs/style/building-brief.md, rule 7): the lighter one for plates that
    face up, the colour itself for sides, the darker one for what is below a step, recessed or underneath"""
    return light(c, k), tuple(c), dark(c, k)


def lane_prop(k, name, seed, scale, x, z, yaw=0.0):
    """one of the lane's own props (tools/map/props.py), small, for a tank's reef: so it matches the sea outside"""
    s = k.sub((x, 0, z), yaw=yaw)
    for _n, centre, size, c, ax in props.bricks(name, seed):
        s._put("Reef", tuple(v * scale for v in centre), tuple(v * scale for v in size), c, ax, {"shadow": False})


def blocky_fish(k, c, belly=WHITE, size=1.0, eyes=True):
    """a fish from boxes, nose toward +z, its middle at the kit's origin. About 22 long at size 1"""
    s = size
    k.box(0, -4 * s, 0, 7 * s, 8 * s, 14 * s, c)
    k.box(0, -5.2 * s, 0.5 * s, 6 * s, 2.4 * s, 12 * s, belly)
    k.box(0, -3.5 * s, 8.5 * s, 6.2 * s, 7 * s, 4 * s, light(c, 0.15))
    k.box(0, -2.5 * s, -8 * s, 4 * s, 5 * s, 3 * s, c)
    k.box(0, -5.5 * s, -10.5 * s, 1.6 * s, 11 * s, 4.5 * s, dark(c, 0.18))
    k.box(0, 3.6 * s, -1 * s, 1.4 * s, 3.4 * s, 7 * s, dark(c, 0.18))
    for sx in (-1, 1):
        k.box(sx * 4.1 * s, -3.4 * s, 3 * s, 1.2 * s, 3 * s, 4 * s, dark(c, 0.18), roll=-sx * 28)
        if eyes:
            k.box(sx * 3.2 * s, 0.2 * s, 8.6 * s, 0.7 * s, 2.2 * s, 2.2 * s, WHITE)
            k.box(sx * 3.4 * s, 0.6 * s, 9.1 * s, 0.7 * s, 1.2 * s, 1.2 * s, DARK)


# ---------------------------------------------------------------- the stations
def sell_old(k):
    """the first two passes' stall, kept for the before pictures (python tools/map/hub_kit.py --old).
    a fishmonger's stall: striped awning, ice crates with the catch on them, a hanging scale, a fish for a sign"""
    k.box(0, 0, 0, 30, 1, 20, WOOD_D)
    k.box(0, 1, 5, 24, 4.5, 5, WOOD)
    k.box(0, 5.5, 5, 25, 0.8, 6, WOOD_L)
    for x, fish in ((-8, ORANGE), (0, PINK)):
        k.box(x, 6.3, 5, 7, 2, 4.6, WOOD_L, solid=False)
        k.box(x, 8.3, 5, 6.4, 1, 4, (222, 242, 252), solid=False)
        k.box(x + 0.4, 9.3, 5, 4, 1.2, 1.6, fish, yaw=20, solid=False)
        k.box(x - 2.1, 9.2, 4.1, 0.6, 1.5, 1.5, dark(fish, 0.15), yaw=20, solid=False)
    k.box(0, 1, -8.6, 28, 15, 1.5, WOOD)
    k.box(0, 9, -7.2, 22, 0.8, 2.2, WOOD_D, solid=False)
    k.box(-6, 9.8, -7.2, 2.6, 3, 2, TEAL, solid=False)
    k.box(5, 9.8, -7.2, 2.6, 2.4, 2, YELLOW, solid=False)
    for sx in (-1, 1):
        k.box(sx * 13.5, 1, 8.5, 2, 15, 2, WOOD_D)
        k.box(sx * 13.5, 1, -8.5, 2, 18.5, 2, WOOD_D)
    for j in range(6):  # the awning: six stripes, leaning down toward the front
        k.box(-12.5 + j * 5, 16.9, 1.2, 5, 1, 24, RED if j % 2 == 0 else WHITE, pitch=11.5)
    k.box(0, 13.2, 12.6, 30, 2.4, 0.8, RED, solid=False)
    k.box(0, 15.2, 10.6, 28, 1.2, 1.2, WOOD_D, solid=False)
    # the scale, hanging over the counter's right end
    k.box(9, 12.4, 6, 0.4, 3.2, 0.4, DARK, solid=False)
    k.box(9, 9.6, 6, 3.2, 3, 0.9, BRASS, solid=False)
    k.box(9, 8.2, 6, 4, 0.4, 3.6, DARK, solid=False)
    # the sign: a big red fish standing on the back wall
    f = k.sub((0, 23, -8.6), yaw=90, solid=False)  # drawn nose toward +z, then turned to stand along the wall
    f.box(0, -3, 0, 1.6, 6, 11, light(RED, 0.1))
    f.box(0, -2.4, 6.5, 1.5, 4.8, 3, light(RED, 0.25))
    f.beam((0, 0, -5), 1.4, 5.5, 2.6, dark(RED, 0.15), pitch=-50)
    f.beam((0, 0, -5), 1.4, 5.5, 2.6, dark(RED, 0.15), pitch=-130)
    f.box(0, 3, -0.5, 1.4, 2, 4, dark(RED, 0.15))
    f.box(-0.9, 0.2, 5, 0.4, 1.7, 1.7, WHITE)
    f.box(-1.1, 0.6, 5.4, 0.4, 0.9, 0.9, DARK)
    # a barrel and crates beside it
    k.box(18.5, 0, 6, 4.2, 5.2, 4.2, WOOD)
    k.box(18.5, 2.2, 6, 4.6, 0.8, 4.6, DARK, solid=False)
    k.box(-18.5, 0, 4, 5, 4, 5, WOOD_L, yaw=12)
    k.box(-18, 4, 4, 3.4, 3, 3.4, WOOD, yaw=-20, solid=False)
    title(k, "SELL", 31, RED, 20)
    ring(k, 23, RED)


STALL_WOOD = (132, 84, 44)  # the shops' timber: deep brown
STALL_TOP = 12.6  # the awning's highest point over the floor


def stall(k, name, colour, name_y=19.0):
    """a shop: one small market stall for every shop (the user, 2026-11-17: "change the stalls so they are more
    simplistic, more alike to ride a dino"). The form the buildings study read off the reference, in our own colours
    and sizes: four thick plain posts, a counter of a few blocks between the front two, and a curved awning of
    striped rows in the shop's colour and white. About two players tall, 20 studs wide, 25 pieces. Nothing on the
    counter, no base plate, no back wall, nothing glows: the name in the air, the ring on the floor and the awning's
    colour tell the shops apart. Timber is plain; the counter is studded on its showing faces, the awning on top.
    Every size is a whole number of studs where studs lie, so none is cut."""
    wood_l, wood, wood_d = tones(STALL_WOOD)
    for sx in (-1, 1):  # the posts: 2 studs square, the back pair taller, each ending inside the awning
        k.box(sx * 8, 0, 3.5, 2, 9.0, 2, wood, n="Post")
        k.box(sx * 8, 0, -3.5, 2, 12.0, 2, wood, n="Post")
    # the counter, between the front posts: a body, a lighter top a little proud front and back, the shop's colour
    # across its front
    k.box(0, 0, 3.5, 14, 3.4, 3, wood, n="Counter", tex="studs")
    k.box(0, 3.4, 3.5, 14, 0.8, 4, wood_l, n="CounterTop", tex="studs")
    k.box(0, 1.0, 5.2, 12, 1.4, 0.4, colour, n="CounterBand", solid=False, shadow=False)
    # the awning: three rows of five bricks, each row turned steeper than the last, so it curves down to the front.
    # A brick is 4 by 4 by 1; the stripes run front to back
    z, y = -5.2, STALL_TOP
    for pitch in (8.0, 22.0, 38.0):
        a = math.radians(pitch)
        dz, dy = math.cos(a), -math.sin(a)
        mz, my = z + dz * 2, y + dy * 2  # the middle of the row's top line
        for j in range(5):
            k.box(-8 + j * 4, my - math.cos(a) * 0.5 - 0.5, mz - math.sin(a) * 0.5, 4, 1, 4, colour if j % 2 == 0 else WHITE,
                  pitch=pitch, n="Awning", tex="stud", solid=False)
        z, y = z + dz * 4, y + dy * 4
    title(k, name, name_y, colour)
    ring(k, 16, colour)


def sell(k):
    stall(k, "SELL", (240, 44, 52))


def auras_stall(k):
    stall(k, "AURAS", (160, 70, 255))


def sub_stall(k):
    stall(k, "SUBMARINE", (20, 190, 160), name_y=33.0)  # its name over AURAS' as seen from the spawn


def auras(k):
    """a giant clam, open, with a glowing pearl; three small pearls in front show what an aura is"""
    shell, inside = (206, 188, 236), (246, 176, 206)
    k.box(0, 0, 1, 28, 2.5, 28, STONE_D)
    k.box(0, 2.5, 1, 24, 0.8, 24, SAND, solid=False)
    k.box(0, 3.3, -0.5, 17, 2, 13, dark(shell, 0.1))  # the lower shell, stepping out as it rises
    k.box(0, 5.3, 0, 21, 1.8, 16.5, dark(shell, 0.04))
    k.box(0, 7.1, 0.3, 24, 1.2, 19, shell)
    k.box(0, 7.9, 0.6, 21, 0.5, 16, inside, solid=False)
    for j, x in enumerate((-9.6, -4.8, 0, 4.8, 9.6)):  # its lip, in ridges
        k.box(x, 7.4, 9.6, 4.4, (1.2, 1.8, 2.2, 1.8, 1.2)[j], 1.8, PURPLE, solid=False)
    lid = k.sub((0, 8.3, -9), pitch=-34)  # the upper shell, hinged at the back and leaning open: a fan, narrower as it rises
    lid.box(0, 0, -1, 24, 8, 2, shell)
    lid.box(0, 8, -1, 21, 6, 2, shell)
    lid.box(0, 14, -1, 16, 4, 2, shell)
    lid.box(0, 0.8, 0.3, 20, 12.4, 0.6, inside, solid=False)
    for x, tall in ((-5, 2), (0, 3), (5, 2)):
        lid.box(x, 18, -1, 4.4, tall, 2, PURPLE, solid=False)
    for x in (-9, -4.5, 0, 4.5, 9):  # ribs down its back
        lid.box(x, 0.5, -2.2, 1.4, 13 if abs(x) > 5 else 17, 0.6, dark(shell, 0.14), solid=False)
    k.box(0, 8.4, 0.5, 11, 1.2, 9, (255, 150, 190), solid=False)
    # (plain, not Neon: a Neon ball this size bloomed into a white blob that hid the shell)
    k.ball(0, 13.8, 0.5, 4.4, (236, 222, 242), n="Pearl", solid=False, shadow=False, light={"range": 22, "bright": 0.45, "colour": [236, 200, 255]})
    k.ball(1.5, 15.6, 2.6, 1.1, WHITE, solid=False, shadow=False)  # its shine
    for x, c in ((-8.5, (255, 214, 96)), (0, CYAN), (8.5, (255, 130, 200))):
        k.box(x, 3.3, 12.6, 1.8, 2.4, 1.8, (70, 58, 104), solid=False)
        k.ball(x, 7.1, 12.6, 1.5, c, glow=True, solid=False)
    for sx, c in ((-1, PINK), (1, ORANGE)):  # a coral either side
        k.beam((sx * 12, 2.5, -9), 2.2, 9, 2.2, c, roll=sx * 8)
        k.beam((sx * 13.2, 2.5, -6), 1.8, 5.5, 1.8, light(c, 0.2), roll=-sx * 14, solid=False)
    title(k, "AURAS", 30, PURPLE, 24)
    ring(k, 26, PURPLE)


def fuse(k):
    """a machine: three glass pods, a fish in each, feeding one big pod"""
    glass = (160, 228, 246)
    k.box(0, 0, 0, 27, 2, 22, IRON)
    k.box(0, 2, 10.4, 27, 0.6, 1.2, YELLOW, solid=False)
    for j, x in enumerate((-9, 0, 9)):
        k.box(x, 2, -5.5, 6, 2, 6, YELLOW)
        k.box(x, 4, -5.5, 5, 8, 5, glass, t=0.5, shadow=False)
        k.box(x, 7, -5.5, 2.4, 1.4, 1, (ORANGE, PINK, CYAN)[j], yaw=30, solid=False)
        k.box(x, 12, -5.5, 6, 1.5, 6, IRON, solid=False)
        k.box(x, 13.5, -5.5, 2.4, 2.2, 2.4, IRON, solid=False)
    k.box(0, 15.5, -5.5, 24, 3, 3, IRON, solid=False)
    k.box(0, 16, -1.5, 3, 2.5, 6, IRON, solid=False)
    k.box(0, 2, 4.5, 9, 2.5, 9, YELLOW)
    k.box(0, 4.5, 4.5, 8, 11, 8, glass, t=0.5, shadow=False)
    k.ball(0, 10, 4.5, 2.8, (255, 238, 156), n="Core", glow=True, solid=False, light={"range": 30, "bright": 1.0, "colour": [255, 226, 140]})
    k.box(0, 15.5, 4.5, 10, 3, 10, IRON)
    k.box(0, 18.5, 4.5, 4, 4, 4, YELLOW, solid=False)
    k.box(0, 22.5, 4.5, 5.2, 1, 5.2, IRON, solid=False)
    k.box(10, 2, 7.5, 6, 3.6, 4, IRON)  # the desk, with two buttons and a lever
    k.box(10, 5.3, 7.7, 6, 0.8, 4.2, YELLOW, pitch=22, solid=False)
    k.box(8.6, 6.1, 7.9, 1.2, 0.6, 1.2, (255, 96, 96), pitch=22, glow=True, solid=False)
    k.box(10.4, 6.1, 7.9, 1.2, 0.6, 1.2, (120, 232, 140), pitch=22, glow=True, solid=False)
    tip = k.beam((12.4, 5.4, 7.5), 0.5, 3.6, 0.5, DARK, roll=-18, solid=False)
    k.ball(tip[0], tip[1], tip[2], 0.9, RED, solid=False)
    k.box(-11, 2, 7.5, 2, 7, 2, IRON)  # a cog on a post
    k.box(-11, 7.4, 8.8, 6.4, 1.8, 1, YELLOW, solid=False)
    k.box(-11, 5.1, 8.8, 1.8, 6.4, 1, YELLOW, solid=False)
    title(k, "FUSE", 30, YELLOW, 20)
    ring(k, 22, YELLOW)


def index(k):
    """a small lighthouse, and a great open book at its foot"""
    k.box(0, 0, -4, 18, 3, 18, STONE_D)
    k.box(0, 3, -4, 14, 2, 14, STONE)
    k.box(0, 5, -4, 11, 10, 11, WHITE)
    k.box(0, 15, -4, 10, 8, 10, BLUE)
    k.box(0, 23, -4, 9, 8, 9, WHITE)
    k.box(0, 31, -4, 13, 1.2, 13, DARK)
    k.box(0, 32.2, -4, 6.5, 6, 6.5, (255, 240, 170), t=0.4, shadow=False)
    k.box(0, 33, -4, 3, 4, 3, (255, 236, 140), n="Lamp", glow=True, solid=False, light={"range": 44, "bright": 1.3, "colour": [255, 232, 150]})
    k.box(0, 38.2, -4, 9, 1.6, 9, dark(BLUE, 0.3))
    k.box(0, 39.8, -4, 6, 1.6, 6, dark(BLUE, 0.3), solid=False)
    k.box(0, 41.4, -4, 1.2, 3, 1.2, BRASS, solid=False)
    k.box(0, 5, 1.6, 3.4, 6, 0.6, (58, 82, 132), solid=False)
    k.box(0, 18, 1.1, 2, 3, 0.5, DARK, solid=False)
    k.box(0, 26, 0.6, 2, 2.6, 0.5, DARK, solid=False)
    k.box(0, 0, 10, 13, 3, 8, STONE)  # the book's stand
    b = k.sub((0, 4.6, 10), pitch=20, solid=False)
    b.box(0, -0.6, 0, 15, 0.8, 10, dark(BLUE, 0.25))
    for sx in (-1, 1):
        b.box(sx * 3.6, 0.2, 0, 6.8, 0.9, 9, (250, 244, 226), roll=sx * 6)
        for j, c in enumerate(((ORANGE, TEAL), (PINK, YELLOW))[(sx + 1) // 2]):
            b.box(sx * 3.8, 1.25 - 0.1 * j, 2 - 3.8 * j, 3, 0.3, 1.6, c, roll=sx * 6)
    b.box(0.2, 0.9, 1.5, 0.8, 0.3, 11, RED)
    title(k, "INDEX", 50 if OLD else 54, BLUE, 24)
    ring(k, 26, BLUE)


def sub(k):
    """a submarine at its mooring: a basin of water, the hatch open, a gangway up to it. Its length runs along x"""
    hull, deck = TEAL, dark(TEAL, 0.22)
    k.box(0, 0, 10, 44, 2.6, 2, STONE)
    k.box(0, 0, -10, 44, 2.6, 2, STONE)
    for sx in (-1, 1):
        k.box(sx * 21, 0, 0, 2, 2.6, 18, STONE)
    k.box(0, 0.2, 0, 40, 1.9, 18, WATER, n="BasinWater", t=0.25, solid=False, shadow=False, tex="ripple")
    k.box(0, 1, 0, 22, 8, 9, hull)
    k.box(0, 9, 0, 19, 1, 6, deck, solid=False)
    k.box(0, 4.6, 4.6, 22, 1, 0.4, YELLOW, solid=False)
    k.box(13.5, 2, 0, 5, 6, 7.5, light(hull, 0.12))  # the nose
    k.box(17.2, 3, 0, 2.6, 4, 5, light(hull, 0.12))
    k.box(18.7, 4.4, 0, 0.6, 1.6, 2.4, (255, 236, 150), glow=True, solid=False)
    k.box(12.5, 3.2, 3.9, 4.4, 4.4, 0.6, YELLOW, solid=False)
    k.box(12.5, 3.8, 4.15, 3.2, 3.2, 0.5, (44, 74, 124), solid=False)
    k.box(-13.5, 2.5, 0, 5, 5, 6.5, hull)  # the tail
    k.box(-17.2, 3.5, 0, 2.6, 3, 4, hull)
    k.box(-16.6, 1.2, 0, 2.4, 7.6, 0.8, deck, solid=False)
    k.box(-16.6, 4.6, 0, 2.4, 0.8, 9, deck, solid=False)
    k.box(-19, 2, 0, 0.6, 6, 1.2, YELLOW, solid=False)
    k.box(-19, 4.4, 0, 0.6, 1.2, 6, YELLOW, solid=False)
    k.box(2, 10, 0, 8, 5, 5.5, hull)  # the tower, its hatch open
    k.box(2, 15, 0, 9, 0.8, 6.5, YELLOW, solid=False)
    k.box(2, 15.8, 0.2, 4, 0.3, 4, DARK, solid=False)
    k.beam((2, 15.8, -2.6), 4.4, 4.4, 0.6, YELLOW, pitch=-18, solid=False)
    k.box(5.4, 15.8, 0, 0.9, 5, 0.9, DARK, solid=False)
    k.box(6, 20.2, 0, 2.2, 1.1, 1.1, DARK, solid=False)
    for x in (-7, 0.5):
        k.box(x, 4.2, 4.7, 3, 3, 0.5, YELLOW, solid=False)
        k.box(x, 4.7, 4.95, 2, 2, 0.4, (44, 74, 124), solid=False)
    k.box(-6, 2.6, 8.4, 7, 0.8, 8.4, WOOD)  # the gangway, over the basin's wall
    k.box(-6, 0, 14, 7, 1.4, 3, WOOD)
    for x in (-9.6, -2.4):
        k.box(x, 0, 12.4, 1.2, 5.4, 1.2, WOOD_D, solid=False)
    k.rod((-6, 3.4, 5.4), (-6, 10, 2.6), 3, 0.5, WOOD_D, solid=False)
    k.box(16, 0, 13.5, 2, 3, 2, IRON)
    k.box(16, 3, 13.5, 2.8, 0.8, 2.8, IRON, solid=False)
    k.rod((16, 3.4, 13.5), (15, 6.5, 4.6), 0.5, 0.5, WOOD_L, solid=False)
    title(k, "SUBMARINE", 29, SUB, 34)
    ring(k, 26, SUB)


def earners(k):
    """the top earners' board, hung on the hub's wall: the names are written on Board by the game"""
    k.box(0, 4, 0, 26, 24, 1.5, WOOD_D)
    k.box(0, 5.5, 0.9, 22, 17.5, 0.6, DARK, n="Board", solid=False,
          gui={"face": "Back", "rows": 5, "colour": [255, 255, 255]})
    k.box(0, 23.6, 1, 21, 4, 1, BRASS, n="Header", solid=False, gui={"face": "Back", "text": "TOP EARNERS", "colour": [60, 40, 10]})
    k.box(0, 28.6, 0.4, 8, 2, 1.5, BRASS, solid=False)
    for x in (-3, 0, 3):
        k.box(x, 30.6, 0.4, 1.6, 2.6 if x == 0 else 1.8, 1.5, BRASS, solid=False)
    for sx in (-1, 1):
        k.box(sx * 12, 0, 0.2, 2, 4, 2, WOOD_D)
        k.box(sx * 11.6, 26.4, 1.4, 2, 2, 2, (255, 236, 160), glow=True, solid=False)
    k.box(8, 0, 4, 4, 0.7, 4, BRASS, solid=False)  # a few coins at its foot
    k.box(8.6, 0.7, 4.3, 3.4, 0.7, 3.4, light(BRASS, 0.2), yaw=20, solid=False)
    k.box(4, 0, 5, 3.2, 0.7, 3.2, BRASS, yaw=35, solid=False)


# ---------------------------------------------------------------- the gate
def arch(k, hub):
    """the arch you dive under: two piers standing on the low walls, a great beam across with DIVE IN facing the hub,
    a wave and two fish on top, kelp hanging in its mouth in the shape of an arch, a lit lip at the water's edge, and
    under the water a curtain of kelp down the wall below the lip (fish are made there: they come out from under it)"""
    face, top = hub["Look"]["face"], hub["Look"]["top"]
    gate_half = hub["Gate"]
    px, pz, y0 = gate_half + hub.get("GateLedge", 32.0) / 2, -14.0, 24.0  # the piers stand on the low terrace's grass (8 over two squares)
    for sx in (-1, 1):
        k.box(sx * px, y0, pz, 14, 5, 14, STONE_D)  # white piers with a blue band, the lighthouse's colours: not the wall's
        k.box(sx * px, y0 + 5, pz, 12, 10, 12, WHITE)
        k.box(sx * px, y0 + 15, pz, 12.6, 5, 12.6, (58, 140, 222))
        k.box(sx * px, y0 + 20, pz, 12, 10, 12, WHITE)
        k.box(sx * px, y0 + 30, pz, 13.4, 3, 13.4, BRASS, solid=False)
        k.box(sx * px, 69, pz, 5, 6, 5, (255, 228, 150), n="Lantern", glow=True, solid=False,
              light={"range": 60, "bright": 1.2, "colour": [255, 226, 160]})
        k.box(sx * px, 75, pz, 7, 1.5, 7, DARK, solid=False)
    span = (px + 10) * 2
    k.box(0, 57, pz, span, 10, 9, WOOD)
    k.box(0, 67, pz, span + 4, 2, 11, WOOD_D)
    k.box(0, 54.5, pz - 5, 84, 15, 1, WHITE, solid=False)
    k.box(0, 55.5, pz - 5.4, 80, 13, 1, (58, 140, 222), n="Sign", solid=False, gui={"face": "Front", "text": "DIVE IN", "colour": [255, 255, 255], "stroke": [20, 30, 60]})
    k.box(0, 69, pz, 30, 4, 8, (58, 140, 222), solid=False)  # the wave on top
    k.box(0, 73, pz, 18, 3.5, 7, light((58, 140, 222), 0.3), solid=False)
    k.box(0, 76.5, pz, 8, 3, 6, WHITE, solid=False)
    for sx in (-1, 1):
        k.box(sx * 38, 69, pz, 16, 3, 7, (58, 140, 222), solid=False)
        k.box(sx * 40, 72, pz, 8, 2, 6, WHITE, solid=False)
        f = k.sub((sx * 64, 76, pz), pitch=-24, yaw=-sx * 90, solid=False)  # a fish leaping inward, each side
        blocky_fish(f, ORANGE if sx < 0 else PINK, size=0.55)
    k.box(0, 56.2, pz - 4, span - 44, 0.8, 1.2, CYAN, glow=True, solid=False)
    k.box(0, FLOOR_Y + 0.55, -0.3, gate_half * 2, 0.4, 0.6, CYAN, n="Lip", glow=True, solid=False)
    r = random.Random(41)
    for sx in (-1, 1):  # kelp hanging from the beam: long by the piers, short toward the middle
        for j, length in enumerate((31, 25, 19, 14, 10, 7, 4.5)):
            x = sx * (px - 9 - j * 8)
            k.box(x, 57 - length, pz + r.uniform(-2.5, 2.5), 5.2, length, 1.2, KELP if j % 2 == 0 else KELP_D, roll=r.uniform(-4, 4), n="Kelp", solid=False, q=False)
    for row, (z, step, shift) in enumerate(((1.6, 9.0, 0.0), (4.6, 9.0, 4.5), (7.8, 18.0, 2.0))):  # the curtain under water
        x = -gate_half + 4 + shift
        while x < gate_half - 3:
            length = r.uniform(22, 40) if row < 2 else r.uniform(14, 26)
            k.box(x + r.uniform(-1, 1), -0.8 - length, z, r.uniform(5.5, 7.5), length, 1.2, (KELP, KELP_D, mix(KELP, KELP_D, 0.5))[r.randrange(3)],
                  roll=r.uniform(-5, 5), n="Kelp", solid=False, q=False, shadow=False)
            x += step


# ---------------------------------------------------------------- a player's plot
def seahorse(k, colour):
    """the toy ride: a seahorse from boxes, facing +z, about 12 tall and 13 long, its body's underside at the kit's
    origin and its saddle 2.7 over that. The part named TrainerRide is its body, and the Model's PrimaryPart"""
    fin, pale = dark(colour, 0.25), light(colour, 0.45)
    k.box(0, 0, 0, 4.2, 2.2, 6.4, colour, n="TrainerRide")
    k.box(0, 2.2, -0.4, 3.6, 0.5, 3.4, (126, 74, 52), n="Saddle")
    k.box(0, 0.2, 3.3, 3.4, 1.8, 0.5, pale)
    tip = k.beam((0, 1.2, 2.2), 3.6, 6.6, 3.4, colour, pitch=14)
    h = k.sub(tip, pitch=22)
    h.box(0, -0.9, 0.6, 3.8, 3.8, 4.4, colour)
    h.box(0, -0.5, 4.2, 1.9, 1.9, 3.6, pale)
    h.box(0, 2.9, -0.8, 0.9, 2.4, 3.4, fin)
    for sx in (-1, 1):
        h.box(sx * 2.0, 0.9, 1.7, 0.4, 1.2, 1.2, DARK)
        k.box(sx * 2.3, 0.5, 1.2, 0.5, 1.6, 2.2, fin, roll=-sx * 16)
    k.box(0, 5.4, 3.3, 5.8, 0.5, 0.5, BRASS, n="Handle")
    k.box(0, 2.2, -3.0, 0.8, 3.2, 2.4, fin)
    k.box(0, -0.4, -4.5, 2.8, 2.8, 2.6, colour)  # the tail, curling behind the machine
    k.box(0, -1.0, -6.3, 2.2, 2.2, 2.2, pale)
    k.box(0, 1.0, -7.0, 1.6, 1.6, 1.6, colour)


def tank_inside(k, r, colour):
    """what stands in a tank, drawn on its sand (the kit's origin is the middle of the sand's top; the water is 86 by
    54 and 32 deep). The display fish lap the middle of the water: never nearer the glass than 4 studs, never lower
    than 3 over the sand (AquariumService). So tall things stand only in a band along the back glass and at the two
    ends, and everything else on the sand is under 2.5 tall."""
    corals = [ORANGE, PINK, PURPLE, YELLOW, (255, 120, 110), light(colour, 0.1)]
    greens = [KELP, KELP_D, (110, 190, 96)]
    slots = [-36.5, -22, -7.5, 7.5, 22, 36.5]
    kinds = ["rock", "kelp", "fan", "tubes", "kelp", "rock"]
    r.shuffle(kinds)
    for x, kind in zip(slots, kinds):
        x += r.uniform(-2, 2) if abs(x) < 30 else 0
        z = -24.2
        if kind == "rock":
            k.box(x, 0, z, r.uniform(8, 10), r.uniform(5, 7), 4.4, STONE_D, yaw=r.uniform(-6, 6))
            k.box(x + r.uniform(-1.5, 1.5), 5.5, z, r.uniform(5, 6.5), r.uniform(4, 6), 4, STONE, yaw=r.uniform(-10, 10))
            k.box(x + r.uniform(-1, 1), 10.5, z, 3.2, r.uniform(2.5, 4), 3.2, r.choice(corals), yaw=r.uniform(-20, 20))
        elif kind == "kelp":
            for j in range(3):
                k.beam((x - 3.2 + j * 3.2, 0, z + r.uniform(-1, 1)), 2.4, r.uniform(15, 25), 0.9, greens[j % 3], roll=r.uniform(-7, 7))
        elif kind == "fan":
            c = r.choice(corals)
            k.box(x, 0, z, 1.8, 6, 1.6, dark(c, 0.2))
            k.box(x, 5, z, 9, 8, 0.9, c)
            k.box(x + 5.5, 0, z + 0.8, 5.5, 5.5, 0.9, light(c, 0.25))
        else:
            c = r.choice(corals)
            for j, tall in enumerate((r.uniform(9, 12), r.uniform(5, 7), r.uniform(7, 9))):
                k.beam((x - 3 + j * 3, 0, z + (j % 2) * 1.2), 2.6, tall, 2.6, c if j != 1 else light(c, 0.25), roll=r.uniform(-4, 4))
    for sx in (-1, 1):  # a low rock pile at each end, by the side glass
        k.box(sx * 39.5, 0, r.uniform(-8, 8), 5, r.uniform(4, 6), r.uniform(9, 12), STONE_D)
        if sx < 0:
            k.box(sx * 39.8, 4.5, r.uniform(-6, 6), 4, 3, 5, r.choice(corals))
    # on the sand, all under 2.5 tall: a pale drift, a starfish, a shell, a pebble, and now and then a chest
    k.box(r.uniform(-24, 24), 0, r.uniform(-10, 14), r.uniform(12, 18), 0.5, r.uniform(6, 9), light(SAND, 0.35), yaw=r.uniform(-25, 25))
    sx_, sz_, star = r.uniform(-30, 30), r.uniform(4, 20), r.choice(((255, 140, 120), (255, 190, 90), (240, 130, 190)))
    for j in range(3):
        k.box(sx_, 0.5, sz_, 5, 0.6, 1.4, star, yaw=j * 60)
    k.box(r.uniform(-30, 30), 0, r.uniform(-4, 20), 2.6, 1.3, 2.2, (250, 226, 214), yaw=r.uniform(0, 90))
    k.box(r.uniform(-32, 32), 0, r.uniform(-14, 20), r.uniform(2, 3.4), r.uniform(1, 1.8), r.uniform(2, 3), STONE_D, yaw=r.uniform(0, 90))
    if r.random() < 0.5:
        cx_, cz_, cyaw = r.uniform(-24, 24), r.uniform(-6, 12), r.uniform(-30, 30)
        c = k.sub((cx_, 0, cz_), yaw=cyaw)
        c.box(0, 0, 0, 3.6, 1.7, 2.4, WOOD)
        c.box(0, 1.7, -0.5, 3.8, 0.6, 1.6, WOOD_D)
        c.box(0, 1.2, 0.7, 2.8, 0.9, 0.9, BRASS)


def plot_old(out, index, cx, cz, turn_deg, hub):
    """the first two passes' plot: the seven not rebuilt yet, and the before pictures.
    a player's plot: the tank at the back; in front of it the owner's sign, the collect pad, the fish chute up to
    the rim, and the trainer (a coin-operated seahorse on a spring)"""
    w, d, h = hub["Plot"]
    colour = tuple(hub["PlotColours"][(index - 1) % len(hub["PlotColours"])])
    frame = tuple(hub["Look"]["frame"])
    name = f"Plots/Plot{index}"
    k = Kit(out, name, (cx, FLOOR_Y, cz), turn_deg)
    r = random.Random(900 + index)
    pad = hub["Look"].get("pad") or tuple(int(c * 0.35 + 160) for c in colour)
    k.box(0, 0, 12, w, 0.4, d + 24, pad, n="Pad", solid=False, shadow=False)
    k.box(0, 0, 0, w, 3, d, frame, n="TankBase")
    k.box(0, 0.6, d / 2 + 0.2, w - 8, 1.8, 0.5, colour, solid=False)
    k.box(0, 3, 0, w - 2, 1, d - 2, SAND, n="TankSand")
    # (0.55 see-through until the tanks got their insides: at that, everything in the water was the water's own blue)
    k.box(0, 4, 0, w - 2, h - 2, d - 2, (90, 190, 225), n="TankWater", t=0.7, solid=False, shadow=False)
    k.box(0, h + 1.6, 0, w - 2.4, 0.3, d - 2.4, (170, 232, 244), n="TankSurface", t=0.3, solid=False, shadow=False, tex="ripple")
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.box(sx * (w / 2 - 1.5), 3, sz * (d / 2 - 1.5), 3, h, 3, frame, n="Post")
            k.box(sx * (w / 2 - 1.5), 3 + h, sz * (d / 2 - 1.5), 4, 1.5, 4, BRASS, n="PostCap", solid=False)
        k.box(sx * (w / 2 - 1.5), 1.5 + h, 0, 3, 1.5, d - 6, frame, n="RimSide")
    for sz in (-1, 1):
        k.box(0, 1.5 + h, sz * (d / 2 - 1.5), w - 6, 1.5, 3, frame, n="RimEnd")
    tank_inside(k.sub((0, 4, 0), solid=False), r, colour)
    # the fish pipe: from a hopper beside the collect pad up over the rim, for the catch to go into the tank by
    k.box(-22, 0, 47, 6, 3.4, 5, WOOD_D, n="ChuteHopper")
    k.rod((-22, 3.6, 46.6), (-22, h + 3.4, d / 2 + 1.4), 4.2, 4.2, (176, 232, 246), n="Chute", t=0.45, solid=False, shadow=False)
    k.box(-22, h + 2.2, d / 2 - 0.4, 5.4, 2.8, 4.4, BRASS, n="ChuteMouth", solid=False)
    # the sign: the game writes the owner's name on SignBoard's front and back
    sx_ = -36
    for dx in (-7.6, 7.6):
        k.box(sx_ + dx, 0, d / 2 + 6, 1.4, 13, 1.4, frame, n="SignPost", solid=False)
    k.box(sx_, 7.6, d / 2 + 6, 14, 5, 1, colour, n="SignBoard", solid=False)
    k.box(sx_, 13, d / 2 + 6, 17.6, 1.2, 1.8, frame, solid=False)
    k.box(sx_, 14.2, d / 2 + 6, 6, 4, 1.2, colour, n="SignNumber", solid=False, gui={"face": "Both", "text": str(index), "colour": [255, 255, 255], "stroke": [30, 30, 50]})
    # (the collect pad went, task k1)
    # the trainer: a pad, a machine with a coin box, a spring, and the seahorse on top
    tx, tz = 20, d / 2 + 10
    k.box(tx, 0, tz, 12, 0.6, 12, (225, 70, 70), n="TrainerSpot", solid=False, shadow=False)
    k.box(tx, 0.6, tz, 6, 0.6, 7, YELLOW, n="TrainerBase")
    k.box(tx, 1.2, tz, 2.2, 0.6, 2.2, IRON, n="TrainerSpring", solid=False)
    k.box(tx + 4.6, 0.6, tz + 2.4, 2.6, 6, 2.6, RED, n="CoinBox")
    k.box(tx + 4.6, 5, tz + 3.75, 1.4, 0.4, 0.2, DARK, n="CoinSlot", solid=False)
    ride = k.sub((tx, 1.8, tz), model=name + "/TrainerRide", solid=False)  # the saddle's top is 4.5 over the floor
    seahorse(ride, colour)

LEVELS = 5  # how many levels a tank has (the user, 2026-11-16: "you can upgrade your aquarium, it gets taller, and
# it also has cooler borders, but only slightly ... maybe a cooler sheen on the glass ... more space to store more fish")
TRIM = {2: (96, 106, 132), 3: (204, 134, 78), 4: (212, 220, 232), 5: GOLD}  # the trim's metal: iron, bronze, silver, gold


def water_height(level):
    return 14 + 6 * (level - 1)


TANK = (56.0, 88.0)  # a tank's width and its depth from front to back: deep, as the reference's pens are (the user,
# 2026-11-16). Its back stands where the plot's back always was; the extra depth comes forward into the hub


def tank(k, level, colour, hub):
    """a tank at one of its levels, its middle on the kit's foot. Mostly glass; the frame is slim and has no boxes on
    it (the user, 2026-11-16: "much skinnier and minimalistic whilst keeping minor intentional details in colour and
    framing"):
      the base      one low course of the plot's colour on a dark toe set half a stud in, a thin lighter line round it,
                    and a row of studs on the ledge the glass stands back from
      the frame     posts 2 studs square, half a stud in from the base's edge, and a rim a quarter of a stud back from
                    the posts' faces; the posts end half a stud over the rim
      the sign      the owner's board with a border of the plot's colour, lying over the front rim
    A higher level is taller (6 studs of water a level) and gains one small thing at a time, in that level's metal:
    2 a thin stripe round each post under the rim, 3 a thin band along the rim, 4 the base's line in metal and a
    sheen on the glass, 5 a stripe at each post's foot and a second sheen."""
    w, d = TANK
    p_l, p, p_d = tones(colour)
    _wood_l, wood, _wood_d = tones(tuple(hub["Look"]["frame"]))
    trim = TRIM.get(level)
    hx, hz = w / 2 - 2, d / 2 - 2  # the glass: the water's half width and half depth
    px, pz = hx - 0.5, hz - 0.5  # the posts' middles
    tall = water_height(level)
    floor = 3.5  # the sand's top
    top = floor + tall  # the water's top
    rim = top + 1  # the rim's top: the water ends halfway up the rim
    k.box(0, 0.4, 0, w - 3, 0.6, d - 3, p_d, n="TankToe", tex="studs")
    k.box(0, 1, 0, w - 2, 2, d - 2, p, n="TankBase", tex="studs")
    k.box(0, 2.2, 0, w - 1.6, 0.5, d - 1.6, trim if level >= 4 else p_l, n="BaseLine", solid=False, shadow=False)
    k.box(0, 3, 0, hx * 2, 0.5, hz * 2, SAND, n="TankSand")
    # clear water (the user's pick from the bench, 2026-11-16): the fish show as brightly as in the open. The moving
    # picture is only a band round the water's edge, so it no longer lies over the fish
    k.box(0, floor, 0, hx * 2, tall, hz * 2, (196, 236, 246), n="TankWater", t=0.9, solid=False, shadow=False)
    for sx in (-1, 1):
        k.box(sx * (hx - 2), top - 0.4, 0, 3.6, 0.3, hz * 2 - 0.4, (170, 232, 244), n="TankSurface", t=0.3, solid=False, shadow=False, tex="ripple")
    for sz in (-1, 1):
        k.box(0, top - 0.4, sz * (hz - 2), hx * 2 - 7.8, 0.3, 3.6, (170, 232, 244), n="TankSurface", t=0.3, solid=False, shadow=False, tex="ripple")
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.box(sx * px, 2.9, sz * pz, 2, rim + 0.5 - 2.9, 2, wood, n="Post")
            if trim:
                k.box(sx * px, rim - 2.9, sz * pz, 2.3, 0.6, 2.3, trim, n="PostStripe", solid=False, shadow=False)
            if level >= 5:
                k.box(sx * px, 3.6, sz * pz, 2.3, 0.6, 2.3, trim, n="PostStripe", solid=False, shadow=False)
        k.box(sx * px, rim - 2, 0, 1.5, 2, pz * 2 - 1.4, wood, n="RimSide")
        if level >= 3:
            k.box(sx * (px + 0.825), rim - 1.3, 0, 0.15, 0.6, pz * 2 - 2, trim, n="RimBand", solid=False, shadow=False)
    for sz in (-1, 1):
        k.box(0, rim - 2, sz * pz, px * 2 - 1.4, 2, 1.5, wood, n="RimEnd")
        if level >= 3:
            k.box(0, rim - 1.3, sz * (pz + 0.825), px * 2 - 2, 0.6, 0.15, trim, n="RimBand", solid=False, shadow=False)
    if level >= 4:  # a sheen on the front glass: one pale streak, two at the top level
        clear = rim - 2 - floor  # the glass between the sand and the rim
        long = (clear - 4) * 0.8
        k.box(-12, floor + clear / 2 - long / 2, hz + 0.11, 3, long, 0.1, WHITE, roll=-32, n="Sheen", t=0.78, solid=False, shadow=False)
        if level >= 5:
            k.box(-7, floor + clear / 2 - long * 0.35, hz + 0.11, 1.2, long * 0.7, 0.1, WHITE, roll=-32, n="Sheen", t=0.78, solid=False, shadow=False)
    # the owner's sign: the game writes on SignBoard's front and back
    k.box(0, rim - 3.5, pz + 0.9, 25, 5, 0.6, p, n="SignBack", solid=False, shadow=False)
    k.box(0, rim - 3, pz + 1.45, 24, 4, 0.5, NAVY, n="SignBoard", solid=False, shadow=False)
    # inside: three of the lane's own props along the back glass. The rest is for the fish
    inside = k.sub((0, floor, 0), solid=False)
    lane_prop(inside, "brain_coral", level, 0.15, -15, -hz + 4.6)
    lane_prop(inside, "fan_coral", level, 0.2, 1, -hz + 2.6)
    lane_prop(inside, "sea_stack", level, 0.14, 15.5, -hz + 4.2)


SUNK = 1.6  # how far the tank stands sunk into the floor (the user's, 2026-11-17)
PLOT_COLOUR = (120, 200, 120)  # every tank green, as the user's copies of Plot 4 are (None: each plot its own colour)


def plot(out, index, cx, cz, turn_deg, hub, level=1):
    """a player's plot, simple (the user, 2026-11-16): a studded pad, the tank at its level (`tank`), and the trainer: the game's own Seahorse on a spring, on a plate (the part TrainerRide). The plot's
    back is where it always was; it is TANK wide and deep, and its front comes forward into the hub"""
    w, d = TANK
    back = -hub["Plot"][1] / 2
    front = back + d
    colour = PLOT_COLOUR or tuple(hub["PlotColours"][(index - 1) % len(hub["PlotColours"])])
    name = f"Plots/Plot{index}"
    k = Kit(out, name, (cx, FLOOR_Y, cz), turn_deg)
    # (the user, 2026-11-17, by hand in Studio: no studded pad under the tank, and the tank sunk 1.6 studs into the
    # floor so its glass starts low. The game still needs a part named Pad, the area that counts as the plot, so it
    # stays, unseen. The pads in front stay on the floor)
    k.box(0, 0, back + (d + 24) / 2, w, 0.4, d + 24, colour, n="Pad", solid=False, shadow=False, t=1)
    tank(k.sub((0, -SUNK, back + d / 2)), level, colour, hub)
    # (no green collect pad any more, Hugo, 2026-11-20, task k1: the tank's E prompt sits on its front glass and a
    # player with a catch wakes on the floor in front of the tank, AquariumService.frontOf)
    tx, tz = 13, front + 11
    k.box(tx, 0, tz, 12, 0.6, 12, (225, 70, 70), n="TrainerSpot", solid=False, shadow=False, tex="stud")
    k.box(tx, 0.6, tz, 8, 1.4, 8, YELLOW, n="TrainerBase", tex="studs")
    k.box(tx, 2, tz, 1.6, 3.2, 1.6, INK, n="TrainerSpring", solid=False, shadow=False)
    for j in range(3):
        k.disc(tx, 2.2 + j, tz, 4.2, 0.6, (176, 182, 196), n="SpringCoil", solid=False, shadow=False)
    ride = k.sub((tx, 5, tz), model=name + "/TrainerRide", solid=False)
    ride.box(0, 0, 0, 6, 0.8, 8, tuple(colour), n="TrainerRide", tex="stud")
    ride.fish("Seahorse", 0, 0.6 + 14.2 * 0.85 / 2, 0, 0.85, n="Toy")
    upgrade_sign(k, tx, tz)
    return k


# the seahorse's upgrade sign (task s2, after Ride a Dino's "Upgrade Machine" board): copied from Config.Train.Sign,
# which TrainService uses for a map without these parts. Side along the plot's front (minus: toward the collect pad),
# Ahead toward the hub, from the trainer's middle; the board's face (UpgradeBoard's front) toward the hub; the game
# writes on it (Client.UI.UpgradeSign)
SIGN = {"Side": -12, "Ahead": 4, "Wide": 10.8, "High": 6.48, "Foot": 2.4, "Post": 0.9, "Thick": 0.5}
SIGN_EDGE = (10, 12, 22)  # the writing's border colour (Shop.Edge)
SIGN_POST = (28, 32, 46)


def upgrade_sign(k, tx, tz):
    s = SIGN
    x, z = tx + s["Side"], tz + s["Ahead"]
    post = s["Foot"] + s["High"] / 2
    k.box(x, 0, z - s["Thick"] / 2 - s["Post"] / 2, s["Post"], post, s["Post"], SIGN_POST, yaw=180, n="UpgradePost")
    k.box(x, s["Foot"], z, s["Wide"], s["High"], s["Thick"], SIGN_EDGE, yaw=180, n="UpgradeBoard", shadow=False)


# ---------------------------------------------------------------- the middle
def landmark(k):
    """a fish and its rider, leaping from a plinth in a round pool"""
    for j in range(8):
        a = math.radians(j * 45)
        k.box(17 * math.sin(a), 0, 17 * math.cos(a), 14.6, 2.6, 2.6, STONE, yaw=j * 45)
    k.disc(0, 0.2, 0, 33, 1.8, WATER, n="PoolWater", t=0.2, solid=False, shadow=False, tex="ripple")
    k.box(0, 0, 0, 12, 4.5, 12, STONE_D)
    k.box(0, 4.5, 0, 9, 3, 9, STONE)
    k.box(0, 1.6, 6.1, 6, 2, 0.4, BRASS, solid=False)
    k.box(0, 7.5, -3, 7, 3.4, 7, WHITE, solid=False)
    f = k.sub((0, 17, 1.5), pitch=-32, solid=False)
    blocky_fish(f, ORANGE)
    f.box(0, 4, 1.6, 2.6, 3.2, 1.8, BLUE)  # the rider
    f.box(0, 7.2, 1.6, 2.1, 2.1, 2.1, (250, 216, 96))
    for sx in (-1, 1):
        f.box(sx * 2, 4, 2.2, 1.1, 1.1, 3, LIME, pitch=18)
    f.beam((1.8, 6.4, 1.6), 1, 3.2, 1, BLUE, roll=-28)
    f.beam((-1.8, 6.2, 1.8), 1, 3, 1, BLUE, pitch=70)
    for j in range(4):  # four jets of water
        a = math.radians(45 + j * 90)
        k.box(11.5 * math.sin(a), 1.8, 11.5 * math.cos(a), 1.4, 7 + 2 * (j % 2), 1.4, (232, 250, 255), t=0.4, glow=True, solid=False)


# ---------------------------------------------------------------- the small things
def lamp(k, lit):
    k.box(0, 0, 0, 2.4, 1.5, 2.4, IRON)
    k.box(0, 1.5, 0, 1.2, 12, 1.2, IRON)
    o = {"light": {"range": 46, "bright": 1.0, "colour": [255, 226, 160]}} if lit else {}
    k.box(0, 13.5, 0, 3, 3.6, 3, (255, 228, 150), n="Lantern", glow=True, solid=False, **o)
    k.box(0, 17.1, 0, 4, 1, 4, IRON, solid=False)


def buoy(k, colour):
    k.box(0, 0, 0, 5, 3, 5, colour)
    k.box(0, 3, 0, 4.4, 3, 4.4, WHITE)
    k.box(0, 6, 0, 3.6, 3, 3.6, colour)
    k.box(0, 9, 0, 0.6, 5, 0.6, DARK, solid=False)
    k.box(0, 14, 0, 1.6, 1.6, 1.6, (255, 236, 150), glow=True, solid=False)


def crates(k, r):
    k.box(0, 0, 0, 5, 5, 5, WOOD_L, yaw=r.uniform(-15, 15))
    k.box(0.4, 5, 0.2, 3.6, 3.4, 3.6, WOOD, yaw=r.uniform(-30, 30), solid=False)
    k.box(5.4, 0, 1, 4, 5.2, 4, WOOD)
    k.box(5.4, 2.2, 1, 4.4, 0.8, 4.4, DARK, solid=False)
    k.box(-4.6, 0, 2.6, 3.4, 3, 3.4, WOOD, yaw=r.uniform(0, 45), solid=False)


def palm(k, r, size=1.0):
    """a palm from boxes: a trunk bending as it rises, five fronds, two coconuts"""
    bark = (184, 146, 100)
    tip, lean = (0.0, 0.0, 0.0), r.uniform(4, 8)
    for j, (w, length) in enumerate(((2.8, 8.5), (2.4, 8), (2.0, 7.5))):
        tip = k.beam(tip, w * size, length * size, w * size, bark if j % 2 == 0 else dark(bark, 0.12), roll=lean * (j + 1))
    for j in range(5):
        a = math.radians(j * 72 + r.uniform(-12, 12))
        out = (tip[0] + 9.5 * size * math.cos(a), tip[1] - r.uniform(1.5, 3.5) * size, tip[2] + 9.5 * size * math.sin(a))
        k.rod(tip, out, 3.6 * size, 0.7, KELP if j % 2 == 0 else (110, 190, 96), solid=False)
    k.box(tip[0], tip[1] - 0.6, tip[2], 3.2 * size, 2 * size, 3.2 * size, KELP_D, solid=False)
    for dx in (-1.3, 1.2):
        k.ball(tip[0] + dx * size, tip[1] - 1.4 * size, tip[2] + 0.8 * size, 0.95 * size, (120, 84, 56), solid=False)


def stones(k, a, b, r, colour):
    """stepping stones from a to b (x, z): flat round slabs, a little out of line"""
    n = max(2, int(math.dist(a, b) / 12))
    for j in range(n):
        f = (j + 0.5) / n
        k.disc(a[0] + (b[0] - a[0]) * f + r.uniform(-1.6, 1.6), FLOOR_Y + 0.01, a[1] + (b[1] - a[1]) * f + r.uniform(-1.2, 1.2),
               r.uniform(5.2, 7), 0.28, colour if j % 2 == 0 else dark(colour, 0.07), n="Stone", solid=False, shadow=False)


def bunting(k, a, b, flags, sag=6.0):
    """a line of flags from a to b, hanging a little in the middle"""
    mid = tuple((a[i] + b[i]) / 2 - (sag if i == 1 else 0) for i in range(3))
    k.rod(a, mid, 0.4, 0.4, WHITE, solid=False, shadow=False)
    k.rod(mid, b, 0.4, 0.4, WHITE, solid=False, shadow=False)
    yaw = math.degrees(math.atan2(b[0] - a[0], b[2] - a[2])) + 90
    colours = ((250, 200, 80), (240, 110, 130), (110, 190, 240), (140, 220, 150), WHITE)
    for j in range(flags):
        f = (j + 0.5) / flags
        p = [a[i] + (b[i] - a[i]) * f for i in range(3)]
        p[1] -= sag * (1 - abs(2 * f - 1))  # two straight halves, as the line is drawn
        k.box(p[0], p[1] - 4.6, p[2], 3.6, 4.4, 0.3, colours[j % 5], yaw=yaw, solid=False, shadow=False)


# ---------------------------------------------------------------- the gate (the creature kit's, for buildings)
def _axes3(p):
    x, y = tuple(p["x"]), tuple(p["y"])
    return x, y, cross(x, y)


def _faces(p):
    """a part's flat faces: (normal, a point on it, the two in-plane axes with their half sizes)"""
    ax, c, half = _axes3(p), p["p"], [v / 2 for v in p["s"]]
    out = []
    for i in range(3):
        if p.get("sh") == "Cylinder" and i != 0:
            continue  # only a round slab's two flat ends are flat
        j, k_ = (i + 1) % 3, (i + 2) % 3
        for sign in (1, -1):
            n = tuple(sign * v for v in ax[i])
            pictured = i == 1 and sign == 1 and bool(p.get("tex"))  # its top, with the stud picture on it
            out.append((n, tuple(c[a] + n[a] * half[i] for a in range(3)), (ax[j], half[j]), (ax[k_], half[k_]), pictured))
    return out


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _overlap(fa, fb):
    """the area two rectangles in one plane share (fb's corners clipped to fa's rectangle)"""
    _n, ca, (ua, hu), (va, hv), _p = fa
    _n, cb, (ub, hub_), (vb, hvb), _p = fb
    poly = []
    for su, sv in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        q = tuple(cb[a] + ub[a] * hub_ * su + vb[a] * hvb * sv - ca[a] for a in range(3))
        poly.append((_dot(q, ua), _dot(q, va)))
    for axis, lim, keep in ((0, hu, 1), (0, -hu, -1), (1, hv, 1), (1, -hv, -1)):
        nxt = []
        for i in range(len(poly)):
            a, b = poly[i], poly[(i + 1) % len(poly)]
            ia, ib = (a[axis] - lim) * keep <= 0, (b[axis] - lim) * keep <= 0
            if ia:
                nxt.append(a)
            if ia != ib:
                f = (lim - a[axis]) / (b[axis] - a[axis])
                nxt.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
        poly = nxt
        if not poly:
            return 0.0
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2


def _inside(point, p, grow):
    ax = _axes3(p)
    q = tuple(point[a] - p["p"][a] for a in range(3))
    return all(abs(_dot(q, ax[i])) <= p["s"][i] / 2 + grow for i in range(3))


def _samples(p):
    ax, half = _axes3(p), [v / 2 for v in p["s"]]
    return [tuple(p["p"][a] + ax[0][a] * half[0] * i + ax[1][a] * half[1] * j + ax[2][a] * half[2] * k_ for a in range(3))
            for i in (-1, 0, 1) for j in (-1, 0, 1) for k_ in (-1, 0, 1)]


def gate(out, model):
    """the faults the creature kit refuses to build with, for one building: a piece that floats (touching neither the
    ground nor another piece), and two faces facing the same way in one plane or under 0.05 studs apart where they
    overlap (they flicker in Roblox; two plain faces of one colour don't, and are let through). The reef in a tank is the lane's own props and is left out. Returns the lines"""
    ps = [p for p in out if (p["m"] == model or p["m"].startswith(model + "/")) and "fish" not in p and p.get("t") != 1 and p["n"] != "Reef"]
    faults, faces = [], [_faces(p) if p.get("sh") != "Ball" else [] for p in ps]
    samples = [_samples(p) for p in ps]
    for i, a in enumerate(ps):
        low = min(q[1] for q in samples[i])
        touching = low <= FLOOR_Y + 0.08
        for j, b in enumerate(ps):
            if touching:
                break
            if i != j and (any(_inside(q, b, 0.08) for q in samples[i]) or any(_inside(q, a, 0.08) for q in samples[j])):
                touching = True
        if not touching:
            faults.append(f"  ! {model}: {a['n']} at {a['p']} floats")
        for j in range(i + 1, len(ps)):
            b = ps[j]
            if math.dist(a["p"], b["p"]) > (math.sqrt(sum(v * v for v in a["s"])) + math.sqrt(sum(v * v for v in b["s"]))) / 2:
                continue
            for fa in faces[i]:
                for fb in faces[j]:
                    if _dot(fa[0], fb[0]) > 0.9999 and abs(_dot(fa[0], tuple(fb[1][c] - fa[1][c] for c in range(3)))) < 0.05:
                        if fa[0][1] < -0.99 and fa[1][1] <= FLOOR_Y + 0.05:
                            continue  # two undersides on the floor: never seen
                        if a["c"] == b["c"] and a.get("t") == b.get("t") and not fa[4] and not fb[4]:
                            continue  # the same plain colour twice: nothing there to flicker
                        area = _overlap(fa, fb)
                        if area > 0.05:
                            faults.append(f"  ! {model}: {a['n']} and {b['n']} share a plane (facing {tuple(round(v, 1) for v in fa[0])}, {area:.1f} square studs) near {tuple(round(v, 1) for v in fb[1])}")
    return faults


# ---------------------------------------------------------------- the whole hub
NEW_PLOTS = {i: 4 for i in range(1, 9)}  # plot: the level its tank is shown at, until the game's upgrade sets it. All
# level 4 since 2026-11-17, as the user's copies are (they were 1 to 5, to show the levels)
SHEET = "--levels" in sys.argv  # all the levels in a row, into hub_levels.json, for tools/blender/hub_view.py


def facing(x, z, toward):
    return math.degrees(math.atan2(toward[0] - x, toward[1] - z))


def build(hub, feet=None):
    out, feet = [], {} if feet is None else feet
    focus = (0.0, -150.0)  # the stations look at where a player stands when they arrive
    front, half, gate_half, gate_turn = hub["Front"], hub["Half"], hub["Gate"], hub["GateTurn"]
    spots = {  # each station: where it stands (x, z) and which way it faces. One line to move one
        # (2026-11-17: SELL and AURAS face each other either side of the spawn and FUSE stands behind it, facing the
        # start: the user's own placing in Studio. The INDEX went to the front corner on the left, facing the gate, as
        # its old place was outside the smaller hub's wall)
        "Sell": (-35.10, -112.71, 90.0), "Auras": (43.55, -112.70, -90.0), "Fuse": (4.73, -154.77, 0.0),
        "Index": (-(half - 34), front - 16, 90.0),
        # (the sub stand: 12 studs to its right and 8 back as seen from its front, Hugo 2026-11-18)
        "Sub": (gate_half + gate_turn + 20, front - 13, 180.0),
        "Earners": (-(gate_half + gate_turn + 20), front - 0.9, 180.0),
    }
    shops = (("Sell", sell_old), ("Auras", auras), ("Sub", sub)) if OLD else (("Sell", sell), ("Auras", auras_stall), ("Sub", sub_stall))
    for name, make in shops + (("Fuse", fuse), ("Index", index), ("Earners", earners)):
        x, z, yaw = spots[name]
        k = Kit(out, "Stations/" + name, (x, FLOOR_Y, z), facing(x, z, focus) if yaw is None else yaw)
        make(k)
        feet["Stations/" + name] = k.foot()
    arch(Kit(out, "Gate", (0, 0, 0)), hub)
    for index_, cx, cz, turn_deg in hub["Plots"]:
        if index_ in NEW_PLOTS and not OLD:
            plot(out, index_, cx, cz, turn_deg, hub, NEW_PLOTS[index_])
        else:
            plot_old(out, index_, cx, cz, turn_deg, hub)
        feet[f"Plots/Plot{index_}"] = Kit(out, "", (cx, FLOOR_Y, cz), turn_deg).foot()
    back = hub["Back"]
    # (the landmark, its lamps and its stepping stones went on 2026-11-17: the user deleted the landmark, and FUSE now
    # stands in the middle. The flags' poles and the far lamps would have stood in the tanks of the smaller hub)
    k = Kit(out, "Dressing")
    r = random.Random(12)
    for sx in (-1, 1):
        buoy(k.sub((sx * (gate_half + 5), FLOOR_Y, front - 3)), RED if sx < 0 else (90, 200, 120))
        palm(k.sub((sx * (gate_half + 14), FLOOR_Y, front - 12), yaw=90 - sx * 90), r)
        palm(k.sub((sx * (half - 34), FLOOR_Y, back + 52), yaw=sx * 40), r, 1.35)
    return out


MODELS = {"Stations": "Folder", "Dressing": "Folder"}  # every other path is a Model
PRIMARY = {"Stations": "Ring", "TrainerRide": "TrainerRide"}  # a station's Model, a trainer's Model: its PrimaryPart


def main():
    hub = json.load(open(os.path.join(BOX, "hub_in.json")))
    if SHEET:
        out = []
        for level in range(1, LEVELS + 1):
            plot(out, level, (level - (LEVELS + 1) / 2) * 100, 0, 0, hub, level)
        faults = [line for level in range(1, LEVELS + 1) for line in gate(out, f"Plots/Plot{level}")]
        print("\n".join(faults) if faults else f"{LEVELS} levels, {len(out)} parts, no faults")
        json.dump({"parts": out, "feet": {"Plots": Kit(out, "", (0, FLOOR_Y, 0)).foot()}}, open(os.path.join(BOX, "hub_levels.json"), "w"))
        return out
    feet = {}
    out = build(hub, feet)
    faults = []
    if not OLD:
        for model in ["Stations/Sell", "Stations/Auras", "Stations/Sub"] + [f"Plots/Plot{i}" for i in sorted(NEW_PLOTS)]:
            faults += gate(out, model)
    if faults:
        print("\n".join(faults))
        print(f"hub kit: {len(faults)} faults: nothing written")
        sys.exit(1)
    json.dump({"parts": out, "feet": feet}, open(os.path.join(BOX, "hub.json"), "w"))
    count = {}
    for p in out:
        key = p["m"] if not p["m"].startswith("Plots/") else "Plots (all eight)"
        key = "Plots, new" if not OLD and any(p["m"].startswith(f"Plots/Plot{i}") for i in NEW_PLOTS) else key
        count[key] = count.get(key, 0) + 1
    print(len(out), "parts:", count)
    return out


if __name__ == "__main__":
    main()
