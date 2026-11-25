-- A stand-in game server for fusing's check (tools/fuse/fuse_test.luau, NULLROOM task u1). The modules under test are
-- the game's own, from a place built by Rojo: RideService, AquariumService, FuseService, IndexService, SaveParts' tank
-- part, Shared/Fuse and Config. Stand-ins: Roblox's instances (tools/index/gui.luau), the players, the remotes, the
-- herd, the props and the fish models.
-- usage: local World = require("./world"); local w = World.new(placePath); local p = w.join("Ann")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Gui = require("../index/gui")
local Harness = require("../index/harness")

local Vector3 = (roblox :: any).Vector3
local CFrame = (roblox :: any).CFrame

local World = {}

function World.new(placePath: string)
	local world = Harness.open(placePath)
	local w: any = { world = world, clock = 100, sent = {}, players = {}, faults = {} }

	world.globals.os = setmetatable({
		clock = function()
			return w.clock
		end,
	}, { __index = os })
	world.globals.print = function() end
	-- (nothing waits: a loop's first wait parks its thread for good)
	world.globals.task = {
		wait = function()
			return coroutine.yield()
		end,
		spawn = function(f: any, ...: any)
			local thread = coroutine.create(f)
			local ok, err = coroutine.resume(thread, ...)
			if not ok then
				table.insert(w.faults, err)
			end
			return thread
		end,
		delay = function() end,
		defer = function(f: any, ...: any)
			coroutine.wrap(f)(...)
		end,
		cancel = function() end,
	}

	local installed = Gui.install(world)
	local new = installed.make
	world.globals.RaycastParams = {
		new = function()
			return { AddToFilter = function() end }
		end,
	}
	world.globals.OverlapParams = world.globals.RaycastParams
	local space = installed.workspace
	w.space = space
	rawget(space, "_own").GetServerTimeNow = function()
		return w.clock
	end
	function w.part(name: string, parent: any, size: any, at: any)
		local part = new("Part", parent)
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(at)
		rawget(part, "_own").Position = at -- (Lune's parts have none of their own)
		return part
	end
	local function model(name: string, parent: any)
		local m = new("Model", parent)
		m.Name = name
		return m
	end
	local blockout = model("ClaudeBlockout", space)
	local dock = model("Dock", blockout)
	local stations = model("Stations", dock)
	w.stations = stations
	w.machine = model("Fuse", stations)
	w.ring = w.part("Ring", w.machine, Vector3.new(22, 1, 22), Vector3.new(100, 0, 100))

	-- the players
	local joined, leaving = Gui.signal(), Gui.signal()
	world.services.Players = {
		PlayerAdded = joined,
		PlayerRemoving = leaving,
		GetPlayers = function()
			return table.clone(w.players)
		end,
	}
	world.services.RunService = {
		Heartbeat = Gui.signal(),
		Stepped = Gui.signal(),
		IsStudio = function()
			return false
		end,
		IsServer = function()
			return true
		end,
	}
	world.services.CollectionService = {
		AddTag = function() end,
		RemoveTag = function() end,
		HasTag = function()
			return false
		end,
		GetTagged = function()
			return {}
		end,
	}
	world.services.PhysicsService = {
		IsCollisionGroupRegistered = function()
			return true
		end,
		RegisterCollisionGroup = function() end,
		CollisionGroupSetCollidable = function() end,
	}
	world.services.HttpService = {
		JSONEncode = function(_self: any, value: any)
			return serde.encode("json", value)
		end,
		JSONDecode = function(_self: any, text: string)
			return serde.decode("json", text)
		end,
	}
	world.services.Debris = { AddItem = function() end }
	world.services.SoundService = {}

	-- the remotes: what the server tells a client is written down; `w.fail` makes that raise an error
	local action = Gui.signal()
	local index = Gui.signal()
	w.fail = false
	local function remote(name: string, from: any)
		return {
			OnServerEvent = from,
			FireClient = function(_self: any, player: any, ...: any)
				if w.fail then
					error("the remote is broken")
				end
				table.insert(w.sent, { Remote = name, Player = player, ... })
			end,
			FireAllClients = function() end,
		}
	end
	local folder = new("Folder")
	world.stubs["ReplicatedStorage.Shared.Net"] = {
		Folder = folder,
		Action = remote("Action", action),
		Ride = remote("Ride", Gui.signal()),
		Fx = remote("Fx", Gui.signal()),
		Index = remote("Index", index),
	}
	local LIB = "ServerScriptService.Server.Lib."
	local SERVICE = "ServerScriptService.Server.Services."
	w.built = {}
	world.stubs[LIB .. "FishModel"] = {
		Tag = "Fish",
		-- (a plain table in place of a model: enough for the tank's show and the fish over the head)
		build = function(kind: any)
			if w.noModels then
				error("the model could not be built")
			end
			local m: any = { Name = kind.Id, Parent = nil, Attributes = {}, Children = {} }
			local root = new("Part")
			root.CFrame = CFrame.new()
			m.PrimaryPart = root
			function m.GetScale()
				return 1
			end
			function m.ScaleTo() end
			function m.PivotTo() end
			function m.GetDescendants()
				return {}
			end
			function m.GetExtentsSize()
				return Vector3.new(4, 4, 4)
			end
			function m.GetBoundingBox()
				return CFrame.new(), Vector3.new(4, 4, 4)
			end
			function m.SetAttribute(_self: any, key: string, value: any)
				m.Attributes[key] = value
			end
			function m.GetAttribute(_self: any, key: string)
				return m.Attributes[key]
			end
			function m.Destroy()
				m.Parent = nil
				m.Gone = true
			end
			table.insert(w.built, m)
			return m
		end,
	}
	world.stubs["ReplicatedStorage.Shared.Variants"] = { apply = function() end }
	local quiet = setmetatable({}, {
		__index = function()
			return function() end
		end,
	})
	world.stubs[SERVICE .. "FishService"] = quiet
	world.stubs[SERVICE .. "PropService"] = quiet

	-- (a plot's signs, its tank's height and its fish in the water are drawn by AquariumService in full Roblox: here the
	-- map has plots only where a test asks, and what is drawn is not looked at)
	function w.plot(n: number)
		local plots = dock:FindFirstChild("Plots") or model("Plots", dock)
		local plot = model("Plot" .. n, plots)
		w.part("TankWater", plot, Vector3.new(40, 20, 20), Vector3.new(200 + 100 * n, 10, 0))
		w.part("Pad", plot, Vector3.new(60, 1, 60), Vector3.new(200 + 100 * n, 0, 20))
		rawget(plot, "_own").GetPivot = function()
			return CFrame.new(200 + 100 * n, 0, 0)
		end
		return plot
	end

	function w.require(path: string)
		return world.require(world.find(path))
	end
	function w.service(name: string)
		return w.require(SERVICE .. name)
	end
	function w.ask(player: any, ...: any)
		action:Fire(player, ...)
	end
	function w.last(player: any, remoteName: string?): any
		for i = #w.sent, 1, -1 do
			local row = w.sent[i]
			if row.Player == player and row.Remote == (remoteName or "Ride") and row[1] ~= "Caught" then
				return row
			end
		end
		return nil
	end
	function w.stand(player: any, at: any)
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		root.CFrame = CFrame.new(at)
		rawget(root, "_own").Position = at
	end
	function w.join(name: string)
		local player = new("Player")
		player.Name = name
		rawget(player, "_own").UserId = #w.players + 1
		rawget(player, "_own").CharacterAdded = Gui.signal()
		rawget(player, "_own").CharacterRemoving = Gui.signal()
		rawget(player, "_own").Character = nil
		local character = model(name, space)
		w.part("HumanoidRootPart", character, Vector3.new(2, 2, 1), Vector3.new(102, 3, 101))
		w.part("Head", character, Vector3.new(1, 1, 1), Vector3.new(102, 5, 101))
		local humanoid = new("Humanoid", character)
		humanoid.Health = 100
		rawget(humanoid, "_own").Sit = false
		table.insert(w.players, player)
		joined:Fire(player)
		rawget(player, "_own").Character = character
		return player
	end
	function w.leave(player: any)
		table.remove(w.players, table.find(w.players, player) :: number)
		leaving:Fire(player)
	end
	return w
end

return World
