"""The fail text (task b5: the Slam band, Kit.failWords and FailController's "The words"): stills from a Studio playtest.
    python tools/studio/b5_fail_text_check.py install | remove   (in Edit, before Play: fail_capture's server Script)
    python tools/studio/b5_fail_text_check.py motion             (in a playtest: the band's motion, held frame by frame)
    python tools/studio/b5_fail_text_check.py lines              (every line, settled, through the Studio switch)
    python tools/studio/b5_fail_text_check.py fails              (real fails: out of breath, thrown, eaten, shaken off)
How: the motion and the lines use FailController's Studio switches (workspace FailWords, FailWordsAge, FailWordsOut,
FailWordsSub); the real fails ride a fish and fail it (RideService.forceFail) with the game's clocks held (FailClock,
DeathClock, FailSlow), as tools/studio/fail_capture.py does. Shots go to work/b5/, sheets to docs/attachments/.
"""
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fail_capture as fc  # noqa: E402

ROOT = fc.ROOT
OUT = ROOT / "work/b5"
OUT.mkdir(parents=True, exist_ok=True)
DOCS = ROOT / "docs/attachments"
fc.WIDTH = 900

LINES = ["OUT OF BREATH!", "THROWN OFF!", "EATEN!", "GULPED!", "DRAGGED DOWN!", "ROLLED OFF!", "FLIPPED OFF!",
         "SHAKEN OFF!", "FLUNG OFF!", "PINNED!", "MISSED THE FISH!", "TOO STRONG!"]


def shot(name, text):
    time.sleep(1.6)  # (Studio redraws a hidden window about once a second)
    return fc.label(fc.shot(OUT / f"{name}.png"), text)


def grid(frames, dest, cols):
    w, h = frames[0].size
    rows = (len(frames) + cols - 1) // cols
    canvas = Image.new("RGB", (w * cols, h * rows), (16, 18, 26))
    for i, f in enumerate(frames):
        canvas.paste(f, ((i % cols) * w, (i // cols) * h))
    canvas.save(dest)
    print(dest)


def motion():
    frames = []
    steps = [(0.03, 0, "0.03 s: the streak, a hairline"), (0.12, 0, "0.12 s: slashing open, the words coming"),
             (0.22, 0, "0.22 s: the words nearly down"), (0.29, 0, "0.29 s: landed: flash"),
             (0.33, 0, "0.33 s: the ring: squashed"), (0.42, 0, "0.42 s: the ring: bounced"),
             (0.62, 0, "0.62 s: the second line pops"), (1.5, 0, "settled"),
             (1.5, 0.45, "on the way out: 45%"), (1.5, 0.8, "on the way out: 80%")]
    fc.setw(FailWords="", FailWordsSub=True)
    time.sleep(0.5)
    for i, (age, out, text) in enumerate(steps):
        fc.setw(FailWordsAge=age, FailWordsOut=out, FailWords="OUT OF BREATH!")
        frames.append(shot(f"motion_{i}", text))
    fc.setw(FailWords="", FailWordsAge=-1, FailWordsOut=0)
    grid(frames, DOCS / "b5-fail-text-motion.png", 5)


def lines():
    frames = []
    for i, line in enumerate(LINES):
        fc.setw(FailWordsAge=2, FailWordsOut=0, FailWordsSub=i % 2 == 0, FailWords=line)
        im = shot(f"line_{i}", line + ("" if i % 2 == 0 else "   (no catch on the dive: no second line)"))
        w, h = im.size
        frames.append(im.crop((0, h // 4, w, h * 3 // 4)))
    fc.setw(FailWords="", FailWordsAge=-1, FailWordsSub=True)
    grid(frames, DOCS / "b5-fail-text-lines.png", 3)


def one(fish, outcome, name, text):
    """Rides `fish` and fails it as `outcome` (None: failed before it is seated, so not thrown: the plain run-out),
    and shoots the words part-way into the black and with the black whole."""
    taken = outcome in fc_taken()
    T = TIMES.get(outcome or "", 0)
    slow = 60 if T == 0 or taken else 20  # (a held throw-off waits T x slow before the drown)
    fc.setw(TestMaxOxygen=10000000, FailSlow=slow, FailClock=0, DeathClock=0, CatchLook=0)
    print(fc.cmd("ride|" + fish))
    if outcome is None:
        print(fc.cmd("fail|"))
    else:
        fc.wait_state({"Riding"})
        time.sleep(3)
        print(fc.cmd("fail|" + outcome))
    frames = []
    if taken:
        for k, dt in enumerate((0.3, 0.75)):
            fc.setw(FailClock=T + dt)
            frames.append(shot(f"{name}_{k}", f"{text}   (fail clock {T + dt:.2f} s)"))
    else:
        if T > 0:
            fc.setw(FailClock=T + 0.2)
        fc.wait_state({"Drowning"}, timeout=90)
        # the drown's own clock (DeathController): 2.9 s not thrown; thrown, a ragdoll's flight (RAG) and then 2.9 s.
        # The black is its last 1.35 s, and the words are set until 0.15 s before the end
        total = 2.9 if outcome is None else RAG + 2.9
        for k, back in enumerate((0.9, 0.25)):
            fc.setw(DeathClock=total - back)
            frames.append(shot(f"{name}_{k}", f"{text}   (drown clock {total - back:.2f} s)"))
    fc.setw(FailClock=-1, DeathClock=-1, FailSlow=1)
    print(fc.cmd("home"))
    time.sleep(4)
    return frames


RAG = 1.8  # Config.Fail.Ragdoll.Time
TIMES = {"Throw": 0, "Chomp": 2.3, "Gulp": 2.5, "Wrap": 3.0, "Roll": 1.7, "Flip": 1.5, "Shell": 1.6, "Coil": 1.9, "Pin": 2.4}


def fc_taken():
    return {"Chomp", "Gulp", "Wrap", "Pin"}


def fails(only=None):
    runs = [("Clownfish", None, "breath", "Out of Oxygen off a fish: OUT OF BREATH!"),
            ("Clownfish", "Throw", "throw", "Throw (Clownfish): THROWN OFF!"),
            ("ReefShark", "Chomp", "chomp", "Chomp (Reef Shark): EATEN!"),
            ("SeaTurtle", "Shell", "shell", "Shell (Sea Turtle): SHAKEN OFF!")]
    frames = []
    for fish, outcome, name, text in runs:
        if only and name not in only:
            continue
        got = one(fish, outcome, name, text)
        frames += got
        grid(got, OUT / f"fails-{name}.png", 2)
    if not only:
        grid(frames, DOCS / "b5-fail-text-fails.png", 2)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(fc.install())
    elif what == "remove":
        print(fc.install(remove=True))
    elif what == "motion":
        motion()
    elif what == "lines":
        lines()
    elif what == "fails":
        fails(sys.argv[2:])
