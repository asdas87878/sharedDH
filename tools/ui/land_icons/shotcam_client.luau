-- Temporary client script for the land-icon shots (tools/ui/land_icons, task u1). Installed into
-- StarterPlayer.StarterPlayerScripts as "ZZShotCam" by install.luau for one playtest, removed after.
-- While ReplicatedStorage has a CFrame attribute "ShotCam", the camera is held there (after every other camera script),
-- the player's own character is hidden (unless "ShotChar"), and the HUD is hidden unless "ShotHud" is true.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local hidden: { [ScreenGui]: boolean } = {}

RunService:BindToRenderStep("ZZShotCam", Enum.RenderPriority.Last.Value + 50, function()
	local cf = RS:GetAttribute("ShotCam")
	local cam = workspace.CurrentCamera
	if typeof(cf) ~= "CFrame" then
		for gui, was in hidden do
			gui.Enabled = was
		end
		table.clear(hidden)
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf
	cam.FieldOfView = RS:GetAttribute("ShotFov") or 70
	local char = player.Character
	local showChar = RS:GetAttribute("ShotChar") == true
	if char then
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if showChar then 0 else 1
			end
		end
	end
	local showHud = RS:GetAttribute("ShotHud") == true
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg then
		for _, g in pg:GetChildren() do
			if g:IsA("ScreenGui") then
				if not showHud then
					if hidden[g] == nil then
						hidden[g] = g.Enabled
					end
					g.Enabled = false
				elseif hidden[g] ~= nil then
					g.Enabled = hidden[g]
					hidden[g] = nil
				end
			end
		end
		-- the strip alone hidden, for a clean place to lay the options over
		local strip = pg:FindFirstChild("LandStrip", true)
		if strip and strip:IsA("GuiObject") and RS:GetAttribute("ShotNoStrip") == true then
			strip.Visible = false
		end
	end
end)
