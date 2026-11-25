-- Every frame of the two eating moves, new and old, as JSON for tools/blender/eat_frames.py (the real FailController,
-- offline: tools/eat/eat_world.luau).
--   lune run tools/eat/eat_frames.luau [Tier] > work/eat/frames.json
local process = require("@lune/process")
local serde = require("@lune/serde")

local World = require("./eat_world")
local w = World.open("work/eat/place.rbxl")
local tier = process.args[1] or "Normal"

local function cf(c: any): { number }
	return { c:GetComponents() }
end

local out: { any } = {}
for _, what in { { "Kronosaurus", "Chomp" }, { "Octopus", "Wrap" } } do
	for _, new in { true, false } do
		local r = World.play(w, { Creature = what[1], Tier = tier, Kind = what[2], New = new })
		local frames: { any } = {}
		for _, fr in r.frames do
			local pose: { [string]: any } = {}
			for name, c in fr.pose do
				pose[name] = cf(c)
			end
			local rider: { any } = {}
			for _, row in World.R15 do
				if row[1] ~= "HumanoidRootPart" then
					table.insert(rider, { row[1], cf(fr.rider * row[2]), { row[3].X, row[3].Y, row[3].Z } })
				end
			end
			table.insert(frames, {
				t = fr.t,
				u = fr.u,
				fish = cf(fr.fish),
				pose = pose,
				rider = rider,
				hidden = fr.hidden,
				camera = if fr.camera then cf(fr.camera) else nil,
			})
		end
		table.insert(out, {
			creature = what[1],
			kind = what[2],
			new = new,
			k = r.k,
			length = r.body.Z,
			jet = w.Config.Fail.EatMoves.Wrap.Jet,
			frames = frames,
		})
	end
end
print(serde.encode("json", out))
