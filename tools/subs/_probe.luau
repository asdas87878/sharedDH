local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../index/harness")
local V3, CF = roblox.Vector3, roblox.CFrame
local world = Harness.open(process.args[1])
local SubAir = world.require(world.find("ReplicatedStorage.Shared.SubAir"))
local SubTrip = world.require(world.find("ReplicatedStorage.Shared.SubTrip"))
local rows = serde.decode("json", fs.readFile(process.args[2]))
local only = tonumber(process.args[3]) or 1
local lip = CF.lookAt(V3.new(0, 0.5, 0), V3.new(0, 0.5, 10))
local stat = {}
local function add(k, v) stat[k] = stat[k] or {}; table.insert(stat[k], v) end
local fails, n, overs = 0, 0, 0
local worst = 0
for i, r in rows do
	if (i % only) ~= 0 then continue end
	local leap = { Take = V3.new(r.take[1], r.take[2], r.take[3]), Heading = V3.new(r.heading[1], 0, r.heading[2]), Far = r.far, Rise = r.a, Fall = r.c, Crouch = r.crouch, Time = r.air, Tilts = r.tilts }
	local half = V3.new(r.size[1], r.size[2], r.size[3]) / 2
	local seat = V3.new(r.seat[1], r.seat[2], r.seat[3])
	for tier = 1, 9 do
		if tonumber(process.args[4]) and tier ~= tonumber(process.args[4]) then continue end
		n += 1
		local c0 = os.clock()
		local air = SubAir.plan(leap, half, seat, SubTrip.Hulls[tier], lip)
		local dt = os.clock() - c0
		worst = math.max(worst, dt)
		if not air then
			fails += 1
			if fails < 30 then print("NONE", r.id, r.tier, r.x, r.slant, tier, half) end
		else
			local k = r.tier
			add(k .. " hopAt", air.HopAt) ; add(k .. " lipToSplash", air.SplashAt - r.crouch); add(k .. " rideAt", air.RideAt)
			add(k .. " rise", (air.Meet.Y + 7.4) - SubAir.saddle(leap, air.HopAt).Y); add(k .. " slope", math.deg(air.Slope)); add(k .. " fall", air.Fall)
			add(k.." meetY", air.Meet.Y)
			add(k.." seat2splash", air.SplashAt-air.SeatAt)
			if air.Over then overs += 1 end
		end
	end
end
print(n, "plans", fails, "failed", overs, "over the arch; slowest", worst)
local keys = {}
for k in stat do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do
	local v = stat[k]; table.sort(v)
	local function q(p) return string.format("%7.2f", v[math.clamp(math.floor(#v * p) + 1, 1, #v)]) end
	print(string.format("%-24s", k), q(0), q(0.25), q(0.5), q(0.75), q(0.9), q(1))
end
