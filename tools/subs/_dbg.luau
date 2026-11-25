local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../index/harness")
local V3, CF = roblox.Vector3, roblox.CFrame
local world = Harness.open("/tmp/ah/place.rbxl")
local SubAir = world.require(world.find("ReplicatedStorage.Shared.SubAir"))
local SubTrip = world.require(world.find("ReplicatedStorage.Shared.SubTrip"))
local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local rows = serde.decode("json", fs.readFile("/tmp/ah/leaps.json"))
local lip = CF.lookAt(V3.new(0, 0.5, 0), V3.new(0, 0.5, 10))
for _, r in rows do
	if r.id == "Octopus" and r.tier == "Huge" and r.x == 0 and r.slant == 0 then
	local leap = { Take = V3.new(r.take[1], r.take[2], r.take[3]), Heading = V3.new(r.heading[1], 0, r.heading[2]), Far = r.far, Rise = r.a, Fall = r.c, Crouch = r.crouch, Time = r.air, Tilts = r.tilts }
	local half = V3.new(r.size[1], r.size[2], r.size[3]) / 2
	local seat = V3.new(r.seat[1], r.seat[2], r.seat[3])
	print(half, seat, r.far, r.a, r.c, r.air, table.concat(r.tilts, " "))
	
	local c = Config.Sub
	for _, slopes in { { 0 }, { 20 }, { 32 }, {44} } do for _, gate in {true, false} do
	local keep, keepB, keepC = c.AirSlopes, c.AirBeam, c.AirCrest
	c.AirSlopes = slopes
	if not gate then c.AirBeam, c.AirCrest = {1, 900,901,-21,-7},{1, 900,901,-21,-7} end
	for _, fm in {330, 3000} do c.AirFallMost = fm
	local a = SubAir.plan(leap, half, seat, SubTrip.Hulls[6], lip)
	print(slopes[1], gate, fm, a and a.Meet, a and a.Fall, a and a.SplashAt) end
	c.AirSlopes, c.AirBeam, c.AirCrest = keep, keepB, keepC
	end end

	local air = SubAir.plan(leap, half, seat, SubTrip.Hulls[6], lip)
	print(air and air.Meet, air and air.Fall, air and air.SplashAt, air and math.deg(air.Slope), air and air.SeatAt)
	if air then
	for t = air.SeatAt, air.RideAt, 0.04 do local s = SubAir.sub(air, t); local f = SubAir.fish(air, math.min(t, r.crouch+r.air)); print(string.format("%.2f sub z %.0f y %.0f pitch %.0f | fish z %.0f y %.0f", t, s.Z, s.Y, math.deg(math.asin(s.LookVector.Y)), f.Z, f.Y)) end
	end
	end
end
