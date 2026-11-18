-- Temporary client script for the land strip's option sheets (task s2). Installed into StarterPlayerScripts as
-- "ZZStripOptions" by options_capture.py, removed after. While ReplicatedStorage's "OptShow" is true it draws the real
-- style-1 strip (Client.UI.LandStrip.preview) once per cell of the JSON in "OptCells": each cell
-- { x, y, s (scale), o (LandStrip options: Best, You, Lock, Line, Dark, Saturation, Blur, Reveal, Numbers),
--   st { land, along, metres, best, bestMetres, touch } }. A cell's holder is 310 by 100 GUI px before its scale, its
-- top left at (x, y). "OptBack" is the dark backing's transparency (1 shows the game), "OptHideHud" hides the rest.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
-- what went wrong (or "up"), to the server driver: ReplicatedStorage.ZZOptReport, made by options_capture.py
local function report(text: string)
	local remote = RS:FindFirstChild("ZZOptReport")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(text)
	end
end
report("starting")
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local okRequire, LandStrip = pcall(require, client:WaitForChild("UI"):WaitForChild("LandStrip"))
if not okRequire then
	report("require: " .. tostring(LandStrip))
end

local NAMES = { "Shallows", "Coral Reef", "Kelp Forest", "Shipwrecks", "Open Blue", "Twilight", "Midnight", "Vents",
	"Bone Graveyard", "The Underworld" }

local gui = Instance.new("ScreenGui")
gui.Name = "ZZStripOptions"
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

local built: { any } = {}
local key = ""

local function rebuild(json: string)
	for _, c in built do
		c.holder:Destroy()
	end
	built = {}
	local ok, cells = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then
		return
	end
	for _, cell in cells do
		local holder = Instance.new("Frame")
		holder.Position = UDim2.fromOffset(cell.x, cell.y)
		holder.Size = UDim2.fromOffset(310, 100)
		holder.BackgroundTransparency = 1
		holder.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Scale = cell.s or 2
		scale.Parent = holder
		local o = cell.o or {}
		local opts = {
			Numbers = o.Numbers or 2,
			Reveal = o.Reveal or "Dive",
			Atlas = workspace:GetAttribute("LandAtlas") or "rbxasset://textures/ridefish/land_atlas.png",
			Fixed = true,
			Best = o.Best,
			You = o.You,
			Lock = o.Lock,
			Line = o.Line,
			Dark = o.Dark,
			Saturation = o.Saturation,
			Blur = o.Blur,
		}
		local okBuild, strip = pcall(LandStrip.preview, holder, opts)
		if not okBuild then
			report("build: " .. tostring(strip))
			continue
		end
		strip.root.Position = UDim2.new(0.5, 0, 0, 10)
		table.insert(built, { holder = holder, strip = strip, st = cell.st or {} })
	end
end

RunService.RenderStepped:Connect(function()
	local show = RS:GetAttribute("OptShow") == true
	gui.Enabled = show
	local hide = show and RS:GetAttribute("OptHideHud") == true
	for _, g in gui.Parent:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui then
			if hide and g.Enabled then
				g:SetAttribute("OptWas", true)
				g.Enabled = false
			elseif not hide and g:GetAttribute("OptWas") then
				g:SetAttribute("OptWas", nil)
				g.Enabled = true
			end
		end
	end
	if not show then
		return
	end
	local json = RS:GetAttribute("OptCells") or "[]"
	if json ~= key then
		key = json
		rebuild(json)
	end
	back.BackgroundTransparency = RS:GetAttribute("OptBack") or 0
	for _, c in built do
		local st = c.st
		if c.failed then
			continue
		end
		local land = st.land or 6
		local okUpdate, err = pcall(function()
		c.strip.place(st.touch == true)
		c.strip.update(
			land,
			NAMES[math.clamp(land, 1, 10)],
			st.along or 0.5,
			st.metres or 600,
			st.best or 7.4,
			st.bestMetres or 1300
		)
		end)
		if not okUpdate then
			c.failed = true
			report("update: " .. tostring(err))
		end
	end
end)
report("up")

-- OptRide (a number that changes): the sandbox's own reset onto a fish, endless air and no fail, for a game backdrop
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local lastRide = RS:GetAttribute("OptRide")
RS:GetAttributeChangedSignal("OptRide"):Connect(function()
	local now = RS:GetAttribute("OptRide")
	if now ~= lastRide then
		lastRide = now
		Net.Sandbox:FireServer("Flag", "EndlessAir", true)
		Net.Sandbox:FireServer("Flag", "NoFail", true)
		Net.Sandbox:FireServer("Reset")
	end
end)
