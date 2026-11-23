"""The HUD under the black of a fail (NULLROOM m3, 2026-11-23): stills over time and numbers from a Studio playtest on
Hugo's PC (studio-runner). The bug: back on the dock the Shop and Index buttons, the plus buttons and the full Oxygen
came up bright while the screen was still black, because the HUD's screen was drawn over the black. The black now has
a screen of its own over the HUD (HudController's BLACK_ORDER).
    python tools/studio/hud_black_check.py install | remove   (in Edit, before Play: the server and client helpers)
    python tools/studio/hud_black_check.py run [chomp] [breath] [throw] [clean]   (in a playtest; all four by default)
    python tools/studio/hud_black_check.py restore             (in a playtest: clears every switch a run set; `run`
                                                                does it by itself in a `finally`, `remove` too)
    python tools/studio/hud_black_check.py log                 (the client's errors and warnings so far)
How: the black lifts 1.3 s after the server puts us home (Config.Death.HoldBlack, FadeIn), on real time, and a hidden
Studio redraws about once a second, so a still would miss it. The client helper holds the black at the dock (workspace
M3Hold: HoldBlack for that long), sets how far it has lifted (M3Fade), puts it back where it was before the fix for one
still (M3Order 4) and says what is on screen (M3Probe: the mode, the black, every screen and its order). The fail
itself is held with the game's own clocks, as b5_fail_text_check.py does. CatchLook is left alone, so the end of the
dive is the look that is live. Shots and sheets go to work/m3/.
"""
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import b5_fail_text_check as b5  # noqa: E402
import fail_capture as fc  # noqa: E402

ROOT = fc.ROOT
OUT = ROOT / "work/m3"
OUT.mkdir(parents=True, exist_ok=True)
fc.WIDTH = 900
# the game view inside the Studio window's shot is fail_capture's CROP (a playtest's layout, 2400 x 1280); if Studio is
# laid out differently, write "left top right bottom" of the view in a full shot to work/m3/view.txt
VIEW = OUT / "view.txt"
if VIEW.exists():
    fc.CROP = tuple(int(v) for v in VIEW.read_text().split())

SWITCHES = ("M3Hold", "M3Fade", "M3Order", "M3Probe")

