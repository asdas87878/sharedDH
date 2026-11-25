-- Holds every saddle Shared/Saddles builds against tools/saddles/saddles.py's, part by part (NULLROOM task s2).
--   python tools/saddles/to_luau.py parts F; rojo build -o P; lune run tools/saddles/saddle_parity.luau P F
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Harness = require("../index/harness")

local world = Harness.open(process.args[1])
local Saddles = world.require(world.find("ReplicatedStorage.Shared.Saddles"))

local saddles, parts, wrong, worst = 0, 0, 0, 0
for line in string.gmatch(fs.readFile(process.args[2]), "[^\n]+") do
	local kind, size, key, want = table.unpack(serde.decode("json", line))
	local got = if kind == "plain" then Saddles.alone(key) else Saddles.build(kind, size, key)
	saddles += 1
	local why: string? = nil
	if not got or #got ~= #want then
		why = `{if got then #got else "no"} parts, not {#want}`
	else
		for i, w in want do
			local g = got[i]
			parts += 1
			local x, y, z, a, b, c, d, e, f, h, j, k = g.At:GetComponents()
			local have = { g.Size.X, g.Size.Y, g.Size.Z, x, y, z, a, b, c, d, e, f, h, j, k }
			local off = 0
			for n = 1, 15 do
				off = math.max(off, math.abs(have[n] - w[6 + n]))
			end
			worst = math.max(worst, off)
			local colour = { math.round(g.Colour.R * 255), math.round(g.Colour.G * 255), math.round(g.Colour.B * 255) }
			if g.What ~= w[1] or g.Shape ~= w[2] or g.Neon ~= (w[3] == 1) then
				why = `part {i} is {g.What} {g.Shape}, not {w[1]} {w[2]}`
			elseif colour[1] ~= w[4] or colour[2] ~= w[5] or colour[3] ~= w[6] then
				why = `part {i}'s colour`
			elseif off > 0.001 then
				why = `part {i} ({g.What}) is {off} off`
			end
			if why then
				break
			end
		end
	end
	if why then
		wrong += 1
		if wrong <= 10 then
			print("  FAIL  " .. kind .. " " .. size .. " " .. key .. ": " .. why)
		end
	end
end
print(`{saddles} saddles, {parts} parts, {wrong} wrong; the furthest number is {string.format("%.5f", worst)} off`)
if wrong > 0 or saddles ~= 83 * 6 * 20 + 20 then
	process.exit(1)
end
