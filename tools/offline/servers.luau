-- Stand-in game servers for the offline rewards' check (tools/offline/offline_test.luau; NULLROOM task o1). Each server
-- loads the game's own SaveService, SaveParts, ProfileStore (the real one, session lock and all), OfflineService and
-- Config from a place built by Rojo (tools/index/harness.luau), and they share one fake Roblox: one DataStore, one
-- MessagingService and one clock moved by hand, so a save, a lost session, a crash and a second server run for real.
-- Stand-ins, not under test: the tank (AquariumService: dump, restore, give, tankOf, with the game's own Config.incomeOf),
-- RideService, TrainService, SubService, AuraService, the remotes and the players.
-- usage: local Servers = require("./servers"); local roblox = Servers.new(placePath); local a = roblox.server({})
local Harness = require("../index/harness")

local Servers = {}

local TICK = 0.05

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

local function signal(faults: { string }?)
	local handlers = {}
	return {
		Connect = function(_self: any, handler: any)
			table.insert(handlers, handler)
			return {
				Disconnect = function()
					local at = table.find(handlers, handler)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		-- (each handler in a thread of its own, as Roblox does: it may wait)
		fire = function(...: any)
			for _, handler in table.clone(handlers) do
				local ok, problem = coroutine.resume(coroutine.create(handler), ...)
				if not ok and faults then
					table.insert(faults, problem)
				end
			end
		end,
		handlers = handlers,
	}
end

function Servers.new(placePath: string)
	local roblox = {
		clock = 1000, -- os.clock(), the same on every server
		epoch = 1_800_000_000, -- and os.time() at clock 0
		data = {} :: { [string]: any }, -- the DataStore
		down = false, -- the DataStore refuses
		deaf = false, -- MessagingService loses every message
		faults = {} :: { string }, -- errors in any thread
		servers = {} :: { any },
		saves = 0,
	}
	local topics: { [string]: { any } } = {}
	local waiting: { { At: number, Thread: thread, Server: any, Args: { any } } } = {}

	local function run(server: any, thread: thread, ...: any)
		local ok, problem = coroutine.resume(thread, ...)
		if not ok then
			table.insert(roblox.faults, `{server.Name}: {problem}\n{debug.traceback(thread)}`)
		end
	end

	-- Time goes by: every thread due runs, every live server's Heartbeat beats
	function roblox.pass(seconds: number)
		local to = roblox.clock + seconds
		while roblox.clock < to - 1e-9 do
			roblox.clock = math.min(roblox.clock + TICK, to)
			local due = {}
			for i = #waiting, 1, -1 do
				if waiting[i].At <= roblox.clock + 1e-9 then
					table.insert(due, 1, table.remove(waiting, i))
				end
			end
			for _, w in due do
				if not w.Server.Dead then
					run(w.Server, w.Thread, table.unpack(w.Args))
				end
			end
			for _, server in roblox.servers do
				if not server.Dead then
					server.Heartbeat.fire(TICK)
				end
			end
		end
	end

	-- Nobody is playing anywhere: the clock jumps (only while no server runs, or it would have waited through it)
	function roblox.skip(seconds: number)
		for _, server in roblox.servers do
			assert(server.Dead, "a server is still running")
		end
		roblox.clock += seconds
	end

	local count = 0

	-- A server. opts: Skew (its os.time() is this many seconds off), NoStudio (a live game: SaveParts' own switch), SaveOn
	-- (default true), AquariumFirst (the tank lets a leaving player go before SaveService's last snapshot, default true)
	function roblox.server(opts: any)
		count += 1
		local world = Harness.open(placePath)
		local server = {
			Name = "server" .. count,
			Dead = false,
			Heartbeat = signal(roblox.faults),
			world = world,
			players = {} :: { any },
			sent = {} :: { { any } },
			lose = false, -- answers to clients are lost
			tanks = {} :: { [any]: any },
			noTank = {} :: { [string]: boolean }, -- players by name who get no plot
			workspace = {} :: { [string]: any },
		}
		table.insert(roblox.servers, server)
		local function schedule(at: number, thread: thread, ...: any)
			table.insert(waiting, { At = at, Thread = thread, Server = server, Args = { ... } })
		end
		local function threadOf(f: any): thread
			return if type(f) == "thread" then f else coroutine.create(f)
		end
		local taskLib = {
			spawn = function(f: any, ...: any)
				local thread = threadOf(f)
				run(server, thread, ...)
				return thread
			end,
			defer = function(f: any, ...: any)
				schedule(roblox.clock, threadOf(f), ...)
			end,
			delay = function(t: number, f: any, ...: any)
				schedule(roblox.clock + t, threadOf(f), ...)
			end,
			wait = function(t: number?): number
				local from = roblox.clock
				schedule(from + math.max(t or 0, TICK), coroutine.running())
				coroutine.yield()
				return roblox.clock - from
			end,
		}
		server.task = taskLib
		world.globals.task = taskLib
		world.globals.print = function() end
		world.globals.os = setmetatable({
			clock = function()
				return roblox.clock
			end,
			time = function()
				return math.floor(roblox.epoch + roblox.clock + (opts.Skew or 0))
			end,
		}, { __index = os })
		world.globals.Instance = {
			new = function(class: string)
				if class == "DataStoreOptions" then
					return { SetExperimentalFeatures = function() end }
				end
				return { ClassName = class, OnServerEvent = signal(roblox.faults) }
			end,
		}
		world.game.PlaceId = 1
		world.game.JobId = "job" .. count
		world.game.BindToClose = function(_self: any, fn: any)
			server.Close = fn
		end

		local attributes = signal(roblox.faults)
		server.workspace.SaveOn = opts.SaveOn
		server.workspace.SaveReal = true -- (Roblox's own store, which is the fake one here)
		if opts.Workspace then
			for k, v in opts.Workspace do
				server.workspace[k] = v
			end
		end
		local space = {
			GetAttribute = function(_self: any, name: string)
				return server.workspace[name]
			end,
			SetAttribute = function(_self: any, name: string, value: any)
				server.workspace[name] = value
				attributes.fire()
			end,
			GetAttributeChangedSignal = function()
				return attributes
			end,
		}
		function server.set(name: string, value: any)
			server.workspace[name] = value
			attributes.fire()
		end
		world.services.Workspace = space
		world.globals.workspace = space
		world.services.ServerStorage = {}
		world.services.HttpService = {
			GenerateGUID = function()
				count += 1
				return `guid-{count}-{roblox.clock}`
			end,
			JSONEncode = function()
				return ""
			end,
		}
		world.services.RunService = {
			Heartbeat = server.Heartbeat,
			IsStudio = function()
				return not opts.NoStudio
			end,
			IsServer = function()
				return true
			end,
		}
		world.services.DataStoreService = {
			GetDataStore = function(_self: any, store: string)
				local base = store .. "/"
				return {
					SetAsync = function() end,
					UpdateAsync = function(_s: any, key: string, change: any)
						taskLib.wait(0.1)
						if roblox.down then
							error("502: API Services rejected request")
						end
						local value = change(copy(roblox.data[base .. key]))
						if value == nil then
							return nil
						end
						roblox.saves += 1
						roblox.data[base .. key] = copy(value)
						return copy(value), {}
					end,
				}
			end,
		}
		world.services.MessagingService = {
			SubscribeAsync = function(_self: any, topic: string, fn: any)
				topics[topic] = topics[topic] or {}
				local entry = { Server = server, Fn = fn }
				table.insert(topics[topic], entry)
				return {
					Disconnect = function()
						local at = table.find(topics[topic], entry)
						if at then
							table.remove(topics[topic], at)
						end
					end,
				}
			end,
			PublishAsync = function(_self: any, topic: string, message: any)
				if roblox.deaf then
					return
				end
				for _, entry in topics[topic] or {} do
					if not entry.Server.Dead then
						local thread = coroutine.create(entry.Fn)
						run(entry.Server, thread, { Data = copy(message) })
					end
				end
			end,
		}

		-- players
		local added, removing = signal(roblox.faults), signal(roblox.faults)
		local Players = {
			PlayerAdded = added,
			PlayerRemoving = removing,
			GetPlayers = function()
				return table.clone(server.players)
			end,
			GetPlayerByUserId = function(_self: any, id: number)
				for _, player in server.players do
					if player.UserId == id then
						return player
					end
				end
				return nil
			end,
		}
		world.services.Players = Players

		-- the remotes
		local remote = {
			ClassName = "RemoteEvent",
			OnServerEvent = signal(roblox.faults),
			IsA = function()
				return true
			end,
			FireClient = function(_self: any, player: any, ...: any)
				if not server.lose then
					table.insert(server.sent, { player, ... })
				end
			end,
		}
		server.remote = remote
		local purchaseRemote = {
			OnServerEvent = signal(roblox.faults),
			IsA = function()
				return true
			end,
			FireClient = function() end,
		}
		world.stubs["ReplicatedStorage.Shared.Net"] = {
			Index = { OnServerEvent = signal(roblox.faults), FireClient = function() end },
			Folder = {
				FindFirstChild = function(_self: any, name: string)
					return if name == "Offline" then remote elseif name == "Purchase" then purchaseRemote else nil
				end,
			},
		}

		-- the tank, and what the save's other parts ask
		local SERVICES = "ServerScriptService.Server.Services."
		local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
		server.Config = Config
		-- (the checks' own numbers: a change in the file for the tuning is not a failure here)
		for key, value in { Least = 300, Share = 0.5, Most = 28800, AskGap = 0.3, Settle = 0.8, On = 1 } do
			Config.Offline[key] = value
		end
		local tanks = server.tanks
		local function entry(f: any)
			local kind = Config.FishById[f.Id]
			return {
				Id = f.Id,
				Size = f.Size,
				Variant = f.Variant,
				On = f.On,
				Income = Config.incomeOf(kind, f.Size, f.Variant),
			}
		end
		function server.putIn(player: any, id: string, on: boolean, size: string?, variant: string?)
			table.insert(
				tanks[player].Fish,
				entry({ Id = id, Size = size or "Normal", Variant = variant or "", On = on })
			)
		end
		function server.claimPlot(player: any)
			tanks[player] = { Coins = 0, Stage = 0, Fish = {} }
		end
		world.stubs[SERVICES .. "AquariumService"] = {
			tankOf = function(player: any)
				return tanks[player] and tanks[player].Fish
			end,
			give = function(player: any, coins: number): boolean
				local tank = tanks[player]
				if not tank or coins ~= coins or math.abs(coins) == math.huge then
					return false
				end
				tank.Coins += coins
				return true
			end,
			dump = function(player: any)
				local tank = tanks[player]
				if not tank then
					return nil
				end
				local fish = {}
				for _, f in tank.Fish do
					table.insert(fish, { Id = f.Id, Size = f.Size, Variant = f.Variant, On = f.On })
				end
				return { Coins = tank.Coins, Stage = tank.Stage, Fish = fish }
			end,
			restore = function(player: any, kept: any): boolean
				local tank = tanks[player]
				if not tank then
					return false
				end
				tank.Coins += kept.Coins
				for _, f in kept.Fish do
					table.insert(tank.Fish, entry(f))
				end
				return true
			end,
		}
		local slow = opts.RideLate or 0
		local joinedAt: { [any]: number } = {}
		world.stubs[SERVICES .. "RideService"] = {
			stateOf = function(player: any)
				return player:GetAttribute("State")
			end,
			train = function()
				return true
			end,
			trainedOxygen = function(player: any)
				-- (RideService can have a player later than the tank has)
				return if joinedAt[player] and roblox.clock - joinedAt[player] >= slow then 0 else nil
			end,
			setTrainedOxygen = function()
				return true
			end,
			grantOxygen = function()
				return true
			end,
			carried = function()
				return {}
			end,
		}
		world.stubs[SERVICES .. "TrainService"] = {
			levelOf = function()
				return 1
			end,
			setLevel = function()
				return true
			end,
		}
		world.stubs[SERVICES .. "SubService"] = {
			tierOf = function()
				return 0
			end,
			equipOf = function()
				return 0
			end,
			setSub = function()
				return true
			end,
		}
		world.stubs[SERVICES .. "AuraService"] = {
			tierOf = function()
				return 0
			end,
			setTier = function()
				return true
			end,
		}

		-- Run real pack persistence when the test also drives purchases.
		for _, name in { "LessonService", "PackService" } do
			if opts.Purchases and name == "PackService" then
				continue
			end
			world.stubs[SERVICES .. name] = {
				dump = function()
					return {}
				end,
				restore = function()
					return true
				end,
			}
		end
		local IndexService = world.require(world.find(SERVICES .. "IndexService"))
		server.Index = IndexService
		local OfflineService = world.require(world.find(SERVICES .. "OfflineService"))
		local SaveService = world.require(world.find(SERVICES .. "SaveService"))
		server.Offline, server.Save = OfflineService, SaveService
		local purchases
		if opts.Purchases then
			local products = world.require(world.find("ReplicatedStorage.Shared.Products"))
			local starter = products.Sections[1].Offers[1]
			starter.Id, products.Triple.Id = 101, 102
			products.TripleRetiredIds = { 103 }
			server.Products = products
			server.prompts = {}
			server.onSale = true
			local marketplace = {
				PromptGamePassPurchaseFinished = signal(roblox.faults),
				PromptProductPurchaseFinished = signal(roblox.faults),
				GetProductInfoAsync = function()
					return { IsForSale = server.onSale }
				end,
				PromptProductPurchase = function(_self: any, player: any, id: number)
					table.insert(server.prompts, { player, id, roblox.kept(player.Name) })
				end,
			}
			world.services.MarketplaceService = marketplace
			world.globals.Enum = setmetatable({
				InfoType = { Product = "Product" },
				ProductPurchaseDecision = { PurchaseGranted = "Granted", NotProcessedYet = "Pending" },
			}, { __index = require("@lune/roblox").Enum })
			function server.promptOnce(player: any)
				purchaseRemote.OnServerEvent.fire(player, "PromptOnce", starter.Id)
			end
			function server.finishPrompt(player: any, id: number, bought: boolean)
				marketplace.PromptProductPurchaseFinished.fire(player.UserId, id, bought)
			end
			function server.receipt(player: any, id: number, purchaseId: string)
				local result = {}
				taskLib.spawn(function()
					result.Decision = marketplace.ProcessReceipt({
						PlayerId = player.UserId,
						ProductId = id,
						PurchaseId = purchaseId,
					})
				end)
				return result
			end
			purchases = world.require(world.find(SERVICES .. "PurchaseService"))
			purchases.Init()
		end

		local function letGo(player: any)
			tanks[player] = nil
		end
		if opts.AquariumFirst ~= false then
			removing:Connect(letGo)
		end
		OfflineService.Init()
		SaveService.Init()
		taskLib.spawn(OfflineService.Start)
		taskLib.spawn(SaveService.Start)
		taskLib.spawn(IndexService.Start)
		if purchases then
			taskLib.spawn(purchases.Start)
		end
		if opts.AquariumFirst == false then
			removing:Connect(letGo)
		end

		-- a player comes in (the same name is the same account), leaves, or is sent off
		function server.join(name: string)
			local held = {} :: { [string]: any }
			local player = {
				Name = name,
				DisplayName = name,
				UserId = 7000 + #name * 131 + string.byte(name),
				Parent = Players :: any,
				Kicked = nil :: string?,
			}
			function player.GetAttribute(_self: any, key: string)
				return held[key]
			end
			function player.SetAttribute(_self: any, key: string, value: any)
				held[key] = value
			end
			function player.Kick(self: any, why: string)
				self.Kicked = why
				server.leave(self)
			end
			player:SetAttribute("State", "Dock")
			table.insert(server.players, player)
			joinedAt[player] = roblox.clock
			if not server.noTank[name] then
				server.claimPlot(player)
			end
			added.fire(player)
			return player
		end
		function server.leave(player: any)
			local at = table.find(server.players, player)
			if not at then
				return
			end
			table.remove(server.players, at)
			player.Parent = nil
			removing.fire(player)
		end
		function server.ask(player: any, ...: any)
			remote.OnServerEvent.fire(player, ...)
		end
		-- the last answer to that player: its name and what came with it
		function server.answer(player: any): (any, any)
			for i = #server.sent, 1, -1 do
				if server.sent[i][1] == player then
					return server.sent[i][2], server.sent[i][3]
				end
			end
			return nil, nil
		end
		function server.coins(player: any): number
			return tanks[player] and tanks[player].Coins or 0
		end
		-- the server is gone, with nothing saved
		function server.crash()
			server.Dead = true
		end
		-- everyone leaves, it saves, and it is gone
		function server.stop()
			for _, player in table.clone(server.players) do
				server.leave(player)
			end
			roblox.pass(5)
			server.Dead = true
		end
		return server
	end

	-- What the store keeps of a player now
	function roblox.kept(name: string): any
		local id = 7000 + #name * 131 + string.byte(name)
		local row = roblox.data["Players1/" .. id]
		return row and row.Data.Parts
	end
	function roblox.keep(name: string, part: string, value: any)
		local id = 7000 + #name * 131 + string.byte(name)
		roblox.data["Players1/" .. id].Data.Parts[part] = value
	end

	return roblox
end

return Servers
