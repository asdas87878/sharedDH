"""Holds the game's sums (src/shared/Keepers.luau, run by lune with its own CFrame) against the ones the design sheet
and the check are drawn with (tools/keepers/keepers.py): every part of every keeper in a spread of poses (idle,
action, look, both sizes), the split of a look, the aim at a point, every stand's space and every prop in it.

    python tools/keepers/sums_check.py        prints the furthest any number is apart; exits 1 past a thousandth

Needs lune (rokit: lune-org/lune); says so and exits 2 without it."""
import glob
import json
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import keepers as K  # noqa: E402

POSES = [
    {},
    {"sway_t": 1.7},
    {"sway_t": 0.4, "action_t": 0.3},
    {"action_t": 0.6, "yaw": 40.0, "pitch": -10.0},
    {"sway_t": 3.3, "action_t": 0.5, "yaw": -76.0, "pitch": 16.0},
    {"sway_t": 9.1, "action_t": 0.93, "yaw": 120.0, "pitch": -60.0},
    {"action_t": 0.05, "yaw": -12.0, "pitch": 5.0},
]
POINTS = [[3.0, 1.0, 5.0], [-4.0, -2.0, 6.0], [2.0, 6.0, -1.0], [-7.0, 0.5, -3.0], [0.0, 3.0, 0.0]]
TURNS = [[10.0, 4.0], [-50.0, -30.0], [76.0, 16.0], [200.0, 90.0], [-23.9, -22.0], [68.6, 0.0]]


def flat(m):
    """a matrix as CFrame:GetComponents gives it: the place, then the turn row by row"""
    return [m[0][3], m[1][3], m[2][3]] + [m[r][c] for r in range(3) for c in range(3)]


def lune():
    found = glob.glob(os.path.expanduser("~/.rokit/tool-storage/lune-org/lune/*/lune"))
    return sorted(found)[-1] if found else shutil.which("lune")


def main():
    data = K.read()
    look = data["Look"]
    hub = json.load(open(K.HUB))
    cases = {"poses": [], "splits": [], "aims": [], "stands": []}
    for k in data["List"]:
        for scale in (1.0, 1.13):
            for how in POSES:
                cases["poses"].append({"id": k["Id"], "scale": scale, "how": how,
                                       "parts": [flat(m) for _row, m in K.pose(k, look=look, scale=scale, **how)]})
        parts = K.station(k["Station"], hub)
        ring = next(p for p in parts if p["n"] == "Ring")
        anchor = next(p for p in parts if p["n"] == k["Stand"])
        space, scale = K.stand_space(parts, k["Stand"], look)
        cases["stands"].append({"id": k["Id"], "anchor": anchor["p"], "ring": ring["p"], "floor": ring["p"][1] - ring["s"][1] / 2,
                                "scale": scale, "space": flat(space),
                                "props": [flat(b["m"]) for b in K.prop_boxes(data, k, space, scale)]})
    for yaw, pitch in TURNS:
        cases["splits"].append({"yaw": yaw, "pitch": pitch, "out": list(K.look_split(look, yaw, pitch))})
    for p in POINTS:
        cases["aims"].append({"at": p, "out": list(K.aim(look, p))})
    exe = lune()
    if not exe:
        print("no lune on this machine: the sums were not held against each other")
        return 2
    work = os.path.join(K.ROOT, "work", "keepers")
    os.makedirs(work, exist_ok=True)
    path = os.path.join(work, "sums.json")
    json.dump(cases, open(path, "w"))
    run = subprocess.run([exe, "run", os.path.join(os.path.dirname(os.path.abspath(__file__)), "sums_check.luau"), K.LUAU, path],
                         capture_output=True, text=True)
    print(run.stdout.strip() or run.stderr.strip())
    return run.returncode


if __name__ == "__main__":
    sys.exit(main())
