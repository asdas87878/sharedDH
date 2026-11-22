-- b3 hook test: the server side (temporary; installed by check.py, removed after the run)
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local FishService = require(Services:WaitForChild("FishService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared:WaitForChild("Net"))

local log = Instance.new("StringValue")
log.Name = "B3Log"
log.Parent = SS
local function say(text)
	log.Value ..= text .. "\n"
end
local report = Instance.new("RemoteEvent")
report.Name = "ZZB3Report"
report.Parent = RS

local land = 10
local function place(player)
	local s = (FishService.landStart(land) or 0) + 400
	local at, along = FishService.lanePoint(s)
	RideService.sandboxReset(player, nil, nil, nil, { At = at, Along = along })
end

local testFish = nil
local function spawn(player, speed, back, kind)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local s = FishService.streamS(root.Position)
	local _, along = FishService.lanePoint(s)
	local velocity = root.AssemblyLinearVelocity
	local dir = if velocity.Magnitude > 5 then (velocity * Vector3.new(1, 0, 1)).Unit else along
	local right = dir:Cross(Vector3.yAxis)
	local at = root.Position - dir * back + right * 14 - Vector3.new(0, 6, 0)
	local w = FishService.spawnTest(kind, "", at, dir)
	if not w then
		say("SPAWN FAILED " .. kind)
		return
	end
	-- a fast one of the herd, at exactly this speed (as a bolt is made: its own share of the fast ones' pace)
	w.Pace = "Zoom"
	w.Own = speed / math.max(w.Land * Config.Pace.Zoom, 1)
	w.Gait = Config.Pace.Zoom * w.Own
	w.Model:SetAttribute("Pace", "Zoom")
	w.Model:SetAttribute("B3Test", true)
	testFish = w
end

report.OnServerEvent:Connect(function(player, kind, a, b, c)
	if kind == "log" then
		say(tostring(a))
	elseif kind == "place" then
		land = tonumber(a) or land
		place(player)
	elseif kind == "spawn" then
		spawn(player, tonumber(a) or 200, tonumber(b) or 150, tostring(c or "BlueChromis"))
	elseif kind == "set" then
		local group = (Config :: any)[a]
		if type(group) == "table" then
			group[b] = c
			if Config.refresh then
				Config.refresh()
			end
		end
	end
end)

-- what the server sees at each ask about the test fish
Net.Action.OnServerEvent:Connect(function(player, action, target)
	if (action ~= "Grab" and action ~= "Land") or typeof(target) ~= "Instance" then
		return
	end
	local w = FishService.get(target)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not w or not root or not target:GetAttribute("B3Test") then
		return
	end
	say(
		string.format(
			"  SERVER %s: rider to fish %.1f studs, fish at %.0f st/s (wants %.0f), slowed=%s, landing allows %.1f",
			action,
			(w.Root.Position - root.Position).Magnitude,
			w.Root.AssemblyLinearVelocity.Magnitude,
			w.Land * w.Gait,
			tostring(target:GetAttribute("Eased")),
			w.Body.Z / 2 + Config.Jump.LandSlack * 2
		)
	)
end)

-- the client's commands come from the runner through this attribute
workspace:GetAttributeChangedSignal("B3Cmd"):Connect(function()
	RS:SetAttribute("B3Client", workspace:GetAttribute("B3Cmd"))
end)
say("server up")
