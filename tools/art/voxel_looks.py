"""Render creatures under texture looks and variants (docs/style/06-textures.md): each job is a creature, a name and a look
(TEXTURES, VARIANT, KEEP, RAINBOW) laid over its model with the kit's --look. Renders go to work/voxel/tex/<Creature>_<look>/.
usage: python tools/art/voxel_looks.py [part of a name ...]   (no names: every job)"""
import json
import os
import subprocess
import sys

from voxel_paths import BLENDER as B, ROOT as R, WORK as S
ST = 1.0
ACCENT = ["black", "tooth", "mouth", "gum"]


def t(tile, on, colours=None, **more):
    rule = {"tile": tile, "on": on, "strength": ST}
    if colours:
        rule["colours"] = colours
    rule.update(more)
    return rule


JOBS = [
    # where the studs go (the Reef Shark)
    ("ReefShark", "top", {"TEXTURES": [t("stud", "top", ["grey"])]}),
    ("ReefShark", "topsides", {"TEXTURES": [t("stud", "top+sides", ["grey"])]}),
    ("ReefShark", "select", {"TEXTURES": [t("stud", "top+sides", ["grey"], x=[-8, 5])]}),
    ("ReefShark", "all", {"TEXTURES": [t("stud", "all", ["grey", "white"], turned=True)]}),
    # round or square, small or big
    ("ReefShark", "square", {"TEXTURES": [t("stud_square", "top", ["grey"])]}),
    ("ReefShark", "round_big", {"TEXTURES": [t("stud", "top", ["grey"], size=2)]}),
    ("ReefShark", "square_big", {"TEXTURES": [t("stud_square", "top", ["grey"], size=2)]}),
    # three directions on three creatures: 1 studs only, 2 a tile for each material, 3 studs with one material tile
    ("ReefShark", "d2", {"TEXTURES": [t("scale", "sides", ["grey"]), t("pleat", "all", ["white"])]}),
    ("ReefShark", "d3", {"TEXTURES": [t("stud", "top", ["grey"]), t("pleat", "all", ["white"])]}),
    ("Archelon", "d1", {"TEXTURES": [t("stud_square", "top", ["shell"])]}),
    ("Archelon", "d2", {"TEXTURES": [t("scute", "top+sides", ["shell"], size=3), t("scale", "top", ["skin"]), t("pleat", "all", ["belly"])]}),
    ("Archelon", "d3", {"TEXTURES": [t("stud_square", "top", ["shell"]), t("scute", "sides", ["shell"], size=3)]}),
    ("Dunkleosteus", "d1", {"TEXTURES": [t("stud", "top", ["body"]), t("stud_square", "top", ["bone"])]}),
    ("Dunkleosteus", "d2", {"TEXTURES": [t("plate", "all", ["bone"], size=2), t("scale", "sides", ["body"])]}),
    ("Dunkleosteus", "d3", {"TEXTURES": [t("stud", "top", ["body"]), t("rivet", "all", ["bone"], size=2)]}),
    # gold and rainbow
    ("ReefShark", "gold", {"VARIANT": "gold", "KEEP": ACCENT}),
    ("ReefShark", "rainbow", {"VARIANT": "rainbow", "KEEP": ACCENT, "TEXTURES": [t("stud", "top")]}),
    ("Archelon", "gold", {"VARIANT": "gold", "KEEP": ACCENT + ["rim"]}),
    ("Archelon", "rainbow", {"VARIANT": "rainbow", "KEEP": ACCENT + ["rim", "bone", "gold", "horn"], "TEXTURES": [t("stud_square", "top", ["shell"])]}),
    ("Mosasaurus", "gold", {"VARIANT": "gold", "KEEP": ACCENT}),
    ("Mosasaurus", "rainbow", {"VARIANT": "rainbow", "KEEP": ACCENT, "TEXTURES": [t("stud", "top", ["hide"])]}),
    # a spread: one fitting look each
    ("Mosasaurus", "fit", {"TEXTURES": [t("stud", "top", ["hide"]), t("scale", "sides", ["belly"])]}),
    ("Basilosaurus", "fit", {"TEXTURES": [t("stud_square", "top", ["hide"]), t("wave", "sides", ["flank"])]}),
    ("SergeantMajor", "fit", {"TEXTURES": [t("scale", "sides", ["yellow", "pale", "black"])]}),
    ("Anglerfish", "fit", {"TEXTURES": [t("pore", "top+sides", ["skin"], size=2), t("pleat", "all", ["belly"])]}),
    ("MantaRay", "fit", {"TEXTURES": [t("spots", "top", ["back"], size=3, turned=True)]}),
    ("Hellmaw", "fit", {"TEXTURES": [t("crackle", "all", ["char"], size=3)]}),
    ("Anomalocaris", "fit", {"TEXTURES": [t("plate", "top", ["shell"], size=2), t("pleat", "top", ["fin"], turned=True)]}),
    ("BobbitWorm", "fit", {"TEXTURES": [t("stud", "top", ["bronze", "copper", "rose", "plum", "violet", "indigo"])]}),
    ("BlueWhale", "fit", {"TEXTURES": [t("pleat", "all", ["throat"]), t("spots", "top", ["body"], size=3)]}),
    ("Kraken", "fit", {"TEXTURES": [t("spots", "top+sides", ["wine"], size=3)]}),
    # selective: whole parts of the body carry the studs, and only those parts
    ("ReefShark", "sel_dark", {"TEXTURES": [t("stud", "all", ["grey"], turned=True)]}),
    ("ReefShark", "sel_light", {"TEXTURES": [t("stud", "all", ["white"], turned=True)]}),
    ("Archelon", "sel_shell", {"TEXTURES": [t("stud_square", "all", ["shell"])]}),
    ("Archelon", "sel_frame", {"TEXTURES": [t("stud", "all", ["rim", "skin"], turned=True)]}),
    ("Dunkleosteus", "sel_bone", {"TEXTURES": [t("stud_square", "all", ["bone"], turned=True)]}),
    ("Dunkleosteus", "sel_body", {"TEXTURES": [t("stud", "all", ["body"], turned=True)]}),
    ("Mosasaurus", "sel_hide", {"TEXTURES": [t("stud", "all", ["hide"], turned=True)]}),
    ("Mosasaurus", "sel_belly", {"TEXTURES": [t("stud", "all", ["belly"], turned=True)]}),
    ("ReefShark", "rainbowgrain", {"VARIANT": "rainbow", "KEEP": ACCENT, "TEXTURES": [t("stud", "top")], "RAINBOW": {"grain": "noise"}}),
]

only = sys.argv[1:]
os.makedirs(S + "looks", exist_ok=True)
for creature, look, spec in JOBS:
    tag = f"{creature}_{look}"
    if only and not any(o in tag for o in only):
        continue
    out = f"{S}tex/{tag}"
    path = f"{S}looks/{tag}.json"
    json.dump(spec, open(path, "w"))
    r = subprocess.run([B, "--background", "--python", R + "tools/blender/voxel_kit.py", "--", R + f"art/creatures/{creature}/voxel.py", out, "--look", path],
                       capture_output=True, text=True)
    lines = [ln for ln in (r.stdout + r.stderr).splitlines() if any(w in ln for w in ("Error", "Traceback", "textures on", "  !"))]
    print(tag, "|", "; ".join(lines[-3:]) or "no textures line", "|", "ok" if os.path.exists(out + "/hero.png") else "NO RENDER", flush=True)
