"""Reads the swatch (a 6-stud block of 83, 214, 100 at look_tests.SWATCH) off the "swatch" pictures of a lighting test:
its top (in the sun) and its two shaded sides, as the screen shows them.
usage: python tools/studio/look_swatch.py <folder> <variant><quality> ...      e.g. work/look ours21 sunA21
"""
import math
import sys

import numpy as np
from PIL import Image

CAM, AT, CENTRE, FOV = (3141, 9, -189), (3130, 3.5, -200), (3130, 3.5, -200), 70.0


def sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return tuple(x / n for x in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def pixel(point, w, h):
    fwd = unit(sub(AT, CAM))
    right = unit(cross(fwd, (0, 1, 0)))
    up = cross(right, fwd)
    d = sub(point, CAM)
    f = (h / 2) / math.tan(math.radians(FOV / 2))
    return w / 2 + dot(d, right) / dot(d, fwd) * f, h / 2 - dot(d, up) / dot(d, fwd) * f


def read(im, point, r=7):
    a = np.asarray(im, dtype=float)
    x, y = pixel(point, im.size[0], im.size[1])
    x, y = int(round(x)), int(round(y))
    return tuple(int(round(v)) for v in a[y - r:y + r + 1, x - r:x + r + 1].reshape(-1, 3).mean(0))


folder = sys.argv[1]
cx, cy, cz = CENTRE
print("%-10s %-16s %-16s %-16s" % ("look", "top (sun)", "side +x (shade)", "side +z (shade)"))
for name in sys.argv[2:]:
    im = Image.open("%s/%s_swatch.jpg" % (folder, name)).convert("RGB")
    print("%-10s %-16s %-16s %-16s" % (name, read(im, (cx, cy + 3, cz)), read(im, (cx + 3, cy, cz)), read(im, (cx, cy, cz + 3))))
