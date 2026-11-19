"""The fail outcomes at 0 Oxygen from a Studio playtest (task f3). The ragdoll is real physics, and Studio redraws its
window only about once a second while it is hidden on another workspace, so a live run can't be filmed. Instead the
game records a live run of the fail (workspace FailRecord: FailController keeps every part of the loose body, each
frame) and plays it back on a second run (FailReplay) with its clocks held (FailClock, DeathClock), one frame at a
time, each shot after Studio has redrawn (about 2 s a frame).
    python tools/studio/fail_live_capture.py install | remove      (in Edit, before Play: fail_capture's server Script)
    python tools/studio/fail_live_capture.py gif <Fish> <Outcome> [suffix] [fps]
    python tools/studio/fail_live_capture.py sheet <name> <gif> ...
    python tools/studio/fail_live_capture.py stills <Fish> <Outcome> [suffix]   (two stills: fail-<outcome>-4a/b.png)
    python tools/studio/fail_live_capture.py stillsheet <name> <png> ...
GIFs go to docs/attachments/fail-<outcome>-<suffix>.gif (suffix 3 by default) and ~/Pictures/ride-a-fish/sheets/.
Needs Studio open with the studio-runner plugin and Rojo serving this repo. niri copies each shot to the clipboard: the
text that was there is put back at the end.
"""
import shutil
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fail_capture as fc  # noqa: E402

ROOT = fc.ROOT
OUT = ROOT / "work/fail_live"
OUT.mkdir(parents=True, exist_ok=True)
SHEETS = fc.SHEETS

# seconds held, and whether it is taken (Config.Fail.Outcomes; the ragdoll's flight 1.8 s after a throw)
TIMES = {"Throw": 0, "Chomp": 2.3, "Gulp": 2.5, "Wrap": 3.0, "Roll": 1.7, "Flip": 1.5, "Shell": 1.6, "Coil": 1.9, "Pin": 2.4}
TAKEN = {"Chomp", "Gulp", "Wrap", "Pin"}


def clipboard():
    try:
        return subprocess.run(["wl-paste", "-n", "-t", "text/plain"], capture_output=True, text=True, timeout=2).stdout
    except Exception:
        return None


