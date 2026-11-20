--!nocheck
-- Task e1's check (docs/plans/2026-11-20-oxygen-equip-landride.md, E1): what a fish needs is its own and the same in
-- every land, and training gives whole numbers once a whole second. Run in Edit with the studio-runner:
--   node ~/Projects/studio-runner/studio-run.mjs tools/studio/oxygen_check.luau
-- Prints PASS/FAIL lines and returns a JSON report. Pure: it makes fish models but never parents them.
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(RS.Shared.Config)
local Zones = require(RS.Shared.Zones)

local report = { pass = 0, fail = 0, lines = {} }
local function check(ok: boolean, text: string)
	if ok then
		report.pass += 1
	else
		report.fail += 1
	end
	local line = (if ok then "PASS " else "FAIL ") .. text
	table.insert(report.lines, line)
	print(line)
end

-- 1. every kind x size x colour: a whole number, at least 1, growing with size and colour; no kind without a base
local sizes = Config.SizeOrder
local colours = { "", "Silver", "Gold", "Rainbow" }
local count, bad, missing = 0, 0, {}
local baselines = {}
for _, fish in Config.Fish do
	if not Config.OxygenBase[fish.Id] then
		table.insert(missing, fish.Id)
	end
	local last = 0
	for _, size in sizes do
		local rowLast = 0
		for _, colour in colours do
			local need = Config.requiredOf(fish, size, colour)
			count += 1
			if need ~= math.floor(need) or need < 1 or need < rowLast then
				bad += 1
			end
			rowLast = need
		end
		local plain = Config.requiredOf(fish, size, "")
		if plain < last then
			bad += 1
		end
		last = plain
	end
	local plain = Config.requiredOf(fish, "Normal", "")
	baselines[plain] = baselines[plain] or {}
	table.insert(baselines[plain], fish.Id)
	if fish.Required ~= plain then
		bad += 1
	end
end
local dupes = {}
for need, ids in baselines do
	if #ids > 1 then
		table.insert(dupes, need .. ": " .. table.concat(ids, ", "))
	end
