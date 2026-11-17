-- Temporary client script for the land strip's options sheet (task l1). Installed into
-- StarterPlayer.StarterPlayerScripts as "ZZShotCam"'s neighbour "ZZStripPreview" by install_preview.luau, removed after.
-- While ReplicatedStorage's "PrevShow" is true it draws the real style-1 strip (Client.UI.LandStrip.preview) twice,
-- big (PrevScale) and at real size, from the attributes the server driver sets: PrevNumbers, PrevReveal, PrevLand,
-- PrevAlong, PrevMetres, PrevBestLands, PrevBestMetres, PrevBack (0 a dark backing, 1 the game behind), PrevTouch.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local LandStrip = require(client:WaitForChild("UI"):WaitForChild("LandStrip"))

local NAMES = { "Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue", "Twilight", "Midnight", "Vents",
	"Bone Graveyard", "The Underworld" }
local ATLAS = workspace:GetAttribute("LandAtlas") or "rbxasset://textures/ridefish/land_atlas.png"

local gui = Instance.new("ScreenGui")
gui.Name = "ZZStripPreview"
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
back.BorderSizePixel = 0
back.Parent = gui

local function holder(y: number): (Frame, UIScale)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, y)
	f.Size = UDim2.fromOffset(300, 90)
	f.BackgroundTransparency = 1
	f.Parent = gui
	local s = Instance.new("UIScale")
	s.Parent = f
	return f, s
end
local bigHolder, bigScale = holder(40)
local smallHolder = holder(0)

local strips: { any } = {}
local key = ""

RunService.RenderStepped:Connect(function()
	local show = RS:GetAttribute("PrevShow") == true
	gui.Enabled = show
	local hide = show and RS:GetAttribute("PrevHideHud") == true
	for _, g in gui.Parent:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui and g.Name ~= "ZZStripPreview" then
			if hide and g.Enabled then
				g:SetAttribute("PrevWas", true)
				g.Enabled = false
			elseif not hide and g:GetAttribute("PrevWas") then
				g:SetAttribute("PrevWas", nil)
				g.Enabled = true
			end
		end
	end
	if not show then
		return
	end
	local numbers = RS:GetAttribute("PrevNumbers") or 2
	local reveal = RS:GetAttribute("PrevReveal") or "Dive"
	local k = tostring(numbers) .. reveal
	if k ~= key then
		key = k
		for _, s in strips do
			s.root:Destroy()
		end
		local opts = { Numbers = numbers, Reveal = reveal, Atlas = ATLAS, Fixed = true }
		strips = { LandStrip.preview(bigHolder, opts), LandStrip.preview(smallHolder, opts) }
		for _, s in strips do
			s.root.Position = UDim2.new(0.5, 0, 0, 10)
		end
	end
	local scale = RS:GetAttribute("PrevScale") or 3
	bigScale.Scale = scale
	local view = workspace.CurrentCamera.ViewportSize
	smallHolder.Position = UDim2.new(0.5, 0, 0, 40 + 100 * scale + 20)
	local _ = view
	back.BackgroundTransparency = RS:GetAttribute("PrevBack") or 0
	local land = RS:GetAttribute("PrevLand") or 3
	local touch = RS:GetAttribute("PrevTouch") == true
	for _, s in strips do
		s.place(touch)
		s.update(
			land,
			NAMES[math.clamp(land, 1, 10)],
			RS:GetAttribute("PrevAlong") or 0.5,
			RS:GetAttribute("PrevMetres") or 60,
			RS:GetAttribute("PrevBestLands") or 4.4,
			RS:GetAttribute("PrevBestMetres") or 108
		)
	end
end)

-- PrevRide (a number that changes): the sandbox's own reset onto a fish at the start, with endless air and no fail,
-- for a real ride down the lane (the server's BestService then raises BestMetres and BestLands)
local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))
local lastRide = RS:GetAttribute("PrevRide")
RS:GetAttributeChangedSignal("PrevRide"):Connect(function()
	local now = RS:GetAttribute("PrevRide")
	if now ~= lastRide then
		lastRide = now
		Net.Sandbox:FireServer("Flag", "EndlessAir", true)
		Net.Sandbox:FireServer("Flag", "NoFail", true)
		Net.Sandbox:FireServer("Reset")
	end
end)
