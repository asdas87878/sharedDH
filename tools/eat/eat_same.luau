-- With Config.Fail.NewEat at 0 nothing changes: every outcome of every creature with a mesh, played frame by frame by this
-- branch's FailController and by main's, and every joint, the fish, the body and the view compared. The other place is
-- THIS branch's source with only main's FailController in it (main has no Lib/EatMoves and other Config, so a place built
-- from main itself does not run here):
--   mkdir -p work/eat && python3 tools/eat/boxes.py all > work/eat/boxes_all.json
--   rojo build default.project.json -o work/eat/place.rbxl
--   rm -rf /tmp/eq && mkdir /tmp/eq && cp -r src default.project.json rokit.toml /tmp/eq
--   git show main:src/client/Controllers/FailController.luau > /tmp/eq/src/client/Controllers/FailController.luau
--   (cd /tmp/eq && rojo build default.project.json -o place_main.rbxl) && cp /tmp/eq/place_main.rbxl work/eat/
--   lune run tools/eat/eat_same.luau work/eat/place.rbxl work/eat/place_main.rbxl
local process = require("@lune/process")

local World = require("./eat_world")
local BOXES = "work/eat/boxes_all.json"
local a, b = World.open(process.args[1], BOXES), World.open(process.args[2], BOXES)
local worst, count, frames, bad = 0, 0, 0, 0

local function far(x: any, y: any): number
	if x == nil and y == nil then
		return 0
	elseif x == nil or y == nil then
		return math.huge
	end
	local p, q = { x:GetComponents() }, { y:GetComponents() }
	local most = 0
	for i = 1, 12 do
		most = math.max(most, math.abs(p[i] - q[i]))
	end
	return most
end

local ids: { string } = {}
for id in a.boxes do
	if a.Config.FishById[id] then
		table.insert(ids, id)
	end
end
table.sort(ids)
for _, dials in { 0, 1 } do
	for _, w in { a, b } do
		w.Config.Fail.MouthFromModel = dials
		w.Config.Fail.Arrive = dials
		w.Config.Fail.Smooth = dials
	end
	for _, id in ids do
		local kinds = {}
		local own = a.Config.Fail.ByCreature[id]
		if own then
			kinds[own] = true -- (Throw is not this controller's: the body is only thrown)
		end
		kinds.Chomp = true
		kinds.Wrap = true
		for kind in kinds do
			local case: any = { Creature = id, Tier = "Normal", Kind = kind, New = false }
			math.randomseed(7)
			local okA, ra = pcall(World.play, a, case)
			math.randomseed(7)
			local okB, rb = pcall(World.play, b, case)
			if okA ~= okB or not okA then
				print("did not play", id, kind, okA, okB, ra, rb)
				bad += 1
				continue
			end
			count += 1
			local most = math.abs(#ra.frames - #rb.frames) * 1000
			for i, fr in ra.frames do
				local other = rb.frames[i]
				if not other then
					break
				end
				frames += 1
				most =
					math.max(most, far(fr.fish, other.fish), far(fr.rider, other.rider), far(fr.camera, other.camera))
				for name, c in fr.pose do
					most = math.max(most, far(c, other.pose[name]))
				end
				if fr.hidden ~= other.hidden then
					most = math.huge
				end
			end
			worst = math.max(worst, most)
			if most > 1e-6 then
				print(id, kind, "dials", dials, "differs by", most)
				bad += 1
			end
		end
	end
end
print(string.format("%d plays, %d frames, the largest difference %g, %d differing", count, frames, worst, bad))
