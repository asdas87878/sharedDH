"""Side view of the dive: the blockout's floor from the dock to the end of the trench, with v1's for comparison.

usage: python tools/art/depth_profile.py art/blockout/v2_zones.json docs/attachments/blockout-v2-profile.png
The zones JSON is what tools/studio/claude_blockout.luau returns after a build.
"""
import json
import sys

import cv2
import numpy as np

RIDE_SPEED = 55  # studs a second, the reference's measured riding speed
REFERENCE_BEST = 7590  # the reference player's best run in the recording
EXAGGERATE = 4  # vertical exaggeration, so a gentle slope is visible at all

zones = json.load(open(sys.argv[1]))["Zones"]
out = sys.argv[2]

W, H = 1800, 640
LEFT, TOP = 70, 70
length = zones[-1]["Z1"] + 300
sx = (W - LEFT - 40) / length
sy = sx * EXAGGERATE


def px(z, y):
    return int(LEFT + z * sx), int(TOP - y * sy)


img = np.full((H, W, 3), 250, np.uint8)
# the sea, darker with depth
for row in range(TOP, H):
    t = min(1.0, (row - TOP) / (H - TOP))
    img[row, :] = (int(205 - 150 * t), int(170 - 140 * t), int(110 - 95 * t))
cv2.line(img, (0, TOP), (W, TOP), (200, 120, 40), 2)
cv2.putText(img, "sea surface", (8, TOP - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (150, 90, 30), 1, cv2.LINE_AA)

# v2's floor, with the drop-offs between zones
points = [px(0, -30)]
for zone in zones:
    points.append(px(zone["Z0"], zone["Y0"]))
    points.append(px(zone["Z1"], zone["Y1"]))
floor = np.array(points + [(points[-1][0], H), (points[0][0], H)], np.int32)
cv2.fillPoly(img, [floor], (60, 75, 95))
cv2.polylines(img, [np.array(points, np.int32)], False, (190, 230, 250), 2, cv2.LINE_AA)

# v1's floor, for comparison: 30 degrees from the end of the pier, then a 60-degree drop
v1 = [px(0, -30), px(260, -30), px(260, -110), px(2260, -1265), px(2560, -1785)]
for a, b in zip(v1, v1[1:]):
    cv2.line(img, a, b, (60, 60, 230), 2, cv2.LINE_AA)
cv2.putText(img, "v1 (too fast)", (v1[3][0] + 8, v1[3][1]), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (60, 60, 230), 2, cv2.LINE_AA)

# zone borders and names, with the depth the gauge would show and the time to ride through
for i, zone in enumerate(zones):
    x0, y0 = px(zone["Z0"], zone["Y0"])
    x1, _ = px(zone["Z1"], zone["Y1"])
    cv2.line(img, (x0, TOP), (x0, y0), (235, 235, 235), 1, cv2.LINE_AA)
    seconds = (zone["Z1"] - zone["Z0"]) / RIDE_SPEED
    mid = (x0 + x1) // 2
    row = TOP + 28 + (i % 2) * 34
    name = zone["Name"].title()
    size = cv2.getTextSize(name, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)[0][0]
    cv2.putText(img, name, (mid - size // 2, row), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
    detail = f"{zone['Metres']:,} m, {seconds:.0f} s"
    size = cv2.getTextSize(detail, cv2.FONT_HERSHEY_SIMPLEX, 0.42, 1)[0][0]
    cv2.putText(img, detail, (mid - size // 2, row + 15), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (225, 235, 245), 1, cv2.LINE_AA)

# distance ticks along the bottom, and the reference player's best run
for d in range(0, int(length), 2000):
    x, _ = px(d, 0)
    cv2.line(img, (x, H - 28), (x, H - 20), (255, 255, 255), 1)
    cv2.putText(img, f"{d:,}", (x - 18, H - 6), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)
x, _ = px(REFERENCE_BEST, 0)
cv2.line(img, (x, H - 60), (x, H - 30), (80, 220, 255), 2)
cv2.putText(img, "reference's best run", (x - 70, H - 64), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (80, 220, 255), 1, cv2.LINE_AA)

total = zones[-1]["Z1"]
deepest = -zones[-1]["Y1"]
title = (
    f"Blockout v2: {total:,} studs long, {deepest:,.0f} deep, about {total / RIDE_SPEED / 60:.0f} min end to end"
    f" at {RIDE_SPEED} studs/s.  Height drawn x{EXAGGERATE}."
)
cv2.putText(img, title, (LEFT, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.62, (40, 40, 40), 2, cv2.LINE_AA)
cv2.imwrite(out, img)
print(out, img.shape)
