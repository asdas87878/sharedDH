-- Temporary client script for task c1 (the catch screen in the real game). Installed into StarterPlayerScripts as
-- "ZZCatchC1" by c1_capture.py, removed after. Driven by ReplicatedStorage attributes:
--   C1Show (a number: each new value plays the real end of a dive, Banners.greatDive, with the sheet's seven fish)
--   C1Clock (a number: CatchShow's clock stopped there; nil: the real clock)
--   C1Press ("<id>:<count>:<gap ms>": that many presses through CatchShow.press, gap 0 = all in one frame)
--   C1Ride (a number: each new value gets on a fish through the sandbox's reset)
-- Reports through ReplicatedStorage.ZZCatchReport.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
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
local State = require(client:WaitForChild("Lib"):WaitForChild("State"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
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

local function state(): string
	local root = player.PlayerGui:FindFirstChild("RideHud")
	local screen = root and root:FindFirstChild("CatchShow", true)
	local group = screen and screen:FindFirstChild("Screen")
	local hit = screen and screen:FindFirstChild("Hit")
	local back = screen and screen:FindFirstChild("Backdrop")
	return string.format(
		"showing=%s back=%s group=%s hit=%s",
		tostring(CatchShow.showing()),
		if back and back:IsA("Frame")
			then string.format("%.2f %s", back.BackgroundTransparency, tostring(back.AbsoluteSize))
			else "-",
		if group and group:IsA("CanvasGroup") then string.format("%.2f", group.GroupTransparency) else "-",
		if hit and hit:IsA("GuiObject") then tostring(hit.Visible) else "-"
	)
end

local seenShow, seenPress, seenRide = nil, nil, nil
RunService.RenderStepped:Connect(function()
	local clock = RS:GetAttribute("C1Clock")
	if type(clock) == "number" then
		CatchShow.Clock = function()
			return clock
		end
	else
		CatchShow.Clock = realClock
	end
	local show = RS:GetAttribute("C1Show")
	if show ~= seenShow then
		seenShow = show
		if show ~= nil then
			local best = RS:GetAttribute("C1Best") ~= false
			local count = RS:GetAttribute("C1Count")
			local list = LIST
			if type(count) == "number" then
				list = table.move(LIST, 1, count, 1, {})
			end
			local ok, err = pcall(Banners.greatDive, 312, best, list)
			report("show " .. tostring(ok) .. " " .. tostring(err) .. " " .. state())
		end
	end
	local press = RS:GetAttribute("C1Press")
	if press ~= seenPress then
		seenPress = press
		if type(press) == "string" then
			local _, count, gap = string.match(press, "^(%w+):(%d+):(%d+)$")
			local n, ms = tonumber(count) or 1, tonumber(gap) or 0
			task.spawn(function()
				local t0 = realClock()
				local log = {}
				for i = 1, n do
					CatchShow.press()
					table.insert(log, string.format("%d@%.0fms %s", i, (realClock() - t0) * 1000, state()))
					if ms > 0 then
						task.wait(ms / 1000)
					end
				end
				report("press " .. press .. "\n  " .. table.concat(log, "\n  "))
				task.wait(0.6)
				report("after 0.6 s: " .. state())
			end)
		end
	end
	local ride = RS:GetAttribute("C1Ride")
	if ride ~= seenRide then
		seenRide = ride
		if ride ~= nil then
			Net.Sandbox:FireServer("Reset")
			report("ride")
		end
	end
end)
task.spawn(function()
	local last = ""
	while true do
		task.wait(0.25)
		local caught = State.Caught
		local now = if caught then HttpService:JSONEncode(caught) else "nil"
		if now ~= last then
			last = now
			report(string.format("caught %.2f %s", realClock(), now))
		end
	end
end)
report("c1 up")
