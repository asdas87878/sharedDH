-- Logs one ride on the server, four times a second for 58 seconds from the first mount: what the herd is like round the
-- rider. Run it in Play on the Server (the chat that has Studio), then ride; the answer is put in
-- ServerStorage.RideLog (a StringValue: "running" until it is done). The numbers in docs/design/herd-revamp.md come
-- from this.
--   ground made good, share of the time riding, riding speed
--   fish within 200 studs; free fish ahead within 300 (and how often there were 0, 1, 2 ...)
--   pairs of bodies overlapping, and pairs within 12 studs, among the fish within 400 studs; by the pair's characters
--   each character's speed against the rider's
--   fish that came into the water: made new (and how near), or woken (parked fish coming back)
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local fishFolder = workspace.Fish
local parkedFolder = game.ServerStorage.ParkedFish
local old = game.ServerStorage:FindFirstChild("RideLog")
if old then
	old:Destroy()
end
local result = Instance.new("StringValue")
result.Name = "RideLog"
result.Value = "running"
result.Parent = game.ServerStorage
local player = Players:GetPlayers()[1]
local uid = player.UserId
task.spawn(function()
	local function root()
		local c = player.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function ridden()
		for _, m in fishFolder:GetChildren() do
			if m:GetAttribute("Rider") == uid then
				return m
			end
		end
		return nil
	end
	local t0 = os.clock()
	while not ridden() and os.clock() - t0 < 30 do
		task.wait(0.05)
	end
	if not ridden() then
		result.Value = "never mounted"
		return
	end
	local parkedAt = {}
	local made, woken = {}, {}
	local c1 = parkedFolder.ChildAdded:Connect(function(m)
		parkedAt[m] = os.clock()
	end)
	local seen = {}
	for _, m in fishFolder:GetChildren() do
		seen[m] = true
	end
	local c2 = fishFolder.ChildAdded:Connect(function(m)
		local r = root()
		task.defer(function()
			local p = m.PrimaryPart
			if not r or not p then
				return
			end
			local d = (p.Position - r.Position).Magnitude
			local fresh = not seen[m] and (parkedAt[m] == nil or os.clock() - parkedAt[m] < 0.2)
			seen[m] = true
			if fresh then
				table.insert(made, d)
			else
				table.insert(woken, d)
			end
		end)
	end)
	local function body(m)
		local kind = Config.FishById[m:GetAttribute("FishType")]
		return if kind then Config.bodyOf(m, kind) else Vector3.new(4, 4, 10)
	end
	local start = os.clock()
	local first = root().Position
	local last = first
	local path = 0
	local samples, ridingN = 0, 0
	local near200, ahead300 = 0, 0
	local aheadHist = {}
	local overlap, close = 0, 0
	local pairsBy = {}
	local rel = { Cruise = {}, Plod = {}, Dart = {}, Zoom = {}, Hunt = {} }
	local rideSpeed, rideN = 0, 0
	while os.clock() - start < 58 do
		task.wait(0.25)
		local r = root()
		if not r then
			break
		end
		local here = r.Position
		path += (here - last).Magnitude
		last = here
		samples += 1
		local mine = ridden()
		local v = r.AssemblyLinearVelocity
		if mine then
			ridingN += 1
			rideSpeed += v.Magnitude
			rideN += 1
		end
		local dir = if v.Magnitude > 5 then v.Unit else r.CFrame.LookVector
		local list = {}
		local n200, n300 = 0, 0
		for _, m in fishFolder:GetChildren() do
			local p = m.PrimaryPart
			if p and m ~= mine then
				local to = p.Position - here
				local d = to.Magnitude
				if d < 200 then
					n200 += 1
				end
				if d < 300 and to:Dot(dir) > 0 and m:GetAttribute("Rider") == 0 then
					n300 += 1
				end
				if d < 400 then
					local pace = m:GetAttribute("Pace") or "Cruise"
					table.insert(list, { p.CFrame, body(m), pace })
					if rel[pace] and mine then
						table.insert(rel[pace], p.AssemblyLinearVelocity.Magnitude - v.Magnitude)
					end
				end
			end
		end
		near200 += n200
		ahead300 += n300
		aheadHist[n300] = (aheadHist[n300] or 0) + 1
		for i = 1, #list - 1 do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local l = a[1]:PointToObjectSpace(b[1].Position)
				local x, y, z = (a[2].X + b[2].X) / 2, (a[2].Y + b[2].Y) / 2, (a[2].Z + b[2].Z) / 2
				if math.abs(l.X) < x and math.abs(l.Y) < y and math.abs(l.Z) < z then
					overlap += 1
					local key = if a[3] < b[3] then a[3] .. "+" .. b[3] else b[3] .. "+" .. a[3]
					pairsBy[key] = (pairsBy[key] or 0) + 1
				elseif math.abs(l.X) < x + 12 and math.abs(l.Y) < y + 12 and math.abs(l.Z) < z + 12 then
					close += 1
				end
			end
		end
	end
	c1:Disconnect()
	c2:Disconnect()
	local took = os.clock() - start
	local out = {}
	local function add(s)
		table.insert(out, s)
	end
	add(
		("took %.1f s; ground made good %.1f studs/s (straight %.1f); riding %.0f%% of the time, riding speed %.1f"):format(
			took,
			path / took,
			(last - first).Magnitude / took,
			100 * ridingN / math.max(samples, 1),
			rideSpeed / math.max(rideN, 1)
		)
	)
	add(("fish within 200: %.1f; ahead within 300: %.1f"):format(near200 / samples, ahead300 / samples))
	local hist = {}
	for n = 0, 16 do
		table.insert(hist, n .. ":" .. math.floor(100 * (aheadHist[n] or 0) / samples + 0.5) .. "%")
	end
	add("ahead hist " .. table.concat(hist, " "))
	add(
		("overlapping pairs %.2f, pairs within 12 studs %.2f (per look, fish within 400)"):format(
			overlap / samples,
			close / samples
		)
	)
	local by = {}
	for key, n in pairsBy do
		table.insert(by, ("%s %.2f"):format(key, n / samples))
	end
	table.sort(by)
	add("overlaps by pair: " .. table.concat(by, ", "))
	for pace, l in rel do
		if #l > 0 then
			local s = 0
			for _, x in l do
				s += x
			end
			add(("%s against the rider: %.1f (n %d)"):format(pace, s / #l, #l))
		end
	end
	table.sort(made)
	table.sort(woken)
	local under = 0
	for _, d in made do
		if d < 500 then
			under += 1
		end
	end
	local wsum = 0
	for _, d in woken do
		wsum += d
	end
	local m10 = {}
	for i = 1, math.min(12, #made) do
		table.insert(m10, tostring(math.floor(made[i])))
	end
	add(("made in the water: %d, under 500 studs: %d, nearest: %s"):format(#made, under, table.concat(m10, " ")))
	add(
		("woken: %d at %.0f on average, nearest %s"):format(
			#woken,
			wsum / math.max(#woken, 1),
			tostring(woken[1] and math.floor(woken[1]))
		)
	)
	result.Value = table.concat(out, "\n")
end)
return "logger armed for " .. player.Name
