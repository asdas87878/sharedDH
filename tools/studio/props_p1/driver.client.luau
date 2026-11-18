-- P1 props-by-size playtest: the client driver (temporary; installed by install.py, removed after the run).
-- Commands through ReplicatedStorage.B1Cmd (the b1 logger's), each with something changing so it can repeat:
--   run <FishId> <propPrefix> [tier]: onto that fish (rerolled up to 8 times until its SizeTier is `tier`, Normal by
--     default), straight at the nearest whole prop whose name starts with propPrefix, and through. One RESULT line:
--     both sizes and the ratio, what Config.propBreak says, the speed before and the least after the touch, the
--     server's Crashed (speed kept) and Boost (Oxygen given) messages, Oxygen before and after, the stuns, and the
--     target prop's boxes knocked out.
--   suite: the cases of docs/playtests/2026-11-18-props-by-size.md
--   set <Group> <Key> <value>
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("B1Report")
local cmd = RS:WaitForChild("B1Cmd")
local function log(...)
	report:FireServer(string.format(...))
end
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError then
		report:FireServer("CLIENT " .. kind.Name .. ": " .. message)
	end
end)
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local RideController = require(Client:WaitForChild("Controllers"):WaitForChild("RideController"))
local PropController = require(Client.Controllers:WaitForChild("PropController"))
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared:WaitForChild("Net"))

local function tune(group, key, value)
	Config[group][key] = value
	if Config.refresh then
		Config.refresh()
	end
	Net.Sandbox:FireServer("Tune", group .. "." .. key, value)
end
local function settle(time)
	local t0 = os.clock()
	while os.clock() - t0 < time do
		RunService.RenderStepped:Wait()
	end
end
local function waitFor(test, time)
	local t0 = os.clock()
	while os.clock() - t0 < time do
		if test() then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return false
end

local aim = nil
RunService:BindToRenderStep("P1Look", Enum.RenderPriority.Input.Value + 1, function()
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	if aim and root then
		local d = aim() - root.Position
		if d.Magnitude > 1 then
			RideController.look(math.atan2(-d.X, -d.Z), math.asin(math.clamp(d.Unit.Y, -1, 1)))
		end
	end
end)
RideController.moveVector = function()
	return Vector3.zero
end

local events = {}
Net.Ride.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "Crashed" or kind == "Boost" then
		table.insert(events, { Kind = kind, A = a, B = b, C = c, D = d, E = e, T = os.clock() })
	end
end)

local function getOn(id, tier)
	aim = nil
	for try = 1, 8 do
		Net.Sandbox:FireServer("Ride", id, "")
		settle(0.5)
		local ok = waitFor(function()
			return State.Mode == "Riding" and State.Fish ~= nil and State.Fish:GetAttribute("FishType") == id
		end, 9)
		if ok and (tier == nil or State.Fish:GetAttribute("SizeTier") == tier) then
			return true
		end
	end
	return State.Mode == "Riding" and State.Fish ~= nil
end

local function boxesOut(model)
	local n = 0
	for _, box in model:GetChildren() do
		if CollectionService:HasTag(box, "PropOut") then
			n += 1
		end
	end
	return n
end

