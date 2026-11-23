"""The nine submarines, one a tier: the game meshes, in the picked style.

    blender --background --python tools/blender/sub_stages.py -- <tier 1-9> <out folder> [--style toy|voxel]
            [--export art/subs] [--check] [--force] [--px 2]
    python tools/blender/sub_stages.py sheet <renders folder> <out.png>          (plain Python with Pillow)
    python tools/blender/sub_stages.py compare <style A renders> <a tier's renders> <out.png>

Two styles, by --style:
  toy    (the default) option A of docs/design/sub-models.md, "Chunky toy", the user's pick of 2026-11-22 ("for
         submarine [use] the toy version"): fat rounded forms with few sides, smooth shaded, thick rims round the
         glass, a guard ring round the propeller and a wind-up key on the back, both in the tier's accent colour (red
         on tier 1); add-ons are toy parts. Tier 1 is the approved model of tools/blender/sub_kit.py, piece for piece.
  voxel  option D, built first as a fallback (mission 7c14c23d): few big boxes on a one-stud grid, each a body part; a
         slope is a whole block turned; colour touches sit a third of a cube proud. Its exports are kept in
         art/subs/voxel/<Id>/ (write them again with --style voxel --export art/subs/voxel).
Every tier, in both styles, keeps the placeholder's seat (its top 5.7 studs over the middle and 5 behind it:
SubController's SEAT), the tower in front of it and the hull's top near 5, so the ride doesn't change with the look;
the silhouette changes every few tiers. The colours are Shared/SubModels' (keep TIERS and that List alike).
Here X runs nose (-X) to tail, Z is up, the origin is the sub's middle (the game's pivot).
Parts: Hull (all that is rigid), Hull_Glow (glass and lines of light: Neon in the game), Seat, Prop (spins about the
hub: its box is centred on it), Prop_Glow (tiers 6 to 9: a glowing hub), Light (the lamp: Neon, carries the beam).
The check: faces that face the same way, overlap and lie under 0.05 studs apart would flicker in Roblox; each is
printed as a line starting "  !" and the build stops before rendering (--force goes on). Voxel: straight boxes only,
and faces buried whole in another box are left out of the mesh. Toy: every face of every piece, of two colours, where
no third piece covers the spot.
--export <folder> writes <folder>/<Id>/<Id>.glb as the creatures' are (one object to a part, vertex colours as plain
sRGB numbers, no materials, Roblox's axes: +Y up, the nose to -Z, 1 unit = 1 stud) and <Id>.mesh.json.
Renders: hero, side and back (the riding side), transparent, with a blocky rider for size; --px 2 doubles their size.
The voxel style's stud tile on faces that look up is in the render only."""
import json
import math
import os
import sys


