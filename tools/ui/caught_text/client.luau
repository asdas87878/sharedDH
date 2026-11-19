-- Temporary client script for the caught-text captures (task t2). Installed into StarterPlayerScripts as "ZZCaughtText"
-- by capture.py, removed after. While ReplicatedStorage's "CaughtOn" is true it shows the game's own look
-- (Client.UI.CaughtText.preview) in the HUD at its own place, stopped at "CaughtT" seconds. A change of "CaughtRun"
-- rebuilds it from "CaughtLook", "CaughtFish", "CaughtEarns" (-1: none) and "CaughtNew". "CaughtReset" (any new value) asks the sandbox to put us on a fish.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local function report(text: string)
	local remote = RS:FindFirstChild("ZZCaughtReport")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(text)
	end
end
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local ok, CaughtText = pcall(require, client:WaitForChild("UI"):WaitForChild("CaughtText"))
if not ok then
	report("require: " .. tostring(CaughtText))
	return
end
report("ready")

-- "CaughtReset" changed: the sandbox's reset puts us on a fish (in the water, as when a catch happens)
local resetKey = RS:GetAttribute("CaughtReset")
RS:GetAttributeChangedSignal("CaughtReset"):Connect(function()
	if RS:GetAttribute("CaughtReset") ~= resetKey then
		resetKey = RS:GetAttribute("CaughtReset")
		local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
		Net.Sandbox:FireServer("Reset")
		report("reset sent")
	end
end)

local show: any = nil
local runKey = nil
RunService.RenderStepped:Connect(function()
	local on = RS:GetAttribute("CaughtOn") == true
	local run = RS:GetAttribute("CaughtRun")
	if not on then
		if show then
			show.root:Destroy()
			show = nil
		end
		runKey = nil
		return
	end
	if run ~= runKey then
		runKey = run
		if show then
			show.root:Destroy()
			show = nil
		end
		local hud = player.PlayerGui:FindFirstChild("RideHud")
		local root = hud and hud:FindFirstChild("Root")
		if not root then
			report("no hud root")
			return
		end
		local look = RS:GetAttribute("CaughtLook") or 1
		local earns = RS:GetAttribute("CaughtEarns") or -1
		local info = CaughtText.info(RS:GetAttribute("CaughtFish") or "ReefShark", if earns >= 0 then earns else nil,
			RS:GetAttribute("CaughtNew") == true)
		local okB, s = pcall(CaughtText.preview, root, look, info)
		if not okB or not s then
			report("build: " .. tostring(s))
			return
		end
		show = s
		show.root.Position = CaughtText.placeOf(look)
		report("built " .. tostring(look))
	end
	if show then
		local okP, err = pcall(show.pose, RS:GetAttribute("CaughtT") or 0)
		if not okP then
			report("pose: " .. tostring(err))
		end
	end
end)
