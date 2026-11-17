"""Captures for the size text options (task u2). Run with a playtest up and ZZSizeMock installed (run_install.py):
    python tools/ui/size_text/capture.py <scene> [versions...]
scene: ride (onto a fish, wait), freeze, near, crowd, far, dark-go, dark, grid, gif, unfreeze
Pictures go to work/size_text/ (not kept in the repo), cropped to the game view.
"""
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "work/size_text"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
VERSIONS = ["Now", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8"]
VIEW = (3, 142, 1986, 1207)  # the game view inside a Studio shot (2400 x 1280)
stamp = int(time.time()) % 100000


def drive(**kw):
    global stamp
    stamp += 1
    args = [f"STAMP={stamp}"]
    for k, v in kw.items():
        if isinstance(v, str):
            v = '"' + v + '"'
        elif isinstance(v, bool):
            v = "true" if v else "false"
        elif isinstance(v, (list, tuple)):
            v = "{" + ",".join(str(x) for x in v) + "}"
        args.append(f"{k}={v}")
    r = subprocess.run(["node", RUN, "--ctx", "server", str(HERE / "drive.luau"), *args], capture_output=True, text=True)
    print(r.stdout.strip(), r.stderr.strip())


def shot(name):
    raw = OUT / "raw.png"
    subprocess.run(["node", RUN, "shot", str(raw)], check=True, capture_output=True)
    Image.open(raw).convert("RGB").crop(VIEW).save(OUT / f"{name}.png")
    print("shot", name)


def scene(name, versions, **kw):
    for v in versions:
        drive(VERSION=v, **kw)
        time.sleep(1.6)
        shot(f"{name}_{v}")


if __name__ == "__main__":
    what = sys.argv[1]
    vs = sys.argv[2:] or VERSIONS
    if what == "ride":
        drive(VERSION="Now", RIDE=stamp + 1)
    elif what == "freeze":
        drive(VERSION="Now", FREEZE=stamp + 1)
    elif what == "unfreeze":
        drive(VERSION="Now", FREEZE=0)
    elif what in ("near", "crowd"):
        scene(what, vs, SET=what)
    elif what == "far":
        scene(what, vs, SET="far", BACK=55)
    elif what == "dark-go":
        # land 7, Midnight: hold the character there so the herd is made round it
        drive(VERSION="Now", FREEZE=0, EYE=[2840, -1020, 14180], AT=[2980, -1040, 14240])
    elif what == "dark":
        scene(what, vs, SET="dark")
    elif what == "grid":
        scene("grid", vs, MODE="grid", ZOOM=float(sys.argv[3]) if False else 1.9)
    elif what == "gif":
        # frames of one version's grid, every 0.1 s over 2.6 s (one gold sweep)
        v = vs[0]
        for i in range(27):
            drive(VERSION=v, MODE="grid", ZOOM=1.9, CLOCK=round(i * 0.1, 2))
            time.sleep(0.6)
            shot(f"gif_{v}_{i:02d}")
