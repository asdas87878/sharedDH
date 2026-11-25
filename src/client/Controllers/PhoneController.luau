--!strict
-- What a phone or tablet is spared (the user, 2026-11-25: "optimize the game for mobile"; Config.Phone; the numbers are in
-- docs/playtests/2026-11-25-phone-numbers.md). Only on this player's machine, and only where there is touch and no
-- keyboard; a PC is as it was. In Studio the workspace's "HudTouch" (true) counts as a phone.
--   The screen is held to landscape, whichever way up.
--   The sun's shadows are off (they draw every part again; 82,000 parts cast one), and so are the glow, the sun's rays and
--   the blur. What turns one back on (LookController when a number changes) is put off again.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local PhoneController = {}

local watched: { [Instance]: boolean } = {}
local on = false

function PhoneController.isPhone(): boolean
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("HudTouch")
		if type(forced) == "boolean" then
			return forced
		end
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function spare(effect: Instance)
	if not effect:IsA("BloomEffect") and not effect:IsA("SunRaysEffect") and not effect:IsA("DepthOfFieldEffect") then
		return
	end
	if Config.Phone.Effects == 0 and effect.Enabled then
		effect.Enabled = false
	end
	if not watched[effect] then
		watched[effect] = true
		effect:GetPropertyChangedSignal("Enabled"):Connect(function()
			if on and Config.Phone.Effects == 0 and effect.Enabled then
				effect.Enabled = false
			end
		end)
	end
end

function PhoneController.Start()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	if UserInputService.TouchEnabled then
		gui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end
	if Config.Phone.On == 0 or not PhoneController.isPhone() then
		return
	end
	on = true
	if Config.Phone.Shadows == 0 then
		Lighting.GlobalShadows = false
		Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
			if Lighting.GlobalShadows and Config.Phone.Shadows == 0 then
				Lighting.GlobalShadows = false
			end
		end)
	end
	for _, effect in Lighting:GetChildren() do
		spare(effect)
	end
	Lighting.ChildAdded:Connect(spare)
end

return PhoneController
