"""Top and side views of the blockout (v3 on): every part's footprint from above, the island close up, and the lane's floor
along its path from the island to the end of the trench.

usage: python tools/art/map_plot.py <bake.json> <out.png> [island.png]
<bake.json> is what sharedDH-local/tools/bake_map.luau writes: the script's zones JSON plus a PartDump of every part.
"""
import json
import sys

import cv2
import numpy as np

RIDE_SPEED = 55  # studs a second, the reference's measured riding speed
EXAGGERATE = 4  # vertical exaggeration in the side view

data = json.load(open(sys.argv[1]))
out = sys.argv[2]
parts = data["PartDump"]
zones = data["Zones"]
path = data["Path"]
ox = data["Origin"][0]


def footprint(p):
    """The outline of the part's box from above, in world x/z: the hull of its eight corners, flattened."""
    r = p["r"]
    axes = [np.array([r[0], r[1]]) * p["sx"] / 2, np.array([r[2], r[3]]) * p["sy"] / 2, np.array([r[4], r[5]]) * p["sz"] / 2]
    c = np.array([p["x"], p["z"]])
    corners = [c + a * axes[0] + b * axes[1] + d * axes[2] for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)]
    return corners


def top_view(width, height, x0, x1, z0, z1, keep, title, labels=True):
    img = np.full((height, width, 3), (120, 60, 20), np.uint8)  # deep water, BGR
    scale = min((width - 40) / (x1 - x0), (height - 60) / (z1 - z0))

    def px(x, z):
        return int(20 + (x - x0) * scale), int(height - 20 - (z - z0) * scale)

    # draw lowest first, so what's higher sits on top
    for p in sorted(parts, key=lambda p: p["top"]):
        if not keep(p) or p["t"] >= 0.99 or p["n"] in ("SeaTile", "Deep", "Smoke", "Glass", "TankWater"):
            continue
        r, g, b = p["c"]
        shape = p.get("shape", "Block")
        if shape == "Ball" or (shape == "Cylinder" and abs(p["r"][0]) + abs(p["r"][1]) < 0.2):  # round from above
            radius = (p["sx"] if shape == "Ball" else min(p["sy"], p["sz"])) / 2
            cv2.circle(img, px(p["x"], p["z"]), max(1, int(radius * scale)), (b, g, r), -1, cv2.LINE_AA)
            continue
        pts = cv2.convexHull(np.array([px(x, z) for x, z in footprint(p)], np.int32))
        cv2.fillConvexPoly(img, pts, (b, g, r))
    # the lane's centreline
    pts = np.array([px(s[1], s[3]) for s in path], np.int32)
    cv2.polylines(img, [pts], False, (255, 255, 255), 1, cv2.LINE_AA)
    if labels:
        for zone in zones:
            x, z = zone["Start"][0] + ox, zone["Start"][1]
            q = px(x, z)
            cv2.circle(img, q, 5, (255, 255, 255), -1)
            cv2.putText(img, zone["Name"].title(), (q[0] + 8, q[1] + 4), cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                        (255, 255, 255), 2, cv2.LINE_AA)
        # a scale bar
        bar = 2000 * scale
        cv2.line(img, (20, height - 10), (20 + int(bar), height - 10), (255, 255, 255), 2)
        cv2.putText(img, "2,000 studs", (24 + int(bar), height - 6), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1,
                    cv2.LINE_AA)
    cv2.putText(img, title, (20, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (255, 255, 255), 2, cv2.LINE_AA)
    return img


xs = [s[1] for s in path] + [ox - 1000, ox + 1000]
zs = [s[3] for s in path] + [-1000, 1000]
total = path[-1][0]
deepest = -min(s[2] for s in path)
top = top_view(
    1100, 1100, min(xs) - 600, max(xs) + 600, min(zs) - 200, max(zs) + 400, lambda p: True,
    f"Blockout v3 from above: {data['Parts']:,} parts, {data['PropModels']} prop placeholders",
)

# the side view: the floor along the lane's path (distance along it), with the zones
W = 1100
LEFT, TOP = 60, 150
start = data["LaneStart"]
sx = (W - LEFT - 30) / (total + start + 300)
sy = sx * EXAGGERATE
H = int(TOP + deepest * sy + 60)
side = np.full((H, W, 3), 250, np.uint8)
for row in range(TOP, H):
    t = min(1.0, (row - TOP) / (H - TOP))
    side[row, :] = (int(205 - 150 * t), int(170 - 140 * t), int(110 - 95 * t))
cv2.line(side, (0, TOP), (W, TOP), (200, 120, 40), 2)


def spx(s, y):
    return int(LEFT + (s + start) * sx), int(TOP - y * sy)


pts = [spx(-start, -30)] + [spx(s[0], s[2]) for s in path]
poly = np.array(pts + [(pts[-1][0], H), (pts[0][0], H)], np.int32)
cv2.fillPoly(side, [poly], (60, 75, 95))
cv2.polylines(side, [np.array(pts, np.int32)], False, (190, 230, 250), 2, cv2.LINE_AA)
for i, zone in enumerate(zones):
    s0, s1 = zone["Z0"] - start, zone["Z1"] - start
    x0, y0 = spx(s0, zone["Y0"])
    cv2.line(side, (x0, TOP), (x0, y0), (235, 235, 235), 1, cv2.LINE_AA)
    mid = (x0 + spx(s1, 0)[0]) // 2
    row = TOP + 24 + (i % 3) * 34
    for text, size, dy in ((zone["Name"].title(), 0.45, 0), (f"{zone['Metres']:,} m, {(s1 - s0) / RIDE_SPEED:.0f} s", 0.38, 14)):
        w = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, size, 1)[0][0]
        cv2.putText(side, text, (mid - w // 2, row + dy), cv2.FONT_HERSHEY_SIMPLEX, size, (255, 255, 255), 1, cv2.LINE_AA)
for d in range(0, int(total), 4000):
    x, _ = spx(d - start, 0)
    cv2.putText(side, f"{d:,}", (x - 14, H - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)
cv2.putText(side, "distance from the island along the lane", (W - 330, H - 26), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)
cv2.putText(side, f"Side view along the lane: {total:,.0f} studs of lane, {deepest:,.0f} deep,", (LEFT, 34),
            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (40, 40, 40), 2, cv2.LINE_AA)
cv2.putText(side, f"about {total / RIDE_SPEED / 60:.0f} min at {RIDE_SPEED} studs/s. Height drawn x{EXAGGERATE}; drops are ramps now.",
            (LEFT, 62), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (40, 40, 40), 2, cv2.LINE_AA)

cv2.imwrite(out, np.vstack([top, side]))
print(out)

if len(sys.argv) > 3:
    island = top_view(
        1000, 1000, ox - 1000, ox + 1000, -1000, 1000, lambda p: abs(p["y"]) < 200,
        "v3 island and lagoon from above (2,000 x 2,000 studs)", labels=False,
    )
    cv2.imwrite(sys.argv[3], island)
    print(sys.argv[3])
