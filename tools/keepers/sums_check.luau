-- Run by tools/keepers/sums_check.py with lune: the game's own module (src/shared/Keepers.luau), given lune's CFrame
-- and Vector3, works out every case in the file the Python sums wrote, and says how far apart the two are.
--   lune run tools/keepers/sums_check.luau <Keepers.luau> <cases.json>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3 = (roblox :: any).CFrame, (roblox :: any).Vector3
local Keepers = luau.load(fs.readFile(process.args[1]), {
	debugName = "Keepers",
	environment = { CFrame = CFrame, Vector3 = Vector3 },
})()
local cases = serde.decode("json", fs.readFile(process.args[2]))

local worst, where, count = 0, "", 0
local function hold(what: string, got: { number }, want: { number })
	for i = 1, math.max(#got, #want) do
		count += 1
		local apart = math.abs((got[i] or math.huge) - (want[i] or math.huge))
		if apart > worst or apart ~= apart then
			worst, where = apart, what
		end
	end
end

local byId = {}
for _, keeper in Keepers.List do
	byId[keeper.Id] = keeper
end
for _, case in cases.poses do
	local keeper = byId[case.id]
	local how = case.how
	local anim = Keepers.anim(keeper, how.sway_t, how.action_t)
	local body, head, tip = 0, 0, 0
	if how.yaw or how.pitch then
		body, head, tip = Keepers.lookSplit(how.yaw or 0, how.pitch or 0)
	end
	local joints = Keepers.joints(keeper, case.scale, anim, body, head, tip)
	for i, row in keeper.Parts do
		local cf = joints[row[1]] * Keepers.offset(keeper, row, case.scale)
		hold(`{case.id} part {i} ({row[1]})`, { cf:GetComponents() }, case.parts[i])
	end
end
for _, case in cases.splits do
	hold(`the split of {case.yaw}, {case.pitch}`, { Keepers.lookSplit(case.yaw, case.pitch) }, case.out)
end
for _, case in cases.aims do
	hold("an aim", { Keepers.aim(Vector3.new(case.at[1], case.at[2], case.at[3])) }, case.out)
end
for _, case in cases.stands do
	local keeper = byId[case.id]
	local space = Keepers.standSpace(
		Vector3.new(case.anchor[1], case.anchor[2], case.anchor[3]),
		Vector3.new(case.ring[1], case.ring[2], case.ring[3]),
		case.floor
	)
	hold(`{case.id}'s stand`, { space:GetComponents() }, case.space)
	for i, row in keeper.Props do
		hold(`{case.id} prop {i}`, { (space * Keepers.propAt(row, case.scale)):GetComponents() }, case.props[i])
	end
end
print(`{count} numbers held against the Python sums: the furthest apart is {string.format("%.6f", worst)} ({where})`)
process.exit(if worst < 0.001 then 0 else 1)
