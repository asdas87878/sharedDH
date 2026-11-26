-- Run from the repo root: lune run tools/badges/award_test.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local now = 0
local pending = {}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			callbacks[callback] = true
			return {
				Disconnect = function()
					callbacks[callback] = nil
				end,
			}
		end,
		Fire = function()
			for callback in callbacks do
				callback()
			end
		end,
	}
end

local root = {
	Position = Vector3.zero,
	IsA = function(_, class)
		return class == "BasePart"
	end,
}
local player = {
	UserId = 123,
	Character = {
		FindFirstChild = function()
			return root
		end,
	},
	Attributes = {},
	Changed = signal(),
}
function player:GetAttribute(name)
	return self.Attributes[name]
end
function player:GetAttributeChangedSignal(name)
	assert(name == "TrainerLevel")
	return self.Changed
end

local players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return { player }
	end,
}
local owned, attempts = {}, {}
local available = true
local api = {
	UserHasBadgeAsync = function(_, _, id)
		attempts[id] = (attempts[id] or 0) + 1
		assert(available, "mock Roblox outage")
		return owned[id] == true
	end,
	AwardBadgeAsync = function(_, _, id)
		assert(available and not owned[id], "award attempted without a valid ownership check")
		owned[id] = true
		return true
	end,
}
local gameServices = {
	Players = players,
	BadgeService = api,
	HttpService = {
		JSONEncode = function(_, data)
			return serde.encode("json", data)
		end,
		JSONDecode = function(_, data)
			return serde.decode("json", data)
		end,
	},
}

local function module(path, parent)
	return luau.load(fs.readFile("src/" .. path .. ".luau"), {
		debugName = path,
		environment = {
			CFrame = CFrame,
			Vector3 = Vector3,
			Color3 = roblox.Color3,
			game = {
				GetService = function(_, name)
					return assert(gameServices[name], name)
				end,
			},
			script = { Parent = parent },
			require = function(value)
				return assert(value)
			end,
			workspace = {
				GetServerTimeNow = function()
					return now
				end,
			},
			task = {
				defer = function(fn)
					table.insert(pending, { Thread = coroutine.create(fn), At = now })
				end,
				wait = coroutine.yield,
			},
		},
	})()
end

local shared = { Creatures = {
	ids = function()
		return {}
	end,
} }
for _, name in { "Config", "Badges", "Ease", "Zones", "SubAir", "SubTrip" } do
	shared[name] = module("shared/" .. name, shared)
end
gameServices.ReplicatedStorage = { Shared = shared }
local config, badges, subTrip = shared.Config, shared.Badges, shared.SubTrip
local nextId = 0
for _, badge in badges do
	nextId += 1
	badge.Id = nextId
end

local zones = {}
for index, name in
	{ "SHALLOWS", "REEF", "FOREST", "WRECKS", "OPEN", "TWILIGHT", "MIDNIGHT", "VENTS", "BONES", "THE UNDERWORLD" }
do
	zones[index] =
		{ Index = index, Name = name, Frame = CFrame.new(0, -100, (index - 1) * 600), Width = 100, Length = 540 }
end
local state = "Dock"
local ride = {
	stateOf = function()
		return state
	end,
}
local fish = {
	zones = function()
		return zones
	end,
	inside = function(position)
		return 50 - math.abs(position.X)
	end,
}
local aquarium = {
	fuse = function(_, picks)
		return if #picks == 3 then { To = "Big" } else nil
	end,
}
local service =
	module("server/Services/BadgeService", { RideService = ride, AquariumService = aquarium, FishService = fish })
config.Badges.On = 0
service.Start()
assert(ride.OnTamed == nil and next(pending) == nil, "off switch installed award hooks")
config.Badges.On = 1
local serviceThread = coroutine.create(service.Start)

local function resume(thread)
	local ok, result = coroutine.resume(thread)
	assert(ok, result)
	return result
end

