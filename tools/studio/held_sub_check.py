"""The held fish rides after the sub (task f2, docs/design/submarine.md): checked and timed in a Studio playtest.
    python tools/studio/held_sub_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/held_sub_check.py run [timing] [held] [plain]   (in a playtest; each stage sets up again; the log is appended)
How: the server Script puts fish in the player's hands (RideService.giveCarried) and one in their tank, buys every sub
(ServerStorage.SubTest), and on each "dive" stands the player in the water past the start strip and logs the trip
(its phases, its plan from the SubTrip attribute, the fish ridden, the hands after) into ReplicatedStorage's
"HSLog". The LocalScript fires the ask a slot's click does (Action "Hold", index, id). Shots go to work/heldsub/,
the log to work/heldsub/check.log; the kept stills and the gif to docs/attachments/held-sub-*.
Needs Studio open with the studio-runner plugin, the repo's code in the place.
"""
import json
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/heldsub"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 125)
VIEW = [1985, 1085]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Http = game:GetService("HttpService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local SubTrip = require(RS:WaitForChild("Shared"):WaitForChild("SubTrip"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZHSReport"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("HSClient", tostring(text))
end)
local function hands(player)
	local t = {}
	for _, c in RideService.carried(player) do
		table.insert(t, c.Id .. "/" .. c.Size .. "/" .. c.Variant)
	end
	return table.concat(t, ",")
end
local function ridden(player)
	for _, m in workspace.Fish:GetChildren() do
		if m:GetAttribute("Rider") == player.UserId then
			return m
		end
	end
	return nil
end
local function dive(player, lines)
	local character = player.Character
	local root = character.HumanoidRootPart
	local strip = workspace.ClaudeBlockout.Dock.StartStrip
	local into = strip.Position + Vector3.new(0, 0, 30)
	character:PivotTo(CFrame.lookAt(Vector3.new(into.X, -9, into.Z), Vector3.new(into.X, -9, into.Z + 10)))
	local began = os.clock()
	local last, plan = "?", false
	local rodeAt = nil
	while os.clock() - began < 30 do
		local st = tostring(player:GetAttribute("State"))
		local ph = tostring(player:GetAttribute("SubPhase"))
		if not plan and player:GetAttribute("SubTrip") then
			plan = true
			local trip = SubTrip.decode(player:GetAttribute("SubTrip"))
			if trip then
				local _, rideAt, arriveAt, dropAt = SubTrip.times(trip)
				local dist = SubTrip.distance(trip, arriveAt)
				table.insert(lines, string.format(
					"PLAN land %d fish=%s approach %.2f pickup %.2f up %.2f cruise %.2f down %.2f RUN %.2f top %.0f runDist %.0f arrive %.2f drop %.2f TOTAL_TO_DROP %.2f",
					trip.Land, tostring(trip.Fish), trip.Approach, trip.Pickup, trip.SpeedUp, trip.Cruise, trip.SlowDown,
					arriveAt - rideAt, trip.Top, dist, trip.Arrive, trip.DropTime, dropAt))
			end
		end
		local key = st .. " " .. ph
		if key ~= last then
			last = key
			table.insert(lines, string.format("%.2f %s", os.clock() - began, key))
		end
		if st == "Riding" and not rodeAt then
			rodeAt = os.clock()
		end
		if rodeAt and os.clock() - rodeAt > 1.5 then
			break
		end
		task.wait(0.05)
	end
	local f = ridden(player)
	table.insert(lines, string.format("RIDING %s size=%s variant=%s tamed-new=%s state=%s held=%s hands=[%s] oxygen=%s",
		f and tostring(f:GetAttribute("FishType")) or "none", f and tostring(f:GetAttribute("SizeTier")) or "-",
		f and tostring(f:GetAttribute("Variant")) or "-", tostring(player:GetAttribute("Tame")),
		tostring(player:GetAttribute("State")), tostring(player:GetAttribute("HeldFish")), hands(player),
		tostring(player:GetAttribute("Oxygen"))))
