-- A2 archetype playtest: server side (temporary; removed after the run)
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")

local log = Instance.new("StringValue")
log.Name = "A2Log"
log.Parent = SS
local lines = {}
local function add(text)
	table.insert(lines, string.format("%7.2f %s", os.clock() % 10000, text))
	log.Value = table.concat(lines, "\n")
end
local report = Instance.new("RemoteEvent")
report.Name = "A2Report"
report.Parent = RS
local ask = Instance.new("RemoteFunction")
ask.Name = "A2Ask"
ask.Parent = RS
local cmd = Instance.new("StringValue")
cmd.Name = "A2Cmd"
cmd.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	add("C " .. tostring(text))
end)
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError then
		add("SERVER " .. kind.Name .. ": " .. message)
	end
end)

local FishService = require(SSS:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("FishService"))

local function fishOf(player)
	local folder = workspace:FindFirstChild("Fish")
	for _, m in folder and folder:GetChildren() or {} do
		if m:GetAttribute("Rider") == player.UserId then
			return m
		end
	end
	return nil
end

ask.OnServerInvoke = function(player, what, a, b, c)
	if what == "speed" then
		-- path length over `a` seconds of the fish the player rides, as the server sees it
		local fish = fishOf(player)
		if not fish or not fish.PrimaryPart then
			return nil
		end
		local root = fish.PrimaryPart
		local from = root.Position
		local length, time = 0, 0
		local samples = {}
		while time < a do
			local dt = RunService.Heartbeat:Wait()
			if not root.Parent then
				break
			end
			local at = root.Position
			length += (at - from).Magnitude
			table.insert(samples, root.AssemblyLinearVelocity.Magnitude)
			from = at
			time += dt
		end
		table.sort(samples)
		return length / math.max(time, 0.001), samples[math.max(1, #samples // 2)]
	elseif what == "prop" then
		local fish = fishOf(player)
		local root = fish and fish.PrimaryPart
		local props = workspace.ClaudeBlockout.Lane.Props
		if not root then
			return nil
		end
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = look.Unit
		local best, bestD, bestN = nil, math.huge, 0
		for _, m in props:GetChildren() do
			local part = m:FindFirstChildWhichIsA("BasePart")
			if part then
				local d = (part.Position - root.Position) * Vector3.new(1, 0, 1)
				local n = d.Magnitude
				local side = math.abs(d.X * look.Z - d.Z * look.X)
				if n > (a or 80) and n < 700 and d:Dot(look) > 0.8 * n and side < 28 and n < bestD then
					best, bestD = m, n
				end
			end
		end
		if not best then
			return nil
		end
		local cf, size = best:GetBoundingBox()
		return cf.Position, size, #best:GetChildren(), best.Name
	elseif what == "spawn" then
		local fish = fishOf(player)
		local root = fish and fish.PrimaryPart
		if not root then
			return nil
		end
		local look = root.CFrame.LookVector
		local w = FishService.spawnTest(a, b or "", root.Position + look * (c or 60), look)
		return w and w.Model
	elseif what == "max" then
		workspace:SetAttribute("TestMaxOxygen", a)
		return true
	elseif what == "count" then
		return #workspace.Fish:GetChildren(), #SS.ParkedFish:GetChildren()
	elseif what == "preytest" then
		-- a fish with a rider, or kept for a hop, is never prey: asked of FishService.prey directly
		local hunter = FishService.get(fishOf(player))
		local out = {}
		local n = 0
		for _, m in workspace.Fish:GetChildren() do
			local w = FishService.get(m)
			if w and w ~= hunter and not w.Rider and not w.Reserved and not w.CoastToken and n < 5 then
				n += 1
				local at = w.Root.Position
				local free = FishService.prey(hunter, at, 1, 1000) == w
				w.Rider = player
				local ridden = FishService.prey(hunter, at, 1, 1000) == w
				w.Rider = nil
				w.Reserved = player
				local kept = FishService.prey(hunter, at, 1, 1000) == w
				w.Reserved = nil
				local tooLong = FishService.prey(hunter, at, 1, w.Body.Z - 0.1) == w
				table.insert(out, string.format("%s free=%s ridden=%s reserved=%s tooLong=%s", w.Type.Id, tostring(free), tostring(ridden), tostring(kept), tostring(tooLong)))
			end
		end
		return table.concat(out, "; ")
	elseif what == "attrs" then
		local fish = fishOf(player)
		if not fish then
			return "no fish"
		end
		return string.format("Archetype=%s Bite=%s Smash=%s Frenzy=%s Angry=%s", tostring(fish:GetAttribute("Archetype")), tostring(fish:GetAttribute("Bite")), tostring(fish:GetAttribute("Smash")), tostring(fish:GetAttribute("Frenzy")), tostring(fish:GetAttribute("Angry")))
	end
	return nil
end
add("server ready")
