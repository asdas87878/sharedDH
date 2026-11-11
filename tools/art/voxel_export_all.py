"""Export voxel creatures' game meshes and bring the queue note up to date (docs/design/creature-queue.md).
usage: python tools/art/voxel_export_all.py [Folder ...]   (no names: every creature)
The note's table is rebuilt from every creature that has an export; the rest of the note is left as it is."""
import glob
import io
import json
import os
import re
import subprocess
import sys

from voxel_paths import BLENDER as B, ROOT as R, WORK as S
NL = chr(10)
WORKED = {"SergeantMajor", "Clownfish", "ReefShark", "Dunkleosteus", "Hellmaw", "Mosasaurus", "BlueWhale", "Basilosaurus", "BobbitWorm",
          "MantaRay", "Kraken", "Anomalocaris", "Anglerfish", "Archelon"}
ZONES = ["SHALLOWS", "CORAL REEF", "KELP FOREST", "SHIPWRECKS", "OPEN BLUE", "TWILIGHT", "MIDNIGHT", "VENTS", "BONE GRAVEYARD", "UNDERWORLD"]
RANK = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET"]
rows, failed, only = [], [], sys.argv[1:]
for model in sorted(glob.glob(R + "art/creatures/*/voxel.py")):
    folder = os.path.basename(os.path.dirname(model))
    out = R + f"art/creatures/{folder}/game"
    log = "voxel kit: export"
    if not only or folder in only:
        r = subprocess.run([B, "--background", "--python", R + "tools/blender/voxel_kit.py", "--", model, f"{S}check_{folder}", "--export", out],
                           capture_output=True, text=True)
        log = r.stdout + r.stderr
        print("exported" if "voxel kit: export" in log else "FAILED", folder, flush=True)
    found = glob.glob(out + "/*.mesh.json")
    if "voxel kit: export" not in log or not found:
        failed.append((folder, [ln for ln in log.splitlines() if ln.startswith("  !") or "Error" in ln][:3]))
        continue
    data = json.load(open(found[0]))
    zone = data["zone"].upper()
    number = int(re.search(r"ZONE (\d+)", zone).group(1)) if re.search(r"ZONE (\d+)", zone) else 99
    rows.append((number, RANK.index(data["rarity"].upper()) if data["rarity"].upper() in RANK else 9, data["name"], data["rarity"].title(),
                 data["size"], data["triangles"], len(data["parts"]), bool(data["glow"]), folder, os.path.basename(found[0])[:-10]))
rows.sort()
lines = ["# Creature queue: models ready to go into the game",
         "Up: [Home](../../Home.md). The creatures built in the voxel style ([workout 4](../style/04-voxel-style.md), [5](../style/05-rarity-look.md),",
         "[6](../style/06-textures.md)), exported as game meshes and waiting to be imported. Written by a script from the exports",
         "(2026-11-10); run it again after a model changes.", "",
         "**Nothing here is in Roblox yet.** Importing a mesh is an upload, and uploads are permanent: they need the user's word.", "",
         "## What each creature's folder holds",
         "`art/creatures/<Folder>/game/`:",
         "- **`<Name>.glb`: the file the game imports.** One mesh object to a part (a part is one rigid piece: one MeshPart and one",
         "  Motor6D), named as in the json, its origin at the part's pivot, parented as the parts are; the colours baked in as vertex",
         "  colours; the faces of a glowing colour split off as `<Part>_Glow` (Neon is set per part). 1 unit = 1 stud.",
         "- `<Name>.obj`: the same mesh as an OBJ, one object to a part, with a palette texture (kept for looking at; the game uses the GLB).",
         "- `<Name>_palette.png` and `<Name>.mtl`: a strip of the creature's colours; every face is mapped onto its colour's cell.",
         "- `<Name>.mesh.json`: size, the rider's seat, each part's parent and pivot, the colours, which colours glow, `glowParts`,",
         "  `swimKeys` (every moving part's turn about its pivot at twelve moments of one swim cycle, as quaternions in Roblox's axes),",
         "  and the stud rule (studs are not in the mesh yet: the texture route in Roblox is untested).",
         "- Axes as Roblox has them: 1 unit = 1 stud, +Y up, the head toward -Z, right toward +X, the origin at the middle of the box.",
         "- The same layout `tools/blender/fish_kit_export.py` writes for the older kit, with parts added.",
         "- To export one again: `blender --background --python tools/blender/voxel_kit.py -- art/creatures/<Folder>/voxel.py <scratch> --export art/creatures/<Folder>/game`.", "",
         "## The queue",
         f"{len(rows)} creatures. \"Worked over\" means built and corrected with the user; \"first draft\" means built in the batches of",
         "2026-11-10 and 11 and passed by the gate, seen by the user only on a batch sheet.", "",
         "| Zone | Creature | Rarity | Length (studs) | Triangles | Parts | Glow | State | Folder |", "|---|---|---|---|---|---|---|---|---|"]
for number, _, name, rarity, size, tris, parts, glow, folder, stem in rows:
    zone = f"{number} {ZONES[number - 1].title()}" if 1 <= number <= 10 else "-"
    lines.append(f"| {zone} | {name} | {rarity} | {max(size[0], size[2]):.1f} | {tris:,} | {parts} | {'yes' if glow else ''} | "
                 f"{'worked over' if folder in WORKED else 'first draft'} | `art/creatures/{folder}/game/` |")
lines += ["", f"Totals: {sum(r[5] for r in rows):,} triangles, {sum(r[6] for r in rows)} parts.", "",
          "## To put one in the game",
          "1. The user says yes to the upload (permanent).",
          "2. Import the `.glb` (one MeshPart to a part).",
          "3. Build the Model: a Motor6D from each part to its parent at the part's pivot; set the colours' Neon parts; the seat.",
          "4. The swim: play `swimKeys` from the json on the joints.",
          "The game's fish are made by `src/server/Lib/FishModel.luau` today (placeholders); the chat that has `src/` in hand does this step.", ""]
if failed:
    lines += ["## Did not export", ""] + [f"- {f}: {'; '.join(why) or 'see the log'}" for f, why in failed] + [""]
text, note = NL.join(lines), R + "docs/design/creature-queue.md"
if os.path.exists(note):  # keep what people have written round the table
    old = io.open(note, encoding="utf-8").read()
    if "## The queue" in old and "## To put one in the game" in old:
        text = (old[: old.index("## The queue")] + text[text.index("## The queue") : text.index("## To put one in the game")]
                + old[old.index("## To put one in the game") :])
io.open(note, "w", encoding="utf-8", newline=NL).write(text)
print(len(rows), "exported;", len(failed), "failed", failed)
