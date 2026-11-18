-- Temporary client script for the land strip's task-l1 captures. Installed into StarterPlayerScripts as "ZZStripL1" by
-- l1_capture.py, removed after. While ReplicatedStorage's "L1Show" is true it draws the real style-1 strip
-- (Client.UI.LandStrip.preview) once per cell of the JSON in "L1Cells": each cell { x, y, s (scale), w, h (the holder,
-- GUI px before its scale; default 310 by 100), o { Font, Intro, Reveal }, st { land, along, metres, best,
-- bestMetres } }. "L1States" (JSON, one state per cell) moves the strips without building them again, so a lock can
-- break; "L1Do" (JSON { n, cell, land, name, metres, new }) plays a land's intro in a cell; "L1Slow" slows every break and
-- intro (LandStrip.Slow). "L1Back" is the dark backing's transparency (1 shows the game), "L1HideHud" hides the rest.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local function report(text: string)
	local remote = RS:FindFirstChild("ZZL1Report")
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
local ATLAS = "rbxasset://textures/ridefish/land_atlas_g4.png"

local gui = Instance.new("ScreenGui")
gui.Name = "ZZStripL1"
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
local key, stateKey, doKey = "", "", ""

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
		holder.Size = UDim2.fromOffset(cell.w or 310, cell.h or 100)
		holder.BackgroundTransparency = 1
		holder.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Scale = cell.s or 2
		scale.Parent = holder
		local o = cell.o or {}
		local font = nil
		if o.Font then
			local okFont, f = pcall(function()
				return (Enum.Font :: any)[o.Font]
			end)
			font = if okFont then f else nil
		end
		local okBuild, strip = pcall(LandStrip.preview, holder, {
			Numbers = 0,
			Reveal = o.Reveal or "Best",
			Atlas = ATLAS,
			Fixed = true,
			Intro = o.Intro,
			Font = font,
		})
		if not okBuild then
			report("build: " .. tostring(strip))
			continue
		end
		table.insert(built, { holder = holder, strip = strip, st = cell.st or {} })
	end
	report("rebuilt " .. #built)
end

RunService.RenderStepped:Connect(function()
	local show = RS:GetAttribute("L1Show") == true
	gui.Enabled = show
	local hide = show and RS:GetAttribute("L1HideHud") == true
	for _, g in gui.Parent:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui then
			if hide and g.Enabled then
				g:SetAttribute("L1Was", true)
				g.Enabled = false
			elseif not hide and g:GetAttribute("L1Was") then
				g:SetAttribute("L1Was", nil)
				g.Enabled = true
			end
		end
	end
	if not show then
		return
	end
	LandStrip.Slow = RS:GetAttribute("L1Slow") or 1
	local json = RS:GetAttribute("L1Cells") or "[]"
	if json ~= key then
		key = json
		stateKey = ""
		rebuild(json)
	end
	local states = RS:GetAttribute("L1States") or ""
	if states ~= stateKey then
		stateKey = states
		local ok, list = pcall(HttpService.JSONDecode, HttpService, states)
		if ok and type(list) == "table" then
			for i, st in list do
				if built[i] and type(st) == "table" then
					built[i].st = st
				end
			end
		end
	end
	back.BackgroundTransparency = RS:GetAttribute("L1Back") or 0
	for _, c in built do
		local st = c.st
		if c.failed then
			continue
		end
		local land = st.land or 6
		local okUpdate, err = pcall(function()
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
	local act = RS:GetAttribute("L1Do") or ""
	if act ~= doKey then
		doKey = act
		local ok, a = pcall(HttpService.JSONDecode, HttpService, act)
		if ok and type(a) == "table" and built[a.cell or 1] then
			local okIntro, err = pcall(
				built[a.cell or 1].strip.intro,
				a.land,
				NAMES[a.land],
				a.metres or 600,
				a.new == true
			)
			if not okIntro then
				report("intro: " .. tostring(err))
			end
		end
	end
end)
report("up")

-- L1Ride (a number that changes): the sandbox's own reset onto a fish, endless air and no fail, for a game backdrop
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local lastRide = RS:GetAttribute("L1Ride")
RS:GetAttributeChangedSignal("L1Ride"):Connect(function()
	local now = RS:GetAttribute("L1Ride")
	if now ~= lastRide then
		lastRide = now
		Net.Sandbox:FireServer("Flag", "EndlessAir", true)
		Net.Sandbox:FireServer("Flag", "NoFail", true)
		Net.Sandbox:FireServer("Reset")
	end
end)
