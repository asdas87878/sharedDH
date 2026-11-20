"""Land riding by body type (task e4, docs/design/land-motion.md): checked and recorded in a Studio playtest.
    python tools/studio/e4_land_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/e4_land_check.py run                (the checks: every kind on land, motion, rest, clearance, rider)
    python tools/studio/e4_land_check.py gifs               (one short GIF per group of three or four body types)
How: the server Script builds land fish as RideService does (FishModel, weightless, Workspace.LandFish) as an anchored
"gallery" and gives the player fish to ride (RideService.giveCarried); the LocalScript presses 1 and Q through
EquipController.press and reads AnimController.landInfo and the joints. The Studio-only workspace attributes LandClock
and LandMove hold the stride (AnimController), so each GIF frame is set, then shot (studio-run.mjs shot); frames are
cropped and shrunk as they come, never kept full size. Log work/e4/check.log, GIFs docs/attachments/e4-land-*.gif.
Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/e4"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
CROP = (4, 190, 1984, 1205)  # the game view in the Studio window's shot (as fail_capture.py), below the top bar
WIDTH = 480

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local RideService = require(Server:WaitForChild("Services"):WaitForChild("RideService"))
local FishModel = require(Server:WaitForChild("Lib"):WaitForChild("FishModel"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZE4Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("E4Client", tostring(text))
end)
local gallery = {}
local mine = nil -- the LandFish folder made here (RideService makes its own when none is there: two would hide one)
local function floorAt(p, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else p.Y
end
-- one land fish as RideService.landOn builds it, but anchored where it is put and with no rider
local function place(id, size, at, face)
	local kind = Config.FishById[id]
	local model = FishModel.build(kind)
	game:GetService("CollectionService"):RemoveTag(model, FishModel.Tag)
	local scale = Config.sizeScale(size, kind)
	model:ScaleTo(model:GetScale() * scale)
	local root = model.PrimaryPart
	for _, d in model:GetDescendants() do
		if d:IsA("Constraint") or d:IsA("Trail") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	root.Anchored = true
	model:PivotTo(CFrame.new())
	local box, ext = model:GetBoundingBox()
	local below = root.Position.Y - (box.Position.Y - ext.Y / 2)
	local y = floorAt(at, { workspace:FindFirstChild("LandFish"), Players:GetPlayers()[1].Character })
	local spot = Vector3.new(at.X, y + below, at.Z)
	local cf = CFrame.lookAt(spot, spot + face)
	model:PivotTo(cf * (root.CFrame:Inverse() * model:GetPivot()))
	model.Name = "ZZGallery_" .. id
	model:SetAttribute("LandRider", 0)
	model:SetAttribute("FishType", id)
	model:SetAttribute("SizeTier", size)
	model:SetAttribute("Variant", "")
	local folder = workspace:FindFirstChild("LandFish")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LandFish"
		folder.Parent = workspace
		mine = folder
	end
	model.Parent = folder
	table.insert(gallery, model)
	return model, ext
end
RS:GetAttributeChangedSignal("E4Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("E4Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "hands" then
			while #RideService.carried(player) > 0 do
				RideService.takeCarried(player, 1)
			end
			for _, f in game:GetService("HttpService"):JSONDecode(arg) do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] or "" })
			end
			return "hands " .. #RideService.carried(player)
		elseif verb == "stand" then
			local spawn = workspace.ClaudeBlockout.Dock.DockSpawn
			player.Character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(tonumber(arg) or 0), 0))
			return "stood"
		elseif verb == "clear" then
			for _, m in gallery do
				m:Destroy()
			end
			table.clear(gallery)
			if mine then
				mine:Destroy()
				mine = nil
			end
			return "cleared"
		elseif verb == "grid" then
			-- every kind in arg (ids, comma-separated) in rows in front of the dock's spawn, 7 a row
			local spawn = workspace.ClaudeBlockout.Dock.DockSpawn.Position
			local ids = string.split(arg, ",")
			for i, id in ids do
				local col, row = (i - 1) % 7, (i - 1) // 7
				place(id, "Normal", spawn + Vector3.new((col - 3) * 55, 0, -70 - row * 60), Vector3.new(1, 0, 0))
			end
			return "grid " .. #ids
		elseif verb == "parade" then
			-- a row nose to tail along +X from the spawn (spec: [[id, size, gap], ...]; "RIDER" = the player's own place)
			-- (on the open floor in front of the spawn, as the grid)
			local spawn = workspace.ClaudeBlockout.Dock.DockSpawn.Position + Vector3.new(0, 0, -60)
			local x = 0
			local out = {}
			for _, f in game:GetService("HttpService"):JSONDecode(arg) do
				if f[1] == "RIDER" then
					local root = player.Character.HumanoidRootPart
					local land = workspace.LandFish:FindFirstChild(player.Name)
					local len = if land then land:GetExtentsSize().Z else 10
					x += len / 2
					local at = spawn + Vector3.new(x, 0, 0)
					local y = root.Position.Y
					player.Character:PivotTo(CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(at.X + 1, y, at.Z)))
					root.Anchored = true
					x += len / 2 + (f[2] or 8)
					table.insert(out, "rider@" .. math.floor(at.X))
				else
					local kind = Config.FishById[f[1]]
					local len = kind.Size.Z * Config.sizeScale(f[2], kind)
					x += len / 2
					place(f[1], f[2], spawn + Vector3.new(x, 0, 0), Vector3.new(1, 0, 0))
					x += len / 2 + (f[3] or 8)
				end
			end
			return "parade " .. math.floor(x) .. " " .. table.concat(out, " ")
		elseif verb == "free" then
			local root = player.Character.HumanoidRootPart
			root.Anchored = false
			return "free"
		elseif verb == "walk" then
			-- walk the player (and the ride fish) straight along +X for arg seconds
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			player.Character.HumanoidRootPart.Anchored = false
			hum:Move(Vector3.new(1, 0, 0), false)
			task.wait(tonumber(arg) or 1)
			hum:Move(Vector3.zero, false)
			return "walked"
		elseif verb == "state" then
			local land = workspace:FindFirstChild("LandFish") and workspace.LandFish:FindFirstChild(player.Name)
			return string.format("mounted=%s land=%s", tostring(player:GetAttribute("LandMounted")), tostring(land and land:GetAttribute("FishType")))
		end
		return "?"
	end)
	RS:SetAttribute("E4Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Controllers = Client:WaitForChild("Controllers")
local EquipController = require(Controllers:WaitForChild("EquipController"))
local AnimController = require(Controllers:WaitForChild("AnimController"))
local report = RS:WaitForChild("ZZE4Report", 60)
local function frames(n)
	for _ = 1, n do
		RunService.PreSimulation:Wait()
	end
end
-- every Rig_ joint's turn now, and the most any joint turned between two of these, degrees
local function snap(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and string.sub(d.Name, 1, 4) == "Rig_" then
			out[d] = d.Transform
		end
	end
	return out
end
local function apart(a, b)
	local most = 0
	for motor, cf in a do
		local other = b[motor]
		if other then
			local _, angle = (cf:Inverse() * other):ToAxisAngle()
			most = math.max(most, math.abs(math.deg(angle)))
			most = math.max(most, (cf.Position - other.Position).Magnitude * 10)
		end
	end
	return most
end
-- how far the creature's lowest part is under its Root's rest bottom (studs; + is sunk)
local function lowest(model)
	local low = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= model.PrimaryPart then
			local cf, size = d.CFrame, d.Size
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						low = math.min(low, (cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)).Y)
					end
				end
			end
		end
	end
	return low
end
local function gallery()
	local out = {}
	local folder = workspace:FindFirstChild("LandFish")
	for _, m in (folder and folder:GetChildren() or {}) do
		if m:IsA("Model") then
			table.insert(out, m)
		end
	end
	return out
end
workspace:GetAttributeChangedSignal("E4Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("E4Do") or "")
	local verb, a = string.match(cmd, "^(%w+)|?([^|]*)")
	local said = ""
	local ok, err = pcall(function()
		if verb == "key" then
			EquipController.press(Enum.KeyCode[a])
			task.wait(0.7)
			said = "pressed " .. a
		elseif verb == "info" then
			-- what the land motion found in each land fish, and whether it moves, rests and keeps off the floor
			local rows = {}
			local models = gallery()
			-- rest first: the clock free, nobody walking (they settle)
			workspace:SetAttribute("LandClock", -1)
			task.wait(2.5)
			local restLow, restA, restBent = {}, {}, {}
			for _, m in models do
				restA[m] = snap(m)
			end
			task.wait(0.6)
			for _, m in models do
				restBent[m] = apart(restA[m], snap(m))
			end
			-- (the floor line: standing, the stride's clock held, as the probe "low" takes it)
			workspace:SetAttribute("LandMove", 0)
			workspace:SetAttribute("LandClock", 0)
			-- (the lowest over a whole idle stir, 0.6 a second: the fins stir down as well as up)
			for _ = 1, 20 do
				frames(6)
				for _, m in models do
					restLow[m] = math.min(restLow[m] or math.huge, lowest(m))
				end
			end
			workspace:SetAttribute("LandMove", 1)
			local samples = {}
			local sink = {}
			for i = 0, 11 do
				workspace:SetAttribute("LandClock", i * 0.19)
				frames(3)
				for _, m in models do
					local now = snap(m)
					samples[m] = samples[m] or { first = now, most = 0 }
					samples[m].most = math.max(samples[m].most, apart(samples[m].first, now))
					sink[m] = math.max(sink[m] or -math.huge, restLow[m] - lowest(m))
				end
			end
			workspace:SetAttribute("LandClock", -1)
			for _, m in models do
				local info = AnimController.landInfo(m)
				local id = tostring(m:GetAttribute("FishType"))
				local _, want = Config.landStyleOf(id)
				local h = m:GetExtentsSize().Y
				table.insert(rows, string.format(
					"%s|%s|%s|limbs=%s arms=%s heads=%s tails=%s joints=%s body=%s|range=%.1f|rest=%.1f|sink=%.2f|h=%.1f",
					id, want, info and info.style or "NONE", info and info.limbs or "-", info and info.arms or "-",
					info and info.heads or "-", info and info.tails or "-", info and info.joints or "-",
					tostring(info and info.body), samples[m].most, restBent[m], sink[m] or 0, h))
			end
			said = table.concat(rows, "\n")
		elseif verb == "rider" then
			-- our own land fish: is it ours, does the rider go with its back
			local land = workspace.LandFish:FindFirstChild(player.Name)
			local info = land and AnimController.landInfo(land)
			local torso = player.Character:FindFirstChild("LowerTorso") or player.Character:FindFirstChild("Torso")
			local ys = {}
			workspace:SetAttribute("LandMove", 1)
			for i = 0, 7 do
				workspace:SetAttribute("LandClock", i * 0.13)
				frames(3)
				local shift = info and AnimController.landInfo(land).shift
				table.insert(ys, string.format("%.2f/%.2f", torso.Position.Y - player.Character.HumanoidRootPart.Position.Y, shift and shift.Position.Y or 0))
			end
			workspace:SetAttribute("LandClock", -1)
			said = string.format("land=%s style=%s rider=%s me=%d torso/shift=%s", tostring(land and land:GetAttribute("FishType")),
				tostring(info and info.style), tostring(info and info.rider), player.UserId, table.concat(ys, " "))
		elseif verb == "walk" then
			-- walk on our own machine (it owns the character): MoveTo a point ahead, read the stride while walking
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			local root = player.Character.HumanoidRootPart
			hum:MoveTo(root.Position + root.CFrame.LookVector * 200)
			task.wait(1.2)
			local land = workspace.LandFish:FindFirstChild(player.Name)
			local info = land and AnimController.landInfo(land)
			local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			said = string.format("walking move=%.2f phase=%.2f speed=%.1f", info and info.move or -1, info and info.phase or -1, speed)
			hum:MoveTo(root.Position)
			task.wait(0.1)
			hum:Move(Vector3.zero)
		elseif verb == "low" then
			-- which part of a gallery fish goes lowest through the stride, and when
			local m = workspace.LandFish:FindFirstChild("ZZGallery_" .. a)
			local function lowPart()
				local low, name = math.huge, ""
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and d ~= m.PrimaryPart then
						local cf, size = d.CFrame, d.Size
						for _, sx in { -1, 1 } do
							for _, sy in { -1, 1 } do
								for _, sz in { -1, 1 } do
									local y = (cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)).Y
									if y < low then
										low, name = y, d.Name
									end
								end
							end
						end
					end
				end
				return low, name
			end
			workspace:SetAttribute("LandMove", 0)
			workspace:SetAttribute("LandClock", 0)
			frames(4)
			local rest, restName = lowPart()
			local rows = { string.format("rest %s %.2f", restName, rest) }
			workspace:SetAttribute("LandMove", 1)
			for i = 0, 11 do
				workspace:SetAttribute("LandClock", i * 0.19)
				frames(3)
				local low, name = lowPart()
				local info = AnimController.landInfo(m)
				table.insert(rows, string.format("%.2f %s sink=%.2f shiftY=%.2f", i * 0.19, name, rest - low, info.shift and info.shift.Position.Y or 0))
			end
			workspace:SetAttribute("LandClock", -1)
			said = table.concat(rows, "; ")
		elseif verb == "probe" then
			-- a gallery fish's named joints: the world height of the part, the joint's turn and its axis
			local args = string.split(a, ",")
			local m = workspace.LandFish:FindFirstChild("ZZGallery_" .. args[1])
			local rows = {}
			for i = 2, #args do
				local p = m:FindFirstChild(args[i], true)
				local mo = m:FindFirstChild("Rig_" .. args[i], true)
				local ax, ang = mo.Transform:ToAxisAngle()
				table.insert(rows, string.format("%s y=%.2f ang=%.1f axis=(%.2f,%.2f,%.2f)", args[i], p.Position.Y, math.deg(ang), ax.X, ax.Y, ax.Z))
			end
			said = table.concat(rows, "; ")
		elseif verb == "move" then
			local land = workspace.LandFish:FindFirstChild(player.Name)
			local info = land and AnimController.landInfo(land)
			said = string.format("move=%.2f phase=%.2f", info and info.move or -1, info and info.phase or -1)
		elseif verb == "cam" then
			local v = string.split(a, ",")
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			cam.FieldOfView = tonumber(v[7]) or 40
			cam.CFrame = CFrame.lookAt(Vector3.new(tonumber(v[1]), tonumber(v[2]), tonumber(v[3])), Vector3.new(tonumber(v[4]), tonumber(v[5]), tonumber(v[6])))
			for _, g in player.PlayerGui:GetChildren() do
				if g:IsA("ScreenGui") then
					g.Enabled = false
				end
			end
			said = "cam"
		elseif verb == "uncam" then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			for _, g in player.PlayerGui:GetChildren() do
				if g:IsA("ScreenGui") then
					g.Enabled = true
				end
			end
			said = "uncam"
		end
	end)
	report:FireServer((if ok then said else "ERR " .. tostring(err)) .. " @" .. cmd)
end)
'''


def run(args, timeout=180):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    return "[==[" + str(v) + "]==]"


def server(code, timeout=180):
    return run(["--ctx", "server", "--code", code], timeout)


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZE4Check")
	if old then old:Destroy() end
end
for _, k in {{ "E4Do", "LandClock", "LandMove" }} do
	workspace:SetAttribute(k, nil)
end
if {"true" if remove else "false"} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZE4Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZE4Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=1.0):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('E4Said', '') RS:SetAttribute('E4Cmd', {lua(c + '|' + str(time.time()))}) "
        f"local t = os.clock() repeat task.wait(0.05) until RS:GetAttribute('E4Said') ~= '' or os.clock() - t > {wait + 20} "
        f"return RS:GetAttribute('E4Said')"
    )


def do(c, wait=60):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('E4Client', '') "
        f"workspace:SetAttribute('E4Do', {lua(c + '|' + str(time.time()))}) "
        f"local t = os.clock() repeat task.wait(0.05) until RS:GetAttribute('E4Client') ~= '' or os.clock() - t > {wait} "
        f"return RS:GetAttribute('E4Client')",
        wait + 30,
    )


def setw(**kw):
    code = ""
    for k, v in kw.items():
        code += f"workspace:SetAttribute({lua(k)}, {v if isinstance(v, (int, float)) else lua(v)}) "
    return server(code + "return 'ok'")


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
    with Image.open(path) as im:
        crop = im.convert("RGB").crop(CROP)
        return crop.resize((WIDTH, round(WIDTH * crop.height / crop.width)), Image.LANCZOS)


def check():
    log = []
    results = []

    def note(text):
        print(text, flush=True)
        log.append(text)

    def expect(name, ok, detail=""):
        results.append(ok)
        note(("PASS " if ok else "FAIL ") + name + (("  [" + detail + "]") if detail else ""))

    ids = [p.stem for p in sorted((ROOT / "src/shared/Creatures").glob("*.json"))]
    note(f"kinds: {len(ids)}")
    note("stand: " + cmd("stand|0"))
    rows = []
    for start in range(0, len(ids), 21):
        batch = ids[start : start + 21]
        note("clear: " + cmd("clear"))
        note(cmd("grid|" + ",".join(batch), 3))
        # the camera: high over the grid's middle, looking down at it (a fish out of view isn't animated)
        server(
            "local s = workspace.ClaudeBlockout.Dock.DockSpawn.Position "
            "workspace:SetAttribute('E4Do', 'cam|' .. (s.X) .. ',' .. (s.Y + 260) .. ',' .. (s.Z + 60) .. ',' .. s.X .. ',' .. s.Y .. ',' .. (s.Z - 130) .. ',60|' .. os.clock()) return 'ok'"
        )
        time.sleep(1.5)
        out = do("info", 90)
        out = out.rsplit(" @", 1)[0]
        rows += [r for r in out.split("\n") if "|" in r]
        for r in out.split("\n"):
            note("    " + r)
    note("clear: " + cmd("clear"))
    do("uncam")
    seen = {}
    for r in rows:
        parts = r.split("|")
        if len(parts) >= 7:
            seen[parts[0]] = parts
    expect("every kind built on land and set up (82)", len(seen) == len(ids) and all(p[2] != "NONE" for p in seen.values()),
           f"{len(seen)} of {len(ids)}; missing {sorted(set(ids) - set(seen))}")
    expect("each kind runs its own assigned body type", all(p[1] == p[2] for p in seen.values()),
           ", ".join(p[0] for p in seen.values() if p[1] != p[2]))
    still = [p[0] for p in seen.values() if float(p[4].split("=")[1]) < 4]
    expect("every kind moves through its stride (some joint turns 4 degrees or more)", not still, ",".join(still))
    # (at rest only the fins' and arms' stir remains: Config.LandRide.IdleFin, 6 degrees each way)
    restless = [f"{p[0]}={p[5]}" for p in seen.values() if float(p[5].split("=")[1]) > 14]
    expect("at rest the stride settles (only the idle stir: no joint moves more than 14 degrees in 0.6 s)", not restless, ",".join(restless))
    sunk = [f"{p[0]}={p[6].split('=')[1]}" for p in seen.values()
            if float(p[6].split("=")[1]) > max(0.6, 0.12 * float(p[7].split("=")[1]))]
    expect("nothing sinks into the floor by more than 12% of its height (0.6 studs at least)", not sunk, ",".join(sunk))
    nolimb = [p[0] for p in seen.values() if "limbs=0" in p[3]]
    note("no limb joints (body motion only): " + ", ".join(nolimb))

    # the rider on their own equipped fish, walking and stopping
    note("hands: " + cmd("hands|" + json.dumps([["SeaTurtle", "Normal", ""], ["Clownfish", "Tiny", ""]])))
    note("stand: " + cmd("stand|-90", 1.5))
    do("key|One", 5)
    do("key|Q", 5)
    time.sleep(1)
    s = cmd("state")
    note("state: " + s)
    expect("Q rides the Sea Turtle on land", "mounted=true" in s and "land=SeaTurtle" in s, s)
    r = do("rider", 30)
    note("rider: " + r)
    expect("our land fish is animated as ours (rider id, Turtle)", f"style=Turtle rider={r.split('me=')[1].split(' ')[0]}" in r if "me=" in r else False, r)
    pairs = [x.split("/") for x in r.split("torso/shift=")[1].split(" @")[0].split(" ")] if "torso/shift=" in r else []
    if pairs:
        torso = [float(a) for a, b in pairs]
        shift = [float(b) for a, b in pairs]
        expect("the rider rises and falls with the body (torso height follows the shift)",
               abs((max(torso) - min(torso)) - (max(shift) - min(shift))) < 0.35, f"torso {min(torso):.2f}..{max(torso):.2f} shift {min(shift):.2f}..{max(shift):.2f}")
    cmd("free")
    m = do("walk", 10)
    note("walking: " + m)
    time.sleep(3)
    m2 = do("move", 5)
    note("stopped 3 s: " + m2)
    try:
        expect("walking at the land speed drives the stride (move > 0.8)", float(m.split("move=")[1].split(" ")[0]) > 0.8, m)
        expect("stopped: the stride eases to nothing", float(m2.split("move=")[1].split(" ")[0]) < 0.05, m2)
    except Exception as e:
        expect("move readings", False, str(e))
    passed = sum(results)
    note(f"{passed}/{len(results)} PASS")
    (OUT / "check.log").write_text("\n".join(log) + "\n")


GROUPS = {
    # name: (parade, camera side distance, clock seconds)
    "a": [["Clownfish", "Normal", 8], ["RIDER", 8], ["Seahorse", "Normal", 8], ["Octopus", "Normal", 8]],
    "b": [["GiantSquid", "Normal", 6], ["Stingray", "Normal", 6], ["MorayEel", "Normal", 6], ["SeaScorpion", "Normal", 6]],
    "c": [["ReefShark", "Normal", 6], ["Dolphin", "Normal", 6], ["Pufferfish", "Normal", 6], ["Mosasaurus", "Normal", 6]],
    "d": [["AuroraJelly", "Normal", 6], ["BobbitWorm", "Normal", 6], ["TheDevourer", "Normal", 6]],
}
RIDE = {"a": "SeaTurtle"}
TITLES = {
    "a": "fish flop, turtle (ridden), seahorse, octopus",
    "b": "squid scoot, ray shuffle, eel slither, crawler",
    "c": "shark lunge, whale heave, bulbous waddle, reptile crawl",
    "d": "jelly scoot, worm ripple, stomp-drag",
}


def gifs(which=None, frames=14, seconds=1.4):
    for name, parade in GROUPS.items():
        if which and name not in which:
            continue
        cmd("clear")
        cmd("free")
        if name in RIDE:
            cmd("hands|" + json.dumps([[RIDE[name], "Normal", ""]]))
            cmd("stand|-90", 1.5)
            do("key|One", 5)
            do("key|Q", 5)
            time.sleep(1)
        else:
            cmd("hands|[]")
            cmd("stand|-90", 1.5)
        said = cmd("parade|" + json.dumps(parade), 3)
        print(name, said, flush=True)
        span = float(said.split(" ")[1])
        # the camera: off to the side and a little above the row's middle, far enough to hold it all
        mid = span / 2
        # (the parade is 60 studs in front of the spawn; the camera stays this side of the spawn, out of the hub's props)
        dist = min(80, max(40, span * 0.55))
        fov = 40 if span < 70 else 55
        server(
            "local s = workspace.ClaudeBlockout.Dock.DockSpawn.Position "
            f"workspace:SetAttribute('E4Do', 'cam|' .. (s.X + {mid}) .. ',' .. (s.Y + {dist * 0.25}) .. ',' .. (s.Z - 60 + {dist}) .. ',' .. (s.X + {mid}) .. ',' .. (s.Y + 3) .. ',' .. (s.Z - 60) .. ',{fov}|' .. os.clock()) return 'ok'"
        )
        time.sleep(1.5)
        setw(LandMove=1)
        images = []
        for i in range(frames):
            setw(LandClock=i * seconds / frames)
            time.sleep(0.12)
            images.append(shot(OUT / "frame.png"))
            print(f"  frame {i + 1}/{frames}", flush=True)
        setw(LandClock=-1)
        path = ATTACH / f"e4-land-{name}.gif"
        images[0].save(path, save_all=True, append_images=images[1:], duration=round(1000 * seconds / frames), loop=0, optimize=True)
        for im in images:
            im.close()
        print("wrote", path, TITLES[name], flush=True)
    do("uncam")
    cmd("clear")
    cmd("free")


if __name__ == "__main__":
    verb = sys.argv[1] if len(sys.argv) > 1 else "run"
    if verb == "install":
        print(install())
    elif verb == "remove":
        print(install(remove=True))
    elif verb == "run":
        check()
    elif verb == "gifs":
        gifs(sys.argv[2:] or None)
