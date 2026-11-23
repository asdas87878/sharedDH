"""How crowded a tank is, by the game's own lap (AquariumService.show, 2026-11-23): each fish circles at its own height,
spread over the water by the golden ratio. For a set of fish at their real size (BaseScale, a Normal one) in water of a
given width, depth and height, over 240 moments:
  others    how many others each fish's box is inside, on average
  layers    how many layers, and how high, to lay them out with none touching (the fish that fit the floor at all)
usage: python tools/map/pen_crowd.py"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pen_bench import SETS, sized  # noqa: E402

MID = ["Archelon", "MantaRay", "Dunkleosteus", "ReefShark", "ReefShark", "Barracuda", "Barracuda", "SeaTurtle", "SeaTurtle", "Stingray", "Stingray"]
LATE = ["BlueWhale", "Kraken", "Megalodon", "Orca", "Orca", "Dunkleosteus", "Dunkleosteus", "Archelon", "Archelon", "MantaRay", "MantaRay",
        "ReefShark", "ReefShark", "ReefShark", "Barracuda", "Barracuda", "Barracuda"]
START = SETS["the Shallows' seven"]
PLOTS = {"stage 0: the Shallows' seven": START, "stage 2: eleven, middle": MID, "stage 5: seventeen, late": LATE}
MOMENTS, SWIM = 240, 5.0  # Config.Aquarium.SwimPace


def boxes(names, w, d, h, t):
    """every fish's box at a moment: centre, half sizes, heading"""
    out = []
    for i, name in enumerate(names, 1):
        fw, fh, fl, _ = sized(name)
        u = (i - 0.5) / len(names)
        rx = max(w / 2 - fl / 2 - 4, 4) * (0.45 + 0.5 * u)
        rz = max(d / 2 - fl / 2 - 4, 4) * (0.45 + 0.5 * u)
        y = 5 + (h - 10) * ((i * 0.618034) % 1)
        way = 1 if i % 2 == 0 else -1
        a = (i * 2.399963) % (2 * math.pi) + way * SWIM / max((rx + rz) / 2, 1) * t
        x, z = rx * math.cos(a), rz * math.sin(a)
        heading = math.atan2(way * rz * math.cos(a), -way * rx * math.sin(a))
        out.append((x, y, z, fl / 2, fw / 2, fh / 2, heading))
    return out


def meet(p, q):
    if abs(p[1] - q[1]) >= p[5] + q[5]:
        return False
    for a in (p[6], p[6] + math.pi / 2, q[6], q[6] + math.pi / 2):
        ux, uz = math.cos(a), math.sin(a)
        reach = sum(b[3] * abs(math.cos(b[6] - a)) + b[4] * abs(math.sin(b[6] - a)) for b in (p, q))
        if abs((p[0] - q[0]) * ux + (p[2] - q[2]) * uz) >= reach:
            return False
    return True


def others(names, w, d, h):
    total = 0
    for k in range(MOMENTS):
        b = boxes(names, w, d, h, k * 1.7)
        total += sum(i != j and meet(b[i], b[j]) for i in range(len(b)) for j in range(len(b)))
    return total / MOMENTS / len(names)


def floor_pack(names, w, d):
    """one layer: as many as lie flat with none touching (the order given); a stud may stick out each way"""
    taken, left = [], []
    for name in names:
        fw, _, fl, _ = sized(name)
        spot = None
        for sx, sz, yaw in ((fw, fl, 0), (fl, fw, 90)):
            if spot or sx > w + 2 or sz > d + 2:
                continue
            for z in range(0, int(d + 2 - sz) + 1):
                for x in range(0, int(w + 2 - sx) + 1):
                    if all(x + sx <= a or a2 <= x or z + sz <= c or c2 <= z for a, a2, c, c2, *_ in taken):
                        spot = (x, x + sx, z, z + sz, name, yaw)
                        break
                if spot:
                    break
        if spot:
            taken.append(spot)
        else:
            left.append(name)
    return taken, left


def layers(names, w, d, gap=1.5):
    """layers from the tallest down: (its height, what is in it). Fish too big for the floor are returned apart"""
    big = [n for n in names if not (floor_pack([n], w, d)[0])]
    left = sorted((n for n in names if n not in big), key=lambda n: (-sized(n)[1], -sized(n)[0] * sized(n)[2]))
    out = []
    while left:
        taken, left = floor_pack(left, w, d)
        out.append((max(sized(t[4])[1] for t in taken) + gap, taken))
    return out, big


if __name__ == "__main__":
    for label, names in PLOTS.items():
        for w, d, what in ((52, 84, "today's 52 x 84"), (49, 59, "a 50 x 60 pen"), (49, 38, "its back 38 only"), (40, 50, "inset 5 (E)")):
            ls, big = layers(names, w, d)
            print("%-28s %-16s %2d layers, %5.1f high; too long to lie inside: %s" % (label, what, len(ls), sum(a for a, _ in ls), ", ".join(big) or "none"))
            print("    others each is inside:", "  ".join("%d: %.1f" % (h, others(names, w, d, h)) for h in (14, 20, 29, 38, 50, 62, 74, 100)))
