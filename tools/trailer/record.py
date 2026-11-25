"""Films the trailer mode (docs/design/trailer.md): Studio's Play, the screen recorder, a look sheet, the cut.

python tools/trailer/record.py probe                a few seconds of the screen: which recorder works here, its size
python tools/trailer/record.py all                  Play, take 1 (loads everything), take 2 (kept), stop, sheet, cut
 or a step at a time:
python tools/trailer/record.py play                 starts Play (sync src/ in Edit mode before)
python tools/trailer/record.py take OUT.mkv         all 20 shots, recorded (--shots 3,5: those; --no-record: OBS does it)
python tools/trailer/record.py stop                 stops Play and gives the mouse and the camera back
python tools/trailer/record.py sheet OUT.mkv        a picture of every shot's start, middle and end: OUT.jpg
python tools/trailer/cut.py OUT.mkv trailer.mp4     the video

Windows: Studio's own connector (STUDIO_ID set). Linux: ~/Projects/studio-runner/studio-run.mjs (or STUDIO_RUNNER).
Needs: pip install opencv-python numpy imageio-ffmpeg. Studio's window up, nothing over it, hands off.
"""
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "work/trailer"
WINDOWS = sys.platform == "win32"
RESET = (
    'task.delay(0, function() game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default '
    'workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end) task.wait(0.3) return "reset"'
)


class Studio:
    """Play, stop and a line of Luau, on either PC."""

    def __init__(self):
        if WINDOWS:
            sys.path.insert(0, str(ROOT / "tools/studio"))
            import play_pass

            self.c = play_pass.Client()
        else:
            self.run = os.environ.get("STUDIO_RUNNER") or os.path.expanduser("~/Projects/studio-runner/studio-run.mjs")

    def runner(self, *args):
        r = subprocess.run(["node", self.run, *args], capture_output=True, text=True, timeout=180)
        return (r.stdout + r.stderr).strip()

    def server(self, code):
        return self.c.lua("Server", code, 60) if WINDOWS else self.runner("--ctx", "server", "--code", code)

    def play(self):
        print(self.c.text(self.c.call("start_stop_play", 120, is_start=True)) if WINDOWS else self.runner("play"))

    def stop(self):
        print(self.c.text(self.c.call("start_stop_play", 120, is_start=False)) if WINDOWS else self.runner("stop"))
        time.sleep(8)
        if WINDOWS:
            print(self.c.lua("Edit", RESET, 60))
            return
        with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
            f.write(RESET)
        print(self.runner(f.name))
        os.unlink(f.name)


def ffmpeg():
    if shutil.which("ffmpeg"):
        return "ffmpeg"
    import imageio_ffmpeg

    return imageio_ffmpeg.get_ffmpeg_exe()


def recorders():
    """(name, command for a file) that record the whole screen here, best first."""
    x264 = ["-c:v", "libx264", "-preset", "ultrafast", "-crf", "14", "-pix_fmt", "yuv420p"]
    # (an odd screen size: yuv420p wants even ones)
    even = ["-vf", "crop=trunc(iw/2)*2:trunc(ih/2)*2"]

    def grab(kind, source):
        return lambda out: [ffmpeg(), "-y", "-loglevel", "error", "-f", kind, "-draw_mouse", "0", "-framerate", "60",
                            "-i", source, *even, *x264, out]

    if WINDOWS:
        return [("gdigrab", grab("gdigrab", "desktop"))]
    found = []
    if shutil.which("gpu-screen-recorder"):
        found.append(("gpu-screen-recorder", lambda out: [
            "gpu-screen-recorder", "-w", "screen", "-f", "60", "-q", "ultra", "-cursor", "no", "-o", out]))
    if os.environ.get("XDG_SESSION_TYPE") != "wayland" and os.environ.get("DISPLAY"):
        found.append(("x11grab", grab("x11grab", os.environ["DISPLAY"])))
    if shutil.which("wf-recorder"):
        found.append(("wf-recorder", lambda out: ["wf-recorder", "-r", "60", "-y", "-f", out]))
    return found


class Recording:
    def __init__(self, out, make):
        self.log = Path(str(out) + ".log")
        self.args = make(str(out))
        self.p = subprocess.Popen(self.args, stdin=subprocess.PIPE, stdout=open(self.log, "w"), stderr=subprocess.STDOUT)
        time.sleep(2)
        if self.p.poll() is not None:
            raise RuntimeError("the recorder stopped at once: " + self.log.read_text()[-400:])

    def end(self):
        if self.p.poll() is not None:
            print("the recorder had already stopped:", self.log.read_text()[-400:])
            return
        if "ffmpeg" in os.path.basename(self.args[0]):
            self.p.stdin.write(b"q")
            self.p.stdin.flush()
        else:
            self.p.send_signal(signal.SIGINT)
        try:
            self.p.wait(60)
        except subprocess.TimeoutExpired:
            self.p.kill()


