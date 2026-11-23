"""Being eaten and drowning (Config.Fail, Config.Death; FailController, DeathController, Lib/Underwater): checked in a
Studio playtest, frame by frame.
    python tools/studio/fail_eat_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript,
                                                             both named ZZFailEatCheck; remove leaves nothing)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/fail_eat_check.py status              (is the playtest there, the check installed, the fps)
    python tools/studio/fail_eat_check.py eat [FISH[@SIZE] ...]
                                                             (each eater (default: every Chomp and Gulp fish, as
                                                             Config.failOf picks it): twice with the dials on, once
                                                             with them at 0; @SIZE: spawned at that size, a name of
                                                             Config.SizeOrder (Tiny ... Colossal), through the
                                                             workspace's TestSize; with the dials on, a fish shorter
                                                             than its kind's Fail.EatMin row must be thrown off, not
                                                             eaten)
    python tools/studio/fail_eat_check.py drown CASE [KIND] [FISH]
                                                             (CASE: deep, surface, lip (a fail just off the strip's
                                                             lip, thrown back at it), miss (free in the water near the
                                                             surface, no fish: the drown that is not thrown), nofail
                                                             (the soft path: AdminNoFail, the meter run out: left
                                                             floating); KIND: the outcome forced (Throw by default;
                                                             Roll, Shell, Flip, Coil ...); dials on, then at 0)
    python tools/studio/fail_eat_check.py hold FISH T         (that fish's own fail held at T seconds in: FailClock and
                                                             DeathClock; prints the probe, a shot to work/fail_eat/)
    python tools/studio/fail_eat_check.py letgo               (lets a hold go, clears every switch, sends the player home)
    python tools/studio/fail_eat_check.py play | stop         (starts or stops the playtest; stop puts the Edit mouse and
                                                             camera back)
    ... --min-fps N                                          (any run: refused under N fps instead of MIN_FPS; under
                                                             MIN_FPS the run is functional only, its verdicts
                                                             labelled INDICATIVE: the timing numbers mean nothing there)
How: the server Script seats the player on a fish of that kind through the sandbox's reset (RideService.sandboxReset,
Studio only) at a place for the case, and forces the fail (RideService.forceFail; the fish's own outcome unless KIND).
The dials (Config.Fail.MouthFromModel, Arrive, Smooth; Config.Death.UnderWater) are switched on the client only, at
runtime (they are client visuals), and put back as the file has them afterwards. Config.Fail.EatSmall is the
server's (Config.failOf picks the outcome there): the server Script sets it, 1 with the dials on and as the file has it
with them off; what to expect comes from the file's Fail.EatMin rows. The LocalScript records every render
frame after the camera (its own dt, the root, the torso, the body's highest part, the camera, the fish, the probes of
FailController and DeathController, walls and floors) and the Python side works out the numbers below from the frames.
It refuses to run under MIN_FPS (a hidden or background Studio draws at 15 fps and the numbers mean nothing then).
Each run: work/fail_eat/<name>.json (the numbers and the verdict) and frames_<name>.txt (every frame), and one line.
Needs Studio open and Rojo serving this repo: through the studio-runner plugin where it is installed, else through the
direct client (RpgGame/tools/studio/studio_mcp.py, as b4_tank_ride_check.py). Nothing is committed or kept in the place.
"""
import json
import math
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/fail_eat"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
MCP = "C:/Users/blast/RpgGame/tools/studio/studio_mcp.py"  # (the direct client: when studio-runner is not on this PC)
STUDIO_ID = os.environ.get("STUDIO_ID", "3b999aa2-7b9c-4390-8231-1c7119b5cc57")
DIRECT = not Path(RUN).exists()
sys.path.insert(0, str(Path(__file__).resolve().parent))

# ---- the pass bars --------------------------------------------------------------------------------------------------
MIN_FPS = 40  # refused under this (frames per second, measured on the client for a second before each run)
TIMING_FPS = 40  # under this the timing numbers mean nothing: a run let through by --min-fps is INDICATIVE
INDICATIVE = False  # (set by fps_ok: this run's fps was under TIMING_FPS)
# eaten
BITE_NEAR = 1.5  # studs from the torso to the mouth's pull at the bite (Fail.ArriveNear)
HIDE_NEAR = 1.5  # and at the hide (swallowed out of sight)
FISH_JERK = 600  # the fish root's biggest change of velocity, studs a second each second (dt-normalised)
TORSO_JERK = 2500  # the torso's (it is grabbed and hits things: looser)
NOSE_SPEED = 250  # the fish's biggest turn rate times half its length: its nose's sweep, studs a second (Smooth
#   peaks near 6.7 rad/s for a fish up to Fail.TurnLength long, 4.5 for a longer one; it was ~13.5 rad/s before)
MOUTH_VS_RULE = 0.5  # studs (at Normal) between the probe's mouth and fail_mouth_table.py's rule (two implementations)
MOUTH_VS_PAINT = 0.08  # and to the painted mouth, as a share of the fish's length (the table's truth)
CAM_JUMP = 4.0  # the camera's biggest move in one frame, studs
WALL_FRAMES = 0  # frames with the fish root or the camera inside something solid or under the map
HIDDEN_OUTSIDE = 0  # frames the body was hidden while not in the mouth
# drowned
SURFACE_Y = 0.0  # Config.Depth.SurfaceY
OXYGEN_Y = -3.0  # Config.Oxygen.SurfaceY
LOOSE_TOP = SURFACE_Y + 2.5  # the body's highest part while loose (Death.Breach 2, and a little)
JOINTS_TOP = OXYGEN_Y  # the body's highest part as its joints come back
AFTER_TOP = OXYGEN_Y  # and from then (after Death.SinkIn) to the fade
SINK_IN = 0.6  # Config.Death.SinkIn
STRIP_FRAMES = 0  # frames with the body on ground that stands above the water
HANDOVER_JUMP = 1.0  # studs the root jumps (past its own speed) on the frame the drown takes it over
NOFAIL_TOP = SURFACE_Y  # the floating body's highest part (the soft path)
SURFACE_CASE = SURFACE_Y - 14  # the surface case counts only if the fail began above this (else "not tested")
LIP_CASE = 35  # and the lip case only within this many studs of the lip (flat)
ERRORS = 0

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RideService = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services"):WaitForChild("RideService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared:WaitForChild("Net"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZFailEatReport"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("FEClient", tostring(text))
end)
local keptMax = nil
local keptEat = Config.Fail.EatSmall

