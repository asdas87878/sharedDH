-- tmp: which fish fail makePlan as it is
local process = require("@lune/process")
local World = require("./world")
local roblox = require("@lune/roblox")
local V3, CF = roblox.Vector3, roblox.CFrame
local world = World.open(process.args[1], process.args[2])
local Config, Dive = world.Config, world.Dive
print(#Config.Fish, "kinds")
local fails, total = 0, 0
for _, kind in Config.Fish do
	local row = {}
	for _, tier in Config.SizeOrder do
		local f = World.landFish(world, kind, tier)
		local start = V3.new(0, 0.5 + f.height, -2.5)
		local cam = CF.lookAt(start + V3.new(0, 5, -17), start)
		local p, why, sums = Dive.planOf(start, 0.5, V3.new(0, 0, 1), 32, true, cam, 70, { low = f.low, high = f.high })
		total += 1
		local under = "-"
		if p then
			under = string.format("%.1f", sums.frameAt(p.tEntry + p.sink + 1).Y)
		end
		if not p then fails += 1 end
		table.insert(row, string.format("%s L%.0f W%.0f d%.0f %s %s", tier, f.size.Z, f.size.X, -f.low.Y, if p then (#why == 0 and "ok" or "ok#" .. #why) else "FAIL", if p then "end y " .. under else table.concat(why, " | ")))
	end
	print(kind.Id)
	for _, r in row do print("   " .. r) end
end
print(fails, "of", total, "fail")
