"""The fail text as Bubble letters (Hugo's pick, 2026-11-22; Kit.failWords and FailController's "The words"): numbers
and stills from a Studio playtest on Hugo's PC (studio-runner).
    python tools/studio/fail_bubble_check.py install | remove   (in Edit, before Play: the server and client helpers)
    python tools/studio/fail_bubble_check.py probe              (in a playtest: every line on four screen sizes, by numbers)
    python tools/studio/fail_bubble_check.py motion             (the motion, held frame by frame)
    python tools/studio/fail_bubble_check.py lines              (every line, settled)
    python tools/studio/fail_bubble_check.py phone              (the long lines on pretended phone screens)
    python tools/studio/fail_bubble_check.py fails [name ...]   (real fails: breath, throw, chomp, shell)
    python tools/studio/fail_bubble_check.py log                (the client's errors and warnings so far)
How: the motion, the lines and the phone use FailController's Studio switches (workspace FailWords, FailWordsAge,
FailWordsOut, FailWordsSub, FailWordsScreen); the real fails ride a fish and fail it with the game's clocks held, as
b5_fail_text_check.py did for the Slam band. The runner cannot run code in the playtest's client, so a LocalScript put
in by `install` sends the client's errors and, when asked (workspace T1Probe), what the words measure on screen.
Shots go to work/t1/, sheets to docs/attachments/fail-bubble-*.png.
"""
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import b5_fail_text_check as b5  # noqa: E402
import fail_capture as fc  # noqa: E402

ROOT = fc.ROOT
OUT = ROOT / "work/t1"
OUT.mkdir(parents=True, exist_ok=True)
DOCS = ROOT / "docs/attachments"
b5.OUT = OUT
fc.WIDTH = 900
# the game view inside the Studio window's shot, as Studio is laid out now (2400 x 1280, the Terrain Editor and the
# Toolbox docked at the left); set by `view` below when the shot's size or the layout differs
VIEW = OUT / "view.txt"
if VIEW.exists():
    fc.CROP = tuple(int(v) for v in VIEW.read_text().split())

LINES = b5.LINES
LONG = ["MISSED THE FISH!", "DRAGGED DOWN!", "OUT OF BREATH!"]
SCREENS = [(844, 390, "phone, held sideways"), (667, 375, "small phone, sideways"), (390, 844, "phone, upright"),
           (1024, 768, "tablet")]

HELPER_SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ev = Instance.new("RemoteEvent")
ev.Name = "ZZT1Report"
ev.Parent = RS
local out = Instance.new("StringValue")
out.Name = "ZZT1Out"
out.Parent = SS
ev.OnServerEvent:Connect(function(_, kind, text)
	out.Value = string.sub(out.Value .. tostring(kind) .. "|" .. tostring(text) .. "\n", -6000)
end)
'''

HELPER_CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local ev = RS:WaitForChild("ZZT1Report")
local seen = {}
LogService.MessageOut:Connect(function(msg, kind)
	if kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning then
		local key = string.sub(msg, 1, 120)
		if not seen[key] then
			seen[key] = true
			ev:FireServer("log", string.sub(msg, 1, 300))
		end
	end
end)
workspace:GetAttributeChangedSignal("T1Probe"):Connect(function()
	task.wait(0.3)
	local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("RideFailWords")
	local root = gui and gui:FindFirstChild("FailWords")
	local band = root and root:FindFirstChild("Word")
	if not band or not root.Visible then
		ev:FireServer("probe", tostring(workspace:GetAttribute("T1Probe")) .. " nothing shown")
		return
	end
	local x0, x1, y0, y1, letters, bubbles, size = math.huge, -math.huge, math.huge, -math.huge, 0, 0, 0
	for _, c in band:GetChildren() do
		if c:IsA("GuiObject") and c.Visible and (c.Name == "Letter" or c.Name == "Bubble") then
			local p, s = c.AbsolutePosition, c.AbsoluteSize
			x0, x1 = math.min(x0, p.X), math.max(x1, p.X + s.X)
			y0, y1 = math.min(y0, p.Y), math.max(y1, p.Y + s.Y)
			if c.Name == "Letter" then
				letters += 1
				local face = c:FindFirstChildOfClass("TextLabel")
				size = if face then face.TextSize else size
			else
				bubbles += 1
			end
		end
	end
	local sub = band:FindFirstChild("Sub")
	local scale = band:FindFirstChildOfClass("UIScale")
	local r0, rs = root.AbsolutePosition, root.AbsoluteSize
	ev:FireServer("probe", string.format(
		"%s screen %dx%d fit %.2f letters %d (text size %.0f) bubbles %d sub %s left %d right %d top %d bottom %d inside %s",
		tostring(workspace:GetAttribute("T1Probe")), rs.X, rs.Y, scale and scale.Scale or 0, letters,
		size * (scale and scale.Scale or 1), bubbles, tostring(sub and sub.Visible), x0 - r0.X, r0.X + rs.X - x1,
		y0 - r0.Y, r0.Y + rs.Y - y1, tostring(x0 >= r0.X and x1 <= r0.X + rs.X and y0 >= r0.Y and y1 <= r0.Y + rs.Y)))
end)
'''


