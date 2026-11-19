"""The fail outcomes at 0 Oxygen, filmed live from a Studio playtest (task f3): the ragdoll is real physics, so the
game's clock can't be held frame by frame (tools/studio/fail_capture.py does that, for the scripted parts only). This
takes pictures of the Studio window as fast as niri gives them (about 10 a second), timestamped, while the fail plays
at its own speed, and makes a GIF with each frame shown for as long as it really lasted.
    python tools/studio/fail_live_capture.py install | remove      (in Edit, before Play: fail_capture's server Script)
    python tools/studio/fail_live_capture.py gif <Fish> <Outcome> [suffix] [fps]
    python tools/studio/fail_live_capture.py sheet <name> <gif> ...
GIFs go to docs/attachments/fail-<outcome>-<suffix>.gif (suffix 3 by default) and ~/Pictures/ride-a-fish/sheets/.
Needs Studio open with the studio-runner plugin and Rojo serving this repo. niri copies each shot to the clipboard: the
text that was there is put back at the end.
"""
import json
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
WIDTH = 560

# seconds held, and whether it is taken (Config.Fail.Outcomes; the ragdoll's flight 1.8 s after a throw)
TIMES = {"Throw": 0, "Chomp": 2.3, "Gulp": 2.5, "Wrap": 3.0, "Roll": 1.7, "Flip": 1.5, "Shell": 1.6, "Coil": 1.9, "Pin": 2.4}
TAKEN = {"Chomp", "Gulp", "Wrap", "Pin"}


def window_id():
    windows = json.loads(subprocess.run(["niri", "msg", "--json", "windows"], capture_output=True, text=True).stdout)
    studio = [w for w in windows if "robloxstudio" in (w.get("app_id") or "").lower() or (w.get("title") or "").endswith(" - Roblox Studio")]
    studio.sort(key=lambda w: -w["layout"]["window_size"][0] * w["layout"]["window_size"][1])
    return studio[0]["id"]


def clipboard():
    try:
        return subprocess.run(["wl-paste", "-n", "-t", "text/plain"], capture_output=True, text=True, timeout=2).stdout
    except Exception:
        return None


def film(seconds, fps, tag):
    """Shots of the window for `seconds`, as close to `fps` a second as niri allows: [(time, path)]."""
    wid = window_id()
    shots = []
    t0 = time.time()
    i = 0
    while time.time() - t0 < seconds:
        path = OUT / f"{tag}_{i:04d}.png"
        path.unlink(missing_ok=True)
        at = time.time() - t0
        subprocess.run(["niri", "msg", "action", "screenshot-window", "--id", str(wid), "--path", str(path)])
        shots.append((at, path))
        i += 1
        wait = (i / fps) - (time.time() - t0)
        if wait > 0:
            time.sleep(wait)
    # (niri writes them after it returns)
    end = time.time() + 15
    while time.time() < end and not all(p.exists() and p.stat().st_size > 0 for _, p in shots):
        time.sleep(0.2)
    time.sleep(0.5)
    return [(a, p) for a, p in shots if p.exists() and p.stat().st_size > 0]


def frame(path, text):
    im = Image.open(path).convert("RGB")
    c = im.crop(fc.CROP)
    c = c.resize((WIDTH, round(c.height * WIDTH / c.width)), Image.LANCZOS)
    d = ImageDraw.Draw(c)
    d.text((10, 8), text, fill="white", font=ImageFont.load_default(size=18), stroke_width=2, stroke_fill="black")
    return c


def save(frames, durations, dest, colours=128):
    pal = [f.quantize(colors=colours, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    durations = list(durations)
    durations[-1] = max(durations[-1], 900)
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=durations, loop=0, optimize=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / dest.name)
    print(dest)


def gif(fish, outcome, suffix="3", fps=12):
    kept = clipboard()
    T = TIMES[outcome]
    tail = 1.0 if outcome in TAKEN else 1.8 + 1.6
    # (the game's own max Oxygen: a huge test max tames the fish at once and its CAUGHT banner covers the shot)
    # (and endless air, so the fish waits for our fail: forceFail ignores the no-fail switches)
    fc.server("workspace:SetAttribute('TestMaxOxygen', nil) workspace:SetAttribute('SandboxEndlessAir', true) return 'ok'")
    fc.setw(FailSlow=1, FailClock=-1, DeathClock=-1, CatchLook=0)
    print(fc.cmd("ride|" + fish))
    fc.wait_state({"Riding"})
    time.sleep(0.7)
    # the fail is asked for half a second into the filming, so a moment of riding comes first
    import threading

    def go():
        time.sleep(0.6)
        print(fc.cmd("fail|" + outcome))

    threading.Thread(target=go).start()
    shots = film(0.6 + 0.3 + T + tail, fps, outcome)
    print(f"{len(shots)} shots")
    frames, durations = [], []
    for k, (at, path) in enumerate(shots):
        t = at - 0.6 - 0.25
        label = f"{fish}: riding, Oxygen hits 0" if t < 0 else f"{fish}: {outcome}   {t:4.2f} s"
        frames.append(frame(path, label))
        nxt = shots[k + 1][0] if k + 1 < len(shots) else at + 1 / fps
        durations.append(max(20, int(round((nxt - at) * 1000))))
    fc.wait_state({"Dock", "Free", "Riding"}, timeout=40)
    time.sleep(1.5)
    dest = ROOT / "docs/attachments" / f"fail-{outcome.lower()}-{suffix}.gif"
    save(frames, durations, dest)
    if kept:
        subprocess.run(["wl-copy"], input=kept, text=True)
    return dest


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
