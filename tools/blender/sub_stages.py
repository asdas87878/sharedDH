"""The nine submarines, one a tier, in the voxel style (option D of docs/design/sub-models.md): the game meshes.

    blender --background --python tools/blender/sub_stages.py -- <tier 1-9> <out folder> [--export art/subs] [--check]

Each sub is few big boxes on a one-stud grid, each a body part; a slope is a whole block turned; colour touches sit a
third of a cube proud; trim is a dark tint. Every tier keeps the placeholder's seat (its top 5.7 studs over the middle
and 5 behind it: SubController's SEAT), the tower in front of it and the deck at 5, so the ride doesn't change with the
look; the silhouette changes every few tiers. The colours are Shared/SubModels' (keep TIERS and that List alike).
Here X runs nose (-X) to tail, Z is up, the origin is the sub's middle (the game's pivot).
Parts: Hull (all that is rigid), Hull_Glow (glass and lines of light: Neon in the game), Seat, Prop (spins about the
hub: its box is centred on it), Light (the lamp: Neon, carries the beam).
The check: two faces of straight boxes that face the same way, overlap and lie under 0.05 studs apart would flicker in
Roblox; each is printed as a line starting "  !" and the build stops before rendering (--force goes on). Faces buried
whole in another box are left out of the mesh.
--export <folder> writes <folder>/<Id>/<Id>.glb as the creatures' are (one object to a part, vertex colours as plain
sRGB numbers, no materials, Roblox's axes: +Y up, the nose to -Z, 1 unit = 1 stud) and <Id>.mesh.json.
Renders: hero, side, back (the riding side) and top, transparent; the stud tile on faces that look up is in the render
only (studs aren't in the game yet, for the creatures either)."""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
TIER, OUT = int(argv[0]), argv[1]
EXPORT = argv[argv.index("--export") + 1] if "--export" in argv else None
CHECK, FORCE = "--check" in argv, "--force" in argv
HERE = os.path.dirname(os.path.abspath(__file__))
STUD = os.path.join(HERE, "..", "..", "art", "style", "tiles", "stud.png")
T = 1 / 3

# id, name, hull, trim, light (Shared/SubModels.List), seat, accent, how far the cameras stand back
TIERS = [
    ("Bathtub", "Bathtub", (255, 196, 38), (40, 54, 78), (120, 220, 255), (122, 75, 46), (232, 80, 58), 1.0),
    ("ReefRunner", "Reef Runner", (255, 128, 40), (60, 40, 30), (255, 240, 160), (122, 75, 46), (244, 241, 230), 1.0),
    ("KelpCruiser", "Kelp Cruiser", (70, 200, 90), (24, 70, 40), (200, 255, 140), (122, 75, 46), (255, 214, 70), 1.08),
    ("WreckDiver", "Wreck Diver", (176, 96, 52), (54, 44, 40), (255, 200, 120), (92, 62, 44), (232, 190, 60), 1.1),
    ("BlueStreak", "Blue Streak", (40, 140, 255), (230, 240, 255), (140, 255, 255), (30, 50, 90), (255, 70, 60), 1.2),
    ("TwilightRay", "Twilight Ray", (150, 80, 230), (40, 24, 70), (255, 140, 255), (40, 24, 70), (255, 200, 90), 1.4),
    ("MidnightHunter", "Midnight Hunter", (30, 40, 70), (10, 14, 24), (60, 255, 230), (22, 28, 46), (240, 240, 235), 1.3),
    ("VentCrawler", "Vent Crawler", (220, 50, 40), (30, 20, 20), (255, 170, 40), (30, 20, 20), (90, 84, 88), 1.3),
    ("AbyssKing", "Abyss King", (255, 214, 70), (20, 16, 30), (255, 80, 120), (20, 16, 30), (150, 70, 220), 1.45),
]
ID, NAME, HULL, TRIM, LIGHT, SEATC, ACCENT, FRAME = TIERS[TIER - 1]


def tone(c, lift=0.0, shade=1.0):
    return tuple(min(255, round((v + (255 - v) * lift) * shade)) for v in c)


dark_trim = sum(TRIM) < 200
PALETTE = {
    "hull": HULL, "hull+": tone(HULL, 0.28), "hull-": tone(HULL, 0, 0.8),
    "trim": TRIM, "trim+": tone(TRIM, 0.2 if dark_trim else 0.5), "trim-": tone(TRIM, 0, 0.8),
    "glass": LIGHT, "glow": LIGHT, "lamp": (255, 250, 210), "seat": SEATC, "accent": ACCENT,
    "white": (244, 241, 230), "tooth": (250, 246, 232),
}
GLOW = {"glass": 1.6, "glow": 2.4, "lamp": 4.0}
STUDDED = ("hull", "hull+", "trim")


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(c):
    return tuple(lin(v / 255) for v in c) + (1.0,)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 48
except AttributeError:
    pass
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------------------------------------ the pieces
BOXES = []  # every piece: {"part", "c", "size", "colour", "r"}; r None = a straight box on the grid's axes


def part_of(p, colour):
    if p == "Light":
        return "Light"
    return p + "_Glow" if colour in GLOW else p