def save(frames, durations, dest, colours=128):
    pal = [f.quantize(colors=colours, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    durations = list(durations)
    durations[-1] = max(durations[-1], 900)
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=durations, loop=0, optimize=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / dest.name)
    print(dest)


def gif(fish, outcome, suffix="3", fps=10):
    """One live run of the fail, recorded by the game (FailRecord), then played back frame by frame (FailReplay) with
    the clocks held, each frame shot after Studio has redrawn."""
    kept = clipboard()
    T = TIMES[outcome]
    taken = outcome in TAKEN
    rag = 1.8
    # (the game's own max Oxygen: a huge test max tames the fish at once and its CAUGHT banner covers the shot; and
    # endless air, so the fish waits for our fail: forceFail ignores the no-fail switches)
    fc.server("workspace:SetAttribute('TestMaxOxygen', nil) workspace:SetAttribute('SandboxEndlessAir', true) return 'ok'")
    # 1. the live run, recorded
    fc.setw(FailRecord=True, FailReplay=False, FailSlow=1, FailClock=-1, DeathClock=-1, CatchLook=0)
    print(fc.cmd("ride|" + fish))
    fc.wait_state({"Riding"})
    time.sleep(0.3)
    print("live:", fc.cmd("fail|" + outcome))
    time.sleep(1)
    fc.wait_state({"Dock"}, timeout=40)
    fc.setw(FailRecord=False)
    time.sleep(1.5)
    # 2. the playback
    n_out = int(round(T * fps)) + 1 if T > 0 else 0
    n_tail = int(round((0.8 if taken else rag + 1.6) * fps)) + 1
    slow = max(15, (n_out + 6) * 2.2 / max(T, 0.1))
    fc.setw(FailReplay=True, FailSlow=slow, FailClock=0, DeathClock=0)
    print(fc.cmd("ride|" + fish))
    fc.wait_state({"Riding"})
    time.sleep(0.3)
    frames = []
    # (no riding frames first: the time they take lets the fish be tamed, and its CAUGHT banner covers the shot)
    print("playback:", fc.cmd("fail|" + outcome))
    for i in range(n_out):
        t = i / fps
        fc.setw(FailClock=t)
        time.sleep(0.9)
        frames.append(label(fc.shot(OUT / f"{outcome}_{i:03d}.png"), f"{fish}: {outcome}   {t:4.2f} s"))
        print(f"\r{outcome} {i + 1}/{n_out}", end="", flush=True)
    print()
    if taken:
        for i in range(1, n_tail):
            t = T + i / fps
            fc.setw(FailClock=t)
            time.sleep(0.9)
            frames.append(label(fc.shot(OUT / f"{outcome}_f{i:03d}.png"), f"{fish}: {outcome}   {t:4.2f} s"))
    else:
        if T > 0:
            fc.setw(FailClock=T + 0.2)
        fc.wait_state({"Drowning"}, timeout=max(60, slow * T + 20))
        for i in range(n_tail):
            t = i / fps
            fc.setw(DeathClock=t)
            time.sleep(0.9)
            frames.append(label(fc.shot(OUT / f"{outcome}_d{i:03d}.png"), f"{fish}: {outcome}, thrown   +{T + t:4.2f} s"))
            print(f"\rtail {i + 1}/{n_tail}", end="", flush=True)
        print()
    fc.setw(FailClock=-1, DeathClock=-1, FailSlow=1, FailReplay=False)
    print(fc.cmd("home"))
    fc.wait_state({"Dock"}, timeout=30)
    dest = ROOT / "docs/attachments" / f"fail-{outcome.lower()}-{suffix}.gif"
    save(frames, [int(1000 / fps)] * len(frames), dest)
    if kept:
        subprocess.run(["wl-copy"], input=kept, text=True)
    return dest


# Two stills per outcome (Hugo, 2026-11-19: "stills are enough"): (a) the rider thrown off, (b) the key moment
# (swallowed, tangled, pinned, or the body come to rest). ("f", t): the fail's clock; ("d", t): the drown's after it.
STILLS = {
    "Throw": [("d", 0.45, "thrown off"), ("d", 1.5, "tumbled and come to rest")],
    "Chomp": [("f", 0.6, "tossed off its back"), ("f", 1.2, "in the jaws")],
    "Gulp": [("f", 1.1, "bucked over its head"), ("f", 1.5, "sucked into the mouth")],
    "Wrap": [("f", 0.6, "thrown off"), ("f", 1.7, "tangled in its arms")],
    "Roll": [("f", 0.95, "slid off its flank"), ("d", 1.0, "thrown, on the floor")],
    "Flip": [("f", 0.85, "dropped off its underside"), ("d", 0.8, "thrown, on the floor")],
    "Shell": [("f", 1.25, "bucked off the shell"), ("d", 0.8, "thrown")],
    "Coil": [("f", 1.0, "held on its coil"), ("f", 1.7, "flung")],
    "Pin": [("f", 0.6, "scraped off ahead"), ("f", 1.7, "pinned and dragged")],
}


def big_shot(path):
    path = Path(path)
    path.unlink(missing_ok=True)
    fc.run(["shot", str(path)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        now = path.stat().st_size if path.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    c = Image.open(path).convert("RGB").crop(fc.CROP)
    return c.resize((1200, round(c.height * 1200 / c.width)), Image.LANCZOS)


def stills(fish, outcome, suffix="4"):
    """The same record-and-replay as gif(), shooting only the outcome's two STILLS: fail-<outcome>-<suffix>a/b.png"""
    kept = clipboard()
    T = TIMES[outcome]
    fc.server("workspace:SetAttribute('TestMaxOxygen', nil) workspace:SetAttribute('SandboxEndlessAir', true) return 'ok'")
    fc.setw(FailRecord=True, FailReplay=False, FailSlow=1, FailClock=-1, DeathClock=-1, CatchLook=0)
    print(fc.cmd("ride|" + fish))
    fc.wait_state({"Riding"})
    time.sleep(0.3)
    print("live:", fc.cmd("fail|" + outcome))
    time.sleep(1)
    fc.wait_state({"Dock"}, timeout=40)
    fc.setw(FailRecord=False)
    time.sleep(1.5)
    fc.setw(FailReplay=True, FailSlow=30, FailClock=0, DeathClock=0)
    print(fc.cmd("ride|" + fish))
    fc.wait_state({"Riding"})
    time.sleep(0.3)
    print("playback:", fc.cmd("fail|" + outcome))
    out = []
    for k, (clock, t, words) in zip("ab", STILLS[outcome]):
        if clock == "f":
            fc.setw(FailClock=t)
        else:
            if T > 0:
                fc.setw(FailClock=T + 0.2)
            fc.wait_state({"Drowning"}, timeout=max(60, 30 * T + 20))
            fc.setw(DeathClock=t)
        time.sleep(1.6)
        im = big_shot(OUT / f"{outcome}_still_{k}.png")
        when = t if clock == "f" else T + t
        d = ImageDraw.Draw(im)
        d.text((16, 12), f"{fish}: {outcome}, {words}  ({when:.2f} s)", fill="white",
               font=ImageFont.load_default(size=30), stroke_width=3, stroke_fill="black")
        dest = ROOT / "docs/attachments" / f"fail-{outcome.lower()}-{suffix}{k}.png"
        im.save(dest)
        SHEETS.mkdir(parents=True, exist_ok=True)
        shutil.copy(dest, SHEETS / dest.name)
        out.append(dest)
        print(dest)
    fc.setw(FailClock=-1, DeathClock=-1, FailSlow=1, FailReplay=False)
    print(fc.cmd("home"))
    fc.wait_state({"Dock"}, timeout=30)
    if kept:
        subprocess.run(["wl-copy"], input=kept, text=True)
    return out


def still_sheet(name, pngs, cols=4, width=560):
    ims = [Image.open(p).convert("RGB") for p in pngs]
    ims = [i.resize((width, round(i.height * width / i.width)), Image.LANCZOS) for i in ims]
    w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    canvas = Image.new("RGB", (w * cols, h * rows), "black")
    for k, im in enumerate(ims):
        canvas.paste(im, ((k % cols) * w, (k // cols) * h))
    dest = ROOT / "docs/attachments" / name
    canvas.save(dest)
    shutil.copy(dest, SHEETS / dest.name)
    print(dest)


def label(im, text):
    d = ImageDraw.Draw(im)
    d.text((10, 8), text, fill="white", font=ImageFont.load_default(size=18), stroke_width=2, stroke_fill="black")
    return im


def sheet(name, gifs, cols=3, scale=0.62, step_ms=80):
    """All of them side by side, each resampled to one clock (step_ms a frame) so they play together."""
    seqs = []
    for g in gifs:
        im = Image.open(g)
        timeline = []
        t = 0
        try:
            while True:
                f = im.convert("RGB")
                f = f.resize((round(f.width * scale), round(f.height * scale)), Image.LANCZOS)
                timeline.append((t, f))
                t += im.info.get("duration", 100)
                im.seek(im.tell() + 1)
        except EOFError:
            pass
        seqs.append((timeline, t))
    total = max(t for _, t in seqs)
    w, h = seqs[0][0][0][1].size
    rows = (len(seqs) + cols - 1) // cols
    frames = []
    for now in range(0, total, step_ms):
        canvas = Image.new("RGB", (w * min(cols, len(seqs)), h * rows), "black")
        for k, (timeline, _) in enumerate(seqs):
            pick = timeline[0][1]
            for at, f in timeline:
                if at <= now:
                    pick = f
            canvas.paste(pick, ((k % cols) * w, (k // cols) * h))
        frames.append(canvas)
    dest = ROOT / "docs/attachments" / name
    save(frames, [step_ms] * len(frames), dest, 64)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "install":
        print(fc.install())
    elif a[0] == "remove":
        print(fc.install(True))
    elif a[0] == "gif":
        gif(a[1], a[2], a[3] if len(a) > 3 else "3", int(a[4]) if len(a) > 4 else 12)
    elif a[0] == "sheet":
        sheet(a[1], a[2:])
    elif a[0] == "stills":
        stills(a[1], a[2], a[3] if len(a) > 3 else "4")
    elif a[0] == "stillsheet":
        still_sheet(a[1], a[2:])
