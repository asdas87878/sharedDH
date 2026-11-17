-- Every fish's picture on one sheet, drawn by the game's own Portrait module, to judge the framing. Edit mode.
--   node tools/studio/run_luau.js <studio_id> tools/ui/portrait_sheet.luau 'WHICH="all"'
--   WHICH: "all", "" (takes the sheet away), or names with commas between ("Dolphin,Kraken") for those few, bigger.
-- Run tools/studio/sync_src.py first: the sheet uses a copy of the UI code that is in Studio.
local WHICH = "all"

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

for _, where in { StarterGui, ServerStorage } do
	local old = where:FindFirstChild("PortraitSheet")
	if old then
		old:Destroy()
	end
end
if WHICH == "" then
	return "sheet taken away"
end

-- a fresh copy of the UI code, so the newest Portrait runs (a module that ran once is not run again)
local ui = game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI:Clone()
ui.Name = "PortraitSheet"
ui.Parent = ServerStorage
local Portrait = require(ui.Portrait)

local names = {}
if WHICH == "all" then
	for _, model in ReplicatedStorage.FishModels:GetChildren() do
		table.insert(names, model.Name)
	end
	table.sort(names)
else
	names = string.split(WHICH, ",")
end

local gui = Instance.new("ScreenGui")
gui.Name = "PortraitSheet"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = StarterGui
local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(56, 92, 128)
back.BorderSizePixel = 0
back.Parent = gui

local few = #names <= 16
local cols = if few then 4 else 13
local tile = if few then 180 else 100
local shown = 0
for i, name in names do
	local cell = Instance.new("Frame")
	cell.Position = UDim2.fromOffset(8 + ((i - 1) % cols) * (tile + 4), 8 + math.floor((i - 1) / cols) * (tile + 4))
	cell.Size = UDim2.fromOffset(tile, tile)
	cell.BackgroundColor3 = Color3.fromRGB(150, 200, 230)
	cell.BorderSizePixel = 0
	cell.ClipsDescendants = true
	cell.Parent = back
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255), Color3.fromRGB(150, 185, 215))
	grad.Rotation = 90
	grad.Parent = cell
	local function place(outline: number?)
		return Portrait.new(cell, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 0.9),
			Outline = outline,
		})
	end
	-- (the Portrait of before 2026-11-17 has no outline to set, and stops at the word)
	local ok, picture = pcall(place, if few then 2.2 else 1.6)
	if not ok then
		for _, left in cell:GetChildren() do
			if not left:IsA("UIGradient") then
				left:Destroy()
			end
		end
		picture = place(nil)
	end
	task.wait()
	if picture.show(name) then
		shown += 1
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -1)
	label.Size = UDim2.new(1, 0, 0, 13)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = if few then 13 else 9
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = name
	label.ZIndex = 5
	label.Parent = cell
end
return string.format("%d of %d pictures drawn", shown, #names)
