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
local fr, pl = {}, {}
for i, r in rows do
	if i % 9 ~= 0 then continue end
	local leap = { Take = V3.new(r.take[1], r.take[2], r.take[3]), Heading = V3.new(r.heading[1], 0, r.heading[2]), Far = r.far, Rise = r.a, Fall = r.c, Crouch = r.crouch, Time = r.air, Tilts = r.tilts }
	local half = V3.new(r.size[1], r.size[2], r.size[3]) / 2
	local seat = V3.new(r.seat[1], r.seat[2], r.seat[3])
	for _, tier in {1,9} do
		local c0 = os.clock()
		local air = SubAir.plan(leap, half, seat, SubTrip.Hulls[tier], lip)
		table.insert(pl, os.clock() - c0)
		if air then
			c0 = os.clock()
			SubAir.frame(air, SubTrip.Hulls[tier], lip)
			table.insert(fr, os.clock() - c0)
		end
	end
end
for k, v in { plan = pl, frame = fr } do
	table.sort(v)
	print(k, v[#v // 2], v[#v * 9 // 10], v[#v])
end