# ------------------------------------------------------------------------------------------------ the sheets (Pillow)
def sheets(mode, args):
    from PIL import Image, ImageDraw, ImageFilter, ImageFont

    bold = next((p for p in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                             "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/arialbd.ttf") if os.path.exists(p)), None)

    def font(size):
        try:
            return ImageFont.truetype(bold, size)
        except (OSError, TypeError, AttributeError):
            return ImageFont.load_default(size)

    INK, SOFT, CREAM, WELL = (38, 38, 38), (122, 114, 106), (254, 248, 241), (244, 236, 226)

    def cut(im):
        box = im.getbbox()
        return im.crop(box) if box else im

    def lay(sheet, im, x, y, w, h, k=None):
        """im, cut to what is drawn, in the middle of the box; k None fits it, else scales it by k. Returns k."""
        im = cut(im)
        if k is None:
            k = min(w / im.width, h / im.height)
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
        at = (x + (w - im.width) // 2, y + (h - im.height) // 2)
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        sh.putalpha(im.getchannel("A").point(lambda a: a // 5))
        sheet.paste((60, 40, 30), (at[0] + 8, at[1] + 12), sh.filter(ImageFilter.GaussianBlur(10)).getchannel("A"))
        sheet.paste(im, at, im)
        return k

    def view(folder, name):
        return Image.open(os.path.join(folder, name)).convert("RGBA")

    if mode == "sheet":
        src, out = args[0], args[1]
        all_stats = [json.load(open(os.path.join(src, str(n), "stats.json"))) for n in range(1, 10)]
        style = all_stats[0].get("style", "voxel")
        CW, CH, HEAD, PAD = 1180, 1010, 190, 30
        sheet = Image.new("RGB", (PAD + 3 * (CW + PAD), HEAD + 3 * (CH + PAD)), CREAM)
        d = ImageDraw.Draw(sheet)
        d.text((50, 26), "RIDE A FISH", font=font(40), fill=INK)
        if style == "toy":
            d.text((50, 74), "THE NINE SUBMARINES (toy style, A)", font=font(72), fill=INK)
            d.text((1900, 60), "one a tier, in the picked Chunky toy style; the seat and the tower are the same", font=font(30), fill=SOFT)
            d.text((1900, 100), "on every one, so the ride doesn't change with the look. Not seen in Studio yet.", font=font(30), fill=SOFT)
        else:
            d.text((50, 74), "THE NINE SUBMARINES (voxel style)", font=font(72), fill=INK)
            d.text((1900, 60), "one a tier; the seat, the tower and the deck are the same on every one,", font=font(30), fill=SOFT)
            d.text((1900, 100), "so the ride doesn't change with the look. Studs are in the render only.", font=font(30), fill=SOFT)
        for n, stats in enumerate(all_stats, 1):
            folder = os.path.join(src, str(n))
            x = PAD + ((n - 1) % 3) * (CW + PAD)
            y = HEAD + ((n - 1) // 3) * (CH + PAD)
            d.rounded_rectangle((x, y, x + CW, y + CH), 26, fill=WELL)
            d.rounded_rectangle((x + 24, y + 22, x + 110, y + 108), 16, fill=INK)
            d.text((x + 67, y + 65), str(n), font=font(60), fill=CREAM, anchor="mm")
            d.text((x + 134, y + 22), stats["name"].upper(), font=font(50), fill=INK)
            d.text((x + 136, y + 82), "%d triangles  /  %d parts  /  %d studs long, %d across" % (
                stats["triangles"], stats["parts"], stats["length"], stats["width"]), font=font(24), fill=SOFT)
            lay(sheet, view(folder, "hero.png"), x + 30, y + 130, CW - 60, 520)
            d.text((x + 40, y + 664), "SIDE", font=font(22), fill=SOFT)
            lay(sheet, view(folder, "side.png"), x + 30, y + 690, CW // 2 - 40, 290)
            d.text((x + CW // 2 + 20, y + 664), "RIDING SIDE", font=font(22), fill=SOFT)
            lay(sheet, view(folder, "back.png"), x + CW // 2 + 10, y + 690, CW // 2 - 40, 290)
    else:  # compare: the approved style A model beside one tier, both at one scale (render A with the tier's --frame)
        ref, src, out = args[0], args[1], args[2]
        stats = json.load(open(os.path.join(src, "stats.json")))
        CW, HEAD, PAD, HERO, SIDE = 1500, 190, 30, 900, 430
        CH = 150 + HERO + 50 + SIDE + 30
        sheet = Image.new("RGB", (PAD + 2 * (CW + PAD), HEAD + CH + PAD), CREAM)
        d = ImageDraw.Draw(sheet)
        d.text((50, 26), "RIDE A FISH", font=font(40), fill=INK)
        d.text((50, 74), "TIER %d, %s, BESIDE THE APPROVED STYLE A" % (stats["tier"], stats["name"].upper()), font=font(72), fill=INK)
        heads = (("A", "APPROVED: CHUNKY TOY", "the model on the options sheet (tier 1), tools/blender/sub_kit.py A"),
                 (str(stats["tier"]), stats["name"].upper() + ", BUILT FOR THE GAME", "%d triangles  /  %d parts  /  %d studs long, %d across; same scale as the left" % (
                     stats["triangles"], stats["parts"], stats["length"], stats["width"])))
        k_hero = k_side = None
        for col in (1, 0):  # the tier first: it sets the scale for both
            x, y = PAD + col * (CW + PAD), HEAD
            folder = src if col else ref
            d.rounded_rectangle((x, y, x + CW, y + CH), 26, fill=WELL)
            d.rounded_rectangle((x + 24, y + 22, x + 110, y + 108), 16, fill=INK)
            d.text((x + 67, y + 65), heads[col][0], font=font(60), fill=CREAM, anchor="mm")
            d.text((x + 134, y + 22), heads[col][1], font=font(50), fill=INK)
            d.text((x + 136, y + 82), heads[col][2], font=font(24), fill=SOFT)
            k_hero = lay(sheet, view(folder, "hero.png"), x + 30, y + 150, CW - 60, HERO, k_hero)
            d.text((x + 40, y + 150 + HERO + 14), "SIDE", font=font(22), fill=SOFT)
            k_side = lay(sheet, view(folder, "side.png"), x + 30, y + 150 + HERO + 50, CW - 60, SIDE, k_side)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out)
    print("sheet:", out, sheet.size)


if len(sys.argv) > 2 and sys.argv[1] in ("sheet", "compare"):
    sheets(sys.argv[1], sys.argv[2:])
    sys.exit(0)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
TIER, OUT = int(argv[0]), argv[1]
STYLE = argv[argv.index("--style") + 1].lower() if "--style" in argv else "toy"
assert STYLE in ("toy", "voxel"), "--style is toy or voxel"
EXPORT = argv[argv.index("--export") + 1] if "--export" in argv else None
CHECK, FORCE = "--check" in argv, "--force" in argv
PX = float(argv[argv.index("--px") + 1]) if "--px" in argv else 1.0
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
if STYLE == "toy" and TIER == 1:
    PALETTE["trim+"] = (61, 81, 115)  # the approved model's own lighter navy


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



# ------------------------------------------------------------------------------------------------ shared by both styles
def aabb(box):
    return [(box["c"][i] - box["size"][i] / 2, box["c"][i] + box["size"][i] / 2) for i in range(3)]


def group(box):
    return "Prop" if box["part"] == "Prop" else "Body"

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

# ------------------------------------------------------------------------------------------------ the toy style (A)
# Every piece is one closed shape of one colour. The first nine lines of each builder are the approved model's own
# numbers (tools/blender/sub_kit.py, style_a); what a tier adds are toy parts in the same hand.
PIECES = []  # {"part", "bm", "colour", "smooth"}
BODY = {}  # the body's stations, sides and corner power, for the pieces that follow its skin
AXIS = {"x": (0, 90, 0), "y": (90, 0, 0), "z": (0, 0, 0)}
SIDES = (-1, 1)


def piece(p, colour, smooth):
    bm = bmesh.new()
    PIECES.append({"part": part_of(p, colour), "bm": bm, "colour": colour, "smooth": smooth})
    return bm


def shut(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def slab(p, c, size, colour, r=(0, 0, 0)):
    """a box centred on c, turned by r (degrees about X, Y, Z)"""
    bm = piece(p, colour, False)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(c) @ rot(r) @ Matrix.Diagonal((*size, 1.0)))
    shut(bm)


def cyl(p, c, radius, depth, colour, axis="x", n=12, r2=None, smooth=True):
    """a cylinder centred on c along an axis; r2 makes it a cone (for x: the radius at the tail end; z: at the top)"""
    bm = piece(p, colour, smooth)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=n, radius1=radius,
                          radius2=radius if r2 is None else r2, depth=depth, matrix=Matrix.Translation(c) @ rot(AXIS[axis]))
    shut(bm)


def rod(p, a, z, radius, colour, r2=None, n=8, smooth=True):
    """a cylinder from a to z; r2 is the radius at z (a blunt cone: toy spikes have no points)"""
    a, z = Vector(a), Vector(z)
    d = z - a
    turn = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4() if d.normalized().z > -0.999 else rot((180, 0, 0))
    bm = piece(p, colour, smooth)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=n, radius1=radius,
                          radius2=radius if r2 is None else r2, depth=d.length, matrix=Matrix.Translation((a + z) / 2) @ turn)
    shut(bm)


def ball(p, c, radius, colour, u=10, v=6, scale=(1, 1, 1)):
    bm = piece(p, colour, True)
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius,
                              matrix=Matrix.Translation(c) @ Matrix.Diagonal((*scale, 1.0)) @ rot((0, 90, 0)))
    shut(bm)


def loft(p, stations, n, colour, phase=0.0, power=1.0, m=None, smooth=True):
    """a body along X: at each station (x, half width, half height, middle z[, middle y]) a ring of n points; power
    under 1 squares the ring's corners. Closed at both ends. m moves it (a wing is a loft along its span)."""
    bm = piece(p, colour, smooth)
    rings = []
    for st in stations:
        x, hw, hh, zc = st[:4]
        yc = st[4] if len(st) > 4 else 0.0
        ring = []
        for i in range(n):
            a = phase + 2 * math.pi * i / n
            ca, sa = math.cos(a), math.sin(a)
            v = Vector((x, yc + hw * math.copysign(abs(ca) ** power, ca), zc + hh * math.copysign(abs(sa) ** power, sa)))
            ring.append(bm.verts.new(m @ v if m else v))
        rings.append(ring)
    for a, z in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], z[i], z[j], a[j]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    shut(bm)


def plate(p, pts, thick, colour, plane="xz", at=0.0, r=(0, 0, 0), c=(0, 0, 0), both=False):
    """a flat convex polygon with thickness: pts in the plane ("xz": a fin standing up, at y = at; "xy": a wing lying
    flat, at z = at), then turned by r about c. both: its mirror across the middle too."""
    for s in SIDES if both else (1,):
        bm = piece(p, colour, False)
        h = thick / 2
        m = Matrix.Translation((c[0], s * c[1], c[2])) @ rot((s * r[0], r[1], s * r[2])) @ Matrix.Translation((-c[0], -s * c[1], -c[2]))
        lo, hi = [], []
        for q, w in pts:
            for row, o in ((lo, -h), (hi, h)):
                row.append(bm.verts.new(m @ Vector((q, s * at + o, w) if plane == "xz" else (q, s * w, at + o))))
        bm.faces.new(lo)
        bm.faces.new(list(reversed(hi)))
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            bm.faces.new((lo[i], hi[i], hi[j], lo[j]))
        shut(bm)


# ---- the body and what follows its skin
def body(stations, colour="hull", n=12, power=1.0):
    BODY.update(st=stations, n=n, power=power)
    loft("Hull", stations, n, colour, phase=math.pi / n, power=power)


def at(x):
    """the body's (half width, half height, middle z) at x"""
    st = BODY["st"]
    x = min(max(x, st[0][0]), st[-1][0])
    for a, z in zip(st, st[1:]):
        if a[0] <= x <= z[0]:
            k = (x - a[0]) / (z[0] - a[0])
            return tuple(a[i] + (z[i] - a[i]) * k for i in (1, 2, 3))
    return st[-1][1:4]


def section(x, grow=0.0):
    """the body's ring at x, as (y, z) points"""
    hw, hh, zc = at(x)
    n, power = BODY["n"], BODY["power"]
    out = []
    for i in range(n):
        a = math.pi / n + 2 * math.pi * i / n
        ca, sa = math.cos(a), math.sin(a)
        out.append(((hw + grow) * math.copysign(abs(ca) ** power, ca), zc + (hh + grow) * math.copysign(abs(sa) ** power, sa)))
    return out


def skin(x, z):
    """how far out the body's side is at x and height z"""
    ring, best = section(x), 0.0
    for (y0, z0), (y1, z1) in zip(ring, ring[1:] + ring[:1]):
        if (z0 - z) * (z1 - z) <= 0 and z0 != z1:
            best = max(best, y0 + (y1 - y0) * (z - z0) / (z1 - z0))
    return best


def top(x):
    return max(z for _, z in section(x))


def under(x):
    return min(z for _, z in section(x))


def band(x0, x1, colour="trim", proud=0.25):
    """a belt round the body from x0 to x1, proud of it; past the body's end it closes over the tip (a nose cap)"""
    st = BODY["st"]
    xs = [x0] + [s[0] for s in st if x0 < s[0] < x1] + [x1]
    rows = [(x, at(x)[0] + proud, at(x)[1] + proud, at(x)[2]) for x in xs]
    if x0 <= st[0][0]:
        rows[0] = (st[0][0] - proud, st[0][1] + proud * 0.4, st[0][2] + proud * 0.4, st[0][3])
    if x1 >= st[-1][0]:
        rows[-1] = (st[-1][0] + proud, st[-1][1] + proud * 0.4, st[-1][2] + proud * 0.4, st[-1][3])
    loft("Hull", rows, BODY["n"], colour, phase=math.pi / BODY["n"], power=BODY["power"])


def stripe(x0, x1, k, colour, thick=0.4, share=0.72):
    """a sticker along each flank on one of the body's flat sides (k 0: the side, -1: the one under it, 1: over it),
    where the body runs straight"""
    ring = section((x0 + x1) / 2)
    n = BODY["n"]
    (y0, z0), (y1, z1) = ring[(k - 1) % n], ring[k % n]
    length = math.hypot(y1 - y0, z1 - z0)
    ny, nz = (z1 - z0) / length, -(y1 - y0) / length
    out = thick / 2 - 0.14
    for s in SIDES:
        slab("Hull", ((x0 + x1) / 2, s * ((y0 + y1) / 2 + ny * out), (z0 + z1) / 2 + nz * out), (x1 - x0, thick, length * share), colour,
             r=(s * math.degrees(math.atan2(-(y1 - y0), z1 - z0)), 0, 0))


def line(x0, x1, z, colour="glow", r=0.3):
    """a line of light along each flank at height z, bent with the body"""
    xs = [x0] + [s[0] for s in BODY["st"] if x0 < s[0] < x1] + [x1]
    for a, q in zip(xs, xs[1:]):
        for s in SIDES:
            rod("Hull", (a, s * (skin(a, z) + 0.05), z), (q, s * (skin(q, z) + 0.05), z), r, colour, n=6)


# ---- the approved model's pieces (sub_kit's style_a), named by what they are
A_BODY = [(-18.0, 1.2, 1.2, -0.6), (-17.0, 3.2, 3.0, -0.3), (-14.5, 4.9, 4.7, 0), (-9, 5.6, 5.3, 0), (4, 5.6, 5.3, 0),
          (10, 4.9, 4.7, 0.2), (14, 3.3, 3.2, 0.5), (16.2, 1.6, 1.6, 0.7)]


def cabin(cap="trim", hatch="trim+"):
    """the tower: a fat rounded block with a cap, a hatch and a bubble window in a thick rim; the same on every tier"""
    loft("Hull", [(-7.0, 2.2, 2.0, 5.6), (-6.2, 3.0, 3.4, 6.4), (1.6, 3.0, 3.4, 6.4), (2.6, 2.4, 2.6, 6.0)], 8, "hull",
         phase=math.pi / 8, power=0.75)
    cyl("Hull", (-2, 0, 10.0), 3.5, 0.9, cap, axis="z", n=10)
    if hatch:
        cyl("Hull", (-2, 0, 10.8), 2.2, 0.8, hatch, axis="z", n=10)
    ball("Hull", (-6.6, 0, 7.2), 2.0, "glass", u=10, v=6, scale=(0.55, 1, 1))
    cyl("Hull", (-6.6, 0, 7.2), 2.5, 0.7, "trim", axis="x", n=10)  # (a tenth forward of the approved model's: its top lay in the tower's)


def saddle():
    """the seat behind the tower (its top at 5.7), a back rest and a bar for the hands; the same on every tier"""
    slab("Seat", (5, 0, 5.2), (3.6, 3.6, 1.0), "seat")
    slab("Seat", (7.0, 0, 6.1), (0.8, 3.6, 2.2), "seat", r=(0, 12, 0))
    for s in SIDES:
        cyl("Seat", (2.6, s * 1.9, 5.9), 0.35, 2.2, "trim", axis="z", n=6, smooth=False)
    cyl("Seat", (2.6, 0, 6.9), 0.4, 4.6, "trim", axis="y", n=6, smooth=False)


def portholes(xs, z=0.6, y=None, r=1.9):
    """glass in a thick rim on each flank"""
    for x in xs:
        out = y if y is not None else skin(x, z) - 0.06
        for s in SIDES:
            cyl("Hull", (x, s * out, z), r, 0.9, "trim", axis="y", n=10)
            cyl("Hull", (x, s * (out + 0.35), z), r - 0.6, 0.5, "glass", axis="y", n=10)


def stubs(x=-7.0, hw=5.6, z=-1.2, size=(4.2, 4.6, 1.3), tip="accent", colour="trim"):
    """stubby wings, fat as a bar of soap, with a coloured end"""
    for s in SIDES:
        slab("Hull", (x, s * (hw + 1.8), z), size, colour, r=(s * -8, 0, s * -10))
        slab("Hull", (x - 0.2, s * (hw + 1.7 + size[1] / 2), z - 0.3), (size[0] - 1.0, 1.0, size[2] + 0.4), tip, r=(s * -8, 0, s * -10))


def tail(tx=16.6, az=0.7, ring=4.3, cross=(11.5, 12.5), blades="white", hub="trim+", glow=False, tips=None):
    """four fat paddles, the guard ring and the three-bar propeller in it. The propeller's pieces are all even about
    the hub, so its box is centred on it and it spins true. The dark disc stands 0.15 proud of the ring (the approved
    model's 0.05 would flicker) and the blades a tenth clear of it."""
    if cross:
        slab("Hull", (tx - 3.2, 0, az - 0.2), (3.6, 1.1, cross[0]), "trim")
        slab("Hull", (tx - 3.2, 0, az - 0.2), (3.6, cross[1], 1.1), "trim")
        if tips:
            for s in SIDES:
                slab("Hull", (tx - 3.2, 0, az - 0.2 + s * (cross[0] / 2 - 0.3)), (2.8, 1.5, 1.2), tips)
                slab("Hull", (tx - 3.2, s * (cross[1] / 2 - 0.3), az - 0.2), (2.8, 1.2, 1.5), tips)
    k = ring / 4.3
    cyl("Hull", (tx, 0, az), ring, 1.6, "accent", axis="x", n=12, smooth=False)
    cyl("Hull", (tx, 0, az), ring - 0.6, 1.9, "trim", axis="x", n=12, smooth=False)
    cyl("Prop", (tx + 0.9, 0, az), 1.2 * k, 1.8, hub, axis="x", n=8, r2=0.6 * k, smooth=False)
    for a in (0, 60, 120):
        slab("Prop", (tx + 1.3, 0, az), (0.5, 1.7 * k, 6.6 * k), blades, r=(a, 0, 0))
    if glow:
        ball("Prop", (tx + 1.95, 0, az), 0.8 * k, "glow", u=8, v=4)


def headlamp(x=-16.6, z=-2.6, r=1.7, y=0.0):
    ball("Light", (x, y, z), r, "lamp", u=8, v=6)
    cyl("Hull", (x + 0.6, y, z), r + 0.4, 1.4, "trim", axis="x", n=10)


def windup(x=11.2, z=None):
    """the wind-up key on the back: the toy's joke, on every tier"""
    z = 5.4 if z is None else z
    cyl("Hull", (x, 0, z), 0.4, 2.6, "accent", axis="z", n=6, smooth=False)
    slab("Hull", (x, 0, z + 2.0), (2.6, 0.6, 1.6), "accent")


def capsule(c, radius, length, colour, n=10):
    """a pill along X"""
    cyl("Hull", c, radius, length, colour, axis="x", n=n)
    for e in SIDES:
        ball("Hull", (c[0] + e * length / 2, c[1], c[2]), radius, colour, u=n, v=6)


def cone(a, z, radius, colour, n=6):
    """a blunt toy spike from a to z"""
    rod("Hull", a, z, radius, colour, r2=radius * 0.25, n=n)


def mirror(pt, s):
    return (pt[0], s * pt[1], pt[2])


# ---- the nine
def toy1():  # the Bathtub: the approved model
    body(A_BODY)
    loft("Hull", [(-9.2, 5.85, 5.55, 0), (-7.6, 5.85, 5.55, 0)], 12, "trim", phase=math.pi / 12)
    loft("Hull", [(4.4, 5.85, 5.55, 0), (6.0, 5.85, 5.55, 0)], 12, "trim", phase=math.pi / 12)
    cabin()
    saddle()
    portholes((-11.5, 0.5), y=5.35)
    stubs()
    tail()
    headlamp()
    windup()


def toy2():  # the Reef Runner: the tub with a bumper bar, a white band, a snorkel and back wings
    body(A_BODY)
    band(-9.2, -7.6)
    band(4.4, 6.0)
    stripe(-7.2, 4.0, -1, "accent")
    cyl("Hull", (-18.9, 0, -0.6), 0.85, 9.4, "trim", axis="y", n=8)  # the bumper: a bar on two stalks, a white knob each end
    for s in SIDES:
        ball("Hull", (-18.9, s * 4.7, -0.6), 1.25, "accent", u=8, v=6)
        cyl("Hull", (-17.7, s * 2.0, -0.6), 0.55, 2.6, "trim", axis="x", n=6, smooth=False)
    cabin()
    saddle()
    portholes((-11.5, 0.5), y=5.35)
    stubs()
    stubs(x=8.6, hw=4.6, z=0.3, size=(2.8, 3.6, 1.1))
    tail()
    headlamp()
    windup()
    cyl("Hull", (-0.6, 2.0, 12.2), 0.5, 3.6, "trim", axis="z", n=6, smooth=False)  # the snorkel: up, an elbow, a white mouth
    ball("Hull", (-0.6, 2.0, 14.0), 0.75, "trim", u=6, v=4)
    cyl("Hull", (-1.8, 2.0, 14.0), 0.5, 2.4, "trim", axis="x", n=6, smooth=False)
    cyl("Hull", (-3.2, 2.0, 14.0), 0.85, 0.8, "accent", axis="x", n=8)


def toy3():  # the Kelp Cruiser: longer, three ports, leaf wings, a V of leaf fins for a tail, kelp on the cap
    body([(-19.5, 1.2, 1.2, -0.6), (-18.5, 3.2, 3.0, -0.3), (-16, 4.9, 4.7, 0), (-10.5, 5.6, 5.3, 0), (5, 5.6, 5.3, 0),
          (11.5, 4.9, 4.7, 0.2), (15.5, 3.3, 3.2, 0.5), (17.7, 1.6, 1.6, 0.7)])
    band(-10.6, -9.0)
    band(5.2, 6.8)
    band(9.2, 10.6, "accent")  # a yellow tail flash
    cabin()
    saddle()
    portholes((-13.3, -5.6, 1.6))
    leaf = [(-11.0, 4.6), (-9.6, 9.0), (-6.5, 11.4), (-3.6, 9.6), (-3.0, 4.6)]
    plate("Hull", leaf, 1.3, "trim", plane="xy", at=-1.2, r=(-8, 0, 0), c=(-7, 4.6, -1.2), both=True)
    plate("Hull", [(-7.5, 4.6), (-7.1, 10.8), (-6.0, 10.8), (-6.2, 4.6)], 1.7, "accent", plane="xy", at=-1.2, r=(-8, 0, 0),
          c=(-7, 4.6, -1.2), both=True)  # the leaf's rib
    fin = [(13.0, 2.0), (14.0, 7.0), (16.0, 10.6), (17.6, 10.0), (17.4, 5.8), (16.2, 2.0)]
    for s in SIDES:
        plate("Hull", fin, 1.2, "trim", plane="xz", r=(s * -30, 0, 0), c=(15, 0, 2.0))
        plate("Hull", [(14.5, 2.0), (16.1, 9.6), (17.0, 9.4), (15.8, 2.0)], 1.6, "accent", plane="xz", r=(s * -30, 0, 0), c=(15, 0, 2.0))
    slab("Hull", (14.9, 0, -2.3), (3.4, 1.1, 4.8), "trim")  # a keel fin
    tail(tx=18.1, cross=None)
    headlamp(x=-18.1)
    windup(x=12.4, z=5.0)
    plate("Hull", [(-3.2, 11.0), (-3.9, 13.2), (-2.6, 15.0), (-1.3, 13.4), (-1.6, 11.0)], 0.8, "trim+", plane="xz", r=(0, 0, 25),
          c=(-2.5, 0, 11))
    plate("Hull", [(-1.8, 11.0), (-2.0, 12.4), (-0.9, 13.6), (-0.1, 12.4), (-0.6, 11.0)], 0.8, "trim+", plane="xz", r=(0, 0, -30),
          c=(-1.0, 0, 11))


def toy4():  # the Wreck Diver: a boxy salvage boat: ballast tanks, a periscope, a crane and hook, patches, twin lamps
    body([(-16.0, 3.6, 3.4, -0.2), (-15.2, 4.9, 4.7, -0.1), (-12, 5.5, 5.3, 0), (6, 5.5, 5.3, 0), (10, 4.9, 4.7, 0.2),
          (14, 3.3, 3.2, 0.5), (16.2, 1.6, 1.6, 0.7)], power=0.6)
    band(-11.4, -9.8)
    band(4.4, 6.0)
    loft("Hull", [(-17.3, 3.2, 1.3, -1.6), (-16.7, 4.5, 1.9, -1.6), (-15.3, 5.3, 2.1, -1.6)], 8, "trim", phase=math.pi / 8,
         power=0.6)  # the bow's bumper
    for s in SIDES:  # ballast tanks along the lower sides, strapped on
        capsule((-2.5, s * 6.3, -2.9), 1.7, 12.0, "hull-")
        for x in (-6.5, 1.5):
            cyl("Hull", (x, s * 6.3, -2.9), 2.0, 1.0, "trim", axis="x", n=10)
    cabin()
    saddle()
    portholes((-7.4, 0.6), z=1.5, r=1.7)
    for x, z, s in ((8.2, 1.4, -1), (-13.4, 1.6, 1)):  # patches: a plate and two bolts
        cyl("Hull", (x, s * (skin(x, z) - 0.05), z), 1.5, 0.6, "hull-", axis="y", n=8, smooth=False)
        for dx, dz in ((-0.7, 0.6), (0.7, -0.6)):
            cyl("Hull", (x + dx, s * (skin(x, z) + 0.2), z + dz), 0.3, 0.5, "trim", axis="y", n=6, smooth=False)
    cyl("Hull", (-3.0, 1.7, 12.6), 0.5, 4.6, "trim", axis="z", n=6, smooth=False)  # the periscope
    cyl("Hull", (-3.7, 1.7, 14.7), 0.8, 2.6, "trim+", axis="x", n=8)
    cyl("Hull", (-5.1, 1.7, 14.7), 0.55, 0.4, "glass", axis="x", n=8)
    cyl("Hull", (-11.6, 0, 6.5), 0.7, 3.8, "trim", axis="z", n=8)  # the crane: a post, an arm, a line, a weight and a hook
    ball("Hull", (-11.6, 0, 8.5), 1.0, "trim", u=8, v=6)
    rod("Hull", (-11.6, 0, 8.5), (-18.6, 0, 10.4), 0.55, "accent", n=6, smooth=False)
    rod("Hull", (-18.4, 0, 10.4), (-18.4, 0, 7.2), 0.18, "trim", n=5, smooth=False)
    ball("Hull", (-18.4, 0, 6.9), 0.7, "accent", u=8, v=6)
    for a, z in (((-18.4, 0, 6.6), (-18.4, 0, 5.3)), ((-18.4, 0, 5.4), (-17.5, 0, 4.8)), ((-17.6, 0, 4.8), (-16.9, 0, 5.6))):
        rod("Hull", a, z, 0.24, "trim+", n=5, smooth=False)
    for s in SIDES:
        headlamp(x=-15.2, z=-4.0, r=1.3, y=s * 1.9)
    tail()
    windup()


def toy5():  # the Blue Streak: a rocket: long and low, a red nose, swept wings, pods, a tall swept fin
    body([(-24.0, 0.5, 0.5, -1.0), (-21.5, 1.9, 1.7, -0.7), (-17, 3.6, 3.2, -0.2), (-11, 4.8, 4.4, 0.5), (-6, 5.1, 4.7, 0.6),
          (5, 5.1, 4.7, 0.6), (11, 4.5, 4.2, 0.7), (16, 3.0, 2.9, 0.7), (19.0, 1.5, 1.5, 0.7)])
    band(-24.0, -20.6, "accent", proud=0.2)
    band(-8.6, -7.2)
    band(4.6, 6.0)
    stripe(-6.6, 4.0, -1, "accent", share=0.4)
    cabin()
    saddle()
    portholes((-12.4, 0.2), z=1.0, r=1.7)
    wing = [(-9.5, 4.0), (-2.0, 12.5), (1.5, 12.5), (-1.0, 4.0)]
    plate("Hull", wing, 1.2, "trim", plane="xy", at=-1.0, r=(-6, 0, 0), c=(-5, 4, -1), both=True)
    plate("Hull", [(-2.7, 11.7), (-2.0, 13.1), (1.7, 13.1), (1.4, 11.7)], 1.6, "accent", plane="xy", at=-1.0, r=(-6, 0, 0),
          c=(-5, 4, -1), both=True)
    for s in SIDES:  # a pod under each wing, a light at its nose
        capsule((-2.4, s * 8.4, -2.7), 1.3, 5.0, "hull")
        ball("Hull", (-5.6, s * 8.4, -2.7), 0.85, "glow", u=8, v=4)
        cyl("Hull", (0.9, s * 8.4, -2.7), 1.45, 1.2, "accent", axis="x", n=10)
    plate("Hull", [(12.0, 3.0), (17.0, 11.8), (19.4, 11.8), (17.6, 3.0)], 1.2, "trim")  # the tall swept fin
    plate("Hull", [(16.5, 10.6), (17.1, 12.1), (19.7, 12.1), (19.3, 10.6)], 1.6, "accent")
    plate("Hull", [(14.5, 1.5), (18.3, 7.5), (20.0, 7.5), (18.2, 1.5)], 1.1, "trim", plane="xy", at=0.7, both=True)
    plate("Hull", [(14.5, -1.0), (17.4, -5.2), (18.6, -5.2), (18.0, -1.0)], 1.1, "trim")
    tail(tx=19.4, cross=None, hub="accent")
    headlamp(x=-17.6, z=-2.5, r=1.4)
    windup(x=10.8, z=5.2)


def toy6():  # the Twilight Ray: a manta: wide rounded wings with a line of light, horns, a long tail spike
    body([(-21.0, 1.0, 0.9, -0.8), (-19.5, 2.8, 2.2, -0.5), (-15.5, 4.6, 3.8, 0.2), (-9, 5.6, 4.9, 0.4), (5, 5.6, 4.9, 0.4),
          (11, 4.8, 4.4, 0.5), (15, 3.2, 3.1, 0.7), (17.2, 1.6, 1.6, 0.7)])
    band(-9.2, -7.6)
    band(4.4, 6.0)
    band(9.4, 10.2, "glow", proud=0.2)
    cabin()
    saddle()
    portholes((-12.2, 0.4), z=1.9, r=1.6)
    # a wing is a loft along its span: (span, half its chord, half its thickness, height, the chord's middle)
    wing = [(3.5, 8.5, 1.4, -1.6, -1.0), (9, 7.4, 1.15, -1.9, 0.0), (14, 5.4, 0.85, -2.4, 1.6), (18, 3.1, 0.6, -3.0, 3.6),
            (20.5, 1.1, 0.35, -3.5, 5.2)]
    for s in SIDES:
        m = Matrix(((0, 1, 0, 0), (s, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
        loft("Hull", wing, 8, "hull", phase=math.pi / 8, m=m)
        loft("Hull", [(17.5, 3.55, 0.78, -2.93, 3.35), (18, 3.25, 0.74, -3.0, 3.6), (20.7, 1.2, 0.47, -3.53, 5.3)], 8, "trim",
             phase=math.pi / 8, m=m)
        edge = [(-8.7, 5.6, -1.72), (-7.4, 9, -1.9), (-3.8, 14, -2.4), (0.0, 17.4, -2.9)]  # the leading edge's line of light
        for a, z in zip(edge, edge[1:]):
            rod("Hull", mirror(a, s), mirror(z, s), 0.5, "glow", n=6)
        rod("Hull", (-17.0, s * 3.0, -1.2), (-22.8, s * 3.9, -2.7), 1.1, "trim", r2=0.5)  # a horn each side of the nose
    slab("Hull", (14.4, 0, 0.5), (3.6, 1.1, 11.5), "trim")
    slab("Hull", (14.4, 0, 0.5), (3.6, 9.0, 1.1), "trim")
    rod("Hull", (13.2, 0, 5.7), (28.5, 0, 7.6), 0.8, "trim", r2=0.2, n=6)  # the tail spike, from the fin's top
    tail(tx=17.6, cross=None, blades="accent", glow=True)
    headlamp(x=-18.6, z=-2.3, r=1.4)
    windup(x=10.6, z=5.4)


def toy7():  # the Midnight Hunter: a shark: a jaw with teeth, slit eyes, gills, a dorsal fin on the cap, claws
    body([(-23.0, 0.9, 0.7, 0.6), (-21.5, 2.4, 1.6, 0.5), (-17, 4.0, 2.9, 0.6), (-11, 5.3, 4.4, 0.5), (-6, 5.6, 4.9, 0.4),
          (5, 5.6, 4.9, 0.4), (11, 4.8, 4.4, 0.5), (16, 3.0, 2.9, 0.7), (19.0, 1.5, 1.5, 0.7)])
    jaw = [(-20.5, 1.4, 0.6, -3.5), (-18.5, 2.8, 0.9, -4.1), (-14.5, 3.9, 1.2, -4.7), (-10.5, 4.2, 1.5, -4.0)]
    loft("Hull", jaw, 8, "trim+", phase=math.pi / 8)
    for x in (-20.2, -18.4, -16.6, -14.8):  # teeth down from the snout
        hw, hh, zc = at(x)
        z = zc - hh * 0.78
        for s in SIDES:
            rod("Hull", (x, s * hw * 0.62, z + 0.5), (x + 0.2, s * hw * 0.62, z - 1.3), 0.55, "tooth", r2=0.15, n=6)
    for x, hw, z in ((-19.3, 2.2, -3.2), (-17.5, 3.1, -3.5), (-15.7, 3.6, -3.8)):  # and up from the jaw, between them
        for s in SIDES:
            rod("Hull", (x, s * hw * 0.62, z - 0.4), (x, s * hw * 0.62, z + 0.9), 0.5, "tooth", r2=0.15, n=6)
    for s in SIDES:  # slit eyes under a brow
        y = skin(-15.4, 1.5)
        ball("Hull", (-15.4, s * (y - 0.1), 1.5), 1.0, "glow", u=8, v=6, scale=(1.5, 0.5, 0.5))
        slab("Hull", (-15.3, s * (y - 0.1), 2.35), (3.8, 1.0, 0.7), "trim", r=(0, -14, 0))
    for x in (-9.5, -8.1, -6.7):  # gills
        band(x, x + 0.6, "trim", proud=0.2)
    band(4.4, 6.0, "trim+")
    cabin(cap="trim+", hatch=None)
    plate("Hull", [(-4.6, 10.3), (-1.2, 14.8), (0.4, 15.0), (1.0, 13.8), (0.6, 10.3)], 1.1, "hull-")  # the dorsal fin
    saddle()
    line(-4.0, 10.0, -1.4, "glow", r=0.32)
    plate("Hull", [(-9.0, 4.2), (-3.0, 11.5), (-0.8, 11.0), (-3.2, 4.2)], 1.2, "hull-", plane="xy", at=-2.2, r=(-16, 0, 0),
          c=(-6, 4.2, -2.2), both=True)
    plate("Hull", [(12.6, 2.0), (16.6, 10.8), (18.6, 11.6), (18.2, 7.6), (16.8, 2.0)], 1.2, "hull-")  # the tail's lobes
    plate("Hull", [(13.0, -0.6), (17.0, -5.4), (18.3, -5.6), (17.4, -0.6)], 1.2, "hull-")
    plate("Hull", [(14.2, 1.5), (17.6, 6.6), (18.5, 6.4), (17.6, 1.5)], 1.1, "trim+", plane="xy", at=0.7, both=True)
    for s in SIDES:  # claws under the chest
        rod("Hull", (-8.5, s * 3.2, -3.8), (-12.6, s * 4.4, -6.4), 0.7, "trim+", n=6)
        rod("Hull", (-12.6, s * 4.4, -6.4), (-15.4, s * 4.1, -5.2), 0.6, "tooth", r2=0.15, n=6)
    tail(tx=19.4, cross=None, blades="accent", glow=True)
    headlamp(x=-10.4, z=-5.2, r=1.2)
    windup(x=10.8, z=5.2)


def toy8():  # the Vent Crawler: armour hoops over glowing seams, vent stacks, pincers, belly spikes
    body([(-17.5, 2.0, 1.9, -0.4), (-16.6, 3.8, 3.5, -0.2), (-14, 5.3, 4.9, 0), (-9.5, 5.9, 5.3, 0), (5, 5.9, 5.3, 0),
          (10, 5.1, 4.7, 0.2), (14, 3.4, 3.2, 0.5), (16.2, 1.6, 1.6, 0.7)])
    band(-17.5, -14.8, "trim", proud=0.2)
    for x in (-9.0, -4.2, 0.6):
        band(x, x + 4.0, "accent", proud=0.4)
    for x in (-9.8, -5.0, -0.2, 4.6):
        band(x, x + 0.8, "glow", proud=0.15)
    band(10.9, 11.5, "glow", proud=0.15)
    cabin(hatch="accent")
    saddle()
    portholes((-12.3,), z=0.8, r=1.7)
    for s in SIDES:
        cyl("Hull", (9.4, s * 2.5, 6.2), 1.15, 5.0, "trim", axis="z", n=8)  # a vent stack, glowing at the mouth
        cyl("Hull", (9.4, s * 2.5, 8.5), 1.55, 1.0, "accent", axis="z", n=8)
        cyl("Hull", (9.4, s * 2.5, 9.0), 1.0, 0.4, "glow", axis="z", n=8)
        rod("Hull", (-12.0, s * 4.4, -2.0), (-17.5, s * 7.6, -2.6), 0.9, "accent")  # a pincer: two arms, a claw of two
        ball("Hull", (-17.5, s * 7.6, -2.6), 1.25, "trim", u=8, v=6)
        rod("Hull", (-17.5, s * 7.6, -2.6), (-21.0, s * 6.0, -2.8), 0.8, "trim")
        ball("Hull", (-21.0, s * 6.0, -2.8), 1.1, "accent", u=8, v=6)
        rod("Hull", (-21.0, s * 6.5, -2.8), (-25.2, s * 7.4, -2.6), 1.0, "hull", r2=0.3)
        rod("Hull", (-21.0, s * 5.5, -2.8), (-24.8, s * 3.9, -2.8), 0.85, "hull+", r2=0.25)
    for x in (-6, 0, 6):
        cone((x, 0, -4.7), (x + 1.4, 0, -7.9), 0.9, "trim")
    cone((12.8, 0, 3.4), (14.6, 0, 7.4), 0.85, "trim")
    tail(blades="accent", glow=True)
    headlamp()
    windup(x=11.5, z=5.3)


def toy9():  # the Abyss King: the biggest: a glowing crown, a trident ram, pods on wings, a crest, spikes
    body([(-23.5, 0.9, 0.9, -1.2), (-22, 2.6, 2.4, -0.9), (-18, 4.6, 4.3, -0.5), (-11, 6.2, 5.8, -0.5), (6, 6.2, 5.8, -0.5),
          (12, 5.4, 5.1, -0.2), (17, 3.6, 3.4, 0.4), (20, 1.7, 1.7, 0.7)])
    band(-23.5, -20.6, "trim", proud=0.2)
    band(-11.2, -9.6)
    band(-9.6, -8.9, "accent", proud=0.15)
    band(5.7, 6.4, "accent", proud=0.15)
    band(6.4, 8.0)
    cabin(hatch=None)
    cyl("Hull", (-2, 0, 10.85), 3.0, 0.8, "accent", axis="z", n=10)  # the crown: a band, six glowing points, a jewel
    for i in range(6):
        ca, sa = math.cos(math.radians(60 * i)), math.sin(math.radians(60 * i))
        rod("Hull", (-2 + 2.3 * ca, 2.3 * sa, 11.0), (-2 + 3.2 * ca, 3.2 * sa, 14.0), 0.65, "glow", r2=0.18, n=6)
    ball("Hull", (-2, 0, 11.5), 1.3, "glow", u=8, v=6)
    saddle()
    portholes((-14.6, -5.2, 1.6), z=0.6)
    line(-8.4, 5.2, -2.8, "glow", r=0.35)
    rod("Hull", (-22.6, 0, -1.1), (-27.0, 0, -1.6), 0.8, "trim+")  # the trident: a shaft, a bar, three prongs with lit ends
    rod("Hull", (-27.0, -3.0, -1.6), (-27.0, 3.0, -1.6), 0.65, "trim+")
    for y, x1 in ((0, -32.6), (-3.0, -31.2), (3.0, -31.2)):
        rod("Hull", (-27.0, y, -1.6), (x1, y * 1.08, -1.6 + (x1 + 27) * 0.11), 0.65, "trim+", r2=0.2)
        ball("Hull", (x1 - 0.1, y * 1.08, -1.6 + (x1 + 27) * 0.11), 0.5, "glow", u=6, v=4)
    wing = [(-7.0, 5.6), (-1.0, 11.2), (5.0, 11.2), (4.0, 5.6)]
    plate("Hull", wing, 1.2, "trim", plane="xy", at=-1.8, both=True)
    for s in SIDES:  # a pod at each wing's end
        capsule((2.0, s * 11.6, -1.8), 1.8, 8.0, "hull")
        ball("Hull", (-3.1, s * 11.6, -1.8), 1.15, "glow", u=8, v=4)
        cyl("Hull", (2.0, s * 11.6, -1.8), 2.05, 1.2, "accent", axis="x", n=10)
        cyl("Hull", (7.2, s * 11.6, -1.8), 1.5, 2.0, "trim", axis="x", n=10, r2=0.6)
    for x in (-7, -1, 5):
        cone((x, 0, -6.0), (x + 1.5, 0, -9.3), 0.95, "trim+")
    cone((14.0, 0, 3.9), (15.3, 0, 8.6), 1.0, "trim")  # the crest
    tail(tx=20.4, ring=5.0, cross=(13.5, 15.0), blades="accent", glow=True, tips="accent")
    headlamp(x=-20.2, z=-3.2)
    windup(x=11.4, z=5.4)


def toy_check():
    """faces of two pieces that face the same way, overlap and lie under 0.05 apart, where no third piece covers them"""
    import numpy as np
    from mathutils.bvhtree import BVHTree

    faces, trees = [], []
    for k, pc in enumerate(PIECES):
        pc["bm"].normal_update()
        trees.append(BVHTree.FromBMesh(pc["bm"]))
        for f in pc["bm"].faces:
            faces.append((k, [v.co.copy() for v in f.verts], f.normal.copy(), f.calc_center_median()))
    normals = np.array([f[2] for f in faces])
    centres = np.array([f[3] for f in faces])
    apart = np.abs(normals @ centres.T - np.sum(normals * centres, axis=1)[:, None])
    found = []
    for i, j in np.argwhere((normals @ normals.T > 0.9995) & (apart < 0.05)):
        (pi, vi, ni, _), (pj, vj, _, _) = faces[i], faces[j]
        a, z = PIECES[pi], PIECES[pj]
        if i >= j or pi == pj or (a["part"].startswith("Prop")) != (z["part"].startswith("Prop")):
            continue
        if a["colour"] == z["colour"] and not a["smooth"] and not z["smooth"]:
            continue  # one colour, one shading: nothing to see
        u = (vi[1] - vi[0]).normalized()
        w = ni.cross(u)
        flat = lambda vs: [((v - vi[0]).dot(u), (v - vi[0]).dot(w)) for v in vs]  # noqa: E731
        area = lambda p: sum(p[k][0] * p[(k + 1) % len(p)][1] - p[(k + 1) % len(p)][0] * p[k][1] for k in range(len(p))) / 2  # noqa: E731
        clip, poly = flat(vi), flat(vj)
        if area(clip) < 0:
            clip.reverse()
        for k in range(len(clip)):  # cut the one by each edge of the other (both are convex)
            (x0, y0), (x1, y1) = clip[k], clip[(k + 1) % len(clip)]
            side = lambda p: (x1 - x0) * (p[1] - y0) - (y1 - y0) * (p[0] - x0)  # noqa: E731
            kept = []
            for q in range(len(poly)):
                p0, p1 = poly[q], poly[(q + 1) % len(poly)]
                s0, s1 = side(p0), side(p1)
                if s0 >= 0:
                    kept.append(p0)
                if (s0 > 0 > s1) or (s0 < 0 < s1):
                    f = s0 / (s0 - s1)
                    kept.append((p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f))
            poly = kept
            if len(poly) < 3:
                break
        if len(poly) < 3 or abs(area(poly)) < 0.05:
            continue
        cx, cy = sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly)
        spot = vi[0] + u * cx + w * cy + ni * 0.06
        hidden = False
        for k, tree in enumerate(trees):
            if k in (pi, pj):
                continue
            near, normal, _, _ = tree.find_nearest(spot)
            if near is not None and (spot - near).dot(normal) < -1e-4:
                hidden = True
                break
        if not hidden:
            found.append("  ! %s (%s) and %s (%s) share a face near (%.1f, %.1f, %.1f)" % (
                a["part"], a["colour"], z["part"], z["colour"], spot.x, spot.y, spot.z))
    return found


dropped = 0
if STYLE == "voxel":
    [tier1, tier2, tier3, tier4, tier5, tier6, tier7, tier8, tier9][TIER - 1]()
    # ------------------------------------------------------------------------------------------------ the check
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
else:
    [toy1, toy2, toy3, toy4, toy5, toy6, toy7, toy8, toy9][TIER - 1]()
    faults = toy_check()
    for line_ in faults:
        print(line_)
    print("sub stages: tier %d %s (toy): %d pieces, %d faults" % (TIER, NAME, len(PIECES), len(faults)))
    if CHECK or (faults and not FORCE):
        sys.exit(1 if faults else 0)
    PARTS = {}
    for pc in PIECES:  # the pieces of a part into one mesh, each keeping its own points (so its own shading)
        bm = PARTS.setdefault(pc["part"], bmesh.new())
        index = mat(pc["colour"])
        twin = {v: bm.verts.new(v.co) for v in pc["bm"].verts}
        for f in pc["bm"].faces:
            g = bm.faces.new([twin[v] for v in f.verts])
            g.material_index, g.smooth = index, pc["smooth"]
    col = bpy.data.collections.new("Sub")
    scene.collection.children.link(col)
    tris, objects, xs, ys = 0, {}, [], []
    for name, bm in PARTS.items():
        bm.normal_update()
        for e in bm.edges:  # smooth pieces keep their hard corners
            e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(0.0) < math.radians(50)
        xs += [v.co.x for v in bm.verts]
        ys += [abs(v.co.y) for v in bm.verts]
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
    FRAME = max(1.0, (max(xs) - min(xs)) / 38, (2 * max(ys) + 10) / 36)  # how far the cameras stand back
print("sub stages: tier %d %s (%s): %d parts, %d triangles (%d hidden faces left out), about %.0f long, %.0f across" % (
    TIER, NAME, STYLE, len(objects), tris, dropped, max(xs) - min(xs), 2 * max(ys)))
with open(os.path.join(OUT, "stats.json"), "w") as fh:
    json.dump({"tier": TIER, "id": ID, "name": NAME, "style": STYLE, "parts": len(objects), "triangles": tris,
               "length": round(max(xs) - min(xs), 1), "width": round(2 * max(ys), 1), "frame": round(FRAME, 3)}, fh)

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
    json.dump({"id": ID, "name": NAME, "tier": TIER, "style": STYLE, "units": "studs", "triangles": tris,
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
    scene.render.resolution_percentage = int(100 * PX)
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