end
check(#missing == 0, #Config.Fish .. " kinds, missing bases: " .. table.concat(missing, ", "))
check(bad == 0 and count == #Config.Fish * 24, count .. " values whole, >= 1, growing with size and colour (" .. bad .. " bad)")
check(#dupes == 0, "no two kinds' Normal plain fish need the same (" .. table.concat(dupes, "; ") .. ")")

-- 2. the same fish in two lands: every reader gives the same
local zones = Zones.discover()
if #zones == 0 then
	zones = Zones.fallback()
end
local function inLand(index: number): Vector3
	for _, z in zones do
		if z.Index == index then
			return z.Frame.Position
		end
	end
	error("no land " .. index)
end
local function model(id: string, size: string, colour: string, at: Vector3): Model
	local m = Instance.new("Model")
	local root = Instance.new("Part")
	root.Anchored = true
	root.Position = at
	root.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("FishType", id)
	m:SetAttribute("Tier", Config.FishById[id].Tier)
	m:SetAttribute("SizeTier", size)
	m:SetAttribute("Variant", colour)
	return m
end
local function readings(m: Model, max: number): { [string]: any }
	local kind = Config.FishById[m:GetAttribute("FishType")]
	local need = Config.requiredOfModel(m)
	local located = Zones.locate(zones, m.PrimaryPart.Position)
	return {
		land = if located then located.Index else 0,
		need = need,
		label = Config.wholeNumber(need),
		strained = Config.strained(need, max),
		seconds = Config.secondsOn(need, max, kind),
		drain = Config.drainFor(need, kind, max),
		tame = Config.tameTime(need, max),
		income = Config.incomeOf(kind, m:GetAttribute("SizeTier"), m:GetAttribute("Variant")),
	}
end
local pairsToTest = {
	{ "Clownfish", "Normal", "", 1, 2, 100 },
	{ "Clownfish", "Colossal", "Rainbow", 1, 2, 1000 },
	{ "HellfinShark", "Normal", "", 6, 10, 50000 },
	{ "Megalodon", "Big", "Gold", 6, 10, 20000 },
}
report.lands = {}
for _, p in pairsToTest do
	local id, size, colour, a, b, max = table.unpack(p)
	local fish = model(id, size, colour, inLand(a))
	local one = readings(fish, max)
	fish.PrimaryPart.Position = inLand(b)
	local two = readings(fish, max)
	local same = one.land ~= two.land
	for key, value in one do
		if key ~= "land" and two[key] ~= value then
			same = false
		end
	end
	table.insert(report.lands, { fish = id, size = size, colour = colour, max = max, a = one, b = two })
	check(
		same,
		string.format(
			"%s %s %s at max %d: land %d and land %d both need %s, strained %s, %.2f s on it, tame %.2f s, %.3f coins/s",
			id,
			size,
			if colour == "" then "plain" else colour,
			max,
			one.land,
			two.land,
			two.label,
			tostring(two.strained),
			two.seconds,
			two.tame,
			two.income
		)
	)
	fish:Destroy()
end

-- 3. one under / at what it needs
for _, p in { { "Clownfish", "Tiny", "" }, { "Kraken", "Colossal", "Rainbow" } } do
	local need = Config.requiredOf(Config.FishById[p[1]], p[2], p[3])
	check(
		Config.strained(need - 1, need) == false and Config.strained(need, need - 1) == true,
		p[1] .. " " .. p[2] .. " " .. (if p[3] == "" then "plain" else p[3]) .. " needs " .. need .. ": at it held, one under too strong"
	)
end

-- 4. training: whole Oxygen once a whole second, at any frame rate (TrainService.gain's arithmetic)
local stepsOf = {
	["60 fps"] = function()
		return 1 / 60
	end,
	["10 Hz"] = function()
		return 0.1
	end,
	["jittery"] = function()
		return 0.02 + math.random() * 0.2
	end,
}
local trainBad = 0
for level, row in Config.Train.Levels do
	for name, step in stepsOf do
		for _, startMax in { 100, 100000 } do
			local carry, gained, t = 0, 0, 0
			while t < 10 - 1e-9 do
				local dt = math.min(step(), 10 - t)
				t += dt
				local ticks, left = Config.trainTicks(carry, dt)
				carry = left
				gained += ticks * row.Oxygen
			end
			local max = startMax + gained
			if gained ~= 10 * row.Oxygen or max ~= math.floor(max) then
				trainBad += 1
				print("  level", level, name, startMax, "gained", gained)
			end
		end
	end
end
check(trainBad == 0, "12 levels x 3 frame timings x max 100 and 100,000: 10 s seated gives exactly 10 x the level's Oxygen")
local ticks = Config.trainTicks(0, 0.9)
check(ticks == 0, "0.9 s seated gives nothing")
check(Config.Train.Share == nil, "no Train.Share (a share of max) left")

report.samples = {}
for _, p in {
	{ "Clownfish", "Normal", "" },
	{ "Clownfish", "Tiny", "" },
	{ "Clownfish", "Giant", "Gold" },
	{ "Clownfish", "Colossal", "Rainbow" },
	{ "Seahorse", "Normal", "" },
	{ "ReefShark", "Normal", "" },
	{ "Dunkleosteus", "Normal", "" },
	{ "Dunkleosteus", "Big", "Silver" },
	{ "BlueWhale", "Normal", "" },
	{ "Kraken", "Normal", "" },
	{ "HellfinShark", "Normal", "" },
	{ "Hellmaw", "Normal", "" },
} do
	local kind = Config.FishById[p[1]]
	table.insert(report.samples, {
		p[1],
		kind.Tier,
		Config.OxygenBase[p[1]],
		p[2],
		p[3],
		Config.requiredOf(kind, p[2], p[3]),
		Config.incomeOf(kind, p[2], p[3]),
	})
end
print(string.format("%d passed, %d failed", report.pass, report.fail))
return HttpService:JSONEncode(report)
