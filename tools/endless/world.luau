-- A stand-in for a running game, for Lune: the saved place's own lane (the census: tools/endless/census.luau) for rays
-- that go straight down and for small spheres, players that are told where to be, a clock that is told what time it is,
-- and fish that swim where the server tells them to. The game's own modules run in it as they are (tools/index/harness).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../index/harness")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local CELL = 64

local World = {}

-- The lane's parts by the squares of the map they are over
function World.census(folder: string)
	local parts, cells = {}, {}
	for line in string.gmatch(fs.readFile(folder .. "/parts.tsv"), "[^\n]+") do
		if string.sub(line, 1, 8) == "CB/Lane/" then
			local f = string.split(line, "\t")
			local p, r, s = string.split(f[5], ","), string.split(f[6], ","), string.split(f[7], ",")
			local part = {
				Folder = string.split(f[1], "/")[3],
				Model = f[2],
				Name = f[3],
				Solid = f[9] == "1",
				X = tonumber(p[1]),
				Y = tonumber(p[2]),
				Z = tonumber(p[3]),
				R = {},
				H = { tonumber(s[1]) :: number / 2, tonumber(s[2]) :: number / 2, tonumber(s[3]) :: number / 2 },
			}
			for k = 1, 9 do
				part.R[k] = tonumber(r[k])
			end
			local R, H = part.R, part.H
			part.EX = math.abs(R[1]) * H[1] + math.abs(R[2]) * H[2] + math.abs(R[3]) * H[3]
			part.EY = math.abs(R[4]) * H[1] + math.abs(R[5]) * H[2] + math.abs(R[6]) * H[3]
			part.EZ = math.abs(R[7]) * H[1] + math.abs(R[8]) * H[2] + math.abs(R[9]) * H[3]
			part.FindFirstAncestor = function(_, name: string)
				return if name == part.Folder or name == "Lane" then { Name = name } else nil
			end
			table.insert(parts, part)
			if part.Solid then
				for cx = (part.X - part.EX) // CELL, (part.X + part.EX) // CELL do
					for cz = (part.Z - part.EZ) // CELL, (part.Z + part.EZ) // CELL do
						local key = cx * 100000 + cz
						local cell = cells[key]
						if not cell then
							cell = {}
							cells[key] = cell
						end
						table.insert(cell, part)
					end
				end
			end
		end
	end
	local info = serde.decode("json", fs.readFile(folder .. "/census.json"))
	return { Parts = parts, Cells = cells, Dive = info.Dive, Kill = info.FallenPartsDestroyHeight }
end

-- Where a straight line down at (x, z) goes into a part and comes out of it (nil: past it)
local function through(part: any, x: number, z: number): (number?, number?)
	local dx, dz = x - part.X, z - part.Z
	local low, high = -math.huge, math.huge
	local R, H = part.R, part.H
	for k = 1, 3 do
		local a = R[k] * dx + R[6 + k] * dz
		local b = R[3 + k]
		if math.abs(b) < 1e-6 then
			if math.abs(a) > H[k] then
				return nil, nil
			end
		else
			local t1, t2 = (-H[k] - a) / b, (H[k] - a) / b
			low = math.max(low, math.min(t1, t2))
			high = math.min(high, math.max(t1, t2))
		end
	end
	if high < low then
		return nil, nil
	end
	return part.Y + low, part.Y + high
end

