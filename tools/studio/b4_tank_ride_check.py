"""The tank ride of task b4: real-size fish in the tank, hold E on the fish looked at, the free ride, E off; checked and
pictured in a playtest.
    python tools/studio/b4_tank_ride_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/b4_tank_ride_check.py run                (in the playtest: the checks; log work/b4/check.log)
    python tools/studio/b4_tank_ride_check.py shots              (in a fresh playtest: the stills)
How: the server Script fills the tank (AquariumService.give), stands the player in front of it and reports the
server's side (state, Oxygen, the shown fish and their sizes, where the ridden fish's Saddle is in the water). The
LocalScript gives TankRideController a look (the screen point of a chosen fish, every frame) and a held key through
its own test hooks (pretend, pressOff), so the hold, the ring and the ask go the real way; it reads what the look is
on, the ring, the joints' turns, and keeps the server's answers.
Log: work/b4/check.log; shots docs/attachments/b4-*.png.
Needs Studio open with the studio-runner plugin and this repo's code in the place.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/b4"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 125)  # the game view in the shot (as c1_tank_hotbar_check.py)
VIEW = [1985, 1085]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local TankRideService = require(Services:WaitForChild("TankRideService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZB4Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("B4Client", tostring(text))
end)
local function stand(player, cf)
	player.Character:PivotTo(cf)
	workspace:SetAttribute("B4Stand", cf) -- (the client owns its body: it moves it too)
end
local function ridden(shown)
	for _, m in shown:GetChildren() do
		if m:GetAttribute("TankRider") then
			return m
		end
	end
end
RS:GetAttributeChangedSignal("B4Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("B4Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		local plot = AquariumService.plotOf(player)
		local water = plot.TankWater
		if verb == "give" then
			AquariumService.give(player, 0, Http:JSONDecode(arg))
			return "given"
		elseif verb == "front" then
			local spot = AquariumService.frontOf(plot)
			stand(player, spot + Vector3.new(0, 3, 0))
			return "front of " .. plot.Name
		elseif verb == "away" then
			local spot = AquariumService.frontOf(plot)
			stand(player, spot + spot.LookVector * -(tonumber(arg) or 80) + Vector3.new(0, 3, 0))
			return "away"
		elseif verb == "sizes" then
			-- every shown fish: how long it is drawn against its real length (its kind's Size, BaseScale in, x its rolled size)
			local shown = AquariumService.shownOf(player)
			local out = {}
			for _, m in shown:GetChildren() do
				local kind = Config.FishById[m:GetAttribute("FishType")]
				local real = kind.Size.Z * Config.sizeScale(m:GetAttribute("SizeTier"), kind)
				local size = m:GetExtentsSize()
				local sea = kind.Size.Z -- (FishModel.build makes it this long: its scale then is 1 x what it was built at)
				table.insert(out, string.format("%s/%s real=%.1f scaleOfBuilt=%.3f wantScale=%.3f longest=%.1f",
					m:GetAttribute("FishType"), m:GetAttribute("SizeTier"), real,
					m:GetAttribute("B4Built") or -1, real / sea, math.max(size.X, size.Y, size.Z)))
			end
			return "water=" .. tostring(water.Size) .. " ; " .. table.concat(out, " ; ")
		elseif verb == "state" then
			local shown = AquariumService.shownOf(player)
			local fish = shown and ridden(shown)
			local seat = ""
			if fish then
				local saddle = fish.PrimaryPart.Saddle
				local p = water.CFrame:PointToObjectSpace(saddle.WorldPosition)
				local h = water.Size / 2
				seat = string.format(" fish=%s seat=(%.1f,%.1f,%.1f) out=(%.1f,%.1f,%.1f) speed=%.1f anchored=%s owner=%s",
					fish:GetAttribute("FishType"), p.X, p.Y, p.Z,
					math.max(math.abs(p.X) - h.X, 0), math.max(math.abs(p.Y) - h.Y, 0), math.max(math.abs(p.Z) - h.Z, 0),
					fish.PrimaryPart.AssemblyLinearVelocity.Magnitude, tostring(fish.PrimaryPart.Anchored),
					tostring(fish.PrimaryPart:GetNetworkOwner()))
			end
			local root = player.Character.HumanoidRootPart
			local front = AquariumService.frontOf(plot)
			local tagged = 0
			for _, m in (shown and shown:GetChildren() or {}) do
				if CollectionService:HasTag(m, "TankFish") then
					tagged += 1
				end
			end
			return string.format("state=%s riding=%s attr=%s oxygen=%s max=%s shown=%d tagged=%d fromFront=%.1f stand=%s%s",
				tostring(RideService.stateOf(player)), tostring(TankRideService.riding(player)),
				tostring(player:GetAttribute("TankRide")), tostring(player:GetAttribute("Oxygen")),
				tostring(player:GetAttribute("MaxOxygen")), shown and #shown:GetChildren() or 0, tagged,
				(root.Position - front.Position).Magnitude,
				tostring(player.Character.Humanoid.PlatformStand), seat)
		elseif verb == "decoy" then
			-- a fish in ANOTHER plot's tank, as another player's would be: tagged, in a TankFish folder there
			local shown = AquariumService.shownOf(player)
			local other
			for _, p in plot.Parent:GetChildren() do
				if p ~= plot and p:FindFirstChild("TankWater") then
					other = p
					break
				end
			end
			local folder = Instance.new("Folder")
			folder.Name = "TankFish"
			local copy = shown:GetChildren()[1]:Clone()
			copy.Name = "B4Decoy"
			copy:PivotTo(CFrame.new(other.TankWater.Position))
			CollectionService:AddTag(copy, "TankFish")
			copy.Parent = folder
			folder.Parent = other
			return "decoy in " .. other.Name
		elseif verb == "undecoy" then
			for _, d in workspace:GetDescendants() do
				if d.Name == "B4Decoy" then
					d.Parent:Destroy()
				end
			end
			return "decoy gone"
		end
		return "?"
	end)
	RS:SetAttribute("B4Said", tostring(said))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local TankRide = require(Client:WaitForChild("Controllers"):WaitForChild("TankRideController"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local Config = require(RS.Shared:WaitForChild("Config"))
local report = RS:WaitForChild("ZZB4Report", 60)
local answers = {}
Net.Ride.OnClientEvent:Connect(function(what, a, b)
	if what == "Denied" or what == "TankMounted" or what == "TankDismounted" then
		table.insert(answers, what .. ":" .. tostring(a) .. (if b ~= nil and what == "Denied" then ":" .. tostring(b) else ""))
	end
end)
workspace:GetAttributeChangedSignal("B4Stand"):Connect(function()
	local cf = workspace:GetAttribute("B4Stand")
	local character = player.Character
	if typeof(cf) == "CFrame" and character then
		character:PivotTo(cf)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end)
local function plot()
	return workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(tostring(player:GetAttribute("Plot")))
end
local function fishes()
	local out = {}
	local shown = plot():FindFirstChild("TankFish")
	for _, m in (shown and shown:GetChildren() or {}) do
		table.insert(out, m)
	end
	table.sort(out, function(a, b)
		return a:GetExtentsSize().Magnitude < b:GetExtentsSize().Magnitude
	end)
	return out
end
local function took()
	local out = table.concat(answers, ",")
	table.clear(answers)
	return "answers=[" .. out .. "]"
end
-- the look kept on a fish (its screen point, every frame), a held key and a push, given to the controller's hooks
local target, push, held, lookYaw, lookPitch = nil, nil, false, nil, nil
-- where the look is now (a hold passes it too: a hold given without it left the look empty until the next frame, and
-- the controller, which looks first in a frame, dropped the hold)
local function lookNow()
	local camera = workspace.CurrentCamera
	if typeof(target) == "Instance" and target.PrimaryPart then
		local v = camera:WorldToViewportPoint(target.PrimaryPart.Position)
		return Vector2.new(v.X, v.Y)
	elseif typeof(target) == "Vector2" then
		return target
	end
	return nil
end
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	TankRide.pretend(lookNow(), nil, push)
	if lookYaw and TankRide.riding() then
		-- the view turned as a mouse drag would: round its focus
		local focus = camera.Focus.Position
		local back = (camera.CFrame.Position - focus).Magnitude
		local way = CFrame.Angles(0, lookYaw, 0) * CFrame.Angles(lookPitch or 0, 0, 0)
		camera.CFrame = CFrame.lookAt(focus - way.LookVector * back, focus)
	end
end)
local function turns(model)
	-- the sum of how far its joints are turned from rest now
	local sum, count = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local _, angle = d.Transform:ToAxisAngle()
			sum += math.abs(angle) + d.Transform.Position.Magnitude
			count += 1
		end
	end
	return sum, count
end
workspace:GetAttributeChangedSignal("B4Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("B4Do") or "")
	local verb, a = string.match(cmd, "^(%w+)|?([^|]*)")
	local said = ""
	local camera = workspace.CurrentCamera
	local p = plot()
	local water = p.TankWater
	local pad = p:FindFirstChild("Pad")
	local way = ((pad.Position - water.Position) * Vector3.new(1, 0, 1)).Unit
	local left = way:Cross(Vector3.yAxis)
	if verb == "look" then
		-- the nth fish of our tank, smallest first ("last": the biggest; "decoy"; "none": the real mouse again; "sky")
		local list = fishes()
		if a == "none" then
			target = nil
		elseif a == "sky" then
			target = Vector2.new(40, 40)
		elseif a == "decoy" then
			target = workspace:FindFirstChild("B4Decoy", true)
		elseif a == "last" then
			target = list[#list]
		else
			target = list[tonumber(a)]
		end
		-- (the view on the tank from behind us, as a player looking at their fish has it)
		if not TankRide.riding() then
			local root = player.Character.HumanoidRootPart
			camera.CFrame = CFrame.lookAt(root.Position + way * 24 + Vector3.new(0, 10, 0), water.Position)
		end
		task.wait(0.5)
		local aimed, fraction = TankRide.aimed()
		if typeof(target) == "Instance" then
			local v, on = camera:WorldToViewportPoint(target.PrimaryPart.Position)
			said = string.format("onScreen=%s ", tostring(on))
		end
		said = said .. string.format("target=%s aimed=%s ring=%.2f mark=%s", tostring(target and (typeof(target) == "Instance" and target:GetAttribute("FishType") or "point")),
			tostring(aimed and aimed:GetAttribute("FishType")), fraction,
			tostring(player.PlayerGui:FindFirstChild("TankRideMark") and player.PlayerGui.TankRideMark.Enabled))
	elseif verb == "hold" then
		-- E held for so long, then let go: what the ring showed on the way, and whether we got on
		local t = tonumber(a) or 1
		TankRide.pretend(lookNow(), true, push)
		local seen = {}
		local began = os.clock()
		while os.clock() - began < t do
			local _, fraction = TankRide.aimed()
			table.insert(seen, string.format("%.2f", fraction))
			task.wait(0.1)
		end
		TankRide.pretend(lookNow(), false, push)
		task.wait(0.6)
		said = "ring=[" .. table.concat(seen, " ") .. "] riding=" .. tostring(TankRide.riding()) .. " " .. took()
	elseif verb == "holdon" then
		TankRide.pretend(lookNow(), true, push)
		said = "holding"
	elseif verb == "holdoff" then
		TankRide.pretend(lookNow(), false, push)
		said = "let go"
	elseif verb == "push" then
		push = tonumber(a)
		said = "push " .. tostring(push)
	elseif verb == "view" then
		local y, pitch = string.match(a, "([^,]+),([^,]+)")
		lookYaw, lookPitch = tonumber(y) and math.rad(tonumber(y)), tonumber(pitch) and math.rad(tonumber(pitch))
		said = "view " .. a
	elseif verb == "off" then
		TankRide.pressOff()
		task.wait(0.8)
		said = "riding=" .. tostring(TankRide.riding()) .. " " .. took()
	elseif verb == "fire" then
		local args = Http:JSONDecode(a)
		if args[3] == "DECOY" then
			args[3] = workspace:FindFirstChild("B4Decoy", true)
		end
		Net.Action:FireServer(table.unpack(args))
		task.wait(0.8)
		said = "riding=" .. tostring(TankRide.riding()) .. " " .. took()
	elseif verb == "swim" then
		-- do the joints of the tank's fish move: each fish's joints' turn now and a moment later
		local out = {}
		local before = {}
		for _, m in fishes() do
			before[m] = turns(m)
		end
		task.wait(0.35)
		local rates = TankRide.speeds()
		for _, m in fishes() do
			local now, count = turns(m)
			table.insert(out, string.format("%s joints=%d turn=%.3f moved=%.3f beat=%.2f", tostring(m:GetAttribute("FishType")),
				count, now, math.abs(now - (before[m] or 0)), rates[m] or -1))
		end
		said = table.concat(out, " ; ")
	elseif verb == "holdset" then
		Config.TankRide.Hold = tonumber(a) or 0.5
		said = "hold " .. tostring(Config.TankRide.Hold)
	elseif verb == "cam" then
		-- the camera where a still wants it: "tank" (the whole tank from the front), "close"
		camera.CameraType = Enum.CameraType.Scriptable
		local dist = if a == "close" then 46 else 78
		local up = if a == "close" then 12 else 22
		camera.CFrame = CFrame.lookAt(water.Position + way * dist + Vector3.new(0, up, 0) + left * 6, water.Position)
		said = "cam " .. a
	elseif verb == "camback" then
		camera.CameraType = Enum.CameraType.Custom
		said = "cam back"
	elseif verb == "hud" then
		said = "mark=" .. tostring(player.PlayerGui:FindFirstChild("TankRideMark") and player.PlayerGui.TankRideMark.Enabled)
			.. " hint=" .. tostring(player.PlayerGui:FindFirstChild("TankRideHint") ~= nil)
			.. " zoom=" .. string.format("%.0f..%.0f", player.CameraMinZoomDistance, player.CameraMaxZoomDistance)
			.. " " .. took()
	end
	report:FireServer(said)
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return "[==[" + str(v) + "]==]"


def server(code):
    return run(["--ctx", "server", "--code", code])


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZB4Check")
	if old then old:Destroy() end
end
workspace:SetAttribute("B4Do", nil)
workspace:SetAttribute("B4Stand", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZB4Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZB4Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('B4Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('B4Said')"
    )


def do(c, wait=1.6):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('B4Client', '') "
        f"workspace:SetAttribute('B4Do', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('B4Client')"
    )


def shot(path):
    path = Path(path)
    path.unlink(missing_ok=True)
    out = run(["shot", str(path)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        now = path.stat().st_size if path.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    else:
        raise SystemExit("no shot: " + out)
    return Image.open(path).convert("RGB")


def scene(name):
    im = shot(OUT / f"raw_{name}.png")
    im.crop((OFFSET[0], OFFSET[1], OFFSET[0] + VIEW[0], OFFSET[1] + VIEW[1])).resize((1280, 700)).save(
        ATTACH / f"b4-{name}.png"
    )


LOG = []


def say(*parts):
    line = " ".join(str(p) for p in parts)
    print(line, flush=True)
    LOG.append(line)


FISH = [
    ["Clownfish", "Tiny", "Normal"],
    ["YellowTang", "Normal", "Normal"],
    ["ReefShark", "Normal", "Normal"],
    ["SeaTurtle", "Big", "Gold"],
    ["Dunkleosteus", "Giant", "Normal"],
    ["Mosasaurus", "Colossal", "Rainbow"],
]


SHOTS = [
    ["Clownfish", "Tiny", "Normal"],
    ["YellowTang", "Normal", "Normal"],
    ["ReefShark", "Normal", "Normal"],
    ["SeaTurtle", "Big", "Gold"],
    ["Dunkleosteus", "Normal", "Normal"],
]


def shots():
    """The stills, in a fresh playtest: the tank with real-size fish, the ring half full, the ride"""
    print(cmd("give|" + json.dumps(SHOTS), 1.5))
    print(cmd("front", 1.5))
    print(cmd("sizes"))
    do("cam|tank", 1.0)
    scene("tank-real-size")
    do("camback", 0.6)
    print(do("look|3", 1.2))
    do("holdset|6", 0.4)
    do("holdon", 3.0)
    scene("hold-ring")
    do("holdoff", 0.4)
    do("holdset|0.5", 0.4)
    print(do("look|3", 1.2))
    print(do("hold|0.9", 3.0))
    do("look|none", 0.6)
    do("view|200,-12", 0.4)
    do("push|1", 1.6)
    scene("riding")
    do("push|0", 0.5)
    do("cam|close", 1.0)
    scene("riding-wide")
    do("camback", 0.5)
    print(cmd("state"))
    print(do("off", 2.4))
    print(cmd("state"))


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "shots":
        shots()
        return
    if what == "install":
        print(install())
        return
    if what == "remove":
        print(install(True))
        return
    if what == "cmd":
        print(cmd(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.8))
        return
    if what == "do":
        print(do(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 1.6))
        return
    if what == "shot":
        scene(sys.argv[2])
        return
    say("give:", cmd("give|" + json.dumps(FISH), 1.5))
    say("front:", cmd("front", 1.5))
    say("sizes:", cmd("sizes"))
    say("state0:", cmd("state"))
    say("swim:", do("swim", 2.0))
    # the look: nothing looked at, then a fish; the ring fills while held, empties when let go early
    say("look sky:", do("look|sky"))
    # every fish of the tank picked by looking at it, smallest first: the giants (94 and 200 studs, all round the
    # others) must not take the look from a small one
    for n in range(1, len(FISH) + 1):
        say(f"pick {n}:", do(f"look|{n}"))
    say("look 2:", do("look|2"))
    say("hold 0.25 (let go early):", do("hold|0.25", 2.2))
    say("state after early:", cmd("state"))
    # another tank's fish: never picked by the look, and refused by the server when asked outright
    say("decoy:", cmd("decoy"))
    say("look decoy:", do("look|decoy"))
    say("fire decoy:", do("fire|" + json.dumps(["TankRide", "On", "DECOY"]), 2.2))
    say("state after decoy:", cmd("state"))
    say("undecoy:", cmd("undecoy"))
    # too far from the tank: not picked; asked outright, refused
    say("away:", cmd("away|90", 1.5))
    say("look 2 from afar:", do("look|2"))
    say("front:", cmd("front", 1.5))
    # the real thing: look, hold E past Hold, on
    say("look 3:", do("look|3"))
    say("hold 0.9:", do("hold|0.9", 3.0))
    say("mounted:", cmd("state"))
    say("hud:", do("hud"))
    # float, swim forward four ways, back, float
    say("float:", cmd("state", 2.0))
    for yaw in (0, 90, 180, 270):
        do(f"view|{yaw},-10", 0.3)
        do("push|1", 0.3)
        say(f"swim yaw {yaw}:", cmd("state", 3.0))
    do("view|45,30", 0.3)
    say("up:", cmd("state", 3.0))
    do("view|45,-50", 0.3)
    say("down:", cmd("state", 3.0))
    do("push|-1", 0.3)
    say("back:", cmd("state", 2.0))
    do("push|0", 0.3)
    say("stopped:", cmd("state", 2.5))
    say("swim ridden:", do("swim", 2.0))
    say("off:", do("off", 2.4))
    say("after off:", cmd("state", 1.0))
    say("hud:", do("hud"))
    (OUT / "check.log").write_text("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
