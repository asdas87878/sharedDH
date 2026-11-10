"""Load a creature's exported GLB back into Blender and compare it with its mesh.json: pivots, size, the middle, turns and
scales, parents, vertex colours.
usage: blender --background --python tools/blender/check_glb.py -- <Folder>   (prints lines starting CHECK)"""
import json
import glob
import os
import sys

import bpy

name = sys.argv[sys.argv.index("--") + 1]
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/")
folder = f"{root}/art/creatures/{name}/game/"
stem = os.path.basename(glob.glob(folder + "*.mesh.json")[0])[:-10]
d = json.load(open(folder + stem + ".mesh.json"))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=folder + stem + ".glb")
bpy.context.view_layer.update()
pivots = {p["name"]: p["pivot"] for p in d["parts"]}
worst, lo, hi = 0.0, [1e9] * 3, [-1e9] * 3
for ob in [o for o in bpy.data.objects if o.type == 'MESH']:
    w = ob.matrix_world
    game = (w.translation.x, w.translation.z, -w.translation.y)
    base = ob.name.replace("_Glow", "")
    if base in pivots:
        worst = max(worst, max(abs(a - b) for a, b in zip(game, pivots[base])))
    for v in ob.data.vertices:
        p = w @ v.co
        for a, c in enumerate((p.x, p.z, -p.y)):
            lo[a], hi[a] = min(lo[a], c), max(hi[a], c)
ob = bpy.data.objects[d["parts"][1]["name"]]
print("CHECK", name, "objects", len(bpy.data.objects), "parts", len(d["parts"]), "glow", len(d["glowParts"]))
print("CHECK worst pivot error", round(worst, 4), "size", [round(hi[a] - lo[a], 2) for a in range(3)], "json size", d["size"], "middle", [round((hi[a] + lo[a]) / 2, 3) for a in range(3)])
print("CHECK", ob.name, "parent", ob.parent.name if ob.parent else None, "rot", [round(x, 3) for x in ob.matrix_world.to_euler()], "scale", [round(x, 3) for x in ob.matrix_world.to_scale()],
      "colours", [a.name for a in ob.data.color_attributes], "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
