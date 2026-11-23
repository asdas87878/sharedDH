"""Does a piece of a submarine stand between its name sign and the run's camera? (src/shared/SubModels.luau, SignUp)

usage: python tools/subs/sign_fit.py            prints, a tier, how far its pieces reach up the sign from the run camera
       python tools/subs/sign_fit.py --check    fails if a tier's name is covered, or stands nearer a piece than CLEAR

Why: SubModels puts the sign's lower edge SIGN_GAP over the model's tallest piece, but the sign stands over the tower
(2 studs ahead of the middle) and the run's camera looks from behind and above. A tall piece far behind the sign, like
Blue Streak's tail fin, is nearer the camera and so reaches higher in the picture than its own height: it covered the
name. This reads the models' own points from art/subs/<Id>/<Id>.glb and, for the camera at no speed, half and full
speed (SubController.cameraFor, the Ride branch: behind by Config.Sub.Distance + 8 x share, up by 10 - 3 x share, the
sub level), works out how high each point stands where the sign is. A tier that needs it gets `SignUp` in
SubModels.List: extra studs for its sign. Run it after a model is rebuilt or the run camera changes.
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import card_fit  # noqa: E402

ROOT = card_fit.ROOT
MODELS = os.path.join(ROOT, "src", "shared", "SubModels.luau")
CONFIG = os.path.join(ROOT, "src", "shared", "Config.luau")
SIGN_WIDE = 14  # the sign's box, studs (SubModels.dress)
SIGN_AHEAD = 2  # and how far ahead of the sub's middle it stands
BACK_PER_SHARE, UP, UP_PER_SHARE = 8, 10, -3  # SubController.cameraFor, the Ride branch
CLEAR = 1.0  # the least room between a piece and the letters' lower edge, as the picture has it, studs


def numbers():
    models = open(MODELS, encoding="utf-8").read()
    config = open(CONFIG, encoding="utf-8").read()
    tall = float(re.search(r"^local SIGN_TALL = ([\d.]+)", models, re.M).group(1))
    gap = float(re.search(r"^local SIGN_GAP = ([\d.]+)", models, re.M).group(1))
    sub = config[config.index("Config.Sub = {"):]
    back = float(re.search(r"^\tDistance = ([\d.]+)", sub, re.M).group(1))
    ups = {}
    for row in re.finditer(r"\{[^{}]*?Id = \"(\w+)\"[^{}]*?\}", models, re.S):
        up = re.search(r"SignUp = ([\d.]+)", row.group(0))
        ups[row.group(1)] = float(up.group(1)) if up else 0.0
    return tall, gap, back, ups


def reach(pts, back, share):
    """how high the model stands at the sign's place, seen from the run camera at this share of full speed"""
    d, h = back + BACK_PER_SHARE * share, UP + UP_PER_SHARE * share
    best, who = -1e9, None
    for x, y, z in pts:
        if z <= -SIGN_AHEAD:
            continue  # ahead of the sign: behind it in the picture
        k = (d + SIGN_AHEAD) / (d - z)
        if abs(x * k) > SIGN_WIDE / 2:
            continue
        at = h + (y - h) * k
        if at > best:
            best, who = at, (x, y, z)
    return best, who


if __name__ == "__main__":
    tall, gap, back, ups = numbers()
    bad = False
    rows = []
    for path in glob.glob(os.path.join(ROOT, "art", "subs", "*", "*.glb")):
        cid = os.path.basename(os.path.dirname(path))
        tier = json.load(open(path[:-4] + ".mesh.json", encoding="utf-8"))["tier"]
        rows.append((tier, cid, card_fit.points_of(path)))
    for tier, cid, pts in sorted(rows):
        top = max(p[1] for p in pts)
        low = max(12.5, top + gap + tall / 2) + ups.get(cid, 0.0) - tall / 2
        worst, who = max(reach(pts, back, share) for share in (0, 0.5, 1))
        room = low - worst
        state = "clear" if room >= CLEAR else ("COVERED" if room < 0 else "TOO NEAR")
        bad = bad or room < CLEAR
        print("%d %-15s top %5.1f  sign's lower edge %5.1f (SignUp %.1f)  pieces reach %5.1f (the point %5.1f, %5.1f, %5.1f)"
              "  room %+.1f  %s" % (tier, cid, top, low, ups.get(cid, 0.0), worst, *who, room, state))
    if "--check" in sys.argv:
        sys.exit(1 if bad else 0)
