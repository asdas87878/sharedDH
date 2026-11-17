-- Server context of a playtest (task u2): hold the player's character near a spot so the herd is made there, aim the
-- mock's camera, and set what the mock draws. EYE/AT = {x, y, z}; VERSION "" turns the mock off.
local VERSION = "Now"
local MODE = "scene"
local SET = "near"
local ZOOM = 2
local EYE = nil
local AT = nil
local CLOCK = nil
local NOHUD = false
local STAMP = 0
local RIDE = nil -- a new number: onto a fish (the sandbox reset)
local FREEZE = nil -- a new number freezes the scene as it is now, 0 lets go; nil leaves it
local FREE = false -- let the character go (unanchored)
local RS = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players"):GetPlayers()[1]
if EYE and AT and plr and plr.Character then
	local root = plr.Character:FindFirstChild("HumanoidRootPart")
	local eye, at = Vector3.new(EYE[1], EYE[2], EYE[3]), Vector3.new(AT[1], AT[2], AT[3])
	if root then
		root.Anchored = true
		root.CFrame = CFrame.new(eye + (eye - at).Unit * 14 + Vector3.new(0, 6, 0))
	end
	RS:SetAttribute("SizeMockCam", CFrame.lookAt(eye, at))
elseif EYE == nil then
	RS:SetAttribute("SizeMockCam", nil)
end
RS:SetAttribute("SizeMockMode", MODE)
RS:SetAttribute("SizeMockSet", SET)
RS:SetAttribute("SizeMockZoom", ZOOM)
RS:SetAttribute("SizeMockClock", CLOCK)
RS:SetAttribute("SizeMockNoHud", NOHUD)
RS:SetAttribute("SizeMockStamp", STAMP)
if RIDE then
	RS:SetAttribute("SizeMockRide", RIDE)
end
if FREEZE then
	RS:SetAttribute("SizeMockFreeze", FREEZE)
end
if FREE and plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
	plr.Character.HumanoidRootPart.Anchored = false
end
RS:SetAttribute("SizeMock", VERSION)
local n = 0
local f = workspace:FindFirstChild("Fish")
if f then
	n = #f:GetChildren()
end
return "set " .. VERSION .. " fish " .. n
