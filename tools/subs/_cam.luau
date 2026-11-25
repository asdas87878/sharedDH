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
local lip = CF.lookAt(V3.new(0, 0.5, 0), V3.new(0, 0.5, 10))
local stat = {}
local function add(k, v) stat[k] = stat[k] or {}; table.insert(stat[k], v) end
for i, r in rows do
	if i % 7 ~= 0 then continue end
	local leap = { Take = V3.new(r.take[1], r.take[2], r.take[3]), Heading = V3.new(r.heading[1], 0, r.heading[2]), Far = r.far, Rise = r.a, Fall = r.c, Crouch = r.crouch, Time = r.air, Tilts = r.tilts }
	local half = V3.new(r.size[1], r.size[2], r.size[3]) / 2
	local seat = V3.new(r.seat[1], r.seat[2], r.seat[3])
	add(r.tier.." tail", half.Z - seat.Z); add(r.tier.." startY", r.start[2]); add(r.tier.." saddle", seat.Y); add(r.tier.." halfY", half.Y)
	add(r.tier.." camback", r.cam[3]-r.start[3]); add(r.tier.." camY", r.cam[2])
	for _, tier in {1,5,9} do
		local air = SubAir.plan(leap, half, seat, SubTrip.Hulls[tier], lip)
		if air then
			local k = r.tier
			local g, sb, f, h = SubAir.seen(air, SubTrip.Hulls[tier], lip, SubAir.samples(air, 0.01), 0.01)
			add(k.." eye gate", g) add(k.." eye sub", sb) add(k.." eye fish", f) add(k.." eye hidden", h)
			add(k.." eye back", air.Eye.Back) add(k.." eye pass-seat", air.Eye.Pass - air.SeatAt)
			add("gate mode "..air.Eye.Gate, 1)
			-- smoothness
			local pe
			for t = 0, air.RideAt, 1/60 do
				local e = SubAir.eye(air, t)
				if pe then add(k.." eye speed", (e-pe).Magnitude*60) add(k.." eye down speed", (pe.Y-e.Y)*60) add(k.." eye up speed", (e.Y-pe.Y)*60) end
				pe = e
			end
			local e = SubAir.eye(air, air.RideAt)
			add(k.." end behind", SubAir.middle(air, air.RideAt).Z - e.Z) add(k.." end y", e.Y)
			-- size of the rider on screen at the hop: 5 studs at distance
			local eh = SubAir.eye(air, air.HopAt)
			add(k.." hop dist", (eh - SubAir.rider(air, air.HopAt).Position).Magnitude)
			-- angle down/up at seat
			local es = SubAir.eye(air, air.SeatAt)
			local d = SubAir.rider(air, air.SeatAt).Position - es
			add(k.." seat look up deg", math.deg(math.atan2(d.Y, d.Z)))
		end
	end
end
local keys = {}
for k in stat do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do
	local v = stat[k]; table.sort(v)
	local function q(p) return string.format("%7.2f", v[math.clamp(math.floor(#v * p) + 1, 1, #v)]) end
	print(string.format("%-40s", k), q(0), q(0.25), q(0.5), q(0.75), q(0.9), q(1))
end