def b(p, x0, x1, hw, z0, z1, colour, y=0.0):
    """a straight block: from x0 to x1, hw either side of y, z0 to z1"""
    BOXES.append({"part": part_of(p, colour), "c": ((x0 + x1) / 2, y, (z0 + z1) / 2),
                  "size": (abs(x1 - x0), 2 * hw, abs(z1 - z0)), "colour": colour, "r": None})


def pair(p, x0, x1, hw, z0, z1, colour, y):
    for s in (-1, 1):
        b(p, x0, x1, hw, z0, z1, colour, s * y)


def t(p, c, size, colour, r):
    """a turned block centred on c, turned by r (degrees about X, Y, Z)"""
    BOXES.append({"part": part_of(p, colour), "c": tuple(c), "size": tuple(size), "colour": colour, "r": tuple(r)})


def tpair(p, c, size, colour, r):
    """a turned block and its mirror across the middle"""
    for s in (-1, 1):
        t(p, (c[0], s * c[1], c[2]), size, colour, (s * r[0], r[1], s * r[2]))


# ------------------------------------------------------------------------------------------------ shared building blocks
AX = 0.75  # the propeller's axis, over the middle


def hull(x0=-10, x1=9, hw=5, belly=-4, front=4, back=4, tail=3, keel=True, deck="hull"):
    """the body: a tub, a step narrower fore and aft, a tail block round the propeller's axis, a darker keel plate.
    Returns (the shoulder's front x, the tail block's end x)."""
    b("Hull", x0, x1, hw, belly, 5, deck)
    b("Hull", x0 - front, x0 + 1, hw - 1, belly + 1, 4, "hull")
    b("Hull", x1 - 1, x1 + back, hw - 1, belly + 1, 4, "hull")
    b("Hull", x1 + back - 1, x1 + back + tail, hw - 2.5, AX - 2.25, AX + 2.25, "hull")
    if keel:
        b("Hull", x0 + 1, x1 - 1, hw - 1, belly - 1, belly + 0.5, "hull-")
    return x0 - front, x1 + back + tail


def nose_blunt(nx, hw=5, tip="hull+"):
    """two turned blocks in a chain, each tilted nose-down and a step smaller"""
    t("Hull", (nx - 1.2, 0, 0.1), (4.6, 2 * (hw - 1) - 1.6, 5.6), "hull", (0, -14, 0))
    t("Hull", (nx - 3.3, 0, -0.9), (3.2, 2 * (hw - 1) - 3.6, 3.6), tip, (0, -24, 0))


def nose_long(nx, hw=5, tip="hull+"):
    """three turned blocks: a longer, lower nose"""
    t("Hull", (nx - 1.6, 0, 0.3), (5.6, 2 * (hw - 1) - 1.4, 5.8), "hull", (0, -9, 0))
    t("Hull", (nx - 5.0, 0, -0.3), (5.0, 2 * (hw - 1) - 3.4, 4.2), "hull", (0, -15, 0))
    t("Hull", (nx - 8.0, 0, -1.3), (3.8, 2 * (hw - 1) - 5.4, 2.7), tip, (0, -22, 0))


def rim(x0=-10, x1=9, hw=5, colour="trim"):
    """a lip all round the tub's top, a third proud"""
    pair("Hull", x0 - T, x1 + T, 0.5, 4, 5 + T, colour, hw - 0.5 + T)
    b("Hull", x0 - T, x0 + 1, hw - 1 + T, 4.1, 5 + T, colour)
    b("Hull", x1 - 1, x1 + T, hw - 1 + T, 4.1, 5 + T, colour)


def tower(h=9, cap="trim", hatch="trim+", x0=-6, x1=2, hw=3):
    b("Hull", x0, x1, hw, 4, h, "hull")
    b("Hull", x0 - T, x1 + T, hw + T, h, h + 1, cap)
    b("Hull", x0 + 3, x1 - 2, 1, h + 0.5, h + 2, hatch)
    b("Hull", x0 - T, x0 + 1, hw - 1, 6, 8, "glass")  # the window, set in the tower's face
    b("Hull", x0 - T * 0.6, x0 + 1, hw - 0.5, 5.4, 5.9, "trim")  # its sill


def seat(back="seat"):
    """the same on every tier: a cushion behind the tower, its top at 5.7, a back rest, a bar for the hands"""
    b("Seat", 3, 7, 2, 4.7, 5.7, "seat")
    b("Seat", 6.6, 8, 2.2, 5.2, 7.5, back)
    pair("Seat", 2.3, 2.9, 0.3, 4.8, 7.0, "trim", 2)
    b("Seat", 2.1, 3.1, 2.5, 6.6, 7.3, "trim+")


def ports(xs, hw=5, z=0.5, half=1.0):
    for x in xs:
        pair("Hull", x - half, x + half, T / 2, z - half, z + half, "glass", hw + T / 2)
        pair("Hull", x - half - 0.5, x + half + 0.5, T / 4, z - half - 0.5, z + half + 0.5, "trim", hw + T / 4)


def side_line(x0, x1, hw=5, z=-1.5, colour="hull+", thick=1.0, proud=T / 2):
    pair("Hull", x0, x1, proud / 2, z - thick / 2, z + thick / 2, colour, hw + proud / 2)