def edit(code):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    return fc.run([f.name])


def install(remove=False):
    print(fc.install(remove=remove))
    print(edit(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer").StarterPlayerScripts
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZT1Helper")
	if old then old:Destroy() end
end
if {fc.lua(remove)} then return "removed" end
local s = Instance.new("Script")
s.Name = "ZZT1Helper"
s.Source = {fc.lua(HELPER_SERVER)}
s.Parent = sss
local l = Instance.new("LocalScript")
l.Name = "ZZT1Helper"
l.Source = {fc.lua(HELPER_CLIENT)}
l.Parent = sps
return "installed"
"""))


def said(clear=False):
    code = "local v = game:GetService('ServerStorage'):FindFirstChild('ZZT1Out') local s = v and v.Value or 'no helper' "
    if clear:
        code += "if v then v.Value = '' end "
    return fc.server(code + "return s")


def shot(name, text, crop=None):
    time.sleep(1.6)  # (Studio redraws a hidden window about once a second)
    im = fc.shot(OUT / f"{name}.png")
    if crop:
        w, h = im.size
        im = im.crop((int(w * crop[0]), int(h * crop[1]), int(w * crop[2]), int(h * crop[3])))
    return fc.label(im, text)


def probe():
    said(clear=True)
    n = 0
    for w, h, _ in [(0, 0, "")] + SCREENS:
        for i, line in enumerate(LINES):
            n += 1
            fc.setw(FailWordsScreen=f"@Vector2.new({w}, {h})", FailWordsAge=2.4, FailWordsOut=0, FailWordsSub=True,
                    FailWords=line)
            fc.setw(T1Probe=f"{n} {line}")
            time.sleep(0.6)
    fc.setw(FailWords="", FailWordsAge=-1, FailWordsScreen="@nil")
    time.sleep(0.5)
    print(said())


def motion():
    frames = []
    steps = [(0.06, 0, "0.06 s: the first letter pops up from below"), (0.18, 0, "0.18 s: one by one"),
             (0.36, 0, "0.36 s: each a little past its size, then back"), (0.6, 0, "0.60 s: the last letters, the bubbles"),
             (0.95, 0, "0.95 s: all up; the second line pops in"), (1.6, 0, "1.6 s: bobbing"),
             (2.3, 0, "2.3 s: bobbing (the letters have moved)"), (3.1, 0, "3.1 s: bobbing"),
             (3.1, 0.2, "on the way out, 20%: floating up"), (3.1, 0.45, "45%: the first have popped (rings)"),
             (3.1, 0.65, "65%: most gone"), (3.1, 0.8, "80%: the last one pops")]
    fc.setw(FailWords="", FailWordsSub=True, FailWordsScreen="@nil")
    time.sleep(0.5)
    for i, (age, out, text) in enumerate(steps):
        fc.setw(FailWordsAge=age, FailWordsOut=out, FailWords="OUT OF BREATH!")
        frames.append(shot(f"motion_{i}", text, (0, 0.27, 1, 0.73)))
    fc.setw(FailWords="", FailWordsAge=-1, FailWordsOut=0)
    b5.grid(frames, DOCS / "fail-bubble-motion.png", 3)


def lines():
    frames = []
    fc.setw(FailWordsScreen="@nil")
    for i, line in enumerate(LINES):
        fc.setw(FailWordsAge=2.4, FailWordsOut=0, FailWordsSub=i % 2 == 0, FailWords=line)
        frames.append(shot(f"line_{i}", line + ("" if i % 2 == 0 else "   (no catch on the dive: no second line)"),
                           (0, 0.27, 1, 0.73)))
    fc.setw(FailWords="", FailWordsAge=-1, FailWordsSub=True)
    b5.grid(frames, DOCS / "fail-bubble-lines.png", 3)


def phone():
    """The long lines on pretended phone screens: the words fit themselves to a box of the phone's size (outlined in
    white), and the shot is cut to that box at its own pixels, so each cell is what that phone would show of them."""
    frames = []
    full = fc.CROP[2] - fc.CROP[0], fc.CROP[3] - fc.CROP[1]
    keep, fc.WIDTH = fc.WIDTH, full[0]  # (no shrinking: the box's own pixels)
    for w, h, name in SCREENS[:3]:
        for line in LONG[:2]:
            fc.setw(FailWordsScreen=f"@Vector2.new({w}, {h})", FailWordsAge=2.4, FailWordsOut=0, FailWordsSub=True,
                    FailWords=line)
            time.sleep(2.6)
            im = fc.shot(OUT / f"phone_{w}_{len(frames)}.png")
            x, y = (im.size[0] - w) // 2, (im.size[1] - h) // 2
            cell = Image.new("RGB", (w + 16, h + 40), (16, 18, 26))
            cell.paste(im.crop((x - 3, y - 3, x + w + 3, y + h + 3)), (5, 31))
            frames.append(fc.label(cell, f"{name}, {w} x {h}"))
    fc.WIDTH = keep
    fc.setw(FailWords="", FailWordsAge=-1, FailWordsScreen="@nil")
    # the four sideways ones down the left, the two upright ones beside them
    canvas = Image.new("RGB", (880 + 2 * 420, 4 * 440), (16, 18, 26))
    for i, f in enumerate(frames[:4]):
        canvas.paste(f, (10, i * 440))
    for i, f in enumerate(frames[4:]):
        canvas.paste(f, (880 + i * 420, 0))
    canvas.save(DOCS / "fail-bubble-phone.png")
    print(DOCS / "fail-bubble-phone.png")


def fails(only=None):
    runs = [("Clownfish", "Throw", "throw", "Throw (Clownfish): THROWN OFF!"),
            ("ReefShark", "Chomp", "chomp", "Chomp (Reef Shark): EATEN!"),
            ("SeaTurtle", "Shell", "shell", "Shell (Sea Turtle): SHAKEN OFF!"),
            ("Clownfish", None, "breath", "Out of Oxygen off a fish: OUT OF BREATH!")]
    frames = []
    for fish, outcome, name, text in runs:
        if only and name not in only:
            continue
        got = b5.one(fish, outcome, name, text)
        if outcome is None:
            got = got[:1]  # (not thrown, the server ends the drown on its own clock: by a second shot we are home)
        frames += got
        b5.grid(got, OUT / f"fails-{name}.png", 2)
    if not only:
        b5.grid(frames, DOCS / "fail-bubble-fails.png", 2)


# (a Vector2 or nil for a workspace attribute: fail_capture's lua() only knows numbers, booleans and words)
_lua = fc.lua
fc.lua = lambda v: v[1:] if isinstance(v, str) and v.startswith("@") else _lua(v)

if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        install()
    elif what == "remove":
        install(remove=True)
    elif what == "probe":
        probe()
    elif what == "motion":
        motion()
    elif what == "lines":
        lines()
    elif what == "phone":
        phone()
    elif what == "fails":
        fails(sys.argv[2:])
    elif what == "log":
        print(said())