local function fakeWorkspace(census: any, kill: number)
	local space = { FallenPartsDestroyHeight = kill, Attributes = {} :: { [string]: any } }
	local function cell(x: number, z: number): { any }
		return census.Cells[(x // CELL) * 100000 + z // CELL] or {}
	end
	function space.Raycast(_, from: any, way: any, _params: any)
		assert(math.abs(way.X) < 1e-6 and math.abs(way.Z) < 1e-6 and way.Y < 0, "only straight down here")
		local best, bestPart = -math.huge, nil
		for _, part in cell(from.X, from.Z) do
			local low, high = through(part, from.X, from.Z)
			if low and high and high <= from.Y and high > best and high >= from.Y + way.Y then
				best, bestPart = high, part
			end
		end
		return if bestPart then { Instance = bestPart, Position = Vector3.new(from.X, best, from.Z) } else nil
	end
	function space.GetPartBoundsInRadius(_, at: any, radius: number, params: any)
		local found = {}
		for _, part in cell(at.X, at.Z) do
			if not (params and params.NoProps and part.Folder == "Props") then
				local dx, dy, dz = at.X - part.X, at.Y - part.Y, at.Z - part.Z
				local R, H, d = part.R, part.H, 0
				for k = 1, 3 do
					local a = math.abs(R[k] * dx + R[3 + k] * dy + R[6 + k] * dz)
					d += math.max(a - H[k], 0) ^ 2
				end
				if d <= radius * radius then
					table.insert(found, part)
				end
			end
		end
		return found
	end
	function space.FindFirstChild(_, name: string, deep: boolean?)
		return if deep and (name == "Seabed" or name == "Props") then { Name = name } else nil
	end
	function space.GetAttribute(_, name: string)
		return space.Attributes[name]
	end
	function space.SetAttribute(_, name: string, value: any)
		space.Attributes[name] = value
	end
	return space
end

-- Numbers that come out the same each run
function World.random(seed: number)
	local state = seed
	local function roll(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local r = { Rolls = 0 }
	function r.NextNumber(_, a: number?, b: number?): number
		r.Rolls += 1
		local u = roll()
		return if a and b then a + (b - a) * u else u
	end
	function r.NextInteger(_, a: number, b: number): number
		return a + math.floor(roll() * (b - a + 1))
	end
	function r.NextUnitVector(_)
		return Vector3.new(roll() - 0.5, roll() - 0.5, roll() - 0.5).Unit
	end
	return r
end

local function fakeFolder()
	local f = { Attributes = {}, Name = "" }
	function f.SetAttribute(_, name: string, value: any)
		f.Attributes[name] = value
	end
	function f.GetAttribute(_, name: string)
		return f.Attributes[name]
	end
	return f
end

-- Opens a place built by Rojo with the stand-ins in it. `set`(Config) is called before the game's services start.
function World.open(placePath: string, census: any, kill: number, set: (any) -> ())
	local w = Harness.open(placePath)
	local self: any = { Harness = w, Now = 1000, Players = {}, Fish = {}, Made = {}, Gone = {}, Beat = nil, Log = {} }
	self.Workspace = fakeWorkspace(census, kill)
	self.Random = World.random(12345)
	local count = 0

	-- a fish: its number, its parts as the server writes to them, and where it is
	local function fish(kind: any)
		count += 1
		local model: any = fakeFolder()
		local root: any = {
			Position = Vector3.zero,
			CFrame = CFrame.new(),
			AssemblyLinearVelocity = Vector3.zero,
			AssemblyAngularVelocity = Vector3.zero,
		}
		local parts = { Swim = { VectorVelocity = Vector3.zero }, Turn = {}, Saddle = { IsA = function()
			return false
		end } }
		function root.FindFirstChild(_, name: string)
			return parts[name]
		end
		function root.IsA()
			return true
		end
		function root.SetNetworkOwner() end
		root.Swim = parts.Swim
		model.PrimaryPart = root
		model.Id = count
		model.Kind = kind.Id
		model.Cleanup = {}
		function model.IsA(_, name: string)
			return name == "Model"
		end
		function model.GetScale()
			return 1
		end
		function model.ScaleTo() end
		function model.GetPivot()
			return root.CFrame
		end
		function model.PivotTo(_, cf: any)
			root.CFrame, root.Position = cf, cf.Position
		end
		model.Destroying = {
			Connect = function(_, f: any)
				table.insert(model.Cleanup, f)
			end,
		}
		function model.Destroy()
			model.Parent = nil
			self.Fish[model.Id] = nil
			table.insert(self.Gone, { At = self.Now, Position = root.Position, Id = model.Id })
			for _, f in model.Cleanup do
				f()
			end
		end
		self.Fish[model.Id] = model
		table.insert(self.Made, { At = self.Now, Model = model, Id = model.Id })
		return model
	end

	w.globals.workspace = self.Workspace
	w.globals.Random = {
		new = function()
			return self.Random
		end,
	}
	w.globals.os = {
		clock = function()
			return self.Now
		end,
		time = os.time,
	}
	w.globals.RaycastParams = {
		new = function()
			return {}
		end,
	}
	w.globals.OverlapParams = {
		new = function()
			return { NoProps = true }
		end,
	}
	w.globals.Instance = { new = fakeFolder }
	w.globals.print = function(...: any)
		table.insert(self.Log, table.concat({ ... }, " "))
	end
	w.globals.task = {
		wait = function(t: number?)
			coroutine.yield(t or 0)
		end,
		delay = function() end,
		spawn = function(f: any)
			f()
		end,
	}
	-- (in the order the fish were made, so that two runs of the same game are the same: a table of models has none)
	w.globals.inOrder = function(wild: any)
		local list = {}
		for model, one in wild do
			table.insert(list, { model, one })
		end
		table.sort(list, function(a, b)
			return a[1].Id < b[1].Id
		end)
		local i = 0
		return function()
			i += 1
			if list[i] then
				return list[i][1], list[i][2]
			end
			return nil
		end
	end
	w.services.Players = {
		GetPlayers = function()
			return self.Players
		end,
		PlayerRemoving = { Connect = function() end },
	}
	w.services.RunService = {
		IsStudio = function()
			return false
		end,
		Heartbeat = {
			Connect = function(_, f: any)
				self.Beat = f
			end,
		},
	}
	w.services.HttpService = {
		JSONDecode = function(_, s: string)
			return serde.decode("json", s)
		end,
		JSONEncode = function(_, t: any)
			return serde.encode("json", t)
		end,
	}
	w.services.ServerStorage = { Name = "ServerStorage" }
	w.services.Workspace = self.Workspace
	self.NetFolder = fakeFolder()
	w.stubs["ReplicatedStorage.Shared.Net"] = { Folder = self.NetFolder }
	w.stubs["ReplicatedStorage.Shared.Variants"] = { apply = function() end }
	w.stubs["ServerScriptService.Server.Lib.FishModel"] = { build = fish }
	self.PropHits = {}
	w.stubs["ServerScriptService.Server.Services.PropService"] = {
		hit = function(at: any)
			table.insert(self.PropHits, at)
			return 0, {}
		end,
	}
	local service = w.find("ServerScriptService.Server.Services.FishService")
	service.Source = string.gsub(service.Source, "for _, w in wild do", "for _, w in inOrder(wild) do")
	self.Config = w.require(w.find("ReplicatedStorage.Shared.Config"))
	set(self.Config)
	local zones = w.require(w.find("ReplicatedStorage.Shared.Zones"))
	zones.discover = zones.fallback
	zones.pathJson = function()
		return census.Dive.Path
	end
	zones.bigAssets = function()
		return serde.decode("json", census.Dive.BigAssets)
	end
	self.Zones = zones
	self.Lane = w.require(w.find("ReplicatedStorage.Shared.Lane"))
	self.Stream = w.require(w.find("ServerScriptService.Server.Lib.Stream"))
	local builtStream = self.Stream.build
	self.Stream.build = function(...)
		self.S = builtStream(...)
		return self.S
	end
	local builtLane = self.Lane.build
	self.Lane.build = function(...)
		self.L = builtLane(...)
		return self.L
	end
	self.Service = w.require(service)
	self.Service.Init()

	local thread = coroutine.create(self.Service.Start)
	local dueAt = 0
	function self.run()
		local ok, wait = coroutine.resume(thread)
		assert(ok, wait)
		dueAt = self.Now + (wait :: number)
	end
	-- one frame: the herd's own code, then every fish in the water goes as the server told it
	function self.frame(dt: number)
		self.Now += dt
		self.Beat(dt)
		for _, model in self.Fish do
			local root = model.PrimaryPart
			if model.Parent and model.Parent.Name == "Fish" then
				local v = root.Swim.VectorVelocity
				root.AssemblyLinearVelocity = v
				root.Position += v * dt
				root.CFrame = CFrame.lookAt(root.Position, root.Position + (if v.Magnitude > 0.1 then v else Vector3.zAxis))
			end
		end
		if self.Now >= dueAt then
			self.run()
		end
	end
	function self.player(at: any)
		local root = {
			Position = at,
			IsA = function()
				return true
			end,
		}
		local character = {
			FindFirstChild = function()
				return root
			end,
		}
		local player = { Character = character, Root = root, UserId = #self.Players + 1 }
		table.insert(self.Players, player)
		return player
	end
	return self
end

World.ok = Harness.tally
World.loader = luau
return World
