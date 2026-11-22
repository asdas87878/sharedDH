-- b3 hook test: the client driver (temporary). Hops off a fish in a deep land; the server sends a fast fish past
-- from behind; the view is turned onto it so the lock takes it, and the grab is pressed (or left to the pull-in).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZB3Report")
local function log(...)
	report:FireServer("log", string.format(...))
end
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local RideController = require(Client:WaitForChild("Controllers"):WaitForChild("RideController"))
local Actions = require(Client:WaitForChild("Lib"):WaitForChild("Actions"))
local State = require(Client.Lib:WaitForChild("State"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared:WaitForChild("Net"))
local camera = workspace.CurrentCamera

local events = {}
Net.Ride.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Denied" then
		table.insert(events, string.format("Denied %s %s", tostring(a), tostring(b)))
	elseif kind == "Mounted" then
		table.insert(events, "Mounted")
	end
end)

local function waitFor(f, most)
	local t0 = os.clock()
	while os.clock() - t0 < most do
		if f() then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return false
end

local function testFish()
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("B3Test") and m:GetAttribute("Rider") == 0 and not m:GetAttribute("B3Done") then
			return m
		end
	end
	return nil
end

-- one hop onto a fish swimming `speed`; `press`: 1 presses the grab as soon as the lock is on it, 0 leaves it to the
-- hands-off pull-in. True when we end up riding that fish.
local function trial(land, speed, press, back, kind)
	-- on a fish in that land, and still on it a moment later (a fish too strong throws us off in that time)
	local from = nil
	for _ = 1, 4 do
		report:FireServer("place", land)
		if waitFor(function()
			return State.Mode == "Riding" and State.Fish ~= nil
		end, 14) then
			task.wait(1.2)
			if State.Mode == "Riding" and State.Fish and State.Fish.PrimaryPart then
				from = State.Fish
				break
			end
		end
	end
	if not from then
		log("TRIAL speed %d: never seated (mode %s)", speed, tostring(State.Mode))
		return false
	end
	local fromSpeed = from.PrimaryPart.AssemblyLinearVelocity.Magnitude
	-- (the test fish comes from behind and is beside us about 0.9 s into the hop, whatever we leave at)
	back = math.max(30, (speed - (fromSpeed * Config.Jump.Launch + Config.Jump.HopBoost)) * 0.9)
	table.clear(events)
	Actions.jump()
	if not waitFor(function()
		return State.Mode == "Jumping"
	end, 1) then
		log("TRIAL speed %d: no hop (mode %s)", speed, tostring(State.Mode))
		return false
	end
	local hopAt = os.clock()
	report:FireServer("spawn", speed, back, kind)
	local fish = nil
	local pressedAt, lockAt, lockGap, lockReach, seenSpeed = nil, nil, 0, 0, 0
	local nearest = math.huge
	local done = waitFor(function()
		fish = fish or testFish()
		local _, root = State.character()
		if fish and fish.PrimaryPart and root then
			local to = fish.PrimaryPart.Position + fish.PrimaryPart.AssemblyLinearVelocity * 0.15 - camera.CFrame.Position
			RideController.look(math.atan2(-to.X, -to.Z), math.asin(math.clamp(to.Unit.Y, -1, 1)), true)
			local gap = (fish.PrimaryPart.Position - root.Position).Magnitude
			nearest = math.min(nearest, gap)
			if State.JumpTarget == fish and not lockAt then
				lockAt = os.clock() - hopAt
				lockGap = gap
				lockReach = State.Reach or 0
				seenSpeed = fish.PrimaryPart.AssemblyLinearVelocity.Magnitude
			end
			if press == 1 and State.JumpTarget == fish and not pressedAt and os.clock() - hopAt > 0.3 then
				pressedAt = os.clock() - hopAt
				Actions.jump()
			end
		end
		return State.Mode ~= "Jumping" or #events > 0 and events[#events] ~= "Mounted" and false
	end, 5)
	task.wait(0.3)
	local ok = State.Mode == "Riding" and State.Fish == fish and fish ~= nil
	-- and still on it a moment later (not thrown straight off)
	local kept = ok
	if ok then
		task.wait(1.2)
		kept = State.Mode == "Riding" and State.Fish == fish
	end
	log(
		"TRIAL land %d fish %d st/s (seen %.0f) off a %.0f fish, press %d: %s | lock at %.2f s gap %.0f reach %.0f, nearest %.0f, pressed %s | mode %s%s | %s",
		land,
		speed,
		seenSpeed,
		fromSpeed,
		press,
		if kept then "LANDED" elseif ok then "LANDED THEN LOST" else "NOT LANDED",
		lockAt or -1,
		lockGap,
		lockReach,
		nearest,
		if pressedAt then string.format("%.2f", pressedAt) else "no",
		tostring(State.Mode),
		if done then "" else " (timed out)",
		table.concat(events, ", ")
	)
	if fish then
		fish:SetAttribute("B3Done", true)
	end
	return kept