local function drain()
	local work = pending
	pending = {}
	for _, request in work do
		if request.At <= now then
			local wait = resume(request.Thread)
			if coroutine.status(request.Thread) ~= "dead" then
				request.At = now + wait
				table.insert(pending, request)
			end
		else
			table.insert(pending, request)
		end
	end
end

local function sample(newState, x, z, elapsed)
	state = newState
	root.Position = Vector3.new(x, -65, z)
	now += elapsed or config.Badges.ZoneEvery
	assert(resume(serviceThread) == config.Badges.ZoneEvery)
	drain()
end

local twilight, midnight, underworld = badges.Twilight.Id, badges.Midnight.Id, badges.Underworld.Id
sample("Dock", 0, 0)
sample("Riding", 0, 0)
for _ = 1, 4 do
	sample("Riding", 0, 3000)
end
assert(not attempts[twilight], "teleport or waiting at its destination counted")

for z = 100, 2700, 100 do
	sample("Riding", 0, z)
end
sample("Riding", 0, 2715)
sample("Riding", 0, 2720)
assert(not attempts[twilight], "gap was treated as the zone itself")
sample("Riding", 600, 2800)
assert(not attempts[twilight], "position six widths outside the lane counted")
sample("Riding", 0, 2800)
assert(owned[twilight], "ordinary entry through the lane was missed")
sample("Riding", 0, 2820)
assert(attempts[twilight] == 1, "repeat samples retried a confirmed award")

local function beginSub(land, withFish, dropZ)
	sample("Dock", 0, 0)
	local points = { root.Position }
	for z = 60, dropZ - 1, 60 do
		table.insert(points, Vector3.new(0, -65, z))
	end
	table.insert(points, Vector3.new(0, -65, dropZ))
	table.insert(points, Vector3.new(0, -65, dropZ + 60))
	local trip = subTrip.new(now, land, withFish, points, dropZ)
	local _, _, _, dropAt = subTrip.times(trip)
	player.Attributes.SubTrip = subTrip.encode(trip)
	sample("Carried", 0, 3000, dropAt / 2)
	return trip.Start + dropAt
end

local dropAt = beginSub(7, false, 3440)
sample("Carried", 0, 3440, dropAt - now - config.Badges.ZoneEvery * 2)
assert(not attempts[midnight], "riding inside the sub counted as arrival")
sample("Jumping", 0, 3440)
assert(not attempts[midnight], "departure before the planned arrival counted")
sample("Jumping", 0, 3870)
assert(not attempts[midnight], "position too far from the planned drop counted")
sample("Jumping", 600, 3440)
sample("Jumping", 0, 3300)
assert(not attempts[midnight], "off-lane or gap position counted as a submarine drop")
sample("Jumping", 0, 3460)
assert(owned[midnight], "submarine fling did not award the destination")

dropAt = beginSub(10, true, 5330)
sample("Carried", 0, 3600, dropAt - now)
sample("Riding", 0, 5000)
assert(not attempts[underworld], "wrong land counted as a submarine drop")
sample("Riding", 0, 5360)
assert(owned[underworld], "submarine fish landing did not award the destination")

local catch = badges.FirstCatch.Id
available = false
ride.OnTamed(player, {})
ride.OnTamed(player, {})
drain()
assert(attempts[catch] == 1 and #pending == 1, "overlapping tame events started separate workers")
for _ = 1, 2 do
	now += 5
	drain()
end
assert(attempts[catch] == 3 and not owned[catch], "expected three failed ownership checks")
available = true
now += config.Badges.RetryCooldown - 1
ride.OnTamed(player, {})
drain()
assert(attempts[catch] == 3, "another tame bypassed the cooldown")
now += 1
drain()
assert(attempts[catch] == 4 and owned[catch], "earned badge did not retry after cooldown")
ride.OnTamed(player, {})
drain()
assert(attempts[catch] == 4, "confirmed award was checked again")

print("Badge checks passed: lane width, dive continuity, submarine arrivals, and award recovery.")
