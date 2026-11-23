"""Checks the shopkeepers' tables against the stands as the hub kit draws them (art/map/greybox/hub.json), with the
game's own sums (tools/keepers/keepers.py):
  - every keeper faces its ring, and stands on something (the floor, or the Fuse machine's base);
  - no piece of a keeper or of a prop stands inside a piece of its stand (the keeper at rest, and at every mix of
    its look's two ends, its bob's two ends and its action), and no prop inside the keeper;
  - no prop is on the floor ring, or nearer it than a player needs to stand on it;
  - nothing reaches the floating name;
  - the part counts.
The Fuse machine is checked where the place has it (moved by hand by (-19.4, 0, 11.8)), which changes nothing: every
sum is from the station's own parts.

    python tools/keepers/check.py        prints what it finds; exits 1 on a fault"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import keepers as K  # noqa: E402

DEEP = 0.06  # studs two boxes may sink into each other before it counts (a hand on a counter, a jar on a base)
RING_CLEAR = 1.0  # studs kept free round the ring's edge
SHIFT = {"Fuse": (-19.4, 0.0, 11.8)}


def axes_of(m):
    return [[m[r][c] for r in range(3)] for c in range(3)]


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def sunk(a, b):
    """how deep two boxes (matrix, size) are in each other along their shallowest way out: 0 or less if apart"""
    (ma, sa), (mb, sb) = a, b
    xa, xb = axes_of(ma), axes_of(mb)
    d = [mb[r][3] - ma[r][3] for r in range(3)]
    tests = xa + xb + [K.cross(p, q) for p in xa for q in xb]
    least = 1e9
    for ax in tests:
        n = math.sqrt(dot(ax, ax))
        if n < 1e-6:
            continue
        ax = [v / n for v in ax]
        ra = sum(abs(dot(ax, xa[i])) * sa[i] / 2 for i in range(3))
        rb = sum(abs(dot(ax, xb[i])) * sb[i] / 2 for i in range(3))
        least = min(least, ra + rb - abs(dot(ax, d)))
        if least <= 0:
            return least
    return least


def main():
    data = K.read()
    look = data["Look"]
    hub = json.load(open(K.HUB))
    faults, total = [], 0
    for k in data["List"]:
        parts = K.station(k["Station"], hub, SHIFT.get(k["Station"], (0.0, 0.0, 0.0)))
        space, scale = K.stand_space(parts, k["Stand"], look)
        lift = K.stand_lift(parts, space, scale, k, look)
        kspace = K.keeper_space(space, scale, k, lift)
        ring = next(p for p in parts if p["n"] == "Ring")
        title = next(p for p in parts if p["n"] == "Title")
        floor = space[1][3]
        solid = [(p["n"], (K.part_matrix(p), p["s"])) for p in parts if p.get("t") != 1]
        # it faces its ring
        to_ring = [ring["p"][i] - kspace[i][3] for i in range(3)]
        ahead = dot([kspace[r][2] for r in range(3)], to_ring) / math.hypot(to_ring[0], to_ring[2])
        if ahead < 0.7:
            faults.append(f"{k['Id']}: does not face its ring (cos {ahead:.2f})")
        most = look["Body"] + look["Head"]
        # every look (both ends and straight) with every moment of the action and both ends of the bob: a player
        # stood to one side while the action plays is the usual case
        poses = []
        for turn, yaw in (("ahead", 0.0), ("left", most), ("right", -most)):
            for bob, sway in (("bob up", k["Bob"][1] / 4), ("bob down", k["Bob"][1] * 3 / 4)):
                for t in (None, 0.2, 0.35, 0.5, 0.65, 0.8):
                    how = {"yaw": yaw, "sway_t": sway}
                    if t is not None:
                        how["action_t"] = t
                    poses.append((f"{turn}, {bob}, " + ("idle" if t is None else f"action {t:.2f}"), how))
        poses.append(("rest", {}))
        worst = {}
        for tag, how in poses:
            for i, b in enumerate(K.keeper_boxes(data, k, kspace, scale, **how)):
                row = k["Parts"][i]
                for name, other in solid:
                    deep = sunk((b["m"], b["size"]), other)
                    if deep > DEEP and deep > worst.get((name, tag), (0,))[0]:
                        worst[(name, tag)] = (deep, f"part {i + 1} ({row[0]} {row[1]} {row[11]})")
        for (name, tag), (deep, which) in sorted(worst.items()):
            faults.append(f"{k['Id']}: {which} is {deep:.2f} into the stand's {name} ({tag})")
        props = K.prop_boxes(data, k, space, scale)
        rest = K.keeper_boxes(data, k, kspace, scale)
        top = floor
        for i, b in enumerate(props):
            row = k["Props"][i]
            for name, other in solid:
                deep = sunk((b["m"], b["size"]), other)
                if deep > DEEP:
                    faults.append(f"{k['Id']}: prop {i + 1} ({row[0]} {row[10]}) is {deep:.2f} into the stand's {name}")
            for kb in rest:
                if sunk((b["m"], b["size"]), (kb["m"], kb["size"])) > DEEP:
                    faults.append(f"{k['Id']}: prop {i + 1} ({row[0]} {row[10]}) is inside the keeper")
                    break
            cs = K.corners(b["m"], b["size"])
            top = max(top, max(c[1] for c in cs))
            near = min(math.hypot(c[0] - ring["p"][0], c[2] - ring["p"][2]) for c in cs) - ring["s"][0] / 2
            if near < RING_CLEAR:
                faults.append(f"{k['Id']}: prop {i + 1} ({row[0]} {row[10]}) is {near:.2f} from the ring's edge")
            if min(c[1] for c in cs) < floor - 0.02:
                faults.append(f"{k['Id']}: prop {i + 1} ({row[0]} {row[10]}) is under the floor")
        ktop = max(c[1] for b in rest for c in K.corners(b["m"], b["size"]))
        name_low = title["p"][1] - title["bill"]["size"][1] / 2
        if max(top, ktop) > name_low - 1:
            faults.append(f"{k['Id']}: reaches {max(top, ktop) - floor:.1f}, the name's lower edge is at {name_low - floor:.1f}")
        lit = sum(1 for r in k["Parts"] + k["Props"] if isinstance(r[-1], dict) and r[-1].get("Light"))
        glow = sum(1 for r in k["Parts"] + k["Props"] if isinstance(r[-1], dict) and r[-1].get("Mat") == "Neon")
        see = sum(1 for r in k["Parts"] + k["Props"] if isinstance(r[-1], dict) and r[-1].get("See"))
        stud = sum(1 for r in k["Parts"] + k["Props"] if isinstance(r[-1], dict) and r[-1].get("Stud"))
        moving = sum(1 for r in k["Parts"] if r[0] != "Root")
        total += len(k["Parts"]) + len(k["Props"])
        print(f"{k['Id']:<11}{k['Station']:<6} scale {scale:.2f}  feet {lift:.2f} over the floor  keeper {len(k['Parts'])} parts "
              f"({moving} move), top {ktop - floor:.2f}  props {len(k['Props'])}, top {top - floor:.2f}  "
              f"neon {glow}, see-through {see}, lights {lit}, stud pictures {stud}")
    print(f"all four: {total} parts")
    for f in faults:
        print("  !", f)
    print("no fault" if not faults else f"{len(faults)} faults")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main())