end

local busy = false
RS:GetAttributeChangedSignal("B3Client"):Connect(function()
	local text = RS:GetAttribute("B3Client")
	if type(text) ~= "string" or busy then
		return
	end
	local words = string.split(text, " ")
	busy = true
	local ok, err = pcall(function()
		if words[1] == "sweep" then
			-- sweep <land> <press> <times> <kind> <speed> <speed> ...
			local land, press, times, kind = tonumber(words[2]), tonumber(words[3]), tonumber(words[4]), words[5]
			for i = 6, #words do
				local speed = tonumber(words[i])
				if speed then
					local good = 0
					for _ = 1, times do
						-- (it comes from behind and is beside us about 0.9 s into the hop)
						local back = math.max(40, (speed - 110) * 0.9)
						if trial(land, speed, press, back, kind) then
							good += 1
						end
					end
					log("SWEEP %d st/s: %d of %d landed", speed, good, times)
				end
			end
			log("SWEEP DONE %s", text)
		elseif words[1] == "landcam" then
			-- the view held on the player from in front and above, for the landing's picture (off: "landcam 0")
			RunService:UnbindFromRenderStep("B3Cam")
			if words[2] ~= "0" then
				local _, root = State.character()
				local at = root.Position - Vector3.new(0, 2.5, 0)
				local eye = at + root.CFrame.LookVector * 15 + root.CFrame.RightVector * 6 + Vector3.new(0, 8, 0)
				RunService:BindToRenderStep("B3Cam", Enum.RenderPriority.Last.Value + 5, function()
					camera.CameraType = Enum.CameraType.Scriptable
					camera.CFrame = CFrame.lookAt(eye, at)
					camera.FieldOfView = 55
				end)
			else
				camera.CameraType = Enum.CameraType.Custom
			end
			log("LANDCAM %s", tostring(words[2]))
		elseif words[1] == "dive" then
			-- dive <fish> <click 0|1>: the end of a dive played as the game plays it; how long it stays up
			local Banners = require(Client.UI.Banners)
			local CatchShow = require(Client.UI.CatchShow)
			local list = {}
			local kinds = { "BlueChromis", "Clownfish", "Boxfish", "FlyingFish", "SeaTurtle", "ReefShark", "Seahorse" }
			for i = 1, math.min(tonumber(words[2]) or 0, 7) do
				local kind = Config.FishById[kinds[i]]
				table.insert(list, { Id = kinds[i], Tier = kind.Tier or kind.Rarity or "Common" })
			end
			local gui = player.PlayerGui
			local probe = Instance.new("Frame")
			probe.Parent = gui:FindFirstChildWhichIsA("ScreenGui")
			local show = CatchShow.preview(probe, CatchShow.look(), 312, true, list)
			local settled = show and show.settled or -1
			probe:Destroy()
			local t0 = os.clock()
			Banners.greatDive(312, true, list)
			local up = CatchShow.showing()
			local pressedAt = nil
			if words[3] == "1" then
				task.wait(settled + 0.5)
				pressedAt = os.clock() - t0
				CatchShow.press()
			end
			waitFor(function()
				return not CatchShow.showing()
			end, 40)
			local gone = os.clock() - t0
			log(
				"DIVE %d fish, look %d: up=%s, settled at %.2f s, %s, gone at %.2f s (%.2f s after it settled%s)",
				#list,
				CatchShow.look(),
				tostring(up),
				settled,
				if pressedAt then string.format("clicked at %.2f s", pressedAt) else "left alone",
				gone,
				gone - settled,
				if pressedAt then string.format(", %.2f s after the click", gone - pressedAt) else ""
			)
		elseif words[1] == "set" then
			local value = tonumber(words[4])
			Config[words[2]][words[3]] = value
			report:FireServer("set", words[2], words[3], value)
			log("SET %s.%s = %s", words[2], words[3], tostring(value))
		end
	end)
	if not ok then
		log("ERROR %s", tostring(err))
	end
	busy = false
end)
log("driver up")
