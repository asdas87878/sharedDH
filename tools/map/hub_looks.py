"""The hub's colour looks side by side (tools/map/greybox.py, HUB_LOOKS): builds the map once per look into
art/map/hub_looks/<Look>, renders two views of the hub for each in Blender, and lays them out as
docs/attachments/map-hub-looks.jpg. Not Roblox: Blender's plain daylight, so it shows how the colours sit together,
not how the game's light pushes them.
usage: python tools/map/hub_looks.py [Look,Look] [sheet name]     (default: the first five, map-hub-looks.jpg)"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
LOOKS = ["Beach", "Lagoon", "Coral", "Pool", "Boardwalk"]
WORDS = {"Beach": "Beach (what is built): sand floor and tops, grey walls", "Lagoon": "Lagoon: sand floor, cream walls, green tops, navy frames",
         "Coral": "Coral: peach floor, coral walls, seafoam tops, teal frames", "Pool": "Pool: aqua floor, white walls, turquoise tops, a yellow strip",
         "Boardwalk": "Boardwalk: wood floor, slate-blue walls, pale tops, a red strip",
         "CoralSand": "Coral sand: a warm pink-sand floor, coral walls, seafoam tops, a teal strip and frames",
         "CoralBlush": "Coral blush: a blush floor close to the walls' colour, seafoam tops, a cream strip",
         "CoralClay": "Coral clay: a brown clay floor, coral walls, seafoam tops, dark wood frames",
         "Terracotta": "Terracotta: browner walls, a pale terracotta floor, seafoam tops, a teal strip",
         "Driftwood": "Driftwood: a driftwood-brown floor, dusty coral walls, deeper seafoam tops, dark frames"}
looks = sys.argv[1].split(",") if len(sys.argv) > 1 else LOOKS
sheet_name = sys.argv[2] if len(sys.argv) > 2 else "map-hub-looks.jpg"
title = sys.argv[3] if len(sys.argv) > 3 else "The hub's colours: five looks."
for look in looks:
    out = os.path.join(ROOT, "art", "map", "hub_looks", look)
    os.makedirs(out, exist_ok=True)
    env = dict(os.environ, HUB_LOOK=look, GREYBOX_OUT=out)
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "map", "greybox.py")], env=env, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([BLENDER, "--background", "--python", os.path.join(ROOT, "tools", "blender", "map_greybox_view.py"), "--", "hub_look,hub_above"],
                   env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("rendered", look, flush=True)

from PIL import Image, ImageDraw, ImageFont  # noqa: E402

font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 30)
w, h = 760, 428
sheet = Image.new("RGB", (w * 2 + 30, 70 + len(looks) * (h + 44)), (255, 248, 240))
d = ImageDraw.Draw(sheet)
d.text((12, 14), title + " Blender's plain daylight, not the game's light; the layout is the same in each.", font=big, fill=(30, 30, 30))
y = 66
for look in looks:
    folder = os.path.join(ROOT, "art", "map", "hub_looks", look, "renders")
    if not os.path.exists(os.path.join(folder, "hub_look.png")):
        continue
    d.text((12, y), WORDS[look], font=font, fill=(30, 30, 30))
    for k, name in enumerate(("hub_look", "hub_above")):
        im = Image.open(os.path.join(folder, name + ".png")).convert("RGB").resize((w, h), Image.LANCZOS)
        sheet.paste(im, (10 + k * (w + 10), y + 30))
    y += h + 44
sheet.save(os.path.join(ROOT, "docs", "attachments", sheet_name), quality=88)
print("sheet written")
