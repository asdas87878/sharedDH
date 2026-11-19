"""Oxygen ring B, third pass (task x2, 2026-11-19): a full fish at 4500 max Oxygen, two rings of 2250 (one thin ring,
ever), the thin ring emptying first, then the big ring, then its red last third (Config.redLine) in five even ticks.
The ticks a little slower: 50 a meter with a 0.25 s floor (Oxygen.TickSize 6), RedTicks 5.
    python tools/ui/oxygen_trail/ring_b3_capture.py plan [seconds]
    python tools/ui/oxygen_trail/ring_b3_capture.py live <slow> <x0,y0,x1,y1> [seconds]
Same driving as ring_b2_capture.py (trail_capture.py install, then listen; ticklog there checks the real server).
Writes docs/attachments/oxygen-trail-b-3.gif and copies it to ~/Pictures/ride-a-fish/sheets/.
"""
import sys

import ring_b2_capture as b2
import trail_capture as tc

b2.MAX = 4500
b2.TICKS = 50
b2.FLOOR = 0.25
b2.RED_AT = 1 / 3 / 2  # a third of the big ring, which holds half the meter (Config.redLine)
b2.RED_TICKS = 5

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "plan":
        p, end = b2.plan(float(sys.argv[2]) if len(sys.argv) > 2 else 9)
        for e in p["events"]:
            print(e, f"{(e[1] - e[2]) / b2.MAX * 2 * 100:.1f}% of a ring")
        print("ticks", len(p["events"]), "end", end)
    elif cmd == "live":
        p, end = b2.plan(float(sys.argv[4]) if len(sys.argv) > 4 else 9)
        tc.PLAN, tc.END = p, end
        tc.LETTER[2] = "b-3"
        tc.NAMES[2] = "ring B, 2 rings at 4500"
        crop = tuple(int(x) for x in sys.argv[3].split(","))
        print(tc.live(2, float(sys.argv[2]), crop))
