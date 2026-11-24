"""The seahorse trainer, checked in a Studio playtest by numbers (docs/design/trainer.md), on Hugo's PC (studio-runner).
    python tools/studio/trainer_check.py install | remove      (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/trainer_check.py run [baseline.json]   (in a playtest: every check below; exit code 1 on a miss)
    python tools/studio/trainer_check.py places > baseline.json (in a playtest: where every ride stands now, to compare
                                                                a later map or a later TrainService against)
    python tools/studio/trainer_check.py run --nomodels        (a playtest of a place whose TrainerModels were taken out)
    python tools/studio/trainer_check.py shot <level> <out.png> (in a playtest: the player's ride at that level)
What `run` checks:
  every plot's ride is Hugo's level 1 from its mesh files (no part of the kit's old machine, no Edit preview left);
  where the rides stand and face (against a baseline from `places`, if one is named);
  level 1 on every one of the pens is in nothing (as the 12 levels below, which are tried on the player's own pen);
  walking up seats you; Oxygen comes once a second at the level's own number; getting off stops it;
  an upgrade by the real request (coins given, standing by the ride) builds level 2 and takes its price;
  each of the 12 levels builds, and no point of it comes within a quarter stud of another seen part of the plots (the
  fence, the posts, the upgrade sign, a neighbour): the level's own mesh points from art/creatures/Seahorse/tiers/game,
  placed as the game built them, at rest, at both ends of the rock and under a landing; it prints the least gap;
  no upgrade flash stays on a ride whose level changed again before it faded;
  level 12 seats and trains at its own number; no warning or error of ours on the server or the client.
How: the server Script answers commands set on ReplicatedStorage's TCCmd (it shares the game's own modules; a runner
job's `require` would get copies); the LocalScript fires the trainer's own remote ("Off", "Up"), holds the camera for
shots (workspace TCCam) and sends the client's warnings back. Needs the place's src/ up to date (sync_src.py).
"""
import json
import math
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
NAME = "ZZTrainerCheck"

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local RideStyles = require(RS:WaitForChild("Shared"):WaitForChild("RideStyles"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZTrainerReport"
report.Parent = RS
local heard = {}
report.OnServerEvent:Connect(function(_, text)
	table.insert(heard, tostring(text))
end)
local function v3(v)
	return { math.floor(v.X * 1000 + 0.5) / 1000, math.floor(v.Y * 1000 + 0.5) / 1000, math.floor(v.Z * 1000 + 0.5) / 1000 }
end
local function plots()
	return workspace.ClaudeBlockout.Dock.Plots
end
local function rideOf(plot)
	local ride = plot:FindFirstChild("TrainerRide")
	local toy = ride and ride:FindFirstChild("Toy")
	local body = toy and toy:FindFirstChild("Body")
	return ride, toy, body
end
-- what of the plots a ride's own parts may touch: its own pieces, and the floor
local FLOOR = { Pad = true, PenPlate = true, TrainerSpot = true, TrainerPad = true }
local NEAR = 16 -- studs from the coil's foot: further than any level reaches
local function rows(plot)
	local ride, toy = rideOf(plot)
	local base = ride:GetAttribute("SpringBase")
	local function row(kind, p, name)
		local c = { base:ToObjectSpace(p.CFrame):GetComponents() }
		for i, v in c do
			c[i] = math.floor(v * 10000 + 0.5) / 10000
		end
		return { k = kind, n = name or p.Name, m = p:IsA("MeshPart"), s = { p.Size.X, p.Size.Y, p.Size.Z }, c = c }
	end
	local out = {}
	for _, d in toy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, row("toy", d))
		end
	end
	local stand = plot:FindFirstChild("TrainerStand")
	if stand then
		for _, d in stand:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, row("still", d))
			end
		end
	end
	for _, d in plots():GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and (d.Position - base.Position).Magnitude - d.Size.Magnitude / 2 < NEAR then
			local own = d:IsDescendantOf(ride)
				or (d.Parent == plot and FLOOR[d.Name])
				or (stand ~= nil and d:IsDescendantOf(stand))
				or (d:FindFirstAncestor("TrainerSpring") ~= nil and d:FindFirstAncestor("TrainerSpring").Parent == plot)
			if not own then
				table.insert(out, row("fixed", d, d.Parent.Name .. "." .. d.Name))
			end
		end
	end
	return out
