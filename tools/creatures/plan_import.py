"""Works out what the next creature import would upload, and uploads nothing (docs/design/creature-import.md).
usage: python tools/creatures/plan_import.py            (writes tools/creatures/import_plan.json and prints the counts)

Reads:
  art/creatures/<Folder>/game/<Name>.mesh.json   every creature that has an export (the Id is the folder's name)
  tools/creatures/picks.json                     {"remove": [Id, ...]}: the creatures the user took out in the picker
  tools/creatures/assets.json                    {Id: asset id}: what is uploaded now
  tools/creatures/assets_dark.json               {Id: old asset id}: first, too-dark uploads that HAVE been replaced
A creature in assets.json and not in assets_dark.json is still the too-dark upload, so it is uploaded again.
"""
import glob
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/")
HERE = ROOT + "/tools/creatures/"
NL = chr(10)


def load(name, default):
    path = HERE + name
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else default


picks = load("picks.json", {"remove": []})
assets = load("assets.json", {})
replaced = {k for k in load("assets_dark.json", {}) if k != "note"}
remove = set(picks.get("remove", []))
plan = {"note": "Written by tools/creatures/plan_import.py. Nothing here is uploaded: an upload is permanent and needs the user's word.",
        "picksSavedAt": picks.get("savedAt"), "uploadNew": [], "uploadAgain": [], "asItIs": [], "leftOut": [], "takeOutOfGame": [], "files": {}}
for found in sorted(glob.glob(ROOT + "/art/creatures/*/game/*.mesh.json")):
    found = found.replace("\\", "/")
    folder = found.split("/")[-3]
    data = json.load(open(found, encoding="utf-8"))
    zone = re.search(r"ZONE (\d+)", data["zone"].upper())
    row = {"id": folder, "name": data["name"], "zone": int(zone.group(1)) if zone else None, "rarity": data["rarity"].title(),
           "triangles": data["triangles"], "parts": len(data["parts"])}
    if folder in remove:
        plan["leftOut"].append(row)
        if folder in assets:
            plan["takeOutOfGame"].append(folder)  # it is in the game now: its template and its row in the fish table go
        continue
    plan["files"][folder] = found[len(ROOT) + 1 : -len(".mesh.json")] + ".glb"
    if folder not in assets:
        plan["uploadNew"].append(row)
    elif folder not in replaced:
        plan["uploadAgain"].append(row)
    else:
        plan["asItIs"].append(row)
unknown = sorted(remove - {r["id"] for r in plan["leftOut"]})
if unknown:
    plan["unknownPicks"] = unknown
io.open(HERE + "import_plan.json", "w", encoding="utf-8", newline=NL).write(json.dumps(plan, indent=1) + NL)
print(f"new uploads {len(plan['uploadNew'])}; uploads again (too dark) {len(plan['uploadAgain'])}; as it is {len(plan['asItIs'])}; "
      f"left out {len(plan['leftOut'])} (of them in the game now: {len(plan['takeOutOfGame'])})")
if unknown:
    print("picks that match no creature:", unknown)
