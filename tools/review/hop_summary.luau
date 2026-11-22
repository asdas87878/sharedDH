-- Feel review: every hop of this Play session summarised (Client datamodel, in Play; the feel log is on in Studio).
-- Reads client_collector.luau's LocalPlayer.HopLogT when it is there, else LogService's history (short runs only:
-- it drops old lines). The dive's first hop is left out. "Same": landed back on the fish just left. Runs of the same
-- in a row are counted within a leg (a gap of more than 5 s between hops starts a new one: the sandbox's R reset).
-- The last line is every hop's clock, "s" for same and "m" for missed: paste it into review_summary.luau's HOPS to
-- split the hops by zone.
local Http = game:GetService("HttpService")
local lp = game:GetService("Players").LocalPlayer
local hops = {}
local function add(t: number?, json: string)
	local ok, d = pcall(function()
		return Http:JSONDecode(json)
	end)
	if ok and d.Grab ~= "dive" and d.N and d.N > 1 then
		d.T = t or 0
		table.insert(hops, d)
	end
end
local stored = lp:FindFirstChild("HopLogT")
if stored and stored.Value ~= "" then
	for line in stored.Value:gmatch("[^\n]+") do
		local t, json = string.match(line, "^([%d%.]+)|(.+)$")
		if json then add(tonumber(t), json) end
	end
else
	for _, e in game:GetService("LogService"):GetLogHistory() do
		local json = string.match(e.message, "^%[FeelHop%] (.+)$")
		if json then add(e.timestamp, json) end
	end
end
local n, landed, same = #hops, 0, 0
local grab, touch, reel, gap, switches = {}, {}, {}, {}, 0
local streak, longest, runs3 = 0, 0, 0
local compact = {}
for i, d in hops do
	if d.End == "landed" then landed += 1 end
	if i > 1 and d.T - hops[i - 1].T > 5 then streak = 0 end
	if d.Same then
		same += 1
		streak += 1
		if streak == 3 then runs3 += 1 end
		longest = math.max(longest, streak)
	else
		streak = 0
	end
	if d.GrabAt then table.insert(grab, d.GrabAt) end
	if d.Touch then table.insert(touch, d.Touch) end
	if d.Reel then table.insert(reel, d.Reel) end
	if d.Gap then table.insert(gap, d.Gap) end
	if d.Locks then switches += math.max(#d.Locks - 1, 0) end
	table.insert(compact, string.format("%.1f%s%s", d.T, d.Same and "s" or "", d.End == "landed" and "" or "m"))
end
local function stats(t)
	if #t == 0 then return "-" end
	table.sort(t)
	return string.format("%.2f to %.2f, median %.2f", t[1], t[#t], t[math.ceil(#t / 2)])
end
local fps = {}
local fpsLog = lp:FindFirstChild("FpsLog")
if fpsLog then
	for v in fpsLog.Value:gmatch("[^,]+") do table.insert(fps, tonumber(v)) end
end
return string.format("%d hops: landed %d, missed %d; back on the fish just left %d (%d%%); runs of 3+ in a row %d, longest %d; hook at %s s; touch at %s s; pull-in %s s; gap %s studs; lock switches %.1f a hop; frames a second %s\n%s",
	n, landed, n - landed, same, math.floor(100 * same / math.max(n, 1) + 0.5), runs3, longest, stats(grab), stats(touch), stats(reel), stats(gap),
	switches / math.max(n, 1), stats(fps), table.concat(compact, " "))
