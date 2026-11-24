-- The offline stage for the dive's checks (tools/dive/*.luau): the game's own DiveController and Config, loaded from a
-- place Rojo built (tools/index/harness.luau), over the solid boxes round the lip (tools/dive/lip_boxes.py), with
-- stand-ins for the workspace's casts, the players, the run loop and the effects. The casts are Lune sums: a ray is
-- exact, a sphere is a ray against the box grown by its radius, a box cast is the box looked for every 2 studs.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Harness = require("../index/harness")

local V3, CF = roblox.Vector3, roblox.CFrame
local World = {}

type Box = { name: string, cf: any, half: any, r: number, p: any }

function World.open(placePath: string, boxesPath: string)
	local world = Harness.open(placePath)
	local data = serde.decode("json", fs.readFile(boxesPath))
	local boxes: { Box } = {}
	for _, b in data.boxes do
		if b.k ~= "figure" then
			local half = V3.new(b.s[1], b.s[2], b.s[3]) * 0.5
			table.insert(boxes, {
				name = b.n,
				cf = CF.fromMatrix(
					V3.new(b.p[1], b.p[2], b.p[3]),
					V3.new(b.x[1], b.x[2], b.x[3]),
					V3.new(b.y[1], b.y[2], b.y[3]),
					V3.new(b.z[1], b.z[2], b.z[3])
				),
				half = half,
				r = half.Magnitude,
				p = V3.new(b.p[1], b.p[2], b.p[3]),
			})
		end
	end
	-- numbers once, for speed
	local N = {}
	for i, b in boxes do
		local x, y, z = b.cf.XVector, b.cf.YVector, b.cf.ZVector
		N[i] = {
			name = b.name,
			inst = { Name = b.name },
			px = b.p.X,
			py = b.p.Y,
			pz = b.p.Z,
			r = b.r,
			a = { { x.X, x.Y, x.Z }, { y.X, y.Y, y.Z }, { z.X, z.Y, z.Z } },
			h = { b.half.X, b.half.Y, b.half.Z },
		}
	end

	local function skipOf(params: any): { [any]: boolean }
		local skip = {}
		for _, v in if params then params.FilterDescendantsInstances else {} do
			skip[v] = true
		end
		return skip
	end

	-- a ray against every box (grown by `grow`): the nearest hit's share of the way and its name. One that begins inside
	-- a box does not see it, as in the engine
	local function cast(from: any, dir: any, grow: number, params: any)
		local skip = skipOf(params)
		local best, name = 2, nil
		local mx, my, mz = from.X, from.Y, from.Z
		local dx, dy, dz = dir.X, dir.Y, dir.Z
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		for _, b in N do
			local ox, oy, oz = mx - b.px, my - b.py, mz - b.pz
			-- (broad: the segment's middle against the box's ball)
			local cx, cy, cz = ox + dx / 2, oy + dy / 2, oz + dz / 2
			local reach = len / 2 + b.r + grow
			if not skip[b.inst] and cx * cx + cy * cy + cz * cz <= reach * reach then
				local near, far, miss = -math.huge, math.huge, false
				for k = 1, 3 do
					local a, h = b.a[k], b.h[k] + grow
					local o = ox * a[1] + oy * a[2] + oz * a[3]
					local d = dx * a[1] + dy * a[2] + dz * a[3]
					if math.abs(d) < 1e-9 then
						if math.abs(o) > h then
							miss = true
							break
						end
					else
						local t1, t2 = (-h - o) / d, (h - o) / d
						if t1 > t2 then
							t1, t2 = t2, t1
						end
						near, far = math.max(near, t1), math.min(far, t2)
						if near > far then
							miss = true
							break
						end
					end
				end
				if not miss and near >= 0 and near <= 1 and near < best then
					best, name = near, b.inst
				end
			end
		end
		return if name then best else nil, name
	end

	-- the boxes an oriented box stands in (by their own axes: the six faces and the nine edges)
	local function inside(cf: any, size: any, params: any)
		local out = {}
		local skip = skipOf(params)
		local x, y, z = cf.XVector, cf.YVector, cf.ZVector
		local A = { { x.X, x.Y, x.Z }, { y.X, y.Y, y.Z }, { z.X, z.Y, z.Z } }
		local H = { size.X / 2, size.Y / 2, size.Z / 2 }
		local R = math.sqrt(H[1] ^ 2 + H[2] ^ 2 + H[3] ^ 2)
		local px, py, pz = cf.X, cf.Y, cf.Z
		for _, b in N do
			local dx, dy, dz = b.px - px, b.py - py, b.pz - pz
			if not skip[b.inst] and dx * dx + dy * dy + dz * dz <= (R + b.r) ^ 2 then
				local apart = false
				local function test(lx: number, ly: number, lz: number)
					local l = lx * lx + ly * ly + lz * lz
					if l < 1e-6 then
						return
					end
					local s = 0
					for k = 1, 3 do
						s += H[k] * math.abs(A[k][1] * lx + A[k][2] * ly + A[k][3] * lz)
						s += b.h[k] * math.abs(b.a[k][1] * lx + b.a[k][2] * ly + b.a[k][3] * lz)
					end
					if math.abs(dx * lx + dy * ly + dz * lz) > s then
						apart = true
					end
				end
				for k = 1, 3 do
					test(A[k][1], A[k][2], A[k][3])
					test(b.a[k][1], b.a[k][2], b.a[k][3])
				end
				for i = 1, 3 do
					for j = 1, 3 do
						local u, v = A[i], b.a[j]
						test(u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1])
					end
				end
				if not apart then
					table.insert(out, b.inst)
				end
			end
		end
		return out
	end

	local space: any = { CurrentCamera = { CFrame = CF.new(), FieldOfView = 70, CameraType = nil } }
	function space.Raycast(_, from: any, dir: any, params: any)
		local t, inst = cast(from, dir, 0, params)
		return if t then { Position = from + dir * t, Instance = inst } else nil
	end
	function space.Spherecast(_, from: any, radius: number, dir: any, params: any)
		local t, inst = cast(from, dir, radius, params)
		return if t then { Position = from + dir * t, Instance = inst } else nil
	end
	function space.Blockcast(_, cf: any, size: any, dir: any, params: any)
		local began: { [any]: boolean } = {}
		for _, b in inside(cf, size, params) do
			began[b] = true
		end
		local steps = math.max(math.ceil(dir.Magnitude / 2), 1)
		for i = 1, steps do
			for _, b in inside(cf + dir * (i / steps), size, params) do
				if not began[b] then
					return { Instance = b }
				end
			end
		end
		return nil
	end
	function space.GetPartBoundsInBox(_, cf: any, size: any, params: any)
		return inside(cf, size, params)
	end
	-- (the ride fish under us on land: world.land, set by World.mount)
	function space.FindFirstChild(_, name: string)
		if name == "LandFish" and world.land then
			return {
				GetChildren = function()
					return { world.land }
				end,
			}
		end
		return nil
	end
	space.Terrain = { Name = "Terrain" }
	world.services.Workspace = space
	world.space, world.boxes, world.cast, world.inside = space, boxes, cast, inside

	-- the clock the dive runs by, moved by hand
	world.clock = 100
	world.globals.os = setmetatable({
		clock = function()
			return world.clock
		end,
	}, { __index = os })
	world.globals.RaycastParams = {
		new = function()
			return { FilterDescendantsInstances = {} }
		end,
	}
	world.globals.OverlapParams = world.globals.RaycastParams
	local function signal()
		return { Connect = function() end }
	end
	local me: any = {
		UserId = 1,
		Name = "Me",
		attributes = { State = "Dock" },
		CharacterAdded = signal(),
	}
	function me.GetAttribute(_, key: string)
		return me.attributes[key]
	end
	world.me = me
	world.services.Players = {
		GetPlayers = function()
			return { me }
		end,
		GetPlayerByUserId = function(_, id: number)
			return if id == 1 then me else nil
		end,
		PlayerAdded = signal(),
		PlayerRemoving = signal(),
	}
	world.steps = {} :: { [string]: (number) -> () }
	world.services.RunService = {
		IsStudio = function()
			return true
		end,
		BindToRenderStep = function(_, name: string, _order: number, f: (number) -> ())
			world.steps[name] = f
		end,
	}
	world.services.UserInputService = { InputChanged = signal() }
	local nothing = function() end
	local stub = function(path: string, value: any)
		world.stubs[world.find(path):GetFullName()] = value
	end
	local client = "StarterPlayer.StarterPlayerScripts.Client."
	stub(client .. "Lib.Feel", { sound = nothing })
	stub(client .. "Lib.Fx", { burstKept = nothing, prewarmBursts = nothing })
	stub(client .. "Lib.Shake", {
		play = nothing,
		update = function()
			return CF.identity
		end,
	})
	world.splashes = {}
	stub(client .. "Lib.Splash", {
		play = function(at: any, way: any, power: number)
			table.insert(world.splashes, { at = at, power = power, clock = world.clock })
			return #world.splashes
		end,
		hold = nothing,
		release = nothing,
		step = nothing,
		prewarm = function()
			return true
		end,
		stats = function()
			return { running = 0, parts = 0, played = #world.splashes }
		end,
	})
	local State: any = {
		Player = me,
		Mode = "Dock",
		Leaping = false,
		FovPunch = 0,
		FovLong = 0,
	}
	function State.character()
		return me.Character, me.root, me.humanoid
	end
	function State.inWater()
		return State.Mode == "Riding" or State.Mode == "Free" or State.Mode == "Jumping"
	end
	world.State = State
	stub(client .. "Lib.State", State)
	world.waterLine = -9.95 -- (as the Studio runs' logs have it: tools/studio/dive_leap_check.py)
	stub(client .. "Controllers.RideController", {
		waterLine = function()
			return world.waterLine
		end,
	})
	world.anim = {}
	stub(client .. "Controllers.AnimController", world.anim)
	-- (the dock's spawn: 144 behind the lip, looking out along +z here)
	local dock = CF.lookAt(V3.new(0, 3.5, -144), V3.new(0, 3.5, 0))
	stub("ReplicatedStorage.Shared.Net", {
		Folder = {
			GetAttribute = function(_, key: string)
				return if key == "Dock" then dock else nil
			end,
		},
	})
	world.dock = dock
	world.Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
	world.Dive = world.require(world.find(client .. "Controllers.DiveController"))
	world.Dive.Init()
	world.Dive.Start()
	return world
end

-- A kind at a size tier as the server stands it under the rider on land (RideService.landOn): its box in the root's
-- own space, and how high the root stands over the floor
function World.landFish(world: any, kind: any, tier: string)
	local Config = world.Config
	local creature = world.require(world.find("ReplicatedStorage.Shared.Creatures"))
	local rig = creature.get(kind.Id)
	local scale = Config.sizeScale(tier, kind)
	local size = kind.Size * scale
	local k = if rig then kind.Size.Z / rig.Size[3] * scale else scale
	-- (the saddle over the box's middle; the seat's own height over the back is not scaled)
	local seat = if rig
		then V3.new(rig.Seat[1], rig.Seat[2], rig.Seat[3]) * k + V3.new(0, Config.Ride.SeatHeight, 0)
		else V3.new(0, size.Y / 2 + Config.Ride.SeatHeight, -size.Z * 0.04)
	local low, high = size * -0.5 - seat, size * 0.5 - seat
	-- (an R15 rider's root stands 3 over the floor on foot: the hip is 2 and half the root 1)
	local height = math.max(3, -low.Y)
	return { low = low, high = high, height = height, size = size, seat = seat, scale = scale, length = size.Z }
end

-- Our character on that fish, standing at `at` (the root), facing out: the root, the humanoid and the land fish as
-- DiveController asks for them
function World.mount(world: any, kind: any, f: any, at: any)
	local me = world.me
	local root: any = {
		IsA = function()
			return true
		end,
		Size = V3.new(2, 2, 1),
		AssemblyAngularVelocity = V3.new(),
	}
	root.CFrame = CF.lookAt(at, at + V3.new(0, 0, 1))
	root.AssemblyLinearVelocity = V3.new(0, 0, 0)
	root.FindFirstChild = function()
		return nil
	end
	root.GetJoints = function()
		return {}
	end
	setmetatable(root, {
		__index = function(t, k)
			return if k == "Position" then rawget(t, "CFrame").Position else nil
		end,
	})
	me.root = root
	me.humanoid = {
		Health = 100,
		Sit = false,
		PlatformStand = false,
		HipHeight = f.height - 1,
		RigType = roblox.Enum.HumanoidRigType.R15,
	}
	me.Character = me.Character or {}
	me.Character = {
		FindFirstChild = function(_, name: string)
			return if name == "HumanoidRootPart" then root else nil
		end,
		FindFirstChildOfClass = function()
			return me.humanoid
		end,
	}
	me.attributes = { State = "Dock", LandMounted = true }
	world.State.Mode = "Dock"
	-- the rig's joints, as the game names them
	local rig = world.require(world.find("ReplicatedStorage.Shared.Creatures")).get(kind.Id)
	local motors: { [string]: any } = {}
	for _, row in if rig then rig.Parts else {} do
		local motor: any = { Transform = CF.identity, part = row[1] }
		function motor.IsA(_, what: string)
			return what == "Motor6D"
		end
		motors["Rig_" .. row[1]] = motor
	end
	local attributes: any = { LandRider = 1, FishType = kind.Id }
	local middle = (f.low + f.high) / 2
	local model: any = { PrimaryPart = root, motors = motors }
	function model.IsA(_, what: string)
		return what == "Model"
	end
	function model.GetAttribute(_, name: string)
		return attributes[name]
	end
	function model.GetBoundingBox()
		return root.CFrame * CF.new(middle), f.size
	end
	function model.GetExtentsSize()
		return f.size
	end
	function model.FindFirstChild(_, name: string)
		return motors[name]
	end
	world.land = model
	return root, model
end

return World
