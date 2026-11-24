"""The submarine's camera, measured in a playtest: is it behind, on the middle line, in every phase of a trip?
(Hugo, 2026-11-23: "make sure it doesnt implement the camera on the side ever"; docs/design/submarine.md, "The camera
is always behind".) IT WALKS THE PLAYER OFF THE DOCK AND SENDS THEM ON TRIPS: run it only in a playtest you started
yourself, and make sure nobody is playing in it. It never sets the camera: it only reads it.
    python tools/studio/sub_camera_check.py install            (in Edit, before Play; prints the helper's size)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/sub_camera_check.py mine               (is this Play ours? the helper's size and token in it)
    python tools/studio/sub_camera_check.py gate               (are the stills live? finds the game view in the window)
    python tools/studio/sub_camera_check.py trip <tier> <land> [fish|-] [label] [side]   (one trip, measured; side:
                                                               studs right of the dock's middle to walk off at)
    python tools/studio/sub_camera_check.py stills <tier> <land> [fish] [tries] (trips with stills, until every phase has
                                                               one; a phase whose still is in docs/attachments is left)
    python tools/studio/sub_camera_check.py report [folder]    (the numbers again, of every trip in work/subcam[/folder])
    node ~/Projects/studio-runner/studio-run.mjs stop
    python tools/studio/sub_camera_check.py remove             (in Edit, after the stop)
How: a server Script picks the sub and the land through SubService's own test door (ServerStorage.SubTest) and sends
the player home after; a LocalScript walks the player off the dock's lip (Humanoid:Move, as a player running at the
water) and, every render frame AFTER every camera step (RenderPriority.Last), writes down where the camera is and
looks, where the rider and the sub are and face (the sub's frame from its hull as placed, not from the camera's own
sums), the shake, what the camera's pull-in ray hits, and what stands within 4 studs of the camera. The sums are made
here, from those places:
    Approach  the line through the rider along the way the rider faces (and against the way they travel);
    Pickup    the line through the rider along the lane (the way the rider faced as Approach ended: the line the
              camera follows, by docs/design/submarine.md). It was the sub's flat nose when the limits were written;
              the first run on the new camera showed the sub's own hull still 6.9 degrees off the lane on Pickup's
              first frame (it comes in from one side and is on the lane a frame later), which read as a camera 2
              studs off a line the camera does not follow. The reading against the nose is still printed, with the
              number of frames over the limit;
    Ride, Arrive, Drop (while carried)   the line through the sub's middle along its flat nose;
    after the sub lets go (the hop, or the saddle)   the line through the rider along the way the sub was going as
              it let go. (Not the way the rider travels: the first run, on the old camera, showed the hop's hook
              pulling the rider 50 degrees aside to a fish while the view never turned; that read as a camera at the
              side when it was the rider's path that bent. The travel reading is still printed, for what it is.)
On each: the camera's sideways distance from the line (studs), its bearing off straight-behind (0: straight behind,
90: at the side), and the view's turn off the line (degrees). The limits below were written before any run.
A small strip in the game view's top left corner says the phase by its colour, so each still knows its own phase;
it is cut off the stills kept. Log: work/subcam/check.log; frames work/subcam/<label>.txt; stills
docs/attachments/subcam-behind-*.jpg.
"""
import json
import math
import sys
import time
import uuid
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s2_subs_check as s2  # noqa: E402  (the runner's helpers only: run, job, server, lua)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/subcam"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
VIEW_FILE = OUT / "view.json"
TOKEN_FILE = OUT / "token.txt"
KELP_FILE = OUT / "kelp.json"

