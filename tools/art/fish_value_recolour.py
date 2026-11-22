"""Recolour fish to a target body lightness (CIE L*) for their land, colours only (docs/design/fish-recolour-list.md).
Starts from the committed voxel.py (git HEAD), moves the big visible palette colours (by the rider's-view weight the
measure uses) in their own hue (Lab: L moves, a and b kept, chroma cut only to stay in sRGB), exports, measures, and
repeats until the body median is within TOL of the target. Glow colours and small colours (eyes, patterns) stay.
usage (from the project folder): python tools/art/fish_value_recolour.py . [Id ...]
Used 2026-11-19 for docs/design/fish-recolour-list.md; TARGET holds that list's targets. It rewrites voxel.py from git HEAD."""
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

import numpy as np

ROOT = sys.argv[1]
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
import fish_values as fv  # noqa: E402

BLENDER = "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
TARGET = {"Clownfish": 77, "Cuttlefish": 70, "PearlSerpent": 51, "Lionfish": 54, "Octopus": 45, "Dunkleosteus": 40,
          "CoralDragon": 35, "GiantSeaBass": 34, "LeopardShark": 82, "GreatWhite": 34, "StellersSeaCow": 34,
          "Dakosaurus": 29, "KelpWyrm": 24, "HammerheadShark": 77, "Sawfish": 77, "ElectricRay": 29, "GoliathGrouper": 29,
          "Xiphactinus": 24, "GalleonWhale": 19, "Dolphin": 67, "Elasmosaurus": 46, "BlueWhale": 41, "GoblinShark": 58,
          "FrilledShark": 67, "Kronosaurus": 43, "Megalodon": 43, "MoltenMegalodon": 48, "EmberSerpent": 48,
          "GraveRay": 86, "GraveTurtle": 86, "HalfboneMegalodon": 91, "PhantomWhale": 91, "BrimstoneEel": 58}
TOL, SHARE, ROUNDS = 2.0, 0.6, 6
ONLY = sys.argv[2:] or list(TARGET)


def to_lab(rgb):
    a = np.asarray(rgb, float) / 255
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = M @ lin / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def from_lab(lab):
    L, A, B = lab
    fy = (L + 16) / 116
    fx, fz = fy + A / 500, fy - B / 200
    f = np.array([fx, fy, fz])
    xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16 / 116) / 7.787) * np.array([0.95047, 1.0, 1.08883])
    Mi = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
    lin = Mi @ xyz
    return np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * np.clip(lin, 0, None) ** (1 / 2.4) - 0.055)


def shift(hexv, dL):
    lab = to_lab([int(hexv[i:i + 2], 16) for i in (1, 3, 5)])
    L = float(np.clip(lab[0] + dL, 4, 98))
    lo, hi = 0.0, 1.0  # the most chroma that stays inside sRGB at the new lightness
    if np.all((from_lab([L, lab[1], lab[2]]) >= 0) & (from_lab([L, lab[1], lab[2]]) <= 1)):
        lo = 1.0
    else:
        for _ in range(30):
            m = (lo + hi) / 2
            c = from_lab([L, lab[1] * m, lab[2] * m])
            lo, hi = (m, hi) if np.all((c >= -1e-4) & (c <= 1 + 1e-4)) else (lo, m)
    c = np.clip(from_lab([L, lab[1] * lo, lab[2] * lo]), 0, 1)
    return "#%02X%02X%02X" % tuple(int(round(v * 255)) for v in c)


def palette(src):
    m = re.search(r"^PALETTE\s*=\s*\{.*?\}\s*$", src, re.S | re.M)
    return m, dict(re.findall(r'"([^"]+)"\s*:\s*"(#[0-9A-Fa-f]{6})"', m.group(0)))


def write_palette(src, new):
    m, _ = palette(src)
    block = m.group(0)
    for name, hexv in new.items():
        block = re.sub(r'("' + re.escape(name) + r'"\s*:\s*")#[0-9A-Fa-f]{6}(")', r"\g<1>" + hexv + r"\2", block)
    return src[: m.start()] + block + src[m.end():]


