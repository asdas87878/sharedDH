"""Is each sub's exported propeller the screw Hugo picked (option 4 of docs/attachments/sub-props-options-2026-11-23.png)?

usage: python tools/subs/screw_check.py            prints a row a tier; fails if a tier's propeller is not option 4

Reads the game meshes (art/subs/<Id>/<Id>.glb, what tools/subs/install.py puts in the place) and compares each tier's
`Prop` and `Prop_Glow`, point by point, with option 4 worked out again here from the option sheet's own formula
(tools/blender/sub_props_options.py: `option(4)`, `flight`, `hub`): a blunt cone of 8 sides from a tenth behind the
ring's middle to 3.3 behind the blades' face, two flights wound 205 degrees round it from 0.4 to 2.7, reaching 3.4
at the leading end and 1.5 at the tail end, 0.75 thick, and on tiers 6 to 9 a glowing ball on the cone's end. Sizes
are tier 1's; a bigger ring scales them (k = ring / 4.3).
It also prints, from the meshes alone: the colours of the cone and of the two flights (the mesh's own numbers), how far
the part's box is off the hub's line (the game spins a part about its box's middle), how far the screw reaches, how
far back it ends, and how near any other part of the sub comes to the space the turning screw sweeps (the builder's
gate does not compare the propeller with the hull).
The tail of each tier (tx: where the ring stands; ring: its radius) is sub_stages.py's `tail(...)` call in `toyN`.
"""
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "creatures"))
import glb_meshes  # noqa: E402

AZ = 0.7  # the hub's line, over the middle
# id, tx, ring, glowing ball
TAILS = [("Bathtub", 16.6, 4.3, False), ("ReefRunner", 16.6, 4.3, False), ("KelpCruiser", 18.1, 4.3, False),
         ("WreckDiver", 16.6, 4.3, False), ("BlueStreak", 19.4, 4.3, False), ("TwilightRay", 17.6, 4.3, True),
         ("MidnightHunter", 19.4, 4.3, True), ("VentCrawler", 16.6, 4.3, True), ("AbyssKing", 20.4, 5.0, True)]
TURN = 1


def option4(tx, k, glow):
    """option 4's corner points in the kit's axes (x to the tail, z up), as the option script builds them:
    the cone's, each flight's, the ball's"""
    face = tx + 0.95 + 0.1
    x0, x1 = tx + 0.1, face + 3.3 * k
    cone = []
    for x, r in ((x0, 1.75 * k), (x1, 0.5 * k)):
        cone += [(x, r * math.sin(2 * math.pi * i / 8), AZ - r * math.cos(2 * math.pi * i / 8)) for i in range(8)]
    flights = []
    for j in range(2):
        pts, n = [], 7
        for i in range(n):
            u = i / (n - 1)
            a = math.radians(90 + 180 * j - TURN * 205 * u)
            x = 0.4 + (2.7 - 0.4) * u
            r_out = 3.4 + (1.5 - 3.4) * u ** 1.4
            if i in (0, n - 1):
                r_out = 1.1 + (r_out - 1.1) * 0.55
            r_in = 1.1 * (1 - 0.5 * u)
            for r, s in ((r_in, -1), (r_out, -1), (r_out, 1), (r_in, 1)):
                pts.append((face + x * k + s * 0.75 * k / 2, r * k * math.cos(a), AZ + r * k * math.sin(a)))
        flights.append(pts)
    ball = (x1 + 0.1 * k, 0.0, AZ, 0.8 * k) if glow else None
    return cone, flights, ball


def kit(p, part):
    """a mesh point in the kit's axes: the game's (x, y, z) is the kit's (y, z, x)"""
    g = [p[i] + part["origin"][i] for i in range(3)]
    return (g[2], g[0], g[1])


def near(a, b):
    return math.dist(a, b)


def rgb(c):
    return tuple(round(v * 255) for v in c[:3])


def main():
    bad = 0
    print("tier  id               cone   flights   ball   box off hub   reach (ring's inside)   ends behind middle   nearest other part"
          "   cone colour      flight 1         flight 2")
    for tier, (name, tx, ring, glow) in enumerate(TAILS, 1):
        k = ring / 4.3
        parts = {p["name"]: p for p in glb_meshes.parts(os.path.join(ROOT, "art", "subs", name, name + ".glb"))}
        prop = parts["Prop"]
        pts = [kit(p, prop) for p in prop["positions"]]
        cone, flights, ball = option4(tx, k, glow)
        want = cone + flights[0] + flights[1]
        # every mesh point is one of option 4's, and every one of option 4's points is in the mesh
        off_mesh = max(min(near(p, w) for w in want) for p in pts)
        off_want = max(min(near(p, w) for p in pts) for w in want)
        # which piece each mesh point belongs to, for the colours
        seen = {"cone": set(), "f1": set(), "f2": set()}
        for p, c in zip(pts, prop["colours"]):
            best = min((min(near(p, w) for w in group), key) for key, group in (("cone", cone), ("f1", flights[0]), ("f2", flights[1])))
            seen[best[1]].add(rgb(c))
        ball_off = None
        if glow:
            b = parts.get("Prop_Glow")
            if b is None:
                ball_off = 99.0
            else:
                bp = [kit(p, b) for p in b["positions"]]
                ball_off = max(abs(near(p, ball[:3]) - ball[3]) for p in bp)
        elif "Prop_Glow" in parts:
            ball_off = 99.0
        xs, ys, zs = zip(*pts)
        box_off = math.hypot((min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2 - AZ)
        reach = max(math.hypot(p[1], p[2] - AZ) for p in pts)
        end = max(xs) if not glow else max(max(xs), ball[0] + ball[3])
        # the space the turning screw sweeps: a cylinder of its reach from the blades' face to its end
        face = tx + 1.05
        gap, who = 1e9, ""
        for other in parts.values():
            if other["name"].startswith("Prop"):
                continue
            for p in other["positions"]:
                q = kit(p, other)
                if face <= q[0] <= end:
                    d = math.hypot(q[1], q[2] - AZ) - reach
                    if d < gap:
                        gap, who = d, other["name"]
        same = off_mesh < 0.002 and off_want < 0.002 and (ball_off is None or ball_off < 0.002) and box_off < 0.002
        inside = reach < ring - 0.6
        clear = gap > 0.1
        bad += not (same and inside and clear)
        print("%d     %-15s  %-5s  %-8s  %-5s  %.3f         %.2f (%.2f)             %.2f                %.2f (%s)%s   %-15s  %-15s  %-15s%s" % (
            tier, name, "same" if off_mesh < 0.002 and off_want < 0.002 else "DIFF", "2", ("same" if ball_off < 0.002 else "DIFF") if ball_off is not None else "none",
            box_off, reach, ring - 0.6, end, min(gap, 99.0), who or "nothing beside it", "" if clear else " TOUCHES",
            "/".join(map(str, sorted(seen["cone"])[0])), "/".join(map(str, sorted(seen["f1"])[0])), "/".join(map(str, sorted(seen["f2"])[0])),
            "" if all(len(v) == 1 for v in seen.values()) else "  ! a piece has more than one colour"))
    print("screw check: %d of 9 tiers are option 4 point for point (to 0.002 studs), inside their ring and clear of the sub" % (9 - bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
