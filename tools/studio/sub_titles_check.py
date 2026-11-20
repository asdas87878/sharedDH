"""The land titles on a sub run (task t1, docs/design/submarine.md "Titles on the run"): checked in a Studio playtest.
    python tools/studio/sub_titles_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/sub_titles_check.py run [far] [short]   (in a playtest; the log is appended)
How: the server Script buys every sub (ServerStorage.SubTest), picks the land and stands the player in the water past
the start strip. The LocalScript watches the HUD every frame: each land title (a CanvasGroup with a "Title" attribute,
UI/LandStrip) as it comes in and goes, the land the player is in, and how many titles were on screen at once; times
are seconds from the trip's start (its SubTrip attribute). Shots go to work/subtitles/ (thumbnails, one at a time),
the log to work/subtitles/check.log. Needs Studio open with the studio-runner plugin, the repo's code in the place.
"""
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/subtitles"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 125)
VIEW = [1985, 1085]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local report = Instance.new("RemoteEvent")
report.Name = "ZZSTReport"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("STClient", tostring(text))
end)
local function dive(player, lines)
	local character = player.Character
	local strip = workspace.ClaudeBlockout.Dock.StartStrip
	local into = strip.Position + Vector3.new(0, 0, 30)
	character:PivotTo(CFrame.lookAt(Vector3.new(into.X, -9, into.Z), Vector3.new(into.X, -9, into.Z + 10)))
	local began = os.clock()
	local rodeAt = nil
	while os.clock() - began < 30 do
		if player:GetAttribute("State") == "Riding" and not rodeAt then
			rodeAt = os.clock()
		end
		-- kept riding a while after the drop: the arrival land's own title must still not come
		if rodeAt and os.clock() - rodeAt > 4 then
			break
		end
		task.wait(0.05)
	end
	table.insert(lines, "state " .. tostring(player:GetAttribute("State")))
end
RS:GetAttributeChangedSignal("STCmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("STCmd") or "")
	local verb, a = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local test = ServerStorage:WaitForChild("SubTest")
	local lines = {}
	local ok, err = pcall(function()
		if verb == "setup" then
			table.insert(lines, "home " .. tostring(test:Invoke("home", player.UserId)))
			task.wait(1)
			table.insert(lines, "give " .. tostring(test:Invoke("give", player.UserId, 1e12, {})))
			for _ = 1, 9 do
				test:Invoke("buy", player.UserId)
			end
		elseif verb == "home" then
			test:Invoke("home", player.UserId)
			task.wait(1.5)
			table.insert(lines, "home")
		elseif verb == "pick" then
			table.insert(lines, "pick " .. tostring(test:Invoke("pick", player.UserId, tonumber(a), "")))
		elseif verb == "dive" then
			dive(player, lines)
		end
	end)
	if not ok then
		table.insert(lines, "ERROR " .. tostring(err))
	end
	RS:SetAttribute("STLog", table.concat(lines, "\n"))
	RS:SetAttribute("STDone", cmd)
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local SubTrip = require(Shared:WaitForChild("SubTrip"))
local Zones = require(Shared:WaitForChild("Zones"))
local State = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Lib"):WaitForChild("State"))
local report = RS:WaitForChild("ZZSTReport", 60)
local lines = {}
local start = nil
local seen = {} -- group -> its title, while on screen
local land = -1
local most = 0
local function stamp()
	if start then
		return string.format("%+6.2f", workspace:GetServerTimeNow() - start)
	end
	return "  ----"
end
local function trip()
	local json = player:GetAttribute("SubTrip")
	if type(json) == "string" then
		local t = SubTrip.decode(json)
		if t and t.Start ~= start then
			start = t.Start
			local pickupAt, rideAt, arriveAt, dropAt = SubTrip.times(t)
			table.insert(lines, string.format("TRIP to land %d: ride %.2f arrive %.2f drop %.2f", t.Land, rideAt, arriveAt, dropAt))
		end
	end
end
player:GetAttributeChangedSignal("SubTrip"):Connect(trip)
RunService.RenderStepped:Connect(function()
	if not start then
		return
	end
	local _, root = State.character()
	if root then
		local zone = Zones.locate(State.Zones, root.Position)
		local now = if zone then zone.Index else 0
		if now ~= land then
			land = now
			table.insert(lines, stamp() .. "  in land " .. now .. "  (" .. tostring(player:GetAttribute("State")) .. ")")
		end
	end
	local gui = player.PlayerGui
	local count = 0
	local here = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("CanvasGroup") and d:GetAttribute("Title") then
			here[d] = true
			if d.GroupTransparency < 0.9 then
				count += 1
			end
			if not seen[d] then
				seen[d] = d:GetAttribute("Title")
				table.insert(lines, stamp() .. "  IN   " .. seen[d])
			end
			if string.sub(d.Name, -3) == "Out" and not d:GetAttribute("Logged") then
				d:SetAttribute("Logged", true)
				table.insert(lines, stamp() .. "  HAND-OFF (fast out) " .. seen[d])
			end
		end
	end
	for d, title in seen do
		if not here[d] then
			seen[d] = nil
			table.insert(lines, stamp() .. "  GONE " .. title)
		end
	end
	if count > most then
		most = count
	end
end)
workspace:GetAttributeChangedSignal("STDo"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("STDo") or "")
	if string.sub(cmd, 1, 4) == "dump" then
		table.insert(lines, "most titles seen at once (under 0.9 transparency): " .. most)
		report:FireServer(table.concat(lines, "\n"))
		lines = {}
		most = 0
		start = nil
		land = -1
	end
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return "[==[" + str(v) + "]==]"


def server(code, timeout=120):
    return run(["--ctx", "server", "--code", code], timeout)


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZSubTitles")
	if old then old:Destroy() end
end
workspace:SetAttribute("STDo", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZSubTitles"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZSubTitles"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=45):
    tag = c + "|" + str(time.time())
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('STDone', '') "
        f"RS:SetAttribute('STCmd', {lua(tag)}) local t = os.clock() "
        f"while RS:GetAttribute('STDone') ~= {lua(tag)} and os.clock() - t < {wait} do task.wait(0.1) end "
        f"return RS:GetAttribute('STLog')",
        timeout=wait + 30,
    )


