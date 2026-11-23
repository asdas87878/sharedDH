"""Checks the shopkeepers' tables against the stands as the hub kit draws them (art/map/greybox/hub.json), with the
game's own sums (tools/keepers/keepers.py):
  - every keeper faces its ring, and stands on something (the floor, or the Fuse machine's base);
  - no piece of a keeper or of a prop stands inside a piece of its stand (the keeper at rest, and at every mix of
    its look's two ends, its bob's two ends and its action), and no prop inside the keeper;
  - no prop is on the floor ring, or nearer it than a player needs to stand on it;
  - a stall's awning cuts nothing off the keeper's head, hat, arms or held thing as a player's camera sees them
    (stood on the ring's middle, its far edge and its near edge; the camera in keepers.py), idle and in the action;
  - no prop of a stall stands inside a piece of the rest of the hub, and each has a floor under it;
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
SHOWS = 30  # pixels of a 1920 x 1080 screen an action has to carry something, seen from the ring's middle
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


def on_floor(spot, floor, hub_in):
    """whether `spot` is over the hub's floor: one level slab, its top at 0.5, from the hub's back to its front and
    Half to each side (art/map/greybox/hub_in.json, tools/map/hub_kit.py), kept 4 studs in from its edges"""
    return (abs(spot[0]) <= hub_in["Half"] - 4 and hub_in["Back"] + 4 <= spot[2] <= hub_in["Front"] - 4
            and abs(floor - 0.5) <= 0.08)


def body(b):
    """a keeper's or a prop's part as the box it is tested as: a ball as a box three quarters its size (its own box
    would count the empty corners round it)"""
    return (b["m"], [v * 0.75 for v in b["size"]] if b.get("shape") == "Ball" else b["size"])


def spots(b, eye, front):
    """the points of a part that have to be seen: a box's corners, a ball's six ends and the top of its outline as
    `eye` sees it. front: only those on its half nearest the eye"""
    m, size = b["m"], b["size"]
    mid = [m[r][3] for r in range(3)]
    if b.get("shape") == "Ball":
        r = size[0] / 2
        out = [[mid[0] + r * d[0], mid[1] + r * d[1], mid[2] + r * d[2]] for d in
               ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
        to = [eye[i] - mid[i] for i in range(3)]
        flat = math.hypot(to[0], to[2])
        far = math.hypot(flat, to[1])
        # up and across the line of sight: the highest point of the ball's outline
        out.append([mid[0] + r * (-to[1] / far) * (to[0] / flat), mid[1] + r * flat / far,
                    mid[2] + r * (-to[1] / far) * (to[2] / flat)])
    else:
        out = K.corners(m, size)
    if front:
        near = sorted(out, key=lambda c: sum((c[i] - eye[i]) ** 2 for i in range(3)))
        out = near[:len(near) // 2] if b.get("shape") != "Ball" else [near[0], out[-1]]
    return out


def main():
    data = K.read()
    look = data["Look"]
    hub = json.load(open(K.HUB))
    hub_in = json.load(open(os.path.join(os.path.dirname(K.HUB), "hub_in.json")))
    faults, total, seen = [], 0, {}
    for k in data["List"]:
        parts = K.station(k["Station"], hub, SHIFT.get(k["Station"], (0.0, 0.0, 0.0)))
        space, scale = K.stand_space(parts, k["Stand"], look)
        lift = K.stand_lift(parts, space, scale, k, look)
        kspace = K.keeper_space(space, scale, k, lift)
        ring = next(p for p in parts if p["n"] == "Ring")
        title = next(p for p in parts if p["n"] == "Title")
        floor = space[1][3]
        solid = [(p["n"], (K.part_matrix(p), p["s"])) for p in parts if p.get("t") != 1]
        others = [(p["m"] + "/" + p["n"], (K.part_matrix(p), p["s"])) for p in hub["parts"]
                  if p["m"] != "Stations/" + k["Station"] and p.get("t") != 1]
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
                    deep = sunk(body(b), other)
                    if deep > DEEP and deep > worst.get((name, tag), (0,))[0]:
                        worst[(name, tag)] = (deep, f"part {i + 1} ({row[0]} {row[1]} {row[11]})")
        for (name, tag), (deep, which) in sorted(worst.items()):
            faults.append(f"{k['Id']}: {which} is {deep:.2f} into the stand's {name} ({tag})")
        # what a player sees: nothing of the head, the hat, the arms or what is held is cut off by the stand (the
        # awning's lip, a post), at the top of the bob and at every moment of the action worth looking at. The
        # keeper is tried looking straight ahead (it has not turned yet) and looking at the player whose camera it
        # is (head turned and tipped up at them: at the counter that is near the most it tips), with the player on
        # the ring's middle line and a step to each side of it. From the ring's middle and its far edge every point
        # counts; from its edge nearest the counter, where the camera looks steepest under the awning, the half of
        # each part that faces the player. A point the keeper's own parts hide is not counted
        if k["Stand"] == "CounterTop":
            solids = [s for s in K.solids_of(parts) if s[0] not in ("Counter", "CounterTop")]
            cut = {}
            for where, name in ((0, "the ring's middle"), (1, "the ring's far edge"), (-1, "the ring's near edge")):
                for side in (0.0, K.ASIDE, -K.ASIDE):
                    eye, at = K.play_camera(space, parts, where, side)
                    yaw, pitch = K.look_at(k, kspace, scale, look, at)
                    for turned, held in (("looking at the player", {"yaw": yaw, "pitch": pitch}), ("looking ahead", {})):
                        if not held and side:
                            continue
                        for t in [None] + K.action_times(k):
                            how = dict(held, sway_t=k["Bob"][1] / 4)
                            if t is not None:
                                how["action_t"] = t
                            boxes = K.keeper_boxes(data, k, kspace, scale, **how)
                            own = [(str(i), b["m"], body(b)[1]) for i, b in enumerate(boxes)]
                            for i, b in enumerate(boxes):
                                row = k["Parts"][i]
                                if row[0] in ("Root", "Body"):
                                    continue
                                for spot in spots(b, eye, where == -1):
                                    by = K.hidden_by(eye, spot, solids)
                                    if by and not K.hidden_by(eye, spot, own[:i] + own[i + 1:]):
                                        when = "idle" if t is None else f"action {t:.2f}"
                                        cut.setdefault((i, name), (by, f"{when}, {turned}, side {side:+.2f}", row))
            for (i, name), (by, when, row) in sorted(cut.items()):
                faults.append(f"{k['Id']}: part {i + 1} ({row[0]} {row[1]} {row[11]}) is cut off by the stand's {by} "
                              f"from {name} ({when})")
        # the action has to show: seen from the ring's middle by a player a step to the side, with the keeper looking
        # at them, it carries something at least SHOWS pixels of a 1920 x 1080 screen, and twice as far as the bob
        eye, at = K.play_camera(space, parts, 0, K.ASIDE)
        yaw, pitch = K.look_at(k, kspace, scale, look, at)
        bob, far, when, joint = K.shows(data, k, kspace, scale, eye, at, yaw=yaw, pitch=pitch)
        seen[k["Id"]] = f"bob {bob:.0f} px, action {far:.0f} px (the {joint} at {when:.2f})"
        if far < SHOWS or far < 2 * bob:
            faults.append(f"{k['Id']}: its action carries nothing further than {far:.0f} px on the screen from the ring's "
                          f"middle (the bob is {bob:.0f}, at least {max(SHOWS, 2 * bob):.0f} wanted)")
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
        # the rest of the hub: no prop inside a piece of anything else, and a floor under each (not the Fuse
        # machine's: it was moved by hand, and its props stand on its own base)
        if k["Station"] not in SHIFT:
            for i, b in enumerate(props):
                row = k["Props"][i]
                for name, other in others:
                    deep = sunk((b["m"], b["size"]), other)
                    if deep > DEEP:
                        faults.append(f"{k['Id']}: prop {i + 1} ({row[0]} {row[10]}) is {deep:.2f} into the hub's {name}")
                mid = [b["m"][r][3] for r in range(3)]
                if not on_floor(mid, floor, hub_in):
                    faults.append(f"{k['Id']}: prop {i + 1} ({row[0]} {row[10]}) has no floor under it")
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
    print("on the screen, from the ring's middle:")
    for name, line in seen.items():
        print(f"  {name:<11}{line}")
    print(f"all four: {total} parts")
    for f in faults:
        print("  !", f)
    print("no fault" if not faults else f"{len(faults)} faults")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main())
