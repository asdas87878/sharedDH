"""Captures for the land strip's option sheets (task s2): the game's own strip code (LandStrip.preview) in a Studio
playtest, many cells at once, each with its own switches.
    python tools/ui/land_icons/options_capture.py install | remove | probe
Used as a module by options_sheets.py: `cells([...])` lays strips out and `grab(...)` crops each one out of one shot.
Needs Studio open with the studio-runner plugin, Rojo serving this repo, and a playtest running (after `install`).
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "work/land_icons/options"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
VIEW = (3, 142, 1986, 1207)  # the game view inside the Studio window's screenshot (as strip_capture.py)
CELL_W, CELL_H = 310, 100  # a cell's holder before its scale (options_client.luau)


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def server(code):
    return run(["--ctx", "server", "--code", code])


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    return "[==[" + str(v) + "]==]"


def attrs(**kw):
    code = "local RS = game:GetService('ReplicatedStorage') "
    for k, v in kw.items():
        code += f"RS:SetAttribute('Opt{k}', {lua(v)}) "
    return server(code + "return 'ok'")


def install(remove=False):
    src = (HERE / "options_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZStripOptions")
if old then old:Destroy() end
if {lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZStripOptions"
s.Source = {lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


LISTEN = """local RS = game:GetService('ReplicatedStorage')
local SS = game:GetService('ServerStorage')
local log = SS:FindFirstChild('ZZOptLog') or Instance.new('StringValue')
log.Name = 'ZZOptLog' log.Parent = SS
if not RS:FindFirstChild('ZZOptReport') then
	local r = Instance.new('RemoteEvent') r.Name = 'ZZOptReport' r.Parent = RS
	r.OnServerEvent:Connect(function(_, text) log.Value = string.sub(log.Value .. '\\n' .. tostring(text), -3000) end)
end
return 'listening'"""


def listen():
    return server(LISTEN)


def log():
    return server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZOptLog') return v and v.Value or 'none'")


def cells(items, back=0.0, hide=True):
    """items: dicts with x, y, s, o (options), st (state). Shows them; returns the JSON sent."""
    data = json.dumps(items)
    attrs(Show=True, Back=back, HideHud=hide, Cells=data)
    return data


def shot(name, wait=1.5):
    time.sleep(wait)
    raw = OUT / "raw.png"
    for _ in range(2):
        run(["shot", str(raw)])
        time.sleep(0.4)
    for _ in range(6):
        try:
            im = Image.open(raw).convert("RGB").crop(VIEW)
            im.save(OUT / f"{name}.png")
            return im
        except OSError:
            time.sleep(1)
    raise RuntimeError("no shot")


def crop(view, item, pad=0):
    s = item.get("s", 2)
    x, y = item["x"], item["y"]
    return view.crop((int(x - pad), int(y - pad), int(x + CELL_W * s + pad), int(y + CELL_H * s + pad)))


def grab(name, items, back=0.0, hide=True, wait=1.5):
    """Lays the items out, takes one shot, returns (whole view, [each cell's picture])."""
    cells(items, back, hide)
    view = shot(name, wait)
    return view, [crop(view, it) for it in items]


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
        print(attrs(Show=False, Cells="[]", HideHud=False))
    elif what == "listen":
        print(listen())
    elif what == "log":
        print(log())
    elif what == "probe":
        view, got = grab("probe", [{"x": 0, "y": 0, "s": 2}, {"x": 700, "y": 0, "s": 1}])
        for i, g in enumerate(got):
            g.save(OUT / f"probe_{i}.png")
        print("probe", view.size)
