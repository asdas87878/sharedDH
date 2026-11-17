-- Server context of a playtest: hold the player's character (anchored) near the shot so the map streams in there, and
-- point the shot camera. CAM = {x, y, z, tx, ty, tz}; CAM = nil lets go.
local CAM = nil
local HUD = false
local FOV = 70
local CHAR = false
local NOSTRIP = false
local ROOT = nil -- {x, y, z}: where to hold the character (default: behind the eye)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local plr = Players:GetPlayers()[1]
if not plr then
	return "no player"
end
local char = plr.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
if CAM == nil then
	RS:SetAttribute("ShotCam", nil)
	return "released"
end
local eye = Vector3.new(CAM[1], CAM[2], CAM[3])
local at = Vector3.new(CAM[4], CAM[5], CAM[6])
if root then
	root.Anchored = true
	-- a little behind and above the eye, out of view
	local back = (eye - at).Unit
	if ROOT then
		root.CFrame = CFrame.lookAt(Vector3.new(ROOT[1], ROOT[2], ROOT[3]), Vector3.new(at.X, ROOT[2], at.Z))
	else
		root.CFrame = CFrame.new(eye + back * 12 + Vector3.new(0, 4, 0))
	end
end
RS:SetAttribute("ShotHud", HUD)
RS:SetAttribute("ShotChar", CHAR)
RS:SetAttribute("ShotNoStrip", NOSTRIP)
RS:SetAttribute("ShotFov", FOV)
RS:SetAttribute("ShotCam", CFrame.lookAt(eye, at))
return "aimed"