# The limits, written before any run (2026-11-23). Calm frames: no shake moving the camera. On shaken frames twice
# these. Approach and Pickup follow the rider, who barely moves: nothing but the shake may take the camera off the
# line. Arrive and Drop follow the sub at 90 studs a second with an eased camera: a bend in the lane may lag it a
# little. Ride is unchanged code and runs the lane's bends at up to thousands of studs a second: its lag is real,
# so its bound is loose. In every phase the camera must be behind (never level with or ahead of what it follows),
# unless the pull-in has it on top of the rider (within 1 stud of the line's start).
LIMITS = {
    "Approach": {"side": 1.0, "bearing": 3.0, "yaw": 3.0},
    "Pickup": {"side": 1.0, "bearing": 3.0, "yaw": 3.0},
    "Ride": {"side": 12.0, "bearing": 15.0, "yaw": 15.0},
    "Arrive": {"side": 3.0, "bearing": 6.0, "yaw": 6.0},
    "Drop": {"side": 3.0, "bearing": 6.0, "yaw": 6.0},
}
SIDE_AT = 45.0  # past this bearing a camera is "at the side" whatever follows (the hop's and the saddle's own cameras)
PHASES = ["Approach", "Pickup", "Ride", "Arrive", "Drop"]
# (stills: seconds to wait before the second and the third grab of the window, by trip; a grab takes 3 to 4.5 s)
WAITS = {
    "nofish": [(0.75, 0.95), (0.0, 1.2), (0.85, 1.05), (0.0, 0.0), (0.0, 1.35)],
    "fish": [(0.75, 0.0), (0.0, 0.6), (2.6, 0.0), (0.85, 0.0), (0.0, 0.0), (0.0, 0.75)],
}
COLOURS = {
    "Pre": (40, 40, 40),
    "Approach": (255, 0, 0),
    "Pickup": (0, 255, 0),
    "Ride": (0, 0, 255),
    "Arrive": (255, 255, 0),
    "Drop": (255, 0, 255),
    "Tail": (0, 255, 255),
}

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local data = Instance.new("Folder")
data.Name = "ZZSubCamData"
data.Parent = SS
local report = Instance.new("RemoteEvent")
report.Name = "ZZSubCamReport"
report.Parent = RS
report.OnServerEvent:Connect(function(_, kind, a, b)
	if kind == "said" then
		RS:SetAttribute("SCClient", tostring(a))
	elseif kind == "data" then
		local v = data:FindFirstChild(tostring(a)) or Instance.new("StringValue")
		v.Name = tostring(a)
		v.Value = tostring(b)
		v.Parent = data
	end
end)
RS:GetAttributeChangedSignal("SCCmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("SCCmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		local t = SS:WaitForChild("SubTest")
		if verb == "sub" then -- tier, land, fish id ("": the fling)
			local tier, land, fish = string.match(arg, "(%d+),(%d+),(%w*)")
			t:Invoke("give", player.UserId, 1e13, if fish ~= "" then { { fish, "Normal", "" } } else nil)
			for _ = 1, 9 do
				t:Invoke("buy", player.UserId)
			end
			t:Invoke("equip", player.UserId, tonumber(tier))
			return t:Invoke("pick", player.UserId, tonumber(land), if fish ~= "" then fish .. "|Normal|" else "")
		elseif verb == "home" then
			RideService.sendHome(player)
			t:Invoke("equip", player.UserId, 0)
			return t:Invoke("pick", player.UserId, 0, "")
		elseif verb == "st" then
			return string.format("state=%s phase=%s equip=%s", tostring(RideService.stateOf(player)),
				tostring(player:GetAttribute("SubPhase")), tostring(player:GetAttribute("SubEquip")))
		elseif verb == "clear" then
			data:ClearAllChildren()
			return "cleared"
		end
		return "?"
	end)
	RS:SetAttribute("SCSaid", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZSubCamReport")
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local SubTrip = require(RS.Shared:WaitForChild("SubTrip"))
local SubModels = require(RS.Shared:WaitForChild("SubModels"))
local Net = require(RS.Shared:WaitForChild("Net"))
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local Shake = require(Client.Lib:WaitForChild("Shake"))
local UP = Vector3.yAxis
local FLAT = Vector3.new(1, 0, 1)
local COLOURS = __COLOURS__

-- the strip that says the phase: three blocks in the view's top left corner
local gui = Instance.new("ScreenGui")
gui.Name = "ZZSubCamMark"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100000
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local blocks = {}
for i = 1, 3 do
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(40, 10)
	f.Position = UDim2.fromOffset((i - 1) * 40, 0)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.Parent = gui
	blocks[i] = f
end
local function mark(a, b, c)
	blocks[1].BackgroundColor3 = a
	blocks[2].BackgroundColor3 = b
	blocks[3].BackgroundColor3 = c
end
local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function controls(on)
	local ok, module = pcall(function()
		return require(player.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls()
	end)
	if ok and module then
		if on then module:Enable() else module:Disable() end
	end
end

local function groundUnder(at)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local list = { workspace.CurrentCamera }
	for _, other in Players:GetPlayers() do
		if other.Character then table.insert(list, other.Character) end
	end
	p.FilterDescendantsInstances = list
	p.RespectCanCollide = true
	p.IgnoreWater = true
	local hit = workspace:Raycast(at, -UP * 40, p)
	return hit and hit.Position.Y or nil
end

-- the dock's lip: from the dock spawn, out along its look until there is no ground under (as dive_leap_check)
local function lip()
	local dock = Net.Folder:GetAttribute("Dock")
	if typeof(dock) ~= "CFrame" then return nil end
	local out = (dock.LookVector * FLAT).Unit
	local from = dock.Position + UP * 4
	local floor = nil
	for step = 0, 800 do
		local at = from + out * (step * 0.5)
		local top = groundUnder(at)
		if not top then
			if not floor then return nil end
			local edge = from + out * math.max(step * 0.5 - 0.5, 0)
			return Vector3.new(edge.X, floor, edge.Z), floor, out
		end
		floor = top
	end
	return nil
end

-- the sub's own frame from its hull as placed: the hull part sits in it where a freshly built one sits at the origin
local rest = {}
local function hullRest(tier)
	if not rest[tier] then
		local model = SubModels.build(tier)
		rest[tier] = (model.PrimaryPart :: BasePart).CFrame
		model:Destroy()
	end
	return rest[tier]
end
local function ourSub()
	for _, m in workspace.CurrentCamera:GetChildren() do
		if m.Name == "Submarine" and m:GetAttribute("For") == player.UserId and m.PrimaryPart then
			local tier = player:GetAttribute("SubEquip")
			tier = if type(tier) == "number" and tier >= 1 then tier else 1
			return m, m.PrimaryPart.CFrame * hullRest(tier):Inverse()
		end
	end
	return nil, nil
end

local rec = nil -- the trip being written down
local names, nameIx = {}, {}
local function nameOf(inst)
	local full = inst:GetFullName()
	local i = nameIx[full]
	if not i then
		table.insert(names, full)
		i = #names
		nameIx[full] = i
	end
	return i
end

Net.Ride.OnClientEvent:Connect(function(kind, a, b)
	local r = rec
	if not r then return end
	if kind == "SubFish" and typeof(a) == "Instance" then
		r.fish = a
	elseif kind == "SubDrop" then
		r.cue = tostring(a)
		r.cueAt = if r.trip then workspace:GetServerTimeNow() - r.trip.Start else -1
		if typeof(b) == "Instance" then r.fish = b end
	end
end)

local function skipList(model, fish)
	local list = { workspace.CurrentCamera }
	if model then table.insert(list, model) end
	if player.Character then table.insert(list, player.Character) end
	local map = workspace:FindFirstChild("ClaudeBlockout")
	local lane = map and map:FindFirstChild("Lane")
	local props = lane and lane:FindFirstChild("Props")
	local surface = map and map:FindFirstChild("Surface")
	if props then table.insert(list, props) end
	if surface then table.insert(list, surface) end
	if fish then table.insert(list, fish) end
	return list
end

-- the gate's kelp under the water: how many plates are see-through on our screen now
local kelpList = nil
local function kelpOut()
	if not kelpList then
		kelpList = {}
		local map = workspace:FindFirstChild("ClaudeBlockout")
		local dock = map and map:FindFirstChild("Dock")
		local gate = dock and dock:FindFirstChild("Gate")
		if gate then
			for _, p in gate:GetChildren() do
				if p:IsA("BasePart") and p.Name == "Kelp" and p.Position.Y < Config.Oxygen.SurfaceY then table.insert(kelpList, p) end
			end
		end
	end
	local n = 0
	for _, p in kelpList do
		if p.LocalTransparencyModifier >= 0.5 then n += 1 end
	end
	return n
end

local function screen(camera, at)
	local p, on = camera:WorldToViewportPoint(at)
	local size = camera.ViewportSize
	return if on then 1 else 0, p.X / size.X, p.Y / size.Y
end

local function step(dt)
	local r = rec
	if not r then return end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local json = player:GetAttribute("SubTrip")
	if type(json) == "string" and json ~= r.json then
		r.json = json
		r.trip = SubTrip.decode(json)
		r.tier = player:GetAttribute("SubEquip")
	end
	local trip = r.trip
	local t, phase, share = -1, "Pre", 0
	if trip then
		t = workspace:GetServerTimeNow() - trip.Start
		phase = SubTrip.phase(trip, t)
		local a, b, c, d, e = SubTrip.times(trip)
		local from, to = 0, a
		if phase == "Pickup" then from, to = a, b
		elseif phase == "Ride" then from, to = b, c
		elseif phase == "Arrive" then from, to = c, d
		elseif phase == "Drop" then from, to = d, e
		elseif phase == "Done" then phase, from, to = "Tail", e, e + 3 end
		share = math.clamp((t - from) / math.max(to - from, 0.01), 0, 1)
		if not r.entry then r.entry = root.Position end
	end
	local g = math.floor(share * 255 + 0.5)
	mark(rgb(COLOURS[phase]), Color3.fromRGB(g, g, g), Color3.fromRGB(255, 255, 255))
	if r.done or #r.rows >= 9000 then return end
	if trip and r.until_ and t > r.until_ then
		r.done = true
		r.modeEnd = State.Mode
		return
	end
	if trip and not r.until_ then
		local _, _, _, _, e = SubTrip.times(trip)
		r.until_ = e + 2.5
	end
	local cf = camera.CFrame
	local model, sub = ourSub()
	local fish = r.fish
	local fishRoot = fish and fish.Parent and fish.PrimaryPart
	-- the pull-in's own ray again (SubController.cameraFor): from 2 over what it follows to the camera, and 2.6 on
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local skip = skipList(model, fish)
	params.FilterDescendantsInstances = skip
	local anchor = if (phase == "Approach" or phase == "Pickup" or phase == "Pre" or not sub) then root.Position else sub.Position
	local from = anchor + UP * 2
	local to = cf.Position - from
	local len = to.Magnitude
	local gap, hitName = 99, 0
	if len > 0.05 then
		local hit = workspace:Raycast(from, to.Unit * (len + 2.6), params)
		if hit then
			gap = (hit.Position - from).Magnitude - len
			hitName = nameOf(hit.Instance)
		end
	end
	-- what stands close to the camera, and what it is inside
	local near, inside = "-", "-"
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = skip
	local close = workspace:GetPartBoundsInRadius(cf.Position, 4, op)
	if #close > 0 then
		local list = {}
		for i = 1, math.min(#close, 6) do
			if close[i].Transparency < 0.98 then table.insert(list, tostring(nameOf(close[i]))) end
		end
		if #list > 0 then near = table.concat(list, ",") end
	end
	local within = workspace:GetPartBoundsInRadius(cf.Position, 0.3, op)
	if #within > 0 then
		local list = {}
		for i = 1, math.min(#within, 4) do
			if within[i].Transparency < 0.98 then table.insert(list, tostring(nameOf(within[i]))) end
		end
		if #list > 0 then inside = table.concat(list, ",") end
	end
	local rOn, rX, rY = screen(camera, root.Position)
	local sOn, sX, sY = 0, 0, 0
	local sp, sl = Vector3.zero, Vector3.zero
	if sub then
		sOn, sX, sY = screen(camera, sub.Position)
		sp, sl = sub.Position, sub.LookVector
	end
	local fOn, fX, fY, fp = -1, 0, 0, Vector3.zero
	if fishRoot then
		fOn, fX, fY = screen(camera, fishRoot.Position)
		fp = fishRoot.Position
	end
	local look = cf.LookVector
	local face = root.CFrame.LookVector
	table.insert(r.rows, string.format(
		"%d %.4f %s %s %.5f %.3f %.3f %.3f %.5f %.5f %.5f %.2f %.3f %.3f %.3f %.4f %.4f %.4f %d %.3f %.3f %.3f %.4f %.4f %.4f %.4f %.3f %.3f %d %d %.3f %.3f %d %.3f %.3f %d %.3f %.3f %.3f %.3f %.3f %s %s %s %d",
		#r.rows + 1, t, phase, tostring(State.Mode), dt,
		cf.Position.X, cf.Position.Y, cf.Position.Z, look.X, look.Y, look.Z, camera.FieldOfView,
		root.Position.X, root.Position.Y, root.Position.Z, face.X, face.Y, face.Z,
		if sub then 1 else 0, sp.X, sp.Y, sp.Z, sl.X, sl.Y, sl.Z,
		Shake.moving(), len, gap, hitName,
		rOn, rX, rY, sOn, sX, sY, fOn, fX, fY, fp.X, fp.Y, fp.Z,
		string.sub(camera.CameraType.Name, 1, 1), near, inside, kelpOut()))
end
RunService:BindToRenderStep("ZZSubCam", Enum.RenderPriority.Last.Value, step)

local function v3(v)
	return { math.floor(v.X * 100 + 0.5) / 100, math.floor(v.Y * 100 + 0.5) / 100, math.floor(v.Z * 100 + 0.5) / 100 }
end

workspace:GetAttributeChangedSignal("SCDo"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("SCDo") or "")
	local words = string.split(cmd, "|")
	local verb = words[1]
	local ok, said = pcall(function()
		if verb == "ping" then
			local size = workspace.CurrentCamera.ViewportSize
			return string.format("pong mode=%s view=%dx%d", tostring(State.Mode), size.X, size.Y)
		elseif verb == "mark" then
			-- cal, cal2: two known pictures of the strip (where the game view is in the window, and are the stills live);
			-- off: no strip
			gui.Enabled = words[2] ~= "off"
			if words[2] == "cal" then
				mark(Color3.fromRGB(255, 0, 255), Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 255, 255))
			elseif words[2] == "cal2" then
				mark(Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 255, 255))
			end
			return "mark " .. tostring(words[2])
		elseif verb == "rec" then
			-- a new record: every frame from now to 2.5 s past the trip's end
			names, nameIx = {}, {}
			rec = { label = words[2], rows = {}, started = os.clock() }
			gui.Enabled = true
			return "rec " .. tostring(words[2])
		elseif verb == "walk" then
			-- off the dock's lip, as a player running at the water: stood a run-up behind it, walked off
			local lipAt, _, out = lip()
			if not lipAt then return "no lip found" end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then return "no character" end
			local runup = tonumber(words[2]) or 12
			local side = tonumber(words[3]) or 0
			local height = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
			local right = out:Cross(UP)
			local stand = lipAt - out * runup + right * side + UP * (height + 0.2)
			controls(false)
			humanoid:Move(Vector3.zero)
			character:PivotTo(CFrame.lookAt(stand, stand + out))
			root.AssemblyLinearVelocity = Vector3.zero
			task.wait(0.8)
			if rec then
				rec.lip = lipAt
				rec.out = out
			end
			local began = os.clock()
			while os.clock() - began < 8 and State.Mode == "Dock" and not player:GetAttribute("SubTrip") do
				humanoid:Move(out)
				task.wait()
			end
			humanoid:Move(Vector3.zero)
			if State.Mode == "Dock" and not player:GetAttribute("SubTrip") then
				controls(true)
			end
			return string.format("walked %.2f s lip=%.1f,%.1f,%.1f mode=%s trip=%s at=%.1f,%.1f,%.1f", os.clock() - began, lipAt.X, lipAt.Y,
				lipAt.Z, tostring(State.Mode), tostring(player:GetAttribute("SubTrip") ~= nil), root.Position.X, root.Position.Y, root.Position.Z)
		elseif verb == "state" then
			local r = rec
			return string.format("mode=%s rows=%d done=%s trip=%s cue=%s", tostring(State.Mode), r and #r.rows or -1, tostring(r and r.done),
				tostring(r and r.trip ~= nil), tostring(r and r.cue))
		elseif verb == "flush" then
			local r = rec
			if not r then return "no record" end
			controls(true)
			local trip = r.trip
			local meta = { label = r.label, rows = #r.rows, names = names, cue = r.cue, cueAt = r.cueAt, modeEnd = r.modeEnd or State.Mode,
				modeNow = State.Mode, tier = r.tier, view = { workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y },
				surfaceY = Config.Oxygen.SurfaceY, fishSide = Config.Sub.FishSide }
			if r.lip then meta.lip = v3(r.lip) meta.out = v3(r.out) end
			if r.entry then meta.entry = v3(r.entry) end
			if trip then
				local a, b, c, d, e = SubTrip.times(trip)
				meta.trip = { land = trip.Land, fish = trip.Fish, times = { a, b, c, d, e }, top = trip.Top, drop = trip.Drop,
					length = trip.Length, pick = v3(trip.Points[1]) }
			end
			report:FireServer("data", r.label .. ":meta", HttpService:JSONEncode(meta))
			local chunk, size, n = {}, 0, 0
			for _, row in r.rows do
				table.insert(chunk, row)
				size += #row + 1
				if size > 120000 then
					n += 1
					report:FireServer("data", r.label .. ":" .. n, table.concat(chunk, "\n"))
					chunk, size = {}, 0
				end
			end
			if #chunk > 0 then
				n += 1
				report:FireServer("data", r.label .. ":" .. n, table.concat(chunk, "\n"))
			end
			report:FireServer("data", r.label .. ":chunks", tostring(n))
			return string.format("flushed %s rows=%d chunks=%d", r.label, #r.rows, n)
		end
		return "?"
	end)
	report:FireServer("said", tostring(said) .. " " .. tostring(ok))
end)
'''

LOG = []


def note(text):
    print(text, flush=True)
    LOG.append(text)


def save_log():
    with open(OUT / "check.log", "a", encoding="utf-8") as f:
        f.write("\n".join(LOG) + "\n")
    LOG.clear()


def client_source():
    colours = "{ " + ", ".join('%s = { %d, %d, %d }' % (k, *v) for k, v in COLOURS.items()) + " }"
    return CLIENT.replace("__COLOURS__", colours)


def install(remove=False):
    token = "" if remove else uuid.uuid4().hex[:12]
    out = s2.job(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZSubCamCheck")
	if old then old:Destroy() end
end
workspace:SetAttribute("SCDo", nil)
game:GetService("ReplicatedStorage"):SetAttribute("SCCmd", nil)
game:GetService("ReplicatedStorage"):SetAttribute("SCSaid", nil)
game:GetService("ReplicatedStorage"):SetAttribute("SCClient", nil)
if {s2.lua(remove)} then
	local left = {{}}
	for _, at in {{ sss, sps, game:GetService("ReplicatedStorage"), game:GetService("ServerStorage"), workspace }} do
		for _, c in at:GetChildren() do
			if string.sub(c.Name, 1, 2) == "ZZ" then table.insert(left, c:GetFullName()) end
		end
	end
	return "removed; ZZ things left: " .. (if #left > 0 then table.concat(left, ", ") else "none")
end
local s = Instance.new("Script")
s.Name = "ZZSubCamCheck"
s.Source = {s2.lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZSubCamCheck"
c.Source = {s2.lua(client_source())}
c:SetAttribute("Token", {s2.lua(token)})
c.Parent = sps
return "installed client=" .. #c.Source .. " server=" .. #s.Source .. " token=" .. c:GetAttribute("Token")
""")
    if not remove:
        # (a Lua long string drops a newline right after its opening bracket: the place's copy is that much shorter)
        source = client_source()
        TOKEN_FILE.write_text(token + " " + str(len(source.encode()) - (1 if source.startswith("\n") else 0)))
    return out


def mine():
    """Is the running Play ours? The helper in it must be the one `install` just made (its token and its size)."""
    token, size = TOKEN_FILE.read_text().split()
    said = s2.server(
        "local c = game:GetService('StarterPlayer').StarterPlayerScripts:FindFirstChild('ZZSubCamCheck') "
        "return c and (tostring(c:GetAttribute('Token')) .. ' ' .. #c.Source) or 'no helper'"
    )
    ours = said.strip().splitlines()[-1].strip() == f"{token} {size}" if said.strip() else False
    return ours, said


def cmd(c, wait=0.8):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('SCCmd', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('SCSaid')"
    )


def do(c, wait=1.0):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('SCClient', '') "
        f"workspace:SetAttribute('SCDo', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('SCClient')"
    )


def fire(c):
    """a word to the client, not waited for (the stills begin at once)"""
    return s2.server(f"workspace:SetAttribute('SCDo', {s2.lua(c + '|' + str(time.time()))}) return 'sent'")


def value(name):
    out = s2.server(
        f"local v = game:GetService('ServerStorage').ZZSubCamData:FindFirstChild({s2.lua(name)}) return v and v.Value or 'MISSING'"
    )
    return out


# --- stills -----------------------------------------------------------------------------------------------------------

def raw(name):
    """one picture of Studio's whole window (the runner's `shot` returns before the file is written)"""
    full = OUT / (name + "-full.png")
    full.unlink(missing_ok=True)
    out = s2.run(["shot", str(full)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        now = full.stat().st_size if full.exists() else -1
        if now > 0 and now == size:
            return full
        size = now
        time.sleep(0.08)
    raise SystemExit("no shot: " + out)


def near(a, b, tol=40):
    return all(abs(a[i] - b[i]) <= tol for i in range(3))


def find_strip(im, colour):
    """the first block of the strip (40 x 10 points of `colour`) in a picture of the window: its box, or None"""
    w, h = im.size
    px = im.load()
    for y in range(0, min(h, 500)):
        for x in range(0, w, 4):
            if near(px[x, y], colour):
                x0 = x
                while x0 > 0 and near(px[x0 - 1, y], colour):
                    x0 -= 1
                x1 = x0
                while x1 + 1 < w and near(px[x1 + 1, y], colour):
                    x1 += 1
                y1 = y
                while y1 + 1 < h and near(px[x0 + 2, y1 + 1], colour):
                    y1 += 1
                if x1 - x0 >= 20 and y1 - y >= 4:
                    return x0, y, x1 + 1, y1 + 1
    return None


def gate():
    """Are the stills live, and where is the game view in the window's picture? Two pictures of the strip in two
    known colours: both must be found."""
    end = time.time() + 60
    said = ""
    while time.time() < end:
        said = do("ping", 0.8)
        if "pong" in said:
            break
        time.sleep(1)
    note("client: " + said)
    vw, vh = [int(v) for v in said.split("view=")[1].split()[0].split("x")]
    note(do("mark|cal", 0.8))
    time.sleep(1.2)
    a = Image.open(raw("gate-a")).convert("RGB")
    box = find_strip(a, (255, 0, 255))
    note(do("mark|cal2", 0.8))
    time.sleep(1.2)
    b = Image.open(raw("gate-b")).convert("RGB")
    box2 = find_strip(b, (0, 255, 255))
    note(f"window picture {a.size}; strip found at {box} then {box2}")
    if not box or not box2:
        save_log()
        raise SystemExit("FROZEN or hidden: the strip was not found in both pictures (is Studio's window covered?)")
    scale = (box[2] - box[0]) / 40
    view = [box[0], box[1], round(box[0] + vw * scale), round(box[1] + vh * scale), scale]
    view[2], view[3] = min(view[2], a.size[0]), min(view[3], a.size[1])
    VIEW_FILE.write_text(json.dumps(view))
    note(f"game view {vw}x{vh} at scale {scale:.3f}: {view[:4]} in the window's picture; stills are live")
    for n in ("gate-a", "gate-b"):
        (OUT / (n + "-full.png")).unlink(missing_ok=True)
    save_log()


def read_strip(im):
    """the phase and how far through it, from the strip in a picture of the window"""
    x0, y0, _, _, scale = json.loads(VIEW_FILE.read_text())
    px = im.load()
    a = px[round(x0 + 20 * scale), round(y0 + 5 * scale)]
    b = px[round(x0 + 60 * scale), round(y0 + 5 * scale)]
    c = px[round(x0 + 100 * scale), round(y0 + 5 * scale)]
    if not near(c, (255, 255, 255), 30):
        return None, 0.0
    for phase, colour in COLOURS.items():
        if near(a, colour, 45):
            return phase, b[0] / 255
    return None, 0.0


def keep_still(full, path):
    """the game view cut out of the window's picture, the strip's rows off its top"""
    x0, y0, x1, y1, scale = json.loads(VIEW_FILE.read_text())
    im = Image.open(full).convert("RGB").crop((x0, y0 + math.ceil(11 * scale), x1, y1))
    im.save(path)
    return path


# --- one trip ---------------------------------------------------------------------------------------------------------

def start_trip(tier, land, fish, label, side=0, wait=True):
    """the sub and the land picked, the record begun, the player walked off the lip (`side` studs right of the dock's
    middle). True once the trip has begun (`wait` False: not waited for, the walk is only sent)"""
    note(f"[{label}] tier {tier} to land {land}, fish {fish or 'none'}: " + cmd(f"sub|{tier},{land},{fish}", 1.5))
    note("  " + do(f"rec|{label}", 0.4))
    if not wait:
        fire(f"walk|12|{side}")
        return True
    said = do(f"walk|12|{side}", 5.0)
    note("  " + said)
    return "trip=true" in said


def end_trip(label):
    """waits for the record's end, brings the frames home, sends the player home"""
    end = time.time() + 40
    said = ""
    while time.time() < end:
        said = do("state", 0.2)
        if "done=true" in said:
            break
        time.sleep(0.5)
    note("  " + said + " | " + cmd("st", 0.2))
    note("  " + do("flush", 2.0))
    meta = json.loads(value(label + ":meta"))
    chunks = int(value(label + ":chunks").strip().splitlines()[-1])
    rows = []
    for i in range(1, chunks + 1):
        rows += [line for line in value(f"{label}:{i}").splitlines() if line and line[0].isdigit()]
    (OUT / f"{label}.txt").write_text(json.dumps(meta) + "\n" + "\n".join(rows) + "\n")
    note(f"  frames: {len(rows)} of {meta['rows']} in work/subcam/{label}.txt")
    note("  home: " + cmd("home", 3))
    time.sleep(1.5)
    return meta, rows


def trip(tier, land, fish, label, side=0):
    if not start_trip(tier, land, fish, label, side):
        note("  ! no trip began")
        cmd("home", 3)
        save_log()
        return None
    meta, rows = end_trip(label)
    result = analyse(meta, rows)
    note(result["text"])
    save_log()
    return result


def stills(tier, land, fish, tries=8):
    """trips with stills taken as fast as they come; the one nearest the middle of each phase is kept"""
    kind = "fish" if fish else "nofish"
    best = {}
    # (without a fish the Drop is the fling: the sub's camera has it for two frames, then the hop's own takes over)
    wanted = set(PHASES) if fish else set(PHASES) - {"Drop"}
    # (a second go only takes what the first one missed)
    wanted -= {p for i, p in enumerate(PHASES, 1) if (ATTACH / f"subcam-behind-{kind}-{i}-{p.lower()}.jpg").exists()}
    for attempt in range(1, tries + 1):
        label = f"stills-{kind}-{attempt}"
        start_trip(tier, land, fish, label, wait=False)
        # (a grab of the window takes about 3 seconds and the short phases are under one: the waits before the
        # second and the third grab put them in Approach and Ride, then Pickup and Arrive, then Pickup and Drop)
        waits = WAITS[kind][(attempt - 1) % len(WAITS[kind])]
        n = 0
        end = time.time() + 22
        seen = []
        while time.time() < end:
            n += 1
            if n in (2, 3):
                time.sleep(waits[n - 2])
            full = raw(f"{label}-{n}")
            phase, share = read_strip(Image.open(full).convert("RGB"))
            seen.append(f"{phase}:{share:.2f}" if phase else "-")
            if phase in wanted:
                score = abs(share - 0.55)
                if phase not in best or score < best[phase][0]:
                    path = OUT / f"still-{kind}-{phase}.png"
                    keep_still(full, path)
                    best[phase] = (score, share, label, path)
            full.unlink(missing_ok=True)
            if phase == "Tail" and share > 0.3:
                break
        note(f"  stills this trip: {' '.join(seen)}")
        if not any(p.split(":")[0] in PHASES + ["Tail"] for p in seen):
            note("  ! no trip began: " + do("state", 0.3))
            cmd("home", 3)
            continue
        meta, rows = end_trip(label)
        result = analyse(meta, rows)
        note(result["text"])
        missing = wanted - set(best)
        note(f"  phases with a still so far: {sorted(best)}; missing: {sorted(missing)}")
        save_log()
        if not missing:
            break
    for i, phase in enumerate(PHASES, 1):
        if phase in best:
            _, share, label, path = best[phase]
            out = ATTACH / f"subcam-behind-{kind}-{i}-{phase.lower()}.jpg"
            Image.open(path).convert("RGB").save(out, quality=90)
            note(f"still: {out}  ({phase}, {share:.2f} through it, trip {label})")
    save_log()
    return best


# --- the sums ---------------------------------------------------------------------------------------------------------

def kelp_boxes(fetch=False):
    """the gate's kelp plates under the water, as boxes (a CFrame's 12 numbers and a size each), read from the place.
    The kelp is not a thing a ray can hit (CanQuery off), so neither the game's pull-in nor this check's own ray and
    overlap tests see it: the first stills did (a wall of green in Pickup), and this reading was added after them."""
    if fetch or not KELP_FILE.exists():
        out = s2.job("""local list = {}
local gate = workspace.ClaudeBlockout.Dock.Gate
local surface = require(game:GetService("ReplicatedStorage").Shared.Config).Oxygen.SurfaceY
for _, p in gate:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Kelp" and p.Position.Y < surface then
		local row = { p.CFrame:GetComponents() }
		table.insert(row, p.Size.X) table.insert(row, p.Size.Y) table.insert(row, p.Size.Z)
		table.insert(list, row)
	end
end
return game:GetService("HttpService"):JSONEncode(list)
""")
        KELP_FILE.write_text(out.strip().splitlines()[-1])
    return json.loads(KELP_FILE.read_text())


def crosses(box, a, b):
    """whether the straight line from a to b goes through the box"""
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, sx, sy, sz = box

    def local(p):
        d = (p[0] - x, p[1] - y, p[2] - z)
        return (r00 * d[0] + r10 * d[1] + r20 * d[2], r01 * d[0] + r11 * d[1] + r21 * d[2], r02 * d[0] + r12 * d[1] + r22 * d[2])

    p, q = local(a), local(b)
    t0, t1 = 0.0, 1.0
    for i, half in enumerate((sx / 2, sy / 2, sz / 2)):
        d = q[i] - p[i]
        if abs(d) < 1e-9:
            if abs(p[i]) > half:
                return False
            continue
        u0, u1 = (-half - p[i]) / d, (half - p[i]) / d
        if u0 > u1:
            u0, u1 = u1, u0
        t0, t1 = max(t0, u0), min(t1, u1)
        if t0 > t1:
            return False
    return True


def flat(x, z):
    m = math.hypot(x, z)
    return (x / m, z / m) if m > 1e-6 else None


def parse(rows):
    out = []
    for line in rows:
        w = line.split()
        if len(w) < 44:
            continue
        f = [float(v) for v in w[4:41]]
        out.append({
            "i": int(w[0]), "t": float(w[1]), "phase": w[2], "mode": w[3], "dt": f[0],
            "cam": (f[1], f[2], f[3]), "look": (f[4], f[5], f[6]), "fov": f[7],
            "rider": (f[8], f[9], f[10]), "face": (f[11], f[12], f[13]),
            "hasSub": f[14] > 0, "sub": (f[15], f[16], f[17]), "subLook": (f[18], f[19], f[20]),
            "shake": f[21], "len": f[22], "gap": f[23], "hit": int(f[24]),
            "rOn": f[25] > 0, "rX": f[26], "rY": f[27], "sOn": f[28] > 0, "sX": f[29], "sY": f[30],
            "fOn": f[31], "fX": f[32], "fY": f[33], "fish": (f[34], f[35], f[36]),
            "type": w[41], "near": w[42], "inside": w[43], "kelpOut": int(w[44]) if len(w) > 44 else 0,
        })
    return out


def against(cam, look, origin, way):
    """the camera against a line through `origin` along the flat way `way`: sideways (right is +), behind, bearing
    off straight-behind, and the view's turn off the line (degrees; None where there is nothing to measure)"""
    fx, fz = way
    rx, rz = -fz, fx
    dx, dz = cam[0] - origin[0], cam[2] - origin[2]
    back = -(dx * fx + dz * fz)
    side = dx * rx + dz * rz
    bearing = math.degrees(math.atan2(side, back)) if math.hypot(side, back) > 1.0 else None
    lf = flat(look[0], look[2])
    yaw = math.degrees(math.atan2(lf[0] * rx + lf[1] * rz, lf[0] * fx + lf[1] * fz)) if lf else None
    return side, back, bearing, yaw


def travel(frames, i, span=4):
    """the flat way the rider travels at frame i (None when nearly still)"""
    a, b = frames[max(i - span, 0)], frames[min(i + span, len(frames) - 1)]
    dx, dz = b["rider"][0] - a["rider"][0], b["rider"][2] - a["rider"][2]
    dt = sum(f["dt"] for f in frames[max(i - span, 0) + 1:min(i + span, len(frames) - 1) + 1]) or 1e-3
    if math.hypot(dx, dz) / dt < 5:
        return None
    return flat(dx, dz)


def angle_between(a, b):
    d = max(-1.0, min(1.0, a[0] * b[0] + a[1] * b[1] + a[2] * b[2]))
    return math.degrees(math.acos(d))


class Most:
    """the biggest |value| seen, and when"""

    def __init__(self):
        self.v, self.t = 0.0, None

    def see(self, v, t):
        if v is not None and abs(v) >= abs(self.v):
            self.v, self.t = v, t

    def __str__(self):
        return f"{self.v:+.2f}" + (f" (t={self.t:.2f})" if self.t is not None else "")


def analyse(meta, rows):
    frames = parse(rows)
    names = meta.get("names", [])
    tr = meta.get("trip")
    lines = []
    fails = []
    label = meta["label"]
    if not tr or not frames:
        return {"text": f"[{label}] NO TRIP in the record", "pass": False, "fails": ["no trip"]}
    a, b, c, d, e = tr["times"]
    lines.append(
        f"[{label}] land {tr['land']} fish={tr['fish']} cue={meta.get('cue')} at t={meta.get('cueAt') or -1:.2f} "
        f"ends in mode {meta.get('modeEnd')} | phases: pickup {a:.2f} ride {b:.2f} arrive {c:.2f} drop {d:.2f} end {e:.2f} s, "
        f"top speed {tr['top']:.0f}, frames {len(frames)}")
    if meta.get("lip") and meta.get("entry"):
        lip, entry, out = meta["lip"], meta["entry"], meta["out"]
        ahead = (entry[0] - lip[0]) * out[0] + (entry[2] - lip[2]) * out[2]
        lines.append(f"  went in {ahead:.1f} studs out from the dock's lip, {lip[1] - entry[1]:.1f} under its floor (a walk off the lip)")
    stats = {}
    prev = None
    lead = []
    held = [f for f in frames if f["mode"] == "Carried" and f["hasSub"] and f["phase"] != "Pre"]
    drop_way = flat(held[-1]["subLook"][0], held[-1]["subLook"][2]) if held else None
    kelp = kelp_boxes() if KELP_FILE.exists() else []
    swum = [f for f in frames if f["phase"] == "Approach"]
    lane = flat(swum[-1]["face"][0], swum[-1]["face"][2]) if swum else None
    for i, f in enumerate(frames):
        ph = f["phase"]
        if ph == "Pre":
            prev = f
            continue
        carried = f["mode"] == "Carried"
        if ph == "Approach" and f["type"] != "S" and not carried:
            # (the trip is made but the sub's camera has not the view yet: still the player's own camera on the
            # dock, a frame or two, on the old code as well. Not the sub's camera, so counted and not judged; this
            # was added after the runs, which had read these frames as a sub camera up to 150 degrees off)
            lead.append(f["t"])
            prev = f
            continue
        key = ph if (ph in ("Approach", "Pickup", "Ride", "Arrive") or (ph == "Drop" and carried)) else "After"
        s = stats.setdefault(key, {
            "n": 0, "calm": 0, "side": Most(), "bearing": Most(), "yaw": Most(), "sideS": Most(), "bearingS": Most(),
            "yawS": Most(), "backMin": 1e9, "backMax": -1e9, "ahead": 0, "onTop": 0, "pulled": {}, "near": {},
            "inside": {}, "rot": Most(), "jump": Most(), "rOn": 0, "sOn": 0, "sFirst": None, "fN": 0, "fOn": 0,
            "fOff": Most(), "types": set(), "riderSide": Most(), "riderBearing": Most(), "crab": Most(), "fov": [1e9, -1e9],
            "modes": set(), "pitch": [1e9, -1e9], "bearingT": Most(), "yawT": Most(), "nT": 0, "bearingD": Most(),
            "yawD": Most(), "yawFirst": None, "yawTurn": Most(), "noseSide": Most(), "noseBearing": Most(),
            "noseOver": 0, "noseOff": Most(), "kelpIn": 0, "kelpSolid": 0, "kelpT": [1e9, -1e9]})
        s["n"] += 1
        s["types"].add(f["type"])
        s["modes"].add(f["mode"])
        s["fov"] = [min(s["fov"][0], f["fov"]), max(s["fov"][1], f["fov"])]
        pitch = math.degrees(math.asin(max(-1, min(1, f["look"][1]))))
        s["pitch"] = [min(s["pitch"][0], pitch), max(s["pitch"][1], pitch)]
        calm = f["shake"] < 0.02
        # the gate's kelp between the camera and the rider, and whether it shows
        if kelp and any(crosses(box, f["cam"], f["rider"]) for box in kelp):
            s["kelpIn"] += 1
            if f["kelpOut"] == 0:
                s["kelpSolid"] += 1
                s["kelpT"] = [min(s["kelpT"][0], f["t"]), max(s["kelpT"][1], f["t"])]
        # the line this phase is measured against
        origin, way = None, None
        sub_way = flat(f["subLook"][0], f["subLook"][2]) if f["hasSub"] else None
        if key == "Approach":
            origin, way = f["rider"], flat(f["face"][0], f["face"][2])
            go = travel(frames, i)
            if go and way:
                s["crab"].see(math.degrees(math.atan2(go[0] * -way[1] + go[1] * way[0], go[0] * way[0] + go[1] * way[1])), f["t"])
        elif key == "Pickup":
            origin, way = f["rider"], lane or sub_way
            if sub_way:
                side_n, _, bearing_n, _ = against(f["cam"], f["look"], f["rider"], sub_way)
                s["noseSide"].see(side_n, f["t"])
                s["noseBearing"].see(bearing_n, f["t"])
                k = 1 if calm else 2
                if abs(side_n) > k * LIMITS[key]["side"] or abs(bearing_n or 0) > k * LIMITS[key]["bearing"]:
                    s["noseOver"] += 1
                if lane:
                    s["noseOff"].see(math.degrees(math.atan2(sub_way[0] * -lane[1] + sub_way[1] * lane[0], sub_way[0] * lane[0] + sub_way[1] * lane[1])), f["t"])
        elif key in ("Ride", "Arrive", "Drop"):
            origin, way = f["sub"], sub_way
        else:
            origin, way = f["rider"], travel(frames, i)
        if key == "After" and drop_way:
            _, _, bearing_d, yaw_d = against(f["cam"], f["look"], f["rider"], drop_way)
            s["bearingD"].see(bearing_d, f["t"])
            s["yawD"].see(yaw_d, f["t"])
            if yaw_d is not None:
                if s["yawFirst"] is None:
                    s["yawFirst"] = yaw_d
                s["yawTurn"].see((yaw_d - s["yawFirst"] + 180) % 360 - 180, f["t"])
        if origin and way:
            side, back, bearing, yaw = against(f["cam"], f["look"], origin, way)
            if key == "After":
                s["nT"] += 1
                if carried:
                    s["carriedT"] = s.get("carriedT", 0) + 1
                s["bearingT"].see(bearing, f["t"])
                s["yawT"].see(yaw, f["t"])
            else:
                which = ("side", "bearing", "yaw") if calm else ("sideS", "bearingS", "yawS")
                s["calm"] += 1 if calm else 0
                s[which[0]].see(side, f["t"])
                s[which[1]].see(bearing, f["t"])
                s[which[2]].see(yaw, f["t"])
                s["backMin"], s["backMax"] = min(s["backMin"], back), max(s["backMax"], back)
                if bearing is None:
                    s["onTop"] += 1
                elif back <= 0:
                    s["ahead"] += 1
            if key in ("Arrive", "Drop") and sub_way:
                # (and against the rider: on the kick they leave the sub's line for the fish, by design)
                side2, _, bearing2, _ = against(f["cam"], f["look"], f["rider"], sub_way)
                s["riderSide"].see(side2, f["t"])
                s["riderBearing"].see(bearing2, f["t"])
        if f["gap"] <= 2.5 and f["hit"] > 0:
            n = names[f["hit"] - 1]
            s["pulled"][n] = s["pulled"].get(n, 0) + 1
        for field in ("near", "inside"):
            if f[field] != "-":
                for ix in f[field].split(","):
                    n = names[int(ix) - 1]
                    s[field][n] = s[field].get(n, 0) + 1
        if prev and prev["phase"] != "Pre" and i > 1:
            s["rot"].see(angle_between(f["look"], prev["look"]), f["t"])
            rel = [f["cam"][k] - f["rider"][k] for k in range(3)]
            rel0 = [prev["cam"][k] - prev["rider"][k] for k in range(3)]
            s["jump"].see(math.dist(rel, rel0), f["t"])
        s["rOn"] += 1 if f["rOn"] else 0
        if f["hasSub"]:
            s["sOn"] += 1 if f["sOn"] else 0
            if f["sOn"] and s["sFirst"] is None:
                s["sFirst"] = f["t"]
        if f["fOn"] >= 0:
            s["fN"] += 1
            s["fOn"] += 1 if f["fOn"] > 0 else 0
            s["fOff"].see(f["fX"] - 0.5, f["t"])
        prev = f

    def short(table, most=4):
        items = sorted(table.items(), key=lambda kv: -kv[1])[:most]
        return ", ".join(f"{k.split('.')[-1]} x{v} ({'.'.join(k.split('.')[1:-1])[-40:]})" for k, v in items) or "nothing"

    for key in PHASES:
        s = stats.get(key)
        if not s:
            lines.append(f"  {key}: no frames" + (" (the fling: the hop's own camera from the drop on)" if key == "Drop" and not tr["fish"] else ""))
            if key != "Drop" or tr["fish"]:
                fails.append(f"{key}: no frames")
            continue
        lim = LIMITS[key]
        lines.append(
            f"  {key}: {s['n']} frames ({s['calm']} calm), camera {','.join(sorted(s['types']))}, modes {','.join(sorted(s['modes']))}; "
            f"sideways {s['side']} studs, bearing off behind {s['bearing']} deg, view off the line {s['yaw']} deg; "
            f"behind {s['backMin']:.1f} to {s['backMax']:.1f} studs; view tipped {s['pitch'][0]:.0f} to {s['pitch'][1]:.0f} deg, fov {s['fov'][0]:.0f} to {s['fov'][1]:.0f}")
        if s["n"] - s["calm"] > 0:
            lines.append(f"      shaken frames ({s['n'] - s['calm']}): sideways {s['sideS']}, bearing {s['bearingS']}, view {s['yawS']}")
        lines.append(
            f"      rider in view {100 * s['rOn'] / s['n']:.0f}% of frames, sub in view {100 * s['sOn'] / s['n']:.0f}%"
            + (f" (first at t={s['sFirst']:.2f})" if s["sFirst"] is not None else "")
            + (f", fish in view {100 * s['fOn'] / s['fN']:.0f}% of {s['fN']} frames, furthest off the middle {s['fOff']} of the width" if s["fN"] else "")
            + f"; biggest turn in one frame {s['rot']} deg, biggest move against the rider in one frame {s['jump']} studs")
        if key == "Approach":
            lines.append(f"      the rider's travel against the way they face: {s['crab']} deg")
        if key == "Pickup":
            lines.append(f"      against the sub's own nose (not the line the camera follows): sideways {s['noseSide']}, bearing {s['noseBearing']} deg, "
                         f"over the limit on {s['noseOver']} of {s['n']} frames; the nose itself was up to {s['noseOff']} deg off the lane")
        if key in ("Arrive", "Drop") and tr["fish"]:
            lines.append(f"      against the rider (who leaves the sub's line for the fish on the kick): sideways {s['riderSide']}, bearing {s['riderBearing']} deg")
        if s["kelpIn"]:
            lines.append(f"      the gate's kelp between the camera and the rider on {s['kelpIn']} frames; SOLID (in the picture) on {s['kelpSolid']} of them"
                         + (f", t={s['kelpT'][0]:.2f} to {s['kelpT'][1]:.2f}" if s["kelpSolid"] else " (see-through for us on the rest)"))
        if s["kelpSolid"]:
            fails.append(f"{key}: the gate's kelp in front of the camera, solid, on {s['kelpSolid']} frames")
        if s["pulled"]:
            lines.append(f"      pull-in ray on: {short(s['pulled'])}")
        if s["near"]:
            lines.append(f"      within 4 studs of the camera: {short(s['near'])}")
        if s["inside"]:
            lines.append(f"      camera within 0.3 studs of: {short(s['inside'])}")
        if s["onTop"]:
            lines.append(f"      pulled right onto the rider on {s['onTop']} frames")
        for name, got, shaken in (("side", s["side"], s["sideS"]), ("bearing", s["bearing"], s["bearingS"]), ("yaw", s["yaw"], s["yawS"])):
            if abs(got.v) > lim[name]:
                fails.append(f"{key}: {name} {got} over {lim[name]}")
            if abs(shaken.v) > 2 * lim[name]:
                fails.append(f"{key}: {name} {shaken} on a shaken frame over {2 * lim[name]}")
        if s["ahead"]:
            fails.append(f"{key}: the camera level with or ahead of what it follows on {s['ahead']} frames")
        if "S" not in s["types"] or len(s["types"]) > 1:
            fails.append(f"{key}: the camera was not the sub's own on every frame ({s['types']})")
    if lead:
        lines.append(f"  before the sub's camera has the view (the player's own camera, still on the dock): {len(lead)} frames, to t={max(lead):.2f}")
        if len(lead) > 4:
            fails.append(f"the sub's camera took the view late: {len(lead)} frames")
    s = stats.get("After")
    if s:
        lines.append(
            f"  After the sub lets go ({s['n']} frames, modes {','.join(sorted(s['modes']))}): against the way the sub was going as it let go, "
            f"bearing off behind the rider {s['bearingD']} deg, view off it {s['yawD']} deg, the view turned at most {s['yawTurn']} deg from the hand-over; "
            f"biggest turn in one frame {s['rot']} deg, biggest move against the rider {s['jump']} studs; rider in view {100 * s['rOn'] / s['n']:.0f}%; "
            f"still carried (the sub's camera) on {s.get('carriedT', 0)} of those frames")
        lines.append(f"      (against the way the rider travels, which the hook bends: bearing {s['bearingT']} deg, view {s['yawT']} deg)")
        if abs(s["bearingD"].v) > SIDE_AT:
            fails.append(f"After: bearing {s['bearingD']} past {SIDE_AT} (at the side)")
    if tr["fish"]:
        if meta.get("cue") != "Kick":
            fails.append(f"fish trip: the cue was {meta.get('cue')}, not Kick")
        if meta.get("modeEnd") != "Riding":
            fails.append(f"fish trip: ended in mode {meta.get('modeEnd')}, not Riding")
    elif meta.get("cue") != "Fling":
        fails.append(f"fling trip: the cue was {meta.get('cue')}")
    lines.append("  " + ("PASS" if not fails else "FAIL: " + "; ".join(fails)))
    return {"text": "\n".join(lines), "pass": not fails, "fails": fails, "stats": stats}


def report(folder=""):
    ok = True
    for path in sorted((OUT / folder).glob("*.txt")):
        if path.name == "token.txt":
            continue
        text = path.read_text().splitlines()
        result = analyse(json.loads(text[0]), text[1:])
        print(result["text"])
        ok = ok and result["pass"]
    print("ALL PASS" if ok else "SOME FAIL")
    return ok


if __name__ == "__main__":
    what = sys.argv[1]
    rest = sys.argv[2:]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "mine":
        ours, said = mine()
        print(("OURS: " if ours else "NOT OURS: ") + said)
        sys.exit(0 if ours else 1)
    elif what == "gate":
        gate()
    elif what == "trip":
        fish = rest[2] if len(rest) > 2 and rest[2] != "-" else ""
        label = rest[3] if len(rest) > 3 else f"trip-{rest[0]}-{rest[1]}-{'fish' if fish else 'nofish'}"
        r = trip(int(rest[0]), int(rest[1]), fish, label, float(rest[4]) if len(rest) > 4 else 0)
        sys.exit(0 if r and r["pass"] else 1)
    elif what == "stills":
        fish = rest[2] if len(rest) > 2 and rest[2] != "-" else ""
        stills(int(rest[0]), int(rest[1]), fish, int(rest[3]) if len(rest) > 3 else 8)
    elif what == "report":
        sys.exit(0 if report(rest[0] if rest else "") else 1)
    elif what == "do":
        print(do(rest[0], float(rest[1]) if len(rest) > 1 else 1.0))
    elif what == "cmd":
        print(cmd(rest[0], float(rest[1]) if len(rest) > 1 else 0.8))