def wings(x=-7, hw=5, z=-1.0, colour="trim", tip="trim+", span=3.6, chord=4.0, drop=10):
    """two boxes a side, the second smaller and starting inside the first, tipped down"""
    tpair("Hull", (x, hw - 0.4 + span / 2, z), (chord, span, 1.0), colour, (-drop, 0, 0))
    tpair("Hull", (x + 0.4, hw - 0.6 + span + 0.9, z - 0.45 - span * 0.06), (chord - 1, 2.6, 0.7), tip, (-drop - 8, 0, 0))


def fins_cross(tx, tall=7, low=-5, wide=6.5, colour="trim", tip="trim+"):
    """the tail's cross: a standing fin and a flat one, each two boxes"""
    b("Hull", tx - 1, tx + 2.5, 0.5, low, tall, colour)
    b("Hull", tx, tx + 3, 0.3, tall - 1, tall + 2, tip)
    b("Hull", tx - 0.5, tx + 2, wide, AX - 0.5, AX + 0.5, colour)
    pair("Hull", tx + 0.5, tx + 2.5, 1.2, AX - 0.3, AX + 0.3, tip, wide + 0.5)


def prop(px, blades=2, reach=3.55, colour="white", hub="trim+"):
    """a block propeller, its box centred on the hub so it spins true"""
    b("Prop", px - 0.5, px + 1, 0.8, AX - 0.75, AX + 0.75, hub)
    b("Prop", px + 0.6, px + 1.4, 0.7, AX - reach, AX + reach, colour)
    b("Prop", px + 0.7, px + 1.3, reach, AX - 0.65, AX + 0.65, colour)
    if blades >= 3:  # a second cross, turned an eighth
        t("Prop", (px + 0.95, 0, AX), (0.5, 1.2, 2 * reach - 0.8), colour, (45, 0, 0))
        t("Prop", (px + 0.95, 0, AX), (0.5, 1.2, 2 * reach - 0.8), colour, (-45, 0, 0))


def lamp(nx, z=-3.0, y=0.0, hw=1.0):
    """a glowing block in a dark housing under the nose"""
    b("Hull", nx - 1.5, nx + 1, hw + 0.5, z - 2, z - 0.5, "trim", y)
    b("Light", nx - 2, nx - 1.2, hw, z - 1.7, z - 0.8, "lamp", y)


def patch(x, z, hw=5, side=-1, w=3, h=3):
    """a patch plate with two bolts: the flaw"""
    b("Hull", x, x + w, T / 2, z, z + h, "hull-", side * (hw + T / 2))
    b("Hull", x + 0.3, x + 0.8, T / 3, z + h - 0.8, z + h - 0.3, "trim", side * (hw + T))
    b("Hull", x + w - 0.8, x + w - 0.3, T / 3, z + 0.3, z + 0.8, "trim", side * (hw + T))


def pods(x0, x1, y, z=-1.0, r=1.5, colour="hull", strut="trim"):
    """a pod on each side on a strut, a light at its nose"""
    pair("Hull", x0, x1, r, z - r, z + r, colour, y)
    pair("Hull", x0 - 1, x0 + 0.5, r - 0.5, z - r + 0.5, z + r - 0.5, colour + "+" if colour == "hull" else colour, y)
    pair("Hull", x0 - 1 - T, x0 - 0.5, r - 0.9, z - r + 0.9, z + r - 0.9, "glow", y)
    pair("Hull", x1 - 0.5, x1 + 0.8, r - 0.6, z - r + 0.6, z + r - 0.6, strut, y)
    pair("Hull", (x0 + x1) / 2 - 1.5, (x0 + x1) / 2 + 1.5, (y - r) / 2 - 1.5, z - 0.5, z + 0.4, strut, (y - r) / 2 + 1.9)


def spikes(xs, z=-5.0, colour="trim", size=(1.4, 1.4, 3.2), lean=28):
    for x in xs:
        t("Hull", (x, 0, z - 0.8), size, colour, (0, lean, 0))


# ------------------------------------------------------------------------------------------------ the nine
def tier1():  # the Bathtub: a friendly tub
    nx, px = hull()
    nose_blunt(nx)
    rim()
    tower()
    seat()
    ports((-8, -1))
    side_line(-8, 7)
    wings()
    fins_cross(13)
    prop(px)
    lamp(nx)
    patch(3, 0)


def tier2():  # the Reef Runner: the tub with a bumper, a white band, a snorkel and a taller rudder
    nx, px = hull()
    nose_blunt(nx, tip="hull")
    t("Hull", (nx - 4.5, 0, -1.6), (1.2, 7.6, 1.4), "trim", (0, -24, 0))  # the bumper bar
    rim()
    tower(cap="trim")
    seat()
    ports((-8, -1))
    side_line(-9, 8, z=-2.2, colour="accent", thick=1.4)
    side_line(-9, 8, z=2.6, colour="trim", thick=0.6, proud=T / 3)
    wings()
    wings(x=10.5, hw=4, z=-0.2, span=2.6, chord=3.0)
    fins_cross(13, tall=8)
    prop(px)
    lamp(nx)
    # the snorkel: a pipe up the tower's side with a bent top
    b("Hull", -1, 0, 0.5, 6, 13, "trim", 3 + T + 0.5)
    b("Hull", -2.4, 0.3, 0.7, 12.4, 13.6, "accent", 3 + T + 0.5)