def export(cid):
    r = subprocess.run([BLENDER, "--background", "--python", f"{ROOT}/tools/blender/voxel_kit.py", "--",
                        f"{ROOT}/art/creatures/{cid}/voxel.py", f"{ROOT}/work/voxel/check_{cid}", "--export",
                        f"{ROOT}/art/creatures/{cid}/game"], capture_output=True, text=True)
    out = r.stdout + r.stderr
    if "voxel kit: export" not in out or re.search(r"^  !", out, re.M):
        raise RuntimeError(cid + " export failed:\n" + out[-1500:])


def measure(cid):
    cols, wts, _, meta = fv.fish_surface(cid)
    L = fv.lstar(cols)
    med = fv.weighted_pct(L, wts, 50)
    cells = meta.get("paletteCells", {})
    glow = {k.lower() for k in (meta.get("glow") or {})}
    names = list(cells)
    ref = np.array([[int(cells[n][i:i + 2], 16) for i in (1, 3, 5)] for n in names], float)
    byname = {}
    for c, w in zip(cols, wts):
        j = int(np.argmin(((ref - c) ** 2).sum(1)))
        base = names[j].rstrip("+-")
        byname[base] = byname.get(base, 0) + w
    return med, byname, glow


def run(cid):
    path = f"{ROOT}/art/creatures/{cid}/voxel.py"
    head = subprocess.run(["git", "show", f"HEAD:art/creatures/{cid}/voxel.py"], capture_output=True, text=True,
                          cwd=ROOT, encoding="utf-8").stdout
    _, base_pal = palette(head)
    open(path, "w", encoding="utf-8", newline="\n").write(head)
    export(cid)
    med0, byname, glow = measure(cid)
    target = TARGET[cid]
    total = sum(byname.values())
    order = [n for n in sorted(byname, key=byname.get, reverse=True) if n in base_pal and n.lower() not in glow
             and "glow" not in n.lower()]
    k, acc, chosen = 0, 0.0, []
    for n in order:  # the big colours, largest first, until they make SHARE of what a rider sees
        chosen.append(n)
        acc += byname[n] / total
        if acc >= SHARE:
            break
    dL, med, hist = target - med0, med0, []
    for rnd in range(ROUNDS):
        new = {n: shift(base_pal[n], dL) for n in chosen}
        src = write_palette(head, new)
        open(path, "w", encoding="utf-8", newline="\n").write(src)
        export(cid)
        med, _, _ = measure(cid)
        hist.append((round(dL, 1), round(med, 1)))
        if abs(med - target) <= TOL:
            break
        # the next guess: the secant through the last two (or the first move scaled), more colours if it stalls
        if len(hist) >= 2 and abs(hist[-1][1] - hist[-2][1]) > 0.3:
            slope = (hist[-1][1] - hist[-2][1]) / (hist[-1][0] - hist[-2][0])
        else:
            slope = (med - med0) / dL if abs(dL) > 0.1 and abs(med - med0) > 0.3 else 0.5
        if slope < 0.35 and len(chosen) < len(order):
            chosen.append(order[len(chosen)])
        dL = float(np.clip(dL + (target - med) / max(slope, 0.2), -80, 80))
    return cid, round(med0, 1), round(med, 1), target, chosen, {n: (base_pal[n], new[n]) for n in chosen}, hist


if __name__ == "__main__":
    with ThreadPoolExecutor(4) as ex:
        results = list(ex.map(lambda c: (lambda: run(c))() if True else None, ONLY))
    json.dump([{"id": r[0], "before": r[1], "after": r[2], "target": r[3], "names": r[4], "colours": r[5], "rounds": r[6]}
               for r in results], open(f"{ROOT}/work/voxel/value_recolour.json", "w"), indent=1)
    for r in results:
        print(f"{r[0]:18} {r[1]:5} -> {r[2]:5} (target {r[3]})  {', '.join(f'{n} {a}->{b}' for n, (a, b) in r[5].items())}")