local tried = {}
local function pickProp(root, prefix)
	local props = workspace.ClaudeBlockout.Lane.Props
	local look = root.CFrame.LookVector
	local best, bestFar = nil, math.huge
	for _, model in props:GetChildren() do
		if string.sub(model.Name, 1, #prefix) == prefix and not tried[model] and boxesOut(model) == 0 then
			local cf = model:GetBoundingBox()
			local off = cf.Position - root.Position
			local far = off.Magnitude
			if far > 90 and far < 900 and off.Unit:Dot(look) > 0.6 and far < bestFar then
				best, bestFar = model, far
			end
		end
	end
	return best
end

-- the gap from our fish's body (a rod tail to nose) to the prop's box
local function gapTo(model, fishRoot, body)
	local cf, size = model:GetBoundingBox()
	local best = math.huge
	for i = -2, 2 do
		local p = fishRoot.Position + fishRoot.CFrame.LookVector * (body.Z / 2) * (i / 2)
		local l = cf:PointToObjectSpace(p)
		local c = Vector3.new(
			math.clamp(l.X, -size.X / 2, size.X / 2),
			math.clamp(l.Y, -size.Y / 2, size.Y / 2),
			math.clamp(l.Z, -size.Z / 2, size.Z / 2)
		)
		best = math.min(best, (l - c).Magnitude)
	end
	return best - math.min(body.X, body.Y) / 2
end

local function run(id, prefix, tier, attempt)
	attempt = attempt or 1
	Net.Sandbox:FireServer("Flag", "NoFail", true)
	waitFor(function()
		return State.Mode ~= "Drowning" and State.Mode ~= "Dead" and not State.dying()
	end, 15)
	settle(0.5)
	tune("Oxygen", "KeepUp", 60) -- (a full meter lasts long enough to reach a prop)
	settle(0.3)
	report:FireServer("__cfg Oxygen KeepUp")
	if not getOn(id, tier) then
		log("RESULT %s %s: could not get on", id, prefix)
		return
	end
	local fish = State.Fish
	local fishRoot = fish.PrimaryPart
	local kind = Config.FishById[id]
	local body = Config.bodyOf(fish, kind)
	local fishSize = Config.boxSize(body)
	local target = pickProp(fishRoot, prefix)
	if not target then
		log("RESULT %s %s: MISS (no whole prop of that kind ahead)", id, prefix)
		return
	end
	tried[target] = true
	local propSize = target:GetAttribute("PropSize") or -1
	local breaks, keep = Config.propBreak(kind, fishSize, propSize)
	local cf = target:GetBoundingBox()
	aim = function()
		return cf.Position
	end
	table.clear(events)
	local stuns0 = PropController.Stats.Stuns
	-- swim at it until the body touches its box
	local speeds = {}
	local touchAt = nil
	local t0 = os.clock()
	while os.clock() - t0 < 15 do
		RunService.RenderStepped:Wait()
		if State.Mode ~= "Riding" or State.Fish ~= fish then
			break
		end
		local v = fishRoot.AssemblyLinearVelocity.Magnitude
		table.insert(speeds, { T = os.clock(), V = v })
		if gapTo(target, fishRoot, body) <= 0.5 then
			touchAt = os.clock()
			break
		end
	end
	if not touchAt then
		log("O2 at miss %s of %s, after %.1fs", tostring(player:GetAttribute("Oxygen")), tostring(player:GetAttribute("MaxOxygen")), os.clock() - t0)
		log("MISS %s(%s %.1f) -> %s(%.1f) (mode %s)", id, tostring(fish:GetAttribute("SizeTier")), fishSize, target.Name, propSize, State.Mode)
		aim = nil
		if attempt < 4 then
			return run(id, prefix, tier, attempt + 1)
		end
		return
	end
	local before = 0
	for _, s in speeds do
		if s.T >= touchAt - 0.4 then
			before = math.max(before, s.V)
		end
	end
	-- on through: straight on, level, from the touch (so the steering doesn't turn back to the prop or nose the floor)
	local flat = Vector3.new(fishRoot.CFrame.LookVector.X, 0, fishRoot.CFrame.LookVector.Z).Unit
	local ahead = fishRoot.Position + flat * 2000 + Vector3.new(0, 60, 0)
	aim = function()
		return ahead
	end
	local oxygenBefore = player:GetAttribute("Oxygen") or -1
	local least, leastAt = math.huge, 0
	while os.clock() - touchAt < 1.5 and State.Mode == "Riding" do
		RunService.RenderStepped:Wait()
		local v = fishRoot.AssemblyLinearVelocity.Magnitude
		if v < least then
			least, leastAt = v, os.clock() - touchAt
		end
	end
	local crashed, boost = "-", "-"
	for _, e in events do
		if e.Kind == "Crashed" then
			crashed = string.format("%.2f", e.A)
		elseif e.Kind == "Boost" then
			boost = string.format("%s x%.2f O2 %.3f", tostring(e.A), e.B or 0, e.D or 0)
		end
	end
	log(
		"RESULT %s(%s) size %.1f -> %s size %.1f ratio %.2f | rule: breaks %s keep %.2f | boxes out %d/%d | speed %.0f -> least %.0f (%.0f%%, at +%.2fs) | Crashed %s | Boost %s | O2 %.0f -> %.0f of %.0f | stuns %d",
		id,
		tostring(fish:GetAttribute("SizeTier")),
		fishSize,
		target.Name,
		propSize,
		fishSize / math.max(propSize, 0.01),
		tostring(breaks),
		keep,
		boxesOut(target),
		#target:GetChildren(),
		before,
		least,
		100 * least / math.max(before, 0.01),
		leastAt,
		crashed,
		boost,
		oxygenBefore,
		player:GetAttribute("Oxygen") or -1,
		player:GetAttribute("MaxOxygen") or -1,
		PropController.Stats.Stuns - stuns0
	)
	aim = nil
end

local SUITE = {
	{ "Clownfish", "sea_grass", "Normal" }, -- small fish, grass: breaks, no slow
	{ "BlueChromis", "sea_grass", "Normal" },
	{ "Clownfish", "fan_coral", "Normal" }, -- small fish, big coral: through (stun)
	{ "ReefShark", "table_coral", "Normal" }, -- mid fish, just bigger than a mid prop: slowed
	{ "ReefShark", "fan_coral", "Normal" }, -- mid fish, smaller than the coral: through
	{ "Megalodon", "fan_coral", "Normal" }, -- giant, a bit bigger than coral: slowed some
	{ "Megalodon", "table_coral", "Normal" }, -- giant, way bigger: barely
	{ "Sawfish", "fan_coral", "Normal" }, -- Breaker, smaller than the coral: breaks, Oxygen, no slow
	{ "Sawfish", "sea_grass", "Normal" },
}

cmd.Changed:Connect(function(value)
	local words = string.split(value, " ")
	if words[1] == "run" then
		run(words[2], words[3], words[4])
		log("RUN DONE")
	elseif words[1] == "suite" then
		for i, case in SUITE do
			if i < (tonumber(words[2]) or 1) then
				continue
			end
			local ok, err = pcall(run, case[1], case[2], case[3])
			if not ok then
				log("ERROR %s", tostring(err))
			end
			settle(1)
		end
		log("SUITE DONE")
	elseif words[1] == "set" then
		tune(words[2], words[3], tonumber(words[4]))
		log("set %s.%s = %s", words[2], words[3], words[4])
	end
end)
log("driver up")
