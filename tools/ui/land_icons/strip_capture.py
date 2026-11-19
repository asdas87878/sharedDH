"""Shots of the new land strip (style 1) for the sheet and the GIF (task l1). Needs a playtest with ZZStripPreview
installed (capture.py install-preview) and, for the in-game shots, the workspace's LandStripStyle = 1 and LandAtlas set
(capture.py style-on) before Play.
    python tools/ui/land_icons/strip_capture.py numbers | reveal | gif | phone | game | clear
Pictures go to work/land_icons/strip/ (not kept in the repo), cropped to the game view.
"""
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "work/land_icons/strip"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
VIEW = (3, 142, 1986, 1207)


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"' + v + '"'
    if v is None:
        return "nil"
    return str(v)


def server(code):
    r = subprocess.run(["node", RUN, "--ctx", "server", "--code", code], capture_output=True, text=True)
    return (r.stdout + r.stderr).strip()


def prev(**kw):
    code = "local RS = game:GetService('ReplicatedStorage') "
    for k, v in kw.items():
        code += f"RS:SetAttribute('Prev{k}', {lua(v)}) "
    return server(code + "return 'ok'")


def shot(name, wait=1.2):
    time.sleep(wait)
    raw = OUT / "raw.png"
    subprocess.run(["node", RUN, "shot", str(raw)], capture_output=True)
    time.sleep(0.5)
    subprocess.run(["node", RUN, "shot", str(raw)], capture_output=True)
    for _ in range(5):
        try:
            Image.open(raw).convert("RGB").crop(VIEW).save(OUT / f"{name}.png")
            print("shot", name)
            return
        except OSError:
            time.sleep(1)


BEST = dict(BestLands=4.4, BestMetres=400)

if __name__ == "__main__":
    what = sys.argv[1]
    if what == "numbers":
        for n in (1, 2, 3):
            prev(Show=True, Back=0, Scale=3, Numbers=n, Reveal="Dive", Touch=False, Land=3, Along=0.5, Metres=245, **BEST)
            shot(f"num_N{n}")
            prev(Land=10, Along=1, Metres=2223, BestLands=10, BestMetres=2223)
            shot(f"num_N{n}_all")
    elif what == "reveal":
        for mode in ("Dive", "Best"):
            prev(Show=True, Back=0, Scale=3, Numbers=2, Reveal=mode, Touch=False, Land=1, Along=0.12, Metres=1, **BEST)
            shot(f"rev_{mode}_start")
            prev(Land=6, Along=0.35, Metres=830, BestLands=4.4, BestMetres=400)
            shot(f"rev_{mode}_past")
    elif what == "gif":
        prev(Show=True, Back=0, Scale=3, Numbers=int(sys.argv[2]) if len(sys.argv) > 2 else 2, Reveal="Dive", Touch=False, BestLands=4.4, BestMetres=400)
        # each land's floor depth where it starts, one metre a stud (2026-11-19), and the lane's end
        metres = [46, 81, 190, 321, 497, 740, 959, 1221, 1566, 1873, 2223]
        i = 0
        for k in range(0, 41):
            p = k / 4  # lands, 0 to 10
            land = min(int(p) + 1, 10)
            along = p - (land - 1)
            m = metres[land - 1] + (metres[land] - metres[land - 1]) * along
            bl, bm = (4.4, 400) if p < 4.4 else (p, m)
            prev(Land=land, Along=along, Metres=round(m), BestLands=bl, BestMetres=round(bm))
            shot(f"gif_{i:03d}", wait=0.4)
            i += 1
    elif what == "phone":
        for n in (1, 2, 3):
            prev(Show=True, Back=1, HideHud=True, Scale=1, Numbers=n, Reveal="Dive", Touch=True, Land=3, Along=0.5, Metres=245, **BEST)
            shot(f"phone_N{n}")
        prev(HideHud=False)
    elif what == "clear":
        print(prev(Show=False))