def tier3():  # the Kelp Cruiser: longer, three ports, a V of leaf fins for a tail, kelp-striped back
    nx, px = hull(x0=-11, x1=10, front=4, back=5)
    nose_blunt(nx)
    rim(-11, 10)
    tower(h=9)
    seat()
    ports((-9, -4.5, 0))
    side_line(-9, 9, z=-2.4, colour="trim", thick=0.8)
    pair("Hull", 9.5, 13.5, T / 2, 0, 2.5, "accent", 4 + T / 2)  # a yellow tail flash
    wings(x=-8, span=4.4, chord=4.4)
    wings(x=9, hw=4, z=-0.4, span=3.2, chord=3.4)
    # the V tail: two leaf fins leaning out, each two boxes, and a small keel fin
    tpair("Hull", (15.2, 2.6, 4.6), (4.0, 0.9, 7.0), "trim", (-28, 12, 0))
    tpair("Hull", (16.6, 4.6, 8.4), (2.8, 0.6, 3.6), "trim+", (-28, 12, 0))
    b("Hull", 13.5, 16.5, 0.5, -4.5, AX, "trim")
    prop(px, blades=3)
    lamp(nx)
    # kelp leaves over the tower's cap: two small turned blocks
    t("Hull", (0.8, 0, 11.2), (2.6, 0.7, 2.4), "trim+", (0, 30, 0))


def tier4():  # the Wreck Diver: a boxy salvage boat: ballast tanks, a periscope, a crane hook, patches, twin lamps
    nx, px = hull(hw=5.5, front=3, back=4)
    t("Hull", (nx - 0.9, 0, 0.3), (3.6, 7.6, 6.0), "hull", (0, -8, 0))  # a flat, blunt bow
    t("Hull", (nx - 2.7, 0, -0.2), (1.2, 8.6, 3.4), "trim", (0, -8, 0))  # its bumper plate
    rim(hw=5.5)
    tower(h=9, cap="trim")
    seat()
    ports((-8, -1), hw=5.5, z=1.2)
    pair("Hull", -9, 8, 1.3, -4.6, -1.4, "hull-", 5.5 + 0.9)  # the ballast tanks along the lower sides
    pair("Hull", -9.8, -8.6, 1.0, -4.2, -1.8, "trim", 5.5 + 0.9)
    pair("Hull", 7.6, 8.8, 1.0, -4.2, -1.8, "trim", 5.5 + 0.9)
    patch(3, 0.6, hw=5.5)
    patch(-6.5, 1.3, hw=5.5, side=1, w=2.4, h=2.4)
    # the periscope
    b("Hull", -3.5, -2.5, 0.5, 10.5, 14.5, "trim", 1.8)
    b("Hull", -5, -2.3, 0.7, 13.6, 15, "trim+", 1.8)
    b("Hull", -5 - T / 2, -4.6, 0.4, 13.9, 14.7, "glass", 1.8)
    # the crane: an arm over the bow with a hook
    t("Hull", (-10.5, 0, 7.6), (8.0, 1.0, 1.0), "accent", (0, 18, 0))
    b("Hull", -14.8, -13.8, 0.3, 4.6, 8.8, "trim")
    b("Hull", -15.6, -13.6, 0.5, 3.8, 4.8, "trim+")
    fins_cross(13, tall=6.5, wide=7)
    prop(px, blades=3, hub="accent")
    lamp(nx, hw=2.6)  # one wide lamp: twin beams behind one glass


def tier5():  # the Blue Streak: long and low, swept wings, pods, a tall swept fin
    nx, px = hull(x0=-10, x1=10, hw=4.5, front=5, back=5, tail=4)
    nose_long(nx, hw=4.5)
    rim(-10, 10, hw=4.5)
    tower(h=8.4, cap="trim")
    seat()
    ports((-8, -3.5), hw=4.5, half=0.9)
    side_line(-13, 13, hw=3.5, z=2.2, colour="trim", thick=0.9, proud=1 + T / 3)  # the racing stripe (on the tub: proud)
    side_line(-9.5, 9.5, hw=4.5, z=-2.4, colour="accent", thick=0.6)
    # swept wings: each two boxes turned back
    tpair("Hull", (-5.5, 6.6, -1.2), (4.6, 5.6, 0.9), "trim", (-6, 0, -28))
    tpair("Hull", (-3.0, 10.2, -1.5), (3.0, 3.6, 0.6), "trim+", (-6, 0, -36))
    pods(-2, 8, 8.4, z=-1.4, r=1.4)
    # the tail: a tall swept fin in three boxes, flat tailplanes
    t("Hull", (15.5, 0, 5.2), (4.4, 0.9, 7.0), "trim", (0, 24, 0))
    t("Hull", (17.6, 0, 9.3), (3.0, 0.6, 3.6), "trim+", (0, 24, 0))
    b("Hull", 14.5, 17, 0.5, -3.8, AX, "trim")
    tpair("Hull", (16.0, 4.6, AX), (3.4, 6.0, 0.8), "trim", (0, 0, -22))
    prop(px, blades=3, colour="trim+", hub="accent")
    lamp(nx - 3, z=-2.6)


