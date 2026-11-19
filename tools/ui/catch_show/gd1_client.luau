-- Temporary client script for task gd1 (GREAT DIVE on caught text 5's banner, in the real game). Installed into
-- StarterPlayerScripts as "ZZCatchGD1" by gd1_capture.py, removed after. Driven by ReplicatedStorage attributes:
--   GD1Show (a number: each new value plays the real end of a dive, Banners.greatDive, with the sheet's seven fish)
--   GD1Look (the DiveScreen variant 1 to 4, set on the workspace as "DiveLook" before the show is built)
--   GD1Clock (a number: CatchShow's clock stopped there; nil: the real clock)
--   GD1Count (how many of the seven fish; nil: all), GD1Best (false: not a new best)
--   GD1Press ("<id>:<count>": that many presses through CatchShow.press in one frame)
-- Reports through ReplicatedStorage.ZZCatchReport.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local function report(text: string)
	local remote = RS:FindFirstChild("ZZCatchReport")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(text)
	end
end
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local UI = client:WaitForChild("UI")
local CatchShow = require(UI:WaitForChild("CatchShow"))
local Banners = require(UI:WaitForChild("Banners"))
local realClock = os.clock

local LIST = {
	{ Id = "Clownfish", Tier = "Common" },
	{ Id = "YellowTang", Tier = "Common" },
	{ Id = "Lionfish", Tier = "Uncommon" },
	{ Id = "Dolphin", Tier = "Rare" },
	{ Id = "ReefShark", Tier = "Epic" },
	{ Id = "MantaRay", Tier = "Epic" },
	{ Id = "Megalodon", Tier = "Legendary" },
}

local seenShow, seenPress = nil, nil
RunService.RenderStepped:Connect(function()
	local clock = RS:GetAttribute("GD1Clock")
	if type(clock) == "number" then
		CatchShow.Clock = function()
			return clock
		end
	else
		CatchShow.Clock = realClock
	end
	local show = RS:GetAttribute("GD1Show")
	if show ~= seenShow then
		seenShow = show
		if show ~= nil then
			workspace:SetAttribute("CatchLook", 5)
			workspace:SetAttribute("DiveLook", RS:GetAttribute("GD1Look") or 1)
			local count = RS:GetAttribute("GD1Count")
			local list = LIST
			if type(count) == "number" then
				list = table.move(LIST, 1, count, 1, {})
			end
			local ok, err = pcall(Banners.greatDive, 312, RS:GetAttribute("GD1Best") ~= false, list)
			report("show " .. tostring(ok) .. " " .. tostring(err) .. " showing=" .. tostring(CatchShow.showing()))
		end
	end
	local press = RS:GetAttribute("GD1Press")
	if press ~= seenPress then
		seenPress = press
		if type(press) == "string" then
			local _, count = string.match(press, "^(%w+):(%d+)$")
			for _ = 1, tonumber(count) or 1 do
				CatchShow.press()
			end
			report("press " .. press .. " showing=" .. tostring(CatchShow.showing()))
		end
	end
end)
report("gd1 up")