def dump():
    return server(
        "local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('STClient', '') "
        f"workspace:SetAttribute('STDo', {lua('dump|' + str(time.time()))}) "
        "local t = os.clock() while RS:GetAttribute('STClient') == '' and os.clock() - t < 5 do task.wait(0.1) end "
        "return RS:GetAttribute('STClient')"
    )


def frames(name, seconds, stop):
    """Shots of the game view while a run goes: downscaled and streamed to disk, one at a time."""
    n = 0
    t0 = time.time()
    end = t0 + seconds
    while time.time() < end and not stop.is_set():
        raw = OUT / f"raw_{name}.png"
        raw.unlink(missing_ok=True)
        run(["shot", str(raw)], timeout=30)
        size, until = -1, time.time() + 5
        while time.time() < until:
            now = raw.stat().st_size if raw.exists() else -1
            if now > 0 and now == size:
                break
            size = now
            time.sleep(0.1)
        else:
            continue
        with Image.open(raw) as im:
            view = im.convert("RGB").crop((OFFSET[0], OFFSET[1], OFFSET[0] + VIEW[0], OFFSET[1] + VIEW[1]))
            view.thumbnail((1280, 720))
            view.save(OUT / f"{name}_{n:03d}_{time.time() - t0:05.2f}.png")
        n += 1
    raw = OUT / f"raw_{name}.png"
    raw.unlink(missing_ok=True)
    return n


def check(stages):
    log = []

    def note(text):
        print(text, flush=True)
        log.append(text)

    note("== setup " + time.strftime("%H:%M:%S"))
    note(cmd("setup"))
    for stage, land in (("far", 10), ("short", 2)):
        if stage not in stages:
            continue
        for p in OUT.glob(f"{stage}_*.png"):
            p.unlink()
        note(f"== {stage}: sub from the gate to land {land}")
        note(cmd(f"pick|{land}"))
        stop = threading.Event()
        th = threading.Thread(target=frames, args=(stage, 24, stop))
        th.start()
        note(cmd("dive"))
        stop.set()
        th.join()
        note(dump())
        note(cmd("home"))
    with open(OUT / "check.log", "a") as f:
        f.write("\n".join(log) + "\n")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    else:
        check(sys.argv[2:] or ["far", "short"])