def tier6():  # the Twilight Ray: a manta: wide wings in three steps with a line of light, a crest, a long tail spike
    nx, px = hull(x0=-10, x1=10, hw=5, front=4, back=5, tail=3)
    nose_long(nx)
    rim(-10, 10)
    tower(h=8.6, cap="trim")
    seat()
    ports((-8, -3.5))
    # the wings: three flat blocks a side, each thinner, shorter and further back, tipped down a little
    tpair("Hull", (-1.0, 8.4, -0.4), (15.0, 7.6, 1.6), "hull", (-5, 0, 0))
    tpair("Hull", (0.6, 14.2, -1.0), (11.0, 5.6, 1.1), "hull-", (-9, 0, 0))
    tpair("Hull", (2.2, 18.6, -1.9), (7.0, 4.4, 0.7), "trim", (-14, 0, 0))
    tpair("Hull", (-8.3, 8.4, -0.4), (0.7, 7.0, 0.9), "glow", (-5, 0, 0))  # the line of light on each leading edge
    tpair("Hull", (-4.7, 14.2, -1.0), (0.6, 5.0, 0.6), "glow", (-9, 0, 0))
    # horn fins either side of the nose, as a manta's
    tpair("Hull", (nx - 3.0, 3.4, -1.6), (4.4, 1.2, 1.6), "trim", (0, -16, 14))
    # the crest behind the seat and the tail spike
    b("Hull", 10, 15, 0.5, 4, 7.2, "trim")
    b("Hull", 12, 16, 0.3, 6.6, 9.0, "trim+")
    t("Hull", (20.5, 0, AX + 3.0), (9.0, 0.9, 0.9), "trim", (0, 8, 0))
    b("Hull", 14, 17, 5.5, AX + 0.6, AX + 1.4, "trim")
    pair("Hull", 9, 13.5, T / 2, 0.4, 1.4, "glow", 4 + T / 2)
    prop(px, blades=3, colour="trim+", hub="glow")
    lamp(nx - 3, z=-2.6)


def tier7():  # the Midnight Hunter: a shark: long snout, a jaw with teeth, a dorsal fin, lines of light, claws
    nx, px = hull(x0=-10, x1=10, hw=5, front=5, back=5, tail=4)
    nose_long(nx, tip="hull")
    # the jaw: a darker block under the snout, teeth along its edge
    t("Hull", (nx - 3.6, 0, -3.3), (7.0, 5.6, 1.6), "trim+", (0, -6, 0))
    for x in (-6.2, -4.4, -2.6, -0.8):
        tpair("Hull", (nx + x, 2.3, -2.3), (0.8, 0.8, 1.3), "tooth", (0, -6, 0))
    rim(-10, 10, colour="trim+")
    tower(h=8.6, cap="trim+", hatch="trim")
    seat()
    # slit eyes for ports, and a line of light along each flank
    pair("Hull", -9, -5, T / 2, 1.2, 2.2, "glow", 5 + T / 2)
    pair("Hull", -9.5, -4.5, T / 4, 0.7, 2.7, "trim", 5 + T / 4)
    side_line(-3, 9.5, z=-1.2, colour="glow", thick=0.5)
    side_line(-3.6, 10, z=-1.2, colour="trim", thick=1.3, proud=T / 4)
    # gill slots
    for x in (-2.5, -1, 0.5):
        pair("Hull", x, x + 0.6, T / 3, 0.6, 3.4, "trim", 5 + T / 3)
    # pectoral fins swept back, the dorsal fin behind the seat, a shark's tail
    tpair("Hull", (-4.5, 7.4, -2.2), (5.0, 6.0, 0.9), "hull-", (-16, 0, -30))
    tpair("Hull", (-1.8, 11.0, -3.3), (3.0, 3.4, 0.6), "trim+", (-16, 0, -38))
    t("Hull", (12.6, 0, 6.6), (5.0, 0.9, 5.6), "hull-", (0, 28, 0))
    t("Hull", (14.6, 0, 9.6), (3.0, 0.6, 3.0), "trim+", (0, 28, 0))
    t("Hull", (17.6, 0, 5.4), (4.0, 0.9, 8.6), "hull-", (0, 30, 0))
    t("Hull", (17.2, 0, -2.6), (3.2, 0.8, 5.0), "hull-", (0, -32, 0))
    tpair("Hull", (15.5, 4.2, AX), (3.0, 5.0, 0.8), "trim+", (0, 0, -24))
    # claws under the bow
    tpair("Hull", (nx + 0.5, 3.4, -4.6), (5.0, 1.0, 1.0), "trim+", (0, 20, -10))
    tpair("Hull", (nx - 2.6, 3.1, -5.4), (2.4, 0.7, 0.7), "tooth", (0, -18, -10))
    prop(px, blades=3, colour="trim+", hub="glow")
    lamp(nx - 1, z=-3.6, hw=0.8)