HELPER_SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ev = Instance.new("RemoteEvent")
ev.Name = "ZZM3Report"
ev.Parent = RS
local out = Instance.new("StringValue")
out.Name = "ZZM3Out"
out.Parent = SS
ev.OnServerEvent:Connect(function(_, kind, text)
	out.Value = string.sub(out.Value .. tostring(kind) .. "|" .. tostring(text) .. "\n", -12000)
end)
'''

HELPER_CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local ev = RS:WaitForChild("ZZM3Report")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
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
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Lib"):WaitForChild("State"))
local hold0 = Config.Death.HoldBlack
local order0 = nil
workspace:GetAttributeChangedSignal("M3Hold"):Connect(function()
	local v = workspace:GetAttribute("M3Hold")
	Config.Death.HoldBlack = if type(v) == "number" then v else hold0
end)
workspace:GetAttributeChangedSignal("M3Fade"):Connect(function()
	local v = workspace:GetAttribute("M3Fade")
	if type(v) == "number" then
		State.Fade = v
	end
end)
workspace:GetAttributeChangedSignal("M3Order"):Connect(function()
	local black = gui:FindFirstChild("RideBlack")
	if not black then
		return
	end
	order0 = order0 or black.DisplayOrder
	local v = workspace:GetAttribute("M3Order")
	black.DisplayOrder = if type(v) == "number" then v else order0
end)
local function shown(o)
	return if o and o:IsA("GuiObject") then tostring(o.Visible) else "none"
end
workspace:GetAttributeChangedSignal("M3Probe"):Connect(function()
	local tag = workspace:GetAttribute("M3Probe")
	if type(tag) ~= "string" then
		return
	end
	task.wait(0.25)
	local black = gui:FindFirstChild("RideBlack")
	local frame = black and black:FindFirstChildOfClass("Frame")
	local screens = {}
	for _, s in gui:GetChildren() do
		if s:IsA("ScreenGui") and s.Enabled then
			table.insert(screens, { s.DisplayOrder, s.Name })
		end
	end
	table.sort(screens, function(a, b)
		return if a[1] == b[1] then a[2] < b[2] else a[1] < b[1]
	end)
	local list = {}
	for _, s in screens do
		table.insert(list, s[2] .. ":" .. s[1])
	end
	local hud = gui:FindFirstChild("RideHud")
	local root = hud and hud:FindFirstChild("Root")
	local plus = "none"
	if root then
		for _, d in root:GetDescendants() do
			if d.Name == "Plus" and d:IsA("GuiObject") then
				plus = tostring(d.Visible)
				break
			end
		end
	end
	local notes = gui:FindFirstChild("DockNotes")
	local note = "none"
	if notes then
		note = "false"
		for _, d in notes:GetDescendants() do
			if d:IsA("GuiObject") and d.Parent == notes and d.Visible then
				note = "true"
			end
		end
	end
	ev:FireServer("probe", string.format(
		"%s; mode %s; fade %.2f; words %s; black order %s see-through %.2f; shop %s; plus %s; notes %s; hold %s; screens %s",
		tag, tostring(State.Mode), State.Fade, if State.FadeText == "" then "-" else State.FadeText,
		tostring(black and black.DisplayOrder), if frame then frame.BackgroundTransparency else -1,
		shown(root and root:FindFirstChild("HubButtons")), plus, note, tostring(Config.Death.HoldBlack),
		table.concat(list, " ")))
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
	local old = at:FindFirstChild("ZZM3Helper")
	if old then old:Destroy() end
end
if {fc.lua(remove)} then return "removed" end
local s = Instance.new("Script")
s.Name = "ZZM3Helper"
s.Source = {fc.lua(HELPER_SERVER)}
s.Parent = sss
local l = Instance.new("LocalScript")
l.Name = "ZZM3Helper"
l.Source = {fc.lua(HELPER_CLIENT)}
l.Parent = sps
return "installed"
"""))


def said(clear=False):
    code = "local v = game:GetService('ServerStorage'):FindFirstChild('ZZM3Out') local s = v and v.Value or 'no helper' "
    if clear:
        code += "if v then v.Value = '' end "
    return fc.server(code + "return s")


def clear():
    """Every switch this check set, off the playtest's workspace (also after a failed or killed run), and the game's
    own capture switches with them (fail_capture's HELD: CatchLook, TestMaxOxygen, the clocks)."""
    print("restore:", fc.restore(*SWITCHES))


LOG = []


def probe(tag):
    """What the client says is on screen now: the line, and a short form of it for the still's label."""
    key = f"{tag} {time.time():.2f}"
    fc.setw(M3Probe=key)
    time.sleep(0.7)
    line = ""
    for row in said().splitlines():
        if row.startswith("probe|" + key):
            line = row[6:]
    LOG.append(line or f"{tag}: no answer from the client helper")
    print(LOG[-1], flush=True)
    part = dict(p.strip().split(" ", 1) for p in line.split(";")[1:] if " " in p.strip())
    return f"{part.get('mode', '?')}, black {part.get('fade', '?')}"


def still(name, text):
    """A probe, then the shot (Studio redraws a hidden window about once a second), labelled with both."""
    told = probe(name)
    time.sleep(1.0)
    return fc.label(fc.shot(OUT / f"{name}.png"), f"{text}   [{told}]")


def home(name, frames, before=False):
    """From the black whole at the dock (held) to the end of the dive."""
    fc.wait_state({"Dock"}, timeout=60)
    fc.setw(FailClock=-1, DeathClock=-1, FailSlow=1)
    time.sleep(0.6)
    frames.append(still(f"{name}_2_dock", "home, the black still whole (held)"))
    if before:
        fc.setw(M3Order=4)
        frames.append(still(f"{name}_2b_before", "the same moment as it was BEFORE the fix (black under the HUD)"))
        fc.setw(M3Order=None)
    fc.setw(M3Fade=0.5)
    half = still(f"{name}_3_half", "the black half lifted (held)")
    if "black 0.50" in LOG[-1].replace("fade", "black"):
        frames.append(half)
    else:
        # (a fail we were sent home from by hand, its drown still running on the client, keeps the black whole)
        print("no half-lifted still: the black did not take the set value")
    fc.setw(M3Hold=None)
    time.sleep(0.5)
    frames.append(still(f"{name}_4_lifted", "the black gone: the end of the dive"))
    time.sleep(1.5)
    frames.append(still(f"{name}_5_after", "a few seconds on"))


def fail(fish, outcome, name, text, before=False):
    """Rides `fish` and fails it as `outcome`, with the black held once we are home. A taken outcome's black is
    FailController's; a thrown one's and the plain run-out's (None: failed before it is seated) are DeathController's.
    The plain run-out plays on real time, with no still of the drown itself: the server ends it on its own clock, and
    a held clock would bring us home with the black part-way or the words never set."""
    T = b5.TIMES.get(outcome or "", 0)
    taken = outcome in b5.fc_taken()
    frames = []
    fc.setw(TestMaxOxygen=10000000, FailSlow=1 if outcome is None else 60 if T == 0 or taken else 20,
            FailClock=-1 if outcome is None else 0, DeathClock=-1 if outcome is None else 0, M3Hold=1e6)
    print(fc.cmd("ride|" + fish))
    if outcome is None:
        print(fc.cmd("fail|"))
    else:
        fc.wait_state({"Riding"})
        time.sleep(3)
        print(fc.cmd("fail|" + outcome))
        if taken:
            clock, coming, whole = "FailClock", T + 0.3, T + 0.75
        else:
            if T > 0:
                fc.setw(FailClock=T + 0.2)
            fc.wait_state({"Drowning"}, timeout=90)
            # (the drown's own clock: a ragdoll's flight, then 2.9 s; the black is its last 1.35 s)
            clock, coming, whole = "DeathClock", b5.RAG + 2.9 - 0.9, b5.RAG + 2.9 - 0.25
        fc.setw(**{clock: coming})
        frames.append(still(f"{name}_0_coming", f"{text}: the black coming in"))
        fc.setw(**{clock: whole})
        frames.append(still(f"{name}_1_black", f"{text}: the black nearly whole" if not taken else f"{text}: the black whole"))
        # (the clocks let go first, so the fail runs out to its end, the black whole, before the server takes us home)
        fc.setw(FailClock=-1, DeathClock=-1)
        time.sleep(0.8)
        fc.setw(FailSlow=1)
        print(fc.cmd("home"))
    home(name, frames, before)
    return frames


def clean(name="clean"):
    """A dive that ends without a fail (sent home off the fish): no black, the dock's pieces at once."""
    frames = []
    fc.setw(TestMaxOxygen=10000000)
    print(fc.cmd("ride|Clownfish"))
    fc.wait_state({"Riding"})
    time.sleep(3)
    frames.append(still(f"{name}_0_riding", "a clean dive: riding"))
    print(fc.cmd("home"))
    fc.wait_state({"Dock"}, timeout=30)
    for k, text in enumerate(("home: no black", "the end of the dive", "a few seconds on")):
        frames.append(still(f"{name}_{k + 1}", text))
        time.sleep(1.2)
    return frames


RUNS = {
    "chomp": lambda: fail("ReefShark", "Chomp", "chomp", "Chomp (Reef Shark), EATEN!", before=True),
    "breath": lambda: fail("Clownfish", None, "breath", "Out of Oxygen, OUT OF BREATH!"),
    "throw": lambda: fail("Clownfish", "Throw", "throw", "Throw (Clownfish), THROWN OFF!"),
    "clean": clean,
}


def run(only):
    try:
        for name in only or list(RUNS):
            got = RUNS[name]()
            b5.grid(got, OUT / f"hud-black-{name}.png", 2 if len(got) <= 4 else 3)
            time.sleep(4)
    finally:
        clear()
        (OUT / "probes.txt").write_text("\n".join(LOG) + "\n")
        print(OUT / "probes.txt")
        print("client log:\n" + said())


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        install()
    elif what == "remove":
        clear()
        install(remove=True)
    elif what == "restore":
        clear()
    elif what == "run":
        run(sys.argv[2:])
    elif what == "log":
        print(said())
