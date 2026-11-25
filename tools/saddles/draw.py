"""Hands scenes to Blender (view.py): fish meshes, the block rider and saddle pieces, in the fish's own axes."""
import json
import os
import subprocess

import numpy as np

import fish as F

WORK = os.path.join(F.ROOT, "work", "saddles")
SKIN = {"skin": (242, 201, 160), "shirt": (60, 120, 216), "pants": (43, 43, 51), "shoe": (245, 245, 245)}


def fish_npz(f, s=1.0, pose=None, tag=""):
    os.makedirs(WORK, exist_ok=True)
    V, C, T, G, n = [], [], [], [], 0
    for name, (v, c, t, _nn) in f.parts.items():
        w = v * s
        if pose is not None:
            m = pose[f.owner[name]]
            w = w @ m[:3, :3].T + m[:3, 3]
        V.append(w)
        c = c if c is not None else np.full((len(v), 3), 0.5)
        C.append(np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4))  # (the meshes hold sRGB)
        T.append(t + n)
        G.append(np.full(len(t), 1 if name in f.rig["Glow"] or name.endswith("_Glow") else 0))
        n += len(v)
    path = os.path.join(WORK, f"{f.id}_{s:.3f}{tag}.npz")
    np.savez(path, verts=np.concatenate(V), colours=np.concatenate(C), tris=np.concatenate(T), glow=np.concatenate(G))
    return path


def rider_parts(at, pose=None, rodeo=False):
    """the rider's boxes for a seat at `at` (the back's top), carried by `pose` (the seat joint's 4x4)"""
    base = F.move(*at)
    if pose is not None:
        base = pose @ base
    return [{"shape": "box", "size": list(size), "m": (base @ m).tolist(), "colour": SKIN[kind], "neon": False} for _n, size, m, kind in F.rider(rodeo)]


def place(pieces, at, pose=None):
    base = F.move(*at)
    if pose is not None:
        base = pose @ base
    return [{"shape": p["shape"], "size": list(p["size"]), "m": (base @ p["m"]).tolist(), "colour": p["colour"], "neon": p.get("neon", False)} for p in pieces]


def shot(scene, name, eye, at, w, h, fov=None, ortho=None):
    s = {"scene": scene, "eye": [float(x) for x in eye], "at": [float(x) for x in at], "w": w, "h": h, "out": os.path.join(WORK, name + ".png")}
    s["ortho" if ortho else "fov"] = ortho or fov or 30
    return s


def blender(path):
    return subprocess.Popen(["blender", "--background", "--python", os.path.join(F.ROOT, "tools", "saddles", "view.py"), "--", path],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def render(scenes, shots, job="job"):
    """Blender several times over at once, a share of the shots each (SADDLE_BLENDERS=1: one small one at a time,
    for a machine short of memory, where the kernel kills them: exit -9 and no message)"""
    os.makedirs(WORK, exist_ok=True)
    one = os.environ.get("SADDLE_BLENDERS") == "1"
    n = max(1, len(shots) // 4) if one else max(1, min(4, len(shots) // 4))
    paths = []
    shots = sorted(shots, key=lambda s: s["scene"]) if one else shots
    for i in range(n):
        mine = shots[i * len(shots) // n:(i + 1) * len(shots) // n] if one else shots[i::n]
        use = {s["scene"] for s in mine}
        paths.append(os.path.join(WORK, f"{job}{i}.json"))
        json.dump({"scenes": {k: v for k, v in scenes.items() if k in use}, "shots": mine}, open(paths[-1], "w"))
    runs = [] if one else [blender(p) for p in paths]
    for i, path in enumerate(paths):
        r = blender(path) if one else runs[i]
        out = r.communicate()[0]
        if r.returncode or "Traceback" in out:
            print(out[-3000:], "exit", r.returncode)
            raise SystemExit("Blender failed")
