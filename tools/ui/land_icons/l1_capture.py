"""Captures for the land strip as Hugo picked it (task l1): the game's own strip code (LandStrip.preview) in a Studio
playtest, through l1_client.luau.
    python tools/ui/land_icons/l1_capture.py install | remove | listen | log | probe
Used as a module by l1_sheets.py. Needs Studio open with the studio-runner plugin, Rojo serving this repo, and a playtest
running (after `install`), and the atlas copied into Studio (atlas.py --gen 4 --studio).
"""
import json
import sys
import tempfile
import time

from PIL import Image

import options_capture as base

ROOT = base.ROOT
OUT = ROOT / "work/land_icons/l1"
OUT.mkdir(parents=True, exist_ok=True)
VIEW = base.VIEW
run, server, lua = base.run, base.server, base.lua


def attrs(**kw):
    code = "local RS = game:GetService('ReplicatedStorage') "
    for k, v in kw.items():
        code += f"RS:SetAttribute('L1{k}', {lua(v)}) "
    return server(code + "return 'ok'")


def install(remove=False):
    src = (base.HERE / "l1_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZStripL1")
if old then old:Destroy() end
if {lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZStripL1"
s.Source = {lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


LISTEN = """local RS = game:GetService('ReplicatedStorage')
local SS = game:GetService('ServerStorage')
local log = SS:FindFirstChild('ZZL1Log') or Instance.new('StringValue')
log.Name = 'ZZL1Log' log.Parent = SS
if not RS:FindFirstChild('ZZL1Report') then
	local r = Instance.new('RemoteEvent') r.Name = 'ZZL1Report' r.Parent = RS
	r.OnServerEvent:Connect(function(_, text) log.Value = string.sub(log.Value .. '\\n' .. tostring(text), -3000) end)
end
return 'listening'"""


def listen():
    return server(LISTEN)


def log():
    return server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZL1Log') return v and v.Value or 'none'")


def cells(items, back=0.0, hide=True, slow=1):
    attrs(Show=True, Back=back, HideHud=hide, Slow=slow, States="", Cells=json.dumps(items))


def states(list_):
    attrs(States=json.dumps(list_))


DO = [0]


def intro(cell, land, metres, new=False):
    DO[0] += 1
    attrs(Do=json.dumps({"n": DO[0], "cell": cell, "land": land, "metres": metres, "new": new}))


def shot(name, wait=1.0, fresh=True):
    """fresh: two shots, the first can be the screen from before (as options_capture's); off for fast frame runs"""
    time.sleep(wait)
    raw = OUT / "raw.png"
    for _ in range(2 if fresh else 1):
        run(["shot", str(raw)])
    for _ in range(6):
        try:
            im = Image.open(raw).convert("RGB").crop(VIEW)
            im.save(OUT / f"{name}.png")
            return im
        except OSError:
            time.sleep(1)
    raise RuntimeError("no shot")


def crop(view, item, w=None, h=None, pad=0):
    s = item.get("s", 2)
    x, y = item["x"], item["y"]
    w = w or item.get("w", 310)
    h = h or item.get("h", 100)
    return view.crop((int(x - pad), int(y - pad), int(x + w * s + pad), int(y + h * s + pad)))


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
        cells([{"x": 0, "y": 0, "s": 3, "st": {"land": 6, "along": 0.5, "metres": 600, "best": 7.4, "bestMetres": 1300}}])
        view = shot("probe", 2.5)
        crop(view, {"x": 0, "y": 0, "s": 3}).save(OUT / "probe_cell.png")
        print("probe", view.size)