def tier8():  # the Vent Crawler: armour plates, vent stacks that glow, pincers, spikes along the belly
    nx, px = hull(x0=-10, x1=10, hw=5.5, front=4, back=4, tail=3)
    nose_blunt(nx, hw=5.5, tip="trim")
    rim(-10, 10, hw=5.5)
    tower(h=9, cap="trim", hatch="accent")
    seat()
    ports((-8,), hw=5.5, z=1.6, half=0.9)
    # armour: three plates a side, a second layer of form, each with a glowing seam under it
    for x in (-5.5, 0, 5.5):
        pair("Hull", x, x + 4.6, 0.4, -3.4, 2.6, "accent", 5.5 + 0.4)
        pair("Hull", x + 0.4, x + 4.2, T / 2, -4.0, -3.5, "glow", 5.5 + T / 2)
    # the vent stacks on the haunch, glowing at the mouth
    for y in (-2.6, 2.6):
        b("Hull", 10.5, 12.5, 1.0, 3.5, 8.0, "trim", y)
        b("Hull", 10.2, 12.8, 1.3, 7.4, 8.6, "accent", y)
        b("Hull", 10.8, 12.2, 0.7, 8.2, 8.6 + T, "glow", y)
    # pincers: an arm of two boxes a side, a claw of two
    tpair("Hull", (-12.0, 6.4, -2.6), (6.0, 1.6, 1.6), "accent", (0, 6, 24))
    tpair("Hull", (-16.6, 6.6, -3.0), (5.0, 1.3, 1.3), "trim", (0, 8, -22))
    tpair("Hull", (-19.6, 6.1, -3.2), (3.0, 0.8, 2.4), "hull", (0, 8, -8))
    tpair("Hull", (-19.4, 4.2, -3.2), (2.6, 0.7, 2.0), "hull+", (0, 8, 26))
    spikes((-6, 0, 6), z=-5.2)
    # back spikes on the tail block, clear of the seat
    t("Hull", (14.6, 0, 4.4), (1.4, 1.4, 4.0), "trim", (0, 30, 0))
    fins_cross(13, tall=6, low=-5.5, wide=7)
    prop(px, blades=3, colour="accent", hub="glow")
    lamp(nx, z=-3.0)
    side_line(11, 14, hw=4.5, z=1.0, colour="glow", thick=0.6)


def tier9():  # the Abyss King: the biggest: a crown, a trident ram, pods, wings, spikes, lines of light
    nx, px = hull(x0=-11, x1=10, hw=5.5, front=5, back=5, tail=4)
    nose_long(nx, hw=5.5, tip="trim")
    # the trident: three dark prongs from the snout, the middle one longest
    t("Hull", (nx - 11.0, 0, -2.4), (5.0, 1.0, 1.0), "trim+", (0, -20, 0))
    tpair("Hull", (nx - 9.4, 2.0, -1.9), (4.0, 0.8, 0.8), "trim+", (0, -20, -16))
    t("Hull", (nx - 13.2, 0, -3.2), (1.2, 0.6, 0.6), "glow", (0, -20, 0))
    rim(-11, 10, hw=5.5, colour="trim")
    pair("Hull", -10.6, 9.6, T / 3, 3.2, 3.8, "accent", 5.5 + T / 3)  # a violet band under the lip
    tower(h=9.4, cap="trim", hatch="trim+")
    # the crown: glowing points round the cap
    for x, y, h in ((-5.2, 2.2, 2.2), (-5.2, -2.2, 2.2), (0.6, 2.2, 2.2), (0.6, -2.2, 2.2), (-5.4, 0, 3.0)):
        b("Hull", x, x + 1.0, 0.5, 10.2, 10.4 + h, "glow", y)
    seat()
    ports((-9, -4.5), hw=5.5, z=0.6)
    side_line(-1.5, 9.5, hw=5.5, z=0.4, colour="glow", thick=0.5)
    side_line(-2.0, 10, hw=5.5, z=0.4, colour="trim", thick=1.5, proud=T / 4)
    pods(-3, 8, 10.0, z=-1.4, r=1.7, colour="trim")
    tpair("Hull", (-8.0, 8.4, -1.0), (4.6, 6.4, 1.0), "trim", (-8, 0, -24))
    tpair("Hull", (-5.6, 12.4, -1.5), (3.0, 3.6, 0.7), "accent", (-8, 0, -32))
    spikes((-7, -1, 5), z=-5.2, colour="trim+")
    # the crest: three plates stepping up toward the tail, clear of the seat
    b("Hull", 9.5, 12.5, 0.5, 4, 7.0, "trim")
    b("Hull", 12, 14.3, 0.4, 3, 9.0, "trim+")
    b("Hull", 12.5, 13.8, T / 2 + 0.4, 6.0, 7.4, "glow")
    fins_cross(15, tall=9.5, low=-6, wide=8, colour="trim", tip="accent")
    prop(px, blades=3, reach=4.2, colour="accent", hub="glow")
    lamp(nx - 2, z=-3.2)


[tier1, tier2, tier3, tier4, tier5, tier6, tier7, tier8, tier9][TIER - 1]()
# ------------------------------------------------------------------------------------------------ the check
def aabb(box):
    return [(box["c"][i] - box["size"][i] / 2, box["c"][i] + box["size"][i] / 2) for i in range(3)]


def group(box):
    return "Prop" if box["part"] == "Prop" else "Body"


