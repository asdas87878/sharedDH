"""Captures for the land pictures in Play, through studio-runner (task l1; round one, u1, was run by hand).
    python tools/ui/land_icons/capture.py install        put the ZZShotCam LocalScript in (Edit)
    python tools/ui/land_icons/capture.py shots <plan.json> [names...]   with a playtest up: aim and shoot each
    python tools/ui/land_icons/capture.py release        let the camera go
    python tools/ui/land_icons/capture.py remove         take the LocalScript out and reset the mouse (Edit)
Pictures go to docs/attachments/land-icons/<name>.jpg, cropped to the game view.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "docs/attachments/land-icons"
WORK = ROOT / "work/land_icons"
WORK.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
VIEW = (3, 142, 1986, 1207)  # the game view inside a Studio shot (2400 x 1280)


def run(*args):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True)
    return (r.stdout + r.stderr).strip()


def luau_list(v):
    return "{" + ",".join(str(x) for x in v) + "}"


def shot(name):
    raw = WORK / "raw.png"
    run("shot", str(raw))
    time.sleep(0.8)
    run("shot", str(raw))
    for _ in range(5):
        try:
            Image.open(raw).convert("RGB").crop(VIEW).save(OUT / f"{name}.jpg", quality=90)
            return
        except OSError:
            time.sleep(1)
            run("shot", str(raw))


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        src = (HERE / "shotcam_client.luau").read_text()
        print(run(str(HERE / "install.luau"), "SOURCE=[=====[" + src + "]=====]"))
    elif what == "remove":
        print(run(str(HERE / "install.luau"), "REMOVE=true"))
        print(run("--code", "task.delay(0.5, function() game:GetService('UserInputService').MouseBehavior = "
                  "Enum.MouseBehavior.Default; workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end) return 'ok'"))
    elif what == "release":
        print(run("--ctx", "server", str(HERE / "aim.luau")))
    elif what == "shots":
        plan = json.loads(Path(sys.argv[2]).read_text())
        only = set(sys.argv[3:])
        for s in plan:
            if only and s["name"] not in only:
                continue
            print(s["name"], run("--ctx", "server", str(HERE / "aim.luau"), "CAM=" + luau_list(s["cam"])))
            time.sleep(3.5)  # the map streams in round the held character
            shot(s["name"])
        print(run("--ctx", "server", str(HERE / "aim.luau")))