end
local function described(plot)
	local ride, _, body = rideOf(plot)
	return {
		level = ride:GetAttribute("Level"),
		mesh = body:IsA("MeshPart") and body.MeshId or body.ClassName,
		title = ride:GetAttribute("Title"),
		swing = RideStyles.Trainer.Swing,
		dip = RideStyles.Trainer.Dip,
		bounce = RideStyles.Trainer.Bounce,
		rows = rows(plot),
	}
end
local function answer(player, what, arg)
	local plot = plots():FindFirstChild(tostring(player:GetAttribute("Plot")))
	if what == "state" then
		local ride, _, body
		if plot then
			ride, _, body = rideOf(plot)
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local level = player:GetAttribute("TrainerLevel") or 0
		local row = Config.Train.Levels[math.clamp(level, 1, #Config.Train.Levels)]
		return {
			plot = plot and plot.Name,
			state = RideService.stateOf(player),
			level = level,
			rideLevel = ride and ride:GetAttribute("Level"),
			mesh = body and body:IsA("MeshPart") and body.MeshId or (body and body.ClassName),
			max = player:GetAttribute("MaxOxygen"),
			training = player:GetAttribute("Training"),
			onRide = player:GetAttribute("TrainerRide"),
			rider = ride and ride:GetAttribute("Rider"),
			welded = body ~= nil and body:FindFirstChild("TrainerWeld") ~= nil,
			coins = AquariumService.coinsOf(player),
			each = row.Oxygen,
			nextPrice = Config.Train.Levels[math.min(level + 1, #Config.Train.Levels)].Price,
			free = Config.Train.Free,
			root = root and v3(root.Position),
			axis = ride and typeof(ride:GetAttribute("SpringBase")) == "CFrame" and v3(ride:GetAttribute("SpringBase").Position),
		}
	elseif what == "coins" then
		AquariumService.give(player, tonumber(arg) or 0)
		return { coins = AquariumService.coinsOf(player) }
	elseif what == "near" or what == "far" then
		-- beside the ride (inside the walk-up reach) or well away from it, on the hub's side
		local ride = rideOf(plot)
		local base = ride:GetAttribute("SpringBase")
		local away = if what == "near" then RideStyles.Trainer.Reach - 1.5 else 16
		local at = base.Position + base.LookVector * away + Vector3.new(0, 4, 0)
		player.Character:PivotTo(CFrame.lookAt(at, at - base.LookVector))
		return { at = v3(at) }
	elseif what == "level" then
		game:GetService("ServerStorage").TrainerTest:Invoke("level", player.UserId, tonumber(arg))
		task.wait(0.4)
		return described(plot)
	elseif what == "rows" then
		return described(plots():FindFirstChild(tostring(arg)))
	elseif what == "places" then
		-- where every plot's ride stands: the coil's foot and top, the seat, and the way it faces
		local out = {}
		for _, p in plots():GetChildren() do
			local ride = p:FindFirstChild("TrainerRide")
			local base = ride and ride:GetAttribute("SpringBase")
			if typeof(base) == "CFrame" then
				out[p.Name] = {
					base = v3(base.Position),
					top = v3(ride:GetAttribute("SpringTop").Position),
					seat = v3(ride:GetAttribute("Seat").Position),
					ahead = v3(base.LookVector),
				}
			end
		end
		return out
	elseif what == "rides" then
		local out = {}
		for i = 1, 8 do
			local p = plots():FindFirstChild("Plot" .. i)
			local ride, toy, body
			if p then
				ride, toy, body = rideOf(p)
			end
			local old, preview = {}, 0
			if p then
				for _, c in p:GetChildren() do
					if c:IsA("BasePart") and (c.Name == "TrainerBase" or c.Name == "TrainerSpring" or c.Name == "SpringCoil") then
						table.insert(old, c.Name)
					end
					if c:GetAttribute("EditPreview") == true then
						preview += 1
					end
				end
				local spot = p:FindFirstChild("TrainerSpot")
				if spot and spot.Transparency < 1 then
					table.insert(old, "TrainerSpot seen")
				end
				if ride and ride:FindFirstChild("TrainerRide") then
					table.insert(old, "plate")
				end
			end
			local meshes, unseen = 0, 0
			if toy then
				for _, d in toy:GetDescendants() do
					if d:IsA("MeshPart") then
						meshes += 1
					elseif d:IsA("BasePart") and d.Transparency >= 1 then
						unseen += 1
					end
				end
			end
			out["Plot" .. i] = {
				level = ride and ride:GetAttribute("Level"),
				mesh = body and body:IsA("MeshPart") and body.MeshId or (body and body.ClassName),
				meshes = meshes,
				unseen = unseen,
				old = old,
				preview = preview,
				stand = p and p:FindFirstChild("TrainerStand") ~= nil,
				spring = p and p:FindFirstChild("TrainerSpring") ~= nil and p.TrainerSpring:IsA("Model"),
				pad = p and p:FindFirstChild("TrainerPad") ~= nil,
				base = ride and typeof(ride:GetAttribute("SpringBase")) == "CFrame",
			}
		end
		return out
	elseif what == "logs" then
		local server = {}
		for _, m in LogService:GetLogHistory() do
			if m.messageType == Enum.MessageType.MessageWarning or m.messageType == Enum.MessageType.MessageError then
				table.insert(server, m.messageType.Name .. ": " .. string.sub(m.message, 1, 300))
			end
		end
		return { server = server, client = heard }
	end
	return { error = "no such command" }
end
RS:GetAttributeChangedSignal("TCCmd"):Connect(function()
	local cmd = RS:GetAttribute("TCCmd")
	if type(cmd) ~= "string" then
		return
	end
	local what, arg = string.match(cmd, "^([^|]*)|([^|]*)|")
	local player = Players:GetPlayers()[1]
	local ok, got = pcall(function()
		return if player then answer(player, what, arg) else { error = "no player" }
	end)
	RS:SetAttribute("TCSaid", cmd .. "\n" .. HttpService:JSONEncode(if ok then got else { error = tostring(got) }))
end)
'''

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local report = RS:WaitForChild("ZZTrainerReport")
local sent = 0
local function say(message, kind)
	if (kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError) and sent < 60 then
		sent += 1
		report:FireServer(kind.Name .. ": " .. string.sub(message, 1, 300))
	end
end
for _, m in LogService:GetLogHistory() do
	say(m.message, m.messageType)
end
LogService.MessageOut:Connect(say)
workspace:GetAttributeChangedSignal("TCDo"):Connect(function()
	local what = string.match(tostring(workspace:GetAttribute("TCDo")), "^([^|]*)|")
	if what == "off" or what == "up" then
		RS:WaitForChild("Remotes"):WaitForChild("Trainer"):FireServer(if what == "off" then "Off" else "Up")
	elseif what == "flashes" then
		-- an upgrade's white flash (TrainerController) still on a ride
		local n = 0
		for _, d in workspace.ClaudeBlockout.Dock.Plots:GetDescendants() do
			if d:IsA("Highlight") and d.Name == "UpgradeFlash" then
				n += 1
			end
		end
		report:FireServer("FLASHES " .. n)
	end
end)
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local want = workspace:GetAttribute("TCCam")
	if typeof(want) == "CFrame" then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = want
		cam.FieldOfView = 50
	elseif cam.CameraType == Enum.CameraType.Scriptable and workspace:GetAttribute("TCCamWas") then
		workspace:SetAttribute("TCCamWas", nil)
		cam.CameraType = Enum.CameraType.Custom
	end
end)
'''


def run(args, timeout=180):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    return "[==[" + str(v) + "]==]"


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("{NAME}")
	if old then old:Destroy() end
end
for _, k in {{ "TCCam", "TCDo", "TCCamWas" }} do
	workspace:SetAttribute(k, nil)
end
for _, k in {{ "TCCmd", "TCSaid" }} do
	game:GetService("ReplicatedStorage"):SetAttribute(k, nil)
end
if {"true" if remove else "false"} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "{NAME}"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "{NAME}"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(what, arg="", wait=6.0):
    """a command to the game's own server script; its answer"""
    stamp = f"{what}|{arg}|{time.time()}"
    out = run(["--ctx", "server", "--code",
               f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('TCCmd', {lua(stamp)}) local t = os.clock() "
               f"repeat task.wait(0.05) local s = RS:GetAttribute('TCSaid') until (type(s) == 'string' and string.sub(s, 1, #{lua(stamp)}) == {lua(stamp)}) "
               f"or os.clock() - t > {wait} return RS:GetAttribute('TCSaid')"])
    at = out.find(stamp + "\n")
    if at < 0:
        raise SystemExit(f"no answer to {what}: {out[-400:]}")
    return json.JSONDecoder().raw_decode(out[at + len(stamp) + 1:])[0]


def do(what):
    run(["--ctx", "server", "--code", f"workspace:SetAttribute('TCDo', {lua(what + '|' + str(time.time()))}) return 'ok'"])


def until(test, seconds=6.0, every=0.4):
    """the state once `test` holds (or the last one read)"""
    end = time.time() + seconds
    while True:
        s = cmd("state")
        if test(s) or time.time() > end:
            return s
        time.sleep(every)


def shot(level, path):
    path = Path(path).resolve()
    info = cmd("level", level, 12)
    s = cmd("state")
    code = ("local p = workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(" + lua(s["plot"]) + ") local base = p.TrainerRide:GetAttribute('SpringBase') "
            "local to = base.Position + Vector3.new(0, 7.5, 0) local from = to + base.LookVector * 27 + base.RightVector * 15 + Vector3.new(0, 5, 0) "
            "workspace:SetAttribute('TCCam', CFrame.lookAt(from, to)) return 'ok'")
    said = run(["--ctx", "server", "--code", code])
    if "ok" not in said:
        raise SystemExit("the camera was not set: " + said[-300:])
    time.sleep(2.5)
    path.unlink(missing_ok=True)
    run(["shot", str(path)])
    size, same = -1, 0
    for _ in range(40):
        time.sleep(0.25)
        now = path.stat().st_size if path.exists() else 0
        same = same + 1 if now == size and now > 0 else 0
        size = now
        if same >= 3:
            break
    run(["--ctx", "server", "--code", "workspace:SetAttribute('TCCamWas', true) workspace:SetAttribute('TCCam', nil) return 'ok'"])
    print(f"level {info.get('level')} ({info.get('title')}): {path} ({size} bytes)")


def vertices(level):
    """each mesh part of a level, as the installer writes it: {name: (its points about its box's middle, the box)}"""
    sys.path.insert(0, str(ROOT / "tools/creatures"))
    import glb_meshes
    out = {}
    for p in glb_meshes.parts(str(ROOT / f"art/creatures/Seahorse/tiers/game/T{level}/SeahorseTrainer{level}.glb")):
        if p["triangles"]:
            pos = p["positions"]
            lo = [min(v[i] for v in pos) for i in range(3)]
            hi = [max(v[i] for v in pos) for i in range(3)]
            out[p["name"]] = ([[v[i] - (lo[i] + hi[i]) / 2 for i in range(3)] for v in pos], [hi[i] - lo[i] for i in range(3)])
    return out


def clearance(got):
    """the least gap, in studs, between a built level and every other seen part of the plots near it: every point of
    its meshes (the game's own, scaled as built; a plain part by its corners), the stand still, the toy at rest, at
    both ends of the rock with the dip, and with a landing's give on top. {other part: (gap, toy part, pose)}"""
    meshes = vertices(got["level"])

    def place(c, v):
        return [c[0] + c[3] * v[0] + c[4] * v[1] + c[5] * v[2], c[1] + c[6] * v[0] + c[7] * v[1] + c[8] * v[2], c[2] + c[9] * v[0] + c[10] * v[1] + c[11] * v[2]]

    def into(c, p):
        d = [p[0] - c[0], p[1] - c[1], p[2] - c[2]]
        return [c[3] * d[0] + c[6] * d[1] + c[9] * d[2], c[4] * d[0] + c[7] * d[1] + c[10] * d[2], c[5] * d[0] + c[8] * d[1] + c[11] * d[2]]

    points = {"toy": [], "still": []}
    for r in got["rows"]:
        if r["k"] == "fixed":
            continue
        if r["m"] and r["n"] in meshes:
            local, box = meshes[r["n"]]
            k = [r["s"][i] / box[i] if box[i] > 0.02 else 1 for i in range(3)]
            local = [[v[i] * k[i] for i in range(3)] for v in local]
        else:
            h = [v / 2 for v in r["s"]]
            local = [[x * h[0], y * h[1], z * h[2]] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        points[r["k"]] += [(r["n"], place(r["c"], v)) for v in local]
    swing, dip, bounce = got["swing"], got["dip"], got["bounce"]
    poses = [(0, 0, "at rest"), (swing, dip, "rocked back"), (-swing, dip, "rocked forward"), (swing / 2, dip / 4, "half back"),
             (-swing / 2, dip / 4, "half forward"), (swing, dip + bounce, "landed on, rocked back"), (-swing, dip + bounce, "landed on, rocked forward")]
    fixed = [r for r in got["rows"] if r["k"] == "fixed"]
    best = {}
    for angle, drop, pose in [(0, 0, "the stand")] + poses:
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        for name, p in points["still" if pose == "the stand" else "toy"]:
            # (in the coil foot's own space: the rock is about its side axis, through the foot)
            q = [p[0], p[1] * ca - p[2] * sa - drop, p[1] * sa + p[2] * ca]
            for f in fixed:
                l = into(f["c"], q)
                d = [abs(l[i]) - f["s"][i] / 2 for i in range(3)]
                out = math.sqrt(sum(max(v, 0) ** 2 for v in d))
                gap = out if out > 0 else max(d)
                if f["n"] not in best or gap < best[f["n"]][0]:
                    best[f["n"]] = (gap, name, pose)
    return best


CLEAR = 0.25  # studs: nearer than this to another part counts as in it


def nearest(got):
    """(the least gap of a built ride, what to say of it: the nearest thing, and the nearest piece of fence)"""
    gaps = sorted(clearance(got).items(), key=lambda kv: kv[1][0])
    if not gaps:
        return 9e9, "nothing within reach"
    fence = [g for g in gaps if ".Fence" in g[0] or g[0].endswith(".Post")]
    show = gaps[:1] + (fence[:1] if fence and fence[0] != gaps[0] else [])
    return gaps[0][1][0], "; ".join(f"{name.split('.')[-1]} {gap:+.2f} ({part}, {pose})" for name, (gap, part, pose) in show)


def check(baseline, nomodels):
    bad = []

    def expect(name, ok, detail=""):
        print(("ok   " if ok else "MISS ") + name + (": " + str(detail) if detail != "" else ""), flush=True)
        if not ok:
            bad.append(name)

    s = until(lambda s: s.get("plot") and s.get("state") == "Dock", 30)
    expect("the player has a plot and is on the dock", bool(s.get("plot")) and s.get("state") == "Dock", f"{s.get('plot')} {s.get('state')}")
    rides = cmd("rides")
    for name in sorted(rides):
        r = rides[name]
        if nomodels:
            ok = r["base"] and r["spring"] and r["pad"] and not r["old"] and r["preview"] == 0 and r["meshes"] == 0
            expect(f"{name}: the stand-in (a pad and a coil, no seahorse), nothing of the old machine", ok, r)
        else:
            ok = (r["level"] == 1 and "ridefish/Trainer1/" in str(r["mesh"]) and r["meshes"] >= 5 and r["unseen"] == 0 and not r["old"]
                  and r["preview"] == 0 and r["stand"] and r["spring"] and r["base"])
            expect(f"{name}: Hugo's level 1 from its meshes, nothing of the old machine, no Edit preview", ok, "" if ok else r)
    if baseline:
        was, here = json.loads(Path(baseline).read_text()), cmd("places")
        worst = max((abs(a - b) for name in was for k in was[name] for a, b in zip(was[name][k], here.get(name, {}).get(k, [9e9] * 3))), default=9e9)
        expect("every ride's coil and seat stand where they stood, facing the same way (baseline)", len(here) == len(was) and worst <= 0.05,
               f"largest difference {worst:.3f} studs over {len(was)} plots")
    if not nomodels:
        # level 1 on every pen (they are mirrored and turned): in nothing
        for name in sorted(rides):
            least, said = nearest(cmd("rows", name, 15))
            expect(f"{name}: level 1 in nothing, the fence least of all", least > CLEAR, "nearest: " + said)
    logs = cmd("logs")
    ours = [m for m in logs["server"] if "TrainService" in m]
    if nomodels:
        expect("the server says once that the level models are missing", len(ours) == 1 and "MISSING" in ours[0], ours)
    else:
        expect("no warning from TrainService", not ours, ours)

    # walk up: seated, and Oxygen once a second at the level's number
    cmd("far")
    time.sleep(0.6)
    cmd("near")
    s = until(lambda s: s.get("onRide"), 5)
    expect("walking up seats you on your own ride", s.get("onRide") == s.get("plot") and s.get("welded") and s.get("rider"), f"{s.get('onRide')} welded {s.get('welded')}")
    until(lambda s: s.get("training"), 3)
    a = cmd("state")
    t0 = time.time()
    time.sleep(6)
    b = cmd("state")
    took = time.time() - t0
    gained, each = (b["max"] or 0) - (a["max"] or 0), a["each"]
    ticks = gained / each if each else 0
    expect(f"seated: +{each} Oxygen once a second", b.get("training") and gained % each == 0 and took - 1.6 <= ticks <= took + 0.6,
           f"{a['max']} to {b['max']} in {took:.1f} s: {ticks:g} ticks of {each}")
    do("off")
    s = until(lambda s: not s.get("onRide"), 5)
    expect("getting off: off the seat, not training", not s.get("onRide") and not s.get("welded") and not s.get("training"), f"{s.get('onRide')} {s.get('training')}")
    time.sleep(1.2)
    a = cmd("state")
    time.sleep(2.5)
    b = cmd("state")
    expect("off the seat no Oxygen comes", a["max"] == b["max"], f"{a['max']} to {b['max']}")

    # the upgrade, by the real request
    need = 0 if b["free"] == 1 else b["nextPrice"]
    cmd("coins", need + 5000)
    before = cmd("state")
    do("up")
    s = until(lambda s: s.get("level") == 2 and s.get("rideLevel") == 2, 5)
    spent = before["coins"] - s["coins"]
    if nomodels:
        expect("an upgrade by the sign's request: level 2, its price taken", s.get("level") == 2 and spent == need, f"level {s.get('level')}, {spent} coins")
    else:
        expect("an upgrade by the sign's request: level 2 built, its price taken",
               s.get("level") == 2 and s.get("rideLevel") == 2 and "Trainer2/" in str(s.get("mesh")) and spent == need,
               f"level {s.get('level')}, ride {s.get('rideLevel')}, {s.get('mesh')}, {spent} coins")
        # every level: built, and clear of everything else on the plots
        for level in range(1, 13):
            got = cmd("level", level, 15)
            least, said = nearest(got)
            expect(f"level {level} ({got.get('title')}) on {before['plot']}: built from its meshes; in nothing, the fence least of all",
                   got["level"] == level and f"Trainer{level}/" in str(got["mesh"]) and least > CLEAR, "nearest: " + said)
        # the upgrade's white flash fades in under a second: none may be left on a ride built again mid-flash
        for level in (3, 6, 9, 12):
            run(["--ctx", "server", "--code", f"game:GetService('ServerStorage').TrainerTest:Invoke('level', game.Players:GetPlayers()[1].UserId, {level}) return 'ok'"])
        time.sleep(2)
        do("flashes")
        time.sleep(1)
        left = [m for m in cmd("logs")["client"] if m.startswith("FLASHES")]
        expect("no upgrade flash left on a ride after levels changed fast", bool(left) and left[-1] == "FLASHES 0", left[-1:] or "the client did not answer")
        cmd("far")
        time.sleep(0.6)
        cmd("near")
        s = until(lambda s: s.get("onRide"), 5)
        until(lambda s: s.get("training"), 3)
        a = cmd("state")
        t0 = time.time()
        time.sleep(4)
        b = cmd("state")
        took = time.time() - t0
        gained, each = (b["max"] or 0) - (a["max"] or 0), a["each"]
        ticks = gained / each if each else 0
        expect(f"level 12 seats and gives +{each} once a second", s.get("onRide") and a["level"] == 12 and gained % each == 0 and took - 1.6 <= ticks <= took + 0.6,
               f"{a['max']} to {b['max']} in {took:.1f} s: {ticks:g} ticks")
        do("off")
        until(lambda s: not s.get("onRide"), 5)
    logs = cmd("logs")
    errors = [m for m in logs["server"] if m.startswith("MessageError")] + [m for m in logs["client"] if m.startswith("MessageError")]
    expect("no error on the server or the client", not errors, errors[:4])
    trainer = [m for m in logs["client"] if "[Trainer]" in m]
    expect("the client has no complaint about the seahorse's mesh files", not trainer, trainer[:2])
    print("client warnings:", len(logs["client"]), "| server warnings and errors:", len(logs["server"]))
    for m in logs["server"][:6] + logs["client"][:6]:
        print("   ", m[:200])
    print("ALL GOOD" if not bad else f"{len(bad)} MISSED: " + "; ".join(bad))
    return 1 if bad else 0


def main():
    args = sys.argv[1:]
    what = args[0] if args else ""
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    elif what == "run":
        rest = [a for a in args[1:] if not a.startswith("--")]
        return check(rest[0] if rest else None, "--nomodels" in args)
    elif what == "shot":
        shot(int(args[1]), args[2])
    elif what == "places":
        print(json.dumps(cmd("places"), indent=1))
    elif what == "logs":
        print(json.dumps(cmd("logs"), indent=1))
    else:
        print(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main())