faults = []
straight = [x for x in BOXES if x["r"] is None]
for i, p in enumerate(straight):
    for q in straight[i + 1 :]:
        if group(p) != group(q):
            continue
        a, c = aabb(p), aabb(q)
        for axis in range(3):
            o1, o2 = [k for k in range(3) if k != axis]
            over = [min(a[k][1], c[k][1]) - max(a[k][0], c[k][0]) for k in (o1, o2)]
            if min(over) <= 0.02:
                continue
            for side in (0, 1):
                if abs(a[axis][side] - c[axis][side]) < 0.05:
                    # hidden when a third box covers the shared patch on its outer side
                    mid = [0.0, 0.0, 0.0]
                    for k in (o1, o2):
                        mid[k] = (max(a[k][0], c[k][0]) + min(a[k][1], c[k][1])) / 2
                    mid[axis] = a[axis][side] + (0.06 if side else -0.06)
                    covered = any(all(lo < mid[k] < hi for k, (lo, hi) in enumerate(aabb(z))) for z in straight
                                  if z is not p and z is not q and group(z) == group(p))
                    if not covered:
                        faults.append("  ! %s %s and %s %s share a face on %s at %.2f (%s / %s)" % (
                            p["part"], [round(v, 2) for v in p["c"]], q["part"], [round(v, 2) for v in q["c"]],
                            "xyz"[axis], a[axis][side], p["colour"], q["colour"]))
for line in faults:
    print(line)
print("sub stages: tier %d %s: %d pieces, %d faults" % (TIER, NAME, len(BOXES), len(faults)))
if CHECK or (faults and not FORCE):
    sys.exit(1 if faults else 0)

# ------------------------------------------------------------------------------------------------ meshes
MATS, ORDER = {}, []


def mat(name):
    if name in MATS:
        return ORDER.index(name)
    base = name.rstrip("*")
    m = bpy.data.materials.new(base + ("|stud" if name.endswith("*") else ""))
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = rgba(PALETTE[base])
    bs.inputs["Roughness"].default_value = 0.65
    if "Specular IOR Level" in bs.inputs:
        bs.inputs["Specular IOR Level"].default_value = 0.25
    if base in GLOW:
        bs.inputs["Emission Color"].default_value = rgba(PALETTE[base])
        bs.inputs["Emission Strength"].default_value = GLOW[base]
    if name.endswith("*"):
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.abspath(STUD))
        tex.image.colorspace_settings.name = "Non-Color"
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = "MULTIPLY"
        mul.inputs["Fac"].default_value = 1.0
        mul.inputs["Color1"].default_value = rgba(PALETTE[base])
        gain = nt.nodes.new("ShaderNodeMath")
        gain.operation = "MULTIPLY"
        gain.inputs[1].default_value = 255 / 128
        nt.links.new(geo.outputs["Position"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], gain.inputs[0])
        nt.links.new(gain.outputs[0], mul.inputs["Color2"])
        nt.links.new(mul.outputs["Color"], bs.inputs["Base Color"])
    MATS[name] = m
    ORDER.append(name)
    return len(ORDER) - 1


def rot(r):
    return Euler([math.radians(a) for a in r]).to_matrix().to_4x4()


def inside(point, box):
    return all(lo - 1e-4 < point[k] < hi + 1e-4 for k, (lo, hi) in enumerate(aabb(box)))


PARTS = {}
dropped = 0
for box in BOXES:
    bm = PARTS.setdefault(box["part"], bmesh.new())
    m = Matrix.Translation(box["c"]) @ (rot(box["r"]) if box["r"] else Matrix.Identity(4)) @ Matrix.Diagonal((*box["size"], 1.0))
    made = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    occluders = [z for z in straight if z is not box and group(z) == group(box)]
    for f in {f for v in made["verts"] for f in v.link_faces}:
        f.normal_update()
        centre = f.calc_center_median()
        probes = [centre + f.normal * 0.02] + [centre + (v.co - centre) * 0.98 + f.normal * 0.02 for v in f.verts]
        if any(all(inside(p, z) for p in probes) for z in occluders):
            bm.faces.remove(f)  # buried whole in one other box: nothing can see it
            dropped += 1
            continue
        stud = box["colour"] in STUDDED and f.normal.z > 0.95
        f.material_index = mat(box["colour"] + ("*" if stud else ""))

col = bpy.data.collections.new("Sub")
scene.collection.children.link(col)
tris, objects = 0, {}
for name, bm in PARTS.items():
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    tris += sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    used = sorted({poly.material_index for poly in me.polygons})
    for i in used:
        me.materials.append(MATS[ORDER[i]])
    for poly in me.polygons:
        poly.material_index = used.index(poly.material_index)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    objects[name] = ob
xs = [c for box in BOXES for c in (box["c"][0] - box["size"][0] / 2, box["c"][0] + box["size"][0] / 2)]
ys = [abs(box["c"][1]) + box["size"][1] / 2 for box in BOXES]
print("sub stages: tier %d %s: %d parts, %d triangles (%d hidden faces left out), about %.0f long, %.0f across" % (
    TIER, NAME, len(objects), tris, dropped, max(xs) - min(xs), 2 * max(ys)))
with open(os.path.join(OUT, "stats.json"), "w") as fh:
    json.dump({"tier": TIER, "id": ID, "name": NAME, "parts": len(objects), "triangles": tris,
               "length": round(max(xs) - min(xs), 1), "width": round(2 * max(ys), 1)}, fh)

