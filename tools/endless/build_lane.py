"""Run the map's own generator (tools/map/greybox.py, not changed) in memory and dump its lane line, for the endless study.

  python tools/endless/build_lane.py today  <out folder>   the lane as it is in the game
  python tools/endless/build_lane.py chunks <out folder>   the same kit, laid out as joinable chunks: nine lands of
        3,000 studs, each two chunks of CHUNK studs; at a chunk's two ends both sides pinch together (the same neck
        for every chunk), the lane is straight and the floor has one slope, so any chunk's end meets any other's start

Writes parts.json and path.json (greybox's own) and line.json (every 4 studs: s, x, y, z, heading, half left, half right).
Needs numpy and Pillow; about 40 seconds. Nothing in art/map or tools/map is touched (GREYBOX_OUT)."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "map", "greybox.py")
MARGIN, CHUNK, SLOPE, GROW = 300.0, 1200.0, 6.0, 2.8
# each chunk's two bends, in degrees (mirroring gives the other hand). Two chunks a land, of like net turn, so the long
# lane they are built on comes back to its heading by itself
TURNS = [(16, 14), (17, 15), (20, -20), (22, -18), (20, 6), (8, 18), (12, 22), (16, 17), (-18, 16),
         (20, -20), (22, 14), (20, 14), (14, 20), (22, 10), (22, -14), (18, -10), (17, 17), (10, 22)]


def swap(src, old, new, n=1):
    assert src.count(old) >= 1, old
    return src.replace(old, new) if n == 0 else src.replace(old, new, n)


def main(mode, out):
    out = os.path.abspath(out)
    os.makedirs(out, exist_ok=True)
    os.environ["GREYBOX_OUT"] = out
    os.environ["PROPS2"] = "1"
    os.environ["PALETTE"] = os.path.join(ROOT, "art/map/palettes/proposal.json")
    os.chdir(ROOT)
    src = open(SRC).read()
    if mode == "chunks":
        far = 1000.0 + 9 * 3000.0
        src = swap(src, "BUILD_TO = 23500.0", f"BUILD_TO = {far}")
        src = swap(src, "FINE_TO = 23500.0", f"FINE_TO = {far}")
        a = src.index("LANDS = [(")
        b = src.index("STEEPER = {")
        src = src[:b] + f"LANDS = [(n, 1000 if i == 0 else 3000, {SLOPE}) for i, (n, _l, _s) in enumerate(LANDS)]\n" + src[b:]
        a = src.index("STEEPER = {")
        b = src.index("\n", a)
        src = src[:a] + "STEEPER = {}" + src[b:]
        # the rooms: a margin, two chunks of two rooms, a margin, in every land after the first
        src = swap(src, "# each side's own spans, pinch to pinch.", f"""
TURNS_ = {TURNS!r}
rooms, joints_ = [], []
rooms.append({{"s0": 0.0, "s1": 330.0, "land": 0}})
rooms.append({{"s0": 330.0, "s1": 1000.0, "land": 0}})
for li_ in range(1, 10):
    at_ = starts[li_]
    marks_ = [0.0, {MARGIN}, {MARGIN + CHUNK / 2}, {MARGIN + CHUNK}, {MARGIN + CHUNK * 1.5}, {MARGIN + CHUNK * 2}, 3000.0]
    joints_ += [at_ + {MARGIN}, at_ + {MARGIN + CHUNK}, at_ + {MARGIN + CHUNK * 2}]
    for k_ in range(6):
        rooms.append({{"s0": at_ + marks_[k_], "s1": at_ + marks_[k_ + 1], "land": li_}})
        c_ = (li_ - 1) * 2 + (0 if k_ < 3 else 1)
        # (the lane as a whole must not curl up on itself while it is being built: every other chunk is turned the
        # other way, and the margins give the rest back)
        rooms[-1]["turn"] = 0.0 if k_ in (0, 5) else float(TURNS_[c_][(k_ - 1) % 2]) * (1 if c_ % 2 == 0 else -1)
    bal_ = -sum(r_["turn"] for r_ in rooms if r_["land"] == li_)
    rooms[-1]["turn"] = max(-24.0, min(24.0, bal_))
swing_ = 0.0
for r_ in rooms:
    r_.setdefault("turn", 0.0)
for i_, r_ in enumerate(rooms):
    r_["seed"] = i_
# each side's own spans, pinch to pinch.""")
        src = swap(src, "for side, pinches in ((-1, left_p), (1, right_p)):", """
for i_ in range(2, len(right_p)):  # both sides pinch together at a joint; between two joints the right keeps its own place
    near_ = min(joints_, key=lambda j_: abs(j_ - left_p[i_]))
    if abs(near_ - left_p[i_]) < 1.0:
        right_p[i_] = left_p[i_]
for side, pinches in ((-1, left_p), (1, right_p)):""")
        src = swap(src, "    return 1.0 + WIDER * max(0.0, at) / TOTAL", f"    return 1.0 + {GROW - 1} * smooth(at / 1000.0)")
        src = swap(src, "        long = 220.0 * grow(room[\"s1\"])\n", "        long = max(120.0, room[\"s1\"] - room[\"s0\"] - 120.0)\n")
        src = swap(src, "smooth((at - room[\"s1\"] + long / 2) / long)", "smooth((at - (room[\"s0\"] + room[\"s1\"]) / 2 + long / 2) / long)")
        src += "\nJOINTS_OUT = joints_\n"
    src += """
import json as json_
json_.dump({"Line": [[k * 4.0, *[round(v, 4) for v in centre(k * 4.0)], round(heading(k * 4.0), 6), round(half(-1, k * 4.0), 3), round(half(1, k * 4.0), 3)]
                     for k in range(int(BUILD_TO / 4) + 1)], "Joints": globals().get("JOINTS_OUT", []), "Starts": starts,
            "Necks": necks}, open(os.path.join(OUT, "line.json"), "w"))
"""
    sys.path.insert(0, os.path.dirname(SRC))
    sys.argv = [SRC]
    exec(compile(src, SRC, "exec"), {"__file__": SRC, "__name__": "__main__"})


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