-- the fish model the player rides or is held by: the nearest with a "Rig" attribute
local function ridden(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, far = nil, math.huge
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Rig") and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < far then
				best, far = m, d
			end
		end
	end
	return best
end

-- the strip's lip: out from the dock spawn along its look until there is no ground over the water
local function lip()
	local dock = Net.Folder:GetAttribute("Dock")
	if typeof(dock) ~= "CFrame" then
		return nil, nil
	end
	local out = (dock.LookVector * Vector3.new(1, 0, 1)).Unit
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.RespectCanCollide = true
	p.IgnoreWater = true
	local skip = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	p.FilterDescendantsInstances = skip
	local surface = Config.Depth.SurfaceY
	local seen = false
	for step = 0, 1600 do
		local at = dock.Position + out * (step * 0.5)
		local hit = workspace:Raycast(Vector3.new(at.X, surface + 40, at.Z), Vector3.new(0, -40.05, 0), p)
		if hit then
			seen = true
		elseif seen then
			return Vector3.new(at.X, surface, at.Z), out
		end
	end
	return nil, nil
end

local function placeOf(case)
	local at, along = RideService.sandboxStart()
	local surface = Config.Depth.SurfaceY
	if case == "lip" then
		local edge, out = lip()
		if not edge then
			error("no lip found from the dock")
		end
		return Vector3.new(edge.X, surface - 7, edge.Z) + out * 2, out
	elseif case == "surface" or case == "free" then
		local p = at + along * 160
		return Vector3.new(p.X, surface - 7, p.Z), along
	end
	return at + along * (tonumber(RS:GetAttribute("FEAhead")) or 160), along
end

RS:SetAttribute("FEReady", true)
RS:GetAttributeChangedSignal("FECmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("FECmd") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	if not player then
		RS:SetAttribute("FESaid", "no player")
		return
	end
	local ok, said = pcall(function()
		if verb == "ride" then
			-- ride|Fish|case (Fish "": none, free in the water)
			local at, along = placeOf(if b ~= "" then b else "deep")
			RideService.sandboxReset(player, nil, if a ~= "" then a else nil, nil, { At = at, Along = along })
			return string.format("ride %s %s at %.0f %.0f %.0f", a, b, at.X, at.Y, at.Z)
		elseif verb == "lip" then
			local edge = lip()
			return if edge then string.format("%.2f %.2f %.2f", edge.X, edge.Y, edge.Z) else "none"
		elseif verb == "miss" then
			-- free in the water near the surface, no fish, and the fail at once (before the reset seats us on the
			-- nearest fish: its first try is 0.35 s on): the drown that is not thrown
			local at, along = placeOf("free")
			RideService.sandboxReset(player, nil, nil, nil, { At = at, Along = along })
			task.wait(0.15)
			return "miss " .. tostring(RideService.forceFail(player)) .. " " .. tostring(player:GetAttribute("State"))
		elseif verb == "fail" then
			-- (the outcome picked: FailKind, none for the plain throw, which is over at once)
			local forced = RideService.forceFail(player, if a ~= "" then a else nil)
			return "fail " .. tostring(forced) .. " " .. tostring(player:GetAttribute("FailKind") or "none")
		elseif verb == "eatsmall" then
			-- eatsmall|1 (Config.Fail.EatSmall, the server's own), eatsmall|kept: as the file has it
			Config.Fail.EatSmall = if a == "kept" then keptEat else (tonumber(a) or 0)
			return "eatsmall " .. tostring(Config.Fail.EatSmall)
		elseif verb == "tier" then
			-- the size of the fish the player is on (its SizeTier, and its scale)
			local m = ridden(player)
			return if m then tostring(m:GetAttribute("Rig")) .. " " .. tostring(m:GetAttribute("SizeTier")) .. " " .. tostring(m:GetAttribute("Size")) else "none"
		elseif verb == "home" then
			RideService.sendHome(player)
			return "home"
		elseif verb == "state" then
			return tostring(player:GetAttribute("State"))
		elseif verb == "nofail" then
			-- nofail|1|max: the soft path (no fail), the meter set to `max`; nofail|0: put back
			if a == "1" then
				keptMax = keptMax or player:GetAttribute("MaxOxygen")
				player:SetAttribute("AdminNoFail", true)
				RideService.setMax(player, tonumber(b) or 2)
				return "nofail on, max " .. tostring(b)
			end
			player:SetAttribute("AdminNoFail", nil)
			if type(keptMax) == "number" then
				RideService.setMax(player, keptMax)
			end
			keptMax = nil
			return "nofail off, max " .. tostring(player:GetAttribute("MaxOxygen"))
		end
		return "?"
	end)
	RS:SetAttribute("FESaid", tostring(said) .. (if ok then "" else " (error)"))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local FailController = require(Client:WaitForChild("Controllers"):WaitForChild("FailController"))
local DeathController = require(Client.Controllers:WaitForChild("DeathController"))
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local Underwater = require(Client.Lib:WaitForChild("Underwater"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = RS:WaitForChild("ZZFailEatReport", 60)
local camera = workspace.CurrentCamera
local DIALS = {
	{ Config.Fail, "MouthFromModel" },
	{ Config.Fail, "Arrive" },
	{ Config.Fail, "Smooth" },
	{ Config.Death, "UnderWater" },
}
local kept = {}
for i, d in DIALS do
	kept[i] = d[1][d[2]]
end

local errors = {}
LogService.MessageOut:Connect(function(text, kind)
	if kind == Enum.MessageType.MessageError and #errors < 20 then
		table.insert(errors, string.sub(text, 1, 200))
	end
end)

local function r1(x)
	return if type(x) == "number" then math.floor(x * 100 + 0.5) / 100 else x
end
local function v3(v)
	return if typeof(v) == "Vector3" then { r1(v.X), r1(v.Y), r1(v.Z) } else nil
end
local function clean(t)
	if typeof(t) == "Vector3" then
		return v3(t)
	elseif typeof(t) == "CFrame" then
		return v3(t.Position)
	elseif type(t) == "table" then
		local out = {}
		for k, v in t do
			out[k] = clean(v)
		end
		return out
	elseif type(t) == "number" then
		return r1(t)
	end
	return t
end

local function skipList()
	local list = { camera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	return list
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true

-- inside something solid (its name), or under the map (nothing under it), or ""
local function where(p)
	if not p then
		return ""
	end
	overlap.FilterDescendantsInstances = skipList()
	for _, part in workspace:GetPartBoundsInRadius(p, 0.3, overlap) do
		if part.CanCollide and part.Anchored then
			return "in " .. part:GetFullName()
		end
	end
	rayParams.FilterDescendantsInstances = skipList()
	if not workspace:Raycast(p, Vector3.new(0, -600, 0), rayParams) then
		return "under"
	end
	return ""
end

-- on ground that stands above the water (the strip)
local function onStrip(p)
	rayParams.FilterDescendantsInstances = skipList()
	local surface = Config.Depth.SurfaceY
	local hit = workspace:Raycast(Vector3.new(p.X, surface + 40, p.Z), Vector3.new(0, -40.05, 0), rayParams)
	return hit ~= nil and p.Y > hit.Position.Y - 3
end

-- (a frame is a list: a nil would leave a hole JSONEncode may cut it at; false stands for none)
local function nz(x)
	if x == nil then
		return false
	end
	return x
end

local frames = {}
local meta = {}
local snap = nil
local recording = false

local function stopRec()
	if recording then
		RunService:UnbindFromRenderStep("ZZFailEatRec")
		recording = false
	end
end

local function startRec(seconds)
	stopRec()
	frames = {}
	errors = {}
	meta = { Begun = os.clock() }
	recording = true
	local begun = os.clock()
	local dockSince = nil
	local seenFail = false
	RunService:BindToRenderStep("ZZFailEatRec", Enum.RenderPriority.Last.Value + 1, function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
		local top = -math.huge
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") == nil and d.Transparency < 1 then
					top = math.max(top, d.Position.Y)
				end
			end
		end
		local fp = FailController.probe(player)
		local dp = DeathController.probe(player)
		local state = tostring(player:GetAttribute("State"))
		if state == "Failing" or state == "Drowning" then
			seenFail = true
		end
		if fp then
			meta.Fail = clean(fp)
		end
		if dp then
			meta.Death = clean(dp)
		end
		local fish = fp and fp.FishRoot
		local look = fp and fp.FishLook
		local t = os.clock() - begun
		local strip = 0
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") == nil and onStrip(d.Position) then
					strip = 1
					break
				end
			end
		end
		table.insert(frames, {
			r1(t), math.floor(dt * 10000 + 0.5) / 10000,
			nz(v3(root and root.Position)), nz(v3(torso and torso.Position)), nz(r1(if top > -math.huge then top else nil)),
			v3(camera.CFrame.Position), nz(v3(fish)), nz(v3(look)),
			state, tostring(State.Mode),
			if character and character:GetAttribute("Ragdoll") then 1 else 0,
			if fp and fp.Hidden then 1 else 0,
			nz(r1(fp and fp.Far)), if fp and fp.InMouth ~= nil then (if fp.InMouth then 1 else 0) else false,
			nz(r1(fp and fp.U)), nz(r1(fp and fp.Wait)),
			where(fish), where(camera.CFrame.Position),
			strip,
			if State.DeathCam then 1 else 0, nz(r1(State.Fade)),
			if dp and dp.Settled then 1 else 0,
		})
		if seenFail and state == "Dock" then
			dockSince = dockSince or os.clock()
		end
		if os.clock() - begun > seconds or (dockSince and os.clock() - dockSince > 1.5) then
			stopRec()
			meta.Ended = os.clock() - begun
		end
	end)
end

-- what is left once it is over, against the snapshot taken at the dock before the run (`snap`)
local function sockets(character)
	local n = 0
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") then
				n += 1
			end
		end
	end
	return n
end
local function endState()
	local character = player.Character
	local left = {}
	if character then
		for _, d in character:GetDescendants() do
			if string.find(d.Name, "^FailHold_") then
				table.insert(left, d:GetFullName())
			end
		end
	end
	if snap and sockets(character) ~= snap.Sockets then
		table.insert(left, string.format("constraints %d (were %d)", sockets(character), snap.Sockets))
	end
	for _, d in camera:GetDescendants() do
		if d.Name == "FailSolid" then
			table.insert(left, d:GetFullName())
		end
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return {
		State = player:GetAttribute("State"),
		Mode = State.Mode,
		DeathCam = State.DeathCam ~= nil,
		CameraType = camera.CameraType.Name,
		CameraTypeBefore = snap and snap.CameraType,
		CameraSubject = if camera.CameraSubject then camera.CameraSubject.Name else nil,
		Humanoid = if humanoid then humanoid:GetState().Name else nil,
		Ragdoll = character ~= nil and character:GetAttribute("Ragdoll") ~= nil,
		Left = left,
		Fade = State.Fade,
	}
end

workspace:GetAttributeChangedSignal("FEDo"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("FEDo") or "")
	local verb, a, b = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)")
	local ok, said = pcall(function()
		if verb == "dials" then
			-- dials|1 or dials|0 (the client's own Config), dials|kept: as the file has them
			for i, d in DIALS do
				d[1][d[2]] = if a == "kept" then kept[i] else (tonumber(a) or 0)
			end
			local now = {}
			for _, d in DIALS do
				table.insert(now, d[2] .. "=" .. tostring(d[1][d[2]]))
			end
			return table.concat(now, " ")
		elseif verb == "snap" then
			snap = { Sockets = sockets(player.Character), CameraType = camera.CameraType.Name }
			return Http:JSONEncode(snap)
		elseif verb == "fps" then
			local n, total = 0, 0
			local c = RunService.RenderStepped:Connect(function(dt)
				n += 1
				total += dt
			end)
			task.wait(1)
			c:Disconnect()
			return tostring(if total > 0 then math.floor(n / total + 0.5) else 0)
		elseif verb == "rec" then
			startRec(tonumber(a) or 9)
			return "rec"
		elseif verb == "recording" then
			return if recording then "yes" else "no"
		elseif verb == "count" then
			return tostring(#frames)
		elseif verb == "frames" then
			local from, n = tonumber(a) or 1, tonumber(b) or 40
			local out = {}
			for i = from, math.min(#frames, from + n - 1) do
				table.insert(out, frames[i])
			end
			return Http:JSONEncode(out)
		elseif verb == "meta" then
			meta.Errors = errors
			meta.End = endState()
			return Http:JSONEncode(clean(meta))
		elseif verb == "probe" then
			return Http:JSONEncode(clean({
				Fail = FailController.probe(player),
				Death = DeathController.probe(player),
				State = player:GetAttribute("State"),
			}))
		elseif verb == "ground" then
			-- ground|on: keep count of what Underwater.groundAbove takes for ground above the water; ground: the count
			-- so far (by part), and stop counting
			if a == "on" then
				Underwater.Seen = {}
				return "counting"
			end
			local seen = Underwater.Seen or {}
			Underwater.Seen = nil
			return Http:JSONEncode(seen)
		elseif verb == "stop" then
			stopRec()
			Underwater.Seen = nil
			return "stopped"
		end
		return "?"
	end)
	report:FireServer(if ok then said else "error: " .. tostring(said))
end)
'''

# the fields of a frame, in order (the LocalScript's table)
FIELDS = ("t", "dt", "root", "torso", "top", "cam", "fish", "look", "state", "mode", "rag", "hidden", "far", "inMouth",
          "u", "wait", "fishIn", "camIn", "strip", "deathCam", "fade", "settled")
# what a check holds on the playtest's workspace (cleared in a `finally` and on a kill)
HELD = ("TestMaxOxygen", "FailSlow", "FailClock", "DeathClock", "CatchLook", "TestSize")


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def call(tool, args, timeout=120, image=None):
    """One tool of the direct client (as b4_tank_ride_check.py); `image`: where a returned picture is saved (the
    client writes it with the picture's own extension, .jpeg for a capture)"""
    path = OUT / "_args.json"
    path.write_text(json.dumps({"studio_id": STUDIO_ID, **args}), encoding="utf-8")
    env = dict(os.environ, MCP_IMG=str(image)) if image else None
    r = subprocess.run([sys.executable, MCP, "call", tool, "@" + str(path), str(timeout)],
                       capture_output=True, text=True, encoding="utf-8", env=env)
    for line in r.stdout.splitlines():
        if line.startswith('{"content"'):
            return "\n".join(c.get("text", "") for c in json.loads(line)["content"])
    return "ERR " + r.stdout[-800:] + r.stderr[-400:]


def capture(path):
    """One picture of the game view to `path` (or the same name as .jpeg from the direct client); the file, or None.
    One at a time: two captures in flight cost minutes (the first times out)."""
    path = Path(path)
    for old in (path, path.with_suffix(".jpeg")):
        old.unlink(missing_ok=True)
    if DIRECT:
        said = call("screen_capture", {"capture_id": path.stem}, 60, image=path)
    else:
        said = run(["shot", str(path)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        got = next((q for q in (path, path.with_suffix(".jpeg")) if q.exists()), None)
        now = got.stat().st_size if got else -1
        if now > 0 and now == size:
            return got
        size = now
        time.sleep(0.15)
    print("no capture:", said[-300:])
    return None


def edit(code):
    """Luau run in Studio's Edit place"""
    if DIRECT:
        return call("execute_luau", {"datamodel_type": "Edit", "code": code})
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    return run([f.name])


def play(on):
    """Starts or stops the playtest; after a stop the Edit mouse and camera are put back (a scripted stop leaves the
    mouse locked and the camera Scriptable)"""
    said = call("start_stop_play", {"is_start": bool(on)}) if DIRECT else run(["play" if on else "stop"])
    if not on:
        time.sleep(2)
        reset = (
            "task.delay(0.5, function() game:GetService('UserInputService').MouseBehavior = Enum.MouseBehavior.Default "
            "workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end) return 'ok'"
        )
        said += " | reset " + edit(reset)
    return said


def lua(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return "[==[" + str(v) + "]==]"


def server(code):
    if DIRECT:
        return call("execute_luau", {"datamodel_type": "Server", "code": code})
    return run(["--ctx", "server", "--code", code])


def last_line(text):
    lines = [x for x in text.strip().splitlines() if x.strip()]
    return lines[-1] if lines else ""


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZFailEatCheck")
	if old then old:Destroy() end
end
workspace:SetAttribute("FEDo", nil)
local RS = game:GetService("ReplicatedStorage")
for _, name in {{ "FECmd", "FESaid", "FEClient", "FEReady", "FEAhead" }} do
	RS:SetAttribute(name, nil)
end
local old = RS:FindFirstChild("ZZFailEatReport")
if old then old:Destroy() end
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZFailEatCheck"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZFailEatCheck"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    if DIRECT:
        return call("execute_luau", {"datamodel_type": "Edit", "code": job})
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.5):
    """A verb for the server Script"""
    return last_line(server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('FECmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('FESaid')"
    ))


def do(c, wait=0.6):
    """A verb for the LocalScript; its answer comes back through the server"""
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('FEClient', '') "
        f"workspace:SetAttribute('FEDo', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('FEClient')"
    )


def js(text):
    start = min([i for i in (text.find("{"), text.find("[")) if i >= 0], default=-1)
    end = max(text.rfind("}"), text.rfind("]"))
    return json.loads(text[start : end + 1]) if start >= 0 and end > start else None


def setw(**kw):
    code = "".join(f"workspace:SetAttribute({lua(k)}, {lua(v)}) " for k, v in kw.items())
    return server(code + "return 'ok'")


def playing():
    """Whether a playtest's server is there. None: could not tell."""
    if DIRECT:
        said = call("execute_luau", {"datamodel_type": "Server", "code": "return 'FE' .. 'PLAYING'"}, 30)
        return True if "FEPLAYING" in said else (None if said.startswith("ERR") else False)
    try:
        return json.loads(run(["status"], timeout=20)).get("connected", {}).get("server", 0) > 0
    except Exception:
        return None


def editing():
    """Whether Studio's Edit place answers (Studio open, the place loaded). None: could not tell."""
    if DIRECT:
        said = call("execute_luau", {"datamodel_type": "Edit", "code": "return 'FE' .. 'EDITING'"}, 30)
        return True if "FEEDITING" in said else (None if said.startswith("ERR") else False)
    return "FEEDITING" in edit("return 'FE' .. 'EDITING'")


def restore():
    """Every switch off: the dials as the file has them, the clocks free, no-fail off"""
    if playing() is False:
        return "no playtest"
    out = [setw(**{k: None for k in HELD}), cmd("nofail|0"), cmd("eatsmall|kept"), last_line(do("dials|kept")),
           last_line(do("stop"))]
    return " / ".join(out)


def _killed(sig, _frame):
    raise SystemExit(128 + sig)


for _sig in (signal.SIGTERM, getattr(signal, "SIGHUP", signal.SIGTERM)):
    signal.signal(_sig, _killed)


def wait_state(want, timeout=30):
    end = time.time() + timeout
    s = ""
    while time.time() < end:
        s = cmd("state", 0.2)
        if s in want:
            return s
        time.sleep(0.4)
    raise SystemExit(f"state stayed {s}, wanted {want}")


def home():
    cmd("home", 1.5)
    try:
        return wait_state({"Dock"}, 20)
    except SystemExit as e:
        return str(e)


def fps_ok():
    global INDICATIVE
    try:
        fps = int(last_line(do("fps", 1.6)) or 0)
    except ValueError:
        fps = 0
    if fps < MIN_FPS:
        print(f"refused: the client draws {fps} fps (< {MIN_FPS}). Bring Studio to the front, not minimised, and run again.")
        return False, fps
    INDICATIVE = fps < TIMING_FPS
    if INDICATIVE:
        print(f"INDICATIVE: {fps} fps (< {TIMING_FPS}, let through by --min-fps): functional only, timing not judged")
    return True, fps


def pull():
    """The last recording: (frames as dicts, meta)"""
    for _ in range(40):
        if "no" in last_line(do("recording", 0.3)):
            break
        time.sleep(0.5)
    n = int(last_line(do("count", 0.3)) or 0)
    frames = []
    i = 1
    while i <= n:
        part = js(do(f"frames|{i}|40", 0.6)) or []
        if not part:
            break
        frames += [dict(zip(FIELDS, [None if v is False else v for v in f])) for f in part]
        i += len(part)
    meta = js(do("meta", 0.6)) or {}
    return frames, meta


def dist(a, b):
    return math.dist(a, b) if a and b else None


def jerk(frames, key):
    """The biggest change of velocity between frames, each by its own dt (studs/s each second), and when"""
    best, at = 0.0, None
    prev_v = None
    for p, q in zip(frames, frames[1:]):
        if not p.get(key) or not q.get(key) or not q["dt"]:
            prev_v = None
            continue
        v = [(b - a) / q["dt"] for a, b in zip(p[key], q[key])]
        if prev_v is not None:
            j = math.dist(v, prev_v) / q["dt"]
            if j > best:
                best, at = j, q["t"]
        prev_v = v
    return round(best), at


def turn_rate(frames):
    best, at = 0.0, None
    for p, q in zip(frames, frames[1:]):
        if p.get("look") and q.get("look") and q["dt"]:
            dot = max(-1.0, min(1.0, sum(a * b for a, b in zip(p["look"], q["look"]))))
            w = math.acos(dot) / q["dt"]
            if w > best:
                best, at = w, q["t"]
    return round(best, 2), at


def cam_jump(frames):
    best, at = 0.0, None
    for p, q in zip(frames, frames[1:]):
        d = dist(p["cam"], q["cam"])
        if d and d > best:
            best, at = d, q["t"]
    return round(best, 2), at


def verdict(checks):
    bad = [k for k, ok in checks.items() if ok is False]
    line = "PASS" if not bad else "FAIL " + ",".join(bad)
    if INDICATIVE:
        line = f"INDICATIVE (under {TIMING_FPS} fps: timing not judged) " + line
    return line, bad


def save(name, frames, result):
    (OUT / f"{name}.json").write_text(json.dumps(result, indent=1))
    with open(OUT / f"frames_{name}.txt", "w") as f:
        f.write("\t".join(FIELDS) + "\n")
        for fr in frames:
            f.write("\t".join(json.dumps(fr.get(k)) for k in FIELDS) + "\n")


def truth(fid):
    """fail_mouth_table.py's mouths for `fid` at Normal: (rule, painted, length), studs in the root's space"""
    try:
        import fail_mouth_table as T

        _, _, _, _, scales = T.read_config()
        rig = json.loads((Path(T.CREATURES) / f"{fid}.json").read_text(encoding="utf-8"))
        k = scales.get(fid, 1.0)
        _, boxes, paints = T.load_model(fid)
        rule = T.rule_mouth(rig, boxes, T.read_sizes()["mouth_at"].get(fid))[0]
        paint = T.paint_mouth(boxes, paints)[0]
        return ([x * k for x in rule] if rule else None, [x * k for x in paint] if paint else None, rig["Size"][2] * k)
    except Exception:  # (a fish with no exported model: nothing to hold it to)
        return None, None, None


def eat_metrics(frames, meta, fish):
    fail = meta.get("Fail") or {}
    failing = [f for f in frames if f["state"] == "Failing"]
    hidden = [f for f in failing if f["hidden"]]
    first_hidden = hidden[0] if hidden else None
    walls = [f for f in failing if f["fishIn"] or f["camIn"]]
    turn = turn_rate(failing)
    length = fail.get("Length") or 0
    out = {
        "kind": fail.get("Kind"),
        "dials": fail.get("Dials"),
        "mouthFromModel": fail.get("Mouthed"),
        "length": length,
        "grabAt": fail.get("GrabAt"),
        "biteAt": fail.get("BiteAt"),
        "biteFar": fail.get("BiteFar"),
        "hideAt": fail.get("HideAt"),
        "hideFar": fail.get("HideFar"),
        "wait": fail.get("Wait"),
        "inMouthAtBite": None,
        "inMouthAtHide": first_hidden["inMouth"] if first_hidden else None,
        "fishJerk": jerk(failing, "fish"),
        "torsoJerk": jerk(failing, "torso"),
        "fishTurn": turn,
        "noseSpeed": round(turn[0] * length / 2),
        "camJump": cam_jump(failing),
        "wallFrames": len(walls),
        "wallFirst": (walls[0]["t"], walls[0]["fishIn"] or walls[0]["camIn"]) if walls else None,
        # (every hidden frame not in the mouth's room or the way down the throat, not only the hide's moment)
        "hiddenOutside": sum(1 for f in hidden if f["inMouth"] == 0),
        "frames": len(frames),
        "meanFps": round(len(frames) / max(sum(f["dt"] or 0 for f in frames), 1e-3)),
        "errors": meta.get("Errors") or [],
        "end": meta.get("End"),
    }
    # in the mouth at the bite: the first frame whose outcome clock u passes the bite beat (FailController's BEATS)
    beat = 1.27 if fail.get("Kind") == "Chomp" else 1.6
    hit = next((f for f in failing if f["u"] is not None and f["u"] >= beat), None)
    out["inMouthAtBite"] = hit["inMouth"] if hit else None
    # the mouth against the offline table (an independent truth: the painted mouth on the exported model)
    rule, paint, normal = truth(fish)
    mouth = fail.get("MouthLocal")
    if mouth and length and normal and fail.get("Mouthed"):
        scaled = [x * normal / length for x in mouth]
        out["mouthVsRule"] = round(math.dist(scaled, rule), 2) if rule else None
        out["mouthVsPaint"] = round(math.dist(scaled, paint) / normal, 3) if paint else None
    checks = {
        "bite": out["biteFar"] is not None and out["biteFar"] <= BITE_NEAR,
        "hide": out["hideFar"] is not None and out["hideFar"] <= HIDE_NEAR,
        "inMouthBite": out["inMouthAtBite"] != 0,
        "inMouthHide": out["inMouthAtHide"] != 0,
        "fishJerk": out["fishJerk"][0] <= FISH_JERK,
        "torsoJerk": out["torsoJerk"][0] <= TORSO_JERK,
        "noseSpeed": out["noseSpeed"] <= NOSE_SPEED,
        "camJump": out["camJump"][0] <= CAM_JUMP,
        "walls": out["wallFrames"] <= WALL_FRAMES,
        "hiddenOutside": out["hiddenOutside"] <= HIDDEN_OUTSIDE,
        "errors": len(out["errors"]) <= ERRORS,
    }
    if out.get("mouthVsRule") is not None:
        checks["mouthVsRule"] = out["mouthVsRule"] <= MOUTH_VS_RULE
    if out.get("mouthVsPaint") is not None:
        checks["mouthVsPaint"] = out["mouthVsPaint"] <= MOUTH_VS_PAINT
    return out, checks


def end_checks(end):
    return {
        "dock": end.get("State") == "Dock",
        "camera": not end.get("DeathCam") and end.get("CameraType") == end.get("CameraTypeBefore"),
        "leftovers": not end.get("Left"),
    }


def drown_metrics(frames, meta, case, lip_at=None):
    loose = [f for f in frames if f["rag"] and f["top"] is not None]
    hi_loose = max(loose, key=lambda f: f["top"]) if loose else None
    back = next((i for i, f in enumerate(frames) if f["state"] == "Drowning" and f["settled"]), None)
    after = []
    joints = None
    jump = None
    if back is not None:
        joints = frames[back]
        settle_t = joints["t"]
        after = [
            f
            for f in frames[back:]
            if f["state"] == "Drowning" and f["t"] >= settle_t + SINK_IN and (f["fade"] or 0) < 1 and f["top"] is not None
        ]
        if back >= 2:
            a, b, c = frames[back - 2], frames[back - 1], frames[back]
            if a["root"] and b["root"] and c["root"] and b["dt"] and c["dt"]:
                v = [(y - x) / b["dt"] for x, y in zip(a["root"], b["root"])]
                guess = [y + w * c["dt"] for y, w in zip(b["root"], v)]
                jump = round(math.dist(guess, c["root"]), 2)
    else:
        # (a drown with no loose body before it, the miss: from its start, after Death.SinkIn)
        begin = next((f["t"] for f in frames if f["state"] == "Drowning"), None)
        if begin is not None:
            after = [
                f
                for f in frames
                if f["state"] == "Drowning" and f["t"] >= begin + SINK_IN and (f["fade"] or 0) < 1 and f["top"] is not None
            ]
    hi_after = max(after, key=lambda f: f["top"]) if after else None
    strip = [f for f in frames if f["strip"] and f["state"] in ("Failing", "Drowning")]
    end = meta.get("End") or {}
    first = next((f for f in frames if f["state"] in ("Failing", "Drowning") and f["root"]), None)
    out = {
        "case": case,
        "firstState": first["state"] if first else None,
        "rootAtFail": first["root"] if first else None,
        "highestLoose": (hi_loose["top"], hi_loose["t"]) if hi_loose else None,
        "topAtJointsBack": joints["top"] if joints else None,
        "rootAtJointsBack": joints["root"][1] if joints and joints["root"] else None,
        "highestAfter": (hi_after["top"], hi_after["t"]) if hi_after else None,
        "stripFrames": len(strip),
        "handoverJump": jump,
        "end": end,
        "errors": meta.get("Errors") or [],
        "frames": len(frames),
        "meanFps": round(len(frames) / max(sum(f["dt"] or 0 for f in frames), 1e-3)),
        "death": meta.get("Death"),
    }
    # the case's own premise: was it where the case says when it failed?
    tested = first is not None
    if first and case == "surface":
        tested = first["root"][1] >= SURFACE_CASE
    elif first and case == "lip":
        here = (first["root"][0], first["root"][2])
        out["lipDistance"] = round(math.dist(here, (lip_at[0], lip_at[2])), 1) if lip_at else None
        tested = out["lipDistance"] is not None and out["lipDistance"] <= LIP_CASE
    elif case == "miss":
        tested = first is not None and first["state"] == "Drowning" and not meta.get("Fail")
    out["tested"] = tested
    checks = {
        "loose": hi_loose is None or hi_loose["top"] <= LOOSE_TOP,
        "jointsBack": joints is None or joints["top"] is None or joints["top"] <= JOINTS_TOP,
        "after": hi_after is None or hi_after["top"] <= AFTER_TOP,
        "strip": len(strip) <= STRIP_FRAMES,
        "handover": jump is None or jump <= HANDOVER_JUMP,
        "errors": len(out["errors"]) <= ERRORS,
        **end_checks(end),
    }
    return out, checks


def nofail_metrics(frames, meta):
    free = [f for f in frames if f["state"] == "Free" and f["top"] is not None]
    hi = max(free, key=lambda f: f["top"]) if free else None
    out = {
        "case": "nofail",
        "tested": bool(free),
        "highestFloating": (hi["top"], hi["t"]) if hi else None,
        "rootFloating": hi["root"][1] if hi and hi["root"] else None,
        "errors": meta.get("Errors") or [],
        "end": meta.get("End"),
    }
    checks = {
        "floating": hi is None or hi["top"] <= NOFAIL_TOP,
        "errors": len(out["errors"]) <= ERRORS,
    }
    return out, checks


def dials(on):
    return last_line(do(f"dials|{1 if on else 0}"))


def ready(on, name):
    """At the dock, the dials set, the fps measured (refused under MIN_FPS), the dock's state kept to diff against"""
    print(f"{name}: dials", dials(on), "| home:", home())
    ok, fps = fps_ok()
    if ok:
        do("snap", 0.4)
    return ok, fps


def proposal():
    """The file's Fail.EatMin rows, and each eater's Normal length and size scales (fail_mouth_table.py)"""
    import fail_mouth_table as T

    rows, sizes = T.table_rows()
    return sizes["eat_min"], {r["id"]: r for r in rows if not r.get("missing")}


def thrown_metrics(frames, said):
    """A fish too small to take the rider (Fail.EatMin): thrown off into the drown, never eaten"""
    hidden = [f for f in frames if f["hidden"]]
    states = {f["state"] for f in frames}
    out = {"said": said, "hiddenFrames": len(hidden), "states": sorted(s for s in states if s)}
    checks = {
        "noFailKind": said.endswith(" none"),
        "neverHidden": not hidden,
        "drowned": "Drowning" in states or "Dead" in states,
    }
    return out, checks


def eat_one(fish, on, name, size=None, mins=None, rows=None):
    ok, fps = ready(on, name)
    if not ok:
        return None
    print(" ", cmd(f"eatsmall|{1 if on else 'kept'}"))
    setw(TestSize=size)
    print(" ", cmd(f"ride|{fish}|deep", 1.0))
    # (one call each for "riding yet?" and "record, fail": through the direct client a call is 2-5 s and the ride on a
    # fish lasts about 9 s whatever TestMaxOxygen is, so the separate calls lost the race and the fail found State Dock)
    tier = last_line(server(
        "local RS = game:GetService('ReplicatedStorage') local p = game:GetService('Players'):GetPlayers()[1] "
        "local t = os.clock() while p:GetAttribute('State') ~= 'Riding' and os.clock() - t < 30 do task.wait(0.05) end "
        "workspace:SetAttribute('TestSize', nil) "
        f"RS:SetAttribute('FECmd', 'tier|{time.time()}') task.wait(0.3) "
        "return (if p:GetAttribute('State') == 'Riding' then '' else 'NOTRIDING ') .. tostring(RS:GetAttribute('FESaid'))"
    ))
    if tier.startswith("NOTRIDING"):
        raise SystemExit(f"state never Riding: {tier}")
    print("  on:", tier)
    if size and tier.split(" ")[1:2] != [size]:
        print(f"{name}: NOT TESTED (asked for {size}, the fish is {tier})")
        return {"name": name, "fish": fish, "verdict": f"NOT TESTED (size {tier})"}
    # the outcome the server should pick: thrown off a fish shorter than its kind's EatMin row (with the dials on)
    row = (rows or {}).get(fish)
    length = row["L"] * row["scales"][size or "Normal"] if row else None
    least = (mins or {}).get(fish)
    expect_throw = bool(on and least and length is not None and length < least)
    said = last_line(server(
        "local RS = game:GetService('ReplicatedStorage') task.wait(0.5) "
        f"workspace:SetAttribute('FEDo', 'rec|10|{time.time()}') task.wait(0.25) "
        f"RS:SetAttribute('FECmd', 'fail||{time.time()}') task.wait(0.3) return RS:GetAttribute('FESaid')"
    ))
    print(" ", said)
    time.sleep(6)
    frames, meta = pull()
    if expect_throw:
        out, checks = thrown_metrics(frames, said)
        out["expect"] = f"thrown (length {length:.1f} < EatMin {least})"
    else:
        out, checks = eat_metrics(frames, meta, fish)
        checks["eaten"] = not said.endswith(" none")
    out["fish"], out["size"], out["fps"], out["name"] = fish, size or "Normal", fps, name
    line, _ = verdict(checks)
    out["verdict"], out["checks"] = line, checks
    save(name, frames, out)
    if expect_throw:
        print(f"{name}: {line} | {out['expect']} | {said} hidden {out['hiddenFrames']} states {out['states']}")
        return out
    print(
        f"{name}: {line} | {out['kind']} bite {out['biteFar']} hide {out['hideFar']} in {out['inMouthAtBite']}/"
        f"{out['inMouthAtHide']} wait {out['wait']} grab {out['grabAt']} jerk fish {out['fishJerk'][0]} torso "
        f"{out['torsoJerk'][0]} nose {out['noseSpeed']} cam {out['camJump'][0]} walls {out['wallFrames']} "
        f"hidOut {out['hiddenOutside']} mouth rule {out.get('mouthVsRule')} paint {out.get('mouthVsPaint')} "
        f"err {len(out['errors'])} fps {out['meanFps']}"
    )
    return out


def eaters():
    import fail_mouth_table as T

    by_creature, by_arch, low, arche, _ = T.read_config()
    out = []
    for fn in sorted((Path(T.CREATURES)).glob("*.json")):
        rig = json.loads(fn.read_text(encoding="utf-8"))
        if T.fail_of(fn.stem, rig.get("Tier"), by_creature, by_arch, low, arche) in ("Chomp", "Gulp"):
            out.append(fn.stem)
    return out


def thrower():
    """The first fish whose own fail is the plain throw (a low tier)"""
    import fail_mouth_table as T

    by_creature, by_arch, low, arche, _ = T.read_config()
    for fn in sorted((Path(T.CREATURES)).glob("*.json")):
        rig = json.loads(fn.read_text(encoding="utf-8"))
        if T.fail_of(fn.stem, rig.get("Tier"), by_creature, by_arch, low, arche) == "Throw":
            return fn.stem
    return ""


def eat(fishes):
    fishes = fishes or eaters()
    mins, table = proposal()
    print(f"Fail.EatSmall 1 with the dials on; EatMin: {mins}")
    setw(TestMaxOxygen=10000000)
    rows = []
    try:
        for spec in fishes:
            fish, _, size = spec.partition("@")
            size = size or None
            for tag, on in (("on1", True), ("on2", True), ("off", False)):
                name = f"eat_{fish}{'_' + size if size else ''}_{tag}"
                try:
                    r = eat_one(fish, on, name, size, mins, table)
                except SystemExit as e:
                    # (a fish that could not be mounted, e.g. the 30 s wait for Riding: said, and the list goes on)
                    if isinstance(e.code, int):
                        raise
                    print(f"{name}: NOT RUN ({e})")
                    setw(TestSize=None)
                    r = {"name": name, "fish": fish, "verdict": f"NOT RUN ({e})"}
                if r is None:
                    return
                rows.append(r)
    finally:
        print("restore:", restore())
        print("home:", home())
        (OUT / "eat_summary.txt").write_text("\n".join(f"{r['name']}: {r['verdict']}" for r in rows) + "\n")


def drown(case, kind="Throw", fish=""):
    if case not in ("deep", "surface", "lip", "miss", "nofail"):
        raise SystemExit("drown CASE: deep, surface, lip, miss, nofail")
    fish = fish or thrower()
    setw(TestMaxOxygen=None if case == "nofail" else 10000000)
    lip_at = None
    if case == "lip":
        said = cmd("lip", 0.6)
        try:
            lip_at = [float(x) for x in said.split()[:3]]
        except ValueError:
            raise SystemExit("no lip: " + said)
    place = {"deep": "deep", "lip": "lip"}.get(case, "surface")
    try:
        for tag, on in (("on", True), ("off", False)):
            name = f"drown_{case}_{kind}_{tag}"
            ok, fps = ready(on, name)
            if not ok:
                return
            do("ground|on", 0.2)
            if case == "miss":
                do("rec|12", 0.2)
                print(" ", cmd("miss", 0.6))
            else:
                print(" ", cmd(f"ride|{fish}|{place}", 1.0))
                # (riding yet, record, fail: one call, as eat_one: call by call through the direct client the fish
                # had swum hundreds of studs off the case's place before the fail)
                both = last_line(server(
                    "local RS = game:GetService('ReplicatedStorage') local p = game:GetService('Players'):GetPlayers()[1] "
                    "local t = os.clock() while p:GetAttribute('State') ~= 'Riding' and os.clock() - t < 30 do task.wait(0.05) end "
                    "if p:GetAttribute('State') ~= 'Riding' then return 'NOTRIDING' end "
                    f"workspace:SetAttribute('FEDo', '{'rec|12' if case != 'nofail' else 'rec|9'}|{time.time()}') task.wait(0.25) "
                    + ("return 'rec'" if case == "nofail" else
                       f"RS:SetAttribute('FECmd', 'fail|{kind}|{time.time()}') task.wait(0.3) return RS:GetAttribute('FESaid')")
                ))
                if both == "NOTRIDING":
                    raise SystemExit("state never Riding")
                if case == "nofail":
                    print(" ", cmd("nofail|1|2", 0.3))
                    # (the meter runs out, the soft path throws and floats; put back at once so it does not go round)
                    try:
                        time.sleep(1.0)
                        wait_state({"Free"}, 20)
                    finally:
                        print(" ", cmd("nofail|0", 0.3))
                else:
                    print(" ", both)
            time.sleep(4)
            frames, meta = pull()
            if case == "nofail":
                out, checks = nofail_metrics(frames, meta)
            else:
                out, checks = drown_metrics(frames, meta, case, lip_at)
            # what the strip guard took for ground standing above the water (part: rays): over open water it
            # should be nothing; anything else here is a part the strip guard would push the body off
            out["groundSeen"] = js(last_line(do("ground", 0.4))) or {}
            line, _ = verdict(checks)
            if not out.get("tested"):
                line = "NOT TESTED (the fail was not where the case says) " + line
            out.update(fish=fish, kind=kind, fps=fps, name=name, verdict=line, checks=checks)
            save(name, frames, out)
            keys = ("rootAtFail", "lipDistance", "highestLoose", "topAtJointsBack", "rootAtJointsBack", "highestAfter",
                    "stripFrames", "handoverJump", "highestFloating")
            print(f"{name}: {line} | " + " ".join(f"{k} {out.get(k)}" for k in keys if k in out)
                  + f" err {len(out['errors'])} fps {out.get('meanFps')}")
            print("  ground above the water:", ", ".join(f"{k} x{v}" for k, v in out["groundSeen"].items()) or "none")
    finally:
        print("restore:", restore())
        print("home:", home())


def hold(fish, t):
    """That fish's own fail stepped to T (as fail_capture.py's gif: the server's waits stretched to the stepping, so
    the body comes loose about when it would), then held there"""
    t = float(t)
    print("home:", home())
    fps = 10
    steps = int(round(t * fps)) + 1
    # (a step is about 1.3 s through studio-runner, about 6 s through the direct client)
    slow = max(2, (steps + 4) * (6.0 if DIRECT else 1.3) / max(t, 0.1))
    setw(TestMaxOxygen=10000000, FailSlow=slow, FailClock=0, DeathClock=0)
    print(cmd(f"ride|{fish}|deep", 1.0))
    wait_state({"Riding"}, 30)
    time.sleep(1.5)
    print(cmd("fail|", 0.3))
    for i in range(steps):
        setw(FailClock=min(t, i / fps))
    setw(DeathClock=t)
    time.sleep(0.5)
    probe = js(do("probe", 0.6))
    print(json.dumps(probe, indent=1))
    print(capture(OUT / f"hold_{fish}_{t}.png") or "no shot")
    print("held: `letgo` lets it go")


def status():
    print("playtest:", playing())
    if playing():
        print("server script:", last_line(server("return tostring(game:GetService('ReplicatedStorage'):GetAttribute('FEReady'))")))
        print("client fps:", last_line(do("fps", 1.6)))
        print("dials:", last_line(do("dials|kept")))


def main():
    global MIN_FPS
    a = sys.argv[1:]
    if "--min-fps" in a:
        i = a.index("--min-fps")
        MIN_FPS = int(a[i + 1])
        del a[i : i + 2]
    what = a[0] if a else "status"
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "status":
        status()
    elif what == "eat":
        eat(a[1:])
    elif what == "drown":
        if len(a) < 2:
            raise SystemExit("drown CASE [KIND] [FISH]: CASE deep, surface, lip, miss, nofail")
        drown(a[1], a[2] if len(a) > 2 else "Throw", a[3] if len(a) > 3 else "")
    elif what == "hold":
        hold(a[1], a[2])
    elif what == "letgo":
        print("restore:", restore())
        print("home:", home())
    elif what in ("play", "stop"):
        print(play(what == "play"))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