if EXPORT:
    folder = os.path.join(EXPORT, ID)
    os.makedirs(folder, exist_ok=True)
    # as tools/blender/voxel_kit.py: colours as plain sRGB numbers in a corner attribute; Blender writes (x, y, z) to a
    # glTF as (x, z, -y) and the game wants (kit y, kit z, kit x), so the meshes are turned to (y, -x, z) first
    turn = Matrix(((0, 1, 0, 0), (-1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    twins = []
    for name, ob in objects.items():
        ob.name = ob.data.name = name + ".view"  # (first: two things can't hold one name)
        twin = ob.copy()
        twin.data = ob.data.copy()
        twin.name = twin.data.name = name
        scene.collection.objects.link(twin)
        me = twin.data
        tint = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for poly in me.polygons:
            colour = me.materials[poly.material_index].name.split("|")[0].split(".")[0]
            r, g, bl = (v / 255 for v in PALETTE[colour])
            for loop in poly.loop_indices:
                tint.data[loop].color = (r, g, bl, 1.0)
        me.color_attributes.active_color = tint
        me.transform(turn)
        twins.append(twin)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for twin in twins:
        twin.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(folder, ID + ".glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=False, export_animations=False,
                              export_vertex_color="ACTIVE", export_materials="NONE")
    for twin in twins:
        bpy.data.objects.remove(twin)
    for name, ob in objects.items():
        ob.name = ob.data.name = name
    json.dump({"id": ID, "name": NAME, "tier": TIER, "units": "studs", "triangles": tris,
               "axes": {"up": "+Y", "forward": "-Z (the nose)", "right": "+X"}, "origin": "the sub's middle (the game's pivot)",
               "seatTop": [0, 5.7, 5], "parts": sorted(objects),
               "glowParts": sorted(n for n in objects if n.endswith("_Glow") or n == "Light"),
               "spins": "Prop (about Z, its box centred on the hub)",
               "colours": {"hull": HULL, "trim": TRIM, "light": LIGHT}},
              open(os.path.join(folder, ID + ".mesh.json"), "w"), indent=1)
    print("sub stages: wrote", os.path.join(folder, ID + ".glb"))


# ------------------------------------------------------------------------------------------------ cameras and light
def look_from(ob, source, target):
    ob.location = source
    ob.rotation_euler = (Vector(target) - Vector(source)).to_track_quat("-Z", "Y").to_euler()


def camera(name, ortho=None, lens=50):
    cam = bpy.data.cameras.new(name)
    if ortho:
        cam.type, cam.ortho_scale = "ORTHO", ortho
    else:
        cam.lens = lens
    cam.clip_end = 2000
    ob = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(ob)
    return ob


def render(cam, name, w, h):
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


# a blocky rider on the seat, so the size reads (root 1.7 over the seat's top, as SubController's SEAT)
RIDER = {"skin": (242, 201, 76), "shirt": (45, 127, 211), "legs": (92, 168, 74)}
rm = {}
for k, c in RIDER.items():
    m = bpy.data.materials.new("Rider_" + k)
    m.use_nodes = True
    m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = rgba(c)
    rm[k] = m


def rbox(c, size, k, r=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(c) @ rot(r) @ Matrix.Diagonal((*size, 1.0)))
    me = bpy.data.meshes.new("Rider")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(rm[k])
    scene.collection.objects.link(bpy.data.objects.new("Rider", me))


SX, SZ = 5.0, 5.7
rbox((SX, 0, SZ + 1.7), (1.0, 2.0, 2.0), "shirt", r=(0, -8, 0))
rbox((SX - 0.3, 0, SZ + 3.4), (1.25, 1.25, 1.25), "skin")
for s in (-1, 1):
    rbox((SX - 1.0, s * 0.55, SZ + 0.5), (2.0, 0.95, 0.95), "legs")
    rbox((SX - 2.0, s * 0.55, SZ - 0.1), (0.95, 0.95, 1.6), "legs", r=(0, 20, 0))
    rbox((SX - 1.2, s * 1.5, SZ + 1.75), (2.3, 0.9, 0.9), "skin", r=(0, 22, 0))

world = bpy.data.worlds.new("World")
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value = rgba((254, 248, 241))
bg.inputs["Strength"].default_value = 0.6
scene.world = world
sun_data = bpy.data.lights.new("Key", "SUN")
sun_data.energy, sun_data.angle = 2.3, math.radians(14)
sun = bpy.data.objects.new("Key", sun_data)
scene.collection.objects.link(sun)
look_from(sun, (-5.0, -7.0, 9.0), (0, 0, 0))
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"

mid = (min(xs) + max(xs)) / 2
hero = camera("Hero", lens=75)
look_from(hero, (mid - 62 * FRAME, -70 * FRAME, 30 * FRAME), (mid + 0.5, 0, 1.5))
render(hero, "hero.png", 1200, 820)
side = camera("Side", ortho=46 * FRAME)
look_from(side, (mid, -200, 2), (mid, 0, 2))
render(side, "side.png", 1000, 480)
look_from(sun, (4, -5, 12), (0, 0, 0))
back = camera("Back", lens=40)
look_from(back, (mid + 44 * FRAME, -17 * FRAME, 21 * FRAME), (mid - 3, 0, 3.0))
render(back, "back.png", 1000, 700)