def probe():
    """The first recorder whose picture is really a picture."""
    import cv2

    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in recorders():
        out = OUT / "probe.mkv"
        out.unlink(missing_ok=True)
        try:
            r = Recording(out, make)
            time.sleep(2)
            r.end()
        except Exception as e:
            print(f"{name}: {e}")
            continue
        cap, frames, last = cv2.VideoCapture(str(out)), 0, None
        while True:
            ok, f = cap.read()
            if not ok:
                break
            frames, last = frames + 1, f
        cap.release()
        out.unlink(missing_ok=True)
        if last is not None and last.std() > 8:
            print(f"{name}: {last.shape[1]}x{last.shape[0]}, {frames} frames in about 4 s")
            return name, make
        print(f"{name}: a blank picture")
    print("no recorder works here: record with OBS by hand (take OUT --no-record)")
    return None


def take(studio, out, shots="all", make=None):
    out.parent.mkdir(parents=True, exist_ok=True)
    studio.server('workspace:SetAttribute("TrailerStage", "") workspace:SetAttribute("TrailerRun", "") return 1')
    time.sleep(1)
    r = Recording(out, make) if make else None
    ended, seen, moved = False, "", time.time()
    try:
        studio.server(f'workspace:SetAttribute("TrailerRun", "{shots}") return 1')
        while time.time() - moved < 120:
            now = studio.server('return "stage<" .. tostring(workspace:GetAttribute("TrailerStage")) .. ">"')
            now = now.split("stage<", 1)[1].rsplit(">", 1)[0] if "stage<" in now else "no answer: " + now[-200:]
            if now != seen:
                seen, moved = now, time.time()
                print(time.strftime("%H:%M:%S"), now, flush=True)
            if now.startswith("done"):
                ended = True
                time.sleep(1)
                break
            time.sleep(1.5)
    finally:
        if r:
            r.end()
    print("the take finished" if ended else "STUCK: nothing new for two minutes", flush=True)
    return ended


def sheet(path):
    import cv2
    import numpy as np

    sys.path.insert(0, str(HERE))
    import cut

    view = cut.find_view(str(path))
    shots, fps = cut.find(str(path), view)
    if not shots:
        print("no shots found: was the slate on the screen, and nothing over it?")
        return
    cap, rows = cv2.VideoCapture(str(path)), []
    for n in sorted(shots):
        a, b = shots[n]
        row = []
        for u in (0.1, 0.5, 0.9):
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(a + (b - a) * u))
            ok, f = cap.read()
            f = cv2.resize(cut.crop(f, view), (384, 216), interpolation=cv2.INTER_AREA) if ok else np.zeros((216, 384, 3), np.uint8)
            cv2.putText(f, str(n), (8, 30), 0, 1, (0, 0, 0), 5)
            cv2.putText(f, str(n), (8, 30), 0, 1, (255, 255, 255), 2)
            row.append(f)
        rows.append(np.hstack(row))
    if len(rows) % 2:
        rows.append(np.zeros_like(rows[0]))
    half = len(rows) // 2
    to = Path(path).with_suffix(".jpg")
    cv2.imwrite(str(to), np.hstack([np.vstack(rows[:half]), np.vstack(rows[half:])]), [1, 80])
    print(f"{to}: shots {sorted(shots)}, the game at {view or 'the whole picture'}, {fps:.0f} frames a second")


def main():
    what, rest = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    shots, record = "all", "--no-record" not in rest
    if "--shots" in rest:
        i = rest.index("--shots")
        shots = rest[i + 1]
        del rest[i:i + 2]
    rest = [a for a in rest if not a.startswith("--")]
    if what == "probe":
        sys.exit(0 if probe() else 1)
    elif what == "sheet":
        sheet(rest[0])
    elif what in ("play", "stop"):
        getattr(Studio(), what)()
    elif what in ("take", "all"):
        found = probe() if record else None
        if record and not found:
            sys.exit(1)
        make, studio = found and found[1], Studio()
        if what == "take":
            sys.exit(0 if take(studio, Path(rest[0]), shots, make) else 1)
        studio.play()
        time.sleep(25)
        try:
            good = take(studio, OUT / "take1.mkv") and take(studio, OUT / "take2.mkv", "all", make)
        finally:
            studio.stop()
        if good and make:
            sheet(OUT / "take2.mkv")
            subprocess.run([sys.executable, str(HERE / "cut.py"), str(OUT / "take2.mkv"), str(OUT / "trailer.mp4")])
    else:
        print(__doc__)


main()
