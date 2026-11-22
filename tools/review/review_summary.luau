-- Feel review: the summary of server_sampler.luau's rows (Server datamodel, in Play). Stops the sampler. Paste
-- hop_summary.luau's last line into HOPS to have the hops split by zone too (back on the same fish, and where the
-- misses were); left empty, only the fish in reach are summarised.
local HOPS = ""
local out = game.ServerStorage:WaitForChild("ReviewLog2")
out:SetAttribute("Stop", true)
task.wait(0.5)
if out.Value == "" then return "no log yet" end
local rows = {}
for line in out.Value:gmatch("[^\n]+") do
	local f = string.split(line, ",")
	table.insert(rows, { t = tonumber(f[1]), st = f[2], ox = tonumber(f[3]), n95 = tonumber(f[5]), n140 = tonumber(f[6]), n250 = tonumber(f[7]), s = tonumber(f[10]) or 0, zone = tonumber(f[11]) or 0 })
end
local function rowAt(t)
	local best, bd = nil, math.huge
	for _, r in rows do
		local d = math.abs(r.t - t)
		if d < bd then best, bd = r, d end
	end
	return best
end
-- the hops by zone, and each leg's stretch of the lane
local byZone, legs, misses = {}, {}, {}
local lastT = -math.huge
for tok in HOPS:gmatch("%S+") do
	local t = tonumber(string.match(tok, "^[%d%.]+"))
	if t then
		if t - lastT > 8 then table.insert(legs, { lo = math.huge, hi = -math.huge }) end
		lastT = t
		local r = rowAt(t)
		if r then
			local z = byZone[r.zone] or { n = 0, same = 0 }
			z.n += 1
			if string.find(tok, "s") then z.same += 1 end
			byZone[r.zone] = z
			local leg = legs[#legs]
			leg.lo, leg.hi = math.min(leg.lo, r.s), math.max(leg.hi, r.s)
			if string.find(tok, "m") then
				table.insert(misses, string.format("s %.0f, zone %d (within 95: %d, 140: %d)", r.s, r.zone, r.n95, r.n140))
			end
		end
	end
end
-- in the air: the free fish in reach (the fish just left counted), by zone
local air, total = {}, { n = 0, n95 = 0, n140 = 0, n250 = 0, lone = 0 }
local lo = math.huge
for _, r in rows do
	lo = math.min(lo, r.ox)
	if r.st == "Jumping" then
		local a = air[r.zone] or { n = 0, n95 = 0, n140 = 0, n250 = 0, lone = 0 }
		for _, x in { a, total } do
			x.n += 1
			x.n95 += r.n95
			x.n140 += r.n140
			x.n250 += r.n250
			if r.n95 <= 1 then x.lone += 1 end
		end
		air[r.zone] = a
	end
end
local function pct(a, b) return math.floor(100 * a / math.max(b, 1) + 0.5) end
local lines = {}
for z = 1, 10 do
	local b, a = byZone[z], air[z]
	if b or a then
		table.insert(lines, string.format("zone %d: hops %d, back on the same %d; in the air, fish within 95: %.2f, 140: %.2f; at most one within 95 %d%% of the time", z,
			b and b.n or 0, b and b.same or 0, a and a.n95 / a.n or 0, a and a.n140 / a.n or 0, a and pct(a.lone, a.n) or 0))
	end
end
local legText = {}
for i, l in legs do table.insert(legText, string.format("leg %d: s %.0f to %.0f", i, l.lo, l.hi)) end
local fish = 0
for _, m in workspace.Fish:GetChildren() do
	if m:IsA("Model") then fish += 1 end
end
local parked = game.ServerStorage:FindFirstChild("ParkedFish")
table.insert(lines, string.format("in the air %d%% of the time; fish within 95: %.2f, 140: %.2f, 250: %.2f; at most one within 95 %d%% of the time; oxygen lowest %.0f; fish in the Workspace now %d, parked %d",
	pct(total.n, #rows), total.n95 / math.max(total.n, 1), total.n140 / math.max(total.n, 1), total.n250 / math.max(total.n, 1), pct(total.lone, total.n), lo, fish, parked and #parked:GetChildren() or 0))
if #legText > 0 then table.insert(lines, table.concat(legText, "; ")) end
if #misses > 0 then table.insert(lines, "misses at: " .. table.concat(misses, "; ")) end
return table.concat(lines, "\n")
