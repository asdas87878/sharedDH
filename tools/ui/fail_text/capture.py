"""The fail-text options sheet (task o2, 2026-11-22): six looks for the words of a failed run, every fail line each,
built as real Roblox UI by options.luau in Studio's Edit view (a ScreenGui in CoreGui, removed after) over the Coral
Reef's lane, dimmed as the fail's fade dims it.
    python tools/ui/fail_text/capture.py shoot    # needs Studio in Edit with the studio-runner plugin; no playtest
    python tools/ui/fail_text/capture.py sheet    # docs/attachments/fail-text-options-2026-11-22.png from the shots
Shots go to work/fail_text/o<n>.png. VIEW is the game view inside the Studio window as it was laid out that day.
"""
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "work/fail_text"
DEST = ROOT / "docs/attachments/fail-text-options-2026-11-22.png"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
VIEW = (778, 141, 1986, 1210)
CAM = "CFrame.lookAt(Vector3.new(2990, -62, 1500), Vector3.new(2900, -125, 2100))"

OPTIONS = [
    ("Slam band", "the house style (GREAT DIVE, CAUGHT): Bangers in hard red metal on a tilted dark streak; always red",
     "in: the streak slashes open from a hairline, the words slam on from the camera and ring; out: drops away with the black"),
    ("Bubble letters", "every letter its own fat bubble letter in the outcome's colour, bubbles round the word",
     "in: letters pop up one by one, then bob; out: they float up and pop"),
    ("Sticker", "a tilted sticker in the outcome's colour with a white rim, chunky white letters",
     "in: slapped on with a squash and a small screen shake; out: peels off downwards"),
    ("Comic burst", "a spiky burst in the outcome's colour, yellow comic letters, the outcome's emoji",
     "in: the burst pops with an overshoot, spikes turning a little; out: shrinks to a point"),
    ("Sinking word", "no plate: the word itself goes under, each letter lower, more turned and fainter",
     "in: fades in level, then the end of the word slowly sinks and trails bubbles; out: the whole word sinks into the black"),
    ("Hazard tape", "warning tape pulled across the screen, black letters, the outcome's emoji in a disc",
     "in: the tape shoots across from the left and snaps taut; out: snaps off to the right"),
]


def run(args):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=180)
    return (r.stdout + r.stderr).strip()


def shoot():
    OUT.mkdir(parents=True, exist_ok=True)
    print(run(["--code", f'local c = workspace.CurrentCamera workspace:SetAttribute("FailTextCam", c.CFrame) c.CFrame = {CAM} return "camera set"']))
    for n in range(1, len(OPTIONS) + 1):
        print(run([str(HERE / "options.luau"), f"OPTION={n}"]))
        shot = OUT / f"o{n}.png"
        shot.unlink(missing_ok=True)
        time.sleep(2.5)
        run(["shot", str(shot)])
        time.sleep(3)  # (the shot is written after the command returns)
    print(run([str(HERE / "options.luau"), "OPTION=0"]))
    print(run(["--code", 'local o = workspace:GetAttribute("FailTextCam") if o then workspace.CurrentCamera.CFrame = o end workspace:SetAttribute("FailTextCam", nil) return "camera back"']))


def font(size, bold=True):
    for name in (["DejaVuSans-Bold.ttf"] if bold else []) + ["DejaVuSans.ttf"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet():
    cols, pw = 3, 1100
    panels = []
    for n in range(1, len(OPTIONS) + 1):
        im = Image.open(OUT / f"o{n}.png").convert("RGB").crop(VIEW)
        panels.append(im.resize((pw, round(im.height * pw / im.width)), Image.LANCZOS))
    ph = panels[0].height
    pad, head, cap = 28, 150, 116
    rows = (len(panels) + cols - 1) // cols
    W = pad + cols * (pw + pad)
    H = head + rows * (cap + ph + pad)
    s = Image.new("RGB", (W, H), (22, 25, 34))
    d = ImageDraw.Draw(s)
    d.text((pad, 24), "Fail text: six looks for the words of a failed run (pick a number)", font=font(44), fill="white")
    d.text((pad, 84), "Real Roblox UI (Studio, a test ScreenGui, removed after) over the Coral Reef, dimmed as the fail's fade dims it. Roblox's own fonts and emoji: nothing uploaded.",
           font=font(22, False), fill=(190, 200, 220))
    d.text((pad, 114), "Each panel: OUT OF BREATH! (the plain run-out) and one line per outcome: Throw, Chomp, Gulp, Wrap, Roll, Flip, Shell, Coil, Pin. Words and motion are proposals; the live text is unchanged.",
           font=font(22, False), fill=(190, 200, 220))
    for i, (im, (name, what, motion)) in enumerate(zip(panels, OPTIONS)):
        x = pad + (i % cols) * (pw + pad)
        y = head + (i // cols) * (cap + ph + pad)
        d.text((x, y + 6), f"{i + 1}  {name}", font=font(38), fill=(255, 210, 63))
        d.text((x, y + 56), what, font=font(20, False), fill="white")
        d.text((x, y + 84), motion, font=font(18, False), fill=(170, 182, 205))
        s.paste(im, (x, y + cap))
    s.save(DEST, optimize=True)
    print(DEST, s.size)


if __name__ == "__main__":
    {"shoot": shoot, "sheet": sheet}[sys.argv[1]]()
