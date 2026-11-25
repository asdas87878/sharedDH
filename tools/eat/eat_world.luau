-- The real FailController, run offline a frame at a time (Lune): the place's own modules through tools/index/harness,
-- with plain stand-ins for the fish, the rider, the camera and the sea. Nothing of the moves is written again here: the
-- begin, the step, the joints, the grabs and the shot are the game's. What is only like the game: the loose body (one
-- mass pulled as an AlignPosition pulls, in the water's lift and drag; its limbs lie as the move means them to) and the
-- sea (a flat floor, a flat wall ahead, the surface). Used by eat_check.luau and eat_frames.luau.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Harness = require("../index/harness")

local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local World = {}

local DT = 1 / 60
local rad = math.rad

-- anything: a table that answers any name with itself (the UI and effects we don't look at)
local function anything(): any
	local t = {}
	setmetatable(t, {
		__index = function()
			return t
		end,
		__call = function()
			return t
		end,
	})
	return t
end

local function quiet(fields: { [string]: any }): any
	return setmetatable(fields, {
		__index = function()
			return function() end
		end,
	})
end

-- a part: what the game reads of one
local function newPart(name: string, size: any, cf: any, class: string): any
	local p: any = { Name = name, Size = size, CFrame = cf, Transparency = 0, Parent = true, Mass = 1 }
	p.AssemblyLinearVelocity = Vector3.zero
	p.AssemblyAngularVelocity = Vector3.zero
	p.IsA = function(_self, c)
		return c == class or c == "BasePart"
	end
	p.GetChildren = function()
		return p.Children or {}
	end
	p.FindFirstChild = function()
		return nil
	end
	p.FindFirstChildOfClass = p.FindFirstChild
	p.Destroy = function() end
	return setmetatable(p, {
		__index = function(_t, k)
			if k == "Position" then
				return p.CFrame.Position
			end
			return nil
		end,
	})
end

-- where the rider's parts are on their root (R15, the usual sizes)
World.R15 = {
	{ "HumanoidRootPart", CFrame.new(0, 0, 0), Vector3.new(2, 2, 1) },
	{ "UpperTorso", CFrame.new(0, 0.2, 0), Vector3.new(2, 1.6, 1) },
	{ "LowerTorso", CFrame.new(0, -0.8, 0), Vector3.new(2, 0.4, 1) },
	{ "Head", CFrame.new(0, 1.6, 0), Vector3.new(1.2, 1.2, 1.2) },
	{ "LeftUpperArm", CFrame.new(-1.5, 0.4, 0), Vector3.new(1, 1.2, 1) },
	{ "RightUpperArm", CFrame.new(1.5, 0.4, 0), Vector3.new(1, 1.2, 1) },
	{ "LeftLowerArm", CFrame.new(-1.5, -0.4, 0), Vector3.new(1, 1.1, 1) },
	{ "RightLowerArm", CFrame.new(1.5, -0.4, 0), Vector3.new(1, 1.1, 1) },
	{ "LeftUpperLeg", CFrame.new(-0.5, -1.5, 0), Vector3.new(1, 1.3, 1) },
	{ "RightUpperLeg", CFrame.new(0.5, -1.5, 0), Vector3.new(1, 1.3, 1) },
	{ "LeftLowerLeg", CFrame.new(-0.5, -2.4, 0), Vector3.new(1, 1.3, 1) },
	{ "RightLowerLeg", CFrame.new(0.5, -2.4, 0), Vector3.new(1, 1.3, 1) },
}

export type Case = {
	Creature: string,
	Tier: string,
	Kind: string,
	New: boolean,
	Speed: number?,
	FloorUnder: number?, -- studs of water under the root (nil: no floor in reach)
	Wall: number?, -- studs of water ahead of the root
	Top: number?, -- studs from the root up to the surface (nil: deep)
	Pitch: number?, -- degrees it was pitched as it began
	Late: number?, -- seconds the body comes loose after the server's time (lag)
	Lag: number?, -- how many times slower than meant the pull on the body is
}

-- opens the place once: the modules, with FailController's own locals handed out
function World.open(placePath: string, boxesPath: string?)
	local world = Harness.open(placePath)
	local player: any = { Name = "P", Parent = true }
	local clock = { now = 0 }
	local camera: any = { CFrame = CFrame.new(), FieldOfView = 70 }
	local sea: any = { floor = nil, wall = nil, top = 0, from = Vector3.zero, look = Vector3.new(0, 0, -1) }
	local workspaceStub: any = {
		CurrentCamera = camera,
		Gravity = 196.2,
		GetAttribute = function()
			return nil
		end,
		FindFirstChild = function()
			return nil
		end,
		GetServerTimeNow = function()
			return clock.now
		end,
		Raycast = function(_self, from, way)
			-- only the wall ahead
			if sea.wall then
				local at = (from - sea.from):Dot(sea.look)
				local step = way:Dot(sea.look)
				if step > 0 and at < sea.wall and at + step > sea.wall then
					local k = (sea.wall - at) / step
					return { Position = from + way * k, Normal = -sea.look, Instance = {} }
				end
			end
			return nil
		end,
	}
	local osStub = {
		clock = function()
			return clock.now
		end,
		time = os.time,
	}
	local instanceStub = {
		new = function(class)
			local i: any = { ClassName = class, Parent = nil }
			i.IsA = function(_self, c)
				return c == class or (class == "Part" and c == "BasePart")
			end
			i.Destroy = function() end
			i.FindFirstChild = function()
				return nil
			end
			i.FindFirstChildOfClass = i.FindFirstChild
			i.Emit = function() end
			return i
		end,
	}
	world.globals = {
		workspace = workspaceStub,
		os = osStub,
		Instance = instanceStub,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		typeof = typeof,
	}
	world.services.RunService = quiet({
		IsStudio = function()
			return false
		end,
	})
	world.services.Players = quiet({
		GetPlayers = function()
			return {}
		end,
	})
	local client = "StarterPlayer.StarterPlayerScripts.Client."
	player.WaitForChild = function()
		return {}
	end
	local state: any = { Player = player }
	world.stubs[client .. "Lib.Course"] = quiet({
		floor = function()
			return sea.floor
		end,
		laneFloor = function()
			return sea.floor
		end,
		clearMove = function(from, to, clearance)
			local at = to
			if sea.wall then
				-- (the real one's ray: it stops a wall's 2 studs off)
				local far = (at - sea.from):Dot(sea.look)
				local was = (from - sea.from):Dot(sea.look)
				local most = math.max(was, sea.wall - 2)
				if far > most then
					at -= sea.look * (far - most)
				end
			end
			if sea.floor then
				at = Vector3.new(at.X, math.max(at.Y, sea.floor + clearance), at.Z)
			end
			return at
		end,
	})
	world.stubs[client .. "Lib.State"] = state
	world.stubs[client .. "Lib.Fx"] = quiet({})
	world.stubs[client .. "Lib.Shake"] = quiet({})
	world.stubs[client .. "Lib.Underwater"] = quiet({
		shapeThrow = function(v)
			return v
		end,
	})
	world.stubs[client .. "UI.Kit"] = anything()
	world.stubs[client .. "Controllers.AnimController"] = quiet({})
	world.stubs["ReplicatedStorage.Shared.Net"] = anything()
	local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
	local EatMoves = world.require(world.find(client .. "Lib.EatMoves"))
	local module = world.find(client .. "Controllers.FailController")
	local source: string = module.Source
	local count
	-- (the body is ours to move here: its own physics help is not run; and the locals are handed out)
	source, count = string.gsub(source, "\t\t\tstepBody%(b, dt%)\n", "\t\t\tlocal _ = stepBody\n")
	assert(count == 1, "stepBody's call")
	source, count = string.gsub(
		source,
		"return FailController%s*$",
		"FailController.Test = { begin = begin, step = step, fails = fails, bodies = bodies, throwOf = throwOf }\n"
			.. "return FailController\n"
	)
	assert(count == 1, "the end")
	module.Source = source
	local Fail = world.require(module)
	local boxes = serde.decode("json", fs.readFile(boxesPath or "work/eat/boxes.json"))
	return {
		Config = Config,
		EatMoves = EatMoves,
		Fail = Fail,
		Test = Fail.Test,
		boxes = boxes,
		player = player,
		clock = clock,
		camera = camera,
		sea = sea,
		state = state,
		creature = function(name: string)
			return serde.decode("json", fs.readFile("src/shared/Creatures/" .. name .. ".json"))
		end,
	}
end

-- plays one case from begin to a little after the outcome's Time; every frame's numbers
function World.play(w: any, case: Case): any
	local Config = w.Config
	local id = case.Creature
	local fishType = Config.FishById[id]
	local rig = w.creature(id)
	local scale = Config.sizeScale(case.Tier, fishType) -- (FishType.Size is already at its base scale)
	local body = fishType.Size * scale
	local k = body.Z / rig.Size[3]
	local sea = w.sea
	local depth = if case.Top then -case.Top else -400
	local root0 = CFrame.new(0, depth, 0) * CFrame.Angles(rad(case.Pitch or 0), 0, 0)
	sea.from = root0.Position
	sea.look = Vector3.new(0, 0, -1)
	sea.floor = if case.FloorUnder then depth - case.FloorUnder else nil
	sea.wall = case.Wall
	local speed = case.Speed or Config.FishStats[id].Speed
	local fishRoot = newPart("Root", body, root0, "Part")
	fishRoot.AssemblyLinearVelocity = root0.LookVector * speed
	-- the rig
	local motors: { [string]: any } = {}
	local order: { string } = {}
	local parts: { [string]: any } = { [""] = fishRoot }
	local pivots: { [string]: any } = {}
	for _, row in rig.Parts do
		local name, parent = row[1], row[2]
		local box = w.boxes[id][name]
		local lo, hi = Vector3.new(table.unpack(box[1])), Vector3.new(table.unpack(box[2]))
		local part = newPart(name, (hi - lo) * k, CFrame.new((lo + hi) / 2 * k), "MeshPart")
		local pivot = Vector3.new(row[3], row[4], row[5]) * k
		local parentRest = if parent == "" then CFrame.new() else CFrame.new(pivots[parent].mid)
		local motor: any = {
			Name = "Rig_" .. name,
			Parent = true,
			Part0 = parts[parent],
			Part1 = part,
			C0 = parentRest:Inverse() * CFrame.new(pivot),
			C1 = part.CFrame:Inverse() * CFrame.new(pivot),
			Transform = CFrame.new(),
			IsA = function(_self, c)
				return c == "Motor6D"
			end,
		}
		pivots[name] = { pivot = pivot, mid = (lo + hi) / 2 * k }
		parts[name] = part
		motors[name] = motor
		table.insert(order, name)
	end
	local fish: any = { Name = id, Parent = true, PrimaryPart = fishRoot }
	fish.GetAttribute = function(_self, a)
		return if a == "Rig" or a == "FishType" then id else nil
	end
	fish.FindFirstChild = function(_self, n)
		return motors[string.sub(n, 5)]
	end
	fish.GetDescendants = function()
		return {}
	end
	-- the rider
	local saddle =
		CFrame.new(Vector3.new(rig.Seat[1], rig.Seat[2], rig.Seat[3]) * k + Vector3.new(0, Config.Ride.SeatHeight, 0))
	local limbs: { [string]: any } = {}
	local character: any = { Name = "P", Parent = true, Ragdoll = false }
	for _, row in World.R15 do
		limbs[row[1]] = newPart(row[1], row[3], root0 * saddle * row[2], "Part")
	end
	character.FindFirstChild = function(_self, n)
		return limbs[n]
	end
	character.GetDescendants = function()
		return {}
	end
	character.GetAttribute = function(_self, a)
		return if a == "Ragdoll" then character.Ragdoll else nil
	end
	local weld: any = { Name = "RideWeld", Parent = true, C0 = saddle, Part1 = limbs.HumanoidRootPart }
	weld.IsA = function(_self, c)
		return c == "Weld"
	end
	fishRoot.Children = { weld }
	local player = w.player
	player.Character = character
	player.GetAttribute = function(_self, a)
		return if a == "State" then "Failing" else nil
	end
	-- the view as you ride: behind and above, looking ahead (RideController's distances, about)
	local back = 14 + body.Z * 0.75
	local eye = root0.Position + Vector3.new(body.Z * 0.12, body.Y * 0.5 + 6 + body.Z * 0.2, back)
	w.camera.CFrame = CFrame.lookAt(eye, root0.Position + Vector3.new(0, body.Y * 0.4, -body.Z * 0.4))
	setmetatable(w.camera, {
		__index = function(_t, key)
			return if key == "Position" or key == "LookVector" then w.camera.CFrame[key] else nil
		end,
	})
	w.camera.Position, w.camera.LookVector = nil, nil
	-- play
	Config.Fail.NewEat[id] = if case.New then 1 else 0
	Config.bodyOf = function()
		return body
	end
	w.clock.now = 100
	w.state.DeathCam = nil
	table.clear(w.Test.fails)
	table.clear(w.Test.bodies)
	w.Test.begin(player, fish, case.Kind)
	local f = w.Test.fails[player]
	assert(f, "it did not begin")
	local def = Config.Fail.Outcomes[case.Kind]
	local frames: { any } = {}
	local at, velocity, turn = (root0 * saddle).Position, Vector3.zero, (root0 * saddle).Rotation
	local spin = Vector3.zero
	local loose: any = nil
	local n = 0
	while n * DT <= def.Time + 0.2 do
		local t = n * DT
		w.clock.now = 100 + t
		-- the swim goes on turning the joints underneath (AnimController: Motor6D.Transform)
		for i, name in order do
			local a = rad(10) * math.sin(t * 6 + i)
			motors[name].Transform = CFrame.Angles(a * 0.6, a, 0)
		end
		motors[order[1]].Transform = CFrame.new()
		if not loose and t >= def.Loose + (case.Late or 0) then
			weld.Parent = nil
			weld.gone = true
			character.Ragdoll = true
			loose = {
				Player = player,
				Character = character,
				Fish = fish,
				Kind = case.Kind,
				Mine = true,
				Replay = false,
				Parts = { limbs.UpperTorso },
				Main = {},
				Colliders = {},
				Holds = {},
				HitAt = 0,
				New = f.New ~= nil,
				MouthOff = f.New ~= nil,
				Since = w.clock.now,
			}
			w.Test.bodies[player] = loose
			if f.New then
				velocity = w.EatMoves.velocity(f.New, f.U)
			else
				velocity, spin = w.Test.throwOf(case.Kind, fishRoot.CFrame, root0.LookVector * speed)
			end
			at += velocity * DT
		end
		-- (the game's step runs as a frame is drawn, after the last frame's physics: it sees the body where it is now)
		if loose then
			for _, row in World.R15 do
				limbs[row[1]].CFrame = CFrame.new(at) * turn * row[2]
			end
		end
		w.Test.step(DT)
		if w.Test.fails[player] == nil then
			break
		end
		-- the joints
		for _, name in order do
			local m = motors[name]
			m.Part1.CFrame = m.Part0.CFrame * m.C0 * m.Transform * m.C1:Inverse()
		end
		-- the rider
		if not loose then
			local rootCF = fishRoot.CFrame * weld.C0
			velocity = (rootCF.Position - at) / DT
			at, turn = rootCF.Position, rootCF.Rotation
		end
		local rider = CFrame.new(at) * turn
		for _, row in World.R15 do
			limbs[row[1]].CFrame = rider * row[2]
		end
		local shot = w.state.DeathCam
		if shot then
			w.camera.CFrame = CFrame.lookAt(shot.Position, shot.Focus)
		end
		local pose: { [string]: any } = {}
		for _, name in order do
			local m = motors[name]
			pose[name] = m.Part1.CFrame * m.C1
		end
		local boxes: { [string]: any } = {}
		for _, name in order do
			boxes[name] = { CFrame = parts[name].CFrame, Size = parts[name].Size }
		end
		table.insert(frames, {
			t = t,
			u = f.U,
			held = if f.ArmsHeld
				then (function()
					local copy = {}
					for i, h in f.ArmsHeld do
						copy[i] = h.At
					end
					return copy
				end)()
				else nil,
			fish = fishRoot.CFrame,
			rider = rider,
			torso = limbs.UpperTorso.Position,
			loose = loose ~= nil,
			pose = pose,
			boxes = boxes,
			hidden = f.HideAt ~= nil,
			camera = shot and w.camera.CFrame,
			meant = if f.New then w.EatMoves.moment(f.New, f.U) else nil,
		})
		-- (and on to the next frame)
		if loose then
			local force = Vector3.zero
			for key, h in loose.Holds do
				if key ~= "EatLegs" then
					local off = limbs.HumanoidRootPart.CFrame:PointToObjectSpace(h.Part.Position)
					local from = CFrame.new(at) * turn * off
					local R = h.Align.Responsiveness / (case.Lag or 1)
					local want = (h.Align.Position - from) * R * 0.5 - velocity
					local most = h.Align.MaxForce * DT
					force += if want.Magnitude > most then want.Unit * most else want
				end
			end
			local r = Config.Fail.Ragdoll
			velocity += force
			velocity = velocity * math.exp(-r.Drag * DT) - Vector3.new(0, 196.2 * (1 - r.Float) * DT, 0)
			if velocity.Magnitude > 140 then
				velocity = velocity.Unit * 140
			end
			at += velocity * DT
			if f.New then
				local m = w.EatMoves.moment(f.New, f.U)
				turn = turn:Lerp(m.Rider.Rotation, 1 - math.exp(-14 * DT))
			elseif spin.Magnitude > 0.01 then
				turn = CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * DT) * turn
				spin *= math.exp(-1.6 * DT)
			end
		end
		n += 1
	end
	return {
		frames = frames,
		f = f,
		plan = f.New,
		body = body,
		k = k,
		saddle = saddle,
		rig = rig,
		case = case,
		root0 = root0,
		limbs = limbs,
		order = order,
	}
end

World.DT = DT
World.Color3 = Color3
return World