end
RS:GetAttributeChangedSignal("HSCmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("HSCmd") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local test = ServerStorage:WaitForChild("SubTest")
	local lines = {}
	local ok, err = pcall(function()
		if verb == "setup" then
			table.insert(lines, "home " .. tostring(test:Invoke("home", player.UserId)))
			task.wait(1)
			for _, f in Http:JSONDecode(a) do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			table.insert(lines, "give " .. tostring(test:Invoke("give", player.UserId, 1e12, { { "Clownfish", "Small", "" } })))
			for _ = 1, 9 do
				test:Invoke("buy", player.UserId)
			end
			table.insert(lines, "hands [" .. hands(player) .. "]")
		elseif verb == "home" then
			test:Invoke("home", player.UserId)
			task.wait(1)
			table.insert(lines, "home: state " .. tostring(RideService.stateOf(player)) .. " held=" .. tostring(player:GetAttribute("HeldFish")) .. " hands=[" .. hands(player) .. "]")
		elseif verb == "equip" then
			table.insert(lines, "equip " .. tostring(test:Invoke("equip", player.UserId, tonumber(a))))
		elseif verb == "pick" then
			table.insert(lines, "pick " .. tostring(test:Invoke("pick", player.UserId, tonumber(a), (string.gsub(b, "~", "|")))))
		elseif verb == "dive" then
			dive(player, lines)
		elseif verb == "state" then
			table.insert(lines, string.format("state %s held=%s hands=[%s]", tostring(RideService.stateOf(player)),
				tostring(player:GetAttribute("HeldFish")), hands(player)))
		end
	end)
	if not ok then
		table.insert(lines, "ERROR " .. tostring(err))
	end
	RS:SetAttribute("HSLog", table.concat(lines, "\n"))
	RS:SetAttribute("HSDone", cmd)
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local report = RS:WaitForChild("ZZHSReport", 60)
local denied = ""
Net.Ride.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Denied" and a == "Hold" then
		denied = tostring(b)
	end
end)
workspace:GetAttributeChangedSignal("HSDo"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("HSDo") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	if verb == "hold" then
		denied = ""
		Net.Action:FireServer("Hold", tonumber(a), b)
		task.wait(0.6)
		report:FireServer("denied=" .. denied .. " held=" .. tostring(player:GetAttribute("HeldFish")) .. " @" .. cmd)
	elseif verb == "clean" then
		-- (the shots only: the end-of-dive screen left up by the quick trips home is hidden, on this machine)
		local n = 0
		for _, d in player.PlayerGui:GetDescendants() do
			if d:IsA("TextLabel") and (string.find(d.Text, "GREAT DIVE") or string.find(d.Text, "NO CATCH")) then
				local top = d
				while top.Parent and not top.Parent:IsA("ScreenGui") do
					top = top.Parent
				end
				if top:IsA("GuiObject") then
					top.Visible = false
					n += 1
				end
			end
		end
		report:FireServer("hid " .. n)
	end
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    return "[==[" + str(v) + "]==]"


def server(code, timeout=120):
    return run(["--ctx", "server", "--code", code], timeout)


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZHeldSub")
	if old then old:Destroy() end
end
workspace:SetAttribute("HSDo", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZHeldSub"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZHeldSub"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=40):
    tag = c + "|" + str(time.time())
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('HSDone', '') "
        f"RS:SetAttribute('HSCmd', {lua(tag)}) local t = os.clock() "
        f"while RS:GetAttribute('HSDone') ~= {lua(tag)} and os.clock() - t < {wait} do task.wait(0.1) end "
        f"return RS:GetAttribute('HSLog')",
        timeout=wait + 30,
    )


def do(c, wait=1.2):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('HSClient', '') "
        f"workspace:SetAttribute('HSDo', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('HSClient')"
    )


def frames(name, seconds, stop):
    """Shots of the game view while a dive runs: downscaled and streamed to disk, one at a time."""
    n = 0
    end = time.time() + seconds
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
            view.thumbnail((640, 360))
            view.save(OUT / f"{name}_{n:03d}_{time.time():.2f}.png")
        n += 1
    return n


def dive_with_shots(name, seconds):
    print("clean: " + do("clean", 0.5), flush=True)
    stop = threading.Event()
    th = threading.Thread(target=frames, args=(name, seconds, stop))
    th.start()
    out = cmd("dive")
    stop.set()
    th.join()
    return out


def check(stages):
    log = []

    def note(text):
        print(text, flush=True)
        log.append(text)

    hands = [["ReefShark", "Big", "Gold"], ["Pufferfish", "Normal", ""]]
    note("== setup: hands " + json.dumps(hands) + ", a Small Clownfish in the tank")
    note(cmd("setup|" + json.dumps(hands)))

    if "timing" in stages:
        # 1. timing, the fling (nothing held, no tank fish picked)
        for land in (2, 5, 10):
            note(f"== timing: sub to land {land}, nothing held (the fling)")
            note(cmd(f"pick|{land}|"))
            note(cmd("dive"))
            note(cmd("home"))

    if "held" in stages:
        # 2. the held fish after the sub; the tank's Clownfish is picked too, the held fish must win
        for p in OUT.glob("sub_*.png"):
            p.unlink()
        note("== held Reef Shark (Big, Gold), sub to land 5, the tank's Clownfish picked too")
        note("hold: " + do("hold|1|ReefShark"))
        note(cmd("pick|5|Clownfish~Small~"))
        note(cmd("state"))
        note(dive_with_shots("sub", 16))
        note("-- home after the ride (as after a drown): the fish must still be in the hands, held again")
        note(cmd("home"))

    if "plain" in stages:
        # 3. the plain dive-in, no sub equipped, with the held fish
        for p in OUT.glob("plain_*.png"):
            p.unlink()
        note("== plain dive-in (no sub equipped), holding the Reef Shark")
        note("hold: " + do("hold|1|ReefShark"))
        note(cmd("equip|0"))
        note(cmd("state"))
        note(dive_with_shots("plain", 6))
        note(cmd("home"))
        # 4. the plain dive-in with nothing held: the dive-in's hop as before
        note("== plain dive-in, nothing held")
        note("put away: " + do("hold|0|"))
        note(cmd("dive"))
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
        check(sys.argv[2:] or ["timing", "held", "plain"])
